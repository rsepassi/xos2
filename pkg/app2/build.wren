import "io" for File, Directory
import "os" for Path

var app2 = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")

  var deps = [
    b.dep("//pkg/cbase"),
    b.dep("//pkg/olive"),
    b.dep("//pkg/text"),
    b.dep("//pkg/glfw/nativefb"),
  ]
  var flags = []

  var ldflags = []

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
    ]
    deps.addAll(desktop_deps)
  } else {
    var os_flags = {
      "ios": "-DAPP_PLATFORM_OS_IOS",
      "linux": "-DAPP_PLATFORM_OS_ANDROID",
    }
    flags.add("-DAPP_PLATFORM_OS_MOBILE")
    flags.add(os_flags[b.target.os])

    if (b.target.os == "linux") {
      deps.add(b.dep("//sdk/android:native_app_glue"))
    } else {
      ldflags.addAll([
        "-framework", "Foundation",
        "-framework", "UIKit",
        "-framework", "CoreGraphics",
      ])
    }
  }

  var lib = zig.buildLib(b, "app2", {
    "flags": ["-I", b.srcDir("include")] + flags,
    "c_srcs": b.srcGlob("src/*.c") + [b.src("src/app_ios.m")],
    "c_deps": deps,
  })

  b.installLib(lib)
  b.installHeaderDir(b.srcDir("include"))
  b.installLibConfig(zig.libConfig(b, "app2", {
    "cflags": flags,
    "ldflags": ldflags,
    "deps": deps,
  }))
}

class Builder {
  construct new(dir) { _dir = dir }
  build(b, opts) {
    var zig = b.deptool("//toolchains/zig")
    if (b.target.abi == "android") {
      var exe = zig.buildDylib(b, opts["name"] || b.label.target, {
        "c_deps": opts["deps"],
      })
      return exe
    } else if (b.target.os == "ios") {
      var lib_opts = {
        "c_deps": opts["deps"],
      }
      var zargs = zig.buildArgs(b, lib_opts)
      var xcode = b.deptool("//pkg/app:xcodeproj")
      var ldargs = zargs.link + zargs.platformLink
      var appdir = xcode.build(b, ldargs, opts["resources"])
      // Sim commands
      // xcrun simctl uninstall booted com.istudios.xos-app.hello
      // xcrun simctl install booted xos-out/bin/xos-app.app
      // xcrun simctl launch booted com.istudios.xos-app.hello
      return appdir
    } else {
      var tmp = b.mktmpdir()
      var exe = zig.buildExe(b, opts["name"] || b.label.target, {
        "c_deps": opts["deps"],
      })
      File.rename(exe, "%(tmp)/%(Path.basename(exe))")
      if (opts["resources"]) Directory.copy(opts["resources"], "%(tmp)/resources")
      return tmp
    }
  }
}

class builder {
  static call(b, args) {}
  static wrap(dir) { Builder.new(dir) }
}
