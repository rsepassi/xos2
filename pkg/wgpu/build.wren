import "io" for File
import "os" for Process

import "build/patch" for Patch

var wgpu_header = Fn.new { |b, args|
  var header = b.fetch("https://raw.githubusercontent.com/webgpu-native/webgpu-headers/aef5e428a1fdab2ea770581ae7c95d8779984e0a/webgpu.h",
    "defb965756966d04186f80fb193994cfa70b375247da7a34d20608662216a50f")
  File.copy(header, "webgpu.h")
  b.installHeader("webgpu.h")
}

var wgpu_platform = {
  "macos-none": {
    "ldflags": ["-framework", "Metal", "-framework", "QuartzCore"]
  },
  "windows-gnu": {
    "ldflags": "-lunwind -lopengl32 -ldxgi -ld3d11 -lkernel32 -luser32 -ld3dcompiler".split(" "),
  },
  "linux-musl": {
    "ldflags": ["-lunwind"],
  },
  "linux-gnu": {
    "ldflags": ["-lunwind"],
  },
  "linux-android": {
    "ldflags": [],
  },
  "ios-none": {
    "ldflags": ["-framework", "Foundation", "-framework", "UIKit", "-framework", "Metal", "-framework", "MetalKit"],
  },
  "ios-simulator": {
    "ldflags": ["-framework", "Foundation", "-framework", "UIKit", "-framework", "Metal", "-framework", "MetalKit"],
  },
}

var wgpu = Fn.new { |b, args|
  var url = "https://api.github.com/repos/gfx-rs/wgpu-native/tarball/33133da"
  var url_hash = "bb55824cda330f594ca23864cfc5a0b0b9b483174baa8807edb8caabfba02708"
  Process.chdir(b.untar(b.fetch(url, url_hash)))

  var header = b.dep(":wgpu_header")
  File.copy("%(header.path)/include/webgpu.h", "ffi/webgpu-headers/webgpu.h")
  File.copy(b.src("bindings.rs"), "ffi/bindings.rs")

  Patch.read(b.src("wgpu.patch")).apply()

  var rust = b.deptool("//toolchains/rust")
  var lib = rust.buildLib(b, "wgpu_native", {})

  var platform_str = "%(b.target.os)-%(b.target.abi)"
  var is_android = platform_str == "linux-android"
  var c_deps = is_android ? [b.dep("//pkg/unwind_dummy")] : []

  b.installHeader("ffi/wgpu.h")
  b.installHeader("ffi/webgpu-headers/webgpu.h")
  b.installLib(lib)
  b.installLibConfig(rust.libConfig(b, "wgpu_native", {
    "ldflags": wgpu_platform[platform_str]["ldflags"],
    "sdk": true,
    "deps": c_deps,
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
