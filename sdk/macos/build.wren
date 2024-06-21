import "io" for File

var Url = "https://github.com/rsepassi/xos/releases/download/macos-sdk-14.2-v5/macossdk.tar.gz"
var Hash = "61121dae9a1a7afd3199e43860995093ea40cd0110a4728b2a9546e1c784e99f"

class Sdk {
  construct new(b) {
    _b = b
  }
  sysroot { "%(_b.installDir)/sdk" }
}

class macos {
  static call(b, args) {
    var dir = b.untar(b.fetch(Url, Hash))
    File.rename(dir, "sdk")
    b.installDir("", "sdk")
  }
  static wrap(b) { Sdk.new(b) }
}
