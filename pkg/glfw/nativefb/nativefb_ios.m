#ifdef CBASE_OS_IOS

#include "nativefb.h"
#include "base/log.h"

#import <UIKit/UIKit.h>

@interface NativefbView : UIView
@property framebuffer_t* fb;
@end

@implementation NativefbView
- (void)drawRect:(CGRect)rect {
  framebuffer_t* fb = self.fb;
  DLOG("NativefbView::drawRect %p", fb);

  uint32_t w = fb->w;
  uint32_t h = fb->h;

  CGContextRef context = UIGraphicsGetCurrentContext();
  CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, fb->buf, w * h * sizeof(uint32_t), NULL);
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGImageRef img = CGImageCreate(w, h, 8, 32, w * 4, space,
                                 kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                                 provider, NULL, false, kCGRenderingIntentDefault);
  CGContextDrawImage(context, CGRectMake(0, 0, w, h), img);
  CGImageRelease(img);
  CGColorSpaceRelease(space);
  CGDataProviderRelease(provider);
}

- (void)drawFb:(framebuffer_t *)fb {
  _fb = fb;
  [self setNeedsDisplay];
}
@end

void nativefb_init(native_platform_t* p, void* w, framebuffer_t* fb) {
  UIView* view = w;
  p->view = [[NativefbView alloc] initWithFrame:[view bounds]];
  [view addSubview:p->view];
}

void nativefb_deinit(native_platform_t* p) {}
void nativefb_resize(native_platform_t* p, framebuffer_t* fb) {}
void nativefb_paint(native_platform_t* p, framebuffer_t* fb) {}

void nativefb_trigger_refresh(native_platform_t* p, framebuffer_t* fb) {
  DLOG("nativefb_trigger_refresh");
  [p->view drawFb:fb];
}

#endif
