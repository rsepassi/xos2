// Images

const std = @import("std");
const log = std.log.scoped(.app);

const app = @import("app");
const appgpu = @import("appgpu");
const twod = @import("twod");

const stb_image = struct {
    const c = @cImport(@cInclude("stb_image.h"));

    fn load(data: []const u8) !twod.Image {
        var x: c_int = 0;
        var y: c_int = 0;
        var chan: c_int = 0;
        const d = c.stbi_load_from_memory(
            data.ptr,
            @intCast(data.len),
            &x,
            &y,
            &chan,
            4,
        ) orelse return error.ImageLoad;
        var dr: [*]twod.RGBA = @ptrCast(d);

        const nrow: usize = @intCast(y);
        const ncol: usize = @intCast(x);

        return twod.Image{
            .data = @ptrCast(dr[0 .. ncol * nrow]),
            .size = .{
                .width = @floatFromInt(x),
                .height = @floatFromInt(y),
            },
        };
    }
};

const ImagePipeline = @import("ImagePipeline.zig");

pub const App = @This();
pub const std_options = .{
    .log_level = .info,
};

appctx: *app.Ctx,
gfx: appgpu.Gfx,
pipeline: ImagePipeline,
images: [2]ImagePipeline.Image,
pipe_args: [2]ImagePipeline.Args,

img_idx: usize = 0,

pub fn init(self: *App, appctx: *app.Ctx) !void {
    const gfx = try appgpu.defaultGfx(appctx);
    errdefer gfx.deinit();

    const pipeline = try ImagePipeline.init(gfx);
    errdefer pipeline.deinit();

    const allocator = appctx.allocator();
    const jpg_data = try appctx.resources().?.dir.readFileAlloc(allocator, "coast.jpg", 2 << 20);
    defer allocator.free(jpg_data);
    const jpg = try stb_image.load(jpg_data);
    defer std.heap.c_allocator.free(jpg.data);

    const png_data = try appctx.resources().?.dir.readFileAlloc(allocator, "fleur.png", 2 << 20);
    defer allocator.free(png_data);
    const png = try stb_image.load(png_data);
    defer std.heap.c_allocator.free(png.data);

    const wsize = appctx.getWindowSize();

    const pipe_img1 = try ImagePipeline.Image.init(gfx, jpg.size);
    pipe_img1.writeImage(jpg);
    pipe_img1.writePos(.{ .x = 0, .y = @floatFromInt(wsize.height) });
    const pipe_img2 = try ImagePipeline.Image.init(gfx, png.size);
    pipe_img2.writeImage(png);
    pipe_img2.writePos(.{ .x = 0, .y = @floatFromInt(wsize.height) });

    const args1 = pipeline.makeArgs(pipe_img1);
    const args2 = pipeline.makeArgs(pipe_img2);

    self.* = .{
        .appctx = appctx,
        .gfx = gfx,
        .pipeline = pipeline,
        .images = .{ pipe_img1, pipe_img2 },
        .pipe_args = .{ args1, args2 },
    };
}

pub fn deinit(self: *App) void {
    defer self.gfx.deinit();
    defer self.pipeline.deinit();
    defer for (self.images) |i| i.deinit();
    defer for (self.pipe_args) |i| i.deinit();
}

pub fn onEvent(self: *App, event: app.Event) !void {
    switch (event) {
        .start => {
            try self.render();
        },
        .resize => {
            self.gfx.updateWindowSize();
            try self.render();
        },
        .char => {
            self.img_idx = if (self.img_idx == 1) 0 else 1;
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

    try self.pipeline.run(frame.pass, self.pipe_args[self.img_idx]);
}
