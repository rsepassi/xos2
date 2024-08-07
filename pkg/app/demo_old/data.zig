const twod = @import("twod");

pub fn getImageData(comptime which: enum { a, b }) twod.Image {
    // Create image data
    const width = 256;
    const height = 256;
    const pixels = comptime blk: {
        @setEvalBranchQuota(100000);
        var pixels: [width * height]twod.RGBA = undefined;
        for (0..width) |i| {
            for (0..height) |j| {
                const idx = j * width + i;
                if (which == .a) {
                    pixels[idx].r = @intCast(i);
                    pixels[idx].g = @intCast(j);
                    pixels[idx].b = 128;
                    pixels[idx].a = 255;
                } else {
                    pixels[idx].r = 0;
                    pixels[idx].g = 0;
                    pixels[idx].b = 255;
                    pixels[idx].a = 255;
                }
            }
        }
        break :blk pixels;
    };
    return .{ .data = &pixels, .size = .{ .width = width, .height = height } };
}

pub fn getSpriteSheet() twod.Image {
    // Make a sprite sheet with 3 100x100 sprites on it
    // 1. red to green
    // 2. green to blue
    // 3. blue to red
    const num_sprites = 3;
    const sprite_width = 100;
    const sprite_height = 100;

    const pixels = comptime blk: {
        @setEvalBranchQuota(100000);
        var pixels: [num_sprites * sprite_width * sprite_height]twod.RGBA = undefined;
        for (0..num_sprites) |s| {
            for (0..sprite_width) |i| {
                for (0..sprite_height) |j| {
                    const idx = sprite_width * s + j * (num_sprites * sprite_width) + i;

                    const delta = j * 2;

                    if (s == 0) {
                        pixels[idx].r = 255 - delta;
                        pixels[idx].g = delta;
                        pixels[idx].b = 0;
                        pixels[idx].a = 255;
                    } else if (s == 1) {
                        pixels[idx].r = 0;
                        pixels[idx].g = 255 - delta;
                        pixels[idx].b = delta;
                        pixels[idx].a = 255;
                    } else if (s == 2) {
                        pixels[idx].r = delta;
                        pixels[idx].g = 0;
                        pixels[idx].b = 255 - delta;
                        pixels[idx].a = 255;
                    } else @compileError("num_sprites=3");
                }
            }
        }
        break :blk pixels;
    };

    return .{ .data = &pixels, .size = .{
        .width = num_sprites * sprite_width,
        .height = sprite_height,
    } };
}
