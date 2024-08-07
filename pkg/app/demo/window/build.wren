var module = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.install("zig", zig.moduleConfig(b, {
    "root": b.src("app.zig"),
    "modules": {
      "app": b.dep("//pkg/app"),
    },
  }))
}

var window = Fn.new { |b, args|
  var app = b.deptool("//pkg/app:builder")
  b.installDir(app.build(b, {
    "module": b.dep(":module"),
  }))
}
