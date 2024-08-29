#ifndef BASE_FILE_H_
#define BASE_FILE_H_

#include "base/status.h"
#include "base/str.h"

Status read_file(const char* fname, str_t* out);

#endif
