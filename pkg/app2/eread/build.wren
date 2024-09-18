import "io" for File

var eread_lib = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": [b.src("eread.c")],
    "deps": [
      b.dep("//pkg/app2"),
      b.dep("//pkg/epub"),
      b.dep("//pkg/clay"),
    ],
  })
}

var eread = Fn.new { |b, args|
  var appbuilder = b.deptool("//pkg/app2:builder")
  var appdir = appbuilder.build(b, {
    "deps": [b.dep(":eread_lib")],
    "resources": b.dep("//pkg/app/demo/resources").path,
  })
  File.rename(appdir, "%(b.installDir)/app")
}
