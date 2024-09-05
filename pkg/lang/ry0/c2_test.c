#include <stdio.h>

#include "c2.h"
#include "base/log.h"

void write(void* ctx, str_t s) {
#ifdef DEBUG
  fprintf(stderr, "%.*s", (int)s.len, s.bytes);
#endif
  str_append((list_t*)ctx, s);
}

int main(int argc, char** argv) {
  C2_Ctx ctx = c2_ctx_init();
  C2_Module module = c2_module_init(&ctx);

  // tmpname
  {
    C2_Name name = c2_ctx_tmpname(&ctx);
    str_t name_s = c2_ctx_strname(&ctx, name);
    CHECK(name_s.len == 4);
    CHECK(!strncmp(name_s.bytes, "tmp0", 4));
  }

  // Pointer type
  C2_TypeId myptr_t;
  {
    C2_Type* t = c2_ctx_addtypec(&ctx, C2_TypePtr, "myptr");
    t->data.named.type = C2_TypeIdBase(C2_TypeU8);
    myptr_t = C2_TypeIdNamed(&ctx, t);
    C2_Name name = c2_ctx_namec(&ctx, "myptr");
    CHECK(c2_names_eq(t->data.named.name, name));
  }

  // Array type
  {
    C2_Type* t = c2_ctx_addtypec(&ctx, C2_TypeArray, "myarr");
    t->data.arr.named.type = C2_TypeIdBase(C2_TypeU8);
    t->data.arr.len = 10;
  }

  // Array of pointer type
  {
    C2_Type* t = c2_ctx_addtypec(&ctx, C2_TypeArray, "myarr");
    t->data.arr.named.type = myptr_t;
    t->data.arr.len = 10;
  }

  // Struct type
  {
    C2_Type* t = c2_ctx_addtypec(&ctx, C2_TypeStruct, "mystruct");
    C2_TypeId tid = C2_TypeIdNamed(&ctx, t);
    c2_ctx_addstructfield(&ctx, tid, "field0", C2_TypeIdBase(C2_TypeF32));
    c2_ctx_addstructfield(&ctx, tid, "field1", myptr_t);
  }

  // Fn ptr type
  {
    C2_Type* t = c2_ctx_addtypec(&ctx, C2_TypeFnPtr, "myfnptr");
    c2_ctx_addfnarg(&ctx, t, "arg0", C2_TypeIdBase(C2_TypeF32));
  }

  // Extern data
  {
    *list_add(C2_Name, &module.extern_data) =
      c2_ctx_namec(&ctx, "myexterndata");
  }

  // BSS
  {
    C2_Data* d = list_add(C2_Data, &module.bss);
    d->name = c2_ctx_namec(&ctx, "mybss");
    d->len = 128;
  }

  // Data
  const char* somedata = "hello world!";
  {
    C2_Data* d = list_add(C2_Data, &module.data);
    d->name = c2_ctx_namec(&ctx, "mydata");
    d->len = strlen(somedata) + 1;
    d->data = (const uint8_t*)somedata;
    d->export = true;
  }

  // Extern fn
  {
    C2_Type* t = c2_ctx_addtypec(&ctx, C2_TypeFnSig, "myexternfn");
    c2_ctx_addfnarg(&ctx, t, "arg0", C2_TypeIdBase(C2_TypeU16));
    c2_ctx_addfnarg(&ctx, t, "arg1", myptr_t);
    t->data.fnsig.ret = C2_TypeIdBase(C2_TypeU64);
    *list_add(C2_TypeId, &module.extern_fns) = C2_TypeIdNamed(&ctx, t);
  }

  // Statements
  {
    C2_Type* sig_t = c2_ctx_addtypec(&ctx, C2_TypeFnSig, "myfn");
    sig_t->data.fnsig.ret = C2_TypeIdBase(C2_TypeU16);
    c2_ctx_addfnarg(&ctx, sig_t, "arg0", C2_TypeIdBase(C2_TypeF32));
    c2_ctx_addfnarg(&ctx, sig_t, "arg1", myptr_t);

    C2_Fn* fn = c2_module_addfn(&module, C2_TypeIdNamed(&ctx, sig_t));

    // Declaration
    {
      C2_Stmt* s = c2_ctx_addstmt(&ctx, fn, C2_Stmt_DECL);
      s->data.decl.name = c2_ctx_namec(&ctx, "a");
      s->data.decl.type = C2_TypeIdBase(C2_TypeU8);
    }

    // Declaration with user type
    {
      C2_Stmt* s = c2_ctx_addstmt(&ctx, fn, C2_Stmt_DECL);
      s->data.decl.name = c2_ctx_namec(&ctx, "b");
      s->data.decl.type = myptr_t;
    }

    // Label
    {
      C2_Stmt* s = c2_ctx_addstmt(&ctx, fn, C2_Stmt_LABEL);
      s->data.label.name = c2_ctx_namec(&ctx, "mylabel");
    }

    // Cast
    {
      C2_Stmt* s = c2_ctx_addstmt(&ctx, fn, C2_Stmt_CAST);
      s->data.cast.in_name = c2_ctx_namec(&ctx, "a");
      s->data.cast.out_name = c2_ctx_namec(&ctx, "c");
      s->data.cast.type = C2_TypeIdBase(C2_TypeU16);
    }

    // Goto
    {
      C2_Stmt* s = c2_ctx_addstmt(&ctx, fn, C2_Stmt_GOTO);
      s->data.xgoto.label = c2_ctx_namec(&ctx, "mylabel");
    }

    // Control flow
    {
      c2_ctx_addstmt(&ctx, fn, C2_Stmt_CONTINUE);
      c2_ctx_addstmt(&ctx, fn, C2_Stmt_BREAK);
      c2_ctx_addstmt(&ctx, fn, C2_Stmt_RETURN);
    }

    // Return with value
    {
      C2_Stmt* s = c2_ctx_addstmt(&ctx, fn, C2_Stmt_RETURN);
      s->data.xreturn.name = c2_ctx_namec(&ctx, "c");
    }

    // Function call
    {
      C2_Stmt* s = c2_ctx_addstmt(&ctx, fn, C2_Stmt_FNCALL);
      s->data.fncall.name = c2_ctx_namec(&ctx, "myexternfn");
      s->data.fncall.ret = c2_ctx_namec(&ctx, "d");
      *list_add(C2_Name, &s->data.fncall.args) =
        c2_ctx_namec(&ctx, "c");
      *list_add(C2_Name, &s->data.fncall.args) =
        c2_ctx_namec(&ctx, "b");
    }

    // Expressions and assignment
    {
      C2_StmtId lhs_term = c2_ctx_addblock(&ctx);
      {
        C2_Stmt* s = c2_ctx_addterm(&ctx, lhs_term, C2_Term_NAME);
        s->data.term.data.name = c2_ctx_namec(&ctx, "b");
      }

      C2_StmtId rhs_term = c2_ctx_addblock(&ctx);
      {
        C2_Stmt* s = c2_ctx_addterm(&ctx, rhs_term, C2_Term_LIT_U64);
        s->data.term.data.val_u64 = 1;
      }

      C2_StmtId lhs = c2_ctx_addexpr(&ctx, C2_Op_NONE, lhs_term, C2_StmtId_NULL);
      C2_StmtId rhs = c2_ctx_addexpr(&ctx, C2_Op_NOT, rhs_term, C2_StmtId_NULL);
      c2_ctx_addassign(&ctx, fn, lhs, rhs);
    }

    // Block
    {
      C2_StmtId block = c2_ctx_stmtid(&ctx, c2_ctx_addstmt(&ctx, fn, C2_Stmt_BLOCK));
      C2_Stmt* s = c2_ctx_blockadd(&ctx, block, C2_Stmt_DECL);
      s->data.decl.name = c2_ctx_namec(&ctx, "myblockvar");
      s->data.decl.type = C2_TypeIdBase(C2_TypeU8);
    }

    // Loop
    {
      C2_StmtId cond_block = c2_ctx_addblock(&ctx);
      {
        C2_Stmt* s = c2_ctx_blockadd(&ctx, cond_block, C2_Stmt_DECL);
        s->data.decl.name = c2_ctx_namec(&ctx, "mycond");
        s->data.decl.type = C2_TypeIdBase(C2_TypeU8);
      }
      C2_StmtId body_block = c2_ctx_addblock(&ctx);
      {
        C2_Stmt* s = c2_ctx_blockadd(&ctx, body_block, C2_Stmt_DECL);
        s->data.decl.name = c2_ctx_namec(&ctx, "mycont");
        s->data.decl.type = C2_TypeIdBase(C2_TypeU8);
      }
      C2_StmtId continue_block = c2_ctx_addblock(&ctx);
      {
        C2_Stmt* s = c2_ctx_blockadd(&ctx, continue_block, C2_Stmt_DECL);
        s->data.decl.name = c2_ctx_namec(&ctx, "mycont_var");
        s->data.decl.type = C2_TypeIdBase(C2_TypeU8);
      }

      C2_Stmt* loop = c2_ctx_addstmt(&ctx, fn, C2_Stmt_LOOP);
      loop->data.loop.cond_stmts = cond_block;
      loop->data.loop.cond_val = c2_ctx_namec(&ctx, "mycond");
      loop->data.loop.body_stmts = body_block;
      loop->data.loop.continue_val = c2_ctx_namec(&ctx, "mycont");
      loop->data.loop.continue_stmts = continue_block;
    }

    // If else
    {
      C2_StmtId if_blocks = c2_ctx_addblock(&ctx);
      {
        C2_StmtId cond_block = c2_ctx_addblock(&ctx);
        {
          C2_Stmt* s = c2_ctx_blockadd(&ctx, cond_block, C2_Stmt_DECL);
          s->data.decl.name = c2_ctx_namec(&ctx, "myifcond");
          s->data.decl.type = C2_TypeIdBase(C2_TypeU8);
        }
        C2_Name cond_name = c2_ctx_namec(&ctx, "myifcond");
        C2_StmtId body_block = c2_ctx_addblock(&ctx);
        {
          C2_Stmt* s = c2_ctx_blockadd(&ctx, body_block, C2_Stmt_DECL);
          s->data.decl.name = c2_ctx_namec(&ctx, "myifbody");
          s->data.decl.type = C2_TypeIdBase(C2_TypeU8);
        }

        c2_ctx_addifblock(&ctx, if_blocks, cond_block, cond_name, body_block);
        c2_ctx_addifblock(&ctx, if_blocks, cond_block, cond_name, body_block);
      }
      C2_StmtId else_block = c2_ctx_addblock(&ctx);
      {
        C2_Stmt* s = c2_ctx_blockadd(&ctx, else_block, C2_Stmt_DECL);
        s->data.decl.name = c2_ctx_namec(&ctx, "myelse");
        s->data.decl.type = C2_TypeIdBase(C2_TypeU8);
      }

      C2_Stmt* xif = c2_ctx_addstmt(&ctx, fn, C2_Stmt_IF);
      xif->data.xif.ifs = if_blocks;
      xif->data.xif.xelse = else_block;
    }

    // Switch
    {
      C2_StmtId cases = c2_ctx_addblock(&ctx);
      {
        C2_StmtId block = c2_ctx_addblock(&ctx);
        c2_ctx_blockadd(&ctx, block, C2_Stmt_BREAK);
        c2_ctx_addswitchcase(&ctx, cases, c2_ctx_namec(&ctx, "case0"), block);
      }

      C2_StmtId xdefault = c2_ctx_addblock(&ctx);
      {
        C2_Stmt* s = c2_ctx_blockadd(&ctx, xdefault, C2_Stmt_DECL);
        s->data.decl.name = c2_ctx_namec(&ctx, "mydefault");
        s->data.decl.type = C2_TypeIdBase(C2_TypeU8);
      }

      C2_Stmt* xswitch = c2_ctx_addstmt(&ctx, fn, C2_Stmt_SWITCH);
      xswitch->data.xswitch.expr = c2_ctx_namec(&ctx, "myswitch");
      xswitch->data.xswitch.cases = cases;
      xswitch->data.xswitch.xdefault = xdefault;
    }
  }

  // Generate C
  list_t out = list_init(uint8_t, -1);
  C2_GenCtxC genctx = { .write = write, .user_ctx = &out };
  c2_gen_c(&ctx, &module, &genctx);

  // Cleanup
  c2_module_deinit(&module);
  c2_ctx_deinit(&ctx);
  list_deinit(&out);

  // Log some struct sizes
  LOG("sizeof(C2_Stmt) %d", sizeof(C2_Stmt));
  LOG("sizeof(C2_StmtId) %d", sizeof(C2_StmtId));
  LOG("sizeof(C2_TypeId) %d", sizeof(C2_TypeId));
  LOG("sizeof(C2_Name) %d", sizeof(C2_Name));
  LOG("sizeof(str_t) %d", sizeof(str_t));
  LOG("sizeof(list_t) %d", sizeof(list_t));

  {
    C2_Type t;
    LOG("sizeof(C2_Type) %d", sizeof(C2_Type));
    LOG("sizeof(C2_Type.data) %d", sizeof(t.data));
    LOG("sizeof(C2_Type.data.named) %d", sizeof(t.data.named));
    LOG("sizeof(C2_Type.data.arr) %d", sizeof(t.data.arr));
    LOG("sizeof(C2_Type.data.fnsig) %d", sizeof(t.data.fnsig));
    LOG("sizeof(C2_Type.data.xstruct) %d", sizeof(t.data.xstruct));
  }

  return 0;
}
