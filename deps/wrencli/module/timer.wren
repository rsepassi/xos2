import "scheduler" for Scheduler

class Timer {
  static sleep(milliseconds) {
    if (!(milliseconds is Num)) Fiber.abort("Milliseconds must be a number.")
    if (milliseconds < 0) Fiber.abort("Milliseconds cannot be negative.")

    return Scheduler.await_ { startTimer_(milliseconds, Fiber.current) }
  }

  foreign static startTimer_(milliseconds, fiber)
}


foreign class Stopwatch {
  construct new() {}
  foreign lap()
  foreign read()
}

class StopwatchTreeNode {
  construct new(start) {
    _time = start
    _children = {}
  }

  time { _time }
  time=(t) { _time = t }

  addChild(name, node) {
    if (_children.containsKey(name)) Fiber.abort("StopwatchTree children already contains name %(name)")
    _children[name] = node
  }

  childTime { _children.reduce(0) { |sum, x| sum + x.value.time } }
  selfTime { _time - childTime }

  toString(indent) {
    var prefix = " " * indent
    var children = [""]
    for (el in _children) {
      var name = el.key
      var child = el.value.toString(indent + 4)
      children.add("%(prefix)%(child) %(name)")
    }
    children = children.join("\n")

    return "Time total=%(timeFmt_(time))ms self=%(timeFmt_(selfTime))ms children=%(timeFmt_(childTime))ms%(children)"
  }

  toString {
    return toString(0)
  }

  timeFmt_(t) {
    var s = "%(t)"
    var rem = " " * (5 - s.count)
    return s + rem
  }
}

class StopwatchTree {
  static time(name, fn) {
    if (__timer_stack == null || __timer_stack.isEmpty) {
      __timer_stack = [StopwatchTreeNode.new(Stopwatch.new())]
    } else {
      var start = __timer_stack[0].time.read()
      var last = __timer_stack[-1]
      var node = StopwatchTreeNode.new(start)
      last.addChild(name, node)
      __timer_stack.add(node)
    }

    var out = fn.call()

    var t = __timer_stack[0].time.read()

    if (__timer_stack.count == 1) {
      __timer_stack[-1].time = t
    } else {
      var start = __timer_stack[-1].time
      var duration = t - start
      __timer_stack[-1].time = duration
      __timer_stack.removeAt(-1)
    }

    return out
  }

  static timerTree {
    if (__timer_stack == null) Fiber.abort("no timer tree was ever instantiated")
    return __timer_stack[-1]
  }

  construct new_() {}
}
