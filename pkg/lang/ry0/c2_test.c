#include "c2.h"

#include "base/str.h"

#define tmpreset() do { tmpid = 25; } while(0)
#define getname(idx) ((C2_Name){ \
  .tag = true, \
  .val = { .str = { .offset = (idx), .len = 1, }}})

void write(void* ctx, const char* s, int64_t len) {
  fprintf(stdout, "%.*s", len, s);
  str_append(ctx, s, len);
}

int main(int argc, char** argv) {
  list_t out = list_init(uint8_t, -1);

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
  {
    C2_Type* t = list_add(C2_Type, &types);
    t->type = C2_TypeStruct;
    t->data.xstruct.name = getname(nameid++);
    t->data.xstruct.fields = list_init(C2_Type, -1);
    list_t* fields = &t->data.xstruct.fields;
    tmpreset();
    {
      C2_Type* f = list_add(C2_Type, fields);
      f->data.named.name = getname(tmpid--);
      f->data.named.type = C2_TypeNamedOffset + 1;
    }
    {
      C2_Type* f = list_add(C2_Type, fields);
      f->data.named.name = getname(tmpid--);
      f->data.named.type = C2_TypeI32;
    }
  }

  // Fn ptr
  {
    C2_Type* t = list_add(C2_Type, &types);
    t->type = C2_TypeFnPtr;
    C2_FnSig* fn = &t->data.fnptr;
    fn->name = getname(nameid++);
    fn->ret = C2_TypeNamedOffset + 2;

    fn->args = list_init(C2_Type, -1);
    {
      C2_Type* t = list_add(C2_Type, &fn->args);
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
    d->data = somedata;
    d->export = true;
  }

  // Extern fns
  list_t extern_fns = list_init(C2_FnSig, -1);
  {
    C2_FnSig* fn = list_add(C2_FnSig, &extern_fns);
    fn->name = getname(nameid++);
    fn->ret = C2_TypeNamedOffset + 2;

    fn->args = list_init(C2_Type, -1);
    {
      C2_Type* t = list_add(C2_Type, &fn->args);
      t->type = C2_TypeFnArg;
      t->data.named.type = C2_TypeU8;
    }
    {
      C2_Type* t = list_add(C2_Type, &fn->args);
      t->type = C2_TypeFnArg;
      t->data.named.type = C2_TypeI8;
    }
  }

  list_t stmts = list_init(C2_Stmt, -1);

  list_t fns = list_init(C2_Fn, -1);
  {
    tmpreset();
    C2_Fn* fn = list_add(C2_Fn, &fns);

    C2_FnSig* sig = &fn->sig;
    sig->name = getname(nameid++);
    sig->ret = C2_TypeNamedOffset + 2;
    sig->args = list_init(C2_Type, -1);
    {
      C2_Type* t = list_add(C2_Type, &sig->args);
      t->type = C2_TypeFnArg;
      t->data.named.type = C2_TypeU8;
      t->data.named.name = getname(tmpid--);
    }
    {
      C2_Type* t = list_add(C2_Type, &sig->args);
      t->type = C2_TypeFnArg;
      t->data.named.type = C2_TypeI8;
      t->data.named.name = getname(tmpid--);
    }

    fn->stmts = list_init(C2_StmtId, -1);
    {
      tmpreset();
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
  C2_GenCtxC genctx = {
    .write = write,
    .ctx = &out,
  };

  CHECK_OK(c2_gen_c(&ctx, &module, &genctx));

  // Cleanup all list_inits
  // including within each struct def
  // including within each fn args
  // including within each fn stmts

  return 0;
}
