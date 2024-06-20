var xos = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig", [])
  var exe = zig.buildExe(b, "xos", {
    "root": b.src("main.zig"),
  })
  b.install("bin", exe)
}
