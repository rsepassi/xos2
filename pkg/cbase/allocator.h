#ifndef BASE_ALLOCATOR_H_
#define BASE_ALLOCATOR_H_

#include <stddef.h>

typedef void* (*allocator_allocate_fn)(
    void *user_ctx, void *ptr, size_t old_size, size_t new_size);

typedef struct {
  allocator_allocate_fn realloc;
  void* ctx;
} allocator_t;

allocator_t allocator_default(void);

inline void* allocator_allocate(allocator_t* a, size_t new_size);

static inline void* allocator_realloc(allocator_t* a, void* ptr, size_t old_size, size_t new_size) {
  return a->realloc(a->ctx, ptr, old_size, new_size);
}

typedef struct {
  char* buf;
  int len;
  int end;
} allocator_bump_t;
allocator_t allocator_bump(allocator_bump_t*);
void allocator_bump_reset(allocator_bump_t*);

#endif
