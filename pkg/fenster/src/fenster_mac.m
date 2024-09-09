#include "fenster.h"
#import <Cocoa/Cocoa.h>

static const uint8_t FENSTER_KEYCODES[128] = {65,83,68,70,72,71,90,88,67,86,0,66,81,87,69,82,89,84,49,50,51,52,54,53,61,57,55,45,56,48,93,79,85,91,73,80,10,76,74,39,75,59,92,44,47,78,77,46,9,32,96,8,0,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,2,3,127,0,5,0,4,0,20,19,18,17,0};

@interface FensterDelegate : NSObject <NSWindowDelegate>
- (void)windowDidResize:(NSNotification *)notification;
@end

@interface FensterView : NSView
@end

@implementation FensterDelegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [NSApp terminate:nil];
    return YES;
}

- (void)windowDidResize:(NSNotification *)notification {
    NSWindow *window = notification.object;
    FensterView *view = (FensterView *)window.contentView;
    fenster *f = (__bridge fenster *)objc_getAssociatedObject(view, @selector(fenster));

    NSRect frame = [view frame];
    f->width = frame.size.width;
    f->height = frame.size.height;
    f->buf = f->realloc(
        f->user_ctx, f->buf, f->width * f->height * sizeof(uint32_t)); 

    [view setNeedsDisplay:YES];
}

@end

@implementation FensterView

- (void)drawRect:(NSRect)dirtyRect {
    fenster* f = (__bridge fenster*)objc_getAssociatedObject(self, @selector(fenster));
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, f->buf, f->width * f->height * sizeof(uint32_t), NULL);
    CGImageRef img = CGImageCreate(f->width, f->height, 8, 32, f->width * 4, space,
                                   kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                                   provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    CGContextDrawImage(context, CGRectMake(0, 0, f->width, f->height), img);
    CGImageRelease(img);
}

@end

int fenster_open(fenster* f) {
  f->buf = f->realloc(
      f->user_ctx, f->buf, f->width * f->height * sizeof(uint32_t)); 
  [NSApplication sharedApplication];
  [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
  
  f->platform.wnd = [[NSWindow alloc]
    initWithContentRect:NSMakeRect(0, 0, f->width, f->height)
    styleMask:
      NSWindowStyleMaskTitled |
      NSWindowStyleMaskClosable |
      NSWindowStyleMaskResizable |
      NSWindowStyleMaskMiniaturizable
    backing:NSBackingStoreBuffered
    defer:NO];

  FensterDelegate* delegate = [[FensterDelegate alloc] init];
  [f->platform.wnd setDelegate:delegate];
  
  FensterView* view = [[FensterView alloc] init];
  [f->platform.wnd setContentView:view];
  objc_setAssociatedObject(
      view,
      @selector(fenster),
      (__bridge id)f, OBJC_ASSOCIATION_ASSIGN);
  
  [f->platform.wnd setTitle:[NSString stringWithUTF8String:f->title]];
  [f->platform.wnd makeKeyAndOrderFront:nil];
  [f->platform.wnd center];
  [NSApp activateIgnoringOtherApps:YES];
  
  return 0;
}

void fenster_close(fenster* f) {
  [f->platform.wnd close];
  f->buf = f->realloc(f->user_ctx, f->buf, 0);
}

void fenster_paint(fenster* f) {
  [[f->platform.wnd contentView] setNeedsDisplay:YES];
}

int fenster_loop(fenster* f) {
  NSEvent* event = [NSApp
    nextEventMatchingMask:NSEventMaskAny
    untilDate:nil
    inMode:NSDefaultRunLoopMode
    dequeue:YES];
  if (!event) return 0;

  switch ([event type]) {
      case NSEventTypeLeftMouseDown:
          f->mouse = FENSTER_LMOUSE_DOWN;
          break;
      case NSEventTypeLeftMouseUp:
          f->mouse = FENSTER_LMOUSE_UP;
          break;
      case NSEventTypeRightMouseDown:
          f->mouse = FENSTER_RMOUSE_DOWN;
          break;
      case NSEventTypeRightMouseUp:
          f->mouse = FENSTER_RMOUSE_UP;
          break;
      case NSEventTypeMouseMoved:
      case NSEventTypeLeftMouseDragged: {
          NSPoint point = [event locationInWindow];
          f->x = (int)point.x;
          f->y = (int)(f->height - point.y);
          return 0;
      }
      case NSEventTypeKeyDown:
      case NSEventTypeKeyUp: {
          NSUInteger keyCode = [event keyCode];
          f->keys[keyCode < 127 ? FENSTER_KEYCODES[keyCode] : 0] =
              [event type] == NSEventTypeKeyDown ? 1 : -1;
          NSUInteger modifiers = [event modifierFlags] >> 17;
          f->mod = (modifiers & 0xc)
            | ((modifiers & 1) << 1)
            | ((modifiers >> 1) & 1);
          return 0;
      }
  }
  
  [NSApp sendEvent:event];
  return 0;
}
