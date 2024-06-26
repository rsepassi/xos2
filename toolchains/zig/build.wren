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
      },
      "windows": {
        "x86_64": "2199eb4c2000ddb1fba85ba78f1fcf9c1fb8b3e57658f6a627a8e513131893f5",
      },
    }
  }

  static getUrl_(target) {
    var version = "0.12.0"
    var suffix = target.os == "windows" ? "zip" : "tar.xz"
    return "https://ziglang.org/builds/zig-%(target.os)-%(target.arch)-%(version).%(suffix)"
  }

  static call(b, args) {
    File.rename(
      b.untar(b.fetch(getUrl_(b.target), urlHashes_[b.target.os][b.target.arch])),
      "zig")
    b.install("", "zig")
  }

  static wrap(dir) {
    import "xos//toolchains/zig/wrap" for Zig
    return Zig.new(dir)
  }
}
