import "io" for File

var image = Fn.new { |b, args|
  var src = File.copy(b.fetch("https://raw.githubusercontent.com/nothings/stb/013ac3b/stb_image.h",
                              "594c2fe35d49488b4382dbfaec8f98366defca819d916ac95becf3e75f4200b3"),
                      "stb_image.h")

  File.write("stb_image.c", "#define STB_IMAGE_IMPLEMENTATION 1\n#include \"stb_image.h\"\n")

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "stb_image", {
    "flags": [
      "-DSTBI_NO_STDIO",
    ],
    "c_srcs": ["stb_image.c"],
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "stb_image"))
  b.installHeader(src)
}

var image_write = Fn.new { |b, args|
  var src = File.copy(b.fetch("https://raw.githubusercontent.com/nothings/stb/013ac3b/stb_image_write.h",
                              "cbd5f0ad7a9cf4468affb36354a1d2338034f2c12473cf1a8e32053cb6914a05"),
                      "stb_image_write.h")

  File.write("stb_image_write.c", "#define STB_IMAGE_WRITE_IMPLEMENTATION 1\n#include \"stb_image_write.h\"\n")

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "stb_image_write", {
    "flags": [
      "-DSTBI_WRITE_NO_STDIO",
    ],
    "c_srcs": ["stb_image_write.c"],
    "libc": true,
  })
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "stb_image_write"))
  b.installHeader(src)
}
