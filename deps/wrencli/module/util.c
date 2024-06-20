#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include "wren.h"

void abortFiber(WrenVM* vm, char* fmt, ...) {

  va_list args;
  va_start(args, fmt);
  ssize_t bufsz = vsnprintf(NULL, 0, fmt, args);
  va_end(args);

  char* errstr = (char*)malloc(bufsz + 1);

  va_list args2;
  va_start(args2, fmt);
  vsnprintf(errstr, bufsz + 1, fmt, args2);
  va_end(args2);

  wrenEnsureSlots(vm, 1);
  wrenSetSlotString(vm, 0, errstr);
  wrenAbortFiber(vm, 0);

  free(errstr);
}
