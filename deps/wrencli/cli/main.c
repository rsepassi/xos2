#include <stdio.h>
#include <string.h>

#include "cli.h"

int main(int argc, const char* argv[])
{
  if (argc == 2 && strcmp(argv[1], "--help") == 0)
  {
    printf("Usage: wren [file] [arguments...]\n");
    printf("\n");
    printf("Optional arguments:\n");
    printf("  --help     Show command line usage\n");
    printf("  --version  Show version\n");
    return 0;
  }

  if (argc == 2 && strcmp(argv[1], "--version") == 0)
  {
    printf("wren %s\n", WREN_VERSION_STRING);
    return 0;
  }

  cliSetArguments(argc, argv);

  WrenInterpretResult result;
  if (argc == 1)
  {
    result = cliRunRepl();
  }
  else
  {
    result = cliRunFile(argv[1], false);
  }

  // Exit with an error code if the script failed.
  if (result == WREN_RESULT_COMPILE_ERROR) return 65; // EX_DATAERR.
  if (result == WREN_RESULT_RUNTIME_ERROR) return 70; // EX_SOFTWARE.

  int code = cliGetExitCode();
  return code;
}
