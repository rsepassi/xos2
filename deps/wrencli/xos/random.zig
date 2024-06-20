// Random

const std = @import("std");
const c = @cImport(@cInclude("wren.h"));

export fn wrenRandomSource() [*c]const u8 {
    const src = @embedFile("random.wren");
    return @ptrCast(src);
}

export fn wrenRandomBindForeignMethod(
    vm: *c.WrenVM,
    cclassName: [*c]const u8,
    isStatic: bool,
    csig: [*c]const u8,
) c.WrenForeignMethodFn {
    _ = vm;
    const className = std.mem.span(cclassName);
    const sig = std.mem.span(csig);

    if (std.mem.eql(u8, className, "Random") and isStatic) {
        if (std.mem.eql(u8, sig, "int(_,_)")) return randInt;
    }

    return null;
}

fn randInt(vm: ?*c.WrenVM) callconv(.C) void {
    const start: usize = @intFromFloat(c.wrenGetSlotDouble(vm, 1));
    const end: usize = @intFromFloat(c.wrenGetSlotDouble(vm, 2));
    const len = end - start;

    var rand = std.crypto.random;
    const randint = rand.int(usize);
    const constrained_randint = start + @mod(randint, len);

    c.wrenEnsureSlots(vm, 1);
    c.wrenSetSlotDouble(vm, 0, @floatFromInt(constrained_randint));
}
