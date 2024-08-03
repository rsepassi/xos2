%include { #include "ry0.h" }

%token_type Token
%token_prefix TOKEN_
%extra_context { State* state }

%parse_accept {}

source ::= struct_body EOF.

struct_body ::= .
struct_body ::= struct_fields.
struct_body ::= struct_fields decls.
struct_body ::= decls.
struct_body ::= decls struct_fields.
struct_body ::= decls struct_fields decls.

struct_fields ::= struct_field SEMICOLON.
struct_fields ::= struct_fields struct_field SEMICOLON.
struct_field ::= NAME COLON expr.

decls ::= decl SEMICOLON.
decls ::= decls decl SEMICOLON.

decl ::= decl_qual decl_bind NAME decl_type EQ expr.

decl_qual ::= .
decl_qual ::= PUB.
decl_bind ::= LET.
decl_bind ::= VAR.

decl_type ::= .
decl_type ::= COLON expr.

type_qualifier ::= CONST.

type_number ::= type_int.
type_number ::= type_flt.
type_array ::= LBRACE NUMBER RBRACE expr.
type_struct ::= STRUCT LBRACK struct_body RBRACK.
type_enum ::= ENUM LBRACK enum_body RBRACK.
type_enum ::= ENUM LPAREN type_int RPAREN LBRACK enum_body RBRACK.
type_union ::= UNION LBRACK struct_body RBRACK.
type_union ::= UNION LPAREN NAME RPAREN LBRACK struct_body RBRACK.
type_pointer ::= STAR expr.
type_optional ::= QUESTION expr.

type_int ::= I8.
type_int ::= I16.
type_int ::= I32.
type_int ::= I64.
type_int ::= I128.
type_int ::= U8.
type_int ::= U16.
type_int ::= U32.
type_int ::= U64.
type_int ::= U128.
type_flt ::= F16.
type_flt ::= F32.
type_flt ::= F64.
type_flt ::= F128.

type_spec ::= type_qualifier expr.
type_spec ::= TYPE.
type_spec ::= BOOL.
type_spec ::= VOID.
type_spec ::= FN fn_def.
type_spec ::= EXTERN FN fn_def.
type_spec ::= type_number.
type_spec ::= type_array.
type_spec ::= type_struct.
type_spec ::= type_enum.
type_spec ::= type_union.
type_spec ::= type_pointer.
type_spec ::= type_optional.

literal ::= NUMBER.
literal ::= STRING.
literal ::= TRUE.
literal ::= FALSE.
literal ::= NULL.
literal ::= UNDEFINED.

import ::= IMPORT STRING.

fn_def ::= expr LPAREN fn_args RPAREN.
fn_def ::= expr LPAREN fn_args RPAREN block.

block ::= LBRACK RBRACK.
block ::= LBRACK stmts RBRACK.

stmts ::= stmt.
stmts ::= stmts stmt.

stmt ::= decl SEMICOLON.
stmt ::= assignment SEMICOLON.
stmt ::= CONTINUE SEMICOLON.
stmt ::= BREAK SEMICOLON.
stmt ::= RETURN expr SEMICOLON.
stmt ::= block.
stmt ::= if.
stmt ::= switch.
stmt ::= while.
stmt ::= for.

assignment ::= lhs EQ expr.

if ::= if_single.
if ::= if_single else.
else ::= ELSE if_single.
else ::= ELSE block.
if_single ::= IF LPAREN expr RPAREN block.

switch ::= SWITCH LPAREN expr RPAREN LBRACK switch_body RBRACK.
switch_body ::= .

while ::= WHILE block.
while ::= WHILE LPAREN expr RPAREN block.
while ::= WHILE LPAREN expr RPAREN LPIPE NAME RPIPE block.

for ::= FOR LPAREN expr RPAREN loop_capture block.

loop_capture ::= LPIPE loop_capture_list RPIPE.
loop_capture_list ::= NAME.
loop_capture_list ::= NAME COMMA loop_capture_list.

fn_args ::= .
fn_args ::= fn_arg.
fn_args ::= fn_arg COMMA fn_args.
fn_arg ::= NAME COLON expr.

enum_body ::= .
enum_body ::= enum_field.
enum_body ::= enum_field COMMA enum_body.
enum_field ::= NAME.
enum_field ::= NAME EQ NUMBER.

lhs ::= NAME.

expr ::= expr_base.

expr_base ::= NAME.
expr_base ::= type_spec.
expr_base ::= import.
expr_base ::= literal.

// expr_base ::= LPAREN expr_binary RPAREN.
// expr_binary ::= expr_base infix_op expr_base.

// assignment ::= lhs infix_op EQ expr.
// infix: < <= > >= == != && || & | ^ + - / * << >> %
// prefix: - ~ ! &
// a.b a() a[b]
// a ? B : c
// infix_op ::= LT.
// infix_op ::= GT.

// pointer deref *a or a.*
// struct, union, enum literals
// blocks (if/else, switch, etc)
// cast, sizeof, alignof, ...
// optional unwrap .? orelse
// error unwrap catch

// TODO:
// * string interpolation
// * bitfields
// * callconv
// * try/catch: result/error
// * while loop continuation
// * defer, errdefer
// * async/await
// * anytype, generics
// * interfaces

%parse_failure {}
%syntax_error { state->has_err = true; }
