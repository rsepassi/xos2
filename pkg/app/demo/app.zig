const std = @import("std");

const app = @import("app");
const gpu = @import("gpu");
const appgpu = @import("appgpu");
const twod = @import("twod");

const dummydata = @import("data.zig");
const text = @import("text.zig");

const DemoPipeline = @import("DemoPipeline.zig");
const ImagePipeline = @import("ImagePipeline.zig");
const SpritePipeline = @import("SpritePipeline.zig");
const GlyphPipeline = @import("GlyphPipeline.zig");
const VgPipeline = @import("VgPipeline.zig");
const VgGPU = @import("VgGPU.zig");
const VgFrame = @import("VgFrame.zig");

pub const std_options = .{
    .log_level = .debug,
};
const log = std.log.scoped(.app);

pub const App = @This();

pub const PipelineCtx = struct {
    gfx: appgpu.Gfx,
    allocator: std.mem.Allocator,
};

// App
appctx: *app.Ctx,
// Graphics
pipectx: PipelineCtx,
demo_pipeline: DemoPipeline,
image_pipeline: ImagePipeline,
sprite_pipeline: SpritePipeline,
glyph_pipeline: GlyphPipeline,
vg_pipeline: VgPipeline,
// Graphics arguments
vg_backend: VgGPU,
// Text
ft: text.FreeType,
font: text.Font,
atlas: text.FontAtlas,

pub fn appConfig() app.Config {
    return .{
        .window_title = "Hello",
        .window_size = .{ 640, 480 },
    };
}

pub fn init(self: *App, appctx: *app.Ctx) !void {
    const allocator = appctx.allocator();

    const gfx = try appgpu.defaultGfx(appctx);
    errdefer gfx.deinit();

    const pipectx = PipelineCtx{
        .gfx = gfx,
        .allocator = allocator,
    };

    log.debug("DemoPipeline", .{});
    const demo_pipeline = try DemoPipeline.init(pipectx);
    errdefer demo_pipeline.deinit();

    log.debug("ImagePipeline", .{});
    const image_pipeline = try ImagePipeline.init(pipectx);
    errdefer image_pipeline.deinit();

    log.debug("SpritePipeline", .{});
    const sprite_pipeline = try SpritePipeline.init(pipectx);
    errdefer sprite_pipeline.deinit();

    log.debug("GlyphPipeline", .{});
    const glyph_pipeline = try GlyphPipeline.init(pipectx);
    errdefer glyph_pipeline.deinit();

    log.debug("VgPipeline", .{});
    const vg_pipeline = try VgPipeline.init(pipectx);
    errdefer self.vg_pipeline.deinit();

    log.debug("VgBackend", .{});
    try self.vg_backend.init(vg_pipeline);
    errdefer self.vg_backend.deinit();

    log.debug("FreeType", .{});
    const ft = try text.FreeType.init();
    errdefer ft.deinit();

    // TODO: re-enable
    // const resources = appctx.resources().?;
    // var font_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    // const font_path = try resources.dir.realpath("CourierPrime-Regular.ttf", &font_path_buf);
    // font_path_buf[font_path.len] = 0;

    // const font = try ft.font(.{
    //     .path = @ptrCast(font_path),
    //     .pxsize = 40,
    // });
    // errdefer font.deinit();
    // log.debug("ascii atlas", .{});
    // const atlas = try text.buildAsciiAtlas(allocator, font);
    // errdefer atlas.deinit();

    self.* = .{
        .appctx = appctx,
        .pipectx = pipectx,
        .demo_pipeline = demo_pipeline,
        .image_pipeline = image_pipeline,
        .sprite_pipeline = sprite_pipeline,
        .glyph_pipeline = glyph_pipeline,
        .vg_pipeline = vg_pipeline,
        .vg_backend = self.vg_backend,
        .ft = ft,
        // TODO: re-enable
        // .font = font,
        // .atlas = atlas,
        .font = undefined,
        .atlas = undefined,
    };
}

pub fn deinit(self: *App) void {
    defer self.pipectx.gfx.deinit();
    defer self.demo_pipeline.deinit();
    defer self.image_pipeline.deinit();
    defer self.sprite_pipeline.deinit();
    defer self.glyph_pipeline.deinit();
    defer self.vg_pipeline.deinit();
    defer self.vg_backend.deinit();
    defer self.ft.deinit();
    defer self.font.deinit();
    defer self.atlas.deinit();
}

pub fn onEvent(self: *App, event: app.Event) !void {
    switch (event) {
        .start => {
            try self.render();
        },
        .resize => {
            self.pipectx.gfx.updateWindowSize();
            try self.render();
        },
        .char,
        => {},
    }
}

fn render(self: *App) !void {
    log.debug("-- render", .{});

    log.debug("imageA", .{});
    const imageA = dummydata.getImageData(.a);
    const pipeline_imageA = try ImagePipeline.PipelineImage.init(self.pipectx.gfx, imageA.size);
    defer pipeline_imageA.deinit();
    pipeline_imageA.writeImage(imageA);
    pipeline_imageA.writePos(.{ .x = 0, .y = imageA.size.height });
    const image_argsA = self.image_pipeline.makeArgs(pipeline_imageA);
    defer image_argsA.deinit();

    log.debug("imageB", .{});
    const imageB = dummydata.getImageData(.b);
    const pipeline_imageB = try ImagePipeline.PipelineImage.init(self.pipectx.gfx, imageB.size);
    defer pipeline_imageB.deinit();
    pipeline_imageB.writeImage(imageB);
    pipeline_imageB.writePos(.{ .x = 256, .y = imageB.size.height });
    const image_argsB = self.image_pipeline.makeArgs(pipeline_imageB);
    defer image_argsB.deinit();

    log.debug("spritesheet", .{});
    const spritesheet = dummydata.getSpriteSheet();
    const pipeline_spritesheet = try SpritePipeline.SpriteSheet.init(self.pipectx.gfx, spritesheet);
    defer pipeline_spritesheet.deinit();
    var sprite_locs = try SpritePipeline.SpriteLocs.init(self.pipectx, 100);
    defer sprite_locs.deinit();
    {
        const box = twod.Rect.fromSize(.{ .width = 100, .height = 100 });
        try sprite_locs.write(&.{
            .{ .pos = box, .uv = box },
            .{ .pos = box.up(100), .uv = box.right(200) },
        });
    }
    const sprite_args = self.sprite_pipeline.makeArgs(pipeline_spritesheet, &sprite_locs);
    defer sprite_args.deinit();

    // TODO: re-enable
    // log.debug("glyphs", .{});
    // const pipeline_atlas = try GlyphPipeline.Atlas.init(self.pipectx.gfx, .{ .data = self.atlas.data, .size = self.atlas.size });
    // defer pipeline_atlas.deinit();
    // var glyph_locs = try GlyphPipeline.GlyphLocs.init(self.pipectx, 100);
    // defer glyph_locs.deinit();
    // {
    //     const colors = twod.color(twod.RGBf);
    //     const xinfo = self.atlas.info.get(self.font.glyphIdx('x')).?;
    //     const xbox = xinfo.quad;
    //     const abox = self.atlas.info.get(self.font.glyphIdx('a')).?.quad;
    //     const box = twod.Rect.fromSize(xbox.size());

    //     try glyph_locs.write(&.{
    //         .{ .pos = box, .uv = xbox, .color = colors.green() },
    //         .{ .pos = box.right(@floatFromInt(xinfo.info.advance_width)), .uv = abox, .color = colors.red() },
    //     });
    // }
    // const glyph_args = self.glyph_pipeline.makeArgs(pipeline_atlas, &glyph_locs);
    // defer glyph_args.deinit();

    log.debug("vg", .{});

    {
        var frame = VgFrame.init(self.vg_backend.ctx);
        defer frame.deinit();

        {
            frame.beginPath();
            defer frame.closePath();
            frame.roundedRect(250, 250, 100, 40, 5);
            frame.fillColor(.{ .r = 0, .g = 1, .b = 0, .a = 1 });
            frame.fill();
        }

        {
            frame.beginPath();
            defer frame.closePath();
            frame.circle(200, 200, 20);
            frame.fillColor(.{ .r = 0, .g = 0, .b = 1, .a = 1 });
            frame.fill();
        }

        {
            frame.beginPath();
            defer frame.closePath();
            frame.lineCap(.Round);
            frame.moveTo(10, 50);
            frame.lineTo(120, 120);
            frame.strokeColor(.{ .r = 0, .g = 0, .b = 1.0, .a = 1.0 });
            frame.strokeWidth(5);
            frame.stroke();
        }
    }

    log.debug("gfx.render", .{});
    const Run = appgpu.Gfx.PipelineRun;
    try self.pipectx.gfx.render(.{
        .load = .{ .Clear = .{
            .r = 0.05,
            .g = 0.05,
            .b = 0.05,
            .a = 1,
        } },
        .piperuns = &.{
            Run.init(&self.demo_pipeline, &void{}, DemoPipeline.run),
            Run.init(&self.image_pipeline, &image_argsA, ImagePipeline.run),
            Run.init(&self.image_pipeline, &image_argsB, ImagePipeline.run),
            Run.init(&self.sprite_pipeline, &sprite_args, SpritePipeline.run),
            // TODO: re-enable
            // Run.init(&self.glyph_pipeline, &glyph_args, GlyphPipeline.run),
            Run.init(&self.vg_pipeline, &self.vg_backend.args, VgPipeline.run),
        },
    });
    log.debug("-- render done", .{});
}
