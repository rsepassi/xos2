#include "base/list.h"
#include "base/stdtypes.h"

#include "munit.h"

TEST(list_null_allocator, {
  u8* s = "hello world!";
  list_t mylist = {0};
  mylist.base = s;
  mylist.elsz = 1;

  assert_char(*list_get(u8, &mylist, 1), ==, 'e');
});

static MunitTest tests[] = {
  {"list_null_allocator", test_list_null_allocator},
  0,
};

TESTMAIN("cbase", tests);
