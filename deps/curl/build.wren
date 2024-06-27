import "io" for File
import "os" for Process

var cacert = Fn.new { |b, args|
  var cert = b.fetch(
    "https://curl.se/ca/cacert-2023-12-12.pem",
    "ccbdfc2fe1a0d7bbbb9cc15710271acf1bb1afe4c8f1725fe95c4c7733fcbe5a")
  File.copy(cert, "cacert.pem")
  b.installArtifact("cacert.pem")
}

var Url = "https://github.com/curl/curl/releases/download/curl-8_6_0/curl-8.6.0.tar.xz"
var Hash = "3ccd55d91af9516539df80625f818c734dc6f2ecf9bada33c76765e99121db15"

var curl = Fn.new { |b, args|
  var src = b.untar(b.fetch(Url, Hash))
  Process.chdir(src)

  File.copy(b.src("build.zig"))
  File.copy(b.src("platform/config-%(b.target.os).h"), "lib/curl_config.h")

  var deps = {}
  for (dep in ["mbedtls", "brotli", "zlib", "zstd", "cares"]) {
    deps[dep] = b.dep("//deps/%(dep)")
  }

  var build_args = deps.map { |x| "-D%(x.key)=%(x.value.path)" }.toList
  var zig = b.deptool("//toolchains/zig")
  var out = zig.build(b, {
    "args": build_args,
    "sysroot": true,
  })

  b.installDir("", "%(out)/bin")
  b.installDir("", "%(out)/lib")
  b.install("include/curl", b.glob("include/curl/*.h"))
}
