import "io" for Directory

var nativefb = Fn.new { |b, args|
  var deps = [
    b.dep("//pkg/cbase"),
  ]

  if (b.target.isDesktop) deps.add(b.dep("//pkg/glfw"))
  var zig = b.deptool("//toolchains/zig")
  b.srcGlob("nativefb/*.h")
  zig.ez.cLib(b, {
    "srcs": b.srcGlob("*.c") + [b.src("nativefb_mac.m")],
    "flags": ["-I", b.srcDir],
    "include": [b.src("nativefb.h")],
    "deps": deps,
    "libc": true,
  })
  Directory.copy("%(b.srcDir)/nativefb", "%(b.installDir)/include/nativefb")
}
