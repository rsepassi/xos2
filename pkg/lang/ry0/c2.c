#include "c2.h"

#include "base/str.h"
#include "khash.h"

// Symbol table C2_Name -> C2_TypeId
KHASH_MAP_INIT_INT(mSymtab, C2_TypeId);
#define symtab_t khash_t(mSymtab)
static symtab_t* symtab_init() { return kh_init(mSymtab); }
static void symtab_deinit(symtab_t* s) { kh_destroy(mSymtab, s); }
static void symtab_reset(symtab_t* s) { kh_clear(mSymtab, s); }
static void symtab_put(symtab_t* s, C2_Name name, C2_TypeId type) {
  int32_t k = *(int32_t*)(&name);
  int ret;
  khiter_t key = kh_put(mSymtab, s, k, &ret);
  kh_val(s, key) = type;
}
static C2_TypeId symtab_get(symtab_t* s, C2_Name name) {
  int32_t k = *(int32_t*)(&name);
  khiter_t iter = kh_get(mSymtab, s, k);
  if (iter == kh_end(s)) return C2_TypeId_NULL;
  return kh_val(s, iter);
}

// symtab_get helper
#define getsymtype(name) getsymtypeid2(name, ctx, symtab, symtab_local)

// printStmts helper
#define gens(stmts, i) printStmts(ctx, genctx, symtab, symtab_local, stmts, i, true);


// Helper to get named type
#define gettype(tid) \
  list_get_from_handle(C2_Type, &ctx->types, (tid).handle)
#define getstmt(sid) \
  list_get_from_handle(C2_Stmt, &ctx->stmts, (sid))
#define getblock(sid) getstmt(sid)->data.block

// print helpers
//
// print str
#define p(s) genctx->write(genctx->user_ctx, (s))
// print c string
#define pc(s) p(cstr(s))
// print C2_Name
#define pn(n) do { \
    C2_Name na = (n); \
    p(str_init((char*)(&ctx->names.buf.base[na.offset]), na.len)); \
  } while (0)
// print C2_TypeId
#define pt(t) printTypeName(ctx, (t), genctx)
// print indent
#define pi(n) printIndent(genctx, n + indent)

static const char* type_strs[C2_TypeNamedOffset] = {
  "INVALID",
  "void",
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
  "uint8_t*",
};

static const char* stmt_strs[C2_Stmt__Sentinel] = {
  "INVALID",
  "CAST",
  "DECL",
  "LABEL",
  "EXPR",
  "TERM",
  "FNCALL",
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
  "BLOCK",
};

static const char* op_strs[C2_Op__Sentinel] = {
  "INVALID",
  "NONE",
  // Unary
  "-",
  "!",
  "~",
  "&",
  // Binary
  "+",
  "-",
  "*",
  "/",
  "%",
  "==",
  "!=",
  "<",
  ">",
  "<=",
  ">=",
  "&&",
  "||",
  "&",
  "|",
  "^",
  "<<",
  ">>",
};

static inline bool typeIsNull(C2_TypeId t) {
  return t.type == 0 && t.handle == 0;
}

static inline bool typesEq(C2_TypeId t0, C2_TypeId t1) {
  return t0.type == t1.type && t0.handle == t1.handle;
}

static C2_TypeId getsymtypeid2(C2_Name name, C2_Ctx* ctx, symtab_t* symtab, symtab_t* symtab_local) {
    C2_TypeId tid = symtab_get(symtab_local, name);
    if (typeIsNull(tid)) tid = symtab_get(symtab, name);
    return tid;
}

static inline bool exprIsUnary(C2_OpType op) {
  return op <= C2_Op_ADDR;
}

static inline bool nameIsNull(C2_Name name) {
  return name.offset == 0 && name.len == 0;
}

static inline bool namesEq(C2_Name name0, C2_Name name1) {
  return name0.offset == name1.offset && name0.len == name1.len;
}

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

static inline bool isNamedType(C2_TypeType t) { return t > C2_TypeNamedOffset; }
static inline bool isBaseType(C2_TypeId t) { return t.type < C2_TypeNamedOffset; }

static void printTypeName(C2_Ctx* ctx, C2_TypeId t, C2_GenCtxC* genctx) {
  if (!isNamedType(t.type)) {
    pc(type_strs[t.type]);
    return;
  }

  C2_Type* type = gettype(t);
  C2_Name name;
  switch (type->type) {
    case C2_TypePtr: {
      name = type->data.named.name;
      break;
    }
    case C2_TypeArray: {
      name = type->data.arr.named.name;
      break;
    }
    case C2_TypeStruct: {
      name = type->data.xstruct.name;
      break;
    }
    case C2_TypeFnSig:
    case C2_TypeFnPtr: {
      name = type->data.fnsig.name;
      break;
    }
    default: {}
  }
  pn(name);
}

static void printTerm(
    C2_Ctx* ctx,
    list_t* expr,
    C2_GenCtxC* genctx,
    symtab_t* symtab,
    symtab_t* symtab_local) {
  int nderef0 = 0;
  int nterms0 = expr->len;
  for (int i = 0; i < nterms0; ++i) {
    C2_Stmt* term = getstmt(*list_get(C2_StmtId, expr, i));
    if (term->data.term.type == C2_Term_DEREF) ++nderef0;
  }
  for (int i = 0; i < nderef0; ++i) pc("(*");

  C2_TypeId tid;
  for (int i = 0; i < nterms0; ++i) {
    C2_Stmt* term = getstmt(*list_get(C2_StmtId, expr, i));

    switch (term->data.term.type) {
      case C2_Term_NAME: {
        C2_Name name = term->data.term.name;
        tid = getsymtype(name);
        pn(name);
        break;
      }
      case C2_Term_DEREF: {
        if (isNamedType(tid.type)) {
          C2_Type* t = gettype(tid);
          if (t->type == C2_TypePtr) {
            tid = t->data.named.type;
          }
        } else if (tid.type == C2_TypeBytes) {
          tid = C2_TypeIdBase(C2_TypeU8);
        }
        pc(")");
        break;
      }
      case C2_Term_ARRAY: {
        if (isNamedType(tid.type)) {
          C2_Type* t = gettype(tid);
          if (t->type == C2_TypePtr) {
            tid = t->data.named.type;
          } else if (t->type == C2_TypeArray) {
            tid = t->data.arr.named.type;
          }
        } else {
          if (tid.type == C2_TypeBytes) tid = C2_TypeIdBase(C2_TypeU8);
        }

        pc("[");
        pn(term->data.term.name);
        pc("]");
        break;
      }
      case C2_Term_FIELD: {
        C2_Name name = term->data.term.name;

        C2_Type* t = gettype(tid);
        if (t->type == C2_TypeStruct) {
          pc(".");
          int nfields = t->data.xstruct.fields.len;
          for (int i = 0; i < nfields; ++i) {
            C2_Type* ft = gettype(*list_get(C2_TypeId, &t->data.xstruct.fields, i));
            if (namesEq(ft->data.named.name, name)) {
              tid = ft->data.named.type;
              break;
            }
          }
        } else if (t->type == C2_TypePtr) {
          pc("->");
          tid = t->data.named.type;
        }

        pn(name);
        break;
      }
    }
  }
}

static void printFnSig(C2_Ctx* ctx, C2_FnSig* fn, C2_GenCtxC* genctx, bool with_names, bool ptr_form, symtab_t* symtab) {
  pt(fn->ret);
  pc(" ");
  if (ptr_form) {
    pc("(*");
    pn(fn->name);
    pc(")");
  } else {
    pn(fn->name);
  }

  pc("(");
  size_t nargs = fn->args.len;
  for (size_t j = 0; j < nargs; ++j) {
    if (j > 0) pc(", ");
    C2_TypeId argtid = *list_get(C2_TypeId, &fn->args, j);
    C2_Type* t = gettype(argtid);
    if (symtab) {
      symtab_put(symtab, t->data.named.name, argtid);
    }
    pt(t->data.named.type);
    if (with_names) {
      pc(" ");
      pn(t->data.named.name);
    }
  }
  pc(")");
}

static void printData(C2_Ctx* ctx, C2_Data* data, C2_GenCtxC* genctx) {
  if (!data->export) {
    pc("static ");
  }
  pt(C2_TypeIdBase(C2_TypeU8));
  pc(" ");
  pn(data->name);
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

static void printStmts(
    C2_Ctx* ctx,
    C2_GenCtxC* genctx,
    symtab_t* symtab,
    symtab_t* symtab_local,
    list_t* stmts,
    int indent,
    bool addnl) {
  size_t nstmt = stmts->len;
  for (size_t j = 0; j < nstmt; ++j) {
    C2_Stmt* stmt = getstmt(*list_get(C2_StmtId, stmts, j));
    pi(0);
    switch (stmt->type) {
      case C2_Stmt_DECL: {
        symtab_put(symtab_local, stmt->data.decl.name, stmt->data.decl.type);
        pt(stmt->data.decl.type);
        pc(" ");
        pn(stmt->data.decl.name);
        break;
      }

      case C2_Stmt_CAST: {
        pn(stmt->data.cast.out_name);
        pc(" = (");
        pt(stmt->data.cast.type);
        pc(")");
        pn(stmt->data.cast.in_name);
        symtab_put(symtab_local, stmt->data.cast.out_name, stmt->data.cast.type);
        break;
      }

      case C2_Stmt_LABEL: {
        pn(stmt->data.label.name);
        pc(":\n");
        break;
      }
      case C2_Stmt_GOTO: {
        pc("goto ");
        pn(stmt->data.xgoto.label);
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
      case C2_Stmt_RETURN: {
        C2_Name name = stmt->data.xreturn.name;
        if (nameIsNull(name)) {
          pc("return");
        } else {
          pc("return ");
          pn(stmt->data.xreturn.name);
        }
        break;
      }

      case C2_Stmt_LOOP: {
        pc("while (1) {\n");

        if (stmt->data.loop.cond_stmts != C2_StmtId_NULL) {
          gens(&getblock(stmt->data.loop.cond_stmts), indent + 2);
        }

        if (!nameIsNull(stmt->data.loop.cond_val)) {
          pi(2);
          pc("if (!");
          pn(stmt->data.loop.cond_val);
          pc(") break;\n");
        }

        if (stmt->data.loop.body_stmts != C2_StmtId_NULL) {
          gens(&getblock(stmt->data.loop.body_stmts), indent + 2);
        }

        if (!nameIsNull(stmt->data.loop.continue_val)) {
          pi(2);
          pc("if (!");
          pn(stmt->data.loop.continue_val);
          pc(") break;\n");
        }

        if (stmt->data.loop.continue_stmts != C2_StmtId_NULL) {
          gens(&getblock(stmt->data.loop.continue_stmts), indent + 2);
        }

        pi(0);
        pc("}\n");
        break;
      }

      case C2_Stmt_IF: {
        if (stmt->data.xif.ifs == C2_StmtId_NULL) {
          pc("\n");
          break;
        }
        list_t* ifs = &getblock(stmt->data.xif.ifs);
        size_t nifs = ifs->len;
        for (int ifi = 0; ifi < nifs; ++ifi) {
          C2_Stmt* xif = getstmt(*list_get(C2_StmtId, ifs, ifi));
          if (ifi > 0) pc(" else {\n  ");
          if (xif->data.ifblock.cond_stmts != C2_StmtId_NULL) {
            gens(&getblock(xif->data.ifblock.cond_stmts), indent);
            pi(0);
          }
          pc("if (");
          pn(xif->data.ifblock.cond);
          pc(") {\n");
          if (xif->data.ifblock.body_stmts != C2_StmtId_NULL) {
            gens(&getblock(xif->data.ifblock.body_stmts), indent + 2);
          }
          pi(0);
          pc("}");
        }

        if (stmt->data.xif.xelse != C2_StmtId_NULL) {
          list_t* xelse = &getblock(stmt->data.xif.xelse);
          if (xelse->len) {
            pc(" else {\n");
            gens(xelse, indent + 2);
            pi(0);
            pc("}");
          }
        }

        if (nifs) for (int k = 0; k < (nifs - 1); ++k) pc("}");
        pc("\n");
        break;
      }

      case C2_Stmt_SWITCH: {
        pc("switch (");
        pn(stmt->data.xswitch.expr);
        pc(") {\n");
        if (stmt->data.xswitch.cases != C2_StmtId_NULL) {
          list_t* cases = &getblock(stmt->data.xswitch.cases);
          size_t ncases = cases->len;
          for (int k = 0; k < ncases; ++k) {
            pi(2);
            pc("case ");
            C2_Stmt* xcase = getstmt(*list_get(C2_StmtId, cases, k));
            pn(xcase->data.switchcase.val);
            pc(":");
            list_t* stmts = &getblock(xcase->data.switchcase.stmts);
            size_t ncasestmts = stmts->len;
            if (ncasestmts) {
              pc("{\n");
              gens(stmts, indent + 4);
              pi(2);
              pc("}\n");
            } else {
              pc("\n");
            }
          }
        }

        if (stmt->data.xswitch.xdefault != C2_StmtId_NULL) {
          list_t* xdefault = &getblock(stmt->data.xswitch.xdefault);
          if (xdefault->len) {
            pi(2);
            pc("default: {\n");
            gens(xdefault, indent + 4);
            pi(2);
            pc("}\n");
          }
        }

        pi(0);
        pc("}\n");
        break;
      }

      case C2_Stmt_FNCALL: {
        bool has_ret = !nameIsNull(stmt->data.fncall.ret);
        if (has_ret) {
          pn(stmt->data.fncall.ret);
          pc(" = ");
        }
        pn(stmt->data.fncall.name);
        pc("(");
        int nargs = stmt->data.fncall.args.len;
        for (int i = 0; i < nargs; ++i) {
          if (i > 0) pc(", ");
          pn(*list_get(C2_Name, &stmt->data.fncall.args, i));
        }
        pc(")");

        break;
      }

      case C2_Stmt_EXPR: {
        C2_OpType op = stmt->data.expr.type;
        if (exprIsUnary(op)) {
          if (op != C2_Op_NONE) pc(op_strs[op]);
          printTerm(ctx, &getblock(stmt->data.expr.term0), genctx, symtab, symtab_local);
        } else {
          printTerm(ctx, &getblock(stmt->data.expr.term0), genctx, symtab, symtab_local);
          pc(" ");
          pc(op_strs[op]);
          pc(" ");
          printTerm(ctx, &getblock(stmt->data.expr.term1), genctx, symtab, symtab_local);
        }
        break;
      }

      case C2_Stmt_ASSIGN: {
        list_t stmts;
        stmts.cap = 1;
        stmts.len = 1;
        stmts.elsz = sizeof(C2_StmtId);

        stmts.base = (uint8_t*)&stmt->data.assign.lhs;
        printStmts(ctx, genctx, symtab, symtab_local, &stmts, 0, false);
        pc(" = ");
        stmts.base = (uint8_t*)&stmt->data.assign.rhs;
        printStmts(ctx, genctx, symtab, symtab_local, &stmts, 0, false);
        break;
      }

      default: {
        pc(stmt_strs[stmt->type]);
      }
    }

    if (!addnl ||
        stmt->type == C2_Stmt_LABEL ||
        stmt->type == C2_Stmt_LOOP ||
        stmt->type == C2_Stmt_IF ||
        stmt->type == C2_Stmt_SWITCH ||
        false) continue;
    pc(";\n");
  }
}

Status c2_gen_c(C2_Ctx* ctx, C2_Module* module, C2_GenCtxC* genctx) {
  // Global symbol table
  symtab_t* symtab = symtab_init();

  pc("#include <stdint.h>\n");

  {
    // Named types
    pc("\n// named types\n");
    size_t ntypes = ctx->types.len;
    for (size_t i = 0; i < ntypes; ++i) {
      C2_Type* type = list_get(C2_Type, &ctx->types, i);
      C2_TypeId typeid = C2_TypeIdNamed(ctx, type);
      switch (type->type) {
        case C2_TypePtr: {
          symtab_put(symtab, type->data.named.name, typeid);
          pc("typedef ");
          pt(type->data.named.type);
          pc("* ");
          pn(type->data.named.name);
          pc(";\n");
          break;
        }
        case C2_TypeFnPtr: {
          symtab_put(symtab, type->data.fnsig.name, typeid);
          pc("typedef ");
          printFnSig(ctx, &type->data.fnsig, genctx, false, true, NULL);
          pc(";\n");
          break;
        }
        case C2_TypeArray: {
          symtab_put(symtab, type->data.arr.named.name, typeid);
          pc("typedef ");
          pt(type->data.arr.named.type);
          pc(" ");
          pn(type->data.arr.named.name);
          char buf[128];
          int len = snprintf(buf, 128, "%d", type->data.arr.len);
          pc("[");
          p(str_init(buf, len));
          pc("];\n");
          break;
        }
        case C2_TypeStruct: {
          symtab_put(symtab, type->data.xstruct.name, typeid);
          pc("typedef struct ");
          pn(type->data.xstruct.name);
          pc("_s ");
          pn(type->data.xstruct.name);
          pc(";\n");
          pc("struct ");
          pn(type->data.xstruct.name);
          pc("_s {\n");
          size_t nfields = type->data.xstruct.fields.len;
          for (size_t i = 0; i < nfields; ++i) {
            pc("  ");
            C2_Type* f = gettype(*list_get(C2_TypeId, &type->data.xstruct.fields, i));
            pt(f->data.named.type);
            pc(" ");
            pn(f->data.named.name);
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
      pt(C2_TypeIdBase(C2_TypeBytes));
      pc(" ");
      C2_Name* name = list_get(C2_Name, &module->extern_data, i);
      pn(*name);
      symtab_put(symtab, *name, C2_TypeIdBase(C2_TypeBytes));
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
      printFnSig(ctx, fn, genctx, false, false, NULL);
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
      symtab_put(symtab, bss->name, C2_TypeIdBase(C2_TypeBytes));
    }
  }

  {
    // Data
    pc("\n// data\n");
    size_t ndata = module->data.len;
    for (size_t i = 0; i < ndata; ++i) {
      C2_Data* data = list_get(C2_Data, &module->data, i);
      printData(ctx, data, genctx);
      symtab_put(symtab, data->name, C2_TypeIdBase(C2_TypeBytes));
    }
  }

  {
    // Functions
    pc("\n// functions\n");

    // Function-local symbol table
    symtab_t* symtab_local = symtab_init();

    size_t nfns = module->fns.len;
    for (size_t i = 0; i < nfns; ++i) {
      symtab_reset(symtab_local);
      C2_Fn* fn = list_get(C2_Fn, &module->fns, i);
      C2_FnSig* sig = &gettype(fn->sig)->data.fnsig;
      printFnSig(ctx, sig, genctx, true, false, symtab_local);
      pc(" {\n");
      gens(&getblock(fn->stmts), 2);
      pc("}\n\n");
    }

    symtab_deinit(symtab_local);
  }

  symtab_deinit(symtab);
  return OK;
}

KHASH_MAP_INIT_STR(mNames, C2_Name);
#define namemap_t khash_t(mNames)

static C2_Names c2_names_init() {
  return (C2_Names){
    .buf = list_init(uint8_t, -1),
    .ctx = (void*)kh_init(mNames),
    .tmp = 0,
  };
}

C2_Name c2_ctx_tmpname(C2_Ctx* ctx) {
  char buf[8];
  int len = snprintf(buf, 8, "tmp%lu", ctx->names.tmp++);
  buf[len] = 0;
  return c2_ctx_namec(ctx, buf);
}

str_t c2_ctx_strname(C2_Ctx* ctx, C2_Name name) {
  return str_init((char*)(&ctx->names.buf.base[name.offset]), name.len);
}

static void c2_names_deinit(C2_Names* names) {
  list_deinit(&names->buf);
  kh_destroy(mNames, (namemap_t*)names->ctx);
}

C2_Name c2_ctx_namec(C2_Ctx* ctx, const char* cname) {
  C2_Names* names = &ctx->names;
  namemap_t* namemap = (namemap_t*)names->ctx;

  khiter_t iter = kh_get(mNames, namemap, cname);
  if (iter == kh_end(namemap)) {
    int len = strlen(cname);
    str_t sbuf = str_append(&names->buf, str_init(cname, len));

    C2_Name name = {
      .offset = list_idx(&names->buf, (void*)sbuf.bytes),
      .len = len,
    };

    int ret;
    khiter_t key = kh_put(mNames, namemap, cname, &ret);
    kh_val(namemap, key) = name;
    return name;
  } else {
    return kh_val(namemap, iter);
  }
}

C2_Module c2_module_init(C2_Ctx* ctx) {
  return (C2_Module){
    .ctx = ctx,
    .extern_fns = list_init(C2_TypeId, -1),
    .extern_data = list_init(C2_Name, -1),
    .data = list_init(C2_Data, -1),
    .bss = list_init(C2_Data, -1),
    .fns = list_init(C2_Fn, -1),
  };
}

void c2_module_deinit(C2_Module* module) {
  list_deinit(&module->extern_fns);
  list_deinit(&module->extern_data);
  list_deinit(&module->data);
  list_deinit(&module->bss);
  list_deinit(&module->fns);
}

C2_Ctx c2_ctx_init() {
  return (C2_Ctx){
    .names = c2_names_init(),
    .types = list_init(C2_Type, -1),
    .stmts = list_init(C2_Stmt, -1),
  };
}

void c2_ctx_deinit(C2_Ctx* ctx) {
  c2_names_deinit(&ctx->names);

  for (int i = 0; i < ctx->types.len; ++i) {
    C2_Type* t = list_get(C2_Type, &ctx->types, i);
    if (t->type == C2_TypeStruct) {
      list_deinit(&t->data.xstruct.fields);
    } else if (t->type == C2_TypeFnPtr || t->type == C2_TypeFnSig) {
      list_deinit(&t->data.fnsig.args);
    }
  }

  for (int i = 0; i < ctx->stmts.len; ++i) {
    C2_Stmt* s = list_get(C2_Stmt, &ctx->stmts, i);
    if (s->type == C2_Stmt_BLOCK) {
      list_deinit(&s->data.block);
    } else if (s->type == C2_Stmt_FNCALL) {
      list_deinit(&s->data.fncall.args);
    }
  }

  list_deinit(&ctx->types);
  list_deinit(&ctx->stmts);
}

C2_Type* c2_ctx_addtypec(C2_Ctx* ctx, C2_TypeType type, const char* cname) {
  DCHECK(isNamedType(type));
  C2_Type* t = list_add(C2_Type, &ctx->types);
  t->type = type;

  C2_Name name = c2_ctx_namec(ctx, cname);

  switch (type) {
    case C2_TypeFnArg:
    case C2_TypeStructField:
    case C2_TypePtr: {
      t->data.named.name = name;
      break;
    }
    case C2_TypeFnPtr:
    case C2_TypeFnSig: {
      t->data.fnsig.name = name;
      t->data.fnsig.args = list_init(C2_TypeId, 8);
      break;
    }
    case C2_TypeArray: {
      t->data.arr.named.name = name;
      break;
    }
    case C2_TypeStruct: {
      t->data.xstruct.name = name;
      t->data.xstruct.fields = list_init(C2_TypeId, 8);
      break;
    }
    default: {
      CHECK(false);
    }
  }

  return t;
}

C2_TypeId C2_TypeIdNamed(C2_Ctx* ctx, C2_Type* t) {
  return (C2_TypeId){
    .type = t->type,
    .handle = list_get_handle(&ctx->types, t),
  };
}

bool c2_names_eq(C2_Name n0, C2_Name n1) { return namesEq(n0, n1); }

void c2_ctx_addstructfield(C2_Ctx* ctx,
    C2_Type* struct_type, const char* field_name, C2_TypeId field_type) {
  list_t* fields = &struct_type->data.xstruct.fields;
  C2_Type* t = c2_ctx_addtypec(ctx, C2_TypeStructField, field_name);
  t->data.named.type = field_type;
  *list_add(C2_TypeId, fields) = C2_TypeIdNamed(ctx, t);
}

void c2_ctx_addfnarg(C2_Ctx* ctx,
    C2_Type* fn_type, const char* arg_name, C2_TypeId arg_type) {
  list_t* args = &fn_type->data.fnsig.args;
  C2_Type* t = c2_ctx_addtypec(ctx, C2_TypeFnArg, arg_name);
  t->data.named.type = arg_type;
  *list_add(C2_TypeId, args) = C2_TypeIdNamed(ctx, t);
}

C2_Fn* c2_module_addfn(C2_Module* module, C2_TypeId sig) {
  C2_Fn* fn = list_add(C2_Fn, &module->fns);
  fn->sig = sig;

  C2_Stmt* block = list_add(C2_Stmt, &module->ctx->stmts);
  block->type = C2_Stmt_BLOCK;
  block->data.block = list_init(C2_StmtId, 32);

  fn->stmts = list_get_handle(&module->ctx->stmts, block);
  return fn;
}

C2_StmtId c2_ctx_addblock(C2_Ctx* ctx) {
  C2_Stmt* stmt = c2_ctx_addstmt(ctx, NULL, C2_Stmt_BLOCK);
  return c2_ctx_stmtid(ctx, stmt);
}

C2_Stmt* c2_ctx_blockadd(C2_Ctx* ctx, C2_StmtId blockid, C2_StmtType type) {
  C2_Stmt* new = c2_ctx_addstmt(ctx, NULL, type);
  C2_Stmt* block = c2_ctx_getstmt(ctx, blockid);
  DCHECK(block->type == C2_Stmt_BLOCK, "blockid %d must reference a block stmt", blockid);
  *list_add(C2_StmtId, &block->data.block) = c2_ctx_stmtid(ctx, new);
  return new;
}

C2_Stmt* c2_ctx_getstmt(C2_Ctx* ctx, C2_StmtId stmt) {
  return list_get_from_handle(C2_Stmt, &ctx->stmts, stmt);
}

C2_Type* c2_ctx_gettype(C2_Ctx* ctx, C2_TypeId type) {
  if (!isNamedType(type.type)) return NULL;
  return list_get_from_handle(C2_Type, &ctx->types, type.handle);
}

C2_Stmt* c2_ctx_addstmt(C2_Ctx* ctx, C2_Fn* fn, C2_StmtType type) {
  C2_Stmt* stmt = list_add(C2_Stmt, &ctx->stmts);
  stmt->type = type;

  if (fn != NULL) {
    list_t* block = &c2_ctx_getstmt(ctx, fn->stmts)->data.block;
    *list_add(C2_StmtId, block) = c2_ctx_stmtid(ctx, stmt);
  }

  if (type == C2_Stmt_FNCALL) {
    stmt->data.fncall.args = list_init(C2_Name, 4);
  } else if (type == C2_Stmt_BLOCK) {
    stmt->data.block = list_init(C2_StmtId, 4);
  }
  return stmt;
}

C2_Stmt* c2_ctx_addexpr(C2_Ctx* ctx, C2_OpType op, C2_Name lhs, C2_Name rhs) {
  list_reserve(&ctx->stmts, ctx->stmts.len + 5);

  C2_Stmt* t0 = c2_ctx_addstmt(ctx, NULL, C2_Stmt_BLOCK);
  C2_Stmt* t00 = c2_ctx_addstmt(ctx, NULL, C2_Stmt_TERM);
  t00->data.term.type = C2_Term_NAME;
  t00->data.term.name = lhs;
  *list_add(C2_StmtId, &t0->data.block) = c2_ctx_stmtid(ctx, t00);

  C2_Stmt* t1 = NULL;
  if (!exprIsUnary(op)) {
    t1 = c2_ctx_addstmt(ctx, NULL, C2_Stmt_BLOCK);
    C2_Stmt* t10 = c2_ctx_addstmt(ctx, NULL, C2_Stmt_TERM);
    t10->data.term.type = C2_Term_NAME;
    t10->data.term.name = rhs;
    *list_add(C2_StmtId, &t1->data.block) = c2_ctx_stmtid(ctx, t10);
  }

  C2_Stmt* expr = c2_ctx_addstmt(ctx, NULL, C2_Stmt_EXPR);
  expr->data.expr.type = op;
  expr->data.expr.term0 = c2_ctx_stmtid(ctx, t0);
  expr->data.expr.term1 = c2_ctx_stmtid(ctx, t1);

  return expr;
}

C2_StmtId c2_ctx_stmtid(C2_Ctx* ctx, C2_Stmt* s) {
  return list_get_handle(&ctx->stmts, s);
}

void c2_ctx_addassign(C2_Ctx* ctx, C2_Fn* fn, C2_StmtId lhs, C2_StmtId rhs) {
  C2_Stmt* s = c2_ctx_addstmt(ctx, fn, C2_Stmt_ASSIGN);
  s->data.assign.lhs = lhs;
  s->data.assign.rhs = rhs;
}

void c2_ctx_addterm(C2_Ctx* ctx, C2_Stmt* expr, bool rhs, C2_TermType type, C2_Name name) {
  C2_Stmt* term = c2_ctx_addstmt(ctx, NULL, C2_Stmt_TERM);
  term->data.term.type = type;
  term->data.term.name = name;

  C2_StmtId sid = rhs ? expr->data.expr.term1 : expr->data.expr.term0;
  C2_Stmt* term_block = c2_ctx_getstmt(ctx, sid);
  *list_add(C2_StmtId, &term_block->data.block) = c2_ctx_stmtid(ctx, term);
}

void c2_ctx_addifblock(C2_Ctx* ctx, C2_StmtId ifs, C2_StmtId cond_block, C2_Name cond, C2_StmtId body_block) {
  C2_Stmt* s = c2_ctx_blockadd(ctx, ifs, C2_Stmt_IFBLOCK);
  s->data.ifblock.cond_stmts = cond_block;
  s->data.ifblock.cond = cond;
  s->data.ifblock.body_stmts = body_block;
}

void c2_ctx_addswitchcase(C2_Ctx* ctx, C2_StmtId cases, C2_Name case_val, C2_StmtId case_block) {
  C2_Stmt* s = c2_ctx_blockadd(ctx, cases, C2_Stmt_SWITCHCASE);
  s->data.switchcase.val = case_val;
  s->data.switchcase.stmts = case_block;
}

// TODO:
// line number directives
// literals
// checks/asserts
// tmpscope to reset tmp names
// hashmap str keys that are not null-terminated
// blocks within functions for more scoped stack alloc
// stmts/types/names reserve so that ptrs are stable
