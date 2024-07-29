#include <stdlib.h>
#include <stdio.h>

#include "wren.h"

int main() {
  // Note: source should always end with a newline or space so that terms
  // always end in a delimiter
  const char *s4 = "if if else foo Foo 0x182 0b111_000 0o776 86 _foo __foo {hi}[boo] 1..2\n1.2 1...3 \nlambda! foo 7\n\n yes true 7 ";
  const char *s3 = "\"foo\\\"barbaz\"";
  const char *s2 = "\"hi %(foo bar)\"";
  const char *s = "if (true) {\nfoo.bar[3..4]\n} \nwhile (true) {}\n";

  State state = state_init(s);
  Token* tok = &state.last;

  void* parser = ParseAlloc(malloc, &state);
#ifndef NDEBUG
  ParseTrace(stdout, "yy: ");
#endif

  int errcnt = 0;
  while (!state.done) {
    state.tok = state.cur;

    switch (lex(&state)) {
      case OK:
        // ptok(*tok, &state);
        Parse(parser, tok->type, *tok);
        if (state.has_err) {
          ++errcnt;
          snprintf(state.err, ERR_LEN, "unexpected token");
          lex_err(&state);
          if (errcnt > 5) return 1;
        }
        break;
      case FILL:
        break;
      case ERR:
        printf("ERROR\n");
        return 1;
    }
  }
  Parse(parser, 0, state.last);
     
  printf("\nOK (%d lines)\n", state.lno);

  ParseFree(parser, free);
  return 0;
}
