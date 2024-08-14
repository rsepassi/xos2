const std = @import("std");
const filedata = @import("filedata.zig");
const checksum = @import("checksum.zig");
const Allocator = @import("Allocator.zig");
const Freelist = @import("Freelist.zig");
const File = @import("File.zig");
const log = std.log.scoped(.kv);

const Metadata = @This();

allocator: *Allocator,
file: *File,
page: *filedata.Page.Metadata,
freelist: Freelist = undefined,

pub const Pair = struct {
    current: Metadata,
    next: Metadata,

    pub fn init(allocator: *Allocator, file: *File, allowcreate: bool) !Pair {
        var pair = try initPair(allocator, file, allowcreate);
        try pair.current.readFreelist();
        return pair;
    }

    pub fn deinit(self: @This()) void {
        const allocator = self.current.allocator.allocator();
        allocator.destroy(self.current.page);
        allocator.destroy(self.next.page);
    }
};

fn initPair(allocator: *Allocator, file: *File, allowcreate: bool) !Pair {
    var m0: Metadata = .{
        .allocator = allocator,
        .file = file,
        .page = try Allocator.allocPage(allocator.allocator(), filedata.Page.Metadata),
    };
    errdefer allocator.allocator().destroy(m0.page);
    var m1: Metadata = .{
        .allocator = allocator,
        .file = file,
        .page = try Allocator.allocPage(allocator.allocator(), filedata.Page.Metadata),
    };
    errdefer allocator.allocator().destroy(m1.page);

    try file.readIdx(0, m0.page);
    try file.readIdx(1, m1.page);

    // Initialize new metadata
    if (m0.isEmpty() and m1.isEmpty()) {
        if (!allowcreate) return error.EmptyMetadata;
        log.debug("initializing new kv", .{});
        m0.setNew();
        m1.setNew();
        try file.write(0, m0.page);
        try file.sync();

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

    const valid = metadataHasValidTxnpages(allocator, file, cand) catch |err| blk: {
        if (err == error.CorruptData) break :blk false;
        return err;
    };
    if (valid) {
        return .{
            .current = cand,
            .next = if (cand.page == m0.page) m1 else m0,
        };
    }
    if (fallback == null) return error.BadMetadata;

    return .{
        .current = fallback.?,
        .next = cand,
    };
}

fn readFreelist(self: *@This()) !void {
    self.freelist = .{
        .freelist = self.page.contents.metadata.freelist,
        .allocator = self.allocator,
        .file = self.file,
    };
}

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

    self.page.contents.header.checksum = checksum.compute(self.page.contents.metadata);
}

fn hasValidHeader(self: @This()) bool {
    if (!std.mem.eql(u8, &self.page.contents.header.magic, filedata.magic_bytes)) return false;
    if (self.page.contents.metadata.version != filedata.kv_version) return false;

    const ck = checksum.compute(self.page.contents.metadata);
    if (!checksum.equal(self.page.contents.header.checksum, ck)) return false;

    return true;
}

fn metadataHasValidTxnpages(allocator: *Allocator, file: *File, m: Metadata) !bool {
    const pl = m.page.contents.metadata.txnpagelist;
    if (pl.npages == 0) return true;

    const pagelist = try Allocator.allocPage(allocator.allocator(), filedata.Page.Txnlist);
    defer allocator.allocator().destroy(pagelist);
    try file.read(pl.first, pagelist);

    var n: u64 = 0;
    outer: while (true) {
        const pages = pagelist.contents.pages;
        const next = pagelist.contents.next;
        for (pages) |p| {
            try file.read(p, pagelist);
            n += 1;
            if (n >= pl.npages) break :outer;
        }
        try file.read(next, pagelist);
    }

    return true;
}
