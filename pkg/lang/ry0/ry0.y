%include { #include "ry0.h" }

%token_type Token
%token_prefix TOKEN_
%extra_context { State* state }

%parse_accept {}

source ::= struct_body EOF.

// struct body = [decls] [fields] [decls]
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

expr ::= expr_base. [EXPRBASE]
expr ::= expr_field.
expr ::= expr_fncall.
expr ::= LPAREN expr RPAREN.
expr ::= expr_array_access.
expr ::= expr_prefix.
expr ::= expr_if.
expr ::= switch.
expr ::= block_labeled.

expr_base ::= type_spec.
expr_base ::= NAME.
expr_base ::= import.
expr_base ::= literal.

type_spec ::= type_qualifier expr. [EXPRTYPE]
type_spec ::= TYPE.
type_spec ::= BOOL.
type_spec ::= VOID.
type_spec ::= FN fn_def.
type_spec ::= EXTERN FN fn_def.
type_spec ::= CCALL FN fn_def.
type_spec ::= type_number.
type_spec ::= type_array.
type_spec ::= type_struct.
type_spec ::= type_signature.
type_spec ::= type_enum.
type_spec ::= type_union.
type_spec ::= type_optional.

type_qualifier ::= CONST.

type_number ::= type_int.
type_number ::= type_flt.
type_array ::= LBRACE NUMBER RBRACE expr. [EXPRTYPE]
type_struct ::= STRUCT LBRACK struct_body RBRACK.
type_signature ::= SIGNATURE LBRACK struct_body RBRACK.
type_enum ::= ENUM LBRACK enum_body RBRACK.
type_enum ::= ENUM LPAREN type_int RPAREN LBRACK enum_body RBRACK.
type_union ::= UNION LBRACK struct_body RBRACK.
type_union ::= UNION LPAREN NAME RPAREN LBRACK struct_body RBRACK.
type_optional ::= QUESTION expr. [EXPRTYPE]

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

literal ::= NUMBER.
literal ::= STRING.
literal ::= TRUE.
literal ::= FALSE.
literal ::= NULL.
literal ::= UNDEFINED.
literal ::= literal_enum.
literal ::= literal_struct.
literal ::= literal_array.

literal_enum ::= DOT NAME.
literal_struct ::= DOT LBRACK RBRACK.
literal_struct ::= DOT LBRACK literal_struct_fields RBRACK.
literal_array ::= DOT LBRACE RBRACE.
literal_array ::= DOT LBRACE exprs_comma RBRACE.

literal_struct_fields  ::= literal_struct_field.
literal_struct_fields  ::= literal_struct_field COMMA literal_struct_field.
literal_struct_field ::= DOT NAME expr.

import ::= IMPORT STRING.

fn_def ::= LPAREN fn_args RPAREN expr.
fn_def ::= LPAREN fn_args RPAREN expr block.

block ::= LBRACK RBRACK.
block ::= LBRACK stmts RBRACK.
block_labeled ::= block_label block.
block_label ::= NAME COLON.
block_label_ref ::= COLON NAME.

stmts ::= stmt.
stmts ::= stmts stmt.

stmt ::= decl SEMICOLON.
stmt ::= assignment SEMICOLON.
stmt ::= CONTINUE SEMICOLON.
stmt ::= CONTINUE block_label_ref SEMICOLON.
stmt ::= BREAK SEMICOLON.
stmt ::= BREAK block_label_ref SEMICOLON.
stmt ::= DEFER block SEMICOLON.
stmt ::= ERRDEFER block SEMICOLON.
stmt ::= YIELD SEMICOLON.
stmt ::= YIELD expr SEMICOLON.
stmt ::= RESUME expr SEMICOLON.
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

expr_if ::= if_single else.

switch ::= SWITCH LPAREN expr RPAREN LBRACK switch_body RBRACK.
switch_body ::= .

while ::= WHILE while_cond while_capture while_continue block.
while ::= block_label WHILE while_cond while_capture while_continue block.
while_continue ::= .
while_continue ::= COLON LPAREN stmt RPAREN.
while_cond ::= .
while_cond ::= LPAREN expr RPAREN.
while_capture ::= .
while_capture ::= LPIPE NAME RPIPE.

for ::= FOR LPAREN expr RPAREN loop_capture block.
for ::= block_label FOR LPAREN expr RPAREN loop_capture block.

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

expr_field ::= expr DOT NAME. [DOT]
expr_fncall ::= expr LPAREN RPAREN. [LPAREN]
expr_fncall ::= expr LPAREN exprs_comma RPAREN. [LPAREN]
expr_array_access ::= expr LBRACE expr RBRACE. [DOT]

expr_prefix ::= AMP expr. [EXPRPREFIX]
expr_prefix ::= STAR expr. [EXPRPREFIX]
expr_prefix ::= MINUS expr. [EXPRPREFIX]
expr_prefix ::= BANG expr. [EXPRPREFIX]
expr_prefix ::= TILDE expr. [EXPRPREFIX]
expr_prefix ::= ASYNC expr. [EXPRPREFIX]
expr_prefix ::= AWAIT expr. [EXPRPREFIX]

exprs_comma ::= expr.
exprs_comma ::= expr COMMA exprs_comma.

%nonassoc EXPRTYPE.
%nonassoc EXPRBASE.
%nonassoc EXPRINFIX.
%left EXPRPREFIX.
%left DOT LPAREN RPAREN LBRACE RBRACE.
%left LBRACK RBRACK.
%left COLON.

// assignment ::= lhs infix_op EQ expr.
// infix: < <= > >= == != && || & | ^ + - / * << >> %
// a ? B : c

// cast, sizeof, alignof, ...
// optional unwrap .? orelse
// error unwrap catch

// TODO:
// * switch_body
// * string interpolation
// * bitfields
// * try/catch: result/error

%parse_failure {}
%syntax_error { state->has_err = true; }
