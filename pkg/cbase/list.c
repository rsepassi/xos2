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

uint8_t* list_add2(list_t* ctx) {
  if (ctx->len == ctx->cap) {
    ctx->cap *= 2;
    ctx->base = realloc(ctx->base, ctx->cap * ctx->elsz);
  }

  uint8_t* cur = &ctx->base[ctx->elsz * ctx->len];
  ++ctx->len;
  return cur;
}
