// FlagParser parses argument lists searching for --flags specified in its
// configuration.

class FlagParserFlag {
  static opt(name) { optional(name) }
  static opt(name, config) { optional(name, config) }
  static optional(name) { optional(name, {}) }
  static optional(name, config) { FlagParserFlag.new_(name, config) }

  static required(name) { required(name, {}) }
  static required(name, config) {
    config["required"] = true
    return FlagParserFlag.new_(name, config)
  }

  default { _config.containsKey("default") ? _config["default"] : null }
  required { _config["required"] || false }
  name { _name }
  help { "%(name): %(_config)" }

  parse(arg) {
    if (!arg.startsWith(_prefix)) return null

    var val = arg[_prefix.count..-1]
    var parser = _config["parser"]
    if (parser == null) return val
    return parser.parse(val)
  }

  construct new_(name, config) {
    _name = name
    _config = config
    _prefix = "--%(_name)="
  }
}

class FlagParser {
  static Flag { FlagParserFlag }

  construct new(name, configs) {
    _name = name
    _configs = configs
  }

  help() {
    System.print("%(_name) flags:")
    for (config in _configs) {
      System.print("  %(config.help)")
    }
  }

  parse(args) {
    var out = {}
    for (arg in args) {
      var matched = false
      for (config in _configs) {
        var match = config.parse(arg)
        if (match == null) continue
        out[config.name] = match
        matched = true
        break
      }
      if (!matched) {
        help()
        Fiber.abort("error: unrecognzed argument %(arg), see usage above")
      }
    }

    for (config in _configs) {
      if (out.containsKey(config.name)) continue
      var default = config.default
      if (default != null) out[config.name] = default
      if (config.required) {
        help()
        Fiber.abort("error: flag %(config.name) is required, but was not provided, see usage above")
      }
    }

    return out
  }
}
