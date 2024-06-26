import "io" for Directory, File
import "os" for Process

var xos = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "xos", {
    "root": b.src("xos/xos.zig"),
    "c_deps": [
      b.dep("//deps/wren"),
      b.dep("//deps/ucl"),
      b.dep("//deps/lmdb"),
    ],
    "libc": true,
  })
  b.installLib(lib)
}

var wrencli = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")

  var module_srcs = [
    "glob",
    "io",
    "os",
    "repl",
    "scheduler",
    "timer",
  ].map { |x| "module/%(x).wren" }

  var wren_modules = [
    "module/glob.wren",
    "module/io.wren",
    "module/os.wren",
    "module/repl.wren",
    "module/scheduler.wren",
    "module/timer.wren",
  ]
  var modules = b.mktmpdir()
  b.deptool("//deps/wren:wren_to_c_string").run(modules, b.srcs(wren_modules))

  var exe = zig.buildExe(b, "wren", {
    "c_srcs": b.srcGlob("cli/*.c") + b.srcGlob("module/*.c"),
    "flags": [
      "-I%(b.srcDir("module"))",
      "-I%(b.srcDir("cli"))",
      "-I%(modules)",

    ],
    "c_deps": [
      zig.cDep(b.dep("//deps/libglob"), "glob"),
      zig.cDep(b.dep("//deps/libuv"), "uv"),
      b.dep("//deps/lmdb"),
      b.dep("//deps/ucl"),
      b.dep("//deps/wren"),
      b.dep(":xos"),
    ],
    "libc": true,
  })
  b.installExe(exe)
}
