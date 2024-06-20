import "io" for File
foreign class Sha256 {
  construct new() {}

  foreign static hashHex(str)
  static hashFileHex(path) {
    // TODO: incremental
    return hashHex(File.read(path))
  }
}
