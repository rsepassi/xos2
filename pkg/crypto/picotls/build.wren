import "os" for Process
import "io" for File

var Url = "https://api.github.com/repos/h2o/picotls/tarball/5a4461"
var Hash = "09efd2e3059f60d9369b5b64aece2c39303ba3e1c0c30e9101028dbc51d62997"

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

  var zig = b.deptool("//toolchains/zig")
  var mbedtls = b.dep("//deps/mbedtls")
  var deps = [
    b.dep(":cifra"),
    b.dep("//deps/brotli"),
    zig.cDep(mbedtls, "mbedtls"),
    zig.cDep(mbedtls, "mbedcrypto"),
    zig.cDep(mbedtls, "mbedx509"),
  ]

  var lib = zig.buildLib(b, "picotls", {
    "flags": [
      "-Iinclude",
      "-Ilib",
      "-Ideps/micro-ecc",
      "-DPICOTLS_USE_BROTLI=1",
      "-DPTLS_HAVE_MBEDTLS=1",
    ],
    "c_srcs": [
      "deps/micro-ecc/uECC.c",
      "lib/asn1.c",
      "lib/certificate_compression.c",
      "lib/ffx.c",
      "lib/hpke.c",
      "lib/pembase64.c",
      "lib/picotls.c",
      "lib/ptlsbcrypt.c",
      "lib/uecc.c",
      "lib/minicrypto-pem.c",
      "lib/mbedtls.c",
      "lib/mbedtls_sign.c",
    ] + b.glob("lib/cifra/*.c"),
    "c_deps": deps,
    "libc": true,
    "sdk": b.target.os == "macos",
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "picotls", {
    "deps": deps,
  }))
  b.installHeaderDir("include")
  b.install("include/picotls/t", "t/util.h")
}
