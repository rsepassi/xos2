import "meta" for Meta

class Enum {
  // Creates a class for the Enum (with an underscore after the name to avoid duplicate definition)
  // and returns a reference to it.
  static create(name, members, startsFrom) {
    if (name.type != String || name == "") Fiber.abort("Name must be a non-empty string.")
    if (members.isEmpty) Fiber.abort("An enum must have at least one member.")
    if (startsFrom.type != Num || !startsFrom.isInteger) {
      Fiber.abort("Must start from an integer.")
    }
    name = name +  "_"
    var s = "class %(name) {\n"
    for (i in 0...members.count) {
      var m = members[i]
      s = s + "  static %(m) { %(i + startsFrom) }\n"
    }
    var mems = members.map { |m| "\"%(m)\"" }.join(", ")
    s = s + "  static startsFrom { %(startsFrom) }\n"
    s = s + "  static members { [%(mems)] }\n}\n"
    s = s + "return %(name)"
    return Meta.compile(s).call()
  }
}
