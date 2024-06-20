const std = @import("std");

pub usingnamespace @import("kv.zig");
pub usingnamespace @import("hash.zig");
pub usingnamespace @import("ucl.zig");
pub usingnamespace @import("random.zig");

export fn xosDirectoryDeleteTree(path: [*c]const u8) bool {
    std.fs.cwd().deleteTree(std.mem.span(path)) catch {
        return false;
    };
    return true;
}

export fn xosDirectoryMkdirs(path: [*c]const u8) bool {
    std.fs.cwd().makePath(std.mem.span(path)) catch {
        return false;
    };
    return true;
}
