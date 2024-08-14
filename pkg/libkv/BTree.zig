const std = @import("std");
const filedata = @import("filedata.zig");
const Allocator = @import("Allocator.zig");
const File = @import("File.zig");
const log = std.log.scoped(.kv);

tree: filedata.metadata_t.btree_t,
file: *File,
allocator: std.mem.Allocator,

pub fn get(self: *@This(), needle: []const u8, out_allocator: std.mem.Allocator) !?[]u8 {
    if (self.tree.height == 0) return null;

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
        if (try iter.keyEqual(needle)) return try iter.valAlloc(out_allocator);
        const live = try iter.advance();
        if (!live) break;
    }

    return null;
}

const Leaf = struct {
    page: *filedata.Page.BTreeLeaf,
    overflow: *filedata.Page.Overflow,
    file: *File,

    fn iterator(self: @This()) Iterator {
        return .{
            .p = self,
            .ptr = self.page.unallocated().ptr,
        };
    }

    const Iterator = struct {
        p: Leaf,
        ptr: [*]u8,
        i: usize = 0,

        fn advance(self: *@This()) !bool {
            if (self.i >= self.p.page.contents.nrecords) return false;
            const header = self.getHeader();
            const nvalbytes = if (self.isValInlined()) header.val_len else @sizeOf(filedata.btree_overflow_t);
            self.ptr = self.valOffset() + nvalbytes;
            self.i += 1;
            return true;
        }

        fn keyEqual(self: @This(), needle: []const u8) !bool {
            const header = self.getHeader();
            return self.itemEqual(self.keyOffset(), header.key_len, needle);
        }

        fn valAlloc(self: @This(), allocator: std.mem.Allocator) ![]u8 {
            const header = self.getHeader();
            const val = try allocator.alloc(u8, header.val_len);
            try self.itemCopy(self.valOffset(), val);
            return val;
        }

        fn itemEqual(
            self: @This(),
            ptr: [*]u8,
            itemlen: usize,
            needle: []const u8,
        ) !bool {
            if (itemlen != needle.len) return false;
            if (itemlen <= filedata.btree_inline_maxlen) {
                const item = ptr[0..itemlen];
                return std.mem.eql(u8, needle, item);
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
                    if (!std.mem.eql(u8, needle[len .. len + n], itemseg)) return false;

                    len += n;
                }
                return true;
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
                if (needle[j] > key[j]) return true;
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
                    if (needle[needle_i + j] > keyseg[j]) return true;
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

    fn iterator(self: @This()) Iterator {
        return .{ .p = self };
    }

    const Iterator = struct {
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
