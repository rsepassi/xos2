#include "creact.h"
#include "base/log.h"

// TODO:
// * Recompute derivation dependencies on recompute
// * Cleanup the txid logic, shouldn't need to be 2 for every tx

// Stack of watchers. Top is returned in reactive_current_watcher().
threadlocal ReactiveWatchScope* tls_reactive_watch_stack = 0;

// txscope allows for nesting transactions, only the top-level one applies.
threadlocal u64 tls_reactive_txscope = 0;

// The current transaction id. Used to ensure derivations and effects only run
// once per transaction.
threadlocal u64 tls_reactive_txid = 0;

// txadvance is a singly linked list with a tail pointer for fast appends.
// It contains everything that needs to be done given the mutations made
// so far.
threadlocal Reactive__advance* tls_reactive_txadvance = 0;
threadlocal Reactive__advance* tls_reactive_txadvance_tail = 0;

static void reactive__propagate(Reactive* r, bool derived) {
  ReactiveWatcher* watcher = r->_watchers;
  if (!watcher) return;

  REACTIVE_LOGF("propagate start", r, " derived=%d", derived);
  u64 n = 0;
  while (watcher) {
    ReactiveWatcher* next = watcher->_next;
    if (watcher->_derived == derived && watcher->_txid != tls_reactive_txid) {
      watcher->_txid = tls_reactive_txid;
      watcher->cb(watcher->userdata, r);
      ++n;
    }
    watcher = next;
  }
  REACTIVE_LOGF("propagate done", r, " derived=%d n=%d", derived, n);
}

void reactive_tx_start() {
  if (tls_reactive_txscope++ == 0) {  // start of a new tx
    ++tls_reactive_txid;
    DLOG("tx_start txid=%d", tls_reactive_txid);
  }
}

void reactive_tx_commit() {
  --tls_reactive_txscope;
  if (tls_reactive_txscope != 0) return;
  DLOG("tx_commit txid=%d", tls_reactive_txid);
  if (tls_reactive_txadvance == NULL) return;

  // Update reactive values.
  Reactive__advance* cur = tls_reactive_txadvance;
  while (cur) {
    if (cur->tick) {
      REACTIVE_LOG("tick", cur->r);
      cur->tick(cur->r);
    }
    cur = cur->next;
  }

  // Derivations and watchers are run in a fresh transaction.
  reactive_tx_start();

  // Update derived values.
  cur = tls_reactive_txadvance;
  while (cur) {
    reactive__propagate(cur->r, true);
    cur = cur->next;
  }
  DLOG("derived done txid=%d", tls_reactive_txid);

  cur = tls_reactive_txadvance;
  tls_reactive_txadvance = 0;

  // Now that all derived values have been updated, run all other watchers.
  // These watchers may modify reactive values.
  while (cur) {
    reactive__propagate(cur->r, false);
    cur = cur->next;
  }
  DLOG("watchers done txid=%d", tls_reactive_txid);

  reactive_tx_commit();  // recurse to handle effects extending txadvance
}

static ReactiveWatcher* reactive_current_watcher() {
  if (tls_reactive_watch_stack == NULL) return NULL;
  return &tls_reactive_watch_stack->watcher;
}

void reactive__mark_get(Reactive* r) {
  REACTIVE_LOG("read", r);
  ReactiveWatcher* watcher = reactive_current_watcher();
  if (watcher) reactive_watch_start(r, watcher);
}

void reactive__mark_set(Reactive* r) {
  reactive_tx_start();

  REACTIVE_LOGF("write", r, " txid=%d", tls_reactive_txid);

  // Register this change
  Reactive__advance* a = &r->_advance;
  a->r = r;
  a->next = NULL;

  if (tls_reactive_txadvance == NULL) {
    // len = 0
    tls_reactive_txadvance = a;
  } else if (tls_reactive_txadvance == tls_reactive_txadvance_tail) {
    // len = 1
    tls_reactive_txadvance->next = a;
  } else {
    // len > 1
    tls_reactive_txadvance_tail->next = a;
  }
  tls_reactive_txadvance_tail = a;

  reactive_tx_commit();
}

void reactive_watch_start(Reactive* r, ReactiveWatcher* watcher) {
  REACTIVE_LOGF("watch start", r, " derived=%d watcher=%p", watcher->_derived, watcher);
  if (r->_watchers == NULL) {
    r->_watchers = watcher;
  } else {
    ReactiveWatcher* cur = r->_watchers;
    while (cur->_next != NULL) {
      if (cur == watcher) return;  // idempotent watch start
      cur = cur->_next;
    }
    if (cur == watcher) return;
    cur->_next = watcher;
  }
}

void reactive_watch_stop(Reactive* r, ReactiveWatcher* watcher) {
  REACTIVE_LOGF("watch stop", r, " watcher=%p", watcher);
  if (r->_watchers == watcher) {
    r->_watchers = watcher->_next;
  } else {
    ReactiveWatcher* cur = r->_watchers;
    while (cur->_next != watcher) cur = cur->_next;
    cur->_next = watcher->_next;
  }
}

void reactive_watch_scope_push(ReactiveWatchScope* scope) {
  DLOG("watch scope watcher=%p", &scope->watcher);
  scope->_next = tls_reactive_watch_stack;
  tls_reactive_watch_stack = scope;
}

void reactive_watch_scope_pop() {
  DCHECK(tls_reactive_watch_stack != NULL, "popping an empty stack");
  DLOG("watch scope done watcher=%p", &tls_reactive_watch_stack->watcher);
  tls_reactive_watch_stack = tls_reactive_watch_stack->_next;
}
