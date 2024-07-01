import "os" for Process

var skip_prefixes = [
  "-Wl,-exported_symbols_list",
]
var skip_suffixes = [
  "crti.o",
  "crt1.o",
]
var skip_args = [
  "-Wl,-dylib",
  "-no-pie",
  "-lgcc",
  "-lgcc_s",
]

var main = Fn.new { |args|
  var filtered = []
  for (arg in args) {
    for (p in skip_prefixes) {
      if (arg.startsWith(p)) continue
    }
    for (s in skip_suffixes) {
      if (arg.endsWith(s)) continue
    }
    for (a in skip_args) {
      if (arg == a) continue
    }

    filtered.add(arg)
  }

  var zig = Process.env("XOS_RUSTCC_ZIG")

  var zigargs = [
    zig, "cc", "-O2"
  ] + filtered
  Process.spawn(zigargs, null, [null, 1, 2])
}

main.call(Process.arguments)
