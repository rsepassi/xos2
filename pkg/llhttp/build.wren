import "io" for File, Directory
import "os" for Process, Path

var llhttp = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(
    "https://github.com/nodejs/llhttp/archive/refs/tags/release/v9.2.1.tar.gz",
    "3c163891446e529604b590f9ad097b2e98b5ef7e4d3ddcf1cf98b62ca668f23e")))
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": b.glob("src/*.c"),
    "flags": ["-Iinclude"],
    "include": ["include/llhttp.h"],
    "libc": true,
  })
}
