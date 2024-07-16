// https://developer.android.com/reference/games/game-activity/group/android-native-app-glue
// https://github.com/android/ndk-samples/blob/main/native-activity/app/src/main/cpp/main.cpp
#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>

#include <android/native_activity.h>
#include <android/native_window.h>
#include <android/input.h>
#include <android/log.h>

#include <android/input.h>
#include <android/keycodes.h>

#include "android_native_app_glue.h"

void _xos_android_provide_native_window(void*, int32_t, int32_t);
void _xos_android_handle_resize(int32_t, int32_t);
void _xos_handle_shutdown(void);

#define LOG_TAG "NativeActivity"
#define LOGE(...) ((void)__android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__))

#define LOGI(...) ((void)__android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__))

void doAndroidLog(const char* msg) {
  LOGI("%s", msg);
}

typedef struct {
  struct android_app* app;
} Ctx;

static int32_t ctxHandleInput(struct android_app* app, AInputEvent* event) {
  // https://developer.android.com/ndk/reference/group/input
  Ctx* ctx = (Ctx*)app->userData;
  int32_t esrc = AInputEvent_getSource(event);
  int32_t etype = AInputEvent_getType(event);
  switch (esrc) {
    case AINPUT_SOURCE_UNKNOWN:
    case AINPUT_SOURCE_KEYBOARD:
    case AINPUT_SOURCE_DPAD:
    case AINPUT_SOURCE_GAMEPAD:
    case AINPUT_SOURCE_TOUCHSCREEN:
    case AINPUT_SOURCE_MOUSE:
    case AINPUT_SOURCE_STYLUS:
    case AINPUT_SOURCE_BLUETOOTH_STYLUS:
    case AINPUT_SOURCE_TRACKBALL:
    case AINPUT_SOURCE_MOUSE_RELATIVE:
    case AINPUT_SOURCE_TOUCHPAD:
    case AINPUT_SOURCE_TOUCH_NAVIGATION:
    case AINPUT_SOURCE_JOYSTICK:
    case AINPUT_SOURCE_ROTARY_ENCODER:
    case AINPUT_SOURCE_ANY:
      LOGI("event src %d", esrc);
      break;
    default:
      LOGE("unknown event src %d", esrc);
      break;
  }

  switch (etype) {
    case AINPUT_EVENT_TYPE_KEY:
    case AINPUT_EVENT_TYPE_MOTION:
    case AINPUT_EVENT_TYPE_FOCUS:
      LOGI("event type %d", etype);
      break;
    default:
      LOGE("unknown event type %d", etype);
      break;
  }
  return 0;
}

static void ctxTermDisplay(Ctx* ctx) {
  _xos_handle_shutdown();
}

static void drawFrame() {}

static void fatal(const char* msg) {
  LOGE("%s", msg);
  abort();
}

static void ctxHandleCmd(struct android_app* app, int32_t cmd) {
  Ctx* ctx = (Ctx*)app->userData;
  switch (cmd) {
    case APP_CMD_INIT_WINDOW: {
      LOGI("APP_CMD_INIT_WINDOW");
      LOGI("init display");
      ANativeWindow* window = app->window;
      _xos_android_provide_native_window(window, ANativeWindow_getWidth(window), ANativeWindow_getHeight(window));
    } break;
    case APP_CMD_START:
      LOGI("APP_CMD_START");
    case APP_CMD_RESUME:
      LOGI("APP_CMD_RESUME");
      break;
    case APP_CMD_GAINED_FOCUS:
      LOGI("APP_CMD_GAINED_FOCUS");
      break;
    case APP_CMD_TERM_WINDOW: {
      LOGI("APP_CMD_TERM_WINDOW");
      ctxTermDisplay(ctx);
    } break;
    case APP_CMD_WINDOW_RESIZED:
    case APP_CMD_WINDOW_REDRAW_NEEDED:
    case APP_CMD_CONTENT_RECT_CHANGED: {
      LOGI("APP_CMD_ resize %d", cmd);
      ANativeWindow* window = app->window;
      _xos_android_handle_resize(ANativeWindow_getWidth(window), ANativeWindow_getHeight(window));
    } break;
    case APP_CMD_INPUT_CHANGED:
    case APP_CMD_LOST_FOCUS:
    case APP_CMD_CONFIG_CHANGED:
    case APP_CMD_LOW_MEMORY:
    case APP_CMD_SAVE_STATE:
    case APP_CMD_PAUSE:
    case APP_CMD_STOP:
    case APP_CMD_DESTROY:
      LOGI("APP_CMD_ %d", cmd);
      break;
    default:
      break;
  }
}

// https://developer.android.com/reference/games/game-activity/struct/android-app
void android_main(struct android_app* app) {
  LOGI("hello world!");
  LOGI("android_main");
  Ctx ctx = {0};
  ctx.app = app;
  app->userData = &ctx;
  app->onAppCmd = ctxHandleCmd;
  app->onInputEvent = ctxHandleInput;

  if (app->savedState != NULL) LOGE("saved state, ignoring");

  // https://developer.android.com/ndk/reference/struct/a-native-activity
  ANativeActivity* activity = app->activity;
  AAssetManager* asset_manager = activity->assetManager;
  JNIEnv* jni = activity->env;
  const char* data_path = activity->internalDataPath;

  LOGI("android_main loop");
  while (!app->destroyRequested) {
    struct android_poll_source* source;
    int result = ALooper_pollOnce(-1, NULL, NULL, (void**)&source);
    assert(result != ALOOPER_POLL_ERROR);
    if (source != NULL) source->process(app, source);
  }

  ctxTermDisplay(&ctx);
  LOGI("goodbye");
}
