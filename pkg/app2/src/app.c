#include <stdarg.h>

#include "app.h"
#include "app_internal.h"

#include "base/fmt.h"

#include "text.h"

str_t app_frame_strfmt(app_state_t* app, char* fmt, ...) {
  va_list args;
  va_start(args, fmt);
  str_t s = vstrfmt(&app->frame_allocator, fmt, args);
  va_end(args);
  return s;
}

void app_quit(app_state_t* state) {
  ((app_platform_t*)(state->platform))->quit_requested = true;
}

void app__resize_fb(app_platform_t* app, int width, int height) {
  if (app->fb.w == width && app->fb.h == height) return;
  app->fb.buf = realloc(app->fb.buf, width * height * sizeof(uint32_t));
  app->fb.w = width;
  app->fb.h = height;
  app->state.size.w = width;
  app->state.size.h = height;
  nativefb_resize(&app->platform, &app->fb);
}

void app__render(app_platform_t* app) {
  allocator_bump_reset(&app->bump);
  app->init.render(app->init.userdata);
  app->state.last_render_ms = app__gettimems(app);
  nativefb_trigger_refresh(&app->platform, &app->fb);
}

u64 app_gettimems(app_state_t* state) {
  return app__gettimems(state->platform);
}

void app_mark_needs_render(app_state_t* state) {
  ((app_platform_t*)(state->platform))->needs_render = true;
}

static const char* event_strs[AppEvent__SENTINEL] = {
  "INVALID",
  "GfxInit",
  "Exit",
  "Char",
  "Key",
  "MouseMotion",
  "MouseClick",
  "MouseEnter",
  "MouseLeave",
  "Scroll",
  "DropPaths",
  "WindowClose",
  "WindowFocus",
  "WindowFocusLost",
  "WindowSize",
  "FrameSize",
  "FrameContentScale",
  "Suspend",
  "Resume",
};

const char* app_event_type_str(app_event_type_t t) {
  return event_strs[t];
}

