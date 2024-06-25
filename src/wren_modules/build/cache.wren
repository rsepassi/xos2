import "io" for Directory, File
import "hash" for Sha256
import "json" for JSON

import "build/config" for Config

class BuildCache {
  construct new() {
    var dir = Directory.ensure("%(Config.get("repo_root"))/.xos-cache")
    Directory.ensure("%(dir)/content")
    Directory.ensure("%(dir)/pkg")
    _dir = dir
    if (_cache == null) _cache = {
      "pkg": {},
      "content": {},
    }
    _file_cache = FileHashCache_.new()
  }

  dir { _dir }

  entry(key) {
    if (!_cache["pkg"].containsKey(key)) {
      var e = BuildCacheEntry_.new(this, key)
      _cache["pkg"][key] = e
    }
    return _cache["pkg"][key]
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
    var d = Directory.ensure("%(dir)/content/%(hash[0...2])")
    return "%(d)/%(hash)"
  }

  fileHasher { _file_cache }
}

class BuildCacheEntry_ {
  construct new(cache, key) {
    _cache = cache
    _key = key
    _dir = "%(cache.dir)/pkg/%(key[0...2])/%(key)"
    _tmpi = 0
    _ok = null
    _deps = null
  }

  ok { _ok == null ? _ok = File.exists("%(_dir)/ok") : _ok }
  workDir { "%(_dir)/home" }
  outDir { "%(_dir)/out" }

  clear() {
    Directory.deleteTree(_dir)
  }

  init() {
    Directory.mkdirs(_dir)
    Directory.create(workDir)
    Directory.create(outDir)
  }

  done() {
    File.create("%(_dir)/ok")
    Directory.deleteTree(workDir)
    _ok = true
  }

  mktmp() {
    var tmpdir = Directory.ensure("%(workDir)/.xos_tmp")
    _tmpi = _tmpi + 1
    return "%(tmpdir)/tmp%(_tmpi)"
  }

  mktmpdir() {
    _tmpi = _tmpi + 1
    return Directory.ensure("%(workDir)/.xos_tmp/tmp%(_tmpi)")
  }

  deps {
    if (_deps == null) {
      _deps = JSON.parse(File.read("%(_dir)/deps.json"))
    }
    return _deps
  }

  recordDeps(deps) {
    _deps = deps
    File.write("%(_dir)/deps.json", JSON.stringify(deps))
  }

  toolCacheDir {
    var d = Directory.ensure("%(_cache.dir)/tools/%(_key[0...2])")
    return "%(d)/%(_key)"
  }
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
