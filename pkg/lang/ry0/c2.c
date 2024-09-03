#include "c2.h"

#include "base/str.h"
#include "khash.h"

// Symbol table C2_Name -> C2_TypeId
KHASH_MAP_INIT_INT64(mSymtab, uint64_t);
#define symtab_t khash_t(mSymtab)
static symtab_t* symtab_init() { return kh_init(mSymtab); }
static void symtab_deinit(symtab_t* s) { kh_destroy(mSymtab, s); }
static void symtab_reset(symtab_t* s) { kh_clear(mSymtab, s); }
static void symtab_put(symtab_t* s, C2_Name* name, C2_TypeId type) {
  int64_t k = 0;
  memcpy(&k, name, sizeof(C2_Name));
  uint64_t v = 0;
  memcpy(&v, &type, sizeof(C2_TypeId));

  int ret;
  khiter_t key = kh_put(mSymtab, s, k, &ret);
  kh_val(s, key) = v;
}
static C2_TypeId symtab_get(symtab_t* s, C2_Name* name) {
  int64_t k = 0;
  memcpy(&k, name, sizeof(C2_Name));
  uint64_t v = kh_val(s, kh_get(mSymtab, s, k));
  C2_TypeId out = 0;
  memcpy(&out, &v, sizeof(C2_TypeId));
  return out;
}

// genStmts helper
#define gens(stmts, i) genStmts(ctx, genctx, symtab, symtab_local, stmts, i);

// Helper to get named type
#define gettype(tid) \
  list_get_from_handle(C2_Type, &ctx->types, ((tid) - C2_TypeNamedOffset))

// print helpers
//
// print str
#define p(s) genctx->write(genctx->ctx, (s).bytes, (s).len)
// print c string
#define pc(s) p(cstr(s))
// print C2_Name*
#define pn(n) p(str_init(&ctx->names[(n)->offset], (n)->len))
// print C2_TypeId
#define pt(t) printTypeName(ctx, (t), genctx)
// print indent
#define pi(n) printIndent(genctx, n + indent)

static void printIndent(C2_GenCtxC* genctx, size_t n) {
  static char spaces[32] = "                                ";
  int left = n;
  while (left > 0) {
    int send = left < 32 ? left : 32;
    str_t s = {.bytes = spaces, .len = send};
    p(s);
    left -= send;
  }
}

static const char* type_strs[C2_TypeNamedOffset] = {
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
  "uint8_t*",
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
    C2_Type* type = gettype(t);
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
      case C2_TypeFnSig:
      case C2_TypeFnPtr: {
        name = &type->data.fnsig.name;
        break;
      }
      default: {}
    }
    pn(name);
  }
}

static void printFnSig(C2_Ctx* ctx, C2_FnSig* fn, C2_GenCtxC* genctx, bool with_names, bool ptr_form) {
  pt(fn->ret);
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
    C2_Type* t = gettype(*list_get(C2_TypeId, &fn->args, j));
    pt(t->data.named.type);
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
  pt(C2_TypeU8);
  pc(" ");
  pn(&data->name);
  char buf[128];
  int len = snprintf(buf, 128, "%lu", data->len);
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

static void genStmts(
    C2_Ctx* ctx,
    C2_GenCtxC* genctx,
    symtab_t* symtab,
    symtab_t* symtab_local,
    list_t* stmts,
    int indent) {
  size_t nstmt = stmts->len;
  for (size_t j = 0; j < nstmt; ++j) {
    C2_StmtId* stmtid = list_get(C2_StmtId, stmts, j);
    C2_Stmt* stmt = list_get_from_handle(C2_Stmt, &ctx->stmts, *stmtid);
    pi(0);
    switch (stmt->type) {
      case C2_Stmt_DECL: {
        symtab_put(symtab_local, &stmt->data.decl.name, stmt->data.decl.type);
        pt(stmt->data.decl.type);
        pc(" ");
        pn(&stmt->data.decl.name);
        break;
      }
      case C2_Stmt_RETURN: {
        C2_Name* name = &stmt->data.xreturn.name;
        if (nameIsNull(name)) {
          pc("return");
        } else {
          pc("return ");
          pn(&stmt->data.xreturn.name);
        }
        break;
      }
      case C2_Stmt_CAST: {
        pn(&stmt->data.cast.out_name);
        pc(" = (");
        pt(stmt->data.cast.type);
        pc(")");
        pn(&stmt->data.cast.in_name);
        symtab_put(symtab_local, &stmt->data.cast.out_name, stmt->data.cast.type);
        break;
      }
      case C2_Stmt_LABEL: {
        pn(&stmt->data.label.name);
        pc(":\n");
        break;
      }
      case C2_Stmt_GOTO: {
        pc("goto ");
        pn(&stmt->data.xgoto.label);
        break;
      }
      case C2_Stmt_CONTINUE: {
        pc("continue");
        break;
      }
      case C2_Stmt_BREAK: {
        pc("break");
        break;
      }
      case C2_Stmt_LOOP: {
        pc("while (1) {\n");
        if (!nameIsNull(&stmt->data.loop.cond_val)) {
          gens(&stmt->data.loop.cond_stmts, indent + 2);
          pi(2);
          pc("if (!");
          pn(&stmt->data.loop.cond_val);
          pc(") break;\n");
        }

        gens(&stmt->data.loop.body_stmts, indent + 2);

        if (!nameIsNull(&stmt->data.loop.continue_val)) {
          pi(2);
          pc("if (!");
          pn(&stmt->data.loop.continue_val);
          pc(") break;\n");
        }
        gens(&stmt->data.loop.continue_stmts, indent + 2);
        pi(0);
        pc("}\n");
        break;
      }
      case C2_Stmt_IF: {
        size_t nifs = stmt->data.xif.ifs.len;
        for (int ifi = 0; ifi < nifs; ++ifi) {
          C2_StmtId* ifhandle = list_get(C2_StmtId, &stmt->data.xif.ifs, ifi);
          C2_Stmt* xif = list_get_from_handle(C2_Stmt, &ctx->stmts, *ifhandle);
          if (ifi > 0) pc(" else {\n  ");
          gens(&xif->data.ifblock.cond_stmts, indent + 2);
          pc("if (");
          pn(&xif->data.ifblock.cond);
          pc(") {\n");
          gens(&xif->data.ifblock.body_stmts, indent + 2);
          pi(0);
          pc("}");
        }
        if (stmt->data.xif.xelse.len) {
          pc(" else {\n");
          gens(&stmt->data.xif.xelse, indent + 2);
          pi(0);
          pc("}");
        }
        for (int k = 0; k < (nifs - 1); ++k) pc("}");
        pc("\n");
        break;
      }
      case C2_Stmt_SWITCH: {
        pc("switch (");
        pn(&stmt->data.xswitch.expr);
        pc(") {\n");
        size_t ncases = stmt->data.xswitch.cases.len;
        for (int k = 0; k < ncases; ++k) {
          pi(2);
          pc("case ");
          C2_StmtId* case_handle = list_get(C2_StmtId, &stmt->data.xswitch.cases, k);
          C2_Stmt* xcase = list_get_from_handle(C2_Stmt, &ctx->stmts, *case_handle);
          pn(&xcase->data.switchcase.val);
          pc(":");
          size_t ncasestmts = xcase->data.switchcase.stmts.len;
          if (ncasestmts) {
            pc("{\n");
          gens(&xcase->data.switchcase.stmts, indent + 2);
            pi(2);
            pc("}\n");
          } else {
            pc("\n");
          }
        }
        if (stmt->data.xswitch.xdefault.len) {
          pi(2);
          pc("default: {\n");
          gens(&stmt->data.xswitch.xdefault, indent + 4);
          pi(2);
          pc("}\n");
        }
        pi(0);
        pc("}\n");
        break;
      }

      // case C2_Stmt_EXPR:
      // case C2_Stmt_ASSIGN:

      default: {
        pc(stmt_strs[stmt->type]);
      }
    }

    if (stmt->type == C2_Stmt_LABEL ||
        stmt->type == C2_Stmt_LOOP ||
        stmt->type == C2_Stmt_IF ||
        stmt->type == C2_Stmt_SWITCH ||
        false) continue;
    pc(";\n");
  }
}

Status c2_gen_c(C2_Ctx* ctx, C2_Module* module, C2_GenCtxC* genctx) {
  symtab_t* symtab = symtab_init();

  pc("#include <stdint.h>\n");

  {
    // Named types
    pc("\n// named types\n");
    size_t ntypes = ctx->types.len;
    for (size_t i = 0; i < ntypes; ++i) {
      C2_Type* type = list_get(C2_Type, &ctx->types, i);
      list_handle_t type_handle = list_get_handle(&ctx->types, type);
      switch (type->type) {
        case C2_TypePtr: {
          symtab_put(symtab, &type->data.named.name, type_handle);
          pc("typedef ");
          pt(type->data.named.type);
          pc("* ");
          pn(&(type->data.named.name));
          pc(";\n");
          break;
        }
        case C2_TypeFnPtr: {
          symtab_put(symtab, &type->data.fnsig.name, type_handle);
          pc("typedef ");
          printFnSig(ctx, &type->data.fnsig, genctx, false, true);
          pc(";\n");
          break;
        }
        case C2_TypeArray: {
          symtab_put(symtab, &type->data.arr.named.name, type_handle);
          pc("typedef ");
          pt(type->data.arr.named.type);
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
          symtab_put(symtab, &type->data.xstruct.name, type_handle);
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
            C2_Type* f = gettype(*list_get(C2_TypeId, &type->data.xstruct.fields, i));
            pt(f->data.named.type);
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
      pc("extern ");
      pt(C2_TypeBytes);
      pc(" ");
      C2_Name* name = list_get(C2_Name, &module->extern_data, i);
      pn(name);
      symtab_put(symtab, name, C2_TypeBytes);
      pc(";\n");
    }
  }

  {
    // Extern fns
    pc("\n// extern fns\n");
    size_t nfns = module->extern_fns.len;
    for (size_t i = 0; i < nfns; ++i) {
      C2_Type* fn_t = gettype(*list_get(C2_TypeId, &module->extern_fns, i));
      C2_FnSig* fn = &fn_t->data.fnsig;
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
      symtab_put(symtab, &bss->name, C2_TypeBytes);
    }
  }

  {
    // Data
    pc("\n// data\n");
    size_t ndata = module->data.len;
    for (size_t i = 0; i < ndata; ++i) {
      C2_Data* data = list_get(C2_Data, &module->data, i);
      printData(ctx, data, genctx);
      symtab_put(symtab, &data->name, C2_TypeBytes);
    }
  }

  {
    // Functions
    pc("\n// functions\n");
    size_t nfns = module->fns.len;
    symtab_t* symtab_local = symtab_init();
    for (size_t i = 0; i < nfns; ++i) {
      symtab_reset(symtab_local);
      C2_Fn* fn = list_get(C2_Fn, &module->fns, i);
      C2_Type* fn_t = gettype(fn->sig);
      C2_FnSig* sig = &fn_t->data.fnsig;
      printFnSig(ctx, sig, genctx, true, false);
      pc(" {\n");
      gens(&fn->stmts, 2);
      pc("}\n\n");
    }
    symtab_deinit(symtab_local);
  }

  symtab_deinit(symtab);
  return OK;
}

// TODO:
// Helpers to manage
//   Names
//   Stmts
//   Types
// line number directives
// literals
