import "io" for File, Directory
import "os" for Path

class InstallDir {
  construct new(b) {
    _b = b
  }

  path { _b.installDir }
  build { _b }

  exe(name) {
    name = _b.target.os == "windows" ? "%(name).exe" : name
    var out = Path.join([path, "bin", name])
    if (!File.exists(out)) Fiber.abort("%(_b.label) does not contain executable %(name)")
    return out
  }

  lib(name) {
    name = _b.target.os == "windows" ? "%(name).lib" : "lib%(name).a"
    var out = Path.join([path, "lib", name])
    if (!File.exists(out)) Fiber.abort("%(_b.label) does not contain library %(name)")
    return out
  }

  libConfig(name) {
    var out = Path.join([path, "lib", "pkgconfig", name])
    if (!File.exists(out)) Fiber.abort("%(_b.label) does not contain lib config %(name)")
    return out
  }

  includeDir {
    var out = Path.join([path, "include"])
    if (!Directory.exists(out)) return null
    return out
  }

  artifact(name) {
    var out = Path.join([path, "share", name])
    if (!File.exists(out)) Fiber.abort("%(_b.label) does not contain artifact %(name)")
    return out
  }

  toString { "InstallDir for %(_b.label)" }
}
