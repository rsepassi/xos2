import "os" for Process
import "io" for File

import "xos//pkg/crypto/libressl/shared" for FetchSrc, Defines, Cflags

var ssl = Fn.new { |b, args|
  Process.chdir(FetchSrc.call(b))
  var zig = b.deptool("//toolchains/zig")
  var c_srcs = b.glob("ssl/*.c")

  var lib = zig.buildLib(b, "ssl", {
    "flags": Defines + Includes + CryptoArch[b.target.arch]["flags"],
    "c_flags": Cflags,
    "c_srcs": c_srcs + CryptoArch[b.target.arch]["srcs"],
    "libc": true,
  })

  b.installLib(lib)
}

var Includes = [
  "-Issl",
  "-Issl/hidden",
  "-Icrypto/bio",
  "-Iinclude",
  "-Iinclude/compat",
]

var CryptoArch = {
  "aarch64": {
    "flags": [
      "-DOPENSSL_NO_ASM ",
      "-DOPENSSL_NO_HW_PADLOCK",
      "-D__ARM_ARCH_8A__=1",
    ],
    "srcs": [
    ],
  },
  "x86_64": {
    "flags": [
      "-DOPENSSL_NO_ASM ",
    ],
    "srcs": [
    ],
  },
}
