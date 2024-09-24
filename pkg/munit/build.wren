import "io" for File, Directory
import "os" for Process, Path

var munit = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(
    "https://api.github.com/repos/nemequ/munit/tarball/fbbdf14",
    "e7aca4eba77f2e311b209a4bf56a07f4f5bdd58ce93f17a2409b2f3b46cbfad5")))


  var addl = """
#define TEST(name, blk) \
  static MunitResult test_ ## name ( \
      const MunitParameter params[], void* data) { \
    blk \
    return MUNIT_OK; \
  }
#define TESTMAIN(name, suite_tests) \
  int main(int argc, char** argv) { \
    MunitSuite test_suite = {name "_", suite_tests}; \
    return munit_suite_main(&test_suite, name, argc, argv); \
  }
  """

  File.write("munit.h", addl + File.read("munit.h"))

  var zig = b.deptool("//toolchains/zig")
  zig.ez.cLib(b, {
    "srcs": ["munit.c"],
    "include": ["munit.h"],
    "libc": true,
  })
}
