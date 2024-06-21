import "os" for Process, Path
import "io" for File

var Url = "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v3.5.2.tar.gz"
var Hash = "35890edf1a2c7a7e29eac3118d43302c3e1173e0df0ebaf5db56126dabe5bb05"

var mbedtls = Fn.new { |b, args|
  var src = b.untar(b.fetch(Url, Hash), {})
  Process.chdir(src)
  File.copy(b.src("build.zig"))
  var zig = b.deptool("//toolchains/zig")
  var out = zig.build(b, {})
  b.installDir("", "%(out)/lib")
  b.installDir("", "%(out)/bin")

  for (h in b.glob("include/**/*.h")) {
    b.install(Path.dirname(h), h)
  }
  b.installLibConfig(zig.libConfig(b, "mbedtls"))
  b.installLibConfig(zig.libConfig(b, "mbedcrypto"))
  b.installLibConfig(zig.libConfig(b, "mbedx509"))
}
