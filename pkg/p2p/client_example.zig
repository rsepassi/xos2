// 207.154.225.255:40000
// udp
// send: swarmID|clientID
// recv: json:
// {"clients":[{"id":"90EDEEEC5B2B478AA39E6109AD56361F","ip":"75.164.192.63","port":"49326"},{"id":"D70FD6434B9A402BB584345868613EBD","ip":"73.11.33.119","port":"21891"},{"id":"667D380790474F25A508F11DF20E455E","ip":"75.164.192.63","port":"38956"},{"id":"05F9D475A1FC4F2F8A7AB880A55CA12C","ip":"67.161.109.113","port":"52714"},{"id":"575C74DDFA3042A384E81219B1111163","ip":"73.11.33.119","port":"1050"}]}

// todo:
// * UV_UDP_RECVMMSG
// * uv_udp_bind
// * uv_udp_connect, uv_udp_getpeername
// * uv_udp_getsockname: me
// * uv_udp_set_broadcast
// * uv_udp_set_ttl
// * uv_udp_send
// * uv_udp_recv_start, uv_udp_recv_stop

const std = @import("std");
const uv = @import("uv");
const zcoro = @import("zigcoro");

const Ctx = struct {
    allocator: std.mem.Allocator,
    loop: *uv.uv_loop_t,
};

pub fn main() !void {
    std.debug.print("hi\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("leak!\n", .{});
    const allocator = gpa.allocator();

    zcoro.initEnv(.{
        .stack_allocator = allocator,
        .default_stack_size = 32768,
    });

    var loop: uv.uv_loop_t = undefined;
    try uv.check(uv.uv_loop_init(&loop));

    var ctx = Ctx{
        .allocator = allocator,
        .loop = &loop,
    };
    const frame = try zcoro.xasync(run, .{&ctx}, null);
    defer frame.deinit();

    try uv.check(uv.uv_run(&loop, uv.UV_RUN_DEFAULT));
    defer _ = uv.uv_loop_close(&loop);
}

fn run(ctx: *Ctx) !void {
    var udp: uv.coro.UDP = undefined;
    try udp.init(ctx.loop);
    defer udp.close();

    const me = try std.net.Ip4Address.parse("0.0.0.0", 8912);
    try uv.check(uv.uv_udp_bind(&udp.handle, @ptrCast(&me), 0));

    const discovery = try std.net.Ip4Address.parse("207.154.225.255", 40000);
    try udp.send("xos|xos0", @ptrCast(&discovery));

    var recv_buf: [1024]u8 = undefined;
    var recv: uv.coro.UDP.Recv = undefined;
    try recv.init(&udp, &recv_buf);
    defer recv.stop();

    const read = try recv.recvAlloc(ctx.allocator);
    defer ctx.allocator.free(read.msg);
    std.debug.print("recv {any} ({d}): {s}\n", .{ read.addr, read.msg.len, read.msg });

    // todo:
    // * loop discovery until peer is present
    // * simultaneous:
    //   * send message to peer
    //   * listen for messages from peer
    // * fallback to libplum
    // * LAN connections
}
