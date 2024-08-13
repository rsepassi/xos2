var test = Fn.new { |b, args|
  b.srcGlob("*.h")
  var zig = b.deptool("//toolchains/zig")

  b.srcGlob("*.h")
  b.srcGlob("*.zig")

  var impl = zig.buildLib(b, "kv", {
    "root": b.src("interface.zig"),
    "flags": ["-I", b.srcDir],
  })

  var exe = zig.buildExe(b, "test", {
    "c_srcs": [
      b.src("kv_test.c"),
      impl,
    ],
    "c_deps": [
      zig.cDep(b.dep("//deps/libuv"), "uv"),
    ],
    "libc": true,
  })
  b.installExe(exe)
}
