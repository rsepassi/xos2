pub const kv_version = 1;
pub const magic_bytes = "KV-37r33";
pub const checksum_size = 32;
pub const page_size = 4096;
pub const btree_sepkey_size = 32;
pub const max_key_len = 512;

// TODO:
// Variable sized keys
// Variable sized values
//
// Allowing entire tree to be in 1 page?
// Root = Last Node = Data page?
// Move root into metadata? 1 fewer page

// How many entries go into 1 btree node?
// Each PAGE_SIZE btree node has k pageptr_t and k-1 btree_sepkey_t
// PAGE_SIZE = k * sizeof(pageptr_t) + (k-1) * sizeof(btree_sepkey_t)
// Solve for k.
pub const btree_branch_factor: usize = (Page.page_size_usable + @sizeOf(btree_sepkey_t)) / (@sizeOf(pageptr_t) + @sizeOf(btree_sepkey_t));

// Page 0: Page.Metadata
// Page 1: Page.Metadata
// Page n: one of
// * Page.BTreeNode
// * Page.BTreeData
// * Page.Freelist
// * Page.Txnlist
pub const Page = struct {
    const reserved_space = 64;
    const page_size_usable = page_size - reserved_space;

    fn PageT(comptime T: type) type {
        const size = @sizeOf(T);
        const npad = page_size_usable - size;
        if (size > page_size_usable) @compileError("type too big for page");
        return extern struct {
            contents: T,
            pad: [npad]u8 = undefined,
            reserved: [reserved_space]u8,
        };
    }

    pub fn bytes(page_t: anytype) *[page_size]u8 {
        if (@sizeOf(@typeInfo(@TypeOf(page_t)).Pointer.child) != page_size) @compileError("bad page type");
        return @ptrCast(page_t);
    }

    pub const Metadata = PageT(extern struct {
        header: metadata_header_t,
        metadata: metadata_t,
    });

    pub const BTreeNode = PageT(extern struct {
        keys: [btree_branch_factor - 1]btree_sepkey_t,
        pages: [btree_branch_factor]pageptr_t,
    });

    // A data page contains a pointer to the next data page and repeated
    // (record_header_t + key + val)
    pub const BTreeData = PageT(extern struct {
        header: btree_data_header_t,
        // TODO: data section - reserved
    });

    pub const Freelist = PageT(extern struct {
        const npages_max = (page_size_usable - @sizeOf(pageptr_t)) / @sizeOf(pageidx_t);
        next: pageptr_t,
        pages: [npages_max]pageidx_t,
    });

    pub const Txnlist = PageT(extern struct {
        const npages_max = (page_size_usable - @sizeOf(pageptr_t)) / @sizeOf(pageptr_t);
        next: pageptr_t,
        pages: [npages_max]pageptr_t,
    });
};

pub const checksum_t = extern struct { data: [checksum_size]u8 };
pub const pageidx_t = u64;
pub const pageptr_t = extern struct {
    checksum: checksum_t,
    idx: pageidx_t,
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
        first: pageptr_t,
        npages: u64,
    };

    pub const txnpagelist_t = extern struct {
        first: pageptr_t,
        npages: u64,
    };

    pub const btree_t = extern struct {
        root: pageptr_t,
        height: u64,
    };
};

pub const btree_sepkey_t = extern struct {
    key: [btree_sepkey_size]u8,
};

pub const btree_val_t = extern struct {
    key: btree_sepkey_t,
    page: pageptr_t,
};

pub const btree_data_header_t = extern struct {
    next: pageptr_t,
};

pub const metadata_header_t = extern struct {
    magic: [8]u8,
    checksum: checksum_t,
};

pub const record_header_t = extern struct {
    key_len: u64,
    val_len: u64,
};
