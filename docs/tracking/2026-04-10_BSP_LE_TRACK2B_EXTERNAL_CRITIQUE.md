# BSP-LE Track 2B D.7 External Critique — P/R/M Three-Lens Analysis

**Date**: 2026-04-10
**Design reviewed**: D.7 (`docs/tracking/2026-04-10_BSP_LE_TRACK2B_DESIGN.md`)
**Self-critique reviewed**: `docs/tracking/2026-04-10_BSP_LE_TRACK2B_SELF_CRITIQUE.md` (15 findings, 5 revised via self-hosting lens)
**Methodology**: `docs/tracking/principles/CRITIQUE_METHODOLOGY.org`

---

## Lens P: Principles Challenged

### P1: `solve-goal-propagator` calls `run-to-quiescence` (Gauss-Seidel), not `run-to-quiescence-bsp` — Severity: Critical

The design's entire Tier 1 optimization pipeline (Phase 5a-5c) targets BSP scheduling overhead (52.6% of the 23us budget). But the actual entry point at line 1889 of `relations.rkt` calls `run-to-quiescence` (Gauss-Seidel), NOT `run-to-quiescence-bsp`. The BSP scheduler is never invoked for the top-level solve.

This means:
- The fire-once fast-path inside `run-to-quiescence-bsp` (Phase 5a) would never be reached unless `solve-goal-propagator` is first changed to call `run-to-quiescence-bsp`.
- The parallel executor (Phase 6) is also wired through `run-to-quiescence-bsp` — same gap.
- The 52.6% BSP overhead number may be measuring the cost of SWITCHING to BSP, not the cost of the CURRENT path.

**Challenge**: Is there an architectural reason the top-level solve uses GS instead of BSP? If GS is actually faster for the common case, then the "switch to BSP" step itself introduces the 52.6% overhead rather than eliminating it. The optimization pipeline may be solving a problem the transition creates.

### P2: Phase 5a and Phase 5c are STILL two separate phases with overlapping scope — Severity: Major

The self-critique (P2) said "merge 5a into 5c" and the resolution says "ACCEPTED: Merged into single fire-once fast-path inside BSP scheduler." But the phased roadmap still lists Phase 5a ("Deterministic Query Fast-Path") with its own description. If the self-critique resolution was genuinely accepted, the roadmap should have ONE phase.

### P3: NAF "adaptive thread dispatch" reintroduces the bifurcation the self-critique eliminated — Severity: Major

The self-critique (P3) established: "BOTH sync and async paths write to the NAF-result cell." But then the design reintroduces a bifurcation: sync for facts-only, async for clause-bearing. The dispatch criterion is `variant-info-clauses` emptiness — relation-structure introspection that fights the propagator model.

**Challenge**: Could the thread decision be EMERGENT? Concretely: always start inner BSP on current thread; if it converges in one round (fire-once, trivially convergent), the result is immediate. If NOT (multiple rounds needed), THEN spawn thread. This "deferred-spawn" pattern eliminates relation-info introspection — the NAF propagator is agnostic to its inner goal's structure.

### P4: Discrimination cell has no propagator producing it in any phase — Severity: Major

The self-hosting lens (§3.8) says the discrimination map should be a cell. But no phase allocates this cell, installs a derivation propagator, or connects it to the relation registry. The cell exists conceptually but is "designed-but-not-implemented."

### P5: `install-conjunction`'s `for/fold` ordering IS relevant for NAF/guard performance — Severity: Major

Section 3.5 says installation order is irrelevant. This is true for correctness (CALM) but NOT for performance: installing goals in dependency order reduces wasted residuations. NAF/guard propagators that fire before their input-producing goals are installed will residuate and need rescheduling.

### P6: DFS retention lacks explicit retirement condition — Severity: Minor

When is the DFS solver retired? What condition makes it no longer needed? The design should state this explicitly.

---

## Lens R: Reality-Check (Code Audit)

### R1: Production code uses GS not BSP — overhead decomposition may measure non-production path — Severity: Critical

Same as P1. Line 1889 calls `run-to-quiescence` (GS). The 52.6% BSP overhead is the cost of enabling BSP, not a baseline cost being optimized away.

### R2: Fact-row PU restructuring is larger than estimated — Severity: Major

Fact-row PU branching mirrors the 48-line multi-clause PU path plus the 58-line `install-one-clause-concurrent`. Estimate should be ~60-80 lines for fact-row PU, not ~30.

### R3: Fact-row and clause bitmask namespaces may collide — Severity: Major

Both facts and clauses allocate assumption IDs starting at 0. Mixed fact+clause relations need coordinated bitmask allocation from the same counter/`solver-assume` infrastructure.

### R4: Phase 5c and old Phase 5d overlap in roadmap — Severity: Minor

The progress tracker lists Phase 5c as "Solver-template cell" but the optimization section still has the old "Context Pooling" description.

### R5: Cross-network cell write mechanism for async NAF is unresolved and load-bearing — Severity: Major

Open question 6 lists three options, selects none. The outer BSP's termination detection (empty worklist = fixpoint) has no mechanism to detect pending writes from sub-networks. A wrong choice produces deadlocks or race conditions.

### R6: `current-is-eval-fn` parameter capture for guard propagator — Severity: Minor

If the guard evaluator fires as a propagator (potentially on a different thread), `current-is-eval-fn` must be captured at propagator installation time, not read at fire time.

---

## Lens M: Propagator-Mindspace

### M1: Current NAF is entirely imperative (including env-scanning); migration scope understated — Severity: Major

The current NAF code at lines 1463-1489 SCANS all environment variables with `for/or` to detect whether the inner goal succeeded. This is imperative comparison, not a cell read. The propagator-native replacement: inner BSP's answer accumulator cell starts at bot; non-bot = succeeded. Single cell read, not scan. Also: current NAF is a no-op in the propagator solver (returns unchanged network regardless of result).

### M2: Lazy context `promoted?` field is imperative flag dispatch — Severity: Minor

A boolean field checked at branch time is imperative. The propagator-native alternative: solver-context as a cell value that monotonically refines from minimal to full. Promotion is a cell write, not a flag check.

### M3: Hypercube merge sketch uses imperative vocabulary — Severity: Minor

The implementation sketch uses mutable `my-result` and `shared-buffer`. The propagator-native description: each pairwise merge IS a propagator. The merge tree is a propagator network. No mutable buffers.

### M4: Guard topology request adds one outer loop round per guard — Severity: Observation

Inner goals installed via topology request are always delayed by one full BSP outer loop iteration. For conjunctions with multiple guards, the rounds accumulate.

### M5: NTT model omits conjunction wiring — NAF/guard interaction with subsequent goals unspecified — Severity: Major

The NTT model shows individual propagators but not how they compose in a conjunction. How does NAF-gate output feed the next goal? How does guard topology request access conjunction scope? This gap will surface during Phase 2-3 implementation.

### M6: `install-conjunction` for/fold is construction-time self-hosting debt — Severity: Observation

For self-hosting, conjunction installation should be a propagator that emits topology requests. The current `for/fold` is scaffolding.

---

## Summary

| ID | Lens | Finding | Severity |
|----|------|---------|----------|
| P1 | P | GS-to-BSP transition is missing prerequisite | Critical |
| P2 | P | Phase 5a/5c still separate despite "merged" | Major |
| P3 | P | NAF adaptive dispatch = structural introspection | Major |
| P4 | P | Discrimination cell has no producing propagator | Major |
| P5 | P | Conjunction ordering affects NAF/guard BSP rounds | Major |
| P6 | P | DFS retirement condition missing | Minor |
| R1 | R | Production uses GS, not BSP — overhead numbers questionable | Critical |
| R2 | R | Fact-row PU line estimate too low | Major |
| R3 | R | Fact-row/clause bitmask namespace collision | Major |
| R4 | R | Phase 5c/5d overlap | Minor |
| R5 | R | Cross-network NAF write unresolved | Major |
| R6 | R | Guard parameter capture for thread context | Minor |
| M1 | M | Current NAF is imperative no-op; migration scope understated | Major |
| M2 | M | Lazy context flag is imperative | Minor |
| M3 | M | Hypercube sketch uses imperative vocabulary | Minor |
| M4 | M | Guard adds one BSP outer round | Observation |
| M5 | M | NTT model missing conjunction wiring | Major |
| M6 | M | Conjunction for/fold is self-hosting debt | Observation |

### Cross-Cutting Observations

1. **The GS-to-BSP transition is the hidden prerequisite.** The entire design is built on BSP scheduling semantics, but the production solver uses Gauss-Seidel. This is the foundation — it must be front-loaded.

2. **The self-hosting lens revision is directionally correct but incompletely realized.** The gap between "this should be a cell" and "this IS a cell with a propagator producing it" is the designed-but-not-implemented anti-pattern.

3. **The NAF cross-network write is the hardest unsolved problem.** The outer BSP's termination detection does not account for pending writes from sub-networks.

4. **The NTT model reveals a conjunction gap.** Individual propagator types are modeled but their composition within a conjunction is not.
