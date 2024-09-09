#include <stdio.h>
#include "base/fmt.h"

str_t vstrfmt(allocator_t* alloc, char* fmt, va_list args) {
  int len = vsnprintf(NULL, 0, fmt, args);
  char* buf = allocator_allocate(alloc, len);
  vsnprintf(buf, len + 1, fmt, args);
  return (str_t){.bytes = buf, .len = len};
}

str_t strfmt(allocator_t* alloc, char* fmt, ...) {
  va_list args;
  va_start(args, fmt);
  str_t out = vstrfmt(alloc, fmt, args);
  va_end(args);
  return out;
}
