import "os" for Process

var EnvLevel = (Fn.new {
  var level = Process.env("LOG")
  if (level == null || level.trim().isEmpty) return null
  return Num.fromString(level)
}).call()

var EnvScopes = (Fn.new {
  var scopes = Process.env("LOG_SCOPES")
  if (scopes == null || scopes.trim().isEmpty) return null
  var out = {}
  for (scope in scopes.split(",")) {
    out[scope] = null
  }
  return out
}).call()

var Loggers = {}

class Logger {
  static DEBUG { 0 }
  static INFO { 1 }
  static WARN { 2 }
  static ERROR { 3 }
  DEBUG { 0 }
  INFO { 1 }
  WARN { 2 }
  ERROR { 3 }

  static get(scope) {
    if (Loggers.containsKey(scope)) return Loggers[scope]
    var log = Logger.new(scope)
    Loggers[scope] = log
    return log
  }

  construct new(scope) {
    _scope = scope
    _level = EnvLevel || Logger.ERROR
    _enabled = EnvScopes == null || EnvScopes.containsKey(scope)
  }

  level=(level) {
    _level = level == null ? Logger.ERROR : level
  }

  level { _level }

  debug(msg) {
    if (_level > 0) return
    log("D", msg)
  }

  info(msg) {
    if (_level > 1) return
    log("I", msg)
  }

  warn(msg) {
    if (_level > 2) return
    log("W", msg)
  }

  err(msg) {
    if (_level > 3) return
    log("E", msg)
  }

  fatal(msg) {
    log("F", msg)
    Process.exit(1)
  }

  log(level, msg) {
    if (!_enabled) return
    System.print("%(level)(%(_scope)): %(msg)")
  }
}

var Log = Logger.new("main")
