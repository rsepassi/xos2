%include { #include "wren.h" }

%token_type Token
%token_prefix TOKEN_
%extra_context { State* state }

%parse_accept {}

// Top-level
// ----------------------------------------------------------------------------

// A Wren source file is made up of a series of newline-separated statements
source ::= nli root_stmts EOF.
root_stmts ::= .
root_stmts ::= root_stmt nli.
root_stmts ::= root_stmts nl root_stmt.

// A root statements is either an import, a class definition, or a block of
// statements.
root_stmt ::= defimport.
root_stmt ::= defclass.
root_stmt ::= block.

block ::= nli stmts nli.
stmts ::= .
stmts ::= stmt nl.
stmts ::= stmts nl stmt.
// ----------------------------------------------------------------------------


// Statements
// ----------------------------------------------------------------------------
stmt ::= BREAK.
stmt ::= CONTINUE.
stmt ::= IF if.
stmt ::= WHILE cond stmt.
stmt ::= FOR LPAREN nli NAME nli IN nli expr RPAREN stmt.
stmt ::= RETURN return.
stmt ::= LBRACK block RBRACK.
stmt ::= defvar.
stmt ::= expr.

if ::= cond stmt.
if ::= cond stmt ELSE stmt.

return ::= expr nl.
return ::= nl.

cond ::= LPAREN nli expr nli RPAREN.
// ----------------------------------------------------------------------------


// Variable
// ----------------------------------------------------------------------------
defvar ::= VAR NAME EQ expr.
defvar ::= VAR NAME.
// ----------------------------------------------------------------------------


// Import
// ----------------------------------------------------------------------------
defimport ::= IMPORT import.

import ::= nli STRING.
import ::= nli STRING FOR import_names.
import_names ::= nli import_name.
import_names ::= import_name COMMA nli import_names.
import_name ::= NAME.
import_name ::= NAME AS NAME.
// ----------------------------------------------------------------------------


// Class
// ----------------------------------------------------------------------------
defclass ::= FOREIGN CLASS class.
defclass ::= CLASS class.

class ::= NAME class_super LBRACK methods RBRACK.
class_super ::= IS expr.
class_super ::= .
methods ::= .
methods ::= nl method.
methods ::= methods nl method nl.

method ::= FOREIGN method_sig.
method ::= FOREIGN STATIC method_sig.
method ::= method_sig LBRACK block RBRACK.
method ::= STATIC method_sig LBRACK block RBRACK.
method ::= CONSTRUCT method_sig_std LBRACK block RBRACK.

method_sig ::= method_sig_std.
method_sig ::= method_sig_getter.
method_sig ::= method_sig_setter.
method_sig ::= prefixop.
method_sig ::= method_sig_infixop.
method_sig ::= method_sig_subscript_getter.
method_sig ::= method_sig_subscript_setter.

method_sig_std ::= NAME LPAREN method_sig_args RPAREN.
method_sig_getter ::= NAME.
method_sig_setter ::= NAME EQ LPAREN NAME RPAREN.
method_sig_infixop ::= infixop LPAREN NAME RPAREN.
method_sig_subscript_getter ::= LBRACE method_sig_args RBRACE.
method_sig_subscript_setter ::= LBRACE method_sig_args RBRACE EQ LPAREN NAME RPAREN.

method_sig_args ::= .
method_sig_args ::= nli NAME.
method_sig_args ::= NAME COMMA nli names.

names ::= nli NAME.
names ::= NAME COMMA nli names.
// ----------------------------------------------------------------------------


// Expression
// ----------------------------------------------------------------------------
expr ::= NAME.
expr ::= FIELD.
expr ::= FALSE.
expr ::= TRUE.
expr ::= NULL.
expr ::= THIS.
expr ::= NUMBER.
expr ::= STATIC_FIELD.
expr ::= STRING.
expr ::= LPAREN nli expr nli RPAREN.
expr ::= LBRACE arr_entries RBRACE.
expr ::= LBRACK map_entries RBRACK.
expr ::= prefixop expr.

expr ::= expr nli DOT nli NAME.
expr ::= expr LBRACE nli expr nli RBRACE.
expr ::= expr nli infixop nli expr.
expr ::= expr EQ nli expr.
expr ::= expr nli QUESTION nli expr nli COLON nli expr.
expr ::= expr nli DOT nli NAME method_call.

method_call ::= LPAREN exprs RPAREN.
method_call ::= method_call_fn.
method_call ::= LPAREN exprs RPAREN method_call_fn.

method_call_fn ::= LBRACK block RBRACK.
method_call_fn ::= LBRACK PIPE method_sig_args PIPE block RBRACK.

map_entries ::= .
map_entries ::= nli map_entry.
map_entries ::= nli map_entry COMMA nli.
map_entries ::= nli map_entry COMMA nli map_entries_n.
map_entries_n ::= nli map_entry.
map_entries_n ::= nli map_entry COMMA nli map_entries_n.
map_entry ::= expr nli COLON nli expr.

arr_entries ::= .
arr_entries ::= nli expr.
arr_entries ::= nli expr COMMA nli.
arr_entries ::= nli expr COMMA nli arr_entries_n.
arr_entries_n ::= nli expr.
arr_entries_n ::= nli expr COMMA nli arr_entries_n.

string ::= STRING.
string ::= INTERPOLATION expr string.

exprs ::= .
exprs ::= nli expr.
exprs ::= nli expr COMMA nli exprs.
// ----------------------------------------------------------------------------


// Newline
// ----------------------------------------------------------------------------
nl ::= nl LINE.
nl ::= LINE.

nli ::= nl.
nli ::= .
// ----------------------------------------------------------------------------


// Op
// ----------------------------------------------------------------------------
prefixop ::= BANG.
prefixop ::= TILDE.
prefixop ::= MINUS.

infixop ::= DOTDOT.
infixop ::= DOTDOTDOT.
infixop ::= STAR.
infixop ::= SLASH.
infixop ::= PERCENT.
infixop ::= PLUS.
infixop ::= LTLT.
infixop ::= GTGT.
infixop ::= PIPE.
infixop ::= CARET.
infixop ::= AMP.
infixop ::= LT.
infixop ::= GT.
infixop ::= LTEQ.
infixop ::= GTEQ.
infixop ::= EQEQ.
infixop ::= BANGEQ.
infixop ::= IS.
// ----------------------------------------------------------------------------

// Error
// ----------------------------------------------------------------------------

// We use the statement level for error recovery
root_stmt ::= error.
stmt ::= error.

%parse_failure {}
%syntax_error { state->has_err = true; }
// ----------------------------------------------------------------------------
