// Global configuration

class Config {
  static init(map) {
    if (__config != null) Fiber.abort("Config has already been initialized")
    __config = map
  }

  static get(key) {
    return __config[key]
  }
}
