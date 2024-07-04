const std = @import("std");
const app = @import("root");
const gpu = @import("gpu");
const twod = @import("twod");

const log = std.log.scoped(.appgpu);

extern fn initGlfwWgpuSurface(gpu.c.WGPUInstance, *app.glfw.c.GLFWwindow, *gpu.c.WGPUSurface) c_int;

pub fn getSurface(instance: gpu.Instance, ctx: *app.Ctx) !gpu.Surface {
    switch (app.platform) {
        .mac, .linux, .windows => {
            var surface: gpu.Surface = undefined;
            if (initGlfwWgpuSurface(instance.ptr, ctx.glfwWindow(), &surface.ptr) != 0) return error.Glue;
            return surface;
        },
        .ios => {
            var desc = gpu.c.WGPUSurfaceDescriptorFromMetalLayer{
                .chain = .{
                    .sType = gpu.c.WGPUSType_SurfaceDescriptorFromMetalLayer,
                },
                .layer = ctx.getMetalLayer(),
            };
            return .{ .ptr = gpu.c.wgpuInstanceCreateSurface(instance.ptr, &.{
                .nextInChain = @ptrCast(&desc),
            }) orelse return error.SurfaceFail };
        },
        .android => {
            var desc = gpu.c.WGPUSurfaceDescriptorFromAndroidNativeWindow{
                .chain = .{
                    .sType = gpu.c.WGPUSType_SurfaceDescriptorFromAndroidNativeWindow,
                },
                .window = ctx.getNativeWindow(),
            };
            return .{ .ptr = gpu.c.wgpuInstanceCreateSurface(instance.ptr, &.{
                .nextInChain = @ptrCast(&desc),
            }) orelse return error.WgpuSurface };
        },
    }
}

pub const Gfx = struct {
    ctx: *app.Ctx,
    surface: gpu.Surface,
    surface_config: gpu.Surface.Config,
    device: gpu.Device,
    queue: gpu.Queue,
    screen_size_buf: gpu.Buffer,

    fn init(ctx: *app.Ctx) !@This() {
        log.debug("gpu.Instance", .{});
        const gpu_instance = try gpu.Instance.init();
        defer gpu_instance.deinit();

        log.debug("getSurface", .{});
        const surface = try getSurface(gpu_instance, ctx);
        errdefer surface.deinit();

        log.debug("requestAdapter", .{});
        const adapter = try gpu_instance.requestAdapter(&.{
            .compatibleSurface = surface.ptr,
        });
        defer adapter.deinit();

        log.debug("getCapabilities", .{});
        const surface_capabilities = surface.getCapabilities(adapter);
        defer surface_capabilities.deinit();

        log.debug("requestDevice", .{});
        const device = try adapter.requestDevice(null);
        errdefer device.deinit();

        log.debug("getQueue", .{});
        const queue = try device.getQueue();
        errdefer queue.deinit();

        log.debug("configure surface", .{});
        const window_size = ctx.getWindowSize();
        const surface_config = gpu.Surface.Config{
            .device = device.ptr,
            .usage = @intFromEnum(gpu.TextureUsage.RenderAttachment),
            .format = surface_capabilities.formats[0],
            .presentMode = @intFromEnum(gpu.PresentMode.Fifo),
            .alphaMode = @intFromEnum(gpu.CompositeAlphaMode.Auto),
            .width = window_size.width,
            .height = window_size.height,
        };
        surface.configure(&surface_config);

        log.debug("create screen size buffer", .{});
        const ssize_buf = try device.createBuffer(&.{
            .label = "screen size",
            .size = @sizeOf(twod.Size),
            .usage = @intFromEnum(gpu.BufferUsage.CopyDst) | @intFromEnum(gpu.BufferUsage.Uniform),
            .mappedAtCreation = 0,
        });
        errdefer ssize_buf.deinit();

        {
            const ssize = ctx.getWindowSize();
            queue.writeBuffer(ssize_buf, 0, &@as([2]f32, @bitCast(twod.Size.init(
                @floatFromInt(ssize.width),
                @floatFromInt(ssize.height),
            ))));
        }

        log.debug("Gfx initialized", .{});
        return .{
            .ctx = ctx,
            .surface = surface,
            .surface_config = surface_config,
            .device = device,
            .queue = queue,
            .screen_size_buf = ssize_buf,
        };
    }

    pub fn deinit(self: @This()) void {
        defer self.surface.deinit();
        defer self.device.deinit();
        defer self.queue.deinit();
        defer self.screen_size_buf.deinit();
    }

    pub const PipelineRun = struct {
        ptr: *const anyopaque,
        args: *const anyopaque,
        run_fn: *const fn (self: *const anyopaque, pass: gpu.RenderPassEncoder, args: *const anyopaque) anyerror!void,

        pub fn run(self: @This(), pass: gpu.RenderPassEncoder) !void {
            try self.run_fn(self.ptr, pass, self.args);
        }

        pub fn init(
            self: anytype,
            args: anytype,
            comptime func: *const fn (std.meta.Child(@TypeOf(self)), gpu.RenderPassEncoder, std.meta.Child(@TypeOf(args))) anyerror!void,
        ) @This() {
            const SelfT = std.meta.Child(@TypeOf(self));
            const ArgsT = std.meta.Child(@TypeOf(args));

            return .{
                .ptr = @ptrCast(self),
                .args = @ptrCast(args),
                .run_fn = (struct {
                    fn call(ptr: *const anyopaque, pass: gpu.RenderPassEncoder, ptr_args: *const anyopaque) !void {
                        const s: *const SelfT = @ptrCast(@alignCast(ptr));
                        const a: *const ArgsT = @ptrCast(@alignCast(ptr_args));
                        try @call(.always_inline, func, .{ s.*, pass, a.* });
                    }
                }.call),
            };
        }
    };

    const RenderOpts = struct {
        load: union(gpu.LoadOp) {
            Clear: gpu.c.WGPUColor,
            Load: void,
        },
        piperuns: []const PipelineRun,
    };
    pub fn render(self: @This(), opts: RenderOpts) !void {
        const texture = try self.surface.getCurrentTexture();
        defer texture.release();

        const view = try texture.createView(null);
        defer view.deinit();

        const command_encoder = try self.device.createCommandEncoder(null);
        defer command_encoder.deinit();

        const pass = try command_encoder.beginRenderPass(
            &.{
                .label = "render_pass_encoder",
                .colorAttachmentCount = 1,
                .colorAttachments = &.{
                    .view = view.ptr,
                    .loadOp = @intFromEnum(opts.load),
                    .storeOp = @intFromEnum(gpu.StoreOp.Store),
                    .depthSlice = gpu.DepthSliceUndefined,
                    .clearValue = if (opts.load == .Clear) opts.load.Clear else .{},
                },
            },
        );
        defer pass.deinit();

        for (opts.piperuns) |piperun| try piperun.run(pass);
        pass.end();

        const command_buffer = try command_encoder.finish(null);
        defer command_buffer.deinit();

        self.queue.submit(&.{command_buffer});
        self.surface.present();
    }

    pub fn updateWindowSize(self: *@This()) void {
        const window_size = self.ctx.getWindowSize();
        self.surface_config.width = window_size.width;
        self.surface_config.height = window_size.height;
        self.surface.configure(&self.surface_config);
        self.queue.writeBuffer(self.screen_size_buf, 0, &@as([2]f32, @bitCast(twod.Size.init(
            @floatFromInt(window_size.width),
            @floatFromInt(window_size.height),
        ))));
    }
};

pub fn defaultGfx(ctx: *app.Ctx) !Gfx {
    return try Gfx.init(ctx);
}
