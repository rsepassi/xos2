import "os" for Process

var klib = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(
    "https://api.github.com/repos/attractivechaos/klib/tarball/de09fb7",
    "77390b9f05cbbdc55baffad27241367c5d3e5fc8cea97da0c38148acf14ffefc")))
  var zig = b.deptool("//toolchains/zig")
  b.installLibConfig(zig.libConfig(b, "klib", {
    "nostdopts": true,
    "cflags": ["-I{{root}}/include"],
  }))
  b.installHeader([
    "khash.h",
  ])
}
