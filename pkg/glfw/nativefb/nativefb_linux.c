#if defined(CBASE_OS_LINUX) && !defined(CBASE_ABI_ANDROID)

#include "nativefb.h"

static XImage* new_image(native_platform_t* p, framebuffer_t* fb) {
  return XCreateImage(
      p->display,
      DefaultVisual(p->display, 0),
      24,
      ZPixmap,
      0,
      (char*)fb->buf,
      fb->w,
      fb->h,
      32,
      0);
}

void nativefb_init(native_platform_t* p, void* w, framebuffer_t* fb) {
  p->display = 	glfwGetX11Display();
  p->window = glfwGetX11Window(w);
  p->gc = XCreateGC(p->display, p->window, 0, 0);
  p->img = new_image(p, fb);
}

void nativefb_resize(native_platform_t* p, framebuffer_t* fb) {
  p->img = new_image(p, fb);
}

void nativefb_deinit(native_platform_t* p) {
  XFreeGC(p->display, p->gc);
  XDestroyImage(p->img);
  p->img = NULL;
}

void nativefb_paint(native_platform_t* p, framebuffer_t* fb) {
  XPutImage(
      p->display,
      p->window,
      p->gc,
      p->img,
      0,
      0,
      0,
      0,
      fb->w,
      fb->h);
  XFlush(p->display);
}

void nativefb_trigger_refresh(native_platform_t* p, framebuffer_t* fb) {
  XEvent e = {0};
  e.type = Expose;
  e.xexpose.window = p->window;
  XSendEvent(p->display, p->window, False, ExposureMask, &e);
  XFlush(p->display);
}

#endif
