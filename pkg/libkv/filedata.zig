pub const kv_version = 1;
pub const magic_bytes = "KV-37r33";
pub const checksum_size = 32;
pub const page_size_reserved = 4096;
pub const btree_inline_maxlen = 255;

const reserved_space = 64;
const page_size_usable = page_size_reserved - reserved_space;

// Page 0: Page.Metadata
// Page 1: Page.Metadata
// Page n: one of
// * Page.BTreeNode
// * Page.BTreeLeaf
// * Page.Freelist
// * Page.Txnlist
// * Page.Overflow
pub const Page = struct {
    fn PageT(comptime T: type) type {
        const size = @sizeOf(T);
        const npad = page_size_usable - size;
        if (size > page_size_usable) @compileError("type too big for page");
        return extern struct {
            contents: T,
            pad: [npad]u8 = undefined,
            reserved: [reserved_space]u8 = undefined,

            pub fn unallocated(self: *@This()) []u8 {
                var ptr: [*]u8 = @ptrCast(self);
                ptr += @sizeOf(T);
                return ptr[0..npad];
            }
        };
    }

    pub const Generic = PageT(extern struct {});

    pub fn bytes(page_t: anytype) *[page_size_reserved]u8 {
        if (@sizeOf(@typeInfo(@TypeOf(page_t)).Pointer.child) != page_size_reserved) @compileError("bad page type");
        return @ptrCast(page_t);
    }

    pub const Metadata = PageT(extern struct {
        header: metadata_header_t,
        metadata: metadata_t,
    });

    // A BTreeNode is logically an alternating sequence of <key> <pageptr>
    // bookended by <pageptr>s. A <pageptr> contains keys lexicographically
    // less than the key to its right (when present) and greater than the key
    // to its left (when present).
    //
    // Each node has variable branching based on the size of the contained
    // keys.
    //
    // The on-disk structure is:
    //
    //   nbranch: u16
    //   pages: [nbranch]pageptr_t
    //   keyinfo: [nbranch - 1]btree_keyinfo_t
    //   keydata: []u8
    //
    //   keydata is a list of (nbranch - 1) variable length items indexed by
    //   keyinfo[i].offset.
    //   Each item i is either
    //     inlined: []u8, if keyinfo[i].len_inline > 0
    //     overflow: btree_overflow_t, if keyinfo[i].len_inline == 0
    //
    // size of page for a fixed key length =
    // b = branching factor
    // k = key length
    // 2 + b * @sizeOf(pageptr_t) + (b - 1) * @sizeOf(btree_keyinfo_t) + (b - 1) * k
    //
    // Maximum branching (k=1) = 252
    // Minimum branching (k=btree_inline_maxlen + 1) = 15
    //
    // The pages pageptr_t items point to
    //   a Page.BTreeNode page, if depth < height
    //   a Page.BTreeLeaf page, otherwise
    // page, depending on the tree height.
    pub const BTreeNode = PageT(extern struct {
        nbranch: u16,
        // variable length remainder is described above
    });

    // A BTreeLeaf is logically a sequence of <key> <value> pairs.
    //
    // The on-disk structure is:
    //   next: pageptr_t
    //   nrecords: u16
    //   data: []u8
    //
    //   data is a list of nrecords entries
    //   Each entry is:
    //     header: record_header_t
    //     key:
    //       inlined: []u8, if header.key_len <= btree_inline_maxlen
    //       overflow: btree_overflow_t, if header.key_len > btree_inline_maxlen
    //     value:
    //       inlined: []u8, if header.val_len <= btree_inline_maxlen
    //       overflow: btree_overflow_t, if header.val_len > btree_inline_maxlen
    pub const BTreeLeaf = PageT(extern struct {
        // Points to a Page.BTreeLeaf page
        next: pageptr_t,
        nrecords: u16,
        // variable length remainder is described above
    });

    pub const Freelist = PageT(extern struct {
        const npages_max = (page_size_usable - @sizeOf(pageptr_t)) / @sizeOf(pageidx_t);
        // Points to a Page.Freelist page
        next: pageptr_t,
        // Points to page of undefined type
        pages: [npages_max]pageidx_t,
    });

    pub const Txnlist = PageT(extern struct {
        const npages_max = (page_size_usable - @sizeOf(pageptr_t)) / @sizeOf(pageptr_t);
        // Points to a Page.Txnlist page
        next: pageptr_t,
        // Points to page of undefined type
        pages: [npages_max]pageptr_t,
    });

    pub const Overflow = PageT(extern struct {
        next: pageptr_t,
        // remainder is data
    });
};

pub const checksum_t = extern struct { data: [checksum_size]u8 };
pub const pageidx_t = u64;
pub const pageptr_t = extern struct {
    checksum: checksum_t,
    idx: pageidx_t,

    pub fn isnull(self: @This()) bool {
        return self.idx == 0;
    }
};

pub const metadata_t = extern struct {
    version: u64,
    txn_id: u64,
    npages: u64,
    nrecords: u64,

    btree: btree_t,
    freelist: freelist_t,
    txnpagelist: txnpagelist_t,

    pub const freelist_t = extern struct {
        // Points to a Page.Freelist page
        first: pageptr_t,
        npages: u64,
    };

    pub const txnpagelist_t = extern struct {
        // Points to a Page.Txnlist page
        first: pageptr_t,
        npages: u64,
    };

    pub const btree_t = extern struct {
        // Points to a Page.BTreeNode page
        root: pageptr_t,
        height: u64,
    };
};

pub const metadata_header_t = extern struct {
    magic: [8]u8,
    checksum: checksum_t,
};

pub const record_header_t = extern struct {
    key_len: u64,
    val_len: u64,
};

pub const btree_keyinfo_t = extern struct {
    offset: u16,
    len_inline: u8,

    pub fn isinline(self: @This()) bool {
        return self.len_inline > 0;
    }
};

pub const btree_overflow_t = extern struct {
    inlined: [btree_inline_maxlen + 1 - @sizeOf(pageptr_t)]u8,
    next: pageptr_t,
};
