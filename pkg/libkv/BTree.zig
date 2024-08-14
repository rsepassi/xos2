const std = @import("std");
const filedata = @import("filedata.zig");
const Allocator = @import("Allocator.zig");
const File = @import("File.zig");
const log = std.log.scoped(.kv);

const BTree = @This();

tree: filedata.metadata_t.btree_t,
file: *File,
allocator: std.mem.Allocator,

// TODO:
// put
// del

inline fn empty(self: @This()) bool {
    return self.tree.height == 0;
}

pub const Iterator = struct {
    p: *BTree,

    pages: []filedata.Page.Generic,
    buf: []u8,
    iter: Leaf.LeafIterator = undefined,

    pub const Record = struct {
        key: []const u8,
        val: []const u8,
    };

    pub fn init(p: *BTree) !@This() {
        const pages = try Allocator.allocPages(p.allocator, filedata.Page.Generic, 2);
        const out: @This() = .{
            .p = p,
            .pages = pages,
            .buf = try p.allocator.alloc(u8, 0),
        };
        return out;
    }

    pub fn deinit(self: @This()) void {
        self.p.allocator.free(self.pages);
        self.p.allocator.free(self.buf);
    }

    pub fn next(self: *@This()) !?Record {
        if (self.p.empty()) return null;
        if (self.iter.done() and !try self.iter.advanceNextLeaf()) return null;

        const header = self.iter.getHeader();
        const combined_len = header.key_len + header.val_len;
        self.buf = try self.p.allocator.realloc(self.buf, combined_len);
        const key = self.buf[0..header.key_len];
        const val = self.buf[header.key_len .. self.buf.len - 1];
        try self.iter.keyCopy(key);
        try self.iter.valCopy(val);
        return .{
            .key = key,
            .val = val,
        };
    }

    pub fn seek(self: *@This(), prefix: []const u8) !void {
        const page: *filedata.Page.BTreeNode = @ptrCast(@alignCast(&self.pages[0]));
        const overflow: *filedata.Page.Overflow = @ptrCast(@alignCast(&self.pages[1]));

        // Search tree for the leaf that may contain the prefix
        const node: Node = .{
            .file = self.p.file,
            .overflow = overflow,
            .page = page,
        };
        var current = self.p.tree.root;
        for (0..self.p.tree.height) |_| {
            try self.p.file.read(current, node.page);
            current = try node.find(prefix);
        }

        // Load the leaf
        const leafpage: *filedata.Page.BTreeLeaf = @ptrCast(@alignCast(page));
        try self.p.file.read(current, leafpage);
        const leaf: Leaf = .{
            .page = leafpage,
            .overflow = overflow,
            .file = self.p.file,
        };

        // Search the leaf, stopping at the first item that is >= prefix
        self.iter = leaf.iterator();
        while (true) {
            if (!(try self.iter.keyCompare(prefix, .LT))) break;
            if (!try self.iter.advance()) break;
        }

        return error.Err;
    }
};

pub fn iterator(self: *@This()) !Iterator {
    return try Iterator.init(self);
}

pub fn get(self: *@This(), needle: []const u8, out_allocator: std.mem.Allocator) !?[]u8 {
    if (self.empty()) return null;

    // Reads require 2 page allocations
    const pages = try Allocator.allocPages(self.allocator, filedata.Page.BTreeNode, 2);
    defer self.allocator.free(pages);

    const page = &pages[0];
    const overflow: *filedata.Page.Overflow = @ptrCast(@alignCast(&pages[1]));

    // Search tree for the leaf that may contain the needle
    const node: Node = .{
        .file = self.file,
        .overflow = overflow,
        .page = page,
    };
    var current = self.tree.root;
    for (0..self.tree.height) |_| {
        try self.file.read(current, node.page);
        current = try node.find(needle);
    }

    // Load the leaf
    const leafpage: *filedata.Page.BTreeLeaf = @ptrCast(@alignCast(page));
    try self.file.read(current, leafpage);
    const leaf: Leaf = .{
        .page = leafpage,
        .overflow = overflow,
        .file = self.file,
    };

    // Search the leaf
    var iter = leaf.iterator();
    while (true) {
        if (try iter.keyCompare(needle, .EQ)) {
            const val = try out_allocator.alloc(u8, iter.getHeader().val_len);
            try iter.valCopy(val);
            return val;
        }
        const live = try iter.advance();
        if (!live) break;
    }

    return null;
}

const Leaf = struct {
    page: *filedata.Page.BTreeLeaf,
    overflow: *filedata.Page.Overflow,
    file: *File,

    inline fn next(self: @This()) filedata.pageptr_t {
        return self.page.contents.next;
    }

    fn iterator(self: @This()) LeafIterator {
        return .{
            .p = self,
            .ptr = self.page.unallocated().ptr,
        };
    }

    const LeafIterator = struct {
        p: Leaf,
        ptr: [*]u8,
        i: usize = 0,

        fn advanceNextLeaf(self: *@This()) !bool {
            const next_leaf_ptr = self.p.next();
            if (next_leaf_ptr.isnull()) return false;
            try self.p.file.read(next_leaf_ptr, self.p.page);
            self.ptr = self.p.page.unallocated().ptr;
            self.i = 0;
            return true;
        }

        inline fn done(self: @This()) bool {
            return self.i >= self.p.page.contents.nrecords;
        }

        fn advance(self: *@This()) !bool {
            if (self.done()) return false;
            const header = self.getHeader();
            const nvalbytes = if (self.isValInlined()) header.val_len else @sizeOf(filedata.btree_overflow_t);
            self.ptr = self.valOffset() + nvalbytes;
            self.i += 1;
            return true;
        }

        inline fn keyCompare(self: @This(), needle: []const u8, comptime comparison: Comparison) !bool {
            const header = self.getHeader();
            return self.itemCompare(needle, self.keyOffset(), header.key_len, comparison);
        }

        inline fn keyEqual(self: @This(), needle: []const u8) !bool {
            return try self.keyCompare(needle, .EQ);
        }

        inline fn keyCopy(self: @This(), out: []u8) !void {
            try self.itemCopy(self.keyOffset(), out);
        }

        inline fn valCopy(self: @This(), out: []u8) !void {
            try self.itemCopy(self.valOffset(), out);
        }

        // needle COMPARE item
        const Comparison = enum { LT, EQ };
        fn itemCompare(
            self: @This(),
            needle: []const u8,
            ptr: [*]u8,
            itemlen: usize,
            comptime comparison: Comparison,
        ) !bool {
            if (comparison == .EQ and itemlen != needle.len) return false;
            if (itemlen <= filedata.btree_inline_maxlen) {
                const item = ptr[0..itemlen];
                switch (comparison) {
                    .EQ => return std.mem.eql(u8, needle, item),
                    .LT => {
                        const complen = @min(needle.len, item.len);
                        for (0..complen) |i| {
                            if (needle[i] == item[i]) continue;
                            return needle[i] < item[i];
                        }
                        return needle.len < item.len;
                    },
                }
            } else {
                const overflow: Overflow = .{
                    .overflow = @ptrCast(@alignCast(ptr)),
                    .page = self.p.overflow,
                    .file = self.p.file,
                };
                var len: usize = 0;
                var iter = overflow.iterator();
                while (try iter.next()) |seg| {
                    const n = @min(itemlen - len, seg.len);
                    const itemseg = seg[0..n];
                    switch (comparison) {
                        .EQ => {
                            if (!std.mem.eql(u8, needle[len .. len + n], itemseg)) {
                                return false;
                            }
                        },
                        .LT => {
                            for (0..n) |i| {
                                if (needle[len + i] == itemseg[i]) continue;
                                return needle[len + i] < itemseg[i];
                            }
                        },
                    }
                    len += n;
                }

                return switch (comparison) {
                    .EQ => true,
                    .LT => needle.len < itemlen,
                };
            }
        }

        fn itemCopy(self: @This(), ptr: [*]u8, out: []u8) !void {
            const itemlen = out.len;
            if (itemlen <= filedata.btree_inline_maxlen) {
                const item = ptr[0..itemlen];
                std.mem.copyForwards(u8, out, item);
            } else {
                const overflow: Overflow = .{
                    .overflow = @ptrCast(@alignCast(ptr)),
                    .page = self.p.overflow,
                    .file = self.p.file,
                };
                var len: usize = 0;
                var iter = overflow.iterator();
                while (try iter.next()) |seg| {
                    const n = @min(itemlen - len, seg.len);

                    const itemseg = seg[0..n];
                    std.mem.copyForwards(u8, out[len .. len + n], itemseg);

                    len += n;
                }
            }
        }

        inline fn getHeader(self: @This()) *const filedata.record_header_t {
            return @ptrCast(@alignCast(self.ptr));
        }

        inline fn keyOffset(self: @This()) [*]u8 {
            return self.ptr + @sizeOf(filedata.record_header_t);
        }

        inline fn valOffset(self: @This()) [*]u8 {
            const header = self.getHeader();
            const nkeybytes = if (self.isKeyInlined()) header.key_len else @sizeOf(filedata.btree_overflow_t);
            return self.ptr + @sizeOf(filedata.record_header_t) + nkeybytes;
        }

        inline fn isKeyInlined(self: @This()) bool {
            return self.getHeader().key_len <= filedata.btree_inline_maxlen;
        }

        inline fn isValInlined(self: @This()) bool {
            return self.getHeader().val_len <= filedata.btree_inline_maxlen;
        }
    };
};

const Node = struct {
    page: *filedata.Page.BTreeNode,
    overflow: *filedata.Page.Overflow,
    file: *File,

    fn find(self: @This(), needle: []const u8) !filedata.pageptr_t {
        const pages = self.getPages();
        const keyinfo = self.getKeyInfo();

        var left: usize = 0;
        var right: usize = keyinfo.len;
        while (right != left) {
            const mid = left + (right - left) / 2;
            const info = &keyinfo[mid];
            if (try self.isgt(needle, info)) {
                left = mid;
            } else {
                right = mid;
            }
        }
        return pages[left];
    }

    fn getPages(self: @This()) []filedata.pageptr_t {
        const nbranch = self.page.contents.nbranch;
        const ptr_start: [*]u8 = @ptrCast(&self.page.contents);
        const pageptr_nbytes = nbranch * @sizeOf(filedata.pageptr_t);
        const pageptr_bytes = ptr_start[2 .. 2 + pageptr_nbytes];
        const pageptr_ptr: [*]filedata.pageptr_t = @ptrCast(@alignCast(pageptr_bytes.ptr));
        return pageptr_ptr[0..nbranch];
    }

    fn getKeyInfo(self: @This()) []filedata.btree_keyinfo_t {
        const nbranch = self.page.contents.nbranch;
        const ptr_start: [*]u8 = @ptrCast(&self.page.contents);
        const pageptr_nbytes = nbranch * @sizeOf(filedata.pageptr_t);
        const keyinfo_nbytes = (nbranch - 1) * @sizeOf(filedata.btree_keyinfo_t);
        const keyinfo_bytes = ptr_start[2 + pageptr_nbytes .. 2 + pageptr_nbytes + keyinfo_nbytes];
        const keyinfo_ptr: [*]filedata.btree_keyinfo_t = @ptrCast(@alignCast(keyinfo_bytes.ptr));
        return keyinfo_ptr[0 .. nbranch - 1];
    }

    fn isgt(self: @This(), needle: []const u8, info: *filedata.btree_keyinfo_t) !bool {
        const base: [*]u8 = @ptrCast(&self.page.contents);
        if (info.isinline()) {
            const key = (base + info.offset)[0..info.len_inline];

            const complen = @min(needle.len, key.len);
            for (0..complen) |j| {
                if (needle[j] == key[j]) continue;
                return needle[j] > key[j];
            }

            if (needle.len > key.len) return true;
        } else {
            const overflow: Overflow = .{
                .overflow = @ptrCast(@alignCast(base + info.offset)),
                .page = self.overflow,
                .file = self.file,
            };

            var current_key_len: u64 = 0;
            var needle_i: usize = 0;
            var iter = overflow.iterator();
            while (try iter.next()) |keyseg| {
                if (needle_i > needle.len) break;
                current_key_len += keyseg.len;

                const complen = @min(needle.len - needle_i, keyseg.len);
                for (0..complen) |j| {
                    if (needle[needle_i + j] == keyseg[j]) continue;
                    return needle[needle_i + j] > keyseg[j];
                }

                if (needle.len > current_key_len) return true;

                needle_i += complen;
            }
        }

        return false;
    }
};

const Overflow = struct {
    overflow: *filedata.btree_overflow_t,
    page: *filedata.Page.Overflow,
    file: *File,

    fn iterator(self: @This()) OverflowIterator {
        return .{ .p = self };
    }

    const OverflowIterator = struct {
        p: Overflow,
        i: u8 = 0,

        fn next(self: *@This()) !?[]u8 {
            if (self.i == 0) {
                // First return inlined
                self.i += 1;
                return &self.p.overflow.inlined;
            } else if (self.i == 1) {
                // Load overflow page
                self.i += 1;
                try self.p.file.read(self.p.overflow.next, self.p.page);
                return self.p.page.unallocated();
            } else {
                // Follow the chain
                const nextp = self.p.page.contents.next;
                if (nextp.isnull()) return null;
                try self.p.file.read(nextp, self.p.page);
                return self.p.page.unallocated();
            }
        }
    };
};
