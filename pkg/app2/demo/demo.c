#include <stdlib.h>

#include "app.h"

#include "base/log.h"

typedef struct {
  int count;
  bool dirty;
  app_state_t* state;
} app_t;

static void on_event(void* userdata, app_event_t* ev) {
  app_t* app = (app_t*)userdata;

  switch (ev->type) {
    default: {
      LOG("event %s", app_event_type_str(ev->type));
    }
  }

  if (app->dirty) app_mark_needs_render(app->state);
}

static void render(void* ctx) {
  app_t* app = (app_t*)ctx;
  u16 h = app->state->size.h;
  u16 w = app->state->size.w;

  LOG("render");
}

void app_init(app_state_t* state, app_init_t* init) {
  app_t* app  = calloc(1, sizeof(app_t));
  app->state = state;

  init->userdata = app;
  init->on_event = on_event;
  init->render = render;
  init->initial_size = (app_size2d_t){ .w = 300, .h = 300 };
  init->window_title = "Hello World!";
}

