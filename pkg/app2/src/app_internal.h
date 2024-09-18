#include "app.h"

#include "nativefb.h"

typedef struct {
  app_state_t state;
  app_init_t init;
  app_event_t event;

  // We push pixels into the framebuffer, and then use the native platform
  // to blit it to the screen.
  framebuffer_t fb;
  native_platform_t platform;
  bool needs_render;
  bool quit_requested;

  // During view tree construction, we use a simple fixed-size bump allocator
  // which gets reset at the beginning of each render.
  allocator_bump_t bump;
} app_platform_t;

void app__resize_fb(app_platform_t* app, int width, int height);
void app__render(app_platform_t* app);
u64 app__gettimems(app_platform_t* app);

#define EV0(evtype) do { \
    app->event.type = AppEvent##evtype; \
    app__send_event(app); \
  } while (0)
#define EV(evtype, field, init) do { \
    app->event.type = AppEvent##evtype; \
    app->event.data.field = (init); \
    app__send_event(app); \
  } while (0)
#define app__send_event(app) \
  (app)->init.on_event((app)->init.userdata, &(app)->event);
