// Boxes

const std = @import("std");
const log = std.log.scoped(.app);

const app = @import("app");
const appgpu = @import("appgpu");

const BoxPipeline = @import("BoxPipeline.zig");

pub const App = @This();
pub const std_options = .{
    .log_level = .info,
};

appctx: *app.Ctx,
gfx: appgpu.Gfx,
pipeline: BoxPipeline,
cur: [2]f32 = .{ 0, 0 },

pub fn init(self: *App, appctx: *app.Ctx) !void {
    const gfx = try appgpu.defaultGfx(appctx);
    errdefer gfx.deinit();

    const pipeline = try BoxPipeline.init(gfx);
    errdefer pipeline.deinit();

    self.* = .{
        .appctx = appctx,
        .gfx = gfx,
        .pipeline = pipeline,
    };
}

pub fn deinit(self: *App) void {
    defer self.gfx.deinit();
    defer self.pipeline.deinit();
}

fn addBox(self: *App) !void {
    try self.pipeline.box(self.cur, .{ 100, 20 }, .{ 0, 0, 1 });
    self.cur = .{ self.cur[0] + 100, self.cur[1] + 20 };
}

pub fn onEvent(self: *App, event: app.Event) !void {
    switch (event) {
        .start => {
            try self.addBox();
            try self.addBox();
            try self.render();
        },
        .resize => {
            self.gfx.updateWindowSize();
            try self.render();
        },
        .char => {
            try self.addBox();
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

    try self.pipeline.run(frame.pass);
}
