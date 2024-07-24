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
  b.installLibConfig(zig.libConfig(b, "uv", {
    "ldflags": os["ldflags"] || [],
    "libc": true,
  }))
}

var zig = Fn.new { |b, args|
  var zig = b.deptool("//toolchains/zig")
  b.srcGlob("zig/*.zig")
  b.install("zig", zig.moduleConfig(b, {
    "root": b.src("zig/uv.zig"),
    "modules": {
      "zigcoro": b.dep("//deps/zigcoro"),
    },
    "c_deps": [zig.cDep(b.dep(":libuv"), "uv")],
  }))
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
  "freebsd": {
    "files": UnixFiles + [
      "src/unix/bsd-ifaddrs.c",
      "src/unix/bsd-proctitle.c",
      "src/unix/freebsd.c",
      "src/unix/kqueue.c",
      "src/unix/posix-hrtime.c",
      "src/unix/random-getrandom.c",
    ],
    "flags": [
      "-I./src/unix",
      "-D_GNU_SOURCE",
      "-DHAVE_DLFCN_H=1",
      "-DHAVE_PTHREAD_PRIO_INHERIT=1",
    ],
    "headers": [
      "include/uv/bsd.h",
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
  "windows": {
    "files": [
      "src/win/async.c",
      "src/win/core.c",
      "src/win/detect-wakeup.c",
      "src/win/dl.c",
      "src/win/error.c",
      "src/win/fs-event.c",
      "src/win/fs.c",
      "src/win/getaddrinfo.c",
      "src/win/getnameinfo.c",
      "src/win/handle.c",
      "src/win/loop-watcher.c",
      "src/win/pipe.c",
      "src/win/poll.c",
      "src/win/process-stdio.c",
      "src/win/process.c",
      "src/win/signal.c",
      "src/win/stream.c",
      "src/win/tcp.c",
      "src/win/thread.c",
      "src/win/tty.c",
      "src/win/udp.c",
      "src/win/util.c",
      "src/win/winapi.c",
      "src/win/winsock.c",
    ],
    "flags": [
      "-I./src/win",
      "-DWIN32_LEAN_AND_MEAN",
      "-D_FILE_OFFSET_BITS=64",
    ],
    "headers": [
      "include/uv/win.h",
      "include/uv/tree.h",
    ],
    "ldflags": [
      "-lws2_32",
      "-luserenv",
      "-lole32",
      "-liphlpapi",
      "-ldbghelp",
    ],
  },
}
OS["ios"] = OS["macos"]
