#include "os.h"
#include "uv.h"
#include "wren.h"
#include "vm.h"
#include "scheduler.h"
#include "util.h"

#if __APPLE__
  #include "TargetConditionals.h"
#endif

int numArgs;
const char** args;

void osSetArguments(int argc, const char* argv[])
{
  numArgs = argc;
  args = argv;
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

  for (int i = 0; i < numArgs; i++)
  {
    wrenSetSlotString(vm, 1, args[i]);
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

typedef struct {
  uv_process_t handle;
  WrenHandle* fiber;
} ProcessState;

void processExitCb(uv_process_t* handle, int64_t exit_status, int term_signal) {
  ProcessState* state = handle->data;
  WrenHandle* fiber = state->fiber;
  free(state);
  if (exit_status == 0) {
    schedulerResume(fiber, false);
  } else {
    schedulerResumeError(fiber, "process failed");
  }
}

void processSpawn(WrenVM* vm) {
  int argc = wrenGetListCount(vm, 1);
  bool has_env = wrenGetSlotType(vm, 2) == WREN_TYPE_LIST;
  int envc = has_env ? wrenGetListCount(vm, 2) : 0;
  int stdin_fd = (int)wrenGetSlotDouble(vm, 3);
  int stdout_fd = (int)wrenGetSlotDouble(vm, 4);
  int stderr_fd = (int)wrenGetSlotDouble(vm, 5);
  WrenHandle* fiber = wrenGetSlotHandle(vm, 6);
  int nslots = 7;

  const char** args = (const char**)malloc((argc + 1) * sizeof(char*));
  const char** env = has_env ? (const char**)malloc((envc + 1) * sizeof(char*)) : NULL;

  wrenEnsureSlots(vm, nslots);
  int scratch_slot = nslots - 1;

  for (int i = 0; i < argc; ++i) {
    wrenGetListElement(vm, 1, i, scratch_slot);
    args[i] = wrenGetSlotString(vm, scratch_slot);
  }
  args[argc] = 0;

  if (has_env) {
    for (int i = 0; i < envc; ++i) {
      wrenGetListElement(vm, 2, i, scratch_slot);
      env[i] = wrenGetSlotString(vm, scratch_slot);
    }
    env[envc] = 0;
  }

  uv_process_options_t options = {0};
  options.exit_cb = processExitCb;
  options.file = args[0];
  options.args = (char**)args;
  options.env = (char**)env;
  uv_stdio_container_t stdio[3];
  if (stdin_fd >= 0) {
    stdio[0].flags = UV_INHERIT_FD;
    stdio[0].data.fd = stdin_fd;
  } else {
    stdio[0].flags = UV_IGNORE;
  }
  if (stdout_fd >= 0) {
    stdio[1].flags = UV_INHERIT_FD;
    stdio[1].data.fd = stdout_fd;
  } else {
    stdio[1].flags = UV_IGNORE;
  }
  if (stderr_fd >= 0) {
    stdio[2].flags = UV_INHERIT_FD;
    stdio[2].data.fd = stderr_fd;
  } else {
    stdio[2].flags = UV_IGNORE;
  }
  options.stdio = stdio;
  options.stdio_count = 3;

  ProcessState* state = (ProcessState*)malloc(sizeof(ProcessState));
  state->fiber = fiber;
  state->handle.data = state;

  int rc = uv_spawn(getLoop(), &state->handle, &options);

  free(args);
  if (has_env) free(env);

  if (rc != 0) {
    free(state);
    abortFiber(vm, "error: process spawn failed: %s", uv_strerror(rc));
    return;
  }
}
