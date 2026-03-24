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
| 1 | Microbenchmark + adversarial + frequency analysis | ✅ | `312ca3a`. Zero compound checks in suite. Success 8-54μs, failure 333μs. |
| 2a | Merge-per-relation registry | ✅ | `d276922`. case dispatch, 10→9 fields |
| 2b | Early-exit quiescence | ✅ | Already implemented (4 firings before exit) |
| 2c | Flat NOT guard (compound-type?) | ✅ | `3e00244`. 2.0μs → 0.47μs (4.3× faster) |
| 2d | Ground-type direct recursive check | ✅ | `a1b347d`. 8μs→2.6μs success, 333μs→3μs failure (110× faster) |
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

## 1B. Phase 1 Findings (Benchmark Data → Design Implications)

**Frequency**: Zero compound subtype checks in the full test suite. All
30 subtype? calls per representative program are flat (Nat<:Int, etc.).
The structural path is pure infrastructure for Track 2.

**Performance tiers** (10000 iterations):

| Path | μs/call | Relative | Notes |
|------|---------|----------|-------|
| Flat success | 0.15 | 1× | Fast path, no cells |
| Flat NOT | 2.0 | 13× | Overhead from structural tag check on atoms |
| Structural 1-level success | 8-10 | 55× | Mini-network + quiesce |
| Structural 2-level success | 13 | 87× | Linear with depth |
| PVec^10 success | 54 | 360× | Linear ~5μs/level |
| Structural FAILURE | 333 | 2200× | Contradiction propagation expensive |

**Design implications**:

1. **Merge registry must use `case` dispatch, not hash lookup.** The flat
   path (0.15μs) is the performance floor. Hash lookup adds ~0.5μs.
   `case` on symbol compiles to jump table — effectively free.

2. **Structural failure path needs early-exit quiescence.** The 333μs failure
   cost comes from full quiescence run after contradiction. An early-exit
   variant that checks for contradiction after each propagator firing would
   eliminate the wasted work. Add to Phase 2 scope.

3. **Flat NOT path overhead (2μs) deferred.** The 13× overhead from
   `sre-constructor-tag` calls on atoms is measurable but low-impact at
   zero frequency. Optimize when Track 2 makes it matter.

## 2. Merge-Per-Relation Registry + Failure Path Optimization

### Problem (merge registry)

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

### Problem (failure path — 333μs, 40× slower than success)

The structural failure path is expensive because `run-to-quiescence` runs
the full worklist even after contradiction is detected. For the subtype
query pattern, once any sub-cell contradicts, the answer is "not a subtype"
— remaining propagator firings are wasted work.

### Principled Fix (early-exit quiescence)

Add a `run-to-quiescence/early-exit` variant (or a flag on `run-to-quiescence`)
that checks `net-contradiction?` after each propagator firing and exits
immediately on contradiction.

```racket
(define (run-to-quiescence-early-exit net)
  ;; Same as run-to-quiescence but bail on first contradiction
  (define-values (net* changed?)
    (drain-worklist net
      #:check-contradiction? #t))  ;; NEW flag
  net*)
```

The subtype query pattern uses this variant:
```racket
(define net4 (run-to-quiescence-early-exit net3))  ;; fast-fail on contradiction
```

**Expected improvement**: The 333μs failure cost should drop to ~20-30μs
(first-level decomposition + one sub-cell contradiction check + immediate exit).
This brings failure cost in line with success cost.

### Problem (flat NOT path — 2μs overhead on atoms)

Every `subtype?` call returning `#f` on atoms pays 13× overhead (2μs vs 0.15μs)
from the structural tag check. The current flow: `flat-subtype?` fails →
`sre-structural-subtype-check` called → `sre-constructor-tag` on both values →
returns `#f` (atoms have no tag) → exits.

### Fix (guard structural call with quick compound check)

Before calling `sre-structural-subtype-check`, verify at least one value is
a known compound struct type. Atoms (expr-Nat, expr-Int, expr-Bool, etc.)
skip the structural path entirely.

```racket
;; Quick check: is this a compound type expression?
(define (compound-type? v)
  (or (expr-Pi? v) (expr-Sigma? v) (expr-app? v) (expr-PVec? v)
      (expr-Set? v) (expr-Map? v) (expr-Vec? v) (expr-Eq? v)
      (expr-pair? v) (expr-lam? v)))

(define (subtype? t1 t2)
  (cond
    [(equal? t1 t2) #t]
    [(flat-subtype? t1 t2) #t]
    ;; Only try structural if both are compound
    [(and (compound-type? t1) (compound-type? t2))
     (sre-structural-subtype-check t1 t2)]
    [else #f]))
```

This eliminates the 1.85μs overhead for atom comparisons (struct predicate
checks are ~0.01μs each — effectively free).

### NTT Correspondence

```prologos
;; NTT: each lattice declaration carries its ordering
;; The merge function IS the ordering (a ≤ b iff merge(a,b) = b)
;; Different relations use different orderings on the same carrier:
;;   equality: flat ordering (Nat ≠ Int → top)
;;   subtype: partial ordering (Nat ≤ Int → Int)
;; The merge-registry is the Racket encoding of NTT's multi-ordered lattice.
```

## 2d. Ground-Type Direct Recursive Check

### Problem

The mini-network query pattern (Phase 4 of Track 1) creates a full
`prop-network` for each compound subtype check: CHAMPs for cells,
propagators, decomps; worklist drain; struct-copies per iteration.
~80-100 allocations for a 2-cell query. Benchmarks show:
- Success: 8-54μs (dominated by allocation, not computation)
- Failure: 333μs (cold-start + 4 propagator firings)

For ground-type subtype checks (both values fully known, no metas),
propagation adds no value — there's no incremental information to flow.
The computation is a total function: walk the structure, check variance
at each level, verify leaves via flat subtype check.

### Principled Fix

Replace the mini-network query pattern with a direct recursive function
for ground-type checks. Uses the SRE's data structures (ctor-desc,
variance annotations, merge-registry) but not the propagator machinery.

```racket
(define (structural-subtype-ground? domain t1 t2)
  (cond
    [(equal? t1 t2) #t]
    [else
     (define tag1 (sre-constructor-tag domain t1))
     (define tag2 (sre-constructor-tag domain t2))
     (cond
       ;; Both compound, same tag → check components with variance
       [(and tag1 tag2 (eq? tag1 tag2))
        (define desc (lookup-ctor-desc tag1 #:domain (sre-domain-name domain)))
        (and desc
             (let ([comps1 ((ctor-desc-extract-fn desc) t1)]
                   [comps2 ((ctor-desc-extract-fn desc) t2)]
                   [variances (or (ctor-desc-component-variances desc)
                                  (make-list (ctor-desc-arity desc) '=))])
               (for/and ([c1 (in-list comps1)]
                         [c2 (in-list comps2)]
                         [v (in-list variances)])
                 (case v
                   [(+) (structural-subtype-ground? domain c1 c2)]
                   [(-) (structural-subtype-ground? domain c2 c1)]
                   [(=) (equal? c1 c2)]
                   [(ø) #t]))))]
       ;; Atomic or different tags → use subtype merge
       [else
        (define merge (sre-domain-merge domain sre-subtype))
        (define merged (merge t1 t2))
        (and (not ((sre-domain-contradicts? domain) merged))
             (equal? merged t2))])]))
```

**Performance expected**: ~0.3-0.5μs for 1-level success (vs 8μs), ~3-5μs
for 10-level (vs 54μs), ~0.3-0.5μs for failure (vs 333μs). Zero allocations.

**Principles alignment**:
- **Propagator-First**: The function reads FROM the SRE's data structures
  (ctor-desc, variance, merge-registry). The structural knowledge is on-network.
  Ground-type subtyping is a pure function over fully-known values — propagation
  adds no information. Analogous to not creating a propagator network to compute `2 + 3`.
- **Data Orientation**: Variance and merge functions are data on ctor-desc/domain.
  The recursive walk is driven by this data, not hardcoded per-type.
- **Completeness**: The mini-network path is PRESERVED for Track 2 (partial
  information with metas). Ground-type optimization is a specialization, not
  a replacement.

**Provenance note**: If explanation is needed ("why is PVec Nat <: PVec Int?"),
the recursive walk can collect a proof trace as a return value alongside the
boolean. This is cheaper than reconstructing provenance from cell write histories.

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
