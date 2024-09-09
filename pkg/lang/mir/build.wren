import "os" for Process
import "io" for File

import "build/patch" for Patch

var Url = "https://api.github.com/repos/vnmakarov/mir/tarball/d6dffef"
var Hash = "4b0747283e822a02ca545502f1c68e5f9368e92a54635007520421ee1a529bc7"

var Fetch = Fn.new { |b|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  Patch.read(b.src("mir.patch")).apply()
}

var mir = Fn.new { |b, args|
  Fetch.call(b)

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "mir", {
    "opt": "Fast",
    "flags": ["-I.", "-DMIR_PARALLEL_GEN"] + (b.target.os == "linux" ? ["-D_GNU_SOURCE"] : []),
    "c_flags": ["-std=c11", "-fsigned-char", "-g"],
    "c_srcs": [
      "mir.c",
      "mir-gen.c",
      "c2mir/c2mir.c",
    ],
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
	File.copy("real-time.h", "mir-real-time.h")
  b.installHeader([
    "mir.h",
    "mir-dlist.h",
    "mir-varr.h",
    "mir-htab.h",
    "mir-gen.h",
    "mir-real-time.h",
  ])
}

var utilexe = Fn.new { |b, args|
  Fetch.call(b)
  var zig = b.deptool("//toolchains/zig")
  b.installExe(zig.buildExe(b, b.label.target, {
    "flags": (args["flags"] || []) + (b.target.os == "linux" ? ["-D_GNU_SOURCE"] : []),
    "c_srcs": [args["src"]],
    "c_deps": [b.dep(":mir")],
    "libc": true,
  }))
}

var m2b = Fn.new { |b, args| utilexe.call(b, {"src": "mir-utils/m2b.c"}) }
var b2m = Fn.new { |b, args| utilexe.call(b, {"src": "mir-utils/b2m.c"}) }
var b2ctab = Fn.new { |b, args| utilexe.call(b, {"src": "mir-utils/b2ctab.c"}) }
var m2c = Fn.new { |b, args|
  utilexe.call(b, {
    "flags": ["-DMIR2C"],
    "src": "mir2c/mir2c.c",
  })
}

var driver = Fn.new { |b, args|
  Fetch.call(b)
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "mir", {
    "c_srcs": [b.src("driver.c")],
    "c_deps": [
      b.dep(":mir"),
      b.dep("//pkg/cbase"),
    ],
    "libc": true,
  })
  b.installExe(exe)
}

var libdriver = Fn.new { |b, args|
  Fetch.call(b)
  var interp = args.count > 0 && args[0] == "--interpret"
  var zig = b.deptool("//toolchains/zig")
  var deps = [b.dep(":mir")]
  var lib = zig.buildLib(b, b.label.target, {
    "flags": ["-DMIR_BIN_DEBUG"] +
      (interp ? ["-DMIR_USE_INTERP"] : []) +
      (b.target.os == "linux" ? ["-D_GNU_SOURCE"] : []),
    "c_srcs": [b.src("driver.c")],
    "c_deps": deps,
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "libdriver", {
    "deps": deps,
  }))
}

class Mir {
  static buildExe(b, name, args) {
    var m2b = b.deptool("//pkg/lang/mir:m2b").exe("m2b")
    File.open(args["src"]) { |fin|
      File.create("src.mirb") { |fout|
        Process.child([m2b])
          .stdin(fin)
          .stdout(fout)
          .stderr(2)
          .run()
      }
    }

    var b2ctab = b.deptool("//pkg/lang/mir:b2ctab").exe("b2ctab")
    File.open("src.mirb") { |fin|
      File.create("src.mir.c") { |fout|
        Process.child([b2ctab])
          .stdin(fin)
          .stdout(fout)
          .stderr(2)
          .run()
      }
    }

    var zig = b.deptool("//toolchains/zig")
    var exe = zig.buildExe(b, name, {
      "c_srcs": ["src.mir.c"],
      "c_deps": [
        b.dep(":libdriver", args["interpret"] ? ["--interpret"] : []),
      ],
      "libc": true,
    })

    return exe
  }
}

var test = Fn.new { |b, args|
  var exe = Mir.buildExe(b, "hello", {
    "src": b.src("hello.mir"),
  })
  b.installExe(exe)
}
