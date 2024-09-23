#ifndef BASE_STR_H_
#define BASE_STR_H_

#include <stdbool.h>
#include <string.h>
#include "base/list.h"
#include "base/khash.h"

typedef struct {
  size_t len;
  uint8_t* bytes;
} str_t;


#define str_init(s, l) ((str_t){.bytes = s, .len = l})
#define cstr(x) ((str_t){.bytes = (uint8_t*)x, .len = strlen(x)})

void *malloc( size_t size );
static inline str_t str_copy(str_t s) {
  str_t out;
  out.bytes = malloc(s.len);
  out.len = s.len;
  memcpy((void*)out.bytes, s.bytes, s.len);
  return out;
}

#define str_from_list(lst) (*(str_t*)(&lst))

static inline str_t str_add(list_t* l, str_t s) {
  uint8_t* ptr = list_addn(uint8_t, l, s.len);
  memcpy(ptr, s.bytes, s.len);
  return str_init(ptr, s.len);
}

static inline uint32_t str_hash(str_t str) {
  uint32_t h = 0;
  for (size_t i = 0; i < str.len; ++i) {
    h = (h << 5) - h + (uint32_t)str.bytes[i];
  }
  return h;
}

static inline bool str_eq(str_t a, str_t b) {
  if (a.len != b.len) return false;
  for (size_t i = 0; i < a.len; ++i) {
    if (a.bytes[i] != b.bytes[i]) return false;
  }
  return true;
}

#define KHASH_MAP_INIT_STRT(name, khval_t) \
  KHASH_INIT(name, str_t, khval_t, 1, str_hash, str_eq)

KHASH_MAP_INIT_STRT(mStrToStr, str_t);
typedef khash_t(mStrToStr) str_map_t;


#endif
