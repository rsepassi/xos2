#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "modules.h"
#include "path.h"

#include "glob.wren.inc"
#include "io.wren.inc"
#include "os.wren.inc"
#include "repl.wren.inc"
#include "scheduler.wren.inc"
#include "timer.wren.inc"

extern void directoryList(WrenVM* vm);
extern void directoryCreate(WrenVM* vm);
extern void directoryDelete(WrenVM* vm);
extern void directoryDeleteTree(WrenVM* vm);
extern void directoryMkdirs(WrenVM* vm);
extern void fileAllocate(WrenVM* vm);
extern void fileFinalize(void* data);
extern void fileDelete(WrenVM* vm);
extern void fileSymlink(WrenVM* vm);
extern void fileCopy(WrenVM* vm);
extern void fileRename(WrenVM* vm);
extern void fileOpen(WrenVM* vm);
extern void fileSizePath(WrenVM* vm);
extern void fileClose(WrenVM* vm);
extern void fileDescriptor(WrenVM* vm);
extern void fileReadBytes(WrenVM* vm);
extern void fileRealPath(WrenVM* vm);
extern void fileReadLink(WrenVM* vm);
extern void fileSize(WrenVM* vm);
extern void fileStat(WrenVM* vm);
extern void fileWriteBytes(WrenVM* vm);
extern void fileFd(WrenVM* vm);
extern void platformHomePath(WrenVM* vm);
extern void platformIsPosix(WrenVM* vm);
extern void platformName(WrenVM* vm);
extern void processAllArguments(WrenVM* vm);
extern void processCwd(WrenVM* vm);
extern void processPid(WrenVM* vm);
extern void processPpid(WrenVM* vm);
extern void processVersion(WrenVM* vm);
extern void processExit(WrenVM* vm);
extern void processEnv(WrenVM* vm);
extern void processEnvName(WrenVM* vm);
extern void processChdir(WrenVM* vm);
extern void processSpawn(WrenVM* vm);
extern void osDebug(WrenVM* vm);
extern void statPath(WrenVM* vm);
extern void statBlockCount(WrenVM* vm);
extern void statBlockSize(WrenVM* vm);
extern void statDevice(WrenVM* vm);
extern void statGroup(WrenVM* vm);
extern void statInode(WrenVM* vm);
extern void statLinkCount(WrenVM* vm);
extern void statMode(WrenVM* vm);
extern void statSize(WrenVM* vm);
extern void statSpecialDevice(WrenVM* vm);
extern void statUser(WrenVM* vm);
extern void statIsDirectory(WrenVM* vm);
extern void statIsFile(WrenVM* vm);
extern void stdinIsRaw(WrenVM* vm);
extern void stdinIsRawSet(WrenVM* vm);
extern void stdinIsTerminal(WrenVM* vm);
extern void stdinReadStart(WrenVM* vm);
extern void stdinReadStop(WrenVM* vm);
extern void stdoutWrite(WrenVM* vm);
extern void stdoutFlush(WrenVM* vm);
extern void schedulerCaptureMethods(WrenVM* vm);
extern void timerStartTimer(WrenVM* vm);
extern void stopwatchAllocate(WrenVM* vm);
extern void stopwatchLap(WrenVM* vm);
extern void stopwatchRead(WrenVM* vm);
extern void wrenGlob(WrenVM* vm);

extern char* wrenHashSource(void);
extern WrenForeignClassMethods wrenHashBindForeignClass(WrenVM* vm,
                                                   const char* module,
                                                   const char* className);
extern WrenForeignMethodFn wrenHashBindForeignMethod(WrenVM* vm,
                                                const char* className,
                                                bool isStatic,
                                                const char* signature);

extern char* wrenRandomSource(void);
extern WrenForeignMethodFn wrenRandomBindForeignMethod(WrenVM* vm,
                                                const char* className,
                                                bool isStatic,
                                                const char* signature);

extern char* wrenKvSource(void);
extern WrenForeignClassMethods wrenKvBindForeignClass(WrenVM* vm,
                                                   const char* module,
                                                   const char* className);
extern WrenForeignMethodFn wrenKvBindForeignMethod(WrenVM* vm,
                                                const char* className,
                                                bool isStatic,
                                                const char* signature);

extern char* wrenJSONSource(void);
extern WrenForeignClassMethods wrenUclBindForeignClass(WrenVM* vm,
                                                   const char* module,
                                                   const char* className);
extern WrenForeignMethodFn wrenUclBindForeignMethod(WrenVM* vm,
                                                const char* className,
                                                bool isStatic,
                                                const char* signature);

// The maximum number of foreign methods a single class defines. Ideally, we
// would use variable-length arrays for each class in the table below, but
// C++98 doesn't have any easy syntax for nested global static data, so we
// just use worst-case fixed-size arrays instead.
//
// If you add a new method to the longest class below, make sure to bump this.
// Note that it also includes an extra slot for the sentinel value indicating
// the end of the list.
#define MAX_METHODS_PER_CLASS 16

// The maximum number of foreign classes a single built-in module defines.
//
// If you add a new class to the largest module below, make sure to bump this.
// Note that it also includes an extra slot for the sentinel value indicating
// the end of the list.
#define MAX_CLASSES_PER_MODULE 6

// Describes one foreign method in a class.
typedef struct
{
  bool isStatic;
  const char* signature;
  WrenForeignMethodFn method;
} MethodRegistry;

// Describes one class in a built-in module.
typedef struct
{
  const char* name;

  MethodRegistry methods[MAX_METHODS_PER_CLASS];
} ClassRegistry;

// Describes one built-in module.
typedef struct
{
  // The name of the module.
  const char* name;

  // Pointer to the string containing the source code of the module. We use a
  // pointer here because the string variable itself is not a constant
  // expression so can't be used in the initializer below.
  const char **source;

  ClassRegistry classes[MAX_CLASSES_PER_MODULE];
} ModuleRegistry;

// To locate foreign classes and modules, we build a big directory for them in
// static data. The nested collection initializer syntax gets pretty noisy, so
// define a couple of macros to make it easier.
#define SENTINEL_METHOD { false, NULL, NULL }
#define SENTINEL_CLASS { NULL, { SENTINEL_METHOD } }
#define SENTINEL_MODULE {NULL, NULL, { SENTINEL_CLASS } }

#define MODULE(name) { #name, &name##ModuleSource, {
#define END_MODULE SENTINEL_CLASS } },

#define CLASS(name) { #name, {
#define END_CLASS SENTINEL_METHOD } },

#define METHOD(signature, fn) { false, signature, fn },
#define STATIC_METHOD(signature, fn) { true, signature, fn },
#define ALLOCATE(fn) { true, "<allocate>", (WrenForeignMethodFn)fn },
#define FINALIZE(fn) { true, "<finalize>", (WrenForeignMethodFn)fn },

// The array of built-in modules.
static ModuleRegistry modules[] =
{
  MODULE(glob)
    CLASS(Glob)
      STATIC_METHOD("glob_(_)", wrenGlob)
    END_CLASS
  END_MODULE
  MODULE(io)
    CLASS(Directory)
      STATIC_METHOD("create_(_,_)", directoryCreate)
      STATIC_METHOD("delete_(_,_)", directoryDelete)
      STATIC_METHOD("deleteTree_(_,_)", directoryDeleteTree)
      STATIC_METHOD("mkdirs_(_,_)", directoryMkdirs)
      STATIC_METHOD("list_(_,_)", directoryList)
    END_CLASS
    CLASS(File)
      ALLOCATE(fileAllocate)
      FINALIZE(fileFinalize)
      STATIC_METHOD("delete_(_,_)", fileDelete)
      STATIC_METHOD("rename_(_,_,_)", fileRename)
      STATIC_METHOD("symlink_(_,_,_)", fileSymlink)
      STATIC_METHOD("copy_(_,_,_)", fileCopy)
      STATIC_METHOD("open_(_,_,_)", fileOpen)
      STATIC_METHOD("sizePath_(_,_)", fileSizePath)
      METHOD("fd", fileFd)
      METHOD("close_(_)", fileClose)
      METHOD("descriptor", fileDescriptor)
      METHOD("readBytes_(_,_,_)", fileReadBytes)
      METHOD("size_(_)", fileSize)
      METHOD("stat_(_)", fileStat)
      METHOD("writeBytes_(_,_,_)", fileWriteBytes)
    END_CLASS
    CLASS(Stat)
      STATIC_METHOD("path_(_,_)", statPath)
      METHOD("blockCount", statBlockCount)
      METHOD("blockSize", statBlockSize)
      METHOD("device", statDevice)
      METHOD("group", statGroup)
      METHOD("inode", statInode)
      METHOD("linkCount", statLinkCount)
      METHOD("mode", statMode)
      METHOD("size", statSize)
      METHOD("specialDevice", statSpecialDevice)
      METHOD("user", statUser)
      METHOD("isDirectory", statIsDirectory)
      METHOD("isFile", statIsFile)
    END_CLASS
    CLASS(Stdin)
      STATIC_METHOD("isRaw", stdinIsRaw)
      STATIC_METHOD("isRaw=(_)", stdinIsRawSet)
      STATIC_METHOD("isTerminal", stdinIsTerminal)
      STATIC_METHOD("readStart_()", stdinReadStart)
      STATIC_METHOD("readStop_()", stdinReadStop)
    END_CLASS
    CLASS(Stdout)
      STATIC_METHOD("write(_)", stdoutWrite)
      STATIC_METHOD("flush()", stdoutFlush)
    END_CLASS
  END_MODULE
  MODULE(os)
    CLASS(Platform)
      STATIC_METHOD("homePath", platformHomePath)
      STATIC_METHOD("isPosix", platformIsPosix)
      STATIC_METHOD("name", platformName)
    END_CLASS
    CLASS(Process)
      STATIC_METHOD("allArguments", processAllArguments)
      STATIC_METHOD("cwd", processCwd)
      STATIC_METHOD("pid", processPid)
      STATIC_METHOD("ppid", processPpid)
      STATIC_METHOD("version", processVersion)
      STATIC_METHOD("exit(_)", processExit)
      STATIC_METHOD("env()", processEnv)
      STATIC_METHOD("env(_)", processEnvName)
      STATIC_METHOD("chdir(_)", processChdir)
      STATIC_METHOD("spawn_(_,_,_,_,_,_)", processSpawn)
    END_CLASS
    CLASS(Path)
      STATIC_METHOD("realPath_(_,_)", fileRealPath)
      STATIC_METHOD("readLink_(_,_)", fileReadLink)
    END_CLASS
    CLASS(Debug)
      STATIC_METHOD("debug(_)", osDebug)
      STATIC_METHOD("debug(_,_)", osDebug)
      STATIC_METHOD("debug(_,_,_)", osDebug)
      STATIC_METHOD("debug(_,_,_,_)", osDebug)
      STATIC_METHOD("debug(_,_,_,_,_)", osDebug)
      STATIC_METHOD("debug(_,_,_,_,_,_)", osDebug)
      STATIC_METHOD("debug(_,_,_,_,_,_,_)", osDebug)
      STATIC_METHOD("debug(_,_,_,_,_,_,_,_)", osDebug)
    END_CLASS
  END_MODULE
  MODULE(repl)
  END_MODULE
  MODULE(scheduler)
    CLASS(Scheduler)
      STATIC_METHOD("captureMethods_()", schedulerCaptureMethods)
    END_CLASS
  END_MODULE
  MODULE(timer)
    CLASS(Timer)
      STATIC_METHOD("startTimer_(_,_)", timerStartTimer)
    END_CLASS
    CLASS(Stopwatch)
      ALLOCATE(stopwatchAllocate)
      METHOD("lap()", stopwatchLap)
      METHOD("read()", stopwatchRead)
    END_CLASS
  END_MODULE

  SENTINEL_MODULE
};

#undef SENTINEL_METHOD
#undef SENTINEL_CLASS
#undef SENTINEL_MODULE
#undef MODULE
#undef END_MODULE
#undef CLASS
#undef END_CLASS
#undef METHOD
#undef STATIC_METHOD
#undef FINALIZER

// Looks for a built-in module with [name].
//
// Returns the BuildInModule for it or NULL if not found.
static ModuleRegistry* findModule(const char* name)
{
  for (int i = 0; modules[i].name != NULL; i++)
  {
    if (strcmp(name, modules[i].name) == 0) return &modules[i];
  }

  return NULL;
}

// Looks for a class with [name] in [module].
static ClassRegistry* findClass(ModuleRegistry* module, const char* name)
{
  for (int i = 0; module->classes[i].name != NULL; i++)
  {
    if (strcmp(name, module->classes[i].name) == 0) return &module->classes[i];
  }

  return NULL;
}

// Looks for a method with [signature] in [clas].
static WrenForeignMethodFn findMethod(ClassRegistry* clas,
                                      bool isStatic, const char* signature)
{
  for (int i = 0; clas->methods[i].signature != NULL; i++)
  {
    MethodRegistry* method = &clas->methods[i];
    if (isStatic == method->isStatic &&
        strcmp(signature, method->signature) == 0)
    {
      return method->method;
    }
  }

  return NULL;
}

void loadModuleComplete(WrenVM* vm, const char* name, struct WrenLoadModuleResult result)
{
  if (result.source == NULL) return;

  free((void*)result.source);
}

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

WrenLoadModuleResult loadBuiltInModule(const char* name)
{
  WrenLoadModuleResult result = {0};
  ModuleRegistry* module = findModule(name);
  if (module == NULL) {
    // Extensions
    char* src = NULL;
    do {
      if (strcmp(name, "random") == 0) {
        src = wrenRandomSource();
        break;
      }
      if (strcmp(name, "hash") == 0) {
        src = wrenHashSource();
        break;
      }
      if (strcmp(name, "kv") == 0) {
        src = wrenKvSource();
        break;
      }
      if (strcmp(name, "json") == 0) {
        src = wrenJSONSource();
        break;
      }
      const char* xosprefix = "xos//";
      if (strncmp(xosprefix, name, strlen(xosprefix)) == 0) {
        const char* pwd = getenv("XOS_REPO_ROOT");
        Path* filePath = pathNew(pwd);
        pathJoin(filePath, name + strlen(xosprefix));
        pathAppendString(filePath, ".wren");
        result.onComplete = loadModuleComplete;
        result.source = readFile(filePath->chars);
        pathFree(filePath);
      }
    } while (0);
    if (src != NULL) {
      size_t length = strlen(src);
      char* copy = (char*)malloc(length + 1);
      memcpy(copy, src, length + 1);
       
      result.onComplete = loadModuleComplete;
      result.source = copy;
    }
    return result;
  }

  size_t length = strlen(*module->source);
  char* copy = (char*)malloc(length + 1);
  memcpy(copy, *module->source, length + 1);
   
  result.onComplete = loadModuleComplete;
  result.source = copy;
  return result;
}

WrenForeignMethodFn bindBuiltInForeignMethod(
    WrenVM* vm, const char* moduleName, const char* className, bool isStatic,
    const char* signature)
{
  // TODO: Assert instead of return NULL?
  ModuleRegistry* module = findModule(moduleName);
  if (module == NULL) {
    if (strcmp(moduleName, "random") == 0) {
      return wrenRandomBindForeignMethod(vm, className, isStatic, signature);
    }
    if (strcmp(moduleName, "kv") == 0) {
      return wrenKvBindForeignMethod(vm, className, isStatic, signature);
    }
    if (strcmp(moduleName, "json") == 0) {
      return wrenUclBindForeignMethod(vm, className, isStatic, signature);
    }
    if (strcmp(moduleName, "hash") == 0) {
      return wrenHashBindForeignMethod(vm, className, isStatic, signature);
    }
    return NULL;
  }

  ClassRegistry* clas = findClass(module, className);
  if (clas == NULL) return NULL;

  return findMethod(clas, isStatic, signature);
}

WrenForeignClassMethods bindBuiltInForeignClass(
    WrenVM* vm, const char* moduleName, const char* className)
{
  WrenForeignClassMethods methods = { NULL, NULL };

  ModuleRegistry* module = findModule(moduleName);
  if (module == NULL) {
    if (strcmp(moduleName, "kv") == 0) {
      return wrenKvBindForeignClass(vm, module, className);
    }
    if (strcmp(moduleName, "json") == 0) {
      return wrenUclBindForeignClass(vm, module, className);
    }
    if (strcmp(moduleName, "hash") == 0) {
      return wrenHashBindForeignClass(vm, module, className);
    }
    return methods;
  }

  ClassRegistry* clas = findClass(module, className);
  if (clas == NULL) return methods;

  methods.allocate = findMethod(clas, true, "<allocate>");
  methods.finalize = (WrenFinalizerFn)findMethod(clas, true, "<finalize>");

  return methods;
}
