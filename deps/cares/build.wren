import "os" for Process, Path
import "io" for File

var Url = "https://github.com/c-ares/c-ares/releases/download/cares-1_27_0/c-ares-1.27.0.tar.gz"
var Hash = "0a72be66959955c43e2af2fbd03418e82a2bd5464604ec9a62147e37aceb420b"

var cares = Fn.new { |b, args|
  var src = b.untar(b.fetch(Url, Hash), {})
  Process.chdir(src)

  File.copy(b.src("platform/config-%(b.target.os).h"), "src/lib/ares_config.h")
  File.copy(b.src("platform/build-%(b.target.os).h"), "include/ares_build.h")

  var srcs = b.glob("src/lib/ares_*.c")
  srcs.addAll(b.glob("src/lib/inet_*.c"))
  srcs.add("src/lib/windows_port.c")

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "cares", {
    "c_srcs": srcs,
    "flags": [
      "-Iinclude",
      "-Isrc/lib",
      "-DHAVE_CONFIG_H",
      "-DCARES_BUILDING_LIBRARY",
      "-DCARES_STATICLIB",
    ] + (b.target.os == "windows" ? ["-lws2_32", "-liphlpapi"] : []),
    "libc": true,
  })

  b.installHeader(b.glob("include/*.h"))
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "cares"))
}
