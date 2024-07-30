#include <string.h>
#include <stdio.h>

#include "mir.h"
#include "mir-gen.h"

extern const uint8_t mir_code[];
extern int32_t mir_code_size;

static size_t curr_input_byte_num;

static int read_byte (MIR_context_t ctx) {
  if (curr_input_byte_num >= mir_code_size) return EOF;
  return mir_code[curr_input_byte_num++];
}

static void printfi(const char* fmt, int32_t x) { printf(fmt, x); }

static void *import_resolver (const char *name) {
  void *sym = NULL;
  if (!strcmp(name, "printfi")) return printfi;
  if (sym == NULL) {
    fprintf (stderr, "can not load symbol %s\n", name);
    exit (1);
  }
  return sym;
}

#ifndef MIR_BIN_DEBUG
#define MIR_BIN_DEBUG 0
#endif

#if MIR_BIN_DEBUG
#include "mir-real-time.h"
#endif

#ifndef MIR_USE_INTERP
#define MIR_USE_INTERP 0
#endif

#ifndef MIR_USE_LAZY_GEN
#define MIR_USE_LAZY_GEN 0
#endif

#ifndef MIR_USE_GEN
#define MIR_USE_GEN 1
#endif

int main (int argc, char *argv[], char *env[]) {
  int exit_code;
  MIR_val_t val;
  MIR_module_t module;
  MIR_item_t func, main_func = NULL;
  uint64_t (*fun_addr) (int, char *argv[], char *env[]);
  MIR_context_t ctx = MIR_init ();
  unsigned funcs_num = 0;
#if MIR_BIN_DEBUG
  double start_time = real_usec_time ();
#endif

  assert (MIR_USE_INTERP || MIR_USE_GEN || MIR_USE_LAZY_GEN);
  curr_input_byte_num = 0;
  MIR_read_with_func (ctx, read_byte);
#if MIR_BIN_DEBUG
  fprintf (stderr, "Finish of MIR reading from memory -- curr_time %.0f usec\n",
           real_usec_time () - start_time);
#endif
  for (module = DLIST_HEAD (MIR_module_t, *MIR_get_module_list (ctx)); module != NULL;
       module = DLIST_NEXT (MIR_module_t, module)) {
    for (func = DLIST_HEAD (MIR_item_t, module->items); func != NULL;
         func = DLIST_NEXT (MIR_item_t, func)) {
      if (func->item_type != MIR_func_item) continue;
      funcs_num++;
      if (strcmp (func->u.func->name, "main") == 0) main_func = func;
    }
    MIR_load_module (ctx, module);
  }
  if (main_func == NULL) {
    fprintf (stderr, "cannot execute program w/o main function\n");
    return 1;
  }
  if (MIR_USE_INTERP) {
    MIR_link (ctx, MIR_set_interp_interface, import_resolver);
#if MIR_BIN_DEBUG
    fprintf (stderr, "Finish of loading/linking (%d funcs) -- curr_time %.0f usec\n", funcs_num,
             real_usec_time () - start_time);
    start_time = real_usec_time ();
#endif
    MIR_interp (ctx, main_func, &val, 3, (MIR_val_t){.i = argc}, (MIR_val_t){.a = (void *) argv},
                (MIR_val_t){.a = (void *) env});
#if MIR_BIN_DEBUG
    fprintf (stderr, "Finish of execution -- overall execution time %.0f usec\n",
             real_usec_time () - start_time);
#endif
    exit_code = val.i;
  } else {
    MIR_gen_init (ctx);
#if MIR_BIN_DEBUG
    MIR_gen_set_debug_file (ctx, stderr);
    MIR_gen_set_debug_level (ctx, MIR_BIN_DEBUG);
#endif
    MIR_link (ctx, MIR_USE_GEN ? MIR_set_gen_interface : MIR_set_lazy_gen_interface,
              import_resolver);
#if MIR_BIN_DEBUG
    fprintf (stderr,
             (!MIR_USE_GEN
                ? "Finish of MIR loading/linking (%d funcs) -- curr_time %.0f usec\n"
                : "Finish of MIR loading/linking/generation (%d funcs) -- curr_time %.0f usec\n"),
             funcs_num, real_usec_time () - start_time);
#endif
    fun_addr = MIR_gen (ctx, main_func);
#if MIR_BIN_DEBUG
    start_time = real_usec_time ();
#endif
    exit_code = fun_addr (argc, argv, env);
#if MIR_BIN_DEBUG
    fprintf (stderr,
             (MIR_USE_GEN
                ? "Finish of execution -- overall execution time %.0f usec\n"
                : "Finish of generation and execution -- overall execution time %.0f usec\n"),
             real_usec_time () - start_time);
#endif
    MIR_gen_finish (ctx);
  }
  MIR_finish (ctx);
  return exit_code;
}
