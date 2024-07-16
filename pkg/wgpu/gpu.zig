// Documentation
// https://github.com/webgpu-native/webgpu-headers/blob/aef5e428a1fdab2ea770581ae7c95d8779984e0a/webgpu.h
// https://github.com/gfx-rs/wgpu-native/blob/85563e553374336fa8b0aa4d07fb1327f7c00244/ffi/wgpu.h
// https://eliemichel.github.io/LearnWebGPU
// WGSL:
// * https://www.w3.org/TR/WGSL
// * Built-ins: https://www.w3.org/TR/WGSL/#builtin-inputs-outputs

const builtin = @import("builtin");
const std = @import("std");

pub const c = @cImport({
    @cInclude("webgpu.h");
    @cInclude("wgpu.h");
});

const log_level = if (builtin.mode == .Debug) .debug else .info;

const log = std.log.scoped(.gpu);

pub const SamplerBindingType = enum(u32) {
    Undefined = 0x00000000,
    Filtering = 0x00000001,
    NonFiltering = 0x00000002,
    Comparison = 0x00000003,
};

pub const TextureSampleType = enum(u32) {
    Undefined = 0x00000000,
    Float = 0x00000001,
    UnfilterableFloat = 0x00000002,
    Depth = 0x00000003,
    Sint = 0x00000004,
    Uint = 0x00000005,
};

pub const BufferBindingType = enum(u32) {
    Undefined = 0x00000000,
    Uniform = 0x00000001,
    Storage = 0x00000002,
    ReadOnlyStorage = 0x00000003,
};

pub const ShaderStage = enum(u32) {
    None = 0x00000000,
    Vertex = 0x00000001,
    Fragment = 0x00000002,
    Compute = 0x00000004,
};

pub const VertexStepMode = enum(u32) {
    Vertex = 0x00000000,
    Instance = 0x00000001,
    VertexBufferNotUsed = 0x00000002,
};

pub const VertexFormat = enum(u32) {
    Undefined = 0x00000000,
    Uint8x2 = 0x00000001,
    Uint8x4 = 0x00000002,
    Sint8x2 = 0x00000003,
    Sint8x4 = 0x00000004,
    Unorm8x2 = 0x00000005,
    Unorm8x4 = 0x00000006,
    Snorm8x2 = 0x00000007,
    Snorm8x4 = 0x00000008,
    Uint16x2 = 0x00000009,
    Uint16x4 = 0x0000000A,
    Sint16x2 = 0x0000000B,
    Sint16x4 = 0x0000000C,
    Unorm16x2 = 0x0000000D,
    Unorm16x4 = 0x0000000E,
    Snorm16x2 = 0x0000000F,
    Snorm16x4 = 0x00000010,
    Float16x2 = 0x00000011,
    Float16x4 = 0x00000012,
    Float32 = 0x00000013,
    Float32x2 = 0x00000014,
    Float32x3 = 0x00000015,
    Float32x4 = 0x00000016,
    Uint32 = 0x00000017,
    Uint32x2 = 0x00000018,
    Uint32x3 = 0x00000019,
    Uint32x4 = 0x0000001A,
    Sint32 = 0x0000001B,
    Sint32x2 = 0x0000001C,
    Sint32x3 = 0x0000001D,
    Sint32x4 = 0x0000001E,
};

pub const BufferUsage = enum(u32) {
    None = 0x00000000,
    MapRead = 0x00000001,
    MapWrite = 0x00000002,
    CopySrc = 0x00000004,
    CopyDst = 0x00000008,
    Index = 0x00000010,
    Vertex = 0x00000020,
    Uniform = 0x00000040,
    Storage = 0x00000080,
    Indirect = 0x00000100,
    QueryResolve = 0x00000200,
};

pub const BlendOperation = enum(u32) {
    Add = 0x00000000,
    Subtract = 0x00000001,
    ReverseSubtract = 0x00000002,
    Min = 0x00000003,
    Max = 0x00000004,
};

pub const BlendFactor = enum(u32) {
    Zero = 0x00000000,
    One = 0x00000001,
    Src = 0x00000002,
    OneMinusSrc = 0x00000003,
    SrcAlpha = 0x00000004,
    OneMinusSrcAlpha = 0x00000005,
    Dst = 0x00000006,
    OneMinusDst = 0x00000007,
    DstAlpha = 0x00000008,
    OneMinusDstAlpha = 0x00000009,
    SrcAlphaSaturated = 0x0000000A,
    Constant = 0x0000000B,
    OneMinusConstant = 0x0000000C,
};

pub const IndexFormat = enum(u32) {
    Undefined = 0x00000000,
    Uint16 = 0x00000001,
    Uint32 = 0x00000002,
};

pub const TextureAspect = enum(u32) {
    All = 0x00000000,
    StencilOnly = 0x00000001,
    DepthOnly = 0x00000002,
};

pub const TextureDimension = enum(u32) {
    oneD = 0x00000000,
    twoD = 0x00000001,
    threeD = 0x00000002,
};

pub const TextureViewDimension = enum(u32) {
    Undefined = 0x00000000,
    oneD = 0x00000001,
    twoD = 0x00000002,
    twoDArray = 0x00000003,
    Cube = 0x00000004,
    CubeArray = 0x00000005,
    threeD = 0x00000006,
};

pub const TextureFormat = enum(u32) {
    Undefined = 0x00000000,
    R8Unorm = 0x00000001,
    R8Snorm = 0x00000002,
    R8Uint = 0x00000003,
    R8Sint = 0x00000004,
    R16Uint = 0x00000005,
    R16Sint = 0x00000006,
    R16Float = 0x00000007,
    RG8Unorm = 0x00000008,
    RG8Snorm = 0x00000009,
    RG8Uint = 0x0000000A,
    RG8Sint = 0x0000000B,
    R32Float = 0x0000000C,
    R32Uint = 0x0000000D,
    R32Sint = 0x0000000E,
    RG16Uint = 0x0000000F,
    RG16Sint = 0x00000010,
    RG16Float = 0x00000011,
    RGBA8Unorm = 0x00000012,
    RGBA8UnormSrgb = 0x00000013,
    RGBA8Snorm = 0x00000014,
    RGBA8Uint = 0x00000015,
    RGBA8Sint = 0x00000016,
    BGRA8Unorm = 0x00000017,
    BGRA8UnormSrgb = 0x00000018,
    RGB10A2Uint = 0x00000019,
    RGB10A2Unorm = 0x0000001A,
    RG11B10Ufloat = 0x0000001B,
    RGB9E5Ufloat = 0x0000001C,
    RG32Float = 0x0000001D,
    RG32Uint = 0x0000001E,
    RG32Sint = 0x0000001F,
    RGBA16Uint = 0x00000020,
    RGBA16Sint = 0x00000021,
    RGBA16Float = 0x00000022,
    RGBA32Float = 0x00000023,
    RGBA32Uint = 0x00000024,
    RGBA32Sint = 0x00000025,
    Stencil8 = 0x00000026,
    Depth16Unorm = 0x00000027,
    Depth24Plus = 0x00000028,
    Depth24PlusStencil8 = 0x00000029,
    Depth32Float = 0x0000002A,
    Depth32FloatStencil8 = 0x0000002B,
    BC1RGBAUnorm = 0x0000002C,
    BC1RGBAUnormSrgb = 0x0000002D,
    BC2RGBAUnorm = 0x0000002E,
    BC2RGBAUnormSrgb = 0x0000002F,
    BC3RGBAUnorm = 0x00000030,
    BC3RGBAUnormSrgb = 0x00000031,
    BC4RUnorm = 0x00000032,
    BC4RSnorm = 0x00000033,
    BC5RGUnorm = 0x00000034,
    BC5RGSnorm = 0x00000035,
    BC6HRGBUfloat = 0x00000036,
    BC6HRGBFloat = 0x00000037,
    BC7RGBAUnorm = 0x00000038,
    BC7RGBAUnormSrgb = 0x00000039,
    ETC2RGB8Unorm = 0x0000003A,
    ETC2RGB8UnormSrgb = 0x0000003B,
    ETC2RGB8A1Unorm = 0x0000003C,
    ETC2RGB8A1UnormSrgb = 0x0000003D,
    ETC2RGBA8Unorm = 0x0000003E,
    ETC2RGBA8UnormSrgb = 0x0000003F,
    EACR11Unorm = 0x00000040,
    EACR11Snorm = 0x00000041,
    EACRG11Unorm = 0x00000042,
    EACRG11Snorm = 0x00000043,
    ASTC4x4Unorm = 0x00000044,
    ASTC4x4UnormSrgb = 0x00000045,
    ASTC5x4Unorm = 0x00000046,
    ASTC5x4UnormSrgb = 0x00000047,
    ASTC5x5Unorm = 0x00000048,
    ASTC5x5UnormSrgb = 0x00000049,
    ASTC6x5Unorm = 0x0000004A,
    ASTC6x5UnormSrgb = 0x0000004B,
    ASTC6x6Unorm = 0x0000004C,
    ASTC6x6UnormSrgb = 0x0000004D,
    ASTC8x5Unorm = 0x0000004E,
    ASTC8x5UnormSrgb = 0x0000004F,
    ASTC8x6Unorm = 0x00000050,
    ASTC8x6UnormSrgb = 0x00000051,
    ASTC8x8Unorm = 0x00000052,
    ASTC8x8UnormSrgb = 0x00000053,
    ASTC10x5Unorm = 0x00000054,
    ASTC10x5UnormSrgb = 0x00000055,
    ASTC10x6Unorm = 0x00000056,
    ASTC10x6UnormSrgb = 0x00000057,
    ASTC10x8Unorm = 0x00000058,
    ASTC10x8UnormSrgb = 0x00000059,
    ASTC10x10Unorm = 0x0000005A,
    ASTC10x10UnormSrgb = 0x0000005B,
    ASTC12x10Unorm = 0x0000005C,
    ASTC12x10UnormSrgb = 0x0000005D,
    ASTC12x12Unorm = 0x0000005E,
    ASTC12x12UnormSrgb = 0x0000005F,
};

pub const CompositeAlphaMode = enum(u32) {
    Auto = 0x00000000,
    Opaque = 0x00000001,
    Premultiplied = 0x00000002,
    Unpremultiplied = 0x00000003,
    Inherit = 0x00000004,
};

pub const ErrorType = enum(u32) {
    NoError = 0x00000000,
    Validation = 0x00000001,
    OutOfMemory = 0x00000002,
    Internal = 0x00000003,
    Unknown = 0x00000004,
    DeviceLost = 0x00000005,

    fn fromInt(i: u32) @This() {
        return @enumFromInt(i);
    }
};

pub const TextureUsage = enum(u32) {
    None = 0x00000000,
    CopySrc = 0x00000001,
    CopyDst = 0x00000002,
    TextureBinding = 0x00000004,
    StorageBinding = 0x00000008,
    RenderAttachment = 0x00000010,
};

pub const PresentMode = enum(u32) {
    Fifo = 0x00000000,
    FifoRelaxed = 0x00000001,
    Immediate = 0x00000002,
    Mailbox = 0x00000003,
};

pub const ColorWriteMask = enum(u32) {
    None = 0x00000000,
    Red = 0x00000001,
    Green = 0x00000002,
    Blue = 0x00000004,
    Alpha = 0x00000008,
    All = 0x00000001 | 0x00000002 | 0x00000004 | 0x00000008,
};

pub const PrimitiveTopology = enum(u32) {
    PointList = 0x00000000,
    LineList = 0x00000001,
    LineStrip = 0x00000002,
    TriangleList = 0x00000003,
    TriangleStrip = 0x00000004,
};

pub const LoadOp = enum(u32) {
    Clear = 1,
    Load = 2,
};

pub const StoreOp = enum(u32) {
    Store = 1,
    Discard = 2,
};

pub const DepthSliceUndefined = c.WGPU_DEPTH_SLICE_UNDEFINED;

pub const Instance = extern struct {
    ptr: c.WGPUInstance,

    pub fn init() !@This() {
        if (log_level == .debug) {
            c.wgpuSetLogLevel(c.WGPULogLevel_Trace);
        } else if (log_level == .info) {
            c.wgpuSetLogLevel(c.WGPULogLevel_Info);
        } else {
            c.wgpuSetLogLevel(c.WGPULogLevel_Warn);
        }
        c.wgpuSetLogCallback(logCallback, null);

        var instance_desc = c.WGPUInstanceExtras{
            .chain = .{
                .sType = c.WGPUSType_InstanceExtras,
            },
            .flags = if (log_level == .debug) c.WGPUInstanceFlag_Debug else 0,
        };
        return .{ .ptr = c.wgpuCreateInstance(&.{
            .nextInChain = @ptrCast(&instance_desc),
        }) orelse return error.InstanceFail };
    }

    pub fn deinit(self: @This()) void {
        c.wgpuInstanceRelease(self.ptr);
    }

    pub fn requestAdapter(self: @This(), options: *const c.WGPURequestAdapterOptions) !Adapter {
        var adapter: Adapter = .{ .ptr = null };
        c.wgpuInstanceRequestAdapter(self.ptr, options, handleRequestAdapter, &adapter);
        if (adapter.ptr == null) return error.FailedAdapter;
        return adapter;
    }
};

pub const Surface = extern struct {
    pub const Config = c.WGPUSurfaceConfiguration;

    pub const Capabilities = extern struct {
        nextInChain: *c.WGPUChainedStructOut,
        formatCount: usize,
        formats: [*c]const c.WGPUTextureFormat,
        presentModeCount: usize,
        presentModes: [*c]const c.WGPUPresentMode,
        alphaModeCount: usize,
        alphaModes: [*c]const c.WGPUCompositeAlphaMode,

        pub fn deinit(self: @This()) void {
            c.wgpuSurfaceCapabilitiesFreeMembers(@bitCast(self));
        }
    };

    ptr: c.WGPUSurface,
    pub fn deinit(self: @This()) void {
        c.wgpuSurfaceRelease(self.ptr);
    }

    pub fn getCapabilities(self: @This(), adapter: Adapter) Capabilities {
        var surface_capabilities: Capabilities = undefined;
        c.wgpuSurfaceGetCapabilities(self.ptr, adapter.ptr, @ptrCast(&surface_capabilities));
        return surface_capabilities;
    }

    pub fn getCurrentTexture(self: @This()) !Texture {
        var maybe_texture: c.WGPUSurfaceTexture = undefined;
        c.wgpuSurfaceGetCurrentTexture(self.ptr, &maybe_texture);

        switch (maybe_texture.status) {
            c.WGPUSurfaceGetCurrentTextureStatus_Success => {
                return .{ .ptr = maybe_texture.texture };
            },
            c.WGPUSurfaceGetCurrentTextureStatus_Timeout => return error.TextureTimeout,
            c.WGPUSurfaceGetCurrentTextureStatus_Outdated => return error.TextureOutdated,
            c.WGPUSurfaceGetCurrentTextureStatus_Lost => return error.TextureLost,
            c.WGPUSurfaceGetCurrentTextureStatus_OutOfMemory => return error.TextureOOM,
            c.WGPUSurfaceGetCurrentTextureStatus_DeviceLost => return error.TextureDeviceLost,
            else => unreachable,
        }
    }

    pub fn present(self: @This()) void {
        c.wgpuSurfacePresent(self.ptr);
    }

    pub fn configure(self: @This(), config: *const Config) void {
        c.wgpuSurfaceConfigure(self.ptr, config);
    }
};

pub const Texture = extern struct {
    pub const View = extern struct {
        ptr: c.WGPUTextureView,

        pub fn deinit(self: @This()) void {
            c.wgpuTextureViewRelease(self.ptr);
        }
    };

    ptr: c.WGPUTexture,

    pub fn deinit(self: @This()) void {
        self.destroy(); // release gpu memory
        self.release(); // release cpu memory
    }

    pub fn destroy(self: @This()) void {
        c.wgpuTextureDestroy(self.ptr);
    }

    pub fn release(self: @This()) void {
        c.wgpuTextureRelease(self.ptr);
    }

    pub fn createView(self: @This(), options: ?*const c.WGPUTextureViewDescriptor) !View {
        const default = c.WGPUTextureViewDescriptor{
            .format = @intFromEnum(self.format()),
            .dimension = @intFromEnum(TextureViewDimension.twoD),
            .mipLevelCount = 1,
            .arrayLayerCount = 1,
            .aspect = @intFromEnum(TextureAspect.All),
        };
        return .{ .ptr = c.wgpuTextureCreateView(self.ptr, options orelse &default) orelse return error.ViewFailed };
    }

    pub fn format(self: @This()) TextureFormat {
        return @enumFromInt(c.wgpuTextureGetFormat(self.ptr));
    }

    pub fn dimension(self: @This()) TextureDimension {
        return @enumFromInt(c.wgpuTextureGetDimension(self.ptr));
    }
};

pub const Device = extern struct {
    ptr: c.WGPUDevice,

    pub fn getQueue(self: @This()) !Queue {
        return .{ .ptr = c.wgpuDeviceGetQueue(self.ptr) orelse return error.QueueFail };
    }

    pub fn deinit(self: @This()) void {
        _ = c.wgpuDevicePoll(self.ptr, 1, null);
        c.wgpuDeviceRelease(self.ptr);
    }

    pub fn createShaderModule(self: @This(), name: [:0]const u8, src: ShaderModule.Src) !ShaderModule {
        const chain: *const c.WGPUChainedStruct = switch (src) {
            .wgsl => |buf| @ptrCast(&c.WGPUShaderModuleWGSLDescriptor{
                .chain = .{
                    .sType = c.WGPUSType_ShaderModuleWGSLDescriptor,
                },
                .code = buf.ptr,
            }),
            .spirv => |buf| @ptrCast(&c.WGPUShaderModuleSPIRVDescriptor{
                .chain = .{
                    .sType = c.WGPUSType_ShaderModuleSPIRVDescriptor,
                },
                .code = buf.ptr,
                .codeSize = @intCast(buf.len),
            }),
        };
        return .{ .ptr = c.wgpuDeviceCreateShaderModule(self.ptr, &.{
            .label = name,
            .nextInChain = chain,
        }) orelse return error.WgpuShader };
    }

    pub fn createPipelineLayout(self: @This(), options: ?*const c.WGPUPipelineLayoutDescriptor) !PipelineLayout {
        return .{ .ptr = c.wgpuDeviceCreatePipelineLayout(
            self.ptr,
            options,
        ) orelse return error.WgpuPipelineLayout };
    }

    pub fn createRenderPipeline(self: @This(), options: *const c.WGPURenderPipelineDescriptor) !RenderPipeline {
        return .{ .ptr = c.wgpuDeviceCreateRenderPipeline(
            self.ptr,
            options,
        ) orelse return error.RenderPipelineFailed };
    }

    pub fn createCommandEncoder(self: @This(), options: ?*const c.WGPUCommandEncoderDescriptor) !CommandEncoder {
        return .{ .ptr = c.wgpuDeviceCreateCommandEncoder(self.ptr, options) orelse return error.WgpuCommandEncoder };
    }

    pub fn createBuffer(self: @This(), options: *const c.WGPUBufferDescriptor) !Buffer {
        return .{ .ptr = c.wgpuDeviceCreateBuffer(self.ptr, options) orelse return error.BufferCreate };
    }

    pub fn createTexture(self: @This(), options: *const c.WGPUTextureDescriptor) !Texture {
        return .{ .ptr = c.wgpuDeviceCreateTexture(self.ptr, options) orelse return error.TextureCreate };
    }

    pub fn createBindGroup(self: @This(), options: *const c.WGPUBindGroupDescriptor) BindGroup {
        return .{ .ptr = c.wgpuDeviceCreateBindGroup(self.ptr, options) };
    }

    pub fn createBindGroupLayout(self: @This(), options: *const c.WGPUBindGroupLayoutDescriptor) BindGroup.Layout {
        return .{ .ptr = c.wgpuDeviceCreateBindGroupLayout(self.ptr, options) };
    }

    pub fn createSampler(self: @This(), options: ?*const c.WGPUSamplerDescriptor) !Sampler {
        const defaults = c.WGPUSamplerDescriptor{
            .addressModeU = c.WGPUAddressMode_ClampToEdge,
            .addressModeV = c.WGPUAddressMode_ClampToEdge,
            .addressModeW = c.WGPUAddressMode_ClampToEdge,
            .magFilter = c.WGPUFilterMode_Linear,
            .minFilter = c.WGPUFilterMode_Nearest,
            .mipmapFilter = c.WGPUMipmapFilterMode_Linear,
            .lodMinClamp = 0,
            .lodMaxClamp = 1,
            .maxAnisotropy = 1,
        };
        return .{ .ptr = c.wgpuDeviceCreateSampler(self.ptr, options orelse &defaults) orelse return error.SamplerCreate };
    }
};

pub const Sampler = extern struct {
    ptr: c.WGPUSampler,

    pub fn deinit(self: @This()) void {
        c.wgpuSamplerRelease(self.ptr);
    }
};

pub const BindGroup = extern struct {
    pub const Layout = extern struct {
        ptr: c.WGPUBindGroupLayout,

        pub fn deinit(self: @This()) void {
            c.wgpuBindGroupLayoutRelease(self.ptr);
        }
    };

    ptr: c.WGPUBindGroup,

    pub fn deinit(self: @This()) void {
        c.wgpuBindGroupRelease(self.ptr);
    }
};

pub const Buffer = extern struct {
    ptr: c.WGPUBuffer,

    pub fn deinit(self: @This()) void {
        self.destroy(); // release gpu memory
        self.release(); // release cpu memory
    }

    pub fn destroy(self: @This()) void {
        c.wgpuBufferDestroy(self.ptr);
    }

    pub fn release(self: @This()) void {
        c.wgpuBufferRelease(self.ptr);
    }
};

pub const CommandEncoder = extern struct {
    ptr: c.WGPUCommandEncoder,

    pub fn deinit(self: @This()) void {
        c.wgpuCommandEncoderRelease(self.ptr);
    }

    pub fn beginRenderPass(self: @This(), options: *const c.WGPURenderPassDescriptor) !RenderPassEncoder {
        return .{ .ptr = c.wgpuCommandEncoderBeginRenderPass(self.ptr, options) orelse return error.RenderPassEncoderFail };
    }

    pub fn finish(self: @This(), options: ?*const c.WGPUCommandBufferDescriptor) !CommandBuffer {
        return .{ .ptr = c.wgpuCommandEncoderFinish(self.ptr, options) orelse return error.CommandBufferFail };
    }
};

pub const CommandBuffer = extern struct {
    ptr: c.WGPUCommandBuffer,
    pub fn deinit(self: @This()) void {
        c.wgpuCommandBufferRelease(self.ptr);
    }
};

pub const RenderPassEncoder = extern struct {
    ptr: c.WGPURenderPassEncoder,

    pub fn deinit(self: @This()) void {
        c.wgpuRenderPassEncoderRelease(self.ptr);
    }

    pub fn setPipeline(self: @This(), pipeline: RenderPipeline) void {
        c.wgpuRenderPassEncoderSetPipeline(self.ptr, pipeline.ptr);
    }

    const DrawArgs = struct {
        vertex_count: u32 = 0,
        instance_count: u32 = 1,
        first_vertex: u32 = 0,
        first_instance: u32 = 0,
    };
    pub fn draw(self: @This(), opts: DrawArgs) void {
        c.wgpuRenderPassEncoderDraw(
            self.ptr,
            opts.vertex_count,
            opts.instance_count,
            opts.first_vertex,
            opts.first_instance,
        );
    }

    pub fn end(self: @This()) void {
        c.wgpuRenderPassEncoderEnd(self.ptr);
    }

    const VertexBufferOpts = struct {
        slot: u32 = 0,
        buf: Buffer,
        offset: u64 = 0,
        size: u64,
    };
    pub fn setVertexBuffer(self: @This(), opts: VertexBufferOpts) void {
        c.wgpuRenderPassEncoderSetVertexBuffer(self.ptr, opts.slot, opts.buf.ptr, opts.offset, opts.size);
    }

    const BindGroupOpts = struct {
        idx: u32 = 0,
        group: BindGroup,
        offsets: []const u32 = &.{},
    };
    pub fn setBindGroup(self: @This(), opts: BindGroupOpts) void {
        c.wgpuRenderPassEncoderSetBindGroup(self.ptr, opts.idx, opts.group.ptr, opts.offsets.len, opts.offsets.ptr);
    }
};

pub const Queue = extern struct {
    ptr: c.WGPUQueue,
    pub fn deinit(self: @This()) void {
        c.wgpuQueueRelease(self.ptr);
    }

    pub fn submit(self: @This(), commands: []const CommandBuffer) void {
        c.wgpuQueueSubmit(self.ptr, commands.len, @ptrCast(commands.ptr));
    }

    pub fn writeBuffer(self: @This(), buffer: Buffer, offset: u64, data: anytype) void {
        const u8data = tou8slice(data);
        c.wgpuQueueWriteBuffer(self.ptr, buffer.ptr, offset, u8data.ptr, u8data.len);
    }

    pub fn writeTexture(
        self: @This(),
        texture: *const c.WGPUImageCopyTexture,
        data: []const u8,
        layout: *const c.WGPUTextureDataLayout,
        size: *const c.WGPUExtent3D,
    ) void {
        c.wgpuQueueWriteTexture(self.ptr, texture, data.ptr, data.len, layout, size);
    }
};

pub const ShaderModule = extern struct {
    const Src = union(enum) {
        wgsl: [:0]const u8,
        spirv: []const u32,
    };
    ptr: c.WGPUShaderModule,

    pub fn deinit(self: @This()) void {
        c.wgpuShaderModuleRelease(self.ptr);
    }
};

pub const PipelineLayout = extern struct {
    ptr: c.WGPUPipelineLayout,
    pub fn deinit(self: @This()) void {
        c.wgpuPipelineLayoutRelease(self.ptr);
    }
};

pub const RenderPipeline = extern struct {
    ptr: c.WGPURenderPipeline,
    pub fn deinit(self: @This()) void {
        c.wgpuRenderPipelineRelease(self.ptr);
    }
};

pub const Adapter = extern struct {
    ptr: c.WGPUAdapter,

    pub fn deinit(self: @This()) void {
        c.wgpuAdapterRelease(self.ptr);
    }

    pub fn limits(self: @This()) !c.WGPULimits {
        var lim: c.WGPUSupportedLimits = undefined;
        if (c.wgpuAdapterGetLimits(self.ptr, &lim) == 0) {
            log.err("wgpuAdapterGetLimits failed", .{});
            return error.AdapterLimits;
        }
        return lim.limits;
    }

    pub fn requestDevice(self: @This(), maybe_options: ?*c.WGPUDeviceDescriptor) !Device {
        var device: Device = .{ .ptr = null };

        const default_options: c.WGPUDeviceDescriptor = .{
            .requiredLimits = &.{
                .limits = defaultLimits(),
            },
            .deviceLostCallback = handleDeviceLost,
            .deviceLostUserdata = null,
        };

        const options = if (maybe_options) |opt| opt else &default_options;
        c.wgpuAdapterRequestDevice(
            self.ptr,
            options,
            handleRequestDevice,
            &device,
        );
        if (device.ptr == null) return error.DeviceFailed;

        c.wgpuDeviceSetUncapturedErrorCallback(device.ptr, handleError, null);

        return device;
    }

    // https://github.com/gfx-rs/wgpu/blob/87576b72b37c6b78b41104eb25fc31893af94092/wgpu-types/src/lib.rs#L1173
    pub fn defaultLimits() c.WGPULimits {
        return .{
            .maxTextureDimension1D = 2048,
            .maxTextureDimension2D = 2048,
            .maxTextureDimension3D = 256,
            .maxTextureArrayLayers = 256,
            .maxBindGroups = 4,
            .maxBindingsPerBindGroup = 1000,
            .maxDynamicUniformBuffersPerPipelineLayout = 8,
            .maxDynamicStorageBuffersPerPipelineLayout = 4,
            .maxSampledTexturesPerShaderStage = 16,
            .maxSamplersPerShaderStage = 16,
            .maxStorageBuffersPerShaderStage = 4,
            .maxStorageTexturesPerShaderStage = 4,
            .maxUniformBuffersPerShaderStage = 12,
            .maxUniformBufferBindingSize = 16 << 10,
            .maxStorageBufferBindingSize = 128 << 20,
            .maxVertexBuffers = 8,
            .maxBufferSize = 256 << 20,
            .maxVertexAttributes = 16,
            .maxVertexBufferArrayStride = 2048,
            .minUniformBufferOffsetAlignment = 256,
            .minStorageBufferOffsetAlignment = 256,
            .maxInterStageShaderComponents = 60,
            .maxComputeWorkgroupStorageSize = 16352,
            .maxComputeInvocationsPerWorkgroup = 256,
            .maxComputeWorkgroupSizeX = 256,
            .maxComputeWorkgroupSizeY = 256,
            .maxComputeWorkgroupSizeZ = 64,
            .maxComputeWorkgroupsPerDimension = 65535,

            // not specified in the rust code
            .maxColorAttachments = 8,
            .maxColorAttachmentBytesPerSample = 32,
            .maxBindGroupsPlusVertexBuffers = 12,
            .maxInterStageShaderVariables = 2,

            // not listed in the c code
            // max_push_constant_size: 0,
            // max_non_sampler_bindings: 1_000_000,
        };
    }
};

fn handleRequestAdapter(
    status: c.WGPURequestAdapterStatus,
    adapter: c.WGPUAdapter,
    message: [*c]const u8,
    userdata: ?*anyopaque,
) callconv(.C) void {
    var ctx: *Adapter = @ptrCast(@alignCast(userdata));
    if (status == c.WGPURequestAdapterStatus_Success) {
        ctx.ptr = adapter;
    } else {
        ctx.ptr = null;
        log.err("wgpu request adapter error: [{any}] {s}", .{ status, message });
    }
}

fn handleRequestDevice(
    status: c.WGPURequestDeviceStatus,
    device: c.WGPUDevice,
    message: [*c]const u8,
    userdata: ?*anyopaque,
) callconv(.C) void {
    var ctx: *Device = @ptrCast(@alignCast(userdata));
    if (status == c.WGPURequestDeviceStatus_Success) {
        ctx.ptr = device;
    } else {
        ctx.ptr = null;
        log.err("wgpu request device error: [{any}] {s}", .{ status, message });
    }
}

const LogLevel = enum(u32) {
    off = 0,
    err,
    warn,
    info,
    debug,
    trace,

    fn fromInt(i: u32) LogLevel {
        return @enumFromInt(i);
    }
};

fn logCallback(level: c.WGPULogLevel, message: [*c]const u8, userdata: ?*anyopaque) callconv(.C) void {
    _ = userdata;
    log.info("[wgpu {s}]: {s}", .{ @tagName(LogLevel.fromInt(level)), message });
}

fn handleDeviceLost(reason: c.WGPUDeviceLostReason, message: [*c]const u8, userdata: ?*anyopaque) callconv(.C) void {
    _ = userdata;
    const reason_str = switch (reason) {
        c.WGPUDeviceLostReason_Undefined => "undefined",
        c.WGPUDeviceLostReason_Destroyed => "destroyed",
        else => unreachable,
    };
    log.err("device lost reason={s} message={s}", .{ reason_str, message });
}

fn handleError(t: c.WGPUErrorType, message: [*c]const u8, userdata: ?*anyopaque) callconv(.C) void {
    _ = userdata;
    log.err("unhandled error {s}: {s}", .{ @tagName(ErrorType.fromInt(t)), message });
    @panic("unhandled error");
}

fn tou8slice(x: anytype) []const u8 {
    const err = "buffer data must be a slice or pointer to an array";
    const T = @TypeOf(x);
    const I = @typeInfo(T);
    if (I != .Pointer) @compileError(err);

    const C = I.Pointer.child;
    if (I.Pointer.size == .Slice) {
        return tou8sliceInner(C, x);
    } else if (I.Pointer.size == .One) {
        const CI = @typeInfo(C);
        if (CI != .Array) @compileError(err);
        return tou8sliceInner(std.meta.Child(C), &x.*);
    } else {
        @compileError(err);
    }
}

fn tou8sliceInner(comptime T: type, x: []const T) []const u8 {
    if (x.len == 0) return &.{};
    const len = @sizeOf(T) * x.len;
    const ptr: [*]const u8 = @ptrCast(&x[0]);
    return ptr[0..len];
}
