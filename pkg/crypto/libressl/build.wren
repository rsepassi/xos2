import "os" for Process
import "io" for File

import "xos//pkg/crypto/libressl/shared" for FetchSrc

var libressl = Fn.new { |b, args|
  var libcrypto = b.dep("crypto")
  var libssl = b.dep("ssl")
  var libtls = b.dep("tls")

  b.installLib(libcrypto.lib("crypto"))
  b.installLib(libssl.lib("ssl"))
  b.installLib(libtls.lib("tls"))

  var zig = b.deptool("//toolchains/zig")
  b.installLibConfig(zig.libConfig(b, "libressl", {
    "nostdopts": true,
    "cflags": ["-I{{root}}/include"],
    "ldflags": [
      "{{root}}/lib/%(b.target.libName("crypto"))",
      "{{root}}/lib/%(b.target.libName("ssl"))",
    ],
  }))

  Process.chdir(FetchSrc.call(b))
  File.delete("include/openssl/Makefile.am")
  File.delete("include/openssl/Makefile.in")
  b.installHeader("include/tls.h")
  b.install("include", "include/openssl")
}
