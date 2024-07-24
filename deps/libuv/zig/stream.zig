const std = @import("std");
const uv = @import("uv.zig");
const coro = @import("zigcoro");

const log = std.log.scoped(.uvzig);

pub const Stream = struct {
    handle: *uv.uv_stream_t,

    const Error = uv.Error;
    const Writer = std.io.Writer(@This(), Error, write);
    pub fn writer(self: @This()) Writer {
        return .{ .context = self };
    }

    pub fn write(self: @This(), buf: []const u8) Error!usize {
        const Data = struct {
            frame: coro.Frame,
            status: ?c_int = null,

            fn init() @This() {
                return .{ .frame = coro.xframe() };
            }
            fn cb(req: [*c]uv.uv_write_t, status: c_int) callconv(.C) void {
                log.debug("stream write cb", .{});
                var data = uv.getHandleData(req.*.handle, @This());
                data.status = status;
                coro.xresume(data.frame);
            }
        };

        log.debug("stream write", .{});
        var data = Data.init();
        var req: uv.uv_write_t = .{};
        var uvbuf = uv.newbuf(@constCast(buf));
        uv.setHandleData(self.handle, &data);
        try uv.check(uv.uv_write(&req, self.handle, &uvbuf, 1, Data.cb));
        coro.xsuspend();
        try uv.check(data.status.?);
        return buf.len;
    }

    const Reader = std.io.Reader(@This(), Error, read);
    pub fn reader(self: @This()) Reader {
        return .{ .context = self };
    }

    pub fn read(self: @This(), buf: []u8) Error!usize {
        const Data = struct {
            frame: coro.Frame,
            userbuf: []u8,
            out: ?struct {
                nread: isize,
            } = null,

            fn init(userbuf: []u8) @This() {
                return .{
                    .frame = coro.xframe(),
                    .userbuf = userbuf,
                };
            }

            fn alloc(h: [*c]uv.uv_handle_t, suggested_size: usize, uvbuf: [*c]uv.uv_buf_t) callconv(.C) void {
                _ = suggested_size;
                const data = uv.getHandleData(h, @This());
                uvbuf.*.base = data.userbuf.ptr;
                uvbuf.*.len = data.userbuf.len;
            }

            fn read(h: *anyopaque, nread: isize, uvbuf: [*c]const uv.uv_buf_t) callconv(.C) void {
                _ = uvbuf;
                const data = uv.getHandleData(@as(*uv.uv_stream_t, @ptrCast(@alignCast(h))), @This());
                data.out = .{
                    .nread = nread,
                };
                coro.xresume(data.frame);
            }
        };

        log.debug("stream read", .{});
        var data = Data.init(buf);
        uv.setHandleData(self.handle, &data);
        try uv.check(uv.uv_read_start(self.handle, Data.alloc, Data.read));
        coro.xsuspend();
        _ = uv.uv_read_stop(self.handle);
        const nread = data.out.?.nread;
        if (nread == uv.UV_EOF) {
            log.debug("stream read done", .{});
            return 0;
        }
        log.debug("stream read n={d}", .{nread});
        try uv.check(nread);
        return @intCast(nread);
    }

    fn shutdown(self: @This()) !void {
        const Data = struct {
            frame: coro.Frame,
            status: ?c_int = null,

            fn init() @This() {
                return .{ .frame = coro.xframe() };
            }
            fn cb(req: [*c]uv.uv_shutdown_t, status: c_int) callconv(.C) void {
                var data = uv.getHandleData(req.handle, @This());
                data.status = status;
                coro.xresume(data.frame);
            }
        };

        var req = uv.uv_shutdown_t{};
        var data = Data.init();
        uv.setHandleData(self.handle, &data);

        try uv.check(uv.uv_shutdown(&req, self.handle, Data.cb));
        coro.xsuspend();
        try uv.check(data.status.?);
    }

    const Listener = struct {
        parent: Stream,
        backlog: c_int,
        frame: ?coro.Frame = null,
        status: ?c_int = 0,

        pub fn next(self: *@This()) !?void {
            if (self.frame == null) {
                self.frame = coro.xframe();
                uv.setHandleData(self.parent.handle, self);
                try uv.check(uv.uv_listen(self.parent.handle, self.backlog, cb));
                log.debug("listen begin", .{});
            }
            while (self.status == null) coro.xsuspend();
            if (self.status != 0) return error.StreamConnectFailed;
            log.debug("new connection", .{});
            self.status = null;
        }

        fn cb(s: [*c]uv.uv_stream_t, status: c_int) callconv(.C) void {
            var self = uv.getHandleData(s, @This());
            self.status = status;
            coro.xresume(self.frame.?);
        }
    };

    pub fn listener(self: @This(), backlog: c_int) Listener {
        return .{ .parent = self, .backlog = backlog };
    }
};

pub const TTY = struct {
    handle: uv.uv_tty_t,

    pub fn init(self: *@This(), loop: *uv.uv_loop_t, fd: uv.uv_file) !void {
        self.* = .{
            .handle = .{},
        };
        try uv.check(uv.uv_tty_init(loop, &self.handle, fd, 0));
    }

    pub fn deinit(self: *@This()) void {
        uv.uv_close(&self.handle, null);
    }

    pub fn stream(self: *@This()) Stream {
        return .{
            .handle = @ptrCast(&self.handle),
        };
    }

    const WinSize = struct {
        width: c_int,
        height: c_int,
    };
    pub fn winsize(self: @This()) !WinSize {
        var width: c_int = 0;
        var height: c_int = 0;
        try uv.check(uv.uv_tty_get_winsize(self.handle, &width, &height));
        return .{
            .width = width,
            .height = height,
        };
    }
};

pub const Pipe = struct {
    handle: uv.uv_pipe_t,

    pub fn init(self: *@This(), loop: *uv.uv_loop_t, ipc: bool) !void {
        self.* = .{
            .handle = .{},
        };
        try uv.check(uv.uv_pipe_init(loop, &self.handle, @intFromBool(ipc)));
    }

    pub fn close(self: *@This()) void {
        var closer = Closer.init();
        closer.close(@ptrCast(&self.handle));
    }

    pub fn stream(self: *@This()) Stream {
        return .{
            .handle = @ptrCast(&self.handle),
        };
    }

    pub fn open(self: *@This(), file: uv.uv_file) !void {
        try uv.check(uv.uv_pipe_open(&self.handle, file));
    }

    pub fn bind(self: *@This(), name: []const u8) !void {
        try uv.check(uv.uv_pipe_bind2(&self.handle, name.ptr, name.len, 0));
    }

    pub fn connect(self: *@This(), name: []const u8) !void {
        const Data = struct {
            frame: coro.Frame,
            status: ?c_int = null,

            fn init() @This() {
                return .{ .frame = coro.xframe() };
            }
            fn cb(req: [*c]uv.uv_connect_t, status: c_int) callconv(.C) void {
                var data = uv.getHandleData(req.handle, @This());
                data.status = status;
                coro.xresume(data.frame);
            }
        };

        var req = uv.uv_connect_t{};
        var data = Data.init();
        uv.setHandleData(&self.handle, &data);
        try uv.uv_pipe_connect2(&req, &self.handle, name.ptr, name.len, 0, Data.cb);
        coro.xsuspend();
        try uv.check(data.status.?);
    }

    const PipePairOpts = struct {
        read_nonblock: bool = false,
        write_nonblock: bool = false,
    };
    pub fn makepair(opts: PipePairOpts) ![2]uv.file {
        var out: [2]uv.file = undefined;
        try uv.check(
            uv.uv_pipe(
                &out,
                if (opts.read_nonblock) uv.UV_NONBLOCK_PIPE else 0,
                if (opts.write_nonblock) uv.UV_NONBLOCK_PIPE else 0,
            ),
        );
        return out;
    }
};

pub const TCP = struct {
    handle: uv.uv_tcp_t,

    pub fn init(self: *@This(), loop: *uv.uv_loop_t) !void {
        try uv.check(uv.uv_tcp_init(loop, &self.handle));
    }

    pub fn close(self: *@This()) void {
        var closer = Closer.init();
        closer.close(@ptrCast(&self.handle));
    }

    pub fn stream(self: *@This()) Stream {
        return .{
            .handle = @ptrCast(&self.handle),
        };
    }

    pub fn connect(self: *@This(), sockaddr: *uv.sockaddr) !void {
        const Data = struct {
            frame: coro.Frame,
            status: ?c_int = null,

            fn init() @This() {
                return .{ .frame = coro.xframe() };
            }
            fn cb(req: [*c]uv.uv_connect_t, status: c_int) callconv(.C) void {
                var data = uv.getHandleData(req.*.handle, @This());
                data.status = status;
                coro.xresume(data.frame);
            }
        };

        var req = uv.uv_connect_t{};
        var data = Data.init();
        uv.setHandleData(&self.handle, &data);
        try uv.check(uv.uv_tcp_connect(&req, &self.handle, sockaddr, Data.cb));
        coro.xsuspend();
        try uv.check(data.status.?);
    }

    const SocketPairOpts = struct {
        sock0_nonblock: bool = false,
        sock1_nonblock: bool = false,
    };
    pub fn makepair(stype: c_int, opts: SocketPairOpts) ![2]uv.uv_os_sock_t {
        var out: [2]uv.uv_os_sock_t = undefined;
        try uv.check(
            uv.uv_socketpair(stype, 0, &out, if (opts.sock0_nonblock) uv.UV_NONBLOCK_PIPE else 0, if (opts.sock1_nonblock) uv.UV_NONBLOCK_PIPE else 0),
        );
        return out;
    }

    const IpPort = struct {
        ip: []const u8,
        port: c_ushort,
    };
    pub fn getpeername(self: *@This(), addr_storage: *uv.sockaddr_storage) !?IpPort {
        return try self.getxname(addr_storage, .peer);
    }

    pub fn getsockname(self: *@This(), addr_storage: *uv.sockaddr_storage) !?IpPort {
        return try self.getxname(addr_storage, .sock);
    }

    pub fn getxname(self: *@This(), addr_storage: *uv.sockaddr_storage, xtype: enum { peer, sock }) !?IpPort {
        var addr_size: c_int = @sizeOf(uv.sockaddr_storage);
        switch (xtype) {
            .peer => try uv.check(uv.uv_tcp_getpeername(&self.handle, @ptrCast(addr_storage), &addr_size)),
            .sock => try uv.check(uv.uv_tcp_getsockname(&self.handle, @ptrCast(addr_storage), &addr_size)),
        }

        if (addr_storage.ss_family == uv.AF_INET) {
            const addr: *uv.sockaddr_in = @ptrCast(@alignCast(addr_storage));
            var ipbuf: [201:0]u8 = undefined;
            try uv.check(uv.uv_ip4_name(addr, &ipbuf, ipbuf.len));
            const iplen = std.mem.len(@as([*:0]u8, @ptrCast(&ipbuf)));
            const ip = ipbuf[0..iplen];

            const port = std.mem.bigToNative(c_ushort, addr.sin_port);

            return .{ .ip = ip, .port = port };
        } else if (addr_storage.ss_family == uv.AF_INET6) {
            const addr: *uv.sockaddr_in6 = @ptrCast(@alignCast(addr_storage));
            var ipbuf: [201:0]u8 = undefined;
            try uv.check(uv.uv_ip6_name(addr, &ipbuf, ipbuf.len));
            const iplen = std.mem.len(@as([*:0]u8, @ptrCast(&ipbuf)));
            const ip = ipbuf[0..iplen];

            const port = std.mem.bigToNative(c_ushort, addr.sin6_port);

            return .{ .ip = ip, .port = port };
        } else {
            return null;
        }
    }
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
