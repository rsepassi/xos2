#include <stdlib.h>
#include <stdio.h>

#include "ry0.h"

int main() {
  // Note: source should always end with a newline or space so that terms
  // always end in a delimiter
  const char *s =
    "let x = [32]a.b.c;" "\n"
    "let foo = fn () bar;" "\n"
    "let foo = struct {}.x;" "\n"
    "let foo = x[32].y;" "\n"
    // "x: i8;" "\n"
    // "y: u8;" "\n"
    // "y: f32;" "\n"
    // "let foo = fn bar();" "\n"
    // "let foo = struct {};" "\n"
    // "var bar = enum {};" "\n"
    // "var bar = union {};" "\n"
    // "var bar = ?union {};" "\n"
    // "var bar = [8]?union {};" "\n"
    // "var bar: i8 = u8;" "\n"
    // "var bar: *?i8 = union(foo) { a:u8; b:i8; };" "\n"
    // "var bar: *?i8 = union { a:u8; b:i8; };" "\n"
    // "let foo = fn void(a: u8) {" "\n"
    // "var a = 7;" "\n"
    // "var b = \"asdf\";" "\n"
    // "var c = undefined;" "\n"
    // "var c = true;" "\n"
    // "var c = false;" "\n"
    // "var c = null;" "\n"
    // "};" "\n"
    // "let foo = import \"foo\";" "\n"
    ;

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
     
  printf("\nOK (%d lines)\n", state.lno);

  ParseFree(parser, free);
  return 0;
}
