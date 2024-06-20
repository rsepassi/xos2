#include <stdio.h>
#include <stdlib.h>
#include <string.h>


ssize_t getline(char** linep, size_t* n, FILE* stream) {
  if (linep == NULL || n == NULL || stream == NULL) return -1;

  char* buf = *linep;
  size_t size = *n;

  char c = fgetc(stream);
  if (c == (char)EOF) return -1;
  if (buf == NULL) {
    buf = malloc(128);
    if (buf == NULL) return -1;
    size = 128;
  }
  char* p = buf;
  while (c != (char)EOF) {
    if ((p - buf) > (size - 1)) {
      size *= 2;
      buf = realloc(buf, size);
      if (buf == NULL) return -1;
      p = buf + (size / 2);
    }
    *p++ = c;
    if (c == '\n') break;
    c = fgetc(stream);
  }

  *p++ = '\0';
  *linep = buf;
  *n = size;

  return p - buf - 1;
}

void process_line(char* line) {
  printf("\"");
  int i = 0;
  while (line[i]) {
    if (line[i] == '\\') printf("\\");
    if (line[i] == '"') printf("\\");
    if (!strcmp(&line[i], "\n")) break;
    printf("%c", line[i]);
    ++i;
  }
  printf("\\n\"\n");
}

int main(int argc, char** argv) {
  const char* varname = argv[1];
  if (!varname) {
    fprintf(stderr, "must provide a single argument for the variable name");
    exit(1);
  }

  printf("static const char* %sModuleSource = \\\n", varname);

  char* line = NULL;
  size_t size;
  while (getline(&line, &size, stdin) != -1) {
    process_line(line);
  }
  free(line);

  printf("\"\";\n");
}
