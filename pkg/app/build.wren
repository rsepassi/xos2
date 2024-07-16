import "io" for File, Directory
import "os" for Path, Process
import "log" for Logger
import "flagparse" for FlagParser

import "build/config" for Config

var Log = Logger.get("appbuild")

var glfw_wgpu_glue = Fn.new { |b, args|
  var wgpu = b.dep("//pkg/wgpu")
  var glfw = b.dep("//pkg/glfw")

  var srcs = [b.src("glfw_wgpu_glue.c")]
  if (b.target.os == "macos") srcs = ["-x", "objective-c"] + srcs

  var glfw_flags = {
    "windows": "-DGLFW_EXPOSE_NATIVE_WIN32",
    "macos": "-DGLFW_EXPOSE_NATIVE_COCOA",
    "linux": "-DGLFW_EXPOSE_NATIVE_X11",
  }

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "glfw_wgpu_glue", {
    "c_srcs": srcs,
    "c_deps": [
      zig.cDep(wgpu, "wgpu_native"),
      glfw,
    ],
    "flags": [
      glfw_flags[b.target.os],
    ],
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}

var twod = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.install("zig", zig.moduleConfig(b, {
    "root": b.src("twod.zig"),
  }))
}

var ios = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "ios", {
    "c_srcs": [b.src("ios.m")],
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}

var android = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var deps = [b.dep("//sdk/android:native_app_glue")]
  var lib = zig.buildLib(b, "android", {
    "c_srcs": [b.src("android.c")],
    "c_deps": deps,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "android", {
    "deps": deps,
  }))
}

var app = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var cdeps = []
  if (b.target.os == "ios") {
    cdeps.add(b.dep(":ios"))
  } else if (b.target.os == "linux" && b.target.abi == "android") {
    cdeps.add(b.dep(":android"))
  }
  b.install("zig", zig.moduleConfig(b, {
    "root": b.src("main.zig"),
    "c_deps": cdeps,
  }))
}

var gpu = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.install("zig", zig.moduleConfig(b, {
    "root": b.src("appgpu.zig"),
    "modules": {
      "gpu": zig.moduleDep(b.dep("//pkg/wgpu:zig"), "gpu"),
      "twod": b.dep(":twod"),
    },
    "c_deps": b.target.isDesktop ? [b.dep(":glfw_wgpu_glue")] : null,
  }))
}

class AppBuilder {
  construct new(dir) { _b = dir.build }

  build(b, opts) {
    var zig = b.deptool("//toolchains/zig")

    if (b.target.isDesktop) {
      var exe = zig.buildExe(b, "app", {
        "root": b.dep("//pkg/app"),
        "c_deps": [
          b.dep("//pkg/glfw"),
        ],
        "modules": {
          "userlib": opts["module"],
        },
      })

      var appdir = Directory.create(Path.join([b.mktmpdir(), "app"]))
      File.rename(exe, Path.join([appdir, Path.basename(exe)]))
      if (opts["resources"]) Directory.copy(opts["resources"], Path.join([appdir, "xos-resources"]))
      return appdir
    } else if (b.target.os == "ios") {
      var lib_opts = {
        "root": b.dep("//pkg/app"),
        "modules": {
          "userlib": opts["module"],
        },
      }
      var lib = zig.buildLib(b, "app", lib_opts)

      var zargs = zig.buildArgs(b, lib_opts)

      var xcode = b.deptool("//pkg/app:xcodeproj")
      var ldargs = [lib]
      ldargs.addAll(zargs.link)
      var appdir = xcode.build(b, ldargs, opts["resources"])

      return appdir
    } else if (b.target.os == "linux" && b.target.abi == "android") {
      var lib_opts = {
        "root": b.dep("//pkg/app"),
        "modules": {
          "userlib": opts["module"],
        },
        "ldflags": ["-landroid", "-lnativewindow", "-llog", "-lvulkan", "-ldl"],
        "libc": true,
      }
      var lib = zig.buildDylib(b, "app", lib_opts)
      var droid = b.deptool("//pkg/app:androidproj", ["--name=xos", "--org=xos", "--pkg=xos"])
      var appdir = droid.build(b, lib, opts["resources"])
      return appdir
    } else {
      Fiber.abort("unrecognized platform for app packaging %(b.target)")
    }
  }
}

class builder {
  static call(b, args) {
  }

  static wrap(dir) { AppBuilder.new(dir) }
}

class XcodeBuilder {
  construct new(dir) {
    _dir = dir
  }

  build(b, ldargs, resource_dir) {
    var platform = b.target.abi == "simulator" ? "iphonesimulator" : "iphoneos"
    Process.chdir(b.mktmpdir())
    Directory.copy(_dir.build.srcDir("xcode"), "xos-app")

    if (resource_dir) {
      Directory.copy(resource_dir, "xos-app/xos-app/xos-resources")
    } else {
      Directory.create("xos-app/xos-app/xos-resources")
    }

    var config = [0, "Debug"].contains(b.opt_mode) ? "Debug" : "Release"

    var args = [
      "xcodebuild",
      "-configuration", config,
      "-target", "xos-app",
      "-arch", b.target.arch == "aarch64" ? "arm64" : "x86_64",
      "-sdk", "%(platform)17.2",
      "-project", "./xos-app/xos-app.xcodeproj",
      "OTHER_LDFLAGS=%(ldargs.join(" "))",
      "build",
    ]
    var env = Process.env()
    env["HOME"] = Config.get("system_home")
    b.system(args, env, Log.level == Log.DEBUG ? [null, 1, 2] : null)
    return "%(Process.cwd)/xos-app/build/%(config)-%(platform)/xos-app.app"
  }
}

class xcodeproj {
  static call(b, args) {
    b.srcDir("xcode")
  }

  static wrap(dir) { XcodeBuilder.new(dir) }
}

class AndroidBuilder {
  construct new(dir) {
    _dir = dir
  }

  build(b, dylib, resource_dir) {
    var tmpdir = b.mktmpdir()
    Process.chdir(Directory.copy("%(_dir.path)/app", "%(tmpdir)/app-build"))
    Directory.ensure("app/src/main/jniLibs/arm64-v8a")
    File.rename(dylib, "app/src/main/jniLibs/arm64-v8a/libapp.so")

    if (resource_dir) {
      Directory.copy(resource_dir, "app/src/main/assets")
    } else {
      Directory.create("xos-app/xos-app/xos-resources")
    }


    var droid = b.dep("//sdk/android")

    var env = droid.sdkenv

    Process.child(["./gradlew", ":app:assembleRelease"])
      .stdout(1).stderr(2)
      .env(env)
      .run()
    Process.child(["apksigner", "sign", "--ks", "%(env["ANDROID_HOME"])/keystore/debug.keystore", "--ks-pass", "pass:android", "app/build/outputs/apk/release/app-release-unsigned.apk"])
      .stdout(1).stderr(2)
      .env(env)
      .run()

    return File.rename("%(tmpdir)/app-build/app/build/outputs/apk/release", "%(tmpdir)/app")



    // todo: return output directory
  }
}

class androidproj {
  static call(b, args) {
    var parser = FlagParser.new("androidproj", [
      FlagParser.Flag.new("name", {"required": true}),
      FlagParser.Flag.new("org", {"required": true}),
      FlagParser.Flag.new("pkg", {"required": true}),
    ])
    if (args.isEmpty) {
      parser.help()
      Fiber.abort("incorrect usage")
    }
    var flags = parser.parse(args)

    Directory.copy(b.srcDir("android-project"), "app")

    File.replace("app/app/build.gradle", "xos_org", flags["org"])
    File.replace("app/app/build.gradle", "xos_pkg_name", flags["pkg"])
    File.replace("app/settings.gradle", "xos-app-name", flags["name"])
    File.replace("app/app/src/main/res/values/strings.xml", "xos-app-name", flags["name"])

    b.installDir("", "app")
  }

  static wrap(dir) { AndroidBuilder.new(dir) }
}
