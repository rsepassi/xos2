const std = @import("std");
const uv = @import("uv.zig");
const coro = @import("zigcoro");

const log = std.log.scoped(.uvzig);

pub fn sleep(loop: *uv.uv_loop_t, duration_ms: usize) !void {
    log.debug("sleep {d}", .{duration_ms});
    var handle = uv.uv_timer_t{};
    defer {
        uv.uv_close(@ptrCast(&handle), Data.xresume2);
        coro.xsuspend();
    }
    var data = Data.init();
    uv.setHandleData(&handle, &data);

    try uv.check(uv.uv_timer_init(loop, &handle));
    try uv.check(uv.uv_timer_start(&handle, Data.xresume, duration_ms, 0));
    coro.xsuspend();
    log.debug("sleep done", .{});
}

const Data = struct {
    frame: coro.Frame,
    fn init() @This() {
        return .{ .frame = coro.xframe() };
    }

    fn xresume(handle: [*c]uv.uv_timer_t) callconv(.C) void {
        const data = uv.getHandleData(handle, @This());
        coro.xresume(data.frame);
    }

    fn xresume2(handle: [*c]uv.uv_handle_t) callconv(.C) void {
        const data = uv.getHandleData(handle, @This());
        coro.xresume(data.frame);
    }
};
