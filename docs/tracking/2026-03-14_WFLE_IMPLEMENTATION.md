# Well-Founded Logic Engine: Stage 3 Implementation Guide

**Created**: 2026-03-14
**Status**: Stage 3 (Detailed Implementation Plan)
**Depends on**: Stage 2 design (`2026-03-14_WELL_FOUNDED_LOGIC_ENGINE_DESIGN.md`)
**Prerequisite**: Propagator network (propagator.rkt), ATMS (atms.rkt), stratified-eval.rkt, tabling.rkt
**Enables**: Coinductive session types, runtime monitoring, model checking, shield synthesis

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 1 | Descending Cells in propagator.rkt | ✅ | `4a492c7` — cell-dirs field, net-new-cell-desc, net-cell-direction, 15 tests |
| 2 | Bilattice Module (bilattice.rkt) | ✅ | `edb3fad` — lattice-desc, bilattice-var, 3-valued read, consistency propagator, 20 tests |
| 3 | Well-Founded Propagator Patterns (wf-propagators.rkt) | ✅ | `fc83451` — fact/negation/positive/aggregate patterns, clause/program compilation, 25 tests |
| 4a | Well-Founded Engine — Core (wf-engine.rkt) | ✅ | `333130a` — wf-solve-goal, NAF oracle, iterative fixpoint, solver dispatch, 24 tests |
| 5 | Three-Valued Tabling Extension | ✅ | `9bc99fc` — wf-table-entry, wf-all-mode-merge, register/add/answers/complete/certainty, 16 tests |
| 4b | Well-Founded Engine — Tabling Integration | ✅ | `7281c1a` — wf-solve-goal-tabled, current-wf-table-store, per-predicate certainty in WF tables, 5 tests |
| 6 | Test Suite — Known Well-Founded Models | ✅ | `9a03bb9` — 3 test files, 30 tests: literature (13), comparison (10), errors (7) |
| 7 | Benchmark Comparison | ⬜ | |

---

## Executive Summary

This document is the implementation guide for the Well-Founded Logic Engine (WFLE) — an alternate solver backend that computes the well-founded semantics of logic programs with negation via bilattice cell pairs on the existing propagator network.

The design is grounded in:

- Stage 2 design: `2026-03-14_WELL_FOUNDED_LOGIC_ENGINE_DESIGN.md` — gap analysis, approach selection (A: bilattice pairs), resolved open questions
- Research: `FORMAL_MODELING_ON_PROPAGATORS.org` §3 (AFT), §7 (propagator universality)
- Research: `PROPAGATORS_AS_MODEL_CHECKERS.org` §2 (μ-calculus mapping)
- Existing infrastructure: `2026-02-24_LOGIC_ENGINE_DESIGN.md` — the Logic Engine this parallels

**Core idea**: Each logic variable gets two propagator cells — `lower` (ascending, starts ⊥) and `upper` (descending, starts ⊤). Propagators update both monotonically in the precision ordering. At quiescence, the gap `[lower, upper]` yields three-valued output: true / false / unknown.

**Key resolved decisions** (from Stage 2):
1. Approach A (bilattice pairs) — trades 2× cell count for scheduling simplicity
2. Simultaneous convergence — both μ and ν cells fire in same `run-to-quiescence` pass
3. ATMS composes orthogonally — branching (ATMS) and incomplete information (bilattice) are separate concerns
4. Grounding via tabled evaluation — SLG-style with three-valued table entries
5. No syntax changes — backend-only; the only user-visible difference is `'unknown` instead of compile errors for cyclic negation

The engine is built in 7 phases:

1. **Descending Cells** — extend propagator.rkt with meet-fns, cell-dirs, `net-new-cell-desc`
2. **Bilattice Module** — `bilattice-var` struct, construction, reading, Boolean bilattice
3. **Well-Founded Propagator Patterns** — positive/negative/unfounded propagators
4. **Well-Founded Engine** — solver orchestration, dispatch, three-valued output
5. **Three-Valued Tabling** — extend tabling.rkt for `'unknown` entries
6. **Test Suite** — known models from the literature, comparison with stratified engine
7. **Benchmark Comparison** — same programs on both backends, measure time/correctness


## Acceptance File

Per workflow rules, a `.prologos` acceptance file is written BEFORE implementation. This file exercises the WFLE through WS-mode surface syntax — the primary design target.

**File**: `examples/2026-03-14-wfle-acceptance.prologos` (commit `742e075`)

9 sections covering the full relational language capability envelope:

| Section | Coverage | Status |
|---------|----------|--------|
| A. Baseline | facts, rules, recursion, unification, NAF, modes | ✅ Passing |
| B. Solver configuration | `solver` form, `solve-with`, `semantics` key | Commented |
| C. Well-founded semantics | odd cycles, self-ref, Nixon diamond, win/lose | Commented |
| D. Explain and provenance | three-valued explanations, cycle info | Commented |
| E. Tabling interaction | `:tabled` + WF, per-variant certainty | Commented |
| F. Advanced relational | `is`, `guard`, `cut`, multi-arity, `rel`, `solve-one`, `schema` | Commented |
| G. Functional interaction | solve results in def/let/match, QTT | Commented |
| H. Type system interaction | Solver/Goal/Relation types | Commented |
| I. Edge cases | empty relations, timeout, engine switching | Commented |

This file is the Level 3 validation gate. The WFLE is not DONE until all target expressions run with 0 errors via `process-file`. Sections B and F also serve as a gap-detection mechanism — features that exist at sexp level but may not be fully wired to WS mode.


## Critical Path

```
Phase 1 (Descending Cells — propagator.rkt)
  ↓
Phase 2 (Bilattice Module — bilattice.rkt)
  ↓
Phase 3 (WF Propagator Patterns — wf-propagators.rkt)
  ↓
Phase 4a (WF Engine Core — wf-engine.rkt)
  ↓                  ↓
Phase 5 (Tabling)    Phase 6a (Ground WF Tests)
  ↓
Phase 4b (Engine + Tabling Integration)
  ↓
Phase 6b (Full Test Suite)
  ↓
Phase 7 (Benchmark Comparison)
```

Phases 1–3–4a are strictly sequential. Phase 5 (tabling) can begin after Phase 3. Phase 4b requires both 4a and 5. Phase 6 has ground-only tests (6a, after 4a) and full tests (6b, after 4b). Phase 7 requires all prior phases.

---

# Phase 1: Descending Cells in propagator.rkt

## 1.1 Goal

Extend the existing propagator network to support **descending cells** — cells that start at ⊤ (top) and refine downward via meet. This is the infrastructure prerequisite for bilattice pairs and all future ν-fixpoint applications.

## 1.2 Theory

A descending cell computes a greatest fixpoint (gfp). Where an ascending cell starts at ⊥ and rises via join (accumulating evidence), a descending cell starts at ⊤ and falls via meet (eliminating possibilities). The convergence criterion is identical but direction-reversed: `meet(old, new) = old` means no change.

The existing `net-cell-write` uses `merge-fn(old, new)` and checks `merged = old`. For ascending cells, `merge-fn` = join. For descending cells, `merge-fn` = meet. The only structural change needed is:

1. A way to create cells with meet semantics and a ⊤ initial value
2. A direction tag so the scheduler (and contradiction detection) know which way is "progress"
3. Updated contradiction detection: ascending cell contradicts at ⊤; descending cell contradicts at ⊥

## 1.3 Data Structure Changes

### 1.3.1 New Fields in `prop-network`

```racket
;; Add to prop-network struct:
;;   cell-dirs: champ-root : cell-id → 'ascending | 'descending
;;
;; This is a registry parallel to merge-fns. Cells without an entry
;; in cell-dirs default to 'ascending (backward compatible).
```

The `prop-network` struct gains one new field: `cell-dirs`. This requires updating `make-prop-network` and all `struct-copy` sites.

```racket
;; Updated struct (add cell-dirs after pair-decomps):
(struct prop-network
  (cells propagators worklist
   next-cell-id next-prop-id fuel contradiction
   merge-fns contradiction-fns widen-fns
   cell-decomps pair-decomps
   cell-dirs)          ;; NEW: champ-root : cell-id → 'ascending | 'descending
  #:transparent)
```

### 1.3.2 Updated `make-prop-network`

```racket
(define (make-prop-network [fuel 1000000])
  (prop-network champ-empty    ;; cells
                champ-empty    ;; propagators
                '()            ;; worklist
                0              ;; next-cell-id
                0              ;; next-prop-id
                fuel           ;; fuel
                #f             ;; no contradiction
                champ-empty    ;; merge-fns
                champ-empty    ;; contradiction-fns
                champ-empty    ;; widen-fns
                champ-empty    ;; cell-decomps
                champ-empty    ;; pair-decomps
                champ-empty))  ;; cell-dirs (NEW)
```

## 1.4 Core Operations

### 1.4.1 `net-new-cell-desc` — Create a Descending Cell

```racket
;; Create a new descending cell (starts at top, refines downward via meet).
;; top-value: the lattice ⊤ (initial value)
;; meet-fn: (old-val new-val → met-val) — the lattice meet
;; contradicts?: optional (val → Bool) — for descending, typically (lambda (v) (eq? v bot))
;; Returns: (values new-network cell-id)
(define (net-new-cell-desc net top-value meet-fn [contradicts? #f])
  (define id (cell-id (prop-network-next-cell-id net)))
  (define cell (prop-cell top-value champ-empty))
  (define h (cell-id-hash id))
  (define net*
    (struct-copy prop-network net
      [cells (champ-insert (prop-network-cells net) h id cell)]
      ;; Use merge-fns registry for meet-fn too — the merge-fn IS the meet
      ;; (net-cell-write uses merge-fn generically; for descending cells, it's meet)
      [merge-fns (champ-insert (prop-network-merge-fns net) h id meet-fn)]
      [cell-dirs (champ-insert (prop-network-cell-dirs net) h id 'descending)]
      [next-cell-id (+ 1 (prop-network-next-cell-id net))]))
  (values
   (if contradicts?
       (struct-copy prop-network net*
         [contradiction-fns
          (champ-insert (prop-network-contradiction-fns net*)
                        h id contradicts?)])
       net*)
   id))
```

**Key insight**: The existing `net-cell-write` already works for descending cells — it calls `merge-fn(old, new)` and checks `merged = old`. If `merge-fn` is `meet`, then writes that try to raise the value above the current level are no-ops (meet of old and higher = old). Only writes that lower the value produce change. No modifications to `net-cell-write` are needed.

### 1.4.2 `net-cell-direction` — Query Cell Direction

```racket
;; Query a cell's direction. Returns 'ascending (default) or 'descending.
(define (net-cell-direction net cid)
  (define dir (champ-lookup (prop-network-cell-dirs net)
                             (cell-id-hash cid) cid))
  (if (eq? dir 'none) 'ascending dir))
```

## 1.5 Backward Compatibility

The existing `net-new-cell` continues to work unchanged — cells without an entry in `cell-dirs` default to `'ascending`. All existing tests pass without modification. The only change to existing code paths is:

1. `make-prop-network` gains a 13th field (`cell-dirs: champ-empty`)
2. All `struct-copy prop-network` sites throughout the codebase that construct `prop-network` by positional fields need updating

### 1.5.1 `struct-copy` Impact Analysis

`struct-copy` by named fields (the pattern used throughout propagator.rkt) is **unaffected** — adding a new field does not break named copies. The concern is only if any code constructs `prop-network` directly by positional arguments (rare — `make-prop-network` is the constructor).

## 1.6 File Changes

| File | Change | Scope |
|------|--------|-------|
| `propagator.rkt` | Add `cell-dirs` field to `prop-network`, `net-new-cell-desc`, `net-cell-direction` | ~40 lines new, ~5 lines modified |

## 1.7 Tests (~15)

```
test-propagator-descending-01.rkt:
  1. net-new-cell-desc creates cell with top value
  2. net-cell-read returns top for fresh descending cell
  3. net-cell-direction returns 'descending for desc cells
  4. net-cell-direction returns 'ascending for regular cells
  5. net-cell-write with meet-fn narrows descending cell
  6. net-cell-write with meet-fn is no-op when meet = old
  7. Descending cell reaches contradiction at bot
  8. Ascending cell in same network still works
  9. Mixed ascending + descending cells coexist
 10. Propagator connecting ascending output to descending input
 11. Propagator connecting descending output to ascending input
 12. run-to-quiescence with mixed direction cells converges
 13. BSP scheduler with mixed direction cells converges
 14. Widening cell coexists with descending cell (no interference)
 15. Descending cell with non-Boolean lattice (e.g., set-intersection lattice)
```

## 1.8 Dependencies

- **Depends on**: Nothing — this is the first phase
- **Provides to Phase 2**: `net-new-cell-desc`, `net-cell-direction`, `cell-dirs` registry


---

# Phase 2: Bilattice Module (bilattice.rkt)

## 2.1 Goal

Create the `bilattice.rkt` module — the abstraction layer that pairs ascending and descending cells into bilattice variables and provides three-valued reading.

## 2.2 Theory

A bilattice L² = L × L consists of pairs `(lower, upper)` where `lower ≤ upper` in the base lattice L. The **precision ordering** ≤_p on L² is:

```
(l₁, u₁) ≤_p (l₂, u₂)  iff  l₁ ≤ l₂  and  u₂ ≤ u₁
```

That is, more precise = higher lower bound, lower upper bound (tighter approximation).

For the Boolean bilattice (L = {false, true}):
- ⊥_p = (false, true) — unknown (widest gap)
- ⊤_p = (true, false) — contradiction (impossible gap)
- (true, true) = definitely true
- (false, false) = definitely false

## 2.3 Data Structures

### 2.3.1 Lattice Descriptor

```racket
;; A lattice descriptor — provides the operations needed to construct
;; and read bilattice variables over lattice L.
;;
;; bot: L — bottom element (initial value for ascending cell)
;; top: L — top element (initial value for descending cell)
;; join: (L L → L) — least upper bound (merge for ascending cell)
;; meet: (L L → L) — greatest lower bound (merge for descending cell)
;; leq: (L L → Bool) — lattice ordering
(struct lattice-desc (bot top join meet leq) #:transparent)
```

### 2.3.2 Standard Lattice Descriptors

```racket
;; The Boolean lattice: {false, true} with false < true.
;; Used for standard logic programming (well-founded semantics over ground atoms).
(define bool-lattice
  (lattice-desc
   #f                          ;; bot = false
   #t                          ;; top = true
   (lambda (a b) (or a b))     ;; join = disjunction
   (lambda (a b) (and a b))    ;; meet = conjunction
   (lambda (a b)               ;; leq: false ≤ true
     (or (not a) b))))

;; The set-lattice over a universe U: ℘(U) with ⊆ ordering.
;; bot = ∅, top = U, join = ∪, meet = ∩
;; Requires providing the universe set for ⊤.
(define (make-set-lattice universe)
  (lattice-desc
   '()                                          ;; bot = empty
   universe                                     ;; top = full universe
   (lambda (a b) (set-union a b))               ;; join = union
   (lambda (a b) (set-intersect a b))           ;; meet = intersection
   (lambda (a b) (subset? a b))))               ;; leq = subset
```

### 2.3.3 Bilattice Variable

```racket
;; A bilattice variable: paired ascending + descending cells.
;; lower-cid: cell-id — ascending cell (starts at bot, rises via join)
;; upper-cid: cell-id — descending cell (starts at top, falls via meet)
;; lattice: lattice-desc — provides the base lattice operations
(struct bilattice-var (lower-cid upper-cid lattice) #:transparent)
```

## 2.4 Core Operations

### 2.4.1 `bilattice-new-var` — Create a Bilattice Variable

```racket
;; Create a new bilattice variable in the network.
;; #:consistency-check? — when #t, adds a consistency propagator
;;   (lower ≤ upper). Default #f for Boolean lattice (invariant
;;   maintained by construction); #t for non-Boolean or during testing.
;; Returns: (values new-network bilattice-var)
(define (bilattice-new-var net lat #:consistency-check? [check? #f])
  ;; Create ascending (lower) cell — starts at bot
  (define-values (net1 lower-cid)
    (net-new-cell net
                  (lattice-desc-bot lat)
                  (lattice-desc-join lat)))
  ;; Create descending (upper) cell — starts at top
  (define-values (net2 upper-cid)
    (net-new-cell-desc net1
                       (lattice-desc-top lat)
                       (lattice-desc-meet lat)))
  (define bvar (bilattice-var lower-cid upper-cid lat))
  (define net3 (if check?
                   (bilattice-add-consistency-propagator net2 bvar)
                   net2))
  (values net3 bvar))
```

### 2.4.2 `bilattice-read` — General Three-Valued Reading

```racket
;; Read a bilattice variable's approximation state.
;; Returns: (list 'exact value) | (list 'approx lower upper) | 'contradiction
;;
;; For the Boolean bilattice:
;;   (true, true)   → (list 'exact #t)      — definitely true
;;   (false, false)  → (list 'exact #f)      — definitely false
;;   (false, true)   → (list 'approx #f #t)  — unknown (gap remains)
;;   (true, false)   → 'contradiction        — impossible
(define (bilattice-read net bvar)
  (define lo (net-cell-read net (bilattice-var-lower-cid bvar)))
  (define hi (net-cell-read net (bilattice-var-upper-cid bvar)))
  (define leq (lattice-desc-leq (bilattice-var-lattice bvar)))
  (cond
    [(equal? lo hi) (list 'exact lo)]
    [(leq lo hi) (list 'approx lo hi)]
    [else 'contradiction]))
```

### 2.4.3 `bilattice-read-bool` — Boolean Specialization

```racket
;; Convenience for the Boolean bilattice (the common case for logic programming).
;; Returns: 'true | 'false | 'unknown | 'contradiction
(define (bilattice-read-bool net bvar)
  (define result (bilattice-read net bvar))
  (cond
    [(eq? result 'contradiction) 'contradiction]
    [(eq? (car result) 'exact) (if (cadr result) 'true 'false)]
    [else 'unknown]))
```

### 2.4.4 `bilattice-lower-write` / `bilattice-upper-write` — Direct Writes

```racket
;; Write to the lower (ascending) cell of a bilattice variable.
;; The cell's merge-fn (join) handles monotonicity.
(define (bilattice-lower-write net bvar val)
  (net-cell-write net (bilattice-var-lower-cid bvar) val))

;; Write to the upper (descending) cell of a bilattice variable.
;; The cell's merge-fn (meet) handles monotonicity.
(define (bilattice-upper-write net bvar val)
  (net-cell-write net (bilattice-var-upper-cid bvar) val))
```

### 2.4.5 `bilattice-add-consistency-propagator` — Cross-Cell Consistency (Optional)

```racket
;; Add a consistency propagator that enforces lower ≤ upper.
;; If lower > upper, sets contradiction.
;;
;; For the Boolean lattice, the negation-flip patterns in Phase 3
;; maintain lower ≤ upper by construction — this propagator can never
;; fire. It is therefore optional for Boolean WF semantics:
;;
;;   #:consistency-check? #f  → omit (default for Boolean, saves a propagator)
;;   #:consistency-check? #t  → include (mandatory for non-Boolean lattices,
;;                              recommended during development/testing)
;;
;; bilattice-new-var accepts the flag and conditionally wires this propagator.
(define (bilattice-add-consistency-propagator net bvar)
  (define lower-cid (bilattice-var-lower-cid bvar))
  (define upper-cid (bilattice-var-upper-cid bvar))
  (define leq (lattice-desc-leq (bilattice-var-lattice bvar)))
  (net-add-propagator net
    (list lower-cid upper-cid)  ;; inputs
    '()                          ;; no outputs (side-effect: contradiction)
    (lambda (net)
      (define lo (net-cell-read net lower-cid))
      (define hi (net-cell-read net upper-cid))
      (if (leq lo hi)
          net  ;; consistent — no action
          (struct-copy prop-network net
            [contradiction lower-cid])))))
```

## 2.5 File Changes

| File | Change | Scope |
|------|--------|-------|
| `bilattice.rkt` | NEW — all of the above | ~120 lines |

## 2.6 Tests (~20)

```
test-bilattice-01.rkt:
  ;; Lattice descriptors
  1. bool-lattice has correct bot/top/join/meet/leq
  2. make-set-lattice produces correct lattice for small universe
  ;; Bilattice variable construction
  3. bilattice-new-var creates two cells (lower ascending, upper descending)
  4. Fresh bilattice-var reads as 'unknown (Boolean)
  5. Fresh bilattice-var with set-lattice reads as (list 'approx '() universe)
  ;; Lower/upper writes
  6. bilattice-lower-write raises lower bound
  7. bilattice-upper-write lowers upper bound
  8. bilattice-lower-write is monotone (can't decrease)
  9. bilattice-upper-write is monotone (can't increase)
  ;; Three-valued reading (Boolean)
 10. (true, true) reads as 'true
 11. (false, false) reads as 'false
 12. (false, true) reads as 'unknown
 13. (true, false) reads as 'contradiction
  ;; Consistency propagator
 14. Consistency propagator is no-op when lower ≤ upper
 15. Consistency propagator flags contradiction when lower > upper
  ;; Multiple bilattice vars
 16. Multiple bilattice-vars coexist in same network
 17. Propagator wired between bilattice-vars transfers information
  ;; Integration with existing cells
 18. Bilattice-vars coexist with regular ascending cells
 19. run-to-quiescence converges with bilattice-vars
 20. BSP scheduler converges with bilattice-vars
```

## 2.7 Dependencies

- **Depends on**: Phase 1 (`net-new-cell-desc`)
- **Provides to Phase 3**: `bilattice-var`, `bilattice-new-var`, `bilattice-read`, `bilattice-lower-write`, `bilattice-upper-write`, `bool-lattice`


---

# Phase 3: Well-Founded Propagator Patterns (wf-propagators.rkt)

## 3.1 Goal

Implement the propagator patterns that compute the well-founded semantics — the "wiring diagrams" that translate logic program clauses into bilattice cell updates.

## 3.2 Theory

The well-founded semantics of a normal logic program P is the ≤_p-least fixpoint of the stable operator on L². For each ground atom p:

- **Lower bound** (ascending): `lower-p = ∨ { body-lower(c) | c is a clause for p }` where `body-lower(c)` = ∧ of lower bounds of positive literals ∧ ¬upper bounds of negative literals
- **Upper bound** (descending): `upper-p = ∨ { body-upper(c) | c is a clause for p }` where `body-upper(c)` = ∧ of upper bounds of positive literals ∧ ¬lower bounds of negative literals

The negation flips cross the bilattice: `¬upper-q` contributes to `lower-not-q`, `¬lower-q` contributes to `upper-not-q`. This is the key insight that makes negation monotone in the precision ordering.

## 3.3 Propagator Pattern Catalog

### 3.3.1 Positive Clause Propagator

For a clause `p :- q₁, q₂, ..., qₙ` (all positive):

```racket
;; Wire a positive clause: p :- q₁, ..., qₙ
;; p-bvar: bilattice-var for the head atom p
;; q-bvars: (listof bilattice-var) for body atoms q₁ ... qₙ
;;
;; Lower bound propagator:
;;   lower-p := lower-p ∨ (lower-q₁ ∧ lower-q₂ ∧ ... ∧ lower-qₙ)
;;   "If all body atoms are certainly true, the head is certainly true"
;;
;; Upper bound propagator:
;;   This clause's contribution to upper-p: upper-q₁ ∧ ... ∧ upper-qₙ
;;   "This clause CAN prove p only if all body atoms are possibly true"
;;
;; Returns: new-network
(define (wf-wire-positive-clause net p-bvar q-bvars)
  ;; --- Lower bound propagator ---
  (define lower-inputs (map bilattice-var-lower-cid q-bvars))
  (define lower-p-cid (bilattice-var-lower-cid p-bvar))
  (define-values (net1 _pid1)
    (net-add-propagator net
      lower-inputs
      (list lower-p-cid)
      (lambda (net)
        ;; body-lower = AND of all lower bounds
        (define body-lower
          (for/and ([bv (in-list q-bvars)])
            (net-cell-read net (bilattice-var-lower-cid bv))))
        ;; lower-p := lower-p ∨ body-lower
        (if body-lower
            (net-cell-write net lower-p-cid #t)
            net))))
  ;; --- Upper bound propagator ---
  (define upper-inputs (map bilattice-var-upper-cid q-bvars))
  (define upper-p-cid (bilattice-var-upper-cid p-bvar))
  (define-values (net2 _pid2)
    (net-add-propagator net1
      upper-inputs
      (list upper-p-cid)
      (lambda (net)
        ;; This clause's upper contribution = AND of body upper bounds
        ;; We need to track ALL clauses for p to compute upper-p correctly.
        ;; See §3.4 for the aggregate upper bound pattern.
        ;; For now, this propagator only contributes its clause's feasibility.
        net)))  ;; upper bound handled by aggregate pattern (§3.4)
  net2)
```

### 3.3.2 Negative Literal Propagator

For a negative literal `not q` in a clause body:

```racket
;; Wire a negative literal: not q appears in a clause body.
;; Returns the bilattice-var for "not q" — a derived bilattice-var
;; whose lower/upper are the negation-flipped values of q.
;;
;; neg-lower = ¬upper-q : "not-q is certainly true iff q is certainly false"
;; neg-upper = ¬lower-q : "not-q is certainly false iff q is certainly true"
;;
;; These are monotone in precision ordering:
;;   - upper-q descends → ¬upper-q ascends (lower for not-q rises) ✓
;;   - lower-q ascends → ¬lower-q descends (upper for not-q falls) ✓
;;
;; q-bvar: bilattice-var for atom q
;; Returns: (values new-network neg-bvar) where neg-bvar represents "not q"
(define (wf-wire-negation net q-bvar)
  (define lat (bilattice-var-lattice q-bvar))
  ;; Create bilattice-var for "not q"
  (define-values (net1 neg-bvar) (bilattice-new-var net lat))
  (define neg-lower-cid (bilattice-var-lower-cid neg-bvar))
  (define neg-upper-cid (bilattice-var-upper-cid neg-bvar))
  (define q-lower-cid (bilattice-var-lower-cid q-bvar))
  (define q-upper-cid (bilattice-var-upper-cid q-bvar))
  ;; Propagator: neg-lower := ¬upper-q
  (define-values (net2 _pid1)
    (net-add-propagator net1
      (list q-upper-cid)
      (list neg-lower-cid)
      (lambda (net)
        (define upper-q (net-cell-read net q-upper-cid))
        ;; ¬true = false, ¬false = true (Boolean negation)
        (net-cell-write net neg-lower-cid (not upper-q)))))
  ;; Propagator: neg-upper := ¬lower-q
  (define-values (net3 _pid2)
    (net-add-propagator net2
      (list q-lower-cid)
      (list neg-upper-cid)
      (lambda (net)
        (define lower-q (net-cell-read net q-lower-cid))
        (net-cell-write net neg-upper-cid (not lower-q)))))
  (values net3 neg-bvar))
```

### 3.3.3 Aggregate Upper Bound Propagator

The upper bound for atom p requires considering ALL clauses for p simultaneously:

```racket
;; Wire the aggregate upper bound for atom p.
;; The upper bound of p is: ∨ over all clauses c of (body-upper(c))
;; where body-upper(c) = ∧ of upper bounds of all body literals in c.
;;
;; "p is possibly true iff at least one clause could possibly prove it"
;;
;; p-bvar: bilattice-var for atom p
;; clause-body-upper-fns: (listof (prop-network → Bool))
;;   Each function reads the network and returns whether that clause's
;;   body is "possibly true" (all upper bounds are true).
;;
;; Returns: new-network
(define (wf-wire-aggregate-upper net p-bvar all-body-upper-cids clause-body-upper-fns)
  (define upper-p-cid (bilattice-var-upper-cid p-bvar))
  (define-values (net1 _pid)
    (net-add-propagator net
      all-body-upper-cids   ;; all cells that any clause reads for upper bounds
      (list upper-p-cid)
      (lambda (net)
        ;; upper-p = OR of clause feasibilities
        (define any-feasible?
          (for/or ([clause-fn (in-list clause-body-upper-fns)])
            (clause-fn net)))
        (if any-feasible?
            net  ;; upper stays at #t (at least one clause could work)
            ;; No clause can possibly prove p → upper-p := false
            (net-cell-write net upper-p-cid #f)))))
  net1)
```

### 3.3.4 Fact Propagator

For a ground fact `p.` (clause with empty body):

```racket
;; Wire a ground fact: p. (no body)
;; lower-p := true (immediately), upper-p stays true.
;; The fact is unconditionally true.
(define (wf-wire-fact net p-bvar)
  (net-cell-write net (bilattice-var-lower-cid p-bvar) #t))
```

## 3.4 Clause Compilation: `wf-compile-clause`

```racket
;; Compile a single clause into bilattice propagators.
;;
;; head-bvar: bilattice-var for the clause's head atom
;; body-specs: (listof (cons 'pos|'neg bilattice-var))
;;   Each element is either ('pos . bvar) for a positive literal
;;   or ('neg . bvar) for a negated literal
;;
;; Returns: (values new-network body-upper-fn body-bvars)
;;   body-upper-fn: (prop-network → Bool) — checks if this clause's body
;;   is "possibly true" (for the aggregate upper bound)
;;   body-bvars: (listof bilattice-var) — effective body bvars (after
;;   negation wiring), used by wf-compile-program to compute precise
;;   upper-bound dependency sets per head atom
(define (wf-compile-clause net head-bvar body-specs)
  ;; Phase 1: wire negation for negative literals → get effective bvars
  (define-values (net1 effective-bvars)
    (for/fold ([net net] [bvars '()])
              ([spec (in-list body-specs)])
      (case (car spec)
        [(pos) (values net (cons (cdr spec) bvars))]
        [(neg)
         (define-values (net2 neg-bvar) (wf-wire-negation net (cdr spec)))
         (values net2 (cons neg-bvar bvars))])))
  (define eff-bvars (reverse effective-bvars))
  ;; Phase 2: wire lower bound propagator
  ;; lower-head := lower-head ∨ (∧ lower-bᵢ for all effective body literals)
  (define lower-inputs (map bilattice-var-lower-cid eff-bvars))
  (define lower-head-cid (bilattice-var-lower-cid head-bvar))
  (define-values (net2 _pid)
    (net-add-propagator net1
      lower-inputs
      (list lower-head-cid)
      (lambda (net)
        (define body-lower
          (for/and ([bv (in-list eff-bvars)])
            (net-cell-read net (bilattice-var-lower-cid bv))))
        (if body-lower
            (net-cell-write net lower-head-cid #t)
            net))))
  ;; Phase 3: construct body-upper-fn for aggregate upper bound
  (define upper-cids (map bilattice-var-upper-cid eff-bvars))
  (define body-upper-fn
    (lambda (net)
      (for/and ([bv (in-list eff-bvars)])
        (net-cell-read net (bilattice-var-upper-cid bv)))))
  (values net2 body-upper-fn eff-bvars))
```

## 3.5 Program Compilation: `wf-compile-program`

```racket
;; Compile a complete logic program into a bilattice propagator network.
;;
;; program: association list ((head-name . body-specs) ...)
;;   where body-specs as in wf-compile-clause
;; Returns: (values new-network atom-bvar-map)
;;   atom-bvar-map: hasheq : symbol → bilattice-var
(define (wf-compile-program net program)
  ;; Phase 1: create bilattice-vars for all atoms
  (define all-atoms
    (remove-duplicates
     (append (map car program)
             (apply append
                    (for/list ([clause (in-list program)])
                      (map cdr (cdr clause)))))))
  (define-values (net1 atom-map)
    (for/fold ([net net] [m (hasheq)])
              ([atom (in-list all-atoms)])
      (if (hash-has-key? m atom)
          (values net m)
          (let-values ([(net2 bvar) (bilattice-new-var net bool-lattice)])
            (values net2 (hash-set m atom bvar))))))
  ;; Phase 2: compile each clause, collecting upper-bound fns and body-bvars per head
  (define-values (net2 head-clause-info)
    (for/fold ([net net1] [hci (hasheq)])
              ([clause (in-list program)])
      (define head-name (car clause))
      (define body-specs
        (for/list ([spec (in-list (cdr clause))])
          (cons (car spec) (hash-ref atom-map (cdr spec)))))
      (define head-bvar (hash-ref atom-map head-name))
      (define-values (net3 body-upper-fn body-bvars)
        (wf-compile-clause net head-bvar body-specs))
      (values net3
              (hash-update hci head-name
                           (lambda (entries)
                             (cons (list body-upper-fn body-bvars) entries))
                           '()))))
  ;; Phase 3: wire aggregate upper bounds
  (define net3
    (for/fold ([net net2])
              ([(head-name entries) (in-hash head-clause-info)])
      (define head-bvar (hash-ref atom-map head-name))
      (define fns (map car entries))
      ;; Collect only the upper-cids that clauses for this head actually reference.
      ;; Each entry includes the body-bvars returned from wf-compile-clause. We
      ;; extract their upper-cids, avoiding O(n²) dependencies where every head
      ;; would watch every atom in the program.
      (define clause-upper-cids
        (remove-duplicates
         (apply append
                (for/list ([entry (in-list entries)])
                  (map bilattice-var-upper-cid (cadr entry))))))
      (wf-wire-aggregate-upper net head-bvar clause-upper-cids fns)))
  (values net3 atom-map))
```

## 3.6 Worked Example: `p :- not q. q :- not p.`

This is the canonical odd-cycle example. The well-founded semantics assigns both p and q the value `'unknown`.

```
Program:
  clause 1: p :- not q
  clause 2: q :- not p

Step 1: Create bilattice-vars
  p: lower-p = #f, upper-p = #t    → (false, true) = unknown
  q: lower-q = #f, upper-q = #t    → (false, true) = unknown

Step 2: Wire propagators

  Clause 1 (p :- not q):
    neg-q: lower-neg-q := ¬upper-q, upper-neg-q := ¬lower-q
    lower-p := lower-p ∨ lower-neg-q
    aggregate: upper-p = upper-neg-q

  Clause 2 (q :- not p):
    neg-p: lower-neg-p := ¬upper-p, upper-neg-p := ¬lower-p
    lower-q := lower-q ∨ lower-neg-p
    aggregate: upper-q = upper-neg-p

Step 3: run-to-quiescence

  Initial:
    lower-p = #f, upper-p = #t
    lower-q = #f, upper-q = #t

  Round 1:
    neg-q:  lower-neg-q = ¬upper-q = ¬#t = #f
            upper-neg-q = ¬lower-q = ¬#f = #t
    neg-p:  lower-neg-p = ¬upper-p = ¬#t = #f
            upper-neg-p = ¬lower-p = ¬#f = #t
    lower-p = #f ∨ #f = #f (no change)
    lower-q = #f ∨ #f = #f (no change)
    upper-p: clause feasible? upper-neg-q = #t → yes → stays #t
    upper-q: clause feasible? upper-neg-p = #t → yes → stays #t

  No cells changed → quiescent.

Step 4: Read results
  p: (false, true) → 'unknown  ✓
  q: (false, true) → 'unknown  ✓
```

## 3.7 Worked Example: `a :- not b. b :- not c. c.`

Stratifiable program (no odd cycles). Well-founded semantics agrees with stratified semantics.

```
Step 1: Create bilattice-vars for a, b, c

Step 2: Wire
  Fact c: lower-c := #t (immediately)
  Clause b :- not c: neg-c propagators + lower-b clause
  Clause a :- not b: neg-b propagators + lower-a clause

Step 3: run-to-quiescence

  Initial: all (false, true)

  Fact fires: lower-c = #t

  neg-c:  lower-neg-c = ¬upper-c = ¬#t = #f
          upper-neg-c = ¬lower-c = ¬#t = #f
  lower-b = #f ∨ #f = #f
  upper-b: clause for b feasible? upper-neg-c = #f → no → upper-b := #f

  neg-b:  lower-neg-b = ¬upper-b = ¬#f = #t
          upper-neg-b = ¬lower-b = ¬#f = #t
  lower-a = #f ∨ #t = #t
  upper-a: clause for a feasible? upper-neg-b = #t → yes → stays #t

  Quiescent.

Step 4:
  c: (true, true) → 'true       ✓
  b: (false, false) → 'false     ✓
  a: (true, true) → 'true       ✓
```

## 3.8 File Changes

| File | Change | Scope |
|------|--------|-------|
| `wf-propagators.rkt` | NEW — propagator patterns, clause/program compilation | ~250 lines |

## 3.9 Tests (~25)

```
test-wf-propagators-01.rkt:
  ;; Positive clause propagator
  1. Single positive clause: p :- q. With q true → p true
  2. Single positive clause: p :- q. With q unknown → p unknown
  3. Multi-body: p :- q, r. With both true → p true
  4. Multi-body: p :- q, r. With one unknown → p unknown
  ;; Negative literal propagator
  5. not q with q true → not-q false
  6. not q with q false → not-q true
  7. not q with q unknown → not-q unknown
  ;; Fact propagator
  8. Ground fact sets lower to true immediately
  ;; Aggregate upper bound
  9. Single clause for p: body infeasible → upper-p false
 10. Two clauses for p: one feasible → upper-p stays true
 11. Two clauses for p: both infeasible → upper-p false
  ;; Clause compilation
 12. wf-compile-clause with positive body
 13. wf-compile-clause with negative body
 14. wf-compile-clause with mixed body
  ;; Program compilation — classic examples
 15. p :- not q. q :- not p. → both unknown
 16. a :- not b. b :- not c. c. → a=true, b=false, c=true
 17. win(X) :- move(X,Y), not win(Y). (ground instances) → correct WF model
 18. Even/odd cycle: even(0). even(s(N)) :- odd(N). odd(s(N)) :- even(N). → all true
  ;; Edge cases
 19. No clauses for atom → false (lower stays ⊥, upper driven to ⊥ by aggregate)
 20. Self-referencing: p :- p. → p = unknown (not false, not contradictory)
 21. Self-referencing with negation: p :- not p. → p = unknown
 22. Empty program → empty atom map
 23. Large cycle: chain of 10 atoms with negation → correct WF model
 24. Multiple clauses, some with negation, some without
 25. Integration: bilattice + wf-propagators + run-to-quiescence end-to-end
```

## 3.10 Dependencies

- **Depends on**: Phase 2 (`bilattice-new-var`, `bilattice-read`, `bilattice-lower-write`, `bilattice-upper-write`, `bool-lattice`)
- **Provides to Phase 4**: `wf-compile-clause`, `wf-compile-program`, `wf-wire-fact`, `wf-wire-negation`


---

# Phase 4: Well-Founded Engine Orchestration (wf-engine.rkt)

Phase 4 is split into two sub-phases to resolve the circular dependency between the engine and three-valued tabling:

- **Phase 4a**: Core engine with ground-only queries (propositional WF semantics)
- **Phase 4b**: Integration with tabling for non-ground queries (after Phase 5)

## 4.1 Goal

Create the `wf-engine.rkt` module — the solver-level entry point that orchestrates the existing DFS solver with bilattice cell pairs to compute well-founded semantics. This is the WFLE parallel to `stratified-eval.rkt`.

## 4.2 Architecture: Hybrid DFS + Bilattice

**Key design decision**: The WFLE does NOT replace the DFS solver's proof search. It wraps the existing solver, using bilattice cells to track the three-valued status of predicates while the DFS solver does the actual unification, backtracking, and variant dispatch. The WFLE's value-add is *negation cycle handling*, not an alternative proof search strategy.

This hybrid approach preserves full Prolog-style queries (unification variables, function symbols, open Herbrand base) while gaining well-founded semantics for negation.

**Bilattice granularity**: Phase 4a operates at **predicate granularity** — one bilattice-var per predicate name (e.g., one for `win`, one for `move`). This is conservative: if any ground instance of a predicate is unknown, all instances are treated as unknown for NAF purposes. For example, with `win(X) :- move(X,Y), not win(Y)` and `move(a,b). move(b,c).`, the bilattice tracks `win` as a single Boolean, not `win(a)` and `win(b)` separately. The DFS solver still returns specific bindings (`{X: a}`, `{X: c}`), but the NAF oracle consults the predicate-level bilattice to decide whether `not win(Y)` can succeed/fail/defer.

Phase 4b (after Phase 5: tabling) refines to **per-tabled-variant granularity**. Each tabled variant gets its own `certainty` annotation in the `wf-table-entry`. This enables variant-specific NAF: `not win(b)` can succeed (b is definitely not a winner) while `not win(a)` defers (a's status is unknown). This is the target granularity for production use.

```
  User query: solve (ancestor ?x bob)
       │
       ▼
  ┌──────────────────────────────────────┐
  │ Solver Dispatch (solver.rkt)          │
  │ config 'semantics key                 │
  └──────┬──────────────┬────────────────┘
         │              │
    'stratified      'well-founded
         │              │
         ▼              ▼
  stratified-       wf-solve-goal
  solve-goal        (wf-engine.rkt)
         │              │
         │         ┌────┴──────────────────────────────────┐
         │         │ Iterative orchestration:               │
         │         │                                        │
         │         │ 1. Create bilattice-var per predicate   │
         │         │ 2. LOOP:                               │
         │         │    a. For each predicate p:             │
         │         │       - Run DFS solver (solve-goal)     │
         │         │       - Results found → lower-p := #t   │
         │         │    b. For each predicate p with NAF:    │
         │         │       - Check negated predicates' status │
         │         │       - No proofs possible → upper-q := #f │
         │         │    c. Wire cross-cell negation:          │
         │         │       - lower-not-q = ¬upper-q          │
         │         │       - upper-not-q = ¬lower-q          │
         │         │    d. run-to-quiescence on bilattice    │
         │         │    e. If bilattice changed → repeat     │
         │         │       If stable → done                  │
         │         │ 3. Read three-valued results             │
         │         └───────────────────────────────────────┘
         │              │
         └────┬─────────┘
              ▼
  Three-valued result:
    'true / 'false / 'unknown
```

**Why hybrid**: The DFS solver already handles unification, backtracking, variant dispatch, and tabling. Reimplementing this as static compilation to a propositional bilattice network would either (a) require ground-instantiation of the Herbrand base (breaks open-ended programs) or (b) require lifting bilattice to first-order (research territory). The hybrid approach reuses all existing solver machinery and adds only the negation-cycle-handling layer.

## 4.3 Solver Config: `semantics` Key

Rather than a separate `current-solver-mode` parameter, the solver backend is selected via the existing `solver-config` mechanism. This is consistent with how other solver behaviors (execution, threshold, strategy, tabling) are already configured.

```racket
;; Add to valid-solver-keys in solver.rkt:
;;   'semantics — 'stratified (default) | 'well-founded
;;
;; Add to solver-defaults:
;;   'semantics 'stratified
;;
;; Add accessor:
(define (solver-config-semantics cfg)
  (solver-config-get cfg 'semantics 'stratified))
```

This enables user-facing selection via the existing `solver` form:

```prologos
solver wf-solver
  semantics well-founded
  tabling by-default
```

No new syntax required — `semantics` is just another solver config key.

## 4.4 Core Operations

### 4.4.1 `wf-solve-goal` — Top-Level Entry Point

```racket
;; Solve a relational goal using the well-founded engine.
;; Parallel to stratified-solve-goal — same external interface.
;;
;; The WFLE wraps the existing DFS solver: it uses solve-goal for proof
;; search, and bilattice cells to track three-valued predicate status.
;; The iteration continues until the bilattice reaches a fixpoint.
;;
;; config: solver-config
;; store: relation store (hasheq of name → relation-info)
;; goal-name: symbol
;; goal-args: (listof any)
;; query-vars: (listof symbol)
;;
;; Returns: (listof wf-answer)
(define (wf-solve-goal config store goal-name goal-args query-vars)
  ;; Step 1: Identify all predicates reachable from the goal
  (define all-preds (transitive-pred-closure store goal-name))
  ;; Step 2: Identify which predicates participate in negation
  (define neg-preds (preds-with-negation store all-preds))
  ;; Step 3: Create bilattice-vars for negation-participating predicates
  (define-values (net pred-bvar-map)
    (for/fold ([net (make-prop-network)] [m (hasheq)])
              ([pred (in-list neg-preds)])
      (let-values ([(net2 bvar) (bilattice-new-var net bool-lattice)])
        (values net2 (hash-set m pred bvar)))))
  ;; Step 4: Iterative fixpoint
  (define-values (final-net final-answers)
    (wf-iterate config store net pred-bvar-map
                goal-name goal-args query-vars))
  ;; Step 5: Annotate answers with certainty
  (annotate-answers final-net pred-bvar-map final-answers goal-name))
```

### 4.4.2 `wf-iterate` — Iterative Fixpoint Loop

```racket
;; Iterate DFS solving + bilattice update until stable.
;;
;; Each iteration:
;; 1. Run solve-goal with current NAF oracle (reads bilattice upper bounds)
;; 2. Update bilattice: proven atoms → lower := #t
;; 3. Update bilattice: atoms with no possible proof → upper := #f
;; 4. Propagate negation cross-links
;; 5. Check for bilattice change → repeat if changed
;;
;; The NAF oracle is the key bridge: when the DFS solver evaluates
;; `not p`, instead of the stratified check ("is p in a lower stratum?"),
;; it consults the bilattice: "is upper-p = #f?" (definitely false → NAF succeeds)
;; or "is lower-p = #t?" (definitely true → NAF fails).
;; If neither (unknown), the NAF result is deferred.
;; Iteration limit: for Boolean lattice with n negation-participating
;; predicates, worst-case convergence is O(n) iterations (each iteration
;; must refine at least one cell, and each cell changes at most twice:
;; ⊥→⊤ for lower, ⊤→⊥ for upper). We set max-iterations = 2n with
;; a floor of 10 to avoid hardcoded magic numbers.
;;
;; Fuel interaction: two separate limits apply during iteration:
;; 1. Propagator fuel (prop-network-fuel): limits propagation steps
;;    within a single run-to-quiescence call. If exhausted mid-iteration,
;;    run-to-quiescence returns the network in its current state — values
;;    are sound approximations (lower ≤ true fixpoint, upper ≥ true fixpoint)
;;    but may be less precise than the true well-founded model.
;; 2. Iteration limit (max-iterations): limits outer fixpoint iterations.
;;    An iteration-capped result is valid but conservative — more 'unknown
;;    than the true model, never incorrect.
;;
;; Critical: never terminate between Phase A (DFS solver) and Phase C
;; (bilattice propagation). If fuel exhausts during Phase C, complete
;; that propagation round before returning, so cross-cell negation links
;; are consistent.
(define (wf-iterate config store net pred-bvar-map
                     goal-name goal-args query-vars)
  (define max-iterations (max 10 (* 2 (hash-count pred-bvar-map))))
  (let loop ([net net] [iteration 0])
    (when (>= iteration max-iterations)
      (values net '()))  ;; iteration limit — return partial (sound) results
    ;; Phase A: Run DFS solver with WF-aware NAF oracle
    (define naf-oracle (make-wf-naf-oracle net pred-bvar-map))
    (define answers
      (parameterize ([current-naf-oracle naf-oracle])
        (solve-goal config store goal-name goal-args query-vars)))
    ;; Phase B: Update bilattice from solver results
    (define net2 (update-bilattice-from-results net pred-bvar-map store answers))
    ;; Phase C: Run bilattice propagators to quiescence
    ;; (always completes this round, even if fuel is low)
    (define net3 (run-to-quiescence net2))
    ;; Phase D: Check for fixpoint (no bilattice change)
    (if (bilattice-stable? net net3 pred-bvar-map)
        (values net3 answers)
        (loop net3 (add1 iteration)))))
```

### 4.4.3 `make-wf-naf-oracle` — Three-Valued NAF

```racket
;; Create a NAF oracle that consults the bilattice instead of
;; the stratification check.
;;
;; Returns a function: (symbol → 'succeed | 'fail | 'defer)
;;   'succeed — the negated predicate is definitely false (upper = #f)
;;   'fail — the negated predicate is definitely true (lower = #t)
;;   'defer — the negated predicate is unknown (bilattice gap)
;;
;; The DFS solver calls this when evaluating `not p`:
;;   'succeed → treat `not p` as true (NAF holds)
;;   'fail → treat `not p` as false (backtrack)
;;   'defer → treat `not p` as unknown (clause-level skip — see below)
;;
;; 'defer semantics (clause-level skip):
;;   When the oracle returns 'defer for `not p`, the DFS solver treats it
;;   identically to 'fail — this clause does not contribute to the answer
;;   set for this iteration. Other clauses for the same head still run.
;;   This is sound because:
;;   - Lower bounds are conservative: only proven atoms count, so skipping
;;     a clause cannot produce false positives
;;   - Upper bounds are handled independently by the bilattice aggregate,
;;     which checks clause feasibility via upper cells
;;   - The iterative loop retries all clauses on the next iteration, when
;;     the bilattice may have refined the deferred predicate's status
;;
;;   Example: a :- b, not c. a :- d. b. d. c :- not c.
;;   Iteration 1: c is unknown → not c deferred → clause 1 skipped
;;                clause 2 (a :- d) succeeds → lower-a = #t
;;   Result: a = 'definite true (via clause 2), c = 'unknown (self-loop)
;;
;; Implementation note: the current DFS solver (relations.rkt:307-317)
;; hardcodes NAF as a direct solve-single-goal call. Phase 4a must
;; introduce a `current-naf-oracle` parameter to intercept this.
(define (make-wf-naf-oracle net pred-bvar-map)
  (lambda (pred-name)
    (define bvar (hash-ref pred-bvar-map pred-name #f))
    (cond
      [(not bvar) 'succeed]  ;; no bilattice entry → closed-world: not provable
      [else
       (define result (bilattice-read-bool net bvar))
       (case result
         [(false) 'succeed]    ;; definitely false → NAF succeeds
         [(true) 'fail]        ;; definitely true → NAF fails
         [(unknown) 'defer]    ;; unknown → defer
         [(contradiction) 'fail])])))
```

### 4.4.4 Answer Type

```racket
;; A well-founded answer: variable bindings with certainty.
;; bindings: hasheq : symbol → value (same as stratified solver)
;; certainty: 'definite | 'unknown
;;   'definite — the well-founded semantics determines this answer
;;   'unknown — the answer is possible but not certain (bilattice gap)
(struct wf-answer (bindings certainty) #:transparent)
```

### 4.4.5 `wf-explain-goal` — Explanation for Three-Valued Results

```racket
;; Explain a well-founded result, including undeterminacy.
;;
;; For atoms with certainty 'definite: returns the proof tree (as in
;; the stratified explain path).
;;
;; For atoms with certainty 'unknown: returns a wf-explanation
;; describing the negation cycle that prevents determination.
;;
;; config: solver-config
;; store, goal-name, goal-args, query-vars: as in wf-solve-goal
;; prov-level: provenance level ('none | 'shallow | 'deep)
;;
;; Returns: (listof wf-explained-answer)
(define (wf-explain-goal config store goal-name goal-args query-vars prov-level)
  (define-values (final-net final-answers)
    (wf-solve-goal config store goal-name goal-args query-vars))
  (for/list ([answer (in-list final-answers)])
    (define certainty (wf-answer-certainty answer))
    (case certainty
      [(definite)
       ;; Delegate to existing explain infrastructure
       (wf-explained-answer
        (wf-answer-bindings answer) 'definite
        (explain-goal config store goal-name goal-args query-vars prov-level))]
      [(unknown)
       ;; Build undeterminacy explanation: identify the cycle
       (define cycle (find-negation-cycle store goal-name))
       (wf-explained-answer
        (wf-answer-bindings answer) 'unknown
        (wf-undeterminacy-explanation goal-name cycle))])))

;; Explanation structs
(struct wf-explained-answer (bindings certainty explanation) #:transparent)
(struct wf-undeterminacy-explanation (atom cycle-predicates) #:transparent)

;; Find the negation cycle containing a predicate.
;; Uses the dependency graph (from stratify.rkt) to identify the SCC
;; with negative edges that creates the undeterminacy.
(define (find-negation-cycle store pred-name)
  (define dep-infos (extract-all-dep-infos store))
  (define graph (build-dependency-graph dep-infos))
  (define sccs (tarjan-scc graph))
  ;; Find the SCC containing pred-name that has a negative internal edge
  (for/or ([scc (in-list sccs)])
    (and (member pred-name scc)
         (scc-has-negative-edge? graph scc)
         scc)))
```

### 4.4.6 Solver Dispatch Integration

```racket
;; In stratified-eval.rkt, modify stratified-solve-goal to check config:
(define (stratified-solve-goal config store goal-name goal-args query-vars)
  (define semantics (solver-config-semantics config))
  (case semantics
    [(well-founded)
     (wf-solve-goal config store goal-name goal-args query-vars)]
    [else
     ;; existing stratified path (unchanged)
     ...]))
```

### 4.4.7 Three-Valued → Two-Valued Bridge

For callers that expect two-valued answers (the common case), the WFLE provides a bridge:

```racket
;; Convert wf-answer list to standard answer list,
;; filtering by certainty or including all with annotation.
;;
;; mode: 'strict — only return 'definite answers (compatible with stratified)
;;       'all — return all answers with certainty annotation
(define (wf-answers->standard answers mode)
  (case mode
    [(strict)
     (for/list ([a (in-list answers)]
                #:when (eq? (wf-answer-certainty a) 'definite))
       (wf-answer-bindings a))]
    [(all)
     (for/list ([a (in-list answers)])
       (hash-set (wf-answer-bindings a)
                 '__certainty (wf-answer-certainty a)))]))
```

## 4.5 Phase 4a vs 4b Split

**Phase 4a** (this phase): Core engine with the iterative loop, NAF oracle, bilattice tracking, explanation, solver dispatch. Uses the DFS solver for proof search. Ground and non-ground queries work because the DFS solver handles unification natively.

**Phase 4b** (after Phase 5): Integration with three-valued tabling. When the WFLE detects that a predicate is `'unknown`, tabled entries for that predicate get certainty `'unknown`. This enables the "compositional" stable model path: ATMS choice points over `'unknown` tabled entries.

## 4.6 File Changes

| File | Change | Scope |
|------|--------|-------|
| `wf-engine.rkt` | NEW — wf-solve-goal, wf-iterate, NAF oracle, wf-explain-goal, answer types | ~250 lines |
| `solver.rkt` | Add `semantics` to valid-solver-keys + defaults + accessor | ~10 lines |
| `stratified-eval.rkt` | Add dispatch checking `solver-config-semantics` | ~10 lines |

## 4.7 Tests (~25)

```
test-wf-engine-01.rkt:
  ;; Basic solving (Phase 4a)
  1. Simple fact query: solve with ground fact → 'definite answer
  2. Simple rule query: p :- q, q is fact → p 'definite
  3. Negation query: a :- not b. b :- not c. c. → a 'definite true
  ;; Well-founded specific
  4. Odd cycle: p :- not q. q :- not p. → both 'unknown
  5. Mixed: some atoms definite, some unknown
  6. Self-reference: p :- not p. → 'unknown
  ;; NAF oracle
  7. NAF oracle returns 'succeed for definitely-false predicate
  8. NAF oracle returns 'fail for definitely-true predicate
  9. NAF oracle returns 'defer for unknown predicate
 10. NAF oracle returns 'succeed for predicate without bilattice entry
  ;; Solver dispatch via config
 11. semantics 'stratified uses stratified engine (default)
 12. semantics 'well-founded uses WF engine
 13. Same program, same answers on both engines (stratifiable case)
  ;; Explanation
 14. wf-explain-goal returns proof tree for 'definite atom
 15. wf-explain-goal returns cycle explanation for 'unknown atom
 16. wf-undeterminacy-explanation identifies correct SCC
  ;; Answer conversion
 17. wf-answers->standard 'strict filters unknowns
 18. wf-answers->standard 'all includes certainty tag
  ;; Integration with solver-config
 19. Solver config respected (timeout, threshold)
  ;; Edge cases
 20. Empty relation store → empty answers
 21. Query for undefined relation → empty answers
 22. Large program (20+ clauses) converges within max-iterations
  ;; Non-ground queries (via DFS solver)
 23. ancestor ?x bob: returns all ancestors with certainty
 24. Query with variables and negation: correct three-valued answers
 25. Iterative fixpoint converges in ≤ 3 iterations for standard examples
```

## 4.8 Dependencies

- **Depends on**: Phase 2 (`bilattice-new-var`, `bilattice-read-bool`), Phase 3 (propositional patterns for reference/testing), existing `solver.rkt`, `stratified-eval.rkt`, `relations.rkt`, `stratify.rkt`
- **Phase 4b depends on**: Phase 5 (three-valued tabling)
- **Provides to Phase 6**: Solver entry point for test programs
- **Provides to Phase 7**: Benchmark-ready solver


---

# Phase 5: Three-Valued Tabling Extension

## 5.1 Goal

Extend `tabling.rkt` to support three-valued table entries (`'definite` / `'unknown`), enabling the well-founded engine to table partial results during iterative evaluation of non-ground queries.

## 5.2 Theory

In SLG-resolution (XSB Prolog), tabled predicates accumulate answers incrementally. For the well-founded semantics:

- A table entry with certainty `'definite` is final — the well-founded semantics fully determines this answer.
- A table entry with certainty `'unknown` is provisional — the current iteration cannot determine whether this answer is true or false. It may be refined in subsequent iterations.
- Table completion (all derivations explored) triggers the transition: any remaining `'unknown` entries represent genuinely undetermined atoms.

## 5.3 Data Structure Changes

### 5.3.1 Extended Table Entry

```racket
;; Extend table-entry with a certainty field:
;; certainty: 'definite | 'unknown | 'active (in-progress)
;;
;; Current table-entry: (name cell-id answer-mode status)
;; Extended:           (name cell-id answer-mode status certainty)
(struct wf-table-entry table-entry (certainty) #:transparent)
```

### 5.3.2 Table Answer with Certainty

```racket
;; A tabled answer paired with its certainty.
;; The cell stores (listof (cons answer certainty)) instead of (listof answer).
(define (wf-all-mode-merge old new)
  ;; Merge answer lists, deduplicating by ANSWER VALUE only.
  ;; If the same answer appears with different certainties,
  ;; keep the higher certainty: 'definite subsumes 'unknown.
  ;;
  ;; This is monotonic in the certainty ordering (unknown ⊑ definite)
  ;; and keys on answer alone — (X=5, 'definite) and (X=5, 'unknown)
  ;; collapse to (X=5, 'definite), while (X=5, 'definite) and
  ;; (X=6, 'definite) are both kept as distinct answers.
  (define best (make-hash))  ;; answer → certainty (best seen)
  (for ([entry (in-list (append old new))])
    (define answer (car entry))
    (define certainty (cdr entry))
    (define current (hash-ref best answer #f))
    (when (or (not current) (eq? certainty 'definite))
      (hash-set! best answer certainty)))
  (for/list ([(answer certainty) (in-hash best)])
    (cons answer certainty)))
```

## 5.4 Core Operations

### 5.4.1 `wf-table-register` — Register a Three-Valued Table

```racket
;; Register a tabled predicate for three-valued answers.
;; Like table-register but uses wf-all-mode-merge.
(define (wf-table-register ts name)
  (define-values (net2 cid)
    (net-new-cell (table-store-network ts) '() wf-all-mode-merge))
  (define entry (wf-table-entry name cid 'all 'active 'unknown))
  (values
   (table-store net2 (hash-set (table-store-tables ts) name entry))
   cid))
```

### 5.4.2 `wf-table-add` — Add Answer with Certainty

```racket
;; Add an answer to a three-valued table.
;; answer: any Racket value (AST expression)
;; certainty: 'definite | 'unknown
(define (wf-table-add ts name answer certainty)
  (define entry (hash-ref (table-store-tables ts) name))
  (define net2 (net-cell-write (table-store-network ts)
                                (table-entry-cell-id entry)
                                (list (cons answer certainty))))
  (struct-copy table-store ts [network net2]))
```

### 5.4.3 `wf-table-answers` — Read Answers with Certainty

```racket
;; Read all answers from a three-valued table.
;; Returns: (listof (cons answer certainty))
(define (wf-table-answers ts name)
  (define entry (hash-ref (table-store-tables ts) name #f))
  (if entry
      (net-cell-read (table-store-network ts) (table-entry-cell-id entry))
      '()))
```

## 5.5 File Changes

| File | Change | Scope |
|------|--------|-------|
| `tabling.rkt` | Add `wf-table-entry`, `wf-table-register`, `wf-table-add`, `wf-table-answers`, `wf-all-mode-merge` | ~60 lines new |

## 5.6 Tests (~12)

```
test-wf-tabling-01.rkt:
  1. wf-table-register creates table with 'unknown initial certainty
  2. wf-table-add stores answer with 'definite certainty
  3. wf-table-add stores answer with 'unknown certainty
  4. wf-table-answers returns (answer . certainty) pairs
  5. Same answer with 'definite supersedes 'unknown
  6. Multiple answers with mixed certainties
  7. Table completion: wf-table-entry status transitions active → complete
  8. Empty table returns '()
  9. wf-all-mode-merge deduplicates correctly
 10. wf-all-mode-merge prefers 'definite over 'unknown
 11. wf-all-mode-merge: same var, different ground values, different certainties
     (e.g., X=5 'definite + X=6 'unknown → both kept, keyed on answer not certainty)
 12. Integration: wf-table with run-to-quiescence
 13. Integration: wf-table with wf-engine (end-to-end)
```

## 5.7 Dependencies

- **Depends on**: Phase 1 (propagator infrastructure), existing `tabling.rkt`
- **Used by**: Phase 4 (wf-engine uses tabling for non-ground queries)


---

# Phase 6: Test Suite — Known Well-Founded Models

## 6.1 Goal

Comprehensive test suite validating the WFLE against published well-founded models from the logic programming literature and against the stratified engine for programs where both should agree.

## 6.2 Test Categories

### 6.2.1 Literature Examples (~15 tests)

Standard well-founded semantics examples from Van Gelder, Ross, and Schlipf (1991):

```
test-wf-literature-01.rkt:
  ;; Two-atom odd cycle (canonical)
  1. p :- not q. q :- not p. → p=unknown, q=unknown

  ;; Three-atom cycle
  2. p :- not q. q :- not r. r :- not p. → all unknown

  ;; Even cycle (has a model)
  3. p :- not q. q :- not p. r :- p. → p: unknown, q: unknown, r: unknown

  ;; Stratifiable (well-founded = 2-valued)
  4. a :- not b. b :- not c. c. → a=true, b=false, c=true

  ;; Win/lose game
  5. win(a) :- move(a,b), not win(b).
     move(a,b). move(b,a). move(b,c). → win(a)=unknown, win(b)=true

  ;; Ancestor (positive only)
  6. ancestor(X,Y) :- parent(X,Y).
     ancestor(X,Y) :- parent(X,Z), ancestor(Z,Y).
     parent(a,b). parent(b,c).
     → ancestor(a,b)=true, ancestor(a,c)=true, ancestor(b,c)=true

  ;; Reachable with negation
  7. reachable(X) :- source(X).
     reachable(X) :- edge(Y,X), reachable(Y), not blocked(Y).
     → correct 3-valued model

  ;; Default reasoning
  8. flies(X) :- bird(X), not abnormal(X).
     abnormal(X) :- penguin(X).
     → flies(tweety)=true if bird(tweety) and not penguin(tweety)

  ;; Clark completion equivalence
  9. p :- q, not r. p :- s. q. s. → p=true (via s), r=false, q=true

  ;; Unfounded atoms
 10. p :- q. q :- p. → p=false, q=false (unfounded — no external support)

  ;; Mixed support
 11. p :- q. q :- r. r. p :- not s. s :- not r.
     → multiple derivation paths, correct model

  ;; Large acyclic stratifiable
 12. 20-predicate chain with negation (no cycles) → matches stratified

  ;; Disjunctive-like via multiple clauses
 13. p :- a. p :- b. a :- not b. b :- not a. → p=unknown (neither a nor b is certain)

  ;; Three-valued propagation
 14. p :- q, not r. q :- not s. s :- not q. r :- not t. t.
     → q=unknown, r=false, p=unknown

  ;; Performance: 50-predicate random graph → terminates, correct
 15. Randomized test with known model
```

### 6.2.2 Comparison Tests (~10 tests)

Same programs on both engines — verify agreement on stratifiable programs:

```
test-wf-comparison-01.rkt:
  1. Pure positive program: same answers
  2. Stratifiable with 2 strata: same answers
  3. Stratifiable with 5 strata: same answers
  4. Program without negation: same answers, same count
  5. Ancestor query: same answers
  6. Reachable query: same answers
  7. Default reasoning (no cycles): same answers
  8. Performance comparison: wall time within 3× threshold
  9. Cell count comparison: 2× for WFLE on bilattice atoms
 10. Propagator count comparison: characterize overhead
```

### 6.2.3 Error Handling Tests (~5 tests)

```
test-wf-errors-01.rkt:
  1. Fuel exhaustion on divergent program → returns partial results
  2. Contradiction detection → reported correctly
  3. Empty program → empty results (no errors)
  4. Missing relation → graceful handling
  5. Timeout respected via solver-config
```

## 6.3 File Changes

| File | Change | Scope |
|------|--------|-------|
| `test-wf-literature-01.rkt` | NEW — literature examples | ~200 lines |
| `test-wf-comparison-01.rkt` | NEW — stratified vs WF comparison | ~150 lines |
| `test-wf-errors-01.rkt` | NEW — error handling | ~60 lines |

## 6.4 Dependencies

- **Depends on**: Phases 1-5 (complete WFLE pipeline)


---

# Phase 7: Benchmark Comparison

## 7.1 Goal

Quantitative comparison of the stratified engine and WFLE on the same programs, establishing performance characteristics and validating the effort/benefit tradeoff.

## 7.2 Benchmark Design

### 7.2.1 Metrics

| Metric | Measurement |
|--------|-------------|
| Wall time | `time` wrapper around solve call |
| Cell count | `prop-network-next-cell-id` at quiescence |
| Propagator count | `prop-network-next-prop-id` at quiescence |
| Propagator firings | fuel-consumed = initial-fuel − `net-fuel-remaining` |
| BSP rounds | Observer round count |
| Answer count | Length of result list |
| Answer agreement | Set equality of 'definite answers |
| Iterations to convergence | Count from `wf-iterate` loop (WFLE only) |

### 7.2.2 Test Programs

| Program | Size | Negation | Expected |
|---------|------|----------|----------|
| ancestor (5 facts) | Small | None | WFLE ~1.5× slower (bilattice overhead on positive-only) |
| ancestor (50 facts) | Medium | None | Characterize scaling |
| reachable with blocked | Medium | Stratifiable | Same answers, WFLE ~2× cells |
| default birds | Small | Stratifiable | Same answers |
| win/lose game (10 nodes) | Medium | Cycles | WFLE produces answers, stratified rejects |
| p ↔ not q cycle | Tiny | Odd cycle | WFLE: unknown; stratified: compile error |
| 3-stratum chain (20 preds) | Large | Stratifiable | Same answers, compare time |
| Random graph (50 preds, 10% neg) | Large | Mixed | Characterize |

**Iteration convergence analysis**: For each WFLE benchmark, record iterations-to-convergence alongside wall time. Expected bounds:
- Positive-only programs: 1 iteration (bilattice trivially stable)
- Stratifiable programs: 1-2 iterations (all NAF resolved on first pass)
- Odd-cycle programs: 2-3 iterations (initial pass → bilattice update → stability check)
- Complex mixed programs: characterize (should be ≤ 2n where n = negation-participating predicates)

Pathological examples to test: long alternating negation chains (a :- not b. b :- not c. c :- not d. ...) and dense negative dependency graphs.

### 7.2.3 Benchmark Runner

```racket
;; Benchmark a single program on both engines.
;; Returns: (hasheq with all metrics for both engines)
(define (benchmark-program program-name clauses facts goal query-vars)
  (define config (default-solver-config))
  ;; Run stratified
  (define strat-config (solver-config-merge config (hasheq 'semantics 'stratified)))
  (define strat-start (current-inexact-milliseconds))
  (define strat-result
    (with-handlers ([exn:fail? (lambda (e) (list 'error (exn-message e)))])
      (stratified-solve-goal strat-config store goal-name goal-args query-vars)))
  (define strat-time (- (current-inexact-milliseconds) strat-start))
  ;; Run well-founded
  (define wf-config (solver-config-merge config (hasheq 'semantics 'well-founded)))
  (define wf-start (current-inexact-milliseconds))
  (define wf-result
    (wf-solve-goal wf-config store goal-name goal-args query-vars))
  (define wf-time (- (current-inexact-milliseconds) wf-start))
  ;; Compare and report
  ...)
```

## 7.3 File Changes

| File | Change | Scope |
|------|--------|-------|
| `test-wf-benchmark-01.rkt` | NEW — benchmark comparison suite | ~150 lines |
| `tools/wf-benchmark.rkt` | NEW — benchmark runner with reporting | ~100 lines |

## 7.4 Dependencies

- **Depends on**: Phases 1-6 (complete WFLE + test suite)


---

# Appendix A: End-to-End Walkthrough — `p :- not q. q :- not p.`

This appendix traces the complete execution of the canonical odd-cycle example through the WFLE, from source program to three-valued result.

## A.1 Source Program

```prologos
ns wf-demo

defr p
| p :- not q

defr q
| q :- not p
```

## A.2 Step 1: Relation Store

The elaborator produces a relation store:

```
store = {
  p → (relation-info 'p
        variants: [(variant-info '()
          clauses: [(clause-info
            goals: [(goal-desc 'not (list (expr-goal-app 'q '())))])])])
  q → (relation-info 'q
        variants: [(variant-info '()
          clauses: [(clause-info
            goals: [(goal-desc 'not (list (expr-goal-app 'p '())))])])])
}
```

## A.3 Step 2: Solver Dispatch

```racket
(parameterize ([current-solver-mode 'well-founded])
  (stratified-solve-goal config store 'p '() '()))
```

The dispatch check sees `current-solver-mode = 'well-founded` and routes to `wf-solve-goal`.

## A.4 Step 3: Ground Clause Extraction

`extract-ground-clauses` walks the store and produces:

```racket
;; program = ((head-name . body-specs) ...)
'((p . ((neg . q)))     ;; p :- not q
  (q . ((neg . p))))    ;; q :- not p
```

## A.5 Step 4: Bilattice Network Construction

`wf-compile-program` creates:

```
Network state after compilation:
  Cells:
    cell-0: lower-p  = #f  (ascending, merge = or)
    cell-1: upper-p  = #t  (descending, merge = and)
    cell-2: lower-q  = #f  (ascending, merge = or)
    cell-3: upper-q  = #t  (descending, merge = and)
    cell-4: lower-neg-q = #f  (ascending, merge = or)
    cell-5: upper-neg-q = #t  (descending, merge = and)
    cell-6: lower-neg-p = #f  (ascending, merge = or)
    cell-7: upper-neg-p = #t  (descending, merge = and)

  Propagators:
    prop-0: [cell-3] → [cell-4]    ;; lower-neg-q := ¬upper-q
    prop-1: [cell-2] → [cell-5]    ;; upper-neg-q := ¬lower-q
    prop-2: [cell-4] → [cell-0]    ;; lower-p := lower-p ∨ lower-neg-q
    prop-3: [cell-5] → [cell-1]    ;; aggregate upper-p: feasible?
    prop-4: [cell-1] → [cell-6]    ;; lower-neg-p := ¬upper-p
    prop-5: [cell-0] → [cell-7]    ;; upper-neg-p := ¬lower-p
    prop-6: [cell-6] → [cell-2]    ;; lower-q := lower-q ∨ lower-neg-p
    prop-7: [cell-7] → [cell-3]    ;; aggregate upper-q: feasible?

  Bilattice vars:
    p → (bilattice-var cell-0 cell-1 bool-lattice)
    q → (bilattice-var cell-2 cell-3 bool-lattice)
```

## A.6 Step 5: Run to Quiescence

```
Worklist: [prop-0 prop-1 prop-2 prop-3 prop-4 prop-5 prop-6 prop-7]

Round 1: Fire all (BSP or Gauss-Seidel)
  prop-0: upper-q = #t → lower-neg-q := ¬#t = #f    (no change, already #f)
  prop-1: lower-q = #f → upper-neg-q := ¬#f = #t    (no change, already #t)
  prop-2: lower-neg-q = #f → lower-p := #f ∨ #f = #f (no change)
  prop-3: upper-neg-q = #t → clause feasible → upper-p stays #t (no change)
  prop-4: upper-p = #t → lower-neg-p := ¬#t = #f    (no change)
  prop-5: lower-p = #f → upper-neg-p := ¬#f = #t    (no change)
  prop-6: lower-neg-p = #f → lower-q := #f ∨ #f = #f (no change)
  prop-7: upper-neg-p = #t → clause feasible → upper-q stays #t (no change)

No cell changed → worklist empty → quiescent.
```

## A.7 Step 6: Read Results

```racket
(bilattice-read net p-bvar)
;; lower-p = #f, upper-p = #t → 'unknown  ✓

(bilattice-read net q-bvar)
;; lower-q = #f, upper-q = #t → 'unknown  ✓
```

Both atoms are genuinely undetermined — the well-founded semantics correctly identifies the odd cycle as irresolvable. Compare with the stratified engine, which would reject this program at compile time (negative edge within SCC).


---

# Appendix B: Interaction with Existing Infrastructure

## B.1 Metavar System

The WFLE does not interact with the metavar system. Metavars are used during type checking and elaboration; the WFLE operates at the solver level on elaborated programs. No metavar changes needed.

## B.2 Trait System

The WFLE does not add new traits. The existing `Lattice` trait (Phase 1 of the Logic Engine design) could be used for lattice descriptors, but for simplicity the WFLE uses Racket-level structs (`lattice-desc`). This avoids circular dependencies and keeps the WFLE infrastructure independent of the Prologos type system.

## B.3 ATMS

Per the Stage 2 resolved design decision (§11.1), the ATMS composes orthogonally:

- ATMS handles branching (choice points, `amb`, worldview exploration)
- Bilattice handles incomplete information (NAF, well-founded undeterminacy)
- Within each ATMS worldview, the bilattice converges independently
- No structural changes to `atms.rkt`

Future: for stable model enumeration, `atms-amb` creates choice points over `'unknown` atoms.

## B.4 QTT / Multiplicities

No interaction. The WFLE is a solver backend; multiplicities are tracked at the type-checking level.

## B.5 Solver Config (`semantics` Key)

The WFLE is selected via the existing `solver-config` mechanism. Current solver keys:

| Key | Default | Purpose |
|-----|---------|---------|
| `execution` | `'parallel` | DFS parallelism strategy |
| `threshold` | `4` | Max parallel branches |
| `strategy` | `'auto` | Search strategy selection |
| `tabling` | `'by-default` | Tabling behavior |
| `provenance` | `'none` | Proof provenance tracking |
| `timeout` | `#f` | Query timeout |
| `narrow-*` | (various) | Narrowing search heuristics (Phase 3b/3c) |
| `cfa-scope` | `'module` | CFA scope (Phase 3a) |
| **`semantics`** | **`'stratified`** | **NEW: Backend selection** |

The `semantics` key selects the logic engine backend:
- `'stratified` (default): Current engine — stratification check, stratum-ordered evaluation, fails on unstratifiable programs
- `'well-founded`: WFLE — bilattice iteration, three-valued output, handles cyclic negation

This is the only user-visible entry point. All other WFLE internals (bilattice-vars, iterative loop, NAF oracle) are implementation details.

## B.6 Explain Path for Unknown Atoms

The `explain` form must handle three-valued results. For atoms determined `'unknown` by the WFLE:

- `wf-explain-goal` returns a `wf-undeterminacy-explanation` struct containing:
  - The atom in question
  - The cycle of predicates responsible (extracted from the bilattice's stable gap)
  - The specific NAF dependency chain (which `not` created the cycle)
- The explanation renderer (pretty-print.rkt) needs a new case for this struct
- For atoms determined `'true` or `'false`, the existing proof-tree renderer works unchanged

## B.7 Existing Test Suite

All existing tests continue to pass. The WFLE is additive — no existing behavior changes. The default `semantics` is `'stratified`, so all existing programs use the stratified engine unless explicitly switched.


---

# Appendix C: Future Evolution — Approach C (Hybrid)

The Stage 2 design recommends Approach A (bilattice pairs) with evolution to Approach C (hybrid with alternating scheduler) when needed. The evolution path is:

1. **Bilattice infrastructure** (Phases 1-2) carries over unchanged
2. **Propagator patterns** (Phase 3) carry over — they are monotone in L² regardless of scheduling
3. **Scheduler augmentation**: add priority levels to propagators based on alternation depth
4. **Priority-aware `run-to-quiescence`**: inner fixpoints converge fully before outer fixpoints advance
5. **Use case trigger**: coinductive types with nested inductive substructure, or full μ-calculus model checking

The key insight: everything built in Phases 1-7 is prerequisite infrastructure for Approach C. No throwaway work.

## C.2 First-Class Bilattice Variables

The current design keeps bilattice-vars as internal Racket structs within `wf-engine.rkt`. A future evolution would expose bilattice variables as first-class Prologos values accessible from user programs:

1. **Prologos-level `BilatticeVar A` type**: wraps the Racket bilattice-var struct, parameterized by the value lattice
2. **`bilattice-read` as Prologos function**: returns `Exact A | Approx A A | Contradiction` (a union type or custom ADT)
3. **User-defined lattice descriptors**: bridge between the Prologos `Lattice` trait and the Racket `lattice-desc` struct
4. **Custom propagator wiring**: users write propagators over bilattice-vars for domain-specific three-valued reasoning

This evolution would serve:
- **Runtime monitoring**: user-level bilattice cells tracking partial verdicts
- **Abstract interpretation**: user-defined abstract domains with widening/narrowing on bilattice pairs
- **Game-theoretic semantics**: bilattice cells for alternating quantifier blocks

Prerequisites: the `Lattice` trait infrastructure, a safe API for propagator construction from Prologos, and a story for managing cell lifetimes. This is post-WFLE work — the internal-only design in Phases 1-7 is the right first step.

## C.3 Incremental Re-Query

The current design computes well-founded semantics from scratch on each `wf-solve-goal` call: fresh bilattice-vars, fresh propagator wiring, full convergence. For interactive development (REPL use), this may be expensive when re-running the same query after small program changes.

The propagator infrastructure inherently supports incrementality — that's a core benefit of the architecture. But exploiting it for the WFLE requires:

1. **Persistent bilattice networks**: cache the converged bilattice between queries, keyed by program version (similar to `current-strata-cache` in `stratified-eval.rkt`)
2. **Retraction protocol**: when facts are added/removed, identify affected bilattice-vars and reset them to their initial state (⊥ for lower, ⊤ for upper), then re-converge. This is non-trivial because cell values are monotonic — retracting a fact requires a "reset" operation that the current propagator network doesn't support
3. **Delta propagation**: only re-fire propagators whose inputs changed since the last query, rather than re-running the full solver

The ATMS already provides a form of incremental truth maintenance for branching. The WFLE+ATMS composition would be the natural place to address incremental re-query, since ATMS worldview exploration already maintains multiple consistent states.

This is genuine future work — not a concern for Phases 1-7, where the from-scratch approach is correct and sufficient.


---

# Phase Summary

| Phase | New Lines | Modified Lines | New Files | Test Count |
|-------|-----------|----------------|-----------|------------|
| 1. Descending Cells | ~40 | ~5 | 0 | ~15 |
| 2. Bilattice Module | ~120 | 0 | 1 | ~20 |
| 3. WF Propagator Patterns | ~250 | 0 | 1 | ~25 |
| 4a. WF Engine Core | ~200 | ~20 | 1 | ~25 |
| 5. Three-Valued Tabling | ~60 | 0 | 0 | ~13 |
| 4b. Engine + Tabling | ~50 | ~10 | 0 | ~8 |
| 6. Test Suite (Literature) | ~410 | 0 | 3 | ~30 |
| 7. Benchmark Comparison | ~250 | 0 | 2 | ~8 |
| **Total** | **~1380** | **~35** | **8** | **~144** |

Total estimated effort: Medium. The propagator infrastructure does most of the heavy lifting — the WFLE is primarily new propagator *patterns* and *wiring*, not new infrastructure.


---

# References

1. Van Gelder, A., Ross, K. A., & Schlipf, J. S. (1991). "The Well-Founded Semantics for General Logic Programs." JACM 38(3).
2. Denecker, M., Marek, V., & Truszczynski, M. (2004). "Ultimate Approximation and Its Application in Nonmonotonic Knowledge Representation Systems." Information and Computation 192(1).
3. Chen, W., & Warren, D. S. (1996). "Tabled Evaluation with Delaying for General Logic Programs." JACM 43(1).
4. Fitting, M. (2002). "Fixpoint Semantics for Logic Programming — A Survey." Theoretical Computer Science 278(1-2).
5. Prologos Logic Engine Design (internal): `2026-02-24_LOGIC_ENGINE_DESIGN.md`
6. Prologos Stage 2 WFLE Design (internal): `2026-03-14_WELL_FOUNDED_LOGIC_ENGINE_DESIGN.md`
7. Prologos Formal Modeling Research (internal): `FORMAL_MODELING_ON_PROPAGATORS.org`
