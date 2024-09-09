#define _DEFAULT_SOURCE 1
#include <X11/XKBlib.h>
#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <time.h>

typedef struct {
  Display *dpy;
  Window w;
  GC gc;
  XImage *img;
} fenster_platform;
