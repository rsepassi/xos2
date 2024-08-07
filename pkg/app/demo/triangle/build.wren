var module = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.srcGlob("**/*.zig")
  b.install("zig", zig.moduleConfig(b, {
    "root": b.src("app.zig"),
    "modules": {
      "app": b.dep("//pkg/app"),
      "appgpu": b.dep("//pkg/app:gpu"),
    },
  }))
}

var triangle = Fn.new { |b, args|
  var app = b.deptool("//pkg/app:builder")
  b.installDir(app.build(b, {
    "module": b.dep(":module"),
  }))
}
