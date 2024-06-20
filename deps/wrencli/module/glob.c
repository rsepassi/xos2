#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

#include "wren.h"
#include "glob.h"
#include "util.h"

static int globErrCode = -1;

static int globErrFn(const char* msg, int code)
{
  globErrCode = code;
  return 0;
}

void wrenGlob(WrenVM* vm)
{
  const char* pattern = wrenGetSlotString(vm, 1);
  int flags = 0;
  glob_t glob = {0};
  int res = g_glob(pattern, flags, globErrFn, &glob);
  int nmatch;
  if (res == 0) {
    nmatch = glob.gl_matchc;
  } else if (res == GLOB_NOMATCH) {
    nmatch = 0;
  } else {
    nmatch = -1;
  }

  if (nmatch < 0) {
    abortFiber(vm, "error: glob failed, %s", strerror(globErrCode));
  } else {
    wrenEnsureSlots(vm, 2);
    wrenSetSlotNewList(vm, 0);
    for (int i = 0; i < nmatch; ++i) {
      const char* path = glob.gl_pathv[i];
      wrenSetSlotString(vm, 1, path);
      wrenInsertInList(vm, 0, -1, 1);
    }
  }

  g_globfree(&glob);
}
