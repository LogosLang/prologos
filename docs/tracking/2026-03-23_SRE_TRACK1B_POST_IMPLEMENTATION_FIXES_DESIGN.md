# SRE Track 1B: Post-Implementation Fixes

**Stage**: 3 (Design)
**Date**: 2026-03-23
**Series**: SRE (Structural Reasoning Engine)
**Parent**: [SRE Track 1 Design](2026-03-23_SRE_TRACK1_RELATION_PARAMETERIZED_DECOMPOSITION_DESIGN.md)
**PIR**: [SRE Track 1 PIR](2026-03-23_SRE_TRACK1_PIR.md) §10 (Lessons Distilled)
**Master Roadmap**: [MASTER_ROADMAP.org](MASTER_ROADMAP.org)

## 0. Vision and Goal

Track 1 delivered relation-parameterized structural decomposition but left
five architectural gaps identified in the PIR review. Each gap represents
a Completeness violation — the foundation is not yet solid enough to build
Track 2 (Elaborator-on-SRE) on top of.

**Principle**: Completeness. Do the hard thing, the right way, so everything
above it is simpler. Track 1B fixes the foundation before Track 2 builds on it.

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 1 | Microbenchmark + adversarial + frequency analysis | ⬜ | Measure before changing. Informs Phase 2 design. |
| 2 | Merge-per-relation registry | ⬜ | Informed by Phase 1 benchmark data |
| 3 | Relation-parameterized decomposition guard | ⬜ | Pure correctness fix, independent |
| 4 | Dependent duality (sre-decompose-binder) | ⬜ | Proper binder opening for DSend/DRecv |
| 5 | Session duality edge case tests | ⬜ | Partial sessions, incremental, deeply nested, mu |

**Baseline**: SRE Track 1 final (7392 tests, 243.9s, commit `155d0ba`)

## 1. Relation-Parameterized Decomposition Guard

### Problem

`sre-maybe-decompose` uses a name-check (`(eq? (sre-relation-name relation) 'equality)`)
to decide whether binder-depth blocks decomposition. This is ad-hoc — it
breaks if we add new relations and forget to update the check.

### Principled Fix

Add `requires-binder-opening?` to `sre-relation`. The relation declares
whether it needs fresh meta variables during binder decomposition.

```racket
(struct sre-relation
  (name
   sub-relation-fn
   requires-binder-opening?)  ;; NEW: bool — does this relation need binder opening?
  #:transparent)

(define sre-equality
  (sre-relation 'equality ... #t))   ;; equality needs fresh metas for binders

(define sre-subtype
  (sre-relation 'subtype ... #f))    ;; subtype operates on ground types

(define sre-duality
  (sre-relation 'duality ... #f))    ;; duality operates on ground types
```

The SRE checks:
```racket
;; In sre-maybe-decompose:
(cond
  [(zero? (ctor-desc-binder-depth desc))
   (sre-decompose-generic ...)]
  [(sre-relation-requires-binder-opening? relation)
   ;; Fall through to PUnify dispatch for binder opening
   net]
  [else
   ;; Ground-type relation: decompose directly (no binder opening needed)
   (sre-decompose-generic ...)])
```

**Correct-by-construction**: Any new relation must declare its binder-opening
requirement at definition time. Forgetting = compilation succeeds but the
field must be provided (struct construction requires it).

### NTT Correspondence

```prologos
;; NTT: relation declaration carries binder semantics
;; equality needs binder opening (creates fresh cells for bound variables)
;; subtype/duality operate on ground values (no binder opening)
;; This is implicit in the NTT — :lattice :structural with `:relation subtype`
;; on ground types never encounters unsolved binders by construction.
```

## 2. Merge-Per-Relation Registry

### Problem

`sre-domain` has two fixed merge fields: `lattice-merge` (for equality) and
`subtype-merge` (for subtyping). This doesn't scale to additional orderings
(precision for gradual typing, capability ordering, etc.). Each new ordering
requires adding a field to `sre-domain` and updating all instantiation sites.

### Principled Fix

Replace the two fixed fields with a single `merge-registry`: a function (or
hash) from relation name to merge function.

```racket
(struct sre-domain
  (name
   merge-registry    ;; (relation-name → merge-fn) — one merge per relation
   contradicts?      ;; (val → bool)
   bot?              ;; (val → bool)
   bot-value         ;; the bottom element
   top-value         ;; the contradiction element
   meta-recognizer   ;; (expr → bool) | #f
   meta-resolver     ;; (expr → cell-id | #f) | #f
   dual-pairs)       ;; '((Send . Recv) ...) | #f
  #:transparent)

;; Access:
(define (sre-domain-merge domain relation)
  (define reg (sre-domain-merge-registry domain))
  (reg (sre-relation-name relation)))
```

For the type domain:
```racket
(define type-merge-registry
  (lambda (rel-name)
    (case rel-name
      [(equality) type-lattice-merge]
      [(subtype subtype-reverse) subtype-lattice-merge]
      [else (error 'type-merge-registry "no merge for relation ~a" rel-name)])))
```

For the session domain:
```racket
(define session-merge-registry
  (lambda (rel-name)
    (case rel-name
      [(equality) session-lattice-merge]
      [(duality) session-lattice-merge]  ;; duality uses same merge (structural swap, not ordering)
      [else (error 'session-merge-registry "no merge for relation ~a" rel-name)])))
```

**Benefits**:
- sre-domain drops from 10 fields to 9 (merge-registry replaces lattice-merge + subtype-merge)
- Adding a new relation's merge = adding a case to the domain's registry function
- No new struct fields needed for new orderings
- Error on unregistered relation (fail-fast, not silent wrong behavior)

**Propagator changes**: `sre-make-equality-propagator` uses
`(sre-domain-merge domain sre-equality)`. `sre-make-subtype-propagator`
uses `(sre-domain-merge domain relation)` (handles both subtype and
subtype-reverse). Uniform API.

### NTT Correspondence

```prologos
;; NTT: each lattice declaration carries its ordering
;; The merge function IS the ordering (a ≤ b iff merge(a,b) = b)
;; Different relations use different orderings on the same carrier:
;;   equality: flat ordering (Nat ≠ Int → top)
;;   subtype: partial ordering (Nat ≤ Int → Int)
;; The merge-registry is the Racket encoding of NTT's multi-ordered lattice.
```

## 3. Dependent Duality (sre-decompose-binder)

### Problem

DSend/DRecv are registered with binder-depth=1 and binder-open-fn=#f.
The Phase 1 binder-depth bypass decomposes them without opening the binder.
For non-dependent cases (continuation doesn't reference the bound variable),
this accidentally works. For genuinely dependent cases (`DSend(x:Int, S(x))`
where `S` depends on `x`), the continuation sub-cell would contain the
unopened binder expression — wrong.

### Principled Fix

Implement `sre-decompose-binder` as a generic binder decomposition function:

1. Call `binder-open-fn` on the descriptor to open the binder
   - Creates a fresh variable (gensym)
   - Substitutes into the continuation to produce the opened body
2. Create sub-cells: one for the payload type, one for the opened continuation
3. Install sub-relation propagators (payload=equality, continuation=duality)
4. Install reconstructor that closes the binder (re-abstracts over the fresh variable)

For session binders (DSend/DRecv), the `binder-open-fn` uses `substS`
(session substitution with de Bruijn indices):

```racket
;; binder-open-fn for DSend:
(lambda (val sym)
  (define payload (sess-dsend-type val))
  (define cont (sess-dsend-cont val))
  (define opened-cont (substS cont 0 (expr-fvar sym)))
  (values payload opened-cont sym))
```

The fresh variable is shared between both sides of the duality — both
endpoints bind the same payload variable.

**Test cases needed**:
- `DSend(x:Int, Send(x, End))` ~ `DRecv(x:Int, Recv(x, End))` — basic dependent
- Variable appears in continuation type position
- Nested dependent sessions

### NTT Correspondence

```prologos
;; NTT: dependent session types with duality
;; DSend binds a value; the continuation may reference it
;; Under duality: DSend(x:A, S(x)) ~ DRecv(x:A, dual(S(x)))
;; The bound variable x is shared (both sides agree on what was sent)
;; The continuation S(x) is dualized structurally
```

## 4. Session Duality Edge Case Tests

### Problem

All 21 existing session tests passed as a drop-in replacement. But the tests
don't exercise the behavioral differences between the old `(dual v)` approach
and the new SRE structural decomposition.

### Tests Needed

**Partially-known sessions**: cell starts at bot, information arrives later.
Old approach: `dual(Send(Int, bot))` = `Recv(Int, bot)` (dualizes bot).
New approach: creates sub-cells, bot continuation stays bot until propagated.
Test: verify eventual consistency when continuation arrives later.

**Incremental information arrival**: cell-a gets `Send(Int, ?)`, later `?`
resolves to `Recv(Bool, End)`. Verify cell-b correctly becomes
`Recv(Int, Send(Bool, End))` after both pieces of information arrive.

**Deeply nested protocols**: 5+ levels of Send/Recv nesting. Verify
correct dualization at each level.

**Mu (recursive) duality**: `mu(Send(Int, svar(0)))` — infinite protocol.
Verify dual is `mu(Recv(Int, svar(0)))` (mu is self-dual, body gets duality).

**Mixed constructors**: `Send(Int, AsyncRecv(Bool, End))` — Send and AsyncRecv
in the same protocol. Verify correct constructor pairing at each level.

## 5. Microbenchmark + Adversarial Subtype Testing

### Problem

The 3.0% wall time increase is within target but unmeasured. We don't know:
- How many `subtype?` calls occur during a full suite run
- How many trigger the structural (query pattern) path
- What the per-check overhead is for compound types
- Whether deeply nested types cause quadratic behavior

### Deliverables

1. **Frequency measurement**: Run full suite with `current-subtype-check-count`
   instrumented. Report: total calls, structural calls, ratio.

2. **Micro-benchmark**: `bench-subtype.rkt` in `benchmarks/micro/` with:
   - Flat subtype checks (Nat <: Int): baseline speed
   - Structural 1-level (PVec Nat <: PVec Int): query pattern overhead
   - Structural 3-level (PVec (Map String Nat) <: PVec (Map String Int)): nesting
   - Adversarial: 10-level nesting, worst-case fan-out

3. **A/B comparison**: bench-ab.rkt on comparative suite with subtype-enabled
   vs disabled (feature flag on structural path). Measures whether the
   structural path adds measurable overhead to normal compilation.

## 6. Principles Alignment

### Completeness

Each fix addresses a specific Completeness gap:
- Phase 1: Decomposition guard is correct-by-construction (struct field, not name check)
- Phase 2: Merge registry generalizes to any number of orderings (no field-per-ordering)
- Phase 3: Dependent duality works correctly, not accidentally
- Phase 4: Test coverage matches behavioral surface
- Phase 5: Performance understood, not assumed

### Correct-by-Construction

- Phase 1: `requires-binder-opening?` is a required struct field — can't create a relation without declaring it
- Phase 2: Merge registry errors on unregistered relation — fail-fast, not silent wrong merge
- Phase 3: `binder-open-fn` produces opened expression — the SRE never sees unexpanded binders

### Propagator-First

- Phase 2 removes the last off-network merge path — all merges go through the domain's registry, which is data (a function value), not ambient state
- Phase 3 keeps binder opening on-network — the opened continuation goes into a cell, not into a temporary variable

## 7. Completion Criteria

Track 1B is DONE when:
1. All 5 phases complete
2. No name-checks on relation name in sre-core.rkt (Phase 1)
3. sre-domain has 9 fields, not 10 (Phase 2)
4. `DSend(x:Int, S(x)) ~ DRecv(x:Int, dual(S(x)))` passes (Phase 3)
5. ≥10 new session duality edge case tests pass (Phase 4)
6. Microbenchmark results documented; frequency counter data captured (Phase 5)
7. Full suite passes with zero regressions

## 8. Source Documents

| Document | Relationship |
|----------|-------------|
| [SRE Track 1 PIR](2026-03-23_SRE_TRACK1_PIR.md) | Origin: §4 (wrong), §10 (lessons) |
| [SRE Track 1 Design](2026-03-23_SRE_TRACK1_RELATION_PARAMETERIZED_DECOMPOSITION_DESIGN.md) | Parent design |
| [SRE Master](2026-03-22_SRE_MASTER.md) | Series tracking |
| [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | Architectural context |
| [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) | NTT correspondence |
