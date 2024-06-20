// This is our root entrypoint.
// It identifies the xos installation directory and the repository root and
// then runs scripts/main.wren in a new environment with a limited PATH.

const std = @import("std");
const builtin = @import("builtin");

const log = std.log.scoped(.xos);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var args = std.process.args();
    var env = try std.process.getEnvMap(alloc);
    const cwd = std.fs.cwd();

    // Identify paths
    const cwd_path = try cwd.realpathAlloc(alloc, ".");
    const binpath = try std.fs.selfExeDirPathAlloc(alloc);
    log.debug("binpath={s}", .{binpath});
    const bindir = try cwd.openDir(binpath, .{});
    const wren_path = try bindir.realpathAlloc(alloc, "wren");
    const script_path = try bindir.realpathAlloc(alloc, "scripts/main.wren");

    // Command-line:
    // wren main.wren <args>
    var exec_args = std.ArrayList([]const u8).init(alloc);
    try exec_args.append(wren_path);
    try exec_args.append(script_path);
    _ = args.next(); // skip $0
    while (args.next()) |arg| {
        try exec_args.append(arg);
    }

    // Limited env
    var exec_env = std.process.EnvMap.init(alloc);
    try exec_env.put("XOS_ROOT", binpath);
    try exec_env.put("XOS_REPO_ROOT", try getRepoRoot(alloc, cwd_path));
    try exec_env.put("XOS_SYSTEM_PATH", env.get("XOS_SYSTEM_PATH") orelse env.get("PATH") orelse "");
    try exec_env.put("XOS_HOST", getHostTriple());
    try exec_env.put("XOS_ID", env.get("XOS_ID") orelse try bindir.readFileAlloc(alloc, "xos_id", 1024));
    try exec_env.put("PATH", binpath);
    try exec_env.put("LOG", env.get("LOG") orelse "");
    try exec_env.put("LOG_SCOPES", env.get("LOG_SCOPES") orelse "");
    try exec_env.put("NO_CACHE", env.get("NO_CACHE") orelse "");
    std.process.execve(std.heap.c_allocator, exec_args.items, &exec_env) catch @panic("bad exec");
}

fn getRepoRoot(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    const cwd = std.fs.cwd();
    var cur: ?[]const u8 = path;
    while (cur) |c| : (cur = std.fs.path.dirname(c)) {
        const gitpath = try std.fs.path.join(alloc, &.{ c, ".git" });
        const rootpath = try std.fs.path.join(alloc, &.{ c, ".xosroot" });
        cwd.access(gitpath, .{}) catch {
            cwd.access(rootpath, .{}) catch {
                continue;
            };
        };
        return try std.fs.realpathAlloc(alloc, c);
    }
    return "";
}

fn getHostTriple() []const u8 {
    return std.fmt.comptimePrint("{s}-{s}-{s}", .{
        @tagName(builtin.cpu.arch),
        @tagName(builtin.os.tag),
        @tagName(builtin.abi),
    });
}
