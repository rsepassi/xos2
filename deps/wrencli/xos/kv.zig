// TODO: consider these options / setup routines
// MDB_NOTLS
// mdb_env_set_maxdbs(), mdb_env_set_mapsize(), mdb_env_set_maxreaders()
// Consider reusing transactions
// Writes on separate thread?
// Reads on separate thread?

const std = @import("std");
const wren = struct {
    const c = @cImport(@cInclude("wren.h"));
};

const lmdb = struct {
    const c = @cImport(@cInclude("lmdb.h"));
    fn check(rc: c_int) !void {
        if (rc != 0) return error.Lmdb;
    }
};

export fn wrenKvSource() [*c]const u8 {
    const src = @embedFile("kv.wren");
    return @ptrCast(src);
}

const wren_methods = .{
    .{ "KV", .{}, .{
        .{ "get(_)", kvGet },
        .{ "set(_,_)", kvSet },
        .{ "remove(_)", kvDel },
        .{ "getPrefix(_)", kvGetPrefix },
        .{ "removePrefix(_)", kvDelPrefix },
    } },
};
const wren_classes = .{
    .{ "KV", alloc, finalize },
};

export fn wrenKvBindForeignMethod(
    vm: *wren.c.WrenVM,
    cclassName: [*c]const u8,
    isStatic: bool,
    csig: [*c]const u8,
) wren.c.WrenForeignMethodFn {
    _ = vm;
    const className = std.mem.span(cclassName);
    const sig = std.mem.span(csig);

    inline for (wren_methods) |m| {
        if (std.mem.eql(u8, className, m[0])) {
            if (isStatic) {
                inline for (m[1]) |m_| {
                    if (std.mem.eql(u8, sig, m_[0])) return m_[1];
                }
            } else {
                inline for (m[2]) |m_| {
                    if (std.mem.eql(u8, sig, m_[0])) return m_[1];
                }
            }
        }
    }

    return null;
}

export fn wrenKvBindForeignClass(
    vm: *wren.c.WrenVM,
    cmodule: [*c]const u8,
    cclassName: [*c]const u8,
) wren.c.WrenForeignClassMethods {
    _ = vm;
    _ = cmodule;

    const className = std.mem.span(cclassName);
    inline for (wren_classes) |c| {
        if (std.mem.eql(u8, className, c[0])) {
            return .{ .allocate = c[1], .finalize = c[2] };
        }
    }

    return .{};
}

var global_env: ?*lmdb.c.MDB_env = null;

const KV = struct {
    dbi: lmdb.c.MDB_dbi,

    const Opts = struct {
        path: [:0]const u8,
    };
    fn init(opts: Opts) !@This() {
        if (global_env == null) {
            try lmdb.check(lmdb.c.mdb_env_create(&global_env));
        }

        try lmdb.check(lmdb.c.mdb_env_open(global_env, opts.path, lmdb.c.MDB_NOSUBDIR | lmdb.c.MDB_NORDAHEAD, 0o644));
        var txn: ?*lmdb.c.MDB_txn = undefined;
        try lmdb.check(lmdb.c.mdb_txn_begin(global_env, null, 0, &txn));
        errdefer lmdb.c.mdb_txn_abort(txn);
        var dbi: lmdb.c.MDB_dbi = undefined;
        try lmdb.check(lmdb.c.mdb_dbi_open(txn, null, 0, &dbi));
        try lmdb.check(lmdb.c.mdb_txn_commit(txn));
        return .{ .dbi = dbi };
    }

    fn deinit(self: @This()) void {
        lmdb.c.mdb_dbi_close(global_env, self.dbi);
    }

    fn set(self: @This(), key: []const u8, val: []const u8) !void {
        var txn: ?*lmdb.c.MDB_txn = undefined;
        try lmdb.check(lmdb.c.mdb_txn_begin(global_env, null, 0, &txn));
        errdefer lmdb.c.mdb_txn_abort(txn);

        var mdbkey: lmdb.c.MDB_val = .{
            .mv_data = @constCast(key.ptr),
            .mv_size = key.len,
        };
        var mdbval: lmdb.c.MDB_val = .{
            .mv_data = @constCast(val.ptr),
            .mv_size = val.len,
        };

        try lmdb.check(lmdb.c.mdb_put(txn, self.dbi, &mdbkey, &mdbval, 0));
        try lmdb.check(lmdb.c.mdb_txn_commit(txn));
    }

    fn del(self: @This(), key: []const u8) !void {
        var txn: ?*lmdb.c.MDB_txn = undefined;
        try lmdb.check(lmdb.c.mdb_txn_begin(global_env, null, 0, &txn));
        errdefer lmdb.c.mdb_txn_abort(txn);

        var mdbkey: lmdb.c.MDB_val = .{
            .mv_data = @constCast(key.ptr),
            .mv_size = key.len,
        };

        const rc = lmdb.c.mdb_del(txn, self.dbi, &mdbkey, null);
        if (rc == lmdb.c.MDB_NOTFOUND) {} else {
            try lmdb.check(rc);
        }
        try lmdb.check(lmdb.c.mdb_txn_commit(txn));
    }

    fn get(self: @This(), key: []const u8, vm: ?*wren.c.WrenVM) !void {
        var txn: ?*lmdb.c.MDB_txn = undefined;
        try lmdb.check(lmdb.c.mdb_txn_begin(global_env, null, lmdb.c.MDB_RDONLY, &txn));
        errdefer lmdb.c.mdb_txn_abort(txn);

        var mdbkey: lmdb.c.MDB_val = .{
            .mv_data = @constCast(key.ptr),
            .mv_size = key.len,
        };
        var mdbval: lmdb.c.MDB_val = undefined;

        const rc = lmdb.c.mdb_get(txn, self.dbi, &mdbkey, &mdbval);
        if (rc == lmdb.c.MDB_NOTFOUND) {
            wren.c.wrenSetSlotNull(vm, 0);
        } else {
            try lmdb.check(rc);
            const cval: [*c]const u8 = @ptrCast(mdbval.mv_data);
            const val = cval[0..mdbval.mv_size];
            wren.c.wrenSetSlotBytes(vm, 0, val.ptr, val.len);
        }

        try lmdb.check(lmdb.c.mdb_txn_commit(txn));
    }

    fn getPrefix(self: @This(), prefix: []const u8, vm: ?*wren.c.WrenVM) !void {
        var txn: ?*lmdb.c.MDB_txn = undefined;
        try lmdb.check(lmdb.c.mdb_txn_begin(global_env, null, lmdb.c.MDB_RDONLY, &txn));
        errdefer lmdb.c.mdb_txn_abort(txn);

        var cursor: ?*lmdb.c.MDB_cursor = undefined;
        try lmdb.check(lmdb.c.mdb_cursor_open(txn, self.dbi, &cursor));
        errdefer lmdb.c.mdb_cursor_close(cursor);

        var mdbkey: lmdb.c.MDB_val = .{
            .mv_data = @constCast(prefix.ptr),
            .mv_size = prefix.len,
        };
        var mdbval: lmdb.c.MDB_val = undefined;

        const return_all = prefix.len == 0;
        const first_op: c_uint = if (return_all) lmdb.c.MDB_FIRST else lmdb.c.MDB_SET_RANGE;

        var i: usize = 0;
        while (true) : (i += 1) {
            const rc = lmdb.c.mdb_cursor_get(cursor, &mdbkey, &mdbval, if (i == 0) first_op else lmdb.c.MDB_NEXT);
            if (rc == lmdb.c.MDB_NOTFOUND) {
                break;
            } else {
                try lmdb.check(rc);

                const ckey: [*c]const u8 = @ptrCast(mdbkey.mv_data);
                const key = ckey[0..mdbkey.mv_size];
                const cval: [*c]const u8 = @ptrCast(mdbval.mv_data);
                const val = cval[0..mdbval.mv_size];

                if (return_all or std.mem.startsWith(u8, key, prefix)) {
                    wren.c.wrenSetSlotBytes(vm, 1, key.ptr, key.len);
                    wren.c.wrenSetSlotBytes(vm, 2, val.ptr, val.len);
                    wren.c.wrenSetMapValue(vm, 0, 1, 2);
                } else {
                    break;
                }
            }
        }
        lmdb.c.mdb_cursor_close(cursor);
        try lmdb.check(lmdb.c.mdb_txn_commit(txn));
    }

    fn delPrefix(self: @This(), prefix: []const u8) !void {
        var txn: ?*lmdb.c.MDB_txn = undefined;
        try lmdb.check(lmdb.c.mdb_txn_begin(global_env, null, 0, &txn));
        errdefer lmdb.c.mdb_txn_abort(txn);

        var cursor: ?*lmdb.c.MDB_cursor = undefined;
        try lmdb.check(lmdb.c.mdb_cursor_open(txn, self.dbi, &cursor));
        errdefer lmdb.c.mdb_cursor_close(cursor);

        var mdbkey: lmdb.c.MDB_val = .{
            .mv_data = @constCast(prefix.ptr),
            .mv_size = prefix.len,
        };
        var mdbval: lmdb.c.MDB_val = undefined;

        var i: usize = 0;
        while (true) : (i += 1) {
            const rc = lmdb.c.mdb_cursor_get(cursor, &mdbkey, &mdbval, if (i == 0) lmdb.c.MDB_SET_RANGE else lmdb.c.MDB_NEXT);
            if (rc == lmdb.c.MDB_NOTFOUND) {
                break;
            } else {
                try lmdb.check(rc);

                const ckey: [*c]const u8 = @ptrCast(mdbkey.mv_data);
                const key = ckey[0..mdbkey.mv_size];

                if (std.mem.startsWith(u8, key, prefix)) {
                    try lmdb.check(lmdb.c.mdb_cursor_del(cursor, 0));
                } else {
                    break;
                }
            }
        }

        lmdb.c.mdb_cursor_close(cursor);

        try lmdb.check(lmdb.c.mdb_txn_commit(txn));
    }
};

fn kvGet(vm: ?*wren.c.WrenVM) callconv(.C) void {
    var kv: *KV = @ptrCast(@alignCast(wren.c.wrenGetSlotForeign(vm, 0)));
    const ckey = wren.c.wrenGetSlotString(vm, 1);
    const key = std.mem.span(ckey);

    wren.c.wrenEnsureSlots(vm, 1);

    kv.get(key, vm) catch {
        wren.c.wrenSetSlotString(vm, 0, "failed to access database");
        wren.c.wrenAbortFiber(vm, 0);
        return;
    };
}

fn kvGetPrefix(vm: ?*wren.c.WrenVM) callconv(.C) void {
    var kv: *KV = @ptrCast(@alignCast(wren.c.wrenGetSlotForeign(vm, 0)));
    const ckey = wren.c.wrenGetSlotString(vm, 1);
    const key = std.mem.span(ckey);

    wren.c.wrenEnsureSlots(vm, 3);
    wren.c.wrenSetSlotNewMap(vm, 0);

    kv.getPrefix(key, vm) catch {
        wren.c.wrenSetSlotString(vm, 0, "failed to access database");
        wren.c.wrenAbortFiber(vm, 0);
        return;
    };
}

fn kvDelPrefix(vm: ?*wren.c.WrenVM) callconv(.C) void {
    var kv: *KV = @ptrCast(@alignCast(wren.c.wrenGetSlotForeign(vm, 0)));
    const ckey = wren.c.wrenGetSlotString(vm, 1);
    const key = std.mem.span(ckey);

    kv.delPrefix(key) catch {
        wren.c.wrenSetSlotString(vm, 0, "failed to delete from database");
        wren.c.wrenAbortFiber(vm, 0);
        return;
    };

    wren.c.wrenEnsureSlots(vm, 1);
    wren.c.wrenSetSlotNull(vm, 0);
}

fn kvSet(vm: ?*wren.c.WrenVM) callconv(.C) void {
    var kv: *KV = @ptrCast(@alignCast(wren.c.wrenGetSlotForeign(vm, 0)));

    const ckey = wren.c.wrenGetSlotString(vm, 1);
    const key = std.mem.span(ckey);

    const cval = wren.c.wrenGetSlotString(vm, 2);
    const val = std.mem.span(cval);

    kv.set(key, val) catch {
        wren.c.wrenSetSlotString(vm, 0, "failed to write to database");
        wren.c.wrenAbortFiber(vm, 0);
        return;
    };
}

fn kvDel(vm: ?*wren.c.WrenVM) callconv(.C) void {
    var kv: *KV = @ptrCast(@alignCast(wren.c.wrenGetSlotForeign(vm, 0)));

    const ckey = wren.c.wrenGetSlotString(vm, 1);
    const key = std.mem.span(ckey);

    kv.del(key) catch {
        wren.c.wrenSetSlotString(vm, 0, "failed to delete from database");
        wren.c.wrenAbortFiber(vm, 0);
        return;
    };

    wren.c.wrenEnsureSlots(vm, 1);
    wren.c.wrenSetSlotNull(vm, 0);
}

fn alloc(vm: ?*wren.c.WrenVM) callconv(.C) void {
    const cpath = wren.c.wrenGetSlotString(vm, 1);
    const path = std.mem.span(cpath);

    const kv: *KV = @ptrCast(@alignCast(wren.c.wrenSetSlotNewForeign(vm, 0, 0, @sizeOf(KV))));
    kv.* = KV.init(.{ .path = path }) catch {
        wren.c.wrenSetSlotString(vm, 0, "failed to create database");
        wren.c.wrenAbortFiber(vm, 0);
        return;
    };
}

fn finalize(ptr: ?*anyopaque) callconv(.C) void {
    var kv: *KV = @ptrCast(@alignCast(ptr));
    kv.deinit();
}
