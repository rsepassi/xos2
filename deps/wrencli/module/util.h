#ifndef util_h
#define util_h

#include "wren.h"

char* createStr(char* fmt, ...);
void abortFiber(WrenVM* vm, char* fmt, ...);

#endif
