import "io" for File, Directory
import "os" for Process, Path

var crypt = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": [b.src("crypt.c")],
    "include": [b.src("crypt.h")],
    "flags": [],
    "deps": [
      b.dep("//pkg/cbase"),
    ],
  })
}

var crypt_exe = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.installExe(zig.buildExe(b, "crypt", {
    "c_srcs": [b.src("crypt_main.c")],
    "flags": [],
    "c_deps": [
      b.dep(":crypt"),
      b.dep("//pkg/cbase"),
      b.dep("//pkg/argparse"),
      zig.cDep(b.dep("//pkg/crypto/libsodium", [], {"opt": "Fast"}), "sodium"),
    ],
    "libc": true,
  }))
}
