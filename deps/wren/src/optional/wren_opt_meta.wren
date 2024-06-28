class Meta {
  static getModuleVariables(module) {
    if (!(module is String)) Fiber.abort("Module name must be a string.")
    var result = getModuleVariables_(module)
    if (result != null) return result

    Fiber.abort("Could not find a module named '%(module)'.")
  }

  static getModuleVariable(module, name) {
    if (!(module is String)) Fiber.abort("Module name must be a string.")
    if (!(name is String)) Fiber.abort("Variable name must be a string.")
    var result = getModuleVariable_(module, name)
    if (result != null) return result

    Fiber.abort("Could not find a module named '%(module)'.")
  }

  static eval(source) {
    if (!(source is String)) Fiber.abort("Source code must be a string.")

    var closure = compile_(source, false, false)
    // TODO: Include compile errors.
    if (closure == null) Fiber.abort("Could not compile source code.")

    closure.call()
  }

  static compileExpression(source) {
    if (!(source is String)) Fiber.abort("Source code must be a string.")
    return compile_(source, true, true)
  }

  static compile(source) {
    if (!(source is String)) Fiber.abort("Source code must be a string.")
    return compile_(source, false, true)
  }

  static captureImports(fn) { ImportCapture_.new(fn) }

  foreign static compile_(source, isExpression, printErrors)
  foreign static getModuleVariables_(module)
  foreign static getModuleVariable_(module, name)
  foreign static captureImportsBegin_()
  foreign static captureImportsEnd_()
}

class ImportCapture_ {
  construct new(fn) {
    _fn = fn
    _imports = null
  }

  imports { _imports }

  call() {
    Meta.captureImportsBegin_()
    var out = _fn.call()
    _imports = Meta.captureImportsEnd_()
    return out
  }
}
