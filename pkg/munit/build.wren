import "io" for File, Directory
import "os" for Process, Path

var munit = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(
    "https://api.github.com/repos/nemequ/munit/tarball/fbbdf14",
    "e7aca4eba77f2e311b209a4bf56a07f4f5bdd58ce93f17a2409b2f3b46cbfad5")))


  var addl = """
#define MUNIT_ENABLE_ASSERT_ALIASES
#define TEST(name, ...) \
  static MunitResult test_ ## name ( \
      const MunitParameter params[], void* data) { \
    __VA_ARGS__ \
    return MUNIT_OK; \
  }
#define TESTMAIN(munitname, suite_tests) \
  int main(int argc, char** argv) { \
    if (argc == 2 && argv[1][0] != '-') { \
      MunitTest* test = &suite_tests[0]; \
      while (test->name != 0 && strcmp(test->name, argv[1])) ++test; \
      if (test->name == 0) munit_log(MUNIT_LOG_ERROR, "no test found"); \
      int ok = test->test(NULL, NULL) == MUNIT_OK; \
      munit_log(MUNIT_LOG_INFO, ok ? "ok" : "fail"); \
      return !ok; \
    } \
    MunitSuite test_suite = {munitname "_", suite_tests}; \
    return munit_suite_main(&test_suite, munitname, argc, argv); \
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
