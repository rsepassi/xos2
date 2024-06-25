import "io" for Directory
import "os" for Process

var lmdb = Fn.new { |b, args|
  Directory.create("lmdb")
  var src = b.untar(b.src("lmdb-0.9.31.tar.gz"))
  Process.chdir("%(src)/libraries/liblmdb")

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "lmdb", {
    "c_srcs": ["mdb.c", "midl.c"],
    "libc": true,
  })

  b.install("lib", lib)
  b.install("include", "lmdb.h")
}
