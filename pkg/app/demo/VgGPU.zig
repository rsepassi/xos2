// gpu renderer for VgFrame

const std = @import("std");
const log = std.log.scoped(.vggpu);

const VgPipeline = @import("VgPipeline.zig");
const VgFrame = @import("VgFrame.zig");

const c = @cImport({
    @cInclude("nanovg.h");
});

const VgGpu = @This();
const Ctx = *c.NVGcontext;

ctx: Ctx,
pipeline: VgPipeline,
args: VgPipeline.Args,

pub fn init(self: *@This(), pipeline: VgPipeline) !void {
    const args = try pipeline.makeArgs();
    errdefer args.deinit();

    self.* = .{
        .ctx = undefined,
        .pipeline = pipeline,
        .args = args,
    };

    const params = c.NVGparams{
        .userPtr = self,
        .edgeAntiAlias = 1,
        .renderCreate = renderCreate,
        .renderCreateTexture = renderCreateTexture,
        .renderDeleteTexture = renderDeleteTexture,
        .renderUpdateTexture = renderUpdateTexture,
        .renderGetTextureSize = renderGetTextureSize,
        .renderViewport = renderViewport,
        .renderCancel = renderCancel,
        .renderFlush = renderFlush,
        .renderFill = renderFill,
        .renderStroke = renderStroke,
        .renderTriangles = renderTriangles,
        .renderDelete = renderDelete,
    };
    self.ctx = c.nvgCreateInternal(@constCast(&params)) orelse return error.nvgCreate;
}

pub fn deinit(self: *@This()) void {
    defer self.args.deinit();
    defer c.nvgDeleteInternal(self.ctx);
}

fn getSelf(uptr: ?*anyopaque) *@This() {
    return @ptrCast(@alignCast(uptr));
}

// Called from nvgBeginFrame
fn renderViewport(
    uptr: ?*anyopaque,
    width: f32,
    height: f32,
    devicePixelRatio: f32,
) callconv(.C) void {
    log.debug("vg frame start", .{});
    _ = width;
    _ = height;
    _ = devicePixelRatio;

    const self = getSelf(uptr);
    self.args.reset();
}

// Called from nvgEndFrame
fn renderFlush(uptr: ?*anyopaque) callconv(.C) void {
    log.debug("vg frame end", .{});
    const self = getSelf(uptr);
    _ = self;

    // TODO: batch instead of directly adding to self.args in
    // renderFill/renderStroke.
}

// Called from nvgFill
fn renderFill(
    uptr: ?*anyopaque,
    cpaint: ?*c.NVGpaint,
    compositeOperation: c.NVGcompositeOperationState,
    scissor: ?*c.NVGscissor,
    fringe: f32,
    cbounds: ?*const f32,
    cpaths: ?*const c.NVGpath,
    npaths: c_int,
) callconv(.C) void {
    log.debug("renderFill", .{});
    _ = scissor;
    _ = compositeOperation;

    const self = getSelf(uptr);

    const paint: *const VgFrame.Paint = @ptrCast(cpaint);
    const bounds: ?*const [4]f32 = if (cbounds == null) null else @ptrCast(cbounds);
    const paths = blk: {
        const p: [*]const c.NVGpath = @ptrCast(cpaths);
        break :blk p[0..@intCast(npaths)];
    };
    _ = bounds;

    var fill_type: enum { fill, convexfill } = .fill;
    var triangle_count: usize = 4;
    if (npaths == 1 and paths[0].convex > 0) {
        triangle_count = 0;
        fill_type = .convexfill;
    } else {
        // https://github.com/memononen/nanovg/blob/f93799c078fa11ed61c078c65a53914c8782c00b/src/nanovg_gl.h#L1356
        // https://github.com/memononen/nanovg/blob/f93799c078fa11ed61c078c65a53914c8782c00b/src/nanovg_gl.h#L1011
        @panic("fill unimplemented");
    }

    const max_vert = 256;
    var vertex_buf: [@sizeOf(VgPipeline.Vertex) * max_vert]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&vertex_buf);
    var vertex_list = std.ArrayList(VgPipeline.Vertex).init(fba.allocator());

    for (paths) |path| {
        // These are provided as triangle fans
        // We convert them to triangle strip format below
        const fills = blk: {
            const cfill: [*]VgPipeline.Vertex = @ptrCast(path.fill);
            const nfill: usize = @intCast(path.nfill);
            break :blk cfill[0..nfill];
        };

        const strokes = blk: {
            const cstrokes: [*]VgPipeline.Vertex = @ptrCast(path.stroke);
            const nstroke: usize = @intCast(path.nstroke);
            break :blk cstrokes[0..nstroke];
        };

        // Fill the initial triangle
        for (fills[0..3]) |f| vertex_list.append(f) catch @panic("oom");

        const anchor = fills[0];
        for (fills[3..]) |v| {
            // For subsequent entries, the intended triangle is a fan between
            // Anchor, V, and the previous vertex
            vertex_list.append(vertex_list.items[vertex_list.items.len - 1]) catch @panic("oom");
            vertex_list.append(anchor) catch @panic("oom");
            vertex_list.append(v) catch @panic("oom");
        }

        // Add degenerates between fills and strokes
        vertex_list.append(vertex_list.items[vertex_list.items.len - 1]) catch @panic("oom");
        vertex_list.append(strokes[0]) catch @panic("oom");

        // Add strokes
        vertex_list.appendSlice(strokes) catch @panic("oom");
    }

    const frag_args: VgPipeline.FragArgs = switch (fill_type) {
        .fill => @panic("fill unimplemented"),
        .convexfill => .{
            .inner_col = @bitCast(paint.inner_color.premul_alpha()),
            .outer_col = @bitCast(paint.outer_color.premul_alpha()),
            .stroke_mult = (fringe * 0.5 + fringe * 0.5) / fringe,
            .stroke_thr = -1,
            .radius = paint.radius,
            .feather = paint.feather,
            .extent = paint.extent,
            .paint_mat = .{ .vals = [3][3]f32{
                [3]f32{ 1, 0, 0 },
                [3]f32{ 0, 1, 0 },
                [3]f32{ 0, 0, 1 },
            } },
        },
    };

    self.args.add(vertex_list.items, frag_args);
}

// Called from nvgStroke
fn renderStroke(
    uptr: ?*anyopaque,
    cpaint: ?*c.NVGpaint,
    composite_op: c.NVGcompositeOperationState,
    scissor: ?*c.NVGscissor,
    fringe: f32,
    stroke_width: f32,
    cpaths: ?*const c.NVGpath,
    npaths: c_int,
) callconv(.C) void {
    log.debug("renderStroke", .{});
    _ = composite_op;
    _ = scissor;

    const self = getSelf(uptr);

    const paint: *const VgFrame.Paint = @ptrCast(cpaint.?);
    const paths = blk: {
        const p: [*]const c.NVGpath = @ptrCast(cpaths);
        break :blk p[0..@intCast(npaths)];
    };

    var vertices: [128]VgPipeline.Vertex = undefined;
    var nvert: usize = 0;
    for (paths) |path| {
        if (nvert >= 128) @panic("vertex overflow");

        const cstrokes: [*]VgPipeline.Vertex = @ptrCast(path.stroke);
        const nstroke: usize = @intCast(path.nstroke);
        const strokes = cstrokes[0..nstroke];
        @memcpy(vertices[nvert .. nvert + nstroke], strokes);
        nvert += nstroke;
    }

    const frag_args: VgPipeline.FragArgs = .{
        .inner_col = @bitCast(paint.inner_color.premul_alpha()),
        .outer_col = @bitCast(paint.outer_color.premul_alpha()),
        .stroke_mult = (stroke_width * 0.5 + fringe * 0.5) / fringe,
        .stroke_thr = -1,
        .radius = paint.radius,
        .feather = paint.feather,
        .extent = paint.extent,
        .paint_mat = .{ .vals = [3][3]f32{
            [3]f32{ 1, 0, 0 },
            [3]f32{ 0, 1, 0 },
            [3]f32{ 0, 0, 1 },
        } },
    };

    const draw_vertices = vertices[0..nvert];
    self.args.add(draw_vertices, frag_args);
}

// ============================================================================
// UNUSED
// ============================================================================

// int (*renderCreateTexture)(void* uptr, int type, int w, int h, int imageFlags, const unsigned char* data);
fn renderCreateTexture(
    uptr: ?*anyopaque,
    ctype: c_int,
    w: c_int,
    h: c_int,
    imageFlags: c_int,
    data: ?*const u8,
) callconv(.C) c_int {
    _ = uptr;
    _ = ctype;
    _ = w;
    _ = h;
    _ = imageFlags;
    _ = data;
    return 1;
}

// int (*renderDeleteTexture)(void* uptr, int image);
fn renderDeleteTexture(uptr: ?*anyopaque, image: c_int) callconv(.C) c_int {
    _ = uptr;
    _ = image;
    return 1;
}

// int (*renderUpdateTexture)(void* uptr, int image, int x, int y, int w, int h, const unsigned char* data);
fn renderUpdateTexture(
    uptr: ?*anyopaque,
    image: c_int,
    x: c_int,
    y: c_int,
    w: c_int,
    h: c_int,
    data: ?*const u8,
) callconv(.C) c_int {
    _ = uptr;

    _ = image;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    _ = data;
    return 1;
}

// int (*renderGetTextureSize)(void* uptr, int image, int* w, int* h);
fn renderGetTextureSize(
    uptr: ?*anyopaque,
    image: c_int,
    w: ?*c_int,
    h: ?*c_int,
) callconv(.C) c_int {
    _ = uptr;
    _ = image;
    _ = w;
    _ = h;
    return 1;
}

// void (*renderTriangles)(void* uptr, NVGpaint* paint, NVGcompositeOperationState compositeOperation, NVGscissor* scissor, const NVGvertex* verts, int nverts, float fringe);
fn renderTriangles(
    uptr: ?*anyopaque,
    paint: ?*c.NVGpaint,
    compositeOperation: c.NVGcompositeOperationState,
    scissor: ?*c.NVGscissor,
    verts: ?*const c.NVGvertex,
    nverts: c_int,
    fringe: f32,
) callconv(.C) void {
    _ = uptr;
    _ = paint;
    _ = compositeOperation;
    _ = scissor;
    _ = verts;
    _ = nverts;
    _ = fringe;
}

// void (*renderCancel)(void* uptr);
fn renderCancel(uptr: ?*anyopaque) callconv(.C) void {
    _ = uptr;
}

// int (*renderCreate)(void* uptr);
fn renderCreate(uptr: ?*anyopaque) callconv(.C) c_int {
    _ = uptr;
    return 1;
}

// void (*renderDelete)(void* uptr);
fn renderDelete(uptr: ?*anyopaque) callconv(.C) void {
    _ = uptr;
}
