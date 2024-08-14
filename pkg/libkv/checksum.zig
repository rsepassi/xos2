const std = @import("std");
const filedata = @import("filedata.zig");

const Hash = std.crypto.hash.Sha1;
comptime {
    if (Hash.digest_length > filedata.checksum_size) {
        @compileError("hash has too large of a digest");
    }
}

pub fn compute(x: anytype) filedata.checksum_t {
    var ck: filedata.checksum_t = undefined;
    Hash.hash(
        &@as([@sizeOf(@TypeOf(x))]u8, @bitCast(x)),
        ck.data[0..Hash.digest_length],
        .{},
    );
    return ck;
}

pub fn equal(a: filedata.checksum_t, b: filedata.checksum_t) bool {
    return std.mem.eql(
        u8,
        a.data[0..Hash.digest_length],
        b.data[0..Hash.digest_length],
    );
}
