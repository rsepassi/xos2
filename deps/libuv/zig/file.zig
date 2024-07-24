const std = @import("std");
const uv = @import("uv.zig");
const coro = @import("zigcoro");

const log = std.log.scoped(.uvzig);

pub const File = struct {
    loop: *uv.uv_loop_t,
    fd: c_int,

    const Data = struct {
        frame: coro.Frame,
        done: bool = false,
        fn init() @This() {
            return .{ .frame = coro.xframe() };
        }
    };

    pub fn open(loop: *uv.uv_loop_t, path: [:0]const u8, flags: c_int, mode: c_int) !@This() {
        log.debug("open {s} flags={b} mode={o}", .{ path, flags, mode });
        var data = Data.init();
        var req = uv.uv_fs_t{};
        defer uv.uv_fs_req_cleanup(&req);
        uv.setReqData(&req, &data);
        try uv.check(uv.uv_fs_open(loop, &req, path, flags, mode, xresume));
        while (!data.done) coro.xsuspend();
        try uv.check(req.result);

        return .{
            .loop = loop,
            .fd = @intCast(req.result),
        };
    }

    pub fn close(self: @This()) void {
        var req = uv.uv_fs_t{};
        defer uv.uv_fs_req_cleanup(&req);
        var data = Data.init();
        uv.setReqData(&req, &data);
        uv.check(uv.uv_fs_close(self.loop, &req, self.fd, xresume)) catch {};
        coro.xsuspend();
    }

    fn xresume(req: [*c]uv.uv_fs_t) callconv(.C) void {
        const data = uv.getReqData(req, Data);
        data.done = true;
        coro.xresume(data.frame);
    }

    const Error = error{
        Read,
        Write,
    } || uv.Error;
    const Reader = std.io.Reader(@This(), Error, read);

    fn read(self: @This(), buf: []u8) Error!usize {
        log.debug("read {d}", .{buf.len});
        var req = uv.uv_fs_t{};
        defer uv.uv_fs_req_cleanup(&req);
        var data = Data.init();
        uv.setReqData(&req, &data);
        var uvbuf = uv.newbuf(buf);
        try uv.check(uv.uv_fs_read(self.loop, &req, self.fd, &uvbuf, 1, -1, xresume));
        coro.xsuspend();
        if (req.result < 0) {
            return Error.Read;
        } else {
            return @intCast(req.result);
        }
    }

    const Writer = std.io.Writer(@This(), Error, write);

    fn write(self: @This(), buf: []const u8) Error!usize {
        log.debug("write", .{});
        var req = uv.uv_fs_t{};
        defer uv.uv_fs_req_cleanup(&req);
        var data = Data.init();
        uv.setReqData(&req, &data);
        var uvbuf = uv.newbuf(@constCast(buf));
        try uv.check(uv.uv_fs_write(self.loop, &req, self.fd, &uvbuf, 1, -1, xresume));
        coro.xsuspend();
        if (req.result < 0) {
            return Error.Write;
        } else {
            return @intCast(req.result);
        }
    }

    pub fn writer(self: @This()) Writer {
        return .{ .context = self };
    }

    pub fn reader(self: @This()) Reader {
        return .{ .context = self };
    }

    pub fn stat(self: @This()) !uv.uv_stat_t {
        var req = uv.uv_fs_t{};
        defer uv.uv_fs_req_cleanup(&req);
        var data = Data.init();
        uv.setReqData(&req, &data);
        try uv.check(uv.uv_fs_fstat(self.loop, &req, self.fd, xresume));
        coro.xsuspend();
        try uv.check(req.result);
        return uv.uv_fs_get_statbuf(&req).*;
    }

    pub fn fsync(self: @This()) !void {
        var req = uv.uv_fs_t{};
        defer uv.uv_fs_req_cleanup(&req);
        var data = Data.init();
        uv.setReqData(&req, &data);
        try uv.check(uv.uv_fs_fsync(self.loop, &req, self.fd, xresume));
        coro.xsuspend();
        try uv.check(req.result);
    }

    pub fn sendfile(self: @This(), dst: c_int, src_offset: ?usize, n: usize) !usize {
        log.debug("send {d}", .{n});
        var req = uv.uv_fs_t{};
        defer uv.uv_fs_req_cleanup(&req);
        var data = Data.init();
        uv.setReqData(&req, &data);

        try uv.check(uv.uv_fs_sendfile(self.loop, &req, dst, self.fd, @intCast(src_offset orelse 0), n, xresume));
        coro.xsuspend();

        try uv.check(req.result);
        return @intCast(req.result);
    }

    // TODO:
    // chown
    // utime
    // chmod
    // datasync
};

pub const fs = struct {
    pub fn mkdir(loop: *uv.uv_loop_t, path: [:0]const u8, mode: c_int) !void {
        var req: uv_fs_cb = undefined;
        req.init();
        defer req.deinit();
        try uv.check(uv.uv_fs_mkdir(loop, &req.req, path.ptr, mode, uv_fs_cb.cb));
        coro.xsuspend();
    }

    pub fn mkdtemp(loop: *uv.uv_loop_t, tpl: [:0]const u8, out: []u8) ![:0]const u8 {
        var req: uv_fs_cb = undefined;
        req.init();
        defer req.deinit();
        try uv.check(uv.uv_fs_mkdtemp(loop, &req.req, tpl.ptr, uv_fs_cb.cb));
        coro.xsuspend();
        const n = std.mem.len(req.req.path);
        if (n >= out.len) return error.BufTooSmall;
        std.mem.copyForwards(u8, out, req.req.path[0..n]);
        out[n] = 0;
        return out[0..n :0];
    }

    const TmpFileInfo = struct {
        path: ?[:0]const u8,
        fd: uv.uv_file,
    };
    pub fn mkstemp(loop: *uv.uv_loop_t, tpl: [:0]const u8, out: ?[]u8) !TmpFileInfo {
        var req: uv_fs_cb = undefined;
        req.init();
        defer req.deinit();
        try uv.check(uv.uv_fs_mkstemp(loop, &req.req, tpl.ptr, uv_fs_cb.cb));
        coro.xsuspend();
        var info = TmpFileInfo{ .path = null, .fd = @intCast(req.req.result) };
        if (out) |buf| {
            const n = std.mem.len(req.req.path);
            if (n >= buf.len) return error.BufTooSmall;
            std.mem.copyForwards(u8, buf, req.req.path[0..n]);
            buf[n] = 0;
            info.path = buf[0..n :0];
        }
        return info;
    }
};

const uv_fs_cb = struct {
    frame: coro.Frame,
    req: uv.uv_fs_t,

    fn init(self: *@This()) void {
        uv.setReqData(&self.req, self);
        self.frame = coro.xframe();
    }

    fn deinit(self: @This()) void {
        uv.uv_fs_req_cleanup(@constCast(&self.req));
    }

    fn cb(req: [*c]uv.uv_fs_t) callconv(.C) void {
        const self = uv.getReqData(req, @This());
        coro.xresume(self.frame);
    }
};
