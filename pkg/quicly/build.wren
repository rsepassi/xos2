import "os" for Process
import "io" for File

var Url = "https://api.github.com/repos/h2o/quicly/tarball/69b2275"
var Hash = "2a75ab06d3a5db87ab433ad3b578a36d9799e29070bb9f95802baba9b6d84340"

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

var quicly = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))

  var deps = [
    b.dep(":klib"),
    b.dep("//pkg/crypto/picotls"),
  ]

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "quicly", {
    "flags": ["-Iinclude", "-Ilib"],
    "c_srcs": b.glob("lib/*.c"),
    "c_deps": deps,
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "quicly", {
    "deps": deps,
  }))
  b.installHeaderDir("include")
}

var cli = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))

  File.replace(
    "src/cli.c",
    "#include \"../deps/picotls/t/util.h\"\n",
    "#include \"picotls/t/util.h\"\n#include <signal.h>\n")

  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "cli", {
    "c_srcs": b.glob("src/cli.c"),
    "c_flags": [
    ],
    "c_deps": [
      b.dep(":quicly"),
    ],
    "libc": true,
  })

  b.installExe(exe)
}

