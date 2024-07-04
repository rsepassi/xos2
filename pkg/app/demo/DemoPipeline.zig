const std = @import("std");
const app = @import("app");
const myapp = @import("app.zig");
const twod = @import("twod");
const gpu = @import("gpu");
const DemoPipeline = @This();

const log = std.log.scoped(.demo_pipeline);

ctx: myapp.PipelineCtx,
vertex_buf: gpu.Buffer,
bind_group: gpu.BindGroup,
pipeline: gpu.RenderPipeline,

const ScreenSize = twod.Size;
const Vertex = extern struct {
    pos: [2]f32,
    color: [3]f32,
};
const nvertices = 6;

pub fn init(ctx: myapp.PipelineCtx) !@This() {
    const device = ctx.gfx.device;
    const queue = ctx.gfx.queue;

    const vertex_data = [_]Vertex{
        .{ .pos = .{ 0, 0 }, .color = .{ 1, 0, 0 } },
        .{ .pos = .{ 640, 0 }, .color = .{ 0, 1, 0 } },
        .{ .pos = .{ 320, 480 }, .color = .{ 0, 0, 1 } },
    };
    const vertex_buf = try device.createBuffer(&.{
        .label = "demo vertices",
        .size = @sizeOf(Vertex) * vertex_data.len,
        .usage = @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Vertex),
        .mappedAtCreation = 0,
    });
    queue.writeBuffer(vertex_buf, 0, &vertex_data);

    const wgsl = @embedFile("demo.wgsl");
    const shader = try device.createShaderModule("demo", .{ .wgsl = wgsl });
    defer shader.deinit();

    const bind_layout = device.createBindGroupLayout(&.{
        .entryCount = 1,
        .entries = &.{
            .binding = 0,
            .visibility = @intFromEnum(gpu.ShaderStage.Vertex),
            .buffer = .{
                .type = @intFromEnum(gpu.BufferBindingType.Uniform),
                .minBindingSize = @sizeOf(ScreenSize),
            },
        },
    });
    defer bind_layout.deinit();
    const pipeline_layout = try device.createPipelineLayout(&.{
        .bindGroupLayoutCount = 1,
        .bindGroupLayouts = &bind_layout.ptr,
    });
    defer pipeline_layout.deinit();

    const bind_group = device.createBindGroup(&.{
        .layout = bind_layout.ptr,
        .entryCount = 1,
        .entries = &.{
            .binding = 0,
            .buffer = ctx.gfx.screen_size_buf.ptr,
            .offset = 0,
            .size = @sizeOf(ScreenSize),
        },
    });

    const demo_pipeline = try device.createRenderPipeline(&.{
        .label = "demo_pipeline",
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
                        .format = @intFromEnum(gpu.VertexFormat.Float32x3),
                        .shaderLocation = 1,
                        .offset = @offsetOf(Vertex, "color"),
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
            .topology = @intFromEnum(gpu.PrimitiveTopology.TriangleList),
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
        .pipeline = demo_pipeline,
        .vertex_buf = vertex_buf,
        .bind_group = bind_group,
    };
}

pub fn deinit(self: @This()) void {
    defer self.vertex_buf.deinit();
    defer self.bind_group.deinit();
    defer self.pipeline.deinit();
}

pub fn run(self: @This(), pass: gpu.RenderPassEncoder, args: void) !void {
    _ = args;

    log.debug("DemoPipeline.run", .{});
    pass.setPipeline(self.pipeline);
    pass.setBindGroup(.{
        .group = self.bind_group,
    });
    pass.setVertexBuffer(.{
        .buf = self.vertex_buf,
        .size = @sizeOf(Vertex) * nvertices,
    });
    pass.draw(.{ .vertex_count = nvertices });
}
