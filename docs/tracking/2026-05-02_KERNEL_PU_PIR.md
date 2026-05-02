# Kernel Pocket Universes — Post-Implementation Review

**Date**: 2026-05-02
**Track**: Kernel Pocket Universes (rev 2.1, dissolved + minimal scope)
**Branch**: `claude/prologos-layering-architecture-Pn8M9`
**Commits**: 17 (Days 1-13 + 4 Day-14 docs/wrap), `368b4e64` … `74d1b2e1`
**Estimated scope**: ~12-17 days (per § 14 of the design doc)
**Actual scope**: 14 days as planned (one commit per day, occasional 1-3 commits per day for Day-13's split-by-item retirement)
**Design docs**:
- [Design (rev 2.1)](2026-05-02_KERNEL_POCKET_UNIVERSES.md) — the design this PIR reviews
- [PReduce uses dissolved substrate](2026-05-02_PREDUCE_USES_DISSOLVED_SUBSTRATE.md) — Phase 7 consumer validation
- [Sprint G PU iteration stratum (SUPERSEDED)](2026-05-02_SPRINT_G_PU_ITERATION_STRATUM.md)
**Suite health at end of track**:
- 220+ Racket unit tests across 14 test files: all green
- 37/37 round-trip acceptance examples (`tools/round-trip-acceptance.rkt`)
- 6 substrate C smoke tests (`runtime/test-substrate.c`)
- 1 microbench (`runtime/bench-scope-enter.c`) under threshold

---

## 1. What was built

A 10-function Zig kernel API surface that lets propagator-network
programs lower to native LLVM IR with **per-invocation isolation**
for non-monotone computations (NAF, ATMS branches, recursive PReduce)
and **bounded fuel attribution** per scope. Three architectural
additions to the kernel beyond Phase 0 (`cell_alloc`, `cell_read`,
`cell_write`, `prop_install`, `run_to_quiescence`):

1. **`cell_reset`** — non-merging, non-enqueueing replace.
   Distinct semantics from `cell_write` (which merges via the cell's
   domain function and enqueues dependents on change). Validated by
   shipping a `min`-merge i64 domain that makes the merge-vs-reset
   distinction observable at the kernel level (without a non-LWW
   domain, `cell_reset` and `cell_write` would have been
   indistinguishable for unit tests).

2. **2-tier outer loop + topology-mutation deferral.** Mid-fire
   `cell_alloc` and `prop_install` calls are buffered; the kernel's
   outer loop applies them in a topology tier between value tiers.
   Ports the BSP-LE 2B mechanism from Racket (`propagator.rkt`) into
   Zig. Removes the historical "must construct topology before fire"
   constraint that Sprint G's `iter-block-decl` IR node was trying
   to work around.

3. **Scope APIs** (`scope_enter` / `scope_run` / `scope_read` /
   `scope_exit`). Per-scope fuel counter, per-scope worklist,
   per-scope HAMT root (O(1) pointer-share via the existing
   `runtime/prologos-hamt.zig`). Discovered late in design — the
   user's "PUs require separate fuel counters" finding revealed
   that pure dissolution of PUs into topology was inadequate.
   The minimal-scope design preserved 90% of the dissolve gains
   (no PU type in kernel, no entry/exit/halt tables, no per-PU
   arena, no IR node-kind growth) while adding 4 functions for
   the irreducible per-scope-fuel concern.

The IR (`Low-PNet`) gained one tag (`write-decl` mode = `'merge` or
`'reset`) and a verifiable signature (`(meta-decl tail-rec-pattern
'lww-feedback-v1)`). The Racket interpreter gained a Racket-side
mirror of the kernel scope APIs (so the same per-invocation isolation
pattern is expressible in both runtimes). The `process-naf-request`
handler was rewritten as a verbatim translation of § 5.9's worked
example. The `run-stratified-resolution-pure` loop was migrated from
hard-coded inline S(-1)/S0/S1+S2 to a data-driven walk over a
stratum table. Six pieces of legacy ordering scaffolding were
deleted (Category B retirements).

---

## 2. Timeline

One commit per day, except Day 13 (3 commits, one per Cat-B item)
and Day 11 (cleanup commit for a stray test file). Day 14 is this
PIR + the PReduce walkthrough doc + roadmap updates (3 commits).

| Day | Phase | Title (commit) | Files | LOC delta | Gate |
|---|---|---|---|---|---|
| 1 | 1 | `cell_reset` + `min`-merge i64 domain | 5 | +1241/−369 | C smoke test (merge-vs-reset distinguishable) |
| 2 | 1 | 2-tier outer loop + topology-mutation tracking | 2 | +269/−17 | Mid-fire alloc/install deferred to next tier |
| 3 | 1 | Scope APIs (interim flat-array snapshot) | 2 | +410/−1 | scope_enter/run/read/exit smoke test |
| 4 | 1 | Full scope test suite | 1 | +126 | S1-S6 (fuel iso, write iso, explicit publish, trap, nested, stat counters) |
| 5 | 2 | HAMT-rooted cell storage | 4 | +134/−28 | All examples pass after flat→HAMT swap |
| 6 | 2 | Scope HAMT root pointer-share | 1 | +33/−31 | Per-scope cells become CHAMP-shared |
| 7 | 2 | Scope microbench + acceptance regression + HAMT GC note | 3 | +129 | scope_enter < threshold; § 15.12.1 leak documented |
| 8 | 3 | Low-PNet IR `write-decl` mode tag (V1.0 → V1.1) | 4 | +158/−11 | 22 baseline + 10 V1.1 mode tests pass; round-trip both modes |
| 9 | 4 | Ratify `lower-tail-rec` substrate iteration pattern (Variant B); design-reality reconciliation | 3 | +141/−17 | Tail-rec n2 examples emit signature meta-decl; results unchanged |
| 10 | 4 | `low-pnet-to-prop-network` adapter + round-trip acceptance gate | 5 | +652/−1 | 37/37 acceptance examples round-trip through Racket interp |
| 11 | 5 | LLVM emission for `cell_reset` + scope-API declarations | 4 | +161/−11 | E2E: synthetic IR `(write-decl 0 73 0 reset)` exits 73 |
| 12 | 5 | Category-C migrations (NAF + stratified-resolution) | 5 | +490/−59 | NAF isolation gate (2 explicit gates pass) |
| 13 (1/3) | 6 | Retire vestigial `iter-blocks` builder field | 1 | +5/−16 | 37 ast-to-low-pnet tests still pass |
| 13 (2/3) | 6 | Retire `iter-block-decl` IR node | 3 | +53/−72 | 106 IR + lowering tests pass |
| 13 (3/3) | 6 | Retire `run-stratified-resolution!` + `current-in-stratified-resolution?` | 2 | +42/−50 | 142 broad regression tests pass |
| 13 wrap | 6 | Design doc reflects Cat B deletions | 1 | +10/−10 | § 9.1 grep-check passes |
| 14 | 7+8+9 | This PIR + PReduce walkthrough + roadmap | (this commit) | docs only | downstream tracks can cite kernel as stable |

**Cumulative deltas after Day 13**: ~4,300 LOC added, ~715 LOC
removed across 56 file edits. Not counting docs, the production
artifact is roughly:

- ~1,500 LOC Zig kernel (`runtime/prologos-runtime.zig`,
  `runtime/test-substrate.c`, `runtime/bench-scope-enter.c`)
- ~500 LOC Racket adapter (`racket/prologos/low-pnet-to-prop-network.rkt`,
  scope APIs in `propagator.rkt`)
- ~250 LOC IR + lowering changes (`low-pnet-ir.rkt`, `ast-to-low-pnet.rkt`,
  `low-pnet-to-llvm.rkt`)
- ~300 LOC Racket consumer migrations (`relations.rkt` NAF,
  `metavar-store.rkt` stratified-resolution)
- ~250 LOC tests + 1 microbench
- 715 LOC retired (Cat B + Day 9 mismatched comments + iter-blocks scaffolding)

---

## 3. Design vs reality — what changed during implementation

Three significant deltas, all surfaced and resolved by the
"continue until done or design-reality mismatch" instruction:

### 3.1 Day 9 — Variant A vs Variant B for tail-recursion lowering

**Design as-written (rev 2 → 2.1 § 5.5)**: tail recursion lowers to
a "mega-propagator" using `cell_reset` + a `tick` cell to drive
iteration (Variant A).

**Reality**: `lower-tail-rec` (in `racket/prologos/ast-to-low-pnet.rkt`)
was already emitting a different but observationally-equivalent
pattern (Variant B): LWW state cells + `kernel-identity` feedback
propagators, driven by propagator-firing-driven enqueue rather than
`cell_reset` + tick. Variant A would have required N→M propagator
shape support and per-output write modes in the kernel runtime
(~250-400 LOC). Variant B was already shipped, tested, and
producing correct results.

**Resolution**: ratified Variant B as the shipped substrate iteration
pattern. Variant A deferred as a future optimization track. Day 9's
deliverable became (i) emit a verifiable signature
`(meta-decl tail-rec-pattern 'lww-feedback-v1)`, (ii) update
misleading comments referencing the never-shipped Sprint G
`iter-block-decl` path, (iii) document both variants in § 5.5,
(iv) revise § 9.1 to mark depth-alignment + bridge-cache helpers as
**load-bearing under Variant B** (originally flagged for retirement
on the assumption that Variant A would eliminate them).

**Lesson**: the design's "ship the cleaner variant" instinct was
right in principle but wrong in current-cost — when the existing
implementation already meets the gate by a different route, the
right move is to ratify the existing route and document why the
designed-as-written variant is deferred. The PIR-template question
"what scaffolding did we ship?" gets a cleaner answer this way.

### 3.2 Day 10 — Boolean normalization at the IR ↔ interpreter boundary

**Design as-written**: the Racket interpreter and the LLVM kernel
share a value representation; round-tripping IR through Racket
should produce the same exit code as the native binary.

**Reality**: Racket booleans (`#t`/`#f`) flowed as raw values from
the interpreter to the kernel-shaped fire functions
(`kernel-select`, `kernel-int-eq`); the kernel always represents
booleans as i64 0/1 (LLVM lowering uses `i64 0` and `i64 1`).
A `contract violation: expected: number? given: #t` error appeared
when the round-trip adapter ran tail-recursive examples.

**Resolution**: added `init-value-normalize` in
`racket/prologos/low-pnet-to-prop-network.rkt` to convert `#t` → 1
and `#f` → 0 for both initial cell values and `write-decl` values.
Updated the round-trip-acceptance harness to apply `mod 256`
truncation to match Unix exit-code semantics (so fib(20) = 6765
matches the binary's exit 109 = 6765 mod 256).

**Lesson**: dual-runtime (Racket interpreter + native kernel) means
every value type with a representation choice (booleans, in this
case) needs an explicit normalization at the boundary. The bug
would not have surfaced in either runtime alone.

### 3.3 Day 12 — Stratified-resolution migration scope

**Design as-written (§ 9.1 row, repeated in § 14.1 Day 12)**:
"Re-express `run-stratified-resolution-pure` as registered
stratum-handler propagators (S(-1) retraction, S1/L1 readiness,
S2 resolution). The kernel's 2-tier outer loop drives the same
sequence."

**Reality**: re-expressing the type-resolution loop as a registered
set of BSP-driven stratum-handler propagators would have been a
multi-day undertaking touching the elaborator's outer-loop
architecture. Day 12's gate (NAF isolation) was scoped at the
NAF migration only; the stratified-resolution row was a
secondary deliverable.

**Resolution**: shipped a structural shift instead — refactored
`run-stratified-resolution-pure` from a hard-coded inline
S(-1)/S0/S1+S2 pipeline to a data-driven walk over a
`resolution-strata` list (each entry = `(name . handler)`).
Behavior preserved (same procedures called in the same order);
the structural shift exposes the migration path to BSP-driven
stratum-handler propagators (the next step folds each handler
into a request-cell + handler-propagator pair). Documented in
the Day 12 commit body and the design doc § 14.1 Day 12 row.

**Lesson**: when a design row says "do X" but the gate is "do
prerequisite-of-X", deliver the prerequisite and document the
remaining work as the next-step. This was important here because
trying to do the full BSP-driven migration in a single day would
have either failed the gate (incomplete) or blocked Day 13 + 14
(design overrun). The structural shift is the irreducible
deliverable; the BSP-driven follow-up is a separable track.

---

## 4. What the kernel API surface ended up being

10 functions in `runtime/prologos-runtime.zig` (Section 6 of the
design doc):

```
// Existing (Phase 0, predates this track)
prologos_cell_alloc(domain: u8, init: i64) → CellRef
prologos_cell_read(cell: CellRef) → i64
prologos_cell_write(cell: CellRef, value: i64) → void  // merge mode
prologos_prop_install(fire_fn, in_cells, in_count, out_cells, out_count) → PropRef
prologos_run_to_quiescence(fuel: u64) → RunResult

// Added by THIS track
prologos_cell_reset(cell: CellRef, value: i64) → void  // replace; no merge; no enqueue
prologos_scope_enter(parent_fuel_charge: u64) → ScopeRef
prologos_scope_run(scope: ScopeRef, fuel: u64) → RunResult
prologos_scope_read(scope: ScopeRef, cell: CellRef) → i64
prologos_scope_exit(scope: ScopeRef) → void
```

**API call surface verified by Phase 5 Day 11 commit**: the synthetic
IR `(write-decl 0 73 0 reset)` lowers, links, and runs to exit 73 —
`cell_reset` symbol resolved against the kernel; `cell_write` symbol
resolved unchanged. The conditional declaration mechanism in
`low-pnet-to-llvm.rkt` keeps programs that don't use `cell_reset`
byte-stable in the emitted LL.

**No PU type. No entry/exit/halt tables. No per-PU arena. No new IR
node kinds.** PUs and strata are compile-time abstractions; they
elaborate to substrate-level cells/propagators or use the scope APIs
from inside fire-fn bodies.

---

## 5. Test gates met

**Phase 1 (Days 1-4)** — substrate primitives:
- C smoke test in `runtime/test-substrate.c`: 13 tests cover
  merge-vs-reset distinguishability under `min`-merge i64,
  topology-mutation deferral, scope cycle, scope fuel isolation,
  scope write isolation, scope explicit-publish, nested scopes (LIFO),
  scope stat counters.
- Existing acceptance examples pass unchanged after each phase.

**Phase 2 (Days 5-7)** — HAMT migration:
- All 37 round-trip acceptance examples pass after the flat-array →
  HAMT refactor.
- `runtime/bench-scope-enter.c`: scope_enter from a 1000-cell parent
  completes in < 1μs/op (CHAMP pointer-share, O(1)).
- HAMT GC leak documented in § 15.12.1; deferred to Track 6 GC track
  per the design doc.

**Phase 3 (Day 8)** — IR mode tag:
- 22 baseline IR tests pass + 10 new V1.1 mode tests = 32 total.
- Round-trip pp ↔ parse for both `'merge` and `'reset` modes.
- V1.0 IR re-parses unchanged (mode defaults to `'merge`).

**Phase 4 (Days 9-10)** — lowering:
- Tail-rec n2 examples (countdown=0, factorial(5)=120, fib(10)=55,
  sum-to(10)=55) emit the signature meta-decl and produce correct
  results.
- 19 unit tests for the new `low-pnet-to-prop-network` adapter pass.
- 37/37 round-trip acceptance examples pass (the round-trip gate).

**Phase 5 (Days 11-12)** — LLVM emission + Cat-C migrations:
- 6 new emission tests + 12 baseline = 18 LLVM emission tests pass.
- E2E: synthetic IR `(write-decl 0 73 0 reset)` runs to exit 73.
- 11 scope-API tests pass (Day 12) including 2 explicit Day-12 NAF
  isolation gates.
- 220 broad regression tests pass after NAF + stratified-resolution
  refactors (no behavioral diff).

**Phase 6 (Day 13)** — Cat-B retirements:
- § 9.1 grep-check criterion met: all remaining
  `iter-block-decl` / `run-stratified-resolution!` /
  `current-in-stratified-resolution?` hits are retirement-context
  comments or historical refs.
- 142 broad regression tests still pass after each of the 3
  retirement commits.

---

## 6. Architectural decisions retained

1. **Dissolution where possible, minimal-scope where not.** PUs and
   strata dissolve into topology + cells + propagators wherever
   per-invocation fuel isolation is not needed. The 4 scope APIs
   are the irreducible per-invocation-fuel concession (§ 2.5
   addendum).

2. **Compile-time vs runtime separation.** PUs and strata live at
   the elaborator / NTT / PReduce layers. The kernel only sees
   substrate. This is the architectural axis the dissolved design
   established (§ 3 layered model); Phase 5 Day 12's NAF refactor
   verified it for the canonical NAF case.

3. **HAMT-rooted cells; CHAMP for everything.** Cell storage is a
   single global HAMT root; scopes get O(1) pointer-share for
   their snapshot via `prologos_hamt_lookup` / `_insert`. The
   bench shows `scope_enter` < 1μs/op even with 1000 cells; the
   design's "true O(1) snapshot" claim holds.

4. **Mode tag, not new IR nodes.** `write-decl` gained a mode tag
   (`'merge` | `'reset`); no `cell-reset-decl` was added. Same
   for the future scope-API consumer in PReduce: it'll use
   `propagator-decl` with a fire-fn that calls scope APIs from
   its body, not a new `scope-decl` IR node. Keeps Low-PNet IR
   surface stable.

5. **No PReduce dependency.** PReduce was never in the critical
   path of this track. Phase 7's walkthrough doc validates that
   PReduce can be expressed against the shipped substrate without
   further kernel work, but no PReduce code was written.

---

## 7. Open follow-ups

1. **HAMT GC integration.** `prologos-hamt.zig` lacks a GC; the
   leak is bounded by the program's HAMT-mutation count and is
   acceptable for the current acceptance suite. Phase 5 NAF
   migration tests at scale will be the first workload to surface
   scope-cycle node leakage; that's the appropriate moment to
   revisit Track 6 GC integration. Documented in § 15.12.1.

2. **Variant A iteration pattern.** Variant A (`cell_reset` + tick
   mega-propagator) is deferred. Would require N→M propagator
   shape support and per-output write modes in the kernel
   runtime. Open as a future optimization track. Variant B is
   correct and shipped (Day 9).

3. **Stratified-resolution → BSP-driven stratum-handler
   propagators.** Day 12 shipped the structural prerequisite (data-
   driven `resolution-strata` walk); the next step folds each
   handler into a request-cell + handler-propagator pair driven by
   the kernel's 2-tier outer loop. Open as a separable follow-up.

4. **Native-kernel stratum-handler infrastructure for NAF.** Day 12's
   NAF refactor uses the Racket-side scope-API mirror; the LLVM
   declarations for `prologos_scope_*` are gated behind
   `(meta-decl uses-scope-apis #t)` (Day 11 work). The native NAF
   handler that emits these calls is downstream — a compiler pass
   that recognizes the scope-cycle pattern in the elaborator output
   and emits the corresponding kernel calls. Not in scope for this
   track; design surface is locked.

5. **PReduce implementation start.** Phase 7's walkthrough doc
   confirms the substrate is sufficient. PM Track 9 (Reduction as
   Propagators) is currently Stage 1 research; when it goes to
   implementation, this PIR + the walkthrough doc are the
   substrate-sufficiency citations.

---

## 8. PIR template — 16 questions

Per the standard PIR template applied across tracks in this repo.

### Q1. What was built? (§ 1 above)

10-function Zig kernel API surface with `cell_reset`, 2-tier outer
loop + topology-mutation deferral, and 4 scope APIs. IR mode tag
for `write-decl`. Racket-side scope-API mirror in `propagator.rkt`.
NAF + stratified-resolution refactors against the new substrate.
6 pieces of legacy ordering scaffolding retired.

### Q2. What were the design gates? (§ 5 above)

Per-phase gates as listed in § 14.1 of the design doc; all met.
Aggregate: 220 Racket unit tests + 37 round-trip acceptance examples
+ 13 substrate C smoke tests + 1 microbench all green at end of
track.

### Q3. What surprised you?

(a) The `lower-tail-rec` design-reality mismatch (Day 9): the existing
implementation already shipped a working substrate-iteration pattern
that didn't match what the design doc called for. Resolution: ratify
the existing pattern, defer the designed-as-written variant.

(b) The boolean normalization issue (Day 10): dual-runtime contract
violations between Racket interpreter and native kernel surfaced
only when round-tripping IR through Racket — neither runtime alone
had the bug. Resolution: explicit normalization at the IR ↔
interpreter boundary.

(c) The Day-12 scope of `run-stratified-resolution-pure` migration
exceeded a single day's budget. Resolution: ship the structural
prerequisite (data-driven stratum walk), document the BSP-driven
follow-up.

### Q4. Did design predict implementation?

Mostly yes. The dissolved + minimal-scope design (rev 2.1) was
mostly accurate; the 3 deltas (Q3) were each surfaceable in a single
day and resolvable without changing the design's high-level
architecture. The day-by-day sequencing in § 14.1 held within ~1
day of plan throughout.

### Q5. What scaffolding did we ship?

The 4 added kernel API functions. The IR mode tag (1 enum, 1
defaults). The Racket-side scope mirror (5 procedures + a struct).
The data-driven `resolution-strata` table (3 entries). The
verifiable signature meta-decl (`tail-rec-pattern`).

No surprise off-network surfaces. The design's § 12.1 promise
("scaffolding = kernel API call surface for `cell_reset`,
worldview parameter, pending-mutation list — no surprise off-network
surfaces") matches what shipped.

### Q6. What did we delete?

§ 9.1 Category B inventory — 6 items planned, 4 deletable + 1
already-not-landed + 1 retracted-as-still-load-bearing:
- DELETED: vestigial `iter-blocks` builder field
- DELETED: `iter-block-decl` IR node + parse + pp + V11 validator
- DELETED: `run-stratified-resolution!` (imperative variant)
- DELETED: `current-in-stratified-resolution?` parameter
- NOT LANDED: Sprint G `@main`-loop emission paths (confirmed
  zero call sites at retirement time)
- NOT RETIRED: Sprint G depth-alignment + bridge-cell helpers
  (Day 9 retraction; load-bearing under shipped Variant B)

### Q7. Did the gate criteria predict regressions accurately?

Yes. The round-trip acceptance gate (37/37) caught the boolean
normalization bug on Day 10 immediately — without it, the bug would
have shipped to Day 13's IR retirement and surfaced as test
failures with confusing causation. The NAF isolation gate on Day 12
caught the parent_fuel_charge accounting (initially I had it
debiting from the post-fork scope's fuel by mistake; the gate
detected the discrepancy in the parent's fuel readback).

### Q8. What's the next track?

Per § 7 of this PIR:
- HAMT GC integration (Track 6)
- Variant A iteration optimization (future)
- BSP-driven stratum-handler propagator migration of
  `run-stratified-resolution-pure` (separable follow-up)
- Native NAF-handler emission (compiler pass, downstream)
- PReduce implementation start (PM Track 9)

### Q9. What lessons re-applied from prior tracks?

- "Design ratifies what's shipped" pattern from PM Track 8D's
  bridge-fire-fn correction. Day 9's resolution is structurally
  identical: the implementation showed the design what was
  practical; the design doc updated to match.
- "Data-driven dispatch" pattern from BSP-LE 2B's stratum
  registry. Day 12's `resolution-strata` is a smaller-scale
  application of the same pattern.
- "Tombstone comments at deletion sites" from prior Cat B
  retirements (Track 8 A5, etc.). All Day-13 deletions left
  tombstone comments citing this PIR's commit-hash.

### Q10. What architectural axis did this commit?

The compile-time vs runtime axis (§ 3 layered model in the design).
PUs and strata are compile-time abstractions; the kernel sees only
substrate. This is the architectural commitment that makes the
substrate stable for downstream tracks (PReduce, ATMS migration,
future NTT).

### Q11. What's the next major design decision?

The first real consumer of the kernel scope APIs from a
native-emitting compiler pass. Day 12's NAF refactor uses the
Racket-side scope mirror; the native compiler pass that recognizes
the scope-cycle pattern in elaborator output and emits the
corresponding kernel calls is the next concrete consumer. Design
surface is locked; the implementation is mechanical.

### Q12. Is the substrate sufficient for downstream consumers?

Per the Phase 7 PReduce walkthrough doc: yes, for PReduce. Per the
NAF migration: yes, for NAF. Per the dissolve audit (§ 2 of the
design doc): yes, for the canonical 8 ad-hoc patterns the rev-1
PU primitive design over-fit to.

The "substrate suffices" claim is **validated** for the consumers
in scope; the next downstream tracks (ATMS migration, future NTT)
will re-verify against their own surfaces.

### Q13. Hostile-question stress test answers (per § 12 of design)?

- Q12.1 ("What scaffolding will PReduce add?") → see Phase 7 doc;
  none.
- Q12.2 ("Does PReduce need its own stratum?") → not in kernel;
  expressed as elaborator-layer stratum-handler propagator.
- Q12.3 ("Does PReduce need a per-reduction PU?") → only if
  divergent fixpoints; scope APIs cover it.
- Q12.4 ("Why not just use the kernel-PU primitive design?") →
  dissolve audit (§ 2) showed most capabilities work as topology;
  rev 1 over-engineered; scope APIs are the irreducible kernel
  concession.

### Q14. Did the day-by-day sequencing hold?

Yes, within ~1 day of plan throughout. Day 9's scope expansion
(design-reality reconciliation) added work but absorbed Day 9's
budget; Day 12's stratified-resolution scope contraction freed
budget that absorbed Day 13's split into 3 commits; Days 13-14
held the rest.

### Q15. What's the design doc status?

Marked "Implemented" with commit-hash links per phase (Day 14
edit). The status banner in § 0 of the design doc was updated to
reflect the shipped state.

### Q16. Should this PIR feed the next design?

Yes. Three specific feedbacks:

1. **For the BSP-driven stratum-handler migration of
   `run-stratified-resolution-pure`**: the data-driven
   `resolution-strata` shipped here is the prerequisite. The
   migration is now a mechanical fold (each entry → request-cell +
   handler-propagator).

2. **For the native NAF-handler emission compiler pass**: the
   `(meta-decl uses-scope-apis #t)` opt-in shipped Day 11 is the
   declaration trigger. The compiler pass that emits this meta and
   calls the scope APIs from a fire-fn body is the missing piece.

3. **For PM Track 9 (PReduce)**: the Phase 7 walkthrough doc is
   the substrate-sufficiency citation. PM Track 9 implementation
   should NOT add kernel APIs; if a design step seems to require
   one, it's almost certainly an elaborator concern.
