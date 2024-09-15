#ifdef CBASE_ABI_ANDROID

#include <string.h>

#include "nativefb.h"

#include <android/native_window.h>

void nativefb_init(native_platform_t* p, void* w, framebuffer_t* fb) {
  p->window = w;
}

void nativefb_resize(native_platform_t* p, framebuffer_t* fb) {}
void nativefb_deinit(native_platform_t* p) {}
void nativefb_trigger_refresh(native_platform_t* p, framebuffer_t* fb) {}

void nativefb_paint(native_platform_t* p, framebuffer_t* fb) {
  u32 w = fb->w;
  u32 h = fb->h;

  ANativeWindow_Buffer buffer;
  ARect bounds;
  bounds.left = 0;
  bounds.top = 0;
  bounds.right = w;
  bounds.bottom = h;
  if (ANativeWindow_lock(p->window, &buffer, &bounds) == 0) {
    u32* line = (u32*)buffer.bits;
    for (int y = 0; y < h; y++) {
        memcpy(line, fb->buf + y * w, w * sizeof(u32));
        line += buffer.stride;
    }

    ANativeWindow_unlockAndPost(p->window);
  }
}


#endif
