import "os" for Process

var wasm3 = Fn.new { |b, args|
  var url = "https://api.github.com/repos/wasm3/wasm3/tarball/139076a"
  var hash = "371969b7c4cef827203f6d9d642b8575b5056ad66e9ed29586b1c15965b940ef"
  Process.chdir(b.untar(b.fetch(url, hash)))
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "wasm3", {
    "c_srcs": b.glob("source/*.c"),
    "libc": true,
  })
  var exe = zig.buildExe(b, "wasm3", {
    "flags": ["-Isource"],
    "c_srcs": ["platforms/app/main.c", lib],
    "libc": true,
  })
  b.installLib(lib)
  b.installExe(exe)
  b.installHeader([
    "source/wasm3.h",
    "source/wasm3_defs.h",
  ])
}
