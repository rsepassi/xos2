@group(0) @binding(0) var<uniform> view_size: vec2f;
@group(0) @binding(1) var image_texture: texture_2d<f32>;
@group(0) @binding(2) var texture_sampler: sampler;

struct VertexInput {
    @location(0) pos: vec2f,
    @builtin(vertex_index) i: u32,
};

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    out.pos = vec4f(
        (in.pos / view_size * 2) - 1,
        0.0,
        1.0
    );

    var uvs = array<vec2f, 6>(
        vec2f(0.0, 1.0),  // bl
        vec2f(1.0, 1.0),  // br
        vec2f(0.0, 0.0),  // tl
        vec2f(0.0, 0.0),  // tl
        vec2f(1.0, 1.0),  // br
        vec2f(1.0, 0.0)   // tr
    );
    out.uv = uvs[in.i];

    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    var color = textureSample(image_texture, texture_sampler, in.uv);

    // Gamma correction, if needed
    // gamma or 1/gamma depending on which correction is needed
    let gamma: f32 = 2.2;
    color = vec4f(pow(color.rgb, vec3f(gamma)), color.a);

    return color;
}
