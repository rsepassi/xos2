import "os" for Process
import "io" for File
import "json" for JSON

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

  cDep(install_dir, libname) {
    return CDep.new(install_dir, libname)
  }

  buildLib(b, name, opts) {
    var srcs = GetSrcs_.call(opts)
    var args = [
        _exe, "build-lib",
        "-target", "%(b.target)",
        "-O", getOpt(b.opt_mode),
        "--name", name,
    ]
    FillArgs_.call(args, opts, srcs, false)

    var env = Process.env()
    env["HOME"] = b.workDir
    Process.spawn(args, env, [null, 1, 2])
    return "%(Process.cwd)/%(Zig.libName(b.target, name))"
  }

  buildExe(b, name, opts) {
    var srcs = GetSrcs_.call(opts)
    var args = [
        _exe, "build-exe",
        "-target", "%(b.target)",
        "-O", getOpt(b.opt_mode),
        "--name", name,
    ]
    FillArgs_.call(args, opts, srcs, true)

    var env = Process.env()
    env["HOME"] = b.workDir
    Process.spawn(args, env, [null, 1, 2])
    return "%(Process.cwd)/%(Zig.exeName(b.target, name))"
  }

  libConfig(b, libname) {
    var pkgconfig = {
      "Cflags": ["-I{{root}}/include"],
      "Libs": ["{{root}}/lib/%(Zig.libName(b.target, libname))"],
    }
    var fname = "%(libname).pc"
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

var FillArgs_ = Fn.new { |args, opts, srcs, include_libs|
  args.addAll(opts["flags"] || [])
  if (opts["c_flags"]) {
    args.add("-cflags")
    args.addAll(opts["c_flags"])
    args.add("--")
  }

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

  if (opts["libc"]) {
    args.add("-lc")
  }
}

class CDep {
  construct new(install_dir, libname) {
    var config = JSON.parse(File.read(install_dir.libConfig("%(libname).pc")))
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
