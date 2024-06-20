import "scheduler" for Scheduler

class ExecutorPromise {
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
  static Promise { ExecutorPromise }

  static run(fn) {
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
    if (promises is ExecutorPromise) {
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
