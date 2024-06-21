import "os" for Process, Path
import "io" for File

var Url = "https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz"
var Hash = "9c4396cc829cfae319a6e2615202e82aad41372073482fce286fac78646d3ee4"

var zstd = Fn.new { |b, args|
  var src = b.untar(b.fetch(Url, Hash), {})
  Process.chdir("%(src)/lib")

  var srcs = b.glob("common/*.c")
  srcs.addAll(b.glob("compress/*.c"))
  srcs.addAll(b.glob("decompress/*.c"))
  srcs.addAll(b.glob("dictBuilder/*.c"))
  srcs.addAll(b.glob("legacy/*.c"))
  if (["linux", "macos"].contains(b.target.os) && b.target.arch == "x86_64") {
    srcs.add("decompress/huf_decompress_amd64.S")
  }

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "zstd", {
    "c_srcs": srcs,
    "flags": [
      "-DXXH_NAMESPACE=ZSTD_",
      "-DDEBUGLEVEL=0",
      "-DZSTD_STATIC_LINKING_ONLY",
      "-DZSTD_MULTITHREAD",
    ],
    "libc": true,
  })

  b.installHeader(b.glob("*.h"))
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "zstd"))
}
