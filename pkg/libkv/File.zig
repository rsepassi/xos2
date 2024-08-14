const std = @import("std");
const c = @cImport(@cInclude("kv.h"));
const filedata = @import("filedata.zig");
const errors = @import("errors.zig");
const checksum = @import("checksum.zig");
const log = std.log.scoped(.kv);

const File = @This();

vfd: c.kv_vfd,

pub const Lock = struct {
    f: *File,

    pub fn release(self: @This()) void {
        self.f.vfd.unlock(self.f.vfd.user_data);
    }
};

pub fn lock(self: *@This()) Lock {
    self.f.vfd.lock(self.f.vfd.user_data);
    return .{ .f = self };
}

pub fn read(self: @This(), pagep: filedata.pageptr_t, page_t: anytype) !void {
    try self.readIdx(pagep.idx, page_t);
    if (!checksum.equal(pagep.checksum, checksum.compute(page_t.*))) return error.CorruptData;
}

pub fn write(self: @This(), pagei: filedata.pageidx_t, page_t: anytype) !void {
    log.debug("write page {d}", .{pagei});

    if (@sizeOf(@typeInfo(@TypeOf(page_t)).Pointer.child) != filedata.page_size_reserved) {
        @compileError("bad page type");
    }

    var buf: c.kv_buf = .{
        .buf = filedata.Page.bytes(page_t),
        .len = filedata.page_size_reserved,
    };

    const bufs: c.kv_bufs = .{
        .bufs = &buf,
        .len = 1,
    };

    var n: u64 = 0;
    try errors.convertResult(self.vfd.write.?(self.vfd.user_data, pagei * filedata.page_size_reserved, bufs, &n));
}

pub fn sync(self: @This()) !void {
    log.debug("sync", .{});
    if (self.vfd.sync) |f| return errors.convertResult(f(self.vfd.user_data));
}

pub fn readIdx(self: @This(), pagei: filedata.pageidx_t, page_t: anytype) !void {
    log.debug("read page {d}", .{pagei});

    if (@sizeOf(@typeInfo(@TypeOf(page_t)).Pointer.child) != filedata.page_size_reserved) {
        @compileError("bad page type");
    }

    var buf: c.kv_buf = .{
        .buf = filedata.Page.bytes(page_t),
        .len = filedata.page_size_reserved,
    };

    const bufs: c.kv_bufs = .{
        .bufs = &buf,
        .len = 1,
    };

    var n: u64 = 0;
    try errors.convertResult(self.vfd.read.?(self.vfd.user_data, pagei * filedata.page_size_reserved, bufs, &n));
}
