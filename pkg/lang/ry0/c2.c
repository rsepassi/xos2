#include "c2.h"

#include "base/str.h"

// print helpers
//
// print str
#define p(s) genctx->write(genctx->ctx, (s).bytes, (s).len)
// print c string
#define pc(s) p(cstr(s))
// print C2_Name*
#define pn(n) p(str_init(&ctx->names[(n)->val.str.offset], (n)->val.str.len))

static const char* type_strs[C2_TypeVoidPtr + 1] = {
  "uint8_t",
  "uint16_t",
  "uint32_t",
  "uint64_t",
  "int8_t",
  "int16_t",
  "int32_t",
  "int64_t",
  "float",
  "double",
  "void*",
};

static const char* stmt_strs[C2_Stmt__Sentinel] = {
  "INVALID",
  "CAST",
  "DECL",
  "LABEL",
  "EXPR",
  "ASSIGN",
  "RETURN",
  "BREAK",
  "CONTINUE",
  "GOTO",
  "IF",
  "SWITCH",
  "LOOP",
  "IFBLOCK",
  "SWITCHCASE",
};

static bool nameIsNull(C2_Name* name) {
  uint8_t* cur = (uint8_t*)(name);
  for (int i = 0; i < sizeof(C2_Name); ++i) {
    if (cur[i] != 0) return false;
  }
  return true;
}

static void printTypeName(C2_Ctx* ctx, C2_TypeId t, C2_GenCtxC* genctx) {
  if (t < C2_TypeNamedOffset) {
    pc(type_strs[t]);
  } else {
    t -= C2_TypeNamedOffset;
    C2_Type* type = list_get_from_handle(C2_Type, &ctx->types, t);
    C2_Name* name;
    switch (type->type) {
      case C2_TypePtr: {
        name = &type->data.named.name;
        break;
      }
      case C2_TypeArray: {
        name = &type->data.arr.named.name;
        break;
      }
      case C2_TypeStruct: {
        name = &type->data.xstruct.name;
        break;
      }
      case C2_TypeFnPtr: {
        name = &type->data.fnptr.name;
        break;
      }
      default: {}
    }
    pn(name);
  }
}

static void printFnSig(C2_Ctx* ctx, C2_FnSig* fn, C2_GenCtxC* genctx, bool with_names, bool ptr_form) {
  printTypeName(ctx, fn->ret, genctx);
  pc(" ");
  if (ptr_form) {
    pc("(*");
    pn(&fn->name);
    pc(")");
  } else {
    pn(&fn->name);
  }

  pc("(");
  size_t nargs = fn->args.len;
  for (size_t j = 0; j < nargs; ++j) {
    if (j > 0) pc(", ");
    C2_Type* t = list_get(C2_Type, &fn->args, j);
    printTypeName(ctx, t->data.named.type, genctx);
    if (with_names) {
      pc(" ");
      pn(&t->data.named.name);
    }
  }
  pc(")");
}

static void printData(C2_Ctx* ctx, C2_Data* data, C2_GenCtxC* genctx) {
  if (!data->export) {
    pc("static ");
  }
  printTypeName(ctx, C2_TypeU8, genctx);
  pc(" ");
  pn(&data->name);
  char buf[128];
  int len = snprintf(buf, 128, "%d", data->len);
  pc("[");
  p(str_init(buf, len));
  pc("]");
  if (data->data) {
    pc(" = {");
    char buf[128];
    for (size_t i = 0; i < data->len; ++i) {
      if (i % 8 == 0) pc("\n");
      int len = snprintf(buf, 128, "0x%02x", data->data[i]);
      p(str_init(buf, len));
      pc(", ");
    }
    pc("\n}");
  }
  pc(";\n");
}

Status c2_gen_c(C2_Ctx* ctx, C2_Module* module, C2_GenCtxC* genctx) {
  pc("#include <stdint.h>\n");

  {
    // Named types
    pc("\n// named types\n");
    size_t ntypes = ctx->types.len;
    for (size_t i = 0; i < ntypes; ++i) {
      C2_Type* type = list_get(C2_Type, &ctx->types, i);
      switch (type->type) {
        case C2_TypePtr: {
          pc("typedef ");
          printTypeName(ctx, type->data.named.type, genctx);
          pc("* ");
          pn(&(type->data.named.name));
          pc(";\n");
          break;
        }
        case C2_TypeFnPtr: {
          pc("typedef ");
          printFnSig(ctx, &type->data.fnptr, genctx, false, true);
          pc(";\n");
          break;
        }
        case C2_TypeArray: {
          pc("typedef ");
          printTypeName(ctx, type->data.arr.named.type, genctx);
          pc(" ");
          pn(&(type->data.arr.named.name));
          char buf[128];
          int len = snprintf(buf, 128, "%d", type->data.arr.len);
          pc("[");
          p(str_init(buf, len));
          pc("];\n");
          break;
        }
        case C2_TypeStruct: {
          pc("typedef struct ");
          pn(&(type->data.xstruct.name));
          pc("_s ");
          pn(&(type->data.xstruct.name));
          pc(";\n");
          pc("struct ");
          pn(&(type->data.xstruct.name));
          pc("_s {\n");
          size_t nfields = type->data.xstruct.fields.len;
          for (size_t i = 0; i < nfields; ++i) {
            pc("  ");
            C2_Type* f = list_get(C2_Type, &type->data.xstruct.fields, i);
            printTypeName(ctx, f->data.named.type, genctx);
            pc(" ");
            pn(&f->data.named.name);
            pc(";\n");
          }
          pc("};\n");
          break;
        }
        default: {}
      }
    }
  }

  {
    // Extern data
    pc("\n// extern data\n");
    size_t ndata = module->extern_data.len;
    for (size_t i = 0; i < ndata; ++i) {
      pc("extern uint8_t* ");
      C2_Name* name = list_get(C2_Name, &module->extern_data, i);
      pn(name);
      pc(";\n");
    }
  }

  {
    // Extern fns
    pc("\n// extern fns\n");
    size_t nfns = module->extern_fns.len;
    for (size_t i = 0; i < nfns; ++i) {
      C2_FnSig* fn = list_get(C2_FnSig, &module->extern_fns, i);
      pc("extern ");
      printFnSig(ctx, fn, genctx, false, false);
      pc(";\n");
    }
  }

  {
    // BSS
    pc("\n// bss\n");
    size_t nbss = module->bss.len;
    for (size_t i = 0; i < nbss; ++i) {
      C2_Data* bss = list_get(C2_Data, &module->bss, i);
      printData(ctx, bss, genctx);
    }
  }

  {
    // Data
    pc("\n// data\n");
    size_t ndata = module->data.len;
    for (size_t i = 0; i < ndata; ++i) {
      C2_Data* data = list_get(C2_Data, &module->data, i);
      printData(ctx, data, genctx);
    }
  }

  {
    // Functions
    pc("\n// functions\n");
    size_t nfns = module->fns.len;
    for (size_t i = 0; i < nfns; ++i) {
      C2_Fn* fn = list_get(C2_Fn, &module->fns, i);
      printFnSig(ctx, &fn->sig, genctx, true, false);
      pc(" {\n");
      size_t nstmt = fn->stmts.len;
      for (size_t j = 0; j < nstmt; ++j) {
        C2_StmtId* stmtid = list_get(C2_StmtId, &fn->stmts, j);
        C2_Stmt* stmt = list_get_from_handle(C2_Stmt, &ctx->stmts, *stmtid);
        pc("  ");
        switch (stmt->type) {
          case C2_Stmt_RETURN: {
            C2_Name* name = &stmt->data.xreturn.name;
            if (nameIsNull(name)) {
              pc("  return");
            } else {
              pc("  return ");
              pn(&stmt->data.xreturn.name);
            }
            break;
          }
          // case C2_Stmt_CAST:
          // case C2_Stmt_DECL:
          // case C2_Stmt_EXPR:
          // case C2_Stmt_ASSIGN:
          //
          // case C2_Stmt_LABEL:
          // case C2_Stmt_GOTO:
          // case C2_Stmt_IF:
          // case C2_Stmt_LOOP:
          // case C2_Stmt_BREAK:
          // case C2_Stmt_CONTINUE:
          // case C2_Stmt_IFBLOCK:
          // case C2_Stmt_SWITCH:
          // case C2_Stmt_SWITCHCASE:
          default: {
            pc(stmt_strs[stmt->type]);
          }
        }
        pc(";\n");
      }
      pc("}\n\n");
    }
  }

  return OK;
}

// TODO:
// Namer
//   get, create, getorcreate
//   tmp name
// line number directives
// literals
