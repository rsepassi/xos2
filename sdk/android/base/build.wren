import "io" for File, Directory
import "os" for Process

import "build/config" for Config

var CmdLineToolsUrl = {
  "windows": {
    "url": "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip",
    "hash": "4d6931209eebb1bfb7c7e8b240a6a3cb3ab24479ea294f3539429574b1eec862",
  },
  "macos": {
    "url": "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip",
    "hash": "7bc5c72ba0275c80a8f19684fb92793b83a6b5c94d4d179fc5988930282d7e64",
  },
  "linux": {
    "url": "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip",
    "hash": "2d2d50857e4eb553af5a6dc3ad507a17adf43d115264b1afc116f95c92e5e258",
  },
}

var RepoOs = {
  "macos": "macosx",
  "linux": "linux",
  "windows": "windows",
}

var base = Fn.new { |b, args|
  var dir = b.toolCacheDir

  Directory.ensure("%(dir)/cmdline-tools")
  if (!Directory.exists("%(dir)/cmdline-tools/latest")) {
    var tools = CmdLineToolsUrl[b.target.os]
    var pkg = b.untar(b.fetch(tools["url"], tools["hash"]))
    File.rename(pkg, "%(dir)/cmdline-tools/latest")
  }
  var bindir = "%(dir)/cmdline-tools/latest/bin"

  Directory.ensure("%(dir)/keystore")
  File.copy(b.src("debug.keystore"), "%(dir)/keystore/debug.keystore")

  var sdk_args = [
    "sdkmanager",
    "ndk-bundle",
    "platforms;android-34",
    "platform-tools",
    "emulator",
    "system-images;android-29;google_apis;arm64-v8a",
  ]
  var env = Process.env()
  env["PATH"] = Process.pathJoin([env["PATH"], bindir, Config.get("system_path")])
  env["PATH"] = Process.pathJoin([env["PATH"], bindir])
  env["ANDROID_HOME"] = dir
  env["ANDROID_SDK_ROOT"] = dir
  env["ANDROID_AVD_HOME"] = "%(dir)/avd"
  env["REPO_OS_OVERRIDE"] = RepoOs[b.target.os]
  env["JAVA_HOME"] = Process.spawnCapture(["/usr/libexec/java_home"])["stdout"].trim()

  var sdk_process = Process.child(sdk_args).env(env)
    .stdout(1).stderr(2)
    .spawn()
  for (i in 0..5) sdk_process.echo("y")
  sdk_process.wait()

  var avd_args = ["avdmanager", "create", "avd", "--force", "-n", "testEmulator", "-k", "system-images;android-29;google_apis;arm64-v8a", "--device", "pixel_7"]
  var avd_process = Process.child(avd_args).env(env)
    .stdout(1).stderr(2)
    .spawn()
  avd_process.echo("no")
  avd_process.wait()

  File.write("readme.txt", "android command line tools installed in %(dir)\n")
  b.install("", "readme.txt")
}
