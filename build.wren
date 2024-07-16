import "os" for Process
import "io" for File
import "hash" for Sha256

import "build/config" for Config

var launcher = Fn.new { |b, args|
  b.src("src/main.wren")
  var zig = b.deptool("//toolchains/zig", [])
  var exe = zig.buildExe(b, "xos", {
    "root": b.src("src/main.zig"),
    "libc": true,
  })
  b.install("bin", exe)
}

var xos = Fn.new { |b, args|
  var launcher = b.dep(":launcher")
  var curl = b.dep("//deps/curl")
  var tar = b.dep("//deps/libarchive:bsdtar")
  var wren = b.dep("//deps/wrencli")
  var wren_main = b.src("src/main.wren")
  var wren_modules = b.srcDir("src/wren_modules")

  var tar_exe = b.target.exeName("tar")
  File.copy(tar.exe("bsdtar"), tar_exe)

  b.install("", launcher.exe("xos"))
  b.install("support", wren_main)
  b.installDir("support", wren_modules)
  b.install("support/bin", tar_exe)
  b.install("support/bin", curl.exe("curl"))
  b.install("support/bin", wren.exe("wren"))

  File.write("xos_id", Sha256.hashHex(Config.get("xos_id") + b.key))
  b.install("support", "xos_id")
}

var wrenbox = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "wrenbox", {
    "root": b.src("src/wrenbox.zig"),
    "libc": true,
  })
  b.installExe(exe)
}
