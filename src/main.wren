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
    FlagParser.Flag.new("target", {"default": Build.Target.host, "parser": Build.Target}),
    FlagParser.Flag.new("opt", {"default": "Debug"}),
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
  var label = Build.Label.parse(args[argi], Config.get("cwd"))
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
  var b = Build.new_({
    "build_args": build_flags,
    "label": label,
    "label_args": label_args,
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

var env = Fn.new { |args|
    var vars = [
      "XOS_ROOT",
      "XOS_REPO_ROOT",
      "XOS_SYSTEM_PATH",
      "XOS_HOST",
      "XOS_ID",
      "WREN_MODULES",
      "PATH",
      "LOG",
      "LOG_SCOPES",
    ]

  for (v in vars) {
    System.print("%(v)=%(Process.env(v))")
  }
  return true
}

var cache_clean = Fn.new { |args|
  for (d in Glob.glob(".xos-cache/pkg/*/*/home")) {
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

CMDS = {
  "help": help,
  "build": build,
  "run": run,
  "env": env,
  "cache": cache,
}

var initConfig = Fn.new {
  var config = {
    "repo_root": Process.env("XOS_REPO_ROOT"),
    "host_target": Build.Target.parse(Process.env("XOS_HOST")),
    "xos_id": Process.env("XOS_ID"),
    "cwd": Process.cwd,
    "bootstrap": File.exists("%(Process.env("XOS_ROOT"))/support/bootstrap"),
  }
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
