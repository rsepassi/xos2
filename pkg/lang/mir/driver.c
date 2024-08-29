#include <string.h>
#include <stdio.h>
#include <stdbool.h>

#include "base/log.h"
#include "base/file.h"
#include "base/str.h"

#include "mir.h"
#include "mir-gen.h"

static str_t* mir_code;
static size_t mir_code_cur;

static int read_byte(MIR_context_t ctx) {
  if (mir_code_cur >= mir_code->len) return EOF;
  return mir_code->bytes[mir_code_cur++];
}

static void print_stdout(const char* out) { printf("%s", out); }
static void print_stderr(const char* out) { fprintf(stderr, "%s", out); }

static void *import_resolver (const char *name) {
  void *sym = NULL;
  if (!strcmp(name, "print_stdout")) return print_stdout;
  if (!strcmp(name, "print_stderr")) return print_stderr;
  if (sym == NULL) {
    fprintf (stderr, "can not load symbol %s\n", name);
    exit (1);
  }
  return sym;
}

MIR_item_t load_main(MIR_context_t ctx, const char* fname) {
  str_t contents;
  CHECK_OK(read_file(fname, &contents), "could not read file");
  mir_code = &contents;
  mir_code_cur = 0;
  MIR_read_with_func(ctx, read_byte);
  free(contents.bytes);

  MIR_item_t main_func = NULL;
  for (MIR_module_t module =
         DLIST_HEAD(MIR_module_t, *MIR_get_module_list(ctx));
       module != NULL;
       module = DLIST_NEXT(MIR_module_t, module)) {
    MIR_load_module(ctx, module);

    for (MIR_item_t func = DLIST_HEAD(MIR_item_t, module->items);
         main_func == NULL && func != NULL;
         func = DLIST_NEXT(MIR_item_t, func)) {
      if (func->item_type != MIR_func_item) continue;
      if (strcmp(func->u.func->name, "main") == 0) main_func = func;
    }
  }

  return main_func;
}

bool debug_enabled() {
  char* v = getenv("MIR_DEBUG");
  if (v == NULL) return false;
  return strcmp(v, "1") == 0;
}

typedef uint64_t (*mir_func)(int argc, char *argv[], char *env[]);

int main(int argc, char *argv[], char *env[]) {
  MIR_context_t ctx = MIR_init();
  CHECK(argc > 1, "must pass a mir binary filename");
  MIR_item_t main_func = load_main(ctx, argv[1]);
  CHECK(main_func, "cannot execute program w/o main function");

  MIR_gen_init(ctx);
  if (debug_enabled()) {
    MIR_gen_set_debug_file(ctx, stderr);
    MIR_gen_set_debug_level(ctx, 2);
  }
  MIR_link(ctx, MIR_set_gen_interface, import_resolver);
  mir_func func_addr = MIR_gen(ctx, main_func);
  int exit_code = func_addr(argc - 1, argv + 1, env);
  MIR_gen_finish(ctx);

  MIR_finish(ctx);
  return exit_code;
}
