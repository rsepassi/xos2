const std = @import("std");
const app = @import("app");
const myapp = @import("app.zig");
const twod = @import("twod");
const gpu = @import("gpu");
const VgPipeline = @This();

const log = std.log.scoped(.vg_pipeline);

ctx: myapp.PipelineCtx,
bind_layout0: gpu.BindGroup.Layout,
bind_layout1: gpu.BindGroup.Layout,
pipeline: gpu.RenderPipeline,

pub const Vertex = extern struct {
    const vec2f = [2]f32;
    pos: vec2f,
    uv: vec2f,
};

// Must respect webgpu alignment
// https://www.w3.org/TR/WGSL/#alignment-and-size
pub const FragArgs = extern struct {
    const expected_size = 112;
    const vec2f = [2]f32;
    const vec4f = [4]f32;
    const mat3x3f = extern struct {
        vals: [3][3]f32,
        pad: [12]u8 = undefined,
    };

    paint_mat: mat3x3f,
    inner_col: vec4f,
    outer_col: vec4f,
    extent: vec2f,
    radius: f32,
    feather: f32,
    stroke_mult: f32,
    stroke_thr: f32,
    pad: [8]u8 = undefined,
};

// deviceLimits.minUniformBufferOffsetAlignment=256
const frag_arg_stride = @max(256, @sizeOf(FragArgs));

comptime {
    if (@sizeOf(FragArgs) != FragArgs.expected_size) @compileError("bad FragArgs");
}

pub fn init(ctx: myapp.PipelineCtx) !@This() {
    const device = ctx.gfx.device;

    const wgsl = @embedFile("vg.wgsl");
    const shader = try device.createShaderModule("vg", .{ .wgsl = wgsl });
    defer shader.deinit();

    const bind_layout0 = device.createBindGroupLayout(&.{
        .entryCount = 1,
        .entries = &[_]gpu.c.WGPUBindGroupLayoutEntry{
            // screen size
            .{
                .binding = 0,
                .visibility = @intFromEnum(gpu.ShaderStage.Vertex),
                .buffer = .{
                    .type = @intFromEnum(gpu.BufferBindingType.Uniform),
                    .minBindingSize = @sizeOf(twod.Size),
                },
            },
        },
    });

    const bind_layout1 = device.createBindGroupLayout(&.{
        .entryCount = 1,
        .entries = &[_]gpu.c.WGPUBindGroupLayoutEntry{
            // FragArgs
            .{
                .binding = 0,
                .visibility = @intFromEnum(gpu.ShaderStage.Fragment),
                .buffer = .{
                    .type = @intFromEnum(gpu.BufferBindingType.Uniform),
                    .minBindingSize = @sizeOf(FragArgs),
                    .hasDynamicOffset = 1,
                },
            },
        },
    });

    const pipeline_layout = try device.createPipelineLayout(&.{
        .bindGroupLayoutCount = 2,
        .bindGroupLayouts = &[_]gpu.c.WGPUBindGroupLayout{
            bind_layout0.ptr,
            bind_layout1.ptr,
        },
    });
    defer pipeline_layout.deinit();

    const vg_pipeline = try device.createRenderPipeline(&.{
        .label = "vg_pipeline",
        .layout = pipeline_layout.ptr,
        .vertex = .{
            .module = shader.ptr,
            .entryPoint = "vs_main",
            .bufferCount = 1,
            .buffers = &.{
                .arrayStride = @sizeOf(Vertex),
                .stepMode = @intFromEnum(gpu.VertexStepMode.Vertex),
                .attributeCount = 2,
                .attributes = &[_]gpu.c.WGPUVertexAttribute{
                    .{
                        .format = @intFromEnum(gpu.VertexFormat.Float32x2),
                        .shaderLocation = 0,
                        .offset = @offsetOf(Vertex, "pos"),
                    },
                    .{
                        .format = @intFromEnum(gpu.VertexFormat.Float32x2),
                        .shaderLocation = 1,
                        .offset = @offsetOf(Vertex, "uv"),
                    },
                },
            },
        },
        .fragment = &.{
            .module = shader.ptr,
            .entryPoint = "fs_main",
            .targetCount = 1,
            .targets = &.{
                .format = ctx.gfx.surface_config.format,
                .blend = &.{
                    .color = .{
                        .operation = @intFromEnum(gpu.BlendOperation.Add),
                        .srcFactor = @intFromEnum(gpu.BlendFactor.SrcAlpha),
                        .dstFactor = @intFromEnum(gpu.BlendFactor.OneMinusSrcAlpha),
                    },
                    .alpha = .{
                        .operation = @intFromEnum(gpu.BlendOperation.Add),
                        .srcFactor = @intFromEnum(gpu.BlendFactor.Zero),
                        .dstFactor = @intFromEnum(gpu.BlendFactor.One),
                    },
                },
                .writeMask = @intFromEnum(gpu.ColorWriteMask.All),
            },
        },
        .primitive = .{
            .topology = @intFromEnum(gpu.PrimitiveTopology.TriangleStrip),
            .stripIndexFormat = @intFromEnum(gpu.IndexFormat.Undefined),
        },
        .multisample = .{
            .count = 1,
            .mask = 0xFFFFFFFF,
            .alphaToCoverageEnabled = 0,
        },
    });
    return .{
        .ctx = ctx,
        .bind_layout0 = bind_layout0,
        .bind_layout1 = bind_layout1,
        .pipeline = vg_pipeline,
    };
}

pub fn deinit(self: @This()) void {
    defer self.bind_layout0.deinit();
    defer self.bind_layout1.deinit();
    defer self.pipeline.deinit();
}

pub fn makeArgs(self: @This()) !Args {
    return try Args.init(self);
}

pub const Args = struct {
    const max_draw_calls = 128;
    const max_vertices = 4096;

    pipeline: VgPipeline,
    bind_group0: gpu.BindGroup,
    bind_group1: gpu.BindGroup,
    vertices: gpu.Buffer,
    uniform: gpu.Buffer,
    nvertices: usize = 0,
    calls: [max_draw_calls]usize = undefined,
    ncalls: usize = 0,

    fn init(pipeline: VgPipeline) !@This() {
        const uniform_buf = try pipeline.ctx.gfx.device.createBuffer(&.{
            .label = "vg uniform",
            .size = frag_arg_stride * max_draw_calls,
            .usage = @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Uniform),
            .mappedAtCreation = 0,
        });
        errdefer uniform_buf.deinit();

        const vertex_buf = try pipeline.ctx.gfx.device.createBuffer(&.{
            .label = "vg vertices",
            .size = @sizeOf(Vertex) * max_vertices,
            .usage = @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Vertex),
            .mappedAtCreation = 0,
        });
        errdefer vertex_buf.deinit();

        return .{
            .pipeline = pipeline,
            .vertices = vertex_buf,
            .uniform = uniform_buf,
            .bind_group0 = pipeline.ctx.gfx.device.createBindGroup(&.{
                .layout = pipeline.bind_layout0.ptr,
                .entryCount = 1,
                .entries = &[_]gpu.c.WGPUBindGroupEntry{
                    .{
                        .binding = 0,
                        .buffer = pipeline.ctx.gfx.screen_size_buf.ptr,
                        .offset = 0,
                        .size = @sizeOf(twod.Size),
                    },
                },
            }),
            .bind_group1 = pipeline.ctx.gfx.device.createBindGroup(&.{
                .layout = pipeline.bind_layout1.ptr,
                .entryCount = 1,
                .entries = &[_]gpu.c.WGPUBindGroupEntry{
                    .{
                        .binding = 0,
                        .buffer = uniform_buf.ptr,
                        .offset = 0,
                        .size = frag_arg_stride,
                    },
                },
            }),
        };
    }

    pub fn deinit(self: @This()) void {
        defer self.bind_group0.deinit();
        defer self.bind_group1.deinit();
        defer self.vertices.deinit();
        defer self.uniform.deinit();
    }

    pub fn add(self: *@This(), vertices: []const Vertex, frag_args: FragArgs) void {
        if (vertices.len == 0) return;

        const queue = self.pipeline.ctx.gfx.queue;

        // Update uniform
        const uoffset = frag_arg_stride * @as(u32, @intCast(self.ncalls));
        queue.writeBuffer(self.uniform, uoffset, &[1]FragArgs{frag_args});

        // Update vertices
        const voffset = @sizeOf(Vertex) * self.nvertices;
        queue.writeBuffer(self.vertices, voffset, vertices);

        self.calls[self.ncalls] = vertices.len;
        self.nvertices += vertices.len;
        self.ncalls += 1;
    }

    pub fn reset(self: *@This()) void {
        self.nvertices = 0;
        self.ncalls = 0;
    }
};

pub fn run(self: @This(), pass: gpu.RenderPassEncoder, args: Args) !void {
    if (args.nvertices == 0 or args.ncalls == 0) return;
    log.debug("VgPipeline.run nvertices={d} ncalls={d}", .{ args.nvertices, args.ncalls });

    // Args encodes many draw calls
    // The FragArgs uniform is dynamically offset

    pass.setPipeline(self.pipeline);

    pass.setBindGroup(.{
        .idx = 0,
        .group = args.bind_group0,
    });
    pass.setVertexBuffer(.{
        .buf = args.vertices,
        .size = @sizeOf(Vertex) * args.nvertices,
    });

    var voffset: usize = 0;
    for (0..args.ncalls) |i| {
        pass.setBindGroup(.{
            .idx = 1,
            .group = args.bind_group1,
            .offsets = &[1]u32{frag_arg_stride * @as(u32, @intCast(i))},
        });
        const vcount = args.calls[i];
        pass.draw(.{
            .vertex_count = @intCast(vcount),
            .first_vertex = @intCast(voffset),
        });
        voffset += vcount;
    }
}
