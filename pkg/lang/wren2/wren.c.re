#include <string.h>
#include <stdbool.h>
#include <stdio.h>

#include "wren.h"

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
  if (t == TOKEN_LINE) {
    printf("%d LINE, ", t);
  } else if (t == TOKEN_STRING) {
    str s = state_current_tokstr(state);
    printf("%d STRING, ", t);
  } else if (t == TOKEN_EOF) {
    printf("%d EOF, ", t);
  } else if (t == TOKEN_NUMBER) {
    printf("%d NUM %.2f, ", t, tok.number);
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
      if (c >= base) return ERR;
      int val = (int)c;
      sum += val * place;
      place *= base;
    }
    --current;
  }
  *num = sum;
  return OK;
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
  return OK;
}

static Status parse_flt(State* state, double* num) {
  // the regex only allows 0-9, can't fail
  const char* point = (char*)memchr(state->tok, '.', state->cur - state->tok);
  double frac;
  if (parse_num_base(state->tok, point - 1, 10, num) != OK) return ERR;
  if (parse_num_base(point + 1, state->cur - 1, 10, &frac) != OK) return ERR;
  for (int i = 0; i < state->cur - point - 1; ++i) frac /= 10;
  *num += frac;
  return OK;
}

static Status parse_bin(State* state, double* num) {
  // the regex only allows 0-1, can't fail
  return parse_num_base(state->tok + 2, state->cur - 1, 2, num);
}

static Status parse_oct(State* state, double* num) {
  if (parse_num_base(state->tok + 2, state->cur - 1, 8, num) == ERR) {
    state->has_err = true;
    snprintf(state->err, ERR_LEN, "malformed octal number");
    return ERR;
  }
  return OK;
}

#define TOK(name) do { \
    state->last.type = TOKEN_##name; \
    state->last.start = state->tok; \
    state->last.end = state->cur - 1; \
    return OK; \
  } while (0)
#define TOK_NUM(val) do { \
    state->last.type = TOKEN_NUMBER; \
    state->last.start = state->tok; \
    state->last.end = state->cur - 1; \
    state->last.number = val; \
    return OK; \
  } while (0)

static void state_next_line(State* state) {
  ++state->lno;
  state->lastline = state->bol;
  state->bol = state->cur;
}

void lex_err(State* state) {
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
    re2c:define:YYFILL     = "return FILL;";
    re2c:eof = 0;

    // Skip comments and whitespace
    "//" .* "\n" { state_next_line(state); continue; }
    [ ]+ { continue; }

    // Track newlines
    "\r\n" | "\n" { state_next_line(state); TOK(LINE); }

    // Delimeter
    punc  = "=" | "," | "/" | "%" | "-" | "~" | "." | "[" | "]" | "(" | ")" | "{" | "}" | "!" | "|" | "<" | ">" | "^" | "+" | "*" | ":" | "?" | "&";
    delim = punc | "\n" | " ";

    // Punctuation
    "="   { TOK(EQ); }
    ","   { TOK(COMMA); }
    "{"   { TOK(LBRACK); }
    "}"   { TOK(RBRACK); }
    "["   { TOK(LBRACE); }
    "]"   { TOK(RBRACE); }
    "("   { TOK(LPAREN); }
    ")"   { TOK(RPAREN); }
    "!"   { TOK(BANG); }
    "~"   { TOK(TILDE); }
    "-"   { TOK(MINUS); }
    "+"   { TOK(PLUS); }
    "*"   { TOK(STAR); }
    "/"   { TOK(SLASH); }
    "%"   { TOK(PERCENT); }
    "<"   { TOK(LT); }
    ">"   { TOK(GT); }
    "<="  { TOK(LTEQ); }
    ">="  { TOK(GTEQ); }
    "=="  { TOK(EQEQ); }
    "!="  { TOK(BANGEQ); }
    "|"   { TOK(PIPE); }
    "^"   { TOK(CARET); }
    "&"   { TOK(AMP); }
    ">>"  { TOK(GTGT); }
    "<<"  { TOK(LTLT); }
    "?"   { TOK(QUESTION); }
    ":"   { TOK(COLON); }
    "."   { TOK(DOT); }
    ".."  { TOK(DOTDOT); }
    "..." { TOK(DOTDOTDOT); }

    // Keywords
    "as"        / delim { TOK(AS); }
    "break"     / delim { TOK(BREAK); }
    "class"     / delim { TOK(CLASS); }
    "construct" / delim { TOK(CONSTRUCT); }
    "continue"  / delim { TOK(CONTINUE); }
    "else"      / delim { TOK(ELSE); }
    "false"     / delim { TOK(FALSE); }
    "for"       / delim { TOK(FOR); }
    "foreign"   / delim { TOK(FOREIGN); }
    "if"        / delim { TOK(IF); }
    "import"    / delim { TOK(IMPORT); }
    "is"        / delim { TOK(IS); }
    "null"      / delim { TOK(NULL); }
    "return"    / delim { TOK(RETURN); }
    "static"    / delim { TOK(STATIC); }
    "this"      / delim { TOK(THIS); }
    "true"      / delim { TOK(TRUE); }
    "var"       / delim { TOK(VAR); }
    "while"     / delim { TOK(WHILE); }

    // Identifiers
    name =    [a-zA-Z][a-zA-Z0-9_]*;
    name      / delim { TOK(NAME); }
    "_" name  / delim { TOK(FIELD); }
    "__" name / delim { TOK(STATIC_FIELD); }

    // Numbers
    [0-9_]+             / delim { if (parse_int(state, &num) == OK) { TOK_NUM(num); } else { lex_err(state); return ERR; }}
    [0-9_]+ "." [0-9_]+ / delim { if (parse_flt(state, &num) == OK) { TOK_NUM(num); } else { lex_err(state); return ERR; }}
    "0x" [0-9a-fA-F_]+  / delim { if (parse_hex(state, &num) == OK) { TOK_NUM(num); } else { lex_err(state); return ERR; }}
    "0b" [01_]+         / delim { if (parse_bin(state, &num) == OK) { TOK_NUM(num); } else { lex_err(state); return ERR; }}
    "0o" [0-9_]+        / delim { if (parse_oct(state, &num) == OK) { TOK_NUM(num); } else { lex_err(state); return ERR; }}

    // String
    // todo: string + interpolation
    // '"' ((. \ "\"") | "\n")* '"' { TOK(STRING); }
    // '"' .* "%(" { TOK(INTERPOLATION); }

    // * = default, unrecognized
    * { lex_err(state); return ERR; }

    // $ = end of source
    $ { state->done = true; TOK(EOF); }

    */
  }

  return OK;
}

Status lex(State* state) { return lexi(state, 0); }
