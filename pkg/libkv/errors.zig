const c = @cImport(@cInclude("kv.h"));

pub const kv_result_strs = [_][:0]const u8{
    // KV_OK,
    "ok",
    // KV_KEY_NOT_FOUND,
    "key not found",
    // KV_ERR,
    "error",
    // KV_ERR_VFD_MISSING,
    "vfd missing from init opts",
    // KV_ERR_MEM_MISSING,
    "mem missing from init opts",
    // KV_ERR_EMPTY_METADATA,
    "metadata is missing and allowcreate is not set",
    // KV_ERR_BAD_METADATA,
    "metadata is corrupt",
    // KV_ERR_OOM,
    "out of memory",
    // KV_ERR_IO_SYNC,
    "io error: sync",
    // KV_ERR_IO_READ,
    "io error: read",
    // KV_ERR_IO_WRITE,
    "io error: write",
    // KV_ERR_CORRUPT_DATA,
    "checksum mismatch, data has been corrupted",
    // KV_ERR_DB_RO,
    "kv is readonly but tried to write",
    // KV_ERR_TXN_RO,
    "txn is readonly but tried to write",
    // KV_ERR_BAD_KEY,
    "key must be at least length 1",
};

comptime {
    if (kv_result_strs.len != c.KV__RESULT_SENTINEL) @compileError("bad kv_result_strs length");
}

pub const KVError = error{
    Err,
    VfdMissing,
    MemMissing,
    OutOfMemory,
    IoSync,
    IoWrite,
    IoRead,
    EmptyMetadata,
    BadMetadata,
    CorruptData,
    KvRO,
    TxnRO,
    BadKey,
};

pub fn convertResult(res: c.kv_result) KVError!void {
    return switch (res) {
        c.KV_OK => void{},
        c.KV_ERR => error.Err,
        c.KV_ERR_VFD_MISSING => error.VfdMissing,
        c.KV_ERR_MEM_MISSING => error.MemMissing,
        c.KV_ERR_OOM => error.OutOfMemory,
        c.KV_ERR_IO_SYNC => error.IoSync,
        c.KV_ERR_IO_READ => error.IoRead,
        c.KV_ERR_IO_WRITE => error.IoWrite,
        c.KV_ERR_EMPTY_METADATA => error.EmptyMetadata,
        c.KV_ERR_BAD_METADATA => error.BadMetadata,
        c.KV_ERR_CORRUPT_DATA => error.CorruptData,
        c.KV_ERR_DB_RO => error.KvRO,
        c.KV_ERR_TXN_RO => error.TxnRO,
        c.KV_ERR_BAD_KEY => error.BadKey,
        else => unreachable,
    };
}

pub fn convertErr(maybe_err: KVError!void) c.kv_result {
    maybe_err catch |err| {
        return switch (err) {
            error.Err => c.KV_ERR,
            error.VfdMissing => c.KV_ERR_VFD_MISSING,
            error.MemMissing => c.KV_ERR_MEM_MISSING,
            error.OutOfMemory => c.KV_ERR_OOM,
            error.IoSync => c.KV_ERR_IO_SYNC,
            error.IoRead => c.KV_ERR_IO_READ,
            error.IoWrite => c.KV_ERR_IO_WRITE,
            error.EmptyMetadata => c.KV_ERR_EMPTY_METADATA,
            error.BadMetadata => c.KV_ERR_BAD_METADATA,
            error.CorruptData => c.KV_ERR_CORRUPT_DATA,
            error.KvRO => c.KV_ERR_DB_RO,
            error.TxnRO => c.KV_ERR_TXN_RO,
            error.BadKey => c.KV_ERR_BAD_KEY,
        };
    };
    return c.KV_OK;
}
