#include <stdlib.h>

#include "base/list.h"

list_t list_init2(size_t elsz, int cap) {
  cap = cap < 0 ? 64 : cap;
  void* base = realloc(NULL, cap * elsz);
  return (list_t){
    .base = base,
    .cap = cap,
    .len = 0,
    .elsz = elsz,
  };
}

void list_deinit(list_t* ctx) {
  realloc(ctx->base, 0);
}

uint8_t* list_get2(list_t* ctx, int i) {
  if (i < 0) i = ctx->len + i;
  return &ctx->base[ctx->elsz * i];
}

uint8_t* list_add2(list_t* ctx) { return list_addn2(ctx, 1); }

uint8_t* list_addn2(list_t* ctx, size_t n) {
  if ((ctx->len + n) > ctx->cap) {
    ctx->cap = (ctx->len + n) * 2;
    ctx->base = realloc(ctx->base, ctx->cap * ctx->elsz);
  }

  uint8_t* cur = &ctx->base[ctx->elsz * ctx->len];
  ctx->len += n;
  return cur;
}

list_handle_t list_get_handle(list_t* ctx, void* el) {
  uint64_t delta = (uint8_t*)el - ctx->base;
  return (delta / ctx->elsz) + 1;
}

uint8_t* list_get_from_handle2(list_t* ctx, list_handle_t handle) {
  if (handle == 0) return NULL;
  handle -= 1;
  return &ctx->base[ctx->elsz * handle];
}
