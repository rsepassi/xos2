import "os" for Process
import "io" for File

var parse = Fn.new { |b, args|
  var lemon = b.deptool("//pkg/lang/lemon")
  var p = Process.child([lemon.exe("lemon"), "-d.", "-T%(lemon.artifact("lempar.c"))", b.src("ry0.y")]).stderr(1).spawn()
  if (p.waitCode() != 0) Fiber.abort("%(Process.cwd)/ry0.out")

  var tokens = File.read("ry0.h").split("\n")
    .where { |s| s.count > 1 }
    .map { |s| s.split(" ")[1] }
    .toList
  tokens = ["__TOKENS_PAD"] + tokens
  var enum_str = tokens.map { |s| "  %(s),\n" }.join("")
  File.copy(b.src("ry0.h.in"), "ry0.h")
  File.replace("ry0.h", "@@TokenType@@", enum_str)

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "parse", {
    "c_srcs": ["ry0.c"],
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installArtifact("ry0.out")
  b.installHeader("ry0.h")
}

var lex = Fn.new { |b, args|
  var parse = b.dep(":parse")
  var re2c = b.deptool("//pkg/lang/re2c").exe("re2c")
  Process.spawn([re2c, b.src("ry0.c.re"), "-o", "ry0.c", "--storable-state", "--case-ranges"])
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "lex", {
    "flags": ["-I", parse.includeDir],
    "c_srcs": ["ry0.c"],
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}

var codegen = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var parse = b.dep(":parse")
  var lib = zig.buildLib(b, "codegen", {
    "flags": ["-I", b.srcDir, "-I", parse.includeDir],
    "c_srcs": [b.src("codegen.c")],
    "c_deps": [
      b.dep("//pkg/cbase"),
      b.dep("//pkg/lang/mir"),
    ],
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}

var ry0 = Fn.new { |b, args|
  var lex = b.dep(":lex")
  var parse = b.dep(":parse")
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "test", {
    "flags": [
      "-I", parse.includeDir,
    ],
    "c_srcs": [
      b.src("test.c"),
    ],
    "c_deps": [
      lex,
      parse,
      b.dep(":codegen"),
      b.dep("//pkg/cbase"),
      b.dep("//pkg/lang/mir"),
    ],
    "libc": true,
  })
  b.installExe(exe)
  b.install("bin", b.src("syntax.ry"))
}

var c2 = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": [b.src("c2.c")],
    "flags": ["-I", b.srcDir],
    "include": [b.src("c2.h")],
    "deps": [
      b.dep("//pkg/cbase"),
      b.dep("//pkg/klib"),
    ],
    "libc": true,
  })
}

var c2_test = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "test", {
    "c_srcs": [
      b.src("c2_test.c"),
    ],
    "c_deps": [
      b.dep(":c2"),
    ],
    "libc": true,
  })
  b.installExe(exe)
}
