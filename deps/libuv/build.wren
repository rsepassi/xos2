import "io" for Directory
import "os" for Process

var libuv = Fn.new { |b, args|
  var src = b.untar(b.src("libuv-1.48.0.tar.gz"))
  Process.chdir(src)

  var os = OS[b.target.os]

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "uv", {
    "c_srcs": os["files"] + b.glob("src/*.c"),
    "c_flags": ["-std=gnu89"],
    "flags": Defines + os["flags"] + [
      "-Iinclude",
      "-Isrc",
    ],
    "libc": true,
  })
  b.install("lib", lib)

  var headers = os["headers"] + [
    "include/uv/version.h",
    "include/uv/threadpool.h",
    "include/uv/errno.h",
  ]
  b.install("include", "include/uv.h")
  b.install("include/uv", headers)
  b.installLibConfig(zig.libConfig(b, "uv"))
}

var Defines = [
  "-DPACKAGE_NAME=\"libuv\"",
  "-DPACKAGE_TARNAME=\"libuv\"",
  "-DPACKAGE_VERSION=\"1.48.0\"",
  "-DPACKAGE_STRING=\"libuv 1.48.0\"",
  "-DPACKAGE_BUGREPORT=\"https://github.com/libuv/libuv/issues\"",
  "-DPACKAGE_URL=\"\"",
  "-DPACKAGE=\"libuv\"",
  "-DVERSION=\"1.48.0\"",
  "-DSUPPORT_ATTRIBUTE_VISIBILITY_DEFAULT=1",
  "-DSUPPORT_FLAG_VISIBILITY=1",
  "-DHAVE_STDIO_H=1",
  "-DHAVE_STDLIB_H=1",
  "-DHAVE_STRING_H=1",
  "-DHAVE_INTTYPES_H=1",
  "-DHAVE_STDINT_H=1",
  "-DHAVE_STRINGS_H=1",
  "-DHAVE_SYS_STAT_H=1",
  "-DHAVE_SYS_TYPES_H=1",
  "-DHAVE_UNISTD_H=1",
  "-DSTDC_HEADERS=1",
]

var UnixFiles = [
  "src/unix/async.c",
  "src/unix/core.c",
  "src/unix/dl.c",
  "src/unix/fs.c",
  "src/unix/getaddrinfo.c",
  "src/unix/getnameinfo.c",
  "src/unix/loop-watcher.c",
  "src/unix/loop.c",
  "src/unix/pipe.c",
  "src/unix/poll.c",
  "src/unix/process.c",
  "src/unix/random-devurandom.c",
  "src/unix/signal.c",
  "src/unix/stream.c",
  "src/unix/tcp.c",
  "src/unix/thread.c",
  "src/unix/tty.c",
  "src/unix/udp.c",
]

var OS = {
  "linux": {
    "files": UnixFiles + [
      "src/unix/linux.c",
      "src/unix/procfs-exepath.c",
      "src/unix/proctitle.c",
      "src/unix/random-getrandom.c",
      "src/unix/random-sysctl-linux.c",
    ],
    "flags": [
      "-I./src/unix",
      "-D_GNU_SOURCE",
      "-DHAVE_DLFCN_H=1",
      "-DHAVE_PTHREAD_PRIO_INHERIT=1",
    ],
    "headers": [
      "include/uv/linux.h",
      "include/uv/unix.h",
    ],
  },
  "macos": {
    "files": UnixFiles + [
      "src/unix/bsd-ifaddrs.c",
      "src/unix/darwin-proctitle.c",
      "src/unix/darwin.c",
      "src/unix/fsevents.c",
      "src/unix/kqueue.c",
      "src/unix/proctitle.c",
      "src/unix/random-getentropy.c",
    ],
    "flags": [
      "-I./src/unix",
      "-D_DARWIN_USE_64_BIT_INODE=1",
      "-D_DARWIN_UNLIMITED_SELECT=1",
      "-DHAVE_DLFCN_H=1",
      "-DHAVE_PTHREAD_PRIO_INHERIT=1",
    ],
    "headers": [
      "include/uv/darwin.h",
      "include/uv/unix.h",
    ],
  },
}
