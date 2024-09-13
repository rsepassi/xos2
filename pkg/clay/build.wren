import "io" for File

var clay = Fn.new { |b, args|
  var h = b.fetch(
    "https://raw.githubusercontent.com/nicbarker/clay/807fd62/clay.h",
    "c9f57a20c88a04dfc29d977b074bc5948f0da3271bb5f785506ce195c5e623e0")
  h = File.copy(h, "clay.h")

  b.installHeader(h)
  var zig = b.deptool("//toolchains/zig")
  b.installLibConfig(zig.libConfig(b, "clay", {
    "nostdopts": true,
    "cflags": ["-I{{root}}/include"],
  }))
}

var demo = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var extras = []
  if (b.target.os == "windows") {
    var pkg = b.deptool("//sdk/windows/pkg")
    var icon_path = "/Users/ryan/tmp/app/calculator.png"
    extras.add(pkg.rcicon(b, icon_path))
  }
  b.installExe(zig.buildExe(b, "demo", {
    "c_srcs": [b.src("demo.c")] + extras,
    "c_deps": [
      b.dep(":clay"),
      b.dep("//pkg/cbase"),
      b.dep("//pkg/olive"),
      b.dep("//pkg/glfw"),
      b.dep("//pkg/glfw/nativefb"),
      b.dep("//pkg/text"),
    ],
    "libc": true,
  }))
}

var demo_pkg = Fn.new { |b, args|
  var bin = b.dep(":demo")
  var icon_path = "/Users/ryan/tmp/app/calculator.png"
  var resources = [
    "/Users/ryan/code/xos2/pkg/app/demo/resources/CourierPrime-Regular.ttf",
  ]

  if (b.target.os == "macos") {
    var pkg = b.deptool("//sdk/macos/pkg")
    var app = pkg.pkg(b, {
      "name": "myapp",
      "exe": bin.exe("demo"),
      "icon_png": icon_path,
      "bundle_id": "com.istudios.myapp",
      "resources": resources,
    })
    var dmg = pkg.dist(b, {
      "app": app,
      "signid": "Developer ID Application: Intelligence Studios, Inc. (V39ZP95M68)",
      "name": "myapp",
    })
    b.install("", app)
    b.install("", dmg)
  } else if (b.target.os == "windows") {
    var pkg = b.deptool("//sdk/windows/pkg")
    var installer = pkg.pkg(b, {
      "name": "myapp",
      "exe": bin.exe("demo"),
      "resources": resources,
      "publisher": "Intelligence Studios",
    })
    b.install("", installer)
  } else if (b.target.os == "linux") {
    var pkg = b.deptool("//sdk/linux/pkg")
    var zip = pkg.pkg(b, {
      "name": "myapp",
      "exe": bin.exe("demo"),
      "resources": resources,
    })
    b.install("", zip)
  } else {
    Fiber.abort("unimpl")
  }
}
