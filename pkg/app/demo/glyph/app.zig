// Glyphs

const std = @import("std");
const log = std.log.scoped(.app);

const app = @import("app");
const appgpu = @import("appgpu");
const twod = @import("twod");

const text = @import("text.zig");
const GlyphPipeline = @import("GlyphPipeline.zig");

pub const App = @This();
pub const std_options = .{
    .log_level = .info,
};

const padding: f32 = 10;

appctx: *app.Ctx,
gfx: appgpu.Gfx,
pipeline: GlyphPipeline,
pipeline_args: GlyphPipeline.Args,
glocs: GlyphPipeline.GlyphLocs,
ft: text.FreeType,
font: text.Font,
atlas: text.FontAtlas,
pipeline_atlas: GlyphPipeline.Atlas,

cursor: twod.Point,

pub fn init(self: *App, appctx: *app.Ctx) !void {
    const gfx = try appgpu.defaultGfx(appctx);
    errdefer gfx.deinit();

    const pipeline = try GlyphPipeline.init(gfx);
    errdefer pipeline.deinit();

    const ft = try text.FreeType.init();
    errdefer ft.deinit();

    var font_path_buf: [std.fs.MAX_PATH_BYTES:0]u8 = undefined;
    const font_path = try appctx.resources().?.dir.realpath("CourierPrime-Regular.ttf", &font_path_buf);
    font_path_buf[font_path.len] = 0;

    const font = try ft.font(.{
        .path = font_path_buf[0..font_path.len :0],
        .pxsize = 24,
    });
    errdefer font.deinit();

    var atlas = try text.buildAsciiAtlas(appctx.allocator(), font);
    errdefer atlas.deinit();

    const glocs = try GlyphPipeline.GlyphLocs.init(gfx, appctx.allocator(), 1024);
    errdefer glocs.deinit();

    const pipeline_atlas = try GlyphPipeline.Atlas.init(gfx, .{
        .data = atlas.data,
        .size = atlas.size,
    });
    errdefer pipeline_atlas.deinit();

    const pipeline_args = pipeline.makeArgs(pipeline_atlas, &self.glocs);
    errdefer pipeline_args.deinit();

    const wsize = appctx.getWindowSize();
    const cursor = .{ .x = padding, .y = @as(f32, @floatFromInt(wsize.height - font.linegap())) - padding };

    self.* = .{
        .appctx = appctx,
        .gfx = gfx,
        .ft = ft,
        .font = font,
        .atlas = atlas,
        .pipeline = pipeline,
        .glocs = glocs,
        .pipeline_atlas = pipeline_atlas,
        .pipeline_args = pipeline_args,
        .cursor = cursor,
    };
}

pub fn deinit(self: *App) void {
    defer self.gfx.deinit();
    defer self.pipeline.deinit();
    defer self.pipeline_args.deinit();
    defer self.glocs.deinit();
    defer self.ft.deinit();
    defer self.font.deinit();
    defer self.atlas.deinit();
    defer self.pipeline_atlas.deinit();
}

fn addGlyph(self: *App, c: usize) !void {
    const info = self.atlas.info.get(self.font.glyphIdx(c)).?;
    const uv = info.quad;

    const line_edge = self.appctx.getWindowSize().width - @as(u32, @intFromFloat(padding));
    const char_edge = self.cursor.x + @as(f32, @floatFromInt(info.info.horiBearingX)) + uv.width();
    if (char_edge > @as(f32, @floatFromInt(line_edge))) {
        self.cursor = .{ .x = padding, .y = self.cursor.y - @as(f32, @floatFromInt(self.font.linegap())) };
    }

    // https://freetype.org/freetype2/docs/glyphs/glyphs-3.html
    const box = twod.Rect.fromSize(uv.size())
        .right(self.cursor.x)
        .up(self.cursor.y)
        .right(@floatFromInt(info.info.horiBearingX))
        .down(uv.height() - @as(f32, @floatFromInt(info.info.horiBearingY)));

    const advance = if (c == ' ') self.atlas.info.get(self.font.glyphIdx('m')).?.info.advance_width else info.info.advance_width;
    self.cursor = self.cursor.right(@floatFromInt(advance));

    const colors = twod.color(twod.RGBf);
    try self.glocs.add(&.{
        .{ .pos = box, .uv = uv, .color = colors.black() },
    });
}

pub fn onEvent(self: *App, event: app.Event) !void {
    switch (event) {
        .start => {
            try self.addGlyph('>');
            try self.addGlyph(' ');
            try self.render();
        },
        .resize => {
            self.gfx.updateWindowSize();
            try self.render();
        },
        .char => |c| {
            log.info("char {c}", .{@as(u8, @intCast(c))});
            try self.addGlyph(c);
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

    try self.pipeline.run(frame.pass, self.pipeline_args);
}
