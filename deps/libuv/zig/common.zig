const std = @import("std");
const uv = @import("uv.zig");
const coro = @import("zigcoro");

pub const uv_close_cb = struct {
    frame: coro.Frame,

    pub fn init(self: *@This(), handle: *uv.uv_handle_t) void {
        uv.setHandleData(handle, self);
        self.frame = coro.xframe();
    }

    pub fn cb(handle: [*c]uv.uv_handle_t) callconv(.C) void {
        const self = uv.getHandleData(handle, @This());
        coro.xresume(self.frame);
    }
};
