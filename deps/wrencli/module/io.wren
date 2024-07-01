import "scheduler" for Scheduler, Executor
import "os" for Path

class Directory {
  // TODO: Copied from File. Figure out good way to share this.
  static ensureString_(path) {
    if (!(path is String)) Fiber.abort("Path must be a string.")
  }

  static ensure(path) {
    if (Directory.exists(path)) return path
    mkdirs(path)
    return path
  }

  static create(path) {
    ensureString_(path)
    return Scheduler.await_ { create_(path, Fiber.current) }
  }

  static mkdirs(path) {
    ensureString_(path)
    return Scheduler.await_ { mkdirs_(path, Fiber.current) }
  }

  static delete(path) {
    ensureString_(path)
    return Scheduler.await_ { delete_(path, Fiber.current) }
  }

  static deleteTree(path) {
    ensureString_(path)
    return Scheduler.await_ { deleteTree_(path, Fiber.current) }
  }

  static exists(path) {
    ensureString_(path)
    var stat
    Fiber.new {
      stat = Stat.path(path)
    }.try()

    // If we can't stat it, there's nothing there.
    if (stat == null) return false
    return stat.isDirectory
  }

  static list(path) {
    ensureString_(path)
    return Scheduler.await_ { list_(path, Fiber.current) }
  }

  static copy(src_dir, dst_dir) {
    import "glob" for Glob
    if (Directory.exists(dst_dir)) {
      dst_dir = ensure(Path.join([dst_dir, Path.basename(src_dir)]))
    }
    var prefix_strip = src_dir.count + 1
    var files = Glob.globFiles("%(src_dir)/**/*")
    var copies = []
    for (src_path in files) {
      var src_rel = src_path[prefix_strip..-1]
      var dst_path = "%(dst_dir)/%(src_rel)"
      copies.add(Executor.async {
        ensure(Path.dirname(dst_path))
        File.copy(src_path, dst_path)
      })
    }

    Executor.await(copies)
  }

  foreign static create_(path, fiber)
  foreign static mkdirs_(path, fiber)
  foreign static delete_(path, fiber)
  foreign static list_(path, fiber)
  foreign static deleteTree_(path, fiber)
}

foreign class File {
  static create(path) {
    return openWithFlags(path,
        FileFlags.writeOnly |
        FileFlags.create |
        FileFlags.truncate)
  }

  static create(path, fn) {
    return openWithFlags(path,
        FileFlags.writeOnly |
        FileFlags.create |
        FileFlags.truncate, fn)
  }

  static delete(path) {
    ensureString_(path)
    Scheduler.await_ { delete_(path, Fiber.current) }
  }

  static rename(src, dst) {
    ensureString_(src)
    ensureString_(dst)
    Scheduler.await_ { rename_(src, dst, Fiber.current) }
  }

  static symlink(src, dst) {
    ensureString_(src)
    ensureString_(dst)
    Scheduler.await_ { symlink_(src, dst, Fiber.current) }
  }

  static copy(src) { copy(src, Path.basename(src)) }
  static copy(src, dst) {
    if (Path.isSymlink(src)) {
      return File.symlink(Path.readLink(src), dst)
    }

    ensureString_(src)
    ensureString_(dst)
    Scheduler.await_ { copy_(src, dst, Fiber.current) }
  }

  static exists(path) {
    ensureString_(path)
    var stat
    Fiber.new {
      stat = Stat.path(path)
    }.try()

    // If we can't stat it, there's nothing there.
    if (stat == null) return false
    return stat.isFile
  }

  static open(path) { openWithFlags(path, FileFlags.readOnly) }

  static open(path, fn) { openWithFlags(path, FileFlags.readOnly, fn) }

  // TODO: Add named parameters and then call this "open(_,flags:_)"?
  // TODO: Test.
  static openWithFlags(path, flags) {
    ensureString_(path)
    ensureInt_(flags, "Flags")
    var fd = Scheduler.await_ { open_(path, flags, Fiber.current) }
    return new_(fd)
  }

  static openWithFlags(path, flags, fn) {
    var file = openWithFlags(path, flags)
    var fiber = Fiber.new { fn.call(file) }

    // Poor man's finally. Can we make this more elegant?
    var result = fiber.try()
    file.close()

    // TODO: Want something like rethrow since now the callstack ends here. :(
    if (fiber.error != null) Fiber.abort(fiber.error)
    return result
  }

  static read(path) {
    return File.open(path) {|file| file.readBytes(file.size) }
  }

  static write(path, bytes) {
    return File.create(path) {|file| file.writeBytes(bytes) }
  }

  static size(path) {
    ensureString_(path)
    return Scheduler.await_ { sizePath_(path, Fiber.current) }
  }

  construct new_(fd) {}

  close() {
    if (isOpen == false) return
    return Scheduler.await_ { close_(Fiber.current) }
  }

  foreign descriptor

  isOpen { descriptor != -1 }

  size {
    ensureOpen_()
    return Scheduler.await_ { size_(Fiber.current) }
  }

  stat {
    ensureOpen_()
    return Scheduler.await_ { stat_(Fiber.current) }
  }

  readBytes(count) { readBytes(count, 0) }

  readBytes(count, offset) {
    ensureOpen_()
    File.ensureInt_(count, "Count")
    File.ensureInt_(offset, "Offset")

    return Scheduler.await_ { readBytes_(count, offset, Fiber.current) }
  }

  writeBytes(bytes) { writeBytes(bytes, size) }

  writeBytes(bytes, offset) {
    ensureOpen_()
    if (!(bytes is String)) Fiber.abort("Bytes must be a string.")
    File.ensureInt_(offset, "Offset")

    return Scheduler.await_ { writeBytes_(bytes, offset, Fiber.current) }
  }

  static replace(path, from, to) { replace(path, path, from, to) }
  static replace(src_path, dst_path, from, to) {
    var src = File.read(src_path)
    File.write(dst_path, src.replace(from, to))
  }

  static chmod(src, mode) {
    if (mode is String) {
      if (!(mode.count == 5 && mode[0...2] == "0o")) Fiber.abort("string mode must be an octal 0oAAA")
      var nums = mode[2..-1].map { |x| Num.fromString(x) }.toList
      mode = nums[0] * 64 + nums[1] * 8 + nums[2]
    }
    return Scheduler.await_ { chmod_(src, mode, Fiber.current) }
  }

  ensureOpen_() {
    if (!isOpen) Fiber.abort("File is not open.")
  }

  static ensureString_(path) {
    if (!(path is String)) Fiber.abort("Path must be a string.")
  }

  static ensureInt_(value, name) {
    if (!(value is Num)) Fiber.abort("%(name) must be an integer.")
    if (!value.isInteger) Fiber.abort("%(name) must be an integer.")
    if (value < 0) Fiber.abort("%(name) cannot be negative.")
  }

  foreign static delete_(path, fiber)
  foreign static open_(path, flags, fiber)
  foreign static sizePath_(path, fiber)
  foreign static rename_(src, dst, fiber)
  foreign static symlink_(src, dst, fiber)
  foreign static copy_(src, dst, fiber)
  foreign static chmod_(path, mode, fiber)

  foreign fd
  foreign close_(fiber)
  foreign readBytes_(count, offset, fiber)
  foreign size_(fiber)
  foreign stat_(fiber)
  foreign writeBytes_(bytes, offset, fiber)
}

class FileFlags {
  // Note: These must be kept in sync with mapFileFlags() in io.c.

  static readOnly  { 0x01 }
  static writeOnly { 0x02 }
  static readWrite { 0x04 }
  static sync      { 0x08 }
  static create    { 0x10 }
  static truncate  { 0x20 }
  static exclusive { 0x40 }
}

foreign class Stat {
  static path(path) {
    if (!(path is String)) Fiber.abort("Path must be a string.")

    return Scheduler.await_ { path_(path, Fiber.current) }
  }

  foreign static path_(path, fiber)

  foreign blockCount
  foreign blockSize
  foreign device
  foreign group
  foreign inode
  foreign linkCount
  foreign mode
  foreign size
  foreign specialDevice
  foreign user

  foreign isFile
  foreign isDirectory
  // TODO: Other mode checks.
}

class Stdin {
  foreign static isRaw
  foreign static isRaw=(value)
  foreign static isTerminal

  static readByte() {
    return read_ {
      // Peel off the first byte.
      var byte = __buffered.bytes[0]
      __buffered = __buffered[1..-1]
      return byte
    }
  }

  static readLine() {
    return read_ {
      // TODO: Handle Windows line separators.
      var lineSeparator = __buffered.indexOf("\n")
      if (lineSeparator == -1) return null

      // Split the line at the separator.
      var line = __buffered[0...lineSeparator]
      __buffered = __buffered[lineSeparator + 1..-1]
      return line
    }
  }

  static read_(handleData) {
    // See if we're already buffered enough to immediately produce a result.
    if (__buffered != null && !__buffered.isEmpty) {
      var result = handleData.call()
      if (result != null) return result
    }

    if (__isClosed == true) Fiber.abort("Stdin was closed.")

    // Otherwise, we need to wait for input to come in.
    __handleData = handleData

    // TODO: Error if other fiber is already waiting.
    readStart_()

    __waitingFiber = Fiber.current
    var result = Scheduler.runNextScheduled_()

    readStop_()
    return result
  }

  static onData_(data) {
    // If data is null, it means stdin just closed.
    if (data == null) {
      __isClosed = true
      readStop_()

      if (__buffered != null) {
        // TODO: Is this correct for readByte()?
        // Emit the last remaining bytes.
        var result = __buffered
        __buffered = null
        __waitingFiber.transfer(result)
      } else {
        __waitingFiber.transferError("Stdin was closed.")
      }
    }

    // Append to the buffer.
    if (__buffered == null) {
      __buffered = data
    } else {
      // TODO: Instead of concatenating strings each time, it's probably faster
      // to keep a list of buffers and flatten lazily.
      __buffered = __buffered + data
    }

    // Ask the data handler if we have a complete result now.
    var result = __handleData.call()
    if (result != null) __waitingFiber.transfer(result)
  }

  foreign static readStart_()
  foreign static readStop_()
}

class Stdout {
  foreign static flush()
  foreign static write(s)
}
