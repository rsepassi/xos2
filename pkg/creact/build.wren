import "io" for File, Directory
import "os" for Process, Path

var creact = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": [b.src("creact.c")],
    "include": [b.src("creact.h")],
    "flags": [],
    "deps": [
      b.dep("//pkg/cbase"),
    ],
  })
}

var test = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.installExe(zig.buildExe(b, "test", {
    "c_srcs": [b.src("test/test.c")],
    "flags": [],
    "c_deps": [
      b.dep(":creact"),
      b.dep("//pkg/cbase"),
      b.dep("//pkg/munit"),
    ],
    "libc": true,
  }))
}
