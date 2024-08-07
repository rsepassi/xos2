const std = @import("std");
const app = @import("app");
const appgpu = @import("appgpu");
const gpu = appgpu.gpu;

const log = std.log.scoped(.triangle_pipeline);

gfx: appgpu.Gfx,
vertex_buf: gpu.Buffer,
bind_group: gpu.BindGroup,
pipeline: gpu.RenderPipeline,

const ScreenSize = extern struct {
    width: f32,
    height: f32,
};
const VertexInput = extern struct {
    pos: [2]f32,
    color: [3]f32,
};
const nvertices = 3;

pub fn init(gfx: appgpu.Gfx) !@This() {
    const device = gfx.device;

    const shader = try device.createShaderModule(
        "triangles",
        .{ .wgsl = @embedFile("triangles.wgsl") },
    );
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

    const vertex_buf = try device.createBuffer(&.{
        .label = "triangle vertices",
        .size = @sizeOf(VertexInput) * nvertices,
        .usage = @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Vertex),
        .mappedAtCreation = 0,
    });
    errdefer vertex_buf.deinit();

    const bind_group = device.createBindGroup(&.{
        .layout = bind_layout.ptr,
        .entryCount = 1,
        .entries = &.{
            .binding = 0,
            .buffer = gfx.screen_size_buf.ptr,
            .offset = 0,
            .size = @sizeOf(ScreenSize),
        },
    });

    const pipeline = try device.createRenderPipeline(&.{
        .label = "pipeline",
        .layout = pipeline_layout.ptr,
        .vertex = .{
            .module = shader.ptr,
            .entryPoint = "vs_main",
            .bufferCount = 1,
            .buffers = &.{
                .arrayStride = @sizeOf(VertexInput),
                .stepMode = @intFromEnum(gpu.VertexStepMode.Vertex),
                .attributeCount = 2,
                .attributes = &[_]gpu.c.WGPUVertexAttribute{
                    .{
                        .format = @intFromEnum(gpu.VertexFormat.Float32x2),
                        .shaderLocation = 0,
                        .offset = @offsetOf(VertexInput, "pos"),
                    },
                    .{
                        .format = @intFromEnum(gpu.VertexFormat.Float32x3),
                        .shaderLocation = 1,
                        .offset = @offsetOf(VertexInput, "color"),
                    },
                },
            },
        },
        .fragment = &.{
            .module = shader.ptr,
            .entryPoint = "fs_main",
            .targetCount = 1,
            .targets = &.{
                .format = gfx.surface_config.format,
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
        .gfx = gfx,
        .pipeline = pipeline,
        .vertex_buf = vertex_buf,
        .bind_group = bind_group,
    };
}

pub fn deinit(self: @This()) void {
    defer self.vertex_buf.deinit();
    defer self.bind_group.deinit();
    defer self.pipeline.deinit();
}

pub fn writeTriangle(self: @This()) !void {
    const size = self.gfx.ctx.getWindowSize();
    const right: f32 = @floatFromInt(size.width);
    const top: f32 = @floatFromInt(size.height);
    const xcenter: f32 = right / 2;

    const vertex_data = [_]VertexInput{
        // bottom left
        .{ .pos = .{ 0, 0 }, .color = .{ 1, 0, 0 } },
        // bottom right
        .{ .pos = .{ right, 0 }, .color = .{ 0, 1, 0 } },
        // top center
        .{ .pos = .{ xcenter, top }, .color = .{ 0, 0, 1 } },
    };
    self.gfx.queue.writeBuffer(self.vertex_buf, 0, &vertex_data);
}

pub fn run(self: @This(), pass: gpu.RenderPassEncoder) !void {
    pass.setPipeline(self.pipeline);
    pass.setBindGroup(.{
        .group = self.bind_group,
    });
    pass.setVertexBuffer(.{
        .buf = self.vertex_buf,
        .size = @sizeOf(VertexInput) * nvertices,
    });
    pass.draw(.{ .vertex_count = nvertices });
}
