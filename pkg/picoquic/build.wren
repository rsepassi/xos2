import "os" for Process

import "build/patch" for Patch

var getSrc = Fn.new { |b|
  var url = "https://api.github.com/repos/private-octopus/picoquic/tarball/2a4c45a"
  var hash = "688c09115c5f62cd2027a2d4ec7d73963a6b50d0ee7ef6b00768c85c6274d6bf"
  var out = b.untar(b.fetch(url, hash))
  Process.chdir(out)
  Patch.read(b.src("picoquic.patch")).apply()
  return out
}

var picoquic = Fn.new { |b, args|
  getSrc.call(b)
  var deps = [
    b.dep("//pkg/crypto/picotls"),
  ]
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "picoquic", {
    "c_srcs": b.glob("picoquic/*.c") +
    b.glob("picoquic_mbedtls/*.c"),
    "flags": [
      "-Ipicoquic_mbedtls",
      "-DPTLS_WITHOUT_OPENSSL",
      "-DPTLS_WITHOUT_FUSION",
      "-DPICOQUIC_WITH_MBEDTLS",
      "-DPICOQUIC_WITHOUT_SSLKEYLOG",
    ],
    "c_deps": deps,
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b, "picoquic", {
    "deps": deps,
  }))
  b.installHeader([
    "picoquic/picoquic.h",
    "picoquic/picosocks.h",
    "picoquic/picoquic_utils.h",
    "picoquic/picoquic_packet_loop.h",
    "picoquic/picoquic_unified_log.h",
    "picoquic/picoquic_logger.h",
    "picoquic/picoquic_binlog.h",
    "picoquic/picoquic_config.h",
    "picoquic/picoquic_lb.h",
    "picoquic_mbedtls/ptls_mbedtls.h",
  ])
}

var loglib = Fn.new { |b, args|
  getSrc.call(b)
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "loglib", {
    "c_srcs": b.glob("loglib/*.c"),
    "flags": [
      "-Ipicoquic",
    ],
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installHeader(b.glob("loglib/*.h"))
}

var picohttp = Fn.new { |b, args|
  getSrc.call(b)
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "picohttp", {
    "c_srcs": b.glob("picohttp/*.c"),
    "flags": [
      "-Ipicoquic",
    ],
    "c_deps": [
      b.dep(":picoquic"),
    ],
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installHeader(b.glob("picohttp/*.h"))
}

var h3demo = Fn.new { |b, args|
  getSrc.call(b)

  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "demo", {
    "c_srcs": ["picoquicfirst/picoquicdemo.c"],
    "flags": [
      "-Ipicoquic",
    ],
    "c_deps": [
      b.dep(":picoquic"),
      b.dep(":picohttp"),
      b.dep(":loglib"),
    ],
    "libc": true,
  })

  b.installExe(exe)
}

var demo = Fn.new { |b, args|
  getSrc.call(b)

  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "demo", {
    "c_srcs": b.glob("sample/*.c"),
    "c_deps": [
      b.dep(":picoquic"),
      b.dep(":loglib"),
    ],
    "libc": true,
  })
  b.installExe(exe)
}

var uvdemo = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")

  var deps = [
    b.dep(":picoquic"),
    b.dep("//pkg/cbase"),
    zig.cDep(b.dep("//deps/libuv"), "uv"),
  ]

  var client = zig.buildExe(b, "client", {
    "c_srcs": [b.src("uvdemo/client.c")],
    "c_deps": deps,
    "libc": true,
  })
  var server = zig.buildExe(b, "server", {
    "c_srcs": [b.src("uvdemo/server.c")],
    "c_deps": deps,
    "libc": true,
  })

  b.installExe(client)
  b.installExe(server)
}
