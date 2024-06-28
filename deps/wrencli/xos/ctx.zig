const std = @import("std");

const c = @cImport({
    @cInclude("wren.h");
});

fn Stack(comptime T: type) type {
    return struct {
        stack: std.ArrayList(T),

        fn init(alloc: std.mem.Allocator) @This() {
            return .{ .stack = std.ArrayList(T).init(alloc) };
        }

        fn deinit(self: @This()) void {
            if (@hasDecl(T, "deinit")) for (self.stack.items) |i| i.deinit();
            self.stack.deinit();
        }

        fn top(self: *@This()) ?*T {
            if (self.stack.items.len == 0) return null;
            return &self.stack.items[self.stack.items.len - 1];
        }

        fn push(self: *@This()) !*T {
            return try self.stack.addOne();
        }

        fn pop(self: *@This()) T {
            return self.stack.pop();
        }
    };
}

const Imports = struct {
    imports: std.ArrayList([]const u8),

    fn init(alloc: std.mem.Allocator) @This() {
        return .{
            .imports = std.ArrayList([]const u8).init(alloc),
        };
    }

    fn deinit(self: @This()) void {
        for (self.imports.items) |s| self.imports.allocator.free(s);
        self.imports.deinit();
    }

    fn add(self: *@This(), str: []const u8) !void {
        const copy = try self.imports.allocator.dupe(u8, str);
        try self.imports.append(copy);
    }
};

const Ctx = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    alloc: std.mem.Allocator,
    imports: Stack(Imports),

    fn deinit(self: *@This()) void {
        self.imports.deinit();
        if (self.gpa.deinit() == .leak) {
            @panic("leak!");
        }
    }
};

export fn xosCtxInit() *anyopaque {
    var ctx = std.heap.c_allocator.create(Ctx) catch @panic("could not create Ctx, OOM");
    ctx.gpa = .{};
    ctx.alloc = ctx.gpa.allocator();
    ctx.imports = Stack(Imports).init(ctx.alloc);
    return ctx;
}

export fn xosCtxDeinit(cctx: *anyopaque) void {
    var ctx = getCtx(cctx);
    ctx.deinit();
    std.heap.c_allocator.destroy(ctx);
}

export fn xosCtxCaptureImportsBegin(vm: ?*c.WrenVM) void {
    const ctx = getCtxVm(vm);
    const imports = ctx.imports.push() catch @panic("could not push import collector, OOM");
    imports.* = Imports.init(ctx.alloc);
}

export fn xosCtxCaptureImportsEnd(vm: ?*c.WrenVM) void {
    const ctx = getCtxVm(vm);
    c.wrenEnsureSlots(vm, 2);
    c.wrenSetSlotNewList(vm, 0);
    const imports = ctx.imports.pop();
    defer imports.deinit();
    for (imports.imports.items) |import| {
        c.wrenSetSlotBytes(vm, 1, import.ptr, import.len);
        c.wrenInsertInList(vm, 0, -1, 1);
    }
}

export fn xosCtxCaptureImportsAdd(vm: ?*c.WrenVM, cstr: [*c]const u8) void {
    const ctx = getCtxVm(vm);
    const str = std.mem.span(cstr);
    if (ctx.imports.top()) |imports|
        imports.add(str) catch @panic("could not add import, OOM");
}

fn getCtx(cctx: *anyopaque) *Ctx {
    return @ptrCast(@alignCast(cctx));
}

fn getCtxVm(vm: ?*c.WrenVM) *Ctx {
    const cctx: ?*anyopaque = c.wrenGetUserData(vm);
    return @ptrCast(@alignCast(cctx));
}
