#include <stdio.h>
#include <string.h>

#include "io.h"
#include "modules.h"
#include "path.h"
#include "scheduler.h"
#include "stat.h"
#include "vm.h"
#include "log.h"

extern void* xosCtxInit();
extern void xosCtxDeinit(void*);
extern void xosCtxCaptureImportsAdd(WrenVM*, const char*);

// The single VM instance that the CLI uses.
static WrenVM* vm;

static WrenBindForeignMethodFn bindMethodFn = NULL;
static WrenBindForeignClassFn bindClassFn = NULL;
static WrenForeignMethodFn afterLoadFn = NULL;

static uv_loop_t* loop;

// TODO: This isn't currently used, but probably will be when package imports
// are supported. If not then, then delete this.
static char* rootDirectory = NULL;
static Path* wrenModulesDirectory = NULL;

// The exit code to use unless some other error overrides it.
int defaultExitCode = 0;

// Reads the contents of the file at [path] and returns it as a heap allocated
// string.
//
// Returns `NULL` if the path could not be found. Exits if it was found but
// could not be read.
static char* readFile(const char* path)
{
  FILE* file = fopen(path, "rb");
  if (file == NULL) return NULL;

  // Find out how big the file is.
  fseek(file, 0L, SEEK_END);
  size_t fileSize = ftell(file);
  rewind(file);

  // Allocate a buffer for it.
  char* buffer = (char*)malloc(fileSize + 1);
  if (buffer == NULL)
  {
    fprintf(stderr, "Could not read file \"%s\".\n", path);
    exit(74);
  }

  // Read the entire file.
  size_t bytesRead = fread(buffer, 1, fileSize, file);
  if (bytesRead < fileSize)
  {
    fprintf(stderr, "Could not read file \"%s\".\n", path);
    exit(74);
  }

  // Terminate the string.
  buffer[bytesRead] = '\0';

  fclose(file);
  return buffer;
}

static bool isDirectory(Path* path)
{
  uv_fs_t request;
  uv_fs_stat(loop, &request, path->chars, NULL);
  // TODO: Check request.result value?

  bool result = request.result == 0 &&
      (request.statbuf.st_mode & S_IFDIR);

  uv_fs_req_cleanup(&request);
  return result;
}

static Path* realPath(Path* path)
{
  uv_fs_t request;
  uv_fs_realpath(loop, &request, path->chars, NULL);

  Path* result = pathNew((char*)request.ptr);

  uv_fs_req_cleanup(&request);
  return result;
}

// Starting at [rootDirectory], walks up containing directories looking for a
// nearby "wren_modules" directory. If found, stores it in
// [wrenModulesDirectory].
//
// If [wrenModulesDirectory] has already been found, does nothing.
static void findModulesDirectory(const char* module_name)
{
  if (wrenModulesDirectory != NULL) return;

  const char* wm_env = getenv("WREN_MODULES");
  if (wm_env) {
    wrenModulesDirectory = pathNew(wm_env);
    DLOG("wrenModulesDirectory=%s", wrenModulesDirectory->chars);
    return;
  }

  // Use the directory where the file is as the root to resolve imports
  // relative to.
  Path* directory = pathNew(module_name);

  Path* searchDirectory = pathNew(rootDirectory);
  Path* lastPath = realPath(searchDirectory);

  // Keep walking up directories as long as we find them.
  for (;;)
  {
    Path* modulesDirectory = pathNew(searchDirectory->chars);
    pathJoin(modulesDirectory, "wren_modules");

    if (isDirectory(modulesDirectory))
    {
      pathNormalize(modulesDirectory);
      wrenModulesDirectory = modulesDirectory;
      break;
    }

    pathFree(modulesDirectory);

    // Walk up directories until we hit the root. We can tell that because
    // adding ".." yields the same real path.
    pathJoin(searchDirectory, "..");
    Path* thisPath = realPath(searchDirectory);
    if (strcmp(lastPath->chars, thisPath->chars) == 0)
    {
      pathFree(thisPath);
      break;
    }

    pathFree(lastPath);
    lastPath = thisPath;
  }

  pathFree(lastPath);
  pathFree(searchDirectory);
}

// Applies the CLI's import resolution policy. The rules are:
//
// * If [module] starts with "./" or "../", it is a relative import, relative
//   to [importer]. The resolved path is [name] concatenated onto the directory
//   containing [importer] and then normalized.
//
//   For example, importing "./a/./b/../c" from "./d/e/f" gives you "./d/e/a/c".
static const char* resolveModule(WrenVM* vm, const char* importer,
                                 const char* module)
{

  // Logical import strings are used as-is and need no resolution.
  if (pathType(module) == PATH_TYPE_SIMPLE) {
    xosCtxCaptureImportsAdd(vm, module);
    return module;
  }

  bool isxos = strncmp(importer, "xos//", 5) == 0;
  if (isxos) importer += 5;

  // Get the directory containing the importing module.
  Path* path = pathNew(importer);
  pathDirName(path);

  // Add the relative import path.
  pathJoin(path, module);

  pathNormalize(path);
  char* resolved;
  if (!isxos) {
    resolved = pathToString(path);
  } else {
    resolved = (char*)malloc(path->length + 6);
    memcpy(resolved, "xos//", 5);
    memcpy(resolved + 5, path->chars, path->length);
    resolved[path->length + 5] = '\0';
  }

  pathFree(path);
  xosCtxCaptureImportsAdd(vm, resolved);
  return resolved;
}

// Attempts to read the source for [module] relative to the current root
// directory.
//
// Returns it if found, or NULL if the module could not be found. Exits if the
// module was found but could not be read.
static WrenLoadModuleResult loadModule(WrenVM* vm, const char* module)
{
  DLOG("loadModule %s", module);
  WrenLoadModuleResult result = {0};
  Path* filePath;
  if (pathType(module) == PATH_TYPE_SIMPLE)
  {
    // If there is no "wren_modules" directory, then the only logical imports
    // we can handle are built-in ones. Let the VM try to handle it.
    findModulesDirectory(module);
    if (wrenModulesDirectory == NULL) {
      return loadBuiltInModule(module);
    }

    // TODO: Should we explicitly check for the existence of the module's base
    // directory inside "wren_modules" here?

    // Look up the module in "wren_modules".
    filePath = pathNew(wrenModulesDirectory->chars);
    pathJoin(filePath, module);

    // If the module is a single bare name, treat it as a module with the same
    // name inside the package. So "foo" means "foo/foo".
    if (strchr(module, '/') == NULL) pathJoin(filePath, module);
  }
  else
  {
    // The module path is already a file path.
    filePath = pathNew(module);
  }

  // Add a ".wren" file extension.
  pathAppendString(filePath, ".wren");
  result.onComplete = loadModuleComplete;
  result.source = readFile(filePath->chars);

  if (result.source != NULL) {
    DLOG("load module %s from %s", module, filePath->chars);
    pathFree(filePath);
    return result;
  }
  pathFree(filePath);

  // Otherwise, see if it's a built-in module.
  return loadBuiltInModule(module);
}

// Binds foreign methods declared in either built in modules, or the injected
// API test modules.
static WrenForeignMethodFn bindForeignMethod(WrenVM* vm, const char* module,
    const char* className, bool isStatic, const char* signature)
{
  WrenForeignMethodFn method = bindBuiltInForeignMethod(vm, module, className,
                                                        isStatic, signature);
  if (method != NULL) return method;

  if (bindMethodFn != NULL)
  {
    return bindMethodFn(vm, module, className, isStatic, signature);
  }

  return NULL;
}

// Binds foreign classes declared in either built in modules, or the injected
// API test modules.
static WrenForeignClassMethods bindForeignClass(
    WrenVM* vm, const char* module, const char* className)
{
  WrenForeignClassMethods methods = bindBuiltInForeignClass(vm, module,
                                                            className);
  if (methods.allocate != NULL) return methods;

  if (bindClassFn != NULL)
  {
    return bindClassFn(vm, module, className);
  }

  return methods;
}

static void write(WrenVM* vm, const char* text)
{
  fprintf(stderr, "%s", text);
}

static void reportError(WrenVM* vm, WrenErrorType type,
                        const char* module, int line, const char* message)
{
  switch (type)
  {
    case WREN_ERROR_COMPILE:
      fprintf(stderr, "[%s line %d] %s\n", module, line, message);
      break;

    case WREN_ERROR_RUNTIME:
      fprintf(stderr, "%s\n", message);
      break;

    case WREN_ERROR_STACK_TRACE:
      fprintf(stderr, "[%s line %d] in %s\n", module, line, message);
      break;
  }
}

static void initVM()
{
  void* xos_ctx = xosCtxInit();

  WrenConfiguration config;
  wrenInitConfiguration(&config);

  config.bindForeignMethodFn = bindForeignMethod;
  config.bindForeignClassFn = bindForeignClass;
  config.resolveModuleFn = resolveModule;
  config.loadModuleFn = loadModule;
  config.writeFn = write;
  config.errorFn = reportError;
  config.userData = xos_ctx;

  // Since we're running in a standalone process, be generous with memory.
  config.initialHeapSize = 1024 * 1024 * 100;
  vm = wrenNewVM(&config);

  // Initialize the event loop.
  loop = (uv_loop_t*)malloc(sizeof(uv_loop_t));
  uv_loop_init(loop);
}

static void freeVM()
{
  ioShutdown();
  schedulerShutdown();

  uv_loop_close(loop);
  free(loop);

  void* xos_ctx = wrenGetUserData(vm);
  xosCtxDeinit(xos_ctx);
  wrenFreeVM(vm);

  if (wrenModulesDirectory != NULL) pathFree(wrenModulesDirectory);
}

WrenInterpretResult runFile(const char* path, bool cleanup) {
  DLOG("runFile %s", path);
  char* source = readFile(path);
  if (source == NULL)
  {
    fprintf(stderr, "Could not find file \"%s\".\n", path);
    exit(66);
  }

  // If it looks like a relative path, make it explicitly relative so that we
  // can distinguish it from logical paths.
  // TODO: It might be nice to be able to run scripts from within a surrounding
  // "wren_modules" directory by passing in a simple path like "foo/bar". In
  // that case, here, we could check to see whether the give path exists inside
  // "wren_modules" or as a relative path and choose to add "./" or not based
  // on that.
  Path* module = pathNew(path);
  if (pathType(module->chars) == PATH_TYPE_SIMPLE)
  {
    Path* relative = pathNew(".");
    pathJoin(relative, path);

    pathFree(module);
    module = relative;
  }

  Path* directory = pathNew(module->chars);
  pathDirName(directory);
  rootDirectory = pathToString(directory);
  pathFree(directory);

  pathRemoveExtension(module);

  WrenInterpretResult result = runSource(module->chars, source, cleanup);

  if (cleanup) {
    free(rootDirectory);
    free(source);
    pathFree(module);
  }

  return result;
}

WrenInterpretResult runSource(const char* module_name, const char* source, bool cleanup)
{
  // This cast is safe since we don't try to free the string later.
  if (rootDirectory == NULL) rootDirectory = (char*)".";
  initVM();

  uv_disable_stdio_inheritance();

  WrenInterpretResult result = wrenInterpret(vm, module_name, source);

  if (afterLoadFn != NULL) afterLoadFn(vm);

  if (result == WREN_RESULT_SUCCESS)
  {
    uv_run(loop, UV_RUN_DEFAULT);
  }

  if (cleanup) {
    freeVM();
  }

  return result;
}

WrenInterpretResult runRepl()
{
  // This cast is safe since we don't try to free the string later.
  rootDirectory = (char*)".";
  initVM();

  printf("\\\\/\"-\n");
  printf(" \\_/   wren v%s\n", WREN_VERSION_STRING);

  WrenInterpretResult result = wrenInterpret(vm, "<repl>", "import \"repl\"\n");

  if (result == WREN_RESULT_SUCCESS)
  {
    uv_run(loop, UV_RUN_DEFAULT);
  }

  freeVM();

  return result;
}

WrenVM* getVM()
{
  return vm;
}

uv_loop_t* getLoop()
{
  return loop;
}

int getExitCode()
{
  return defaultExitCode;
}

void setExitCode(int exitCode)
{
  defaultExitCode = exitCode;
}

void setTestCallbacks(WrenBindForeignMethodFn bindMethod,
                      WrenBindForeignClassFn bindClass,
                      WrenForeignMethodFn afterLoad)
{
  bindMethodFn = bindMethod;
  bindClassFn = bindClass;
  afterLoadFn = afterLoad;
}
