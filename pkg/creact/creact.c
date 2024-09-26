#include "creact.h"
#include "base/log.h"

threadlocal ReactiveWatchScope* tls_reactive_watch_scope = 0;

threadlocal u64 tls_reactive_txscope = 0;
threadlocal u64 tls_reactive_txid = 0;
threadlocal Reactive__advance* tls_reactive_txadvance = 0;

static void reactive__propagate(Reactive* r) {
  ReactiveWatcher* watcher = r->watchers;
  if (!watcher) return;

  REACTIVE_LOG("propagate start", r);

  while (watcher) {
    ReactiveWatcher* next = watcher->_next;
    if (watcher->_tid != tls_reactive_txid) {
      watcher->_tid = tls_reactive_txid;
      watcher->cb(watcher->userdata, r);
    }
    watcher = next;
  }

  REACTIVE_LOG("propagate done", r);
}

void reactive_tx_start() {
  if (tls_reactive_txscope++ == 0) {
    ++tls_reactive_txid;
    DLOG("tx_start txid=%d", tls_reactive_txid);
  }
}

void reactive_tx_commit() {
  --tls_reactive_txscope;
  if (tls_reactive_txscope != 0) return;
  DLOG("tx_commit txid=%d", tls_reactive_txid);

  // Transaction has ended
  while (tls_reactive_txadvance) {
    // Apply all deferred changes
    Reactive__advance* cur = tls_reactive_txadvance;
    while (cur) {
      REACTIVE_LOG("tick", cur->r);
      cur->tick(cur->r);
      cur = cur->next;
    }

    cur = tls_reactive_txadvance;
    tls_reactive_txadvance = 0;

    u64 tid = tls_reactive_txid;

    // Propagate the changes under a new transaction
    reactive_tx_start();
    DCHECK(tls_reactive_txid != tid);
    while (cur && cur->tid == tid) {
      reactive__propagate(cur->r);
      cur = cur->next;
    }
    reactive_tx_commit();
  }
}

static ReactiveWatcher* reactive_current_watcher() {
  if (tls_reactive_watch_scope == NULL) return NULL;
  return &tls_reactive_watch_scope->watcher;
}

void reactive__mark_get(Reactive* r) {
  REACTIVE_LOG("read", r);
  ReactiveWatcher* watcher = reactive_current_watcher();
  if (watcher) {
    reactive_watch(r, watcher);
  }
}

void reactive__mark_set(Reactive* r) {
  reactive_tx_start();
  REACTIVE_LOGF("write", r, " txid=%d", tls_reactive_txid);

  // Register this change
  r->_advance.r = r;
  r->_advance.next = tls_reactive_txadvance;
  r->_advance.tid = tls_reactive_txid;
  tls_reactive_txadvance = &r->_advance;

  reactive_tx_commit();
}

void reactive_watch(Reactive* r, ReactiveWatcher* watcher) {
  REACTIVE_LOGF("attach watcher", r, " watcher=%p", watcher);
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
  REACTIVE_LOGF("detach watcher", r, " watcher=%p", watcher);
  if (r->watchers == watcher) {
    r->watchers = watcher->_next;
  } else {
    ReactiveWatcher* last = r->watchers;
    while (last->_next != watcher) last = last->_next;
    last->_next = watcher->_next;
  }
}

void reactive_watch_scope_push(ReactiveWatchScope* scope) {
  scope->_next = tls_reactive_watch_scope;
  tls_reactive_watch_scope = scope;
}

void reactive_watch_scope_pop() {
  tls_reactive_watch_scope = tls_reactive_watch_scope->_next;
}
