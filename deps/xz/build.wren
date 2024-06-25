import "os" for Process, Path
import "io" for File

import "build/patch" for Patch

var Url = "https://github.com/tukaani-project/xz/archive/refs/tags/v5.2.2.tar.gz"
var Hash = "578694987c14d73b2d075f477d89006522b91c88890f45a1d231cd29d555e00e"

var xz = Fn.new { |b, args|
  var src = b.untar(b.fetch(Url, Hash), {})
  Process.chdir(src)

  File.copy(b.src("build.zig"))
  File.copy(b.src("platform/config-%(b.target.os).h"), "config.h")
  Patch.read(b.src("windows.patch")).apply()

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.build(b, {})

  b.installDir("", "zig-out/include")
  b.installDir("", "zig-out/bin")
  b.installDir("", "zig-out/lib")
  b.installLibConfig(zig.libConfig(b, "lzma"))
}
