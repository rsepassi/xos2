#!/usr/bin/env wren

import "os" for Process
import "json" for JSON
import "timer" for Timer

var Appid = "com.xos.hello"

class Sdk {
  new(env) {
    _env = env
  }

  launchEmulator() {
  }

  run(args) {
    if (args is String) args = args.split(" ")
    Process.child(args)
      .env(_env)
      .stdin(0)
      .stdout(1)
      .stderr(2)
      .run()
  }
}

var main = Fn.new { |args|
  var emu = args.isEmpty || args[0] != "emu"

  // env is what's in env.json
}
main.call(Process.arguments)


if [ "\$launch" = "emu" ]
then
  device="-e"
  nprocesses=\$(ps ax | grep testEmulator | wc -l)
  if [ \$nprocesses -lt 2 ]
  then
    emulator -avd testEmulator -wipe-data -no-boot-anim -netdelay none -no-snapshot 2>&1 >/dev/null &
    sleep 10
  fi
else
  # this keeps the screen on, not sure how to include it
  echo 'to keep device on, run this in a separate shell'
  echo 'while true; do adb -d shell input keyevent mouse ; sleep 1 ; done'
  device="-d"
fi

adb \$device install $BUILD_OUT/apk/app-release-unsigned.apk
adb \$device shell am start -n \$appid/android.app.NativeActivity
adb \$device logcat | grep 'NativeActivity:'
