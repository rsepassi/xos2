import "io" for File, Directory
import "os" for Process

var android = Fn.new { |b, args|
  var base = b.deptool("base")
	var rootdir = base.build.toolCacheDir

  File.write("libc.txt", GetLibc_.call(rootdir))
  b.install("", "libc.txt")

  var zig = b.deptool("//toolchains/zig")
  b.installLibConfig(zig.libConfig(b, "platform", {
    "nostdopts": true,
    "cflags": [
      "-I%(rootdir)/ndk-bundle/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include",
      "-I%(rootdir)/ndk-bundle/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include/aarch64-linux-android",
      "-I%(rootdir)/ndk-bundle/sources/android/native_app_glue",
    ],
    "ldflags": [
      "-L%(rootdir)/ndk-bundle/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/29",
    ],
  }))
}

var GetLibc_ = Fn.new { |root|
    var template = """
# The directory that contains `stdlib.h`.
# On POSIX-like systems, include directories be found with: `cc -E -Wp,-v -xc /dev/null`
include_dir={{root}}/ndk-bundle/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include

# The system-specific include directory. May be the same as `include_dir`.
# On Windows it's the directory that includes `vcruntime.h`.
# On POSIX it's the directory that includes `sys/errno.h`.
sys_include_dir={{root}}/ndk-bundle/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include

# The directory that contains `crt1.o` or `crt2.o`.
# On POSIX, can be found with `cc -print-file-name=crt1.o`.
# Not needed when targeting MacOS.
crt_dir={{root}}/ndk-bundle/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/30

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
