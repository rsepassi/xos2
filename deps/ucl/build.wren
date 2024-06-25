import "io" for Directory
import "os" for Process

var ucl = Fn.new { |b, args|
  var src = b.untar(b.src("ucl-0.9.2.tar.gz"))
  Process.chdir(src)

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "ucl", {
    "c_srcs": b.glob("src/*.c"),
    "flags": ["-Iinclude", "-Isrc", "-Iklib", "-Iuthash"],
    "libc": true,
  })

  b.install("lib", lib)
  b.install("include", "include/ucl.h")
}
