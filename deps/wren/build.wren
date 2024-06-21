import "io" for Directory, File
import "os" for Process, Path

var wren_to_c_string = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "wren_to_c_string", {
    "c_srcs": [b.src("wren_to_c_string.c")],
    "libc": true,
  })
  b.install("bin", exe)
}

var wren_module_include = Fn.new { |b, args|
  var wren_to_c_string = b.deptool(":wren_to_c_string").exe("wren_to_c_string")
  for (m in args) {
    var name = Path.basename(m).split(".")[0]
    var out = "%(name).wren.inc"
    File.open(m) { |src_f|
      File.create(out) { |dst_f|
          Process.spawn([wren_to_c_string, name], null, [src_f.fd, dst_f.fd, 2])
      }
    }
    b.installArtifact(out)
  }
}

var wren = Fn.new { |b, args|
  var modules = b.dep(":wren_module_include", [b.src("src/optional/wren_opt_meta.wren")])

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "wren", {
    "c_srcs": b.srcGlob("src/vm/*.c") + b.srcGlob("src/optional/*.c"),
    "flags": [
      "-I%(b.srcDir("src/include"))",
      "-I%(b.srcDir("src/vm"))",
      "-I%(b.srcDir("src/optional"))",
      "-I%(modules.path)/share",
      "-DWREN_OPT_META=1",
      "-DWREN_OPT_RANDOM=0",
    ],
    "libc": true,
  })
  b.installLib(lib)
  b.installHeader(b.src("src/include/wren.h"))
}
