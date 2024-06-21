import "io" for File
import "log" for Logger

var Log = Logger.get("zig")

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
    File.rename(
      b.untar(b.fetch(getUrl_(b.target), urlHashes_[b.target.os][b.target.arch])),
      "zig")
    b.install("", "zig")
  }

  static wrap(b) {
    import "xos//toolchains/zig/wrap" for Zig
    return Zig.new(b)
  }
}
