# Low-PNet IR — Design Doc (SH Track 2)

**Date**: 2026-05-02
**Status**: Stage 0/1 design proposal
**Track**: SH Track 2 (Low-PNet IR design)
**Branch**: `claude/prologos-layering-architecture-Pn8M9`
**Cross-references**:
- [SH Master Tracker](2026-04-30_SH_MASTER.md) — Track 2 description + open questions
- [SH Series Alignment Delta](2026-05-02_SH_SERIES_ALIGNMENT.md) — flagged Low-PNet as a real gap (§5)
- [Self-Hosting Path and Bootstrap Stages](../research/2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md)
- [`.pnet` change list](previous-chat-answer summarized in alignment doc) — sibling Track 1 work
- Adhesive categories research, SRE form registry research, PRN founding work — see Master Tracker References § Foundational research

## 1. Purpose and scope

This document proposes a data model for **Low-PNet IR**: an explicit lowering layer between the high-level propagator network (cells with lattice merges, propagators as black boxes, scheduler runs to quiescence) and LLVM IR (SSA, basic blocks, types).

Per the SH Master Tracker, Track 2's scope:
> Low-PNet IR design — lowering layer between propagator network and LLVM IR.
> Cells as typed memory regions; propagators as functions over those regions;
> scheduler as worklist data structure; lattice merges inlined or dispatched.
> Analog: GHC's STG/Cmm, MLIR's dialect tower.

This doc establishes the data model — what Low-PNet *is*. It is a design proposal, not an implementation. Implementation is gated on Track 1 (`.pnet` network-as-value) landing first, since Low-PNet consumes `.pnet` artifacts as input.

## 2. Why an IR (and why not direct lowering)

The N0 prototype (commit `b77f469`) lowered `network-skeleton` → LLVM IR directly. That works for ~3 cells + 1 write + 1 read. It does *not* scale to:

- The BSP scheduler (worklist, fire-and-collect, quiescence detection)
- Multiple lattice domains (each with its own merge-fn dispatch)
- Compound cells (component-paths, fan-in latches)
- Topology mutation (new cells/propagators allocated mid-quiescence)
- Worldview bitmask filtering (per-propagator speculation tags)
- ATMS hypothesis tracking (provenance + nogoods)

Each of these is a significant engineering surface. Without an IR layer, every lowering rule for every feature is a one-off case in `network-lower.rkt`. Reading the lowering code becomes archaeology; adding a feature means touching N places.

The IR's job is to **factor out the common structure**: "a propagator network is a fixed set of cells + a fixed set of propagators + a scheduler that fires them to quiescence." Once that factoring is explicit, lowering becomes mechanical, optimizations become reusable, and the LLVM-IR output is regular.

## 3. The data model

Low-PNet has **eight node kinds**. Each is a tagged record. The IR is a list of these nodes in dependency order (declarations before uses).

### 3.1 `(cell-decl id domain-id init-value)`

Declares a cell. At LLVM lowering time:
- `id` becomes a stable u32 cell-id (allocated by the runtime kernel via `prologos_cell_alloc`)
- `domain-id` is looked up against a runtime domain-registry to get the merge-fn pointer
- `init-value` is written via `prologos_cell_write_initial(id, value)` (a kernel API yet to exist)

Example: `(cell-decl 0 'monotone-set (set-empty))`.

### 3.2 `(propagator-decl id input-cells output-cells fire-fn-tag flags)`

Declares a propagator. At LLVM lowering time:
- `fire-fn-tag` is a symbol resolved at link time against a per-program `.o` (per-program fire-fn body) or against the runtime kernel (for built-in fire-fns like `merge-set-union`)
- `input-cells` and `output-cells` reference cell-decl ids
- `flags` carries scheduler hints (fire-once, broadcast, threshold, etc.)

Example: `(propagator-decl 1 (list 0) (list 2) 'int-add 0)`.

### 3.3 `(domain-decl id name merge-fn-tag bot contradiction-pred-tag)`

Declares a lattice domain. At LLVM lowering time:
- `merge-fn-tag` and `contradiction-pred-tag` are symbols resolved against the runtime kernel
- `bot` is the cell's bottom value (a serializable lattice element)

Example: `(domain-decl 0 'monotone-set 'merge-set-union (set-empty) 'never)`.

### 3.4 `(write-decl cell-id value tag)`

Declares an initial write. Distinct from `cell-decl` because:
- Multiple writes can happen at startup (e.g., constant initialization)
- Writes can be tagged for worldview bitmask filtering (post-Track 5)

Example: `(write-decl 0 (set 'a 'b) 0)` — write `(set 'a 'b)` to cell 0 with worldview tag 0 (default).

### 3.5 `(dep-decl prop-id cell-id paths)`

Declares a dependency edge: this propagator depends on this cell, optionally restricted to specific component paths. At LLVM lowering time, this populates the cell's dependent list (informing the scheduler which propagators to wake when the cell changes).

`paths` is a list of component-paths or `'all` if no path restriction. Component paths matter for compound cells (Track 4 in SH Master).

Example: `(dep-decl 1 0 '(all))`.

### 3.6 `(stratum-decl id name handler-tag)`

Declares a stratum (S0, S(-1), S1, topology). At LLVM lowering time:
- `handler-tag` is a symbol resolved against the runtime kernel (kernel-provided strata) or against the per-program `.o` (user-defined strata)
- The scheduler uses the stratum-decl to know what to call between BSP rounds

Example: `(stratum-decl 0 's0-monotone 'kernel-bsp-round)`.

### 3.7 `(entry-decl main-cell)`

Declares the program's entry point — the cell whose final value is the program's result. The lowered `main()` reads this cell after quiescence and exits with its value.

Example: `(entry-decl 5)`.

### 3.8 `(meta-decl key value)`

Declares program-wide metadata (substrate version, compiler version, source file paths for debug info). Optional but useful for diagnostics.

Example: `(meta-decl 'substrate-version "0.1")`.

## 4. Lowering rules to LLVM IR

The IR-to-LLVM lowering is mostly mechanical. Each Low-PNet node maps to a small LLVM IR fragment. Sketches:

### `cell-decl` → kernel call

```llvm
%c0 = call i32 @prologos_cell_alloc(i32 <domain-id>)
; init-value is set by a separate write-decl below if non-bot
```

### `domain-decl` → registry table entry

Domains accumulate into a static array initialized at module load. The runtime kernel's `prologos_init` walks it and registers each domain with the merge-fn-tag → fn-pointer mapping.

```llvm
@__prologos_domains = global [N x %DomainEntry] [
  %DomainEntry { i32 0, i8* @"merge-set-union", i64 <bot-bits>, i8* @"never" },
  ...
]
```

### `propagator-decl` → kernel install + topology binding

```llvm
%fn0 = bitcast i64 (i64*)* @<fire-fn-tag-symbol> to i8*
%p0 = call i32 @prologos_propagator_install(i32 <pid>,
                                              [N x i32] <input-cells>,
                                              [M x i32] <output-cells>,
                                              i8* %fn0,
                                              i32 <flags>)
```

### `write-decl` → direct write

```llvm
call void @prologos_cell_write(i32 %c0, i64 <value>)
```

### `dep-decl` → kernel call

```llvm
call void @prologos_propagator_subscribe(i32 %p0, i32 %c0, i32 <path-tag>)
```

### `stratum-decl` → kernel registration

Strata accumulate into a static array (like domains).

### `entry-decl` → main()

```llvm
define i32 @main() {
entry:
  call void @prologos_init()                   ; install domains, strata, init kernel
  call void @prologos_initial_writes()         ; perform write-decls
  call i32 @prologos_run_to_quiescence()       ; runs scheduler
  %r = call i64 @prologos_cell_read(i32 %main-cell)
  ret i64 %r
}
```

### `meta-decl` → LLVM module metadata

```llvm
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"prologos-substrate-version", !"0.1"}
```

## 5. The lowering pipeline

```
.pnet (Track 1 artifact)
    ↓ pnet-load
in-memory propagator network
    ↓ lower-to-low-pnet
Low-PNet IR (list of decls)
    ↓ lower-to-llvm
LLVM IR text
    ↓ clang + libprologos-runtime
native binary
```

Each arrow is a separate Racket-side pass. The Low-PNet IR is the stable interchange format between "what the elaborator produced" and "what the LLVM emitter consumes."

**Why two arrows instead of one (`.pnet` → LLVM IR directly)?**

1. **Reusability**: Low-PNet IR can also lower to WASM (Track 8), to a sub-Racket interpreter (for testing), or to a future MLIR dialect. The LLVM emitter is one of multiple backends.
2. **Optimization opportunities**: Low-PNet is a natural place for compiler-style optimizations — dead-cell elimination, propagator coalescing, common-subexpression elimination on propagator bodies, constant folding across the network. None of these are practical on raw `.pnet`; all are mechanical on Low-PNet.
3. **Testability**: Low-PNet is small enough to be human-readable. Test cases can assert on Low-PNet shape rather than LLVM IR text, which is more brittle.
4. **Stratum compatibility**: Multiple LLVM lowering strategies (single-block-per-fn vs basic-blocks-per-fire-fn-rule) become alternative emitters consuming the same Low-PNet input.

## 6. Optimization passes (future work, but worth naming)

The IR is designed to enable these. None implemented yet.

| Pass | What it does | When it pays off |
|---|---|---|
| Dead-cell elimination | Remove cells unreachable from `entry-decl` | Cells used only for typing get dropped |
| Propagator inlining | Inline a single-use propagator's fire-fn into its consumer | Common in narrow programs |
| Constant write hoisting | If a cell's only writes are constants known at compile time, replace cell with a constant | Tier 0–3 programs degenerate to this |
| Stratum specialization | If a stratum has a known-empty handler, omit calls to it | Skips topology stratum for programs that never mutate topology |
| Domain monomorphization | If a domain is used by only one cell, inline the merge-fn at the write site | Eliminates dispatch overhead for rare-domain cells |
| Worldview bitmask elision | If a propagator never participates in speculation, omit bitmask checks at fire | Removes overhead for stable subgraphs |

The optimization architecture is: each pass is a Low-PNet → Low-PNet transformation. Composable; orderable; testable in isolation.

## 7. Comparison to GHC's STG/Cmm and MLIR's dialect tower

### GHC's STG/Cmm

- **STG**: lazy functional core. Lambda forms, case-of-known, let-rec.
- **Cmm**: portable assembly. Basic blocks, calls, memory ops, GC barriers.
- Translation: STG → Cmm → native via NCG / LLVM.

Low-PNet is closer to Cmm than STG: it's the "explicit graph" layer where lazy thunks (STG) have been resolved into concrete data + control flow. Our analog of STG is the propagator network itself (still has implicit "fire when ready" semantics); Low-PNet makes the firing explicit.

### MLIR's dialect tower

- Each dialect captures one abstraction layer; passes lower from higher to lower dialects.
- A "tower" is a chain: e.g., your-language-dialect → linalg → memref → llvm.
- Optimization passes can target any layer.

Low-PNet would be one dialect in a notional Prologos MLIR tower. The other dialects might be: Prologos-AST (typed AST as a dialect), Propagator-Net (the high-level network), Low-PNet (this doc), LLVM (final).

We don't need MLIR to do this — Low-PNet as a Racket-side data model is sufficient for now. MLIR adoption is a Track 8 / future-dialect-tower concern.

### Honest comparison

Low-PNet is *less ambitious* than MLIR (one dialect, not a framework). It's *more specialized* than Cmm (knows about propagators + lattices). It's *the right size* for our scope: the smallest IR that abstracts the lowering mechanics without committing to a framework.

## 8. Open questions

### 8.1 Where does the propagator's fire-fn body live?

Three options:

(a) **In the per-program `.o`** — the fire-fn-tag is a symbol exported from a program-specific compiled `.o`. Lowering: `bitcast i64 (...)* @<tag> to i8*`. This is what fire-fn-tag (commit `b0227cb`) is preparing for.

(b) **In the runtime kernel** — built-in fire-fns (lattice merges, structural decomposers, the BSP scheduler itself) are already in `libprologos-runtime`. Tag resolution is a static lookup.

(c) **Embedded as LLVM bitcode in `.pnet`** — the .pnet carries the fire-fn body as bitcode; the loader either JITs or links. Most flexible, most engineering.

Recommendation: (a) for user-defined fire-fns, (b) for built-ins. Defer (c) until JIT use cases emerge.

### 8.2 How does Low-PNet handle ATMS / worldview bitmask?

ATMS adds a layer: each propagator carries a worldview bitmask (which speculation branches it participates in); each cell write tags itself with the firing propagator's bitmask. Low-PNet would need:

- `propagator-decl` gains a `worldview-bits` field
- `write-decl` gains a `tag` field (already in this doc)
- A `prologos_resolve_worldview` kernel API for filtering reads

This complicates the IR. Worth deferring until the ATMS-related Track 5 (type erasure, which interacts with capabilities + sessions + speculation) lands. Initial Low-PNet can be ATMS-free; ATMS extension is a minor version bump.

### 8.3 Should Low-PNet use names or numeric ids?

**Numeric ids** (cell-id 0, 1, 2; prop-id 0, 1, ...): compact, fast, but opaque in test output.

**Symbolic names** (`'main`, `'add-result`, `'is-zero-output`): readable, but require a name table and renaming passes.

Recommendation: numeric ids in the canonical form, with an optional sidecar names map (similar to LLVM IR's `!dbg` metadata). Test framework can render with names; production stays numeric.

### 8.4 Versioning

Low-PNet IR will evolve. A version field on the top-level form (`(low-pnet :version (1 0) (cell-decl ...) ...)` ) lets producers and consumers stay in sync. Same shape as the format-2 wrapper we landed on `.pnet`.

### 8.5 Is this Racket-side or kernel-side data?

Low-PNet IR is **Racket-side only** — the racket compiler emits it from `.pnet`, lowers it to LLVM IR, throws it away. The kernel never sees Low-PNet; it sees only LLVM-emitted code calling kernel APIs.

## 9. Implementation sequencing

When Track 2 opens for implementation:

1. **Phase 2.A — data structures**: define the 8 node kinds as Racket structs. Provide `parse-low-pnet` (read from sexp form), `pp-low-pnet` (pretty-print), and `validate-low-pnet` (basic well-formedness checks).

2. **Phase 2.B — `.pnet` → Low-PNet**: a pure data transformation. Read a Track-1 `.pnet`, walk the propagator structure, emit Low-PNet decls.

3. **Phase 2.C — Low-PNet → LLVM**: rewrite `network-lower.rkt` to consume Low-PNet instead of the `network-skeleton` struct. The N0 acceptance programs continue to pass after this (they just go through one more layer).

4. **Phase 2.D — first optimization pass**: dead-cell elimination, the simplest. Validates the pass infrastructure.

5. **Phase 2.E — Documentation**: a Low-PNet quickstart with worked examples (a `def main : Int := 42`-equivalent; a recursive function; a multi-domain solver).

Phases 2.A and 2.B can land before Track 1 is fully complete (we have N0's `network-skeleton` as a proxy input). Phases 2.C+ depend on Track 1 to be useful end-to-end.

## 10. Sketch of N0 in Low-PNet

To make this concrete, here's `def main : Int := 42` in Low-PNet form:

```
(low-pnet
  :version (1 0)
  :substrate "0.1"

  (meta-decl 'source-file "exit-42.prologos")

  (domain-decl 0 'int 'merge-int-monotone (i64 0) 'never)

  (cell-decl 0 0 (i64 0))      ; main's result cell, domain int

  (write-decl 0 (i64 42) 0)    ; initial constant

  (entry-decl 0))              ; main exits with cell 0's value
```

vs. the current N0 skeleton which has 3 fields (cells, writes, result-cell):

```
(network-skeleton
  '((cell-decl 0 main))
  '((write-decl 0 42))
  0)
```

Low-PNet is more verbose but explicit about every detail (domain, init values, entry vs. write). Current skeleton omits domain (implicit 'int) and uses raw integers for values (no boxing). The verbosity is intentional — it means N1 (a propagator that fires) needs no new struct fields, just one more decl form.

For a one-propagator program (`def main : Int := [int+ 1 2]` if we lowered through propagator shape):

```
(low-pnet
  :version (1 0)
  :substrate "0.1"

  (domain-decl 0 'int 'merge-int-monotone (i64 0) 'never)

  (cell-decl 0 0 (i64 0))      ; in-a
  (cell-decl 1 0 (i64 0))      ; in-b
  (cell-decl 2 0 (i64 0))      ; result

  (write-decl 0 (i64 1) 0)
  (write-decl 1 (i64 2) 0)

  (propagator-decl 0
    (list 0 1)                 ; inputs
    (list 2)                   ; outputs
    'int-add                   ; fire-fn-tag (resolved against kernel's int-add)
    0)                         ; flags

  (dep-decl 0 0 '(all))        ; prop 0 watches cell 0
  (dep-decl 0 1 '(all))        ; prop 0 watches cell 1

  (entry-decl 2))
```

The fire-fn-tag `'int-add` is what `b0227cb` (fire-fn-tag work) just made possible.

## 11. What this design doc commits to

- Eight node kinds (cell-decl, propagator-decl, domain-decl, write-decl, dep-decl, stratum-decl, entry-decl, meta-decl)
- Numeric ids in the canonical form
- Versioned format header (mirrors `.pnet` format-2 wrapper)
- Racket-side only — kernel sees LLVM, not Low-PNet
- Pass-based optimization architecture (Low-PNet → Low-PNet transformations)

## 12. What this design doc explicitly does NOT commit to

- ATMS / worldview bitmask integration (deferred to future minor version)
- MLIR dialect adoption (Track 8 concern)
- Specific optimization passes beyond naming them
- Whether Low-PNet emission happens during compile-to-`.pnet` or compile-from-`.pnet` (could be either; should be either; choose at implementation time)
- Concrete Racket struct field names (will be settled in Phase 2.A)

## 13. Cross-references

- SH Master Tracker, Track 2
- SH Series Alignment Delta §5 — flagged Low-PNet as a real gap
- Issue #44 — PReductions output contract; Low-PNet consumes the same metadata PReductions exposes (fire-fn tags, stratum tags)
- `.pnet` format-2 wrapper (commit `65312be`) — Low-PNet versioning mirrors this
- Fire-fn-tag system (commit `b0227cb`) — provides the symbol space Low-PNet's `propagator-decl` references
- Adhesive categories research, SRE form registry research — provide the theoretical substrate for "everything is DPO rewriting" which justifies the unified IR claim
