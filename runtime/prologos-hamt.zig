// prologos-hamt.zig — Persistent Hash-Array-Mapped Trie for the substrate kernel.
//
// SH Track 6 sub-piece, Issue #42 Path A.
//
// Bagwell-style HAMT with 32-way branching (5 bits per level), Wang's
// integer hash for key distribution, path-copy on modification for
// persistent semantics. Single-threaded; no reference counting; nodes
// leak on insert/remove (acceptable for PoC scope, see plan doc § 2).
//
// Key type: u32 (fits cell-ids and propagator-ids).
// Value type: i64 (fits cell-ids, propagator-ids, pointer-sized payloads).
// Max trie depth: 6 (uses 30 of the 32 hash bits). Distinct-key collisions
// at the 30-bit prefix level are astronomically rare with wang_hash; they
// abort. Real-world use will keep depths well below 6.
//
// C ABI (see prologos_hamt_* exports at bottom):
//   prologos_hamt_t prologos_hamt_new(void)
//   int             prologos_hamt_lookup(h, key, *out_value)  -> 1 if found
//   prologos_hamt_t prologos_hamt_insert(h, key, value)       -> new root
//   prologos_hamt_t prologos_hamt_remove(h, key)              -> new root
//   uint32_t        prologos_hamt_size(h)                     -> entry count
//
// Pinned to Zig 0.13.0.

const std = @import("std");

extern fn abort() noreturn;

const allocator = std.heap.page_allocator;

const BITS_PER_LEVEL: u5 = 5;
const MASK: u32 = 31;
const MAX_DEPTH: u5 = 6;

// Wang's 32-bit integer hash. Cheap, well-distributed, deterministic.
fn wang_hash(k: u32) u32 {
    var x: u32 = k;
    x = (~x) +% (x << 15);
    x = x ^ (x >> 12);
    x = x +% (x << 2);
    x = x ^ (x >> 4);
    x = x *% 2057;
    x = x ^ (x >> 16);
    return x;
}

const NodeKind = enum(u8) { branch, leaf };

const Node = struct {
    kind: NodeKind,
    payload: extern union {
        branch: extern struct {
            bitmap: u32,
            children_ptr: [*]*Node,
            children_len: u32,
        },
        leaf: extern struct {
            key: u32,
            value: i64,
        },
    },
};

fn make_leaf(key: u32, value: i64) *Node {
    const n = allocator.create(Node) catch abort();
    n.* = .{
        .kind = .leaf,
        .payload = .{ .leaf = .{ .key = key, .value = value } },
    };
    return n;
}

fn make_branch(bitmap: u32, children: []*Node) *Node {
    const n = allocator.create(Node) catch abort();
    n.* = .{
        .kind = .branch,
        .payload = .{ .branch = .{
            .bitmap = bitmap,
            .children_ptr = children.ptr,
            .children_len = @intCast(children.len),
        } },
    };
    return n;
}

fn branch_children(n: *Node) []*Node {
    return n.payload.branch.children_ptr[0..n.payload.branch.children_len];
}

fn idx_for_bit(bitmap: u32, bit: u5) u32 {
    const before_mask: u32 = (@as(u32, 1) << bit) - 1;
    return @popCount(bitmap & before_mask);
}

fn bit_at_depth(hash: u32, depth: u5) u5 {
    return @truncate((hash >> (depth * BITS_PER_LEVEL)) & MASK);
}

// ============================================================
// lookup
// ============================================================

fn lookup_node(maybe_node: ?*Node, key: u32) ?i64 {
    var node = maybe_node orelse return null;
    const hash = wang_hash(key);
    var depth: u5 = 0;
    while (true) {
        switch (node.kind) {
            .leaf => {
                if (node.payload.leaf.key == key) return node.payload.leaf.value;
                return null;
            },
            .branch => {
                if (depth > MAX_DEPTH) abort();
                const bit = bit_at_depth(hash, depth);
                const bm = node.payload.branch.bitmap;
                if (bm & (@as(u32, 1) << bit) == 0) return null;
                const idx = idx_for_bit(bm, bit);
                node = branch_children(node)[idx];
                depth += 1;
            },
        }
    }
}

// ============================================================
// insert
// ============================================================

fn insert_node(maybe_node: ?*Node, key: u32, value: i64) *Node {
    if (maybe_node) |n| {
        return insert_at(n, key, value, wang_hash(key), 0);
    } else {
        return make_leaf(key, value);
    }
}

fn insert_at(node: *Node, key: u32, value: i64, hash: u32, depth: u5) *Node {
    switch (node.kind) {
        .leaf => {
            if (node.payload.leaf.key == key) {
                // Overwrite
                return make_leaf(key, value);
            }
            // Split this leaf with the new entry
            return combine_leaves(node, key, value, hash, depth);
        },
        .branch => {
            if (depth > MAX_DEPTH) abort();
            const bit = bit_at_depth(hash, depth);
            const bm = node.payload.branch.bitmap;
            const cs = branch_children(node);
            const idx = idx_for_bit(bm, bit);

            if (bm & (@as(u32, 1) << bit) == 0) {
                // Bit absent: insert new leaf at idx
                const new_leaf = make_leaf(key, value);
                const new_cs = allocator.alloc(*Node, cs.len + 1) catch abort();
                @memcpy(new_cs[0..idx], cs[0..idx]);
                new_cs[idx] = new_leaf;
                @memcpy(new_cs[idx + 1 ..], cs[idx..]);
                return make_branch(bm | (@as(u32, 1) << bit), new_cs);
            } else {
                // Bit present: recurse on the child at idx
                const new_child = insert_at(cs[idx], key, value, hash, depth + 1);
                const new_cs = allocator.alloc(*Node, cs.len) catch abort();
                @memcpy(new_cs, cs);
                new_cs[idx] = new_child;
                return make_branch(bm, new_cs);
            }
        },
    }
}

// Two leaves with different keys: descend until their hash-bit positions
// at some depth differ, then create a branch holding both. With u32 keys
// and Wang's hash, depth >= MAX_DEPTH on distinct keys is astronomically
// rare; we abort if it happens.
fn combine_leaves(existing: *Node, new_key: u32, new_value: i64, new_hash: u32, depth: u5) *Node {
    if (depth > MAX_DEPTH) abort();
    const existing_key = existing.payload.leaf.key;
    const existing_hash = wang_hash(existing_key);
    const eb = bit_at_depth(existing_hash, depth);
    const nb = bit_at_depth(new_hash, depth);

    if (eb != nb) {
        const new_leaf = make_leaf(new_key, new_value);
        const cs = allocator.alloc(*Node, 2) catch abort();
        if (eb < nb) {
            cs[0] = existing;
            cs[1] = new_leaf;
        } else {
            cs[0] = new_leaf;
            cs[1] = existing;
        }
        const bm = (@as(u32, 1) << eb) | (@as(u32, 1) << nb);
        return make_branch(bm, cs);
    } else {
        // Same bit at this level: recurse one deeper
        const inner = combine_leaves(existing, new_key, new_value, new_hash, depth + 1);
        const cs = allocator.alloc(*Node, 1) catch abort();
        cs[0] = inner;
        const bm = @as(u32, 1) << eb;
        return make_branch(bm, cs);
    }
}

// ============================================================
// remove
// ============================================================

// Returns the new node, or null if the entire subtree should be removed.
fn remove_at(node: *Node, key: u32, hash: u32, depth: u5) ?*Node {
    switch (node.kind) {
        .leaf => {
            if (node.payload.leaf.key == key) {
                return null; // leaf removed
            }
            return node; // key not found at this leaf
        },
        .branch => {
            if (depth > MAX_DEPTH) abort();
            const bit = bit_at_depth(hash, depth);
            const bm = node.payload.branch.bitmap;
            const cs = branch_children(node);
            if (bm & (@as(u32, 1) << bit) == 0) {
                return node; // key not in this branch
            }
            const idx = idx_for_bit(bm, bit);
            const new_child = remove_at(cs[idx], key, hash, depth + 1);

            if (new_child) |child| {
                // Child still exists: replace at idx
                const new_cs = allocator.alloc(*Node, cs.len) catch abort();
                @memcpy(new_cs, cs);
                new_cs[idx] = child;
                return make_branch(bm, new_cs);
            } else {
                // Child removed: drop the slot
                if (cs.len == 1) {
                    return null; // last child gone → branch dies
                }
                const new_cs = allocator.alloc(*Node, cs.len - 1) catch abort();
                @memcpy(new_cs[0..idx], cs[0..idx]);
                @memcpy(new_cs[idx..], cs[idx + 1 ..]);
                const new_bm = bm & ~(@as(u32, 1) << bit);
                // Collapse: if we have exactly one child and it's a leaf,
                // promote the leaf in place of the branch. Keeps the trie
                // tight; lookup still works because lookup compares the
                // full key at any leaf.
                if (new_cs.len == 1 and new_cs[0].kind == .leaf) {
                    return new_cs[0];
                }
                return make_branch(new_bm, new_cs);
            }
        },
    }
}

fn remove_node(maybe_node: ?*Node, key: u32) ?*Node {
    const n = maybe_node orelse return null;
    return remove_at(n, key, wang_hash(key), 0);
}

// ============================================================
// size
// ============================================================

fn size_of(maybe_node: ?*Node) u32 {
    const n = maybe_node orelse return 0;
    switch (n.kind) {
        .leaf => return 1,
        .branch => {
            var total: u32 = 0;
            for (branch_children(n)) |c| {
                total += size_of(c);
            }
            return total;
        },
    }
}

// ============================================================
// C ABI exports
// ============================================================
//
// Opaque handle: ?*Node represented as a pointer (NULL = empty trie).
// All operations are persistent: new roots returned, old roots untouched.

export fn prologos_hamt_new() ?*Node {
    return null;
}

export fn prologos_hamt_lookup(h: ?*Node, key: u32, out_value: *i64) c_int {
    if (lookup_node(h, key)) |v| {
        out_value.* = v;
        return 1;
    }
    return 0;
}

export fn prologos_hamt_insert(h: ?*Node, key: u32, value: i64) ?*Node {
    return insert_node(h, key, value);
}

export fn prologos_hamt_remove(h: ?*Node, key: u32) ?*Node {
    return remove_node(h, key);
}

export fn prologos_hamt_size(h: ?*Node) u32 {
    return size_of(h);
}

// ============================================================
// Zig unit tests
// ============================================================

test "empty trie has size 0 and lookup misses" {
    const h: ?*Node = null;
    try std.testing.expectEqual(@as(u32, 0), size_of(h));
    try std.testing.expectEqual(@as(?i64, null), lookup_node(h, 42));
}

test "single insert + lookup" {
    const h0: ?*Node = null;
    const h1 = insert_node(h0, 7, 100);
    try std.testing.expectEqual(@as(u32, 1), size_of(h1));
    try std.testing.expectEqual(@as(?i64, 100), lookup_node(h1, 7));
    try std.testing.expectEqual(@as(?i64, null), lookup_node(h1, 8));
}

test "multiple inserts preserve all entries" {
    var h: ?*Node = null;
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        h = insert_node(h, i, @as(i64, i) * 10);
    }
    try std.testing.expectEqual(@as(u32, 100), size_of(h));
    i = 0;
    while (i < 100) : (i += 1) {
        try std.testing.expectEqual(@as(?i64, @as(i64, i) * 10), lookup_node(h, i));
    }
    try std.testing.expectEqual(@as(?i64, null), lookup_node(h, 100));
}

test "insert overwrite returns latest value" {
    var h: ?*Node = null;
    h = insert_node(h, 5, 100);
    h = insert_node(h, 5, 200);
    h = insert_node(h, 5, 300);
    try std.testing.expectEqual(@as(u32, 1), size_of(h));
    try std.testing.expectEqual(@as(?i64, 300), lookup_node(h, 5));
}

test "remove a single key" {
    var h: ?*Node = null;
    h = insert_node(h, 5, 100);
    h = insert_node(h, 7, 200);
    h = remove_node(h, 5);
    try std.testing.expectEqual(@as(u32, 1), size_of(h));
    try std.testing.expectEqual(@as(?i64, null), lookup_node(h, 5));
    try std.testing.expectEqual(@as(?i64, 200), lookup_node(h, 7));
}

test "remove of last key returns empty trie" {
    var h: ?*Node = null;
    h = insert_node(h, 5, 100);
    h = remove_node(h, 5);
    try std.testing.expectEqual(@as(u32, 0), size_of(h));
}

test "remove of non-existent key is a no-op" {
    var h: ?*Node = null;
    h = insert_node(h, 5, 100);
    h = remove_node(h, 99);
    try std.testing.expectEqual(@as(u32, 1), size_of(h));
    try std.testing.expectEqual(@as(?i64, 100), lookup_node(h, 5));
}

test "persistence: old root unaffected by insert into derived root" {
    const h0: ?*Node = null;
    const h1 = insert_node(h0, 5, 100);
    const h2 = insert_node(h1, 7, 200);
    // h1 should still see only key 5
    try std.testing.expectEqual(@as(u32, 1), size_of(h1));
    try std.testing.expectEqual(@as(?i64, 100), lookup_node(h1, 5));
    try std.testing.expectEqual(@as(?i64, null), lookup_node(h1, 7));
    // h2 sees both
    try std.testing.expectEqual(@as(u32, 2), size_of(h2));
    try std.testing.expectEqual(@as(?i64, 100), lookup_node(h2, 5));
    try std.testing.expectEqual(@as(?i64, 200), lookup_node(h2, 7));
}

test "persistence: old root unaffected by remove from derived root" {
    var h0: ?*Node = null;
    h0 = insert_node(h0, 5, 100);
    h0 = insert_node(h0, 7, 200);
    const h1 = remove_node(h0, 5);
    // h0 should still see both
    try std.testing.expectEqual(@as(u32, 2), size_of(h0));
    try std.testing.expectEqual(@as(?i64, 100), lookup_node(h0, 5));
    // h1 sees only 7
    try std.testing.expectEqual(@as(u32, 1), size_of(h1));
    try std.testing.expectEqual(@as(?i64, null), lookup_node(h1, 5));
    try std.testing.expectEqual(@as(?i64, 200), lookup_node(h1, 7));
}

test "stress: insert 10000 entries and look them all up" {
    var h: ?*Node = null;
    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        h = insert_node(h, i, @as(i64, i) * 7);
    }
    try std.testing.expectEqual(@as(u32, 10000), size_of(h));
    i = 0;
    while (i < 10000) : (i += 1) {
        try std.testing.expectEqual(@as(?i64, @as(i64, i) * 7), lookup_node(h, i));
    }
}

test "stress: insert then remove half + verify remaining" {
    var h: ?*Node = null;
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        h = insert_node(h, i, @as(i64, i));
    }
    // Remove evens
    i = 0;
    while (i < 1000) : (i += 2) {
        h = remove_node(h, i);
    }
    try std.testing.expectEqual(@as(u32, 500), size_of(h));
    i = 0;
    while (i < 1000) : (i += 1) {
        if (i % 2 == 0) {
            try std.testing.expectEqual(@as(?i64, null), lookup_node(h, i));
        } else {
            try std.testing.expectEqual(@as(?i64, @as(i64, i)), lookup_node(h, i));
        }
    }
}
