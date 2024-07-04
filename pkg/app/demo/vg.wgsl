// A partial port of the GL shader in nanovg
// TODO: apply some of the optimizations from
// https://programmer.group/nanovg-optimized-notes-the-secret-of-five-fold-performance-improvement.html

@group(0) @binding(0) var<uniform> view_size: vec2f;
@group(1) @binding(0) var<uniform> fargs: FragArgs;

struct VertexInput {
    @location(0) pos: vec2f,
    @location(1) uv: vec2f,
};

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) opos: vec2f,
    @location(1) uv: vec2f,
};

struct FragArgs {
    paint_mat: mat3x3<f32>,
    inner_col: vec4f,
    outer_col: vec4f,
    extent: vec2f,
    radius: f32,
    feather: f32,
    stroke_mult: f32,
    stroke_thr: f32,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.pos = vec4f(
        (in.pos / view_size * 2) - 1,
        0.0,
        1.0
    );
    out.opos = in.pos;
    out.uv = in.uv;
    return out;
}

fn sdroundrect(pt: vec2f, ext: vec2f, rad: f32) -> f32 {
    let ext2 = ext - vec2f(rad, rad);
    let d = abs(pt) - ext2;
    return min(max(d.x, d.y), 0.0) + length(d) - rad;
}

fn strokeMask(coord: vec2f, mult: f32) -> f32 {
    return min(1.0, (1.0 - abs(coord.x * 2.0 - 1.0)) * mult) * min(1.0, coord.y);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    let inner_color = vec4f(0, 1, 1, 1);
    let outer_color = vec4f(0, 1, 1, 1);

    let stroke_alpha = strokeMask(in.uv, fargs.stroke_mult);
    if (stroke_alpha < fargs.stroke_thr) { discard; }

    let pt = (fargs.paint_mat * vec3(in.opos, 1.0)).xy;
    let d = clamp((sdroundrect(pt, fargs.extent, fargs.radius) + fargs.feather * 0.5) / fargs.feather, 0.0, 1.0);

    var color = mix(inner_color, outer_color, d);
    color *= stroke_alpha;
    return color;
}
