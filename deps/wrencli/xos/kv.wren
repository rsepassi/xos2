foreign class KV {
  static open(path) {
    return new_(path)
  }

  construct new_(path) {}

  [key] {
    return get(key)
  }

  [key]=(val) {
    set(key, val)
  }

  foreign remove(key)
  foreign removePrefix(prefix)
  foreign get(key)
  foreign set(key, val)
  foreign getPrefix(prefix)
}
