# PTF Track 1: Module-Theoretic Foundations — Research-Driven Track Design

**Date**: 2026-03-28
**Series**: PTF (Propagator Theory Foundations)
**Type**: Research-driven interleaved design — phases alternate between investigation and implementation. Each phase's findings shape subsequent phases.
**Research note**: `docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`
**Cross-references**: SRE Master, PPN Master, BSP-LE Master, PAR Master, PRN Master

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Submodule validation experiment | ✅ | PREMATURE. 20 cells, 0 propagators. Constraint solving is imperative. Revisit after PPN/SRE migration. |
| 1 | Residuation computability check | ✅ | PARTIAL. Works for first-order pattern match. Equal cost for recursive. Cheaper for non-matching rejection. |
| 2 | Decision gate: interpret findings | ✅ | Phase 3 proceeds. Phase 4 deferred (modest ROI until larger ADTs). Phase 5 deferred (Phase 0). |
| 3 | SRE algebraic-kind → SRE Track 3 design recommendation | ✅ | Audit revealed this is a track-sized effort, not a phase. Design recommendation captured. SRE Track 3 created. |
| 4 | Residuation prototype | ⏸️ | DEFERRED. Modest ROI for current programs. Revisit when larger ADTs or automatic backward propagators needed. |
| 5 | Submodule architecture review | ⏸️ | DEFERRED. Network lacks propagator density. Revisit after PPN/SRE migration. |
| 6 | Synthesis: update PTF Master + PRN + design principles | ⬜ | Capture confirmed/refuted conjectures |
| 7 | PIR | ⬜ | |

**Phase completion protocol**: commit → tracker → dailies → proceed.

---

## Design Philosophy

This is not a traditional "design everything, implement everything" track. It's a **research-driven track** where empirical findings shape the implementation scope.

The module theory research note (§13) identifies 5 open questions. This track answers the most impactful ones empirically and implements what the answers reveal. Phases that depend on uncertain findings have conditional scope — they may expand, shrink, or be skipped based on what we learn.

The track follows the Completeness principle: do the hard theoretical work first, so everything built on top is simpler. But it also follows the pragmatic principle: answer questions with code and data, not with extended theoretical speculation.

---

## Phase 0: Submodule Validation Experiment

**Goal**: Determine whether our subsystem boundaries match the canonical module decomposition.

**Method**:
1. Instrument a representative program's elaboration (e.g., `benchmarks/comparative/dependent-types.prologos`)
2. After quiescence, dump the cell → propagator bipartite graph (which cells does each propagator read/write)
3. Compute connected components of this graph
4. Compare connected components to our ~10 named subsystems

**What we learn**:
- If components match subsystems: architecture is canonically justified by Krull-Schmidt. Proceed with confidence.
- If components are FEWER than subsystems: some subsystems we treat as separate are actually entangled (share cells). They should be considered together for scheduling and design.
- If components are MORE than subsystems: some subsystems we treat as monolithic are actually decomposable. Opportunity for finer-grained parallelism.
- The component structure also reveals the **parallel partition** — which groups of propagators can fire independently.

**Deliverable**: A report mapping components to subsystems, with the cell-propagator graph data.

**Implementation notes**:
- `prop-network` already has `propagators` (CHAMP of pid → propagator) and `cells` (CHAMP of cid → cell-value)
- Each `propagator` struct has `inputs` (list of cids) and `outputs` (list of cids)
- Connected components via union-find on cids: for each propagator, union all its input and output cids
- Group propagators by which component their outputs land in

### Phase 0 Findings (commit `f9ea509`)

**The experiment was premature.** The per-command elab-network has cells (20 for a polymorphic program) but **zero propagators**. Constraint solving is entirely imperative — `solve-meta!` and the resolution loop in `metavar-store.rkt` do the work, not propagator firing.

Infrastructure built:
- `current-network-capture-box` parameter in `driver.rkt` — fires after each `process-command`, stores the `elab-network` in a box for external analysis.
- Union-find analysis script validated on synthetic networks (correctly identifies 2 components from 6 cells + 3 propagators).

**Why zero propagators**: The elaboration creates cells for metavariables and infrastructure (global-env, namespace, macros, warnings, narrowing). But the constraint resolution between metavariables is imperative — `solve-meta!` reads the `meta-info` CHAMP and calls `unify`, `resolve-trait-constraints!`, etc. These are not propagators on the network. They're imperative functions called from the resolution loop.

The propagators that DO exist on the network are:
- SRE decomposition sub-propagators (from PAR Track 1) — only for compound types
- Readiness propagators (from constraint-propagators.rkt) — for delayed constraints
- Infrastructure cell watchers (global-env, namespace) — from `register-*-cells!`

For typical programs, these don't fire (no compound subtyping, no delayed constraints). The elaboration is imperative with a thin propagator veneer.

**Implication for PTF Track 1**: The submodule decomposition is meaningful ONLY after SRE/PPN migration puts real subsystems on the network. Phase 5 (architecture review) is deferred.

**Implication for the broader architecture**: This confirms PAR Track 2 R1's finding (18 BSP rounds across 14 programs). The parallel infrastructure is ready. The workload isn't. PPN/SRE migration is the critical path to leveraging both the module-theoretic decomposition AND true parallelism.

---

## Phase 1: Residuation Computability Check

**Goal**: Determine whether our type/term lattices support residuation — and if so, whether the residual computation is cheaper than narrowing's constructor enumeration.

**Method**:
1. Select 3-4 narrowing test cases from `tests/test-narrowing-*.rkt` with known results
2. For each, manually trace the residual computation following the structural formula:
   - For pattern-match functions: follow clauses in reverse
   - For type constructors: decompose componentwise, respecting variance
   - For composed functions: chain residuals (f∘g)\b = g\(f\b)
3. Compare: does the residual give the same answer as narrowing? Is the computation shorter?

**What we learn**:
- If residuals match narrowing results: the propagator algebra IS residuated. Narrowing can be replaced by residual computation (medium-term).
- If residuals diverge: identify where — is it a specific pattern (higher-order? recursive?) that breaks residuation? This tells us the boundary of the residuated fragment.
- If computation is cheaper: quantify the savings. Residuation is O(type depth) vs narrowing's O(constructors × type depth). For wide ADTs (many constructors), the savings are substantial.

**Deliverable**: A table of test cases with narrowing result, residual result, and computation steps for each. Assessment of whether residuation is viable.

**Implementation notes**:
- This phase is MANUAL — pen-and-paper (or comment-block) computation, not code
- The point is to understand the algebraic structure before committing to implementation
- If the manual computation reveals that residuation requires information not available in the current narrowing context (e.g., it needs the full definitional tree, not just the current branch), that shapes Phase 4's scope

---

### Phase 1 Findings (commit `e5d2af6`)

Four narrowing examples traced through both current narrowing and structural residuation:

| Example | Narrowing | Residuation | Same answer? | Cheaper? |
|---------|-----------|-------------|-------------|----------|
| `not(?) = true` | 2 tries, 1 backtrack | 2 clause checks | ✓ | Equal |
| `add(?, ?) = 0` | 2 tries + sub-search | 2 clause checks | ✓ | **Yes** (no reduction) |
| `add(?, ?) = 3` | 4 recursive branches | 4 recursive residuals | ✓ | Equal (recursive) |
| `pred(?) = zero` | 2 tries, 1 fail | 2 clause checks | ✓ | Slightly |

**Confirmed**: Residuation is computable for first-order, constructor-based pattern matching — exactly the definitional tree fragment.

**Where residuation wins**: Non-matching cases. Residuation checks RHS constructor head against target — O(1) rejection. Narrowing evaluates the function first — O(reduction) rejection. For types with many constructors where few match, residuation is significantly cheaper.

**Where residuation equals narrowing**: Recursive cases. Both do the same structural decomposition (peel target, recurse on sub-terms). Same tree of sub-problems.

**Boundary**: Residuation does NOT extend to higher-order functions (inverse beta-reduction is undecidable), guarded/conditional functions (requires inverting arbitrary guards), or non-injective functions (residual is ⊤, not useful for search).

**Architectural implications**:
1. Existing bidirectional propagators (infer/check) ARE computing residuals — the theory validates what we already do.
2. Residuation gives a formal correctness argument: backward direction = unique greatest pre-image under lattice ordering.
3. Automatic backward propagators (derive residual from forward definition) are feasible for the definitional-tree fragment.
4. Implementation deferred — modest ROI for current programs. Becomes valuable with larger ADTs or when building automatic backward propagator infrastructure.

---

## Phase 2: Decision Gate

**Goal**: Interpret findings from Phases 0-1 and determine scope of subsequent phases.

**Decision matrix (revised after Phase 0)**:

Phase 0 result: **premature** — network lacks propagator structure. Phase 5 deferred to post-PPN/SRE migration. The decision now rests on Phase 1 alone:

| Phase 1 finding | Action |
|----------------|--------|
| Residuation works (correct + cheaper) | Phase 3 (algebraic kind) + Phase 4 (residuation prototype) + Phase 6 (synthesis) |
| Residuation partial (works for some cases) | Phase 3 + Phase 4 (scoped to working fragment) + Phase 6. Document boundary. |
| Residuation fails (incorrect or not cheaper) | Phase 3 + Phase 6. Skip Phase 4. Document why. |

**Phase 3 (algebraic-kind) always proceeds** — it's independently valuable regardless of other findings.
**Phase 5 (architecture review) deferred** — revisit when network has propagator density (post-PPN Track 2+).

---

## Phase 3: SRE Algebraic-Kind → Design Recommendation for SRE Track 3

### Phase 3 Findings

The audit of `sre-core.rkt` revealed that the algebraic-kind generalization is a **track-sized effort, not a phase**. The current architecture is "mostly generic" via `sub-relation-fn` closures, but the genericity is accidental — it works without expressing its algebraic structure.

**What the code does (historical accident):**
- 5 relation structs (`sre-equality`, `sre-subtype`, `sre-subtype-reverse`, `sre-duality`, `sre-phantom`), each with a hand-written `sub-relation-fn` closure
- `sre-subtype`'s closure reads `component-variances` from `ctor-desc` and maps: `+ → subtype`, `- → subtype-reverse`, `= → equality`, `ø → phantom`
- `sre-subtype-reverse`'s closure mirrors the above
- `sre-duality`'s closure reads `component-lattices` (NOT variances!) and maps: `type → equality`, `else → duality`
- 6 explicit `(eq? rel-name ...)` checks survive where the generic dispatch breaks down
- The topology handler has a 2-path fork: duality vs everything else

**What the code SHOULD express (algebraic structure):**
- A single **kind-variance table** — the endomorphism ring decomposition as data:

  | Variance | Equality | Subtype | Duality | Rewriting |
  |----------|----------|---------|---------|-----------|
  | covariant | identity | monotone | antitone | idempotent |
  | contravariant | identity | antitone | monotone | idempotent |
  | invariant | identity | identity | identity | idempotent |
  | dual-continuation | identity | — | duality | — |
  | type-component | identity | — | equality | — |
  | phantom | phantom | phantom | phantom | phantom |

- Relations derived FROM the table, not hand-written closures
- Duality using the SAME variance mechanism as subtyping — session constructors get duality-specific variances (`'d` for dual-continuation, `'t` for type-component) in `component-variances`
- The topology handler dispatching on algebraic properties (antitone? → read both cells), not on relation names

**Why this is track-sized:**
1. Unifying duality's `component-lattices` dispatch with the variance mechanism requires updating 19 constructor registrations in `ctor-registry.rkt`
2. The kind-variance table replaces 3 closures + 6 dispatch checks — non-trivial refactoring
3. Nomenclature cleanup (`sre-relation` → algebraic kind naming) touches all SRE consumers
4. The topology handler unification removes the last duality special case — must be tested across all PAR Track 1 bug categories
5. This is fundamental infrastructure — getting it wrong breaks all structural reasoning. Deserves full design methodology (Stage 2 audit → Stage 3 design → critique → implement).

### Design Recommendation: SRE Track 3 — Algebraic Foundation

**Objective**: Make the SRE's endomorphism ring decomposition self-documenting. The algebraic structure should be visible in the code, not hidden in ad-hoc closures.

**Deliverables**:
1. **Kind-variance table as data** — single lookup function: `(algebraic-kind-for variance relation-kind) → sub-relation-kind`. Replaces all `sub-relation-fn` closures.
2. **Unified variance for duality** — session constructors use duality-specific variance annotations (`'d`, `'t`) in the same `component-variances` field. Duality reads variances, not `component-lattices`.
3. **Nomenclature cleanup** — `sre-relation` → naming that reflects algebraic kind. `sub-relation-fn` → derived from table.
4. **Topology handler unification** — duality/non-duality fork → kind-property-dispatched. "Needs both cells" is a property of antitone kinds, not a check on `'duality`.
5. **New relation extensibility** — adding a relation kind = adding a column to the table. No new closures, propagator constructors, or topology handler branches.

**Cross-references**:
- Module theory: `docs/research/2026-03-28_MODULE_THEORY_LATTICES.md` §3 (endomorphism ring decomposition)
- PAR Track 1 experience: duality was hardest (3 of 10 bugs). Algebraic-kind dispatch would have prevented the topology handler's duality-specific bugs.
- PTF Track 1: Phase 1 residuation analysis confirmed the algebraic structure; Phase 3 audit revealed the implementation gap.

---

**Goal**: Add algebraic-kind derivation to `ctor-desc`. Make SRE decomposition generic (kind-dispatched instead of per-relation case dispatch).

**Why this is independently valuable**: Every future SRE-consuming track (PPN normalization, BSP-LE tabling, CIU collection dispatch) benefits from generic decomposition. The current per-relation special cases (especially duality's cross-component mixing) were the source of 3 of PAR Track 1's 10 bugs.

**Design**:

### Algebraic kind derivation

For a given (field-variance, relation) pair, the algebraic kind is:

| Field variance | Equality | Subtype | Duality | Rewriting |
|---------------|----------|---------|---------|-----------|
| covariant | identity | monotone | antitone | idempotent |
| contravariant | identity | antitone | monotone | idempotent |
| invariant | identity | identity | identity | idempotent |

The table IS the endomorphism ring decomposition made explicit. The SRE reads it instead of case-dispatching.

### Implementation

1. Add `(define (algebraic-kind-for-field variance relation) ...)` to `sre-core.rkt`
2. `sre-decompose-generic` calls `algebraic-kind-for-field` per field instead of checking `(eq? relation 'subtype)` etc.
3. The topology handler uses the same table — no more `(eq? rel-name 'duality)` branch
4. Duality-specific code (`sre-duality-decompose-dual-pair`) becomes the generic antitone case
5. Test: all existing SRE tests pass (decomposition behavior unchanged)

### Acceptance criteria
- All 383 tests GREEN
- No per-relation `case`/`cond` in decomposition hot path
- Duality tests specifically verified (the hardest path)
- New relation types can be added by extending the table, not by writing new code paths

---

## Phase 4: Residuation Prototype (Conditional)

**Scope determined by Phase 1 findings.**

If residuation is viable:

### Minimal prototype
1. Implement `residual` function for the term lattice: given a pattern-match function and a target value, compute the residual structurally
2. Compare against narrowing on 10 test cases from the narrowing test suite
3. Measure: computation steps (residual vs narrowing), correctness (same results?)

### What this does NOT do (yet)
- Does not replace narrowing in the elaborator
- Does not handle higher-order residuation
- Does not integrate with the propagator network (residual propagators are a later track)

### What it proves
- Residuation IS computable for our lattice (or identifies the boundary where it breaks)
- The structural formula produces correct results
- The computation is cheaper than enumeration (or quantifies when it isn't)

---

## Phase 5: Submodule-Informed Architecture Review (Conditional)

**Scope determined by Phase 0 findings.**

If the submodule decomposition differs from our subsystem boundaries:

1. Document the discrepancy: which subsystems are entangled? Which are decomposable?
2. For entangled subsystems: is the entanglement essential (shared cells that MUST be shared) or accidental (cells that happen to be shared but could be separated)?
3. For decomposable subsystems: what are the sub-components? Do they correspond to meaningful sub-concerns?
4. Recommendation: should our subsystem boundaries change? If so, which tracks are affected?

This phase produces a design recommendation, not code changes. The actual restructuring (if needed) would be a subsequent track.

---

## Phase 6: Synthesis

**Goal**: Capture confirmed/refuted conjectures, update theory documents, inform future tracks.

1. Update PTF Master with confirmed findings
2. Update PRN Master with module-theoretic grounding
3. Update relevant series masters if findings change their scope
4. Distill lessons into DEVELOPMENT_LESSONS.org and/or DESIGN_PRINCIPLES.org
5. Identify follow-on tracks spawned by findings (residuation track in BSP-LE, algebraic-kind in SRE, etc.)

---

## Phase 7: PIR

Standard post-implementation review following the methodology (16 questions, 10-PIR longitudinal survey).

---

## Living Document Protocol

This design document evolves as findings arrive:

- **After Phase 0**: Update the Progress Tracker. Add Phase 0 findings summary. Adjust Phase 5 scope or mark SKIP.
- **After Phase 1**: Update the Progress Tracker. Add Phase 1 findings summary. Adjust Phase 4 scope or mark SKIP.
- **After Phase 2**: Decision gate captures the chosen path. Remaining phases have concrete scope.
- **After each implementation phase**: Standard phase completion protocol (commit → tracker → dailies → proceed).

The document is both a plan and a record. Future readers can trace the research → decision → implementation chain.

---

## Relationship to Other Tracks

### Feeds into
- **SRE Track 3+**: algebraic-kind generalization makes future SRE tracks simpler
- **BSP-LE Track 3+**: residuation findings shape the logic engine design
- **PPN Track 2+**: filtration structure informs how new graded pieces are added
- **PAR Track 3+**: submodule decomposition informs the `:auto` heuristic

### Depends on
- **PAR Track 1**: BSP-as-default (COMPLETE) — needed for parallel submodule experiments
- **SRE Tracks 0-2**: structural reasoning engine (COMPLETE) — the substrate we're analyzing
- **PPN Track 1**: propagator reader (COMPLETE) — parse domains in the module structure

### Does not block
- **PPN Track 2**: can proceed in parallel. Phase 3 (algebraic-kind) improves PPN Track 2 if done first, but PPN Track 2 doesn't depend on it.
- **PM 10C**: test parallelism — independent infrastructure concern.
