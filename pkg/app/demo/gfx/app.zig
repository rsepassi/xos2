// Solid color

const std = @import("std");
const log = std.log.scoped(.app);

const app = @import("app");
const appgpu = @import("appgpu");

pub const App = @This();
pub const std_options = .{
    .log_level = .info,
};

appctx: *app.Ctx,
gfx: appgpu.Gfx,

pub fn init(self: *App, appctx: *app.Ctx) !void {
    self.* = .{
        .appctx = appctx,
        .gfx = try appgpu.defaultGfx(appctx),
    };
}

pub fn deinit(self: *App) void {
    defer self.gfx.deinit();
}

pub fn onEvent(self: *App, event: app.Event) !void {
    switch (event) {
        .start, .resize => {
            self.gfx.updateWindowSize();
            try self.render();
        },
        else => |e| {
            log.info("event {any}", .{e});
        },
    }
}

fn render(self: *App) !void {
    const frame = try self.gfx.beginFrame(.{
        .load = .{ .Clear = .{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 } },
    });
    defer frame.endFrame() catch @panic("bad frame");
}
