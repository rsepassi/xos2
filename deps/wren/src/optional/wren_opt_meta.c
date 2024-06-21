#include <string.h>
#include <stdio.h>

#include "wren_vm.h"

#include "wren_opt_meta.wren.inc"

void metaCompile(WrenVM* vm)
{
  const char* source = wrenGetSlotString(vm, 1);
  bool isExpression = wrenGetSlotBool(vm, 2);
  bool printErrors = wrenGetSlotBool(vm, 3);

  // TODO: Allow passing in module?
  // Look up the module surrounding the callsite. This is brittle. The -2 walks
  // up the callstack assuming that the meta module has one level of
  // indirection before hitting the user's code. Any change to meta may require
  // this constant to be tweaked.
  ObjFiber* currentFiber = vm->fiber;
  ObjFn* fn = currentFiber->frames[currentFiber->numFrames - 2].closure->fn;
  ObjString* module = fn->module->name;

  ObjClosure* closure = wrenCompileSource(vm, module->value, source,
                                          isExpression, printErrors);
  
  // Return the result. We can't use the public API for this since we have a
  // bare ObjClosure*.
  if (closure == NULL)
  {
    vm->apiStack[0] = NULL_VAL;
  }
  else
  {
    vm->apiStack[0] = OBJ_VAL(closure);
  }
}

void metaGetModuleVariables(WrenVM* vm)
{
  wrenEnsureSlots(vm, 3);
  
  Value moduleValue = wrenMapGet(vm->modules, vm->apiStack[1]);
  if (IS_UNDEFINED(moduleValue))
  {
    vm->apiStack[0] = NULL_VAL;
    return;
  }
    
  ObjModule* module = AS_MODULE(moduleValue);
  ObjList* names = wrenNewList(vm, module->variableNames.count);
  vm->apiStack[0] = OBJ_VAL(names);

  // Initialize the elements to null in case a collection happens when we
  // allocate the strings below.
  for (int i = 0; i < names->elements.count; i++)
  {
    names->elements.data[i] = NULL_VAL;
  }
  
  for (int i = 0; i < names->elements.count; i++)
  {
    names->elements.data[i] = OBJ_VAL(module->variableNames.data[i]);
  }
}

static void abortFiber(WrenVM* vm, char* fmt, ...) {

  va_list args;
  va_start(args, fmt);
  ssize_t bufsz = vsnprintf(NULL, 0, fmt, args);
  va_end(args);

  char* errstr = (char*)malloc(bufsz + 1);

  va_list args2;
  va_start(args2, fmt);
  vsnprintf(errstr, bufsz + 1, fmt, args2);
  va_end(args2);

  wrenEnsureSlots(vm, 1);
  wrenSetSlotString(vm, 0, errstr);
  wrenAbortFiber(vm, 0);

  free(errstr);
}

void metaGetModuleVariable(WrenVM* vm)
{
  const char* module = wrenGetSlotString(vm, 1);
  const char* label = wrenGetSlotString(vm, 2);

  if (!wrenHasVariable(vm, module, label)) {
    abortFiber(vm, "error: module %s has no top-level object named %s", module, label);
    return;
  }

  wrenEnsureSlots(vm, 1);
  wrenGetVariable(vm, module, label, 0);
}

const char* wrenMetaSource()
{
  return wren_opt_metaModuleSource;
}

WrenForeignMethodFn wrenMetaBindForeignMethod(WrenVM* vm,
                                              const char* className,
                                              bool isStatic,
                                              const char* signature)
{
  // There is only one foreign method in the meta module.
  ASSERT(strcmp(className, "Meta") == 0, "Should be in Meta class.");
  ASSERT(isStatic, "Should be static.");
  
  if (strcmp(signature, "compile_(_,_,_)") == 0)
  {
    return metaCompile;
  }
  
  if (strcmp(signature, "getModuleVariables_(_)") == 0)
  {
    return metaGetModuleVariables;
  }
  
  if (strcmp(signature, "getModuleVariable_(_,_)") == 0)
  {
    return metaGetModuleVariable;
  }
  
  ASSERT(false, "Unknown method.");
  return NULL;
}
