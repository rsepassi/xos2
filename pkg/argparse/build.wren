import "os" for Process

var argparse = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(
    "https://api.github.com/repos/cofyc/argparse/tarball/682d452",
    "1400aa5ef96517db9ce0a1ec1a8edb875f1ed644a498786d8a7b399ab2a10a35")))
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": ["argparse.c"],
    "include": ["argparse.h"],
    "libc": true,
  })
}
