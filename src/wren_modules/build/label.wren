// A Label represents a single build target
// It manages identifying the label source directory, build script, and build
// function/class.

import "log" for Logger
import "meta" for Meta
import "os" for Process, Path
import "io" for Directory, File

import "build/config" for Config
import "build/install_dir" for InstallDir
import "build/repo" for RepoManager

var Log = Logger.get("xos")

class Label {
  repo { _repo }
  path { _path }
  target { _target }

  toString { "@%(repo)//%(_path):%(_target)" }

  srcdir { _path.isEmpty ? repoPath_ : Path.join([repoPath_, _path]) }
  modulePath { Path.join([srcdir, "build.wren"]) }

  static parse(label, label_src_dir, cache) {
    if (__repos == null) __repos = RepoManager.new(cache)

    // Valid forms:
    //   @repo//path
    //   @repo//path:target
    //   //path
    //   //path:target
    //   path
    //   path:target
    //   :target

    var parts = Label.parseLabel_(label)
    var repo = parts[0] || __repos.translateLocal(label_src_dir)
    var path = parts[1]
    var target = parts[2] || Path.basename(path).replace("-", "_")

    if (path.startsWith("//")) {
      path = path[2..-1]
    } else {
      // Make the path relative to the repo root
      var repo = __repos.get(repo)
      if (!label_src_dir.startsWith(repo.dir)) Fiber.abort("The label %(label) is referenced from %(label_src_dir) which doesn't seem to be within the repository rooted at %(repo.dir)")
      path = repo.relativePath(label_src_dir, path)
    }

    return Label.new_(repo, path, target)
  }

  getBuilder() {
    if (_builder == null) {
      var repo = __repos.get(_repo)

      var capture = Meta.captureImports {
        Meta.eval("import \"%(moduleName_)\"")
      }
      capture.call()

      var f = Fiber.new {
        return Meta.getModuleVariable(moduleName_, _target)
      }
      var fn = f.try()
      if (f.error != null) Fiber.abort("unable to load variable '%(_target)' from %(modulePath)")
      _builder = Builder_.new(this, fn, capture.imports)
    }
    return _builder
  }

  static repoPath_(repo) { __repos.get(repo).dir }
  repoPath_ { Label.repoPath_(repo) }
  moduleName_ { __repos.get(_repo).modulePath(_path, "build") }

  static parseLabel_(s) {
    var repo = null
    if (s[0] == "@") {
      var repo_end = s.indexOf("//")
      if (repo_end == -1) Fiber.abort("label with repo specified is missing path, e.g. @foo//bar. got %(s)")
      repo = s[1...repo_end]
      s = s[repo_end..-1]
    }

    var path = null
    var target = null
    var path_end = s.indexOf(":")
    if (path_end == -1) {
      path = s
    } else {
      path = s[0...path_end]
      target = s[path_end + 1..-1]
    }

    if (path.isEmpty && (target == null || target.isEmpty)) {
      Fiber.abort("label must specify a path and/or target, got %(s)")
    }

    return [repo, path, target]
  }

  construct new_(repo, path, target) {
    _repo = repo
    _path = path
    _target = target
    _builder = null
  }
}

class Builder_ {
  construct new(label, fn, imports) {
    _label = label
    _fn = fn
    _imports = imports
  }

  build(b, args) {
    var capture = Meta.captureImports {
      _fn.call(b, args)
    }
    capture.call()
    for (m in _imports) b.addImport_(m)
    for (m in capture.imports) b.addImport_(m)
    return wrap(b)
  }

  wrap(b) {
    var dir = InstallDir.new(b)
    var f = Fiber.new {
      return _fn.wrap(dir)
    }
    var wrap = f.try()
    if (f.error != null) {
      if (f.error.endsWith("does not implement 'wrap(_)'.")) {
        return dir
      } else {
        Fiber.abort("error: wrapping the output of %(_label) failed: %(f.error)")
      }
    }
    return wrap
  }
}
