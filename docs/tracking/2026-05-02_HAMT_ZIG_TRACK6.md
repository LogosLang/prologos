# Persistent HAMT in Zig — Track 6 sub-piece

**Date**: 2026-05-02
**Status**: Stage 4 implementation
**Track**: SH Track 6 (Runtime services), Issue #42 Path A
**Branch**: `claude/prologos-layering-architecture-Pn8M9`

## 1. Goal

Implement a persistent hash-array-mapped trie in Zig as `runtime/prologos-hamt.zig`. The first non-trivial data structure in the substrate kernel — validates that Zig is the right language for substrate work and provides the persistent-map primitive every Track 4 path needs.

Per Issue #42 Path A: re-implement CHAMP/HAMT in Zig as part of the runtime kernel.

## 2. Scope

### In scope

- 32-way branching trie (Bagwell-style), 5 bits per level
- Wang's 32-bit integer hash on `u32` keys (sequential cell-ids would otherwise produce a degenerate trie)
- Path-copy on insert/remove (persistent semantics — old roots remain valid)
- C-ABI exports for `prologos_hamt_new`, `prologos_hamt_lookup`, `prologos_hamt_insert`, `prologos_hamt_remove`, `prologos_hamt_size`
- Zig unit tests covering: empty, single insert, multi-insert, overwrite, lookup-miss, remove, persistence (old root unaffected by new insert), large-N stress
- C-side smoke test linking the `.o` and exercising the C ABI

### Out of scope (deferred)

- Reference counting or GC — nodes leak on insert/remove. Fine for the substrate kernel where the BSP scheduler controls lifetime; revisit when Track 6 GC design lands. Documented in the Zig source.
- Hash collision handling beyond the 32-bit keyspace (impossible with `u32` keys; would matter for `u64` later)
- Generic value type — fixed `i64` for now (fits cell-ids, propagator-ids, pointer-sized payloads)
- Concurrent / lock-free operation — single-threaded; Track 6 multi-threading is N4+
- Iterator / fold operations — only point queries needed for substrate kernel use

## 3. Algorithm sketch

```
Node = Branch { bitmap: u32, children: [popcount(bitmap)]*Node }
     | Leaf   { key: u32, value: i64 }

hash(k) = wang_hash_u32(k)            # 32-bit pseudorandom output

lookup(node, k, depth):
  case node:
    Leaf(lk, lv): if lk==k then Some(lv) else None
    Branch(bm, cs):
      bit = (hash(k) >> (depth*5)) & 0x1F
      if bm & (1 << bit) == 0: None
      else lookup(cs[popcount(bm & ((1<<bit)-1))], k, depth+1)

insert(node, k, v, depth):
  case node:
    nil:           Leaf(k, v)
    Leaf(lk, lv): if lk==k then Leaf(k, v)        # overwrite
                  else split: a 1- or 2-deep Branch
    Branch(bm, cs):
      bit = ...
      if bm & (1 << bit) == 0:
        # absent: insert new Leaf, copy others
        Branch(bm | (1<<bit), cs ++ [Leaf(k,v)] inserted at index)
      else:
        # present: recurse, copy with replaced child
        new_child = insert(cs[idx], k, v, depth+1)
        Branch(bm, cs[..idx] ++ [new_child] ++ cs[idx+1..])

remove(node, k, depth):
  symmetric; if a Branch ends up with 0 children → return nil;
  if it ends up with 1 leaf child → collapse to that leaf
```

## 4. C ABI

```c
typedef const void* prologos_hamt_t;  // opaque handle (Node* or NULL for empty)

prologos_hamt_t prologos_hamt_new(void);
int            prologos_hamt_lookup(prologos_hamt_t h, uint32_t key, int64_t* out_value);
prologos_hamt_t prologos_hamt_insert(prologos_hamt_t h, uint32_t key, int64_t value);
prologos_hamt_t prologos_hamt_remove(prologos_hamt_t h, uint32_t key);
uint32_t       prologos_hamt_size(prologos_hamt_t h);
```

`lookup` returns 1 if found (writes to `*out_value`) or 0 if absent.

## 5. Tests

- `runtime/prologos-hamt.zig` includes Zig `test` blocks for the algorithm
- `runtime/test-hamt.c` is a standalone C harness that links the `.o` and exercises the C ABI end-to-end
- CI runs both via `zig test` and `clang test-hamt.c prologos-hamt.o`

## 6. Mantra alignment

The HAMT itself is a data structure, not a propagator network. It's substrate infrastructure — the layer below the network. Same scaffolding statement as the rest of the Zig kernel.

## 7. Cross-references

- Issue #42 — Persistent HAMT/CHAMP in Prologos (this commit closes Path A's first phase)
- SH Master Tracker, Track 6 (Runtime services)
- `racket/prologos/champ.rkt` — the Racket-side CHAMP this eventually replaces (~1164 LOC; Zig version expected ~400 LOC)
