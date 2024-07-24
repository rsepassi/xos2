var discovery = Fn.new { |b, args|

}

var client = Fn.new { |b, args|

}

var client_example = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "example", {
    "root": b.src("client_example.zig"),
    "modules": {
      "uv": b.dep("//deps/libuv:zig"),
      "zigcoro": b.dep("//deps/zigcoro"),
    },
    "libc": true,
  })
  b.installExe(exe)
}
