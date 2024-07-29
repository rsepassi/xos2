import "io" for File

var lemon = Fn.new { |b, args|
  var url = "https://sqlite.org/src/raw/d048516b2c3ad4119b1c1154a73f4f9435b275fea076318959f817effe23b827?at=lemon.c"
  var hash = "3661d01cb826d443a0148d93e440d3891d27782d0c3c0656e187968febb49bc0"
  var url2 = "https://sqlite.org/src/raw/e6b649778e5c027c8365ff01d7ef39297cd7285fa1f881cce31792689541e79f?at=lempar.c"
  var hash2 = "d4f6ee3b4d439e42318ac9563d712c503cb68c0cb302e51616656ae53e80723b"
  var src = b.fetch(url, hash)
  var src2 = b.fetch(url2, hash2)
  src = File.copy(src, "lemon.c")
  src2 = File.copy(src2, "lempar.c")
  var zig = b.deptool("//toolchains/zig")
  var exe = zig.buildExe(b, "lemon", {
    "c_srcs": [src],
    "libc": true,
  })
  b.installExe(exe)
  b.installArtifact(src2)
}
