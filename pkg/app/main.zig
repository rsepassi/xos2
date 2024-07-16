const std = @import("std");
const builtin = @import("builtin");

const userlib = @import("userlib");
const log = std.log.scoped(.approot);

pub const std_options = .{
    .log_level = userlib.std_options.log_level,
    .logFn = switch (platform) {
        .ios => iosApp.logFn,
        .android => androidApp.logFn,
        else => std.log.defaultLog,
    },
};

// An App has:
// * Callbacks
//   * init
//   * frame
//   * cleanup
//   * event
// * Window title
// * Window size

pub const Platform = enum { mac, windows, linux, ios, android };
pub const platform: Platform = switch (builtin.os.tag) {
    .ios => .ios,
    .macos => .mac,
    .windows => .windows,
    .linux => if (builtin.abi == .android) .android else .linux,
    else => @compileError("unsupported"),
};
pub const Config = struct {
    window_title: [:0]const u8 = "xos",
    window_size: [2]u32 = .{ 640, 480 },
};

const WindowSize = struct { width: u32, height: u32 };

pub const Resources = struct {
    dir: std.fs.Dir,

    fn init(allocator: std.mem.Allocator) !@This() {
        const exepath = try std.fs.selfExePathAlloc(allocator);
        defer allocator.free(exepath);
        const exedir = std.fs.path.dirname(exepath) orelse return error.NoResourceDir;
        const resource_dir_path = try std.fs.path.join(allocator, &.{ exedir, "xos-resources" });
        defer allocator.free(resource_dir_path);
        return .{
            .dir = try std.fs.cwd().openDir(resource_dir_path, .{}),
        };
    }

    fn deinit(cself: *const @This()) void {
        const self: *@This() = @constCast(cself);
        self.dir.close();
    }
};

pub const Ctx = struct {
    const PlatformT = PlatformCtxMixin(@This());

    gpa: std.heap.GeneralPurposeAllocator(.{}),
    _resources: ?Resources = null,
    platform: PlatformT,

    pub usingnamespace PlatformT;

    fn init() !*@This() {
        const self = try std.heap.c_allocator.create(@This());
        self.gpa = .{};
        const alloc = self.gpa.allocator();
        self._resources = Resources.init(alloc) catch null;
        return self;
    }

    fn deinit(cself: *const @This()) void {
        const self: *@This() = @constCast(cself);
        defer if (self.gpa.deinit() == .leak) log.err("leak!", .{});
        defer if (self._resources) |r| r.deinit();
    }

    pub fn allocator(self: *@This()) std.mem.Allocator {
        return self.gpa.allocator();
    }

    pub fn resources(self: @This()) ?Resources {
        return self._resources;
    }
};

fn PlatformCtxMixin(comptime T: type) type {
    return switch (platform) {
        .mac, .windows, .linux => struct {
            app: *const glfw,

            pub fn glfwWindow(self: T) *glfw.c.GLFWwindow {
                return self.platform.app.window;
            }

            pub fn getWindowSize(self: T) WindowSize {
                var width: c_int = 0;
                var height: c_int = 0;
                glfw.c.glfwGetWindowSize(self.platform.app.window, &width, &height);
                return .{ .width = @intCast(width), .height = @intCast(height) };
            }
        },
        .ios => struct {
            metal_layer: *anyopaque,
            window_size: [2]f64,

            pub fn getMetalLayer(self: T) *anyopaque {
                return self.platform.metal_layer;
            }

            pub fn getWindowSize(self: T) WindowSize {
                return .{ .width = @intFromFloat(self.platform.window_size[0]), .height = @intFromFloat(self.platform.window_size[1]) };
            }
        },
        .android => struct {
            native_window: *anyopaque,
            window_size: [2]i32,

            pub fn getNativeWindow(self: T) *anyopaque {
                return self.platform.native_window;
            }

            pub fn getWindowSize(self: T) WindowSize {
                return .{ .width = @intCast(self.platform.window_size[0]), .height = @intCast(self.platform.window_size[1]) };
            }
        },
    };
}

const App = AppUser(userlib.App);
pub const Event = union(enum) {
    start: void,
    char: u32,
    resize: void,
};

fn AppUser(comptime T: type) type {
    return struct {
        const Self = @This();

        app: *T,

        fn getConfig() Config {
            return if (@hasDecl(T, "appConfig")) T.appConfig() else .{};
        }

        fn init(ctx: *Ctx) !Self {
            const app = try std.heap.c_allocator.create(T);
            if (@hasDecl(T, "init")) try app.init(ctx);

            return .{
                .app = app,
            };
        }

        fn deinit(self: @This()) void {
            if (@hasDecl(T, "deinit")) self.app.deinit();
            defer std.heap.c_allocator.destroy(self.app);
        }

        fn start(self: @This()) void {
            self.onEvent(.{ .start = {} });
        }

        fn onEvent(self: @This(), event: Event) void {
            log.debug("event {s}", .{@tagName(event)});
            self.app.onEvent(event) catch |err| {
                log.err("event handling failed: {any}", .{err});
                @panic("event handling failed");
            };
        }
    };
}

pub const glfw = struct {
    // https://www.glfw.org/docs/latest/window_guide.html
    // https://www.glfw.org/docs/latest/input_guide.html

    pub const c = @cImport({
        @cDefine("GLFW_INCLUDE_NONE", "1");
        @cInclude("GLFW/glfw3.h");
        switch (builtin.os.tag) {
            .macos => @cDefine("GLFW_EXPOSE_NATIVE_COCOA", "1"),
            .linux => @cDefine("GLFW_EXPOSE_NATIVE_X11", "1"),
            .windows => @cDefine("GLFW_EXPOSE_NATIVE_WIN32", "1"),
            else => @compileError("unsupported"),
        }
        @cInclude("GLFW/glfw3native.h");
    });

    window: *c.GLFWwindow,

    fn init(config: Config) !@This() {
        _ = c.glfwSetErrorCallback(errorCallback);
        if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInit;
        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        const window = c.glfwCreateWindow(
            @intCast(config.window_size[0]),
            @intCast(config.window_size[1]),
            config.window_title,
            null,
            null,
        ) orelse return error.GlfwWindow;
        return .{ .window = window };
    }

    fn deinit(self: @This()) void {
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();
    }

    fn shouldClose(self: @This()) bool {
        return c.glfwWindowShouldClose(self.window) == glfw.c.GLFW_TRUE;
    }

    fn onChar(window: ?*c.GLFWwindow, codepoint: c_uint) callconv(.C) void {
        const app = getApp(window);
        app.onEvent(.{ .char = codepoint });
    }

    fn onFbSize(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
        log.debug("resize ({d}, {d})", .{ width, height });
        const app = getApp(window);
        app.onEvent(.{ .resize = {} });
    }

    fn getApp(window: ?*c.GLFWwindow) *App {
        return @ptrCast(@alignCast(c.glfwGetWindowUserPointer(window)));
    }

    fn errorCallback(error_code: c_int, description: [*c]const u8) callconv(.C) void {
        log.err("glfw error: [{d}] {s}\n", .{ error_code, description });
    }

    fn main() !void {
        log.debug("hello world!", .{});
        defer log.debug("goodbye", .{});

        const config = App.getConfig();

        const app = try glfw.init(config);
        defer app.deinit();

        var ctx = try Ctx.init();
        ctx.platform.app = &app;
        defer ctx.deinit();

        var userapp = try App.init(ctx);
        defer userapp.deinit();

        _ = glfw.c.glfwSetCharCallback(app.window, glfw.onChar);
        _ = glfw.c.glfwSetFramebufferSizeCallback(app.window, glfw.onFbSize);

        glfw.c.glfwSetWindowUserPointer(app.window, @ptrCast(&userapp));
        // _ = glfw.c.glfwSetKeyCallback(app.window, AppGlfw.onKey);
        // _ = glfw.c.glfwSetCursorPosCallback(window, AppGlfw.onCursorMove);
        // _ = glfw.c.glfwSetCursorEnterCallback(window, AppGlfw.onCursorEnter);
        // _ = glfw.c.glfwSetMouseButtonCallback(window, AppGlfw.onClick);
        // _ = glfw.c.glfwSetScrollCallback(window, AppGlfw.onScroll);
        // _ = glfw.c.glfwSetDropCallback(window, AppGlfw.onDrop);

        userapp.start();
        while (glfw.c.glfwWindowShouldClose(app.window) == glfw.c.GLFW_FALSE)
            glfw.c.glfwWaitEvents();
    }
};

//     // glfwSetWindowTitle(window, "My Window");
//     // glfwSetWindowIcon(window, 2, images);
//     // glfwIconifyWindow(window);
//     // glfwRestoreWindow(window);
//     // glfwSetWindowIconifyCallback(window, window_iconify_callback);
//     // void window_iconify_callback(GLFWwindow* window, int iconified)
//     // glfwMaximizeWindow(window);
//     // glfwRestoreWindow(window);
//     // glfwSetWindowMaximizeCallback(window, window_maximize_callback);
//     // glfwFocusWindow(window);
//     // glfwSetWindowFocusCallback(window, window_focus_callback);
//     // glfwRequestWindowAttention(window);
//     // glfwSetWindowRefreshCallback(m_handle, window_refresh_callback);
//
//     // void framebuffer_size_callback(GLFWwindow* window, int width, int height)
//     // void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
//     // The action is one of GLFW_PRESS, GLFW_REPEAT or GLFW_RELEASE. Events with GLFW_PRESS and GLFW_RELEASE actions are emitted for every key press. Most keys will also emit events with GLFW_REPEAT actions while a key is held down.
//     //
//     // void character_callback(GLFWwindow* window, unsigned int codepoint)
//     // void cursor_position_callback(GLFWwindow* window, double xpos, double ypos)
//
//     // or query it glfwGetCursorPos(window, &xpos, &ypos);
//
//     // void cursor_enter_callback(GLFWwindow* window, int entered)
//     // or query it glfwGetWindowAttrib(window, GLFW_HOVERED)
//     //
//     // void mouse_button_callback(GLFWwindow* window, int button, int action, int mods)
//     // The action is one of GLFW_PRESS or GLFW_RELEASE.
//
//     // void scroll_callback(GLFWwindow* window, double xoffset, double yoffset)
//     //
//     //
//     // const char* text = glfwGetClipboardString(NULL);
//     // glfwSetClipboardString(NULL, "A string with words in it");
//     //
//     // void drop_callback(GLFWwindow* window, int count, const char** paths)
// };

var gctx: *Ctx = undefined;
var gapp: App = undefined;

extern fn doiOSLog(msg: [*:0]const u8) void;
extern fn doAndroidLog(msg: [*:0]const u8) void;

var log_fn_buf: [if (builtin.mode == .Debug) 16384 else 2048]u8 = undefined;

const iosApp = struct {
    fn logFn(
        comptime level: std.log.Level,
        comptime scope: @TypeOf(.EnumLiteral),
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = level;
        _ = scope;
        const msg = std.fmt.bufPrintZ(&log_fn_buf, format, args) catch "<log message too long>";
        doiOSLog(msg);
    }

    fn provideMetalLayer(layer: *anyopaque, width: f64, height: f64) callconv(.C) void {
        log.debug("provideMetalLayer ({d}, {d})", .{ width, height });
        gctx = Ctx.init() catch |err| {
            log.err("Ctx init failed: {any}", .{err});
            @panic("Ctx init failed");
        };
        gctx.platform = .{
            .metal_layer = layer,
            .window_size = .{ width, height },
        };
        gapp = App.init(gctx) catch |err| {
            log.err("App init failed: {any}", .{err});
            @panic("App init failed");
        };
        gapp.start();
    }

    fn handleResize(width: f64, height: f64) callconv(.C) void {
        log.debug("handleResize ({d}, {d})", .{ width, height });
        gctx.platform.window_size = .{ width, height };
        gapp.onEvent(.{ .resize = {} });
    }

    fn handleShutdown() callconv(.C) void {
        gapp.deinit();
    }
};

const androidApp = struct {
    fn logFn(
        comptime level: std.log.Level,
        comptime scope: @TypeOf(.EnumLiteral),
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = level;
        _ = scope;
        const msg = std.fmt.bufPrintZ(&log_fn_buf, format, args) catch "<log message too long> format=" ++ format;
        doAndroidLog(msg);
    }

    fn provideNativeWindow(window: *anyopaque, width: i32, height: i32) callconv(.C) void {
        log.debug("provideNativeWindow ({d}, {d})", .{ width, height });
        gctx = Ctx.init() catch |err| {
            log.err("Ctx init failed: {any}", .{err});
            @panic("Ctx init failed");
        };
        gctx.platform = .{
            .native_window = window,
            .window_size = .{ width, height },
        };
        gapp = App.init(gctx) catch |err| {
            log.err("App init failed: {any}", .{err});
            @panic("App init failed");
        };
        gapp.start();
    }

    fn handleResize(width: i32, height: i32) callconv(.C) void {
        log.debug("handleResize ({d}, {d})", .{ width, height });
        gctx.platform.window_size = .{ width, height };
        gapp.onEvent(.{ .resize = {} });
    }

    fn handleShutdown() callconv(.C) void {
        gapp.deinit();
    }
};

pub usingnamespace switch (platform) {
    .mac, .windows, .linux => struct {
        pub fn main() !void {
            try glfw.main();
        }
    },
    .ios, .android => struct {},
};

comptime {
    switch (platform) {
        .mac, .windows, .linux => {},
        .ios => {
            @export(iosApp.provideMetalLayer, .{ .name = "_xos_ios_provide_metal_layer" });
            @export(iosApp.handleResize, .{ .name = "_xos_ios_handle_resize" });
            @export(iosApp.handleShutdown, .{ .name = "_xos_handle_shutdown" });
        },
        .android => {
            @export(androidApp.provideNativeWindow, .{ .name = "_xos_android_provide_native_window" });
            @export(androidApp.handleResize, .{ .name = "_xos_android_handle_resize" });
            @export(androidApp.handleShutdown, .{ .name = "_xos_handle_shutdown" });
        },
    }
}
