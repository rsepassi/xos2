#include <stdlib.h>

#include "app.h"

#include "base/log.h"
#include "base/file.h"

typedef struct app_s app_t;
#define CLAY_MAX_ELEMENT_COUNT 8192
#define CLAY_EXTEND_CONFIG_TEXT \
  app_t* app;
#include "clay.h"

#include "text.h"
#include "archive.h"
#include "olive.h"
#include "epub.h"

typedef struct {
  FT_Library ft_library;
  str_t font_data;
  FT_Face ft_face;
  hb_font_t* hb_font;
  hb_buffer_t* hb_buf;
  float lineh;
  text_atlas_t atlas;
} text_t;

typedef struct {
  u32 section;
  bool dirty;
} view_state_t;

struct app_s {
  epub_t epub;
  view_state_t view;
  text_t txt;
  app_state_t* state;
};

static inline Clay_Dimensions measure_text(
    Clay_String* text,
    Clay_TextElementConfig* config) {
  app_t* app = config->app;
  float width = text_measure(
      (str_t){.bytes = text->chars, .len = text->length},
      app->txt.hb_font, app->txt.hb_buf);
  return (Clay_Dimensions){.width = width, .height = app->txt.lineh};
}

void text_init(text_t* txt) {
  int font_size = 16;
  str_t font_data = fs_resource_read(cstr("EBGaramond-Regular.ttf"));
  FT_Library ft_library;
  CHECK(!FT_Init_FreeType(&ft_library));
  CHECK(!FT_New_Memory_Face(ft_library, (const FT_Byte*)font_data.bytes, font_data.len, 0, &txt->ft_face));
  FT_Set_Char_Size(txt->ft_face, 0, font_size << 6, 72, 72);
  txt->lineh = text_line_height(txt->ft_face);
  txt->hb_font = hb_ft_font_create(txt->ft_face, NULL);
  txt->hb_buf = text_english_buf();
  int atlash = (int)(txt->lineh + 0.5);
  int atlasw = (1 << 20) / atlash;
  txt->atlas = text_atlas_init(malloc(atlash * atlasw), atlasw, atlash);
}

static inline uint32_t convertColor(Clay_Color color) {
  uint8_t out[4];
  out[0] = (uint8_t)color.r;
  out[1] = (uint8_t)color.g;
  out[2] = (uint8_t)color.b;
  out[3] = (uint8_t)color.a;
  return *((uint32_t*)out);
}

static Clay_String claystr(str_t s) {
  return (Clay_String){.length = s.len, .chars = s.bytes};
}

static void build_view_tree(app_t* app) {
  CLAY_RECTANGLE(CLAY_ID("OuterContainer"),
      CLAY_LAYOUT(.sizing = {CLAY_SIZING_GROW(), CLAY_SIZING_GROW()},
                  .padding = {16, 16},
                  .layoutDirection = CLAY_TOP_TO_BOTTOM,
                  .childGap = 16),
      CLAY_RECTANGLE_CONFIG(.color = {255,255,255,255}), {

    CLAY_SCROLL_CONTAINER(CLAY_ID("TXT-SCROLL"),
        CLAY_LAYOUT(.sizing = {CLAY_SIZING_GROW(), CLAY_SIZING_FIT()},
                    .layoutDirection = CLAY_TOP_TO_BOTTOM),
        CLAY_SCROLL_CONFIG(.vertical = true), {

      // Our current section
      epub_section_t* section = list_get(epub_section_t,
          &app->epub.sections, app->view.section);

      // Print out the nodes
      epub_node_t* n;
      list_foreach(epub_node_t, &section->nodes, n, {
        CLAY_TEXT(CLAY_ID("txtA"),
            claystr(str_from_list(n->contents)),
            CLAY_TEXT_CONFIG(
              .textColor = {0, 0, 0, 0},
              .app = app));
      });

    });
  });  // OuterContainer
}

static void render(void* ctx) {
  app_t* app = (app_t*)ctx;
  u16 h = app->state->size.h;
  u16 w = app->state->size.w;
  LOG("render (%d, %d)", w, h);

  Clay_BeginLayout(w, h);
  build_view_tree(app);
  LOG("view tree done");
  Clay_RenderCommandArray renderCommands = Clay_EndLayout(w, h);
  LOG("layout done");

  framebuffer_t* fb = app->state->fb;
  Olivec_Canvas canvas = olivec_canvas((uint32_t*)fb->buf, w, h, w);

  bool scissor = false;
  Clay_BoundingBox scissor_box = {0};

  for (int i = 0; i < renderCommands.length; i++) {
    Clay_RenderCommand *renderCommand = &renderCommands.internalArray[i];
    switch (renderCommand->commandType) {
      case CLAY_RENDER_COMMAND_TYPE_RECTANGLE: {
        Clay_BoundingBox box = renderCommand->boundingBox;
        Clay_RectangleElementConfig* config = renderCommand->config.rectangleElementConfig;
        Clay_Color color = renderCommand->config.rectangleElementConfig->color;
        olivec_fill(olivec_subcanvas(canvas,
            box.x, box.y,
            box.width, box.height),
            convertColor(config->color));
      } break;
      case CLAY_RENDER_COMMAND_TYPE_TEXT: {
        Clay_BoundingBox box = renderCommand->boundingBox;
        Clay_String* text = &renderCommand->text;
        Clay_TextElementConfig* config = renderCommand->config.textElementConfig;

        // Shape
        text_glyph_info_t shaped = text_shape(
            (str_t){.bytes = text->chars, .len = text->length},
            app->txt.hb_font, app->txt.hb_buf);

        // Render
        float cursor_x = box.x;
        for (unsigned int i = 0; i < shaped.n; ++i) {
          hb_codepoint_t glyph_index = shaped.info[i].codepoint;

          // Render bitmap
          text_atlas_entry_t* entry = text_atlas_get(&app->txt.atlas, glyph_index);
          if (entry == NULL) {
            text_bitmap_t bitmap;
            text_atlas_entry_info_t entry_info;
            CHECK(text_atlas_render_glyph(app->txt.ft_face, glyph_index, &entry_info, &bitmap) == 0);
            CHECK(text_atlas_put(&app->txt.atlas, glyph_index, bitmap, entry_info, &entry) == 0);
          }

          // Top-left corner of the glyph in the framebuffer
          float glyph_x = cursor_x +
            entry->info.dx +
            (shaped.pos[i].x_offset >> 6);
          float glyph_y = box.y +
            entry->info.dy -
            (shaped.pos[i].y_offset >> 6);

          text_bitmap_t bitmap = text_atlas_bitmap(&app->txt.atlas, entry->box);

          for (int j = 0; j < bitmap.h; ++j) {
            for (int k = 0; k < bitmap.w; ++k) {
              int x = glyph_x + k;
              int y = glyph_y + j;

              // Bounds check
              bool inbounds = true;
              if (scissor) {
                if (x < scissor_box.x
                    || x >= (scissor_box.x + scissor_box.width)
                    || y < scissor_box.y
                    || y >= (scissor_box.y + scissor_box.height))
                  inbounds = false;
              } else {
                if (x < 0
                    || x >= canvas.width
                    || y < 0
                    || y >= canvas.height)
                  inbounds = false;
              }
              if (!inbounds) continue;

              framebuffer_px_t new = {
                .r = config->textColor.r,
                .g = config->textColor.g,
                .b = config->textColor.b,
                .a = bitmap.buf[j * bitmap.row_stride + k],
              };
              framebuffer_px_t current = framebuffer_pixel(*fb, x, y);
              framebuffer_pixel(*fb, x, y) =
                framebuffer_alpha_blend(current, new);
            }
          }

          cursor_x += shaped.pos[i].x_advance >> 6;
        }
      } break;
      case CLAY_RENDER_COMMAND_TYPE_SCISSOR_START: {
        scissor_box = renderCommand->boundingBox;
        scissor = true;
      } break;
      case CLAY_RENDER_COMMAND_TYPE_SCISSOR_END: {
        scissor = false;
      } break;
      case CLAY_RENDER_COMMAND_TYPE_NONE:
      case CLAY_RENDER_COMMAND_TYPE_BORDER:
      case CLAY_RENDER_COMMAND_TYPE_IMAGE:
      case CLAY_RENDER_COMMAND_TYPE_CUSTOM: {
        LOG("render %d", renderCommand->commandType);
      } break;
    }
  }
}

static void on_event(void* userdata, app_event_t* ev) {
  app_t* app = (app_t*)userdata;

  u32 key;

  switch (ev->type) {
    case AppEventMouseMotion:
      Clay_SetPointerPosition((Clay_Vector2){
          ev->data.pos.x,
          ev->data.pos.y,
      });
      break;
    case AppEventKey:
      key = ev->data.key.key;
      switch (key) {
        case AppKey_ESCAPE:
          app_quit(app->state);
          break;
        case AppKey_LEFT:
          if ((ev->data.key.action == AppKeyPress || ev->data.key.action == AppKeyRepeat) &&
              app->view.section > 0) {
            app->view.section -= 1;
            app->view.dirty = true;
          }
          break;
        case AppKey_RIGHT:
          if ((ev->data.key.action == AppKeyPress || ev->data.key.action == AppKeyRepeat) && app->view.section < (app->epub.sections.len - 1)) {
            app->view.section += 1;
            app->view.dirty = true;
          }
          break;
        case AppKey_DOWN:
        case AppKey_UP:
          if ((ev->data.key.action == AppKeyPress ||
                ev->data.key.action == AppKeyRepeat)) {
            u64 delta = app_gettimems(app->state) - app->state->last_render_ms;
            float yoffset = key == AppKey_UP ? 5 : -5;
            Clay_UpdateScrollContainers(
                false,
                (Clay_Vector2){ 0, yoffset },
                (float)delta / 1000.0);
            app->view.dirty = true;
          }
          break;
        default:
          LOG("event key: %d", key);
          break;
      }
      break;
    default: {
      LOG("event %s", app_event_type_str(ev->type));
    }
  }

  if (app->view.dirty) {
    app_mark_needs_render(app->state);
    app->view.dirty = false;
  }
}

void app_init(app_state_t* state, app_init_t* init) {
  app_t* app  = calloc(1, sizeof(app_t));
  app->state = state;
  text_init(&app->txt);

  uint64_t totalMemorySize = CLAY_MAX_ELEMENT_COUNT * 1 << 10;
  char* clay_buf = malloc(totalMemorySize);
  Clay_Arena arena = Clay_CreateArenaWithCapacityAndMemory(
      totalMemorySize, clay_buf);
  Clay_SetMeasureTextFunction(measure_text);
  Clay_Initialize(arena);

  str_t epub_buf = fs_resource_read(cstr("communist-manifesto.epub"));

  struct archive *a = archive_read_new();
  archive_read_support_format_zip(a);
  CHECK(archive_read_open_memory(a, epub_buf.bytes, epub_buf.len) == ARCHIVE_OK);

  epub_init_from_archive(&app->epub, a);
  epub_parse_rootfile(&app->epub);
  epub_parse_toc(&app->epub);
  for (int i = 0; i < app->epub.spine.len; ++i) epub_parse_section(&app->epub, i);

  archive_read_free(a);
  free((void*)epub_buf.bytes);

  init->userdata = app;
  init->on_event = on_event;
  init->render = render;
  init->initial_size = (app_size2d_t){ .w = 1024, .h = 1024 };
  init->window_title = "eReader";
}
