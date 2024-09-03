#include "c2.h"

#include "base/str.h"

#define tmpreset() do { tmpid = 25; } while(0)
#define getname(idx) ((C2_Name){ .offset = (idx), .len = 1, })

void write(void* ctx, const char* s, int64_t len) {
  fprintf(stdout, "%.*s", (int)len, s);
  str_append(ctx, s, len);
}

int main(int argc, char** argv) {
  C2_NameBuf names = "abcdefghijklmnopqrstuvwxyz";
  size_t nameid = 0;
  size_t tmpid = 25;

  list_t types = list_init(C2_Type, -1);

  // Pointer
  {
    C2_Type* t = list_add(C2_Type, &types);
    t->type = C2_TypePtr;
    t->data.named.name = getname(nameid++);
    t->data.named.type = C2_TypeU8;
  }

  // Array
  {
    C2_Type* t = list_add(C2_Type, &types);
    t->type = C2_TypeArray;
    t->data.arr.named.name = getname(nameid++);
    t->data.arr.named.type = C2_TypeU8;
    t->data.arr.len = 10;
  }

  // Struct
  C2_TypeId struct_id = 0;
  {
    C2_Type* t = list_add(C2_Type, &types);
    t->type = C2_TypeStruct;
    t->data.xstruct.name = getname(nameid++);
    struct_id = C2_TypeNamedOffset + list_get_handle(&types, t);
    t->data.xstruct.fields = list_init(C2_TypeId, -1);
    list_t* fields = &t->data.xstruct.fields;
    tmpreset();
    {
      C2_Type* f = list_add(C2_Type, &types);
      *list_add(C2_TypeId, fields) = C2_TypeNamedOffset + list_get_handle(&types, f);
      f->type = C2_TypeStructField;

      f->data.named.name = getname(tmpid--);
      f->data.named.type = C2_TypeNamedOffset + 1;
    }
    {
      C2_Type* f = list_add(C2_Type, &types);
      *list_add(C2_TypeId, fields) = C2_TypeNamedOffset + list_get_handle(&types, f);
      f->data.named.name = getname(tmpid--);
      f->data.named.type = C2_TypeI32;
    }
  }

  // Fn ptr
  {
    C2_Type* t = list_add(C2_Type, &types);
    t->type = C2_TypeFnSig;
    C2_FnSig* fn = &t->data.fnsig;
    fn->name = getname(nameid++);
    fn->ret = C2_TypeNamedOffset + 2;

    fn->args = list_init(C2_TypeId, -1);
    {
      C2_Type* t = list_add(C2_Type, &types);
      *list_add(C2_TypeId, &fn->args) = C2_TypeNamedOffset + list_get_handle(&types, t);
      t->type = C2_TypeFnArg;
      t->data.named.type = C2_TypeU8;
    }
  }

  // Extern data
  list_t extern_data = list_init(C2_ExternData, -1);
  {
    C2_ExternData* d = list_add(C2_ExternData, &extern_data);
    *d = getname(nameid++);
  }

  // BSS
  list_t bss = list_init(C2_Data, -1);
  {
    C2_Data* d = list_add(C2_Data, &bss);
    d->name = getname(nameid++);
    d->len = 128;
  }

  // Data
  const char* somedata = "hello world!";
  list_t data = list_init(C2_Data, -1);
  {
    C2_Data* d = list_add(C2_Data, &data);
    d->name = getname(nameid++);
    d->len = strlen(somedata) + 1;
    d->data = (const uint8_t*)somedata;
    d->export = true;
  }

  // Extern fns
  list_t extern_fns = list_init(C2_TypeId, -1);
  {
    C2_Type* fn_t = list_add(C2_Type, &types);
    *list_add(C2_TypeId, &extern_fns) = C2_TypeNamedOffset + list_get_handle(&types, fn_t);
    fn_t->type = C2_TypeFnSig;
    C2_FnSig* fn = &fn_t->data.fnsig;

    fn->name = getname(nameid++);
    fn->ret = C2_TypeNamedOffset + 2;

    fn->args = list_init(C2_TypeId, -1);
    {
      C2_Type* t = list_add(C2_Type, &types);
      *list_add(C2_TypeId, &fn->args) = C2_TypeNamedOffset + list_get_handle(&types, t);
      t->type = C2_TypeFnArg;
      t->data.named.type = C2_TypeU8;
    }
    {
      C2_Type* t = list_add(C2_Type, &types);
      *list_add(C2_TypeId, &fn->args) = C2_TypeNamedOffset + list_get_handle(&types, t);
      t->type = C2_TypeFnArg;
      t->data.named.type = C2_TypeI8;
    }
  }

  list_t stmts = list_init(C2_Stmt, -1);

  list_t fns = list_init(C2_Fn, -1);
  {
    tmpreset();
    C2_Fn* fn = list_add(C2_Fn, &fns);

    C2_Type* sig_t = list_add(C2_Type, &types);
    fn->sig = C2_TypeNamedOffset + list_get_handle(&types, sig_t);
    sig_t->type = C2_TypeFnSig;

    C2_FnSig* sig = &sig_t->data.fnsig;
    sig->name = getname(nameid++);
    sig->ret = C2_TypeNamedOffset + 2;
    sig->args = list_init(C2_TypeId, -1);
    {
      C2_Type* t = list_add(C2_Type, &types);
      *list_add(C2_TypeId, &sig->args) = C2_TypeNamedOffset + list_get_handle(&types, t);
      t->type = C2_TypeFnArg;
      t->data.named.type = C2_TypeI8;
      t->data.named.name = getname(tmpid--);
    }
    {
      C2_Type* t = list_add(C2_Type, &types);
      *list_add(C2_TypeId, &sig->args) = C2_TypeNamedOffset + list_get_handle(&types, t);
      t->type = C2_TypeFnArg;
      t->data.named.type = C2_TypeI8;
      t->data.named.name = getname(tmpid--);
    }

    fn->stmts = list_init(C2_StmtId, -1);
    {
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_DECL;
        stmt->data.decl.name = getname(tmpid--);
        stmt->data.decl.type = C2_TypeU8;
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_DECL;
        stmt->data.decl.name = getname(tmpid--);
        stmt->data.decl.type = struct_id;
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_LABEL;
        stmt->data.label.name = getname(tmpid--);
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_CAST;
        stmt->data.cast.in_name = getname(25);
        stmt->data.cast.out_name = getname(tmpid--);
        stmt->data.cast.type = C2_TypeI8;
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_GOTO;
        stmt->data.xgoto.label = getname(22);
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_CONTINUE;
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_BREAK;
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_LOOP;
        stmt->data.loop.cond_val = getname(tmpid--);
        stmt->data.loop.continue_val = getname(tmpid--);
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_IF;
        stmt->data.xif.ifs = list_init(C2_StmtId, -1);
        stmt->data.xif.xelse = list_init(C2_StmtId, -1);

        {
          C2_Stmt* if0 = list_add(C2_Stmt, &stmts);
          if0->type = C2_Stmt_IFBLOCK;
          if0->data.ifblock.cond = getname(tmpid--);
          *list_add(C2_StmtId, &stmt->data.xif.ifs) = list_get_handle(&stmts, if0);
        }
        {
          C2_Stmt* if0 = list_add(C2_Stmt, &stmts);
          if0->type = C2_Stmt_IFBLOCK;
          if0->data.ifblock.cond = getname(tmpid--);
          *list_add(C2_StmtId, &stmt->data.xif.ifs) = list_get_handle(&stmts, if0);
        }
        {
          C2_Stmt* if0 = list_add(C2_Stmt, &stmts);
          if0->type = C2_Stmt_IFBLOCK;
          if0->data.ifblock.cond = getname(tmpid--);
          *list_add(C2_StmtId, &stmt->data.xif.ifs) = list_get_handle(&stmts, if0);
        }
        {
          C2_Stmt* else0 = list_add(C2_Stmt, &stmts);
          *list_add(C2_StmtId, &stmt->data.xif.xelse) = list_get_handle(&stmts, else0);
        }
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_SWITCH;
        stmt->data.xswitch.expr = getname(tmpid--);
        stmt->data.xswitch.cases = list_init(C2_StmtId, -1);
        stmt->data.xswitch.xdefault = list_init(C2_StmtId, -1);

        {
          C2_Stmt* c0 = list_add(C2_Stmt, &stmts);
          c0->type = C2_Stmt_SWITCHCASE;
          c0->data.switchcase.val = getname(tmpid--);
          *list_add(C2_StmtId, &stmt->data.xswitch.cases) = list_get_handle(&stmts, c0);
        }
        {
          C2_Stmt* c0 = list_add(C2_Stmt, &stmts);
          c0->type = C2_Stmt_SWITCHCASE;
          c0->data.switchcase.val = getname(tmpid--);
          *list_add(C2_StmtId, &stmt->data.xswitch.cases) = list_get_handle(&stmts, c0);
        }
        {
          C2_Stmt* def0 = list_add(C2_Stmt, &stmts);
          *list_add(C2_StmtId, &stmt->data.xswitch.xdefault) = list_get_handle(&stmts, def0);
        }
      }
      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_FNCALL;
        stmt->data.fncall.name = getname(tmpid--);
        stmt->data.fncall.ret = getname(tmpid--);
        stmt->data.fncall.args = list_init(C2_Name, 2);
        {
          C2_Name* arg = list_add(C2_Name, &stmt->data.fncall.args);
          *arg = getname(tmpid--);
        }
        {
          C2_Name* arg = list_add(C2_Name, &stmt->data.fncall.args);
          *arg = getname(tmpid--);
        }
      }

      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_EXPR;
        stmt->data.expr.type = C2_Op_ADDR;
        stmt->data.expr.term0 = list_init(C2_StmtId, 1);
        {
          C2_Stmt* ts = list_add(C2_Stmt, &stmts);
          *list_add(C2_StmtId, &stmt->data.expr.term0) = list_get_handle(&stmts, ts);
          ts->type = C2_Stmt_TERM;
          ts->data.term.type = C2_Term_NAME;
          ts->data.term.name = getname(tmpid--);
        }
      }

      {
        C2_StmtId lhs = 0;
        C2_StmtId rhs = 0;
        {
          C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
          lhs = list_get_handle(&stmts, stmt);
          stmt->type = C2_Stmt_EXPR;
          stmt->data.expr.type = C2_Op_NONE;
          stmt->data.expr.term0 = list_init(C2_StmtId, 2);
          {
            C2_Stmt* ts = list_add(C2_Stmt, &stmts);
            *list_add(C2_StmtId, &stmt->data.expr.term0) = list_get_handle(&stmts, ts);
            ts->type = C2_Stmt_TERM;
            ts->data.term.type = C2_Term_NAME;
            ts->data.term.name = getname(tmpid--);
          }
          {
            C2_Stmt* ts = list_add(C2_Stmt, &stmts);
            *list_add(C2_StmtId, &stmt->data.expr.term0) = list_get_handle(&stmts, ts);
            ts->type = C2_Stmt_TERM;
            ts->data.term.type = C2_Term_DEREF;
          }
        }
        {
          C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
          rhs = list_get_handle(&stmts, stmt);
          stmt->type = C2_Stmt_EXPR;
          stmt->data.expr.type = C2_Op_NEGATE;
          stmt->data.expr.term0 = list_init(C2_StmtId, 1);
          {
            C2_Stmt* ts = list_add(C2_Stmt, &stmts);
            *list_add(C2_StmtId, &stmt->data.expr.term0) = list_get_handle(&stmts, ts);
            ts->type = C2_Stmt_TERM;
            ts->data.term.type = C2_Term_NAME;
            ts->data.term.name = getname(tmpid--);
          }
        }
        {
          C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
          *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
          stmt->type = C2_Stmt_ASSIGN;
          stmt->data.assign.lhs = lhs;
          stmt->data.assign.rhs = rhs;
        }
      }


      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_EXPR;
        stmt->data.expr.type = C2_Op_MOD;
        stmt->data.expr.term0 = list_init(C2_StmtId, 3);
        stmt->data.expr.term1 = list_init(C2_StmtId, 1);

        {
          list_t* terms = &stmt->data.expr.term0;

          {
            C2_Stmt* ts = list_add(C2_Stmt, &stmts);
            *list_add(C2_StmtId, terms) = list_get_handle(&stmts, ts);
            ts->type = C2_Stmt_TERM;
            ts->data.term.type = C2_Term_NAME;
            ts->data.term.name = getname(tmpid--);
          }
          {
            C2_Stmt* ts = list_add(C2_Stmt, &stmts);
            *list_add(C2_StmtId, terms) = list_get_handle(&stmts, ts);
            ts->type = C2_Stmt_TERM;
            ts->data.term.type = C2_Term_DEREF;
          }
          {
            C2_Stmt* ts = list_add(C2_Stmt, &stmts);
            *list_add(C2_StmtId, terms) = list_get_handle(&stmts, ts);
            ts->type = C2_Stmt_TERM;
            ts->data.term.type = C2_Term_ARRAY;
            ts->data.term.name = getname(tmpid--);
          }
        }
        {
          list_t* terms = &stmt->data.expr.term1;

          C2_Stmt* ts = list_add(C2_Stmt, &stmts);
          *list_add(C2_StmtId, terms) = list_get_handle(&stmts, ts);
          ts->type = C2_Stmt_TERM;
          ts->data.term.type = C2_Term_NAME;
          ts->data.term.name = getname(tmpid--);
        }
      }

      {
        C2_Stmt* stmt = list_add(C2_Stmt, &stmts);
        *list_add(C2_StmtId, &fn->stmts) = list_get_handle(&stmts, stmt);
        stmt->type = C2_Stmt_RETURN;
        stmt->data.xreturn.name = getname(tmpid--);
      }
    }
  }

  C2_Ctx ctx = {
    .names = names,
    .types = types,
    .stmts = stmts,
  };
  C2_Module module = {
    .extern_fns = extern_fns,
    .extern_data = extern_data,
    .data = data,
    .bss = bss,
    .fns = fns,
  };
  list_t out = list_init(uint8_t, -1);
  C2_GenCtxC genctx = {
    .write = write,
    .ctx = &out,
  };

  CHECK_OK(c2_gen_c(&ctx, &module, &genctx));

  // Cleanup all list_inits

  return 0;
}