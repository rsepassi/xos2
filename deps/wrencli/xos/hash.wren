import "io" for File

foreign class Sha256 {
  construct new() {}

  static hashFileHex(path) {
    var hasher = Sha256.new()
    return HashFile_.call(path, hasher)
  }

  foreign update(str)
  foreign finalHex()
  static hashHex(str) { Sha256.new().update(str).finalHex() }
}

foreign class Blake3 {
  construct new() {}

  static hashFileHex(path) {
    var hasher = Blake3.new()
    return HashFile_.call(path, hasher)
  }

  foreign update(str)
  foreign finalHex()
  static hashHex(str) { Blake3.new().update(str).finalHex() }
}


var HashFile_ = Fn.new { |path, hasher|
  var hex
  File.open(path) { |f|
    var size = f.size
    var offset = 0
    var chunk_size = 4096
    while (offset < size) {
      var remaining = size - offset
      if (chunk_size > remaining) chunk_size = remaining
      hasher.update(f.readBytes(chunk_size, offset))
      offset = offset + chunk_size
    }
    hex = hasher.finalHex()
  }
  return hex
}
