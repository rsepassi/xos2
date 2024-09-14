var app2 = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")

  var deps = [
    b.dep("//pkg/cbase"),
    b.dep("//pkg/olive"),
    b.dep("//pkg/text"),
  ]
  var flags = []

  if (b.target.isDesktop) {
    var os_flags = {
      "macos": "-DAPP_PLATFORM_OS_MACOS",
      "linux": "-DAPP_PLATFORM_OS_LINUX",
      "windows": "-DAPP_PLATFORM_OS_WINDOWS",
    }
    flags.add("-DAPP_PLATFORM_OS_DESKTOP")
    flags.add(os_flags[b.target.os])
    var desktop_deps = [
      b.dep("//pkg/glfw"),
      b.dep("//pkg/glfw/nativefb"),
    ]
    deps.addAll(desktop_deps)
  }

  var lib = zig.buildLib(b, "app2", {
    "flags": ["-I", b.srcDir("include")] + flags,
    "c_srcs": [b.src("src/app.c")],
    "c_deps": deps,
  })

  b.installLib(lib)
  b.installHeaderDir(b.srcDir("include"))
  b.installLibConfig(zig.libConfig(b, "app2", {
    "cflags": flags,
    "deps": deps,
  }))
}

class Builder {
  construct new(dir) { _dir = dir }
  build(b, opts) {
    var zig = b.deptool("//toolchains/zig")
    var exe = zig.buildExe(b, opts["name"] || b.label.target, {
      "c_deps": opts["deps"],
    })
    return exe
  }
}

class builder {
  static call(b, args) {}
  static wrap(dir) { Builder.new(dir) }
}
