import "os" for Process, Path
import "io" for Directory, File
import "log" for Logger
import "hash" for Sha256
import "kv" for KV
import "random" for Random
import "glob" for Glob
import "timer" for StopwatchTree

import "build/label" for Label
import "build/config" for Config
import "build/cache" for BuildCache
import "build/target" for Target

var Log = Logger.get("xos")

class Build {
  static Target { Target }
  static Label { Label }

  target { _args["target"] }
  opt_mode { _args["opt"] }
  label { _label }
  key { _key }
  workDir { _cache_entry.workdir }
  installDir { _cache_entry.outdir }
  toolCacheDir { _cache.toolCacheDir(_key) }

  // File dependencies
  src(path) {
    var out = "%(label.srcdir)/%(path)"
    _deps["files"][path] = 1
    return out
  }
  srcs(paths) { paths.map { |x| src(x) }.toList }
  srcGlob(pattern) {
    var prefix_strip = label.srcdir.count + 1
    return srcs(Glob.glob("%(label.srcdir)/%(pattern)").map { |x| x[prefix_strip..-1] })
  }
  srcDir(path) {
    var out = path.isEmpty ? label.srcdir : "%(label.srcdir)/%(path)"
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
        if (Config.get("bootstrap")) {
          Process.spawn(["wget", "-q", "--no-check-certificate", url, "-O", tmp_dst])
        } else {
          Process.spawn(["curl", "-s", "-L", url, "-O", tmp_dst])
        }
        var computed_hash = _cache.setContent(tmp_dst)
        if (hash != computed_hash) {
          Fiber.abort("unexpected hash for %(url).\nexpected %(hash)\nfetched  %(computed_hash)")
        }
      }
    } else {
      Log.debug("%(_label) fetching %(url), cached")
    }
    _deps["fetches"][url] = hash
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
  installLibConfig(src) { install("lib/pkgconfig", src) }
  installHeader(srcs) { install("include", srcs) }
  installArtifact(srcs) { install("share", srcs) }
  installDir(src_dir) { installDir("", src_dir) }
  installDir(dst_dir, src_dir) {
    var name = Path.basename(src_dir)
    dst_dir = dst_dir.isEmpty ? "%(name)" : "%(dst_dir)/%(name)"
    var prefix_strip = src_dir.count + 1
    for (f in Glob.globFiles("%(src_dir)/**/*")) {
      var frel = f[prefix_strip..-1]
      var parts = Path.split(frel)
      var fdst_dir = parts[0] ? "%(dst_dir)/%(parts[0])" : dst_dir
      install(fdst_dir, f)
    }
  }
  install(dir, srcs) {
    if (!(srcs is List)) srcs = [srcs]
    var dst_dir = Directory.ensure(dir ? "%(installDir)/%(dir)" : installDir)
    for (src_path in srcs) {
      var name = Path.basename(src_path)
      var dst_path = "%(dst_dir)/%(name)"
      Log.debug("installing %(name) to %(dir.isEmpty ? "/" : dir)")

      var mv = !Path.isAbs(src_path) || src_path.startsWith(workDir)
      if (mv) {
        File.rename(src_path, dst_path)
      } else {
        File.copy(src_path, dst_path)
      }
    }
  }

  // Convenience
  glob(pattern) { Glob.glob(pattern) }
  untar(archive) { untar(archive, {}) }
  untar(archive, opts) {
    var tmpdir = _cache_entry.mktmpdir()
    Log.debug("unpacking %(archive)")
    var strip = opts["strip"] || 1
    Process.spawn(["tar", "xf", archive, "--strip-components=%(strip)", "-C", tmpdir], null)
    return tmpdir
  }

  // Internal use
  // ==========================================================================
  construct new_(args) {
    args["label_args"].sort(ByteCompare)

    _parent = args["parent"]
    _args = args["build_args"]
    _label = args["label"]
    _label_args = args["label_args"]
    _cache = args["cache"] || (_parent && _parent.cache_) || BuildCache.new()
    _deps = {
      "files": {},
      "directories": {},
      "fetches": {},
      "labels": {},
    }

    // xos cache key
    // * xos id
    // * label
    // * label arguments
    // * label build script
    // * build arguments
    _key = (Fn.new {
      var xos_id = Config.get("xos_id")
      var label_str = "%(_label)"
      var label_args_str = "%(_label_args)"
      var build_args_str = HashStringifyMap.call(_args)
      var build_script_hash = Sha256.hashFileHex(_label.modulePath)
      var key_inputs = "%(xos_id) %(label_str) %(label_args_str) %(build_args_str) %(build_script_hash)"
      var key = Sha256.hashHex(key_inputs)
      return key
    }).call()

    _cache_entry = _cache.entry(_key)
  }

  toString { "Build %(_label) %(_label_args) %(_args) %(_key)" }

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

    _cache_entry.clear()
    _cache_entry.init()

    var cwd = Process.cwd
    Process.chdir(_cache_entry.workdir)
    var out = builder.build(this, _label_args)
    Process.chdir(cwd)

    for (f in _deps["files"].keys) {
      _deps["files"][f] = Sha256.hashFileHex("%(label.srcdir)/%(f)")
    }
    for (f in _deps["directories"].keys) {
      _deps["directories"][f] = HashDir.call(f.isEmpty ? label.srcdir : "%(label.srcdir)/%(f)")
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

    // File deps
    if (!need_build) {
      for (f in deps["files"]) {
        var path = "%(label.srcdir)/%(f.key)"
        Log.debug("checking %(path)")
        if (!File.exists(path)) {
          need_build = true
          need_build_reason = "%(f.key) no longer exists"
          break
        }
        if (Sha256.hashFileHex(path) != f.value) {
          need_build = true
          need_build_reason = "%(f.key) contents changed"
          break
        }
      }
    }

    // Directory deps
    if (!need_build) {
      for (f in deps["directories"]) {
        var path = f.key.isEmpty ? label.srcdir : "%(label.srcdir)/%(f.key)"
        Log.debug("checking %(path)")
        if (!Directory.exists(path)) {
          need_build = true
          need_build_reason = "%(f.key) no longer exists"
          break
        }
        if (HashDir.call(path) != f.value) {
          need_build = true
          need_build_reason = "%(f.key) contents changed"
          break
        }
      }
    }

    // Network deps
    if (!need_build) {
      for (f in deps["fetches"]) {
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

    if (!need_build && Process.env("NO_CACHE") == "1") {
      need_build = true
      need_build_reason = "NO_CACHE set"
    }

    var out = {
      "need": need_build,
      "reason": need_build_reason,
    }
    return out
  }
}

var ByteCompare = Fn.new { |a, b|
  // a < b by bytes
  a = a.bytes
  b = b.bytes
  var len = a.count.min(b.count)
  for (i in 0...len) {
    if (a[i] < b[i]) return true
    if (a[i] > b[i]) return false
  }
  if (a.count < b.count) return true
  return false
}

var HashStringifyMap = Fn.new { |x|
  var items = []
  for (k in x.keys.toList.sort(ByteCompare)) {
    items.add(k)
    items.add(x[k])
  }
  return "%(items)"
}

var HashDir = Fn.new { |x|
  var dir_files = Glob.globFiles("%(x)/**/*").sort(ByteCompare)
  var hashes = dir_files.map { |x| Sha256.hashFileHex(x) }
  return Sha256.hashHex(hashes.join("\n"))
}
