import "os" for Process
import "io" for File
import "json" for JSON
import "log" for Logger

var Log = Logger.get("zig")

// Install wrapper
class Zig {
  construct new(dir) {
    _b = dir.build
    _exe = "%(_b.installDir)/zig/%(_b.target.exeName("zig"))"
  }

  zigExe { _exe }

  getOpt(opt) {
    var opts = {
      0: "Debug",
      1: "Debug",
      2: "ReleaseSafe",
      3: "ReleaseFast",
      "s": "ReleaseSmall",
      "z": "ReleaseSmall",
      "Debug": "Debug",
      "Safe": "ReleaseSafe",
      "Small": "ReleaseSmall",
      "Fast": "ReleaseFast",
      "ReleaseSafe": "ReleaseSafe",
      "ReleaseFast": "ReleaseFast",
    }
    if (!opts.containsKey(opt)) Fiber.abort("unrecognized optimization mode %(opt)")
    return opts[opt]
  }

  getOpt_(b, opts) { getOpt(opts["opt"] || b.opt_mode) }

  cDep(install_dir, libname) { CDep.create(install_dir, libname) }

  exec_(b, args) {
    var env = Process.env()
    env["HOME"] = b.workDir
    env["LOCALAPPDATA"] = b.workDir
    env["TMP"] = b.workDir
    env["ZIG_GLOBAL_CACHE_DIR"] = b.toolCacheDir
    Log.debug(args)
    Process.spawn(args, env, [null, 1, 2])
  }

  build(b, opts) {
    var args = [
      _exe, "build",
    ]
    var defaults = [
      "-Dtarget=%(b.target)",
      "-Doptimize=%(getOpt_(b, opts))",
    ]
    if (!opts["nostdopts"]) args.addAll(defaults)
    if (opts["args"]) args.addAll(opts["args"])
    if (opts["sysroot"]) {
      var platform = GetPlatform_.call(b, {"sdk": true})
      args.add("-Dsysroot=%(platform.sysroot)")
    }

    exec_(b, args)
    return "zig-out"
  }

  buildLib(b, name, opts) {
    var srcs = GetSrcs_.call(opts)
    var opt_mode = getOpt_(b, opts)
    var args = [
        _exe, "build-lib",
        "-target", "%(b.target)",
        "-O", opt_mode,
        "--name", name,
    ]
    FillArgs_.call(b, args, opts, srcs, false, opt_mode)

    exec_(b, args)
    return "%(Process.cwd)/%(b.target.libName(name))"
  }

  buildExe(b, name, opts) {
    var srcs = GetSrcs_.call(opts)
    var opt_mode = getOpt_(b, opts)
    var args = [
        _exe, "build-exe",
        "-target", "%(b.target)",
        "-O", opt_mode,
        "--name", name,
    ]
    FillArgs_.call(b, args, opts, srcs, true, opt_mode)

    exec_(b, args)
    return "%(Process.cwd)/%(b.target.exeName(name))"
  }

  libConfig(b) { libConfig(b, b.label.target, {}) }
  libConfig(b, libname) { libConfig(b, libname, {}) }
  libConfig(b, libname, opts) {
    var cflags = ["-I{{root}}/include"]
    var ldflags = ["{{root}}/lib/%(b.target.libName(libname))"]
    ldflags.addAll(opts["ldflags"] || [])

    var deps = (opts["deps"] || []).map { |x| (x is CDep ? x : CDep.create(x)).toJSON }.toList
    Log.debug("generating libconfig %(deps)")
    var pkgconfig = {
      "Cflags": cflags,
      "Libs": ldflags,
      "Requires": deps,
      "sdk": opts["sdk"],
      "libc": opts["libc"],
    }
    var fname = "%(libname).pc.json"
    var json = JSON.stringify(pkgconfig)
    Log.debug("generating libconfig %(json)")
    File.write(fname, json)
    return fname
  }

}

var GetSrcs_ = Fn.new { |opts|
  var srcs = []

  var root = opts["root"]
  if (root) srcs.add(root)

  var csrcs = opts["c_srcs"]
  if (csrcs) {
    if (!(csrcs is List)) Fiber.abort("c_srcs must be a list")
    srcs.addAll(csrcs)
  }

  if (srcs.isEmpty) Fiber.abort("must provide srcs, either root or c_srcs")
  return srcs
}

class Platform {
  construct new(b, opts) {
    _b = b
    _opts = opts
  }
  flags { [] }
  cflags { [] }
  sysroot { "" }
  libflags {
    var flags = []
    if (_opts["libc++"]) flags.add("-lc++")
    if (_opts["libc"]) flags.add("-lc")
    return flags
  }
}

class FreeBSD is Platform {
  construct new(b, opts) {
    _dir = b.dep("//sdk/freebsd")
    _opts = opts
    super(b, opts)
  }

  sysroot { "%(_dir.path)/sdk" }

  flags {
    return [
      "--libc", "%(sysroot)/libc.txt",
      "--sysroot", sysroot,
    ]
  }
}

class MacOS is Platform {
  construct new(b, opts) {
    _dir = b.dep("//sdk/macos")
    _opts = opts
    super(b, opts)
  }

  sysroot { "%(_dir.path)/sdk" }

  flags {
    return [
      "--libc", "%(sysroot)/libc.txt",
      "-F%(sysroot)/System/Library/Frameworks",
    ]
  }
}

var GetPlatform_ = Fn.new { |b, opts|
  var os = b.target.os
  if (os == "freebsd") {
    return FreeBSD.new(b, opts)
  } else if (os == "macos" && opts["sdk"]) {
    return MacOS.new(b, opts)
  } else {
    return Platform.new(b, opts)
  }
}

var FillArgs_ = Fn.new { |b, args, opts, srcs, include_libs, opt_mode|
  if (opt_mode == "Debug") {
    args.add("-DDEBUG")
  } else {
    args.add("-DNDEBUG")
  }

  // dependency flags
  var dep_includes = []
  var dep_libs = []
  for (dep in opts["c_deps"] || []) {
    if (!(dep is CDep)) dep = CDep.create(dep)
    dep_includes.addAll(dep.cflags)
    dep_libs.addAll(dep.libs)
    if (dep.sdk) opts["sdk"] = true
    if (dep.libc) opts["libc"] = true
    if (dep.libcpp) opts["libc++"] = true
  }

  var platform = GetPlatform_.call(b, opts)

  // zig flags
  args.addAll(opts["flags"] || [])

  // c flags
  if (opts["c_flags"]) {
    args.add("-cflags")
    args.addAll(opts["c_flags"])

    args.addAll(platform.cflags)

    // determinism
    args.addAll([
      "-Wno-builtin-macro-redefined",
      "-D__DATE__=",
      "-D__TIME__=",
      "-D__TIMESTAMP__=",
    ])

    args.add("--")
  }

  args.addAll(dep_includes)
  args.addAll(platform.flags)

  args.addAll(srcs)
  args.addAll(opts["ldflags"] || [])
  if (include_libs) args.addAll(dep_libs)

  args.addAll(platform.libflags)
}

class CDep {
  static create(install_dir) { create(install_dir, install_dir.build.label.target) }
  static create(install_dir, libname) { new_(install_dir, libname) }

  construct new_(install_dir, libname) {
    var config = JSON.parse(File.read(install_dir.libConfig("%(libname).pc.json")))
    var cflags = config["Cflags"] || []
    var libs = config["Libs"] || []
    var requires = (config["Requires"] || []).map { |x| CDep.fromJSON(install_dir.build, x) }

    for (req in requires) {
      cflags.addAll(req.cflags)
      libs.addAll(req.libs)
    }

    _dir = install_dir
    _libname = libname

    _cflags = cflags.map { |x| x.replace("{{root}}", install_dir.path) }.toList
    _libs = libs.map { |x| x.replace("{{root}}", install_dir.path) }.toList
    _sdk = config["sdk"] == true
    _libc = config["libc"] == true
    _libcpp = config["libc++"] == true
  }

  cflags { _cflags }
  libs { _libs }
  libc { _libc }
  libcpp { _libcpp }
  sdk { _sdk }

  toJSON {
    return {
      "build": _dir.build.toJSON,
      "libname": _libname,
    }
  }

  static fromJSON(b, x) {
    var dir = b.dep(x["build"]["label"], x["build"]["label_args"])
    return CDep.create(dir, x["libname"])
  }
}
