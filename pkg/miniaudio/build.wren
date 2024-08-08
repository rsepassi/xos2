import "io" for File

var miniaudio = Fn.new { |b, args|
  var url = "https://github.com/mackron/miniaudio/raw/4a5b74b/miniaudio.h"
  var hash = "6b2029714f8634c4d7c70cc042f45074e0565766113fc064f20cd27c986be9c9"
  var header = File.copy(b.fetch(url, hash), "miniaudio.h")
  var src = "miniaudio.c"
  File.write(src, "#define MINIAUDIO_IMPLEMENTATION\n#include \"miniaudio.h\"\n")
  var zig = b.deptool("//toolchains/zig")

  var ldflags = []
  var flags = b.opt_mode == "Debug" ? ["-DMA_DEBUG_OUTPUT"] : []
  if (["ios", "macos"].contains(b.target.os)) {
    flags.addAll(["-DMA_NO_RUNTIME_LINKING"])
    ldflags = ["-framework", "CoreAudio", "-framework", "AudioToolbox"]
    src = File.copy(src, "miniaudio.m")
  }

  var lib = zig.buildLib(b, "miniaudio", {
    "flags": flags,
    "c_srcs": [src],
    "libc": true,
    "sdk": true,
  })
  b.installHeader(header)
  b.installLib(lib)


  b.installLibConfig(zig.libConfig(b, "miniaudio", {
    "ldflags": ldflags,
  }))
}

var zig = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.install("zig", zig.moduleConfig(b, "zig", {
    "root": b.src("miniaudio.zig"),
    "c_deps": [b.dep(":miniaudio")],
  }))
}
