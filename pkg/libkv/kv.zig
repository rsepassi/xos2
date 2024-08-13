const std = @import("std");
const builtin = @import("builtin");

const log = std.log.scoped(.kv);

const c = @cImport(@cInclude("kv.h"));
const errors = @import("errors.zig");
const filedata = @import("filedata.zig");

pub const KV = struct {
    vfd: UserFD,
    mem: UserAllocator,
    readonly: bool,
    metadata: KVMetadata,

    const KVMetadata = struct {
        current: Metadata,
        next: Metadata,
    };

    pub fn init(opts: c.kv_init_opts) !*KV {
        log.debug("kv_init", .{});

        if (opts.mem.realloc == null) return error.MemMissing;
        if (opts.vfd.user_data == null) return error.VfdMissing;

        const flags: InitFlags = .{ .flags = opts.flags };
        var mem: UserAllocator = .{ .mem = opts.mem };
        const allocator = mem.allocator();

        const kv: *KV = try allocator.create(KV);
        errdefer allocator.destroy(kv);
        kv.* = .{
            .vfd = .{ .vfd = opts.vfd },
            .mem = mem,
            .readonly = flags.readonly(),
            .metadata = undefined,
        };

        kv.metadata = try initMetadata(kv, flags);
        return kv;
    }

    pub fn deinit(self: *@This()) void {
        const allocator = self.mem.allocator();
        allocator.destroy(self.metadata.current.page);
        allocator.destroy(self.metadata.next.page);
        allocator.destroy(self);
    }

    pub fn get(kv: *KV, key: []const u8, val: *[]u8) !void {
        log.debug("kv_get", .{});

        var txn: Txn = undefined;
        txn.init(kv, .{
            .readonly = true,
        });
        defer txn.close();

        try txn.get(key, val);
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
};

pub const Txn = struct {
    kv: *KV,
    opts: Opts,
    arena: std.heap.ArenaAllocator,
    pages: PageList,
    metadata: filedata.metadata_t,

    const PageList = std.ArrayListAligned([filedata.page_size]u8, filedata.page_size);
    const Opts = struct {
        readonly: bool = false,
    };

    pub fn init(self: *@This(), kv: *KV, opts: Opts) void {
        self.kv = kv;
        self.opts = opts;
        self.arena = std.heap.ArenaAllocator.init(kv.mem.allocator());
        self.pages = PageList.init(self.arena.allocator());
        self.metadata = kv.metadata.current.page.contents.metadata;
    }

    pub fn internalDeinit(self: *@This()) void {
        self.arena.deinit();
    }

    pub fn get(self: *@This(), key: []const u8, val: *[]u8) !void {
        if (key.len < 1 or key.len > filedata.max_key_len) return error.BadKey;
        _ = self;
        _ = val;
    }

    pub fn put(self: *@This(), key: []const u8, val: []const u8) !void {
        if (key.len < 1 or key.len > filedata.max_key_len) return error.BadKey;
        _ = self;
        _ = val;
    }

    pub fn del(self: *@This(), key: []const u8) !void {
        if (key.len < 1 or key.len > filedata.max_key_len) return error.BadKey;
        _ = self;
    }

    pub fn commit(self: *@This()) !void {
        defer self.internalDeinit();

        if (self.kv.readonly) return error.KvRO;
        if (self.opts.readonly) return error.TxnRO;


    }

    pub fn abort(self: *@This()) void {
        defer self.internalDeinit();
    }

    pub fn close(self: *@This()) void {
        defer self.internalDeinit();
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
        return (self.i + min_record_size) >= filedata.page_size;
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
        const nrem = filedata.page_size - self.i - @sizeOf(filedata.record_header_t);
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
    const PageList = std.ArrayListAligned([filedata.page_size]u8, filedata.page_size);
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

const Metadata = struct {
    page: *filedata.Page.Metadata,

    fn isEmpty(self: @This()) bool {
        for (filedata.Page.bytes(self.page)) |b| {
            if (b > 0) return false;
        }
        return true;
    }

    fn setNew(self: *@This()) void {
        std.mem.copyForwards(u8, &self.page.contents.header.magic, filedata.magic_bytes);

        const m = &self.page.contents.metadata;
        m.* = std.mem.zeroes(filedata.metadata_t);
        m.version = filedata.kv_version;
        m.npages = 1;

        self.page.contents.header.checksum = Checksummer.checksum(self.page.contents.metadata);
    }

    fn hasValidHeader(self: @This()) bool {
        if (!std.mem.eql(u8, &self.page.contents.header.magic, filedata.magic_bytes)) return false;
        if (self.page.contents.metadata.version != filedata.kv_version) return false;

        const ck = Checksummer.checksum(self.page.contents.metadata);
        if (!Checksummer.checksumEqual(self.page.contents.header.checksum, ck)) return false;

        return true;
    }
};

const Checksummer = struct {
    const Hash = std.crypto.hash.Sha1;

    fn checksum(x: anytype) filedata.checksum_t {
        if (Hash.digest_length > filedata.checksum_size) @compileError("hash has too large of a digest");
        var ck: filedata.checksum_t = undefined;
        Hash.hash(&@as([@sizeOf(@TypeOf(x))]u8, @bitCast(x)), ck.data[0..Hash.digest_length], .{});
        return ck;
    }

    fn checksumEqual(a: filedata.checksum_t, b: filedata.checksum_t) bool {
        return std.mem.eql(u8, a.data[0..Hash.digest_length], b.data[0..Hash.digest_length]);
    }
};

const UserFD = struct {
    vfd: c.kv_vfd,

    fn readPtrBuf(self: @This(), pagep: filedata.pageptr_t, page_t: anytype) !void {
        try self.readBuf(pagep.idx, page_t);
        if (!Checksummer.checksumEqual(pagep.checksum, Checksummer.checksum(page_t.*))) return error.CorruptData;
    }

    fn readBuf(self: @This(), pagei: filedata.pageidx_t, page_t: anytype) !void {
        log.debug("read page {d}", .{pagei});

        if (@sizeOf(@typeInfo(@TypeOf(page_t)).Pointer.child) != filedata.page_size) {
            @compileError("bad page type");
        }

        var buf: c.kv_buf = .{
            .buf = filedata.Page.bytes(page_t),
            .len = filedata.page_size,
        };

        const bufs: c.kv_bufs = .{
            .bufs = &buf,
            .len = 1,
        };

        var n: u64 = 0;
        try errors.convertResult(self.vfd.read.?(self.vfd.user_data, pagei * filedata.page_size, bufs, &n));
    }

    fn write(self: @This(), pagei: filedata.pageidx_t, page_t: anytype) !void {
        log.debug("write page {d}", .{pagei});

        if (@sizeOf(@typeInfo(@TypeOf(page_t)).Pointer.child) != filedata.page_size) {
            @compileError("bad page type");
        }

        var buf: c.kv_buf = .{
            .buf = filedata.Page.bytes(page_t),
            .len = filedata.page_size,
        };

        const bufs: c.kv_bufs = .{
            .bufs = &buf,
            .len = 1,
        };

        var n: u64 = 0;
        try errors.convertResult(self.vfd.write.?(self.vfd.user_data, pagei * filedata.page_size, bufs, &n));
    }

    fn sync(self: @This()) !void {
        log.debug("sync", .{});
        if (self.vfd.sync) |f| return errors.convertResult(f(self.vfd.user_data));
    }
};

const UserAllocator = struct {
    mem: c.kv_mem,

    fn allocPage(self: *@This(), comptime T: type) !*T {
        if (@sizeOf(T) != filedata.page_size) @compileError("bad page type");
        const buf = try self.allocator().alignedAlloc(T, filedata.page_size, 1);
        const res: *T = @ptrCast(buf.ptr);
        self.zeroPage(res);
        return res;
    }

    fn zeroPage(self: @This(), page_t: anytype) void {
        _ = self;
        @memset(filedata.Page.bytes(page_t), 0);
    }

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = std_alloc,
                .resize = std_resize,
                .free = std_free,
            },
        };
    }

    fn std_alloc(ctx: *anyopaque, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *@This() = @ptrCast(@alignCast(ctx));
        if (self.mem.realloc.?(self.mem.user_data, null, @as(usize, 1) << @intCast(log2_ptr_align), len)) |p| {
            return @ptrCast(@alignCast(p));
        } else return null;
    }

    fn std_free(
        ctx: *anyopaque,
        old_mem: []u8,
        log2_old_align_u8: u8,
        ret_addr: usize,
    ) void {
        _ = log2_old_align_u8;
        _ = ret_addr;
        const self: *@This() = @ptrCast(@alignCast(ctx));
        _ = self.mem.realloc.?(self.mem.user_data, old_mem.ptr, 0, 0);
    }

    fn std_resize(
        ctx: *anyopaque,
        old_mem: []u8,
        log2_old_align_u8: u8,
        new_size: usize,
        ret_addr: usize,
    ) bool {
        _ = ret_addr;
        const self: *@This() = @ptrCast(@alignCast(ctx));
        const p = self.mem.realloc.?(self.mem.user_data, old_mem.ptr, @as(usize, 1) << @intCast(log2_old_align_u8), new_size);
        if (p == null) return false;
        std.debug.assert(@as([*]u8, @ptrCast(@alignCast(p))) == old_mem.ptr);
        return true;
    }
};

const InitFlags = struct {
    flags: u64,

    inline fn readonly(self: @This()) bool {
        return self.flags & c.KV_INIT_READONLY == c.KV_INIT_READONLY;
    }
    inline fn allowcreate(self: @This()) bool {
        return self.flags & c.KV_INIT_ALLOWCREATE == c.KV_INIT_ALLOWCREATE;
    }
};

fn initMetadata(kv: *KV, flags: InitFlags) !KV.KVMetadata {
    const allocator = kv.mem.allocator();

    var m0: Metadata = .{ .page = try kv.mem.allocPage(filedata.Page.Metadata) };
    errdefer allocator.destroy(m0.page);
    var m1: Metadata = .{ .page = try kv.mem.allocPage(filedata.Page.Metadata) };
    errdefer allocator.destroy(m1.page);

    try kv.vfd.readBuf(0, m0.page);
    try kv.vfd.readBuf(1, m1.page);

    // Initialize new metadata
    if (m0.isEmpty() and m1.isEmpty()) {
        if (!flags.allowcreate()) return error.EmptyMetadata;
        log.debug("initializing new kv", .{});
        m0.setNew();
        m1.setNew();
        try kv.vfd.write(0, m0.page);
        try kv.vfd.sync();
        return .{
            .current = m0,
            .next = m1,
        };
    }

    // Determine valid metadata
    var candidate: ?Metadata = null;
    var fallback: ?Metadata = null;

    if (m0.isEmpty() and m1.hasValidHeader()) {
        candidate = m1;
        fallback = null;
    } else if (m0.hasValidHeader() and m1.isEmpty()) {
        candidate = m0;
        fallback = null;
    } else if (m0.hasValidHeader() and !m1.hasValidHeader()) {
        candidate = m0;
        fallback = null;
    } else if (!m0.hasValidHeader() and m1.hasValidHeader()) {
        candidate = m1;
        fallback = null;
    } else if (m0.hasValidHeader() and m1.hasValidHeader()) {
        const m0_txn = m0.page.contents.metadata.txn_id;
        const m1_txn = m1.page.contents.metadata.txn_id;
        if (m0_txn == m1_txn) return error.BadMetadata;
        if (m0_txn > m1_txn) {
            candidate = m0;
            fallback = m1;
        } else {
            candidate = m1;
            fallback = m0;
        }
    }
    if (candidate == null) return error.BadMetadata;

    const cand = candidate.?;
    // In order to determine whether to use the candidate or the fallback,
    // we must check the validity of the txnpagelist pointers. If they
    // are valid, then the candidate is current. Otherwise, use the
    // fallback.

    const valid = metadataHasValidTxnpages(kv, cand) catch |err| blk: {
        if (err == error.CorruptData) break :blk false;
        return err;
    };
    if (valid) return .{
        .current = cand,
        .next = if (cand.page == m0.page) m1 else m0,
    };
    if (fallback == null) return error.BadMetadata;

    return .{
        .current = fallback.?,
        .next = cand,
    };
}

fn metadataHasValidTxnpages(kv: *KV, m: Metadata) !bool {
    const pl = m.page.contents.metadata.txnpagelist;
    if (pl.npages == 0) return true;

    const pagelist = try kv.mem.allocPage(filedata.Page.Txnlist);
    defer kv.mem.allocator().destroy(pagelist);
    try kv.vfd.readPtrBuf(pl.first, pagelist);

    var n: u64 = 0;
    outer: while (true) {
        const pages = pagelist.contents.pages;
        const next = pagelist.contents.next;
        for (pages) |p| {
            try kv.vfd.readPtrBuf(p, pagelist);
            n += 1;
            if (n >= pl.npages) break :outer;
        }
        try kv.vfd.readPtrBuf(next, pagelist);
    }

    return true;
}
