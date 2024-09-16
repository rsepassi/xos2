#ifdef APP_PLATFORM_OS_ANDROID
// https://developer.android.com/reference/games/game-activity/group/android-native-app-glue
// https://github.com/android/ndk-samples/blob/main/native-activity/app/src/main/cpp/main.cpp
#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>

#include "app.h"
#include "app_internal.h"

#include "base/log.h"
#include "base/file.h"

#include <android/native_activity.h>
#include <android/native_window.h>
#include <android/input.h>
#include <android/log.h>
#include <android/input.h>
#include <android/keycodes.h>
#include "android_native_app_glue.h"

static struct android_app* droid_global = NULL;
extern void app_init(app_state_t* state, app_init_t* init);

u64 app__gettimems(app_platform_t* app) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return now.tv_sec * 1000 + now.tv_nsec / 1000000LL;
}

static app_key_modifiers_t map_keymods(i32 android_meta) {
  app_key_modifiers_t out = 0;

  i32 m = android_meta;
  if (m & (AMETA_ALT_ON | AMETA_ALT_LEFT_ON | AMETA_ALT_RIGHT_ON))
      out |= APP_MOD_ALT;
  if (m & (AMETA_SHIFT_ON | AMETA_SHIFT_LEFT_ON | AMETA_SHIFT_RIGHT_ON))
      out |= APP_MOD_SHIFT;
  if (m & (AMETA_CTRL_ON | AMETA_CTRL_LEFT_ON | AMETA_CTRL_RIGHT_ON))
      out |= APP_MOD_CTRL;
  if (m & (AMETA_META_ON | AMETA_META_LEFT_ON | AMETA_META_RIGHT_ON))
      out |= APP_MOD_SUPER;
  if (m & AMETA_NUM_LOCK_ON)
      out |= APP_MOD_NUM_LOCK;
  if (m & AMETA_CAPS_LOCK_ON)
      out |= APP_MOD_CAPS_LOCK;

  if (AMETA_SYM_ON | AMETA_FUNCTION_ON | AMETA_SCROLL_LOCK_ON)
    LOG("unhandled keymod %d", android_meta);

  return out;
} 

static u32 map_keycode2(i32 android_keycode) {
  // Android #keycodes = 317
  // App #keycodes = 120
  // 105 mapped
  switch(android_keycode) {
    case AKEYCODE_SPACE: return AppKey_SPACE;
    case AKEYCODE_APOSTROPHE: return AppKey_APOSTROPHE;
    case AKEYCODE_COMMA: return AppKey_COMMA;
    case AKEYCODE_MINUS: return AppKey_MINUS;
    case AKEYCODE_PERIOD: return AppKey_PERIOD;
    case AKEYCODE_SLASH: return AppKey_SLASH;
    case AKEYCODE_0: return AppKey_0;
    case AKEYCODE_1: return AppKey_1;
    case AKEYCODE_2: return AppKey_2;
    case AKEYCODE_3: return AppKey_3;
    case AKEYCODE_4: return AppKey_4;
    case AKEYCODE_5: return AppKey_5;
    case AKEYCODE_6: return AppKey_6;
    case AKEYCODE_7: return AppKey_7;
    case AKEYCODE_8: return AppKey_8;
    case AKEYCODE_9: return AppKey_9;
    case AKEYCODE_SEMICOLON: return AppKey_SEMICOLON;
    case AKEYCODE_EQUALS: return AppKey_EQUAL;
    case AKEYCODE_A: return AppKey_A;
    case AKEYCODE_B: return AppKey_B;
    case AKEYCODE_C: return AppKey_C;
    case AKEYCODE_D: return AppKey_D;
    case AKEYCODE_E: return AppKey_E;
    case AKEYCODE_F: return AppKey_F;
    case AKEYCODE_G: return AppKey_G;
    case AKEYCODE_H: return AppKey_H;
    case AKEYCODE_I: return AppKey_I;
    case AKEYCODE_J: return AppKey_J;
    case AKEYCODE_K: return AppKey_K;
    case AKEYCODE_L: return AppKey_L;
    case AKEYCODE_M: return AppKey_M;
    case AKEYCODE_N: return AppKey_N;
    case AKEYCODE_O: return AppKey_O;
    case AKEYCODE_P: return AppKey_P;
    case AKEYCODE_Q: return AppKey_Q;
    case AKEYCODE_R: return AppKey_R;
    case AKEYCODE_S: return AppKey_S;
    case AKEYCODE_T: return AppKey_T;
    case AKEYCODE_U: return AppKey_U;
    case AKEYCODE_V: return AppKey_V;
    case AKEYCODE_W: return AppKey_W;
    case AKEYCODE_X: return AppKey_X;
    case AKEYCODE_Y: return AppKey_Y;
    case AKEYCODE_Z: return AppKey_Z;
    case AKEYCODE_LEFT_BRACKET: return AppKey_LEFT_BRACKET;
    case AKEYCODE_BACKSLASH: return AppKey_BACKSLASH;
    case AKEYCODE_RIGHT_BRACKET: return AppKey_RIGHT_BRACKET;
    case AKEYCODE_GRAVE: return AppKey_GRAVE_ACCENT;
    case AKEYCODE_ESCAPE: return AppKey_ESCAPE;
    case AKEYCODE_ENTER: return AppKey_ENTER;
    case AKEYCODE_TAB: return AppKey_TAB;
    case AKEYCODE_DEL: return AppKey_BACKSPACE;
    case AKEYCODE_INSERT: return AppKey_INSERT;
    case AKEYCODE_FORWARD_DEL: return AppKey_DELETE;
    case AKEYCODE_DPAD_RIGHT: return AppKey_RIGHT;
    case AKEYCODE_DPAD_LEFT: return AppKey_LEFT;
    case AKEYCODE_DPAD_DOWN: return AppKey_DOWN;
    case AKEYCODE_DPAD_UP: return AppKey_UP;
    case AKEYCODE_PAGE_UP: return AppKey_PAGE_UP;
    case AKEYCODE_PAGE_DOWN: return AppKey_PAGE_DOWN;
    case AKEYCODE_MOVE_HOME: return AppKey_HOME;
    case AKEYCODE_MOVE_END: return AppKey_END;
    case AKEYCODE_CAPS_LOCK: return AppKey_CAPS_LOCK;
    case AKEYCODE_SCROLL_LOCK: return AppKey_SCROLL_LOCK;
    case AKEYCODE_NUM_LOCK: return AppKey_NUM_LOCK;
    case AKEYCODE_SYSRQ: return AppKey_PRINT_SCREEN;
    case AKEYCODE_BREAK: return AppKey_PAUSE;
    case AKEYCODE_F1: return AppKey_F1;
    case AKEYCODE_F2: return AppKey_F2;
    case AKEYCODE_F3: return AppKey_F3;
    case AKEYCODE_F4: return AppKey_F4;
    case AKEYCODE_F5: return AppKey_F5;
    case AKEYCODE_F6: return AppKey_F6;
    case AKEYCODE_F7: return AppKey_F7;
    case AKEYCODE_F8: return AppKey_F8;
    case AKEYCODE_F9: return AppKey_F9;
    case AKEYCODE_F10: return AppKey_F10;
    case AKEYCODE_F11: return AppKey_F11;
    case AKEYCODE_F12: return AppKey_F12;
    case AKEYCODE_NUMPAD_0: return AppKey_KP_0;
    case AKEYCODE_NUMPAD_1: return AppKey_KP_1;
    case AKEYCODE_NUMPAD_2: return AppKey_KP_2;
    case AKEYCODE_NUMPAD_3: return AppKey_KP_3;
    case AKEYCODE_NUMPAD_4: return AppKey_KP_4;
    case AKEYCODE_NUMPAD_5: return AppKey_KP_5;
    case AKEYCODE_NUMPAD_6: return AppKey_KP_6;
    case AKEYCODE_NUMPAD_7: return AppKey_KP_7;
    case AKEYCODE_NUMPAD_8: return AppKey_KP_8;
    case AKEYCODE_NUMPAD_9: return AppKey_KP_9;
    case AKEYCODE_NUMPAD_DOT: return AppKey_KP_DECIMAL;
    case AKEYCODE_NUMPAD_DIVIDE: return AppKey_KP_DIVIDE;
    case AKEYCODE_NUMPAD_MULTIPLY: return AppKey_KP_MULTIPLY;
    case AKEYCODE_NUMPAD_SUBTRACT: return AppKey_KP_SUBTRACT;
    case AKEYCODE_NUMPAD_ADD: return AppKey_KP_ADD;
    case AKEYCODE_NUMPAD_ENTER: return AppKey_KP_ENTER;
    case AKEYCODE_NUMPAD_EQUALS: return AppKey_KP_EQUAL;
    case AKEYCODE_SHIFT_LEFT: return AppKey_LEFT_SHIFT;
    case AKEYCODE_CTRL_LEFT: return AppKey_LEFT_CONTROL;
    case AKEYCODE_ALT_LEFT: return AppKey_LEFT_ALT;
    case AKEYCODE_META_LEFT: return AppKey_LEFT_SUPER;
    case AKEYCODE_SHIFT_RIGHT: return AppKey_RIGHT_SHIFT;
    case AKEYCODE_CTRL_RIGHT: return AppKey_RIGHT_CONTROL;
    case AKEYCODE_ALT_RIGHT: return AppKey_RIGHT_ALT;
    case AKEYCODE_META_RIGHT: return AppKey_RIGHT_SUPER;
    case AKEYCODE_MENU: return AppKey_MENU;
    default: return AppKey_UNKNOWN;
  }
}

static u32 map_keycode(u32 android_keycode) {
  u32 key = map_keycode2(android_keycode);
  if (key == AppKey_UNKNOWN) LOG("unknown keycode %d", android_keycode);
  return key;
}

static i32 handle_input(struct android_app* droid, AInputEvent* event) {
  // https://developer.android.com/ndk/reference/group/input
  app_platform_t* app = (app_platform_t*)droid->userData;

  if (false) {
    i32 esrc = AInputEvent_getSource(event);
    switch (esrc) {
      case AINPUT_SOURCE_UNKNOWN:
      case AINPUT_SOURCE_DPAD:
      case AINPUT_SOURCE_GAMEPAD:
      case AINPUT_SOURCE_KEYBOARD:
      case AINPUT_SOURCE_TOUCHSCREEN:
      case AINPUT_SOURCE_MOUSE:
      case AINPUT_SOURCE_TRACKBALL:
      case AINPUT_SOURCE_MOUSE_RELATIVE:
      case AINPUT_SOURCE_TOUCHPAD:
      case AINPUT_SOURCE_TOUCH_NAVIGATION:
      case AINPUT_SOURCE_STYLUS:
      case AINPUT_SOURCE_BLUETOOTH_STYLUS:
      case AINPUT_SOURCE_JOYSTICK:
      case AINPUT_SOURCE_ROTARY_ENCODER:
      case AINPUT_SOURCE_ANY:
        LOG("event src %d", esrc);
        break;
    }
  }

  i32 etype = AInputEvent_getType(event);
  switch (etype) {
    case AINPUT_EVENT_TYPE_KEY: {
      app_event_key_t* ev = &app->event.data.key;
      i32 action = AKeyEvent_getAction(event);

      ev->key = map_keycode(AKeyEvent_getKeyCode(event));
      ev->mods = map_keymods(AKeyEvent_getMetaState(event));
      ev->scancode = AKeyEvent_getScanCode(event);
      ev->action = (action == AKEY_EVENT_ACTION_DOWN ? AppKeyPress : (action == AKEY_EVENT_ACTION_UP ?
            AppKeyRelease : AppKeyRepeat));
      EV0(Key);

    } break;
    case AINPUT_EVENT_TYPE_MOTION: {
      size_t ntouch = AMotionEvent_getPointerCount(event);

      app->state.mouse.x = AMotionEvent_getX(event, 0);
      app->state.mouse.y = AMotionEvent_getY(event, 0);

      i32 action = AMotionEvent_getAction(event);
      switch (action) {
        case AMOTION_EVENT_ACTION_DOWN:
        case AMOTION_EVENT_ACTION_UP:
        case AMOTION_EVENT_ACTION_MOVE:
        case AMOTION_EVENT_ACTION_CANCEL:
          // EV(Motion)?
          // EV(Touch)?

        case AMOTION_EVENT_ACTION_SCROLL:
          // AMotionEvent_getAxisValue
          // EV(Scroll)
          // AMOTION_EVENT_AXIS_VSCROLL and AMOTION_EVENT_AXIS_HSCROLL

        case AMOTION_EVENT_ACTION_BUTTON_PRESS:
        case AMOTION_EVENT_ACTION_BUTTON_RELEASE:
          // EV(Key) ?
          //   AMotionEvent_getActionButton(event)  // Enum 47
          // AMotionEvent_getButtonState(event)  // Enum 38

        case AMOTION_EVENT_ACTION_MASK:
        case AMOTION_EVENT_ACTION_POINTER_INDEX_MASK:
        case AMOTION_EVENT_ACTION_OUTSIDE:
        case AMOTION_EVENT_ACTION_POINTER_DOWN:
        case AMOTION_EVENT_ACTION_POINTER_UP:
        case AMOTION_EVENT_ACTION_HOVER_MOVE:
        case AMOTION_EVENT_ACTION_HOVER_ENTER:
        case AMOTION_EVENT_ACTION_HOVER_EXIT:
          LOG("motion");
          break;
      }

      LOG("motion");
    } break;
    case AINPUT_EVENT_TYPE_FOCUS:
      LOG("event type %d", etype);
      break;
  }
  return 0;
}

static void render(app_platform_t* app) {
  app__render(app);
  nativefb_paint(&app->platform, &app->fb);
}

static void handle_cmd(struct android_app* droid, i32 cmd) {
  ANativeWindow* window = droid->window;
  app_platform_t* app = (app_platform_t*)droid->userData;

  switch (cmd) {
    case APP_CMD_INIT_WINDOW: {
      u16 w = ANativeWindow_getWidth(window);
      u16 h = ANativeWindow_getHeight(window);
      app__resize_fb(app, w, h);
      nativefb_init(&app->platform, window, &app->fb);
      EV0(GfxInit);
      render(app);
    } break;
    case APP_CMD_GAINED_FOCUS:
      EV0(WindowFocus);
      break;
    case APP_CMD_LOST_FOCUS:
      EV0(WindowFocusLost);
      break;
    case APP_CMD_TERM_WINDOW:
      EV0(Exit);
      break;
    case APP_CMD_RESUME:
      EV0(Resume);
      break;
    case APP_CMD_PAUSE:
      EV0(Suspend);
      break;
    case APP_CMD_CONFIG_CHANGED:
    case APP_CMD_WINDOW_RESIZED:
    case APP_CMD_WINDOW_REDRAW_NEEDED:
    case APP_CMD_CONTENT_RECT_CHANGED: {
      u16 w = ANativeWindow_getWidth(window);
      u16 h = ANativeWindow_getHeight(window);
      app__resize_fb(app, w, h);
      render(app);
    } break;
    case APP_CMD_START:
    case APP_CMD_INPUT_CHANGED:
    case APP_CMD_LOW_MEMORY:
    case APP_CMD_SAVE_STATE:
    case APP_CMD_STOP:
    case APP_CMD_DESTROY:
      LOG("APP_CMD_ %d", cmd);
      break;
    default:
      break;
  }
}

str_t fs_resource_read_android(str_t name) {
  ANativeActivity* activity = droid_global->activity;
  AAssetManager* mgr = activity->assetManager;
  char* fname = malloc(name.len + 1);
  memcpy(fname, name.bytes, name.len);
  fname[name.len] = 0;
  AAsset* asset = AAssetManager_open(mgr, fname, AASSET_MODE_BUFFER);
  free(fname);

  u32 len = AAsset_getLength(asset);
  u8* buf = malloc(len);
  CHECK(AAsset_read(asset, buf, len) == len);

  return (str_t){.bytes = (u8*)buf, .len = len};
}

// https://developer.android.com/reference/games/game-activity/struct/android-app
void android_main(struct android_app* droid) {
  LOG("android_main");
  if (droid->savedState != NULL) LOG("saved state, ignoring");

  app_platform_t app = {0};
  droid_global = droid;
  droid->userData = &app;
  droid->onAppCmd = handle_cmd;
  droid->onInputEvent = handle_input;

  LOG("app init");
  app_init(&app.state, &app.init);

  app.bump.buf = malloc(1 << 20);
  app.bump.len = 1 << 20;

  app.state.frame_allocator = allocator_bump(&app.bump);
  app.state.platform = &app;
  app.state.fb = &app.fb;

  LOG("text init");
  int font_size = 32;
  str_t font_data = fs_resource_read(cstr("CourierPrime-Regular.ttf"));
  FT_Library ft_library;
  CHECK(!FT_Init_FreeType(&ft_library));
  CHECK(!FT_New_Memory_Face(ft_library, (const FT_Byte*)font_data.bytes, font_data.len, 0, &app.ft_face));
  FT_Set_Char_Size(app.ft_face, 0, font_size << 6, 72, 72);
  app.lineh = text_line_height(app.ft_face);
  app.hb_font = hb_ft_font_create(app.ft_face, NULL);
  app.hb_buf = text_english_buf();
  int atlash = (int)(app.lineh + 0.5);
  int atlasw = (1 << 20) / atlash;
  app.atlas = text_atlas_init(malloc(atlash * atlasw), atlasw, atlash);

  // https://developer.android.com/ndk/reference/struct/a-native-activity
  ANativeActivity* activity = droid->activity;
  AAssetManager* asset_manager = activity->assetManager;
  JNIEnv* jni = activity->env;
  const char* data_path = activity->internalDataPath;

  LOG("android_main loop");
  while (!droid->destroyRequested) {
    struct android_poll_source* source;
    int result = ALooper_pollOnce(-1, NULL, NULL, (void**)&source);
    assert(result != ALOOPER_POLL_ERROR);
    if (source != NULL) source->process(droid, source);
  }

  LOG("Cleanup");
  text_atlas_deinit(&app.atlas);
  free(app.atlas.buf);
  hb_buffer_destroy(app.hb_buf);
  hb_font_destroy(app.hb_font);
  FT_Done_Face(app.ft_face);
  free((void*)font_data.bytes);
  FT_Done_FreeType(ft_library);
  free(app.bump.buf);

  LOG("goodbye");
}

#endif
