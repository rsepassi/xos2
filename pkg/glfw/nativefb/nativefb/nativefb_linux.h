#define GLFW_EXPOSE_NATIVE_X11
#include "GLFW/glfw3.h"
#include "GLFW/glfw3native.h"

typedef struct {
  Display* display;
  Window window;
  GC gc;
  XImage *img;
} native_platform_t;

