@group(0) @binding(0) var<uniform> view_size: vec2f;

struct VertexInput {
    @location(0) pos: vec2f,
    @location(1) color: vec3f,
};

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) color: vec3f,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.pos = vec4f(
        (in.pos / view_size * 2) - 1,
        0.0,
        1.0
    );
    out.color = in.color;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    return vec4f(in.color, 1.0);
}
