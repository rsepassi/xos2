import "io" for Directory
import "os" for Process

var ucl = Fn.new { |b, args|
  var src = b.untar(b.src("ucl-0.9.2.tar.gz"))
  Process.chdir(src)

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "ucl", {
    "c_srcs": b.glob("src/*.c"),
    "flags": ["-Iinclude", "-Isrc", "-Iklib", "-Iuthash"] + (b.target.abi == "android" ? ["-DNBBY=8"] : []),
    "libc": true,
  })

  b.installHeader("include/ucl.h")
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}
