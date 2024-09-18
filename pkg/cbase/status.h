#ifndef BASE_STATUS_H_
#define BASE_STATUS_H_

#include "base/log.h"

#define OK 0
#define ERR 1

#define CHECK_OK(x, ...) CHECK((x == OK), ##__VA_ARGS__)

#define TRY(x) do { \
    int code = (x); \
    if (code != OK) return code; \
  } while (0)

#endif
