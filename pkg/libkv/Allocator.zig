const std = @import("std");
const c = @cImport(@cInclude("kv.h"));
const filedata = @import("filedata.zig");

mem: c.kv_mem,

pub fn allocPage(alloc: std.mem.Allocator, comptime T: type) !*T {
    const out = try allocPages(alloc, T, 1);
    return @ptrCast(out.ptr);
}

pub fn allocPages(alloc: std.mem.Allocator, comptime T: type, n: usize) ![]T {
    if (@sizeOf(T) != filedata.page_size_reserved) @compileError("bad page type");
    const buf = try alloc.alignedAlloc(
        T,
        filedata.page_size_reserved,
        n,
    );
    for (buf) |*x| zeroPage(x);
    return buf;
}

pub fn zeroPage(page_t: anytype) void {
    @memset(filedata.Page.bytes(page_t), 0);
}

pub fn allocator(self: *@This()) std.mem.Allocator {
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
