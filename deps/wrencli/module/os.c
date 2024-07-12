#include <string.h>

#include "os.h"
#include "uv.h"
#include "wren.h"
#include "vm.h"
#include "scheduler.h"
#include "util.h"

#if __APPLE__
  #include "TargetConditionals.h"
#endif

static int osNumArgs;
static const char** osArgs;

void osSetArguments(int argc, const char* argv[])
{
  osNumArgs = argc;
  osArgs = argv;
}

void platformHomePath(WrenVM* vm)
{
  wrenEnsureSlots(vm, 1);

  char _buffer[WREN_PATH_MAX];
  char* buffer = _buffer;
  size_t length = sizeof(_buffer);
  int result = uv_os_homedir(buffer, &length);

  if (result == UV_ENOBUFS)
  {
    buffer = (char*)malloc(length);
    result = uv_os_homedir(buffer, &length);
  }

  if (result != 0)
  {
    wrenSetSlotString(vm, 0, "Cannot get the current user's home directory.");
    wrenAbortFiber(vm, 0);
    return;
  }

  wrenSetSlotString(vm, 0, buffer);

  if (buffer != _buffer) free(buffer);
}

void platformName(WrenVM* vm)
{
  wrenEnsureSlots(vm, 1);
  
  #ifdef _WIN32
    wrenSetSlotString(vm, 0, "Windows");
  #elif __APPLE__
    #if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
      wrenSetSlotString(vm, 0, "iOS");
    #elif TARGET_OS_MAC
      wrenSetSlotString(vm, 0, "OS X");
    #else
      wrenSetSlotString(vm, 0, "Unknown");
    #endif
  #elif __linux__
    wrenSetSlotString(vm, 0, "Linux");
  #elif __unix__
    wrenSetSlotString(vm, 0, "Unix");
  #elif defined(_POSIX_VERSION)
    wrenSetSlotString(vm, 0, "POSIX");
  #else
    wrenSetSlotString(vm, 0, "Unknown");
  #endif
}

void platformIsPosix(WrenVM* vm)
{
  wrenEnsureSlots(vm, 1);
  
  #ifdef _WIN32
    wrenSetSlotBool(vm, 0, false);
  #elif __APPLE__
    wrenSetSlotBool(vm, 0, true);
  #elif __linux__
    wrenSetSlotBool(vm, 0, true);
  #elif __unix__
    wrenSetSlotBool(vm, 0, true);
  #elif defined(_POSIX_VERSION)
    wrenSetSlotBool(vm, 0, true);
  #else
    wrenSetSlotString(vm, 0, false);
  #endif
}

void processAllArguments(WrenVM* vm)
{
  wrenEnsureSlots(vm, 2);
  wrenSetSlotNewList(vm, 0);

  for (int i = 0; i < osNumArgs; i++)
  {
    wrenSetSlotString(vm, 1, osArgs[i]);
    wrenInsertInList(vm, 0, -1, 1);
  }
}

void processCwd(WrenVM* vm)
{
  wrenEnsureSlots(vm, 1);

  char buffer[WREN_PATH_MAX * 4];
  size_t length = sizeof(buffer);
  if (uv_cwd(buffer, &length) != 0)
  {
    wrenSetSlotString(vm, 0, "Cannot get current working directory.");
    wrenAbortFiber(vm, 0);
    return;
  }

  wrenSetSlotString(vm, 0, buffer);
}

void processPid(WrenVM* vm) {
  wrenEnsureSlots(vm, 1);
  wrenSetSlotDouble(vm, 0, uv_os_getpid());
}

void processPpid(WrenVM* vm) {
  wrenEnsureSlots(vm, 1);
  wrenSetSlotDouble(vm, 0, uv_os_getppid());
}

void processVersion(WrenVM* vm) {
  wrenEnsureSlots(vm, 1);
  wrenSetSlotString(vm, 0, WREN_VERSION_STRING);
}

void processExit(WrenVM* vm) {
  int code = (int)wrenGetSlotDouble(vm, 1);
  exit(code);
}

void processEnvName(WrenVM* vm) {
  const char* name = wrenGetSlotString(vm, 1);
  char* val = getenv(name);
  wrenEnsureSlots(vm, 1);
  if (val) { wrenSetSlotString(vm, 0, val); } else wrenSetSlotNull(vm, 0);
}

extern char **environ;

void processEnv(WrenVM* vm) {
  wrenEnsureSlots(vm, 3);
  wrenSetSlotNewMap(vm, 0);
  char **s = environ;
  char* p = (char*)malloc(strlen(*s));
  for (; *s; s++) {
    int len = strlen(*s);
    p = (char*)realloc(p, len);
    int keylen = 0;
    while ((*s)[keylen] && (*s)[keylen] != '=') ++keylen;
    p = (char*)realloc(p, keylen + 1);
    memcpy(p, *s, keylen);
    p[keylen] = 0;
    wrenSetSlotString(vm, 1, p);
    wrenSetSlotString(vm, 2, &(*s)[keylen + 1]);
    wrenSetMapValue(vm, 0, 1, 2);
  }
  free(p);
}

void processChdir(WrenVM* vm) {
  const char* path = wrenGetSlotString(vm, 1);
  if (uv_chdir(path) != 0) {
    wrenSetSlotString(vm, 0, "Could not change current working directory.");
    wrenAbortFiber(vm, 0);
    return;
  }
  wrenEnsureSlots(vm, 1);
  wrenSetSlotNull(vm, 0);
}

