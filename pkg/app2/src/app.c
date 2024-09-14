// TODO: resource read for the font?
// means we need to package it?
// need better layering i think

#include <stdarg.h>

#include "app.h"

#include "base/log.h"
#include "base/file.h"
#include "base/fmt.h"

extern void app_init(app_state_t* state, app_init_t* init);

str_t app_frame_strfmt(app_state_t* app, char* fmt, ...) {
  va_list args;
  va_start(args, fmt);
  str_t s = vstrfmt(&app->frame_allocator, fmt, args);
  va_end(args);
  return s;
}

#ifdef APP_PLATFORM_OS_DESKTOP
// GLFW main

#include "olive.h"

#include "GLFW/glfw3.h"
#include "nativefb.h"

#include "text.h"

typedef struct {
  app_state_t state;
  app_init_t init;
  app_event_t event;

  // We push pixels into the framebuffer, and then use the native platform
  // to blit it to the screen.
  framebuffer_t fb;
  native_platform_t platform;
  bool needs_render;

  // During view tree construction, we use a simple fixed-size bump allocator
  // which gets reset at the beginning of each render.
  allocator_bump_t bump;

  // Text state
  FT_Face ft_face;
  hb_font_t* hb_font;
  hb_buffer_t* hb_buf;
  float lineh;
  text_atlas_t atlas;
} app_platform_t;

static void resize_fb(app_platform_t* app, int width, int height) {
  if (app->fb.w == width && app->fb.h == height) return;
  app->fb.buf = realloc(app->fb.buf, width * height * sizeof(uint32_t));
  app->fb.w = width;
  app->fb.h = height;
  app->state.size.w = width;
  app->state.size.h = height;
  nativefb_resize(&app->platform, &app->fb);
}

static void render(app_platform_t* app) {
  allocator_bump_reset(&app->bump);
  app->init.render(app->init.userdata);
  app->state.last_render_ms = glfwGetTime() * 1000;
}

static inline void send_event(app_platform_t* app) {
  app->init.on_event(app->init.userdata, &app->event);
}

// GLFW callbacks
// ----------------------------------------------------------------------------
#define getapp() (app_platform_t*)glfwGetWindowUserPointer(window);
#define EV0(evtype) do { \
    app->event.type = AppEvent##evtype; \
    send_event(app); \
  } while (0)
#define EV(evtype, field, init) do { \
    app->event.type = AppEvent##evtype; \
    app->event.data.field = (init); \
    send_event(app); \
  } while (0)

static void close_callback_glfw(GLFWwindow* window) {
  app_platform_t* app = getapp();
  EV0(WindowClose);
}

static void error_callback_glfw(int error, const char* description) {
  LOG("GLFW Error (%d): %s", error, description);
}

static void character_callback(GLFWwindow* window, unsigned int codepoint) {
  app_platform_t* app = getapp();
  EV(Char, xchar, codepoint);
}

static void cursor_position_callback(GLFWwindow* window, double xpos, double ypos) {
  app_platform_t* app = getapp();
  // Clay_SetPointerPosition((Clay_Vector2){xpos, ypos});

  app->state.mouse.x = xpos;
  app->state.mouse.y = ypos;

  EV(MouseMotion, pos, app->state.mouse);
}

static void cursor_enter_callback(GLFWwindow* window, int entered) {
  app_platform_t* app = getapp();
  if (entered) { EV0(MouseEnter); } else { EV0(MouseLeave); }
}

static void mouse_button_callback(GLFWwindow* window, int button, int action, int mods) {
  // https://www.glfw.org/docs/latest/group__buttons.html
  app_platform_t* app = getapp();

  app_event_mouse_t* ev = &app->event.data.mouse;
  ev->button = (button == GLFW_MOUSE_BUTTON_LEFT ? AppMouseLeft : (
        button == GLFW_MOUSE_BUTTON_RIGHT ? AppMouseRight : AppMouseMiddle));
  ev->press = action == GLFW_PRESS;
  ev->mods = mods;
  EV0(MouseClick);
}

static void scroll_callback(GLFWwindow* window, double xoffset, double yoffset) {
  app_platform_t* app = getapp();
  EV(Scroll, scroll, ((app_event_scroll_t){ .x = xoffset, .y = yoffset }));
}

static void drop_callback(GLFWwindow* window, int count, const char** paths) {
  app_platform_t* app = getapp();
  EV(DropPaths, paths, ((app_event_paths_t){.paths = paths, .npaths = count }));
}

static void window_refresh_callback(GLFWwindow* window) {
  LOG("GLFW window refresh");
  app_platform_t* app = getapp();
  nativefb_paint(&app->platform, &app->fb);
}

static void window_focus_callback(GLFWwindow *window, int focus) {
  app_platform_t* app = getapp();
  if (focus) { EV0(WindowFocus); } else { EV0(WindowFocusLost); }
}

static void window_content_scale_callback(GLFWwindow *window, float xscale, float yscale) {
  app_platform_t* app = getapp();
  EV(FrameContentScale, scale, ((app_event_scale_t){ .x = xscale, .y = yscale }));
}

static void fbsize_callback(GLFWwindow *window, int width, int height) {
  app_platform_t* app = getapp();
  resize_fb(app, width, height);
  app_mark_needs_render(&app->state);
  EV(FrameSize, size, ((app_size2d_t){ .w = width, .h = height }));
}

static void winsize_callback(GLFWwindow *window, int width, int height) {
  app_platform_t* app = getapp();
  resize_fb(app, width, height);
  app_mark_needs_render(&app->state);
  EV(WindowSize, size, ((app_size2d_t){ .w = width, .h = height }));
}

static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods) {
  app_platform_t* app = getapp();
  app_event_key_t* ev = &app->event.data.key;
  ev->key = key;
  ev->scancode = scancode;
  ev->mods = mods;
  ev->action = (action == GLFW_PRESS ? AppKeyPress : (action == GLFW_RELEASE ?
        AppKeyRelease : AppKeyRepeat));
  EV0(Key);
}

// ----------------------------------------------------------------------------

int main(int argc, char** argv) {
  LOG("hello");

  app_platform_t app = {0};

  LOG("app init");
  app_init(&app.state, &app.init);
  int w = app.init.initial_size.w;
  int h = app.init.initial_size.h;
  app.fb.buf = malloc(w * h * sizeof(uint32_t));
  app.fb.w = w;
  app.fb.h = h;
  app.bump.buf = malloc(1 << 20);
  app.bump.len = 1 << 20;

  app.state.frame_allocator = allocator_bump(&app.bump);
  app.state.platform = &app;
  app.state.size.w = w;
  app.state.size.h = h;

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

  LOG("GLFW init");
  CHECK(glfwInit());
  glfwSetErrorCallback(error_callback_glfw);
  glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);
  glfwWindowHint(GLFW_VISIBLE, GLFW_TRUE);
  glfwWindowHint(GLFW_DECORATED, GLFW_TRUE);
  glfwWindowHint(GLFW_FOCUSED, GLFW_TRUE);
  glfwWindowHint(GLFW_FOCUS_ON_SHOW, GLFW_TRUE);
  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
  GLFWwindow* window = glfwCreateWindow(w, h, app.init.window_title, NULL, NULL);
  CHECK(window);
  glfwSetWindowUserPointer(window, &app);
  glfwSetWindowCloseCallback(window, close_callback_glfw);
  glfwSetWindowSizeCallback(window, winsize_callback);
  glfwSetFramebufferSizeCallback(window, fbsize_callback);
  glfwSetWindowContentScaleCallback(window, window_content_scale_callback);
  glfwSetWindowFocusCallback(window, window_focus_callback);
  glfwSetWindowRefreshCallback(window, window_refresh_callback);
  // Input callbacks
  // https://www.glfw.org/docs/latest/group__input.html
  glfwSetKeyCallback(window, key_callback);
  glfwSetCharCallback(window, character_callback);
  glfwSetCursorPosCallback(window, cursor_position_callback);
  glfwSetCursorEnterCallback(window, cursor_enter_callback);
  glfwSetMouseButtonCallback(window, mouse_button_callback);
  glfwSetScrollCallback(window, scroll_callback);
  glfwSetDropCallback(window, drop_callback);

  LOG("Framebuffer init");
  nativefb_init(&app.platform, window, &app.fb);
  app.event.type = AppEventGfxInit;
  send_event(&app);

  LOG("UI loop...");
  app.needs_render = true;
  while (!glfwWindowShouldClose(window)) {
    if (app.needs_render) {
      render(&app);
      app.needs_render = false;
    }
    // Wake from other thread with glfwPostEmptyEvent()
    glfwWaitEvents();
  }

  LOG("Cleanup");
  app.event.type = AppEventExit;
  send_event(&app);

  nativefb_deinit(&app.platform);
  glfwDestroyWindow(window);
  glfwTerminate();
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

void app_mark_needs_render(app_state_t* state) {
  ((app_platform_t*)(state->platform))->needs_render = true;
}

void app_onscreen_keyboard(app_state_t* state, bool show) {}

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
};

const char* app_event_type_str(app_event_type_t t) {
  return event_strs[t];
}

#endif
