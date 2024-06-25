import "os" for Process
import "io" for File

var launcher = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig", [])
  var exe = zig.buildExe(b, "xos", {
    "root": b.src("src/main.zig"),
    "libc": true,
  })
  b.install("bin", exe)
}

var xos = Fn.new { |b, args|
  var launcher = b.dep(":launcher")
  var wren = b.dep("//deps/wrencli")
  var curl = b.dep("//deps/curl")
  var tar = b.dep("//deps/libarchive:bsdtar")
  var wren_main = b.src("src/main.wren")
  var wren_modules = b.srcDir("src/wren_modules")

  File.copy(tar.exe("bsdtar"), "tar")

  b.install("", launcher.exe("xos"))
  b.install("support", wren.exe("wren"))
  b.install("support", "tar")
  b.install("support", curl.exe("curl"))
  b.install("support/scripts", wren_main)
  b.installDir("support/scripts", wren_modules)

  // todo: xos_id (srcs + zig version)
  File.write("xos_id", b.key)
  b.install("support", "xos_id")
}
