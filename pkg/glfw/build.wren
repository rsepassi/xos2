import "os" for Process

var getAddlSrcs_ = Fn.new { |b|
  if (b.target.os == "macos") return b.glob("src/*.m")
  return []
}

var platform = {
  "macos": {
    "flags": ["-D_GLFW_COCOA"],
    "ldflags": ["-framework", "Cocoa", "-framework", "IOKit"],
  },
  "linux": {
    "flags": ["-D_GLFW_X11"],
    "ldflags": [],
  },
  "windows": {
    "flags": ["-D_GLFW_WIN32"],
    "ldflags": [],
  },
}

var glfw = Fn.new { |b, args|
  var url = "https://github.com/glfw/glfw/archive/refs/tags/3.4.tar.gz"
  var url_hash = "c038d34200234d071fae9345bc455e4a8f2f544ab60150765d7704e08f3dac01"
  Process.chdir(b.untar(b.fetch(url, url_hash)))

  System.print(Process.cwd)

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "glfw", {
    "c_srcs": b.glob("src/*.c") + getAddlSrcs_.call(b),
    "flags": platform[b.target.os]["flags"],
    "libc": true,
    "sdk": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "glfw", {
    "ldflags": platform[b.target.os]["ldflags"],
    "sdk": true,
    "libc": true,
  }))
  b.installDir("", "include")
}

var example = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "app", {
    "root": b.src("app.zig"),
    "c_deps": [
      b.dep(":glfw"),
    ],
    "ldflags": ["-framework", "OpenGL"],
  })
  b.installExe(exe)
}
