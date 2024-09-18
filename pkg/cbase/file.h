#ifndef BASE_FILE_H_
#define BASE_FILE_H_

#include "base/status.h"
#include "base/str.h"

int fs_read_file(const char* fname, str_t* out);
str_t fs_self_path();
str_t fs_resource_read(str_t name);
str_t fs_dirname(str_t path);

#endif
