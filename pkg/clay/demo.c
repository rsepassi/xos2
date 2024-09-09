#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>

#include "base/log.h"
#include "base/ascii.h"
#include "base/allocator.h"
#include "base/fmt.h"
#include "clay.h"
#include "fenster.h"
#include "olive.h"

static char lorem[] = "lorem ipsum is simply dummy text of the printing and typesetting industry. lorem ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. it has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. it was popularised in the 1960s with the release of letraset sheets containing lorem ipsum passages, and more recently with desktop publishing software like aldus pagemaker including versions of lorem ipsum.";

typedef struct {
  int count;

  allocator_bump_t bump;
  allocator_t frame_alloc;
} appstate_t;

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
    CLAY_RECTANGLE(CLAY_ID("A"),
        CLAY_LAYOUT(.sizing = {CLAY_SIZING_PERCENT(.5), CLAY_SIZING_GROW()},
                    .padding = {16, 16},
                    .layoutDirection = CLAY_TOP_TO_BOTTOM,
                    .childGap = 16,),
        CLAY_RECTANGLE_CONFIG(.color = {0,0,255,255}), {
      CLAY_TEXT(CLAY_ID("TitleA"),
          CLAY_STRING("left"),
          CLAY_TEXT_CONFIG(.fontSize = 1, .textColor = {255, 255, 255, 255}));
      CLAY_TEXT(CLAY_ID("txtA"),
          CLAY_STRING(lorem),
          CLAY_TEXT_CONFIG(
            .lineSpacing = 5,
            .fontSize = 1,
            .textColor = {255, 255, 255, 255}));
    });
    CLAY_RECTANGLE(CLAY_ID("B"),
        CLAY_LAYOUT(.sizing = {CLAY_SIZING_PERCENT(.5), CLAY_SIZING_GROW()},
                    .padding = {16, 16},
                    .childGap = 32),
        CLAY_RECTANGLE_CONFIG(.color = {255,0,0,255}), {

        CLAY_TEXT(CLAY_ID("TitleB"),
            app_strfmt(app, "count %d", app->count),
            CLAY_TEXT_CONFIG(.fontSize = 1, .textColor = {255, 255, 255, 255}));
    });
  });
}

static void repaint(fenster* f, appstate_t* app) {
  LOG("begin layout");
  allocator_bump_reset(&app->bump);
  Clay_BeginLayout(f->width, f->height);
  buildTree(f->width, f->height, app);
  LOG("end layout");
  Clay_RenderCommandArray renderCommands =
    Clay_EndLayout(f->width, f->height);

  Olivec_Canvas canvas = olivec_canvas(f->buf, f->width, f->height, f->width);
  for (int i = 0; i < renderCommands.length; i++) {
    Clay_RenderCommand *renderCommand = &renderCommands.internalArray[i];
    switch (renderCommand->commandType) {
      case CLAY_RENDER_COMMAND_TYPE_RECTANGLE: {
        Clay_BoundingBox box = renderCommand->boundingBox;
        Clay_RectangleElementConfig* config = renderCommand->config.rectangleElementConfig;
        Clay_Color color = renderCommand->config.rectangleElementConfig->color;
        LOG("render rect xy=(%.1f, %.1f), wh=(%.1f, %.1f), color=(%.1f, %.1f, %.1f, %.1f)",
            box.x, box.y,
            box.width, box.height,
            config->color.r, config->color.g, config->color.b, config->color.a);
        olivec_rect(canvas,
            box.x, box.y,
            box.width, box.height,
            convertColor(config->color));
      } break;
      case CLAY_RENDER_COMMAND_TYPE_TEXT: {
        Clay_BoundingBox box = renderCommand->boundingBox;
        Clay_String txt = renderCommand->text;
        Clay_TextElementConfig* config = renderCommand->config.textElementConfig;
        LOG("render txt");
        olivec_text(canvas,
            txt.chars, txt.length,
            box.x, box.y,
            olivec_default_font,
            config->fontSize,
            convertColor(config->textColor));
      } break;
      default: {
        LOG("render %d", renderCommand->commandType);
      } break;
      // case CLAY_RENDER_COMMAND_TYPE_BORDER:
      // case CLAY_RENDER_COMMAND_TYPE_IMAGE:
      // case CLAY_RENDER_COMMAND_TYPE_SCISSOR_START:
      // case CLAY_RENDER_COMMAND_TYPE_SCISSOR_END:
      // case CLAY_RENDER_COMMAND_TYPE_CUSTOM:
    }
  }
  fenster_paint(f);
}

static inline void* Realloc(void *user_ctx, void *ptr, size_t new_size) {
  return realloc(ptr, new_size);
}

void process_event(fenster* f, appstate_t* app) {
  // Scan keys
  for (int i = 0; i < 128; ++i) {
    if (f->keys[i] == FENSTER_KEY_DOWN) {
      fprintf(stderr, "keydown %d", i);
      if (fenster_mod(f, CTRL)) fprintf(stderr, " ctrl");
      if (fenster_mod(f, SHIFT)) fprintf(stderr, " shift");
      if (fenster_mod(f, ALT)) fprintf(stderr, " alt");
      if (fenster_mod(f, META)) fprintf(stderr, " meta");
      fprintf(stderr, "\n");
      f->keys[i] = FENSTER_KEY_NONE;

      // Adjust case based on shift
      if (i >= ASCII_A && i <= ASCII_Z) {
        if (!fenster_mod(f, SHIFT)) {
          i += (ASCII_a - ASCII_A);
        }
      }

      if (i == ASCII_z) {
        LOG("count=%d", app->count);
        app->count += 1;
        repaint(f, app);
      }
    } else if (f->keys[i] == FENSTER_KEY_UP) {
      fprintf(stderr, "keyup %d\n", i);
      f->keys[i] = FENSTER_KEY_NONE;
    }
  }

  // Scan mouse
  if (f->mouse != FENSTER_MOUSE_NONE) {
    fprintf(stderr, "mouse %d (%d, %d)\n", f->mouse, f->x, f->y);
    f->mouse = FENSTER_MOUSE_NONE;
  }

  // Resize
  if (f->resized) {
    f->resized = false;
    repaint(f, app);
  }

  Clay_SetPointerPosition((Clay_Vector2){f->x, f->y});
}

// Example measure text function
static inline Clay_Dimensions MeasureText(
    // Note: Clay_String->chars is not guaranteed to be null terminated
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
  appstate_t app = {0};
  app.bump.buf = malloc(1 << 20);
  app.bump.len = 1 << 20;
  app.frame_alloc = allocator_bump(&app.bump);

  fenster f = {
    .title = "demo",
    .width = 600,
    .height = 600,
    .buf = Realloc(NULL, NULL, 600 * 600 * sizeof(uint32_t)),
    .realloc = Realloc,
  };

  uint64_t totalMemorySize = CLAY_MAX_ELEMENT_COUNT * 1 << 10;
  char* memblock = Realloc(NULL, NULL, totalMemorySize);
  Clay_Arena arena = Clay_CreateArenaWithCapacityAndMemory(
      totalMemorySize, memblock);
  Clay_Initialize(arena);
  Clay_SetMeasureTextFunction(MeasureText);

  fenster_open(&f);
  repaint(&f, &app);

  LOG("loop...");
  while (fenster_loop(&f) == 0) process_event(&f, &app);

  fenster_close(&f);
  LOG("goodbye");
}
