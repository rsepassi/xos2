// Global configuration

class Config {
  static init(map) {
    if (__config != null) Fiber.abort("Config has already been initialized")
    __config = map
  }

  static get(key) {
    if (!__config.containsKey(key)) Fiber.abort("Config does not define %(key)")
    return __config[key]
  }
}
