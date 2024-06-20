import "os" for Process, Path
import "io" for Directory, File
import "log" for Logger
import "hash" for Sha256
import "kv" for KV
import "random" for Random
import "glob" for Glob

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
  workDir { _cache_entry.workdir }
  installDir { _cache_entry.outdir }

  // File dependencies
  src(path) {
    var out = "%(label.srcdir)/%(path)"
    _deps["files"][path] = 1
    return out
  }
  srcs(paths) {
    return paths.map { |x| src(x) }.toList
  }
  srcGlob(pattern) {
    return srcs(Glob.glob("%(label.srcdir)/%(pattern)"))
  }

  // Network dependencies
  fetch(url, hash) {
    var path = _cache.getContent(hash)
    if (path == null) {
      Log.debug("%(_label) fetching %(url)")

      var tmp_dst = _cache_entry.mktmp()
      Process.spawn(["wget", url, "-O", tmp_dst], null)
      var computed_hash = _cache.setContent(tmp_dst)
      if (hash != computed_hash) {
        Fiber.abort("unexpected hash for %(url).\nexpected %(hash)\nfetched  %(computed_hash)")
      }
    } else {
      Log.debug("%(_label) fetching %(url), cached")
    }
    _deps["fetches"][url] = hash
    return path
  }

  // Label dependencies
  deptool(label) {
    return deptool(label, [])
  }
  deptool(label, label_args) {
    return deptool(label, label_args, argsCopy_)
  }
  deptool(label, label_args, build_args) {
    build_args["target"] = Target.host
    return dep(label, label_args, build_args)
  }
  dep(label) {
    return dep(label, [])
  }
  dep(label, label_args) {
    return dep(label, label_args, argsCopy_)
  }
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
  install(dir, src_path) {
    var name = Path.basename(src_path)
    var dst_dir = Directory.ensure(dir ? "%(installDir)/%(dir)" : installDir)
    var dst_path = "%(dst_dir)/%(name)"
    src_path = Path.abspath(src_path)
    Log.debug("installing %(dst_path)")
    File.rename(src_path, dst_path)
  }

  // Internal use
  // ==========================================================================
  construct new_(args) {
    args["label_args"].sort()

    _parent = args["parent"]
    _args = args["build_args"]
    _label = args["label"]
    _label_args = args["label_args"]
    _cache = args["cache"] || (_parent && _parent.cache_) || BuildCache.new()
    _deps = {
      "files": {},
      "fetches": {},
      "labels": {},
    }

    _key = (Fn.new {
      var xos_id = Config.get("xos_id")
      var label_str = "%(_label)"
      var label_args_str = "%(_label_args)"
      var build_args_str = HashStringifyMap.call(_args)
      var build_script_hash = Sha256.hashHex(File.read(_label.modulePath))
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

  build_() {
    Log.debug("%(this)")

    var builder = _label.getBuilder()
    var need_build = needBuild_
    if (!need_build["need"]) {
      Log.info("not building %(_label), cached")
      return builder.wrap(this)
    }
    Log.info("building %(_label), reason=%(need_build["reason"])")

    _cache_entry.clear()
    _cache_entry.init()

    var cwd = Process.cwd
    Process.chdir(_cache_entry.workdir)
    var out = builder.build(this, _label_args)
    Process.chdir(cwd)

    for (f in _deps["files"].keys) {
      _deps["files"][f] = Sha256.hashHex(File.read("%(label.srcdir)/%(f)"))
    }

    _cache_entry.recordDeps(_deps)
    _cache_entry.done()
    _needBuild = {"need": false}

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
        if (!File.exists(path)) {
          need_build = true
          need_build_reason = "%(f.key) no longer exists"
          break
        }
        if (Sha256.hashHex(File.read(path)) != f.value) {
          need_build = true
          need_build_reason = "%(f.key) contents changed"
          break
        }
      }
    }

    // Network deps
    if (!need_build) {
      for (f in deps["fetches"]) {
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

    return {
      "need": need_build,
      "reason": need_build_reason,
    }
  }
}

var byteCompare = Fn.new { |a, b|
  // a < b by bytes
  a = a.bytes
  b = b.bytes
  var len = a.count.min(b.count)
  for (i in 0..len) {
    if (a[i] < b[i]) return true
    if (a[i] > b[i]) return false
  }
  if (a.count < b.count) return true
  return false
}

var HashStringifyMap = Fn.new { |x|
  var items = []
  for (k in x.keys.toList.sort(byteCompare)) {
    items.add(k)
    items.add(x[k])
  }
  return "%(items)"
}
