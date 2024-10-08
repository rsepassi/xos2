#include <stdlib.h>
#include <stdio.h>

#include "base/file.h"
#include "base/log.h"

int fs_read_file(const char* fname, str_t* out) {
    FILE* file = fopen(fname, "rb");
    if (!file) return ERR;
    
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    char* content = malloc(size + 1);
    if (!content) {
        fclose(file);
        return ERR;
    }
    
    fread(content, 1, size, file);
    content[size] = 0;
    
    fclose(file);

    out->len = size;
    out->bytes = content;
    return OK;
}

str_t fs_dirname(str_t path) {
  // Find the last /
  int i = path.len - 1;
  while (i >= 0 && path.bytes[i] != '/') --i;
  if (i == -1) return (str_t){ .bytes = ".", .len = 1};
  return (str_t){ .bytes = path.bytes, .len = i };
}
