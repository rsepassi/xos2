#ifndef LOG_H_
#define LOG_H_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)

#define LOG(fmt, ...) do { \
    fprintf(stderr, "[%s %s:%d] " fmt "\n", log_get_current_time(), __FILENAME__, __LINE__ , ##__VA_ARGS__); \
  } while (0)

#ifdef NDEBUG
#define DLOG(fmt, ...)
#else
#define DLOG(fmt, ...) LOG(fmt, ##__VA_ARGS__)
#endif

#define CHECK2(x, fmt, ...) do { \
  if (!(x)) { LOG(fmt, ##__VA_ARGS__); exit(1); } \
  } while (0)
#define CHECK(x, ...) CHECK2(x, "check failed: " __VA_ARGS__);

char* log_get_current_time();

#endif  // LOG_H_
