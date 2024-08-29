#ifndef BASE_STATUS_H_
#define BASE_STATUS_H_

#include "base/log.h"

typedef enum {
  OK,
  ERR,
} Status;

#define CHECK_OK(x, ...) CHECK((x == OK), ##__VA_ARGS__)

#define TRY(x) do { \
    Status code = (x); \
    if (code != OK) return code; \
  } while (0)

#endif
