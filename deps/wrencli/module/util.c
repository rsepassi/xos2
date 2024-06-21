#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include "wren.h"

char* createStr(char* fmt, ...) {
  ssize_t bufsz;
  {
    va_list args;
    va_start(args, fmt);
    bufsz = vsnprintf(NULL, 0, fmt, args);
    va_end(args);
  }

  char* errstr = (char*)malloc(bufsz + 1);

  {
    va_list args;
    va_start(args, fmt);
    vsnprintf(errstr, bufsz + 1, fmt, args);
    va_end(args);
  }

  return errstr;
}


void abortFiber(WrenVM* vm, char* fmt, ...) {
  va_list args;
  va_start(args, fmt);
  char* errstr = createStr(fmt, args);
  va_end(args);

  wrenEnsureSlots(vm, 1);
  wrenSetSlotString(vm, 0, errstr);
  wrenAbortFiber(vm, 0);

  free(errstr);
}
