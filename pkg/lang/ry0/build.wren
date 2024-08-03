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

var ry0 = Fn.new { |b, args|
  var lex = b.dep(":lex")
  var parse = b.dep(":parse")
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "test", {
    "flags": ["-I", parse.includeDir],
    "c_srcs": [b.src("test.c")],
    "c_deps": [lex, parse],
    "libc": true,
  })
  b.installExe(exe)
}
