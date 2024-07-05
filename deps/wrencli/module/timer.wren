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
    name = uniqueName(name)
    _children[name] = node
  }

  uniqueName(name) {
    var current = name
    var i = 0
    while (_children.containsKey(current)) {
      current = "%(name) (%(i))"
      i = i + 1
    }
    return current
  }

  childTime { _children.reduce(0) { |sum, x| sum + x.value.time } }
  selfTime { _time - childTime }

  toString(indent, name) {
    var prefix = " " * indent

    var out = "Time total= %(timeFmt_(time))ms self= %(timeFmt_(selfTime))ms children= %(timeFmt_(childTime))ms %(name)"

    var children = [""]
    for (el in _children) {
      var name = el.key
      var child = el.value.toString(indent + 4, name)
      children.add("%(prefix)%(child)")
    }
    children = children.join("\n")

    return out + children
  }

  toString {
    return toString(0, "root")
  }

  timeFmt_(t) {
    var s = "%(t)"
    var rem = " " * (6 - s.count)
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
