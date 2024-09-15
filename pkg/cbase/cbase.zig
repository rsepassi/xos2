const std = @import("std");
const builtin = @import("builtin");
const c = @cImport(@cInclude("base/str.h"));

fn fromcstr(x: c.str_t) []const u8 {
    return x.bytes[0..x.len];
}

fn tocstr(x: []const u8) c.str_t {
    return .{
        .bytes = x.ptr,
        .len = x.len,
    };
}

fn panic(msg: []const u8) noreturn {
    if (builtin.abi != .android) {
        @panic(msg);
    } else std.c.abort();
}

export fn fs_self_path() c.str_t {
    const path = std.fs.selfExePathAlloc(std.heap.c_allocator) catch panic("OOM");
    return tocstr(path);
}

export fn fs_resource_read(name: c.str_t) c.str_t {
    const alloc = std.heap.c_allocator;
    const path = std.fs.selfExePathAlloc(std.heap.c_allocator) catch panic("OOM");
    defer alloc.free(path);

    if (std.c.getenv("XOS_RESOURCE_DIR")) |cdir| {
        const dir = std.mem.span(cdir);
        const cwd = std.fs.cwd();
        const resource_path = std.fs.path.join(alloc, &[_][]const u8{
            dir,
            fromcstr(name),
        }) catch panic("OOM");
        defer alloc.free(resource_path);
        const contents = cwd.readFileAlloc(alloc, resource_path, 1 << 30) catch panic("resource not found");
        return tocstr(contents);
    } else if (builtin.os.tag == .macos) {
        // Contents/
        //   MacOS/
        //     exe
        //   Resources/
        //     resource
        const contents_dir = std.fs.path.dirname(std.fs.path.dirname(path).?).?;
        const resource_path = std.fs.path.join(alloc, &[_][]const u8{
            contents_dir,
            "Resources",
            fromcstr(name),
        }) catch panic("OOM");
        defer alloc.free(resource_path);
        const cwd = std.fs.cwd();
        const contents = cwd.readFileAlloc(alloc, resource_path, 1 << 30) catch panic("resource not found");
        return tocstr(contents);
    } else if (builtin.os.tag == .windows) {
        // Flat directory with exe + resources
        const contents_dir = std.fs.path.dirname(path).?;
        const resource_path = std.fs.path.join(alloc, &[_][]const u8{
            contents_dir,
            fromcstr(name),
        }) catch panic("OOM");
        defer alloc.free(resource_path);
        const cwd = std.fs.cwd();
        const contents = cwd.readFileAlloc(alloc, resource_path, 1 << 30) catch panic("resource not found");
        return tocstr(contents);
    } else if (builtin.os.tag == .linux and builtin.abi != .android) {
        // exe
        // resources/
        //   resource
        const contents_dir = std.fs.path.dirname(path).?;
        const resource_path = std.fs.path.join(alloc, &[_][]const u8{
            contents_dir,
            "resources",
            fromcstr(name),
        }) catch panic("OOM");
        defer alloc.free(resource_path);
        const cwd = std.fs.cwd();
        const contents = cwd.readFileAlloc(alloc, resource_path, 1 << 30) catch panic("resource not found");
        return tocstr(contents);
    } else if (builtin.os.tag == .linux and builtin.abi == .android) {
        const read = @extern(*const fn(c.str_t) callconv(.C) c.str_t, .{.name = "fs_resource_read_android" });
        return read(name);
    } else {
        @compileError("not implemented");
    }
}
