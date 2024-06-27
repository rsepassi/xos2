import "os" for Process
import "io" for File

var launcher = Fn.new { |b, args|
  b.src("src/main.wren")
  var zig = b.deptool("//toolchains/zig", [])
  var exe = zig.buildExe(b, "xos", {
    "root": b.src("src/main.zig"),
    "c_deps": [
      zig.cDep(b.dep("//deps/wrencli:lib"), "wrencli"),
    ],
    "libc": true,
  })
  b.install("bin", exe)
}

var xos = Fn.new { |b, args|
  var launcher = b.dep(":launcher")
  var curl = b.dep("//deps/curl")
  var tar = b.dep("//deps/libarchive:bsdtar")
  var wren_main = b.src("src/main.wren")
  var wren_modules = b.srcDir("src/wren_modules")

  import "xos//toolchains/zig/wrap" for Zig
  var tar_exe = Zig.exeName(b.target, "tar")
  File.copy(tar.exe("bsdtar"), tar_exe)

  b.install("", launcher.exe("xos"))
  b.install("support", tar_exe)
  b.install("support", curl.exe("curl"))
  b.installDir("support", wren_modules)

  // todo: xos_id (srcs + zig version)
  File.write("xos_id", b.key)
  b.install("support", "xos_id")
}
