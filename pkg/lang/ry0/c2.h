#ifndef C2_H_
#define C2_H_

#include <stdbool.h>

#include "base/list.h"
#include "base/status.h"

typedef const char* C2_NameBuf;
typedef list_handle_t C2_TypeId;
typedef list_handle_t C2_StmtId;

typedef enum {
  C2_ExprType_ADD,
  C2_ExprType_SUB,
} C2_ExprType;

typedef enum {
  C2_Stmt_INVALID,
  C2_Stmt_CAST,
  C2_Stmt_DECL,
  C2_Stmt_LABEL,
  C2_Stmt_EXPR,
  C2_Stmt_ASSIGN,
  C2_Stmt_RETURN,
  C2_Stmt_BREAK,
  C2_Stmt_CONTINUE,
  C2_Stmt_GOTO,
  C2_Stmt_IF,
  C2_Stmt_SWITCH,
  C2_Stmt_LOOP,
  C2_Stmt_IFBLOCK,
  C2_Stmt_SWITCHCASE,
  C2_Stmt__Sentinel,
} C2_StmtType;

typedef enum {
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
  C2_TypeVoidPtr,
  C2_TypeBytes,
  C2_TypeNamedOffset,
  C2_TypePtr,
  C2_TypeFnPtr,
  C2_TypeArray,
  C2_TypeStruct,
  C2_TypeStructField,
  C2_TypeFnArg,
} C2_TypeType;

typedef struct {
  union {
    struct {
      uint16_t offset;
      uint16_t len;
    } str;
    uint16_t tmp;
  } val;
  bool tag;
} C2_Name;
#define C2_Name_NULL ((C2_Name){0})

#define C2_FnQual_INLINE 1 << 0
#define C2_FnQual_EXPORT 1 << 1
typedef uint8_t C2_FnQual;

typedef struct {
  C2_Name name;
  C2_TypeId ret;
  C2_FnQual quals;
  list_t args;  // C2_TypeId (C2_TypeFnArg)
} C2_FnSig;

typedef struct {
  C2_Name name;
  C2_TypeId type;
} C2_NamedType;

typedef struct {
  C2_TypeType type;
  union {
    C2_NamedType named;
    C2_FnSig fnptr;
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
  C2_TypeId sig;  // C2_TypeFnPtr
  list_t stmts;  // C2_StmtId
} C2_Fn;

typedef struct {
  C2_Name name;
  const uint8_t* data;
  uint64_t len;
  bool export;
} C2_Data;

typedef C2_Name C2_ExternData;

typedef struct {
  C2_StmtType type;
  union {
    struct {
      C2_Name in_name;
      C2_Name out_name;
      C2_TypeId type;
    } cast;
    struct {
      C2_Name name;
      C2_TypeId type;
    } decl;
    struct {
      C2_Name name;
    } label;
    struct {
      C2_ExprType type;
      C2_Name op0;
      C2_Name op1;
    } expr;
    struct {
      C2_Name lhs;
      C2_Name rhs;
    } assign;
    struct {
      C2_Name name;
    } xreturn;
    struct {
      C2_Name label;
    } xgoto;
    struct {
      list_t ifs;  // C2_StmtId (C2_Stmt_IFBLOCK)
      list_t xelse;  // C2_StmtId
    } xif;
    struct {
      list_t cond_stmts;  // C2_StmtId
      list_t body_stmts;  // C2_StmtId
      C2_Name cond;
    } ifblock;
    struct {
      C2_Name expr;
      list_t cases;  // C2_StmtId (C2_Stmt_SWITCHCASE)
      list_t xdefault;  // C2_StmtId
    } xswitch;
    struct {
      C2_Name val;
      list_t stmts;  // C2_StmtId
    } switchcase;
    struct {
      // while (true) {
      //   <cond_stmts>
      //   if (!<cond_val>) break;
      //   <body_stmts>
      //   if (!<continue_val>) break;
      //   <continue_stmts>
      // }
      list_t cond_stmts;  // C2_StmtId
      C2_Name cond_val;
      list_t body_stmts;  // C2_StmtId
      C2_Name continue_val;
      list_t continue_stmts;  // C2_StmtId
    } loop;
  } data;
} C2_Stmt;

typedef struct {
  list_t extern_fns;  // C2_TypeId (C2_TypeFnPtr)
  list_t extern_data;  // C2_ExternData
  list_t data;  // C2_Data
  list_t bss;  // C2_Data
  list_t fns;  // C2_Fn
} C2_Module;

typedef struct {
  C2_NameBuf names;
  list_t types;  // C2_Type
  list_t stmts;  // C2_Stmt
} C2_Ctx;

typedef struct {
  void (*write)(void* ctx, const char* s, int64_t len);
  void* ctx;
} C2_GenCtxC;

Status c2_gen_c(C2_Ctx* ctx, C2_Module* module, C2_GenCtxC* genctx);

#endif
