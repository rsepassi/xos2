const std = @import("std");
const log = std.log.scoped(.sprite_pipeline);

const app = @import("app");
const gpu = @import("gpu");
const appgpu = @import("appgpu");
const twod = @import("twod");

const myapp = @import("app.zig");

const SpritePipeline = @This();

ctx: myapp.PipelineCtx,
sampler: gpu.Sampler,
bind_layout: gpu.BindGroup.Layout,
pipeline: gpu.RenderPipeline,

const vertices_per_sprite = 6;

const Vertex = extern struct {
    pos: twod.Point,
    uv: twod.Point,
};

pub const SpriteLocs = struct {
    ctx: myapp.PipelineCtx,
    vertices: []Vertex,
    pos: gpu.Buffer,
    nmax: usize,
    nvertices: u32 = 0,

    pub fn init(ctx: myapp.PipelineCtx, nmax: usize) !@This() {
        const nvertices = nmax * vertices_per_sprite;

        const vertices = try ctx.allocator.alloc(Vertex, nvertices);
        errdefer ctx.allocator.free(vertices);

        const pos = try ctx.gfx.device.createBuffer(&.{
            .label = "sprite sheet vertices",
            .size = @sizeOf(Vertex) * nvertices,
            .usage = @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Vertex),
            .mappedAtCreation = 0,
        });
        errdefer pos.deinit();

        return .{
            .ctx = ctx,
            .vertices = vertices,
            .pos = pos,
            .nmax = nmax,
        };
    }

    pub fn deinit(self: @This()) void {
        defer self.ctx.allocator.free(self.vertices);
        defer self.pos.deinit();
    }

    pub const Loc = struct {
        pos: twod.Rect,
        uv: twod.Rect,
    };
    pub fn write(self: *@This(), locs: []const Loc) !void {
        if (locs.len > self.nmax) return error.TooManyVertices;

        for (locs, 0..) |loc, i| {
            const start = i * vertices_per_sprite;
            const end = start + vertices_per_sprite;
            const verts = self.vertices[start..end];

            const pos_pts: [6]twod.Point = @bitCast(loc.pos.toTriangles());
            const uv_pts: [6]twod.Point = @bitCast(loc.uv.toTriangles());

            inline for (0..6) |j| {
                verts[j].pos = pos_pts[j];
                verts[j].uv = uv_pts[j];
            }
        }

        const nvertices = locs.len * vertices_per_sprite;
        self.ctx.gfx.queue.writeBuffer(self.pos, 0, self.vertices[0..nvertices]);
        self.nvertices = @intCast(nvertices);
    }
};

pub const SpriteSheet = struct {
    gfx: appgpu.Gfx,
    tex: gpu.Texture,
    view: gpu.Texture.View,
    size_buf: gpu.Buffer,

    pub fn init(gfx: appgpu.Gfx, sheet: twod.Image) !@This() {
        const tex = try createTexture(gfx.device, sheet.size);
        errdefer tex.deinit();
        writeImage(gfx.queue, tex, sheet);

        const view = try tex.createView(null);
        errdefer view.deinit();

        const size_buf = try gfx.device.createBuffer(&.{
            .label = "sprite sheet size",
            .size = @sizeOf(twod.Size),
            .usage = @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Uniform),
            .mappedAtCreation = 0,
        });
        errdefer size_buf.deinit();
        gfx.queue.writeBuffer(size_buf, 0, &@as([2]f32, @bitCast(sheet.size)));

        return .{
            .gfx = gfx,
            .tex = tex,
            .view = view,
            .size_buf = size_buf,
        };
    }

    pub fn deinit(self: @This()) void {
        defer self.tex.deinit();
        defer self.view.deinit();
        defer self.size_buf.deinit();
    }
};

pub fn init(ctx: myapp.PipelineCtx) !@This() {
    const device = ctx.gfx.device;

    const wgsl = @embedFile("sprite.wgsl");
    const shader = try device.createShaderModule("sprite", .{ .wgsl = wgsl });
    defer shader.deinit();

    const bind_layout = device.createBindGroupLayout(&.{
        .entryCount = 4,
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
            // texture size
            .{
                .binding = 3,
                .visibility = @intFromEnum(gpu.ShaderStage.Vertex),
                .buffer = .{
                    .type = @intFromEnum(gpu.BufferBindingType.Uniform),
                    .minBindingSize = @sizeOf(twod.Size),
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
        .label = "sprite pipeline",
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
        .ctx = ctx,
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

pub fn makeArgs(self: @This(), spritesheet: SpriteSheet, sprite_locs: *const SpriteLocs) Args {
    return Args.init(self, spritesheet, sprite_locs);
}

pub const Args = struct {
    bind_group: gpu.BindGroup,
    locs: *const SpriteLocs,

    fn init(pipeline: SpritePipeline, spritesheet: SpriteSheet, locs: *const SpriteLocs) @This() {
        return .{
            .locs = locs,
            .bind_group = pipeline.ctx.gfx.device.createBindGroup(&.{
                .layout = pipeline.bind_layout.ptr,
                .entryCount = 4,
                .entries = &[_]gpu.c.WGPUBindGroupEntry{
                    .{
                        .binding = 0,
                        .buffer = pipeline.ctx.gfx.screen_size_buf.ptr,
                        .offset = 0,
                        .size = @sizeOf(twod.Size),
                    },
                    .{
                        .binding = 1,
                        .textureView = spritesheet.view.ptr,
                    },
                    .{
                        .binding = 2,
                        .sampler = pipeline.sampler.ptr,
                    },
                    .{
                        .binding = 3,
                        .buffer = spritesheet.size_buf.ptr,
                        .offset = 0,
                        .size = @sizeOf(twod.Size),
                    },
                },
            }),
        };
    }

    pub fn deinit(self: @This()) void {
        self.bind_group.deinit();
    }
};

fn writeImage(q: gpu.Queue, tex: gpu.Texture, image: twod.Image) void {
    q.writeTexture(
        &.{
            .texture = tex.ptr,
            .mipLevel = 0,
            .origin = .{ .x = 0, .y = 0, .z = 0 },
            .aspect = @intFromEnum(gpu.TextureAspect.All),
        },
        image.tou8slice(),
        &.{
            .offset = 0,
            .bytesPerRow = @as(u32, @intFromFloat(image.size.width)) * 4,
            .rowsPerImage = @intFromFloat(image.size.height),
        },
        &.{
            .width = @intFromFloat(image.size.width),
            .height = @intFromFloat(image.size.height),
            .depthOrArrayLayers = 1,
        },
    );
}

fn createTexture(device: gpu.Device, size: twod.Size) !gpu.Texture {
    return try device.createTexture(&.{
        .label = "sprite sheet",
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

pub fn run(self: @This(), pass: gpu.RenderPassEncoder, args: Args) !void {
    const nvertices = args.locs.nvertices;
    if (nvertices == 0) return;
    log.debug("SpritePipeline.run nvertices={d}", .{nvertices});

    pass.setPipeline(self.pipeline);
    pass.setBindGroup(.{ .group = args.bind_group });
    pass.setVertexBuffer(.{
        .buf = args.locs.pos,
        .size = @sizeOf(Vertex) * nvertices,
    });
    pass.draw(.{ .vertex_count = nvertices });
}
