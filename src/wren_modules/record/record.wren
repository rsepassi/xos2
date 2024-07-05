import "meta" for Meta

class MutableRecord {
  static create(name, members) {
    return Record.create_(name, members, true)
  }
}

class Record {
  static create(name, members) {
    return Record.create_(name, members, false)
  }

  static create_(name, members, mutable) {
    if (name.type != String || name == "") Fiber.abort("Name must be a non-empty string.")
    if (members.isEmpty) Fiber.abort("A record must have at least one member.")
    name = name +  "_"
    var s = "class %(name) {\n"
    s = s + "  construct new_(data) { _data = data }\n"
    s = s + "  static fromMap(map) { fromMap_(%(name), map) }\n"
    s = s + "  static fromMap_(K, map) {\n"
    s = s + "    var data = List.filled(%(members.count), 0)\n"
    for (i in 0...members.count) {
      var m = members[i]
      s = s + "    data[%(i)] = map[\"%(m)\"]\n"
    }
    s = s + "    return K.new_(data)\n"
    s = s + "  }\n"
    for (i in 0...members.count) {
      var m = members[i]
      s = s + "  %(m) { _data[%(i)] }\n"
    }
    if (mutable) {
      for (i in 0...members.count) {
        var m = members[i]
        s = s + "  %(m)=(val) { _data[%(i)] = val }\n"
      }
    }
    s = s + "}\n"
    s = s + "return %(name)"
    System.print(s)
    return Meta.compile(s).call()
  }
}
