import "io" for File, Directory
import "os" for Path, Process

class Pkg {
  construct new(dir) {
    _dir = dir
  }

  pkg(b, opts) {
    // opts:
    //   exe
    //   name
    //   resources
    var tmpdir = Directory.create(opts["name"])
    var resources = Directory.create("%(opts["name"])/resources")

    File.copy(opts["exe"], "%(tmpdir)/%(opts["name"])")
    for (r in opts["resources"] || []) {
      File.copy(r, resources)
    }
    var tar = b.deptool("//deps/libarchive:bsdtar").exe("bsdtar")
    var zipname = "%(opts["name"]).zip"
    var args = [tar, "-a", "--numeric-owner", "-cf", zipname, tmpdir]
    b.spawn(args)

    return zipname
  }
}

class pkg {
  static call(b, args) {
  }

  static wrap(dir) { Pkg.new(dir) }
}
