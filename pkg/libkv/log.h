#include <stdio.h>
#include <string.h>

#define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)

#define LOG(fmt, ...) do { \
    fprintf(stderr, "[%s:%d] " fmt "\n", __FILENAME__, __LINE__ , ##__VA_ARGS__); \
  } while (0)

#define CHECK2(x, fmt, ...) do { \
  if (!(x)) { LOG(fmt, ##__VA_ARGS__); exit(1); } \
  } while (0)
#define CHECK(x, ...) CHECK2(x, "check failed: " __VA_ARGS__);
