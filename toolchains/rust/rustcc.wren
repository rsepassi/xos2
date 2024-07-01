import "os" for Process

var skip_prefixes = [
  "--target=",
  "-Wl,-exported_symbols_list",
  "-lwinapi_",
]
var skip_suffixes = [
  "crti.o",
  "crt1.o",
]
var skip_args = [
  "-Wl,-dylib",
  "-Wl,-Bdynamic",
  "-Wl,-O1",
  "-Wl,--disable-auto-image-base",
  "-no-pie",
  "-lgcc",
  "-lgcc_eh",
  "-lgcc_s",
  "-lmsvcrt",
  "-l:libpthread.a",
]

var main = Fn.new { |args|
  var filtered = []
  for (arg in args) {
    var skip = false
    for (p in skip_prefixes) {
      if (arg.startsWith(p)) {
        skip = true
        break
      }
    }
    if (skip) continue

    for (s in skip_suffixes) {
      if (arg.endsWith(s)) {
        skip = true
        break
      }
    }
    if (skip) continue

    for (a in skip_args) {
      if (arg == a) {
        skip = true
        break
      }
    }
    if (skip) continue

    if (arg.startsWith("-l") && arg.endsWith(".dll")) {
      filtered.add(arg[0..-4])
    }

    filtered.add(arg)
  }

  var opt = Process.env("XOS_RUSTCC_OPT")
  var target = Process.env("XOS_RUSTCC_TARGET")
  var zig = Process.env("XOS_RUSTCC_ZIG")
  var flags = Process.env("XOS_RUSTCC_CFLAGS").split(" ")

  var zigargs = [
    zig, "cc", "-target", target, "-O%(opt)"
  ]
  zigargs.addAll(flags)
  zigargs.addAll(filtered)
  System.print(zigargs)
  Process.spawn(zigargs, null, [null, 1, 2])
}

main.call(Process.arguments)
