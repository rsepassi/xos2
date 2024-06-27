class JSON {
  static stringify(x) {
    if (x is List || x is Map) {
      return JSONObj_.build(x).stringify()
    } else {
      Fiber.abort("top-level JSON object must be a Map or a List")
    }
  }
  foreign static parse(x)
}

foreign class JSONObj_ {
  static build(x) {
    if (x is Map) {
      var els = List.filled(x.count * 2, 0)
      var i = 0
      for (el in x) {
        if (!(el.key is String)) Fiber.abort("Map keys must be Strings, got %(el.key)")
        els[i] = el.key
        els[i + 1] = JSONObj_.build(el.value)
        i = i + 2
      }
      return JSONObj_.fromMap(els)
    } else if (x is List) {
      var els = List.filled(x.count, 0)
      var i = 0
      for (el in x) {
        els[i] = JSONObj_.build(el)
        i = i + 1
      }
      return JSONObj_.fromList(els)
    } else if (x is Bool || x is Num || x == null || x is String) {
      return JSONObj_.fromVal(x)
    } else {
      var f = Fiber.new {
        return x.toJSON
      }
      var j = f.try()
      if (f.error != null) {
        if (f.error.endsWith("does not implement 'toJSON'.")) {
          Fiber.abort("%(x) is not encodable as JSON")
        } else {
          Fiber.abort("toJSON for %(x) failed: %(f.error)")
        }
      }
      return JSONObj_.fromVal(j)
    }
  }

  construct new_(val, type) {}

  static fromVal(x) {
    return JSONObj_.new_(x, 0)
  }
  static fromList(x) {
    return JSONObj_.new_(x, 1)
  }
  static fromMap(x) {
    return JSONObj_.new_(x, 2)
  }

  foreign stringify()
}
