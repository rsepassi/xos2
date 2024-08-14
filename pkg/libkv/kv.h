#ifndef KV_H_
#define KV_H_

#include <stdint.h>   // uint64_t
#include <stdbool.h>  // bool
#include <stdlib.h>   // size_t

typedef struct kv_ctx* kv_ctx;
typedef struct kv_txn* kv_txn;
struct kv_ctx;
struct kv_txn;

typedef enum {
  KV_OK,
  KV_KEY_NOT_FOUND,
  KV_ERR,
  KV_ERR_VFD_MISSING,
  KV_ERR_MEM_MISSING,
  KV_ERR_EMPTY_METADATA,
  KV_ERR_BAD_METADATA,
  KV_ERR_OOM,
  KV_ERR_IO_SYNC,
  KV_ERR_IO_READ,
  KV_ERR_IO_WRITE,
  KV_ERR_CORRUPT_DATA,
  KV_ERR_DB_RO,
  KV_ERR_TXN_RO,
  KV_ERR_BAD_KEY,
  KV__RESULT_SENTINEL,
} kv_result;

typedef struct {
  char* buf;
  size_t len;
} kv_buf;

typedef struct {
  kv_buf* bufs;
  size_t len;
} kv_bufs;

typedef struct {
  void* (*realloc)(void* user_data, void* p, size_t align, size_t size);
  void* user_data;
} kv_mem;

typedef struct {
  kv_result (*read)(void* user_data, uint64_t offset, kv_bufs bufs, uint64_t* n);
  kv_result (*write)(void* user_data, uint64_t offset, kv_bufs bufs, uint64_t* n);
  kv_result (*sync)(void* user_data);
  void (*lock)(void* user_data);
  void (*unlock)(void* user_data);
  void* user_data;
} kv_vfd;

#define KV_INIT_READONLY    (1 << 0)
#define KV_INIT_ALLOWCREATE (1 << 1)

typedef struct {
  kv_vfd vfd;
  kv_mem mem;
  uint64_t flags; // KV_INIT_*
} kv_init_opts;

#define KV_TXN_READONLY (1 << 0)

typedef struct {
  kv_txn parent;
  uint64_t flags; // KV_TXN_*
} kv_txn_opts;

typedef enum {
  KV_ITER_CONTINUE,
  KV_ITER_STOP,
} kv_iter_cb_ctrl;

typedef struct {
  kv_iter_cb_ctrl (*cb)(void* user_data, kv_result res, kv_buf key, kv_buf val);
  void* user_data;
} kv_iter_cb;

kv_result kv_init(kv_init_opts opts, kv_ctx* ctx);
kv_result kv_deinit(kv_ctx ctx);
uint64_t kv_nrecords(kv_ctx ctx);

kv_result kv_get(kv_ctx ctx, kv_buf key, kv_buf* val);
kv_result kv_put(kv_ctx ctx, kv_buf key, kv_buf val);
kv_result kv_del(kv_ctx ctx, kv_buf key);
void kv_iter(kv_ctx ctx, kv_buf prefix, kv_iter_cb cb);

kv_result kv_txn_init(kv_ctx ctx, kv_txn_opts opts, kv_txn* txn);
kv_result kv_txn_deinit(kv_txn txn);
kv_result kv_txn_reset(kv_txn txn);

kv_result kv_txn_commit(kv_txn txn);
kv_result kv_txn_abort(kv_txn txn);
kv_result kv_txn_close(kv_txn txn);

kv_result kv_txn_get(kv_txn txn, kv_buf key, kv_buf* val);
kv_result kv_txn_put(kv_txn txn, kv_buf key, kv_buf val);
kv_result kv_txn_del(kv_txn txn, kv_buf key);
void kv_txn_iter(kv_txn txn, kv_buf prefix, kv_iter_cb cb);

char* kv_result_str(kv_result res);

#endif  // KV_H_
