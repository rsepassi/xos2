#include "nativefb.h"

framebuffer_px_t framebuffer_alpha_blend(framebuffer_px_t x, framebuffer_px_t y) {
  if (y.a <= 0) return x;

  float xa = x.a / 255.;
  float ya = y.a / 255.;

  float r = ya * y.r + (1. - ya) * x.r * xa;
  float g = ya * y.g + (1. - ya) * x.g * xa;
  float b = ya * y.b + (1. - ya) * x.b * xa;
  float a = ya +  xa * (1. - ya);

  return (framebuffer_px_t){
    .r = r,
    .g = g,
    .b = b,
    .a = a * 255.,
  };
}
