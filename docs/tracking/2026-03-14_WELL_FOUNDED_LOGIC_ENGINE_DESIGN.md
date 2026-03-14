# Well-Founded Logic Engine: μ/ν Mixed-Fixpoint Propagator Backend

**Created**: 2026-03-14
**Status**: Stage 2 (Research Refinement and Gap Analysis)
**Depends on**: Propagator network (propagator.rkt), ATMS (atms.rkt), stratified-eval.rkt
**Enables**: Coinductive session types, runtime monitoring, model checking, shield synthesis
**Research basis**: `PROPAGATORS_AS_MODEL_CHECKERS.org`, `FORMAL_MODELING_ON_PROPAGATORS.org`, `LAYERED_RECOVERY_CATEGORICAL_ANALYSIS.org`
**Master roadmap link**: Research Program items 1-2, 5 in `FORMAL_MODELING_ON_PROPAGATORS.org` §9

---

## 1. Context and Problem Statement

### 1.1 What Exists Today

Prologos's Logic Engine is a three-layer persistent architecture:

1. **Layer 1 (propagator.rkt)**: Persistent propagator network with ascending cells (lfp only), Gauss-Seidel and BSP/Jacobi schedulers, widening/narrowing support, cross-domain Galois connections
2. **Layer 2 (atms.rkt)**: Persistent ATMS with assumptions, nogoods, TMS cells, worldview exploration
3. **Layer 3 (stratify.rkt + stratified-eval.rkt)**: Compile-time stratification check (Tarjan SCC + negative-edge detection), bottom-up stratum evaluation

**Current limitation**: All propagator cells are ascending (start at ⊥, refine upward via join). The engine computes **only least fixpoints**. This is adequate for:
- Positive logic programs (Herbrand model = lfp of T_P)
- Type inference (principal type = lfp of unification constraints)
- Stratified negation (sound NAF via stratum ordering)

But it **cannot express**:
- Well-founded semantics (three-valued: true/false/unknown — requires bilattice pairs)
- Coinductive reasoning (greatest fixpoint: streams, infinite processes, server loops)
- Mixed safety/liveness properties (ν for "always holds," μ for "eventually holds")
- Level 2+ alternation hierarchy properties (response: "every request eventually gets a reply")

### 1.2 What This Design Proposes

A **separate backend** — the Well-Founded Logic Engine (WFLE) — that extends the propagator network with:

1. **Descending cells** (ν-cells): start at ⊤, refine downward via meet, computing greatest fixpoints
2. **Bilattice cell pairs**: (lower, upper) ∈ L² where lower ascends and upper descends, computing well-founded fixpoints via AFT
3. **Stratified μ/ν scheduling**: respect alternation structure when mixed-polarity cells coexist
4. **Same interface as the current engine**: programs run on both backends for comparison

The WFLE operates as an alternate solver backend, selectable per-query. Existing programs continue to use the current engine; programs with negation cycles, coinductive definitions, or mixed-fixpoint requirements route to the WFLE.

### 1.3 Why This Matters

**Immediate**: Programs with odd negation cycles (currently rejected at compile time) get a meaningful answer — the well-founded semantics assigns true/false/unknown rather than failing.

**Near-term**: Coinductive session types (`νX. !Int.?Bool.X` — infinite server loops) can be type-checked. The current engine cannot represent "assume the type holds and check consistency" (gfp reasoning).

**Design pattern**: The WFLE establishes the pattern for descending/bilattice cells that all future propagator applications need — runtime monitors, model checking, shield synthesis, abstract interpretation refinement.

**Measurement**: Running identical programs on both backends reveals the cost and benefit of well-founded semantics vs. stratified NAF, informing which engine to use by default.


## 2. Infrastructure Gap Analysis

| Component | Status | What Exists | What's Needed |
|-----------|--------|-------------|---------------|
| Ascending cells (μ) | COMPLETE | `net-new-cell` in propagator.rkt | — |
| Cell merge (join) | COMPLETE | Per-cell merge-fn via `net-cell-write` | — |
| Descending cells (ν) | MISSING | — | `net-new-cell-desc` with meet-fn, starts at ⊤ |
| Cell direction flag | MISSING | — | `:ascending` / `:descending` tag on cells |
| Bilattice pairs (L²) | MISSING | — | Paired cells with cross-propagators |
| Meet functions | PARTIAL | Session lattice has `session-lattice-meet` | Need meet-fn registry parallel to merge-fns |
| Contradiction for ν-cells | MISSING | Contradiction = reaching ⊤ (ascending) | Contradiction = reaching ⊥ (descending) |
| Widening (ascending) | COMPLETE | `net-cell-write-widen`, `run-to-quiescence-widen` | — |
| Narrowing (descending) | PARTIAL | Narrowing phase in `run-to-quiescence-widen` | Needs adaptation for ν-cell context |
| BSP scheduler | COMPLETE | `run-to-quiescence-bsp` | Needs mixed-direction awareness |
| Stratification | COMPLETE | `stratify.rkt` — Tarjan SCC | Needs well-founded iteration alternative |
| Well-founded operator | MISSING | — | S_A(x,y) = (lfp(A_l(·,y)), gfp(A_u(x,·))) |
| ATMS integration | COMPLETE | `atms.rkt` — assumptions, nogoods, TMS | Needs bilattice-aware TMS reads |
| Three-valued output | MISSING | — | `'true` / `'false` / `'unknown` from bilattice gap |
| Solver interface | COMPLETE | `stratified-solve-goal` | Need `well-founded-solve-goal` parallel |
| Tabling (memoization) | COMPLETE | `tabling.rkt` — SLG-style | Needs three-valued table entries |
| Trace/observation | COMPLETE | BSP observer, `prop-trace` | Needs direction-aware diff reporting |
| Cross-domain propagators | COMPLETE | `net-add-cross-domain-propagator` | — |
| Threshold propagators | COMPLETE | `net-add-threshold` | — |


## 3. Design Space: Alternative Approaches

### 3.1 Approach A: Bilattice Cell Pairs (AFT-native)

**Mechanism**: Every logic variable gets two cells — `lower` (ascending, μ) and `upper` (descending, ν). Propagators update both. The gap `[lower, upper]` narrows over iteration. At quiescence:
- `lower = upper` → exact answer (true or false)
- `lower < upper` → unknown (genuinely undetermined)
- `lower > upper` → contradiction

**How it works**:
1. For each predicate `p`, create `lower-p` (starts at ⊥ = false) and `upper-p` (starts at ⊤ = true)
2. Positive evidence raises the lower bound: if a clause proves `p`, set `lower-p := true`
3. Negative evidence (NAF) lowers the upper bound: if no clause can prove `p`, set `upper-p := false`
4. Cross-propagators enforce consistency: `lower ≤ upper`
5. Iterate to quiescence via standard `run-to-quiescence`

**Pros**:
- Directly implements AFT's well-founded fixpoint — mathematically clean
- Handles arbitrary negation cycles without stratification
- Three-valued output is inherent (no post-processing)
- Composes with existing propagator infrastructure (cells + propagators)
- Generalizes to richer lattices (not just Boolean)

**Cons**:
- 2× cell count (every variable gets a pair)
- Cross-propagators between lower/upper add scheduling overhead
- Need to implement the stable operator S_A for full stable-model semantics

### 3.2 Approach B: Polarity-Tagged Cells with Alternating Scheduler

**Mechanism**: Each cell is tagged `:ascending` or `:descending`. The scheduler respects a priority ordering: fully converge one stratum of same-polarity cells before advancing.

**How it works**:
1. Compile the dependency graph with polarity information (positive → same direction, negative → flip)
2. Assign priority levels (alternation depth)
3. Scheduler iterates: at each priority level, run all cells of that level to quiescence
4. Lower-priority fixpoints may reset when higher-priority cells change

**Pros**:
- Natural mapping to parity games and μ-calculus alternation
- No cell-count doubling — each variable has one cell
- Direct support for Level 2+ alternation hierarchy
- Scheduler is a clean generalization of stratified evaluation

**Cons**:
- More complex scheduler (priority-aware, reset logic)
- Single cell per variable means no "unknown" gap — must use a three-valued lattice explicitly
- Less natural fit for well-founded semantics (AFT is bilattice-native)
- Priority assignment requires dependency analysis at compile time

### 3.3 Approach C: Hybrid — Bilattice Core with Alternating Scheduler

**Mechanism**: Use bilattice pairs (Approach A) as the cell representation, but schedule them with alternation awareness (Approach B). The bilattice gives three-valued output; the alternating scheduler handles nested fixpoints.

**How it works**:
1. Each variable gets a bilattice pair `(lower, upper)`
2. Compile the alternation structure (which fixpoints are nested inside which)
3. Schedule inner fixpoints to full convergence before outer fixpoints advance
4. The well-founded fixpoint emerges from the bilattice; nested μ/ν from the scheduler

**Pros**:
- Gets both: well-founded semantics (bilattice) AND nested alternation (scheduler)
- Subsumes Approaches A and B
- Clean separation: bilattice handles truth values, scheduler handles nesting
- Future-proof for Level 3+ alternation

**Cons**:
- Most complex to implement
- May be over-engineered for the immediate use case (well-founded semantics alone)
- Harder to reason about correctness

### 3.4 Recommendation: Approach A (Bilattice Pairs) first, evolve to C

**Rationale**:
- The primary goal is well-founded semantics for logic programming with negation — Approach A nails this directly
- Bilattice pairs are the foundation that Approach C builds on — starting with A is not throwaway work
- Stratified evaluation already handles the scheduling concern for stratum-ordered programs
- Level 2+ alternation is a future need, not an immediate one
- Approach A is testable against the existing stratified engine on the same programs
- Evolution path: A → C when temporal property specifications or coinductive types need nested alternation

This follows the "Completeness Over Deferral" principle — implement what we have clarity on now (bilattice pairs for well-founded semantics), defer what requires more design (alternating scheduler for nested fixpoints).


## 4. Core Design: Bilattice Cell Pairs

### 4.1 Data Structures

**Bilattice cell**: A pair of existing propagator cells with coordinating propagators.

```
;; A bilattice variable: (lower bound, upper bound) ∈ L²
;; lower ascends via join; upper descends via meet
;; Invariant: lower ≤ upper (enforced by consistency propagator)
(struct bilattice-var
  (lower-cid    ;; cell-id — ascending cell (starts at ⊥)
   upper-cid    ;; cell-id — descending cell (starts at ⊤)
   lattice))    ;; lattice descriptor (provides bot, top, join, meet, ≤)
```

**Descending cell support**: Extend `prop-network` with a `meet-fns` registry parallel to `merge-fns`.

```
;; In prop-network struct, add:
;;   meet-fns: champ-root : cell-id → (val val → val)
;;   cell-dirs: champ-root : cell-id → 'ascending | 'descending
```

**Three-valued result**: Extract from bilattice gap at quiescence.

```
;; (bilattice-read net bvar) → 'true | 'false | 'unknown | 'contradiction
(define (bilattice-read net bvar)
  (let ([lo (net-cell-read net (bilattice-var-lower-cid bvar))]
        [hi (net-cell-read net (bilattice-var-upper-cid bvar))])
    (cond
      [(and (eq? lo #t) (eq? hi #t)) 'true]
      [(and (eq? lo #f) (eq? hi #f)) 'false]  ;; only if ⊥ = #f
      [(lattice-leq lo hi) 'unknown]           ;; gap remains
      [else 'contradiction])))                 ;; lower > upper
```

### 4.2 The Boolean Bilattice for Logic Programming

For the well-founded semantics of logic programs with NAF, the base lattice is Boolean: `L = {false, true}` with `false < true`.

The bilattice `L²` has four elements:

```
        (true, true)     = definitely true
       /              \
(false, true)    (true, false)
  = unknown         = contradiction
       \              /
        (false, false)   = definitely false
```

In the precision ordering `≤_p`:
- ⊥_p = `(false, true)` (unknown — widest approximation)
- ⊤_p = `(true, false)` (contradiction — impossible)

Each ground atom starts at `(false, true)` = unknown.

### 4.3 Propagator Patterns for Well-Founded Semantics

**Positive rule propagator**: For a clause `p :- q₁, q₂, ..., qₙ` (no negation):

```
;; Lower bound: if all qᵢ are certainly true, p is certainly true
;;   lower-p := lower-p ∨ (lower-q₁ ∧ lower-q₂ ∧ ... ∧ lower-qₙ)
;;
;; Upper bound: if any qᵢ is certainly false, this clause can't prove p
;;   upper-p := upper-p ∧ (upper-q₁ ∨ upper-q₂ ∨ ... ∨ upper-qₙ)
;;   (but: must consider ALL clauses for p, not just this one)
```

**Negative literal propagator**: For a goal `not q` in a clause body:

```
;; Lower bound contribution: not-q is certainly true iff q is certainly false
;;   lower-not-q = ¬upper-q    (flip the upper bound of q)
;;
;; Upper bound contribution: not-q is certainly false iff q is certainly true
;;   upper-not-q = ¬lower-q    (flip the lower bound of q)
```

This is the key insight: negation in bilattice land is **not non-monotone**. `¬upper-q` is monotone in the precision ordering because `upper-q` descends — as `upper-q` decreases, `¬upper-q` increases. The bilattice construction turns non-monotone negation into monotone cross-cell propagation.

**Unfounded set detection**: The well-founded semantics includes an unfounded-set computation that identifies atoms that *cannot be supported by any derivation*. In propagator terms:

```
;; For each atom p, if no clause for p has all body literals
;; with upper bound = true, then p is unfounded:
;;   upper-p := false
```

This is the descending cell doing its job: atoms whose support collapses have their upper bound driven down.

### 4.4 The Well-Founded Iteration

The well-founded fixpoint computation proceeds as follows:

1. **Initialize**: For each ground atom `p`, create `bilattice-var` with `lower-p = false`, `upper-p = true`
2. **Wire propagators**: For each clause, create lower-bound and upper-bound propagators as described in §4.3
3. **Run to quiescence**: Standard `run-to-quiescence` — all propagators fire until no cell changes
4. **Read results**: For each atom, read the bilattice pair:
   - `(true, true)` → definitely true
   - `(false, false)` → definitely false
   - `(false, true)` → unknown (genuinely undetermined)

Because all propagators are monotone in the precision ordering (lower bounds only increase, upper bounds only decrease), Knaster-Tarski guarantees convergence to the well-founded fixpoint.

### 4.5 Architecture: Parallel Backend

```
                    ┌──────────────────────────┐
                    │     User Program          │
                    │  (relations + queries)    │
                    └──────────┬───────────────┘
                               │
                    ┌──────────▼───────────────┐
                    │   Solver Dispatch         │
                    │  (solver-mode parameter)  │
                    └──────┬──────────┬────────┘
                           │          │
              ┌────────────▼──┐  ┌────▼────────────┐
              │  Stratified   │  │  Well-Founded    │
              │  Engine       │  │  Engine (WFLE)   │
              │               │  │                  │
              │ stratify.rkt  │  │  wf-engine.rkt   │
              │ strat-eval.rkt│  │  bilattice.rkt   │
              │               │  │                  │
              │ 2-valued      │  │  3-valued        │
              │ (true/false)  │  │  (true/false/unk) │
              │ Rejects cycles│  │  Handles cycles  │
              └───────┬───────┘  └────────┬────────┘
                      │                   │
                      └─────────┬─────────┘
                                │
                    ┌───────────▼──────────────┐
                    │  Propagator Network      │
                    │  (propagator.rkt)         │
                    │  + ATMS (atms.rkt)        │
                    └──────────────────────────┘
```

Both engines share the same underlying propagator network. The WFLE creates bilattice pairs and wires different propagators; the stratified engine creates single cells with stratification barriers. The solver dispatch reads a `(current-solver-mode)` parameter: `'stratified` (default) or `'well-founded`.

### 4.6 Module Organization

| File | Purpose | New/Modified |
|------|---------|--------------|
| `bilattice.rkt` | Bilattice-var struct, construction, reading, Boolean bilattice | NEW |
| `wf-propagators.rkt` | Well-founded propagator patterns (positive, negative, unfounded) | NEW |
| `wf-engine.rkt` | Well-founded solver orchestration (parallel to stratified-eval.rkt) | NEW |
| `propagator.rkt` | Add descending cell support (meet-fns, cell-dirs, net-new-cell-desc) | MODIFIED |
| `solver.rkt` | Add `current-solver-mode` parameter, dispatch logic | MODIFIED |
| `tabling.rkt` | Three-valued table entries for well-founded memoization | MODIFIED |


## 5. Principle Alignment Check

| Principle | Assessment |
|-----------|------------|
| **Correctness Through Types** | ✅ Well-founded semantics is strictly more informative than stratified NAF — it gives answers where stratification rejects programs |
| **Simplicity of Foundation** | ✅ Bilattice pairs are a clean extension of the existing cell model, not a new mechanism. The same `run-to-quiescence` computes the fixpoint |
| **Progressive Disclosure** | ✅ Users who don't use negation cycles see no difference. Users who do get `'unknown` instead of a compile error. The three-valued output is opt-in |
| **Pragmatism with Rigor** | ✅ AFT is deep theory; the user sees `'true` / `'false` / `'unknown` |
| **Decomplection** | ✅ The WFLE is a separate backend, not entangled with the stratified engine. Both share the propagator substrate. The bilattice concern (three-valued reasoning) is orthogonal to the scheduling concern (stratum ordering) |
| **Most Generalizable Interface** | ✅ Bilattice cell pairs generalize beyond logic programming — they're the pattern for any lfp/gfp dual computation (session types, monitoring, etc.) |
| **Homoiconicity** | ✅ No new syntax required at the language level. The backend is a solver implementation detail |


## 6. Risks and Mitigations

### Risk 1: Performance regression from 2× cell count
**Likelihood**: Medium
**Impact**: Medium — logic programs would create twice as many cells
**Mitigation**: Only create bilattice pairs when the program uses negation (or when `solver-mode = 'well-founded`). Programs without negation use single ascending cells via the stratified engine. Benchmark the overhead: if it's under 20%, acceptable; if over 50%, consider lazy upper-bound cell creation (create ν-cell only when a negative literal first references the atom).

### Risk 2: Unfounded set computation is expensive
**Likelihood**: Medium
**Impact**: High — the well-founded fixpoint requires detecting which atoms have no remaining support, which can be O(program-size) per iteration
**Mitigation**: Use the propagator network itself to track support. An atom's upper bound is driven by the conjunction of its clauses' feasibility — this is already what the upper-bound propagators compute. If propagation is insufficient (some unfounded atoms require set-based reasoning), implement the alternating fixpoint characterization (Van Gelder 1993) as a post-quiescence pass.

### Risk 3: Correctness of descending cells in existing scheduler
**Likelihood**: Low-Medium
**Impact**: High — descending cells are a new direction; bugs could produce wrong fixpoints
**Mitigation**: Extensive testing. The key invariant is that `net-cell-write` for descending cells uses meet (not join) and checks `merged = old` for convergence. Write tests that compute known well-founded models (from the logic programming literature) and compare against published results. Start with the standard examples: `p :- not q. q :- not p.` → both unknown.

### Risk 4: ATMS interaction with bilattice cells
**Likelihood**: Low
**Impact**: Medium — ATMS TMS cells have their own multi-valued reading semantics
**Mitigation**: ATMS and bilattice address orthogonal concerns (see §11.1). The ATMS handles branching (choice points, `amb`); the bilattice handles incomplete information (NAF, well-founded unknown). Within a single ATMS worldview, run the well-founded fixpoint on bilattice cells. The WFLE uses standard propagator cells (not TMS cells) for bilattice pairs — the ATMS wraps the network as today, providing worldview-scoped reads.

### Risk 5: Tabling with three-valued entries
**Likelihood**: Low
**Impact**: Medium — the current tabling system stores two-valued answers
**Mitigation**: Extend table entries to store `(value . certainty)` where certainty ∈ {`'definite`, `'unknown`}. A `'definite` entry is final (as today); an `'unknown` entry may be refined on subsequent iterations. This is a straightforward extension of the existing tabling API.


## 7. Comparison with Existing Engine

| Aspect | Stratified Engine | Well-Founded Engine (WFLE) |
|--------|-------------------|---------------------------|
| **Negation cycles** | Rejected at compile time | Handled — atoms get `'unknown` |
| **Output values** | 2-valued: true/false | 3-valued: true/false/unknown |
| **Cell count** | 1 per atom | 2 per atom (bilattice pair) |
| **Stratification check** | Required (Tarjan SCC) | Not required |
| **Computation** | Bottom-up per stratum | Single fixpoint over L² |
| **Monotonicity** | Within strata only | Global (precision ordering) |
| **Complexity** | O(|program| × |strata|) | O(|program|²) worst case |
| **Answer correctness** | Sound and complete for stratifiable programs | Sound and complete for all normal programs |
| **Stable models** | Not computed | Obtainable via stable operator (future) |

**When to use which**:
- **Stratified**: Default for programs without negation cycles. Lower overhead, same answers.
- **Well-founded**: Programs with odd negation cycles, or when `'unknown` is a meaningful answer (e.g., "we can't determine if this property holds — generate a runtime check").


## 8. Connection to Future Systems

The bilattice pair pattern established by the WFLE is the **design pattern** for:

### 8.1 Coinductive Session Types
A session type `νX. !Int.?Bool.X` has type variable X that should be solved by **greatest fixpoint** — "assume the protocol repeats forever, check consistency." The upper cell starts at ⊤ (all session types) and descends to the specific recursive protocol. This is a single ν-cell, not a bilattice pair, but the descending cell infrastructure from the WFLE is the prerequisite.

### 8.2 Runtime Monitoring
An `always φ` monitor is a ν-cell that starts at `true` (property holds) and descends to `false` on violation. An `eventually φ` monitor is a μ-cell that starts at `false` and ascends to `true` when witnessed. Mixed monitors (response: `always(φ → eventually ψ)`) need both — the bilattice pattern.

### 8.3 Model Checking
CTL model checking on propagator networks requires both ascending cells (`EF φ` = μ) and descending cells (`AG φ` = ν). The WFLE's descending cell support completes the infrastructure needed for §7.3.1 of `FORMAL_MODELING_ON_PROPAGATORS.org`.

### 8.4 Abstract Interpretation Refinement
Widening (ascending → post-fixpoint) then narrowing (descending → refined fixpoint) is already supported, but framing it as a bilattice computation clarifies the theory: the widened value is the upper bound, the narrowed value is the lower bound, and the gap represents imprecision.


## 9. Effort Estimate

| Phase | Scope | Est. Effort | Risk |
|-------|-------|-------------|------|
| Phase 1: Descending cells in propagator.rkt | meet-fns, cell-dirs, net-new-cell-desc, net-cell-write-desc | Small | Low |
| Phase 2: bilattice.rkt | bilattice-var struct, construction, reading, Boolean bilattice | Small | Low |
| Phase 3: wf-propagators.rkt | Positive/negative/unfounded propagator patterns | Medium | Medium |
| Phase 4: wf-engine.rkt | Solver orchestration, dispatch, three-valued output | Medium | Medium |
| Phase 5: Tabling extension | Three-valued table entries | Small | Low |
| Phase 6: Test suite | Known well-founded models, comparison with stratified engine | Medium | Low |
| Phase 7: Benchmark comparison | Same programs on both engines, measure time/correctness | Small | Low |

**Total**: Medium effort. The propagator infrastructure does most of the heavy lifting — the WFLE is primarily new propagator *patterns* and *wiring*, not new infrastructure.


## 10. Open Questions (Resolved)

### Q1: Grounding — How do bilattice pairs interact with unification?

**Resolution: Tabled evaluation with three-valued table entries (Approach C).**

The well-founded semantics is defined for ground atoms, but Prologos uses unification variables. Three approaches were considered:

- **(a) Ground-instantiate**: Enumerate the Herbrand base before WF computation. Standard in ASP/Datalog but incompatible with Prologos's open-ended unification — the Herbrand base may be infinite or impractically large.
- **(b) Lift bilattice to first-order**: Research territory. Requires constructive negation (complement computation over constrained substitutions). Theoretically elegant but significantly harder to implement.
- **(c) Tabled evaluation with partial answers**: SLG-resolution style (as in XSB Prolog). Each tabled predicate accumulates answers incrementally. Negation checks the table: if complete (all derivations explored), use closed-world assumption; if incomplete, delay the negative literal and revisit when the table grows.

Approach (c) fits most naturally because Prologos already has tabling infrastructure (`tabling.rkt`). The bilattice pairs store tabled answer sets: lower bound = answers proven so far, upper bound = answers not yet ruled out. Three-valued table entries (Phase 5 in §9) implement this directly. Table completion detection triggers the transition from `'unknown` to definite.

### Q2: Stable models — Should the WFLE compute them?

**Resolution: Deferred, but the composition path is clear.**

The well-founded fixpoint is always unique and polynomial-time. Stable models (answer sets) can be multiple and NP-hard to enumerate. Both are AFT fixpoints:
- Well-founded = ≤_p-least fixpoint of S_A (unique, cautious)
- Stable = exact fixpoints of S_A (possibly multiple, credulous)

The WFLE targets the well-founded fixpoint initially. Stable model enumeration follows naturally by composing ATMS with bilattice: after computing the well-founded fixpoint, for each `'unknown` atom, use `atms-amb` to create choice points (assume true vs. false). Each consistent combination that produces an exact fixpoint (no remaining unknowns) is a stable model. This is the Option 3 composition (§11.1) — ATMS handles the branching over unknowns, bilattice handles the negation semantics.

### Q3: Interaction with type checker — Should types ever be `'unknown`?

**Resolution: Not directly, but `'unknown` maps to "emit runtime check."**

The type checker should continue producing types or errors. It should not produce `'unknown` as a type. But when a dependent type's predicate involves logic programming with negation cycles (e.g., a type-level guard calling a relation with well-founded undeterminacy), the type checker delegates to the WFLE and interprets the three-valued result:

- `'true` → type checks (static guarantee)
- `'false` → type error (static rejection)
- `'unknown` → insert a **runtime guard** (the theory doesn't determine this statically)

This gives `'unknown` a natural operational semantics at the type level: it's the **boundary between static and dynamic verification**. The type system admits the program but instruments it with a runtime check. This connects directly to the runtime monitoring story in `FORMAL_MODELING_ON_PROPAGATORS.org` §7.3.4 — temporal properties that can't be verified statically compile to runtime monitors using the same propagator infrastructure.

### Q4: Performance threshold — What overhead is acceptable?

**Resolution: Empirical benchmark plan.**

Hypothesis: for stratifiable programs (the common case), the stratified engine should be ~1.5-2× faster (no bilattice cell overhead). For programs with negation cycles, the WFLE gives answers where the stratified engine gives compile errors (qualitative improvement, not quantitative).

Benchmark plan:
1. Run the existing logic-programming test suite on both engines
2. Compare wall time for stratifiable programs (expect stratified to win)
3. Compare answers for programs with negation cycles (expect WFLE to produce results where stratified rejects)
4. Measure cell count and propagator firing count for overhead characterization
5. Establish a threshold: if WFLE overhead on stratifiable programs exceeds 3×, investigate optimization (lazy upper-bound cell creation, elide bilattice pairs for atoms with no negative dependencies)

### Q5: WS-mode syntax — Any changes needed?

**Resolution: No syntax changes. Backend-only.**

The WS-mode reader already parses `not` as a goal modifier. The solver backend switch is transparent to the surface language. The only user-visible difference is output: where the stratified engine rejects a program with cyclic negation, the WFLE returns `'unknown` for undetermined atoms.

One potential future surface addition (not part of this design): a `certain?` query form that exposes the three-valued result — `[certain? [ancestor avanti bob]]` returning `'true`/`'false`/`'unknown`. This is syntactic sugar over the existing query mechanism, not new infrastructure.


## 11. Resolved Design Decisions

### 11.1 Choice Points: ATMS and Bilattice Compose Orthogonally (Option 3)

**Decision**: The ATMS handles **branching** (choice points, `amb`, disjunctive alternatives). The bilattice handles **incomplete information** (NAF, well-founded undeterminacy). They compose orthogonally — within a single ATMS worldview, the well-founded fixpoint runs on bilattice cells.

**Three options were considered**:

**Option 1 — ATMS on top (layered)**: Run a separate well-founded fixpoint per worldview. Clean but potentially expensive (full re-computation per worldview).

**Option 2 — ATMS-aware bilattice (integrated)**: Bilattice cells hold supported lower/upper bounds tagged with assumption sets, producing worldview-dependent bilattice gaps. Efficient (one fixpoint, multiple readings) but conflates two different kinds of uncertainty.

**Option 3 — Orthogonal composition (chosen)**: ATMS manages worldview alternatives; bilattice manages negation-as-failure. Within each worldview, the bilattice converges independently. The ATMS's `atms-solve-all` enumerates worldviews; for each, the bilattice produces three-valued results.

**Rationale**: The two concerns are semantically distinct:
- "Which branch to take?" → ATMS (alternatives are *choices*, mutually exclusive)
- "Can the theory determine this?" → bilattice (unknown is *epistemic*, not a choice)

Conflating them (Option 2) loses this distinction. A `'unknown` result should mean "the theory genuinely doesn't determine this," not "we haven't explored all branches yet."

**Implementation**: The existing `infra-state` wraps `atms` which wraps `prop-network`. The WFLE creates bilattice pairs as standard propagator cells within the network. The ATMS manages assumptions and worldviews as today. The solver dispatch (`wf-engine.rkt`) runs `run-to-quiescence` on the bilattice-augmented network, then reads results under the current worldview. No structural changes to `atms.rkt`.

**Composition for stable models (future)**: When the well-founded fixpoint produces `'unknown` atoms, `atms-amb` can create choice points over those atoms to enumerate stable models. This is the clean decomposition: bilattice identifies *what's undetermined*, ATMS searches *how to resolve it*.

### 11.2 Execution Model: Simultaneous Convergence

**Decision**: Both μ-cells (lower bounds, ascending) and ν-cells (upper bounds, descending) fire in the **same `run-to-quiescence` pass**. There is no turn-taking, no priority scheduling, no stratum barriers.

**Rationale**: All propagators are monotone in the precision ordering ≤_p on L² (lower bounds only rise, upper bounds only fall). The entire bilattice network is a single monotone operator on L², and Knaster-Tarski guarantees convergence regardless of firing order. The BSP scheduler's confluence property (CALM theorem) extends to mixed-direction cells because the precision ordering makes the product lattice well-defined.

**Tradeoff**: This trades **space** (2× cells) for **scheduling simplicity** (no reset logic, no re-convergence, single pass). For the well-founded semantics (alternation depth 1), this is optimal — no nested fixpoints need resetting. For Level 2+ alternation (future: Approach C evolution), the simultaneous approach would need to be augmented with priority-aware scheduling.

**When to evolve to Approach C**: When the system needs to compute properties like `νX. μY. φ(X,Y)` — nested alternating fixpoints where the inner μ must fully reconverge each time the outer ν takes a step. This arises in response properties (`AG(p → AF q)`), coinductive types with nested inductive substructure, and full μ-calculus model checking. The bilattice infrastructure from Approach A carries over; only the scheduler needs augmentation.
