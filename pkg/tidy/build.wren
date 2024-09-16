import "io" for File, Directory
import "os" for Process, Path

var tidy = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(
    "https://github.com/htacg/tidy-html5/archive/refs/tags/5.8.0.tar.gz",
    "59c86d5b2e452f63c5cdb29c866a12a4c55b1741d7025cf2f3ce0cde99b0660e"
  )))
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": b.glob("src/*.c"),
    "include": b.glob("include/tidy*.h"),
    "flags": ["-Iinclude"],
    "libc": true,
  })
}

var demo = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.installExe(zig.buildExe(b, "demo", {
    "c_srcs": [b.src("demo.c")],
    "c_deps": [
      b.dep(":tidy"),
      b.dep("//pkg/cbase"),
    ],
  }))
}
