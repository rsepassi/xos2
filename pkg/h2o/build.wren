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

var picohttpparser = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "picohttpparser", {
    "c_srcs": [
      "deps/picohttpparser/picohttpparser.c",
    ],
    "flags": ["-Ideps/picohttpparser"] + (os_flags[b.target.os] || []),
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installHeader(b.glob("deps/picohttpparser/*.h"))
}

var hiredis = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  Patch.read(b.src("musl.patch")).apply()
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "hiredis", {
    "c_srcs": [
      "deps/hiredis/async.c",
      "deps/hiredis/hiredis.c",
      "deps/hiredis/net.c",
      "deps/hiredis/read.c",
      "deps/hiredis/sds.c",
    ],
    "flags": ["-Ideps/hiredis"] + (os_flags[b.target.os] || []),
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installHeader(b.glob("deps/hiredis/*.h"))
}

var yrmcds = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "yrmcds", {
    "c_srcs": [
      "deps/libyrmcds/close.c",
      "deps/libyrmcds/connect.c",
      "deps/libyrmcds/counter.c",
      "deps/libyrmcds/recv.c",
      "deps/libyrmcds/send.c",
      "deps/libyrmcds/send_text.c",
      "deps/libyrmcds/set_compression.c",
      "deps/libyrmcds/socket.c",
      "deps/libyrmcds/strerror.c",
      "deps/libyrmcds/text_mode.c",
    ],
    "flags": ["-Ideps/libyrmcds"],
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installHeader(b.glob("deps/libyrmcds/*.h"))
}

var yaml = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "yaml", {
    "c_srcs": b.glob("deps/yaml/src/*.c"),
    "flags": ["-Ideps/yaml/src", "-Ideps/yaml/include"],
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installHeaderDir("deps/yaml/include")
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
    b.dep(":yaml"),
    b.dep(":yrmcds"),
    b.dep(":hiredis"),
    b.dep(":picohttpparser"),
    b.dep("//pkg/quicly"),
    zig.cDep(b.dep("//deps/zlib"), "z"),
    zig.cDep(b.dep("//deps/libuv"), "uv"),
  ]
  var lib = zig.buildLib(b, "h2o", {
    "c_srcs": b.glob("lib/**/*.c") + [
      "deps/cloexec/cloexec.c",
      "deps/libgkc/gkc.c",
    ],
    "flags": [
      "-DH2O_USE_LIBUV=0",
      "-DH2O_USE_BROTLI=1",
      "-Iinclude",
      "-Ideps/cloexec",
      "-Ideps/golombset",
      "-Ideps/libgkc",
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
      "-Ideps/yoml",
      "-Ideps/neverbleed",
    ] + (os_flags[b.target.os] || []),
    "c_deps": [zig.cDep(b.dep(":libh2o"), "h2o")],
    "libc": true,
  })
  b.installExe(exe)
}

var httpclient = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))

  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "httpclient", {
    "c_srcs": ["src/httpclient.c"],
    "flags": [
      "-DH2O_USE_LIBUV=0",
      "-DH2O_USE_BROTLI=1",
    ] + (os_flags[b.target.os] || []),
    "c_deps": [zig.cDep(b.dep(":libh2o"), "h2o")],
    "libc": true,
  })
  b.installExe(exe)
}
