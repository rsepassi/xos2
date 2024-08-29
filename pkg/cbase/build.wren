import "io" for Directory, File

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
  b.installLibConfig(zig.libConfig(b))
  b.install("include", "base")
}
