#include "cli.h"

#include "os.h"
#include "vm.h"

void cliSetArguments(int argc, const char* argv[]) {
  osSetArguments(argc, argv);
}

WrenInterpretResult cliRunFile(const char* path, bool cleanup) {
  return runFile(path, cleanup);
}

WrenInterpretResult cliRunSource(const char* module_name, const char* source, bool cleanup) {
  return runSource(module_name, source, cleanup);
}

WrenInterpretResult cliRunRepl() {
  return runRepl();
}

int cliGetExitCode() {
  return getExitCode();
}
