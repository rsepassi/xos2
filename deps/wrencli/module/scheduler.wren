class Scheduler {
  static add(callable) {
    if (__scheduled == null) __scheduled = []

    __scheduled.add(Fiber.new {
      callable.call()
      runNextScheduled_()
    })
  }

  // Called by native code.
  static resume_(fiber) { fiber.transfer() }
  static resume_(fiber, arg) { fiber.transfer(arg) }
  static resumeError_(fiber, error) { fiber.transferError(error) }

  // wait for a method to finish that has a callback on the C side
  static await_(fn) {
    fn.call()
    return Scheduler.runNextScheduled_()
  }

  static runNextScheduled_() {
    if (__scheduled == null || __scheduled.isEmpty) {
      return Fiber.suspend()
    } else {
      return __scheduled.removeAt(0).transfer()
    }
  }

  foreign static captureMethods_()
}

class ExecutorPromise_ {
  construct new() {
    _done = false
    _err = null
    _val = null
  }

  done { _done }

  fail(err) {
    _err = err
    _done = true
  }

  succeed(val) {
    _val = val
    _done = true
  }

  await() {
    while (!_done) Scheduler.runNextScheduled_()
    if (_err != null) Fiber.abort(_err)
    return _val
  }
}

class Executor {
  static Promise { ExecutorPromise_ }

  static async(fn) {
    var root = Fiber.current
    var promise = Executor.Promise.new()
    Scheduler.add {
      var f = Fiber.new {
        return fn.call()
      }
      var result = f.try()
      if (f.error != null) {
        promise.fail(f.error)
      } else {
        promise.succeed(result)
      }
      root.transfer()
    }
    return promise
  }

  static await(promises) {
    if (promises is ExecutorPromise_) {
      return promises.await()
    }
    if (promises is Map) {
      var out = {}
      for (p in promises) {
        out[p.key] = Executor.await(p.value)
      }
      return out
    }
    if (promises is List) {
      var out = []
      for (p in promises) {
        out.add(Executor.await(p))
      }
      return out
    }
  }
}

Scheduler.captureMethods_()
