#ifndef GLFW_NATIVEFB_H_
#define GLFW_NATIVEFB_H_

#include "GLFW/glfw3.h"

#if defined(__APPLE__)
#include "nativefb/nativefb_mac.h"
#elif defined(_WIN32)
#include "nativefb/nativefb_win32.h"
#else
#include "nativefb/nativefb_linux.h"
#endif

typedef struct {
  uint8_t r, g, b, a;
} framebuffer_px_t;

typedef struct {
  framebuffer_px_t* buf;
  uint32_t w;
  uint32_t h;
} framebuffer_t;
#define framebuffer_pixel(f, x, y) ((f).buf[((y) * (f).w) + (x)])

void nativefb_init(native_platform_t* p, GLFWwindow* w, framebuffer_t* fb);
void nativefb_deinit(native_platform_t* p);
void nativefb_resize(native_platform_t* p, framebuffer_t* fb);
void nativefb_paint(native_platform_t* p, framebuffer_t* fb);

#endif
