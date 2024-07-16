import "io" for Directory, File
import "os" for Path
import "hash" for Sha256
import "json" for JSON
import "log" for Logger

import "build/config" for Config

var Log = Logger.get("xos")

class BuildCache {
  construct new() {
    var dir = Directory.ensure(Path.join(["%(Config.get("repo_root"))", ".xos-cache"]))
    Directory.ensure(Path.join([dir, "content"]))
    Directory.ensure(Path.join([dir, "label"]))
    _dir = dir
    if (_cache == null) _cache = {
      "label": {},
      "content": {},
    }
    _file_cache = FileHashCache_.new()
  }

  dir { _dir }

  entry(key) {
    if (!_cache["label"].containsKey(key)) {
      var e = BuildCacheEntry_.new(this, key)
      _cache["label"][key] = e
    }
    return _cache["label"][key]
  }

  setContent(src_path) {
    if (!File.exists(src_path)) Fiber.abort("no file exists at %(src_path)")
    var hash = Sha256.hashFileHex(src_path)
    var path = contentPathForHash_(hash)
    File.rename(src_path, path)
    _cache["content"][hash] = path
    return hash
  }

  getContent(hash) {
    if (!_cache["content"].containsKey(hash)) {
      var path = contentPathForHash_(hash)
      if (!File.exists(path)) return null
      _cache["content"][hash] = path
      return path
    }
    return _cache["content"][hash]
  }

  contentPathForHash_(hash) {
    var d = Directory.ensure(Path.join([dir, "content", hash[0...2]]))
    return Path.join([d, hash])
  }

  fileHasher { _file_cache }
}

class BuildCacheEntry_ {
  construct new(cache, key) {
    _cache = cache
    _key = key
    _dir = Path.join([cache.dir, "label", key[0...2], key])
    _tmpi = 0
    _ok = null
    _deps = null
  }

  ok {
    if (_ok == null) {
      _ok = File.exists(Path.join([_dir, "ok"]))
      if (Config.get("no_cache")) {
        Log.info("Config.no_cache enabled, disabling cache for %(_key)")
        _ok = false
      }
    }
    return _ok
  }

  workDir { Path.join([_dir, "home"]) }
  outDir { Path.join([_dir, "out"]) }

  init() {
    Directory.deleteTree(_dir)
    _tmpi = 0
    _ok = null
    _deps = null

    Directory.mkdirs(_dir)
    Directory.create(workDir)
    Directory.create(outDir)
  }

  done() {
    File.create(Path.join([_dir, "ok"]))
    Directory.deleteTree(workDir)
    _ok = true
    _deps = null
  }

  mktmp() {
    var tmpdir = Directory.ensure(Path.join([workDir, ".xos_tmp"]))
    _tmpi = _tmpi + 1
    return Path.join([tmpdir, "tmp%(_tmpi)"])
  }

  mktmpdir() {
    _tmpi = _tmpi + 1
    return Directory.ensure(Path.join([workDir, ".xos_tmp", "tmp%(_tmpi)"]))
  }

  info {
    if (_deps == null) {
      _deps = JSON.parse(File.read(infoPath_))
    }
    return _deps
  }

  recordInfo(info) {
    File.write(infoPath_, JSON.stringify(info))
  }

  toolCacheDir { Path.join([_cache.dir, "tools", _key[0...2], _key]) }

  infoPath_ { Path.join([_dir, "info.json"]) }
}

class FileHashCache_ {
  construct new() {
    _cache = {}
  }

  hash(path) {
    if (!_cache.containsKey(path)) {
      var hash = Sha256.hashFileHex(path)
      _cache[path] = hash
      return hash
    }
    return _cache[path]
  }
}
