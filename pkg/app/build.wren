import "io" for File, Directory
import "os" for Path

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

var app = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.install("zig", zig.moduleConfig(b, {
    "root": b.src("main.zig"),
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
    "c_deps": [b.dep(":glfw_wgpu_glue")],
  }))
}

class AppBuilder {
  construct new(dir) { _b = dir.build }

  build(b, opts) {

    var zig = b.deptool("//toolchains/zig")
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
    if (opts["resources"]) Directory.copy(opts["resources"], appdir)
    return appdir
  }
}

class builder {
  static call(b, args) {

  }

  static wrap(dir) { AppBuilder.new(dir) }
}
