const std = @import("std");
const filedata = @import("filedata.zig");
const Allocator = @import("Allocator.zig");
const File = @import("File.zig");
const log = std.log.scoped(.kv);

tree: filedata.metadata_t.btree_t,
file: *File,
allocator: std.mem.Allocator,

pub fn doThing(self: *@This()) !void {
    log.debug("doThing", .{});
    if (self.tree.height == 0) return;

    const s = "hi";

    // Descend down the tree
    const page = try Allocator.allocPage(self.allocator, filedata.Page.BTreeNode);
    const overflow = try Allocator.allocPage(self.allocator, filedata.Page.Overflow);
    const node: Node = .{
        .file = self.file,
        .overflow = overflow,
        .page = page,
    };
    var current = self.tree.root;
    for (0..self.tree.height) |_| {
        try self.file.read(current, node.page);
        current = try node.find(s);
    }

    // Load the leaf
    const leafpage = try Allocator.allocPage(self.allocator, filedata.Page.BTreeLeaf);
    try self.file.read(current, leafpage);
    const leaf: Leaf = .{
        .page = leafpage,
        .overflow = overflow,
        .file = self.file,
    };
    try leaf.iter();
}

const Leaf = struct {
    page: *filedata.Page.BTreeLeaf,
    overflow: *filedata.Page.Overflow,
    file: *File,

    fn iter(self: @This()) !void {
        const nrecords = self.page.contents.nrecords;
        var ptr = self.page.unallocated().ptr;
        for (0..nrecords) |_| {
            const header: *filedata.record_header_t = @ptrCast(@alignCast(ptr));
            ptr += @sizeOf(filedata.record_header_t);
            if (header.key_len <= filedata.btree_inline_maxlen) {
                const key = ptr[0..header.key_len];
                ptr += header.key_len;
                _ = key;
            } else {
                var overflow: Overflow = .{
                    .overflow = @ptrCast(@alignCast(ptr)),
                    .page = self.overflow,
                    .file = self.file,
                };
                while (try overflow.next()) |seg| {
                    _ = seg;
                }
            }
            if (header.val_len <= filedata.btree_inline_maxlen) {
                const val = ptr[0..header.val_len];
                ptr += header.val_len;
                _ = val;
            } else {
                var overflow: Overflow = .{
                    .overflow = @ptrCast(@alignCast(ptr)),
                    .page = self.overflow,
                    .file = self.file,
                };
                while (try overflow.next()) |seg| {
                    _ = seg;
                }
            }
        }
    }
};

const Node = struct {
    page: *filedata.Page.BTreeNode,
    overflow: *filedata.Page.Overflow,
    file: *File,

    fn find(self: @This(), search: []const u8) !filedata.pageptr_t {
        const pages = self.getPages();
        const keyinfo = self.getKeyInfo();

        var left: usize = 0;
        var right: usize = keyinfo.len;
        while (right != left) {
            const mid = left + (right - left) / 2;
            const info = &keyinfo[mid];
            if (try self.isgt(search, info)) {
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

    fn isgt(self: @This(), search: []const u8, info: *filedata.btree_keyinfo_t) !bool {
        const base: [*]u8 = @ptrCast(&self.page.contents);
        if (info.isinline()) {
            const key = (base + info.offset)[0..info.len_inline];

            const complen = @min(search.len, key.len);
            for (0..complen) |j| {
                if (search[j] > key[j]) return true;
            }

            if (search.len > key.len) return true;
        } else {
            var overflow: Overflow = .{
                .overflow = @ptrCast(@alignCast(base + info.offset)),
                .page = self.overflow,
                .file = self.file,
            };

            var current_key_len: u64 = 0;
            var search_i: usize = 0;
            while (try overflow.next()) |keyseg| {
                if (search_i > search.len) break;
                current_key_len += keyseg.len;

                const complen = @min(search.len - search_i, keyseg.len);
                for (0..complen) |j| {
                    if (search[search_i + j] > keyseg[j]) return true;
                }

                if (search.len > current_key_len) return true;

                search_i += complen;
            }
        }

        return false;
    }
};

const Overflow = struct {
    overflow: *filedata.btree_overflow_t,
    page: *filedata.Page.Overflow,
    file: *File,
    i: u8 = 0,

    fn next(self: *@This()) !?[]u8 {
        if (self.i == 0) {
            // First return inlined
            self.i += 1;
            return &self.overflow.inlined;
        } else if (self.i == 1) {
            // Load overflow page
            self.i += 1;
            try self.file.read(self.overflow.next, self.page);
            return self.page.unallocated();
        } else {
            // Follow the chain
            const nextp = self.page.contents.next;
            if (nextp.isnull()) return null;
            try self.file.read(nextp, self.page);
            return self.page.unallocated();
        }
    }
};
