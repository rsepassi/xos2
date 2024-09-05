#include "c2_mir.h"
#include "c2_internal.h"

#include "base/log.h"

static const MIR_type_t c2_mir_types[C2_TypeFnPtr + 1] = {
  MIR_T_UNDEF,
  MIR_T_UNDEF,
  MIR_T_U8,
  MIR_T_U16,
  MIR_T_U32,
  MIR_T_U64,
  MIR_T_I8,
  MIR_T_I16,
  MIR_T_I32,
  MIR_T_I64,
  MIR_T_F,
  MIR_T_D,
  MIR_T_P,
  MIR_T_UNDEF,
  MIR_T_P,
  MIR_T_P,
  MIR_T_UNDEF,
  MIR_T_UNDEF,
  MIR_T_P,
};

static inline MIR_type_t c2_getmirtype(C2_TypeType t) {
  CHECK(t <= C2_TypePtr, "MIR does not accept type %d", t);
  MIR_type_t out = c2_mir_types[t];
  CHECK(out != MIR_T_UNDEF, "MIR does not accept type %d", t);
  return out;
}

static void genStmts(
    C2_Ctx* ctx,
    MIR_context_t mir,
    list_t* stmts,
    c2_symtab_t* symtab,
    c2_symtab_t* symtab_local) {
  size_t nstmt = stmts->len;
  for (size_t i = 0; i < nstmt; ++i) {
    C2_Stmt* stmt = c2_ctx_getstmt(ctx, *list_get(C2_StmtId, stmts, i));
    switch (stmt->type) {
      case C2_Stmt_CAST: {
        // symtab_local
        // sign/zero extension?
      }
      case C2_Stmt_DECL: {
        // symtab_local
        // If mir type, declare local
        // Else, add to alloca size
      }
      case C2_Stmt_LABEL: {
        // label
      }
      case C2_Stmt_EXPR: {
        // op
      }
      case C2_Stmt_TERM: {
        // immediate, or mem op
      }
      case C2_Stmt_FNCALL: {
        // call
      }
      case C2_Stmt_ASSIGN: {
        // mov
      }
      case C2_Stmt_RETURN: {
        // return
      }
      case C2_Stmt_BREAK: {
        // jmp to current loop end label
      }
      case C2_Stmt_CONTINUE: {
        // jmp to current loop start label
      }
      case C2_Stmt_GOTO: {
        // jmp to label
      }
      case C2_Stmt_IF: {
        // setup each block + else
      }
      case C2_Stmt_SWITCH: {
        // switch instruction
      }
      case C2_Stmt_LOOP: {
        // labels for start end
      }
      case C2_Stmt_IFBLOCK: {
        // if false, jmp to block end
      }
      case C2_Stmt_SWITCHCASE: {
        // case labels
      }
      case C2_Stmt_BLOCK: {
        // block start/end
      }
      default: {
      }
    }
  }
}

static void genFnSig(
    C2_Ctx* ctx,
    MIR_context_t mir,
    C2_FnSig* fn,
    bool proto_only,
    c2_symtab_t* symtab) {
  size_t nargs = fn->args.len;
  CHECK(nargs <= 16, "maximum number of fn arguments is 16");
  MIR_var_t args[16];
  for (size_t i = 0; i < nargs; ++i) {
    C2_TypeId argtid = *list_get(C2_TypeId, &fn->args, i);
    C2_Type* t = c2_ctx_gettype(ctx, argtid);
    if (symtab) c2_symtab_put(symtab, t->data.named.name, t->data.named.type);

    args[i] = (MIR_var_t){
      .type = c2_getmirtype(t->data.named.type.type),
      .name = c2_ctx_strname(ctx, t->data.named.name).bytes,
    };
  }

  bool has_ret = fn->ret.type != C2_TypeVOID;
  MIR_type_t ret_type = c2_getmirtype(fn->ret.type);

  if (proto_only) {
    str_t proto_name = c2_ctx_strname(
        ctx, c2_ctx_name_suffix(ctx, fn->name, "_proto"));
    MIR_new_proto_arr(
        mir, proto_name.bytes, (int)has_ret, &ret_type, nargs, args);
  } else {
    MIR_item_t func = MIR_new_func_arr(
        mir, c2_ctx_strname(ctx, fn->name).bytes, (int)has_ret, &ret_type,
        nargs, args);
  }
}

void c2_gen_mir(C2_Ctx* ctx, C2_Module* module, C2_GenCtxMir* genctx) {
  MIR_context_t mir = genctx->mir;
  MIR_module_t mod = MIR_new_module(mir, genctx->module_name);

  // Global symbol table
  c2_symtab_t* symtab = c2_symtab_init();

  {
    // Named types
    size_t ntypes = ctx->types.len;
    for (size_t i = 0; i < ntypes; ++i) {
      C2_Type* type = list_get(C2_Type, &ctx->types, i);
      C2_TypeId typeid = C2_TypeIdNamed(ctx, type);
      switch (type->type) {
        case C2_TypePtr: {
          c2_symtab_put(symtab, type->data.named.name, typeid);
          break;
        }
        case C2_TypeFnPtr: {
          c2_symtab_put(symtab, type->data.fnsig.name, typeid);
          break;
        }
        case C2_TypeArray: {
          c2_symtab_put(symtab, type->data.arr.named.name, typeid);
          break;
        }
        case C2_TypeStruct: {
          c2_symtab_put(symtab, type->data.xstruct.name, typeid);
          break;
        }
        default: {}
      }
    }
  }

  {
    // Extern data
    size_t ndata = module->extern_data.len;
    for (size_t i = 0; i < ndata; ++i) {
      C2_Name* name = list_get(C2_Name, &module->extern_data, i);
      c2_symtab_put(symtab, *name, C2_TypeIdBase(C2_TypeBytes));

      str_t name_s = c2_ctx_strname(ctx, *name);
      MIR_new_import(mir, name_s.bytes);
    }
  }

  {
    // Extern fns
    size_t nfns = module->extern_fns.len;
    for (size_t i = 0; i < nfns; ++i) {
      C2_Type* fn_t = c2_ctx_gettype(
          ctx, *list_get(C2_TypeId, &module->extern_fns, i));
      C2_FnSig* fn = &fn_t->data.fnsig;

      str_t name_s = c2_ctx_strname(ctx, fn->name);
      MIR_new_import(mir, name_s.bytes);

      genFnSig(ctx, mir, fn, true, NULL);
    }
  }

  {
    // BSS
    size_t nbss = module->bss.len;
    for (size_t i = 0; i < nbss; ++i) {
      C2_Data* bss = list_get(C2_Data, &module->bss, i);
      c2_symtab_put(symtab, bss->name, C2_TypeIdBase(C2_TypeBytes));
      str_t name_s = c2_ctx_strname(ctx, bss->name);
      MIR_new_bss(mir, name_s.bytes, bss->len);
      if (bss->export) {
        MIR_new_export(mir, name_s.bytes);
      }
    }
  }

  {
    // Data
    size_t ndata = module->data.len;
    for (size_t i = 0; i < ndata; ++i) {
      C2_Data* data = list_get(C2_Data, &module->data, i);
      c2_symtab_put(symtab, data->name, C2_TypeIdBase(C2_TypeBytes));
      str_t name_s = c2_ctx_strname(ctx, data->name);
      MIR_new_data(mir, name_s.bytes, MIR_T_U8, data->len, data->data);
      if (data->export) {
        MIR_new_export(mir, name_s.bytes);
      }
    }
  }

  {
    // Functions

    // Function-local symbol table
    c2_symtab_t* symtab_local = c2_symtab_init();

    size_t nfns = module->fns.len;
    for (size_t i = 0; i < nfns; ++i) {
      c2_symtab_reset(symtab_local);
      C2_Fn* fn = list_get(C2_Fn, &module->fns, i);
      C2_FnSig* sig = &c2_ctx_gettype(ctx, fn->sig)->data.fnsig;
      genFnSig(ctx, mir, sig, false, symtab_local);
      list_t stmts = c2_ctx_getstmt(ctx, fn->stmts)->data.block;
      genStmts(ctx, mir, &stmts, symtab, symtab_local);
      MIR_finish_func(mir);
      if (sig->quals & C2_FnQual_EXPORT) {
        MIR_new_export(mir, c2_ctx_strname(ctx, sig->name).bytes);
      }
    }

    c2_symtab_deinit(symtab_local);
  }


  c2_symtab_deinit(symtab);
  MIR_finish_module(mir);
}
