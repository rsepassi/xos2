#if !defined(_WIN32) && !defined(__APPLE__)

#include "fenster.h"

static Atom wm_delete_window;

// clang-format off
static int FENSTER_KEYCODES[124] = {XK_BackSpace,8,XK_Delete,127,XK_Down,18,XK_End,5,XK_Escape,27,XK_Home,2,XK_Insert,26,XK_Left,20,XK_Page_Down,4,XK_Page_Up,3,XK_Return,10,XK_Right,19,XK_Tab,9,XK_Up,17,XK_apostrophe,39,XK_backslash,92,XK_bracketleft,91,XK_bracketright,93,XK_comma,44,XK_equal,61,XK_grave,96,XK_minus,45,XK_period,46,XK_semicolon,59,XK_slash,47,XK_space,32,XK_a,65,XK_b,66,XK_c,67,XK_d,68,XK_e,69,XK_f,70,XK_g,71,XK_h,72,XK_i,73,XK_j,74,XK_k,75,XK_l,76,XK_m,77,XK_n,78,XK_o,79,XK_p,80,XK_q,81,XK_r,82,XK_s,83,XK_t,84,XK_u,85,XK_v,86,XK_w,87,XK_x,88,XK_y,89,XK_z,90,XK_0,48,XK_1,49,XK_2,50,XK_3,51,XK_4,52,XK_5,53,XK_6,54,XK_7,55,XK_8,56,XK_9,57};
// clang-format on

static void create_image(fenster *f) {
  f->buf = f->realloc(
      f->user_ctx, f->buf, sizeof(uint32_t) * f->width * f->height);
  f->platform.img = XCreateImage(
      f->platform.dpy,
      DefaultVisual(f->platform.dpy, 0),
      24,
      ZPixmap,
      0,
      (char *)f->buf,
      f->width,
      f->height,
      32,
      0);
}

int fenster_open(fenster *f) {
  f->platform.dpy = XOpenDisplay(NULL);
  int screen = DefaultScreen(f->platform.dpy);
  f->platform.w = XCreateSimpleWindow(
      f->platform.dpy,
      RootWindow(f->platform.dpy, screen),
      0,
      0,
      f->width,
      f->height,
      0,
      BlackPixel(f->platform.dpy, screen),
      WhitePixel(f->platform.dpy, screen));
  wm_delete_window = XInternAtom(f->platform.dpy, "WM_DELETE_WINDOW", 0);
  XSetWMProtocols(f->platform.dpy, f->platform.w, &wm_delete_window, 1);
  f->platform.gc = XCreateGC(f->platform.dpy, f->platform.w, 0, 0);
  XSelectInput(
      f->platform.dpy, f->platform.w,
      StructureNotifyMask |
      ExposureMask |
      KeyPressMask |
      KeyReleaseMask |
      ButtonPressMask |
      ButtonReleaseMask |
      PointerMotionMask);
  XStoreName(f->platform.dpy, f->platform.w, f->title);
  XMapWindow(f->platform.dpy, f->platform.w);
  XSync(f->platform.dpy, f->platform.w);
  create_image(f);
  return 0;
}

void fenster_close(fenster *f) {
  XCloseDisplay(f->platform.dpy);
  f->buf = f->realloc(f->user_ctx, f->buf, 0);
}

void fenster_paint(fenster *f) {
  XPutImage(
      f->platform.dpy,
      f->platform.w,
      f->platform.gc,
      f->platform.img,
      0,
      0,
      0,
      0,
      f->width,
      f->height);
  XFlush(f->platform.dpy);
}

int fenster_loop(fenster *f) {
  XEvent ev;
  while (XPending(f->platform.dpy)) {
    XNextEvent(f->platform.dpy, &ev);
    switch (ev.type) {
      case ConfigureNotify:
        f->width = ev.xconfigure.width;
        f->height = ev.xconfigure.height;
        create_image(f);
        break;
      case ButtonPress:
      case ButtonRelease:
        if (ev.xbutton.button == Button1) {
          if (ev.type == ButtonPress) {
            f->mouse = FENSTER_LMOUSE_DOWN;
          } else {
            f->mouse = FENSTER_LMOUSE_UP;
          }
        } else if (ev.xbutton.button == Button3) {
          if (ev.type == ButtonPress) {
            f->mouse = FENSTER_RMOUSE_DOWN;
          } else {
            f->mouse = FENSTER_RMOUSE_UP;
          }
        }
        break;
      case MotionNotify:
        f->x = ev.xmotion.x, f->y = ev.xmotion.y;
        break;
      case KeyPress:
      case KeyRelease: {
        int m = ev.xkey.state;
        int k = XkbKeycodeToKeysym(f->platform.dpy, ev.xkey.keycode, 0, 0);
        for (unsigned int i = 0; i < 124; i += 2) {
          if (FENSTER_KEYCODES[i] == k) {
            f->keys[FENSTER_KEYCODES[i + 1]] = (ev.type == KeyPress ? 1 : -1);
            break;
          }
        }
        f->mod = (!!(m & ControlMask)) | (!!(m & ShiftMask) << 1) |
                 (!!(m & Mod1Mask) << 2) | (!!(m & Mod4Mask) << 3);
      } break;
      case ClientMessage: {
        if ((Atom)ev.xclient.data.l[0] == wm_delete_window) {
          return 1;
        }
      }
    }
  }
  return 0;
}

#endif
