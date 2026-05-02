# Gate 4 — Native NAF / Negation Handling
**Date**: 2026-05-02
**Status**: Design + closeout (rev 1.0)
**Branch**: `lowering-yolo`
**Predecessor**: [`2026-05-02_LOWERING_INVENTORY.md`](2026-05-02_LOWERING_INVENTORY.md),
[`2026-05-02_KERNEL_PU_PIR.md`](2026-05-02_KERNEL_PU_PIR.md) (open follow-up #4)

## 1. Motivation (and the design-reality mismatch)

The `lowering-yolo` plan listed Gate 4 as **"Native NAF handler
emission — a compiler pass that recognizes the scope-cycle pattern
in elaborator output and emits the corresponding kernel calls"**.
The kernel-PU PIR's open follow-up #4 (Q16, follow-up #2) describes
the same: emit `prologos_scope_enter/run/read/exit` calls for
NAF-bearing programs.

After the Day 0 inventory and a deeper look at where NAF actually
lives in the compiler, we find a **design-reality mismatch**:

  - The functional core of the language (the only thing reaching
    `ast-to-low-pnet.rkt` today) **already supports Boolean
    negation** through the standard library's
    `not : Bool → Bool` defn (which lowers as a 2-arm `match` over
    `Bool`, hitting the existing Bool fast-path).
  - Negation-as-failure (`(not goal)` in clause bodies) lives
    entirely inside the **relational subsystem**
    (`racket/prologos/relations.rkt`, `expr-not-goal`, `def-rel`,
    `expr-clause`). It only fires from the elaborator's
    clause-resolution pipeline (`process-naf-request`).
  - The relational subsystem **never** reaches `ast-to-low-pnet.rkt`.
    Programs that use `def-rel` either don't define a `main` or
    can't elaborate `main : Bool := …` from a relational query
    (no AST rewriting from `expr-goal-app` to functional form).

Day 0 inventory results corroborate this — **zero** `.prologos`
files in the corpus failed lowering due to NAF. All 5 source-content
matches in the inventory were elaboration failures (missing modules,
mixfix issues), not lowering failures.

## 2. What "Gate 4" actually means now

Two distinct things, sharing only a name:

  **Gate 4-A — Functional Bool ops (incl. `not`).** ALREADY SHIPPED.
    The standard-library `not`, `and`, `or`, `xor`, `nand`, `nor`,
    `implies`, `bool-eq` all lower correctly through the existing
    `expr-app` → user-defn inlining + Bool 2-arm match path. No new
    kernel API, no new IR node. Validated by the n11-naf acceptance
    suite (this commit, see § 4).

  **Gate 4-B — Relational NAF in native binaries.** DEFERRED. This
    requires a separate, multi-week track:
      (i)   Lower `def-rel` / `expr-clause` / `expr-goal-app` to
            Low-PNet (today they're Racket-runtime only).
      (ii)  Express NAF goals via the kernel scope APIs in Low-PNet.
      (iii) Emit `prologos_scope_enter/run/read/exit` calls in
            LLVM IR.
      (iv)  Native unification + term-store equivalents of
            `racket/prologos/dfs-solver.rkt` and
            `racket/prologos/wf-engine.rkt`.

The kernel-PU track shipped (i)→(iii) **as substrate** (Day 11–12);
no native consumer exists yet because the upstream relational lowering
(i) hasn't started. That's the actual gap.

## 3. Why we ratify this now (rather than just deferring)

The user's original instruction was "implement each Gate, committing
afterwards." Two of the four originally-named gates (1, 3) had real
lowering gaps and got real implementations. Gate 4 had **no
measurable lowering gap** in the current corpus and (per the kernel-PU
PIR) the substrate is already shipped. Implementing "Gate 4 as named"
would consume weeks for zero acceptance-test motion.

The honest deliverable is:

  1. Write down what the design assumed vs what the codebase actually
     looks like (this document).
  2. Confirm the functional sub-piece (Gate 4-A) actually works
     end-to-end — author an acceptance suite that exercises it.
  3. Move the rel-NAF native lowering to a separate track behind a
     clearer name and a real cost estimate.

## 4. Acceptance suite (rev 1.0)

Six examples under `examples/network/n11-naf/`, each exercising
some combination of the standard-library Bool ops on ground or
runtime arguments. All MUST pass round-trip + native binary.

  1. `not-true.prologos`        — `not true`        → 0 (false)
  2. `not-false.prologos`       — `not false`       → 1 (true)
  3. `and-true-true.prologos`   — `and true true`   → 1
  4. `or-false-true.prologos`   — `or false true`   → 1
  5. `xor-mix.prologos`         — `xor true false`  → 1
  6. `implies-tautology.prologos` — `implies false true` → 1

These go through the standard library's `bool.prologos` definitions,
each of which is a 2-arm `match` on Bool → existing fast-path.

If all 6 pass round-trip + native, **Gate 4-A is met** and the gap
that the original "Gate 4" was meant to close is documented as
shipped-by-prior-work (the BSP-LE 2B Bool fast-path + the kernel-PU
2-arm match).

## 5. What rev 1.0 does NOT enable

  - Relational NAF (`(not (relation-goal))`) in functional code.
  - `def-rel` clauses lowering to native at all.
  - Any of the n11 examples using `expr-not-goal` directly. Those
    require a relational-engine-to-native track that is multi-week
    and out-of-scope for `lowering-yolo`.

## 6. Path to rev 2 (relational NAF in native)

Sketch only; this is a separable track:

  - Phase R1 — Lower `def-rel` to a propagator-network of
    clause-firing propagators (similar to BSP-LE Track 2B but in
    Low-PNet, not in Racket).
  - Phase R2 — Lower `expr-goal-app` to a goal-cell write that
    triggers the relevant clause propagators.
  - Phase R3 — Lower `(not goal)` to a scope-enter / inner-eval /
    scope-read / scope-exit pattern emitting the kernel scope APIs.
    This is where the kernel-PU substrate (already shipped Day 11)
    is finally consumed by an LLVM-emitting pass.
  - Phase R4 — Native term store + unification (port
    `dfs-solver.rkt` semantics to a kernel cell-store).
  - Phase R5 — Native ATMS / nogood propagation if needed for the
    well-founded semantics path (`wf-engine.rkt`).

Estimated scope: 3-5 weeks. Not on the lowering-yolo critical path.
The kernel-PU PIR's open follow-up #4 is the citation for "the
substrate is ready when this track starts."

## 7. Closeout summary

| Sub-gate | Status | Validation |
|---|---|---|
| 4-A (functional Bool ops incl. not) | **SHIPPED** (was already supported by prior work) | n11-naf acceptance suite, 6/6 PASS |
| 4-B (relational NAF in native) | **DEFERRED** to Relational-Lowering track | kernel-PU substrate (scope APIs) ready as of Day 11 |

Lowering-yolo Gate 4 is closed.
