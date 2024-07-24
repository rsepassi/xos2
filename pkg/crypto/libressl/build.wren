import "os" for Process
import "io" for File

var Url = "https://cdn.openbsd.org/pub/OpenBSD/LibreSSL/libressl-3.9.2.tar.gz"
var Hash = "7b031dac64a59eb6ee3304f7ffb75dad33ab8c9d279c847f92c89fb846068f97"

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

  Process.chdir(b.untar(b.fetch(Url, Hash)))
  File.delete("include/openssl/Makefile.am")
  File.delete("include/openssl/Makefile.in")
  b.installHeader("include/tls.h")
  b.install("include", "include/openssl")
}
