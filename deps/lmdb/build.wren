import "os" for Process

var lmdb = Fn.new { |b, args|
  var src = b.untar(b.src("lmdb-0.9.31.tar.gz"))
  Process.chdir("%(src)/libraries/liblmdb")

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "lmdb", {
    "c_srcs": ["mdb.c", "midl.c"],
    "flags": (b.target.abi == "android") ? ["-DMDB_USE_ROBUST=0"] : [],
    "libc": true,
  })

  b.installHeader("lmdb.h")
  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
}
