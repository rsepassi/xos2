#include <stdlib.h>
#include <stdio.h>

#include "fenster.h"

#define TITLE "hello"
#define W 320
#define H 240
#define FPS 60

void* my_realloc(void *user_ctx, void *ptr, size_t new_size) {
  return realloc(ptr, new_size);
}

void process_event(fenster* f) {
  // Scan keys
  for (int i = 0; i < 256; ++i) {
    if (f->keys[i] == FENSTER_KEY_DOWN) {
      fprintf(stderr, "keydown %d", i, fenster_mod(f, CTRL));
      if (fenster_mod(f, CTRL)) fprintf(stderr, " ctrl");
      if (fenster_mod(f, SHIFT)) fprintf(stderr, " shift");
      if (fenster_mod(f, ALT)) fprintf(stderr, " alt");
      if (fenster_mod(f, META)) fprintf(stderr, " meta");
      fprintf(stderr, "\n");
      f->keys[i] = FENSTER_KEY_NONE;
    } else if (f->keys[i] == FENSTER_KEY_UP) {
      fprintf(stderr, "keyup %d\n", i);
      f->keys[i] = FENSTER_KEY_NONE;
    }
  }

  // Scan mouse
  if (f->mouse != FENSTER_MOUSE_NONE) {
    fprintf(stderr, "mouse %d (%d, %d)\n", f->mouse, f->x, f->y);
    f->mouse = FENSTER_MOUSE_NONE;
  }
}

int main() {
  fenster f = {
    .title = TITLE,
    .width = W,
    .height = H,
    .realloc = my_realloc,
  };

  fenster_open(&f);

  int64_t frame_ms = 1000.0 / FPS;
  int64_t next_tick = 0;
  while (fenster_loop(&f) == 0) {
    int64_t delay_ms = (next_tick - fenster_time());
    if (delay_ms > 0) fenster_sleep(delay_ms);

    process_event(&f);

    for (int i = 0; i < f.width; i++) {
      for (int j = 0; j < f.height; j++) {
        fenster_pixel(&f, i, j) = rand();
      }
    }
    fenster_paint(&f);

    next_tick = fenster_time() + frame_ms;
  }

  fenster_close(&f);
  return 0;
}
