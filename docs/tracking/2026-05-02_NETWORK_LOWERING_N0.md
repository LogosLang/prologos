# Network Lowering — N0 (SH Series Track 3 prototype)

**Date**: 2026-05-02
**Status**: Stage 4 implementation — **shipped as a too-early Track 3 prototype**; artifact format will change post-Track-1
**Series**: SH (Self-Hosting) — see [SH Master Tracker](2026-04-30_SH_MASTER.md)
**Branch**: `claude/prologos-layering-architecture-Pn8M9`
**Cross-references**:
- [SH Master Tracker (formal series)](2026-04-30_SH_MASTER.md) — Track 3 ("LLVM substrate PoC") is the formal track this work prototypes
- [Self-Hosting Path and Bootstrap Stages](../research/2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md) — strategy doc; `.pnet`-as-runtime-format is the linchpin
- [SH Series Alignment Delta](2026-05-02_SH_SERIES_ALIGNMENT.md) — how this work relates to the formal track structure
- [Track 1 (Tier 0–2)](2026-04-30_LLVM_LOWERING_TIER_0_2.md), [Track 2 (Tier 3)](2026-05-01_LLVM_LOWERING_TIER_3.md)
- Prior commits: `9f84490`, `307e995`, `ab5513a`, `a6de14d`, `3ac25dd`, `4551684`, `7d2b257`

## 0. Relationship to the formal SH series (added post-rebase 2026-05-02)

The SH Master Tracker landed on main on 2026-04-30 with a 10-track structure. Mapping our shipped work to that structure:

| Our shipped work | Formal SH track | Relationship |
|---|---|---|
| Tiers 0–3 (AST→LLVM lowering) | Track 5 (Type erasure boundary) — partial; also feeds Track 4 fire-fn body compiler | Repositions as fire-fn body compilation prototype, not a track of its own |
| **N0 (this doc)** | Track 3 (LLVM substrate PoC) | **This is the Track 3 deliverable**, but done before Tracks 1 and 2 (its formal prerequisites) |
| Issue #42 (HAMT/CHAMP) | Track 6 (Runtime services) sub-concern | Stays open under Track 6 |
| Issue #44 (PReductions output contract) | Cross-series — Track 9 of PRN/PReductions | Stays open under PReductions |

**The artifact format will change.** N0's input to the Zig kernel is the `network-skeleton` struct emitted by `network-emit.rkt` — a Racket-side data structure. Track 1 (`.pnet` network-as-value) replaces this with a serialized `.pnet` artifact. The Zig kernel's API stays roughly the same (`prologos_cell_alloc/read/write`); the loader changes from "consume a Racket-emitted skeleton" to "load a `.pnet` file." The Tier 0–3 fire-fn body compiler and the Zig kernel both survive; only the glue between them gets replaced.

**Why N0 still has value**: it validates the substrate-on-LLVM shape end-to-end. Track 3's deliverable per the SH Master is "smallest end-to-end validation of the substrate-on-LLVM path." That's exactly what N0 ships — it just used a temporary artifact format. Once Track 1 lands, the loader becomes `.pnet`-aware and N0's contribution merges into the formal track lineage.

## 1. Reframe

Per the roadmap reevaluation: the architecturally correct shape for compiled Prologos programs is **propagator network + minimal runtime**, not sequential AST. Tier 0–3 of LLVM lowering is repositioned as the *fire-fn body compiler* (it lowers individual sequential functions). The new track lowers the *network skeleton* — cells, propagators, dependency graph — and links it against a hand-written runtime kernel.

Stage A.5 (the user's "runtime Racket retirement"): once the kernel + skeleton lower to LLVM, deployed Prologos programs are native binaries with no Racket process. Racket becomes build-time-only, like a dev dependency.

## 2. Scope (N0 only)

The smallest meaningful network: **one cell**, holding a constant value, returned as the program's result.

Acceptance: `def main : Int := 42` compiles to a binary that
1. Calls `prologos_cell_alloc()` to get a cell-id
2. Calls `prologos_cell_write(id, 42)` to store the value
3. Calls `prologos_cell_read(id)` to retrieve it
4. Exits with that integer code

This exercises the kernel's three primitives + the linker glue + the LLVM IR emission — all of the architecture, none of the layered features. Subsequent N-tiers add propagators (N1), the BSP scheduler (N2), persistent maps + domain registry (N3), threading (N4), and topology/ATMS/worldview (N5).

## 3. Architecture

```
.prologos source
    ↓ (Racket-side: process-file)
typed AST in global env
    ↓ (Racket-side: network-emit.rkt)
network skeleton — list of (cell-decl, prop-decl) records
    ↓ (Racket-side: network-lower.rkt)
LLVM IR: declarations of runtime fns + a `main` that calls them
    ↓ (clang, links with prologos-runtime.o)
native binary
```

```
runtime/prologos-runtime.zig         (compiled once via `zig build-obj`)
    ↓
prologos-runtime.o
    ↓ (linked with each compiled program)
binary
```

## 4. Kernel API (N0)

Three exported functions:

```zig
// runtime/prologos-runtime.zig
export fn prologos_cell_alloc() callconv(.C) u32;
export fn prologos_cell_read(id: u32) callconv(.C) i64;
export fn prologos_cell_write(id: u32, value: i64) callconv(.C) void;
```

Implementation: a fixed-size array of `i64` cells (capacity 1024 for N0 — well past sufficient), a counter for the next free slot. No persistent maps, no merging, no dependency graph. Single-threaded.

This is intentionally not a real propagator runtime. It's the skeleton of one — the ABI surface that subsequent tiers grow into.

## 5. Network skeleton

For N0, the skeleton is trivial:

```racket
;; network-skeleton struct (Racket-side)
(struct network-skeleton (cells writes) #:transparent)
;; cells  : Listof cell-decl   — for now: just an integer count
;; writes : Listof (cell-idx . i64-value)  — initial values
```

For `def main : Int := 42`:
- 1 cell (the result)
- 1 write: `(0 . 42)`

The skeleton is consumed by `network-lower` to emit LLVM IR.

## 6. LLVM IR emission

```llvm
declare i32 @prologos_cell_alloc()
declare i64 @prologos_cell_read(i32)
declare void @prologos_cell_write(i32, i64)

define i64 @main() {
entry:
  %c0 = call i32 @prologos_cell_alloc()
  call void @prologos_cell_write(i32 %c0, i64 42)
  %r = call i64 @prologos_cell_read(i32 %c0)
  ret i64 %r
}
```

`@main`'s exit value is `%r` — same exit-code convention as Tier 0–3. No new ABI work.

## 7. Build flow

```
.prologos
   ↓ racket tools/network-compile.rkt prog.prologos -o prog
prog.ll               ← network-lower output
   ↓ clang prog.ll prologos-runtime.o -o prog
prog                  ← native binary

runtime/prologos-runtime.zig
   ↓ zig build-obj prologos-runtime.zig
prologos-runtime.o    ← built once, cached, linked into all programs
```

The `zig build-obj` step uses Zig version pinned via `.zig-version` (or via the CI `setup-zig` action's `version` field). Initial pin: `0.13.0`.

## 8. Local validation strategy

I cannot install Zig in the dev sandbox (the official binary distribution is at ziglang.org which is outbound-blocked). To validate the architecture before pushing:

1. Write the Zig kernel file (committed).
2. Write a *parallel C kernel* with identical ABI (NOT committed; only for local verification).
3. Compile the C kernel locally via `clang -c`, link a generated `.ll`, run, verify exit code.
4. Once architecture is confirmed via the C path, push and let CI validate the Zig path.

The Zig kernel and the C kernel share the same `extern "C"` ABI; if linkage works against C, it works against Zig modulo Zig syntax bugs (which CI catches).

## 9. CI

New workflow `.github/workflows/network-lower.yml`:
- `actions/checkout@v4`
- `Bogdanp/setup-racket@v1.11` with `version: '9.0'`
- `mlugg/setup-zig@v1` with `version: '0.13.0'`
- Verify clang available
- Pre-compile Racket: `raco make racket/prologos/{driver,llvm-lower,network-emit,network-lower}.rkt`
- Build Zig kernel: `zig build-obj runtime/prologos-runtime.zig`
- Run N0 acceptance: `racket tools/network-test.rkt --tier 0 racket/prologos/examples/network/n0`

## 10. Progress Tracker

| Phase | Description | Status |
|---|---|---|
| N0.A | Plan doc | ✅ committed `c223dcf` |
| N0.B | Zig kernel | ✅ `runtime/prologos-runtime.zig` |
| N0.C | network-emit.rkt | ✅ |
| N0.D | network-lower.rkt | ✅ |
| N0.E | network-compile.rkt CLI driver | ✅ |
| N0.F | network-test.rkt directory walker | ✅ |
| N0.G | C-shim local verification | ✅ 3/3 pass via parallel C kernel |
| N0.H | Acceptance programs (3 constants) | ✅ exit-0, exit-42, exit-7 |
| N0.I | CI workflow | ✅ `network-lower.yml` with `mlugg/setup-zig@v1` |
| N0.✅ | Commit + push | 🔄 next |

## Cross-references (added post-implementation)

- Issue #42 — Persistent HAMT/CHAMP in Prologos (gates N3)
- Issue #44 — PReductions output contract for downstream lowering (gates eventual walk-extract migration)

## 11. Out of scope (N1+)

- Propagators: any cell write that triggers another cell update — N1
- BSP scheduler: worklist, fire-and-collect-writes, quiescence — N2
- Lattice merge on writes: domain registry → merge fn → contradiction check — N2
- Persistent maps (CHAMP HAMT): cell value storage as immutable HAMT — N3
- Multiple cells with computed dependencies: real network topology — N1
- Multi-threaded propagator firing: parallel BSP — N4
- ATMS, worldview bitmask, NAF stratum, topology stratum — N5

## 12. Mantra alignment

Same scaffolding statement carried forward from Track 1 § 5: the lowering itself is a Racket function, not a propagator stratum. The runtime kernel IS on-network in the sense that it manages a propagator network at runtime, but its own implementation is sequential C-shaped Zig. That's intrinsic — the "physics" of the network can't itself be propagator-shaped without infinite regress.

## 13. Open questions resolved at scope

- **Q1 (kernel language)**: Zig 0.13.0 pinned. (Resolved 2026-05-02 in chat.)
- **Q2 (fresh emit vs walk-extract)**: Fresh emission via `network-emit.rkt`. P-reductions integration deferred to when PReductions Track 1+ lands. (Resolved 2026-05-02.)
- **Q3 (compile model)**: Pure — every Prologos program eventually compiles to network shape, including trivially-constant programs like N0's. Sequential AST→LLVM (Tier 0–3) becomes scaffolding for the fire-fn body compiler. (Resolved 2026-05-02.)
