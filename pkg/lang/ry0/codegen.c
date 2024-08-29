#include "codegen.h"

// https://github.com/vnmakarov/mir/blob/master/MIR.md
// function variable: MIR_new_func_reg(mir, main, MIR_T_I64, "foo")

// insn operands
// I64, U64, F, D
// label (from MIR_new_label)
// ref
// arg/var (from MIR_reg or MIR_new_func_reg)
// mem (base + displacement + (index * scale)) scale={1, 2, 4, 8}

// insn: MIR_new_insn
// return reg/mem typically first arg
// for call: MIR_new_call_insn
// for ret: MIR_new_ret_insn
// add to func: MIR_append_insn

// new_data
// new_bss
// new_export


static MIR_item_t main_func_init(MIR_context_t mir) {
  MIR_type_t main_result_t = MIR_T_U8;
  MIR_var_t main_args_t[2] = {
  ((MIR_var_t){
    .type = MIR_T_I64,
    .name = "argc",
  }),
  ((MIR_var_t){
    .type = MIR_T_P,
    .name = "argv",
  })
  };

  MIR_item_t func = MIR_new_func_arr(
      mir, "main", 1, &main_result_t, 2, main_args_t);

  return func;
}

Status codegen(CodegenCtx* ctx, NodeHandle root_handle) {
  MIR_context_t mir = ctx->mir;
  Node* root = node_get(ctx->node_ctx, root_handle);
  if (root == NULL) return ERR;

  // Main module
  MIR_module_t mod = MIR_new_module(mir, "modulemain");

  // Imports
  MIR_item_t print_stdout = MIR_new_import(mir, "print_stdout");
  MIR_item_t print_stderr = MIR_new_import(mir, "print_stderr");
  MIR_var_t print_args_t = (MIR_var_t){.type = MIR_T_P, .name = "s"};
  MIR_item_t print_proto = MIR_new_proto_arr(
      mir, "print_p", 0, NULL, 1, &print_args_t);

  // Data
  const char* hello = "hello world!\n";
  MIR_item_t data = MIR_new_data(mir, "hello", MIR_T_U8, strlen(hello) + 1, hello);

  // Main
  MIR_item_t main = main_func_init(mir);
  MIR_append_insn(mir, main, MIR_new_call_insn(mir, 3,
        MIR_new_ref_op(mir, print_proto),
        MIR_new_ref_op(mir, print_stdout),
        MIR_new_ref_op(mir, data)));
  MIR_finish_func(mir);

  MIR_finish_module(mir);
  return OK;
}
