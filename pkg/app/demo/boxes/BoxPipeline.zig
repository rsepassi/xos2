const std = @import("std");
const app = @import("app");
const appgpu = @import("appgpu");
const gpu = appgpu.gpu;

const log = std.log.scoped(.triangle_pipeline);

gfx: appgpu.Gfx,
vertex_buf: gpu.Buffer,
bind_group: gpu.BindGroup,
pipeline: gpu.RenderPipeline,
nboxes: usize = 0,
capacity: usize,

const ScreenSize = extern struct {
    width: f32,
    height: f32,
};
const XY = [2]f32;
const Color = [3]f32;
const VertexInput = extern struct {
    pos: XY,
    color: Color,
};

const initial_capacity = 32;
const nvert_per_box = 6;

pub fn init(gfx: appgpu.Gfx) !@This() {
    const device = gfx.device;

    const shader = try device.createShaderModule(
        "boxes",
        .{ .wgsl = @embedFile("boxes.wgsl") },
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
        .label = "box vertices",
        .size = @sizeOf(VertexInput) * initial_capacity * nvert_per_box,
        .usage = @intFromEnum(gpu.BufferUsage.CopySrc) | @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Vertex),
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
        .capacity = initial_capacity,
    };
}

pub fn deinit(self: @This()) void {
    defer self.vertex_buf.deinit();
    defer self.bind_group.deinit();
    defer self.pipeline.deinit();
}

pub fn reserve(self: *@This(), new_capacity: usize) !void {
    const new_buf = try self.gfx.device.createBuffer(&.{
        .label = "box vertices",
        .size = @sizeOf(VertexInput) * new_capacity * nvert_per_box,
        .usage = @intFromEnum(gpu.BufferUsage.CopySrc) | @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Vertex),
        .mappedAtCreation = 0,
    });
    errdefer new_buf.deinit();

    const command_encoder = try self.gfx.device.createCommandEncoder(null);
    defer command_encoder.deinit();

    command_encoder.copyBufferToBuffer(
        self.vertex_buf,
        0,
        new_buf,
        0,
        @sizeOf(VertexInput) * nvert_per_box * self.nboxes,
    );

    const command_buffer = try command_encoder.finish(null);
    defer command_buffer.deinit();
    self.gfx.queue.submit(&.{command_buffer});

    self.vertex_buf.deinit();
    self.vertex_buf = new_buf;
    self.capacity = new_capacity;
}

pub fn reset(self: *@This()) void {
    self.nboxes = 0;
}

pub fn box(self: *@This(), pos: XY, size: XY, color: Color) !void {
    if (self.nboxes + 1 > self.capacity) try self.reserve(self.capacity * 2);

    const vertex_data = [_]VertexInput{
        // bottom left
        .{ .pos = pos, .color = color },
        // bottom right
        .{ .pos = .{ pos[0] + size[0], pos[1] }, .color = color },
        // top left
        .{ .pos = .{ pos[0], pos[1] + size[1] }, .color = color },
        // top left
        .{ .pos = .{ pos[0], pos[1] + size[1] }, .color = color },
        // bottom right
        .{ .pos = .{ pos[0] + size[0], pos[1] }, .color = color },
        // top right
        .{ .pos = .{ pos[0] + size[0], pos[1] + size[1] }, .color = color },
    };
    const offset = @sizeOf(VertexInput) * self.nboxes * nvert_per_box;
    self.gfx.queue.writeBuffer(self.vertex_buf, offset, &vertex_data);
    self.nboxes += 1;
}

pub fn run(self: @This(), pass: gpu.RenderPassEncoder) !void {
    const nvert: u32 = @intCast(self.nboxes * nvert_per_box);
    if (nvert == 0) return;

    pass.setPipeline(self.pipeline);
    pass.setBindGroup(.{
        .group = self.bind_group,
    });
    pass.setVertexBuffer(.{
        .buf = self.vertex_buf,
        .size = @sizeOf(VertexInput) * nvert,
    });
    pass.draw(.{ .vertex_count = nvert });
}
