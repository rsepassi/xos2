import "io" for Directory, File
import "os" for Process, Path

import "build/install_dir" for InstallDir

class wren_to_c_string {
  static call(b, args) {
    var zig = b.deptool("//toolchains/zig")
    var exe = zig.buildExe(b, "wren_to_c_string", {
      "c_srcs": [b.src("wren_to_c_string.c")],
      "libc": true,
    })
    b.install("bin", exe)
  }

  static wrap(dir) { new(dir) }

  construct new(dir) {
    _dir = dir
  }

  run(dir, args) {
    var exe = _dir.exe("wren_to_c_string")
    for (m in args) {
      var name = Path.basename(m).split(".")[0]
      var out = Path.join([dir, "%(name).wren.inc"])
      File.open(m) { |src_f|
        File.create(out) { |dst_f|
          Process.spawn([exe, name], null, [src_f.fd, dst_f.fd, 2])
        }
      }
    }
  }
}

var wren = Fn.new { |b, args|
  var modules = b.mktmpdir()
  b.deptool(":wren_to_c_string").run(modules, [
    b.src("src/optional/wren_opt_meta.wren"),
    b.src("src/vm/wren_core.wren"),
  ])

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "wren", {
    "c_srcs": b.srcGlob("src/vm/*.c") + b.srcGlob("src/optional/*.c"),
    "flags": [
      "-I%(b.srcDir("src/include"))",
      "-I%(b.srcDir("src/vm"))",
      "-I%(b.srcDir("src/optional"))",
      "-I%(modules)",
      "-DWREN_OPT_META=1",
      "-DWREN_OPT_RANDOM=0",
    ],
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installHeader(b.src("src/include/wren.h"))
}
