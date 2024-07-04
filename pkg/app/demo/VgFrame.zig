const log = @import("std").log.scoped(.vgframe);
const twod = @import("twod");
const c = @cImport({
    @cInclude("nanovg.h");
});

pub const Point = twod.Point;

pub const Transform = extern struct {
    els: [6]f32,
};

pub const Winding = enum(c_int) {
    CCW = 1,
    CW = 2,
};

pub const Solidity = enum(c_int) {
    Solid = 1,
    Hole = 2,
};

pub const LineCap = enum(c_int) {
    Butt,
    Round,
    Square,
};

pub const LineJoin = enum(c_int) {
    Round = c.NVG_ROUND,
    Bevel = c.NVG_BEVEL,
    Miter = c.NVG_MITER,
};

pub const Color = twod.RGBAf;
pub const Paint = extern struct {
    xform: [6]f32,
    extent: [2]f32,
    radius: f32,
    feather: f32,
    inner_color: Color,
    outer_color: Color,
    unused_image: i32,
};

const Ctx = *c.NVGcontext;

ctx: Ctx,

pub fn init(ctx: Ctx) @This() {
    c.nvgBeginFrame(ctx, 1.0, 1.0, 1.0);
    return .{ .ctx = ctx };
}

pub fn deinit(self: @This()) void {
    c.nvgEndFrame(self.ctx);
}

pub fn save(self: @This()) void {
    c.nvgSave(self.ctx);
}

pub fn restore(self: @This()) void {
    c.nvgRestore(self.ctx);
}

pub fn reset(self: @This()) void {
    c.nvgReset(self.ctx);
}

pub fn shapeAntiAlias(self: @This(), enabled: bool) void {
    c.nvgShapeAntiAlias(self.ctx, @intFromBool(enabled));
}

pub fn strokeColor(self: @This(), color: Color) void {
    c.nvgStrokeColor(self.ctx, @bitCast(color));
}

pub fn fillColor(self: @This(), color: Color) void {
    c.nvgFillColor(self.ctx, @bitCast(color));
}

pub fn strokePaint(self: @This(), paint: Paint) void {
    c.nvgStrokePaint(self.ctx, @bitCast(paint));
}

pub fn fillPaint(self: @This(), paint: Paint) void {
    c.nvgFillPaint(self.ctx, @bitCast(paint));
}

pub fn miterLimit(self: @This(), limit: f32) void {
    c.nvgMiterLimit(self.ctx, limit);
}

pub fn strokeWidth(self: @This(), width: f32) void {
    c.nvgStrokeWidth(self.ctx, width);
}

pub fn lineCap(self: @This(), cap: LineCap) void {
    c.nvgLineCap(self.ctx, @intFromEnum(cap));
}

pub fn lineJoin(self: @This(), join: LineJoin) void {
    c.nvgLineJoin(self.ctx, @intFromEnum(join));
}

pub fn globalAlpha(self: @This(), alpha: f32) void {
    c.nvgGlobalAlpha(self.ctx, alpha);
}

pub fn resetTransform(self: @This()) void {
    c.nvgResetTransform(self.ctx);
}

pub fn setTransform(self: @This(), xform: Transform) void {
    c.nvgTransform(
        self.ctx,
        xform.els[0],
        xform.els[1],
        xform.els[2],
        xform.els[3],
        xform.els[4],
        xform.els[5],
    );
}

pub fn currentTransform(self: @This()) Transform {
    var dst: Transform = undefined;
    c.nvgCurrentTransform(self.ctx, &dst.els);
    return dst;
}

pub fn translate(self: @This(), x: f32, y: f32) void {
    c.nvgTranslate(self.ctx, x, y);
}

pub fn rotate(self: @This(), angle: f32) void {
    c.nvgRotate(self.ctx, angle);
}

pub fn skewX(self: @This(), angle: f32) void {
    c.nvgSkewX(self.ctx, angle);
}

pub fn skewY(self: @This(), angle: f32) void {
    c.nvgSkewY(self.ctx, angle);
}

pub fn scale(self: @This(), x: f32, y: f32) void {
    c.nvgScale(self.ctx, x, y);
}

pub fn beginPath(self: @This()) void {
    c.nvgBeginPath(self.ctx);
}

pub fn closePath(self: @This()) void {
    c.nvgClosePath(self.ctx);
}

pub fn moveTo(self: @This(), x: f32, y: f32) void {
    c.nvgMoveTo(self.ctx, x, y);
}

pub fn lineTo(self: @This(), x: f32, y: f32) void {
    c.nvgLineTo(self.ctx, x, y);
}

pub fn bezierTo(self: @This(), c1x: f32, c1y: f32, c2x: f32, c2y: f32, x: f32, y: f32) void {
    c.nvgBezierTo(self.ctx, c1x, c1y, c2x, c2y, x, y);
}

pub fn quadTo(self: @This(), cx: f32, cy: f32, x: f32, y: f32) void {
    c.nvgQuadTo(self.ctx, cx, cy, x, y);
}

pub fn arcTo(self: @This(), x1: f32, y1: f32, x2: f32, y2: f32, radius: f32) void {
    c.nvgArcTo(self.ctx, x1, y1, x2, y2, radius);
}

pub fn pathWinding(self: @This(), dir: Winding) void {
    c.nvgPathWinding(self.ctx, @intFromEnum(dir));
}

pub fn arc(self: @This(), cx: f32, cy: f32, r: f32, a0: f32, a1: f32, dir: Winding) void {
    c.nvgArc(self.ctx, cx, cy, r, a0, a1, @intFromEnum(dir));
}

pub fn rect(self: @This(), x: f32, y: f32, w: f32, h: f32) void {
    c.nvgRect(self.ctx, x, y, w, h);
}

pub fn roundedRect(self: @This(), x: f32, y: f32, w: f32, h: f32, r: f32) void {
    c.nvgRoundedRect(self.ctx, x, y, w, h, r);
}

pub fn roundedRectVarying(self: @This(), x: f32, y: f32, w: f32, h: f32, radTopLeft: f32, radTopRight: f32, radBottomRight: f32, radBottomLeft: f32) void {
    c.nvgRoundedRectVarying(self.ctx, x, y, w, h, radTopLeft, radTopRight, radBottomRight, radBottomLeft);
}

pub fn ellipse(self: @This(), cx: f32, cy: f32, rx: f32, ry: f32) void {
    c.nvgEllipse(self.ctx, cx, cy, rx, ry);
}

pub fn circle(self: @This(), cx: f32, cy: f32, r: f32) void {
    c.nvgCircle(self.ctx, cx, cy, r);
}

pub fn fill(self: @This()) void {
    c.nvgFill(self.ctx);
}

pub fn stroke(self: @This()) void {
    c.nvgStroke(self.ctx);
}

pub fn linearGradient(self: @This(), sx: f32, sy: f32, ex: f32, ey: f32, icol: Color, ocol: Color) Paint {
    const paint = c.nvgLinearGradient(self.ctx, sx, sy, ex, ey, @bitCast(icol), @bitCast(ocol));
    return @bitCast(paint);
}

pub fn boxGradient(self: @This(), x: f32, y: f32, w: f32, h: f32, r: f32, f: f32, icol: Color, ocol: Color) Paint {
    const paint = c.nvgBoxGradient(self.ctx, x, y, w, h, r, f, @bitCast(icol), @bitCast(ocol));
    return @bitCast(paint);
}

pub fn radialGradient(self: @This(), cx: f32, cy: f32, inr: f32, outr: f32, icol: Color, ocol: Color) Paint {
    const paint = c.nvgRadialGradient(self.ctx, cx, cy, inr, outr, @bitCast(icol), @bitCast(ocol));
    return @bitCast(paint);
}

pub fn transformIdentity(self: @This()) Transform {
    _ = self;
    var dst: Transform = undefined;
    c.nvgTransformIdentity(&dst.els);
    return dst;
}

pub fn transformTranslate(self: @This(), tx: f32, ty: f32) Transform {
    _ = self;
    var dst: Transform = undefined;
    c.nvgTransformTranslate(&dst.els, tx, ty);
    return dst;
}

pub fn transformScale(self: @This(), sx: f32, sy: f32) Transform {
    _ = self;
    var dst: Transform = undefined;
    c.nvgTransformScale(&dst.els, sx, sy);
    return dst;
}

pub fn transformRotate(self: @This(), a: f32) Transform {
    _ = self;
    var dst: Transform = undefined;
    c.nvgTransformRotate(&dst.els, a);
    return dst;
}

pub fn transformSkewX(self: @This(), a: f32) Transform {
    _ = self;
    var dst: Transform = undefined;
    c.nvgTransformSkewX(&dst.els, a);
    return dst;
}

pub fn transformSkewY(self: @This(), a: f32) Transform {
    _ = self;
    var dst: Transform = undefined;
    c.nvgTransformSkewY(&dst.els, a);
    return dst;
}

pub fn transformMultiply(self: @This(), src: Transform) Transform {
    _ = self;
    var dst: Transform = undefined;
    c.nvgTransformMultiply(&dst.els, &src.els);
    return dst;
}

pub fn transformPremultiply(self: @This(), src: Transform) Transform {
    _ = self;
    var dst: Transform = undefined;
    c.nvgTransformPremultiply(&dst.els, &src.els);
    return dst;
}

pub fn transformInverse(self: @This(), src: Transform) !Transform {
    _ = self;
    var dst: Transform = undefined;
    if (c.nvgTransformInverse(&dst.els, &src.els) != 0) {
        return dst;
    } else {
        return error.NoInverse;
    }
}

pub fn transformPoint(self: @This(), xform: Transform, src: Point) Point {
    _ = self;
    var dstx: f32 = 0;
    var dsty: f32 = 0;
    c.nvgTransformPoint(&dstx, &dsty, &xform.els, src.x, src.y);
    return .{ .x = dstx, .y = dsty };
}
