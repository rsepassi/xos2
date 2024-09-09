#ifndef C2_H_
#define C2_H_

#include <stdbool.h>

#include "base/list.h"
#include "base/str.h"

typedef enum {
  C2_Op_INVALID,
  C2_Op_NONE,
  // Unary
  C2_Op_NEGATE,
  C2_Op_NOT,
  C2_Op_BITNOT,
  C2_Op_ADDR,
  // Binary
  C2_Op_ADD,
  C2_Op_SUB,
  C2_Op_MUL,
  C2_Op_DIV,
  C2_Op_MOD,
  C2_Op_EQ,
  C2_Op_NEQ,
  C2_Op_LT,
  C2_Op_GT,
  C2_Op_LTE,
  C2_Op_GTE,
  C2_Op_AND,
  C2_Op_OR,
  C2_Op_BITAND,
  C2_Op_BITOR,
  C2_Op_BITXOR,
  C2_Op_BITLS,
  C2_Op_BITRS,
  C2_Op__Sentinel,
} C2_OpType;

typedef enum {
  C2_Stmt_INVALID,
  C2_Stmt_CAST,
  C2_Stmt_DECL,
  C2_Stmt_EXPR,
  C2_Stmt_TERM,
  C2_Stmt_FNCALL,
  C2_Stmt_ASSIGN,
  C2_Stmt_RETURN,
  C2_Stmt_BREAK,
  C2_Stmt_CONTINUE,
  C2_Stmt_IF,
  C2_Stmt_SWITCH,
  C2_Stmt_LOOP,
  C2_Stmt_IFBLOCK,
  C2_Stmt_SWITCHCASE,
  C2_Stmt_BLOCK,
  C2_Stmt__Sentinel,
} C2_StmtType;

typedef enum {
  C2_TypeINVALID,
  C2_TypeVOID,
  C2_TypeU8,
  C2_TypeU16,
  C2_TypeU32,
  C2_TypeU64,
  C2_TypeI8,
  C2_TypeI16,
  C2_TypeI32,
  C2_TypeI64,
  C2_TypeF32,
  C2_TypeF64,
  C2_TypeBytes,  // uint8_t*
  C2_TypeNamedOffset,
  C2_TypePtr,
  C2_TypeArray,
  C2_TypeStruct,
  C2_TypeStructField,
  C2_TypeFnPtr,
  C2_TypeFnSig,
  C2_TypeFnArg,
} C2_TypeType;

typedef enum {
  C2_Term_NAME,
  C2_Term_DEREF,
  C2_Term_ARRAY,
  C2_Term_FIELD,
  C2_Term_LIT_U64,
  C2_Term_LIT_I64,
  C2_Term_LIT_F32,
  C2_Term_LIT_F64,
  C2_Term_LIT_STR,
} C2_TermType;

#define C2_FnQual_INLINE 1 << 0
#define C2_FnQual_EXPORT 1 << 1
typedef uint8_t C2_FnQual;

// Identifiers to key datatypes
// * Name
// * Stmt
// * Type
typedef struct {
  uint16_t offset;
  uint16_t len;
} C2_Name;
#define C2_Name_NULL ((C2_Name){0})
inline bool c2_names_eq(C2_Name, C2_Name);

typedef struct {
  C2_TypeType type;
  list_handle_t handle;
} C2_TypeId;
#define C2_TypeId_NULL ((C2_TypeId){0})

typedef list_handle_t C2_StmtId;
#define C2_StmtId_NULL 0

typedef struct {
  C2_Name name;
  C2_FnQual quals;
  list_t args;  // C2_TypeId (C2_TypeFnArg)
  C2_TypeId ret;
} C2_FnSig;

typedef struct {
  C2_TypeId sig;  // C2_TypeFnSig
  C2_StmtId stmts;  // C2_Stmt_BLOCK
} C2_Fn;

typedef struct {
  C2_Name name;
  C2_TypeId type;
} C2_NamedType;

typedef struct {
  C2_TypeType type;
  union {
    C2_NamedType named;
    C2_FnSig fnsig;
    struct {
      C2_NamedType named;
      uint32_t len;
    } arr;
    struct {
      C2_Name name;
      list_t fields;  // C2_TypeId (C2_TypeStructField)
    } xstruct;
  } data;
} C2_Type;

typedef struct {
  C2_Name name;
  const uint8_t* data;
  uint64_t len;
  bool export;
} C2_Data;

typedef struct {
  C2_StmtType type;
  union {
    struct {
      C2_TypeId type;
      C2_Name in_name;
      C2_Name out_name;
    } cast;
    struct {
      C2_Name name;
      C2_TypeId type;
    } decl;
    struct {
      C2_StmtId lhs;  // C2_Stmt_Expr
      C2_StmtId rhs;  // C2_Stmt_Expr
    } assign;
    struct {
      C2_Name name;
    } xreturn;
    struct {
      C2_StmtId ifs;  // C2_Stmt_BLOCK (C2_Stmt_IFBLOCK)
      C2_StmtId xelse;  // C2_Stmt_BLOCK
    } xif;
    struct {
      C2_StmtId cond_stmts;  // C2_Stmt_BLOCK
      C2_Name cond;
      C2_StmtId body_stmts;  // C2_Stmt_BLOCK
    } ifblock;
    struct {
      C2_Name expr;
      C2_StmtId cases;  // C2_Stmt_BLOCK (C2_Stmt_SWITCHCASE)
      C2_StmtId xdefault;  // C2_Stmt_BLOCK
    } xswitch;
    struct {
      C2_Name val;
      C2_StmtId stmts;  // C2_Stmt_BLOCK
    } switchcase;
    struct {
      // while (true) {
      //   <cond_stmts>
      //   if (!<cond_val>) break;
      //   <body_stmts>
      //   if (!<continue_val>) break;
      //   <continue_stmts>
      // }
      C2_StmtId cond_stmts;  // C2_Stmt_BLOCK
      C2_Name cond_val;
      C2_StmtId body_stmts;  // C2_Stmt_BLOCK
      C2_Name continue_val;
      C2_StmtId continue_stmts;  // C2_Stmt_BLOCK
    } loop;
    struct {
      C2_StmtId term0;  // C2_Stmt_BLOCK (C2_Stmt_TERM)
      C2_StmtId term1;  // C2_Stmt_BLOCK (C2_Stmt_TERM)
      C2_OpType type;
    } expr;
    struct {
      C2_TermType type;
      union {
        C2_Name name;
        uint64_t val_u64;
        int64_t val_i64;
        float val_f32;
        double val_f64;
      } data;
    } term;
    struct {
      C2_Name name;
      C2_Name ret;
      list_t args;  // C2_Name
    } fncall;
    list_t block;  // C2_StmtId
  } data;
} C2_Stmt;

typedef struct {
  list_t buf;
  void* ctx;
  size_t tmp;
} C2_Names;

typedef struct {
  C2_Names names;
  list_t types;  // C2_Type
  list_t stmts;  // C2_Stmt
} C2_Ctx;
C2_Ctx c2_ctx_init();
void c2_ctx_deinit(C2_Ctx*);

typedef struct {
  C2_Ctx* ctx;
  list_t extern_fns;  // C2_TypeId (C2_TypeFnSig)
  list_t extern_data;  // C2_Name
  list_t data;  // C2_Data
  list_t bss;  // C2_Data
  list_t fns;  // C2_Fn
} C2_Module;
C2_Module c2_module_init(C2_Ctx*);
void c2_module_deinit(C2_Module*);

// C codegen
typedef struct {
  void (*write)(void* user_ctx, str_t s);
  void* user_ctx;
} C2_GenCtxC;
void c2_gen_c(C2_Ctx* ctx, C2_Module* module, C2_GenCtxC* genctx);

// C2_Ctx builder API
// ----------------------------------------------------------------------------

// Names
C2_Name c2_ctx_namec(C2_Ctx*, const char* name);
C2_Name c2_ctx_name_suffix(C2_Ctx*, C2_Name, const char* suffix);
C2_Name c2_ctx_tmpname(C2_Ctx*);
inline str_t c2_ctx_strname(C2_Ctx* ctx, C2_Name name);

// Types
C2_Type* c2_ctx_addtypec(C2_Ctx*, C2_TypeType, const char* name);
#define C2_TypeIdBase(t) (C2_TypeId){.type = (t), .handle = 0}
inline C2_TypeId C2_TypeIdNamed(C2_Ctx*, C2_Type*);
inline C2_Type* c2_ctx_gettype(C2_Ctx*, C2_TypeId);
// Helpers
void c2_ctx_addstructfield(C2_Ctx*,
    C2_TypeId struct_type, const char* field_name, C2_TypeId field_type);
void c2_ctx_addfnarg(C2_Ctx*,
    C2_Type* fn_type, const char* arg_name, C2_TypeId arg_type);

// Stmts
C2_Fn* c2_module_addfn(C2_Module*, C2_TypeId sig);
C2_Stmt* c2_ctx_addstmt(C2_Ctx*, C2_Fn* fn, C2_StmtType);
inline C2_StmtId c2_ctx_stmtid(C2_Ctx*, C2_Stmt*);
inline C2_Stmt* c2_ctx_getstmt(C2_Ctx*, C2_StmtId);
// Helpers
void c2_ctx_addassign(C2_Ctx*, C2_Fn* fn, C2_StmtId lhs, C2_StmtId rhs);
C2_Stmt* c2_ctx_addterm(C2_Ctx*, C2_StmtId block, C2_TermType);
C2_StmtId c2_ctx_addexpr(C2_Ctx*, C2_OpType, C2_StmtId lhs, C2_StmtId rhs);
C2_StmtId c2_ctx_addblock(C2_Ctx*);
C2_Stmt* c2_ctx_blockadd(C2_Ctx*, C2_StmtId block, C2_StmtType);
void c2_ctx_addifblock(C2_Ctx*, C2_StmtId ifs, C2_StmtId cond_block, C2_Name cond, C2_StmtId body_block);
void c2_ctx_addswitchcase(C2_Ctx*, C2_StmtId cases, C2_Name case_val, C2_StmtId case_block);

// TODO
// * Add named block construct (vs goto+label)
// * WebAssembly backend
// * WebAssembly frontend?
#endif
