import "os" for Process, Path
import "io" for File

var Url = "https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz"
var Hash = "e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff"

var brotli = Fn.new { |b, args|
  var src = b.untar(b.fetch(Url, Hash), {})
  Process.chdir(src)

  var srcs = b.glob("c/common/**/*.c")
  srcs.addAll(b.glob("c/enc/**/*.c"))
  srcs.addAll(b.glob("c/dec/**/*.c"))

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "brotli", {
    "c_srcs": srcs,
    "flags": ["-Ic/include"],
    "libc++": true,
  })

  b.installDir("include", "c/include/brotli")
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "brotli"))
}
