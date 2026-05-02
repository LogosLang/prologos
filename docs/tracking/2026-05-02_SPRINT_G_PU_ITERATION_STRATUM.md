# Sprint G — Tail-Recursion as Pocket Universe + Iteration Stratum

**Date**: 2026-05-02
**Status**: 🚫 **SUPERSEDED 2026-05-02 by [`2026-05-02_KERNEL_POCKET_UNIVERSES.md`](2026-05-02_KERNEL_POCKET_UNIVERSES.md) (rev 2.1, dissolved + minimal scope architecture).** The iteration case is migrated as Phase 4 (Day 9) of the new track: `lower-tail-rec` is rewritten to emit a substrate iteration pattern (state cells + iter-step propagator + `cell_reset` writes + monotone `tick` cell + halt-guard) directly into Low-PNet IR, with NO `iter-block-decl` IR node and NO `@main` LLVM-loop emission path. Sprint G's Phase 1 (already-shipped `iter-block-decl`) is retired by Phase 6 (Day 13) of the new track. **Do not start Sprint G Phases 2-6** — they are superseded; the work would be wasted because the LLVM `@main`-loop output is the off-network surface the new track is specifically designed to retire (workflow rule § "Ban 'pragmatic'…" + "scaffolding without a retirement plan"). See § 12.4 of the new doc for the architectural rationale, and § 14.1 for the day-by-day sequencing.
**Track**: SH Sprint G (architectural correctness for tail-rec lowering) — **superseded; iteration-case ownership transferred to kernel-pocket-universes track Phase 4**
**Branch**: `claude/prologos-layering-architecture-Pn8M9`
**Cross-references**:
- [Depth Alignment Research (rev 2)](2026-05-02_DEPTH_ALIGNMENT_RESEARCH.md) — origin of the redesign; collaborator critique that F.5/F.6 violate CALM
- [Low-PNet IR Track 2](2026-05-02_LOW_PNET_IR_TRACK2.md) — sibling IR doc; iter-block-decl is an additive node kind
- [SH Series Alignment](2026-05-02_SH_SERIES_ALIGNMENT.md) — Sprint G placement
- [`.claude/rules/stratification.md`](../../.claude/rules/stratification.md) — strata pattern; iteration is a new instance
- [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md) — design mantra, Hyperlattice Conjecture
- [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md) — fan-in / set-latch / fire-once patterns
- [docs/tracking/principles/DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) — Stage 3 design discipline
- PAR Track 0 CALM audit (2026-03-27) — prior precedent: ordering inside S0 means stratum boundary missing
- SRE Track 2G (2026-03-30) — prior precedent: scatter scaffolding retired by Pocket Universe redesign

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| 1 | Extend Low-PNet IR with `iter-block-decl` | ✅ → 🚫 retired by superseding track Phase 6 | landed in same series of edits as the design write-up; struct + parse + pp + V11 validator. **To be deleted at kernel-pocket-universes Phase 6 (Day 13) per § 9.1 Category B.** |
| 2 | Refactor `lower-tail-rec` to emit `iter-block-decl`; drop bridges + feedback edges | 🚫 SUPERSEDED | superseding track Phase 4 (Day 9) rewrites `lower-tail-rec` to emit substrate iteration pattern directly (NO `iter-block-decl`) |
| 3 | Extend `low-pnet-to-llvm` to generate `@main` loop from iter-block | 🚫 SUPERSEDED | superseding track Phase 5 (Day 11) emits `prologos_cell_reset` + `prologos_cell_write` calls (no `@main` loop) |
| 4 | Quarantine F.5/F.6 bridge code (lift-cell-to-depth, emit-aligned-propagator!, bridge-cache, depth-balance invariant) | 🚫 SUPERSEDED | superseding track Phase 6 (Day 13) Category B includes Sprint-G depth-alignment / bridge-cell helpers in `lower-tail-rec`'s rewrite obsolescence |
| 5 | Regression: 34 acceptance examples + benchmarks | 🚫 SUPERSEDED | covered by superseding track Phases 5 + 8 (Days 11-12, 14) |
| 6 | Commit + push + dailies + Master Roadmap update | 🚫 SUPERSEDED | covered by superseding track Phase 9 (Day 14) |

Status legend: ⬜ not started, 🔄 in progress, ✅ done, ⏸️ blocked, 🚫 SUPERSEDED.

---

## 1. Summary

Sprint F.5/F.6 lowered tail-recursion using identity-bridge propagators (Z⁻¹ delay elements) and a feedback edge from `next-state` cells back to `state` cells, all inside a single S0 round. This works for 34 acceptance examples but is a known **CALM violation**: the tail-rec pattern is *non-monotone* (state cells overwrite, not refine), and we hide that non-monotonicity behind ordering inside S0 via depth alignment.

Sprint G replaces this with the architecturally correct lowering:

- **Iteration becomes its own stratum**, separate from S0.
- The tail-rec body's per-iteration computation lives in S0 — fully monotone, CALM-safe.
- The state advance (`state ← next-state`) lives in the **iteration stratum**, which runs after S0 quiesces.
- The iteration loop is realized as **a loop in generated `@main`**, not a kernel-level multi-stratum runtime. This pragmatic realization avoids the 5-10 days of kernel work the research doc estimated.

The architectural shape is: **Pocket Universe** with two strata (S0 + iteration), where the PU's lifecycle is implemented in LLVM control flow rather than in the kernel. This keeps the design CALM-compliant without committing to a kernel-level multi-stratum runtime today.

---

## 2. Motivation (CALM lens)

From the depth-alignment research doc, revision 2:

> F.5/F.6 are *essentially non-monotonic*. Inside S0 we read `state` cells, compute `next-state`, then *overwrite* `state` via the feedback identity propagator. Overwrite is not lattice refinement. The fact that the program produces the right answer relies on **ordering inside the S0 round** (achieved via depth alignment) — exactly what CALM warns against.

The canonical fix per `.claude/rules/stratification.md`:

> Reach for a new stratum when a computation is non-monotone (it can retract information).

State advance retracts the prior iteration's `state` value. That's non-monotone. It belongs in a higher stratum, not in S0.

### 2.1 Why this matters beyond aesthetics

- **Scheduler-agnostic**: F.5's bridges depend on BSP's specific snapshot-then-merge semantics. They would break under a Datalog-style seminaive scheduler that fires propagators in topological order. Sprint G's loop-in-`@main` works under any scheduler.
- **Composable**: nested tail-rec (an outer recursion whose body contains an inner recursion) becomes nested PUs. F.5/F.6 don't compose this way — the outer iteration's depth-alignment would interact catastrophically with the inner's.
- **Future translators inherit it**: every future lowering (NTT, expr-iterate, expr-loop, expr-fold) gets stratification-aware lowering for free instead of inheriting F.5/F.6's anti-pattern.
- **Smaller networks**: bridge cells go away. F.6 measured ~5–25% structural overhead from bridge cells; Sprint G eliminates that.

### 2.2 Mantra audit

> "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."

| Word | F.5/F.6 | Sprint G |
|---|---|---|
| All-at-once | ✗ — depth alignment imposes per-cell sequencing within S0 | ✓ — within an iteration, S0 fires everything in parallel |
| All in parallel | ✗ — bridges are explicit Z⁻¹ delays | ✓ — within S0, no Z⁻¹ |
| Structurally emergent | ✗ — bridge insertion is an imperative pass | ✓ — iteration loop is structural (one loop in `@main`) |
| Information flow | partial — feedback edges DO carry information through cells, but the depth-alignment auxiliary infrastructure is off-network | ✓ — state cells are first-class; iteration handler reads/writes them |
| ON-NETWORK | ✗ — depth tracking lives in the *builder*, not on the network | ✓ — iter-block-decl is a first-class IR node |

Sprint G satisfies the mantra; F.5/F.6 don't.

---

## 3. Pragmatic realization: PU-as-LLVM-loop

The research doc estimated a full kernel-level Pocket Universe runtime would cost 10-15 days. We don't need that today. **The tail-rec PU has only one entry, one exit, one stratum, and one nesting level (always at the top of `@main`).** Under those constraints, the PU collapses to:

```llvm
@main:
  ; (cell allocation + propagator install for everything in the network)
  call run_to_quiescence
  br label %loop_header

loop_header:
  ; read cond cell
  %cond = call cell_read(i64 <cond-cell-id>)
  ; halt-when=#t: halt if cond != 0
  ; halt-when=#f: halt if cond == 0
  %halt = icmp <ne|eq> i64 %cond, 0
  br i1 %halt, label %exit, label %advance

advance:
  ; for each (state-cell, next-cell) in iter-block:
  %v0 = call cell_read(i64 <next-0>)
  call cell_write(i64 <state-0>, i64 %v0)
  %v1 = call cell_read(i64 <next-1>)
  call cell_write(i64 <state-1>, i64 %v1)
  ;; ...
  call run_to_quiescence
  br label %loop_header

exit:
  %r = call cell_read(i64 <result-cell>)
  ret i64 %r
```

### 3.1 Why this realization is sufficient

1. **One stratum (iteration) above S0** — the LLVM loop body IS the stratum handler. No kernel-side handler registration needed.
2. **Each iteration's S0 is fully monotone** — `run_to_quiescence` is the unmodified BSP scheduler. Nothing changes inside the kernel.
3. **State advance is non-monotone but sequenced after S0 quiesces** — the `cell_write(state, read(next))` calls happen between two `run_to_quiescence` invocations, so they're a clean stratum boundary.
4. **Termination via cond cell read** — the loop exits when the cond cell carries the halt value. This is the BSP analog of "stratum handler decides whether to re-enter S0."

### 3.2 What we lose vs full kernel-level PU

- **Multiple strata** — only one extra stratum supported. Tail-rec only needs one, so this is fine for now.
- **Nested PUs** — nested tail-rec would need either another LLVM loop level (mechanical) or a real kernel PU. We don't have nested tail-rec today; defer.
- **Per-PU cell scoping** — all cells live in the parent network's flat array. PU "scope" is conceptual only. Fine for now; no concrete program needs scoped cells yet.

### 3.3 What we gain vs F.5/F.6

- F.5's `lift-cell-to-depth`, F.5's `emit-aligned-propagator!`, F.6's bridge-cache, F.6's depth-balance invariant: **all become unnecessary**. Each iteration's S0 reaches its own monotone fixpoint; no in-stratum ordering is needed because there is no in-stratum non-monotonicity.
- The depth-tracking machinery in the builder (`builder-depths`, `cell-depth`, `set-cell-depth!`) becomes vestigial. We keep it for now (it's read-only, costs nothing) but don't update it.

---

## 4. NTT model

Per the workflow rule "NTT model REQUIRED for propagator designs," here is Sprint G's iter-block expressed in speculative NTT syntax. This is not implementable today (NTT itself is a future track) — the purpose is architectural purity check.

```ntt
;; A tail-rec PU declares: a set of state cells, a set of step expressions,
;; a cond cell, and a halt-when bit. The iter-block is a stratum-handler.

(propagator iter-block
  (:reads (state-cells :lattice :scalar)
          (cond-cell  :lattice :bool))
  (:writes (state-cells :lattice :scalar))
  (:stratum :iteration)
  (:fires-after :S0-quiescence)
  (:fire
    (let ((c (cell-read cond-cell)))
      (cond
        [(halt? c halt-when)  (commit)]   ;; exit PU; result cell read by parent
        [else
         ;; advance: read each next-cell, write to corresponding state-cell
         (for-each-pair (state next state-cells next-cells)
           (cell-write state (cell-read next)))
         ;; re-enter S0: this is the "fires-after" loop.
         (rerun-S0)]))))
```

### 4.1 Correspondence table (NTT → Racket → LLVM)

| NTT construct | Racket realization | LLVM realization |
|---|---|---|
| `(:stratum :iteration)` | `iter-block-decl` IR node | `loop_header` / `advance` blocks |
| `(:fires-after :S0-quiescence)` | implicit: handler runs after BSP quiesces | `call run_to_quiescence` precedes `loop_header` |
| `(cell-read cond-cell)` | builder allocates cond-cell during build | `cell_read(<cond-id>)` in `loop_header` |
| `(halt? c halt-when)` | `halt-when` field on iter-block-decl | `icmp <ne|eq> i64 %cond, 0` |
| `(commit)` | exit the iter-block | `br label %exit` |
| `(for-each-pair (state next ...) ...)` | parallel state-cells/next-cells lists | sequence of `cell_read` + `cell_write` calls |
| `(rerun-S0)` | implicit | `call run_to_quiescence` + `br label %loop_header` |

### 4.2 NTT gaps surfaced by this design

1. **Stratum declaration syntax is missing**. NTT speculative syntax §4 doesn't have `:stratum` or `:fires-after` clauses. Sprint G surfaces this as a needed addition. Recorded in `2026-03-22_NTT_SYNTAX_DESIGN.md` open questions for the future NTT track.

2. **Per-iteration re-entry**. NTT today expresses one-shot propagator firing. Iteration handlers re-enter S0; this is a new control-flow primitive (`rerun-S0`). Two design options for NTT eventually:
   - (a) explicit `(rerun-S0)` action in the handler body
   - (b) declarative `:re-enter-on (cond-cell != halt-value)` — the kernel re-enters automatically based on a predicate
   - Option (b) is more declarative and aligns with the Hyperlattice Conjecture's "computation IS the lattice's Hasse diagram." Defer.

3. **Multi-stratum nesting**. NTT today doesn't have hierarchical strata. The PU pattern needs them eventually. Defer.

These NTT gaps are **not blocking** Sprint G — Sprint G is implemented in Racket today, and the NTT model is architectural reference. The gaps are catalogued for the future NTT track.

---

## 5. Low-PNet IR extension

A new node kind, additive to the existing 8 in `low-pnet-ir.rkt`:

```racket
(struct iter-block-decl (state-cells next-cells cond-cell halt-when) #:transparent)
```

| Field | Type | Meaning |
|---|---|---|
| `state-cells` | `(Listof cell-id)` | the recurrence's state binders, in outermost-first order |
| `next-cells` | `(Listof cell-id)` | parallel: the step expressions' result cells |
| `cond-cell` | `cell-id` | a Bool cell whose value controls iteration |
| `halt-when` | `Bool` | `#t` halts when cond=1 (base-on-true); `#f` halts when cond=0 (base-on-false) |

Invariants (validator V11):
- All cell-ids reference declared `cell-decl` nodes.
- `length(state-cells) = length(next-cells)`.

The `entry-decl` still points at the *result* cell (read once after the loop exits). This is unchanged from the F.5/F.6 design.

A program with no tail-recursion has zero iter-block-decls. A program with one tail-rec call has exactly one. (Multiple tail-rec calls in one program — e.g., two nested or sequenced — would need multiple iter-blocks; Sprint G handles them as a list, with the LLVM lowering sequencing them in `@main`. The acceptance suite doesn't exercise this case, so we'll defer testing it.)

### 5.1 Why a new node kind, not an existing one

- `propagator-decl` represents a *kernel-installed propagator*. iter-block isn't a propagator — it's a control-flow construct in `@main`.
- `stratum-decl` declares that a stratum *exists* (registers a handler). iter-block is *the* iteration stratum's body, not a registration.
- A new node keeps the lowering rule simple: iter-block-decl → `@main` loop blocks.

### 5.2 Future generalization

If we later add `expr-iterate` or `expr-loop` as a first-class language construct, the elaborator can lower them directly to iter-block-decl (skipping the tail-rec recognition pass). The IR node is the convergence point.

---

## 6. AST → Low-PNet lowering changes

### 6.1 `lower-tail-rec` rewrite

Phases of the current `lower-tail-rec`:

1. **init-vts**: literal init values per arg. **KEEP** — no change.
2. **state-vts allocation**: emit cells matching init-vts shape. **KEEP** — these become iter-block's `state-cells`.
3. **cond-expr build**: build the cond-vt from state cells. **KEEP** the build call. **DROP** the cond-init mutation (the `set-builder-cells!` block that flips `#f` → `#t` for `base-on-true?`). Rationale: F.5 needed this so round-1 reads of cond would freeze the right value before the feedback overwrote state. Sprint G has no feedback in S0 — cond's natural fixpoint within the iteration's S0 is what the iter-block reads.
4. **raw-step-vts**: build step expressions in state-env. **KEEP** — these become iter-block's `next-cells` (after shape-flattening).
5. **F.5 lag-matching** (`max-step-depth`, `cond-cid-lifted`, lifted `step-vts`): **DROP entirely**. No bridges.
6. **emit-feedback** (per-leaf select + identity to close the loop): **DROP entirely**. No feedback.
7. **NEW**: emit a single `iter-block-decl` to `builder-iter-blocks` with:
   - `state-cells`: flatten state-vts to a flat cell-id list
   - `next-cells`: flatten raw-step-vts to a flat cell-id list (parallel to state-cells)
   - `cond-cell`: cond-cid from phase 3
   - `halt-when`: `base-on-true?`
8. **base-result**: build the base-result expression in state-env. **KEEP** — its return value (a vtree) is what `lower-tail-rec` returns to its caller.

### 6.2 Why we don't need cond-init mutation anymore

In F.5, the cond cell's initial value mattered because S0's first round computed cond from the *current* state, then the feedback identity wrote `next-state` to `state`, and the *second* round of select+feedback needed cond to already reflect "do we halt or advance" before the state changed under it. The init-flip ensured a stable value.

In Sprint G, *each iteration's S0 reaches a clean fixpoint* before the iteration handler reads cond. State doesn't change during S0. The "base-on-true means cond initializes #t" trick is no longer needed — cond will compute correctly within S0 from the current state cells.

### 6.3 Why we don't need feedback edges

The feedback edge in F.5 (`(emit-propagator! b (list next-cid) state-vt 'kernel-identity)`) closed the iteration loop *inside the network*. In Sprint G, the iteration loop is closed *in `@main`*: after S0 quiesces, the LLVM loop reads the next cells and writes them to state cells. No on-network feedback propagator is needed.

### 6.4 Pair-typed state slots

F.3 added pair-typed state slots; F.4 added Nat. Both work the same way in Sprint G — `flatten-vtree` walks the nested structure to produce a flat cell-id list. The iter-block-decl is shape-blind: it just sees flat lists.

```racket
(define (flatten-vtree vt)
  (cond
    [(exact-integer? vt) (list vt)]
    [else (append-map flatten-vtree vt)]))
```

`length(flatten-vtree state-vt) = length(flatten-vtree next-vt)` is enforced by `vtree-shapes-match?` (already present in F.3/F.4).

### 6.5 Builder field changes

```racket
;; Sprint G addition (already done in this commit's preparatory edit):
(struct builder ([...prior fields...]
                 [iter-blocks #:auto #:mutable])
  ...)

(define (make-builder)
  (define b (builder))
  ;; ...
  (set-builder-iter-blocks! b '())
  b)
```

### 6.6 Entry-point assembly (`ast-to-low-pnet`)

```racket
(low-pnet
 '(1 0)
 (append (list meta)
         domain-decls
         cells-emitted
         props-emitted
         deps-emitted
         (reverse (builder-iter-blocks b))   ; NEW: iter-blocks before entry
         (list (entry-decl result-cid))))
```

Validator V11 confirms cell references; no new ordering constraints beyond "iter-block-decl after the cells it references."

---

## 7. Low-PNet → LLVM lowering changes

### 7.1 Current shape

`low-pnet-to-llvm.rkt` today emits a flat `@main` that does:
1. Cell allocations
2. Propagator installs + dep registrations
3. Initial writes
4. One `call run_to_quiescence`
5. Read entry cell
6. Return

### 7.2 New shape (with iter-blocks)

If the program has zero iter-block-decls, the output is unchanged.

If the program has one or more iter-block-decls, `@main` becomes:

```
1. Cell allocations              (unchanged)
2. Propagator installs           (unchanged)
3. Initial writes                (unchanged)
4. call run_to_quiescence
5. For each iter-block-decl in document order:
   - emit a loop with header / advance / exit blocks (per § 3 above)
6. Read entry cell
7. Return
```

Each iter-block-decl emits its own loop. They're sequenced in `@main` (one fully completes before the next starts). For programs with one iter-block (the common case), this collapses to the single loop shown in § 3.

### 7.3 LLVM SSA detail

For each `(iter-block-decl state-cells next-cells cond-cell halt-when)`:

```llvm
  br label %loop_<n>_header

loop_<n>_header:
  %cond_<n> = call i64 @prologos_cell_read(i64 <cond-cell-id>)
  ; halt-when = #t  →  halt if cond ≠ 0  →  icmp ne
  ; halt-when = #f  →  halt if cond == 0 →  icmp eq
  %halt_<n> = icmp <ne|eq> i64 %cond_<n>, 0
  br i1 %halt_<n>, label %loop_<n>_exit, label %loop_<n>_advance

loop_<n>_advance:
  ; read each next-cell, write to corresponding state-cell
  %v_<n>_0 = call i64 @prologos_cell_read(i64 <next-0>)
  call void @prologos_cell_write(i64 <state-0>, i64 %v_<n>_0)
  ; ... (one read+write per (state, next) pair)
  call void @prologos_run_to_quiescence()
  br label %loop_<n>_header

loop_<n>_exit:
  ; control falls through to next iter-block or to the result-read tail
```

Notes:
- `<n>` is the iter-block's position in the program (0-indexed) so labels don't collide.
- The cell-read/cell-write for the advance is the only non-monotone work; it's safely between two `run_to_quiescence` calls (each of which is monotone S0).
- `prologos_cell_write` is the existing kernel API used for initial writes; here it's used for non-initial writes too. The kernel's domain-merge function still applies — but for iteration state cells we want **overwrite**, not merge. See § 7.4.

### 7.4 Overwrite semantics for iteration state cells

A subtle point: `prologos_cell_write` typically *merges* the new value with the cell's current value via the domain's merge-fn. For an Int cell, `merge(2, 5)` is whatever `kernel-merge-int` defines (typically: contradiction unless equal, or pick-first, or last-write-wins).

Iteration state needs **overwrite**: iteration N's state value replaces iteration N-1's, regardless of merge. Two options:

1. **Add a kernel API** `prologos_cell_overwrite(id, value)` that bypasses merge. Cleanest semantically but requires kernel work.
2. **Use a domain whose merge-fn is last-write-wins** for state cells.
3. **Reset the cell first**: `prologos_cell_reset(id)` then `prologos_cell_write(id, value)`. Two calls per state cell per iteration.

We'll start with **option 3** — it's a kernel API gap we can identify after Phase 3 measures actual cost. If `prologos_cell_reset` doesn't exist yet, add it: it sets the cell back to bot. This is a small, well-scoped kernel addition.

**Open question for Phase 3**: does the existing kernel have `prologos_cell_reset`? If yes, use it. If no, the simplest safe path is option 1 — a new `prologos_cell_overwrite` API. Decide during Phase 3 implementation; document the decision in the PIR.

### 7.5 Shape after Phase 3

The `@main` output for a tail-rec program (e.g., Pell N=5) becomes ~25 LLVM lines longer than F.5/F.6's output but contains ~5–25% fewer cells (no bridges). On benchmark workloads this should be a small wall-time improvement (less per-iteration BSP work) plus a structural simplification of the network.

---

## 8. Migration plan

| Phase | Change | Risk | Verify |
|---|---|---|---|
| 1 | Add `iter-block-decl` to Low-PNet IR. **No behavior change.** | nil | unit tests (22) pass |
| 2 | Refactor `lower-tail-rec`: drop bridges, drop feedback, emit iter-block-decl. **Behavior change in lowered output, but LLVM lowering still emits the F.5 shape until Phase 3.** | medium — programs may not run end-to-end between Phase 2 and Phase 3 | acceptance examples produce iter-block-decl in Low-PNet output; LLVM lowering errors with "iter-block-decl not yet supported" are acceptable mid-phase |
| 3 | Extend `low-pnet-to-llvm` with iter-block loop generation. End-to-end works. | medium — kernel API gap (cell_reset/overwrite) may surface | 34 acceptance examples pass; Pell N=5 = 29 |
| 4 | Quarantine F.5/F.6 code: `lift-cell-to-depth`, `emit-aligned-propagator!`, `bridge-cache`, `assert-depth-balance-invariant!`. Keep `cell-depth` (read-only, no cost). | low | acceptance + benchmark suite green |
| 5 | Benchmark comparison: Pell, fib, etc. Expect ~5-25% fewer cells, comparable or better wall-time. | low | bench-ab.rkt comparisons in PIR |
| 6 | Commit + push + Master Roadmap update | nil | |

**Phase 2 ↔ Phase 3 gap**: between these two phases, the codebase is in a temporarily broken state — `lower-tail-rec` emits iter-block-decls, but `low-pnet-to-llvm` doesn't yet handle them. We'll commit each phase separately; the Phase 2 commit notes that end-to-end is broken until Phase 3. This is acceptable for a development branch (`claude/prologos-layering-architecture-Pn8M9`); we'll rebase or squash if needed before promoting.

Alternative: implement Phases 2 + 3 in parallel and commit them together. Lower risk on the branch; harder to review in isolation. Pick whichever lands smoother during implementation.

---

## 9. Risks and mitigations

| Risk | Mitigation |
|---|---|
| `prologos_cell_overwrite` doesn't exist; merge-fn semantics produce contradictions on state cells | Phase 3 detects this; add the API or use cell_reset. Document in PIR. |
| iter-block-decl ordering vs entry-decl (validator) | V11 already validates cell references; iter-block-decl placed before entry-decl in the output |
| Multiple tail-rec calls in one program | Each emits one iter-block-decl; LLVM lowering sequences them. Defer testing — no acceptance file exercises this case today. Document as known-untested. |
| Future translators want an "iteration stratum" but Sprint G's realization is LLVM-only | When that need arises, promote the iter-block lifecycle to a real kernel-side stratum (research doc § 5 estimates 5-10 days). Sprint G's Low-PNet IR shape (`iter-block-decl`) doesn't change. |
| Depth-tracking machinery left vestigial in builder | Quarantine in Phase 4. Comments mark it as scaffolding from F.5/F.6. Future cleanup commit can delete entirely. |

---

## 10. Vision Alignment Gate

Per `DESIGN_METHODOLOGY.org` § Vision Alignment Gate, before committing each phase:

### 10.1 On-network?

Sprint G's information flow:
- State cells → step propagators (S0, on-network ✓)
- Cond cell → iter-block (read by `@main`'s loop_header — *off-network*, but this is the stratum boundary, which is correct per stratification.md)
- Next cells → state cells (the cell_read + cell_write in `advance` — *off-network* between iterations, which is correct)

**Verdict**: On-network where it should be (S0); off-network at stratum boundaries (which is the definition of a stratum boundary). ✓

### 10.2 Complete?

Each phase has a concrete deliverable + test gate. The design specifies all kernel API gaps (cell_reset/overwrite) before implementation. ✓

### 10.3 Vision-advancing?

Yes. Sprint G:
- Removes a known CALM violation
- Aligns tail-rec lowering with the project's stratification discipline
- Makes the lowering scheduler-agnostic (works under future Datalog seminaive scheduler too)
- Establishes a pattern reusable for future iteration constructs (`expr-iterate`, `expr-loop`)
- Reduces network size

The realization "PU as LLVM loop" is **pragmatic scaffolding** for the kernel-side multi-stratum runtime — but it's pragmatic in the *named* sense ("incomplete because kernel multi-stratum runtime is its own track"), not in the rationalizing sense. The architectural shape (PU + iteration stratum) is correct; the implementation route is the cheapest realization that delivers the architectural benefit today.

### 10.4 Adversarial framing (catalogue → challenge)

| Catalogue | Challenge |
|---|---|
| ✓ Iter-block is a new IR node | Could it be subsumed by stratum-decl + a special tag? — *No, stratum-decl is for kernel-registered handlers; iter-block is LLVM-emitted. Different layer.* |
| ✓ S0 is monotone within an iteration | But the cell_write in `advance` writes to state cells that S0 also writes to. Could S0 see a partial advance? — *No, advance happens between two `run_to_quiescence` calls. S0 is fully quiescent before advance starts; advance fully completes before next S0 starts.* |
| ✓ No feedback edges | What if a propagator inside the body needs the *previous* iteration's state value? — *Sprint G doesn't support this. F.5/F.6 didn't either (state was overwritten before any read of "previous"). Tail-rec's recurrence semantics is "next state computed from current state"; previous-state access would be a different language feature.* |
| ✓ Pragmatic LLVM-loop realization | "Pragmatic" — is this rationalization for incomplete? — *Named explicitly in § 9 as "incomplete because kernel multi-stratum runtime is its own track." Specifies the gap and what would close it. Not rationalization.* |
| ✓ Cell_overwrite or cell_reset | Belt-and-suspenders? — *No, picking ONE API. If kernel already has reset, use it. If not, add overwrite. Decision in Phase 3 based on actual kernel state.* |

---

## 11. Open questions (to resolve during implementation)

1. **Does the kernel have `prologos_cell_reset`?** Resolved during Phase 3.
2. **Is option 3 (reset + write) actually safe?** Specifically: can the reset → write sequence be observed mid-update by another thread? Sprint D's multi-thread BSP work touches this. For Phase 3 (single-threaded), it's fine.
3. **Should we keep or delete `lift-cell-to-depth` etc?** Phase 4 quarantines (comments out / dead-code-marks); a follow-up commit can delete after a few weeks of confidence.
4. **Multi-iter-block programs** — defer testing; document as known-untested in Phase 5 PIR.

---

## 12. References

- Depth Alignment Research rev 2 (`docs/tracking/2026-05-02_DEPTH_ALIGNMENT_RESEARCH.md`) — origin
- Stratification rule (`.claude/rules/stratification.md`) — strata pattern; this design adds the "iteration" stratum as a new instance
- On-Network rule (`.claude/rules/on-network.md`) — design mantra
- PAR Track 0 CALM audit (2026-03-27) — prior precedent on CALM violations
- SRE Track 2G Phase 6 retirement (2026-03-30) — prior precedent on Pocket Universe redesign
- BSP-LE Track 2B PIR §9.6, §12.8 — `register-stratum-handler!` infrastructure
- DESIGN_METHODOLOGY.org § Stage 3 — design discipline, this doc's structure
- POST_IMPLEMENTATION_REVIEW.org — for Sprint G's eventual PIR

---

## 13. Phase deliverables (concrete)

**Phase 1** (DONE): `low-pnet-ir.rkt` adds `iter-block-decl` struct, parser case, pp case, V11 validator. 22 IR tests pass.

**Phase 2**: `ast-to-low-pnet.rkt` `lower-tail-rec` rewritten:
- `make-builder` initializes `iter-blocks` to `'()` ✓ (already done)
- `lower-tail-rec` body: drops `cond` init mutation, drops `max-step-depth` / `cond-cid-lifted` / lifted `step-vts`, drops `emit-feedback`. Emits one `iter-block-decl` to `builder-iter-blocks`.
- `ast-to-low-pnet` entry point: appends `(reverse (builder-iter-blocks b))` to the final low-pnet decl list.
- Test gate: a unit test exercising tail-rec produces an iter-block-decl in the output (we'll add this in Phase 2).

**Phase 3**: `low-pnet-to-llvm.rkt` emits the loop blocks per § 7. Resolves the cell_reset/overwrite kernel API question. Acceptance suite (34 examples) passes.

**Phase 4**: F.5/F.6 code quarantined (or deleted) per § 9.

**Phase 5**: Benchmarks; PIR.

**Phase 6**: Commit, push, Master Roadmap, dailies.

---

**End of design doc.**

When ready to proceed: review this doc, raise objections / propose changes, and on green-light I'll resume Phase 2.
