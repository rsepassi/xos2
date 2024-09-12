#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "base/log.h"
#include "base/file.h"
#include "ry0.h"
#include "mir.h"
#include "codegen.h"

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

int main(int argc, char** argv) {
  CHECK(argc > 1, "must pass ry file");

  str_t file;
  CHECK_OK(fs_read_file(argv[1], &file), "could not read file");

  State state = state_init(file.bytes);
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
  printf("\n");
  ParseCoverage(stdout);
#endif
  ParseFree(parser, free);

  printf("\n");
  log_sizes();
  printf("\n");
  node_print(&state.ctx, state.root);
  printf("\nOK (%d lines)\n", state.lno);

  MIR_context_t mir = MIR_init();

  CodegenCtx cg = {
    .mir = mir,
    .node_ctx = &state.ctx,
  };
  CHECK_OK(codegen(&cg, state.root), "codegen failed");
  MIR_output(mir, stdout);

  FILE* f = fopen("/tmp/code.mirb", "wb");
  MIR_write(mir, f);
  fclose(f);

  MIR_finish(mir);
  node_ctx_deinit(state.ctx);
  free(file.bytes);

  return 0;
}
