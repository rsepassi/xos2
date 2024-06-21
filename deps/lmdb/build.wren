import "io" for Directory
import "os" for Process

var lmdb = Fn.new { |b, args|
  Directory.create("lmdb")
  var tar = b.src("lmdb-0.9.31.tar.gz")
  Process.spawn(["tar", "xf", tar, "--strip-components=1", "-C", "lmdb"], null)
  Process.chdir("lmdb/libraries/liblmdb")

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "lmdb", {
    "c_srcs": ["mdb.c", "midl.c"],
    "libc": true,
  })
  b.install("lib", lib)
  b.install("include", "lmdb.h")
}
