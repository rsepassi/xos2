#ifndef GLFW_NATIVEFB_H_
#define GLFW_NATIVEFB_H_

#ifdef CBASE_ABI_ANDROID
#include "nativefb/nativefb_android.h"
#elif defined(__APPLE__)
#include "nativefb/nativefb_mac.h"
#elif defined(_WIN32)
#include "nativefb/nativefb_win32.h"
#else
#include "nativefb/nativefb_linux.h"
#endif

#include "base/stdtypes.h"

typedef struct {
  u8 r, g, b, a;
} framebuffer_px_t;

typedef struct {
  framebuffer_px_t* buf;
  u32 w;
  u32 h;
} framebuffer_t;
#define framebuffer_pixel(f, x, y) ((f).buf[((y) * (f).w) + (x)])

void nativefb_init(native_platform_t* p, void* w, framebuffer_t* fb);
void nativefb_deinit(native_platform_t* p);
void nativefb_resize(native_platform_t* p, framebuffer_t* fb);
void nativefb_trigger_refresh(native_platform_t* p, framebuffer_t* fb);
void nativefb_paint(native_platform_t* p, framebuffer_t* fb);
framebuffer_px_t framebuffer_alpha_blend(framebuffer_px_t x, framebuffer_px_t y);

#endif
