import "scheduler" for Scheduler

class Platform {
  foreign static homePath
  foreign static isPosix
  foreign static name

  static isWindows { name == "Windows" }
}

class Process {
  // TODO: This will need to be smarter when wren supports CLI options.
  static arguments { allArguments.count >= 2 ? allArguments[2..-1] : [] }

  foreign static allArguments
  foreign static pid
  foreign static ppid
  foreign static version
  foreign static exit(code)
  foreign static env(name)
  foreign static env()
  foreign static chdir(path)

  static cwd { cwd_.replace("\\", "/") }

  static pathJoin(parts) { parts.join(Platform.isWindows ? ";" : ":") }

  static spawn(args) { spawn(args, null, null) }
  static spawn(args, env) { spawn(args, env, null) }
  static spawn(args, env, stdio) {
    var env_flat = null
    if (env != null) {
      if (!(env is Map)) Fiber.abort("env must be a Map, got %(env)")
      env_flat = List.filled(env.count, 0)
      var i = 0
      for (el in env) {
        env_flat[i] = "%(el.key)=%(el.value)"
        i = i + 1
      }
    }

    if (stdio == null) stdio = [-1, -1, -1]
    if (stdio.count != 3) Fiber.abort("stdio specification must include an entry for stdin, stdout, and stderr, but got %(stdio.count) entries")
    stdio = stdio.map { |x|
      if (x == null) return -1
      if (!(x is Num)) Fiber.abort("stdio entries must be null or an integer fd, got %(x)")
      return x
    }.toList

    Scheduler.await_ { spawn_(args, env_flat, stdio[0], stdio[1], stdio[2], Fiber.current) }
  }

  foreign static spawn_(args, env, stdin, stdout, stderr, fiber)
  foreign static cwd_
}

class Path {
  static sep { "/" }

  static isSep(c) {
    if (c == "/") return true
    if (Platform.isWindows && (c == "/" || c == "\\")) return true
    return false
  }

  static normsep(p) { Platform.isWindows ? p.replace("\\", "/") : p }

  static isAbs(p) {
    if (p.isEmpty) return false
    if (Platform.isWindows) {
      if (p.count >= 3 && p[1] == ":" && isSep(p[2])) return true
    }
    return isSep(p[0])
  }

  static abspath(p) {
    if (isAbs(p)) return p
    return normpath(join([Process.cwd, p]))
  }

  static join(paths) {
    var x = []
    for (p in paths) {
      if (p.isEmpty) continue
      if (!x.isEmpty && isAbs(p)) Fiber.abort("only the first path in a join sequence can be an absolute path, got %(p)")
      x.add(p)
    }
    return x.join(sep)
  }

  static normpath(p) {
    var isabs = isAbs(p)
    var parts = p.split(sep)
    var normparts = []
    for (part in parts) {
      if (part.isEmpty || part == ".") continue
      if (part == "..") {
        if (normparts.isEmpty || normparts[-1] == "..") {
          normparts.add(part)
        } else {
          normparts.removeAt(-1)
        }
        continue
      }
      normparts.add(part)
    }

    var start = isabs ? sep : ""
    return start + normparts.join(sep)
  }

  static split(p) {
    if (p.isEmpty) return ["", ""]
    var j = null
    for (i in (p.count - 1)..0) {
      if (isSep(p[i])) {
        j = i
        break
      }
    }
    if (j == null) {
      return ["", p]
    }
    var tail = p[j+1..-1]
    var head = p[0...j]
    return [head, tail]
  }

  static basename(p) {
    return split(p)[1]
  }

  static dirname(p) {
    return split(p)[0]
  }

  static realPath(path) {
    return normsep(Scheduler.await_ { realPath_(path, Fiber.current) })
  }

  static isSymlink(path) {
    if (!isAbs(path)) path = abspath(path)
    return realPath(path) != path
  }

  static readLink(path) {
    return normsep(Scheduler.await_ { readLink_(path, Fiber.current) })
  }

  foreign static realPath_(path, fiber)
  foreign static readLink_(path, fiber)
}

class Debug {
  foreign static debug(x)
  foreign static debug(x1, x2)
  foreign static debug(x1, x2, x3)
  foreign static debug(x1, x2, x3, x4)
  foreign static debug(x1, x2, x3, x4, x5)
  foreign static debug(x1, x2, x3, x4, x5, x6)
  foreign static debug(x1, x2, x3, x4, x5, x6, x7)
  foreign static debug(x1, x2, x3, x4, x5, x6, x7, x8)
}
