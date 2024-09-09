#include "fenster.h"
#include <stdlib.h>

#define W 320
#define H 240
#define FPS 60

int main() {
  int64_t frame_ms = 1000.0 / FPS;
  uint32_t buf[W * H];
  fenster f = { .title = "hello", .width = W, .height = H, .buf = buf };

  fenster_open(&f);
  int64_t next = 0;
  while (fenster_loop(&f) == 0) {
    int64_t delay_ms = (next - fenster_time());
    if (delay_ms > 0) fenster_sleep(delay_ms);

    for (int i = 0; i < W; i++) {
      for (int j = 0; j < H; j++) {
        fenster_pixel(&f, i, j) = rand();
      }
    }
    fenster_paint(&f);

    next = fenster_time() + frame_ms;
  }
  fenster_close(&f);
  return 0;
}
