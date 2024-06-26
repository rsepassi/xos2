var libglob = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "glob", {
    "c_srcs": [b.src("glob.c")],
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "glob"))
  b.installHeader(b.src("glob.h"))
}
