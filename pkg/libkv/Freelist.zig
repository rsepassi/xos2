const std = @import("std");
const filedata = @import("filedata.zig");
const File = @import("File.zig");
const Allocator = @import("Allocator.zig");

freelist: filedata.metadata_t.freelist_t,
file: *File,
allocator: *Allocator,
pages: ?[]filedata.Page.Freelist = null,

fn read(self: @This()) !void {
    std.debug.assert(self.pages == null);
    if (self.freelist.npages == 0) return;
    self.pages = try self.allocator.allocPages(filedata.Page.Freelist, self.freelist.npages);
    var ptr = self.freelist.first;
    for (0..self.freelist.npages) |i| {
        const page = &self.pages[i];
        self.file.read(ptr, page);
        ptr = page.next;
    }
}

fn deinit(self: @This()) void {
    if (self.pages == null) return;
    self.allocator.allocator().free(self.pages.?);
}
