import "os" for Process
import "io" for File

import "xos//pkg/crypto/libressl/shared" for FetchSrc, Defines, Cflags

var tls = Fn.new { |b, args|
  Process.chdir(FetchSrc.call(b))
  var zig = b.deptool("//toolchains/zig")

  var lib = zig.buildLib(b, "tls", {
    "flags": Defines.call(b) + Includes + CryptoArch[b.target.arch]["flags"],
    "c_flags": Cflags,
    "c_srcs": [
      "tls/tls.c",
      "tls/tls_bio_cb.c",
      "tls/tls_client.c",
      "tls/tls_config.c",
      "tls/tls_conninfo.c",
      "tls/tls_keypair.c",
      "tls/tls_ocsp.c",
      "tls/tls_peer.c",
      "tls/tls_server.c",
      "tls/tls_signer.c",
      "tls/tls_util.c",
      "tls/tls_verify.c",
    ] + (CompatSrcs[b.target.os] || []),
    "libc": true,
  })

  b.installLib(lib)
}

var Includes = [
  "-Itls",
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
  },
  "x86_64": {
    "flags": [
      "-DOPENSSL_NO_ASM ",
    ],
  },
}

var CompatSrcs = {
  "windows": [
    "tls/compat/ftruncate.c",
    "tls/compat/pread.c",
    "tls/compat/pwrite.c",
  ],
}
