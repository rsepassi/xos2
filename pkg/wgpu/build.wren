import "io" for File
import "os" for Process

var wgpu_header = Fn.new { |b, args|
  var header = b.fetch("https://raw.githubusercontent.com/webgpu-native/webgpu-headers/aef5e428a1fdab2ea770581ae7c95d8779984e0a/webgpu.h",
    "defb965756966d04186f80fb193994cfa70b375247da7a34d20608662216a50f")
  File.copy(header, "webgpu.h")
  b.installHeader("webgpu.h")
}

var wgpu_platform = {
  "macos": {
    "ldflags": ["-framework", "Metal", "-framework", "QuartzCore"]
  },
  "windows": {
    "ldflags": "-lunwind -lopengl32 -ldxgi -ld3d11 -lkernel32 -luser32 -ld3dcompiler".split(" "),
  },
  "linux": {
    "ldflags": ["-lunwind"],
  },
  "ios": {
    "ldflags": ["-framework", "Foundation", "-framework", "UIKit", "-framework", "Metal", "-framework", "MetalKit"],
  },
}

var wgpu = Fn.new { |b, args|
  var url = "https://api.github.com/repos/gfx-rs/wgpu-native/tarball/33133da"
  var url_hash = "bb55824cda330f594ca23864cfc5a0b0b9b483174baa8807edb8caabfba02708"
  Process.chdir(b.untar(b.fetch(url, url_hash)))

  var header = b.dep(":wgpu_header")
  File.copy("%(header.path)/include/webgpu.h", "ffi/webgpu-headers/webgpu.h")

  var toml = File.read("Cargo.toml")
  toml = toml.replace("\"cdylib\",", "")
  File.write("Cargo.toml", toml)

  var rust = b.deptool("//toolchains/rust")
  var lib = rust.buildLib(b, "wgpu_native", {})

  b.installHeader("ffi/wgpu.h")
  b.installHeader("ffi/webgpu-headers/webgpu.h")
  b.installLib(lib)
  b.installLibConfig(rust.libConfig(b, "wgpu_native", {
    "ldflags": wgpu_platform[b.target.os]["ldflags"],
    "sdk": true,
    "libc": true,
  }))
}

var zig = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.install("zig", zig.moduleConfig(b, "gpu", {
    "root": b.src("gpu.zig"),
    "c_deps": [zig.cDep(b.dep(":wgpu"), "wgpu_native")],
  }))
}
