#ifndef cli_h
#define cli_h

#include "wren.h"

void cliSetArguments(int argc, const char* argv[]);
WrenInterpretResult cliRunFile(const char* path, bool cleanup);
WrenInterpretResult cliRunSource(const char* module_name, const char* source, bool cleanup);
WrenInterpretResult cliRunRepl();
int cliGetExitCode();

#endif
