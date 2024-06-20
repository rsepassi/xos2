var libglob = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "glob", {
    "c_srcs": [b.src("glob.c")],
  })
  b.install("lib", lib)
  b.install("include", b.src("glob.h"))
}
