import "os" for Process, Path
import "io" for File
import "log" for Logger

var Log = Logger.get("rust")

var RustVersion = "1.76.0"
var RustupVersion = "1.26.0"

var RustPlatform = {
  "macos": {
    "aarch64": {
      "triple": "aarch64-apple-darwin",
      "hash": "ed299a8fe762dc28161a99a03cf62836977524ad557ad70e13882d2f375d3983",
    },
  },
  "linux": {
    "x86_64": {
      "triple": "x86_64-unknown-linux-musl",
      "hash": "7aa9e2a380a9958fc1fc426a3323209b2c86181c6816640979580f62ff7d48d4",
    },
  },
}

var base = Fn.new { |b, args|
  var platform = RustPlatform[b.target.os][b.target.arch]
  var rustup_file = b.target.exeName("rustup-init")
  var url = "https://static.rust-lang.org/rustup/archive/%(RustupVersion)/%(platform["triple"])/%(rustup_file)"
  var rustup_dl = b.fetch(url, platform["hash"])
  var rust_home = b.toolCacheDir
  Log.debug("rust home %(rust_home)")
  var rustup_init = Path.join([rust_home, "rustup-init"])
  File.copy(rustup_dl, rustup_init)
  File.chmod(rustup_init, "0o774")

  var rustup_args = [
    rustup_init,
    "-y", "-q",
    "--default-host", platform["triple"],
    "--default-toolchain", RustVersion,
    "--no-modify-path",
    "--profile", "minimal",
  ]
  var rustup_env = Process.env()
  rustup_env["HOME"] = rust_home

  Log.debug("rustup-init %(rustup_args)")
  Process.spawn(rustup_args, rustup_env)

  File.write("%(b.installDir)/readme.txt", "rust installed in %(b.toolCacheDir)")
}
