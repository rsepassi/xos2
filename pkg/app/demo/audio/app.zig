// Audio

const std = @import("std");
pub const std_options = .{
    .log_level = .info,
};
const log = std.log.scoped(.app);

const ma = @import("miniaudio");

const app = @import("app");
pub const App = @This();

context: ma.c.ma_context = undefined,
device: ma.c.ma_device = undefined,
sine: ma.c.ma_waveform = undefined,
on: bool = false,

const sample_rate = 48000;

pub fn init(self: *App, appctx: *app.Ctx) !void {
    _ = appctx;

    self.* = .{};

    try ma.check(ma.c.ma_context_init(null, 0, null, &self.context));
    errdefer _ = ma.c.ma_context_uninit(&self.context);

    // Log devices
    {
        var pPlaybackDeviceInfos: [*c]ma.c.ma_device_info = undefined;
        var playbackDeviceCount: c_uint = 0;
        var pCaptureDeviceInfos: [*c]ma.c.ma_device_info = undefined;
        var captureDeviceCount: c_uint = 0;
        try ma.check(ma.c.ma_context_get_devices(
            &self.context,
            &pPlaybackDeviceInfos,
            &playbackDeviceCount,
            &pCaptureDeviceInfos,
            &captureDeviceCount,
        ));

        std.debug.print("playback:\n", .{});
        for (0..@intCast(playbackDeviceCount)) |i| {
            std.debug.print("{d}: {s}\n", .{ i, pPlaybackDeviceInfos[i].name });
        }
        std.debug.print("capture:\n", .{});
        for (0..@intCast(captureDeviceCount)) |i| {
            std.debug.print("{d}: {s}\n", .{ i, pCaptureDeviceInfos[i].name });
        }
    }


    // Init device
    var device_config = ma.c.ma_device_config_init(ma.c.ma_device_type_playback);
    device_config.playback.format = ma.c.ma_format_f32;
    device_config.playback.channels = 2;
    device_config.sampleRate = sample_rate;
    device_config.dataCallback = data_callback;
    device_config.pUserData = self;
    try ma.check(ma.c.ma_device_init(&self.context, &device_config, &self.device));
    errdefer ma.c.ma_device_uninit(&self.device);

    // Init sine
    const sine_config = ma.c.ma_waveform_config_init(
        self.device.playback.format,
        self.device.playback.channels,
        self.device.sampleRate,
        ma.c.ma_waveform_type_sine,
        0.2,
        220,
    );
    try ma.check(ma.c.ma_waveform_init(&sine_config, &self.sine));
}

pub fn deinit(self: *App) void {
    defer _ = ma.c.ma_context_uninit(&self.context);
    defer ma.c.ma_device_uninit(&self.device);
    defer ma.c.ma_waveform_uninit(&self.sine);
}

pub fn onEvent(self: *App, event: app.Event) !void {
    switch (event) {
        .char => {
            try if (self.on) self.turnOff() else self.turnOn();
            self.on = !self.on;
        },
        else => |e| {
            log.info("event {any}", .{e});
        },
    }
}

fn turnOn(self: *App) !void {
    try ma.check(ma.c.ma_device_start(&self.device));
}

fn turnOff(self: *App) !void {
    try ma.check(ma.c.ma_device_stop(&self.device));
}

fn data_callback(
    pDevice: [*c]ma.c.ma_device,
    pOutput: ?*anyopaque,
    pInput: ?*const anyopaque,
    frameCount: c_uint,
) callconv(.C) void {
    _ = pInput;

    const self: *App = @ptrCast(@alignCast(pDevice.*.pUserData));
    ma.check(ma.c.ma_waveform_read_pcm_frames(&self.sine, pOutput, frameCount, null)) catch @panic("bad audio read");
}
