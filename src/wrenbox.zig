// wrenbox aliased as foo will run "wren foo.wren"
const std = @import("std");

pub fn main() !void {
    const alloc = std.heap.c_allocator;

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const binpath = try std.fs.selfExeDirPathAlloc(alloc);
    const script_name = try std.fmt.allocPrint(alloc, "{s}.wren", .{std.fs.path.basename(args[0])});
    const scriptpath = try std.fs.path.join(alloc, &.{ binpath, script_name });
    alloc.free(binpath);
    alloc.free(script_name);

    var exec_args = std.ArrayList([]const u8).init(alloc);
    defer exec_args.deinit();
    try exec_args.ensureTotalCapacity(args.len + 1);
    exec_args.appendAssumeCapacity("wren");
    exec_args.appendAssumeCapacity(scriptpath);
    for (args, 0..) |arg, i| {
        if (i == 0) continue;
        exec_args.appendAssumeCapacity(arg);
    }

    var child = std.process.Child.init(exec_args.items, alloc);
    try child.spawn();
    switch (try child.wait()) {
        .Exited => |code| {
            std.process.exit(code);
        },
        else => {
            std.process.exit(1);
        },
    }
}
