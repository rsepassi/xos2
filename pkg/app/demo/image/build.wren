var module = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.srcGlob("**/*.zig")
  b.install("zig", zig.moduleConfig(b, {
    "root": b.src("app.zig"),
    "modules": {
      "app": b.dep("//pkg/app"),
      "appgpu": b.dep("//pkg/app:gpu"),
      "twod": b.dep("//pkg/app:twod"),
    },
    "c_deps": [
      zig.cDep(b.dep("//pkg/stb:image"), "stb_image"),
    ],
  }))
}

var image = Fn.new { |b, args|
  var app = b.deptool("//pkg/app:builder")
  b.installDir(app.build(b, {
    "module": b.dep(":module"),
    "resources": b.dep("//pkg/app/demo/resources"),
  }))
}
