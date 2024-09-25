#pragma once

#include "base/stdtypes.h"

typedef struct Reactive_s Reactive;
typedef struct ReactiveWatcher_s ReactiveWatcher;
typedef struct Reactive__advance_s Reactive__advance;

// TODO: enable consistent reads during a tick.
// Internal helpers.
struct Reactive__advance_s {
  Reactive* r;
  void (*cb)(Reactive* r);
  Reactive__advance* next;
};

// All reactive objects have as a struct prefix a Reactive, which
// maintains a linked list of active watchers.
struct Reactive_s {
  ReactiveWatcher* watchers;
  Reactive__advance _advance;
};
typedef void (*ReactiveCb)(void* userdata, Reactive*);
struct ReactiveWatcher_s {
  ReactiveCb cb;
  void* userdata;
  ReactiveWatcher* _next;
};

// Register interest in a reactive value.
void reactive_watch(Reactive* r, ReactiveWatcher* watcher);
// Stop watching a reactive value.
void reactive_leave(Reactive* r, ReactiveWatcher* watcher);

// Within a scope, all accessed reactive values will have the scope's watcher
// registered.
typedef struct ReactiveScope_s ReactiveScope;
struct ReactiveScope_s {
  ReactiveWatcher watcher;
  ReactiveScope* _next;
};
void reactive_scope_push(ReactiveScope* scope);
void reactive_scope_pop();
// Call the fn under the given scope.
static inline void reactive_scope(ReactiveScope* scope, void* userdata, void (*fn)(void*)) {
  reactive_scope_push(scope);
  fn(userdata);
  reactive_scope_pop();
}

// Manually trigger a reactive value as read/updated.
// Called as part of type-specific reactive_T_{get,set}.
// Typically does not need to be called directly.
void reactive_mark_get(Reactive* r);
void reactive_mark_set(Reactive* r);

// Helpers for equality checks
//
// == equality for plain old data types
#define reactive_eq_pod(a, b) a == b
// Ignore equality, always trigger on set
#define reactive_eq_alwaysupdate(a, b) false

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
    T _value_next; \
  } Reactive_ ## name; \
 \
  static inline T reactive_ ## name ## _get(Reactive_ ## name* r) { \
    reactive_mark_get(&r->base); \
    return r->value; \
  } \
 \
  static inline T* reactive_ ## name ## _getp(Reactive_ ## name* r) { \
    reactive_mark_get(&r->base); \
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
    r->base._advance.cb = reactive__ ## name ## _tick; \
    r->value = v; \
    reactive_mark_set(&r->base); \
  }
#define REACTIVE2(T, eqfn) REACTIVE3(T, T, eqfn)
#define REACTIVE(T) REACTIVE2(T, reactive_eq_pod)

REACTIVE(bool);
REACTIVE(u64);
REACTIVE(i64);
REACTIVE(f32);
REACTIVE3(ptr, void*, reactive_eq_pod);

// Declare typed derived reactive values
//
// ReactiveDerived_T
// reactive_derived_T_init
#define REACTIVE_DERIVED2(name, T) \
  typedef struct { \
    T (*fn)(void* userdata); \
    void* userdata; \
    Reactive_ ## name reactive; \
    ReactiveScope _scope; \
  } ReactiveDerived_ ## name; \
 \
  static inline void reactive__derived_ ## name ## _recompute(void* userdata) { \
    ReactiveDerived_ ## name * derived = (ReactiveDerived_ ## name *)userdata; \
    T new_value = derived->fn(derived->userdata); \
    reactive_ ## name ## _set(&derived->reactive, new_value); \
  } \
 \
  static inline void reactive__derived_ ## name ## _watch(void* userdata, Reactive* r) { \
    reactive__derived_ ## name ## _recompute(userdata); \
  } \
 \
  static inline void reactive_derived_ ## name ## _init(ReactiveDerived_ ## name * derived) { \
    derived->_scope.watcher.userdata = derived; \
    derived->_scope.watcher.cb = reactive__derived_ ## name ## _watch; \
    derived->reactive = (Reactive_ ## name){0}; \
    reactive_scope(&derived->_scope, derived, reactive__derived_ ## name ## _recompute); \
  }
#define REACTIVE_DERIVED(T) REACTIVE_DERIVED2(T, T)

REACTIVE_DERIVED(bool);
REACTIVE_DERIVED(u64);
REACTIVE_DERIVED(i64);
REACTIVE_DERIVED(f32);
REACTIVE_DERIVED2(ptr, void*);

// // Reactive computation that will be rerun on data changes
// S(fn)
// // Scope for consistent reads (no-op within a computation, time is already
// // frozen)
// S.freeze(fn)
// 
// // Temporal consistency
// // Functions only run once per update
// //   Which means there's a cached value
