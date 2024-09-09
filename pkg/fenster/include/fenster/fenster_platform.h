#if defined(__APPLE__)
#include "fenster/fenster_mac.h"
#elif defined(_WIN32)
#include "fenster/fenster_win32.h"
#else
#include "fenster/fenster_linux.h"
#endif
