var module = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.install("zig", zig.moduleConfig(b, {
    "root": b.src("app.zig"),
    "modules": {
      "app": b.dep("//pkg/app"),
      "gpu": zig.moduleDep(b.dep("//pkg/wgpu:zig"), "gpu"),
      "appgpu": b.dep("//pkg/app:gpu"),
      "twod": b.dep("//pkg/app:twod"),
    },
    "c_deps": [
      b.dep("//pkg/nanovg"),
      b.dep("//pkg/freetype"),
    ],
  }))
}

var demo = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var app = b.deptool("//pkg/app:builder")
  var appdir = app.build(b, {
    "module": b.dep(":module"),
    "resources": b.srcDir("resources"),
  })
  b.installDir("", appdir)
}
