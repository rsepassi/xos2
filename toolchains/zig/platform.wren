import "io" for File
import "json" for JSON

class PlatformOpts {
  construct new() {
    _opts = {
      "sdk": false,
      "libc": false,
      "libc++": false,
    }
  }
  construct new(opts) { _opts = opts }
  sdk { _opts["sdk"] }
  libc { _opts["libc"] }
  libcpp { _opts["libcpp"] }
  union(other) {
    other = other is PlatformOpts ? other : PlatformOpts.new(other)
    var opts = {}
    opts["sdk"] = sdk || other.sdk
    opts["libc"] = libc || other.libc
    opts["libc++"] = libcpp || other.libcpp
    return PlatformOpts.new(opts)
  }
}

class Platform {
  static Opts { PlatformOpts }
  static get(b, opts) { GetPlatform_.call(b, opts) }

  construct new(b, opts) {
    _b = b
    _opts = opts
  }
  flags { [] }
  ccflags { [] }
  sysroot { "" }
  ldargs {
    var args = []
    if (_opts.libcpp) args.add("-lc++")
    if (_opts.libc) args.add("-lc")
    return args
  }
}

class FreeBSD is Platform {
  construct new(b, opts) {
    _dir = b.dep("//sdk/freebsd")
    _opts = opts
    super(b, opts)
  }

  sysroot { "%(_dir.path)/sdk" }

  flags {
    return [
      "--libc", "%(sysroot)/libc.txt",
      "--sysroot", sysroot,
    ]
  }
}

class MacOS is Platform {
  construct new(b, opts) {
    _dir = b.dep("//sdk/macos")
    _opts = opts
    super(b, opts)
  }

  sysroot { "%(_dir.path)/sdk" }

  flags {
    return [
      "--libc", "%(sysroot)/libc.txt",
      "-F%(sysroot)/System/Library/Frameworks",
    ]
  }

  ccflags {
    return [
      "-I%(sysroot)/usr/include",
      "-L%(sysroot)/usr/lib",
      "-F%(sysroot)/System/Library/Frameworks",
      "-includeTargetConditionals.h",
    ]
  }
}

class Windows is Platform {
  construct new(b, opts) {
    _dir = b.dep("//sdk/windows")
    _opts = opts
    super(b, opts)
  }

  ldargs { ["-L%(_dir.path)/sdk/x64"] + super }
}

class IOS is Platform {
  construct new(b, opts) {
    _dir = b.dep("//sdk/ios")
    _opts = opts
    super(b, opts)
  }

  sysroot { "%(_dir.path)/sdk" }

  flags {
    return [
      "--libc", "%(sysroot)/libc.txt",
      "-F%(sysroot)/System/Library/Frameworks",
    ]
  }

  ccflags {
    return [
      "-I%(sysroot)/usr/include",
      "-L%(sysroot)/usr/lib",
      "-F%(sysroot)/System/Library/Frameworks",
      "-includeTargetConditionals.h",
    ]
  }
}

class Android is Platform {
  construct new(b, opts) {
    _droid = b.dep("//sdk/android")
    _opts = opts
    _pc = JSON.parse(File.read("%(_droid.installDir.path)/sdk.pc.json"))
    super(b, opts)
  }

  flags {
    return [
      "--libc", "%(_droid.installDir.path)/libc.txt",
    ] + _pc["Cflags"]
  }

  ldargs {
    var args = []
    args.addAll(_pc["Libs"])
    args.addAll(super)
    return args
  }
}

var GetPlatform_ = Fn.new { |b, opts|
  opts = opts is PlatformOpts ? opts : PlatformOpts.new(opts)
  var os = b.target.os
  if (os == "freebsd") {
    return FreeBSD.new(b, opts)
  } else if (os == "macos" && opts.sdk) {
    return MacOS.new(b, opts)
  } else if (os == "windows" && opts.sdk) {
    return Windows.new(b, opts)
  } else if (os == "ios") {
    return IOS.new(b, opts)
  } else if (os == "linux" && b.target.abi == "android") {
    return Android.new(b, opts)
  } else {
    return Platform.new(b, opts)
  }
}
