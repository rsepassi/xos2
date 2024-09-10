#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>

#include "base/log.h"
#include "base/allocator.h"
#include "base/fmt.h"

#include "clay.h"
#include "olive.h"

#include "GLFW/glfw3.h"
#include "nativefb.h"

static char lorem[] = "lorem ipsum is simply dummy text of the printing and typesetting industry. lorem ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. it has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. it was popularised in the 1960s with the release of letraset sheets containing lorem ipsum passages, and more recently with desktop publishing software like aldus pagemaker including versions of lorem ipsum.";

typedef struct {
  int count;

  framebuffer_t fb;
  native_platform_t platform;

  allocator_bump_t bump;
  allocator_t frame_alloc;

  bool needs_render;
  double last_render;
} appstate_t;

static void appstate_free(appstate_t* app) {
  // free(app->fb.buf);  nativefb_deinit releases this on X11
  free(app->bump.buf);
}

static void render(GLFWwindow* window, appstate_t* app);

#define getapp() (appstate_t*)glfwGetWindowUserPointer(window);

static void close_callback_glfw(GLFWwindow* window) {
  appstate_t* app = getapp();
  LOG("GLFW closing...");
}

static void error_callback_glfw(int error, const char* description) {
  LOG("GLFW Error (%d): %s", error, description);
}

static void character_callback(GLFWwindow* window, unsigned int codepoint) {
  LOG("GLFW codepoint");
}

static void cursor_position_callback(GLFWwindow* window, double xpos, double ypos) {
  Clay_SetPointerPosition((Clay_Vector2){xpos, ypos});
}

static void cursor_enter_callback(GLFWwindow* window, int entered) {
  if (entered) {
    LOG("cursor enter");
  }
  else {
    LOG("cursor leave");
  }
}

static void mouse_button_callback(GLFWwindow* window, int button, int action, int mods) {
  // https://www.glfw.org/docs/latest/group__buttons.html
  appstate_t* app = getapp();
  if (button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_PRESS) {
    if (Clay_PointerOver(CLAY_ID("INCR"))) {
      app->count += 1;
      app->needs_render = true;
    }
  }
}

static void scroll_callback(GLFWwindow* window, double xoffset, double yoffset) {
  appstate_t* app = getapp();

  double xpos, ypos;
  glfwGetCursorPos(window, &xpos, &ypos);
  Clay_SetPointerPosition((Clay_Vector2){xpos, ypos});

  xoffset *= 4;
  yoffset *= 4;

  if (Clay_PointerOver(CLAY_ID("A-scroll"))) {
    double delta = glfwGetTime() - app->last_render;
    Clay_UpdateScrollContainers(false, (Clay_Vector2){ xoffset, yoffset }, delta);
    app->needs_render = true;
  }
}

static void drop_callback(GLFWwindow* window, int count, const char** paths) {
  for (int i = 0;  i < count;  i++) {
    LOG("drop path %s", paths[i]);
  }
}

static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods) {
  // https://www.glfw.org/docs/latest/group__keys.html
  appstate_t* app = getapp();
  LOG("key event");
  if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
    glfwSetWindowShouldClose(window, GLFW_TRUE);
  }
  if (key == GLFW_KEY_Z && action == GLFW_PRESS) {
    app->count += 1;
    app->needs_render = true;
  }

  // Can query key names
  // const char* key_name = glfwGetKeyName(GLFW_KEY_W, 0);
  // show_tutorial_hint("Press %s to move forward", key_name);
}

static void window_refresh_callback(GLFWwindow* window) {
  appstate_t* app = getapp();
  render(window, app);
}

static void window_focus_callback(GLFWwindow *window, int focus) {
  if (focus) {
    LOG("GLFW window gained focus");
  } else {
    LOG("GLFW window lost focus");
  }
}

static void window_content_scale_callback(GLFWwindow *window, float xscale, float yscale) {
  LOG("GLFW content scale changed (%.2f, %.2f)", xscale, yscale);
}

static void doresize(appstate_t* app, int width, int height) {
  if (app->fb.w == width && app->fb.h == height) return;
  app->fb.buf = realloc(app->fb.buf, width * height * sizeof(uint32_t));
  app->fb.w = width;
  app->fb.h = height;
  nativefb_resize(&app->platform, &app->fb);
}

static void fbsize_callback(GLFWwindow *window, int width, int height) {
  appstate_t* app = getapp();
  LOG("GLFW FB resize (%d, %d)", width, height);
  doresize(app, width, height);
  render(window, app);
}

static void winsize_callback(GLFWwindow *window, int width, int height) {
  appstate_t* app = getapp();
  LOG("GLFW Window resize (%d, %d)", width, height);
  doresize(app, width, height);
  render(window, app);
}

static inline Clay_String app_strfmt(appstate_t* app, char* fmt, ...) {
  va_list args;
  va_start(args, fmt);
  str_t s = vstrfmt(&app->frame_alloc, fmt, args);
  va_end(args);
  return ((Clay_String){.chars = s.bytes, .length = s.len});
}

static inline uint32_t convertColor(Clay_Color color) {
  uint8_t out[4];
  out[0] = (uint8_t)color.r;
  out[1] = (uint8_t)color.g;
  out[2] = (uint8_t)color.b;
  out[3] = (uint8_t)color.a;
  return *((uint32_t*)out);
}

static void buildTree(int w, int h, appstate_t* app) {
  CLAY_RECTANGLE(CLAY_ID("OuterContainer"),
      CLAY_LAYOUT(.sizing = {CLAY_SIZING_FIXED(w), CLAY_SIZING_FIXED(h)},
                  .padding = {16, 16},
                  .childGap = 16),
      CLAY_RECTANGLE_CONFIG(.color = {0,255,0,255}), {

    // A
    CLAY_RECTANGLE(CLAY_ID("A"),
        CLAY_LAYOUT(.sizing = {CLAY_SIZING_PERCENT(.5), CLAY_SIZING_GROW()},
                    .padding = {16, 16},
                    .layoutDirection = CLAY_TOP_TO_BOTTOM,
                    .childGap = 16,),
        CLAY_RECTANGLE_CONFIG(.color = {0,0,255,255}), {
      CLAY_TEXT(CLAY_ID("TitleA"),
          CLAY_STRING("left"),
          CLAY_TEXT_CONFIG(.fontSize = 1, .textColor = {255, 255, 255, 255}));
      CLAY_SCROLL_CONTAINER(CLAY_ID("A-scroll"),
          CLAY_LAYOUT(.sizing = {CLAY_SIZING_GROW(), CLAY_SIZING_FIT()}),
          CLAY_SCROLL_CONFIG(.vertical = true), {
        CLAY_TEXT(CLAY_ID("txtA"),
            CLAY_STRING(lorem),
            CLAY_TEXT_CONFIG(
              .lineSpacing = 5,
              .fontSize = 3,
              .textColor = {255, 255, 255, 255}));
      });
    });

    // B
    CLAY_RECTANGLE(CLAY_ID("B"),
        CLAY_LAYOUT(.sizing = {CLAY_SIZING_PERCENT(.5), CLAY_SIZING_GROW()},
                    .padding = {16, 16},
                    .childGap = 32),
        CLAY_RECTANGLE_CONFIG(.color = {255,0,0,255}), {
      CLAY_TEXT(CLAY_ID("TitleB"),
          app_strfmt(app, "count %d", app->count),
          CLAY_TEXT_CONFIG(.fontSize = 1, .textColor = {255, 255, 255, 255}));
      CLAY_RECTANGLE(CLAY_ID("INCR"),
          CLAY_LAYOUT(.sizing = {CLAY_SIZING_FIT(40), CLAY_SIZING_FIT(20)},
                      .padding = {10, 10}),
          CLAY_RECTANGLE_CONFIG(.color = {190, 190, 190, 255}), {
        CLAY_TEXT(CLAY_ID("INCR-text"),
            app_strfmt(app, "increment", app->count),
            CLAY_TEXT_CONFIG(.fontSize = 1, .textColor = {0, 0, 0, 255}));
      });
    });
  });
}

static void render(GLFWwindow* window, appstate_t* app) {
  double start_time = glfwGetTime();
  double duration;
  int w = app->fb.w;
  int h = app->fb.h;

  allocator_bump_reset(&app->bump);
  Clay_BeginLayout(w, h);
  buildTree(w, h, app);
  Clay_RenderCommandArray renderCommands = Clay_EndLayout(w, h);

  Olivec_Canvas canvas = olivec_canvas(app->fb.buf, w, h, w);

  bool scissor = false;
  Clay_BoundingBox scissor_box = {0};
  Olivec_Canvas subcanvas = {0};

  for (int i = 0; i < renderCommands.length; i++) {
    Clay_RenderCommand *renderCommand = &renderCommands.internalArray[i];
    switch (renderCommand->commandType) {
      case CLAY_RENDER_COMMAND_TYPE_RECTANGLE: {
        Clay_BoundingBox box = renderCommand->boundingBox;
        Clay_RectangleElementConfig* config = renderCommand->config.rectangleElementConfig;
        Clay_Color color = renderCommand->config.rectangleElementConfig->color;
        olivec_rect(canvas,
            box.x, box.y,
            box.width, box.height,
            convertColor(config->color));
      } break;
      case CLAY_RENDER_COMMAND_TYPE_TEXT: {
        Clay_BoundingBox box = renderCommand->boundingBox;
        Clay_String txt = renderCommand->text;
        Clay_TextElementConfig* config = renderCommand->config.textElementConfig;

        if (scissor) {
          olivec_text(subcanvas,
              txt.chars, txt.length,
              box.x - scissor_box.x, box.y - scissor_box.y,
              olivec_default_font,
              config->fontSize,
              convertColor(config->textColor));
        } else {
          olivec_text(canvas,
              txt.chars, txt.length,
              box.x, box.y,
              olivec_default_font,
              config->fontSize,
              convertColor(config->textColor));
        }
      } break;
      case CLAY_RENDER_COMMAND_TYPE_SCISSOR_START: {
        scissor_box = renderCommand->boundingBox;
        subcanvas = olivec_subcanvas(canvas, scissor_box.x, scissor_box.y, scissor_box.width, scissor_box.height);
        scissor = true;
      } break;
      case CLAY_RENDER_COMMAND_TYPE_SCISSOR_END: {
        scissor = false;
      } break;
      case CLAY_RENDER_COMMAND_TYPE_BORDER:
      case CLAY_RENDER_COMMAND_TYPE_IMAGE:
      case CLAY_RENDER_COMMAND_TYPE_CUSTOM: {
        LOG("render %d", renderCommand->commandType);
      } break;
    }
  }

  app->last_render = glfwGetTime();
  nativefb_paint(&app->platform, &app->fb);
  duration = app->last_render - start_time;
  LOG("rendered in %dms", (int)(duration * 1000.0));
}

static inline Clay_Dimensions MeasureText(
    Clay_String* text,
    // Clay_TextElementConfig contains members such as fontId, fontSize, letterSpacing etc
    Clay_TextElementConfig* config) {
  int len = text->length;
  float w = len * (config->fontSize * OLIVEC_DEFAULT_FONT_WIDTH) + config->letterSpacing;
  float h = (config->fontSize * OLIVEC_DEFAULT_FONT_HEIGHT) + config->lineSpacing;
  return (Clay_Dimensions){.width = w, .height = h};
}

int main(int argc, char** argv) {
  LOG("hello");
  LOG("app init");
  int w = 640;
  int h = 480;
  appstate_t app = {0};
  app.fb.buf = malloc(w * h * sizeof(uint32_t));
  app.fb.w = w;
  app.fb.h = h;
  app.bump.buf = malloc(1 << 20);
  app.bump.len = 1 << 20;
  app.frame_alloc = allocator_bump(&app.bump);
  app.needs_render = true;

  LOG("GLFW init");
  CHECK(glfwInit());
  glfwSetErrorCallback(error_callback_glfw);
  glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);
  glfwWindowHint(GLFW_VISIBLE, GLFW_TRUE);
  glfwWindowHint(GLFW_DECORATED, GLFW_TRUE);
  glfwWindowHint(GLFW_FOCUSED, GLFW_TRUE);
  glfwWindowHint(GLFW_FOCUS_ON_SHOW, GLFW_TRUE);
  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);

  GLFWwindow* window = glfwCreateWindow(w, h, "demo", NULL, NULL);
  CHECK(window);
  nativefb_init(&app.platform, window, &app.fb);

  glfwSetWindowUserPointer(window, &app);
  glfwSetWindowCloseCallback(window, close_callback_glfw);
  glfwSetWindowSizeCallback(window, winsize_callback);
  glfwSetFramebufferSizeCallback(window, fbsize_callback);
  glfwSetWindowContentScaleCallback(window, window_content_scale_callback);
  glfwSetWindowFocusCallback(window, window_focus_callback);
  // Input callbacks
  // https://www.glfw.org/docs/latest/group__input.html
  glfwSetKeyCallback(window, key_callback);
  glfwSetCharCallback(window, character_callback);
  glfwSetCursorPosCallback(window, cursor_position_callback);
  glfwSetCursorEnterCallback(window, cursor_enter_callback);
  glfwSetMouseButtonCallback(window, mouse_button_callback);
  glfwSetScrollCallback(window, scroll_callback);
  glfwSetDropCallback(window, drop_callback);

  // Clay init
  LOG("Clay init");
  uint64_t totalMemorySize = CLAY_MAX_ELEMENT_COUNT * 1 << 10;
  char* clay_memblock = malloc(totalMemorySize);
  Clay_Arena arena = Clay_CreateArenaWithCapacityAndMemory(
      totalMemorySize, clay_memblock);
  Clay_SetMeasureTextFunction(MeasureText);
  Clay_Initialize(arena);

  LOG("UI loop...");
  while (!glfwWindowShouldClose(window)) {
    if (app.needs_render) {
      render(window, &app);
      app.needs_render = false;
    }
    // Wake from other thread with glfwPostEmptyEvent()
    glfwWaitEvents();
  }

  free(clay_memblock);
  nativefb_deinit(&app.platform);
  glfwDestroyWindow(window);
  glfwTerminate();
  appstate_free(&app);
  LOG("goodbye");
}
