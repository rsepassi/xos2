#include <stdio.h>
#include <string.h>

#ifdef WIN32
#define PATHSEP '\\'
#define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : (strrchr(__FILE__, '\\') ? strrchr(__FILE__, '\\') + 1 : __FILE__))
#else
#define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
#endif

#define LOG_INNER(fd, level, fmt, ...) \
  do { \
    fprintf(fd, "%s[%s:%d] " fmt "\n", level, __FILENAME__, __LINE__, ##__VA_ARGS__); \
  } while(0)
#define LOG(fmt, ...) LOG_INNER(stdout, "I", "%s" fmt, "", ##__VA_ARGS__)

#ifdef DEBUG
#define DLOG(fmt, ...) \
  LOG_INNER(stderr, "D", "%s" fmt, "", ##__VA_ARGS__)
#else
#define DLOG(fmt, ...) do {} while(0)
#endif
