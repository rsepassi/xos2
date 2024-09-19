import "os" for Process, Path
import "build/patch" for Patch

var Url = "https://github.com/openziti/tlsuv/archive/refs/tags/v0.31.4.tar.gz"
var Hash = "559bf5af26c953215573d26c8b144271c20bc3fc30176eadbbc8546b95e69000"

var getsrc = Fn.new { |b|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  Patch.read(b.src("tlsuv.patch")).apply()
}


var uvlink = Fn.new { |b, args|
  getsrc.call(b)
  Process.chdir("deps/uv_link_t")
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": b.glob("src/*.c"),
    "flags": ["-I."],
    "include": ["include/uv_link_t.h"],
    "deps": [zig.cDep(b.dep("//deps/libuv"), "uv")],
    "libc": true,
  })
}

var tlsuv = Fn.new { |b, args|
  getsrc.call(b)
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": b.glob("src/*.c") + b.glob("src/mbedtls/*.c"),
    "flags": ["-Iinclude", "-Isrc", "-DUSE_MBEDTLS"],
    "includeDir": "include",
    "deps": [
      b.dep(":uvlink"),
      b.dep("//pkg/llhttp"),
      zig.cDep(b.dep("//deps/mbedtls"), "mbedtls"),
      zig.cDep(b.dep("//deps/mbedtls"), "mbedcrypto"),
      zig.cDep(b.dep("//deps/mbedtls"), "mbedx509"),
      zig.cDep(b.dep("//deps/zlib"), "z"),
    ],
    "libc": true,
  })
}

var http_ping = Fn.new { |b, args|
  getsrc.call(b)
  var zig = b.deptool("//toolchains/zig")
  b.installExe(zig.buildExe(b, "http_ping", {
    "c_srcs": [
      "sample/http-ping.c",
      "sample/common.c",
    ],
    "c_deps": [
      b.dep(":tlsuv"),
    ],
  }))
}
