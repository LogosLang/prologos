# Type Inference on the Logic Engine — Design Document

**Date**: 2026-02-25
**Status**: DESIGN (pre-implementation)
**Scope**: Metavar resolution and type inference redesigned on Prologos's propagator-based logic engine
**Prerequisites**: Logic Engine Phases 1-7 complete, benchmarking framework (companion document)

---

## 1. Executive Summary

Prologos's type inference system currently uses an **ad-hoc metavar system** — mutable hash tables for metavar storage, a handwritten unification algorithm, speculative execution via full-state copy/restore, and a worklist-based trait resolution pass. This works but has known limitations:

- **Error messages lack dependency tracking** — when a constraint fails, the system reports what failed but not *why* (which upstream decisions led to the conflict)
- **Speculative execution is expensive** — `save-meta-state`/`restore-meta-state!` copies the entire meta store, even for small speculative branches
- **No incremental re-checking** — changing one definition requires re-elaborating everything
- **Trait resolution is one-shot** — constraints are solved in a single post-type-check pass; no iterative refinement

Meanwhile, Prologos now has a **mature propagator infrastructure** (Phases 1-7 of the logic engine): persistent PropNetworks backed by CHAMP maps, BSP parallel execution, persistent ATMS for hypothetical reasoning, persistent UnionFind for disjoint sets, SLG-style tabling, and a working DFS relational solver.

This document designs the **refactoring of type inference to use the propagator infrastructure** — replacing the ad-hoc metavar system with proper lattice-valued propagator cells, where:

- **Metavariables become cells** on a propagator network
- **Unification constraints become propagators** between cells
- **Trait resolution becomes propagator-triggered** (fire when argument types stabilize)
- **Speculative type-checking uses ATMS worldviews** instead of full state copy
- **Error messages carry dependency provenance** via ATMS support sets

This is the **"Elaborator Propagator Refactoring"** identified in `DEFERRED.md` and recommended (with "High" confidence) in the research document "Towards a General Logic Engine on Propagators."

---

## 2. Current Architecture: The Ad-Hoc Metavar System

### 2.1 Four Parallel Metavar Stores

| Store | Parameter | Domain | Solved To |
|-------|-----------|--------|-----------|
| Expression metas | `current-meta-store` | `hasheq : id → meta-info` | Types, terms |
| Level metas | `current-level-meta-store` | `hasheq : id → solution\|'unsolved` | Universe levels |
| Multiplicity metas | `current-mult-meta-store` | `hasheq : id → 'm0\|'m1\|'mw\|'unsolved` | QTT multiplicities |
| Session metas | `current-sess-meta-store` | `hasheq : id → session-type\|'unsolved` | Session protocol states |

### 2.2 Constraint Lifecycle

```
1. fresh-meta(ctx, type, source)          → creates unsolved meta
2. unify(ctx, t1, t2)                     → may solve metas or postpone
3. add-constraint!(lhs, rhs, ctx, source) → registers postponed constraint
4. solve-meta!(id, solution)              → solves meta, triggers wakeup
5. retry-constraints-for-meta!(id)        → retries waiting constraints
6. resolve-trait-constraints!()           → post-type-check trait resolution
7. zonk-final(expr)                       → substitutes all solved metas
```

### 2.3 Speculative Execution

```racket
(define saved (save-meta-state))     ;; snapshot ALL four stores
;; ... try branch A ...
(if success
    ;; keep changes
    (restore-meta-state! saved)      ;; discard, try branch B
    )
```

**Cost**: O(N) where N is total metas across all stores. For large programs with hundreds of metas, this is measurable.

### 2.4 Limitations

1. **No dependency tracking**: When `unify(Int, String)` fails, we know it failed but not *which* upstream inference decision led to `Int` being here
2. **No incremental propagation**: Solving one meta triggers immediate retry of waiting constraints, but there's no transitive propagation — if retrying a constraint solves another meta, that meta's dependents aren't automatically retried (requires explicit wakeup chain)
3. **State copy for speculation**: Full-state copy/restore is the only mechanism for hypothetical reasoning
4. **Imperative**: Mutable hash tables make parallelism impossible and reasoning about meta state difficult
5. **No learning from failure**: When a speculative branch fails, the failure information is discarded — no nogood recording

---

## 3. Target Architecture: Propagator-Based Type Inference

### 3.1 The Isomorphism

| Current (Ad-Hoc) | Target (Propagator) |
|-------------------|---------------------|
| Metavariable (gensym id) | Cell on PropNetwork (CellId, deterministic Nat) |
| Meta solution (value in hasheq) | Cell value (lattice element) |
| `solve-meta!(id, val)` | `net-cell-write(net, cid, val)` (lattice join) |
| Unification constraint | Propagator between two cells |
| `add-constraint!` | `net-add-propagator` |
| `retry-constraints-for-meta!` | Automatic: cell change → schedule dependent propagators |
| `save/restore-meta-state!` | ATMS: create worldview / believe hypothesis |
| Trait constraint | Propagator watching type-arg cells, fires when ground |
| `zonk(expr)` | `net-cell-read` to extract solved values |
| Unsolved meta | Cell at `⊥` (bottom of type lattice) |
| Contradiction (unification failure) | Cell at `⊤` (top) → ATMS nogood recording |

### 3.2 The Type Lattice

**Domain**: The lattice of Prologos types with partial information.

```
⊤ (contradiction / inconsistent)
│
├── Int    String    Bool    Nat    ...  (ground types)
│
├── ?a → ?b   (Pi with unsolved domain/codomain)
│
├── (List ?a)   (Option ?a)   ...  (parameterized types with unknowns)
│
├── {unsolved meta}  (any cell not yet constrained)
│
⊥ (no information — fresh metavariable)
```

**Lattice operations:**
- `bot` = `expr-meta` (unsolved, no information)
- `join(⊥, T)` = `T` (learning something about an unknown)
- `join(T, T)` = `T` (idempotent — same information twice)
- `join(T1, T2)` where `T1 ≠ T2` = `⊤` (contradiction) or unification result
- `leq(⊥, T)` = `#t` for all `T`
- `leq(T, ⊤)` = `#t` for all `T`

**Key insight**: The type lattice is essentially the **FlatLattice** from `lattice-instances.prologos` applied to types. Each cell holds either `⊥` (unsolved), a specific type, or `⊤` (contradiction). The join is unification — merging partial information.

**Applied metas** (e.g., `?m x y` where the meta is applied to arguments) do **not** require a richer lattice. Prologos's existing unification uses Miller's pattern unification (`decompose-meta-app` + `pattern-check` + `invert-args` in `unify.rkt`): when the pattern condition holds (all arguments are distinct bound variables), the meta is solved to a concrete lambda term via argument inversion. This lambda is an ordinary type expression — it fits in the same FlatLattice. When the pattern condition fails (e.g., `?m zero`), the constraint is **postponed** — in propagator terms, the propagator fires, reads the cell, finds `⊥`, and returns the network unchanged. When another propagator later solves the meta from a different direction, dependents fire automatically. This "idle until ground" pattern is strictly better than the current system's explicit wakeup chains, and requires no lattice extension.

### 3.3 Propagator Types for Type Inference

**Unification propagator**: Created when two types must be equal.

```
Cell A ←→ Cell B
  When A changes: write A's value to B (via unification)
  When B changes: write B's value to A (via unification)
```

This is a **bidirectional** propagator. The Radul-Sussman model supports this naturally — a propagator fires whenever any of its input cells change.

**Decomposition propagator**: Created for structured types.

```
Cell (Pi ?domain ?codomain) decomposed into:
  Cell domain ← propagator → Cell (Pi cell)
  Cell codomain ← propagator → Cell (Pi cell)
```

When the Pi cell gets more information (e.g., unified with `Int → String`), the decomposition propagator writes `Int` to the domain cell and `String` to the codomain cell.

**Trait resolution propagator**: Created for each trait constraint.

```
Cell type-arg → [when ground] → look up trait instance → Cell dict-param
  Fires only when type-arg cell has a ground (fully-resolved) value
  On fire: performs monomorphic or parametric trait lookup
  Writes resolved dict to the dict-param cell
```

This replaces the explicit `resolve-trait-constraints!()` post-pass — trait resolution happens automatically as type information flows through the network.

**Subtype propagator**: For coercion/widening.

```
Cell T₁ → [subtype check] → Cell T₂
  When T₁ changes: check T₁ <: T₂, if fails → contradiction
  Handles Nat <: Int <: Rat widening
  Handles union type subset checking
```

### 3.4 ATMS Integration for Speculative Type-Checking

**Current speculation**: Church fold detection tries to elaborate as a fold; if that fails, falls back to normal elaboration. Uses `save/restore-meta-state!`.

**Propagator alternative**: Create ATMS hypotheses for each speculative branch.

```
Hypothesis h₁: "this is a Church fold"
Hypothesis h₂: "this is NOT a Church fold"

Under h₁:
  - Elaborate as Church fold
  - If contradiction (cell reaches ⊤): record nogood {h₁}
  - h₁ is invalidated; h₂ is the surviving worldview

Under h₂:
  - Elaborate normally
  - All inferences contingent on h₂

Advantage: If fold elaboration partially succeeds before failing,
the successful parts can inform the normal elaboration path.
With save/restore, ALL partial work is discarded.
```

**Cost model**: ATMS labels are sets of assumptions. For deterministic programs (no speculation), cells have empty assumption labels — the ATMS overhead is near-zero. This validates the "Speculative ATMS" idea from the research document: "don't create labels until the first amb."

### 3.5 Dependency-Directed Error Messages

**Current**: Error says "Cannot unify Int with String at line 42"

**Propagator**: Error says:

```
Type error at line 42: Cannot unify Int with String

Derivation:
  - line 10: `x` inferred as Int (from `(+ x 1)` at line 10)
  - line 25: `x` required to be String (from `(string-length x)` at line 25)
  - These constraints are incompatible.

Assumptions:
  - The type of `f` was inferred as `Int → String` (line 5)
  - If this inference is wrong, the error may be elsewhere.
```

The ATMS support set for the contradiction cell identifies exactly which assumptions (upstream inference decisions) led to the conflict. This is **dependency-directed** — not just "what failed" but "why it failed."

### 3.6 Multi-Error Collection

The ad-hoc system typically aborts elaboration on the first `unify` failure, reporting one error at a time. The propagator architecture enables **multi-error collection**: a contradiction in one cell (`⊤`) does not prevent independent cells from continuing to propagate, because propagators that read a contradicted cell simply propagate the `⊤` to their outputs while other regions of the network proceed normally.

**Strategy:**
1. When a cell reaches `⊤`, record the contradiction with its ATMS support set (derivation chain)
2. Mark the cell — no further *useful* propagation through it, but dependent cells learn of the contradiction
3. Continue running the network to quiescence; independent constraint regions proceed unaffected
4. At quiescence, collect *all* contradictions (not just the first)
5. Report all errors to the user with their respective dependency chains

This transforms the type-checking experience from "fix this one error, re-run, discover the next" to "here are all the type errors in this definition." The `prop-network-contradiction` field currently records only the *first* contradiction cell; this will be extended to a list of contradiction cells in Phase 5.

---

## 4. Design: The Propagator-Based Elaborator

### 4.1 Network Lifecycle

```
1. Create fresh PropNetwork (empty)
2. For each top-level definition:
   a. Create cells for all new metas
   b. Create propagators for all unification/subtype constraints
   c. Create propagators for trait resolution
   d. Run network to quiescence
   e. Collect all contradictions (cells at ⊤) — see §3.6
   f. If contradictions: extract ATMS support sets for error messages
   g. If quiescent without contradiction: read cell values = solved types
3. Zonk = read final cell values
```

**Scheduling**: Step 2d uses the existing `run-to-quiescence` from `propagator.rkt`. Two schedulers are available: **Gauss-Seidel** (sequential worklist, fires one propagator at a time — good for chain dependencies like `?a → ?b → ?c`) and **Jacobi/BSP** (parallel, fires all worklist propagators per round with snapshot isolation — good for wide, independent constraint regions). Both reach the same fixed point regardless of firing order due to lattice commutativity + associativity + monotonicity (the CALM theorem). Scheduler selection is a Phase 6 optimization concern — Gauss-Seidel is the default.

**Bidirectional modes**: The elaborator's three bidirectional checking modes map naturally to propagator operations:
- **Checking mode** (expected type known): create cell, write expected type immediately, add unification propagator between expected and actual → constraints flow from known type downward
- **Inference mode** (type unknown): create cell at `⊥`, elaborate, read cell after quiescence → information flows upward from leaves
- **Application mode** (function type decomposes): create domain/codomain cells, add Pi decomposition propagator (§3.3) → the function cell's information decomposes into sub-cells

### 4.2 Meta Creation → Cell Creation

```racket
;; Current:
(define meta-id (fresh-meta ctx expected-type source))
;; Returns: expr-meta with gensym id

;; Propagator version:
(define-values (net* cell-id) (net-new-cell network bot type-lattice-merge))
;; Returns: updated network + deterministic CellId
;; The cell starts at ⊥ (no information)
;; type-lattice-merge = unification as lattice join
```

### 4.3 Unification → Propagator Creation

```racket
;; Current:
(unify ctx t1 t2)
;; Side effects: may solve metas, may add constraints

;; Propagator version:
(define net* (net-add-propagator network
  (list cell-t1 cell-t2)   ;; inputs
  (list cell-t1 cell-t2)   ;; outputs (bidirectional)
  (lambda (net)
    (define v1 (net-cell-read net cell-t1))
    (define v2 (net-cell-read net cell-t2))
    (define unified (unify-values v1 v2))
    (cond
      [(eq? unified 'contradiction)
       (net-cell-write net cell-t1 top)]  ;; signal contradiction
      [else
       (-> net
           (net-cell-write cell-t1 unified)
           (net-cell-write cell-t2 unified))]))))
```

### 4.4 Trait Resolution → Watch Propagator

```racket
;; Propagator that watches type-arg cells and resolves traits when ground
(define net* (net-add-propagator network
  type-arg-cells        ;; inputs: cells for each type argument
  (list dict-cell)      ;; output: the trait dict cell
  (lambda (net)
    (define type-args (map (curry net-cell-read net) type-arg-cells))
    (cond
      [(andmap ground-type? type-args)
       ;; All type args resolved — try trait lookup
       (define dict (try-monomorphic-resolve trait-name type-args))
       (if dict
           (net-cell-write net dict-cell dict)
           (net-cell-write net dict-cell top))]  ;; no instance found
      [else net]))))  ;; not yet resolved — wait for more info
```

### 4.5 Zonking → Cell Reading

```racket
;; Current:
(zonk-final expr)
;; Walks expr, replaces solved metas with solutions, defaults unsolved

;; Propagator version:
(define (read-type net cell-id)
  (define val (net-cell-read net cell-id))
  (if (eq? val bot)
      (default-type)   ;; unsolved → default (like current zonk-final)
      val))
```

---

## 5. Phased Implementation Strategy

### 5.0 Pre-Phase: Benchmarking Baseline (companion doc)

Before any refactoring, establish the benchmark baseline:
1. Instrument current system with heartbeat counters
2. Record phase-level timing for the full test suite
3. Create the comparative benchmark programs (§6)
4. Store baseline metrics in `data/benchmarks/baseline-system-a.jsonl`

### 5.1 Phase 1: Type Lattice Module (~100 lines)

**Files**: New `type-lattice.rkt`

Define the type lattice for propagator cells:

```racket
;; type-lattice.rkt

;; A type-lattice-value is one of:
;; - 'bot      (no information)
;; - expr      (a Prologos type expression)
;; - 'top      (contradiction)

(define (type-lattice-merge v1 v2)
  (cond
    [(eq? v1 'bot) v2]
    [(eq? v2 'bot) v1]
    [(eq? v1 'top) 'top]
    [(eq? v2 'top) 'top]
    [(equal? v1 v2) v1]
    [else
     ;; Attempt structural unification
     (define result (try-unify-pure v1 v2))
     (if result result 'top)]))

(define (type-lattice-contradicts? v)
  (eq? v 'top))
```

**Key decision**: `try-unify-pure` is a **pure** version of unification that returns a unified type or `#f`, without side effects. This is necessary because propagator merge functions must be pure (the network is persistent/immutable).

### 5.2 Phase 2: Parallel Infrastructure (~150 lines)

**Files**: New `elaborator-network.rkt`

Build the bridge between the elaborator and the propagator network:

```racket
;; elaborator-network.rkt

;; Create a fresh elaboration network
(define (make-elaboration-network)
  (prop-network-empty))

;; Allocate a meta as a cell
(define (elab-fresh-meta net ctx type source)
  (define-values (net* cid) (net-new-cell net 'bot type-lattice-merge type-lattice-contradicts?))
  (values net* cid))

;; Add a unification constraint
(define (elab-add-unify-constraint net cell-a cell-b)
  (net-add-propagator net (list cell-a cell-b) (list cell-a cell-b)
    (make-unify-propagator cell-a cell-b)))

;; Run to quiescence and extract results
(define (elab-solve net)
  (define net* (run-to-quiescence net))
  (if (prop-network-contradiction net*)
      (values 'error (extract-contradiction-info net*))
      (values 'ok net*)))
```

### 5.3 Phase 3: Elaborator Dual-Mode (~200 lines)

**Files**: `elaborator.rkt` modifications

Run the elaborator in **dual mode**: both the current ad-hoc system AND the propagator system, comparing results. This ensures correctness before switching over.

```racket
(define (elaborate-dual expr env depth)
  ;; System A: current implementation
  (define result-a (elaborate expr env depth))

  ;; System B: propagator implementation
  (define result-b (elaborate-propagator expr env depth))

  ;; Compare (in debug mode)
  (when (current-dual-mode-check?)
    (assert (alpha-equivalent? (zonk result-a) (read-result result-b))))

  result-a)  ;; return System A result (trusted)
```

This dual-mode approach is conservative — it validates the propagator system against the known-correct ad-hoc system before any switchover.

### 5.4 Phase 4: ATMS Integration for Speculation (~200 lines)

**Files**: `elaborator-network.rkt` extensions

Replace `save/restore-meta-state!` with ATMS worldviews:

```racket
(define (elaborate-speculative net alternatives)
  ;; Create one hypothesis per alternative
  (define hypotheses
    (for/list ([alt alternatives])
      (define-values (net* h) (atms-new-hypothesis net))
      (cons h alt)))

  ;; Elaborate each alternative under its hypothesis
  (for ([h+alt hypotheses])
    (define h (car h+alt))
    (define alt (cdr h+alt))
    (atms-believe net h)
    (elaborate-under-hypothesis net h alt)
    (atms-unbelieve net h))

  ;; Find consistent worldview (hypothesis without nogoods)
  (define winner (atms-first-consistent-worldview net hypotheses))
  (if winner
      (atms-commit net winner)
      (error "all alternatives failed")))
```

### 5.5 Phase 5: Full Switchover + Error Improvement (~150 lines)

**Files**: `elaborator.rkt`, `typing-core.rkt` modifications

1. Remove dual-mode check
2. Make propagator system the primary path
3. Implement dependency-directed error messages using ATMS support sets
4. Remove `save-meta-state`/`restore-meta-state!` (replaced by ATMS)
5. Remove `current-meta-store` parameter (replaced by cells on network)

### 5.6 Phase 6: Performance Optimization (~200 lines)

**Files**: Various optimizations

1. **Lazy propagator creation**: Don't create propagators for trivially-solvable constraints
2. **Ground-type fast path**: If both sides of a unification are ground, skip propagator creation
3. **Batched propagation**: Group related constraints and fire in bulk
4. **Cell reuse**: When a meta is immediately solved, reuse its cell for the solution
5. **Speculative ATMS bypass**: For programs with no speculation, skip ATMS entirely
6. **Shared networks for small definitions**: Batch adjacent small definitions (0-2 metas each) into a shared network to amortize creation overhead; single quiescence pass covers the batch
7. **Scheduler selection**: Profile Gauss-Seidel vs. BSP on real workloads; consider priority-queue scheduling (ground-type propagators first) for improved convergence speed

---

## 6. Comparative Benchmark Programs

### 6.1 Programs That Should Improve

Programs where the propagator system should outperform the ad-hoc system:

```prologos
;; deep-implicit-chain.prologos
;; Tests: Many implicit arguments resolved through chain of trait constraints
;; Why better: Propagator-triggered trait resolution fires automatically
;; as type information flows, avoiding the one-shot post-pass

ns deep-implicit-chain
spec compose-all : {A B C D E : Type}
  :where (Eq A) (Ord B) (Add C) (Mul D) (Num E)
  A -> B -> C -> D -> E -> [Pair A E]
```

```prologos
;; speculative-heavy.prologos
;; Tests: Many programs requiring Church fold detection / union type speculation
;; Why better: ATMS worldviews are O(1) to create/switch vs O(N) state copy
;; Partial work from failed branches informs later branches

ns speculative-heavy
;; Programs with multiple Church-foldable definitions
def nat-fold := (fn [f z] (fn [n] ...))
def bool-fold := (fn [t f] (fn [b] ...))
;; etc.
```

```prologos
;; error-chain.prologos
;; Tests: Programs with type errors in deeply-nested contexts
;; Why better: ATMS support sets provide dependency chain for error messages
;; Current system just reports the final contradiction, not the path

ns error-chain
;; Deliberately ill-typed programs for error message quality comparison
```

### 6.2 Programs That Should Be Neutral

Programs where performance should be similar:

```prologos
;; simple-typed.prologos — No metas, no constraints, purely checking mode
;; prelude-load.prologos — Prelude loading (I/O bound, not inference bound)
;; reduction-heavy.prologos — Programs bottlenecked by reduction, not inference
```

### 6.3 Programs That Might Regress

Programs where the propagator overhead might be noticeable:

```prologos
;; many-small-defs.prologos
;; Programs with hundreds of small definitions
;; Each creates a network, runs to quiescence, extracts results
;; Propagator setup cost might exceed ad-hoc hash table operations

;; trivial-inference.prologos
;; Programs where every meta is immediately solved (no postponement)
;; Ad-hoc system: solve-meta! is O(1) hash-set
;; Propagator system: cell-write + merge + check dependents
```

These regression candidates inform Phase 6 optimizations.

---

## 7. Integration with Future Systems

### 7.1 Theorem Proving

The propagator-based type inference system is a **foundation for theorem proving**:

- **Proof search** = nondeterministic search in the propagator network
- **Tactic execution** = writing to cells (providing evidence)
- **Auto tactic** = running the solver to find inhabitants of a type
- **Hole filling** = reading from cells that have been solved by propagation

The ATMS worldview mechanism directly supports **interactive proof development**: each tactic choice is a hypothesis, and the proof assistant maintains all possible proof states simultaneously.

### 7.2 Editor-Assisted Interactive Development

The propagator network enables **incremental type checking**:

- When a user edits one definition, only the affected cells need re-propagation
- The editor can show **live type information** as it flows through the network
- **Hole types** (`??`) are cells — the editor shows what type is expected by reading the cell
- **Suggested completions** = querying the network for values that would make all cells consistent

### 7.3 Property-Based Testing

The propagator system enables **type-directed test generation**:

1. Given `spec f : Int → String → Bool`, create cells for the input types
2. Use the Gen trait to generate values inhabiting each input type
3. Apply `f` and check the output type
4. The propagator network guides generation toward well-typed inputs

### 7.4 Generative Testing via Relations

With `defr` working end-to-end, we can express type-checking **as a relation**:

```prologos
defr has-type [?expr ?type ?ctx]
  ;; Base cases
  &> (= expr (nat-lit n)) (= type Nat)
  &> (= expr (str-lit s)) (= type String)

  ;; Application
  &> (= expr (app f x))
     (has-type f (pi A B) ctx)
     (has-type x A ctx)
     (= type B)

  ;; Lambda
  &> (= expr (lam x body))
     (has-type body B (extend ctx x A))
     (= type (pi A B))
```

Then `solve (has-type ?expr Int empty-ctx)` **generates** all expressions of type `Int` — this is **type inhabitation** via the relational engine. The benchmarking framework can compare this approach against purpose-built generators.

---

## 8. Risk Analysis

### 8.1 Performance Risk

**Risk**: Propagator overhead exceeds ad-hoc system for common cases.

**Mitigation**: Phase 6 optimizations (lazy creation, ground-type fast path, speculative ATMS bypass). The dual-mode phase (Phase 3) measures actual overhead before switchover.

### 8.2 Correctness Risk

**Risk**: Propagator-based system produces different results than ad-hoc system.

**Mitigation**: Dual-mode validation (Phase 3) runs both systems in parallel and asserts alpha-equivalence. Property-based tests verify soundness properties.

### 8.3 Complexity Risk

**Risk**: Propagator system is harder to debug than ad-hoc system.

**Mitigation**: ATMS support sets provide better debugging information than the ad-hoc system. The persistent network can be serialized and inspected. Heartbeat counters measure propagation cost.

### 8.4 Applied Meta Risk

**Risk**: Applied metas (`?m x y`) are the hardest case — they require a richer lattice than FlatLattice.

**Mitigation**: Applied metas map to **higher-order cells** that hold functions from arguments to types. The substitution lattice from the research documents provides the theoretical framework. Phase 1 starts with FlatLattice (sufficient for most metas) and extends to applied metas in Phase 2.

---

## 9. Implementation Timeline

| Phase | Effort | Dependencies |
|-------|--------|-------------|
| 5.0: Benchmark baseline | Small | Benchmarking framework Phase A-B |
| 5.1: Type lattice module | Small | None |
| 5.2: Elaborator-network bridge | Medium | Phase 5.1 |
| 5.3: Dual-mode elaborator | Medium-Large | Phase 5.2 |
| 5.4: ATMS speculation | Medium | Phase 5.3, ATMS (Phase 5 of logic engine) |
| 5.5: Full switchover | Medium | Phase 5.4, all benchmarks green |
| 5.6: Performance optimization | Medium | Phase 5.5, benchmark data |

**Total estimated effort**: ~1000 new/changed lines across 6 phases

---

## 10. Success Criteria

1. **Correctness**: All 4202+ tests pass with propagator-based type inference
2. **Performance**: No more than 10% regression on the full test suite
3. **Error quality**: Error messages include dependency chains (at least for unification failures)
4. **Speculation efficiency**: Speculative type-checking (Church folds, union types) is at least 2x faster on programs with many speculative branches
5. **Incremental potential**: The persistent network enables O(1) backtrack to pre-definition state (keep old reference), demonstrating the architectural foundation for future incremental re-checking (transitive dependency tracking across definitions is a separate, future design)
6. **Multi-error reporting**: A single elaboration pass collects multiple independent type errors (§3.6), rather than aborting on the first
7. **Benchmark visibility**: A/B comparison data visible in the static HTML dashboard

---

## 11. References

### Primary
- "Towards a General Logic Engine on Propagators" — `docs/tracking/2026-02-24_TOWARDS_A_GENERAL_LOGIC_ENGINE_ON_PROPAGATORS.org`
- "Logic Engine Design" — `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`
- "Relational Language Vision" — `docs/tracking/principles/RELATIONAL_LANGUAGE_VISION.org`

### External
- Radul & Sussman, "The Art of the Propagator" (MIT TR, 2009)
- de Kleer, "An Assumption-Based TMS" (AI Journal, 1986)
- Ed Kmett, Guanxi — propagator-based unification (Haskell)
- Andras Kovacs, "Elaboration Zoo" — modern elaboration techniques
- Dunfield & Krishnaswami, "Bidirectional Typechecking" (ICFP 2014)
- GHC's OutsideIn(X) constraint solver
- Lean4's heartbeat system and elaborator profiling
- Will Byrd et al., miniKanren-based type inference
