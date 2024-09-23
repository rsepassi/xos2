import "meta" for Meta
import "io" for File, Directory
import "os" for Path, Process
import "build/config" for Config
import "build/target" for Target

class RepoManager {
  construct new(cache) {
    var root_repos = {}
    Fiber.new {
      Meta.eval("import \"xos//build\"")
      root_repos = Meta.getModuleVariable("xos//build", "REPOS")
    }.try()

    _cache = cache
    _root_repos = root_repos
    _repos = {
      "local": Repo.new(Config.get("repo_root")),
    }
  }

  translateLocal(dir) {
    if (dir.startsWith(_cache.repoDir)) {
      for (repo in _repos) {
        if (dir.startsWith(repo.value.dir)) return repo.key
      }
      Fiber.abort("cannot identify repo for directory %(dir)")
    }

    if (!dir.startsWith(_repos["local"].dir)) Fiber.abort("cannot identify repo for directory %(dir)")
    return "local"
  }

  get(name) {
    if (_repos.containsKey(name)) return _repos[name]
    if (!_root_repos.containsKey(name)) Fiber.abort("requested repo %(name) but that repo is not registered in REPOS")

    var info = _root_repos[name]
    var dir = fetchRepo_(info["url"], info["hash"])
    var repo = Repo.new(dir)
    _repos[name] = repo

    return repo
  }

  fetchRepo_(url, hash) {
    var dir = _cache.repoDir(hash)
    if (Directory.exists(dir)) return dir

    var archive = _cache.fetch(url, hash)
    var tmpdir = Directory.ensure(dir + "-tmp")
    var args = [Target.host.exeName("tar"), "-xf", archive, "-C", tmpdir, "--strip-components=1"]
    Process.spawn(args, null, [null, 1, 2])
    File.rename(tmpdir, dir)

    return dir
  }
}

class Repo {
  construct new(dir) {
    _dir = dir
  }
  dir { _dir }

  relativePath(src, path) {
    if (src == dir) return path
    if (!src.startsWith(dir)) Fiber.abort("the requested src dir %(src) is not part of the repo rooted at %(dir)")
    src = src[dir.count + 1..-1]
    if (path == null || path.isEmpty) return src
    return Path.join([src, path])
  }

  modulePath(path, module) {
    if (dir == Config.get("repo_root")) {
      return path.isEmpty ? "xos//%(module)" : "xos//%(path)/%(module)"
    }

    var module_dir = dir[Config.get("repo_root").count + 1..-1]

    if (path.isEmpty) {
      return "xos//%(module_dir)/%(module)"
    } else {
      return "xos//%(module_dir)/%(path)/%(module)"
    }
  }
}
