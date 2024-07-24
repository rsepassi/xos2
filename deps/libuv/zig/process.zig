const std = @import("std");
const uv = @import("uv.zig");
const coro = @import("zigcoro");

const log = std.log.scoped(.uvzig);

pub const Process = struct {
    pub const StdioOpts = union(enum) {
        inherit_fd: uv.uv_file,
        inherit_stream: *uv.uv_stream_t,
        create_pipe: struct {
            pipe: *uv.uv_stream_t,
            flow: enum { RO, WO, RW },
            nonblock: bool = false,
        },
    };
    const RunOpts = struct {
        env: ?[][:0]const u8 = null,
        cwd: ?[:0]const u8 = null,
        stdio: [3]?StdioOpts = .{ null, null, null },
    };

    pub const Status = struct {
        exit_status: i64,
        term_signal: c_int,
    };

    pub fn run(loop: *uv.uv_loop_t, alloc: std.mem.Allocator, args: [][:0]const u8, opts: RunOpts) !Status {
        log.debug("process run", .{});
        var handle = uv.uv_process_t{};
        defer {
            var closer = Closer.init();
            closer.close(@ptrCast(&handle));
        }
        var data = Data.init();
        uv.setHandleData(&handle, &data);

        const cargs = try alloc.alloc([*c]const u8, args.len + 1);
        defer alloc.free(cargs);
        cargs[args.len] = null;
        for (args, 0..) |a, i| {
            log.debug("- {s}", .{a});
            cargs[i] = a;
        }

        var cenv: ?[][*c]const u8 = null;
        if (opts.env) |env| {
            cenv = try alloc.alloc([*c]const u8, env.len + 1);
            cenv.?[env.len] = null;
            for (env, 0..) |e, i| cenv.?[i] = e;
        }
        defer if (cenv) |e| alloc.free(e);

        var stdio: [3]uv.uv_stdio_container_t = undefined;
        for (0..3) |i| {
            if (opts.stdio[i]) |sopt| {
                switch (sopt) {
                    .inherit_fd => |fd| {
                        log.debug("stdio[{d}]=.inherit_fd={d}", .{ i, fd });
                        stdio[i].flags = uv.UV_INHERIT_FD;
                        stdio[i].data.fd = fd;
                    },
                    .inherit_stream => |s| {
                        log.debug("stdio[{d}]=.inherit_stream={*}", .{ i, s });
                        stdio[i].flags = uv.UV_INHERIT_STREAM;
                        stdio[i].data.stream = s;
                    },
                    .create_pipe => |opt| {
                        log.debug("stdio[{d}]=.create_pipe {s}", .{ i, @tagName(opt.flow) });
                        var flags = uv.UV_CREATE_PIPE;
                        if (opt.nonblock) flags |= uv.UV_NONBLOCK_PIPE;
                        flags |= switch (opt.flow) {
                            .RO => uv.UV_READABLE_PIPE,
                            .WO => uv.UV_WRITABLE_PIPE,
                            .RW => uv.UV_READABLE_PIPE | uv.UV_WRITABLE_PIPE,
                        };

                        stdio[i].flags = @intCast(flags);
                        stdio[i].data.stream = opt.pipe;
                    },
                }
            } else {
                stdio[i].flags = uv.UV_IGNORE;
            }
        }

        var o = uv.uv_process_options_t{};
        o.file = cargs[0];
        o.args = @constCast(@ptrCast(cargs.ptr));
        o.env = if (cenv) |env| @constCast(@ptrCast(env.ptr)) else null;
        o.cwd = if (opts.cwd) |cwd| cwd.ptr else null;
        o.stdio_count = 3;
        o.stdio = &stdio;
        o.exit_cb = Data.onExit;

        try uv.check(uv.uv_spawn(loop, &handle, &o));
        log.debug("process spawned pid={d}", .{handle.pid});
        coro.xsuspend();
        log.debug("process exited pid={d} code={d}", .{ handle.pid, data.out.?.exit_status });

        return data.out.?;
    }

    const Data = struct {
        frame: coro.Frame,
        out: ?Status = null,
        fn init() @This() {
            return .{ .frame = coro.xframe() };
        }

        fn onExit(process: [*c]uv.uv_process_t, exit_status: i64, term_signal: c_int) callconv(.C) void {
            const data = uv.getHandleData(process, Data);
            data.out = .{
                .exit_status = exit_status,
                .term_signal = term_signal,
            };
            coro.xresume(data.frame);
        }
    };
};

const Closer = struct {
    frame: coro.Frame,
    fn init() @This() {
        return .{ .frame = coro.xframe() };
    }
    fn close(self: *@This(), handle: [*c]uv.uv_handle_t) void {
        uv.setHandleData(handle, self);
        uv.uv_close(handle, onClose);
        coro.xsuspend();
    }
    fn onClose(handle: [*c]uv.uv_handle_t) callconv(.C) void {
        const data = uv.getHandleData(handle, @This());
        coro.xresume(data.frame);
    }
};
