const std = @import("std");
const c = @cImport(@cInclude("wren.h"));

const Sha256 = std.crypto.hash.sha2.Sha256;
const Blake3 = std.crypto.hash.Blake3;

fn WrenHash(comptime T: type) type {
    return struct {
        fn alloc(vm: ?*c.WrenVM) callconv(.C) void {
            const hash: *T = @ptrCast(@alignCast(c.wrenSetSlotNewForeign(vm, 0, 0, @sizeOf(T))));
            hash.* = T.init(.{});
        }

        fn update(vm: ?*c.WrenVM) callconv(.C) void {
            var hasher: *T = @ptrCast(@alignCast(c.wrenGetSlotForeign(vm, 0)));

            var bytes_len: c_int = 0;
            var bytes_ptr = c.wrenGetSlotBytes(vm, 1, &bytes_len);
            const bytes = bytes_ptr[0..@intCast(bytes_len)];

            hasher.update(bytes);
        }

        fn finalHex(vm: ?*c.WrenVM) callconv(.C) void {
            var hasher: *T = @ptrCast(@alignCast(c.wrenGetSlotForeign(vm, 0)));

            var digest: [T.digest_length]u8 = undefined;
            hasher.final(&digest);

            const digest_hex = std.fmt.bytesToHex(digest, .lower);
            var cdigest_hex: [digest_hex.len + 1]u8 = undefined;
            std.mem.copyForwards(u8, cdigest_hex[0..digest_hex.len], &digest_hex);
            cdigest_hex[cdigest_hex.len - 1] = 0;

            c.wrenEnsureSlots(vm, 1);
            c.wrenSetSlotString(vm, 0, &cdigest_hex);
        }

        fn bindMethod(isStatic: bool, sig: []const u8) c.WrenForeignMethodFn {
            if (!isStatic) {
                if (std.mem.eql(u8, sig, "update(_)")) return update;
                if (std.mem.eql(u8, sig, "finalHex()")) return finalHex;
            }
            return null;
        }
    };
}

export fn wrenHashSource() [*c]const u8 {
    const src = @embedFile("hash.wren");
    return @ptrCast(src);
}

export fn wrenHashBindForeignMethod(
    vm: *c.WrenVM,
    cclassName: [*c]const u8,
    isStatic: bool,
    csig: [*c]const u8,
) c.WrenForeignMethodFn {
    _ = vm;
    const className = std.mem.span(cclassName);
    const sig = std.mem.span(csig);

    if (std.mem.eql(u8, className, "Sha256")) {
        return WrenHash(Sha256).bindMethod(isStatic, sig);
    }
    if (std.mem.eql(u8, className, "Blake3")) {
        return WrenHash(Blake3).bindMethod(isStatic, sig);
    }

    return null;
}

export fn wrenHashBindForeignClass(
    vm: *c.WrenVM,
    cmodule: [*c]const u8,
    cclassName: [*c]const u8,
) c.WrenForeignClassMethods {
    _ = vm;
    _ = cmodule;

    const className = std.mem.span(cclassName);

    if (std.mem.eql(u8, className, "Sha256")) {
        return .{ .allocate = WrenHash(Sha256).alloc };
    }
    if (std.mem.eql(u8, className, "Blake3")) {
        return .{ .allocate = WrenHash(Blake3).alloc };
    }

    return .{};
}
