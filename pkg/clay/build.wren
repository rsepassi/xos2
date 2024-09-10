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
  b.installExe(zig.buildExe(b, "demo", {
    "c_srcs": [b.src("demo.c")],
    "c_deps": [
      b.dep(":clay"),
      b.dep("//pkg/cbase"),
      b.dep("//pkg/olive"),
      b.dep("//pkg/glfw"),
      b.dep("//pkg/glfw/nativefb"),
    ],
    "libc": true,
  }))

}
