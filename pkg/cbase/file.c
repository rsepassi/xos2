#include <stdlib.h>
#include <stdio.h>

#include "base/file.h"

Status fs_read_file(const char* fname, str_t* out) {
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
