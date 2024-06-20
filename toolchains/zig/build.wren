import "os" for Process
import "io" for Directory

// Install wrapper
class Zig {
  construct new(b) {
    _b = b
    _exe = "%(b.installDir)/zig/%(Zig.exeName(b.target, "zig"))"
  }

  exe { _exe }

  static exeName(target, name) {
    return target.os == "windows" ? "%(name).exe" : name
  }

  static libName(target, name) {
    return target.os == "windows" ? "%(name).lib" : "lib%(name).a"
  }

  static dylibName(target, name) {
    return target.os == "windows" ? "%(name).lib" : "lib%(name).so"
  }

  getOpt(opt) {
    var opts = {
      0: "Debug",
      1: "Debug",
      2: "ReleaseSafe",
      3: "ReleaseFast",
      "s": "ReleaseSmall",
      "z": "ReleaseSmall",
      "Debug": "Debug",
      "Safe": "ReleaseSafe",
      "Fast": "ReleaseFast",
      "ReleaseSafe": "ReleaseSafe",
      "ReleaseFast": "ReleaseFast",
    }
    if (!opts.containsKey(opt)) Fiber.abort("unrecognized optimization mode %(opt)")
    return opts[opt]
  }

  buildExe(b, name, opts) {
    var srcs = []

    var root = opts["root"]
    if (root) srcs.add(root)

    var csrcs = opts["c_srcs"]
    if (csrcs) {
      if (!(csrcs is List)) Fiber.abort("c_srcs must be a list")
      srcs.addAll(csrcs)
    }

    if (srcs.isEmpty) Fiber.abort("must provide srcs, either root or c_srcs")

    var env = Process.env()
    env["HOME"] = b.workDir
    Process.spawn([
        _exe, "build-exe",
        "-target", "%(b.target)",
        "-O", getOpt(b.opt_mode),
        "--name", name,
      ] + srcs,
      env, [null, 1, 2])
    return Zig.exeName(b.target, name)
  }
}

// Build target
class zig {
  static urlHashes_ {
    return {
      "macos": {
        "aarch64": "294e224c14fd0822cfb15a35cf39aa14bd9967867999bf8bdfe3db7ddec2a27f",
        "x86_64": "4d411bf413e7667821324da248e8589278180dbc197f4f282b7dbb599a689311",
      },
      "linux": {
        "x86_64": "c7ae866b8a76a568e2d5cfd31fe89cdb629bdd161fdd5018b29a4a0a17045cad",
      }
    }
  }

  static getUrl_(target) {
    var version = "0.12.0"
    return "https://ziglang.org/builds/zig-%(target.os)-%(target.arch)-%(version).tar.xz"
  }

  static call(b, args) {
    var archive_path = b.fetch(getUrl_(b.target), urlHashes_[b.target.os][b.target.arch])
    Directory.create("zig")
    Process.spawn(["tar", "xf", archive_path, "--strip-components=1", "-C", "zig"], null)
    b.install(null, "zig")
  }

  static wrap(b) {
    return Zig.new(b)
  }
}
