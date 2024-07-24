import "os" for Process
import "io" for File

var Url = "https://api.github.com/repos/h2o/picotls/tarball/096fc5c"
var Hash = "46cd4aa4d3c6c00cd85168daa17dc44daf766dd665ac5fb21cdaeb7b82602844"

var cifra = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  b.glob("deps/cifra/src/test*").map { |s| File.delete(s) }.toList
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "cifra", {
    "flags": ["-Ideps/cifra/src", "-Ideps/cifra/src/ext"],
    "c_srcs": b.glob("deps/cifra/src/*.c"),
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installHeader(b.glob("deps/cifra/src/*.h"))
}

var picotls = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  File.delete("lib/cifra/libaegis.c")

  var deps = [
    b.dep(":cifra"),
    b.dep("//pkg/crypto/libressl"),
    b.dep("//deps/brotli"),
  ]

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "picotls", {
    "flags": ["-Iinclude", "-Ilib"],
    "c_srcs": [
      "lib/asn1.c",
      "lib/certificate_compression.c",
      "lib/ffx.c",
      "lib/hpke.c",
      "lib/openssl.c",
      "lib/pembase64.c",
      "lib/picotls.c",
      "lib/ptlsbcrypt.c",
    ] + b.glob("lib/cifra/*.c"),
    "c_deps": deps,
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "picotls", {
    "deps": deps,
  }))
  b.installHeaderDir("include")
  b.install("include/picotls/t", "t/util.h")
}
