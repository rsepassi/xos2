#if defined(_WIN32)

#include "fenster.h"

// clang-format off
static const uint8_t FENSTER_KEYCODES[] = {0,27,49,50,51,52,53,54,55,56,57,48,45,61,8,9,81,87,69,82,84,89,85,73,79,80,91,93,10,0,65,83,68,70,71,72,74,75,76,59,39,96,0,92,90,88,67,86,66,78,77,44,46,47,0,0,0,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,17,3,0,20,0,19,0,5,18,4,26,127};
// clang-format on

typedef struct BINFO{
    BITMAPINFOHEADER    bmiHeader;
    RGBQUAD             bmiColors[3];
}BINFO;

static LRESULT CALLBACK fenster_wndproc(HWND hwnd, UINT msg, WPARAM wParam,
                                        LPARAM lParam) {
  fenster *f = (fenster *)GetWindowLongPtr(hwnd, GWLP_USERDATA);
  switch (msg) {
  case WM_SIZE: {
    f->width = LOWORD(lParam);
    f->height = HIWORD(lParam);
    f->buf = f->realloc(
        f->user_ctx, f->buf, f->width * f->height * sizeof(uint32_t)); 
  } break;
  case WM_PAINT: {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);
    HDC memdc = CreateCompatibleDC(hdc);
    HBITMAP hbmp = CreateCompatibleBitmap(hdc, f->width, f->height);
    HBITMAP oldbmp = SelectObject(memdc, hbmp);
    BINFO bi = {{sizeof(bi), f->width, -f->height, 1, 32, BI_BITFIELDS}};
    bi.bmiColors[0].rgbRed = 0xff;
    bi.bmiColors[1].rgbGreen = 0xff;
    bi.bmiColors[2].rgbBlue = 0xff;
    SetDIBitsToDevice(
        memdc,
        0,
        0,
        f->width,
        f->height,
        0,
        0,
        0,
        f->height,
        f->buf,
        (BITMAPINFO *)&bi,
        DIB_RGB_COLORS);
    BitBlt(hdc, 0, 0, f->width, f->height, memdc, 0, 0, SRCCOPY);
    SelectObject(memdc, oldbmp);
    DeleteObject(hbmp);
    DeleteDC(memdc);
    EndPaint(hwnd, &ps);
  } break;
  case WM_CLOSE:
    DestroyWindow(hwnd);
    break;
  case WM_LBUTTONDOWN:
  case WM_LBUTTONUP:
    f->mouse = (msg == WM_LBUTTONDOWN ?
        FENSTER_LMOUSE_DOWN : FENSTER_LMOUSE_UP);
    break;
  case WM_RBUTTONDOWN:
  case WM_RBUTTONUP:
    f->mouse = (msg == WM_RBUTTONDOWN ?
        FENSTER_RMOUSE_DOWN : FENSTER_RMOUSE_UP);
    break;
  case WM_MOUSEMOVE:
    f->y = HIWORD(lParam), f->x = LOWORD(lParam);
    break;
  case WM_KEYDOWN:
  case WM_KEYUP: {
    f->mod = ((GetKeyState(VK_CONTROL) & 0x8000) >> 15) |
             ((GetKeyState(VK_SHIFT) & 0x8000) >> 14) |
             ((GetKeyState(VK_MENU) & 0x8000) >> 13) |
             (((GetKeyState(VK_LWIN) | GetKeyState(VK_RWIN)) & 0x8000) >> 12);
    f->keys[FENSTER_KEYCODES[HIWORD(lParam) & 0x1ff]] = !((lParam >> 31) & 1) ? 1 : -1;
  } break;
  case WM_DESTROY:
    PostQuitMessage(0);
    break;
  default:
    return DefWindowProc(hwnd, msg, wParam, lParam);
  }
  return 0;
}

int fenster_open(fenster *f) {
  f->buf = f->realloc(
      f->user_ctx, f->buf, f->width * f->height * sizeof(uint32_t)); 
  HINSTANCE hInstance = GetModuleHandle(NULL);
  WNDCLASSEX wc = {0};
  wc.cbSize = sizeof(WNDCLASSEX);
  wc.style = CS_VREDRAW | CS_HREDRAW;
  wc.lpfnWndProc = fenster_wndproc;
  wc.hInstance = hInstance;
  wc.lpszClassName = f->title;
  RegisterClassEx(&wc);
  f->platform.hwnd = CreateWindowEx(
      WS_EX_CLIENTEDGE,
      f->title,
      f->title,
      WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      f->width,
      f->height,
      NULL,
      NULL,
      hInstance,
      NULL);

  if (f->platform.hwnd == NULL)
    return -1;
  SetWindowLongPtr(f->platform.hwnd, GWLP_USERDATA, (LONG_PTR)f);
  ShowWindow(f->platform.hwnd, SW_NORMAL);
  UpdateWindow(f->platform.hwnd);
  return 0;
}

void fenster_close(fenster *f) {
  f->buf = f->realloc(f->user_ctx, f->buf, 0);
}

void fenster_paint(fenster *f) {
  InvalidateRect(f->platform.hwnd, NULL, TRUE);
}

int fenster_loop(fenster *f) {
  MSG msg;
  while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
    if (msg.message == WM_QUIT)
      return -1;
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }
  return 0;
}

void fenster_sleep(int64_t ms) { Sleep(ms); }

int64_t fenster_time() {
  LARGE_INTEGER freq, count;
  QueryPerformanceFrequency(&freq);
  QueryPerformanceCounter(&count);
  return (int64_t)(count.QuadPart * 1000.0 / freq.QuadPart);
}

#endif
