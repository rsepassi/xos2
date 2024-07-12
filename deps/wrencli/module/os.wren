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
  static pathSplit(path) { path.split(Platform.isWindows ? ";" : ":") }

  static spawn(args) { spawn(args, null, null) }
  static spawn(args, env) { spawn(args, env, null) }
  static spawn(args, env, stdio) {
    if (stdio == null) stdio = [null, null, null]
    child(args)
      .env(env)
      .stdin(stdio[0])
      .stdout(stdio[1])
      .stderr(stdio[2])
      .run()
  }

  static spawnCapture(args) { spawnCapture(args, null) }
  static spawnCapture(args, env) {
    var stdout_parts = []
    var stdout = Fn.new { |val| stdout_parts.add(val) }
    var stderr_parts = []
    var stderr = Fn.new { |val| stderr_parts.add(val) }
    child(args)
      .env(env)
      .onStdout(stdout)
      .onStderr(stderr)
      .run()
    return {
      "stderr": stderr_parts.join(""),
      "stdout": stdout_parts.join(""),
    }
  }

  static child(args) { SubprocessBuilder.new(args) }

  foreign static cwd_
}

class SubprocessBuilder {
  construct new(args) {
    _args = args
    _env = null
    _stdio = [-1, -1, -1]
    _stdio_fns = [null, null]
  }

  env(env_map) {
    _env = FlattenEnv_.call(env_map)
    return this
  }

  stdin(fd) { stdio_(fd, 0) }
  stdout(fd) { stdio_(fd, 1) }
  stderr(fd) { stdio_(fd, 2) }

  onStdout(fn) {
    _stdio_fns[0] = fn
    return this
  }

  onStderr(fn) {
    _stdio_fns[1] = fn
    return this
  }

  spawn() { Subprocess.new_(_args, _env, _stdio[0], _stdio[1], _stdio[2], _stdio_fns[0], _stdio_fns[1]) }

  run() {
    var sp = spawn()
    sp.wait()
  }

  stdio_(x, idx) {
    _stdio[idx] = (Fn.new {
      if (x == null) return -1
      if (x is Num) return x
      return x.fd
    }).call()
    return this
  }
}

foreign class Subprocess {
  construct new_(args, env, stdin, stdout, stderr, stdout_f, stderr_f) {}

  write(x) { Scheduler.await_ { write_(x, Fiber.current) } }
  echo(x) { write("%(x)\n") }
  kill() { kill(Signal.TERM) }

  wait() {
    var code = waitCode()
    if (code != 0) Fiber.abort("process pid %(pid) exited with code %(code)")
  }
  waitCode() { Scheduler.await_ { wait_(Fiber.current) } }

  foreign kill(signum)
  foreign pid
  foreign done

  foreign wait_(f)
  foreign write_(x, f)
}

class Signal {
  static HUP { 1 }
  static INT { 2 }
  static QUIT { 3 }
  static ILL { 4 }
  static FPE { 8 }
  static KILL { 9 }
  static SEGV { 11 }
  static TERM { 15 }
  static BREAK { 21 }
  static ABRT { 22 }
  static WINCH { 28 }
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

var FlattenEnv_ = Fn.new { |env|
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
  return env_flat
}
