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

  ldargs {
    var args = super
    args.add(["-L%(_dir.path)/sdk/x64"])
    return args
  }
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
  } else {
    return Platform.new(b, opts)
  }
}
