#ifndef RY0_CODEGEN_H_
#define RY0_CODEGEN_H_

#include "base/status.h"
#include "ry0.h"
#include "mir.h"

typedef struct {
  MIR_context_t mir;
  NodeCtx* node_ctx;
} CodegenCtx;

Status codegen(CodegenCtx* ctx, NodeHandle root);

#endif
