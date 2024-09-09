import "io" for File

var Url = "https://github.com/rsepassi/xos/releases/download/macos-sdk-14.2-v5/macossdk.tar.gz"
var Hash = "61121dae9a1a7afd3199e43860995093ea40cd0110a4728b2a9546e1c784e99f"

var macos = Fn.new { |b, args|
  var dir = b.untar(b.fetch(Url, Hash))
  File.rename(dir, "%(b.installDir)/sdk")
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
