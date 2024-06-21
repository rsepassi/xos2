import "io" for Directory
import "os" for Process

import "xos//toolchains/zig/wrap" for Zig

var busybox = Fn.new { |b, args|
  var tar = b.fetch(
    "https://github.com/rsepassi/busybox-bin/releases/download/v20240612/busybox.tar.gz",
    "5a712554ee267c23eb2d57345efbc675f00358e2e60a51e4eeeb4b1dab449598")
  Directory.create("busybox")
  Process.spawn(["tar", "xf", tar, "-C", "busybox", "--strip-components=1"])
  b.installExe("busybox/%(b.target)/bin/%(Zig.exeName(b.target, "busybox"))")
}
