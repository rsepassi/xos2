import "os" for Process
import "io" for File

var re2c = Fn.new { |b, args|
  var url = "https://github.com/skvadrik/re2c/archive/refs/tags/3.1.tar.gz"
  var hash = "087c44de0400fb15caafde09fd72edc7381e688a35ef505ee65e0e3d2fac688b"
  Process.chdir(b.untar(b.fetch(url, hash)))
  var srcs = b.glob("src/**/*.cc") + b.glob("bootstrap/src/**/*.cc")
  srcs = srcs.where { |f| !f.endsWith("test.cc") }
  File.copy(b.src("config.h"))
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "re2c", {
    "flags": [
      "-DHAVE_CONFIG_H",
      "-DRE2C_STDLIB_DIR=\"\"",
      "-I.",
      "-Ibootstrap",
    ],
    "c_srcs": srcs,
    "c_flags": ["-std=c++11"],
    "libc++": true,
  })
  b.installExe(exe)
}
