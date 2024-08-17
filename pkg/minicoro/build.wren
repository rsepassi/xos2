import "io" for File

var minicoro = Fn.new { |b, args|
  var url = "https://raw.githubusercontent.com/edubart/minicoro/ff5321d/minicoro.h"
  var hash = "c4205e8db0a95456dfde9f73f071609c6d2cad2ebfd1d74ed0a9254f121caa2f"
  File.copy(b.fetch(url, hash), "minicoro.h")

  var contents = """
#define MINICORO_IMPL
#define MCO_USE_ASM
#include "minicoro.h"
  """
  File.write("minicoro.c", contents)

  var flags = []
  if (args.count > 0) {
    var ss = args[0]["--stacksize=".count..-1]
    flags.add("-DMCO_DEFAULT_STACK_SIZE=%(ss)")
  }

  var zig = b.deptool("//toolchains/zig")
  var lib = zig.buildLib(b, "minicoro", {
    "flags": flags,
    "c_srcs": ["minicoro.c"],
    "libc": true,
  })

  b.installLib(lib)
  b.installLibConfig(zig.libConfig(b))
  b.installHeader("minicoro.h")
}
