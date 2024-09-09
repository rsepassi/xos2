import "os" for Process
import "io" for File

var Url = "https://github.com/jedisct1/libsodium/releases/download/1.0.20-RELEASE/libsodium-1.0.20.tar.gz"
var Hash = "ebb65ef6ca439333c2bb41a0c1990587288da07f6c7fd07cb3a18cc18d30ce19"

var libsodium = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  var zig = b.deptool("//toolchains/zig")
  zig.build(b, {
    "args": ["-Dshared=false", "-Dtest=false"],
  })

  File.rename("zig-out/lib", "%(b.installDir)/lib")
  File.rename("zig-out/include", "%(b.installDir)/include")

  b.installLibConfig(zig.libConfig(b, "sodium"))
}
