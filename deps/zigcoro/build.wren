var options = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.install("zig", zig.moduleConfig(b, "options", {
    "root": b.src("default_options.zig"),
  }))
}

var zigcoro = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.srcGlob("**/*.zig")
  b.srcGlob("**/*.s")
  b.install("zig", zig.moduleConfig(b, "zigcoro", {
    "root": b.src("coro.zig"),
    "modules": {
      "libcoro_options": b.dep(":options"),
    },
  }))
}
