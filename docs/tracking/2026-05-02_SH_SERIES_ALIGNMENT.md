# SH Series Alignment Delta — Our Shipped Work vs the Formal Tracker

**Date**: 2026-05-02
**Status**: Documentation
**Branch**: `claude/prologos-layering-architecture-Pn8M9`
**Cross-references**:
- [SH Master Tracker](2026-04-30_SH_MASTER.md) — the formal track structure (10 tracks)
- [Self-Hosting Path and Bootstrap Stages](../research/2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md) — strategy
- [Propagator Network as Super-Optimizing Compiler](../research/2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) — architectural why
- [Tier 0–2 plan](2026-04-30_LLVM_LOWERING_TIER_0_2.md), [Tier 3 plan](2026-05-01_LLVM_LOWERING_TIER_3.md), [N0 plan](2026-05-02_NETWORK_LOWERING_N0.md)

## 1. Purpose

This document catalogs the work shipped on this branch (commits `b3ddcc3` through `0fcf148`) and maps each piece to the formal SH series tracks introduced by the SH Master Tracker (`docs/tracking/2026-04-30_SH_MASTER.md`, 2026-04-30). It also identifies which pieces survive intact, which get reframed, and which get superseded by future track work.

The shipping was speculative: the work happened before the formal track structure was published, guided by collaborator notes and an evolving plan. Now that the formal structure exists, this doc closes the loop.

## 2. What we shipped

15 commits across three plan docs:

### LLVM lowering (Track 1 informal label, "Tier 0–3")

Commits: `b3ddcc3`, `9dca057`, `43cd522`, `4073d3d` (Tiers 0–2), `852d15e`, `9516eb5`, `97ccd90` (Tier 3)

- `racket/prologos/llvm-lower.rkt` — closed AST→LLVM lowering pass
- `tools/llvm-compile.rkt`, `tools/llvm-test.rkt` — CLI + test runner
- `racket/prologos/tests/test-llvm-lower.rkt` — 35 rackunit tests
- 16 acceptance programs across `examples/llvm/tier{0,1,2,3}/`
- `.github/workflows/llvm-lower.yml` — per-tier CI steps

Compiles a typed AST (post-elaboration) directly to LLVM IR for sequential native execution. No propagator network at runtime. Handles literals, Int arithmetic, top-level functions with m0 erasure, conditionals, recursion via boolrec/reduce on Bool.

### Network lowering (Track 2 informal label, "N0")

Commits: `e5deb21` (plan doc), `b77f469` (initial), `8c528fb`, `ffe71a8`, `4c6d8d4`, `d8f9773`, `0fcf148` (CI fixes)

- `runtime/prologos-runtime.zig` — 3-fn kernel (~40 LOC) with extern abort
- `racket/prologos/network-emit.rkt` — typed AST → `network-skeleton` struct
- `racket/prologos/network-lower.rkt` — skeleton → LLVM IR text
- `tools/network-compile.rkt`, `tools/network-test.rkt` — CLI + test runner
- 3 acceptance programs in `examples/network/n0/`
- `.github/workflows/network-lower.yml` — Zig + LLVM substrate path CI

Compiles `def main : Int := <int-literal>` to a native binary that allocates a cell, writes the constant, reads it, exits with the value.

### Issues filed

- **#42** — Persistent HAMT/CHAMP in Prologos
- **#44** — PReductions output contract for downstream LLVM lowering

## 3. Mapping to the formal SH tracks

### 3.1 LLVM lowering (Tiers 0–3)

| Aspect | Maps to | Status |
|---|---|---|
| Architecture | Track 5 (Type erasure boundary) — partial; m0 erasure, closure rejection, primitive ABI all prototyped | Track 5 not formally opened. This work prefigures it. |
| Eventual home | Track 4 (Production LLVM substrate) — fire-fn body compiler is a sub-component | Track 4 won't open for a while; this is held as ready-to-integrate |
| Standalone value | Sequential native compilation of a Prologos subset (no propagator at runtime) | Useful as a pure-AST-to-native path even after Track 4 lands |

**Reposition**: Tiers 0–3 are *the fire-fn body compiler prototype*. Per the SH Master, every propagator's fire-fn must be lowered to native code as part of Track 4's production substrate. Each Prologos function in a propagator-shape program → a fire-fn → a per-function native implementation. Tiers 0–3 demonstrated this lowering for Int + control flow + recursion; Tier 4+ would extend to closures + sums + heap data when needed.

**No Track 5 retrofit needed yet**: Track 5 (type erasure boundary) is gated on PPN Track 4. Our m0 erasure work is consistent with what Track 5 will formalize but doesn't preempt the design.

### 3.2 Network lowering (N0)

| Aspect | Maps to | Status |
|---|---|---|
| Goal | Track 3 ("LLVM substrate PoC") deliverable | **N0 IS the Track 3 deliverable**, done before formal prerequisites |
| Prerequisites done out of order | Track 1 (`.pnet` network-as-value), Track 2 (Low-PNet IR) | We sidestepped both; artifact format is Racket-side struct, not `.pnet` |
| What survives | Zig kernel, ABI shape (cell-alloc/read/write), CI substrate | Reusable as Track 3 evolves |
| What gets replaced | `network-skeleton` struct emitted by `network-emit.rkt` | Replaced by `.pnet`-loaded topology when Track 1 lands |

**Reposition**: N0 is the prototype of Track 3. The Track 3 spec says "smallest end-to-end validation of the substrate-on-LLVM path." That's exactly what N0 ships: a Prologos source compiles via the Racket compiler, the runtime loads structure, the substrate executes, the program exits with the right code. The artifact format (skeleton vs `.pnet`) is incidental to the validation claim.

**Track 3's eventual close**: when Track 1 (`.pnet` network-as-value) lands, the Zig kernel gains a `pnet_load` API and the Racket-side glue switches from "emit skeleton" to "emit `.pnet`." The change is local to:
- `tools/network-compile.rkt` — CLI driver: invoke `.pnet` writer instead of `network-lower.rkt`
- `racket/prologos/network-emit.rkt` — retired in favor of `pnet-serialize.rkt` extension
- `racket/prologos/network-lower.rkt` — retired (or transformed to lower the per-program fire-fn `.o`)
- `runtime/prologos-runtime.zig` — gains `pnet_load`, `pnet_run`, `pnet_read_result` entry points

### 3.3 Issues #42 and #44

| Issue | Maps to | Status |
|---|---|---|
| #42 (HAMT/CHAMP) | Track 6 (Runtime services) — persistent map sub-concern | Stays open. Three-path tradeoff (Zig native vs Prologos library vs hand-translate Racket) named in the issue body. |
| #44 (PReductions output contract) | Cross-series — Track 9 of PRN/PReductions tree | Stays open. SH Master notes Track 9 is "*not* an SH track — cross-series dependency." |

Both issues are correctly scoped as "follow-ups for future tracks" rather than "blockers for current work."

## 4. The artifact-format transition (Track 1 → Track 3 update)

The substantive change when Track 1 lands:

```
BEFORE Track 1 (current N0):

  source.prologos
       ↓ process-file (Racket)
  global-env (typed AST cells)
       ↓ network-emit.rkt
  network-skeleton (Racket struct: cells, writes, result-cell)
       ↓ network-lower.rkt
  source.ll (LLVM IR text with kernel calls)
       ↓ clang + Zig kernel.o
  source.bin (native)

AFTER Track 1 (Track 3 finalized):

  source.prologos
       ↓ process-file (Racket)
  global-env (typed AST cells)
       ↓ pnet-serialize.rkt (Track 1 extension)
  source.pnet (serialized propagator network with topology + fire-fn tags)
       ↓ Tier 0–3 lowering of fire-fn bodies
  source.o (native fire-fn implementations, exported by tag)
       ↓ Zig kernel statically links + dynamically loads .pnet
  (zig kernel, source.pnet, source.o) → execute
```

Key changes:
- `.pnet` is the deployment artifact (matches collaborator's load-bearing observation)
- Fire-fn bodies live in a separate `.o` (parallels GHC's `.hi` + `.o` model)
- The Zig kernel learns to load `.pnet` and resolve fire-fn tags against the `.o`
- Tiers 0–3 work feeds in cleanly as the fire-fn body compiler

The Zig kernel's existing primitives (`prologos_cell_alloc/read/write`) survive unchanged. New primitives are added: `pnet_load`, `pnet_install_propagator(tag, inputs, outputs)`, `pnet_resolve_tag(tag) → fn_ptr`.

## 5. Discrepancies that don't matter and discrepancies that do

### Don't matter

- **Order we did things in.** SH Master expects Tracks 1 and 2 before Track 3; we did Track 3 first via the skeleton sidestep. Result is the same architectural validation.
- **Zig vs Rust for the kernel.** Track 4 ("production LLVM substrate") flags Rust as a candidate for the production host language, citing Inkwell + MMTk ecosystem. Track 3's PoC is too small for that to matter — 40 lines of Zig is fine. Re-evaluate at Track 4 begin.
- **Tier 0–3 not being on the formal track list.** It's the fire-fn body compiler. It feeds Track 4. Standalone, it's also a useful sub-Prologos sequential native compilation path. Doesn't need its own track.

### Do matter

- **N0's artifact format will change.** Worth being explicit: `network-skeleton` is throwaway, `.pnet` is permanent. Don't build N1, N2, ... on the throwaway format.
- **The "extend `.pnet`" work is Track 1.** Significant scope (per the prior chat answer: 7 changes touching `propagator.rkt`, `pnet-serialize.rkt`, `infra-cell.rkt`, plus new files). PPN Track 4 is the cross-series prerequisite per SH Master.
- **Track 2 (Low-PNet IR) is a real gap.** N0 went directly from skeleton → LLVM IR. For larger substrates (with the BSP scheduler, multiple lattice domains, compound cells, fan-in latches), an explicit middle layer is needed. Track 2 design doc would make sense as a parallel track.

## 6. Next-track candidates (in dependency order)

### Path A — wait for prerequisites

1. **Wait for PPN Track 4** to close. Then Track 1 (`.pnet` extension) can open. Then Track 2 (Low-PNet) and Track 3 (real PoC) follow. Multi-quarter.

### Path B — work that's not blocked

Some pieces don't depend on PPN Track 4:

- **Track 2 (Low-PNet IR) design doc** — design work only, no implementation. PRN theory provides the substrate; the design lays out the data model. Can land independently.
- **`.pnet` versioning header** (a Track 1 sub-piece) — purely additive change to `pnet-serialize.rkt`: add a magic + version + mode header, deserialize defaults to current behavior. Backward-compatible; doesn't require PPN Track 4. The version flag is what enables future format changes without breaking existing `.pnet` files.
- **Issue #42 / Issue #44 triage** — categorize against the formal track they belong to (Track 6, Track 9 respectively); update bodies if needed.

Path B preserves momentum without preempting the formal track structure.

## 7. Recommended immediate work

The least risky and highest-leverage near-term move is **adding a version flag to `.pnet`**:

- Pure addition: a few-line `(define current-pnet-format-version "0.1")` + write+read of header magic + version
- Backward compatible: deserialize falls back to `'pre-versioned` mode on missing header
- Forward-aligned: every subsequent `.pnet` change (Track 1's full network-as-value extension, eventual schema changes) becomes safe to roll out
- Diagnostic value: when something breaks across a version boundary, the failure mode is "version mismatch" instead of "structural deserialization error in CHAMP guts"

This is the seed of Track 1 — landing it first means future Track 1 work is incremental rather than format-defining.

## 8. Out of scope for this doc

- The PReductions / PRN work (Track 9) — separate series
- WASM (Track 8) — parallel to LLVM, distant
- Bootstrap verification (Track 10) — depends on Track 9 (compiler-in-Prologos) which is multi-year
- The super-optimizing-compiler architectural claims — covered in companion research doc, not implementation-scope
