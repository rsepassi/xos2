import "os" for Process
import "io" for File

var parse = Fn.new { |b, args|
  var lemon = b.deptool("//pkg/lang/lemon")
  var p = Process.child([lemon.exe("lemon"), "-d.", "-T%(lemon.artifact("lempar.c"))", b.src("wren.y")]).spawn()
  var code = p.waitCode()

  var tokens = File.read("wren.h").split("\n")
    .where { |s| s.count > 1 }
    .map { |s| s.split(" ")[1] }
    .toList
  tokens = ["__TOKENS_PAD"] + tokens
  var enum_str = tokens.map { |s| "  %(s),\n" }.join("")
  File.copy(b.src("wren.h.in"), "wren.h")
  File.replace("wren.h", "@@TokenType@@", enum_str)

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "parse", {
    "c_srcs": ["wren.c"],
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installArtifact("wren.out")
  b.installHeader("wren.h")
}

var lex = Fn.new { |b, args|
  var parse = b.dep(":parse")
  var re2c = b.deptool("//pkg/lang/re2c").exe("re2c")
  Process.spawn([re2c, b.src("wren.c.re"), "-o", "wren.c", "--storable-state", "--case-ranges"])
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "lex", {
    "flags": ["-I", parse.includeDir],
    "c_srcs": ["wren.c"],
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}

var wren2 = Fn.new { |b, args|
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
