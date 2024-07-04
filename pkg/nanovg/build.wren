import "os" for Process

var nanovg = Fn.new { |b, args|
  var url = "https://api.github.com/repos/memononen/nanovg/tarball/f93799c"
  var hash = "9972acabedd7e2f40f897de5af1c548479f74c7cd4cc059c2747f77d7a3eb279"
  Process.chdir(b.untar(b.fetch(url, hash)))

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "nanovg", {
    "c_srcs": ["src/nanovg.c"],
    "flags": ["-DNVG_NO_STB"],
    "libc": true,
  })
  b.installHeader("src/nanovg.h")
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}
