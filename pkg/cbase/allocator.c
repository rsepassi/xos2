#include "base/allocator.h"

extern void *realloc( void *ptr, size_t new_size );

static void* default_allocate(
    void *user_ctx, void *ptr, size_t old_size, size_t new_size) {
  return realloc(ptr, new_size);
}

allocator_t allocator_default(void) {
  return (allocator_t){
    .realloc = default_allocate,
    .ctx = NULL,
  };
}

static void* bump_allocate(
    void *user_ctx, void *ptr, size_t old_size, size_t new_size) {
  allocator_bump_t* ctx = (allocator_bump_t*)user_ctx;

  // Free
  if (new_size == 0) return NULL;

  // Resize
  if (ptr != NULL) return NULL;

  // New alloc
  if ((ctx->end + new_size) > ctx->len) return NULL;

  char* out = &ctx->buf[ctx->end];
  ctx->end += new_size;
  return out;
}

allocator_t allocator_bump(allocator_bump_t* a) {
  a->end = 0;
  return (allocator_t){
    .realloc = bump_allocate,
    .ctx = a,
  };
}

void allocator_bump_reset(allocator_bump_t* a) {
  a->end = 0;
}

void* allocator_allocate(allocator_t* a, size_t new_size) {
  return a->realloc(a->ctx, NULL, 0, new_size);
}
