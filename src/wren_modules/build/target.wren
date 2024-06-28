import "build/config" for Config

class Target {
  static host {
    return Config.get("host_target")
  }

  static parse(arg) {
    var parts = arg.split("-")
    if (parts.count < 2) {
      Fiber.abort("Target must specify at least arch and os, got %(arg)")
    }
    if (parts.count > 3) {
      Fiber.abort("Target can specify <arch>-<os>[-<abi>], got %(arg)")
    }
    var abi
    if (parts.count == 2) {
      abi = "none"
    } else {
      abi = parts[2]
    }
    return Target.new(parts[0], parts[1], abi)
  }

  construct new(arch, os, abi) {
    _arch = arch
    _os = os
    _abi = abi
  }
  arch { _arch }
  os { _os }
  abi { _abi }

  exeName(name) { os == "windows" ? "%(name).exe" : name }
  libName(name) { os == "windows" ? "%(name).lib" : "lib%(name).a" }
  dylibName(name) { os == "windows" ? "%(name).lib" : "lib%(name).so" }

  toString {
    return "%(_arch)-%(_os)-%(_abi)"
  }

  toJSON {
    return "%(this)"
  }
}
