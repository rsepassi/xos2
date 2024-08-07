// Event log

const std = @import("std");
pub const std_options = .{
    .log_level = .info,
};
const log = std.log.scoped(.app);

const app = @import("app");
pub const App = @This();

pub fn onEvent(self: *App, event: app.Event) !void {
    _ = self;
    switch (event) {
        else => |e| {
            log.info("event {any}", .{e});
        },
    }
}
