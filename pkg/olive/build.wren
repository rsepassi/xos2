import "io" for File

var olive = Fn.new { |b, args|
  // var f = b.fetch(
  //   "https://raw.githubusercontent.com/tsoding/olive.c/9d410b1/olive.c",
  //   "14887c5f712082ad02d173c45a01f55a5a7813dab1894cea37083f7712517b3d")
  File.copy(b.src("olive.c"), "olive.h")

  File.write("olive.c", "#include \"olive.h\"")
  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": ["olive.c"],
    "include": ["olive.h"],
    "flags": ["-DOLIVECDEF=extern", "-DOLIVEC_IMPLEMENTATION"],
  })

}
