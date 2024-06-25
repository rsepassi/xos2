const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os = target.result.os.tag;

    const lib = b.addStaticLibrary(.{
        .name = "lzma",
        .target = target,
        .optimize = optimize,
    });

    lib.defineCMacro("HAVE_CONFIG_H", "1");
    lib.defineCMacro("TUKLIB_SYMBOL_PREFIX", "lzma_");
    lib.addIncludePath(.{ .path = "." });
    lib.addIncludePath(.{ .path = "src/liblzma" });
    lib.addIncludePath(.{ .path = "src/liblzma/api" });
    lib.addIncludePath(.{ .path = "src/liblzma/common" });
    lib.addIncludePath(.{ .path = "src/liblzma/check" });
    lib.addIncludePath(.{ .path = "src/liblzma/lz" });
    lib.addIncludePath(.{ .path = "src/liblzma/rangecoder" });
    lib.addIncludePath(.{ .path = "src/liblzma/lzma" });
    lib.addIncludePath(.{ .path = "src/liblzma/delta" });
    lib.addIncludePath(.{ .path = "src/liblzma/simple" });
    lib.addIncludePath(.{ .path = "src/common" });
    lib.addCSourceFiles(.{ .files = &lib_src_files, .flags = &cflags });
    lib.linkLibC();
    const headers = b.addInstallDirectory(.{
        .source_dir = .{ .path = "src/liblzma/api" },
        .install_dir = .header,
        .install_subdir = "",
        .include_extensions = &.{".h"},
    });
    b.default_step.dependOn(&headers.step);
    b.installArtifact(lib);

    const xz = b.addExecutable(.{
        .name = "xz",
        .target = target,
        .optimize = optimize,
        .linkage = if (os == .linux) .static else null,
        .strip = true,
    });
    xz.defineCMacro("HAVE_CONFIG_H", "1");
    xz.defineCMacro("LOCALEDIR", "\"dummylocale\"");
    xz.defineCMacro("TUKLIB_SYMBOL_PREFIX", "lzma_");
    xz.addIncludePath(.{ .path = "." });
    xz.addIncludePath(.{ .path = "src/xz" });
    xz.addIncludePath(.{ .path = "src/common" });
    xz.addIncludePath(.{ .path = "src/liblzma/api" });
    xz.addIncludePath(.{ .path = "lib" });
    xz.addCSourceFiles(.{ .files = &xz_src_files });
    xz.linkLibrary(lib);
    xz.linkLibC();
    b.installArtifact(xz);

    const xd = b.addExecutable(.{
        .name = "xzdec",
        .target = target,
        .optimize = optimize,
        .linkage = if (os == .linux) .static else null,
        .strip = true,
    });
    xd.defineCMacro("HAVE_CONFIG_H", "1");
    xd.defineCMacro("TUKLIB_GETTEXT", "0");
    xd.defineCMacro("TUKLIB_SYMBOL_PREFIX", "lzma_");
    xd.addIncludePath(.{ .path = "." });
    xd.addIncludePath(.{ .path = "src/xzdec" });
    xd.addIncludePath(.{ .path = "src/common" });
    xd.addIncludePath(.{ .path = "src/liblzma/api" });
    xd.addIncludePath(.{ .path = "lib" });
    xd.addCSourceFiles(.{ .files = &xzdec_src_files });
    xd.linkLibrary(lib);
    xd.linkLibC();
    b.installArtifact(xd);
}

const cflags = [_][]const u8{};

const lib_src_files = [_][]const u8{
    "src/common/tuklib_cpucores.c",
    "src/common/tuklib_exit.c",
    "src/common/tuklib_mbstr_fw.c",
    "src/common/tuklib_mbstr_width.c",
    "src/common/tuklib_open_stdxxx.c",
    "src/common/tuklib_physmem.c",
    "src/common/tuklib_progname.c",
    "src/liblzma/check/check.c",
    "src/liblzma/check/crc32_fast.c",
    "src/liblzma/check/crc32_table.c",
    "src/liblzma/check/crc64_fast.c",
    "src/liblzma/check/crc64_table.c",
    "src/liblzma/check/sha256.c",
    "src/liblzma/common/alone_decoder.c",
    "src/liblzma/common/alone_encoder.c",
    "src/liblzma/common/auto_decoder.c",
    "src/liblzma/common/block_buffer_decoder.c",
    "src/liblzma/common/block_buffer_encoder.c",
    "src/liblzma/common/block_decoder.c",
    "src/liblzma/common/block_encoder.c",
    "src/liblzma/common/block_header_decoder.c",
    "src/liblzma/common/block_header_encoder.c",
    "src/liblzma/common/block_util.c",
    "src/liblzma/common/common.c",
    "src/liblzma/common/easy_buffer_encoder.c",
    "src/liblzma/common/easy_decoder_memusage.c",
    "src/liblzma/common/easy_encoder.c",
    "src/liblzma/common/easy_encoder_memusage.c",
    "src/liblzma/common/easy_preset.c",
    "src/liblzma/common/filter_buffer_decoder.c",
    "src/liblzma/common/filter_buffer_encoder.c",
    "src/liblzma/common/filter_common.c",
    "src/liblzma/common/filter_decoder.c",
    "src/liblzma/common/filter_encoder.c",
    "src/liblzma/common/filter_flags_decoder.c",
    "src/liblzma/common/filter_flags_encoder.c",
    "src/liblzma/common/hardware_cputhreads.c",
    "src/liblzma/common/hardware_physmem.c",
    "src/liblzma/common/index.c",
    "src/liblzma/common/index_decoder.c",
    "src/liblzma/common/index_encoder.c",
    "src/liblzma/common/index_hash.c",
    "src/liblzma/common/outqueue.c",
    "src/liblzma/common/stream_buffer_decoder.c",
    "src/liblzma/common/stream_buffer_encoder.c",
    "src/liblzma/common/stream_decoder.c",
    "src/liblzma/common/stream_encoder.c",
    "src/liblzma/common/stream_encoder_mt.c",
    "src/liblzma/common/stream_flags_common.c",
    "src/liblzma/common/stream_flags_decoder.c",
    "src/liblzma/common/stream_flags_encoder.c",
    "src/liblzma/common/vli_decoder.c",
    "src/liblzma/common/vli_encoder.c",
    "src/liblzma/common/vli_size.c",
    "src/liblzma/delta/delta_common.c",
    "src/liblzma/delta/delta_decoder.c",
    "src/liblzma/delta/delta_encoder.c",
    "src/liblzma/lz/lz_decoder.c",
    "src/liblzma/lz/lz_encoder.c",
    "src/liblzma/lz/lz_encoder_mf.c",
    "src/liblzma/lzma/fastpos_table.c",
    "src/liblzma/lzma/lzma2_decoder.c",
    "src/liblzma/lzma/lzma2_encoder.c",
    "src/liblzma/lzma/lzma_decoder.c",
    "src/liblzma/lzma/lzma_encoder.c",
    "src/liblzma/lzma/lzma_encoder_optimum_fast.c",
    "src/liblzma/lzma/lzma_encoder_optimum_normal.c",
    "src/liblzma/lzma/lzma_encoder_presets.c",
    "src/liblzma/rangecoder/price_table.c",
    "src/liblzma/simple/arm.c",
    "src/liblzma/simple/armthumb.c",
    "src/liblzma/simple/ia64.c",
    "src/liblzma/simple/powerpc.c",
    "src/liblzma/simple/simple_coder.c",
    "src/liblzma/simple/simple_decoder.c",
    "src/liblzma/simple/simple_encoder.c",
    "src/liblzma/simple/sparc.c",
    "src/liblzma/simple/x86.c",
};

const xz_src_files = [_][]const u8{
    "src/xz/args.c",
    "src/xz/coder.c",
    "src/xz/file_io.c",
    "src/xz/hardware.c",
    "src/xz/list.c",
    "src/xz/main.c",
    "src/xz/message.c",
    "src/xz/mytime.c",
    "src/xz/options.c",
    "src/xz/signals.c",
    "src/xz/suffix.c",
    "src/xz/util.c",
};

const xzdec_src_files = [_][]const u8{
    "src/xzdec/xzdec.c",
};
