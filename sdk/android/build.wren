import "io" for File, Directory
import "os" for Process, Path
import "json" for JSON

import "build/config" for Config

var RepoOs = {
  "macos": "macosx",
  "linux": "linux",
  "windows": "windows",
}

class Android {
  construct new(dir) {
    _dir = dir
    _env = JSON.parse(File.read("%(_dir.path)/env.json"))
  }

  sdkroot { _env["ANDROID_HOME"] }
  installDir { _dir }
  sdkenv {
    var env = Process.env()
    var path = env["PATH"]
    for (x in _env) {
      env[x.key] = x.value
    }
    env["PATH"] = Process.pathJoin([path, env["PATH"], Config.get("system_path")])
    return env
  }
}

class android {
  static call(b, args) {
    var base = b.deptool("base")
    var rootdir = base.build.toolCacheDir

    var unwind_dummy = b.dep("//pkg/unwind_dummy")

    var host_os = b.cls.Target.host.os
    if (host_os == "macos") host_os = "darwin"

    File.write("libc.txt", GetLibc_.call(rootdir, host_os))
    b.install("", "libc.txt")

    var zig = b.deptool("//toolchains/zig")
    b.install("", zig.libConfig(b, "sdk", {
      "nostdopts": true,
      "cflags": [
        "-I%(rootdir)/ndk-bundle/toolchains/llvm/prebuilt/%(host_os)-x86_64/sysroot/usr/include",
        "-I%(rootdir)/ndk-bundle/toolchains/llvm/prebuilt/%(host_os)-x86_64/sysroot/usr/include/aarch64-linux-android",
      ],
      "ldflags": [
        "-L%(rootdir)/ndk-bundle/toolchains/llvm/prebuilt/%(host_os)-x86_64/sysroot/usr/lib/aarch64-linux-android/29",
        "-L%(rootdir)/ndk-bundle/toolchains/llvm/prebuilt/%(host_os)-x86_64/sysroot/usr/lib/aarch64-linux-android",
        "%(unwind_dummy.path)/lib/libunwind_dummy.a",
      ],
    }))
    var env = sdkenv_(rootdir, b.cls.Target.host.os)
    File.write("env.json", JSON.stringify(env))
    b.install("", "env.json")
    File.write("env.sh", env.map { |el| "%(el.key)=%(el.value)" }.toList.join("\n"))
    b.install("", "env.sh")
  }

  static wrap(dir) { Android.new(dir) }

  static sdkenv_(rootdir, os) {
    var dir = rootdir
    var env = {}
    env["PATH"] = Process.pathJoin([
      "%(dir)/cmdline-tools/latest/bin",
      "%(dir)/build-tools/33.0.1",
      "%(dir)/emulator",
      "%(dir)/platform-tools",
    ])
    env["ANDROID_HOME"] = dir
    env["ANDROID_SDK_ROOT"] = dir
    env["ANDROID_AVD_HOME"] = "%(dir)/avd"
    env["REPO_OS_OVERRIDE"] = RepoOs[os]
    if (os == "macos") {
      env["JAVA_HOME"] = Process.spawnCapture(["/usr/libexec/java_home"])["stdout"].trim()
    } else if (os == "linux") {
      var link = Path.readLink("/usr/lib/jvm/default-jvm")
      if (!Path.isAbs(link)) link = Path.join(["/usr/lib/jvm", link])
      env["JAVA_HOME"] = link
    } else {
      Fiber.abort("finding JAVA_HOME is unimplemented on this OS")
    }
    env["GRADLE_USER_HOME"] = "%(dir)/gradle"
    return env
  }
}

var native_app_glue = Fn.new { |b, args|
  var base = b.deptool("base")
	var rootdir = base.build.toolCacheDir
  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "native_app_glue", {
    "c_srcs": ["%(rootdir)/ndk-bundle/sources/android/native_app_glue/android_native_app_glue.c"],
    "libc": true,
  })

  b.installLib(lib)
  b.installHeader("%(rootdir)/ndk-bundle/sources/android/native_app_glue/android_native_app_glue.h")
  b.installLibConfig(zig.libConfig(b, "native_app_glue", {
    "ldflags": ["--force_undefined", "ANativeActivity_onCreate", "-landroid", "-llog"],
  }))
}

var GetLibc_ = Fn.new { |root, os|
    var template = """
# The directory that contains `stdlib.h`.
# On POSIX-like systems, include directories be found with: `cc -E -Wp,-v -xc /dev/null`
include_dir={{root}}/ndk-bundle/toolchains/llvm/prebuilt/{{os}}-x86_64/sysroot/usr/include

# The system-specific include directory. May be the same as `include_dir`.
# On Windows it's the directory that includes `vcruntime.h`.
# On POSIX it's the directory that includes `sys/errno.h`.
sys_include_dir={{root}}/ndk-bundle/toolchains/llvm/prebuilt/{{os}}-x86_64/sysroot/usr/include

# The directory that contains `crt1.o` or `crt2.o`.
# On POSIX, can be found with `cc -print-file-name=crt1.o`.
# Not needed when targeting MacOS.
crt_dir={{root}}/ndk-bundle/toolchains/llvm/prebuilt/{{os}}-x86_64/sysroot/usr/lib/aarch64-linux-android/30

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
    return template.replace("{{root}}", root).replace("{{os}}", os)
}
