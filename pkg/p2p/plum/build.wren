import "os" for Process

var getSrc_ = Fn.new { |b|
  Process.chdir(b.untar(
      b.fetch("https://api.github.com/repos/paullouisageneau/libplum/tarball/ca2fa31",
      "993f42159847f4c3de57b5b44533ddee09b368f8b494edf47ce136350c2a6d77")))
}

var plum = Fn.new { |b, args|
  getSrc_.call(b)
  var zig = b.deptool("//toolchains/zig")

  var ldflags = b.target.os == "windows" ?
    ["-lws2_32", "-lbcrypt", "-liphlpapi"] :
    []

  var lib = zig.buildLib(b, "plum", {
    "flags": ["-Iinclude/plum", "-DPLUM_STATIC=1"],
    "c_srcs": b.glob("src/*.c"),
    "libc": true,
  })
  b.installLib(lib)
  b.installHeaderDir("include")
  b.installLibConfig(zig.libConfig(b, "plum", {
    "cflags": ["-DPLUM_STATIC=1"],
    "ldflags": ldflags,
  }))
}

var example = Fn.new { |b, args|
  getSrc_.call(b)
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "run", {
    "c_srcs": ["example/main.c"],
    "c_deps": [b.dep(":plum")],
    "libc": true,
  })
  b.installExe(exe)
}
