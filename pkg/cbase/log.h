#ifndef LOG_H_
#define LOG_H_

#ifdef CBASE_ABI_ANDROID
#include <android/log.h>
#define LOG(fmt, ...) ((void)__android_log_print(ANDROID_LOG_INFO, "NativeActivity", fmt, ##__VA_ARGS__))
#else

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)

#define LOG(fmt, ...) do { \
    fprintf(stderr, "[%s %s:%d] " fmt "\n", log_get_current_time(), __FILENAME__, __LINE__ , ##__VA_ARGS__); \
  } while (0)

char* log_get_current_time();

#endif  // CBASE_ABI_ANDROID

#ifndef NDEBUG
#define DLOG(fmt, ...) LOG(fmt, ##__VA_ARGS__)
#else
#define DLOG(fmt, ...)
#endif

#define CHECK2(x, fmt, ...) do { \
  if (!(x)) { LOG(fmt, ##__VA_ARGS__); exit(1); } \
  } while (0)
#define CHECK(x, ...) CHECK2(x, "check failed: " __VA_ARGS__);

#ifndef NDEBUG
#define DCHECK(x, ...) CHECK(x, ##__VA_ARGS__)
#else
#define DCHECK(x, ...)
#endif

#endif  // LOG_H_
