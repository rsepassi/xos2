#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "uv.h"
#include "kv.h"
#include "log.h"

#define MINICORO_IMPL
#define MCO_DEFAULT_STACK_SIZE 128*1024
#include "minicoro.h"

#define KV_CHECK(x) do { \
  kv_result res = (x); \
  CHECK(res == KV_OK, "Error in KV: %s\n", kv_result_str(res)); \
  } while (0)

#define MCO_CHECK(x) do { \
  mco_result res = (x); \
  CHECK(res == MCO_SUCCESS, "Error in minicoro\n"); \
  } while (0)


#define CREATE(T, n) T* n = (T*)malloc(sizeof(T));

#define UV_CHECK(x) do { \
    const int rc = (x); \
    if (rc < 0) { fprintf(stderr, "Error in UV: %s\n", uv_strerror(rc)); exit(1); } \
  } while (0)

#define MAX_WAITERS 128

// Lock for coroutines
// On lock, if already locked, coroutine is added to waiters and suspends.
// On unlock, if there are waiters, a waiter is marked ready.
// Ready waiters are resumed from the top-level event loop.
typedef struct {
  mco_coro* locked;
  mco_coro* ready;
  mco_coro* waiters[MAX_WAITERS];
  size_t waiters_len;
  size_t waiters_head;
  size_t waiters_tail;
} corolock;

void corolock_lock(corolock* lock) {
  mco_coro* self = mco_running();

  if (lock->locked == NULL) {
    lock->locked = self;
    return;
  }

  CHECK((lock->waiters_len + 1) < MAX_WAITERS, "too many waiters");
  CHECK(lock->locked != self, "already hold the lock");

  lock->waiters[lock->waiters_tail] = self;
  ++lock->waiters_tail;
  if (lock->waiters_tail == MAX_WAITERS) lock->waiters_tail = 0;
  ++lock->waiters_len;
  
  while(lock->locked != self) mco_yield(self);
}

void corolock_unlock(corolock* lock) {
  mco_coro* self = mco_running();
  CHECK(lock->locked == self, "lock not held");
  lock->locked = NULL;

  if (lock->waiters_len == 0) return;

  // Mark a waiter as ready
  lock->ready = lock->waiters[lock->waiters_head];
  ++lock->waiters_head;
  if (lock->waiters_head == MAX_WAITERS) lock->waiters_head = 0;
  --lock->waiters_len;
}

void corolock_ready(corolock* lock) {
  lock->locked = lock->ready;
  lock->ready = NULL;
  MCO_CHECK(mco_resume(lock->locked));
}

typedef struct {
  uv_loop_t* loop;
  uv_file fd;
  kv_ctx kvctx;
  corolock lock;
} appctx;

typedef struct {
  mco_coro* co;
  ssize_t result;
  bool done;
} req_state;

void on_req_done(uv_fs_t *req) {
  req_state* data = (req_state*)req->data;
  data->result = req->result;
  data->done = true;
  LOG("on_req_done result=%li", req->result);
  MCO_CHECK(mco_resume(data->co));
}

void vfd_lock(void* fd) {
  LOG("vfd_lock");
  appctx* ctx = (appctx*)fd;
  corolock_lock(&ctx->lock);
}

void vfd_unlock(void* fd) {
  LOG("vfd_unlock");
  appctx* ctx = (appctx*)fd;
  corolock_unlock(&ctx->lock);
}

kv_result vfd_read(void* fd, uint64_t offset, kv_bufs bufs, uint64_t* n) {
  LOG("vfd_read");
  appctx* ctx = (appctx*)fd;

  req_state state = {
    .co = mco_running(),
  };
  uv_fs_t req;
  req.data = &state;
  UV_CHECK(uv_fs_read(ctx->loop, &req, ctx->fd, (const uv_buf_t*)bufs.bufs, bufs.len, offset, on_req_done));
  while(!state.done) mco_yield(state.co);
  LOG("vfd_read resumed");
  if (state.result < 0) return KV_ERR_IO_READ;
  *n = state.result;
  return KV_OK;
}

kv_result vfd_write(void* fd, uint64_t offset, kv_bufs bufs, uint64_t* n) {
  LOG("vfd_write");
  appctx* ctx = (appctx*)fd;

  req_state state = {
    .co = mco_running(),
  };
  uv_fs_t req;
  req.data = &state;
  UV_CHECK(uv_fs_write(ctx->loop, &req, ctx->fd, (const uv_buf_t*)bufs.bufs, bufs.len, offset, on_req_done));
  while(!state.done) mco_yield(state.co);
  LOG("vfd_write resumed");
  if (state.result < 0) return KV_ERR_IO_WRITE;
  *n = state.result;
  return KV_OK;
}

kv_result vfd_sync(void* fd) {
  LOG("vfd_sync");
  appctx* ctx = (appctx*)fd;

  req_state state = {
    .co = mco_running(),
  };
  uv_fs_t req;
  req.data = &state;
  UV_CHECK(uv_fs_fdatasync(ctx->loop, &req, ctx->fd, on_req_done));
  while(!state.done) mco_yield(state.co);
  LOG("vfd_sync resumed");
  if (state.result < 0) return KV_ERR_IO_SYNC;
  return KV_OK;
}

void* myrealloc(void* user_data, void* p, size_t align, size_t n) {
  if (p == NULL) {
    return aligned_alloc(align, n);
  } else if (n == 0) {
    free(p);
    return NULL;
  } else {
    // Zig only wants it if it can be grown in-place, and we can't determine
    // that here. If we try and fail, we'll end up double-freeing because
    // the Zig Allocator will free the old buffer if resize returns false.
    // void* newp = realloc(p, n);
    // if (newp == NULL) return NULL;
    // if (((uintptr_t)newp & (align - 1)) == 0) return newp;
    return NULL;
  }
}

void myfree(void* user_data, void* p) {
}

void run(appctx* myctx) {
  LOG("run");

  kv_ctx kv = myctx->kvctx;
  KV_CHECK(kv_init((kv_init_opts){
    .mem = (kv_mem){
      .realloc = myrealloc,
    },
    .vfd = (kv_vfd){
      .write = vfd_write,
      .read = vfd_read,
      .sync = vfd_sync,
      .lock = vfd_lock,
      .unlock = vfd_unlock,
      .user_data = myctx,
    },
    .flags = KV_INIT_ALLOWCREATE,
  }, &kv));

  kv_buf key = {
    .buf = "hi",
    .len = 2,
  };
  kv_buf val = {
    .buf = "bye",
    .len = 3,
  };

  LOG("kv size %llu", kv_nrecords(kv));
  KV_CHECK(kv_put(kv, key, val));
  LOG("kv size %llu", kv_nrecords(kv));
  KV_CHECK(kv_get(kv, key, &val));
  LOG("kv size %llu", kv_nrecords(kv));
  KV_CHECK(kv_del(kv, key));
  LOG("kv size %llu", kv_nrecords(kv));

  KV_CHECK(kv_deinit(kv));
}

void run_coro(mco_coro* co) {
  appctx* myctx = (appctx*)mco_get_user_data(co);
  run(myctx);
}

const char* test_filepath = "/tmp/mydb.kv";

int main(int argc, char** argv) {
  appctx myctx;

  uv_loop_t* loop = uv_default_loop();

  uv_fs_t fs_req;
  UV_CHECK(uv_fs_open(
        loop,
        &fs_req,
        test_filepath,
        UV_FS_O_RDWR | UV_FS_O_CREAT,
        S_IREAD | S_IWRITE | S_IRGRP | S_IWGRP | S_IROTH,
        NULL));
  myctx.loop = loop;
  myctx.fd = fs_req.result;
  myctx.lock = (corolock){0};

  UV_CHECK(uv_fs_ftruncate(loop, &fs_req, myctx.fd, 0, NULL));

  mco_coro* co;
  mco_desc desc = mco_desc_init(run_coro, 0);
  desc.user_data = &myctx;
  MCO_CHECK(mco_create(&co, &desc));
  MCO_CHECK(mco_resume(co));

  while (true) {
    uv_run(loop, UV_RUN_DEFAULT);
    if (myctx.lock.ready == NULL) break;
    corolock_ready(&myctx.lock);
  }

  MCO_CHECK(mco_destroy(co));
  UV_CHECK(uv_fs_close(loop, &fs_req, myctx.fd, NULL));
  uv_fs_req_cleanup(&fs_req);
  uv_loop_close(loop);
  return 0;
}
