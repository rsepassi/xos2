const std = @import("std");
const log = std.log.scoped(.quic);

const coro = @import("coro");

pub const c = @cImport(@cInclude("picoquic.h"));
pub const max_packet_size = c.PICOQUIC_MAX_PACKET_SIZE;

const Quic = @This();

quic: *c.picoquic_quic_t,

pub const Ctx = struct {
    cb: Callback,
    ptr: ?*anyopaque = null,
    quic: ?*c.picoquic_quic_t = null,
};

pub const CallbackError = error{};
pub const Callback = *const fn () CallbackError!void;
pub const InitOpts = struct {
    ctx: *Ctx,
    max_connections: u32 = 1024,
    cert_fname: ?[:0]const u8 = null,
    key_fname: ?[:0]const u8 = null,
    cert_root_fname: ?[:0]const u8 = null,
    default_alpn: [:0]const u8 = "picoquic-xos",
    ticket_fname: ?[:0]const u8 = null,
    ticket_encryption_key: ?[]const u8 = null,
};

pub fn init(opts: InitOpts) !Quic {
    const quic = c.picoquic_create(
        opts.max_connections,
        if (opts.cert_fname) |f| f.ptr else null,
        if (opts.key_fname) |f| f.ptr else null,
        if (opts.cert_root_fname) |f| f.ptr else null,
        opts.default_alpn.ptr,
        quic_callback,
        opts.ctx,
        null, // cnx_id_callback
        null, // cnx_id_callback_data
        null, // reset_seed
        c.picoquic_current_time(),
        null,
        if (opts.ticket_fname) |f| f.ptr else null,
        if (opts.ticket_encryption_key) |f| f.ptr else null,
        if (opts.ticket_encryption_key) |f| f.len else 0,
    ) orelse return error.QuicCreate;
    return .{ .quic = quic };
}

pub fn deinit(self: Quic) void {
    c.picoquic_free(self.quic);
}

pub const Cxn = struct {
    quic: *const Quic,
    cxn: *c.picoquic_cnx_t,
    free_on_deinit: bool = false,

    pub fn deinit(self: @This()) void {
        if (self.free_on_deinit) c.picoquic_delete_cnx(self.cxn);
    }

    pub fn close(self: @This()) !void {
        return self.closeCode(0);
    }

    pub fn closeCode(self: @This(), code: u64) !void {
        const rc = c.picoquic_close(self.cxn, code);
        if (rc != 0) return error.QuicCxnClose;
    }

    pub fn closeImmediate(self: @This()) void {
        c.picoquic_close_immediate(self.cxn);
    }

    pub const StreamOpts = struct {
        server: bool,
        unidir: bool,
    };

    pub fn getStream(self: *const @This(), id: u64, opts: StreamOpts) Stream {
        const unidir: u64 = if (opts.unidir) 2 else 0;
        const server: u64 = if (opts.server) 1 else 0;
        const stream_id = (id << 2) | unidir | server;
        return .{ .cxn = self, .id = stream_id };
    }
};

pub const StreamError = error{
    QuicStreamUnimpl,
    QuicActivateStream,
};

pub const Stream = struct {
    cxn: *const Cxn,
    id: u64,

    pub fn reader(self: *const @This()) Reader {
        return .{ .stream = self };
    }

    pub fn writer(self: *const @This()) Writer {
        return .{ .stream = self };
    }

    pub const Reader = struct {
        stream: *const Stream,

        pub fn read(self: @This()) StreamError!?[]const u8 {
            _ = self;
            return error.QuicStreamUnimpl;
        }
    };

    pub const Writer = struct {
        stream: *const Stream,

        pub const Buffer = struct {
            stream: *const Stream,
            buf: []u8,

            pub fn write(self: @This()) void {
                _ = self;
            }
        };

        pub fn prepareWrite(self: *const @This()) StreamError!Buffer {
            const rc = c.picoquic_mark_active_stream(
                self.stream.cxn.cxn,
                self.stream.id,
                1,
                @constCast(self.stream),
            );
            if (rc != 0) return error.QuicActivateStream;

            // Sleep until event prepare_to_send or error
            // Buffer pointer delivered
            // Return it in Buffer

            return error.QuicStreamUnimpl;
        }
    };
};

pub const ClientOpts = struct {
    addr: *const std.net.Address,
    sni: ?[:0]const u8 = "test.example.com",
    alpn: ?[:0]const u8 = "picoquic-xos",
};

pub fn connect(self: *const Quic, opts: ClientOpts) !Cxn {
    const cxn = c.picoquic_create_client_cnx(
        self.quic,
        @ptrCast(@constCast(&opts.addr.any)),
        c.picoquic_current_time(),
        0,
        if (opts.sni) |f| f.ptr else null,
        if (opts.alpn) |f| f.ptr else null,
        null,
        null,
    ) orelse return error.QuicCxnCreate;
    return .{ .cxn = cxn, .free_on_deinit = true, .quic = self };
}

fn quic_callback(
    cnx: ?*c.picoquic_cnx_t,
    stream_id: u64,
    cbytes: [*c]u8,
    cbyteslen: usize,
    fin_or_event: c.picoquic_call_back_event_t,
    callback_ctx: ?*anyopaque,
    stream_ctx: ?*anyopaque,
) callconv(.C) c_int {
    _ = cnx;

    // Have I seen the cnx before?
    //   For client, always yes
    //   For server, need to wake cxn waiter

    const event: CallbackEvent = @enumFromInt(fin_or_event);
    const ctx: *Ctx = @ptrCast(@alignCast(callback_ctx));
    const sctx: ?*Stream = if (stream_ctx) |s| @as(*Stream, @ptrCast(@alignCast(s))) else null;
    const bytes: ?[]u8 = if (cbytes) |b| b[0..cbyteslen] else null;

    _ = ctx;
    _ = sctx;
    _ = bytes;
    _ = stream_id;

    switch (event) {
        .stream_data, .stream_fin => |e| {
            // Stream delivery
            log.debug("event {s}", .{@tagName(e)});
        },
        .prepare_to_send => |e| {
            // Deliver the event, passing length (which is max_bytes)
            // SUSPEND
            // User fills (nsend, is_fin, stay_active)
            // RESUME
            const nsend = cbyteslen;
            const is_fin = true;
            const stay_active = false;
            const maybe_cbuf = c.picoquic_provide_stream_data_buffer(
                cbytes,
                nsend,
                @intFromBool(is_fin),
                @intFromBool(stay_active),
            );
            if (maybe_cbuf) |cbuf| {
                const buf = cbuf[0..nsend];
                _ = buf;
            } else {
                // set error
            }

            // SUSPEND
            // User fills buffer
            // RESUME

            // Stream write
            log.debug("event {s}", .{@tagName(e)});
        },
        .stream_reset, .stop_sending => |e| {
            // Stream close
            log.debug("event {s}", .{@tagName(e)});
        },
        .stateless_reset, .close, .application_close => |e| {
            // Connection close
            log.debug("event {s}", .{@tagName(e)});
        },
        .datagram => |e| {
            // Datagram delivery
            log.debug("event {s}", .{@tagName(e)});
        },
        .prepare_datagram => |e| {
            // Datagram write
            log.debug("event {s}", .{@tagName(e)});
        },
        .stream_gap,
        .almost_ready,
        .ready,
        .version_negotiation,
        .request_alpn_list,
        .set_alpn,
        .pacing_changed,
        .datagram_acked,
        .datagram_lost,
        .datagram_spurious,
        .path_available,
        .path_suspended,
        .path_deleted,
        .path_quality_changed,
        => |e| {
            log.debug("unhandled event {s}", .{@tagName(e)});
        },
    }

    return 0;
}

const CallbackEvent = enum(c_uint) {
    stream_data,
    stream_fin,
    stream_reset,
    stop_sending,
    stateless_reset,
    close,
    application_close,
    stream_gap,
    prepare_to_send,
    almost_ready,
    ready,
    datagram,
    version_negotiation,
    request_alpn_list,
    set_alpn,
    pacing_changed,
    prepare_datagram,
    datagram_acked,
    datagram_lost,
    datagram_spurious,
    path_available,
    path_suspended,
    path_deleted,
    path_quality_changed,
};

pub fn incomingPacket(
    self: @This(),
    pkt: []u8,
    peer: std.net.Address,
    local: std.net.Address,
) !void {
    const rc = c.picoquic_incoming_packet(
        self.quic,
        pkt.ptr,
        pkt.len,
        @ptrCast(@constCast(&peer.any)),
        @ptrCast(@constCast(&local.any)),
        0, // if_index_to,
        0, // received_ecn,
        c.picoquic_get_quic_time(self.quic),
    );
    if (rc != 0) return error.QuicIncomingPacket;
}

pub inline fn getTime(self: @This()) u64 {
    return c.picoquic_get_quic_time(self.quic);
}

pub fn nextPacket(
    self: @This(),
    buf: []u8,
    peer: *std.net.Address,
    local: *std.net.Address,
    if_index: *c_int,
    logcid: *c.picoquic_connection_id_t,
) !?[]u8 {
    var len: usize = 0;
    var last_cnx: ?*c.picoquic_cnx_t = null;
    const rc = c.picoquic_prepare_next_packet(
        self.quic,
        self.getTime(),
        buf.ptr,
        buf.len,
        &len,
        @ptrCast(@alignCast(&peer.any)),
        @ptrCast(@alignCast(&local.any)),
        if_index,
        logcid,
        &last_cnx,
    );
    if (rc != 0) return error.QuicNextPacket;
    if (len <= 0) return null;
    return buf[0..len];
}
