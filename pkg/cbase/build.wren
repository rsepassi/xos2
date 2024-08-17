var cbase = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.installLibConfig(zig.libConfig(b, "cbase", {
    "nostdopts": true,
    "cflags": ["-I{{root}}/include"],
  }))
  b.install("include/base", b.src("log.h"))
}
