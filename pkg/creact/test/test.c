#include "creact.h"

#include "munit.h"

void increment(void* userdata, Reactive* r) {
  (*(u64*)userdata)++;
}

TEST(basic, {
  u64 count = 0;

  Reactive_u64 a = {.value = 22};
  ReactiveWatcher watcher = {increment, &count};
  reactive_watch(&a.base, &watcher);

  reactive_u64_set(&a, 16);
  assert_int(count, ==, 1);

  u64 v0 = reactive_u64_get(&a);
  reactive_u64_set(&a, 42);
  assert_int(count, ==, 2);

  reactive_leave(&a.base, &watcher);
  reactive_u64_set(&a, 43);
  assert_int(count, ==, 2);
});

typedef struct {
  Reactive_u64 a;
} State;

u64 derivation(void* userdata) {
  return reactive_u64_get(&((State*)userdata)->a) + 6;
}

TEST(derive, {
  State state = {0};
  state.a.value = 22;

  ReactiveDerived_u64 derived = {0};
  derived.fn = derivation;
  derived.userdata = &state;
  reactive_derived_u64_init(&derived);
  assert_int(state.a.value, ==, 22);
  assert_int(derived.reactive.value, ==, 28);

  u64 count = 0;
  ReactiveWatcher watcher = {increment, &count};
  reactive_watch(&derived.reactive.base, &watcher);

  reactive_u64_set(&state.a, 30);
  assert_int(state.a.value, ==, 30);
  assert_int(derived.reactive.value, ==, 36);
  assert_int(count, ==, 1);
});

TEST(scope, {
  u64 count = 0;
  ReactiveScope scope = {{increment, &count}};

  reactive_scope_push(&scope);

  Reactive_u64 a = {.value = 22};
  reactive_u64_set(&a, 16);  // no inc, because no read yet

  u64 v0 = reactive_u64_get(&a);  // read, now watching
  reactive_u64_set(&a, 42);  // inc

  u64 v1 = reactive_u64_get(&a);  // another read, shouldn't duplicate
  reactive_u64_set(&a, 42);  // same value, no inc
  reactive_u64_set(&a, 52);  // inc
  reactive_u64_set(&a, 53);  // inc again
  u64 v2 = reactive_u64_get(&a);

  assert_int(v0, ==, 16);
  assert_int(v1, ==, 42);
  assert_int(v2, ==, 53);

  assert_int(count, ==, 3);
  reactive_leave(&a.base, &scope.watcher);
  reactive_u64_set(&a, 55);
  assert_int(count, ==, 3);

  reactive_scope_pop();

  Reactive_u64 b = {.value = 22};
  u64 b0 = reactive_u64_get(&b);
  reactive_u64_set(&b, 55);
  u64 b1 = reactive_u64_get(&b);

  assert_int(b0, ==, 22);
  assert_int(b1, ==, 55);
  assert_int(count, ==, 3);
});

static MunitTest tests[] = {
  {"basic", test_basic},
  {"scope", test_scope},
  {"derive", test_derive},
  0,
};

TESTMAIN("creact", tests);
