import "os" for Process

var getAddlSrcs_ = Fn.new { |b|
  if (b.target.os == "macos") return b.glob("src/*.m")
  return []
}

var glfw_platform = {
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
    "ldflags": ["-lws2_32", "-luserenv", "-lbcrypt", "-lgdi32", "--subsystem", "windows"],
  },
}

var glfw = Fn.new { |b, args|
  var url = "https://github.com/glfw/glfw/archive/refs/tags/3.4.tar.gz"
  var url_hash = "c038d34200234d071fae9345bc455e4a8f2f544ab60150765d7704e08f3dac01"
  Process.chdir(b.untar(b.fetch(url, url_hash)))

  var zig = b.deptool("//toolchains/zig")
  var deps = []
  if (b.target.os == "linux" && b.target.abi == "musl") {
    deps.add(zig.cDep(b.dep("//sdk/linux:alpineX11"), "sdk"))
  } else if (b.target.os == "linux" && b.target.abi == "gnu") {
    deps.add(zig.cDep(b.dep("//sdk/linux:debianX11"), "sdk"))
  }

  var lib = zig.buildLib(b, "glfw", {
    "c_srcs": b.glob("src/*.c") + getAddlSrcs_.call(b),
    "flags": glfw_platform[b.target.os]["flags"],
    "c_deps": deps,
    "libc": true,
    "sdk": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "glfw", {
    "ldflags": glfw_platform[b.target.os]["ldflags"],
    "deps": deps,
    "sdk": true,
    "libc": true,
  }))
  b.installDir("", "include")
}

var example_platform = {
  "macos": {
    "ldflags": ["-framework", "OpenGL"],
  },
  "linux": {
    "ldflags": ["-lGL"],
  },
  "windows": {
    "ldflags": ["-lopengl32"],
  },
}

var example = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var platform = example_platform[b.target.os]

  var deps = [
    b.dep(":glfw"),
  ]

  var exe = zig.buildExe(b, "app", {
    "root": b.src("app.zig"),
    "c_deps": deps,
    "ldflags": platform["ldflags"],
  })
  b.installExe(exe)
}
