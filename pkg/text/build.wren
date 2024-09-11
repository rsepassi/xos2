var text = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": [b.src("text.c")],
    "include": [b.src("text.h")],
    "deps": [
      b.dep("//pkg/harfbuzz"),
      b.dep("//pkg/freetype"),
      b.dep("//pkg/cbase"),
    ],
  })
}
