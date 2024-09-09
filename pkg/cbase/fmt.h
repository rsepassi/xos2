#ifndef BASE_FMT_H_
#define BASE_FMT_H_

#include <stdarg.h>

#include "base/str.h"
#include "base/allocator.h"

str_t strfmt(allocator_t*, char* fmt, ...);
str_t vstrfmt(allocator_t*, char* fmt, va_list args);

#endif
