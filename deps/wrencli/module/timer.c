#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#include "uv.h"

#include "scheduler.h"
#include "vm.h"
#include "wren.h"

// Called by libuv when the timer finished closing.
static void timerCloseCallback(uv_handle_t* handle)
{
  free(handle);
}

// Called by libuv when the timer has completed.
static void timerCallback(uv_timer_t* handle)
{
  WrenHandle* fiber = (WrenHandle*)handle->data;

  // Tell libuv that we don't need the timer anymore.
  uv_close((uv_handle_t*)handle, timerCloseCallback);

  // Run the fiber that was sleeping.
  schedulerResume(fiber, false);
}

void timerStartTimer(WrenVM* vm)
{
  int milliseconds = (int)wrenGetSlotDouble(vm, 1);
  WrenHandle* fiber = wrenGetSlotHandle(vm, 2);

  // Store the fiber to resume when the timer completes.
  uv_timer_t* handle = (uv_timer_t*)malloc(sizeof(uv_timer_t));
  handle->data = fiber;

  uv_timer_init(getLoop(), handle);
  uv_timer_start(handle, timerCallback, milliseconds, 0);
}

typedef struct {
  double start;
} stopwatch;

static double getTimeMs() {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  double ms = tv.tv_sec * 1000 + tv.tv_usec / 1000;
  return ms;
}

void stopwatchAllocate(WrenVM* vm)
{
  double ms = getTimeMs();
  wrenEnsureSlots(vm, 1);
  stopwatch* sw = (stopwatch*)wrenSetSlotNewForeign(vm, 0, 0, sizeof(stopwatch));
  sw->start = ms;
}

void stopwatchLap(WrenVM* vm)
{
  double ms = getTimeMs();
  stopwatch* sw = (stopwatch*)wrenGetSlotForeign(vm, 0);
  sw->start = ms;
}

void stopwatchRead(WrenVM* vm)
{
  double ms = getTimeMs();
  stopwatch* sw = (stopwatch*)wrenGetSlotForeign(vm, 0);
  double duration = ms - sw->start;
  wrenSetSlotDouble(vm, 0, duration);
}
