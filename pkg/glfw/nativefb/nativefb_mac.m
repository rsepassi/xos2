#ifdef __APPLE__

#include "nativefb.h"

void nativefb_init(native_platform_t* p, GLFWwindow* w, framebuffer_t* fb) {
  p->wnd = glfwGetCocoaWindow(w);
  p->view = glfwGetCocoaView(w);
}

void nativefb_resize(native_platform_t* p, framebuffer_t* fb) {}

void nativefb_deinit(native_platform_t* p) {}

void nativefb_paint(native_platform_t* p, framebuffer_t* fb) {
  // [p->view setNeedsDisplay:YES];

  CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, fb->buf, fb->w * fb->h * sizeof(uint32_t), NULL);
  CGImageRef img = CGImageCreate(fb->w, fb->h, 8, 32, fb->w * 4, space,
                                 kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                                 provider, NULL, false, kCGRenderingIntentDefault);
  CGColorSpaceRelease(space);
  CGDataProviderRelease(provider);
  CGContextDrawImage(context, CGRectMake(0, 0, fb->w, fb->h), img);
  CGImageRelease(img);
}

#endif
