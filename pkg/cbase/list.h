#ifndef BASE_LIST_H_
#define BASE_LIST_H_

#include <stdint.h>
#include <stddef.h>

typedef struct {
  uint8_t* base;
  size_t cap;
  size_t len;
  size_t elsz;
} list_t;

typedef uint32_t list_handle_t;

#define list_init(T, cap) list_init2(sizeof(T), cap)
void list_deinit(list_t* ctx);
#define list_get(T, ctx, i) ((T*)(list_get2(ctx, i)))
#define list_add(T, ctx) ((T*)(list_add2(ctx)))
#define list_addn(T, ctx, n) ((T*)(list_addn2(ctx, n)))
list_handle_t list_get_handle(list_t* ctx, void* el);
#define list_get_from_handle(T, ctx, h) ((T*)(list_get_from_handle2(ctx, h)))

list_t list_init2(size_t elsz, int cap);
uint8_t* list_get2(list_t* ctx, int i);
uint8_t* list_get_from_handle2(list_t* ctx, list_handle_t handle);
uint8_t* list_add2(list_t* ctx);
uint8_t* list_addn2(list_t* ctx, size_t n);

#endif
