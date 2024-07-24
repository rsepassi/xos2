const std = @import("std");
const uv = @import("uv.zig");
const uv_common = @import("common.zig");
const coro = @import("zigcoro");

const log = std.log.scoped(.uvzig);

const uv_udp_recv_cb = struct {
    const Read = struct {
        msg: []const u8,
        addr: std.net.Address,
        flags: c_uint,
    };
    frame: coro.Frame,
    buf: []u8,
    err_code: ?isize,
    read: ?Read = null,

    fn init(self: *@This(), buf: []u8) void {
        self.frame = coro.xframe();
        self.buf = buf;
    }

    fn alloc_cb(handle: [*c]uv.uv_handle_t, ssize: usize, buf: [*c]uv.uv_buf_t) callconv(.C) void {
        const self = uv.getHandleData(handle, @This());
        _ = ssize;
        buf.* = uv.newbuf(self.buf);
    }

    fn read_cb(
        handle: [*c]uv.uv_udp_t,
        nread: isize,
        buf: [*c]const uv.uv_buf_t,
        addr: [*c]const uv.sockaddr,
        flags: c_uint,
    ) callconv(.C) void {
        const self = uv.getReqData(handle, @This());
        _ = buf;
        if (nread < 0) {
            self.err_code = nread;
            self.read = null;
        } else if (nread == 0 and @intFromPtr(addr) == 0) {
            self.err_code = null;
            self.read = null;
        } else {
            self.err_code = null;
            self.read = .{
                .msg = self.buf[0..@intCast(nread)],
                .addr = std.net.Address.initPosix(@ptrCast(@alignCast(addr))),
                .flags = flags,
            };
        }
        coro.xresume(self.frame);
    }
};

const uv_udp_send_cb = struct {
    frame: coro.Frame,
    req: uv.uv_udp_send_t,
    status: c_int = 0,

    fn init(self: *@This()) void {
        uv.setReqData(&self.req, self);
        self.frame = coro.xframe();
    }

    fn cb(req: [*c]uv.uv_udp_send_t, status: c_int) callconv(.C) void {
        const self = uv.getReqData(req, @This());
        self.status = status;
        coro.xresume(self.frame);
    }
};

pub const UDP = struct {
    handle: uv.uv_udp_t,

    pub fn init(self: *@This(), loop: *uv.uv_loop_t) !void {
        try uv.check(uv.uv_udp_init(loop, &self.handle));
    }

    pub fn close(self: *@This()) void {
        var cb: uv_common.uv_close_cb = undefined;
        cb.init(@ptrCast(&self.handle));
        uv.uv_close(@ptrCast(&self.handle), uv_common.uv_close_cb.cb);
        coro.xsuspend();
    }

    pub const Recv = struct {
        udp: *UDP,
        state: uv_udp_recv_cb,
        receiving: bool = false,

        pub fn init(self: *@This(), udp: *UDP, buf: []u8) !void {
            self.udp = udp;
            self.state.init(buf);
        }

        pub fn stop(self: *@This()) void {
            self.receiving = false;
            _ = uv.uv_udp_recv_stop(&self.udp.handle);
        }

        pub fn recv(self: *@This()) !?uv_udp_recv_cb.Read {
            uv.setHandleData(&self.udp.handle, &self.state);
            if (!self.receiving) {
                try uv.check(uv.uv_udp_recv_start(
                    &self.udp.handle,
                    uv_udp_recv_cb.alloc_cb,
                    uv_udp_recv_cb.read_cb,
                ));
                self.receiving = true;
            }
            coro.xsuspend();
            if (self.state.err_code) |code| {
                try uv.check(code);
                unreachable;
            } else {
                return self.state.read;
            }
        }

        pub fn recvAlloc(self: *@This(), alloc: std.mem.Allocator) !uv_udp_recv_cb.Read {
            var list = std.ArrayList(u8).init(alloc);
            var out: uv_udp_recv_cb.Read = undefined;
            while (try self.recv()) |read| {
                out.flags = read.flags;
                out.addr = read.addr;
                try list.appendSlice(read.msg);
            }

            out.msg = try list.toOwnedSlice();
            return out;
        }
    };

    pub fn send(self: *@This(), buf: []const u8, dst: ?*const uv.sockaddr) !void {
        var req: uv_udp_send_cb = undefined;
        req.init();
        var uvbuf = uv.uv_buf_t{
            .base = @constCast(buf.ptr),
            .len = buf.len,
        };
        try uv.check(uv.uv_udp_send(&req.req, &self.handle, &uvbuf, 1, dst, uv_udp_send_cb.cb));
        coro.xsuspend();
        try uv.check(req.status);
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
            .peer => try uv.check(uv.uv_udp_getpeername(&self.handle, @ptrCast(addr_storage), &addr_size)),
            .sock => try uv.check(uv.uv_udp_getsockname(&self.handle, @ptrCast(addr_storage), &addr_size)),
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
