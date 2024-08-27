#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "base/log.h"
#include "ry0.h"

#define LOG_FIELD(name) \
  if (sizeof(n.data.name) > 32) printf("sizeof(" #name ")=%zu\n", sizeof(n.data.name))

void log_sizes() {
  Node n;
  printf("sizeof(Node)=%d\n", sizeof(Node));  // 56
  printf("sizeof(NodeHandle)=%d\n", sizeof(NodeHandle));  // 4
  printf("sizeof(NodeType)=%d\n", sizeof(NodeType));  // 4
  printf("sizeof(Node.data)=%d\n", sizeof(n.data));  // 48
  printf("sizeof(Token)=%d\n", sizeof(Token));  // 24
  printf("sizeof(TokenType)=%d\n", sizeof(TokenType));  // 4
  LOG_FIELD(decl);  // 48
  LOG_FIELD(xfor);  // 40
  LOG_FIELD(struct_field);  // 40
  LOG_FIELD(literal_struct_field);  // 40
  LOG_FIELD(fnarg);  // 40
  LOG_FIELD(enumfield);  // 40
  LOG_FIELD(struct_body);
  LOG_FIELD(name);
  LOG_FIELD(literal);
  LOG_FIELD(type);
  LOG_FIELD(expr);
  LOG_FIELD(block);
  LOG_FIELD(stmt_ctrl);
  LOG_FIELD(assign);
  LOG_FIELD(xif);
  LOG_FIELD(xwhile);
  LOG_FIELD(xswitch);
  LOG_FIELD(expr_field);
  LOG_FIELD(fncall);
  LOG_FIELD(expr_array);
  LOG_FIELD(expr_prefix);
  LOG_FIELD(xcase);
}

char* readFile(const char* filename) {
    FILE* file = fopen(filename, "rb");
    CHECK(file, "can't open file");
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    rewind(file);

    char* buffer = (char*)malloc(file_size + 1);
    size_t read_size = fread(buffer, 1, file_size, file);
    buffer[file_size] = '\0';

    fclose(file);
    return buffer;
}

int main() {
  const char* s = readFile("./xos-out/bin/syntax.ry");

  State state = state_init(s);
  state.ctx = node_ctx_init();
  Token* tok = &state.last;

  void* parser = ParseAlloc(malloc, &state);
#ifndef NDEBUG
  ParseTrace(stdout, "yy: ");
#endif

  int errcnt = 0;
  while (!state.done) {
    state.tok = state.cur;

    switch (lex(&state)) {
      case LEX_OK:
        Parse(parser, tok->type, *tok);
        if (state.has_err) {
          if (state.last.type == TOKEN_EOF) {
            snprintf(state.err, ERR_LEN, "unexpected end of file");
          } else {
            snprintf(state.err, ERR_LEN, "unexpected token");
          }
          lex_err(&state);
          return 1;
        }
        break;
      case LEX_FILL:
        break;
      case LEX_ERR:
        return 1;
    }
  }
  Parse(parser, 0, state.last);

  if (state.root == 0) {
    printf("no root!\n");
    exit(1);
  }


#ifndef NDEBUG
  ParseCoverage(stdout);
#endif
  ParseFree(parser, free);

  printf("\n");
  log_sizes();
  printf("\n");
  node_print(&state.ctx, state.root);
  printf("\nOK (%d lines)\n", state.lno);

  node_ctx_deinit(state.ctx);
  free(s);

  return 0;
}
