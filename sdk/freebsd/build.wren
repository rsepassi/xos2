import "os" for Process, Path
import "io" for Directory, File

var Url = "https://artifact.ci.freebsd.org/snapshot/14.0-STABLE/2472e352d80fcf6440fd42fbb16960cc49d05b03/amd64/amd64/base.txz"
var Hash = "09c7067870c2eb67fc3049714e64169460d59c7ae9f6962a64a362d5dbfa1a8c"

var freebsd = Fn.new { |b, args|
  if (!(b.target.os == "freebsd" && b.target.arch == "x86_64")) {
    Fiber.abort("only available for x86_64-freebsd")
  }

  Process.chdir(b.untar(b.fetch(Url, Hash), {
    "args": [
      "./lib",
      "./usr/lib",
      "./usr/include",
    ],
    "exclude": ["./usr/lib/include"],
    "strip": 0,
  }))

  var sdkdir = Directory.ensure(Path.join([b.installDir, "sdk"]))
  var usrdir = Directory.ensure(Path.join([b.installDir, "sdk", "usr"]))

  Directory.copy("lib", sdkdir)
  Directory.copy("usr/include", usrdir)
  Directory.copy("usr/lib", usrdir)

  File.write("libc.txt", GetLibc_.call("%(b.installDir)/sdk"))
  File.copy("libc.txt", "%(sdkdir)/libc.txt")
}

var GetLibc_ = Fn.new { |root|
    var template = """
# The directory that contains `stdlib.h`.
# On POSIX-like systems, include directories be found with: `cc -E -Wp,-v -xc /dev/null`
include_dir={{root}}/usr/include

# The system-specific include directory. May be the same as `include_dir`.
# On Windows it's the directory that includes `vcruntime.h`.
# On POSIX it's the directory that includes `sys/errno.h`.
sys_include_dir={{root}}/usr/include

# The directory that contains `crt1.o` or `crt2.o`.
# On POSIX, can be found with `cc -print-file-name=crt1.o`.
# Not needed when targeting MacOS.
crt_dir={{root}}/usr/lib

# The directory that contains `vcruntime.lib`.
# Only needed when targeting MSVC on Windows.
msvc_lib_dir=

# The directory that contains `kernel32.lib`.
# Only needed when targeting MSVC on Windows.
kernel32_lib_dir=

# The directory that contains `crtbeginS.o` and `crtendS.o`
# Only needed when targeting Haiku.
gcc_dir=
    """
    return template.replace("{{root}}", root)
}
