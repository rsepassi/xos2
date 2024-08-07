const std = @import("std");
const log = std.log.scoped(.image_pipeline);

const app = @import("app");
const appgpu = @import("appgpu");
const gpu = appgpu.gpu;
const twod = @import("twod");

const myapp = @import("app.zig");

const ImagePipeline = @This();

gfx: appgpu.Gfx,
sampler: gpu.Sampler,
bind_layout: gpu.BindGroup.Layout,
pipeline: gpu.RenderPipeline,

const nvertices = 6;

const Vertex = twod.Point;
const Size = twod.Size;

pub const Image = PipelineImage;
const PipelineImage = struct {
    gfx: appgpu.Gfx,
    tex: gpu.Texture,
    view: gpu.Texture.View,
    size: twod.Size,
    pos: gpu.Buffer,

    pub fn init(gfx: appgpu.Gfx, size: twod.Size) !@This() {
        const tex = try createTexture(gfx.device, size);
        errdefer tex.deinit();

        const view = try tex.createView(null);
        errdefer view.deinit();

        const pos = try gfx.device.createBuffer(&.{
            .label = "image vertices",
            .size = @sizeOf(Vertex) * nvertices,
            .usage = @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Vertex),
            .mappedAtCreation = 0,
        });
        errdefer pos.deinit();

        return .{
            .gfx = gfx,
            .size = size,
            .tex = tex,
            .view = view,
            .pos = pos,
        };
    }

    pub fn deinit(self: @This()) void {
        defer self.tex.deinit();
        defer self.view.deinit();
        defer self.pos.deinit();
    }

    pub fn writeImage(self: @This(), image: twod.Image) void {
        self.gfx.queue.writeTexture(
            &.{
                .texture = self.tex.ptr,
                .mipLevel = 0,
                .origin = .{ .x = 0, .y = 0, .z = 0 },
                .aspect = @intFromEnum(gpu.TextureAspect.All),
            },
            image.tou8slice(),
            &.{
                .offset = 0,
                .bytesPerRow = @as(u32, @intFromFloat(self.size.width)) * 4,
                .rowsPerImage = @intFromFloat(self.size.height),
            },
            &.{
                .width = @intFromFloat(self.size.width),
                .height = @intFromFloat(self.size.height),
                .depthOrArrayLayers = 1,
            },
        );
    }

    pub fn writePos(self: @This(), pos_tl: twod.Point) void {
        const pos_br = pos_tl.down(self.size.height).right(self.size.width);
        const pos_rect = twod.Rect{ .tl = pos_tl, .br = pos_br };
        const vertex_data: [6]twod.Point = @bitCast(pos_rect.toTriangles());
        self.gfx.queue.writeBuffer(self.pos, 0, &vertex_data);
    }
};

fn createTexture(device: gpu.Device, size: twod.Size) !gpu.Texture {
    return try device.createTexture(&.{
        .label = "image texture",
        .usage = @intFromEnum(gpu.TextureUsage.CopyDst) | @intFromEnum(gpu.TextureUsage.TextureBinding),
        .dimension = @intFromEnum(gpu.TextureDimension.twoD),
        .size = .{
            .width = @intFromFloat(size.width),
            .height = @intFromFloat(size.height),
            .depthOrArrayLayers = 1,
        },
        .format = @intFromEnum(gpu.TextureFormat.RGBA8UnormSrgb),
        .mipLevelCount = 1,
        .sampleCount = 1,
    });
}

pub fn init(gfx: appgpu.Gfx) !@This() {
    const device = gfx.device;

    const wgsl = @embedFile("image.wgsl");
    const shader = try device.createShaderModule("image", .{ .wgsl = wgsl });
    defer shader.deinit();

    const bind_layout = device.createBindGroupLayout(&.{
        .entryCount = 3,
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
            // texture
            .{
                .binding = 1,
                .visibility = @intFromEnum(gpu.ShaderStage.Fragment),
                .texture = .{
                    .sampleType = @intFromEnum(gpu.TextureSampleType.Float),
                    .viewDimension = @intFromEnum(gpu.TextureViewDimension.twoD),
                    .multisampled = 0,
                },
            },
            // sampler
            .{
                .binding = 2,
                .visibility = @intFromEnum(gpu.ShaderStage.Fragment),
                .sampler = .{
                    .type = @intFromEnum(gpu.SamplerBindingType.Filtering),
                },
            },
        },
    });
    errdefer bind_layout.deinit();

    const pipeline_layout = try device.createPipelineLayout(&.{
        .bindGroupLayoutCount = 1,
        .bindGroupLayouts = &bind_layout.ptr,
    });
    defer pipeline_layout.deinit();

    const pipeline = try device.createRenderPipeline(&.{
        .label = "image pipeline",
        .layout = pipeline_layout.ptr,
        .vertex = .{
            .module = shader.ptr,
            .entryPoint = "vs_main",
            .bufferCount = 1,
            .buffers = &.{
                .arrayStride = @sizeOf(Vertex),
                .stepMode = @intFromEnum(gpu.VertexStepMode.Vertex),
                .attributeCount = 1,
                .attributes = &[_]gpu.c.WGPUVertexAttribute{
                    .{
                        .format = @intFromEnum(gpu.VertexFormat.Float32x2),
                        .shaderLocation = 0,
                        .offset = 0,
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
    errdefer pipeline.deinit();

    const sampler = try device.createSampler(null);
    errdefer sampler.deinit();

    return .{
        .gfx = gfx,
        .sampler = sampler,
        .bind_layout = bind_layout,
        .pipeline = pipeline,
    };
}

pub fn deinit(self: @This()) void {
    defer self.sampler.deinit();
    defer self.bind_layout.deinit();
    defer self.pipeline.deinit();
}

pub fn makeArgs(self: @This(), image: PipelineImage) Args {
    return Args.init(self, image);
}

pub const Args = struct {
    bind_group: gpu.BindGroup,
    vertices: gpu.Buffer,

    fn init(pipeline: ImagePipeline, image: PipelineImage) @This() {
        return .{
            .vertices = image.pos,
            .bind_group = pipeline.gfx.device.createBindGroup(&.{
                .layout = pipeline.bind_layout.ptr,
                .entryCount = 3,
                .entries = &[_]gpu.c.WGPUBindGroupEntry{
                    .{
                        .binding = 0,
                        .buffer = pipeline.gfx.screen_size_buf.ptr,
                        .offset = 0,
                        .size = @sizeOf(twod.Size),
                    },
                    .{
                        .binding = 1,
                        .textureView = image.view.ptr,
                    },
                    .{
                        .binding = 2,
                        .sampler = pipeline.sampler.ptr,
                    },
                },
            }),
        };
    }

    pub fn deinit(self: @This()) void {
        self.bind_group.deinit();
    }
};

pub fn run(self: @This(), pass: gpu.RenderPassEncoder, args: Args) !void {
    log.debug("ImagePipeline.run nvertices={d}", .{nvertices});
    pass.setPipeline(self.pipeline);
    pass.setBindGroup(.{ .group = args.bind_group });
    pass.setVertexBuffer(.{
        .buf = args.vertices,
        .size = @sizeOf(Vertex) * nvertices,
    });
    pass.draw(.{ .vertex_count = nvertices });
}
