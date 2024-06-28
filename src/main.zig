// This is our root entrypoint.
// It identifies the xos installation directory and the repository root and
// then runs scripts/main.wren in a new environment with a limited PATH.

const std = @import("std");
const builtin = @import("builtin");

const wrencli = @cImport({
    @cInclude("cli.h");
});

const log = std.log.scoped(.xos);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    if (try std.process.hasEnvVar(alloc, "XOS_WRAPPED")) {
        try mainInner(alloc);
    } else {
        try mainOuter(alloc);
    }
}

// Run main.wren
pub fn mainInner(alloc: std.mem.Allocator) !void {
    const args = try std.process.argsAlloc(alloc);
    const cargs = try alloc.alloc([*c]const u8, args.len);
    for (args, 0..) |arg, i| cargs[i] = arg;

    wrencli.cliSetArguments(@intCast(args.len), cargs.ptr);

    const source = @embedFile("main.wren");
    const result = wrencli.cliRunSource("xos_main", source, false);

    const code = blk: {
        // Exit with an error code if the script failed.
        if (result == wrencli.WREN_RESULT_COMPILE_ERROR) break :blk 65; // EX_DATAERR.
        if (result == wrencli.WREN_RESULT_RUNTIME_ERROR) break :blk 70; // EX_SOFTWARE.
        break :blk wrencli.cliGetExitCode();
    };

    log.debug("runSource done, code={d}", .{code});
    std.process.exit(@intCast(code));
}

// Respawn to mainInner
pub fn mainOuter(alloc: std.mem.Allocator) !void {
    const args = try std.process.argsAlloc(alloc);
    const env = try std.process.getEnvMap(alloc);
    const cwd = std.fs.cwd();

    // Identify paths
    const cwd_path = try cwd.realpathAlloc(alloc, ".");
    const binpath = try std.fs.selfExeDirPathAlloc(alloc);

    const bindir = try cwd.openDir(binpath, .{});
    const supportdir = try bindir.openDir("support", .{});
    const supportpath = try supportdir.realpathAlloc(alloc, ".");
    const modulespath = try supportdir.realpathAlloc(alloc, "wren_modules");

    const repo_root = try getRepoRoot(alloc, cwd_path);

    // Command-line:
    // wren main.wren <args>
    var exec_args = std.ArrayList([]const u8).init(alloc);
    try exec_args.append(args[0]);
    try exec_args.append("main.wren");
    for (args, 0..) |arg, i| {
        if (i == 0) continue;
        try exec_args.append(arg);
    }

    // Limited env
    var exec_env = std.process.EnvMap.init(alloc);
    if (builtin.os.tag == .windows) {
        _ = std.mem.replace(u8, binpath, "\\", "/", binpath);
        _ = std.mem.replace(u8, repo_root, "\\", "/", repo_root);
        try exec_env.put("SYSTEMROOT", env.get("SYSTEMROOT") orelse "");
        try exec_env.put("WINDIR", env.get("WINDIR") orelse "");
    }
    try exec_env.put("XOS_WRAPPED", "1");
    try exec_env.put("XOS_ROOT", binpath);
    try exec_env.put("XOS_REPO_ROOT", repo_root);
    try exec_env.put("XOS_SYSTEM_PATH", env.get("XOS_SYSTEM_PATH") orelse env.get("PATH") orelse "");
    try exec_env.put("XOS_HOST", getHostTriple());
    try exec_env.put("XOS_ID", env.get("XOS_ID") orelse try supportdir.readFileAlloc(alloc, "xos_id", 1024));
    try exec_env.put("WREN_MODULES", modulespath);
    try exec_env.put("PATH", supportpath);
    try exec_env.put("LOG", env.get("LOG") orelse "");
    try exec_env.put("LOG_SCOPES", env.get("LOG_SCOPES") orelse "");
    try exec_env.put("NO_CACHE", env.get("NO_CACHE") orelse "");

    var child = std.process.Child.init(exec_args.items, alloc);
    child.env_map = &exec_env;
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

fn getRepoRoot(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
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
