import "io" for File, Directory
import "os" for Path, Process

class Pkg {
  construct new(dir) {
    _dir = dir
  }

  rcicon(b, png) {
    var base = Path.basename(png).split(".")[0...-1].join(".")
    var outname = base + ".ico"
    var convert = ["magick", "-background", "transparent", png, "-define", "icon:auto-resize=256,128,64,48,32,16", outname]
    b.system(convert)

    var path = Path.join([Process.cwd, outname])
    File.write("%(base).rc", "IDI_ICON1 ICON \"%(outname)\"\n")
    return Path.join([Process.cwd, "%(base).rc"])
  }

  pkg(b, opts) {
    // opts:
    //   exe
    //   name
    //   publisher
    //   resources
    
    var appdir = Directory.create("windows-app")
    var exename = Path.basename(opts["exe"])
    File.copy(opts["exe"], appdir)

    var resources_install = []
    var resources_delete = []
    for (r in opts["resources"] || []) {
      File.copy(r, appdir)
      var name = Path.basename(r)
      resources_install.add(" File \"%(name)\"")
      resources_delete.add(" Delete \"$INSTDIR\\%(name)\"")
    }
    resources_install = resources_install.join("\n")
    resources_delete = resources_delete.join("\n")

    var installer_nsi = File.read(_dir.artifact("installer.nsi"))
    installer_nsi = installer_nsi.replace("XOS_APP_NAME", opts["name"])
    installer_nsi = installer_nsi.replace("XOS_EXE_NAME", exename)
    installer_nsi = installer_nsi.replace("XOS_INSTALL_RESOURCES", resources_install)
    installer_nsi = installer_nsi.replace("XOS_DELETE_RESOURCES", resources_delete)
    installer_nsi = installer_nsi.replace("XOS_PUBLISHER", opts["publisher"])
    File.write("%(appdir)/installer.nsi", installer_nsi)

    File.copy(_dir.artifact("install.ico"), appdir)

    var oldcwd = Process.cwd
    Process.chdir(appdir)
    var env = Process.env()
    env["LANG"] = "en_US.UTF-8"
    b.systemExport(["makensis", "installer.nsi"], env)
    Process.chdir(oldcwd)

    return "%(appdir)/Install %(opts["name"]).exe"
  }
}

class pkg {
  static call(b, args) {
    b.installArtifact([
      b.src("install.ico"),
      b.src("installer.nsi"),
    ])
  }

  static wrap(dir) { Pkg.new(dir) }
}
