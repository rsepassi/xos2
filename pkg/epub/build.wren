import "io" for File, Directory
import "os" for Process, Path

var epub = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": [
      b.src("epub.c"),
      b.src("html5_tags.c"),
    ],
    "include": [b.src("epub.h")],
    "flags": [],
    "deps": [
      b.dep("//pkg/cbase"),
      b.dep("//pkg/tidy"),
      zig.cDep(b.dep("//deps/libarchive"), "archive"),
    ],
  })
}

var epub_exe = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.installExe(zig.buildExe(b, "epub", {
    "c_srcs": [b.src("epub_main.c")],
    "flags": [],
    "c_deps": [
      b.dep(":epub"),
      b.dep("//pkg/cbase"),
    ],
    "libc": true,
  }))
}
