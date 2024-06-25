const std = @import("std");
const c = @cImport(@cInclude("wren.h"));

const WrenType = enum(u8) {
    bool,
    num,
    foreign,
    list,
    map,
    null,
    string,
    unknown,
};

export fn osDebug(vm: ?*c.WrenVM) void {
    const n: usize = @intCast(c.wrenGetSlotCount(vm));
    for (0..n) |i| {
        const slot: c_int = @intCast(i);
        const t: WrenType = @enumFromInt(c.wrenGetSlotType(vm, slot));
        switch (t) {
            .bool => {
                const val = c.wrenGetSlotBool(vm, slot);
                std.debug.print("arg[{d}]={any}\n", .{ slot, val });
            },
            .num => {
                const val = c.wrenGetSlotDouble(vm, slot);
                std.debug.print("arg[{d}]={d}\n", .{ slot, val });
            },
            .foreign, .list, .map, .null, .unknown => {
                std.debug.print("arg[{d}]={s}\n", .{ slot, @tagName(t) });
            },
            .string => {
                const val = c.wrenGetSlotString(vm, slot);
                std.debug.print("arg[{d}]='{s}'\n", .{ slot, val });
            },
        }
    }
}
