import "os" for Process
import "io" for File, Directory

var podman = Fn.new { |b, args|
  if (args.count < 1) Fiber.abort("must pass a base image and (optionally) a list of packages")
  var image = args[0]
  var pkgs = args.count > 1 ? args[1].split(",") : []

  var arch = b.target.arch == "aarch64" ? "arm64" : b.target.arch

  var libinstall
  var libinclude
  if (image.startsWith("alpine")) {
    libinstall = "usr/lib"
    libinclude = "usr/lib"
  } else if (image.startsWith("debian")) {
    libinstall = "usr/lib"
    libinclude = "usr/lib/%(arch)-linux-gnu"
  } else {
    Fiber.abort("the podman target currently supports alpine and debian, got %(image)")
  }

  var cmds = []
  if (!pkgs.isEmpty) {
    if (image.startsWith("alpine")) {
      cmds.add(["apk", "add"] + pkgs)
    } else if (image.startsWith("debian")) {
      cmds.add(["apt-get", "update"])
      cmds.add(["apt-get", "install", "-y"] + pkgs)
    }
  }

  File.create("podman_pid") { |pid|
    b.systemExport(["podman", "run", "--arch", arch, "-d", image, "sleep", "10000000"], null, [null, pid.fd, null])
  }
  var pid = File.read("podman_pid").trim()
  for (cmd in cmds) {
    b.systemExport(["podman", "exec", pid] + cmd)
  }
  var archive_path = "export.tar.gz"
  b.systemExport(["podman", "export", pid, "-o", archive_path])
  b.systemExport(["podman", "kill", pid])
  Process.chdir(b.untar(archive_path, {"strip": 0}))

  Directory.ensure("%(b.installDir)/sdk/usr")
  File.rename(libinclude, "%(b.installDir)/sdk/%(libinstall)")
  if (Directory.exists("usr/include")) b.installDir("sdk/usr", "usr/include")

  var zig = b.deptool("//toolchains/zig")
  b.installLibConfig(zig.libConfig(b, "sdk", {
    "nostdopts": true,
    "cflags": ["-I{{root}}/sdk/usr/include"],
    "ldflags": ["-L{{root}}/sdk/%(libinstall)"],
  }))
}

var debianX11 = Fn.new { |b, args|
  var sdk = b.dep(":podman", ["debian:bookworm", "libx11-dev,libxcursor-dev,libxrandr-dev,libxinerama-dev,libxi-dev,libgl1-mesa-dev"])
  File.rename("%(sdk.path)/sdk", "%(b.installDir)/sdk")
  File.rename("%(sdk.path)/lib", "%(b.installDir)/lib")
}

var alpineX11 = Fn.new { |b, args|
  var sdk = b.dep(":podman", ["alpine:3.19", "libx11-dev,libxcursor-dev,libxrandr-dev,libxinerama-dev,libxi-dev,mesa-dev"])

  Directory.ensure("%(b.installDir)/sdk/usr/include")
  Directory.ensure("%(b.installDir)/sdk/usr/lib")

  var root = "%(sdk.path)/sdk"
  var libs = [
    "libX11.so.6.4.0",
    "libX11.so.6",
    "libX11.so",
  ]
  for (lib in libs) {
    File.copy("%(root)/usr/lib/%(lib)", "%(b.installDir)/sdk/usr/lib/%(lib)")
  }

  var incdirs = [
    "X11",
    "GL",
    "KHR",
  ]
  for (dir in incdirs) {
    Directory.copy("%(root)/usr/include/%(dir)", "%(b.installDir)/sdk/usr/include/%(dir)")
  }

  var zig = b.deptool("//toolchains/zig")
  b.installLibConfig(zig.libConfig(b, "sdk", {
    "nostdopts": true,
    "cflags": ["-I{{root}}/sdk/usr/include"],
    "ldflags": ["-L{{root}}/sdk/usr/lib"],
  }))
}
