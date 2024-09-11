#include "text.h"

float text_measure(str_t s, hb_font_t* font, hb_buffer_t* buf) {
  hb_buffer_set_length(buf, 0);
  hb_buffer_add_utf8(buf, s.bytes, s.len, 0, s.len);
  hb_shape(font, buf, NULL, 0);

  unsigned int glyph_count;
  hb_glyph_info_t *glyph_info = hb_buffer_get_glyph_infos(buf, &glyph_count);
  hb_glyph_position_t *glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);
  float advance = 0;
  for (unsigned int i = 0; i < glyph_count; i++) {
    advance += glyph_pos[i].x_advance >> 6;
  }
  return advance;
}

float text_line_height(FT_Face font) {
  FT_Size_Metrics* metrics = &font->size->metrics;
  float ascender = metrics->ascender >> 6;
  float descender = metrics->descender >> 6;
  float lineHeight = ascender - descender;

  float height = metrics->height >> 6;
  if (lineHeight < height) lineHeight = height;

  return lineHeight;
}

hb_buffer_t* text_english_buf() {
  hb_buffer_t* buf = hb_buffer_create();
  hb_buffer_set_direction(buf, HB_DIRECTION_LTR);
  hb_buffer_set_script(buf, HB_SCRIPT_LATIN);
  hb_buffer_set_language(buf, hb_language_from_string("en", -1));
  return buf;
}

text_glyph_info_t text_shape(str_t s, hb_font_t* font, hb_buffer_t* buf) {
  hb_buffer_set_length(buf, 0);
  hb_buffer_add_utf8(buf, s.bytes, s.len, 0, s.len);
  hb_shape(font, buf, NULL, 0);
  unsigned int glyph_count;
  hb_glyph_info_t *glyph_info = hb_buffer_get_glyph_infos(buf, &glyph_count);
  hb_glyph_position_t *glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);
  return (text_glyph_info_t){
    .n = glyph_count,
    .info = glyph_info,
    .pos = glyph_pos,
  };
}

KHASH_INIT(mTextAtlasInfo,
    uint32_t, text_atlas_entry_t, 1,
    kh_int_hash_func, kh_int_hash_equal);

text_atlas_t text_atlas_init(uint8_t* buf, uint32_t w, uint32_t h) {
  return (text_atlas_t){
    .buf = buf,
    .w = w,
    .h = h,
    .info = kh_init(mTextAtlasInfo),
  };
}

void text_atlas_deinit(text_atlas_t* a) {
  kh_destroy(mTextAtlasInfo, (khash_t(mTextAtlasInfo)*)a->info);
}

text_atlas_entry_t* text_atlas_get(text_atlas_t* a, uint32_t glyph_index) {
  khash_t(mTextAtlasInfo)* info = a->info;
  khiter_t iter = kh_get(mTextAtlasInfo, info, glyph_index);
  if (iter == kh_end(info)) return NULL;
  return &kh_val(info, iter);
}

int text_atlas_put(
    text_atlas_t* a,
    uint32_t glyph_index,
    text_bitmap_t bm,
    text_atlas_entry_info_t entry,
    text_atlas_entry_t** out) {
  if (bm.h > a->h) return 1;
  if (a->xoffset + bm.w > a->w) return 1;

  uint32_t offset = a->xoffset;
  for (int i = 0; i < bm.h; ++i) {
    for (int j = 0; j < bm.w; ++j) {
      a->buf[i * a->w + offset + j] = bm.buf[i * bm.row_stride + j];
    }
  }
  a->xoffset += bm.w;

  khash_t(mTextAtlasInfo)* info = a->info;
  int ret;
  khiter_t key = kh_put(mTextAtlasInfo, info, glyph_index, &ret);
  kh_val(info, key) = (text_atlas_entry_t){
    .info = entry,
    .box = (text_box_t){
      .x = offset,
      .y = 0,
      .w = bm.w,
      .h = bm.h,
    },
  };
  *out = &kh_val(info, key);
  return 0;
}

text_bitmap_t text_atlas_bitmap(text_atlas_t* a, text_box_t box) {
  return (text_bitmap_t){
    .buf = &a->buf[box.y * a->w + box.x],
    .w = box.w,
    .h = box.h,
    .row_stride = a->w,
  };
}

int text_atlas_render_glyph(
    FT_Face face,
    uint32_t glyph_index,
    text_atlas_entry_info_t* info,
    text_bitmap_t* bm) {
  if (FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT) != 0) return 1;
  if (FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL) != 0) return 1;
  FT_Bitmap bitmap = face->glyph->bitmap;
  *bm = (text_bitmap_t){
    .h = bitmap.rows,
    .w = bitmap.width,
    .buf = bitmap.buffer,
    .row_stride = bitmap.pitch,
  };
  int32_t dx = face->glyph->metrics.horiBearingX >> 6;
  int32_t dy = (face->size->metrics.ascender >> 6) -
    (face->glyph->metrics.horiBearingY >> 6);
  *info = (text_atlas_entry_info_t){
    .dx = dx,
    .dy = dy,
  };
  return 0;
}

