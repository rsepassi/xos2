#ifndef LOG_H_
#define LOG_H_

#include <stdio.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>

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

char* log_get_current_time() {
  static char time_str[13];
  struct timeval tv;
  struct tm* tm_info;

  gettimeofday(&tv, NULL);
  tm_info = gmtime(&tv.tv_sec);

  snprintf(time_str, sizeof(time_str), "%02d:%02d:%02d.%03ld",
           tm_info->tm_hour, tm_info->tm_min, tm_info->tm_sec, tv.tv_usec / 1000);

  return time_str;
}


#endif  // LOG_H_
