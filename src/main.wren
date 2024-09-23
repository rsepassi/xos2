// xos cli

import "os" for Process, Path
import "io" for File, Directory
import "log" for Logger
import "timer" for Stopwatch
import "flagparse" for FlagParser
import "glob" for Glob
import "timer" for StopwatchTree

import "build" for Build
import "build/config" for Config
import "build/cache" for BuildCache

var Log = Logger.get("xos")

var CMDS
var CACHE_CMDS

var help = Fn.new { |args|
  var usage = "
xos <command>

commands: %(CMDS.keys.toList)
"
  System.print(usage)
  return true
}

var buildInner = Fn.new { |args, install|
  var usage = "
xos build [<build-flags>...] <label> [-- <label-arg>...]
"
  var flag_parser = FlagParser.new("build", [
    FlagParser.Flag.optional("target", {"default": Build.Target.host, "parser": Build.Target}),
    FlagParser.Flag.optional("opt", {"default": "Debug"}),
  ])

  if (args.isEmpty) {
    System.print(usage)
    flag_parser.help()
    return
  }

  // Parse build flags
  var build_flags = []
  var argi = 0
  while (argi < args.count && args[argi].startsWith("--")) {
    build_flags.add(args[argi])
    argi = argi + 1
  }
  build_flags = flag_parser.parse(build_flags)

  if (argi >= args.count) {
    System.print("error: no label provided")
    return
  }

  // Parse label argument
  var cache = BuildCache.new()
  var label = Build.Label.parse(args[argi], Config.get("cwd"), cache)
  argi = argi + 1
  if (!File.exists(label.modulePath)) {
    System.print("error: no build script exists at %(label.modulePath)")
    return
  }
  if (label.getBuilder() == null) {
    System.print("error: target '%(label)' expects build script at '%(label.modulePath)' to contain top-level variable '%(label.target)'")
    return
  }

  // Separate label arguments
  var label_args = []
  if (argi < args.count) {
    if (args[argi] != "--") {
      System.print("error: Argument %(args[argi]) specified after label. If it is a build flag, specify it before the label, and if it is an argument for the label function, specify it after '--'")
      System.print(usage)
      flag_parser.help()
      return
    }
    argi = argi + 1
    label_args = args[argi..-1]
  }

  // Build
  var b = Build.get({
    "build_args": build_flags,
    "label": label,
    "label_args": label_args,
    "cache": cache,
  })
  Log.debug("%(b)")
  var out = b.build_()

  if (install) {
    // Install
    var out_dir = "%(Config.get("repo_root"))/xos-out"
    Log.debug("installing %(b) output in %(out_dir)")
    Directory.deleteTree(out_dir)
    Directory.copy(b.installDir, out_dir)
  }

  return out
}

var build = Fn.new { |args|
  buildInner.call(args, true)
  return true
}


var run = Fn.new { |args|
  var usage = "
xos run [<build-flags>...] [--bin=<binname>] [--binargs <bin-arg>... --] <label> [-- <label-arg>...]
"
  if (args.isEmpty) {
    System.print(usage)
    return
  }

  var filtered_args = []
  var binname = null
  var binargs = []
  var in_binargs = false
  for (arg in args) {
    if (in_binargs) {
      if (arg == "--") {
        in_binargs = false
      } else {
        binargs.add(arg)
      }
    } else if (arg == "--binargs") {
      in_binargs = true
    } else if (arg.startsWith("--bin=")) {
      binname = arg.split("=")[1]
    } else {
      filtered_args.add(arg)
    }
  }

  var install = buildInner.call(filtered_args, false)
  if (binname == null) binname = install.build.label.target

  var exe = install.exe(binname)
  Log.debug("running exe %(exe)")
  var f = Fiber.new {
    Process.spawn([exe] + binargs, null, [0, 1, 2])
  }
  f.try()
  return f.error == null
}

var readenv = Fn.new {
  var vars = [
    "XOS_ROOT",
    "XOS_REPO_ROOT",
    "XOS_SYSTEM_PATH",
    "XOS_SYSTEM_HOME",
    "XOS_HOST",
    "XOS_ID",
    "WREN_MODULES",
    "PATH",
    "LOG",
    "LOG_SCOPES",
  ]
  var env = {}
  for (v in vars) env[v] = Process.env(v)
  return env
}

var env_cmd = Fn.new { |args|
  var env = readenv.call()
  for (v in env) {
    System.print("%(v.key)=%(v.value)")
  }
  return true
}

var cache_clean = Fn.new { |args|
  for (d in Glob.glob(".xos-cache/label/*/*/home")) {
    var pkg = Path.dirname(d)
    Directory.deleteTree(pkg)
  }
  return true
}

var cache_help = Fn.new { |args|
  var usage = "
xos cache <command>

commands: %(CACHE_CMDS.keys.toList)
"
  System.print(usage)
  return true
}

CACHE_CMDS = {
  "help": cache_help,
  "clean": cache_clean,
}

var cache = Fn.new { |args|
  var cmd = "help"
  var cmd_args = []

  if (args.count >= 1) {
    cmd = args[0]
    if (CACHE_CMDS.containsKey(cmd)) {
      cmd_args = args.count > 1 ? args[1..-1] : []
    } else {
      System.print("error: uncrecognized command %(cmd)")
      cmd = "help"
    }
  }

  Log.debug("cache command=%(cmd) args=%(cmd_args)")
  return CACHE_CMDS[cmd].call(cmd_args)
}

var new = Fn.new { |args|
  if (args.count == 0) {
    var usage = "
  xos new <name|path>
  "
    System.print(usage)
    return true
  }

  var path = args[0]
  var target = Path.basename(path)
  Directory.ensure(path)
  var build_path = Path.join([path, "build.wren"])
  if (File.exists(build_path)) {
    System.print("%(build_path) already exists")
    return false
  }

  var cpath = Path.join([path, "%(target).c"])
  var exepath = Path.join([path, "%(target)_main.c"])
  var hpath = Path.join([path, "%(target).h"])
  File.write(cpath, "#include \"%(target).h\"\n")
  File.write(hpath, "")
  var execontents = "#include \"base/log.h\"

#include \"%(target).h\"

int main(int argc, char** argv) {
  LOG(\"hello world!\");
  return 0;
}
"
  File.write(exepath, execontents)

  var contents = "import \"io\" for File, Directory
import \"os\" for Process, Path

var %(target) = Fn.new { |b, args|
  var zig = b.deptool(\"//toolchains/zig\")
  zig.ez.cLib(b, {
    \"srcs\": [b.src(\"%(target).c\")],
    \"include\": [b.src(\"%(target).h\")],
    \"flags\": [],
    \"deps\": [
      b.dep(\"//pkg/cbase\"),
    ],
  })
}

var %(target)_exe = Fn.new { |b, args|
  var zig = b.deptool(\"//toolchains/zig\")
  b.installExe(zig.buildExe(b, \"%(target)\", {
    \"c_srcs\": [b.src(\"%(target)_main.c\")],
    \"flags\": [],
    \"c_deps\": [
      b.dep(\":%(target)\"),
      b.dep(\"//pkg/cbase\"),
    ],
    \"libc\": true,
  }))
}
"

  File.write(build_path, contents)
  System.print(Path.abspath(path))
  System.print(Directory.list(path).join("  "))
  return true
}

CMDS = {
  "help": help,
  "build": build,
  "run": run,
  "env": env_cmd,
  "cache": cache,
  "new": new,
}

var initConfig = Fn.new {
  var env = readenv.call()
  var config = {
    "repo_root": env["XOS_REPO_ROOT"],
    "system_path": env["XOS_SYSTEM_PATH"],
    "system_home": env["XOS_SYSTEM_HOME"],
    "host_target": Build.Target.parse(env["XOS_HOST"]),
    "xos_id": env["XOS_ID"],
    "no_cache": env["NO_CACHE"] == "1",
    "cwd": Process.cwd,
    "bootstrap": File.exists("%(env["XOS_ROOT"])/support/bootstrap"),
  }
  Log.debug("Config")
  Log.debug(config)
  Config.init(config)
}

var main = Fn.new { |args|
  StopwatchTree.time("root") {
    Log.debug("xos main")
    var time = Stopwatch.new()

    initConfig.call()
    Log.debug("xos id %(Config.get("xos_id"))")

    var cmd = "help"
    var cmd_args = []

    if (args.count >= 1) {
      cmd = args[0]
      if (CMDS.containsKey(cmd)) {
        cmd_args = args.count > 1 ? args[1..-1] : []
      } else {
        System.print("error: uncrecognized command %(cmd)")
        cmd = "help"
      }
    }

    Log.debug("command=%(cmd) args=%(cmd_args)")
    var ok = CMDS[cmd].call(cmd_args)
    Log.info("done time=%(time.read())ms")

    if (!ok) {
      Log.debug("error: command=%(cmd) args=%(cmd_args) failed")
      Process.exit(1)
    }
  }
  Log.debug("timings: %(StopwatchTree.timerTree)")
  Process.exit(0)
}

main.call(Process.arguments)
