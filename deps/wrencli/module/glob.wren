import "io" for Directory, File

var globchars_ = "$[?]*{}"

var subDirs_
subDirs_ = Fn.new { |dir|
  var dirs = []
  for (d in Directory.list(dir)) {
    var subdir = "%(dir)/%(d)"
    if (Directory.exists(subdir)) {
      dirs.add(subdir)
      dirs.addAll(subDirs_.call(subdir))
    }
  }
  return dirs
}

var ExpandDirs_
ExpandDirs_ = Fn.new { |prefix, subdir_globs|
  if (subdir_globs.count == 0) {
    if (Directory.exists(prefix)) {
      return [prefix]
    } else {
      return []
    }
  }

  var dir_matches = []
  var this_glob = subdir_globs[0]
  var rest = subdir_globs[1..-1]

  if (this_glob == "**") {
    if (Directory.exists(prefix)) dir_matches.add(prefix)
    for (match in subDirs_.call(prefix)) {
      dir_matches.addAll(ExpandDirs_.call(match, rest))
    }
  } else {
    for (match in Glob.glob_("%(prefix)/%(this_glob)")) {
      if (!Directory.exists(match)) continue
      dir_matches.addAll(ExpandDirs_.call(match, rest))
    }
  }
  return dir_matches
}

class GlobType {
  static All { 0 }
  static File { 1 }
  static Directory { 2 }
}

var IsPlain_ = Fn.new { |part| !globchars_.any { |char| part.contains(char) } }

var GlobFilter_ = Fn.new { |matches, config|
  var t = config["type"]
  if (t == GlobType.All) return matches
  return matches.where { |m|
    if (t == GlobType.File) return File.exists(m)
    if (t == GlobType.Directory) return Directory.exists(m)
    Fiber.abort("unreachable")
  }.toList
}

class Glob {
  static Type { GlobType }

  static glob(pattern) {
    return glob(pattern, {"type": GlobType.All})
  }

  static glob(pattern, config) {
    var out = globExUnsorted(pattern, config)
    if (config["sort"]) out.sort() { |a, b| a.bytes < b.bytes }
    return out
  }

  static globFiles(pattern) { globFiles(pattern, {}) }
  static globFiles(pattern, config) {
    config["type"] = GlobType.File
    return glob(pattern, config)
  }

  static globDirs(pattern) { globDirs(pattern, {}) }
  static globDirs(pattern, config) {
    config["type"] = GlobType.Directory
    glob(pattern, config)
  }

  static globExUnsorted(pattern, config) {
    // Easy case: nothing to glob
    if (pattern.isEmpty) return []

    // If there are no directory parts, just glob directly
    var dirparts = pattern.split("/")  
    if (dirparts.count == 1) return GlobFilter_.call(glob_(pattern), config)

    // Handle absolute paths so we can always add a / below
    if (pattern[0] == "/") {
      dirparts[1] = "/%(dirparts[1])"
      dirparts.removeAt(0)
    }

    // We start by finding a plain prefix (i.e. parts with no glob characters)
    var plain_parts = (Fn.new {
      var prefix = []
      for (part in dirparts) {
        var plain = IsPlain_.call(part)
        if (plain) {
          prefix.add(part)
        } else {
          break
        }
      }
      return prefix
    }).call()

    // If it's all plain, just check if a file or directory exists at that path
    if (plain_parts.count == dirparts.count) {
      if (File.exists(pattern) || Directory.exists(pattern)) {
        return GlobFilter_.call([pattern], config)
      } else {
        return []
      }
    }


    // Now we know the dynamic directory globs and the final dynamic glob
    var plain_prefix = plain_parts.join("/")
    var dirglobs = dirparts[plain_parts.count...-1]
    var tailglob = dirparts[-1]
    if (tailglob == "**") Fiber.abort("final part of a glob cannot be **")

    // We find all matching directories first

    var dirmatches = ExpandDirs_.call(plain_prefix, dirglobs)

    // For each matching directory, we glob for the last part
    var matches = []
    var is_last_plain = IsPlain_.call(tailglob)
    for (dirmatch in dirmatches) {
      var pattern = "%(dirmatch)/%(tailglob)"
      if (is_last_plain && (File.exists(pattern) || Directory.exists(pattern))) {
        matches.add(pattern)
      } else {
        matches.addAll(glob_(pattern))
      }
    }

    return GlobFilter_.call(matches, config)
  }

  foreign static glob_(pattern)
}
