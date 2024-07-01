import "os" for Process
var sccache = Fn.new { |b, args|
  var url = "https://github.com/mozilla/sccache/archive/refs/tags/v0.8.1.tar.gz"
  var hash = "30b951b49246d5ca7d614e5712215cb5f39509d6f899641f511fb19036b5c4e5"
  Process.chdir(b.untar(b.fetch(url, hash)))
  var rust = b.deptool("//toolchains/rust")
  var exe = rust.buildExe(b, "sccache", {"nocache": true})
  b.installExe(exe)
}
