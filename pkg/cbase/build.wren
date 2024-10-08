import "io" for Directory, File

var mkbasedir = Fn.new { |b|
  Directory.create("base")
  var headers = b.srcGlob("*.h")
  for (h in headers) File.copy(h, "base")
  var klib = b.dep("//pkg/klib")
  File.copy(klib.header("khash.h"), "base")
}

var cbase_zig = Fn.new { |b, args|
  mkbasedir.call(b)

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "cbase_zig", {
    "opt": "Fast",
    "flags": ["-I."],
    "root": b.src("cbase.zig"),
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}

var cbase = Fn.new { |b, args|
  var cflags = []
  var os = {
    "macos": "MACOS",
    "windows": "WINDOWS",
    "linux": "LINUX",
    "ios": "IOS",
  }
  cflags.add("-DCBASE_OS_%(os[b.target.os])")
  var abi = {
    "musl": "MUSL",
    "android": "ANDROID",
    "gnu": "GNU",
    "none": "NONE",
  }
  cflags.add("-DCBASE_ABI_%(abi[b.target.abi] || "NONE")")
  var arch = {
    "aarch64": "AARCH64",
    "x86_64": "X86_64",
  }
  cflags.add("-DCBASE_ARCH_%(arch[b.target.arch])")

  if (b.target.isDesktop) {
    cflags.add("-DCBASE_OS_DESKTOP")
  } else {
    cflags.add("-DCBASE_OS_MOBILE")
  }

  mkbasedir.call(b)

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "cbase", {
    "flags": ["-I."] + cflags,
    "c_srcs": b.srcGlob("*.c"),
    "libc": true,
    "sdk": b.target.isMobile,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "cbase", {
    "cflags": cflags,
    "deps": [b.dep(":cbase_zig")],
    "libc": true,
  }))
  b.install("include", "base")
}

var test = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.installExe(zig.buildExe(b, "test", {
    "c_srcs": [b.src("test/test.c")],
    "c_deps": [
      b.dep(":cbase"),
      b.dep("//pkg/munit"),
    ],
  }))
}
