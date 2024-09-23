import "os" for Process
import "io" for File, Directory

var Url = "https://github.com/mity/md4c/archive/refs/tags/release-0.5.2.tar.gz"
var Hash = "55d0111d48fb11883aaee91465e642b8b640775a4d6993c2d0e7a8092758ef21"

var md4c = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": b.glob("src/*.c"),
    "include": ["src/md4c.h", "src/md4c-html.h"],
    "libc": true,
  })
}

var md2html = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "exe", {
    "c_srcs": b.glob("md2html/*.c"),
    "flags": [
      "-DMD_VERSION_MAJOR=0",
      "-DMD_VERSION_MINOR=5",
      "-DMD_VERSION_RELEASE=2",
    ],
    "c_deps": [b.dep(":md4c")],
  })
  Directory.ensure("%(b.installDir)/bin")
  File.rename(b.target.exeName("exe"), "%(b.installDir)/bin/md2html")
}
