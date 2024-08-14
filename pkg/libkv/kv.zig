const std = @import("std");
const builtin = @import("builtin");
const c = @cImport(@cInclude("kv.h"));
const checksum = @import("checksum.zig");
const filedata = @import("filedata.zig");
const Allocator = @import("Allocator.zig");
const Metadata = @import("Metadata.zig");
const File = @import("File.zig");
const BTree = @import("BTree.zig");
const log = std.log.scoped(.kv);

pub const KV = struct {
    vfd: File,
    mem: Allocator,
    readonly: bool,
    metadata: Metadata.Pair,

    pub fn init(opts: c.kv_init_opts) !*KV {
        log.debug("kv_init", .{});

        if (opts.mem.realloc == null) return error.MemMissing;
        if (opts.vfd.user_data == null) return error.VfdMissing;

        const flags: InitFlags = .{ .flags = opts.flags };
        var mem: Allocator = .{ .mem = opts.mem };
        const allocator = mem.allocator();

        const kv: *KV = try allocator.create(KV);
        errdefer allocator.destroy(kv);

        kv.* = .{
            .vfd = .{ .vfd = opts.vfd },
            .mem = mem,
            .readonly = flags.readonly(),
            .metadata = undefined,
        };

        kv.metadata = try Metadata.Pair.init(&kv.mem, &kv.vfd, flags.allowcreate());
        return kv;
    }

    pub fn deinit(self: *@This()) void {
        log.debug("kv_deinit", .{});
        const allocator = self.mem.allocator();
        self.metadata.deinit();
        allocator.destroy(self);
    }

    pub fn get(kv: *KV, key: []const u8) !?[]u8 {
        log.debug("kv_get", .{});

        var tx: Txn = undefined;
        tx.init(kv, .{
            .readonly = true,
        });
        defer tx.close();

        return try tx.get(key);
    }

    pub fn put(kv: *KV, key: []const u8, val: []const u8) !void {
        log.debug("kv_put", .{});

        var tx: Txn = undefined;
        tx.init(kv, .{});
        {
            errdefer tx.abort();
            try tx.put(key, val);
        }

        try tx.commit();
    }

    pub fn del(kv: *KV, key: []const u8) !void {
        log.debug("kv_del", .{});

        var tx: Txn = undefined;
        tx.init(kv, .{});
        {
            errdefer tx.abort();
            try tx.del(key);
        }
        try tx.commit();
    }

    pub fn txn(kv: *KV, opts: Txn.Opts) !*Txn {
        return try Txn.initAlloc(kv, opts);
    }

    const InitFlags = struct {
        flags: u64,
        inline fn readonly(self: @This()) bool {
            return self.flags & c.KV_INIT_READONLY == c.KV_INIT_READONLY;
        }
        inline fn allowcreate(self: @This()) bool {
            return self.flags & c.KV_INIT_ALLOWCREATE == c.KV_INIT_ALLOWCREATE;
        }
    };
};

pub const Txn = struct {
    kv: *KV,
    opts: Opts,
    arena: std.heap.ArenaAllocator,
    pages: PageList,
    metadata: filedata.metadata_t,
    btree: BTree,
    selfalloc: bool = false,

    const PageList = std.ArrayListAligned([filedata.page_size_reserved]u8, filedata.page_size_reserved);
    const Opts = struct {
        readonly: bool = false,
    };

    fn initAlloc(kv: *KV, opts: Opts) !*@This() {
        const allocator = kv.mem.allocator();
        const self = try allocator.create(@This());
        self.init(kv, opts);
        self.selfalloc = true;
        return self;
    }

    fn init(self: *@This(), kv: *KV, opts: Opts) void {
        self.kv = kv;
        self.opts = opts;
        self.arena = std.heap.ArenaAllocator.init(kv.mem.allocator());
        self.pages = PageList.init(self.arena.allocator());
        self.metadata = kv.metadata.current.page.contents.metadata;
        self.btree = .{
            .tree = self.metadata.btree,
            .file = &kv.vfd,
            .allocator = self.arena.allocator(),
        };
    }

    fn internalDeinit(self: *@This()) void {
        self.arena.deinit();
        if (self.selfalloc) self.kv.mem.allocator().destroy(self);
    }

    pub fn get(self: *@This(), key: []const u8) !?[]u8 {
        if (key.len < 1) return error.BadKey;
        return try self.btree.get(key, self.kv.mem.allocator());
    }

    pub fn put(self: *@This(), key: []const u8, val: []const u8) !void {
        if (key.len < 1) return error.BadKey;
        try self.assertWritable();
        _ = val;
    }

    pub fn del(self: *@This(), key: []const u8) !void {
        if (key.len < 1) return error.BadKey;
        try self.assertWritable();
    }

    const Iterator = struct {
        iter: BTree.Iterator,

        pub fn next(self: *@This()) !?BTree.Iterator.Record {
            return try self.iter.next();
        }

        pub fn seek(self: *@This(), prefix: []const u8) !void {
            return try self.iter.seek(prefix);
        }
    };

    pub fn iterator(self: *@This()) !Iterator {
        return .{ .iter = try self.btree.iterator() };
    }

    pub fn commit(self: *@This()) !void {
        defer self.internalDeinit();
    }

    pub fn abort(self: *@This()) void {
        defer self.internalDeinit();
    }

    pub fn close(self: *@This()) void {
        defer self.internalDeinit();
        if (!self.opts.readonly) @panic("close can only be called on a readonly txn");
    }

    inline fn assertWritable(self: @This()) !void {
        if (self.kv.readonly) return error.KvRO;
        if (self.opts.readonly) return error.TxnRO;
    }
};
