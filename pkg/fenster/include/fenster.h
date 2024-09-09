#ifndef FENSTER_H
#define FENSTER_H

#include <stdint.h>
#include <stdbool.h>

#include "fenster/fenster_platform.h"

typedef struct {
  uint8_t* title;
  int32_t width;
  int32_t height;
  uint32_t* buf;
  bool keys[256]; /* keys are mostly ASCII, but arrows are 17..20 */
  uint8_t mod;    /* mod is 4 bits mask, ctrl=1, shift=2, alt=4, meta=8 */
  int32_t x;
  int32_t y;
  bool mouse;
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
