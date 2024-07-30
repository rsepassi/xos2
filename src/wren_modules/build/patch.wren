import "io" for File

class Patch {
  static read(src) {
    var lines = Iter_.new(File.read(src).split("\n"))
    var parser = PatchParser_.new(lines)
    return parser.parse()
  }

  apply() {
    for (diff in _diffs) applyDiff_(diff)
  }

  applyDiff_(diff) {
    var src_lines = File.read(diff["src"]).split("\n")
    var dst_lines = []

    var i = 0
    for (hunk in diff["hunks"]) {
      var header = hunk["header"]

      var src_start = header["from"]["line"] - 1
      var src_end = src_start + header["from"]["count"]

      dst_lines.addAll(src_lines[i...src_start])
      i = src_end

      for (line in hunk["lines"]) {
        if (line.startsWith(" ")) {
          dst_lines.add(line[1..-1])
        } else if (line.startsWith("+")) {
          dst_lines.add(line[1..-1])
        } else if (line.startsWith("-")) {
        }
      }
    }

    dst_lines.addAll(src_lines[i..-1])

    File.create(diff["dst"]) { |f|
      for (line in dst_lines) {
        f.writeBytes(line)
        f.writeBytes("\n")
      }
    }
  }

  construct new_(diffs) { _diffs = diffs }
}

class PatchParser_ {
  construct new(lines) {
    _lines = lines
  }

  parse() {
    var diffs = []
    while (!_lines.isEmpty) {
      var line = _lines.peek()
      if (line.startsWith("---")) diffs.add(parseDiff())
      _lines.advance()
    }
    return Patch.new_(diffs)
  }

  parseDiff() {
    var src = _lines.next().split(" ")[1][2..-1]
    var dst = _lines.next().split(" ")[1][2..-1]

    var hunks = []
    while (!_lines.isEmpty) {
      if (_lines.peek().startsWith("@@")) {
        hunks.add(parseHunk())
      } else {
        break
      }
    }

    return {
      "src": src,
      "dst": dst,
      "hunks": hunks,
    }
  }

  parseHunk() {
    var header = parseHunkHeader()

    var adds = []
    var dels = []
    var lines = []
    var i = 0

    while (!_lines.isEmpty) {
      var line = _lines.peek()
      if (line.startsWith(" ")) {
        lines.add(line)
      } else if (line.startsWith("+")) {
        adds.add([i, line[1..-1]])
        lines.add(line)
      } else if (line.startsWith("-")) {
        dels.add([i, line[1..-1]])
        lines.add(line)
      } else {
        break
      }

      i = i + 1
      _lines.advance()
    }

    return {
      "header": header,
      "lines": lines,
      "adds": adds,
      "dels": dels,
    }
  }

  parseHunkHeader() {
    var parts = _lines.next().split(" ")
    var from = parseHunkHeaderLines(parts[1])
    var to = parseHunkHeaderLines(parts[2])
    return {
      "from": from,
      "to": to,
    }
  }

  parseHunkHeaderLines(s) {
    var parts = s.split(",")
    if (parts.count == 1) parts.add("1")
    parts[0] = Num.fromString(parts[0][1..-1])
    parts[1] = Num.fromString(parts[1])
    return {
      "line": parts[0],
      "count": parts[1],
    }
  }
}

class Iter_ {
  construct new(seq) {
    _seq = seq
    _it = seq.iterate(null)
  }

  isEmpty { !_it }
  peek() { _seq.iteratorValue(_it) }
  advance() { _it = _seq.iterate(_it) }
  next() {
    var out = peek()
    advance()
    return out
  }
}
