import "os" for Process

var main = Fn.new { |args|
  var zig = Process.env("XOS_RUSTCC_ZIG")
  var zigargs = [zig, "ar"] + args
  System.print(zigargs)
  Process.spawn(zigargs, null, [null, 1, 2])
}

main.call(Process.arguments)
