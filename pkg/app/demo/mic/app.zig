// Audio

const std = @import("std");
pub const std_options = .{
    .log_level = .info,
};
const log = std.log.scoped(.app);

const app = @import("app");
pub const App = @This();

const ma = @import("miniaudio");

device: ma.c.ma_device = undefined,
converter: ma.c.ma_channel_converter = undefined,

rec: bool = true,
frames: std.ArrayList(f32),
flush_idx: usize = 0,

const sample_rate = 48000;

pub fn init(self: *App, appctx: *app.Ctx) !void {
    self.* = .{
        .frames = std.ArrayList(f32).init(appctx.allocator()),
    };

    // Init device
    var device_config = ma.c.ma_device_config_init(ma.c.ma_device_type_duplex);
    device_config.capture.format = ma.c.ma_format_f32;
    device_config.capture.channels = 1;
    device_config.playback.format = ma.c.ma_format_f32;
    device_config.playback.channels = 2;
    device_config.sampleRate = sample_rate;
    device_config.dataCallback = data_callback;
    device_config.pUserData = self;
    try ma.check(ma.c.ma_device_init(null, &device_config, &self.device));
    errdefer ma.c.ma_device_uninit(&self.device);

    // Converter
    var converter_config = ma.c.ma_channel_converter_config_init(
        device_config.capture.format,
        device_config.capture.channels,
        null,
        device_config.playback.channels,
        null,
        ma.c.ma_channel_mix_mode_default,
    );
    try ma.check(ma.c.ma_channel_converter_init(&converter_config, null, &self.converter));
    errdefer ma.c.ma_channel_converter_uninit(&self.converter, null);

    try ma.check(ma.c.ma_device_start(&self.device));
}

pub fn deinit(self: *App) void {
    defer ma.c.ma_device_uninit(&self.device);
    defer ma.c.ma_channel_converter_uninit(&self.converter, null);
    defer self.frames.deinit();
}

pub fn onEvent(self: *App, event: app.Event) !void {
    switch (event) {
        .char => {
            if (self.rec) self.rec = false;
        },
        else => |e| {
            log.info("event {any}", .{e});
        },
    }
}

fn data_callback(
    pDevice: [*c]ma.c.ma_device,
    pOutput: ?*anyopaque,
    pInput: ?*const anyopaque,
    frameCount: c_uint,
) callconv(.C) void {
    const self: *App = @ptrCast(@alignCast(pDevice.*.pUserData));

    if (self.rec) {
        // 1 channel of f32 samples
        // Collect them up
        var pinput: [*]const f32 = @ptrCast(@alignCast(pInput));
        self.frames.appendSlice(pinput[0..frameCount]) catch @panic("oom");
    } else {
        // Push to speakers
        if (self.flush_idx >= self.frames.items.len) {
            // Flushed. Reset
            self.frames.shrinkRetainingCapacity(0);
            self.rec = true;
            self.flush_idx = 0;
            return;
        }

        const n = @min(self.frames.items.len - self.flush_idx, frameCount);
        _ = ma.c.ma_channel_converter_process_pcm_frames(
            &self.converter,
            pOutput,
            self.frames.items.ptr + self.flush_idx,
            n,
        );
        self.flush_idx += n;
    }
}
