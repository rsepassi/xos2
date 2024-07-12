#include <string.h>

#include "uv.h"
#include "wren.h"
#include "vm.h"
#include "scheduler.h"
#include "util.h"

typedef struct {
  uv_process_t handle;
  bool has_stdinp;
  uv_pipe_t stdinp;
  bool has_stdoutp;
  uv_pipe_t stdoutp;
  bool has_stderrp;
  uv_pipe_t stderrp;
  bool has_stdin_write;
  uv_write_t stdin_write;
  char* stdin_buf;
  char stdout_buf[65536];
  char stderr_buf[65536];
  WrenVM* vm;
  WrenHandle* wren_call1;
  WrenHandle* stdin_write_fiber;
  WrenHandle* stdout_cb;
  WrenHandle* stderr_cb;
  WrenHandle* fiber;
  int done_count;
  int64_t exit_status;
  bool pipe_err;
  bool wait_called;
} SubprocessState;

static void subprocessFree(SubprocessState* state) {
  if (state->has_stdinp) uv_close((uv_handle_t*)&state->stdinp, NULL);
  if (state->has_stdoutp) uv_close((uv_handle_t*)&state->stdoutp, NULL);
  if (state->has_stderrp) uv_close((uv_handle_t*)&state->stderrp, NULL);
  uv_close((uv_handle_t*)&state->handle, NULL);

  if (state->stdin_buf) free(state->stdin_buf);

  if (state->stdout_cb || state->stderr_cb) wrenReleaseHandle(state->vm, state->wren_call1);
  if (state->stdout_cb) wrenReleaseHandle(state->vm, state->stdout_cb);
  if (state->stderr_cb) wrenReleaseHandle(state->vm, state->stderr_cb);
}

static bool subprocessIsDone2(SubprocessState* state) {
  int expected_done_count = 1;
  if (state->has_stdoutp) ++expected_done_count; 
  if (state->has_stderrp) ++expected_done_count; 
  return state->done_count == expected_done_count;
}

bool subprocessIsDone(WrenVM* vm) {
  SubprocessState* state = wrenGetSlotForeign(vm, 0);
  wrenSetSlotBool(vm, 0, subprocessIsDone2(state));
}

static void subprocessWaitResume(SubprocessState* state) {
  if (state->pipe_err) {
    char* errstr = strfmt("reading from stdout/stderr failed for process %d", state->handle.pid);
    schedulerResumeError(state->fiber, errstr);
    free(errstr);
  } else {
    schedulerResume(state->fiber, true);
    wrenSetSlotDouble(state->vm, 2, state->exit_status);
    schedulerFinishResume();
  }
}

static void subprocessDone(SubprocessState* state) {
  if (!state->wait_called) return;
  subprocessWaitResume(state);
}

static void subprocessExitCb(uv_process_t* handle, int64_t exit_status, int term_signal) {
  SubprocessState* state = handle->data;
  state->exit_status = exit_status;
  ++state->done_count;
  if (subprocessIsDone2(state)) subprocessDone(state);
}

static void subprocessStdioAlloc(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf, int idx) {
  SubprocessState* state = handle->data;
  buf->base = idx == 0 ? state->stdout_buf : state->stderr_buf;
  buf->len = 65536;
}

static void subprocessStdoutAlloc(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf) {
  subprocessStdioAlloc(handle, suggested_size, buf, 0);
}

static void subprocessStderrAlloc(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf) {
  subprocessStdioAlloc(handle, suggested_size, buf, 1);
}

static void subprocessStdioRead(uv_stream_t *stream, ssize_t nread, const uv_buf_t *buf, int idx) {
  SubprocessState* state = stream->data;
  if (nread == UV_EOF) {
    ++state->done_count;
    if (subprocessIsDone2(state)) subprocessWaitResume(state);
  } else if (nread < 0) {
    state->pipe_err = true;
    ++state->done_count;
    if (subprocessIsDone2(state)) subprocessWaitResume(state);
  } else {
    wrenEnsureSlots(state->vm, 2);
    wrenSetSlotHandle(state->vm, 0, idx == 0 ? state->stdout_cb : state->stderr_cb);
    wrenSetSlotBytes(state->vm, 1, buf->base, nread);
    wrenCall(state->vm, state->wren_call1);
  }
}

static void subprocessStdoutRead(uv_stream_t *stream, ssize_t nread, const uv_buf_t *buf) {
  subprocessStdioRead(stream, nread, buf, 0);
}

static void subprocessStderrRead(uv_stream_t *stream, ssize_t nread, const uv_buf_t *buf) {
  subprocessStdioRead(stream, nread, buf, 1);
}

void subprocessAllocate(WrenVM* vm) {
  SubprocessState* state = wrenSetSlotNewForeign(vm, 0, 0, sizeof(SubprocessState));
  memset(state, 0, sizeof(SubprocessState));
  state->vm = vm;

  int argc = wrenGetListCount(vm, 1);
  bool has_env = wrenGetSlotType(vm, 2) == WREN_TYPE_LIST;
  int stdin_fd = (int)wrenGetSlotDouble(vm, 3);
  int stdout_fd = (int)wrenGetSlotDouble(vm, 4);
  int stderr_fd = (int)wrenGetSlotDouble(vm, 5);
  bool has_stdout_fn = wrenGetSlotType(vm, 6) != WREN_TYPE_NULL;
  bool has_stderr_fn = wrenGetSlotType(vm, 7) != WREN_TYPE_NULL;
  int scratch_slot = 3;

  int envc = has_env ? wrenGetListCount(vm, 2) : 0;
  const char** args = malloc((argc + 1) * sizeof(char*));
  const char** env = has_env ? (const char**)malloc((envc + 1) * sizeof(char*)) : NULL;

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

  // Setup stdio
  uv_stdio_container_t stdio[3];

  if (stdin_fd >= 0) {
    stdio[0].flags = UV_INHERIT_FD;
    stdio[0].data.fd = stdin_fd;
  } else {
    stdio[0].flags = UV_CREATE_PIPE | UV_READABLE_PIPE;
    stdio[0].data.stream = (uv_stream_t*)&state->stdinp;
    uv_pipe_init(getLoop(), &state->stdinp, 0);
    state->has_stdinp = true;
    state->stdinp.data = state;
  }

  if (has_stdout_fn) {
    stdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
    stdio[1].data.stream = (uv_stream_t*)&state->stdoutp;
    uv_pipe_init(getLoop(), &state->stdoutp, 0);
    state->has_stdoutp = true;
    state->stdoutp.data = state;
    state->stdout_cb = wrenGetSlotHandle(vm, 6);
  } else if (stdout_fd >= 0) {
    stdio[1].flags = UV_INHERIT_FD;
    stdio[1].data.fd = stdout_fd;
  } else {
    stdio[1].flags = UV_IGNORE;
  }

  if (has_stderr_fn) {
    stdio[2].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
    stdio[2].data.stream = (uv_stream_t*)&state->stderrp;
    uv_pipe_init(getLoop(), &state->stderrp, 0);
    state->has_stderrp = true;
    state->stderrp.data = state;
    state->stderr_cb = wrenGetSlotHandle(vm, 7);
  } else if (stderr_fd >= 0) {
    stdio[2].flags = UV_INHERIT_FD;
    stdio[2].data.fd = stderr_fd;
  } else {
    stdio[2].flags = UV_IGNORE;
  }

  if (has_stdout_fn || has_stderr_fn) {
    state->wren_call1 = wrenMakeCallHandle(vm, "call(_)");
  }

  uv_process_options_t options = {0};
  options.exit_cb = subprocessExitCb;
  options.file = args[0];
  options.args = (char**)args;
  options.env = (char**)env;
  options.stdio = stdio;
  options.stdio_count = 3;
  state->handle.data = state;
  int rc = uv_spawn(getLoop(), &state->handle, &options);
  if (rc != 0) {
    abortFiber(vm, "process spawn failed: code=%d %s, arg0=%s", rc, uv_strerror(rc), args[0]);
    goto error;
  }

  if (has_stdout_fn) uv_read_start(&state->stdoutp, subprocessStdoutAlloc, subprocessStdoutRead);
  if (has_stderr_fn) uv_read_start(&state->stderrp, subprocessStderrAlloc, subprocessStderrRead);
  
  goto done;

error:
  subprocessFree(state);
done:
  if (has_env) free(env);
  free(args);
}

void subprocessFinalize(void* data) {
  subprocessFree((SubprocessState*)data);
}

void subprocessKill(WrenVM* vm) {
  SubprocessState* state = wrenGetSlotForeign(vm, 0);
  uv_process_kill(&state->handle, (int)wrenGetSlotDouble(vm, 1));
}

void subprocessPid(WrenVM* vm) {
  SubprocessState* state = wrenGetSlotForeign(vm, 0);
  wrenSetSlotDouble(vm, 0, state->handle.pid);
}

void subprocessWait(WrenVM* vm) {
  SubprocessState* state = wrenGetSlotForeign(vm, 0);
  state->fiber = wrenGetSlotHandle(vm, 1);
  state->wait_called = true;
  if (subprocessIsDone2(state)) subprocessWaitResume(state);
}

static void subprocessWriteCb(uv_write_t* handle, int status) {
  SubprocessState* state = handle->data;
  state->has_stdin_write = false;
  if (status == 0) {
    schedulerResume(state->stdin_write_fiber, false);
  } else {
    char* errstr = strfmt("stdin write failed for process %d", state->handle.pid);
    schedulerResumeError(state->stdin_write_fiber, errstr);
    free(errstr);
  }
}

void subprocessWrite(WrenVM* vm) {
  SubprocessState* state = wrenGetSlotForeign(vm, 0);
  if (!state->has_stdinp) {
    abortFiber(vm, "subprocess %d does not support writing to stdin", state->handle.pid);
    return;
  }
  if (state->has_stdin_write) {
    abortFiber(vm, "subprocess %d already has an active stdin write request", state->handle.pid);
    return;
  }

  state->has_stdin_write = true;

  int len;
  char* wren_str = wrenGetSlotBytes(vm, 1, &len);

  state->stdin_write_fiber = wrenGetSlotHandle(vm, 2);

  state->stdin_buf = realloc(state->stdin_buf, len);
  memcpy(state->stdin_buf, wren_str, len);

  uv_buf_t buf;
  buf.base = state->stdin_buf;
  buf.len = len;

  state->stdin_write.data = state;

  uv_write(&state->stdin_write, (uv_stream_t*)&state->stdinp, &buf, 1, subprocessWriteCb);
}
