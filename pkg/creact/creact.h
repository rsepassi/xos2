#pragma once

#include "base/stdtypes.h"

typedef struct Reactive_s Reactive;
typedef struct ReactiveWatcher_s ReactiveWatcher;
typedef struct Reactive__advance_s Reactive__advance;

// Internal helpers.
struct Reactive__advance_s {
  Reactive* r;
  void (*tick)(Reactive* r);
  Reactive__advance* next;
};
void reactive__mark_get(Reactive* r);
void reactive__mark_set(Reactive* r);

// Debug logging helpers
#ifdef DEBUG
#include "base/log.h"
#define REACTIVE_DEBUG_DATA \
  char* name;
#define REACTIVE_SETNAME(r, rname) do { (r)->name = rname; } while(0)
#define REACTIVE_LOGF(tag, r, fmt, ...) do { \
    if (r->name) { \
      LOG("%s: %s" fmt, tag, r->name, ##__VA_ARGS__); \
    } else { \
      LOG("%s: %p" fmt, tag, r, ##__VA_ARGS__); \
    } \
  } while (0)
#define REACTIVE_LOG(tag, r) REACTIVE_LOGF(tag, r, "")
#else
#define REACTIVE_DEBUG_DATA
#define REACTIVE_SETNAME(r, name)
#define REACTIVE_LOG(tag, r)
#define REACTIVE_LOGF(tag, r, fmt, ...)
#endif

// A reactive object has as its base a linked list of active _watchers.
struct Reactive_s {
  ReactiveWatcher* _watchers;
  Reactive__advance _advance;
  REACTIVE_DEBUG_DATA
};

// A watcher is a user-provided function that will be called when a reactive
// value changes.
typedef void (*ReactiveWatchFn)(void* userdata, Reactive*);
struct ReactiveWatcher_s {
  ReactiveWatchFn cb;
  void* userdata;

  ReactiveWatcher* _next;
  u64 _txid;  // called at most once per tx
  bool _derived;  // whether the watcher produces a ReactiveDerived value
};

// Start/stop watching a reactive value.
void reactive_watch_start(Reactive* r, ReactiveWatcher* watcher);
void reactive_watch_stop(Reactive* r, ReactiveWatcher* watcher);

// Within a watch scope, all accessed reactive values will have the scope's
// watcher registered.
typedef struct ReactiveWatchScope_s ReactiveWatchScope;
struct ReactiveWatchScope_s {
  ReactiveWatcher watcher;

  ReactiveWatchScope* _next;
};

void reactive_watch_scope_push(ReactiveWatchScope* scope);
void reactive_watch_scope_pop();
// Call the fn under the given watch scope.
static inline void reactive_watch_scope(
    ReactiveWatchScope* scope, void* userdata, void (*fn)(void*)) {
  reactive_watch_scope_push(scope);
  fn(userdata);
  reactive_watch_scope_pop();
}

// Batch changes together in a single transaction.
// The tx fn will see a consistent view of all reactive values.
// All reactive values will advance to their new values atomically.
void reactive_tx_start();
void reactive_tx_commit();
// Call the fn under a tx.
static inline void reactive_tx(void* userdata, void (*fn)(void*)) {
  reactive_tx_start();
  fn(userdata);
  reactive_tx_commit();
}

// Helpers for equality checks
//
// == equality for plain old data types
#define reactive_eq_pod(a, b) a == b
// Ignore equality, always trigger on set
#define reactive_eq_alwaystrigger(a, b) false

// Declare typed reactive values
//
// Reactive_T
// T reactive_T_get(r)
// T* reactive_T_getp(r)
// reactive_T_set(r, value)
#define REACTIVE3(name, T, eqfn) \
  typedef struct { \
    Reactive base; \
    T value; \
    \
    T _value_next; \
  } Reactive_ ## name; \
 \
  static inline T reactive_ ## name ## _get(Reactive_ ## name* r) { \
    reactive__mark_get(&r->base); \
    return r->value; \
  } \
 \
  static inline T* reactive_ ## name ## _getp(Reactive_ ## name* r) { \
    reactive__mark_get(&r->base); \
    return &r->value; \
  } \
 \
  static inline void reactive__ ## name ## _tick(Reactive* r) { \
    Reactive_ ## name * rt = (Reactive_ ## name *)r; \
    rt->value = rt->_value_next; \
  } \
 \
  static inline void reactive_ ## name ## _set(Reactive_ ## name* r, T v) { \
    if (eqfn(r->value, v)) return; \
    r->base._advance.tick = reactive__ ## name ## _tick; \
    r->_value_next = v; \
    reactive__mark_set(&r->base); \
  } \
 \
  static inline void reactive__ ## name ## _derive_set(Reactive_ ## name* r, T v) { \
    if (eqfn(r->value, v)) return; \
    r->value = v; \
    reactive__mark_set(&r->base); \
  }
#define REACTIVE2(T, eqfn) REACTIVE3(T, T, eqfn)
#define REACTIVE(T) REACTIVE2(T, reactive_eq_pod)

// Declare typed derived reactive values
//
// ReactiveDerived_T
// reactive_derived_T_init
#define REACTIVE_DERIVED2(name, T) \
  typedef struct { \
    T (*fn)(void* userdata); \
    void* userdata; \
    Reactive_ ## name reactive; \
    \
    ReactiveWatchScope _scope; \
  } ReactiveDerived_ ## name; \
 \
  static inline void reactive__derived_ ## name ## _recompute(void* userdata) { \
    ReactiveDerived_ ## name * derived = (ReactiveDerived_ ## name *)userdata; \
    T new_value = derived->fn(derived->userdata); \
    reactive__ ## name ## _derive_set(&derived->reactive, new_value); \
  } \
 \
  static inline void reactive__derived_ ## name ## _watch(void* userdata, Reactive* r) { \
    reactive__derived_ ## name ## _recompute(userdata); \
  } \
 \
  static inline void reactive_derived_ ## name ## _init(ReactiveDerived_ ## name * derived) { \
    derived->_scope.watcher.userdata = derived; \
    derived->_scope.watcher.cb = reactive__derived_ ## name ## _watch; \
    derived->_scope.watcher._derived = true; \
    derived->reactive = (Reactive_ ## name){0}; \
    reactive_watch_scope(&derived->_scope, derived, reactive__derived_ ## name ## _recompute); \
  }
#define REACTIVE_DERIVED(T) REACTIVE_DERIVED2(T, T)

// Declare Reactive_X and ReactiveDerived_X for basic types.
REACTIVE(bool);
REACTIVE(u64);
REACTIVE(i64);
REACTIVE(f32);
REACTIVE3(ptr, void*, reactive_eq_pod);
REACTIVE_DERIVED(bool);
REACTIVE_DERIVED(u64);
REACTIVE_DERIVED(i64);
REACTIVE_DERIVED(f32);
REACTIVE_DERIVED2(ptr, void*);
