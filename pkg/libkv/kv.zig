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

        var txn: Txn = undefined;
        txn.init(kv, .{
            .readonly = true,
        });
        defer txn.close();

        return try txn.get(key);
    }

    pub fn put(kv: *KV, key: []const u8, val: []const u8) !void {
        log.debug("kv_put", .{});

        var txn: Txn = undefined;
        txn.init(kv, .{});
        {
            errdefer txn.abort();
            try txn.put(key, val);
        }

        try txn.commit();
    }

    pub fn del(kv: *KV, key: []const u8) !void {
        log.debug("kv_del", .{});

        var txn: Txn = undefined;
        txn.init(kv, .{});
        {
            errdefer txn.abort();
            try txn.del(key);
        }
        try txn.commit();
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

    const PageList = std.ArrayListAligned([filedata.page_size_reserved]u8, filedata.page_size_reserved);
    const Opts = struct {
        readonly: bool = false,
    };

    pub fn init(self: *@This(), kv: *KV, opts: Opts) void {
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

// Impl
// ============================================================================

const BTreeDataPageCursor = struct {
    page: *filedata.Page.BTreeData,
    i: usize,

    const Record = struct {
        header: *filedata.record_header_t,
        key: []u8,
        val: []u8,
    };

    fn init(page: *filedata.Page.BTreeData) @This() {
        return .{
            .page = page,
            .i = @sizeOf(filedata.btree_data_header_t),
        };
    }

    inline fn cur(self: @This()) [*]u8 {
        return @as([*]u8, @ptrCast(filedata.Page.bytes(self.page))) + self.i;
    }

    inline fn atEnd(self: @This()) bool {
        const min_record_size = @sizeOf(filedata.record_header_t) + 1;
        return (self.i + min_record_size) >= filedata.page_size_usable;
    }

    fn current(self: @This()) ?Record {
        if (self.atEnd()) return null;
        const header: *filedata.record_header_t = @ptrCast(@alignCast(self.cur()));
        if (header.key_len == 0) return null;
        var base = self.cur() + @sizeOf(filedata.record_header_t);
        return .{
            .header = header,
            .key = base[0..header.key_len],
            .val = base[header.key_len .. header.key_len + header.val_len],
        };
    }

    const RecordMut = struct {
        header: *filedata.record_header_t,
        data: []u8,

        fn write(self: @This(), key: []const u8, val: []const u8) bool {
            if (key.len + val.len > self.data.len) return false;
            self.header.key_len = key.len;
            self.header.val_len = val.len;
            std.mem.copyForwards(u8, self.data[0..key.len], key);
            std.mem.copyForwards(u8, self.data[key.len .. key.len + val.len], val);
            return true;
        }
    };

    fn remaining(self: *@This()) ?RecordMut {
        while (self.advance()) {}
        if (self.atEnd()) return null;
        const header: *filedata.record_header_t = @ptrCast(@alignCast(self.cur()));
        var base = self.cur() + @sizeOf(filedata.record_header_t);
        const nrem = filedata.page_size_usable - self.i - @sizeOf(filedata.record_header_t);
        return .{
            .header = header,
            .data = base[0..nrem],
        };
    }

    fn advance(self: *@This()) bool {
        if (self.current()) |rec| {
            self.i += @sizeOf(filedata.record_header_t) + rec.key.len + rec.val.len;
            return true;
        }
        return false;
    }
};

// B-tree insertion
//
//             const height = txn.metadata.btree.height;
//             if (height == 0) {
//                 const root = try txn.newPage(filedata.Page.BTreeNode);
//
//                 // Determine insert position
//                 const len = filedata.btree_branch_factor - 1;
//                 const middle = len / 2;
//
//                 // Determine separator key
//                 const sepkey = blk: {
//                     var sepkey: filedata.btree_sepkey_t = undefined;
//                     const klen = @min(key.len, filedata.btree_sepkey_size);
//                     std.mem.copyForwards(u8, &sepkey.key, key[0..klen]);
//                     @memset(sepkey.key[klen..filedata.btree_sepkey_size], 0);
//                     break :blk sepkey;
//                 };
//
//                 // Insert separator key
//                 root.contents.keys[middle] = sepkey;
//
//                 // Create data page
//                 var data = BTreeDataPageCursor.init(try txn.newPage(filedata.Page.BTreeData));
//                 if (data.remaining()) |rem| {
//                     // TODO: Keys can be constrained in size...
//                     // And I should do shared prefixes on the keys
//                     // But values shouldn't be
//                     if (!rem.write(key, val)) return error.Err;
//                 } else return error.Err;
//
//             } else {
//                 const current = try txn.readPage(filedata.Page.BTreeNode, txn.metadata.btree.root);
//                 for (0..height) |i| {
//                     const len = filedata.btree_branch_factor - 1;
//                     _ = current;
//                     _ = i;
//                     _ = len;
//                 }
//             }
//         }
//
//         // conflicts?
//

const Txn2 = struct {
    const PageList = std.ArrayListAligned([filedata.page_size_reserved]u8, filedata.page_size_reserved);
    kv: *KV,
    arena: std.heap.ArenaAllocator,
    pages: PageList,
    metadata: filedata.metadata_t,

    fn init(self: *@This(), kv: *KV) void {
        const alloc = kv.mem.allocator();

        self.kv = kv;
        self.arena = std.heap.ArenaAllocator.init(alloc);
        self.pages = PageList.init(self.arena.allocator());
        self.metadata = kv.metadata.current.page.contents.metadata;
    }

    fn deinit(self: @This()) void {
        self.arena.deinit();
    }

    fn readPage(self: *@This(), comptime T: type, ptr: filedata.pageptr_t) !*T {
        const page: *T = @ptrCast(@alignCast(try self.pages.addOne()));
        try self.kv.vfd.readPtrBuf(ptr, page);
        return page;
    }

    fn newPage(self: *@This(), comptime T: type) !*T {
        const page: *T = @ptrCast(@alignCast(try self.pages.addOne()));
        self.kv.mem.zeroPage(page);
        return page;
    }

    fn abort(self: @This()) void {
        defer self.deinit();
    }

    fn commit(self: *@This()) !void {
        defer self.deinit();

        // Metadata updates
        // * txn_id
        // * npages
        // * nrecords
        // * btree: root + nodes + data pages
        // * freelist
        // * txnpagelist

        // Have to ensure that txns write to disjoint pages?
        // Either free or EOF
        // Annoying...
        // Or do all writes under lock?

        // Write all pages
        //   Safe to do outside of critical section because no other txn will
        //   be writing to those same pages, and if the txn fails, these will
        //   be reused eventually
        // CRITICAL START: Lock
        //   Write to metadata.next (shared pointer *Page.Metadata)
        //   Write metadata.next page (shared page 0/1)
        //   Sync
        //   Swap next+current
        // CRITICAL END: Unlock

        // TODO: npages -> should be kept by whatever allocates new pages

        // const next = &self.next.page.metadata;
        // next.* = m;
        // next.version = kv_version;
        // next.txn_id = self.current.page.metadata.txn_id + 1;
        // next.npages = undefined;

        // self.next.page.header.checksum = Checksummer.checksum(self.next.page.metadata);

        // Transaction write pages
        // Every write transaction updates:
        // - specific offset
        // * metadata page
        // - end of file because all new pages? no, could be in holes if reusing freelist pages
        //   could try coalescing contiguous writes
        // * 0+ btree interior nodes
        // * 0-1 btree root
        // * 1+ btree data pages
        // * 0+ freelist pages
        // * 1+ txnpagelist pages
        // sync
    }

    // // Read in freelist
    // {
    //     var freelist = std.ArrayList(Page.Freelist).init(allocator);
    //     defer freelist.deinit();
    //     const fl = kv.current.page.metadata.freelist;
    //     if (fl.npages > 0) {
    //         var pages = try kv.vfd.readPtr(Page.Freelist, fl.first);
    //         try freelist.append(pages);
    //         var n: u64 = 0;
    //         while (true) {
    //             n += pages.pages.len;
    //             if (n >= fl.npages) break;
    //             pages = try kv.vfd.readPtr(Page.Freelist, pages.next);
    //             try freelist.append(pages);
    //         }
    //     }
    // }
};
