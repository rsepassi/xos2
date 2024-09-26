#include "creact.h"

#include "munit.h"

#include "base/log.h"

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
  ReactiveWatchScope scope = {{increment, &count}};

  reactive_watch_scope_push(&scope);

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

  reactive_watch_scope_pop();

  Reactive_u64 b = {.value = 22};
  u64 b0 = reactive_u64_get(&b);
  reactive_u64_set(&b, 55);
  u64 b1 = reactive_u64_get(&b);

  assert_int(b0, ==, 22);
  assert_int(b1, ==, 55);
  assert_int(count, ==, 3);
});

typedef struct {
  Reactive_u64 a;
  Reactive_u64 b;
  ReactiveDerived_u64 c;
  u64 derive_count;
  u64 watch_count;
} TxState;

void txfn(void* userdata) {
  TxState* state = (TxState*)userdata;
  u64 a = reactive_u64_get(&state->a);
  u64 b = reactive_u64_get(&state->b);
  u64 c = reactive_u64_get(&state->c.reactive);
  assert_int(c, ==, a * b);

  // A set does not change the value in this tick
  reactive_u64_set(&state->a, 7);
  u64 a2 = reactive_u64_get(&state->a);
  assert_int(a2, ==, a);

  // Derived value is still the same
  u64 c2 = reactive_u64_get(&state->c.reactive);
  assert_int(c2, ==, c);

  // Same for b
  reactive_u64_set(&state->b, 11);
  u64 b2 = reactive_u64_get(&state->b);
  assert_int(b2, ==, b);

  // Derived value is still the same
  u64 c3 = reactive_u64_get(&state->c.reactive);
  assert_int(c3, ==, c);
}

u64 tx_derivation(void* userdata) {
  TxState* state = (TxState*)userdata;
  state->derive_count++;
  u64 a = reactive_u64_get(&state->a);
  u64 b = reactive_u64_get(&state->b);
  return a * b;
}

void watch_var(void* userdata, Reactive* r) {
  TxState* state = (TxState*)userdata;
  state->watch_count++;
}

TEST(tx, {
  // To test a tx, we create a derived value c that depends on a and b.
  // We update a and b in a tx, and assert that we never see the value c with
  // only a or b updated, but only with both updated.

  TxState state = {0};
  state.a.value = 3;
  state.b.value = 5;
  REACTIVE_SETNAME(&state.a.base, "a");
  REACTIVE_SETNAME(&state.b.base, "b");

  state.c.userdata = &state;
  state.c.fn = tx_derivation;
  reactive_derived_u64_init(&state.c);
  REACTIVE_SETNAME(&state.c.reactive.base, "c");
  assert_int(state.derive_count, ==, 1);

  ReactiveWatcher watcher = {watch_var, &state};
  reactive_watch(&state.c.reactive.base, &watcher);
  assert_int(state.watch_count, ==, 0);

  {
    u64 a = reactive_u64_get(&state.a);
    u64 b = reactive_u64_get(&state.b);
    u64 c = reactive_u64_get(&state.c.reactive);

    assert_int(a, ==, 3);
    assert_int(b, ==, 5);
    assert_int(c, ==, 15);
  }

  reactive_tx(&state, txfn);
  assert_int(state.derive_count, ==, 2);
  assert_int(state.watch_count, ==, 1);

  {
    u64 a = reactive_u64_get(&state.a);
    u64 b = reactive_u64_get(&state.b);
    u64 c = reactive_u64_get(&state.c.reactive);

    assert_int(a, ==, 7);
    assert_int(b, ==, 11);
    assert_int(c, ==, 77);
  }
});

// Has TxState as a prefix
typedef struct {
  Reactive_u64 a;
  Reactive_u64 b;
  ReactiveDerived_u64 c;
  u64 derive_count;
  u64 watch_count;
  ReactiveDerived_u64 d;
  u64 derive_d_count;
} Tx2State;

u64 derive_d(void* userdata) {
  Tx2State* state = (Tx2State*)userdata;
  state->derive_d_count++;
  u64 b = reactive_u64_get(&state->b);
  u64 c = reactive_u64_get(&state->c.reactive);
  return b * c;
}

void tx2fn(void* userdata) {
  TxState* state = (TxState*)userdata;

  reactive_u64_set(&state->a, 7);
  reactive_u64_set(&state->b, 11);
}

TEST(tx_complex, {
  // a  b
  // | / \
  // c -> d
  //
  // Let's say a+b are updated
  // Propagation order matters
  // Let's say d is the first watcher
  // It will read a stale value of c because c has not been updated yet
  // Then c will update
  // Then d will update again
  // From the outside, things will look consistent.
  // But internally, there was inconsistent state.
  // That's fine if everything is pure, but not if there are side effects.
  //
  // Initialization order also matters. If we flip the initialization of c and
  // d, then d will see the uninitialized value of c and no watcher will be
  // registered because init zeroes out the underlying reactive!
  //
  // So...
  // Some thoughts.
  // Embedding a functional dataflow language in an imperative stateful
  // language is always a bit weird.
  // Could have better errors (e.g. on getting an uninitialized value).
  // Could be smarter about evaluation order by paying attention to
  // dependencies. But churning through the fn pointers is simple and fast.
  //
  // Is there a better way?

  Tx2State state = {0};
  state.a.value = 3;
  state.b.value = 5;
  REACTIVE_SETNAME(&state.a.base, "a");
  REACTIVE_SETNAME(&state.b.base, "b");

  state.c.userdata = &state;
  state.c.fn = tx_derivation;
  reactive_derived_u64_init(&state.c);
  REACTIVE_SETNAME(&state.c.reactive.base, "c");
  assert_int(state.derive_count, ==, 1);

  state.d.userdata = &state;
  state.d.fn = derive_d;
  reactive_derived_u64_init(&state.d);
  REACTIVE_SETNAME(&state.d.reactive.base, "d");

  // Watch d
  ReactiveWatcher watcher = {watch_var, &state};
  reactive_watch(&state.d.reactive.base, &watcher);
  assert_int(state.watch_count, ==, 0);

  reactive_tx(&state, tx2fn);
  assert_int(state.derive_count, ==, 2);

  // Because of the intermediate update of c, the derivation function for d
  // gets called twice, and an observer on d sees both values.
  assert_int(state.derive_d_count, ==, 3);
  assert_int(state.watch_count, ==, 2);

  u64 a = reactive_u64_get(&state.a);
  u64 b = reactive_u64_get(&state.b);
  u64 c = reactive_u64_get(&state.c.reactive);
  u64 d = reactive_u64_get(&state.d.reactive);

  assert_int(a, ==, 7);
  assert_int(b, ==, 11);
  assert_int(c, ==, 77);
  assert_int(d, ==, 847);
});

static MunitTest tests[] = {
  {"basic", test_basic},
  {"scope", test_scope},
  {"derive", test_derive},
  {"tx", test_tx},
  {"tx_complex", test_tx_complex},
  0,
};

TESTMAIN("creact", tests);
