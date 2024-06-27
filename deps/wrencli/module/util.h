#ifndef util_h
#define util_h

#include "wren.h"

char* strfmt(const char* fmt, ...);
void abortFiber(WrenVM* vm, char* fmt, ...);

#endif
