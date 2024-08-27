%include {
#include <stdlib.h>
#include <string.h>
#include "ry0.h"
#define NULL_TOKEN (Token){.type = TokenType__Sentinel}
#define NODE_INIT(ttype) node_get(&state->ctx, node_init(&state->ctx, ttype))
#define NODE_APPEND(head, el, field) do { \
  NodeHandle* tail = &head->data.field.list.tail; \
  if (*tail == 0) { \
    head->data.field.list.next = NH(el); \
  } else { \
    Node* tnode = NODE_GET(*tail); \
    tnode->data.field.list.next = NH(el); \
  } \
  *tail = NH(el); \
  } while (0)

#define NODE_GET(h) node_get(&state->ctx, h)
#define NH(node) node_get_handle(&state->ctx, node)

#define INFIX(a, b, c, theop) do { \
  a = NODE_INIT(NodeInfix); \
  a->data.infix.lhs = NH(b); \
  a->data.infix.rhs = NH(c); \
  a->data.infix.op = Infix_ ## theop; \
  } while(0)

#ifndef NDEBUG
#define YYCOVERAGE
#endif
}

%token_type Token
%token_prefix TOKEN_
%extra_context { State* state }
%default_type { Node* }

%parse_accept {}

source_file ::= struct_body(R) EOF.
  { state->root = NH(R); }

struct_body(L) ::= .
  { L = NODE_INIT(NodeStructBody); }
struct_body(L) ::= struct_fields(R).
  { L = NODE_INIT(NodeStructBody); L->data.struct_body.fields = NH(R); }
struct_body(L) ::= decls(R).
  { L = NODE_INIT(NodeStructBody); L->data.struct_body.decls = NH(R); }
struct_body(L) ::= struct_fields(R1) decls(R2).
  { L = NODE_INIT(NodeStructBody);
    L->data.struct_body.fields = NH(R1);
    L->data.struct_body.decls = NH(R2); }

struct_fields(L) ::= struct_field(R) SEMICOLON.
  { L = R; }
struct_fields(L) ::= struct_fields(R1) struct_field(R2) SEMICOLON.
  { NODE_APPEND(R1, R2, struct_field); L = R1; }
struct_field(L) ::= NAME(R1) COLON expr(R2).
  { L = NODE_INIT(NodeStructField);
    L->data.struct_field.name = R1;
    L->data.struct_field.type = NH(R2); }
struct_field(L) ::= NAME(R1) COLON expr(R2) EQ expr(R3).
  { L = NODE_INIT(NodeStructField);
    L->data.struct_field.name = R1;
    L->data.struct_field.type = NH(R2);
    L->data.struct_field.xdefault = NH(R3); }

decls(L) ::= decl(R) SEMICOLON.
  { L = R; }
decls(L) ::= decls(R1) decl(R2) SEMICOLON.
  { NODE_APPEND(R1, R2, decl); L = R1; }

decl(L) ::= decl_quals(R1) decl_bind(R2) NAME(R3) decl_type(R4) EQ expr (R5).
  { L = NODE_INIT(NodeDecl);
    L->data.decl.quals = R1;
    L->data.decl.var = R2;
    L->data.decl.name = R3;
    L->data.decl.type = NH(R4);
    L->data.decl.expr = NH(R5); }

%type decl_quals {DeclQual}
%type decl_qual {DeclQual}
decl_quals(L) ::= .                              { L = 0; }
decl_quals(L) ::= decl_quals(R1) decl_qual(R2).  { L = R1 | R2; }
decl_qual(L) ::= PUB.                            { L = DeclQual_PUB; }
decl_qual(L) ::= TLS.                            { L = DeclQual_THREADLOCAL; }

%type decl_bind {bool}
decl_bind(L) ::= LET. { L = false; }
decl_bind(L) ::= VAR. { L = true; }

decl_type(L) ::= .              { L = NULL; }
decl_type(L) ::= COLON expr(R). { L = R; }

expr(L) ::= expr_regular(R).
  { L = NODE_INIT(NodeExpr); L->data.expr.expr = NH(R); }
expr(L) ::= expr_ctrlflow(R). [EXPR_CTRLF_EXPR]
  { L = NODE_INIT(NodeExpr); L->data.expr.expr = NH(R); }

expr_regular(L) ::= expr_base(R). [EXPR_BASE] { L = R; }
expr_regular(L) ::= expr_field(R).           { L = R; }
expr_regular(L) ::= expr_fncall(R).          { L = R; }
expr_regular(L) ::= expr_array_access(R).    { L = R; }
expr_regular(L) ::= expr_prefix(R).          { L = R; }
expr_regular(L) ::= expr_infix(R).           { L = R; }
expr_regular(L) ::= expr_optional(R).        { L = R; }
expr_regular(L) ::= block_labeled(R).        { L = R; }
expr_regular(L) ::= LPAREN expr(R) RPAREN.   { L = R; }

expr_ctrlflow(L) ::= if(R).                   { L = R; }
expr_ctrlflow(L) ::= switch(R).               { L = R; }

expr_base(L) ::= type_spec(R). { L = R; }
expr_base(L) ::= import (R).   { L = R; }
expr_base(L) ::= literal(R).   { L = R; }
expr_base(L) ::= NAME(R).
  { L = NODE_INIT(NodeName); L->data.name = R; }

type_spec(L) ::= type_spec2(R). [EXPR_TYPE] { L = R; }

type_spec2(L) ::= TYPE.
  { L = NODE_INIT(NodeTypeSpec); L->data.type.type = Type2_type; }
type_spec2(L) ::= BOOL.
  { L = NODE_INIT(NodeTypeSpec); L->data.type.type = Type2_bool; }
type_spec2(L) ::= VOID.
  { L = NODE_INIT(NodeTypeSpec); L->data.type.type = Type2_void; }
type_spec2(L) ::= type_number(R).
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_num;
    L->data.type.data.num = R; }

type_spec2(L) ::= type_fn(R).        { L = R; }
type_spec2(L) ::= type_array(R).     { L = R; }
type_spec2(L) ::= type_struct(R).    { L = R; }
type_spec2(L) ::= type_signature(R). { L = R; }
type_spec2(L) ::= type_enum(R).      { L = R; }
type_spec2(L) ::= type_union(R).     { L = R; }
type_spec2(L) ::= type_optional(R).  { L = R; }

type_fn(L) ::= fn_quals(R1) FN fn_main(R2).
  { L = R2; L->data.type.data.fndef.quals = R1; }

fn_main(L) ::= fn_def(R).  { L = R; }
fn_main(L) ::= fn_sig(R). { L = R; }

type_array(L) ::= LBRACE expr(R1) RBRACE expr(R2).
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_array;
    L->data.type.data.array.count = NH(R1);
    L->data.type.data.array.type = NH(R2); }
    
type_struct(L) ::= STRUCT LBRACK struct_body(R) RBRACK.
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_struct;
    L->data.type.data.xstruct = NH(R); }

type_signature(L) ::= SIGNATURE LBRACK struct_body(R) RBRACK.
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_signature;
    L->data.type.data.xstruct = NH(R); }

type_union(L) ::= UNION LBRACK struct_body(R) RBRACK.
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_union;
    L->data.type.data.xunion.body = NH(R); }

type_union(L) ::= UNION expr(R1) LBRACK struct_body(R2) RBRACK.
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_union;
    L->data.type.data.xunion.tag_type = NH(R1);
    L->data.type.data.xunion.body = NH(R2); }

type_enum(L) ::= ENUM LBRACK enum_body(R) RBRACK.
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_enum;
    L->data.type.data.xenum.elements = NH(R); }

type_enum(L) ::= ENUM expr(R1) LBRACK enum_body(R2) RBRACK.
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_enum;
    L->data.type.data.xenum.backing_type = NH(R1);
    L->data.type.data.xenum.elements = NH(R2); }

type_optional(L) ::= QUESTION expr(R).
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_optional;
    L->data.type.data.expr = NH(R); }

%type type_int {NumType}
%type type_flt {NumType}
%type type_number {NumType}
type_number(L) ::= type_int(R). { L = R; }
type_number(L) ::= type_flt(R). { L = R; }
type_int(L) ::= I8.   { L = I8; }
type_int(L) ::= I16.  { L = I16; }
type_int(L) ::= I32.  { L = I32; }
type_int(L) ::= I64.  { L = I64; }
type_int(L) ::= I128. { L = I128; }
type_int(L) ::= U8.   { L = U8; }
type_int(L) ::= U16.  { L = U16; }
type_int(L) ::= U32.  { L = U32; }
type_int(L) ::= U64.  { L = U64; }
type_int(L) ::= U128. { L = U128; }
type_flt(L) ::= F16.  { L = F16; }
type_flt(L) ::= F32.  { L = F32; }
type_flt(L) ::= F64.  { L = F64; }
type_flt(L) ::= F128. { L = F128; }

literal(L) ::= NUMBER(R).
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_num;
    L->data.literal.data.tok = R; }
literal(L) ::= STRING(R).
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_str;
    L->data.literal.data.tok = R; }
literal(L) ::= TRUE.
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_true; }
literal(L) ::= FALSE.
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_false; }
literal(L) ::= NULL.
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_null; }
literal(L) ::= UNDEFINED.
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_undefined; }
literal(L) ::= literal_enum(R).   { L = R; }
literal(L) ::= literal_struct(R). { L = R; }
literal(L) ::= literal_array(R).  { L = R; }

literal_enum(L) ::= DOT NAME(R).
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_enum;
    L->data.literal.data.tok = R; }

literal_struct(L) ::= DOT LBRACK RBRACK.
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_struct; }
literal_struct(L) ::= DOT LBRACK literal_struct_fields(R) RBRACK.
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_struct;
    L->data.literal.data.struct_field = NH(R); }
literal_struct(L) ::= DOT LBRACK literal_struct_fields(R) COMMA RBRACK.
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_struct;
    L->data.literal.data.struct_field = NH(R); }

literal_array(L) ::= DOT LBRACE RBRACE.
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_array; }
literal_array(L) ::= DOT LBRACE exprs_comma(R) RBRACE.
  { L = NODE_INIT(NodeLiteral);
    L->data.literal.type = Literal_array;
    L->data.literal.data.array_entry = NH(R); }

literal_struct_fields(L) ::= literal_struct_field(R). { L = R; }
literal_struct_fields(L) ::= literal_struct_fields(R1) COMMA literal_struct_field(R2).
  { NODE_APPEND(R1, R2, literal_struct_field); L = R1; }

literal_struct_field(L) ::= DOT NAME(R1) EQ expr(R2).
  { L = NODE_INIT(NodeLiteralStructField);
    L->data.literal_struct_field.name = R1;
    L->data.literal_struct_field.expr = NH(R2); }

import(L) ::= IMPORT LPAREN expr(R) RPAREN.
  { L = NODE_INIT(NodeImport); L->data.expr.expr = NH(R); }

%type fn_quals {FnQual}
%type fn_qual {FnQual}
fn_quals(L) ::= .                         { L = 0; }
fn_quals(L) ::= fn_quals(R1) fn_qual(R2). { L = R1 | R2; }
fn_qual(L) ::= EXTERN.                    { L = FnQual_EXTERN; }
fn_qual(L) ::= CCALL.                     { L = FnQual_CCALL; }

fn_def(L) ::= LPAREN fn_args(R1) RPAREN expr(R2) block(R3).
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_fndef;
    L->data.type.data.fndef.args = NH(R1);
    L->data.type.data.fndef.ret_type = NH(R2);
    L->data.type.data.fndef.body = NH(R3); }

fn_sig(L) ::= LPAREN fn_args(R1) RPAREN expr(R2).
  { L = NODE_INIT(NodeTypeSpec);
    L->data.type.type = Type2_fndef;
    L->data.type.data.fndef.args = NH(R1);
    L->data.type.data.fndef.ret_type = NH(R2); }

block(L) ::= LBRACK RBRACK.
  { L = NODE_INIT(NodeBlock);
    L->data.block.label = NULL_TOKEN; }
block(L) ::= LBRACK stmts(R) RBRACK.
  { L = NODE_INIT(NodeBlock);
    L->data.block.stmts = NH(R);
    L->data.block.label = NULL_TOKEN; }
block_labeled(L) ::= block_label(R1) block(R2).
  { L = R2; L->data.block.label = R1; }

%type block_label {Token}
block_label(L) ::= COLON NAME(R).     { L = R; }

stmts(L) ::= stmt(R).
  { L = R; }
stmts(L) ::= stmts(R1) stmt(R2).
  { NODE_APPEND(R1, R2, stmt); L = R1; }

stmt(L) ::= stmt2(R).
  { L = NODE_INIT(NodeStmt); L->data.stmt.stmt = NH(R); }

stmt2(L) ::= SEMICOLON. { L = NODE_INIT(NodeNoop); }
stmt2(L) ::= expr_regular(R) SEMICOLON.          { L = R; }
stmt2(L) ::= expr_ctrlflow(R). [EXPR_CTRLF_STMT] { L = R; }
stmt2(L) ::= decl(R) SEMICOLON.       { L = R; }
stmt2(L) ::= infixeql(R) SEMICOLON.       { L = R; }
stmt2(L) ::= assignment(R) SEMICOLON. { L = R; }
stmt2(L) ::= block(R).                { L = R; }
stmt2(L) ::= while(R).                { L = R; }
stmt2(L) ::= for(R).                  { L = R; }
stmt2(L) ::= CONTINUE SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_continue; }
stmt2(L) ::= CONTINUE block_label(R) SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_continue;
    L->data.stmt_ctrl.label = R; }
stmt2(L) ::= BREAK SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_break; }
stmt2(L) ::= BREAK block_label(R) SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_break;
    L->data.stmt_ctrl.label = R; }
stmt2(L) ::= BREAK block_label(R1) expr(R2) SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_break;
    L->data.stmt_ctrl.label = R1;
    L->data.stmt_ctrl.body = NH(R2); }
stmt2(L) ::= DEFER block(R) SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_defer;
    L->data.stmt_ctrl.body = NH(R); }
stmt2(L) ::= ERRDEFER block(R) SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_errdefer;
    L->data.stmt_ctrl.body = NH(R); }
stmt2(L) ::= YIELD SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_yield; }
stmt2(L) ::= YIELD expr(R) SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_yield;
    L->data.stmt_ctrl.body = NH(R); }
stmt2(L) ::= RESUME expr(R) SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_resume;
    L->data.stmt_ctrl.body = NH(R); }
stmt2(L) ::= RETURN SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_return; }
stmt2(L) ::= RETURN expr(R) SEMICOLON.
  { L = NODE_INIT(NodeStmtCtrl);
    L->data.stmt_ctrl.keyword = StmtCtrl_return;
    L->data.stmt_ctrl.body = NH(R); }

assignment(L) ::= expr(R1) EQ expr(R2).
  { L = NODE_INIT(NodeAssign);
    L->data.assign.lhs = NH(R1);
    L->data.assign.rhs = NH(R2); }

if(L) ::= if_single(R).
  { L = R; }
if(L) ::= if_single(R1) ELSE if(R2).
  { NODE_APPEND(R1, R2, xif); L = R1; }
if(L) ::= if_single(R1) ELSE block(R2).
  { NODE_APPEND(R1, R2, xif); L = R1; }
if_single(L) ::= IF LPAREN expr(R1) RPAREN block(R2).
  { L = NODE_INIT(NodeIf);
    L->data.xif.cond = NH(R1);
    L->data.xif.body = NH(R2); }

while(L) ::= block_label(R1) while2(R2).
  { L = R2;
    L->data.xwhile.label = NH(NODE_INIT(NodeName));
    NODE_GET(L->data.xwhile.label)->data.name = R1; }
while(L) ::= while2(R).  { L = R; }

while2(L) ::= WHILE LPAREN while_cond(R1) RPAREN while_capture(R2) while_continue(R3) block(R4).
  { L = NODE_INIT(NodeWhile);
    L->data.xwhile.cond = NH(R1);
    L->data.xwhile.capture = NH(R2);
    L->data.xwhile.xcontinue = NH(R3);
    L->data.xwhile.body = NH(R4); }

while_continue(L) ::= .  { L = NULL; }
while_continue(L) ::= COLON LPAREN stmt(R) RPAREN. { L = R; }
while_cond(L) ::= expr(R). { L = R; }
while_capture(L) ::= . { L = NULL; }
while_capture(L) ::= PIPE NAME(R) PIPE.
  { L = NODE_INIT(NodeName); L->data.name = R; }

for(L) ::= block_label(R1) for2(R2).
  { L = R2; L->data.xfor.label = R1; }
for(L) ::= for2(R).  { L = R; }

for2(L) ::= FOR LPAREN exprs_comma(R1) RPAREN loop_capture(R2) block(R3).
  { L = NODE_INIT(NodeFor);
    L->data.xfor.label = NULL_TOKEN;
    L->data.xfor.expr = NH(R1);
    L->data.xfor.capture = NH(R2);
    L->data.xfor.body = NH(R3); }

loop_capture(L) ::= PIPE loop_capture_list(R) PIPE. { L = R; }
loop_capture_list(L) ::= NAME(R).
  { L = NODE_INIT(NodeCapture); L->data.capture.name = R; }
loop_capture_list(L) ::= NAME(R1) COMMA loop_capture_list(R2).
  { L = NODE_INIT(NodeCapture); L->data.name = R1; NODE_APPEND(L, R2, capture); }

fn_args(L) ::= . { L = NULL; }
fn_args(L) ::= fn_arg(R). { L = R; }
fn_args(L) ::= fn_arg(R1) COMMA fn_args(R2).
  { NODE_APPEND(R1, R2, fnarg); L = R1; }
fn_arg(L) ::= NAME(R1) COLON expr(R2).
  { L = NODE_INIT(NodeFnArg);
    L->data.fnarg.name = R1;
    L->data.fnarg.type = NH(R2); }
fn_arg(L) ::= expr(R).
  { L = NODE_INIT(NodeFnArg);
    L->data.fnarg.name = NULL_TOKEN;
    L->data.fnarg.type = NH(R); }

enum_body(L) ::= .                     { L = NULL; }
enum_body(L) ::= enum_fields(R).       { L = R; }
enum_body(L) ::= enum_fields(R) COMMA. { L = R; }


enum_fields(L) ::= enum_field(R).
  { L = R; }
enum_fields(L) ::= enum_fields(R1) COMMA enum_field(R2).
  { NODE_APPEND(R1, R2, enumfield); L = R1; }
enum_field(L) ::= NAME(R).
  { L = NODE_INIT(NodeEnumField);
    L->data.enumfield.name = R; }
enum_field(L) ::= NAME(R1) EQ expr(R2).
  { L = NODE_INIT(NodeEnumField);
    L->data.enumfield.name = R1;
    L->data.enumfield.value = NH(R2); }

expr_field(L) ::= expr(R1) DOT NAME(R2). [DOT]
  { L = NODE_INIT(NodeFieldAccess);
    L->data.expr_field.base = NH(R1);
    L->data.expr_field.field = R2; }

expr_fncall(L) ::= expr(R) LPAREN RPAREN. [LPAREN]
  { L = NODE_INIT(NodeFnCall);
    L->data.fncall.fn = NH(R); }
expr_fncall(L) ::= expr(R1) LPAREN exprs_comma(R2) RPAREN. [LPAREN]
  { L = NODE_INIT(NodeFnCall);
    L->data.fncall.fn = NH(R1);
    L->data.fncall.args = NH(R2); }

expr_array_access(L) ::= expr(R1) LBRACE expr(R2) RBRACE. [LBRACE]
  { L = NODE_INIT(NodeArrayAccess);
    L->data.expr_array.base = NH(R1);
    L->data.expr_array.idx = NH(R2); }

expr_optional(L) ::= expr(R) DOTQ. [DOTQ]
  { L = NODE_INIT(NodeOptional); L->data.expr.expr = NH(R); }

expr_prefix(L) ::= AMP expr(R). [BANG]
  { L = NODE_INIT(NodeExprPrefix);
    L->data.expr_prefix.base = NH(R);
    L->data.expr_prefix.prefix = ExprPrefix_amp; }
expr_prefix(L) ::= STAR expr(R). [BANG]
  { L = NODE_INIT(NodeExprPrefix);
    L->data.expr_prefix.base = NH(R);
    L->data.expr_prefix.prefix = ExprPrefix_star; }
expr_prefix(L) ::= MINUS expr(R). [BANG]
  { L = NODE_INIT(NodeExprPrefix);
    L->data.expr_prefix.base = NH(R);
    L->data.expr_prefix.prefix = ExprPrefix_minus; }
expr_prefix(L) ::= BANG expr(R).
  { L = NODE_INIT(NodeExprPrefix);
    L->data.expr_prefix.base = NH(R);
    L->data.expr_prefix.prefix = ExprPrefix_bang; }
expr_prefix(L) ::= TILDE expr(R).
  { L = NODE_INIT(NodeExprPrefix);
    L->data.expr_prefix.base = NH(R);
    L->data.expr_prefix.prefix = ExprPrefix_tilde; }
expr_prefix(L) ::= ASYNC expr(R).
  { L = NODE_INIT(NodeExprPrefix);
    L->data.expr_prefix.base = NH(R);
    L->data.expr_prefix.prefix = ExprPrefix_async; }
expr_prefix(L) ::= AWAIT expr(R).
  { L = NODE_INIT(NodeExprPrefix);
    L->data.expr_prefix.base = NH(R);
    L->data.expr_prefix.prefix = ExprPrefix_await; }
expr_prefix(L) ::= CONST expr(R).
  { L = NODE_INIT(NodeExprPrefix);
    L->data.expr_prefix.base = NH(R);
    L->data.expr_prefix.prefix = ExprPrefix_const; }
expr_prefix(L) ::= TRY expr(R).
  { L = NODE_INIT(NodeExprPrefix);
    L->data.expr_prefix.base = NH(R);
    L->data.expr_prefix.prefix = ExprPrefix_try; }

expr_infix(L) ::= expr(R1) STAR expr(R2). [STAR] { INFIX(L, R1, R2, STAR); }
expr_infix(L) ::= expr(R1) PERCENT expr(R2). [PERCENT] { INFIX(L, R1, R2, PERCENT); }
expr_infix(L) ::= expr(R1) LTLT expr(R2). [LTLT] { INFIX(L, R1, R2, LTLT); }
expr_infix(L) ::= expr(R1) GTGT expr(R2). [GTGT] { INFIX(L, R1, R2, GTGT); }
expr_infix(L) ::= expr(R1) PLUS expr(R2). [PLUS] { INFIX(L, R1, R2, PLUS); }
expr_infix(L) ::= expr(R1) MINUS expr(R2). [MINUS] { INFIX(L, R1, R2, MINUS); }
expr_infix(L) ::= expr(R1) PIPE expr(R2). [PIPE] { INFIX(L, R1, R2, PIPE); }
expr_infix(L) ::= expr(R1) CARAT expr(R2). [CARAT] { INFIX(L, R1, R2, CARAT); }
expr_infix(L) ::= expr(R1) AMP expr(R2). [AMP] { INFIX(L, R1, R2, AMP); }
expr_infix(L) ::= expr(R1) DOT2 expr(R2). [DOT2] { INFIX(L, R1, R2, DOT2); }
expr_infix(L) ::= expr(R1) AMP2 expr(R2). [AMP2] { INFIX(L, R1, R2, AMP2); }
expr_infix(L) ::= expr(R1) PIPE2 expr(R2). [PIPE2] { INFIX(L, R1, R2, PIPE2); }
expr_infix(L) ::= expr(R1) EQEQ expr(R2). [EQEQ] { INFIX(L, R1, R2, EQEQ); }
expr_infix(L) ::= expr(R1) NEQ expr(R2). [NEQ] { INFIX(L, R1, R2, NEQ); }
expr_infix(L) ::= expr(R1) LT expr(R2). [LT] { INFIX(L, R1, R2, LT); }
expr_infix(L) ::= expr(R1) LTE expr(R2). [LTE] { INFIX(L, R1, R2, LTE); }
expr_infix(L) ::= expr(R1) GT expr(R2). [GT] { INFIX(L, R1, R2, GT); }
expr_infix(L) ::= expr(R1) GTE expr(R2). [GTE] { INFIX(L, R1, R2, GTE); }
expr_infix(L) ::= expr(R1) SLASH expr(R2). [SLASH] { INFIX(L, R1, R2, SLASH); }

infixeql(L) ::= expr(R1) infix_op(R2) EQ expr(R3).
  { L = NODE_INIT(NodeInfixAssign);
    L->data.infix.lhs = NH(R1);
    L->data.infix.rhs = NH(R3);
    L->data.infix.op = R2; }

%type infix_op {InfixOp}
infix_op(L) ::= SLASH. { L = Infix_SLASH; }
infix_op(L) ::= PERCENT. { L = Infix_PERCENT; }
infix_op(L) ::= LTLT. { L = Infix_LTLT; }
infix_op(L) ::= GTGT. { L = Infix_GTGT; }
infix_op(L) ::= PLUS. { L = Infix_PLUS; }
infix_op(L) ::= MINUS. { L = Infix_MINUS; }
infix_op(L) ::= PIPE. { L = Infix_PIPE; }
infix_op(L) ::= CARAT. { L = Infix_CARAT; }
infix_op(L) ::= AMP. { L = Infix_AMP; }
infix_op(L) ::= DOT2. { L = Infix_DOT2; }
infix_op(L) ::= AMP2. { L = Infix_AMP2; }
infix_op(L) ::= PIPE2. { L = Infix_PIPE2; }
infix_op(L) ::= EQEQ. { L = Infix_EQEQ; }
infix_op(L) ::= NEQ. { L = Infix_NEQ; }
infix_op(L) ::= LT. { L = Infix_LT; }
infix_op(L) ::= LTE. { L = Infix_LTE; }
infix_op(L) ::= GT. { L = Infix_GT; }
infix_op(L) ::= GTE. { L = Infix_GTE; }

exprs_comma(L) ::= expr(R).
  { L = R; }
exprs_comma(L) ::= exprs_comma(R1) COMMA expr(R2).
  { NODE_APPEND(R1, R2, expr); L = R1; }

switch(L) ::= SWITCH LPAREN expr(R1) RPAREN LBRACK switch_body(R2) RBRACK.
  { L = NODE_INIT(NodeSwitch);
    L->data.xswitch.expr = NH(R1);
    L->data.xswitch.body = NH(R2); }

switch_body(L) ::= .
  { L = NULL; }
switch_body(L) ::= switch_clauses(R).
  { L = R; }
switch_body(L) ::= switch_clauses(R) COMMA.
  { L = R; }
switch_body(L) ::= switch_clauses(R1) COMMA switch_default(R2).
  { NODE_APPEND(R1, R2, xcase); L = R1; }
switch_body(L) ::= switch_clauses(R1) COMMA switch_default(R2) COMMA.
  { NODE_APPEND(R1, R2, xcase); L = R1; }

switch_clauses(L) ::= switch_clauses(R1) COMMA switch_clause(R2).
  { NODE_APPEND(R1, R2, xcase); L = R1; }
switch_clauses(L) ::= switch_clause(R).
  { L = R; }

switch_clause(L) ::= exprs_comma(R1) COLON switch_clause_body(R2).
  { L = NODE_INIT(NodeCase);
    L->data.xcase.cases = NH(R1);
    L->data.xcase.body = NH(R2); }
switch_clause(L) ::= exprs_comma(R1) COMMA COLON switch_clause_body(R2).
  { L = NODE_INIT(NodeCase);
    L->data.xcase.cases = NH(R1);
    L->data.xcase.body = NH(R2); }

switch_default(L) ::= DEFAULT COLON switch_clause_body(R).  { L = R; }

switch_clause_body(L) ::= expr(R).  { L = R; }
switch_clause_body(L) ::= block(R). { L = R; }

// Because if+switch can be either expressions or statements, there are some
// compound constructs that create a reduce-reduce ambiguity (expr followed by
// DOT, LPAREN, LBRACK), we use an explicit precedence rule to resolve the
// reduce-reduce conflicts in favor of the statement. Wrapping a expr_ctrlflow
// in parens explicitly makes it an expr.
%nonassoc EXPR_CTRLF_EXPR.
%nonassoc EXPR_CTRLF_STMT.

%left ASYNC AWAIT CONST TRY.
%left AMP2.
%left PIPE2.
%left EQEQ NEQ.
%nonassoc LT LTE GT GTE.
%left DOT2.
%left PIPE CARAT AMP.
%left PLUS MINUS.
%left STAR SLASH PERCENT LTLT GTGT.
%left QUESTION BANG TILDE.
%left DOT DOTQ LPAREN RPAREN LBRACE RBRACE.
%left COLON LBRACK RBRACK.

%parse_failure {}
%syntax_error { state->has_err = true; }

%code {

NodeCtx node_ctx_init() {
  size_t cap = 16384;
  void* base = realloc(NULL, cap * sizeof(Node));
  return (NodeCtx){
    .base = base,
    .cap = cap,
    .len = 0,
  };
}

void node_ctx_deinit(NodeCtx ctx) {
  realloc(ctx.base, 0);
}

NodeHandle node_init(NodeCtx* ctx, NodeType type) {
  if (ctx->len == ctx->cap) {
    ctx->cap *= 2;
    if (ctx->cap >= 0xFFFFFFFF - 1) {
      printf("node overflow\n");
      exit(1);
    }
    ctx->base = realloc(ctx->base, ctx->cap * sizeof(Node));
  }

  Node* cur = &ctx->base[ctx->len++];
  memset(cur, 0, sizeof(Node));
  cur->type = type;
  return ctx->len;
}

Node* node_get(NodeCtx* ctx, NodeHandle handle) {
  if (handle == 0) return NULL;
  return &ctx->base[handle - 1];
}

NodeHandle node_get_handle(NodeCtx* ctx, Node* node) {
  if (node == NULL) return 0;
  return (node - ctx->base) + 1;
}

#define PRINT(fmt, ...) do { \
    printf("%*s", indent, ""); \
    printf(fmt, ##__VA_ARGS__); \
  } while (0)

#define PRINTI(in, fmt, ...) do { \
    printf("%*s", in + indent, ""); \
    printf(fmt, ##__VA_ARGS__); \
  } while (0)

void node_print2(NodeCtx* ctx, NodeHandle node, int indent);

#define PRINT_NODES(ctx, cur, field, indent) PRINT_NODES2(ctx, cur, field, indent, indent)
#define PRINT_NODES2(ctx, cur, field, indent, preindent) do { \
    while (cur != 0) { \
      printf("%*s", indent, ""); \
      node_print2(ctx, cur, indent); \
      printf(",\n"); \
      cur = node_get(ctx, cur)->data.field.list.next; \
    } \
  } while(0)

void node_print_typespec(NodeCtx* ctx, TypeSpec* spec, int indent) {
  if (spec == NULL) {
    printf("NULL");
    return;
  }
  switch (spec->type) {

    case Type2_num: {
      printf("type=%s", numtype_strs[spec->data.num]);
      break;
    }

    case Type2_bool: {
      printf("type=bool");
      break;
    }

    case Type2_void: {
      printf("type=void");
      break;
    }

    case Type2_type: {
      printf("type=type");
      break;
    }

    case Type2_optional: {
      printf("type=optional ");
      node_print2(ctx, spec->data.expr, indent);
      break;
    }

    case Type2_array: {
      printf("type=array,\n");
      PRINTI(2, "count=");
      node_print2(ctx, spec->data.array.count, indent + 2);
      printf(",\n");
      PRINTI(2, "type=");
      node_print2(ctx, spec->data.array.type, indent + 2);
      break;
    }

    case Type2_fndef: {
      printf("type=fn, quals=[");

      if (spec->data.fndef.quals & FnQual_EXTERN) printf(" extern");
      if (spec->data.fndef.quals & FnQual_CCALL) printf(" ccall");
      printf(" ], args=[\n");

      PRINT_NODES(ctx, spec->data.fndef.args, fnarg, indent + 4);
      PRINTI(2, "],\n");

      PRINTI(2, "ret_type=");
      node_print2(ctx, spec->data.fndef.ret_type, indent + 4);

      if (spec->data.fndef.body != 0) {
        printf(",\n");
        PRINTI(2, "body=");
        node_print2(ctx, spec->data.fndef.body, indent + 4);
      }

      break;
    }

    case Type2_enum: {
      printf("type=enum");

      printf(",\n");
      PRINTI(2, "backing_type=");
      node_print2(ctx, spec->data.xenum.backing_type, indent);

      printf(",\n");
      PRINTI(2, "elements=[\n");
      PRINT_NODES(ctx, spec->data.xenum.elements, enumfield, indent + 4);
      PRINTI(2, "]");

      break;
    }

    case Type2_struct: {
      printf("type=struct, body=");
      NodeHandle body = spec->data.xstruct;
      node_print2(ctx, body, indent);
      break;
    }

    case Type2_signature: {
      printf("type=signature, body=");
      NodeHandle body = spec->data.xstruct;
      node_print2(ctx, body, indent);
      break;
    }

    case Type2_union: {
      printf("type=union,\n");
      PRINTI(2, "tag_type=");
      node_print2(ctx, spec->data.xunion.tag_type, indent + 2);
      printf(",");
      NodeHandle body = spec->data.xunion.body;

      printf("\n");
      PRINTI(2, "body=");
      node_print2(ctx, body, indent + 2);
      break;
    }

    default: {
      printf("unrecognized typespec type %d\n", spec->type);
      exit(1);
    }
  }
}

void tok_print(Token* tok, int indent, char* label) {
  if (tok->type == TokenType__Sentinel) {
    PRINT("%s=NULL", label);
  } else {
    PRINT("%s=\"%.*s\"", label, (int)tok->len, tok->start);
  }
}

void node_print2(NodeCtx* ctx, NodeHandle node_handle, int indent) {
  if (node_handle == 0) { printf("NULL"); return; }

  Node* node = node_get(ctx, node_handle);
  const char* node_name = node_type_strs[node->type];

  printf("%s(", node_name);
  switch (node->type) {

    case NodeName: {
      tok_print(&node->data.name, 0, "name");
      printf(")");
      break;
    }

    case NodeStructBody: {
      printf("\n");

      PRINTI(2, "fields=[\n");
      PRINT_NODES(ctx, node->data.struct_body.fields, struct_field, indent + 4);
      PRINTI(2, "]");
      printf(",\n");

      PRINTI(2, "decls=[\n");
      PRINT_NODES(ctx, node->data.struct_body.decls, decl, indent + 4);
      PRINTI(2, "]");
      printf(",\n");
      PRINT(")");

      break;
    }

    case NodeStructField: {
      tok_print(&node->data.struct_field.name, 0, "name");
      printf(", type=");
      node_print2(ctx, node->data.struct_field.type, indent);
      printf(", default=");
      node_print2(ctx, node->data.struct_field.xdefault, indent);
      printf(")");
      break;
    }

    case NodeExpr: {
      node_print2(ctx, node->data.expr.expr, indent);
      printf(")");
      break;
    }

    case NodeDecl: {
      Token* name = &node->data.decl.name;
      tok_print(&node->data.decl.name, 0, "name");

      printf(", quals=[");
      if (node->data.decl.quals & DeclQual_PUB) printf(" pub");
      if (node->data.decl.quals & DeclQual_THREADLOCAL) printf(" tls");
      if (node->data.decl.var) printf(" var");
      printf(" ],\n");

      PRINTI(2, "type=");
      node_print2(ctx, node->data.decl.type, indent + 2);
      printf(",\n");

      PRINTI(2, "expr=");
      node_print2(ctx, node->data.decl.expr, indent + 2);

      printf(")");
      break;
    }

    case NodeTypeSpec: {
      TypeSpec* type = &node->data.type;
      node_print_typespec(ctx, type, indent);
      printf(")");
      break;
    }

    case NodeLiteral: {
      Literal* literal = &node->data.literal;

      printf("type=%s", literal_type_strs[literal->type]);
      printf(", value=");
      switch (literal->type) {
        case Literal_enum:
        case Literal_num:
        case Literal_str: {
          tok_print(&literal->data.tok, 0, "");
          break;
        }
        case Literal_true:
          printf("true");
          break;
        case Literal_false:
          printf("false");
          break;
        case Literal_null:
          printf("null");
          break;
        case Literal_undefined:
          printf("undefined");
          break;
        case Literal_struct:
          printf("[\n");
          PRINT_NODES(ctx, literal->data.struct_field, literal_struct_field, indent + 2);
          PRINT("]");
          break;
        case Literal_array:
          printf("[\n");
          PRINT_NODES(ctx, literal->data.array_entry, expr, indent + 2);
          PRINT("]");
          break;

        default:
          printf("unrecognized");
          exit(1);
      }
      printf(")");

      break;
    }

    case NodeInfix:
    case NodeInfixAssign: {
      printf("op=\"%s\",\n", infixop_strs[node->data.infix.op]);
      PRINTI(2, "lhs=");
      node_print2(ctx, node->data.infix.lhs, indent + 2);
      printf(",\n");
      PRINTI(2, "rhs=");
      node_print2(ctx, node->data.infix.rhs, indent + 2);
      printf(")");
      break;
    }

    case NodeExprPrefix: {
      printf("prefix=%s, ", exprprefix_strs[node->data.expr_prefix.prefix]);
      printf("base=");
      node_print2(ctx, node->data.expr_prefix.base, indent + 2);
      printf(")");
      break;
    }

    case NodeImport: {
      printf("import=");
      node_print2(ctx, node->data.expr.expr, indent + 2);
      printf(")");
      break;
    }

    case NodeFnCall: {
      printf("\n");
      PRINTI(2, "fn=");
      node_print2(ctx, node->data.fncall.fn, indent + 2);

      printf(",\n");
      PRINTI(2, "args=[\n");
      PRINT_NODES(ctx, node->data.fncall.args, expr, indent + 4);
      PRINTI(2, "]");

      printf(")");
      break;
    }

    case NodeFnArg: {
      tok_print(&node->data.fnarg.name, 0, "name");
      printf(", type=");
      node_print2(ctx, node->data.fnarg.type, indent);
      printf(")");
      break;
    }

    case NodeEnumField: {
      tok_print(&node->data.enumfield.name, 0, "name");

      printf(", value=");
      node_print2(ctx, node->data.enumfield.value, indent + 2);
      printf(")");
      break;
    }

    case NodeFieldAccess: {
      tok_print(&node->data.expr_field.field, 0, "field");

      printf(",\n");
      PRINTI(2, "base=");
      node_print2(ctx, node->data.expr_field.base, indent + 4);
      printf(")");
      break;
    }

    case NodeArrayAccess: {
      printf("\n");
      PRINTI(2, "idx=");
      node_print2(ctx, node->data.expr_array.idx, indent + 2);

      printf(",\n");
      PRINTI(2, "base=");
      node_print2(ctx, node->data.expr_array.base, indent + 2);
      printf(")");
      break;
    }

    case NodeIf: {
      Node* cur;
      cur = node;
      while (true) {
        printf("\n");
        PRINTI(2, "cond=");
        node_print2(ctx, cur->data.xif.cond, indent + 2);

        printf(",\n");
        PRINTI(2, "body=");
        node_print2(ctx, cur->data.xif.body, indent + 2);
        printf(",");

        NodeHandle nh = cur->data.xif.list.next;
        if (nh == 0) break;
        cur = node_get(ctx, nh);

        if (cur->type != NodeIf) {
          printf("\n");
          PRINTI(2, "else=");
          node_print2(ctx, nh, indent + 2);
          break;
        }
      }

      printf(")");
      break;
    }

    case NodeStmt: {
      node_print2(ctx, node->data.stmt.stmt, indent);
      break;
    }

    case NodeBlock: {
      tok_print(&node->data.block.label, 0, "label");
      printf(", stmts=[\n");
      PRINT_NODES(ctx, node->data.block.stmts, stmt, indent);
      PRINT("])");
      break;
    }

    case NodeAssign: {
      printf("\n");
      PRINTI(2, "lhs=");
      node_print2(ctx, node->data.assign.lhs, indent + 4);

      printf(",\n");
      PRINTI(2, "rhs=");
      node_print2(ctx, node->data.assign.rhs, indent + 4);
      printf(")");
      break;
    }

    case NodeStmtCtrl: {
      printf("keyword=%s", stmtctrl_strs[node->data.stmt_ctrl.keyword]);

      printf(", ");
      tok_print(&node->data.stmt_ctrl.label, 0, "label");

      printf(",\n");
      PRINTI(2, "body=");
      node_print2(ctx, node->data.stmt_ctrl.body, indent + 4);
      printf(")");

      break;
    }

    case NodeCapture: {
      tok_print(&node->data.capture.name, 0, "name");
      printf(")");
      break;
    }

    case NodeFor: {
      tok_print(&node->data.xfor.label, 0, "label");

      printf(",\n");
      PRINTI(2, "exprs=[\n");
      PRINT_NODES(ctx, node->data.xfor.expr, expr, indent + 4);
      PRINTI(2, "]");

      printf(",\n");
      PRINTI(2, "captures=[\n");
      PRINT_NODES(ctx, node->data.xfor.capture, capture, indent + 4);
      PRINTI(2, "]");

      printf(",\n");
      PRINTI(2, "body=");
      node_print2(ctx, node->data.xfor.body, indent + 2);

      printf(")");
      break;
    }

    case NodeWhile: {
      Node* label = node_get(ctx, node->data.xwhile.label);
      if (label) {
        tok_print(&label->data.name, 0, "label");
      } else {
        printf("label=NULL");
      }

      Node* capture = node_get(ctx, node->data.xwhile.capture);
      if (capture) {
        printf(", ");
        tok_print(&capture->data.name, 0, "capture");
      } else {
        printf(", capture=NULL");
      }

      printf(",\n");
      PRINTI(2, "cond=");
      node_print2(ctx, node->data.xwhile.cond, indent + 2);

      printf(",\n");
      PRINTI(2, "continue=");
      node_print2(ctx, node->data.xwhile.xcontinue, indent + 2);

      printf(",\n");
      PRINTI(2, "body=");
      node_print2(ctx, node->data.xwhile.body, indent + 2);
  
      printf(")");
      break;
    }

    case NodeSwitch: {
      printf("\n");
      PRINTI(2, "expr=");
      node_print2(ctx, node->data.xswitch.expr, indent + 2);

      printf(",\n");
      PRINTI(2, "body=[\n");
      PRINT_NODES(ctx, node->data.xswitch.body, xcase, indent + 4);
      PRINTI(2, "])");
      break;
    }

    case NodeCase: {
      printf("cases=[\n");
      PRINT_NODES(ctx, node->data.xcase.cases, expr, indent + 4);
      PRINTI(2, "],\n");

      PRINTI(2, "body=");
      node_print2(ctx, node->data.xcase.body, indent + 4);

      printf(")");
      break;
    }

    case NodeLiteralStructField: {
      tok_print(&node->data.literal_struct_field.name, 0, "field");
      printf(" = ");
      node_print2(ctx, node->data.literal_struct_field.expr, indent);
      printf(")");
      break;
    }

    case NodeOptional: {
      node_print2(ctx, node->data.expr.expr, indent);
      printf(")");
      break;
    }

    case NodeNoop: {
      break;
    }

    default: {
      printf("\nunrecognized node type %d!\n", node->type);
      exit(1);
    }
  }
}

void node_print(NodeCtx* ctx, NodeHandle node) {
  node_print2(ctx, node, 0);
  printf("\n");
}

char* numtype_strs[NumType__Sentinel] = {
  "I8",
  "I16",
  "I32",
  "I64",
  "I128",
  "U8",
  "U16",
  "U32",
  "U64",
  "U128",
  "F16",
  "F32",
  "F64",
  "F128",
};

char* type2_strs[Type2__Sentinel] = {
  "_Invalid",
  "type",
  "bool",
  "void",
  "fndef",
  "num",
  "array",
  "struct",
  "signature",
  "enum",
  "union",
  "optional",
};

char* literal_type_strs[Literal__Sentinel] = {
  "_Invalid",
  "num",
  "str",
  "true",
  "false",
  "null",
  "undefined",
  "enum",
  "struct",
  "array",
};

char* exprprefix_strs[ExprPrefix__Sentinel] = {
  "amp",
  "minus",
  "bang",
  "tilde",
  "star",
  "async",
  "await",
  "const",
  "try",
};

char* stmtctrl_strs[StmtCtrl__Sentinel] = {
  "continue",
  "break",
  "defer",
  "errdefer",
  "yield",
  "resume",
  "return",
};

char* infixop_strs[Infix__Sentinel] = {
  "_Invalid",
  "*",
  "/",
  "%",
  "<<",
  ">>",
  "+",
  "-",
  "|",
  "^",
  "&",
  "..",
  "&&",
  "||",
  "==",
  "!=",
  "<",
  "<=",
  ">",
  ">=",
};

char* node_type_strs[Node__Sentinel] = {
  "InvalidType",
  "StructBody",
  "StructField",
  "Decl",
  "Name",
  "TypeSpec",
  "Literal",
  "LiteralStructField",
  "Import",
  "Block",
  "StmtCtrl",
  "Assign",
  "If",
  "While",
  "For",
  "FnArg",
  "EnumField",
  "Switch",
  "FieldAccess",
  "FnCall",
  "ArrayAccess",
  "ExprPrefix",
  "Case",
  "Optional",
  "Noop",
  "Capture",
  "Stmt",
  "Expr",
  "ExprInfix",
  "ExprInfixAssign",
};

}

// TODO:
// * Builtins: cast, sizeof, alignof, etc
// * orelse
// * Error returns, catch
// * string interpolation
// * bitfields
// * Default fn args?
// * slice
// * extern fn with let doesn't make much sense?
// * remove parens on if/for/while/switch
// * linear types, disable/release
// * fn pattern matching
// * "hard" type aliases
// * context management/keywords
// * make yield an expression so that resume can return things to it?
