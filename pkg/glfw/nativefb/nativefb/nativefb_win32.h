#define GLFW_EXPOSE_NATIVE_WIN32
#include "GLFW/glfw3.h"
#include "GLFW/glfw3native.h"

typedef struct {
  HWND hwnd;
} native_platform_t;
