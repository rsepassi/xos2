#ifndef BASE_LIST_H_
#define BASE_LIST_H_

#include <stdint.h>

typedef struct {
  uint8_t* base;
  size_t cap;
  size_t len;
  size_t elsz;
} list_t;

#define list_init(T, cap) list_init2(sizeof(T), cap)
void list_deinit(list_t* ctx);
#define list_get(T, ctx, i) (*T)(list_get2(ctx, i))
#define list_add(T, ctx) (*T)(list_add2(ctx))

list_t list_init2(size_t elsz, int cap);
uint8_t* list_get2(list_t* ctx, int i);
uint8_t* list_add2(list_t* ctx);

#endif
