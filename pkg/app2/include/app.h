#ifndef APP_H_
#define APP_H_

#include "base/stdtypes.h"
#include "base/allocator.h"
#include "base/str.h"

#include "app_keycodes.h"

#include "nativefb.h"

// Platform defs
// APP_PLATFORM_OS_MACOS
// APP_PLATFORM_OS_LINUX
// APP_PLATFORM_OS_WINDOWS
// APP_PLATFORM_OS_DESKTOP
// APP_PLATFORM_OS_IOS
// APP_PLATFORM_OS_ANDROID
// APP_PLATFORM_OS_MOBILE

// TODO:
// * Clipboard
// * On-screen keyboard

typedef enum {                 // app_event_t.data payload
  AppEvent__INVALID,
  AppEventGfxInit,             // none
  AppEventExit,                // none
  AppEventChar,                // xchar
  AppEventKey,                 // key
  AppEventMouseMotion,         // pos
  AppEventMouseClick,          // mouse
  AppEventMouseEnter,          // none
  AppEventMouseLeave,          // none
  AppEventScroll,              // scroll
  AppEventDropPaths,           // paths
  AppEventWindowClose,         // none
  AppEventWindowFocus,         // none
  AppEventWindowFocusLost,     // none
  AppEventWindowSize,          // size
  AppEventFrameSize,           // size
  AppEventFrameContentScale,   // scale
  AppEventSuspend,             // none
  AppEventResume,              // none
  AppEvent__SENTINEL,
} app_event_type_t;

typedef struct {
  i16 x, y;
} app_pos2d_t;

typedef struct {
  u16 h, w;
} app_size2d_t;

typedef struct {
  f32 x, y;
} app_event_scroll_t;

typedef struct {
  f32 x, y;
} app_event_scale_t;

typedef struct {
  const char** paths;
  u32 npaths;
} app_event_paths_t;

#define APP_MOD_SHIFT     1 << 0
#define APP_MOD_CTRL      1 << 1
#define APP_MOD_ALT       1 << 2
#define APP_MOD_SUPER     1 << 3
#define APP_MOD_CAPS_LOCK 1 << 4
#define APP_MOD_NUM_LOCK  1 << 5
typedef u8 app_key_modifiers_t;

typedef struct {
  enum {
    AppMouseLeft,
    AppMouseRight,
    AppMouseMiddle,
  } button;
  bool press;
  app_key_modifiers_t mods;
} app_event_mouse_t;

typedef struct {
  u32 key;
  u32 scancode;
  enum {
    AppKeyPress,
    AppKeyRelease,
    AppKeyRepeat,
  } action;
  app_key_modifiers_t mods;
} app_event_key_t;

typedef struct {
  app_event_type_t type;
  union {
    u32 xchar;
    app_pos2d_t pos;
    app_size2d_t size;
    app_event_mouse_t mouse;
    app_event_key_t key;
    app_event_scroll_t scroll;
    app_event_paths_t paths;
    app_event_scale_t scale;
  } data;
} app_event_t;

typedef struct {
  void* platform;
  u64 last_render_ms;
  app_size2d_t size;
  app_pos2d_t mouse;
  allocator_t frame_allocator;
  bool onscreen_keyboard;
  framebuffer_t* fb;
} app_state_t;

typedef void (*app_event_callback)(void* userdata, app_event_t* ev);
typedef void (*app_render_callback)(void* userdata);

typedef struct {
  void* userdata;
  app_event_callback on_event;
  app_render_callback render;
  app_size2d_t initial_size;
  char* window_title;
} app_init_t;

typedef void (*app_init_function)(app_state_t* state, app_init_t* init);

void app_mark_needs_render(app_state_t* state);
void app_onscreen_keyboard(app_state_t* state, bool show);
const char* app_event_type_str(app_event_type_t);
str_t app_frame_strfmt(app_state_t* app, char* fmt, ...);
u64 app_gettimems(app_state_t* app);
void app_quit(app_state_t* app);

#endif
