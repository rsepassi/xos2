import "os" for Process, Path, Debug
import "io" for Directory, File
import "log" for Logger
import "hash" for Sha256
import "glob" for Glob
import "timer" for StopwatchTree
import "scheduler" for Executor

import "build/label" for Label
import "build/config" for Config
import "build/cache" for BuildCache
import "build/target" for Target

var Log = Logger.get("xos")

var BuiltinModules_ = {
  "io": 1,
  "os": 1,
  "meta": 1,
  "hash": 1,
  "kv": 1,
  "json": 1,
  "random": 1,
  "scheduler": 1,
  "repl": 1,
  "glob": 1,
  "timer": 1,
  "record": 1,
  "enum": 1,
  "flagparse": 1,
  "log": 1,
  "build/patch": 1,
  "build/label": 1,
  "build/cache": 1,
  "build/config": 1,
  "build/target": 1,
  "build/install_dir": 1,
}

class Build {
  static Target { Target }
  static Label { Label }

  target { _args["target"] }
  opt_mode { _args["opt"] }
  label { _label }
  key { _key }
  workDir { _cache_entry.workDir }
  installDir { _cache_entry.outDir }
  toolCacheDir { Directory.ensure(_cache_entry.toolCacheDir) }

  // File dependencies
  src(path) {
    var out = Path.join([label.srcdir, path])
    _deps["files"][path] = 1
    return out
  }
  srcs(paths) { paths.map { |x| src(x) }.toList }
  srcGlob(pattern) {
    var prefix_strip = label.srcdir.count + 1
    return srcs(Glob.glob(Path.join([label.srcdir, pattern])).map { |x| x[prefix_strip..-1] })
  }
  srcDir(path) {
    var out = path.isEmpty ? label.srcdir : Path.join([label.srcdir, path])
    _deps["directories"][path] = 1
    return out
  }

  // Network dependencies
  fetch(url, hash) {
    var path = _cache.getContent(hash)
    if (path == null) {
      StopwatchTree.time(url) {
        var tmp_dst = _cache_entry.mktmp()
        Log.debug("%(_label) fetching %(url) to %(tmp_dst)")
        var stdio = NormalizeStdio_.call(null)
        if (Config.get("bootstrap")) {
          Process.spawn(["wget", "-q", "--no-check-certificate", url, "-O", tmp_dst], null, stdio)
        } else {
          var args = [Target.host.exeName("curl"), "-s", "-L", url, "-o", tmp_dst]
          Log.debug("%(args)")
          Process.spawn(args, null, stdio)
        }
        var computed_hash = _cache.setContent(tmp_dst)
        if (hash != computed_hash) {
          Fiber.abort("unexpected hash for %(url).\nexpected %(hash)\nfetched  %(computed_hash)")
        }
      }
    } else {
      Log.debug("%(_label) fetching %(url), cached")
    }
    _deps["content"][url] = hash
    return _cache.getContent(hash)
  }

  // Label dependencies
  deptool(label) { deptool(label, []) }
  deptool(label, label_args) { deptool(label, label_args, argsCopy_) }
  deptool(label, label_args, build_args) {
    build_args["target"] = Target.host
    build_args["opt"] = 2
    return dep(label, label_args, build_args)
  }
  dep(label) { dep(label, []) }
  dep(label, label_args) { dep(label, label_args, argsCopy_) }
  dep(label, label_args, build_args) {
    label = Build.Label.parse(label, this.label.srcdir)
    Log.debug("%(_label) depends on %(label)")
    var b = subbuild_({
      "build_args": build_args,
      "label": label,
      "label_args": label_args,
    })
    var out = b.build_()

    _deps["labels"]["%(label)"] = {
      "build_args": build_args,
      "label_args": label_args,
    }
    return out
  }

  // Move src_path into the build's output directory
  installExe(srcs) { install("bin", srcs) }
  installLib(srcs) { install("lib", srcs) }
  installLibConfig(src) { install(Path.join(["lib", "pkgconfig"]), src) }
  installHeader(srcs) { install("include", srcs) }
  installArtifact(srcs) { install("share", srcs) }
  installDir(src_dir) { installDir("", src_dir) }
  installDir(dst_dir, src_dir) {
    var name = Path.basename(src_dir)
    dst_dir = dst_dir.isEmpty ? "%(name)" : Path.join([dst_dir, name])
    var prefix_strip = src_dir.count + 1

    var promises = []
    for (f in Glob.globFiles(Path.join([src_dir, "**", "*"]))) {
      var frel = f[prefix_strip..-1]
      var parts = Path.split(frel)
      var fdst_dir = parts[0] ? Path.join([dst_dir, parts[0]]) : dst_dir
      promises.add(Executor.async { install(fdst_dir, f) })
    }
    Executor.await(promises)
  }
  install(dir, srcs) {
    if (!(srcs is List)) srcs = [srcs]
    var dst_dir = Directory.ensure(dir ? Path.join([installDir, dir]) : installDir)
    var promises = []
    for (src_path in srcs) {
      promises.add(Executor.async {
        var name = Path.basename(src_path)
        var dst_path = Path.join([dst_dir, name])
        Log.debug("installing %(name) to %(dir.isEmpty ? "/" : dir)")

        // If it's a file that lives in this package's temporary working
        // directory, move it into the output directory. Otherwise, copy it.
        var mv = !Path.isAbs(src_path) || src_path.startsWith(workDir)
        if (mv) {
          File.rename(src_path, dst_path)
        } else {
          File.copy(src_path, dst_path)
        }
      })
    }
    Executor.await(promises)
  }

  // Convenience
  glob(pattern) { Glob.glob(pattern) }
  untar(archive) { untar(archive, {}) }
  untar(archive, opts) {
    var tmpdir = _cache_entry.mktmpdir()
    var args = [Target.host.exeName("tar"), "-xf", archive, "-C", tmpdir]
    var strip = opts["strip"] || 1
    if (strip > 0) args.add("--strip-components=%(strip)")
    (opts["exclude"] || []).map { |x| args.addAll(["--exclude", x]) }.toList
    args.addAll(opts["args"] || [])
    Log.debug("unpacking %(archive), %(args)")
    var stdio = NormalizeStdio_.call(null)
    Process.spawn(args, null, stdio)
    return tmpdir
  }
  mktmp() { _cache_entry.mktmp() }
  mktmpdir() { _cache_entry.mktmpdir() }

  systemExport(args) { systemExport(args, null, null) }
  systemExport(args, env) { systemExport(args, env, null) }
  systemExport(args, env, stdio) {
    if (env == null) env = Process.env()
    Log.debug("running system command: %(args)")
    stdio = NormalizeStdio_.call(stdio)
    env["PATH"] = Config.get("system_path")
    Process.spawn(args, env, stdio)
  }

  // Internal use
  // ==========================================================================
  // Within a build process, a Build can always be reconstructed from exactly:
  // * build_args
  // * label
  // * label_args
  construct new_(args) {
    args["label_args"].sort(ByteCompare_)

    _args = args["build_args"]
    _label = args["label"]
    _label_args = args["label_args"]

    var parent = args["parent"]
    _cache = args["cache"] || (parent && parent.cache_) || BuildCache.new()
    _deps = {
      "files": {},
      "directories": {},
      "content": {},
      "labels": {},
      "imports": {},
    }

    // xos cache key
    // * xos id
    // * build arguments
    // * label
    // * label arguments
    // * label build script
    _key = (Fn.new {
      var xos_id = Config.get("xos_id")
      var label_str = "%(_label)"
      var label_args_str = "%(_label_args)"
      var build_args_str = HashStringifyMap_.call(_args)
      var key_inputs = "%(xos_id) %(label_str) %(label_args_str) %(build_args_str)"
      var key = Sha256.hashHex(key_inputs)
      return key
    }).call()

    _cache_entry = _cache.entry(_key)
  }

  toString { "Build %(_label) %(_label_args) %(_args) %(_key)" }
  toJSON {
    return {
      "build_args": _args,
      "label": "%(_label)",
      "label_args": _label_args,
    }
  }

  addImport_(module) {
    if (BuiltinModules_.containsKey(module)) return
    Log.debug("%(_label) depends on module %(module)")
    if (module.startsWith("xos//")) {
      var module_path = Path.join([Config.get("repo_root"), module[5..-1]])
      _deps["imports"][module] = _cache.fileHasher.hash("%(module_path).wren")
    } else {
      b.src("%(module).wren")
    }
  }

  subbuild_(args) {
    args["parent"] = this
    return Build.new_(args)
  }

  cache_ { _cache }

  argsCopy_ {
    var bargs = {}
    for (el in _args) bargs[el.key] = el.value
    return bargs
  }

  build_() { StopwatchTree.time("%(_label)") { build__() } }
  build__() {
    var builder = _label.getBuilder()
    var need_build = needBuild_
    if (!need_build["need"]) {
      Log.info("%(_label) cached")
      return builder.wrap(this)
    }
    Log.info("%(this) building, reason=%(need_build["reason"])")

    _cache_entry.init()

    var cwd = Process.cwd
    Process.chdir(_cache_entry.workDir)
    var out = builder.build(this, _label_args)
    Process.chdir(cwd)

    for (f in _deps["files"].keys) {
      _deps["files"][f] = _cache.fileHasher.hash(Path.join([label.srcdir, f]))
    }
    for (f in _deps["directories"].keys) {
      _deps["directories"][f] = HashDir_.call(f.isEmpty ? label.srcdir : Path.join([label.srcdir, f]), _cache.fileHasher)
    }

    _cache_entry.recordDeps(_deps)
    _cache_entry.done()
    _needBuild = {"need": false}

    Log.info("%(_label) built")
    return out
  }

  needBuild_ {
    // If we haven't built this label before, we need to build it
    if (!_cache_entry.ok) {
      return {
        "need": true,
        "reason": "%(_label) not in cache",
      }
    }

    // If the label is present in the cache, check to see if any of its
    // dynamic dependencies need to be built.
    var need_build = false
    var need_build_reason = ""

    var deps = _cache_entry.deps

    // Import deps
    if (!need_build) {
      var root = Config.get("repo_root")
      for (f in deps["imports"]) {
        var path = Path.join([root, f.key[5..-1]]) + ".wren"
        Log.debug("checking %(path)")
        if (!File.exists(path)) {
          need_build = true
          need_build_reason = "%(f.key) no longer exists"
          break
        }
        if (_cache.fileHasher.hash(path) != f.value) {
          need_build = true
          need_build_reason = "%(f.key) contents changed"
          break
        }
      }
    }

    // File deps
    if (!need_build) {
      for (f in deps["files"]) {
        var path = Path.join([label.srcdir, f.key])
        Log.debug("checking %(path)")
        if (!File.exists(path)) {
          need_build = true
          need_build_reason = "%(f.key) no longer exists"
          break
        }
        if (_cache.fileHasher.hash(path) != f.value) {
          need_build = true
          need_build_reason = "%(f.key) contents changed"
          break
        }
      }
    }

    // Directory deps
    if (!need_build) {
      for (f in deps["directories"]) {
        var path = f.key.isEmpty ? label.srcdir : Path.join([label.srcdir, f.key])
        Log.debug("checking %(path)")
        if (!Directory.exists(path)) {
          need_build = true
          need_build_reason = "%(f.key) no longer exists"
          break
        }
        if (HashDir_.call(path, _cache.fileHasher) != f.value) {
          need_build = true
          need_build_reason = "%(f.key) contents changed"
          break
        }
      }
    }

    // Network deps
    if (!need_build) {
      for (f in deps["content"]) {
        Log.debug("checking %(f.key)")
        if (_cache.getContent(f.value) == null) {
          need_build = true
          need_build_reason = "%(f.key) not in cache"
          break
        }
      }
    }

    // Labels
    if (!need_build) {
      for (f in deps["labels"]) {
        Log.debug("checking %(f.key)")
        var sub_label = f.key
        var sub_args = f.value
        var b = Build.new_({
          "build_args": {
            "target": Target.parse(sub_args["build_args"]["target"]),
            "opt": sub_args["build_args"]["opt"],
          },
          "label": Label.parse(sub_label, label.srcdir),
          "label_args": sub_args["label_args"],
        })

        var sub_need = b.needBuild_
        if (sub_need["need"]) {
          need_build = true
          need_build_reason = "%(f.key) -> %(sub_need["reason"])"
          break
        }
      }
    }

    var out = {
      "need": need_build,
      "reason": need_build_reason,
    }
    return out
  }
}

var ByteCompare_ = Fn.new { |a, b| a.bytes < b.bytes }

var HashStringifyMap_ = Fn.new { |x|
  var items = []
  for (k in x.keys.toList.sort(ByteCompare_)) {
    items.add(k)
    items.add(x[k])
  }
  return "%(items)"
}

var HashDir_ = Fn.new { |x, fhasher|
  var pattern = Path.join([x, "**", "*"])
  var dir_files = Glob.globFiles(pattern).sort(ByteCompare_)
  var hashes = dir_files.map { |x| fhasher.hash(x) }
  return Sha256.hashHex(hashes.join("\n"))
}

var NormalizeStdio_ = Fn.new { |stdio|
  if (Log.level != Log.DEBUG) return stdio
  if (stdio == null) return [null, 1, 2]
  var i = 0
  var new_stdio = []
  for (fd in stdio) {
    if (fd == null) fd = i
    new_stdio.add(fd)
    i = i + 1
  }
  return new_stdio
}
