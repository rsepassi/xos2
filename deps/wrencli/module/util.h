#ifndef util_h
#define util_h

#include "wren.h"

char* strfmt(char* fmt, ...);
void abortFiber(WrenVM* vm, char* fmt, ...);

#endif
