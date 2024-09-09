#include "c2_mir.h"
#include "c2_internal.h"

#include "base/log.h"

typedef enum {
  M_INVALID,
  M_REG,
} mirstate_type;

typedef struct {
  mirstate_type type;
  union {
    MIR_reg_t reg;
  } data;
} mirstate;

KHASH_MAP_INIT_INT(mc2mirtab, mirstate);
#define c2_mirtab_t khash_t(mc2mirtab)
void mirtab_put(c2_mirtab_t* t, C2_Name name, mirstate val) {
  int32_t k = *(int32_t*)(&name);
  int ret;
  khiter_t key = kh_put(mc2mirtab, t, k, &ret);
  kh_val(t, key) = val;
}

mirstate* mirtab_get(c2_mirtab_t* t, C2_Name name) {
  int32_t k = *(int32_t*)(&name);
  khiter_t iter = kh_get(mc2mirtab, t, k);
  if (iter == kh_end(t)) return NULL;
  return &kh_val(t, iter);
}

mirstate* mirtab_get2(c2_mirtab_t* global, c2_mirtab_t* local, C2_Name name) {
  mirstate* out = mirtab_get(local, name);
  if (out) return out;
  return mirtab_get(global, name);
}

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

static void dothing(MIR_context_t mir, MIR_item_t func, MIR_reg_t reg) {
  LOG("hi");
        MIR_op_t reg_op = MIR_new_reg_op(mir, reg);
        MIR_op_t zero = MIR_new_int_op(mir, 0);
        MIR_insn_t insn = MIR_new_insn(mir, MIR_MOV, reg_op, zero);
        MIR_append_insn(mir, func, insn);
};

static inline void zeroinit_reg(MIR_context_t mir, MIR_item_t func, MIR_reg_t reg) {
  MIR_append_insn(mir, func, MIR_new_insn(mir,
        MIR_MOV, MIR_new_reg_op(mir, reg), MIR_new_int_op(mir, 0)));
  return;
  // MIR_type_t t = MIR_reg_type(mir, reg, MIR_get_item_func(mir, func));

  // MIR_op_t zero;
  // if (MIR_int_type_p(t)) {
  //    zero = MIR_new_int_op(mir, 0);
  // } else {
  //   switch (t) {
  //     case MIR_T_F:
  //       zero = MIR_new_float_op(mir, 0);
  //     case MIR_T_D:
  //       zero = MIR_new_double_op(mir, 0);
  //     default: CHECK(false);
  //   }
  // }

  // MIR_append_insn(mir, func, MIR_new_insn(mir,
  //       MIR_MOV, MIR_new_reg_op(mir, reg), zero));
}

static inline MIR_type_t getregtype(MIR_type_t t) {
  if (MIR_int_type_p(t)) return MIR_T_I64;
  return t;
}

static inline bool ismirtype(C2_TypeType t) {
  if (t > C2_TypeFnPtr) return false;
  if (c2_mir_types[t] == MIR_T_UNDEF) return false;
  return true;
}

static inline MIR_type_t c2_getmirtype(C2_TypeType t) {
  DCHECK(ismirtype(t), "MIR does not accept type %s", c2_type_strs[t]);
  return c2_mir_types[t];
}

static void genStmts(
    C2_Ctx* ctx,
    MIR_context_t mir,
    MIR_item_t func,
    list_t* stmts,
    c2_symtab_t* symtab,
    c2_symtab_t* symtab_local,
    c2_mirtab_t* mirtab,
    c2_mirtab_t* mirtab_local) {
  size_t nstmt = stmts->len;
  for (size_t i = 0; i < nstmt; ++i) {
    C2_Stmt* stmt = c2_ctx_getstmt(ctx, *list_get(C2_StmtId, stmts, i));
    DLOG("%s", c2_stmt_strs[stmt->type]);
    switch (stmt->type) {
      case C2_Stmt_CAST: {
        c2_symtab_put(
            symtab_local, stmt->data.cast.out_name, stmt->data.cast.type);
        break;
      }
      case C2_Stmt_DECL: {
        C2_Name name = stmt->data.decl.name;
        C2_TypeId type = stmt->data.decl.type;
        c2_symtab_put(symtab_local, name, type);
        str_t name_s = c2_ctx_strname(ctx, stmt->data.decl.name);

        MIR_reg_t reg;
        MIR_type_t reg_type;
        if (ismirtype(type.type)) {
          // If mir type, declare local
          MIR_type_t t = c2_getmirtype(stmt->data.decl.type.type);
          reg_type = getregtype(t);
          reg = MIR_new_func_reg(
            mir, MIR_get_item_func(mir, func), reg_type, name_s.bytes);
        } else {
          // Else, stored in alloca
          // How much to add to alloca and where to place it in alloca
          //   Type size, type alignment
          // And then a local pointer to it
          reg_type = MIR_T_I64;
          reg = MIR_new_func_reg(
            mir, MIR_get_item_func(mir, func), MIR_T_I64, name_s.bytes);
        }

        // Zero the register
        MIR_op_t reg_op = MIR_new_reg_op(mir, reg);
        MIR_op_t zero;
        if (MIR_int_type_p(reg_type)) {
           zero = MIR_new_int_op(mir, 0);
        } else {
          switch (reg_type) {
            case MIR_T_F:
              zero = MIR_new_float_op(mir, 0);
            case MIR_T_D:
              zero = MIR_new_double_op(mir, 0);
            default: CHECK(false);
          }
        }
        MIR_new_int_op(mir, 0);
        MIR_insn_t insn = MIR_new_insn(mir, MIR_MOV, reg_op, zero);
        MIR_append_insn(mir, func, insn);

        mirstate state;
        state.type = M_REG;
        state.data.reg = reg;
        mirtab_put(mirtab_local, name, state);
        break;
      }
      case C2_Stmt_RETURN: {
        C2_Name name = stmt->data.xreturn.name;
        MIR_insn_t ret;
        if (c2_name_isnull(name)) {
          ret = MIR_new_ret_insn(mir, 0);
        } else {
          mirstate* state = mirtab_get2(mirtab, mirtab_local, name);
          DCHECK(state);
          DCHECK(state->type == M_REG);

          MIR_op_t op = MIR_new_reg_op(mir, state->data.reg);
          ret = MIR_new_ret_insn(mir, 1, &op);
        }
        MIR_append_insn(mir, func, ret);
        break;
      }
      case C2_Stmt_FNCALL: {
        C2_Name fn_name = stmt->data.fncall.name;
        C2_Name ret_name = stmt->data.fncall.ret;
        list_t* args = &stmt->data.fncall.args;
        bool has_ret = !c2_name_isnull(ret_name);

        // prototype ref + func + return + args
        int nops = 2 + (int)has_ret + args->len;
        MIR_op_t* ops = alloca(sizeof(MIR_op_t) * nops);

        mirstate* fnm = mirtab_get2(mirtab, mirtab_local, fn_name);
        mirstate* retm;
        if (!c2_name_isnull(ret_name)) {
          retm = mirtab_get2(mirtab, mirtab_local, ret_name);
          DCHECK(retm);
          DCHECK(retm->type == M_REG);
          ops[2] = MIR_new_reg_op(mir, retm->data.reg);
        }

        for (int i = 0; i < args->len; ++i) {
          C2_Name arg_name = *list_get(C2_Name, args, i);
          retm = mirtab_get2(mirtab, mirtab_local, arg_name);
          DCHECK(retm);
          DCHECK(retm->type == M_REG);
        }

        MIR_insn_t call = MIR_new_insn_arr(mir, MIR_CALL, nops, ops);
        MIR_append_insn(mir, func, call);
      }
      case C2_Stmt_EXPR: {
        // op
      }
      case C2_Stmt_TERM: {
        // immediate, or mem op
      }
      case C2_Stmt_ASSIGN: {
        // mov
      }
      case C2_Stmt_BLOCK: {
        // block start/end
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
      case C2_Stmt_BREAK: {
        // jmp to current loop end label
      }
      case C2_Stmt_CONTINUE: {
        // jmp to current loop start label
      }
      case C2_Stmt_IFBLOCK: {
        // if false, jmp to block end
      }
      case C2_Stmt_SWITCHCASE: {
        // case labels
      }
      default: {
      }
    }
  }
}

static MIR_item_t genFnSig(
    C2_Ctx* ctx,
    MIR_context_t mir,
    C2_FnSig* fn,
    c2_symtab_t* symtab,
    bool proto_only) {
  str_t fn_name = c2_ctx_strname(ctx, fn->name);
  DLOG("genFnSig %.*s", fn_name.len, fn_name.bytes);
  size_t nargs = fn->args.len;
  MIR_var_t* args = alloca(sizeof(MIR_var_t) * nargs);
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
  MIR_type_t ret_type = has_ret ? c2_getmirtype(fn->ret.type) : 0;

  if (proto_only) {
    str_t proto_name = c2_ctx_strname(
        ctx, c2_ctx_name_suffix(ctx, fn->name, "_proto"));
    return MIR_new_proto_arr(
        mir, proto_name.bytes, (int)has_ret, &ret_type, nargs, args);
  } else {
    return MIR_new_func_arr(
        mir, fn_name.bytes, (int)has_ret, &ret_type, nargs, args);
  }
}

void c2_gen_mir(C2_Ctx* ctx, C2_Module* module, C2_GenCtxMir* genctx) {
  MIR_context_t mir = genctx->mir;
  MIR_module_t mod = MIR_new_module(mir, genctx->module_name);

  // Global symbol table
  c2_symtab_t* symtab = c2_symtab_init();
  c2_mirtab_t* mirtab = kh_init(mc2mirtab);

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

      MIR_item_t proto = genFnSig(ctx, mir, fn, NULL, true);
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
    c2_mirtab_t* mirtab_local = kh_init(mc2mirtab);

    size_t nfns = module->fns.len;
    for (size_t i = 0; i < nfns; ++i) {
      c2_symtab_reset(symtab_local);
      C2_Fn* fn = list_get(C2_Fn, &module->fns, i);
      C2_FnSig* sig = &c2_ctx_gettype(ctx, fn->sig)->data.fnsig;
      MIR_item_t func = genFnSig(ctx, mir, sig, symtab_local, false);
      list_t stmts = c2_ctx_getstmt(ctx, fn->stmts)->data.block;
      genStmts(ctx, mir, func, &stmts, symtab, symtab_local, mirtab, mirtab_local);
      MIR_finish_func(mir);
      DLOG("func done");
      if (sig->quals & C2_FnQual_EXPORT) {
        MIR_new_export(mir, c2_ctx_strname(ctx, sig->name).bytes);
      }
    }

    kh_destroy(mc2mirtab, mirtab_local);
    c2_symtab_deinit(symtab_local);
  }

  kh_destroy(mc2mirtab, mirtab);
  c2_symtab_deinit(symtab);
  MIR_finish_module(mir);
}
