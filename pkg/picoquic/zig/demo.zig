const std = @import("std");
const log = std.log.scoped(.demo);
const Quic = @import("Quic");
const uv = @import("uv");
const coro = @import("coro");

const Ctx = struct {
    allocator: std.mem.Allocator,
    quic: Quic = undefined,
};
fn cb() Quic.CallbackError!void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leak = gpa.deinit();
        if (leak == .leak) log.debug("leak!", .{});
    }
    const allocator = gpa.allocator();
    coro.initEnv(.{
        .stack_allocator = allocator,
        .default_stack_size = 1024 * 128,
    });

    const loop = uv.c.uv_default_loop();
    defer uv.check(uv.c.uv_loop_close(loop)) catch @panic("loop close failed");
    defer uv.debugWalk(loop);

    var socket: uv.c.uv_udp_t = undefined;
    try uv.check(uv.c.uv_udp_init(loop, &socket));
    defer uv.c.uv_close(@ptrCast(&socket), null);

    try uv.check(uv.c.uv_udp_recv_start(&socket, uvUdpAlloc, uvUdpRead));
    defer uv.check(uv.c.uv_udp_recv_stop(&socket)) catch @panic("could not stop udp");

    var addr: std.net.Address = undefined;
    var addr_len: c_int = 0;
    try uv.check(uv.c.uv_udp_getsockname(&socket, @ptrCast(&addr.any), &addr_len));

    var ctx: Ctx = .{ .allocator = allocator };
    var quic_ctx = Quic.Ctx{ .ptr = &ctx, .cb = cb };
    ctx.quic = try Quic.init(.{ .ctx = &quic_ctx });
    defer ctx.quic.deinit();

    var udpbuf: [Quic.max_packet_size]u8 = undefined;
    var udpctx = UdpCtx{
        .socket = &socket,
        .buf = &udpbuf,
        .quic = ctx.quic,
        .addr = &addr,
    };
    uv.setHandleData(&socket, &udpctx);

    const frame = try coro.xasync(runClient, .{&ctx}, null);
    defer frame.deinit();

    log.info("loop begin", .{});
    var active = true;
    while (active) {
        const live = uv.c.uv_run(loop, uv.c.UV_RUN_ONCE);
        active = live != 0;
    }
    log.info("loop exit", .{});

    try coro.xawait(frame);
}

fn runClient(ctx: *Ctx) !void {
    const server_addr = try std.net.Address.parseIp4("127.0.0.1", 4443);
    const cxn = try ctx.quic.connect(.{
        .addr = &server_addr,
    });
    defer cxn.deinit();

    const req_stream = cxn.getStream(0, .{ .server = false, .unidir = true });
    const resp_stream = cxn.getStream(0, .{ .server = true, .unidir = true });

    const writer = req_stream.writer();
    const reader = resp_stream.reader();

    // Send request
    {
        const reqbuf = try writer.prepareWrite();
        // TODO: write into reqbuf
        reqbuf.write();
    }

    // Receive response
    {
        var resp = std.ArrayList(u8).init(ctx.allocator);
        defer resp.deinit();
        while (try reader.read()) |msg| {
            try resp.appendSlice(msg);
        }
        log.debug("response: {s}", .{resp.items});
    }

    try cxn.close();
}

const UdpCtx = struct {
    socket: *uv.uv_udp_t,
    quic: Quic,
    buf: []u8,
    addr: *std.net.Address,
};

fn uvUdpAlloc(
    udp: [*c]uv.c.uv_handle_t,
    suggested_size: usize,
    buf: [*c]uv.c.uv_buf_t,
) callconv(.C) void {
    _ = suggested_size;
    const udpctx: *UdpCtx = @ptrCast(@alignCast(udp.*.data));
    buf.*.base = udpctx.buf.ptr;
    buf.*.len = udpctx.buf.len;
}

fn uvUdpRead(
    udp: [*c]uv.c.uv_udp_t,
    nread: isize,
    buf: [*c]const uv.c.uv_buf_t,
    addr: [*c]const uv.c.struct_sockaddr,
    flags: c_uint,
) callconv(.C) void {
    _ = flags;

    const udpctx: *UdpCtx = @ptrCast(@alignCast(udp.*.data));

    uv.check(nread) catch {
        // TODO: deliver error
        @panic("udp error");
    };

    if (@intFromPtr(addr) == 0) {
        udpctx.quic.incomingPacket(
            buf.*.base[0..@intCast(nread)],
            std.net.Address{ .any = @as(*const std.posix.sockaddr, @ptrCast(@alignCast(addr))).* },
            udpctx.addr.*,
        ) catch {
            @panic("quic incoming packet failed");
        };
    } else {
        std.debug.assert(nread == 0);
    }

    _ = quicSend(udpctx) catch @panic("send failed");
}

fn quicSend(udpctx: *UdpCtx) !bool {
    var local_addr: std.net.Address = undefined;
    var peer_addr: std.net.Address = undefined;
    var if_index: c_int = 0;
    var logcid: Quic.c.picoquic_connection_id_t = undefined;
    var buf: [Quic.max_packet_size]u8 = undefined;

    const maybe_send_buf = try udpctx.quic.nextPacket(
        &buf,
        &peer_addr,
        &local_addr,
        &if_index,
        &logcid,
    );
    if (maybe_send_buf) |send_buf| {
        const SendState = struct {
            rc: ?c_int = null,
            frame: coro.Frame,
            fn cb(handle: [*c]uv.c.uv_udp_send_s, rc: c_int) callconv(.C) void {
                const state = uv.getHandleData(handle, @This());
                state.rc = rc;
                coro.xresume(state.frame);
            }
            fn wait(self: @This()) !void {
                while (self.rc == null) coro.xsuspend();
                return uv.check(self.rc.?);
            }
        };
        var state = SendState{ .frame = coro.xframe() };
        var req: uv.c.uv_udp_send_t = undefined;
        req.data = &state;
        var uv_send_buf = uv.c.uv_buf_t{
            .base = send_buf.ptr,
            .len = send_buf.len,
        };
        try uv.check(uv.c.uv_udp_send(
            &req,
            udpctx.socket,
            &uv_send_buf,
            1,
            @ptrCast(@alignCast(&peer_addr.any)),
            SendState.cb,
        ));
        state.wait() catch {
            @panic("udp send failed");
        };
        return true;
    } else {
        return false;
    }
}
