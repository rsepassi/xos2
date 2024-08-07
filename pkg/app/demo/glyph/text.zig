const std = @import("std");

const twod = @import("twod");

const log = std.log.scoped(.text);

pub const c = @cImport({
    @cInclude("freetype/freetype.h");
    @cInclude("freetype/ftmodapi.h");
    @cInclude("freetype/ftglyph.h");
});

pub const GlyphIndex = u32;

pub const FreeType = struct {
    const Self = @This();

    ft: c.FT_Library,

    pub fn init() !Self {
        var self = std.mem.zeroes(Self);
        if (c.FT_Init_FreeType(&self.ft) != 0) return error.FTInitFail;
        return self;
    }

    pub fn deinit(self: Self) void {
        _ = c.FT_Done_Library(self.ft);
    }

    pub fn font(self: Self, args: Font.InitArgs) !Font {
        return try Font.init(&self, args);
    }
};

pub const Font = struct {
    const Self = @This();

    face: c.FT_Face,

    const InitArgs = struct {
        path: [:0]const u8,
        face_index: u8 = 0,
        pxsize: usize = 12,
    };
    fn init(lib: *const FreeType, args: InitArgs) !Self {
        var self: Self = undefined;
        if (c.FT_New_Face(
            lib.ft,
            args.path,
            args.face_index,
            &self.face,
        ) != 0) return error.FTFontLoadFail;

        if (c.FT_HAS_FIXED_SIZES(self.face)) {
            if (c.FT_Select_Size(self.face, 0) != 0) return error.FTFontSizeFail;
        } else {
            if (c.FT_Set_Char_Size(self.face, 0, @intCast(args.pxsize << 6), 0, 0) != 0)
                return error.FTFontSizeFail;
        }

        // Identity transform
        c.FT_Set_Transform(self.face, 0, 0);

        return self;
    }

    pub fn deinit(self: Self) void {
        _ = c.FT_Done_Face(self.face);
    }

    pub fn glyphIdx(self: Self, char: usize) GlyphIndex {
        return c.FT_Get_Char_Index(self.face, @intCast(char));
    }

    pub fn loadGlyph(self: Self, id: GlyphIndex) !void {
        const load_flags = c.FT_LOAD_DEFAULT;
        if (c.FT_Load_Glyph(self.face, id, load_flags) != 0)
            return error.FTLoadGlyph;
    }

    pub fn glyph(self: Self, id: u32) !Glyph {
        try self.loadGlyph(id);
        var g: Glyph = .{
            .id = id,
            .font = &self,
            .glyph = undefined,
        };
        if (c.FT_Get_Glyph(self.face.*.glyph, &g.glyph) != 0)
            return error.FTGetGlyph;
        return g;
    }

    pub fn metrics(self: Self) c.FT_Size_Metrics {
        return self.face.*.size.*.metrics;
    }

    pub fn linegap(self: Self) usize {
        const m = self.metrics();
        const ascent = m.ascender >> 6;
        const descent = m.descender >> 6;
        return @intCast(ascent - descent);
    }
};

pub const Glyph = struct {
    font: *const Font,
    glyph: c.FT_Glyph,
    id: u32,

    pub fn deinit(self: @This()) void {
        c.FT_Done_Glyph(self.glyph);
    }

    pub fn name(self: @This(), buf: [:0]u8) ![]u8 {
        if (c.FT_Get_Glyph_Name(self.font.face, self.id, buf.ptr, @intCast(buf.len)) != 0)
            return error.FTGetGlyphName;
        return buf[0..std.mem.len(buf.ptr)];
    }

    pub const Bitmap = struct {
        glyph: *const Glyph,
        buf: []u8,
        nrows: u32,
        ncols: u32,
        pitch: i32,

        const Iterator = struct {
            bitmap: *const Bitmap,
            i: i32 = 0,

            pub fn next(self: *@This()) ?[]u8 {
                if (self.i >= self.bitmap.nrows) return null;
                const rowstart = self.i * self.bitmap.pitch;
                const rowend = rowstart + @as(i32, @intCast(self.bitmap.ncols));
                const out = self.bitmap.buf[@intCast(rowstart)..@intCast(rowend)];
                self.i += 1;
                return out;
            }
        };

        pub fn rows(self: *const @This()) Iterator {
            return .{ .bitmap = self };
        }

        pub fn ascii(self: @This(), writer: anytype) !void {
            var rows_ = self.rows();
            while (rows_.next()) |row| {
                for (row) |val| {
                    const s = if (val == 0) "_" else "X";
                    _ = try writer.write(s);
                }
                _ = try writer.write("\n");
            }
        }
    };

    pub fn render(self: *@This()) !Bitmap {
        if (self.glyph.*.format != c.FT_GLYPH_FORMAT_BITMAP) {
            // replaces self.glyph
            if (c.FT_Glyph_To_Bitmap(&self.glyph, c.FT_RENDER_MODE_NORMAL, null, 1) != 0)
                return error.FTRender;
        }
        const bit: *const c.FT_BitmapGlyph = @ptrCast(@alignCast(&self.glyph));
        const bm = bit.*.*.bitmap;
        return .{
            .glyph = self,
            .buf = bm.buffer[0 .. bm.rows * bm.width],
            .nrows = bm.rows,
            .ncols = bm.width,
            .pitch = bm.pitch,
        };
    }
};

pub const FontAtlas = struct {
    const RenderInfo = struct {
        horiBearingX: c_long,
        horiBearingY: c_long,
        advance_width: c_long,
    };
    const AtlasInfo = struct {
        quad: twod.Rect,
        info: RenderInfo,
    };
    const InfoMap = std.hash_map.AutoHashMap(GlyphIndex, AtlasInfo);

    data: []u8,
    size: twod.Size,
    info: InfoMap,
    padpx: usize,
    col_offset: usize = 0,

    pub fn init(alloc: std.mem.Allocator, size: twod.Size, padpx: usize) !@This() {
        const info = FontAtlas.InfoMap.init(alloc);
        const data = try alloc.alloc(u8, @intFromFloat(size.area()));
        return .{
            .data = data,
            .size = size,
            .info = info,
            .padpx = padpx,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.info.allocator.free(self.data);
        self.info.deinit();
    }

    pub fn addGlyph(
        self: *@This(),
        glyph: GlyphIndex,
        bitmap: Glyph.Bitmap,
        info: RenderInfo,
    ) !void {
        const data_width_px: usize = @intFromFloat(self.size.width + 0.5);
        const data_height_px: usize = @intFromFloat(self.size.height + 0.5);

        if (bitmap.nrows > data_height_px) return error.CharTooTall;
        if (self.col_offset + bitmap.ncols > data_width_px) return error.CharTooWide;

        const start = data_width_px * (data_height_px - bitmap.nrows);

        var i: usize = 0;
        var rows = bitmap.rows();
        while (rows.next()) |row| : (i += 1) {
            const row_start = start + self.col_offset + i * data_width_px;
            std.mem.copyForwards(u8, self.data[row_start .. row_start + bitmap.ncols], row);
        }
        const rect = twod.Rect{
            .tl = .{ .x = @floatFromInt(self.col_offset), .y = @floatFromInt(bitmap.nrows) },
            .br = .{ .x = @floatFromInt(self.col_offset + bitmap.ncols), .y = 0 },
        };

        try self.info.put(glyph, .{
            .info = info,
            .quad = rect,
        });

        // To render to ascii on stderr, uncomment this line
        // try bitmap.ascii(std.io.getStdErr().writer());

        self.col_offset += bitmap.ncols + self.padpx;
    }

    pub fn ascii(self: @This(), quad: twod.Rect, writer: anytype) !void {
        const offset: usize = @intFromFloat(quad.tl.x);
        const width: usize = @intFromFloat(quad.width());
        const height: usize = @intFromFloat(quad.height());

        for (0..height) |i| {
            const row_start = i * self.width + offset;
            for (0..width) |j| {
                const val = self.data[row_start + j];
                const s = if (val == 0) "_" else "X";
                _ = try writer.write(s);
            }
            _ = try writer.write("\n");
        }
    }
};

const ascii_chars = blk: {
    @setEvalBranchQuota(9999);
    var n = 0;
    for (0..256) |i| {
        if (std.ascii.isPrint(i) and !std.ascii.isWhitespace(i)) n += 1;
    }
    var chars: [n]u8 = undefined;
    var i = 0;
    for (0..256) |x| {
        if (std.ascii.isPrint(x) and !std.ascii.isWhitespace(x)) {
            chars[i] = x;
            i += 1;
        }
    }
    break :blk chars;
};

pub fn buildAsciiAtlas(alloc: std.mem.Allocator, font: Font) !FontAtlas {
    const padpx = 2;

    var max_height: c_long = 0;
    var total_width: c_long = 0;
    for (ascii_chars) |char| {
        const glyph_idx = font.glyphIdx(char);
        try font.loadGlyph(glyph_idx);
        const metrics = font.face.*.glyph.*.metrics;
        max_height = @max(max_height, metrics.height);
        total_width += metrics.width + (padpx << 6);
    }

    const data_height = (max_height + 1) >> 6;
    const data_width = (total_width + 1) >> 6;
    log.debug("buildAsciiAtlas nchars={d} size=({d}, {d})", .{ ascii_chars.len, data_width, data_height });

    var atlas = try FontAtlas.init(
        alloc,
        .{ .width = @floatFromInt(data_width), .height = @floatFromInt(data_height) },
        padpx,
    );

    for (ascii_chars) |char| {
        const idx = font.glyphIdx(char);
        var glyph = try font.glyph(idx);
        defer glyph.deinit();
        const bitmap = try glyph.render();
        try atlas.addGlyph(idx, bitmap, .{
            .horiBearingX = font.face.*.glyph.*.metrics.horiBearingX >> 6,
            .horiBearingY = font.face.*.glyph.*.metrics.horiBearingY >> 6,
            .advance_width = font.face.*.glyph.*.advance.x >> 6,
        });
    }

    return atlas;
}

// Color
// if (c.FT_HAS_COLOR(self.face)) self.has_color = true;
// if (self.has_color) load_flags |= @intCast(c.FT_LOAD_COLOR);
