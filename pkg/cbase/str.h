#ifndef BASE_STR_H_
#define BASE_STR_H_

#include <string.h>
#include "base/list.h"

typedef struct {
  size_t len;
  const char* bytes;
} str_t;


#define str_init(s, l) ((str_t){.bytes = s, .len = l})
#define cstr(x) ((str_t){.bytes = x, .len = strlen(x)})

static inline str_t str_from_list(list_t l) {
  return (str_t){.bytes = (char*)l.base, .len = l.len};
}

static inline str_t str_append(list_t* l, str_t s) {
  uint8_t* ptr = list_addn(uint8_t, l, s.len);
  memcpy(ptr, s.bytes, s.len);
  return str_init((char*)ptr, s.len);
}

#endif
