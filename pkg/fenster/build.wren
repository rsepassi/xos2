var fenster = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")

  var deps = []
  var ldflags = []
  var sdk = false
  if (b.target.os == "linux") {
    ldflags = ["-lX11"]
    if (b.target.abi == "musl") {
      deps.add(zig.cDep(b.dep("//sdk/linux:alpineX11"), "sdk"))
    } else if (b.target.abi == "gnu") {
      deps.add(zig.cDep(b.dep("//sdk/linux:debianX11"), "sdk"))
    }
  } else if (b.target.os == "windows") {
    ldflags = ["-lgdi32", "--subsystem", "windows"]
  } else if (b.target.os == "macos") {
    ldflags = ["-framework", "Cocoa"]
    sdk = true
  }

  zig.ez.cLib(b, {
    "srcs": b.srcGlob("src/*"),
    "flags": ["-I", b.srcDir("include")],
    "includeDir": b.srcDir("include"),
    "deps": deps,
    "ldflags": ldflags,
    "libc": true,
    "sdk": sdk,
  })
}

var demo = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "demo", {
    "c_srcs": [b.src("example/demo.c")],
    "c_deps": [b.dep(":fenster")],
    "libc": true,
  })
  b.installExe(exe)
}
