#include <string.h>
#include <stdbool.h>
#include <stdio.h>

#include "ry0.h"

typedef struct str {
  const char* s;
  unsigned int len;
} str;

State state_init(const char* s) {
  State state = {0};
  state.cur = s;
  state.lim = s + strlen(s);
  state.bol = s;
  state.lno = 1;
  state.lexers[0].state = -1;
  return state;
}

static str state_current_tokstr(State* state) {
  str s = {
    state->tok,
    state->cur - state->tok,
  };
  return s;
}

static void ptok(Token tok, State* state) {
  TokenType t = tok.type;
  if (t == TOKEN_STRING) {
    str s = state_current_tokstr(state);
    printf("%d STRING, ", t);
  } else if (t == TOKEN_EOF) {
    printf("%d EOF, ", t);
  } else if (t == TOKEN_NUMBER) {
    printf("%d NUM %.2f, ", t, tok.data.number);
  } else {
    str s = state_current_tokstr(state);
    printf("%d %.*s, ", t, s.len, s.s);
  }
}

static Status parse_num_base(const char* begin, const char* end, int base, double* num) {
  double sum = 0;
  const char* current = end;
  int place = 1;
  while (current >= begin) {
    if (*current != '_') {
      char c = (*current - 48);
      if (c >= base) return LEX_ERR;
      int val = (int)c;
      sum += val * place;
      place *= base;
    }
    --current;
  }
  *num = sum;
  return LEX_OK;
}

static Status parse_int(State* state, double* num) {
  // the regex only allows 0-9, can't fail
  return parse_num_base(state->tok, state->cur - 1, 10, num);
}

static Status parse_hex(State* state, double* num) {
  // the regex only allows 0-9a-zA-Z, can't fail
  double sum = 0;
  const char* begin = state->tok + 2;
  const char* current = state->cur - 1;
  int place = 1;
  while (current >= begin) {
    if (*current != '_') {
      int val;
      if (*current < 'A') {
        val = *current - 48;
      } else if (*current < 'a') {
        val = *current - 65 + 10;
      } else {
        val = *current - 97 + 10;
      }
      sum += val * place;
      place *= 16;
    }
    --current;
  }
  *num = sum;
  return LEX_OK;
}

static Status parse_flt(State* state, double* num) {
  // the regex only allows 0-9, can't fail
  const char* point = (char*)memchr(state->tok, '.', state->cur - state->tok);
  double frac;
  if (parse_num_base(state->tok, point - 1, 10, num) != LEX_OK) return LEX_ERR;
  if (parse_num_base(point + 1, state->cur - 1, 10, &frac) != LEX_OK) return LEX_ERR;
  for (int i = 0; i < state->cur - point - 1; ++i) frac /= 10;
  *num += frac;
  return LEX_OK;
}

static Status parse_bin(State* state, double* num) {
  // the regex only allows 0-1, can't fail
  return parse_num_base(state->tok + 2, state->cur - 1, 2, num);
}

static Status parse_oct(State* state, double* num) {
  if (parse_num_base(state->tok + 2, state->cur - 1, 8, num) == LEX_ERR) {
    state->has_err = true;
    snprintf(state->err, ERR_LEN, "malformed octal number");
    return LEX_ERR;
  }
  return LEX_OK;
}

#define TOK(name) do { \
    state->last.type = TOKEN_##name; \
    state->last.start = state->tok; \
    state->last.end = state->cur - 1; \
    return LEX_OK; \
  } while (0)
#define TOK_NUM(val) do { \
    state->last.type = TOKEN_NUMBER; \
    state->last.start = state->tok; \
    state->last.end = state->cur - 1; \
    state->last.data.number = val; \
    return LEX_OK; \
  } while (0)

static void state_next_line(State* state) {
  ++state->lno;
  state->lastline = state->bol;
  state->bol = state->cur;
}

Status lex_err(State* state) {
  fprintf(stderr, "Syntax error on line %d:\n", state->lno);
  if (state->lno > 1) fprintf(stderr, "  %.*s", (int)(state->bol - state->lastline), state->lastline);
  const char* eol = (char*)memchr(state->bol, '\n', state->lim - state->bol);
  if (eol == NULL) eol = state->lim;
  fprintf(stderr, "  %.*s\n", (int)(eol - state->bol), state->bol);
  for (int i = 0; i < state->cur - state->bol + 1; ++i) fprintf(stderr, " ");
  if (state->has_err) {
    state->has_err = false;
    fprintf(stderr, "^: %s\n\n", state->err);
  } else {
    fprintf(stderr, "^: invalid token\n\n");
  }
  return LEX_ERR;
}

static Status lexi(State* state, int lex_id) {
  double num;

  int yyaccept;
  char yych;
  /*!getstate:re2c*/

  for (;;) {
    state->tok = state->cur;

    /*!re2c

    re2c:api:style = free-form;
    re2c:define:YYCTYPE = char;
    re2c:define:YYCURSOR = state->cur;
    re2c:define:YYMARKER = state->lexers[lex_id].mar;
    re2c:define:YYLIMIT = state->lim;
    re2c:define:YYGETSTATE = state->lexers[lex_id].state;
    re2c:define:YYSETSTATE = "state->lexers[lex_id].state = @@;";
    re2c:define:YYFILL     = "return LEX_FILL;";
    re2c:eof = 0;

    // Skip comments and whitespace
    "//" .* { continue; }
    [ \t]+ { continue; }

    // Track line breaks
    "\n" | "\r\n" { state_next_line(state); continue; }

    // Delimeter
    punc  = "=" | ";" | "," | "/" | "%" | "-" | "~" | "." | "[" | "]" | "(" | ")" | "{" | "}" | "!" | "|" | "<" | ">" | "^" | "+" | "*" | ":" | "?" | "&" | "\"";
    delim = punc | "\n" | " ";

    // Punctuation
    "="   { TOK(EQ); }
    "{"   { TOK(LBRACK); }
    "}"   { TOK(RBRACK); }
    "["   { TOK(LBRACE); }
    "]"   { TOK(RBRACE); }
    "("   { TOK(LPAREN); }
    ")"   { TOK(RPAREN); }
    ";"   { TOK(SEMICOLON); }
    ":"   { TOK(COLON); }
    "*"   { TOK(STAR); }
    "?"   { TOK(QUESTION); }
    ","   { TOK(COMMA); }

    // Keywords
    "pub" / delim { TOK(PUB); }
    "extern" / delim { TOK(EXTERN); }
    "import" / delim { TOK(IMPORT); }
    "let" / delim { TOK(LET); }
    "var"  / delim { TOK(VAR); }
    "const" / delim { TOK(CONST); }
    "struct" / delim { TOK(STRUCT); }
    "fn" / delim { TOK(FN); }
    "enum" / delim { TOK(ENUM); }
    "union" / delim { TOK(UNION); }
    "true" / delim { TOK(TRUE); }
    "false" / delim { TOK(FALSE); }
    "null" / delim { TOK(NULL); }
    "undefined" / delim { TOK(UNDEFINED); }
    "type" / delim { TOK(TYPE); }
    "void" / delim { TOK(VOID); }
    "bool" / delim { TOK(BOOL); }
    "continue" / delim { TOK(CONTINUE); }
    "break" / delim { TOK(BREAK); }
    "return" / delim { TOK(RETURN); }
    "if" / delim { TOK(IF); }
    "else" / delim { TOK(ELSE); }
    "switch" / delim { TOK(SWITCH); }
    "for" / delim { TOK(FOR); }
    "while" / delim { TOK(WHILE); }

    "i8" / delim { TOK(I8); }
    "i16" / delim { TOK(I16); }
    "i32" / delim { TOK(I32); }
    "i64" / delim { TOK(I64); }
    "i128" / delim { TOK(I128); }
    "u8" / delim { TOK(U8); }
    "u16" / delim { TOK(U16); }
    "u32" / delim { TOK(U32); }
    "u64" / delim { TOK(U64); }
    "u128" / delim { TOK(U128); }
    "f16" / delim { TOK(F16); }
    "f32" / delim { TOK(F32); }
    "f64" / delim { TOK(F64); }
    "f128" / delim { TOK(F128); }

    // Identifiers
    name =    [a-zA-Z][a-zA-Z0-9_]*;
    name      / delim { TOK(NAME); }

    // Numbers
    [0-9][0-9_]* / delim { if (parse_int(state, &num) == LEX_OK) { TOK_NUM(num); } else { return lex_err(state); }}
    [0-9][0-9_]* "." [0-9][0-9_]* / delim { if (parse_flt(state, &num) == LEX_OK) { TOK_NUM(num); } else { return lex_err(state); }}
    "0x" [0-9a-fA-F][0-9a-fA-F_]* / delim { if (parse_hex(state, &num) == LEX_OK) { TOK_NUM(num); } else { return lex_err(state); }}
    "0b" [01][01_]* / delim { if (parse_bin(state, &num) == LEX_OK) { TOK_NUM(num); } else { return lex_err(state); }}
    "0o" [0-9][0-9_]* / delim { if (parse_oct(state, &num) == LEX_OK) { TOK_NUM(num); } else { return lex_err(state); }}

    // String
    '"' .* '"' { TOK(STRING); }

    // WIP
    "EXPR" / delim { TOK(EXPR); }

    // * = default, unrecognized
    * { snprintf(state->err, ERR_LEN, "unrecognized character"); return lex_err(state); }

    // $ = end of source
    $ { state->done = true; TOK(EOF); }

    */
  }

  return LEX_OK;
}

Status lex(State* state) { return lexi(state, 0); }
