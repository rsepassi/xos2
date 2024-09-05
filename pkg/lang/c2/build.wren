var c2 = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.srcGlob("*.h")
  zig.ez.cLib(b, {
    "srcs": [
      b.src("c2.c"),
      b.src("c2_mir.c"),
    ],
    "flags": ["-I", b.srcDir],
    "include": [
      b.src("c2.h"),
      b.src("c2_mir.h"),
    ],
    "deps": [
      b.dep("//pkg/cbase"),
      b.dep("//pkg/klib"),
      b.dep("//pkg/lang/mir"),
    ],
    "libc": true,
  })
}

var test = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "test", {
    "c_srcs": [
      b.src("c2_test.c"),
    ],
    "c_deps": [
      b.dep(":c2"),
    ],
    "libc": true,
  })
  b.installExe(exe)
}
