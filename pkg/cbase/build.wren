import "io" for Directory, File

var cbase_zig = Fn.new { |b, args|
  Directory.create("base")
  var headers = b.srcGlob("*.h")
  for (h in headers) File.copy(h, "base")

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "cbase_zig", {
    "flags": ["-I."],
    "root": b.src("cbase.zig"),
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}

var cbase = Fn.new { |b, args|
  Directory.create("base")
  var headers = b.srcGlob("*.h")
  for (h in headers) File.copy(h, "base")
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "cbase", {
    "flags": ["-I."],
    "c_srcs": b.srcGlob("*.c"),
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "cbase", {
    "deps": [b.dep(":cbase_zig")],
  }))
  b.install("include", "base")

  var klib = b.dep("//pkg/klib")
  File.copy(klib.header("khash.h"), "%(b.installDir)/include/base/khash.h")
}
