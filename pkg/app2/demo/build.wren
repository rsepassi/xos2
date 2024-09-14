var demo_lib = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": [b.src("demo.c")],
    "deps": [b.dep("//pkg/app2")],
  })
}

var demo = Fn.new { |b, args|
  var appbuilder = b.deptool("//pkg/app2:builder")
  var exe = appbuilder.build(b, {
    "deps": [b.dep(":demo_lib")],
  })
  b.installExe(exe)
}
