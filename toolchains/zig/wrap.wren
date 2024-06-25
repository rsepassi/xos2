import "os" for Process
import "io" for File
import "json" for JSON
import "log" for Logger

var Log = Logger.get("zig")

// Install wrapper
class Zig {
  construct new(b) {
    _b = b
    _exe = "%(b.installDir)/zig/%(Zig.exeName(b.target, "zig"))"
  }

  zigExe { _exe }

  static exeName(target, name) {
    return target.os == "windows" ? "%(name).exe" : name
  }

  static libName(target, name) {
    return target.os == "windows" ? "%(name).lib" : "lib%(name).a"
  }

  static dylibName(target, name) {
    return target.os == "windows" ? "%(name).lib" : "lib%(name).so"
  }

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

  cDep(install_dir, libname) {
    return CDep.new(install_dir, libname)
  }

  exec_(b, args) {
    var env = Process.env()
    env["HOME"] = b.workDir
    env["XDG_CACHE_HOME"] = b.toolCacheDir
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

    exec_(b, args)
    return "zig-out"
  }

  buildLib(b, name, opts) {
    var srcs = GetSrcs_.call(opts)
    var args = [
        _exe, "build-lib",
        "-target", "%(b.target)",
        "-O", getOpt_(b, opts),
        "--name", name,
    ]
    FillArgs_.call(b, args, opts, srcs, false)

    exec_(b, args)
    return "%(Process.cwd)/%(Zig.libName(b.target, name))"
  }

  buildExe(b, name, opts) {
    var srcs = GetSrcs_.call(opts)
    var args = [
        _exe, "build-exe",
        "-target", "%(b.target)",
        "-O", getOpt_(b, opts),
        "--name", name,
    ]
    FillArgs_.call(b, args, opts, srcs, true)

    exec_(b, args)
    return "%(Process.cwd)/%(Zig.exeName(b.target, name))"
  }

  libConfig(b, libname) { libConfig(b, libname, {}) }
  libConfig(b, libname, opts) {
    var cflags = ["-I{{root}}/include"]
    var ldflags = opts["ldflags"] || []
    ldflags.add("{{root}}/lib/%(Zig.libName(b.target, libname))")

    var pkgconfig = {
      "Cflags": cflags,
      "Libs": ldflags,
    }
    var fname = "%(libname).pc.json"
    File.write(fname, JSON.stringify(pkgconfig))
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

var FillArgs_ = Fn.new { |b, args, opts, srcs, include_libs|
  // zig flags
  args.addAll(opts["flags"] || [])

  // c flags
  if (opts["c_flags"]) {
    args.add("-cflags")
    args.addAll(opts["c_flags"])

    // sdk
    if (opts["sdk"]) {
      if (b.target.os == "macos") {
        var sdk = b.dep("//sdk/macos")
        var root = sdk.sysroot
        args.addAll([
          "--sysroot=%(root)",
          "-I%(root)/usr/include",
          "-F%(root)/System/Library/Frameworks",
          "-DTARGET_OS_OSX",
        ])
      }
    }

    // determinism
    args.addAll([
      "-Wno-builtin-macro-redefined",
      "-D__DATE__=",
      "-D__TIME__=",
      "-D__TIMESTAMP__=",
    ])

    args.add("--")
  }

  // dependency flags
  var dep_includes = []
  var dep_libs = []

  for (dep in opts["c_deps"] || []) {
    if (dep is CDep) {
      dep_includes.addAll(dep.cflags)
      dep_libs.addAll(dep.libs)
    } else {
      if (dep.includeDir) dep_includes.add("-I%(dep.includeDir)")
      dep_libs.add(dep.lib(dep.build.label.target))
    }
  }

  args.addAll(dep_includes)
  args.addAll(srcs)
  if (include_libs) args.addAll(dep_libs)

  // libc, libc++
  if (opts["libc++"]) args.add("-lc++")
  if (opts["libc"]) args.add("-lc")
}

class CDep {
  construct new(install_dir, libname) {
    var config = JSON.parse(File.read(install_dir.libConfig("%(libname).pc.json")))
    var cflags = config["Cflags"] || []
    var libs = config["Libs"] || []

    cflags = cflags.map { |x| x.replace("{{root}}", install_dir.path) }.toList
    libs = libs.map { |x| x.replace("{{root}}", install_dir.path) }.toList

    _cflags = cflags
    _libs = libs
  }

  cflags { _cflags }
  libs { _libs }
}
