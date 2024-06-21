import "io" for Directory, File
import "hash" for Sha256
import "random" for Random
import "json" for JSON

import "build/config" for Config

class BuildCache {
  construct new() {
    var dir = Directory.ensure("%(Config.get("repo_root"))/.xos-cache")
		Directory.ensure("%(dir)/content")
		Directory.ensure("%(dir)/pkg")
    _dir = dir
  }

  dir { _dir }

  entry(key) {
    return BuildCacheEntry.new(this, key)
  }

	setContent(src_path) {
    if (!File.exists(src_path)) Fiber.abort("no file exists at %(src_path)")
    var hash = Sha256.hashFileHex(src_path)
		var path = contentPathForHash_(hash)
    File.rename(src_path, path)
    return hash
	}

	getContent(hash) {
		var path = contentPathForHash_(hash)
    if (!File.exists(path)) return null
		return path
	}

  contentPathForHash_(hash) {
    var d = Directory.ensure("%(dir)/content/%(hash[0...2])")
		return "%(d)/%(hash)"
  }

  toolCacheDir(hash) {
    var d = Directory.ensure("%(dir)/tools/%(hash[0...2])")
		return "%(d)/%(hash)"
  }
}

class BuildCacheEntry {
  construct new(cache, key) {
    _cache = cache
    _key = key
    _dir = "%(cache.dir)/pkg/%(key[0...2])/%(key)"
  }

  ok { File.exists("%(_dir)/ok") }
  workdir { "%(_dir)/home" }
  outdir { "%(_dir)/out" }

  clear() {
    Directory.deleteTree(_dir)
  }

  init() {
    Directory.mkdirs(_dir)
    Directory.create(workdir)
    Directory.create(outdir)
  }

  done() {
    File.create("%(_dir)/ok")
    Directory.deleteTree(workdir)
  }

  mktmp() {
    var tmpdir = Directory.ensure("%(workdir)/.xos_tmp")
    return "%(tmpdir)/tmp%(Random.int(999999))"
  }

  mktmpdir() {
    return Directory.ensure("%(workdir)/.xos_tmp/tmp%(Random.int(999999))")
  }

  deps {
    return JSON.parse(File.read("%(_dir)/deps.json"))
  }

  recordDeps(deps) {
    File.write("%(_dir)/deps.json", JSON.stringify(deps))
  }
}
