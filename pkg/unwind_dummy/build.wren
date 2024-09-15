var unwind_dummy = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "unwind_dummy", {
    "c_srcs": [b.src("unwind.c")],
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}
