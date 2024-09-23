import "io" for File
import "json" for JSON

var eread_lib = Fn.new { |b, args|
  var clay_config = {
    "CLAY_EXTEND_CONFIG_TEXT": "app_t* app;",
    "CLAY_MAX_ELEMENT_COUNT": "8192",
  }

  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": [b.src("eread.c")],
    "deps": [
      b.dep("//pkg/app2"),
      b.dep("//pkg/epub"),
      b.dep("//pkg/clay", [
        "--txt=typedef struct app_s app_t;",
        "--defines=%(JSON.stringify(clay_config))",
      ]),
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
