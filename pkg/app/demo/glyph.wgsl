@group(0) @binding(0) var<uniform> view_size: vec2f;
@group(0) @binding(1) var tex: texture_2d<f32>;
@group(0) @binding(2) var smp: sampler;
@group(0) @binding(3) var<uniform> texsize: vec2f;

struct VertexInput {
    @location(0) pos: vec2f,
    @location(1) uv: vec2f,
    @location(2) color: vec3f,
};

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f,
    @location(1) color: vec3f,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    out.pos = vec4f(
        (in.pos / view_size * 2) - 1,
        0.0,
        1.0
    );
    out.uv = vec2f(
        in.uv.x / texsize.x,
        1 - in.uv.y / texsize.y,
    );
    out.color = in.color;

    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    var alpha = textureSample(tex, smp, in.uv).r;
    if (alpha <= 0) { discard; }
    return vec4f(in.color, alpha);
}
