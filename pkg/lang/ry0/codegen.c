#include "codegen.h"

// https://github.com/vnmakarov/mir/blob/master/MIR.md

static const char* mirmain = "mirmain";

static MIR_item_t main_func_init(MIR_context_t mir) {
  MIR_type_t main_result_t = MIR_T_I32;
  MIR_var_t main_args_t[2] = {
  ((MIR_var_t){
    .type = MIR_T_I32,
    .name = "argc",
  }),
  ((MIR_var_t){
    .type = MIR_T_P,
    .name = "argv",
  })
  };

  MIR_item_t func = MIR_new_func_arr(
      mir, mirmain, 1, &main_result_t, 2, main_args_t);

  return func;
}

static Status gen(CodegenCtx* ctx, Node* root) {
  // I want to march through root and do codegen
  // Everything should be easy at this point
  // All type-checked, everything precomputed

  // root is always of type StructBody
  // I'm only interested in the decls
  // And by this point I should know which decls matter
  // So functions at this level should be generated
  // Assume that functions have all been flattened out?
  // Forward declarations needed?
  // Let's also assume that...


  // Need
  //   imports
  //   import signatures
  //     explicit extern functions
  //     stdlib functions, I know they're extern
  //   exports
  //     pub functions used by other modules
  //     export functions
  //     data used by other modules
  //   data
  //   bss
  //   functions


  switch (node->type) {
  }

}



Status codegen(CodegenCtx* ctx, NodeHandle root_handle) {
  MIR_context_t mir = ctx->mir;
  Node* root = node_get(ctx->node_ctx, root_handle);
  if (root == NULL) return ERR;

  // Main module
  MIR_module_t mod = MIR_new_module(mir, "modulemain");

  // Generate starting with entrypoints
  // export, main

  // Imports
  MIR_item_t print_stdout = MIR_new_import(mir, "print_stdout");
  MIR_item_t print_stderr = MIR_new_import(mir, "print_stderr");
  MIR_new_export(mir, mirmain);
  MIR_var_t print_args_t = (MIR_var_t){.type = MIR_T_P, .name = "s"};
  MIR_item_t print_proto = MIR_new_proto_arr(
      mir, "print_p", 0, NULL, 1, &print_args_t);

  // Data
  const char* hello = "hello world!\n";
  MIR_item_t data = MIR_new_data(mir, "hello", MIR_T_U8, strlen(hello) + 1, hello);

  // Main
  MIR_item_t main = main_func_init(mir);
  MIR_op_t call_ops[3] = {
    MIR_new_ref_op(mir, print_proto),
    MIR_new_ref_op(mir, print_stdout),
    MIR_new_ref_op(mir, data),
  };
  MIR_append_insn(mir, main, MIR_new_insn_arr(mir, MIR_CALL, 3, call_ops));
  MIR_op_t ret_ops[1] = {
    MIR_new_int_op(mir, 0),
  };
  MIR_append_insn(mir, main, MIR_new_insn_arr(mir, MIR_RET, 1, ret_ops));
  MIR_finish_func(mir);

  MIR_finish_module(mir);
  return OK;
}
