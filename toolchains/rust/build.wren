import "os" for Process, Path
import "io" for File, Directory
import "log" for Logger

var Log = Logger.get("rust")

class rust {
  static call(b, args) {
    var base = b.deptool("//toolchains/rust/base")
    var runner = b.deptool("//:wrenbox").exe("wrenbox")
    b.install("tools", runner)

    var installFn
    if (b.target.os == "windows") {
      installFn = Fn.new { |tool| File.copy(runner, tool) }
    } else {
      installFn = Fn.new { |tool| File.symlink("wrenbox", tool) }
    }

    installFn = b.target.os == "windows" ?
      Fn.new { |tool| File.copy(runner, tool) } :
      Fn.new { |tool| File.symlink("wrenbox", tool) }

    var tools = ["rustcc", "cc", "ar", "strip", "xcrun"]
    for (tool in tools) {
      b.install("tools", b.src("%(tool).wren"))
      installFn.call(tool)
      b.install("tools", tool)
    }
  }

  static wrap(dir) {
    import "./wrap" for Rust
    return Rust.new(dir)
  }
}

var example = Fn.new { |b, args|
  var rust = b.deptool(":rust")
  Process.chdir(Directory.copy(b.srcDir("example"), "example"))
  var exe = rust.buildExe(b, "example", {

  })
  b.installExe(exe)
}

var example_lib = Fn.new { |b, args|
  var rust = b.deptool(":rust")
  Process.chdir(Directory.copy(b.srcDir("example"), "example"))
  var exe = rust.buildLib(b, "example", {

  })
  b.installLib(exe)
}
