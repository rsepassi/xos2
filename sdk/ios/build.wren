import "io" for File
import "os" for Process

var Url = "https://github.com/rsepassi/xos/releases/download/ios-sdk-17.2-1/ios.tar.gz"
var Hash = "958ba7fbb13a8df4b8ac0dfa056c0826008badc92453148b1c3d28f2d22084df"

var ios = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  var dir = b.target.arch == "simulator" ? "ios-sim" : "ios"
  File.rename("%(dir)/sdk", "%(b.installDir)/sdk")

  File.write("libc.txt", GetLibc_.call("%(b.installDir)/sdk"))
  b.install("sdk", "libc.txt")
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
crt_dir=

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
