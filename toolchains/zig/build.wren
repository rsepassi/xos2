import "io" for File
import "log" for Logger

import "build/patch" for Patch

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
        "aarch64": "754f1029484079b7e0ca3b913a0a2f2a6afd5a28990cb224fe8845e72f09de63",
      },
      "windows": {
        "x86_64": "2199eb4c2000ddb1fba85ba78f1fcf9c1fb8b3e57658f6a627a8e513131893f5",
      },
      "freebsd": {
        "x86_64": "bd49957d1157850b337ee1cf3c00af83585cff98e1ebc3c524a267e7422a2d7b",
      },
    }
  }

  static getUrl_(target) {
    var version = "0.12.0"
    var suffix = target.os == "windows" ? "zip" : "tar.xz"
    return "https://ziglang.org/download/%(version)/zig-%(target.os)-%(target.arch)-%(version).%(suffix)"
  }

  static call(b, args) {
    File.rename(
      b.untar(b.fetch(getUrl_(b.target), urlHashes_[b.target.os][b.target.arch])),
      "zig")
    import "os" for Process
    Patch.read(b.src("zig.patch")).apply()
    b.install("", "zig")
  }

  static wrap(dir) {
    import "xos//toolchains/zig/wrap" for Zig
    return Zig.new(dir)
  }
}
