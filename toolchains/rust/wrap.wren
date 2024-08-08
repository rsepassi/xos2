import "io" for File
import "os" for Process, Path
import "log" for Logger

import "build/target" for Target

var Log = Logger.get("rust")

var RustTriples = {
  "aarch64-macos-none": {
    "triple": "aarch64-apple-darwin",
    "linker": "CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER",
  },
  "x86_64-macos-none": {
    "triple": "x86_64-apple-darwin",
    "linker": "CARGO_TARGET_X86_64_APPLE_DARWIN_LINKER",
  },
  "aarch64-linux-android": {
    "triple": "aarch64-linux-android",
    "linker": "CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER",
  },
  "aarch64-linux-musl": {
    "triple": "aarch64-unknown-linux-musl",
    "linker": "CARGO_TARGET_AARCH64_LINUX_MUSL_LINKER",
  },
  "x86_64-linux-musl": {
    "triple": "x86_64-unknown-linux-musl",
    "linker": "CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER",
  },
  "x86_64-windows-gnu": {
    "triple": "x86_64-pc-windows-gnu",
    "linker": "CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER",
  },
  "aarch64-ios-simulator": {
    "triple": "aarch64-apple-ios-sim",
    "linker": "CARGO_TARGET_AARCH64_IOS_SIM_LINKER",
  },
  "aarch64-ios-none": {
    "triple": "aarch64-apple-ios",
    "linker": "CARGO_TARGET_AARCH64_IOS_LINKER",
  },
}

class Rust {
  construct new(dir) {
    _b = dir.build
  }

  cargoExe_(b, name) { Path.join([b.toolCacheDir, ".cargo", "bin", Target.host.exeName(name)]) }

  target(bTarget) {
    var target_str = "%(bTarget)"
    if (!RustTriples.containsKey(target_str)) Fiber.abort("rust does not support %(target_str)")
    return RustTriples[target_str]["triple"]
  }

  buildExe(b, name, opts) { build_(b, name, opts, {"bin": name}) }
  buildLib(b, name, opts) { build_(b, name, opts, {}) }

  libConfig(b, name, opts) {
    var zig = b.deptool("//toolchains/zig")
    return zig.libConfig(b, name, opts)
  }

  build_(b, name, user_opts, opts) {
    var base = b.deptool("//toolchains/rust/base")
    var zig = b.deptool("//toolchains/zig")
    var opt = zig.getCCOpt(b.opt_mode)
    var platform = zig.getPlatform(b, {"sdk": true})

    var rust_home = base.build.toolCacheDir
    var rust_target = target(b.target)

    var rustup = cargoExe_(base.build, "rustup")
    var rustup_env = Process.env()
    rustup_env["HOME"] = rust_home
    b.spawn([rustup, "target", "add", rust_target], rustup_env)

    var cargo = cargoExe_(base.build, "cargo")
    if (!File.exists("Cargo.lock")) Fiber.abort("Cargo.lock missing")

    // cargo build arguments
    var artifact_name
    var args = [cargo, "build", "--target", rust_target]
    if (opts["bin"]) {
      args.addAll(["--bin", opts["bin"]])
      artifact_name = b.target.exeName(opts["bin"])
    } else {
      args.add("--lib")
      artifact_name = "lib%(name).a"
    }
    if (opt != 0) args.add("--release")

    // setup env
    var env = Process.env()
    env["RUSTUP_HOME"] = Path.join([rust_home, ".rustup"])
    env["CARGO_HOME"] = Path.join([rust_home, ".cargo"])
    env["CARGO_TARGET_DIR"] = b.toolCacheDir
    env["CC"] = "rustcc"
    env["RUSTFLAGS"] = "-C panic=abort"
    env["PATH"] = Process.pathJoin([Path.join([_b.installDir, "tools"]), env["PATH"]])
    env["HOME"] = rust_home
    env["XOS_RUST_SDK_PATH"] = platform.sysroot
    env["XOS_RUSTCC_TARGET"] = "%(b.target)"
    env["XOS_RUSTCC_OPT"] = opt
    env["XOS_RUSTCC_ZIG"] = zig.zigExe
    env["XOS_RUSTCC_CFLAGS"] = platform.ccflags.join(" ")
    // TODO: enable. zig cc seems to fail error: unable to create compilation
    // if (!user_opts["nocache"]) {
    //   var sccache = b.deptool("//toolchains/zig/sccache")
    //   env["RUSTC_WRAPPER"] = sccache.exe("sccache")
    // }
    env[RustTriples["%(b.target)"]["linker"]] = "rustcc"

    var stdio = Log.level == Log.DEBUG ? [null, 1, 2] : null
    b.spawn(args, env, stdio)

    var artifact_dir = Path.join([b.toolCacheDir, rust_target, opt == 0 ? "debug" : "release"])

    var output_path = Path.join([artifact_dir, artifact_name])

    if (b.target.os == "windows" && output_path.endsWith(".a")) {
      var new_path = Path.join([artifact_dir, "%(name).lib"])
      File.rename(output_path, new_path)
      output_path = new_path
    }

    return output_path
  }
}
