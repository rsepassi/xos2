import "io" for File
import "os" for Process

import "log" for Logger
var Log = Logger.get("libarchive")

var Url = "https://www.libarchive.org/downloads/libarchive-3.7.2.tar.xz"
var Hash = "04357661e6717b6941682cde02ad741ae4819c67a260593dfb2431861b251acb"

var libarchive = Fn.new { |b, args|
  var src = b.untar(b.fetch(Url, Hash))
  Process.chdir(src)

  File.copy(b.src("platform/config-%(b.target.os).h"), "libarchive/config.h")

  var zig = b.deptool("//toolchains/zig")

  var mbedtls = b.dep("//deps/mbedtls")

  var lib = zig.buildLib(b, "archive", {
    "c_srcs": b.glob("libarchive/*.c"),
    "flags": [
      "-DHAVE_CONFIG_H",
      "-DLIBARCHIVE_STATIC",
      "-D__LIBARCHIVE_ENABLE_VISIBILITY",
    ],
    "c_flags": [
      "-include", "%(mbedtls.includeDir)/mbedtls/compat-2.x.h",
    ],
    "c_deps": [
      b.dep("//deps/zstd"),
      zig.cDep(mbedtls, "mbedcrypto"),
      zig.cDep(b.dep("//deps/xz"), "lzma"),
      zig.cDep(b.dep("//deps/zlib"), "z"),
    ],
    "libc": true,
    "sdk": true,
  })

  b.installHeader("libarchive/archive.h")
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "archive"))
}

var archive_fe = Fn.new { |b, args|
  var src = b.untar(b.fetch(Url, Hash))
  Process.chdir(src)

  var zig = b.deptool("//toolchains/zig")

  File.copy(b.src("platform/config-%(b.target.os).h"), "libarchive_fe/config.h")

  var lib = zig.buildLib(b, "archive_fe", {
    "c_srcs": b.glob("libarchive_fe/*.c"),
    "flags": [
      "-DHAVE_CONFIG_H",
      "-DLIBARCHIVE_STATIC",
      "-D__LIBARCHIVE_ENABLE_VISIBILITY",
    ],
    "c_deps": [
      zig.cDep(b.dep(":libarchive"), "archive"),
    ],
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "archive_fe"))
}

var bsdtar = Fn.new { |b, args|
  if (b.opt_mode == "Debug") {
    Log.err("bsdtar known to crash in Debug builds")
  }
  var src = b.untar(b.fetch(Url, Hash))
  Process.chdir(src)

  var zig = b.deptool("//toolchains/zig")

  File.copy(b.src("platform/config-%(b.target.os).h"), "tar/config.h")

  var exe = zig.buildExe(b, "bsdtar", {
    "c_srcs": [
      "tar/bsdtar.c",
      "tar/cmdline.c",
      "tar/creation_set.c",
      "tar/read.c",
      "tar/subst.c",
      "tar/util.c",
      "tar/write.c",
      "tar/bsdtar_windows.c",
    ],
    "flags": [
      "-DHAVE_CONFIG_H",
      "-Ilibarchive",
      "-Ilibarchive_fe",
    ],
    "c_deps": [
      zig.cDep(b.dep(":libarchive"), "archive"),
      b.dep(":archive_fe"),
      b.dep("//deps/zstd"),
      zig.cDep(b.dep("//deps/mbedtls"), "mbedcrypto"),
      zig.cDep(b.dep("//deps/xz"), "lzma"),
      zig.cDep(b.dep("//deps/zlib"), "z"),
    ],
    "libc": true,
  })

  b.installExe(exe)
}
