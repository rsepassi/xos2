import "io" for File, Directory
import "os" for Path, Process

class Pkg {
  construct new(dir) {
    _dir = dir
  }

  pkg(b, opts) {
    // opts:
    //   name
    //   exe
    //   resources
    //   icon_png
    //   bundle_id
    //   info_plist_extras
    var appdir = "%(opts["name"]).app"
    var resource_dir = "%(appdir)/Contents/Resources"
    Directory.create(appdir)
    Directory.create("%(appdir)/Contents")
    Directory.create("%(appdir)/Contents/MacOS")
    Directory.create(resource_dir)

    var exename = Path.basename(opts["exe"])
    File.copy(opts["exe"], "%(appdir)/Contents/MacOS/%(exename)")

    if (opts["icon_png"]) {
      b.systemExport([_dir.artifact("iconify.sh"), opts["icon_png"]])
      File.rename("icon.icns", "%(resource_dir)/icon.icns")
    }

    var info_plist = File.read(_dir.artifact("Info.plist"))
    info_plist = info_plist.replace("XOS_EXE_NAME", exename)
    info_plist = info_plist.replace("XOS_BUNDLE_ID", opts["bundle_id"])
    info_plist = info_plist.replace("XOS_APP_NAME", opts["name"])
    info_plist = info_plist.replace("XOS_PLIST_EXTRAS", opts["info_plist_extras"] || "")
    File.write("%(appdir)/Contents/Info.plist", info_plist)

    for (r in opts["resources"] || []) {
      File.copy(r, resource_dir)
    }

    return appdir
  }

  dist(b, opts) {
    // opts:
    //   app
    //   signid
    //   name
    //   entitlements_plist_extras

    // Setup tmpdir
    var tmpdir = Directory.create("dmgbuild")
    var bundle_name = Path.basename(opts["app"])
    var bundle_path = "%(tmpdir)/%(bundle_name)"
    Directory.copy(opts["app"], bundle_path)

    // Setup entitlements
    var entitlements = File.read(_dir.artifact("entitlements.plist"))
    entitlements = entitlements.replace("XOS_PLIST_EXTRAS", opts["entitlements_plist_extras"] || "")
    File.write("entitlements.plist", entitlements)

    // Sign the .app bundle
    var appsign = [ "codesign",
      "--entitlements", "entitlements.plist",
      "--force", "--deep", "--timestamp",
      "--sign", opts["signid"],
      "-o", "runtime",
      bundle_path
    ]
    b.system(appsign)

    // Make a .dmg
    File.copy(_dir.artifact("template.applescript"))
    var dmg_name = "%(opts["name"]).dmg"
    var mkdmg = [_dir.artifact("create-dmg.sh"),
      "--volname", "%(opts["name"]) Installer",
      "--window-pos", "200", "120",
      "--window-size", "800", "400",
      "--icon-size", "100",
      "--icon", bundle_name, "200", "200",
      "--hide-extension", bundle_name,
      "--app-drop-link", "600", "185",
      dmg_name, tmpdir,
    ]
    b.systemExport(mkdmg)

    // Sign the .dmg
    var dmgsign = [ "codesign",
      "--force", "--deep", "--timestamp",
      "--sign", opts["signid"],
      bundle_path
    ]
    b.system(dmgsign)

    // Notarize the .dmg
    var notarize = [
      "xcrun", "notarytool", "submit", dmg_name, "--wait", "--keychain-profile", opts["signid"],
    ]
    b.system(notarize)

    var staple = [
      "xcrun", "stapler", "staple", dmg_name,
    ]
    b.system(staple)

    return dmg_name
  }
}

class pkg {
  static call(b, args) {
    b.installArtifact([
      b.src("entitlements.plist"),
      b.src("Info.plist"),
      b.src("iconify.sh"),
      b.src("template.applescript"),
      b.src("create-dmg.sh"),
    ])
  }
  static wrap(dir) {
    return Pkg.new(dir)
  }
}
