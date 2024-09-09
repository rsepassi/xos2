#ifndef FENSTER_H
#define FENSTER_H

#include <stdint.h>

#include "fenster/fenster_platform.h"

typedef void* (*fenster_realloc)(void *user_ctx, void *ptr, size_t new_size);

typedef enum {
  FENSTER_LMOUSE_DOWN = 1,
  FENSTER_LMOUSE_UP,
  FENSTER_RMOUSE_DOWN,
  FENSTER_RMOUSE_UP,
} fenster_mouse;

#define FENSTER_MOD_CTRL  1 << 0
#define FENSTER_MOD_SHIFT 1 << 1
#define FENSTER_MOD_ALT   1 << 2
#define FENSTER_MOD_META  1 << 3
#define fenster_mod(f, key) (f->mod & FENSTER_MOD_##key)

typedef struct {
  char* title;
  int32_t width;
  int32_t height;
  // keys are mostly ASCII, but arrows are 17..20
  // down=1 up=-1
  int8_t keys[256];
  uint8_t mod;
  // position of click or mouse motion
  int32_t x;
  int32_t y;
  fenster_mouse mouse;
  // Pixel buffer, managed internally
  uint32_t* buf;
  // User-provided allocation function
  // Used for allocating pixel buffer on open and resize
  fenster_realloc realloc;
  // User-provided context passed to realloc
  void* user_ctx;
  // Platform-specific state
  fenster_platform platform;
} fenster;

int fenster_open(fenster *f);
int fenster_loop(fenster *f);
void fenster_paint(fenster *f);
void fenster_close(fenster *f);
void fenster_sleep(int64_t ms);
int64_t fenster_time(void);
#define fenster_pixel(f, x, y) ((f)->buf[((y) * (f)->width) + (x)])

#endif /* FENSTER_H */
