#include <stdlib.h>

#include "base/list.h"

static inline void Realloc(list_t* ctx, size_t newsz) {
  ctx->base = allocator_realloc(&ctx->alloc, ctx->base, ctx->cap * ctx->elsz, newsz);
}

list_t list_init2(size_t elsz, int cap) {
  cap = cap < 0 ? 64 : cap;
  allocator_t alloc = allocator_default();
  void* base = cap == 0 ? 0 : allocator_realloc(&alloc, NULL, 0, cap * elsz);
  return (list_t){
    .base = base,
    .cap = cap,
    .len = 0,
    .elsz = elsz,
    .alloc = alloc,
  };
}

void list_deinit(list_t* ctx) {
  if (ctx->cap > 0) Realloc(ctx, 0);
}

uint8_t* list_get2(list_t* ctx, int i) {
  if (i < 0) i = ctx->len + i;
  return &ctx->base[ctx->elsz * i];
}

uint8_t* list_add2(list_t* ctx) { return list_addn2(ctx, 1); }

void list_reserve(list_t* ctx, size_t n) {
  if (n <= ctx->cap) return;
  ctx->cap = n;
  Realloc(ctx, ctx->cap * ctx->elsz);
}

void list_clear(list_t* ctx) {
  ctx->len = 0;
}

uint8_t* list_addn2(list_t* ctx, size_t n) {
  if ((ctx->len + n) > ctx->cap) list_reserve(ctx, (ctx->len + n) * 2);
  uint8_t* cur = &ctx->base[ctx->elsz * ctx->len];
  ctx->len += n;
  return cur;
}

list_handle_t list_get_handle(list_t* ctx, void* el) {
  if (el == NULL) return 0;
  uint64_t delta = (uint8_t*)el - ctx->base;
  return (delta / ctx->elsz) + 1;
}

size_t list_idx(list_t* ctx, void* el) {
  return list_get_handle(ctx, el) - 1;
}

uint8_t* list_get_from_handle2(list_t* ctx, list_handle_t handle) {
  if (handle == 0) return NULL;
  handle -= 1;
  return &ctx->base[ctx->elsz * handle];
}
