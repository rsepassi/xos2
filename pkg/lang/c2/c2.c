#include "c2.h"
#include "c2_internal.h"

#include <stdio.h>

#include "base/log.h"
#include "khash.h"

// Some helper macros
#define gettype(tid) c2_ctx_gettype(ctx, tid)
#define getstmt(sid) c2_ctx_getstmt(ctx, sid)
#define getblock(sid) &getstmt(sid)->data.block
#define getsymtype(name) getsymtypeid2(name, ctx, symtab, symtab_local)

// print helpers
//
// print str_t
#define p(s) genctx->write(genctx->user_ctx, (s))
// print c string
#define pc(s) p(cstr(s))
// print C2_Name
#define pn(n) p(c2_ctx_strname(ctx, n))
// print C2_TypeId
#define pt(t) printTypeName(ctx, (t), genctx)
// print indent
#define pi(n) printIndent(genctx, n + indent)
// printStmts helper
#define pblock(stmts, i) \
  printStmts(ctx, genctx, symtab, symtab_local, stmts, i, true);

const char* c2_type_strs[C2_TypeNamedOffset] = {
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

const char* c2_stmt_strs[C2_Stmt__Sentinel] = {
  "INVALID",
  "CAST",
  "DECL",
  "EXPR",
  "TERM",
  "FNCALL",
  "ASSIGN",
  "RETURN",
  "BREAK",
  "CONTINUE",
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

static inline bool exprIsUnary(C2_OpType op) { return op <= C2_Op_ADDR; }
static inline bool typeIsNull(C2_TypeId t) {
  return t.type == 0 && t.handle == 0;
}
bool c2_name_isnull(C2_Name n) {
  return n.offset == 0 && n.len == 0;
}
static inline bool isNamedType(C2_TypeType t) {
  return t > C2_TypeNamedOffset;
}

c2_symtab_t* c2_symtab_init() { return kh_init(mc2symtab); }
void c2_symtab_deinit(c2_symtab_t* s) { kh_destroy(mc2symtab, s); }
void c2_symtab_reset(c2_symtab_t* s) { kh_clear(mc2symtab, s); }
void c2_symtab_put(c2_symtab_t* s, C2_Name name, C2_TypeId type) {
  int32_t k = *(int32_t*)(&name);
  int ret;
  khiter_t key = kh_put(mc2symtab, s, k, &ret);
  kh_val(s, key) = type;
}
C2_TypeId c2_symtab_get(c2_symtab_t* s, C2_Name name) {
  int32_t k = *(int32_t*)(&name);
  khiter_t iter = kh_get(mc2symtab, s, k);
  if (iter == kh_end(s)) return C2_TypeId_NULL;
  return kh_val(s, iter);
}

static C2_TypeId getsymtypeid2(
    C2_Name name,
    C2_Ctx* ctx,
    c2_symtab_t* symtab,
    c2_symtab_t* symtab_local) {
  C2_TypeId tid = c2_symtab_get(symtab_local, name);
  if (typeIsNull(tid)) tid = c2_symtab_get(symtab, name);
  return tid;
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

static void printTypeName(C2_Ctx* ctx, C2_TypeId t, C2_GenCtxC* genctx) {
  if (!isNamedType(t.type)) {
    pc(c2_type_strs[t.type]);
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
    c2_symtab_t* symtab,
    c2_symtab_t* symtab_local) {
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
        C2_Name name = term->data.term.data.name;
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
        pn(term->data.term.data.name);
        pc("]");
        break;
      }
      case C2_Term_FIELD: {
        C2_Name name = term->data.term.data.name;

        C2_Type* t = gettype(tid);
        if (t->type == C2_TypeStruct) {
          pc(".");
          int nfields = t->data.xstruct.fields.len;
          for (int i = 0; i < nfields; ++i) {
            C2_Type* ft = gettype(
                *list_get(C2_TypeId, &t->data.xstruct.fields, i));
            if (c2_names_eq(ft->data.named.name, name)) {
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
      case C2_Term_LIT_STR: {
        pc("\"");
        pn(term->data.term.data.name);
        pc("\"");
        break;
      }
      default: {
        char buf[256];
        int len;

        switch (term->data.term.type) {
          case C2_Term_LIT_U64:
            len = snprintf(buf, 256, "%lu", term->data.term.data.val_u64);
            break;
          case C2_Term_LIT_I64:
            len = snprintf(buf, 256, "%li", term->data.term.data.val_i64);
            break;
          case C2_Term_LIT_F32:
            len = snprintf(buf, 256, "%f", term->data.term.data.val_f32);
            break;
          case C2_Term_LIT_F64:
            len = snprintf(buf, 256, "%f", term->data.term.data.val_f64);
            break;
          default:
            CHECK(false);
        }

        buf[len] = 0;
        pc(buf);
        break;
      }
    }
  }
}

static void printFnSig(
    C2_Ctx* ctx,
    C2_FnSig* fn,
    C2_GenCtxC* genctx,
    bool with_names,
    bool ptr_form,
    c2_symtab_t* symtab) {
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
      c2_symtab_put(symtab, t->data.named.name, t->data.named.type);
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
    c2_symtab_t* symtab,
    c2_symtab_t* symtab_local,
    list_t* stmts,
    int indent,
    bool addnl) {
  size_t nstmt = stmts->len;
  for (size_t j = 0; j < nstmt; ++j) {
    C2_Stmt* stmt = getstmt(*list_get(C2_StmtId, stmts, j));
    pi(0);
    switch (stmt->type) {
      case C2_Stmt_DECL: {
        c2_symtab_put(symtab_local, stmt->data.decl.name, stmt->data.decl.type);
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
        c2_symtab_put(
            symtab_local, stmt->data.cast.out_name, stmt->data.cast.type);
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
        if (c2_name_isnull(name)) {
          pc("return");
        } else {
          pc("return ");
          pn(stmt->data.xreturn.name);
        }
        break;
      }

      case C2_Stmt_BLOCK: {
        pc("{\n");
        pblock(&stmt->data.block, indent + 2);
        pi(0);
        pc("}\n");
        break;
      }

      case C2_Stmt_LOOP: {
        pc("while (1) {\n");

        if (stmt->data.loop.cond_stmts != C2_StmtId_NULL) {
          pblock(getblock(stmt->data.loop.cond_stmts), indent + 2);
        }

        if (!c2_name_isnull(stmt->data.loop.cond_val)) {
          pi(2);
          pc("if (!");
          pn(stmt->data.loop.cond_val);
          pc(") break;\n");
        }

        if (stmt->data.loop.body_stmts != C2_StmtId_NULL) {
          pblock(getblock(stmt->data.loop.body_stmts), indent + 2);
        }

        if (!c2_name_isnull(stmt->data.loop.continue_val)) {
          pi(2);
          pc("if (!");
          pn(stmt->data.loop.continue_val);
          pc(") break;\n");
        }

        if (stmt->data.loop.continue_stmts != C2_StmtId_NULL) {
          pblock(getblock(stmt->data.loop.continue_stmts), indent + 2);
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
        list_t* ifs = getblock(stmt->data.xif.ifs);
        size_t nifs = ifs->len;
        for (int ifi = 0; ifi < nifs; ++ifi) {
          C2_Stmt* xif = getstmt(*list_get(C2_StmtId, ifs, ifi));
          if (ifi > 0) pc(" else {\n  ");
          if (xif->data.ifblock.cond_stmts != C2_StmtId_NULL) {
            pblock(getblock(xif->data.ifblock.cond_stmts), indent);
            pi(0);
          }
          pc("if (");
          pn(xif->data.ifblock.cond);
          pc(") {\n");
          if (xif->data.ifblock.body_stmts != C2_StmtId_NULL) {
            pblock(getblock(xif->data.ifblock.body_stmts), indent + 2);
          }
          pi(0);
          pc("}");
        }

        if (stmt->data.xif.xelse != C2_StmtId_NULL) {
          list_t* xelse = getblock(stmt->data.xif.xelse);
          if (xelse->len) {
            pc(" else {\n");
            pblock(xelse, indent + 2);
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
          list_t* cases = getblock(stmt->data.xswitch.cases);
          size_t ncases = cases->len;
          for (int k = 0; k < ncases; ++k) {
            pi(2);
            pc("case ");
            C2_Stmt* xcase = getstmt(*list_get(C2_StmtId, cases, k));
            pn(xcase->data.switchcase.val);
            pc(":");
            list_t* stmts = getblock(xcase->data.switchcase.stmts);
            size_t ncasestmts = stmts->len;
            if (ncasestmts) {
              pc("{\n");
              pblock(stmts, indent + 4);
              pi(2);
              pc("}\n");
            } else {
              pc("\n");
            }
          }
        }

        if (stmt->data.xswitch.xdefault != C2_StmtId_NULL) {
          list_t* xdefault = getblock(stmt->data.xswitch.xdefault);
          if (xdefault->len) {
            pi(2);
            pc("default: {\n");
            pblock(xdefault, indent + 4);
            pi(2);
            pc("}\n");
          }
        }

        pi(0);
        pc("}\n");
        break;
      }

      case C2_Stmt_FNCALL: {
        bool has_ret = !c2_name_isnull(stmt->data.fncall.ret);
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
          printTerm(
              ctx,
              getblock(stmt->data.expr.term0),
              genctx,
              symtab,
              symtab_local);
        } else {
          printTerm(
              ctx,
              getblock(stmt->data.expr.term0),
              genctx,
              symtab,
              symtab_local);
          pc(" ");
          pc(op_strs[op]);
          pc(" ");
          printTerm(
              ctx,
              getblock(stmt->data.expr.term1),
              genctx,
              symtab,
              symtab_local);
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
        pc(c2_stmt_strs[stmt->type]);
      }
    }

    if (!addnl ||
        stmt->type == C2_Stmt_LOOP ||
        stmt->type == C2_Stmt_IF ||
        stmt->type == C2_Stmt_SWITCH ||
        stmt->type == C2_Stmt_BLOCK ||
        false) continue;
    pc(";\n");
  }
}

void c2_gen_c(C2_Ctx* ctx, C2_Module* module, C2_GenCtxC* genctx) {
  // Global symbol table
  c2_symtab_t* symtab = c2_symtab_init();

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
          c2_symtab_put(symtab, type->data.named.name, typeid);
          pc("typedef ");
          pt(type->data.named.type);
          pc("* ");
          pn(type->data.named.name);
          pc(";\n");
          break;
        }
        case C2_TypeFnPtr: {
          c2_symtab_put(symtab, type->data.fnsig.name, typeid);
          pc("typedef ");
          printFnSig(ctx, &type->data.fnsig, genctx, false, true, NULL);
          pc(";\n");
          break;
        }
        case C2_TypeArray: {
          c2_symtab_put(symtab, type->data.arr.named.name, typeid);
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
          c2_symtab_put(symtab, type->data.xstruct.name, typeid);
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
            C2_Type* f = gettype(
                *list_get(C2_TypeId, &type->data.xstruct.fields, i));
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
      c2_symtab_put(symtab, *name, C2_TypeIdBase(C2_TypeBytes));
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
      c2_symtab_put(symtab, bss->name, C2_TypeIdBase(C2_TypeBytes));
    }
  }

  {
    // Data
    pc("\n// data\n");
    size_t ndata = module->data.len;
    for (size_t i = 0; i < ndata; ++i) {
      C2_Data* data = list_get(C2_Data, &module->data, i);
      printData(ctx, data, genctx);
      c2_symtab_put(symtab, data->name, C2_TypeIdBase(C2_TypeBytes));
    }
  }

  {
    // Functions
    pc("\n// functions\n");

    // Function-local symbol table
    c2_symtab_t* symtab_local = c2_symtab_init();

    size_t nfns = module->fns.len;
    for (size_t i = 0; i < nfns; ++i) {
      c2_symtab_reset(symtab_local);
      C2_Fn* fn = list_get(C2_Fn, &module->fns, i);
      C2_FnSig* sig = &gettype(fn->sig)->data.fnsig;
      printFnSig(ctx, sig, genctx, true, false, symtab_local);
      pc(" {\n");
      pblock(getblock(fn->stmts), 2);
      pc("}\n\n");
    }

    c2_symtab_deinit(symtab_local);
  }

  c2_symtab_deinit(symtab);
}

KHASH_INIT(mNames, str_t, C2_Name, 1, str_hash, str_eq);
#define namemap_t khash_t(mNames)

static C2_Names c2_names_init() {
  return (C2_Names){
    .buf = list_init(uint8_t, -1),
    .ctx = (void*)kh_init(mNames),
    .tmp = 0,
  };
}

static void c2_names_deinit(C2_Names* names) {
  list_deinit(&names->buf);
  kh_destroy(mNames, (namemap_t*)names->ctx);
}

C2_Name c2_ctx_tmpname(C2_Ctx* ctx) {
  char buf[16];
  int len = snprintf(buf, 8, "tmp%lu", ctx->names.tmp++);
  buf[len] = 0;
  return c2_ctx_namec(ctx, buf);
}

str_t c2_ctx_strname(C2_Ctx* ctx, C2_Name name) {
  return str_init((char*)(&ctx->names.buf.base[name.offset]), name.len);
}

C2_Name c2_ctx_namec(C2_Ctx* ctx, const char* cname) {
  str_t name = cstr(cname);

  C2_Names* names = &ctx->names;
  namemap_t* namemap = (namemap_t*)names->ctx;

  khiter_t iter = kh_get(mNames, namemap, name);
  if (iter != kh_end(namemap)) return kh_val(namemap, iter);

  // If not already in the pool, add it and insert into the map
  // Add 1 to len to store null but don't keep it in the len
  name.len += 1;
  str_t sbuf = str_add(&names->buf, name);
  name.len -= 1;
  ((char*)sbuf.bytes)[sbuf.len - 1] = 0;

  C2_Name val = {
    .offset = list_idx(&names->buf, (void*)sbuf.bytes),
    .len = name.len,
  };
  int ret;
  khiter_t key = kh_put(mNames, namemap, name, &ret);
  kh_val(namemap, key) = val;
  return val;
}

C2_Name c2_ctx_name_suffix(C2_Ctx* ctx, C2_Name base, const char* suffix) {
  size_t suffixlen = strlen(suffix);
  list_t tmp = list_init(uint8_t, base.len + suffixlen + 1);
  str_add(&tmp, c2_ctx_strname(ctx, base));
  str_add(&tmp, cstr(suffix));
  *list_add(uint8_t, &tmp) = 0;

  C2_Name out = c2_ctx_namec(ctx, tmp.base);
  list_deinit(&tmp);
  return out;
}

bool c2_names_eq(C2_Name n0, C2_Name n1) {
  return n0.offset == n1.offset && n0.len == n1.len;
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
  DCHECK(isNamedType(type), "named types cannot be base types");
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
  DCHECK(isNamedType(t->type),
      "C2_TypeIdNamed can only be called on named types");
  return (C2_TypeId){
    .type = t->type,
    .handle = list_get_handle(&ctx->types, t),
  };
}

void c2_ctx_addstructfield(C2_Ctx* ctx,
    C2_TypeId struct_typeid, const char* field_name, C2_TypeId field_type) {
  C2_Type* t = c2_ctx_addtypec(ctx, C2_TypeStructField, field_name);
  C2_Type* struct_type = c2_ctx_gettype(ctx, struct_typeid);
  DCHECK(struct_type->type == C2_TypeStruct);
  list_t* fields = &struct_type->data.xstruct.fields;
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
  DCHECK(block->type == C2_Stmt_BLOCK,
      "blockid %d must reference a block stmt", blockid);
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

C2_Stmt* c2_ctx_addterm(C2_Ctx* ctx, C2_StmtId block, C2_TermType type) {
  C2_Stmt* s = c2_ctx_blockadd(ctx, block, C2_Stmt_TERM);
  s->data.term.type = type;
  return s;
}

C2_StmtId c2_ctx_addexpr(
    C2_Ctx* ctx,
    C2_OpType op,
    C2_StmtId lhs,
    C2_StmtId rhs) {
  C2_Stmt* expr = c2_ctx_addstmt(ctx, NULL, C2_Stmt_EXPR);
  expr->data.expr.type = op;
  expr->data.expr.term0 = lhs;
  expr->data.expr.term1 = rhs;
  return c2_ctx_stmtid(ctx, expr);
}

C2_StmtId c2_ctx_stmtid(C2_Ctx* ctx, C2_Stmt* s) {
  return list_get_handle(&ctx->stmts, s);
}

void c2_ctx_addassign(C2_Ctx* ctx, C2_Fn* fn, C2_StmtId lhs, C2_StmtId rhs) {
  C2_Stmt* s = c2_ctx_addstmt(ctx, fn, C2_Stmt_ASSIGN);
  s->data.assign.lhs = lhs;
  s->data.assign.rhs = rhs;
}

void c2_ctx_addifblock(
    C2_Ctx* ctx,
    C2_StmtId ifs,
    C2_StmtId cond_block,
    C2_Name cond,
    C2_StmtId body_block) {
  C2_Stmt* s = c2_ctx_blockadd(ctx, ifs, C2_Stmt_IFBLOCK);
  s->data.ifblock.cond_stmts = cond_block;
  s->data.ifblock.cond = cond;
  s->data.ifblock.body_stmts = body_block;
}

void c2_ctx_addswitchcase(
    C2_Ctx* ctx,
    C2_StmtId cases,
    C2_Name case_val,
    C2_StmtId case_block) {
  C2_Stmt* s = c2_ctx_blockadd(ctx, cases, C2_Stmt_SWITCHCASE);
  s->data.switchcase.val = case_val;
  s->data.switchcase.stmts = case_block;
}
