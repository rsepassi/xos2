const std = @import("std");

const wren = struct {
    const c = @cImport(@cInclude("wren.h"));
};

const ucl = struct {
    const c = @cImport(@cInclude("ucl.h"));
};

export fn wrenJSONSource() [*c]const u8 {
    const src = @embedFile("json.wren");
    return @ptrCast(src);
}

const wren_methods = .{
    .{ "JSON", .{
        .{ "parse(_)", jsonParse },
    }, .{} },
    .{ "JSONObj_", .{}, .{
        .{ "stringify()", jsonObjStringify },
    } },
};
const wren_classes = .{
    .{ "JSONObj_", jsonAlloc, jsonFinalize },
};

export fn wrenUclBindForeignMethod(
    vm: *wren.c.WrenVM,
    cclassName: [*c]const u8,
    isStatic: bool,
    csig: [*c]const u8,
) wren.c.WrenForeignMethodFn {
    _ = vm;
    const className = std.mem.span(cclassName);
    const sig = std.mem.span(csig);

    inline for (wren_methods) |m| {
        if (std.mem.eql(u8, className, m[0])) {
            if (isStatic) {
                inline for (m[1]) |m_| {
                    if (std.mem.eql(u8, sig, m_[0])) return m_[1];
                }
            } else {
                inline for (m[2]) |m_| {
                    if (std.mem.eql(u8, sig, m_[0])) return m_[1];
                }
            }
        }
    }

    return null;
}

export fn wrenUclBindForeignClass(
    vm: *wren.c.WrenVM,
    cmodule: [*c]const u8,
    cclassName: [*c]const u8,
) wren.c.WrenForeignClassMethods {
    _ = vm;
    _ = cmodule;

    const className = std.mem.span(cclassName);
    inline for (wren_classes) |c| {
        if (std.mem.eql(u8, className, c[0])) {
            return .{ .allocate = c[1], .finalize = c[2] };
        }
    }

    return .{};
}

fn jsonParse(vm: ?*wren.c.WrenVM) callconv(.C) void {
    var json_len: c_int = 0;
    const json = wren.c.wrenGetSlotBytes(vm, 1, &json_len);
    const parser = ucl.c.ucl_parser_new(ucl.c.UCL_PARSER_NO_IMPLICIT_ARRAYS | ucl.c.UCL_PARSER_NO_TIME);
    defer ucl.c.ucl_parser_free(parser);
    if (!ucl.c.ucl_parser_add_string(parser, json, @intCast(json_len))) {
        abort(vm, "json parse failed");
        return;
    }
    const err = ucl.c.ucl_parser_get_error(parser);
    if (@intFromPtr(err) != 0) {
        const stderr = std.io.getStdErr().writer();
        _ = stderr.write(std.mem.span(err)) catch unreachable;
        _ = stderr.write("\n") catch unreachable;
        abort(vm, "json parse failed");
        return;
    }
    if (ucl.c.ucl_parser_get_object(parser)) |obj| {
        defer ucl.c.ucl_object_unref(obj);
        wren.c.wrenEnsureSlots(vm, 1);
        jsonDecodeValue(vm, 0, obj) catch {
            abort(vm, "parse error");
            return;
        };
    } else {
        abort(vm, "parse error");
        return;
    }
}

fn jsonDecodeValue(vm: ?*wren.c.WrenVM, slot: c_int, obj: *const ucl.c.ucl_object_t) !void {
    const t = ucl.c.ucl_object_type(obj);
    switch (t) {
        ucl.c.UCL_OBJECT => {
            wren.c.wrenEnsureSlots(vm, slot + 3);
            wren.c.wrenSetSlotNewMap(vm, slot);

            var it = std.mem.zeroes(ucl.c.ucl_object_iter_t);
            while (ucl.c.ucl_object_iterate_with_error(obj, &it, true, @ptrFromInt(0))) |el| {
                const key = ucl.c.ucl_object_key(el);
                wren.c.wrenSetSlotString(vm, slot + 1, key);
                try jsonDecodeValue(vm, slot + 2, el);
                wren.c.wrenSetMapValue(vm, slot, slot + 1, slot + 2);
            }
        },
        ucl.c.UCL_ARRAY => {
            wren.c.wrenEnsureSlots(vm, slot + 2);
            wren.c.wrenSetSlotNewList(vm, slot);
            const n = ucl.c.ucl_array_size(obj);

            for (0..n) |i| {
                const el = ucl.c.ucl_array_find_index(obj, @intCast(i));
                try jsonDecodeValue(vm, slot + 1, el);
                wren.c.wrenInsertInList(vm, slot, -1, slot + 1);
            }
        },
        ucl.c.UCL_INT => {
            wren.c.wrenSetSlotDouble(vm, slot, @floatFromInt(ucl.c.ucl_object_toint(obj)));
        },
        ucl.c.UCL_FLOAT => {
            wren.c.wrenSetSlotDouble(vm, slot, ucl.c.ucl_object_todouble(obj));
        },
        ucl.c.UCL_STRING => {
            wren.c.wrenSetSlotString(vm, slot, ucl.c.ucl_object_tostring(obj));
        },
        ucl.c.UCL_BOOLEAN => {
            wren.c.wrenSetSlotBool(vm, slot, ucl.c.ucl_object_toboolean(obj));
        },
        ucl.c.UCL_NULL => {
            wren.c.wrenSetSlotNull(vm, slot);
        },
        ucl.c.UCL_TIME,
        ucl.c.UCL_USERDATA,
        => return error.UnsupportedType,
        else => unreachable,
    }
}

fn jsonAlloc(vm: ?*wren.c.WrenVM) callconv(.C) void {
    const otype: usize = @intFromFloat(wren.c.wrenGetSlotDouble(vm, 2));
    const obj: **ucl.c.ucl_object_t = @ptrCast(@alignCast(wren.c.wrenSetSlotNewForeign(vm, 0, 0, @sizeOf(*ucl.c.ucl_object_t))));

    const ismap = otype == 2;
    obj.* = jsonBuildObj(vm, 1, ismap) catch |err| {
        var writer = std.io.getStdErr().writer();
        writer.print("{any}\n", .{err}) catch {};
        return abort(vm, "could not encode value");
    };
}

fn jsonFinalize(ptr: ?*anyopaque) callconv(.C) void {
    const obj: **ucl.c.ucl_object_t = @ptrCast(@alignCast(ptr));
    ucl.c.ucl_object_unref(obj.*);
}

fn abort(vm: ?*wren.c.WrenVM, msg: [:0]const u8) void {
    wren.c.wrenSetSlotString(vm, 0, msg);
    wren.c.wrenAbortFiber(vm, 0);
    return;
}

fn jsonBuildObj(vm: ?*wren.c.WrenVM, slot: c_int, ismap: bool) !*ucl.c.ucl_object_t {
    const t = wren.c.wrenGetSlotType(vm, slot);
    switch (t) {
        wren.c.WREN_TYPE_LIST => {
            if (ismap) {
                const obj = ucl.c.ucl_object_typed_new(ucl.c.UCL_OBJECT);
                const n = @divExact(wren.c.wrenGetListCount(vm, slot), 2);
                wren.c.wrenEnsureSlots(vm, slot + 2);
                for (0..@intCast(n)) |i| {
                    wren.c.wrenGetListElement(vm, slot, @intCast(i * 2), slot + 1);
                    const key = wren.c.wrenGetSlotString(vm, slot + 1);
                    wren.c.wrenGetListElement(vm, slot, @intCast(i * 2 + 1), slot + 1);
                    const val: **ucl.c.ucl_object_t = @ptrCast(@alignCast(wren.c.wrenGetSlotForeign(vm, slot + 1)));
                    if (!ucl.c.ucl_object_insert_key(obj, val.*, key, 0, true)) return error.JSONInsert;
                }
                return obj;
            } else {
                const obj = ucl.c.ucl_object_typed_new(ucl.c.UCL_ARRAY);
                const n = wren.c.wrenGetListCount(vm, slot);
                wren.c.wrenEnsureSlots(vm, slot + 2);
                for (0..@intCast(n)) |i| {
                    wren.c.wrenGetListElement(vm, slot, @intCast(i), slot + 1);
                    const el: **ucl.c.ucl_object_t = @ptrCast(@alignCast(wren.c.wrenGetSlotForeign(vm, slot + 1)));
                    if (!ucl.c.ucl_array_append(obj, el.*)) return error.JSONAppend;
                }
                return obj;
            }
        },
        wren.c.WREN_TYPE_BOOL => {
            return ucl.c.ucl_object_frombool(wren.c.wrenGetSlotBool(vm, slot));
        },
        wren.c.WREN_TYPE_NUM => {
            return ucl.c.ucl_object_fromdouble(wren.c.wrenGetSlotDouble(vm, slot));
        },
        wren.c.WREN_TYPE_NULL => {
            return ucl.c.ucl_object_new();
        },
        wren.c.WREN_TYPE_STRING => {
            return ucl.c.ucl_object_fromstring(wren.c.wrenGetSlotString(vm, slot));
        },
        wren.c.WREN_TYPE_FOREIGN,
        wren.c.WREN_TYPE_UNKNOWN,
        => return error.Unencodable,
        else => unreachable,
    }
}

fn jsonObjStringify(vm: ?*wren.c.WrenVM) callconv(.C) void {
    const obj: **ucl.c.ucl_object_t = @ptrCast(@alignCast(wren.c.wrenGetSlotForeign(vm, 0)));
    if (ucl.c.ucl_object_emit(obj.*, ucl.c.UCL_EMIT_JSON_COMPACT)) |s| {
        defer ucl.c.UCL_FREE(std.mem.len(s), s);
        wren.c.wrenEnsureSlots(vm, 1);
        wren.c.wrenSetSlotString(vm, 0, s);
    } else {
        abort(vm, "could not encode as json");
    }
}
