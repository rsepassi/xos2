const c = @cImport(@cInclude("kv.h"));
const impl = @import("kv.zig");
const errors = @import("errors.zig");

comptime {
    KV(.{}).exportFns();
}

pub const Opts = struct {};

pub fn KV(opts: Opts) type {
    _ = opts;

    return struct {
        fn kv_init(init_opts: c.kv_init_opts, ctx: *c.kv_ctx) callconv(.C) c.kv_result {
            const ret = impl.KV.init(init_opts) catch |err| return errors.convertErr(err);
            ctx.* = @ptrCast(ret);
            return c.KV_OK;
        }

        fn kv_deinit(ctx: c.kv_ctx) callconv(.C) c.kv_result {
            getKV(ctx).deinit();
            return c.KV_OK;
        }

        fn kv_nrecords(ctx: c.kv_ctx) callconv(.C) u64 {
            return getKV(ctx).metadata.current.page.contents.metadata.nrecords;
        }

        fn kv_put(ctx: c.kv_ctx, key: c.kv_buf, val: c.kv_buf) callconv(.C) c.kv_result {
            getKV(ctx).put(fromBuf(key), fromBuf(val)) catch |err| return errors.convertErr(err);
            return c.KV_OK;
        }

        fn kv_get(ctx: c.kv_ctx, key: c.kv_buf, val: *c.kv_buf) callconv(.C) c.kv_result {
            var zval: []u8 = @as([*]u8, @ptrCast(val.buf))[0..val.len];
            getKV(ctx).get(fromBuf(key), &zval) catch |err| return errors.convertErr(err);
            val.len = zval.len;
            return c.KV_OK;
        }

        fn kv_del(ctx: c.kv_ctx, key: c.kv_buf) callconv(.C) c.kv_result {
            getKV(ctx).del(fromBuf(key)) catch |err| return errors.convertErr(err);
            return c.KV_OK;
        }

        fn kv_result_str(res: c.kv_result) callconv(.C) [*:0]const u8 {
            return errors.kv_result_strs[res].ptr;
        }

        fn exportFns() void {
            @export(kv_init, .{ .name = "kv_init", .linkage = .strong });
            @export(kv_deinit, .{ .name = "kv_deinit", .linkage = .strong });
            @export(kv_nrecords, .{ .name = "kv_nrecords", .linkage = .strong });
            @export(kv_put, .{ .name = "kv_put", .linkage = .strong });
            @export(kv_get, .{ .name = "kv_get", .linkage = .strong });
            @export(kv_del, .{ .name = "kv_del", .linkage = .strong });
            @export(kv_result_str, .{ .name = "kv_result_str", .linkage = .strong });
        }
    };
}

fn getKV(ctx: c.kv_ctx) *impl.KV {
    return @ptrCast(@alignCast(ctx));
}

fn fromBuf(buf: c.kv_buf) []u8 {
    var p: [*]u8 = @ptrCast(buf.buf);
    return p[0..buf.len];
}
