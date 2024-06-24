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
  var bb = b.dep("//toolchains/busybox")
  var wren_main = b.src("src/main.wren")
  var wren_modules = b.srcDir("src/wren_modules")

  b.install("", launcher.exe("xos"))
  b.install("support", wren.exe("wren"))
  b.install("support", bb.exe("busybox"))
  b.install("support/scripts", wren_main)
  b.installDir("support/scripts", wren_modules)

  var bb_links = [
    "tar",
    "wget",
  ]
  for (link in bb_links) {
    File.symlink("busybox", "%(b.installDir)/support/%(link)")
  }

  // todo: xos_id (srcs + zig version)
  File.write("xos_id", "xos2")
  b.install("support", "xos_id")
}
