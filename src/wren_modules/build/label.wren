// A Label represents a single build target
// It manages identifying the label source directory, build script, and build
// function/class.

import "log" for Logger
import "meta" for Meta
import "os" for Process, Path
import "io" for Directory, File

import "build/config" for Config
import "build/install_dir" for InstallDir

var Log = Logger.get("xos")

class Label {
  repo { _repo }
  path { _path }
  target { _target }

  toString { "@%(repo)//%(_path):%(_target)" }

  srcdir { _path.isEmpty ? repoPath : Path.join([repoPath, _path]) }
  repoPath { Label.repoPath(repo) }
  modulePath { Path.join([srcdir, "build.wren"]) }
  moduleName { _path.isEmpty ? "xos//build" : "xos//%(_path)/build" }

  static parse(label, label_src_dir) {
    // Valid forms:
    //   @repo//path
    //   @repo//path:target
    //   //path
    //   //path:target
    //   path
    //   path:target
    //   :target

    var parts = Label.parseLabel_(label)
    var repo = parts[0] || "local"
    var path = parts[1]
    var target = parts[2] || Path.basename(path).replace("-", "_")

    if (path.startsWith("//")) {
      path = path[2..-1]
    } else {
      // Make the path relative to the repo root
      var root = Label.repoPath(repo)
      if (!label_src_dir.startsWith(root)) Fiber.abort("The label %(label) is referenced from %(label_src_dir) which doesn't seem to be within the repository rooted at %(root)")
      if (label_src_dir != root) {
        label_src_dir = label_src_dir[root.count + 1..-1]
        if (path == null || path.isEmpty) {
          path = label_src_dir
        } else {
          path = Path.join([label_src_dir, path])
        }
      }
    }

    return Label.new_(repo, path, target)
  }

  getBuilder() {
    if (_builder == null) {
      if (_repo != "local") Fiber.abort("repo unimplemented, specified in %(this)")

      var capture = Meta.captureImports {
        Meta.eval("import \"%(moduleName)\"")
      }
      capture.call()

      var f = Fiber.new {
        return Meta.getModuleVariable(moduleName, _target)
      }
      var fn = f.try()
      if (f.error != null) Fiber.abort("unable to load variable '%(_target)' from %(modulePath)")
      _builder = Builder.new(fn, capture.imports)
    }
    return _builder
  }

  static repoPath(repo) {
    if (repo != "local") Fiber.abort("repo unimplemented")
    return Config.get("repo_root")
  }

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

class Builder {
  construct new(fn, imports) {
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
        Fiber.abort("error: wrapping the output of %(this) failed: %(f.error)")
      }
    }
    return wrap
  }
}
