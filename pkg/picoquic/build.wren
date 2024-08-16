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
    "c_srcs": b.glob("picoquic/*.c") + b.glob("picoquic_mbedtls/*.c"),
    "flags": [
      "-Ipicoquic_mbedtls",
      "-DPTLS_WITHOUT_OPENSSL",
      "-DPTLS_WITHOUT_FUSION",
      "-DPICOQUIC_WITH_MBEDTLS",
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
  ])
}

var demo = Fn.new { |b, args|
  getSrc.call(b)

  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "demo", {
    "c_srcs": ["picoquicfirst/picoquicdemo.c"] +
      b.glob("picohttp/*.c") +
      b.glob("loglib/*.c"),
    "flags": [
      "-Ipicoquic",
      "-Iloglib",
      "-Ipicohttp",
    ],
    "c_deps": [
      b.dep(":picoquic"),
    ],
    "libc": true,
  })

  b.installExe(exe)
}


