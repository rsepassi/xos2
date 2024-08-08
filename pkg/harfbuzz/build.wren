import "os" for Process

var harfbuzz = Fn.new { |b, args|
  var url = "https://github.com/harfbuzz/harfbuzz/releases/download/8.0.1/harfbuzz-8.0.1.tar.xz"
  var hash = "c1ce780acd385569f25b9a29603d1d5bc71e6940e55bfdd4f7266fad50e42620"
  Process.chdir(b.untar(b.fetch(url, hash)))

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "harfbuzz", {
    "flags": ["-DHAVE_FREETYPE"],
    "c_srcs": ["src/harfbuzz.cc"],
    "c_deps": [b.dep("//pkg/freetype")],
    "libc++": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "harfbuzz", {
    "libc++": true,
  }))
  b.install("include/harfbuzz", b.glob("src/*.h"))
}
