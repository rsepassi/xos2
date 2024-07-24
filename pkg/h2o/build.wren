import "os" for Process
import "io" for Directory, File

import "build/patch" for Patch

var Url = "https://api.github.com/repos/h2o/h2o/tarball/16b13ee"
var Hash = "918037ad6d11c903589a73d26018960875eb00bdd783f1f5c457177fce1681cb"

var os_flags = {
  "linux": [
    "-D_GNU_SOURCE",
    "-D_MUSL_LIB",
  ],
}

var libh2o = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))

  Patch.read(b.src("musl.patch")).apply()

  Directory.deleteTree("lib/handler/mruby")
  File.delete("lib/handler/mruby.c")
  File.delete("lib/handler/configurator/mruby.c")
  File.delete("lib/websocket.c")

  var zig = b.deptool("//toolchains/zig")
  var deps = [
    b.dep("//pkg/quicly"),
    zig.cDep(b.dep("//deps/zlib"), "z"),
    zig.cDep(b.dep("//deps/libuv"), "uv"),
  ]
  var lib = zig.buildLib(b, "h2o", {
    "c_srcs": b.glob("lib/**/*.c") + [
      "deps/cloexec/cloexec.c",
      "deps/hiredis/async.c",
      "deps/hiredis/hiredis.c",
      "deps/hiredis/net.c",
      "deps/hiredis/read.c",
      "deps/hiredis/sds.c",
      "deps/libgkc/gkc.c",
      "deps/libyrmcds/close.c",
      "deps/libyrmcds/connect.c",
      "deps/libyrmcds/recv.c",
      "deps/libyrmcds/send.c",
      "deps/libyrmcds/send_text.c",
      "deps/libyrmcds/socket.c",
      "deps/libyrmcds/strerror.c",
      "deps/libyrmcds/text_mode.c",
      "deps/picohttpparser/picohttpparser.c",
    ] + b.glob("deps/yaml/src/*.c"),
    "c_flags": [
      "-std=c99",
      "-Wall",
      "-Wno-unused-value",
      "-Wno-unused-function",
      "-Wno-nullability-completeness",
      "-Wno-expansion-to-defined",
      "-Werror=implicit-function-declaration",
      "-Werror=incompatible-pointer-types",
    ],
    "flags": [
      "-DH2O_USE_LIBUV=0",
      "-DH2O_USE_BROTLI=1",
      "-Iinclude",
      "-Ideps/cloexec",
      "-Ideps/brotli/c/include",
      "-Ideps/golombset",
      "-Ideps/hiredis",
      "-Ideps/libgkc",
      "-Ideps/libyrmcds",
      "-Ideps/klib",
      "-Ideps/neverbleed",
      "-Ideps/picohttpparser",
      "-Ideps/picotest",
      "-Ideps/picotls/deps/cifra/src/ext",
      "-Ideps/picotls/deps/cifra/src",
      "-Ideps/picotls/deps/micro-ecc",
      "-Ideps/picotls/include",
      "-Ideps/quicly/include",
      "-Ideps/yaml/include",
      "-Ideps/yoml",
    ] + (os_flags[b.target.os] || []),
    "c_deps": deps,
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "h2o", {
    "deps": deps,
  }))
  b.installHeaderDir("include")
}

var h2o = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))

  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "h2o", {
    "c_srcs": ["src/main.c", "src/ssl.c", "deps/neverbleed/neverbleed.c"],
    "flags": [
      "-DH2O_USE_LIBUV=0",
      "-DH2O_USE_BROTLI=1",
      "-Ideps/cloexec",
      "-Ideps/hiredis",
      "-Ideps/yoml",
      "-Ideps/yaml/include",
      "-Ideps/neverbleed",
      "-Ideps/libyrmcds",
    ] + (os_flags[b.target.os] || []),
    "c_deps": [zig.cDep(b.dep(":libh2o"), "h2o")],
    "libc": true,
  })
  b.installExe(exe)
}

// todo: exe
// src/httpclient.c
//
// todo: exe
// src/main.c
// src/ssl.c
// "deps/neverbleed/neverbleed.c",
