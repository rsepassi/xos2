#ifndef TEXT_H_
#define TEXT_H_

#include "ft2build.h"
#include FT_FREETYPE_H
#include "harfbuzz/hb.h"
#include "harfbuzz/hb-ft.h"

#include "base/str.h"
#include "base/khash.h"

float text_measure(str_t s, hb_font_t* font, hb_buffer_t* buf);
inline float text_line_height(FT_Face);
hb_buffer_t* text_english_buf(void);

typedef struct {
  unsigned int n;
  hb_glyph_info_t* info;
  hb_glyph_position_t* pos;
} text_glyph_info_t;
text_glyph_info_t text_shape(str_t s, hb_font_t* font, hb_buffer_t* buf);

typedef struct {
  uint8_t* buf;
  uint32_t h, w;
  int32_t row_stride;
} text_bitmap_t;
typedef struct {
  uint32_t x, y, w, h;
} text_box_t;
typedef struct {
  int32_t dx;
  int32_t dy;
} text_atlas_entry_info_t;
typedef struct {
  text_atlas_entry_info_t info;
  text_box_t box;
} text_atlas_entry_t;
typedef void text_atlas_map_t;
typedef struct {
  uint8_t* buf;
  uint32_t w, h;
  text_atlas_map_t* info;
  uint32_t xoffset;
} text_atlas_t;

text_atlas_t text_atlas_init(uint8_t* buf, uint32_t w, uint32_t h);
void text_atlas_deinit(text_atlas_t*);
text_atlas_entry_t* text_atlas_get(text_atlas_t*, uint32_t glyph_index);
int text_atlas_put(text_atlas_t*, uint32_t glyph_index,
    text_bitmap_t, text_atlas_entry_info_t, text_atlas_entry_t**);
text_bitmap_t text_atlas_bitmap(text_atlas_t*, text_box_t);
int text_atlas_render_glyph(
    FT_Face face,
    uint32_t glyph_index,
    text_atlas_entry_info_t* info,
    text_bitmap_t* bm);

#endif
