import "os" for Process, Path
import "io" for File
import "json" for JSON
import "log" for Logger

import "xos//toolchains/zig/platform" for Platform

var Log = Logger.get("zig")

// Install wrapper
class Zig {
  construct new(dir) {
    _b = dir.build
    _exe = "%(_b.installDir)/zig/%(_b.target.exeName("zig"))"
  }

  zigExe { _exe }

  getPlatform(b, opt) { Platform.get(b, opt) }

  getOpt(opt) { Zig.getOpt(opt) }
  static getOpt(opt) {
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

  getCCOpt(opt) { Zig.getCCOpt(opt) }
  static getCCOpt(opt) {
    var opts = {
      0: 0,
      1: 1,
      2: 2,
      3: 3,
      "s": "s",
      "z": "z",
      "Debug": 0,
      "Safe": 2,
      "Small": "s",
      "Fast": 3,
      "ReleaseSafe": 2,
      "ReleaseFast": 3,
    }
    if (!opts.containsKey(opt)) Fiber.abort("unrecognized optimization mode %(opt)")
    return opts[opt]
  }

  getOpt_(b, opts) { getOpt(opts["opt"] || b.opt_mode) }

  cDep(install_dir, libname) { CDep.create(install_dir, libname) }
  moduleDep(install_dir, modulename) { ModuleDep.create(install_dir, modulename) }

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
      var platform = Platform.get(b, {"sdk": true})
      args.add("-Dsysroot=%(platform.sysroot)")
    }

    exec_(b, args)
    return "zig-out"
  }

  buildLib(b, name, opts) {
    var args = [_exe, "build-lib", "--name", name]
    args.addAll(GetTopLevelArgs_.call(b, opts, false))
    exec_(b, args)
    return "%(Process.cwd)/%(b.target.libName(name))"
  }

  buildExe(b, name, opts) {
    var args = [_exe, "build-exe", "--name", name]
    args.addAll(GetTopLevelArgs_.call(b, opts, true))
    exec_(b, args)
    return "%(Process.cwd)/%(b.target.exeName(name))"
  }

  moduleConfig(b, opts) { moduleConfig(b, b.label.target, opts) }
  moduleConfig(b, module_name, opts) {
    var cdeps = (opts["c_deps"] || []).map { |x| (x is CDep ? x : CDep.create(x)).toJSON }.toList

    var modules = {}
    for (el in opts["modules"] || []) {
      var m = el.value
      m = (m is ModuleDep ? m : ModuleDep.create(m)).toJSON
      modules[el.key] = m
    }

    var mconfig = {
      "root": opts["root"],
      "Cflags": opts["cflags"] || [],
      "Libs": opts["ldflags"] || [],
      "Requires": cdeps,
      "sdk": opts["sdk"],
      "libc": opts["libc"],
      "Modules": modules,
    }
    var fname = "%(module_name).pc.json"
    var json = JSON.stringify(mconfig)
    Log.debug("generating zig module config %(json)")
    File.write(fname, json)
    return fname
  }

  libConfig(b) { libConfig(b, b.label.target, {}) }
  libConfig(b, libname) { libConfig(b, libname, {}) }
  libConfig(b, libname, opts) {
    var cflags = []
    var ldflags = []
    if (!opts["nostdopts"]) {
      cflags.add("-I{{root}}/include")
      ldflags.add("{{root}}/lib/%(b.target.libName(libname))")
    }
    cflags.addAll(opts["cflags"] || [])
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

var GetTopLevelArgs_ = Fn.new { |b, opts, include_libs|
  var opt_mode = Zig.getOpt(b.opt_mode)
  var args = [
    "-target", "%(b.target)",
    "-O", opt_mode,
  ]
  args.addAll(GetArgs_.call(b, opts, include_libs))
  return args
}

var GetArgs_ = Fn.new { |b, opts, include_libs|
  var cargs = GetCArgs_.call(b, opts)
  var args = cargs["args"]

  var module_opts = opts["modules"] || {}
  if (opts["root"]) module_opts["__xosroot__"] = opts["root"]
  var modules = GetModules_.call(b, module_opts)

  var platform = Platform.get(b, cargs["platform_opts"].union(modules["platform_opts"]))
  args.addAll(platform.flags)
  args.addAll(modules["module_args"])

  if (include_libs) {
    args.addAll(cargs["ldargs"])
    args.addAll(modules["ldargs"])
    args.addAll(platform.ldargs)
  }

  return args
}

var CollectModules_ = Fn.new { |all, modules|
  var wrapped = {}
  for (el in modules) {
    if (el.key == "__xosroot__") {
      if (all.containsKey(el.key)) Fiber.abort("duplicate root modules found: %(all["__xosroot"]) and %(el.value)")
      var m = el.value
      m = m is String ? m : (m is ModuleDep ? m : ModuleDep.create(m))
      all[el.key] = m
    } else {
      var m = el.value
      m = m is ModuleDep ? m : ModuleDep.create(m)
      if (all.containsKey(m.key)) continue
      all[m.key] = m
      wrapped[el.key] = m
      CollectModules_.call(all, m.modules)
    }
  }
  return wrapped
}

var GetModules_ = Fn.new { |b, modules|
  // Each module needs a name for -Mname=root
  // Then they need to be tied together with --dep flags

  var all_modules = {}
  var modules_wrapped = CollectModules_.call(all_modules, modules)

  var module_args = []
  var ldargs = []
  var platform_opts = Platform.Opts.new()

  var root_module = all_modules.remove("__xosroot__")
  var root_module_key = "xx"
  if (root_module) {
    if (root_module is String) {
      for (el in modules_wrapped) {
        module_args.addAll(["--dep", "%(el.key)=%(el.value.key)"])
      }
      module_args.add("-Mmain=%(root_module)")
    } else {
      var m = root_module
      root_module_key = m.key
      ldargs.addAll(m.libs)
      module_args.addAll(m.cflags)
      for (el in modules_wrapped) {
        module_args.addAll(["--dep", "%(el.key)=%(el.value.key)"])
      }
      module_args.add("-Mmain=%(m.root)")
      platform_opts = platform_opts.union(m.platformOpts)
    }
  }

  for (el in all_modules) {
    var m = el.value
    if (m.key == root_module_key) continue
    ldargs.addAll(m.libs)
    module_args.addAll(m.cflags)
    for (el2 in m.modules) {
      var dep_key = el2.value.key
      if (dep_key == root_module_key) dep_key = "main"
      module_args.addAll(["--dep", "%(el2.key)=%(dep_key)"])
    }
    module_args.add("-M%(el.key)=%(m.root)")
    platform_opts = platform_opts.union(m.platformOpts)
  }

  return {
    "module_args": module_args,
    "ldargs": ldargs,
    "platform_opts": platform_opts,
  }
}

var GetCArgs_ = Fn.new { |b, opts|
  var platform_opts = Platform.Opts.new()

  // dependency flags
  var dep_includes = []
  var dep_libs = []
  for (dep in opts["c_deps"] || []) {
    if (!(dep is CDep)) dep = CDep.create(dep)
    dep_includes.addAll(dep.cflags)
    dep_libs.addAll(dep.libs)
    platform_opts = platform_opts.union(dep.platformOpts)
  }

  var platform = Platform.get(b, platform_opts)

  var args = []

  // zig flags
  args.add(Zig.getOpt(b.opt_mode) == "Debug" ? "-DDEBUG" : "-DNDEBUG")
  args.addAll(opts["flags"] || [])

  // c flags
  if (opts["c_flags"]) {
    args.add("-cflags")
    args.addAll(opts["c_flags"])
    args.addAll(platform.ccflags)

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
  args.addAll(opts["c_srcs"] || [])

  var ldargs = opts["ldflags"] || []
  ldargs.addAll(dep_libs)

  return {
    "args": args,
    "ldargs": ldargs,
    "platform_opts": Platform.Opts.new({
      "sdk": opts["sdk"],
      "libc": opts["libc"],
      "libc++": opts["libc++"],
    }),
  }
}

class CDep {
  static create(install_dir) { create(install_dir, install_dir.build.label.target) }
  static create(install_dir, libname) { new_(install_dir, libname) }

  construct new_(install_dir, libname) {
    var pc_path = install_dir.libConfig("%(libname).pc.json")
    if (!File.exists(pc_path)) Fiber.abort("no lib config exists for %(install_dir.build.label) at %(pc_path)")
    var f = Fiber.new { JSON.parse(File.read(pc_path)) }
    var config = f.try()
    if (f.error != null) Fiber.abort("could not parse the pc.json for %(install_dir.build.label) %(libname)")

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
    _platform_opts = Platform.Opts.new({
      "sdk": config["sdk"] == true,
      "libc": config["libc"] == true,
      "libc++": config["libc++"] == true,
    })
  }

  cflags { _cflags }
  libs { _libs }
  platformOpts { _platform_opts }

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

class ModuleDep {
  static create(install_dir) { new_(install_dir, install_dir.build.label.target) }
  static create(install_dir, module_name) { new_(install_dir, module_name) }

  construct new_(install_dir, module_name) {
    var pc_path = Path.join([install_dir.path, "zig", "%(module_name).pc.json"])
    if (!File.exists(pc_path)) Fiber.abort("no zig module config exists for %(install_dir.build.label) at %(pc_path)")

    var f = Fiber.new { JSON.parse(File.read(pc_path)) }
    var config = f.try()
    if (f.error != null) Fiber.abort("could not parse the zig pc.json for %(install_dir.build.label) %(module_name)")

    var cflags = config["Cflags"] || []
    var libs = config["Libs"] || []
    var requires = (config["Requires"] || []).map { |x| CDep.fromJSON(install_dir.build, x) }
    for (req in requires) {
      cflags.addAll(req.cflags)
      libs.addAll(req.libs)
    }

    var modules = {}
    for (el in config["Modules"] || []) {
      modules[el.key] = ModuleDep.fromJSON(install_dir.build, el.value)
    }

    _dir = install_dir
    _name = module_name
    _root = config["root"]
    _modules = modules
    _cflags = cflags
    _libs = libs
    _platform_opts = Platform.Opts.new({
      "sdk": config["sdk"] == true,
      "libc": config["libc"] == true,
      "libc++": config["libcpp"] == true,
    })
  }

  name { _name }
  root { _root }
  modules { _modules }
  cflags { _cflags }
  libs { _libs }
  platformOpts { _platform_opts }

  toJSON {
    return {
      "build": _dir.build.toJSON,
      "modulename": _name,
    }
  }

  static fromJSON(b, x) {
    var dir = b.dep(x["build"]["label"], x["build"]["label_args"])
    return ModuleDep.create(dir, x["modulename"])
  }

  key { "%(name)_%(_dir.build.key)" }
}
