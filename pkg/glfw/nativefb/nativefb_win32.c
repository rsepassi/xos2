#ifdef _WIN32

#include "nativefb.h"

typedef struct {
  BITMAPINFOHEADER bmiHeader;
  RGBQUAD bmiColors[3];
} BINFO;

void nativefb_init(native_platform_t* p, GLFWwindow* w, framebuffer_t* fb) {
  p->hwnd = glfwGetWin32Window(w);
}

void nativefb_deinit(native_platform_t* p) {}
void nativefb_resize(native_platform_t* p, framebuffer_t* fb) {}

void nativefb_trigger_refresh(native_platform_t* p, framebuffer_t* fb) {
  InvalidateRect(p->hwnd, NULL, TRUE);
}

void nativefb_paint(native_platform_t* p, framebuffer_t* fb) {
  PAINTSTRUCT ps;
  HDC hdc = BeginPaint(p->hwnd, &ps);
  HDC memdc = CreateCompatibleDC(hdc);
  HBITMAP hbmp = CreateCompatibleBitmap(hdc, fb->w, fb->h);
  HBITMAP oldbmp = SelectObject(memdc, hbmp);
  BINFO bi = {{sizeof(bi), fb->w, -fb->h, 1, 32, BI_BITFIELDS}};
  bi.bmiColors[0].rgbRed = 0xff;
  bi.bmiColors[1].rgbGreen = 0xff;
  bi.bmiColors[2].rgbBlue = 0xff;
  SetDIBitsToDevice(
      memdc,
      0,
      0,
      fb->w,
      fb->h,
      0,
      0,
      0,
      fb->h,
      fb->buf,
      (BITMAPINFO*)&bi,
      DIB_RGB_COLORS);
  BitBlt(hdc, 0, 0, fb->w, fb->h, memdc, 0, 0, SRCCOPY);
  SelectObject(memdc, oldbmp);
  DeleteObject(hbmp);
  DeleteDC(memdc);
  EndPaint(p->hwnd, &ps);
}

#endif
