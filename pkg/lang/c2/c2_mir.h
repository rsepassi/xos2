#include "c2.h"
#include "mir.h"

// MIR codegen
typedef struct {
  MIR_context_t mir;
  const char* module_name;
} C2_GenCtxMir;
void c2_gen_mir(C2_Ctx* ctx, C2_Module* module, C2_GenCtxMir* genctx);

