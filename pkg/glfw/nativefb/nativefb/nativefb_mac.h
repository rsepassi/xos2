#include <objc/objc-runtime.h>

#define GLFW_EXPOSE_NATIVE_COCOA
#include "GLFW/glfw3.h"
#include "GLFW/glfw3native.h"

typedef struct {
  id view;
} native_platform_t;
