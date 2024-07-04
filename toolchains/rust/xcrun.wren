import "io" for Stdout
import "os" for Process
Stdout.write("%(Process.env("XOS_RUST_SDK_PATH"))\n")
