#include "creact.h"

threadlocal ReactiveScope* tls_reactive_scope = 0;
threadlocal u64 tls_reactive_setscope = 0;
threadlocal Reactive__advance* tls_reactive_advance = 0;

static ReactiveWatcher* reactive_current_watcher() {
  if (tls_reactive_scope == NULL) return NULL;
  return &tls_reactive_scope->watcher;
}

void reactive_mark_get(Reactive* r) {
  ReactiveWatcher* watcher = reactive_current_watcher();
  if (watcher) reactive_watch(r, watcher);
}

void reactive_mark_set(Reactive* r) {
  // Register this change
  ++tls_reactive_setscope;
  r->_advance.r = r;
  r->_advance.next = tls_reactive_advance;
  tls_reactive_advance = &r->_advance;

  // Propagate this change
  ReactiveWatcher* watcher = r->watchers;
  while (watcher) {
    ReactiveWatcher* next = watcher->_next;
    watcher->cb(watcher->userdata, r);
    watcher = next;
  }

  --tls_reactive_setscope;
  if (tls_reactive_setscope == 0) {
    // Initial change propagator is now returning. All changes have been
    // propagated. Tick forward by setting value = value_next;
    Reactive__advance* cur = tls_reactive_advance;
    while (cur) {
      // cur->cb(cur->r);
      cur = cur->next;
    }
    tls_reactive_advance = 0;
  }
}

void reactive_watch(Reactive* r, ReactiveWatcher* watcher) {
  if (r->watchers == NULL) {
    r->watchers = watcher;
  } else {
    ReactiveWatcher* cur = r->watchers;
    while (cur->_next != NULL) {
      if (cur == watcher) return;
      cur = cur->_next;
    }
    if (cur == watcher) return;
    cur->_next = watcher;
  }
}

void reactive_leave(Reactive* r, ReactiveWatcher* watcher) {
  if (r->watchers == watcher) {
    r->watchers = watcher->_next;
  } else {
    ReactiveWatcher* last = r->watchers;
    while (last->_next != watcher) last = last->_next;
    last->_next = watcher->_next;
  }
}

void reactive_scope_push(ReactiveScope* scope) {
  scope->_next = tls_reactive_scope;
  tls_reactive_scope = scope;
}

void reactive_scope_pop() {
  tls_reactive_scope = tls_reactive_scope->_next;
}
