import "os" for Process, Path
import "io" for File

var Url = "https://zlib.net/zlib-1.3.1.tar.gz"
var Hash = "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"

var zlib = Fn.new { |b, args|
  var src = b.untar(b.fetch(Url, Hash), {})
  Process.chdir(src)

  File.copy(b.src("zconf.h"))

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "z", {
    "c_srcs": b.glob("*.c"),
    "flags": [
      "-DHAVE_HIDDEN",
      "-D_LARGEFILE64_SOURCE=1",
    ],
    "libc": true,
  })

  b.installHeader(["zconf.h", "zlib.h"])
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "z"))
}
