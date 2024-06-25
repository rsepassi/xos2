import "io" for Directory
import "os" for Process

import "xos//toolchains/zig/wrap" for Zig

var busybox = Fn.new { |b, args|
  var src = b.untar(b.fetch(
    "https://github.com/rsepassi/busybox-bin/releases/download/v20240612/busybox.tar.gz",
    "5a712554ee267c23eb2d57345efbc675f00358e2e60a51e4eeeb4b1dab449598"))
  b.installExe("%(src)/%(b.target)/bin/%(Zig.exeName(b.target, "busybox"))")
}
