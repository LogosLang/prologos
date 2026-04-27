# PPN 4C Tropical Quantale Addendum — Pre-0 Microbench Plan

**Date**: 2026-04-26
**Stage**: 3 — Pre-0 phase per [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) Stage 3 ("Pre-0 Benchmarks Per Semantic Axis")
**Status**: Plan drafted; execution pending
**Parent design**: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) (D.1) — this doc expands D.1 §13 with comprehensive multi-axis Pre-0 plan

---

## §1 Purpose and scope

### §1.1 Purpose

Per Stage 3 mandate: **Pre-0 benchmarks are DESIGN INPUT, not validation.** They establish the data that informs D.2 design revisions BEFORE implementation begins. Per longitudinal pattern across recent PIRs (10/10 instances), Pre-0 reshapes design.

This plan covers:
1. **Pre-implementation baselines** — measure CURRENT state (counter-based fuel; deprecated atms surfaces; existing prop-network) so we have a reference point
2. **Post-implementation comparisons** — re-measure same scenarios after Phase 1B/1C/1A-iii-b/1A-iii-c land; compare to baselines
3. **Adversarial scenarios** — stress tests that surface edge cases the happy-path benchmarks would miss
4. **Algebraic correctness verification** — quantale axioms + residuation laws + module theory laws; post-impl
5. **Multi-quantale composition** — TypeFacetQ + TropicalFuelQ co-existence; post-impl
6. **Memory as first-class characterization** — per `DESIGN_METHODOLOGY.org` "Memory cost is a separate axis from wall-clock"; measured on every benchmark where applicable
7. **Suite-level regression detection** — full-suite wall time + per-file timings + heartbeat counter deltas
8. **Parity validation** — counter-vs-cell exhaustion equivalence + ATMS retirement parity

### §1.2 Performance characterization framework

Every benchmark gets THREE dimensions where applicable:

**Wall-clock** (timing axis):
- Mean / median / stddev / CV / IQR / 95% CI per `bench-micro` style measurement
- Operation-level (ns/call) for micros; run-level (ms) for E2E
- Tukey outlier detection; stability validation

**Memory** (allocation + retention axis — per `DESIGN_METHODOLOGY.org` "Memory cost is a separate axis from wall-clock"):
- **Allocation bytes** per call/run (pressure measure)
- **Live retention** (`mem_retained_bytes` from heartbeat counters; post-GC memory)
- **GC activity** (count + duration; per DESIGN_METHODOLOGY "Required measurements per phase")
- Use existing `bench-mem` macro (bench-ppn-track4c.rkt:73)

**Semantic correctness** (where applicable):
- Algebraic axiom verification (C-series): assertion-based
- Parity equivalence (V-series): set-equal/semantic-equal between paths

### §1.3 Why memory is first-class for THIS addendum

Per DESIGN_METHODOLOGY: "Memory cost is a separate axis from wall-clock... different axes catch different problems."

For tropical fuel substrate specifically, memory matters at FOUR distinct points:

1. **Per-operation allocation** — `(net-cell-write net fuel-cid (+ cost n))` allocates a tagged-cell-value entry per worldview; the existing `(- (prop-network-fuel net) n)` was a struct-copy. Allocation profile differs.
2. **Sustained retention** — long-running computations accumulate fuel-cell history (under speculation worldviews); compare to counter's bounded state.
3. **GC pressure under load** — high-frequency decrement scenarios (deep type inference, prelude loading) generate GC pressure proportional to allocation rate.
4. **Per-consumer overhead** — multi-consumer scenarios (10 consumers × N decrements each) test whether per-consumer fuel cells scale memory linearly or worse.

Per DESIGN_METHODOLOGY: "Parallel infrastructure is especially memory-sensitive (worker pool threads, channels, per-worker CHAMP forks, GC amplification across threads)." Tropical fuel cells under speculation forks (Phase 3A union-type ATMS branching, future) inherit this concern.

### §1.4 Out of scope (Pre-0 specifically)

- **Implementation of tropical-fuel.rkt** — Pre-0 establishes baseline; impl is Phase 1B
- **Phase 3C residuation propagator implementation** — Pre-0 anticipates via UC1/UC2/UC3 forward-capture but doesn't implement
- **Multi-quantale Galois bridge implementation** — Pre-0 covers NTT-level co-existence test (X-series); full bridge is Phase 3C consumer
- **Cross-quantale tensor products** — quantaloids (research §3.6) out of scope per D.1 §1.3

---

## §2 Tier structure

| Tier | Purpose | Pre-impl | Post-impl | Total tests |
|---|---|---|---|---|
| **M** Micro-benchmarks | Per-operation costs (wall + memory) | M7-M13 baseline counter-side | M7-M13 cell-side comparison | 7 |
| **A** Adversarial scenarios | Stress patterns + edge cases | A5-A12 counter-side | A5-A12 cell-side | 8 |
| **C** Algebraic correctness | Quantale axioms + residuation laws + module theory | — (no quantale yet) | C1-C5 verification | 5 |
| **X** Multi-quantale composition | TypeFacetQ + TropicalFuelQ co-existence | — (only TypeFacetQ exists) | X1-X3 verification | 3 |
| **E** End-to-end programs | Realistic workloads (extending E1-E6) | E7-E9 counter-side | E7-E9 cell-side | 3 |
| **R** Memory-specific scenarios | Memory as PRIMARY signal | R1-R5 counter-side | R1-R5 cell-side | 5 |
| **S** Suite-level | Full-suite wall + heartbeat + per-file | S1-S4 baseline | S1-S4 post-impl | 4 |
| **V** Parity validation | Counter-vs-cell + ATMS retirement parity | — (parity only post-impl) | V4-V6 | 3 |

**Total: 38 distinct test specifications across 8 tiers.** Each M/A/E/R test gets wall + memory axes (12+8+3+5 = 28 tests with dual-axis measurement).

---

## §3 Tier M — Micro-benchmarks (per-operation costs)

Each M-test follows the same structure: setup + wall-clock measurement + memory measurement + hypothesis + decision rule.

### M7 — Tropical-fuel-merge (min) cost

**Semantic axis**: per-write merge function cost

**Setup**:
- Pre-impl: pre-allocated `prop-net-cold` with `fuel = 1000000`
- Post-impl: pre-allocated tropical fuel cell with initial value 0; budget cell with 1000000

**Wall-clock measurement**:
- Pre-impl: `(struct-copy prop-net-cold ... [fuel (- old-fuel n)])` × 50000 iterations; ns/call
- Post-impl: `(net-cell-write net fuel-cid (+ cost n))` × 50000 iterations; ns/call
- Sub-variants: n=1 (typical), n=100 (batched), n=10000 (large step)

**Memory measurement** (per `bench-mem` macro):
- Allocation bytes per merge call
- Post-GC retention delta after 10000 merges
- GC count over 50000 merges
- Pre-impl: struct-copy = ~1 prop-net-cold instance per call (~200 bytes)
- Post-impl: tagged-cell-value entry per worldview-tag (variable; typically 1 entry under no-speculation, multiple under speculation)

**Hypothesis**:
- Wall: cell-write within 50% of struct-copy cost (~1.5x at worst). Both are O(1) per call.
- Memory: cell-write allocates similar order (~100-300 bytes per call) under no-speculation; under speculation, additional tagged entries scale with worldview count
- GC: comparable count under no-speculation; speculation forks may amplify

**Decision rule if hypothesis fails**:
- If wall > 2x struct-copy: reconsider canonical instance approach (maybe per-consumer allocation only; revisit Q-A2)
- If memory > 3x struct-copy: investigate tagged-cell-value overhead; consider non-tagged variant for canonical fuel cell
- If GC count > 2x: investigate allocation pattern for object-pooling opportunity

### M8 — Threshold propagator firing cost

**Semantic axis**: per-write threshold check cost (vs inline check)

**Setup**:
- Pre-impl: `(<= (prop-network-fuel net) 0)` inline check at decrement site
- Post-impl: threshold propagator installed on (fuel-cid, budget-cid); fires when cost >= budget

**Wall-clock measurement**:
- Pre-impl: inline check cost per decrement; 50000 iterations
- Post-impl: write to fuel-cid → BSP scheduler fires threshold propagator → propagator reads + compares + conditional contradiction-write
- Sub-variants:
  - No-trigger case (cost << budget): propagator fires + no-op
  - Just-below-trigger: propagator fires + no-op
  - Trigger case (cost >= budget): propagator fires + writes contradiction

**Memory measurement**:
- Allocation per threshold-fire (no-op vs contradiction-write)
- GC pressure under high decrement rate

**Hypothesis**:
- Wall: threshold propagator within 30% of inline check at no-trigger case (single comparison + conditional write); at trigger case, includes contradiction-write cost (~10x baseline due to net-contradiction infrastructure)
- Memory: propagator fire allocates a worklist entry per fire (~50-100 bytes); compare to inline check's 0 allocation
- GC: propagator approach may pressure GC under sustained decrement; worth measuring

**Decision rule if hypothesis fails**:
- If no-trigger wall > 100% of inline check: reconsider threshold propagator architecture (maybe inline check at decrement site as alternative)
- If memory significantly higher: object-pool worklist entries OR reduce per-fire allocation
- If GC > 5x: reconsider per-write threshold-fire frequency (batch with set-latch pattern from propagator-design.md)

### M9 — Per-consumer fuel cell allocation cost

**Semantic axis**: scaling of per-consumer fuel cell allocation

**Setup**:
- Pre-impl: existing `net-new-cell` baseline (no specific fuel-cell concept)
- Post-impl: `net-new-tropical-fuel-cell net` with N=1, 5, 50, 500 consumers per net

**Wall-clock measurement**:
- Pre-impl: existing `net-new-cell` cost per allocation; cumulative for N allocations
- Post-impl: `net-new-tropical-fuel-cell` per allocation; verify O(1) per cell
- Cumulative time for N=1, 5, 50, 500

**Memory measurement** (especially load-bearing for THIS test):
- Allocation bytes per fuel cell (per N value)
- Per-cell overhead (tagged-cell-value + cell entry in CHAMP)
- Total network memory growth with N consumers
- GC pressure for high-N scenarios

**Hypothesis**:
- Wall: O(1) per cell; N=500 should be 500x N=1 (with negligible per-call overhead variance)
- Memory: ~200-500 bytes per cell (cell entry + initial tagged-cell-value); linear with N
- Verify: `net-new-cell` baseline (~0.56 μs/op per S2 baseline §3) should match tropical-fuel-cell allocation time

**Decision rule if hypothesis fails**:
- If non-O(1) (e.g., O(N log N) due to CHAMP rebalancing pathology): reconsider per-consumer feasibility; maybe pool-based allocation
- If memory > 1KB per cell: investigate cell value layout

### M10 — Residuation operator (read-time) cost

**Semantic axis**: pure function call cost

**Setup**:
- Post-impl ONLY (no pre-impl baseline; operator doesn't exist)
- `(tropical-left-residual a b)` for various (a, b) value combinations

**Wall-clock measurement**:
- Simple case: `(tropical-left-residual 5 10)` × 50000 iterations
- Boundary case: `(tropical-left-residual 0 0)`, `(tropical-left-residual 5 +inf.0)`, `(tropical-left-residual +inf.0 5)`
- Pathological: `(tropical-left-residual a b)` with extreme values
- Compare to hypothetical propagator-wrapped variant (Q-1B-4 informant)

**Memory measurement**:
- Allocation per call (pure function: should be 0 for fixnum cases; possibly bignum allocation for extreme cases)
- Boxing cost for `+inf.0` (Racket float)

**Hypothesis**:
- Wall: ~10-30 ns/call for fixnum cases; ~50-100 ns/call for `+inf.0` cases (float comparison)
- Memory: 0 for fixnum cases; possible boxing for floats
- Decision input for Q-1B-4: read-time helper has near-zero overhead → consumers wrap in propagator only when needed

**Decision rule if hypothesis fails**:
- If wall > 100 ns: residuation operator may need optimization (e.g., open-coded comparison)
- If significant memory overhead: revisit `+inf.0` representation choice (Q-1B-2)

### M11 — Tropical tensor (a + b) cost

**Semantic axis**: cost composition (⊗ operation)

**Setup**:
- Pre-impl: `(- old-fuel n)` (cost subtraction; equivalent operation in counter model)
- Post-impl: `(+ accumulated-cost step-cost)` via `tropical-fuel-tensor`

**Wall-clock measurement**:
- Sub-variants: small fixnum, large fixnum, `+inf.0` propagation
- 50000 iterations per variant

**Memory measurement**:
- Should be 0 allocation for fixnum cases; possible bignum for very large accumulations
- `+inf.0` propagation cost

**Hypothesis**:
- Wall: ~5-10 ns/call (single arithmetic op)
- Memory: 0 for fixnum cases

**Decision rule if hypothesis fails**:
- If wall > 50 ns: investigate Racket's `+` for the relevant numeric domain
- If memory non-zero: choose representation more carefully (Q-1B-2)

### M12 — SRE domain registration overhead

**Semantic axis**: one-time module-load cost

**Setup**:
- Pre-impl: existing `register-domain!` cost for type-sre-domain (already registered; measure as proxy)
- Post-impl: tropical-fuel-sre-domain registration cost

**Wall-clock measurement**:
- One-time: register-domain! cost (single execution)
- Multi-time: how does registration scale if hypothetically called repeatedly (idempotency check)

**Memory measurement**:
- One-time allocation for SRE domain entry
- merge-fn-registry entry

**Hypothesis**:
- Wall: < 1 ms (one-time at module load)
- Memory: < 10KB per domain (struct + property declarations + merge-fn entries)

**Decision rule if hypothesis fails**:
- If significantly higher: investigate property inference triggering at registration vs lazy

### M13 — Compound cell value access cost

**Semantic axis**: cell read for tropical fuel cell

**Setup**:
- Pre-impl: `(prop-network-fuel net)` accessor (syntax-rule expansion to struct-field access)
- Post-impl: `(net-cell-read net fuel-cid)` for tropical fuel cell

**Wall-clock measurement**:
- 50000 iterations per variant
- Pre-impl: struct-field access (~5 ns)
- Post-impl: cell-read includes CHAMP lookup (~30-50 ns per BSP-LE 0 baselines)

**Memory measurement**:
- Should be 0 for both (read-only)

**Hypothesis**:
- Wall: cell-read 6-10x slower than struct-field access (constant factor; per-call cost)
- Memory: 0 for both
- Aggregate impact on full elaboration: bounded; reads are not the hot path

**Decision rule if hypothesis fails**:
- If wall > 100 ns: investigate cell-read cost optimization (e.g., pre-resolved cell-id cache)

---

## §4 Tier A — Adversarial scenarios (stress patterns)

### A5 — Cost-bounded exploration vs flat fuel exhaustion (semantic axis)

**Semantic axis**: tropical fuel's cost-awareness vs counter's step-count-only behavior

**Setup**:
- Workload with non-uniform per-step cost: 80% steps cost 1, 15% steps cost 10, 5% steps cost 1000
- Total expected cost under uniform-cost assumption: N × 1 = N
- Total expected cost under realistic profile: N × (0.8 × 1 + 0.15 × 10 + 0.05 × 1000) = N × 52.3

**Wall-clock measurement**:
- Pre-impl: counter exhausts at step-count regardless of cost; budget = N steps
- Post-impl: tropical fuel exhausts at accumulated cost == budget; budget = N × 52.3 cost units
- Compare: at what step count does each approach exhaust?

**Memory measurement**:
- Per-step allocation profile under each
- Long-running retention (does tropical fuel cell value grow unboundedly under worldview accumulation?)

**Hypothesis**:
- Pre-impl: counter exhausts at exactly N steps (cost-blind)
- Post-impl: tropical fuel exhausts at variable step count depending on encountered cost distribution; provides cost-aware exhaustion as designed
- Memory: similar order of magnitude; tropical fuel may have slight worldview-tagged overhead

**Decision rule if hypothesis fails**:
- If post-impl exhausts at step count rather than cost: bug in tensor accumulation
- If memory grows unboundedly: investigate tagged-cell-value retention semantics

### A6 — Deep dependency chain (Phase 3C residuation walk pre-test)

**Semantic axis**: Phase 3C UC1 fuel-exhaustion blame attribution forward-capture

**Setup**:
- Construct propagator dependency chain of depth N (N=10, 50, 200)
- Each propagator decrements fuel by 1 when fired
- Fuel exhausts at end of chain

**Wall-clock measurement**:
- Pre-impl: counter exhaustion + dependency chain walk cost (currently no infrastructure)
- Post-impl: tropical fuel exhaustion + future Phase 3C residuation walk via `tropical-left-residual` (forward-capture; not implemented in 1B but operator works)
- Sub-test: time the residuation walk simulation (manually walking the dep graph using the operator) for chain depth N

**Memory measurement**:
- Allocation per chain step
- Total chain memory at exhaustion
- GC profile during walk

**Hypothesis**:
- Wall: residuation walk cost O(N) for chain depth N; for N=200, < 100 μs total
- Memory: O(N) for chain representation; manageable for typical depth (< 1 KB / step)
- Decision input for Phase 3C UC1 feasibility: confirms residuation walk is algorithmically efficient

**Decision rule if hypothesis fails**:
- If walk cost > 1 ms for N=200: reconsider Phase 3C UC1 design (maybe lazy walk vs eager)
- If memory per step too high: investigate dep-graph representation

### A7 — High-frequency decrement (fuel exhaustion under load)

**Semantic axis**: high-throughput cost accumulation

**Setup**:
- N=1000, 10000, 100000 decrements in tight loop
- Compare wall-clock + memory + GC profile

**Wall-clock measurement**:
- Pre-impl: counter decrement loop time (baseline)
- Post-impl: cell-write loop time
- Aggregate ms for N decrements

**Memory measurement** (PRIMARY SIGNAL for this test):
- Allocation rate (bytes/sec)
- GC pause count during loop
- Total retention after loop completes
- Pre-impl: bounded (single struct-copy per call; old struct GC'd)
- Post-impl: tagged-cell-value accumulation per call (multiple worldview entries possible)

**Hypothesis**:
- Wall: cell-write loop within 50% of struct-copy loop time
- Memory: cell-write loop allocates 1-3x bytes/sec vs struct-copy (under no-speculation)
- GC: comparable count; if cell-write triggers more GC, investigate object pooling

**Decision rule if hypothesis fails**:
- If allocation rate > 5x baseline: investigate object pooling for tagged-cell-value entries
- If GC count significantly higher: same as above
- If wall regression > 100%: reconsider threshold propagator approach (maybe inline check)

### A8 — Multi-consumer concurrent (10 consumers × 1000 decrements each)

**Semantic axis**: per-consumer fuel cell scaling under concurrent decrement

**Setup**:
- 10 consumers, each with own fuel cell + budget cell + threshold propagator
- Each consumer performs 1000 decrements
- Sequential execution (Pre-0 doesn't exercise true parallel — but test the sequential composition pattern)

**Wall-clock measurement**:
- Pre-impl: equivalent multi-consumer scenario impossible (no per-consumer concept)
- Post-impl: sequential per-consumer execution + cross-consumer cost reads (forward-capture for OE Track 1 weighted parsing)

**Memory measurement** (PRIMARY SIGNAL):
- Total allocation across all consumers
- Per-consumer cell overhead (verify M9 hypothesis at scale)
- GC pressure under cumulative load

**Hypothesis**:
- Wall: O(N × M) for N consumers × M decrements (linear)
- Memory: O(N) for cell allocation + O(N × M) for accumulated tagged-cell-value entries
- GC: proportional to total allocation; should not spike

**Decision rule if hypothesis fails**:
- If non-linear scaling: investigate per-consumer cell pollution OR cross-consumer state interference
- If memory > predicted: investigate per-consumer overhead

### A9 — Speculation rollback cost (write-tagged-then-rollback)

**Semantic axis**: tropical fuel under speculation worldview semantics

**Setup**:
- Pre-impl: speculation rollback uses elab-net snapshot mechanism (off-network state for fuel; counter restored from snapshot)
- Post-impl: speculation rollback via tagged-cell-value worldview filtering (per-worldview tagged entries; rollback narrows worldview)

**Wall-clock measurement**:
- 100 speculation cycles, each accumulating fuel cost; rollback each cycle
- Compare snapshot-restore cost (pre-impl) to worldview-narrow cost (post-impl)

**Memory measurement** (PRIMARY SIGNAL):
- Pre-impl: snapshot allocation per cycle (whole prop-net structure)
- Post-impl: per-worldview tagged entry allocation per cycle (just the per-worldview slice)
- Retention: do worldview entries leak under repeated rollback?

**Hypothesis**:
- Wall: post-impl significantly faster (worldview narrow is O(1) vs snapshot restore being O(N) cells)
- Memory: post-impl significantly less retention (per-worldview slice vs full snapshot)
- This is a structural WIN for tropical fuel under speculation

**Decision rule if hypothesis fails**:
- If memory leaks under rollback: investigate tagged-cell-value cleanup at S(-1) retraction stratum
- If wall regression: investigate worldview-filtering implementation

### A10 — Branch fork explosion (per-branch fuel cells under union ATMS)

**Semantic axis**: forward-capture for Phase 3A union-type ATMS branching with per-branch fuel

**Setup**:
- Construct synthetic 5-way union; 5 branches forked
- Per-branch fuel cell allocated per branch
- Each branch performs 100 decrements before resolution

**Wall-clock measurement**:
- Allocation cost for 5 branches
- Per-branch decrement cost
- Branch resolution cost (4 retracted, 1 commits — typical pattern)

**Memory measurement** (PRIMARY SIGNAL):
- Total allocation under fork
- Per-branch cell overhead under speculation worldview
- GC pressure when branches retract
- Retention after resolution (only winning branch's state should remain)

**Hypothesis**:
- Wall: O(B × M) for B branches × M decrements per branch
- Memory: O(B) cell allocation + O(B × M) tagged entries during speculation; collapses to O(1) cell + O(M) entries after resolution
- GC: should reclaim retracted branch state at S(-1) retraction stratum

**Decision rule if hypothesis fails**:
- If retention after resolution > O(M): retracted branch state leaks; investigate S(-1) cleanup
- If wall non-linear in B: investigate per-branch cell pollution

### A11 — Pathological cost patterns

**Semantic axis**: edge-case cost accumulation behavior

**Setup**:
- Sub-test 1: single huge cost (1 step × cost 1000000) — exhausts in 1 step
- Sub-test 2: many tiny costs (1000000 steps × cost 1) — exhausts in N=1000000 steps with budget 1000000
- Sub-test 3: alternating pattern (50% cost 0, 50% cost 2; budget 1000) — interesting average behavior
- Sub-test 4: monotonically-increasing cost (step i costs i; budget 1000) — exhausts at step ~44

**Wall-clock measurement**:
- Each sub-test: time-to-exhaust + total step count
- Compare pre-impl (counter, step-count-only) vs post-impl (tropical, cost-aware)

**Memory measurement**:
- Each sub-test: allocation profile + retention at exhaustion

**Hypothesis**:
- Pre-impl all sub-tests exhaust at exactly N=budget steps (cost-blind)
- Post-impl exhausts at correct cost-aware point per sub-test
- Memory: similar order; no pathological allocation patterns

**Decision rule if hypothesis fails**:
- Bug in cost accumulation if post-impl exhausts incorrectly
- Pathological allocation indicates merge-fn bug

### A12 — Edge-case algebra (residuation at boundaries)

**Semantic axis**: residuation operator boundary behavior

**Setup**:
- (a=b): `(tropical-left-residual 5 5) = 0`
- (a=0): `(tropical-left-residual 0 5) = 5`
- (b=+inf.0): `(tropical-left-residual 5 +inf.0) = +inf.0`
- (a=+inf.0): `(tropical-left-residual +inf.0 5) = 0` (overspend)
- (a > b): `(tropical-left-residual 10 5) = 0` (overspend)
- (both 0): `(tropical-left-residual 0 0) = 0` (identity)

**Measurement**: assertion-based correctness (wall-clock secondary; mostly C-series scope)

**Hypothesis**: all 6 edge cases produce expected results per residuation formula

**Decision rule if hypothesis fails**:
- Bug in `tropical-left-residual` implementation
- Reconsider residuation operator code (Q-1B-2 representation choice if `+inf.0` semantics ambiguous)

---

## §5 Tier C — Algebraic correctness verification (post-impl)

C-series runs ONLY after Phase 1B implementation lands. They verify the quantale algebraic structure is correctly realized.

### C1 — Quantale axioms verification

**Semantic axis**: algebraic correctness of tropical quantale

**Tests**:
- C1.1 Associativity of ⊕: `(min a (min b c)) = (min (min a b) c)` for sample (a,b,c) tuples
- C1.2 Commutativity of ⊕: `(min a b) = (min b a)`
- C1.3 Idempotence of ⊕: `(min a a) = a`
- C1.4 Distributivity of ⊗ over arbitrary joins: `(+ a (min b c)) = (min (+ a b) (+ a c))`
- C1.5 Identity of ⊗: `(+ 0 a) = a`
- C1.6 Absorbing element: `(+ +inf.0 a) = +inf.0`

**Methodology**: assertion-based (rackunit `check-equal?`). Run on representative finite samples + boundary values.

**Hypothesis**: all 6 axioms confirmed.

**Decision rule if hypothesis fails**: bug in tropical-fuel-merge or tropical-fuel-tensor implementation. **Critical correctness bug — must fix before Phase 1C migration.**

### C2 — Residuation laws

**Semantic axis**: residuation operator algebraic correctness

**Tests**:
- C2.1 Adjunction: `(a ⊗ x) ≤_rev b ⟺ x ≤_rev (a \ b)` — i.e., `(>= (+ a x) b) ⟺ (>= x (tropical-left-residual a b))` for samples
- C2.2 `(a \ b) ⊗ a ≤_rev b` — i.e., `(>= (+ (tropical-left-residual a b) a) b)`
- C2.3 `a \ (b ⊓ c) = (a \ b) ⊓ (a \ c)` — distribution over meet (in T_min, ⊓ = max)
- C2.4 `1 \ a = a` — left-identity residual
- C2.5 `a \ ⊥_rev = ⊥_rev` (overspend → top in Lawvere convention)

**Methodology**: assertion-based; run on samples + boundary values

**Hypothesis**: all 5 laws confirmed

**Decision rule if hypothesis fails**: bug in residuation operator. **Critical correctness bug.**

### C3 — Integral quantale verification

**Semantic axis**: `1 = ⊤` (in Lawvere convention, both = 0)

**Tests**:
- `tropical-unit = tropical-bot = 0` (identity coincides with lattice top in `≤_rev`)
- Verify multiplicative identity: `(+ 0 a) = a`
- Verify lattice top identity: `(min 0 a) = a` for `a >= 0`

**Hypothesis**: confirmed by construction (per research §9.2)

### C4 — Module Theory laws

**Semantic axis**: cells-as-Q-modules verification

**Tests**:
- C4.1 Action associativity: `(q1 ⊗ q2) · m = q1 · (q2 · m)` (where · is cell-write composition)
- C4.2 Unit action: `tropical-unit · m = m` (writing 0-cost yields no state change)
- C4.3 Sup-preservation: `(q1 ⊕ q2) · m = (q1 · m) ⊕ (q2 · m)` (writing min-of-costs equals min-of-cell-values)

**Methodology**: state cell value before + after; verify equivalence

**Hypothesis**: all 3 laws confirmed (these are structural to Q-module definition per research §6.1)

**Decision rule if hypothesis fails**: bug in either tropical-fuel-tensor or net-cell-write integration. **Critical correctness bug.**

### C5 — CALM-safety verification

**Semantic axis**: CALM theorem applicability verification

**Tests**:
- Run a multi-decrement sequence in two different orders; verify same fixpoint state
- Run decrements interleaved across multiple consumers; verify per-consumer fixpoint independence
- Exhaustion is idempotent: writing more cost after exhaustion stays exhausted (no oscillation)

**Hypothesis**: CALM-safe per quantale's monotone merge structure

**Decision rule if hypothesis fails**: structural bug; quantale not properly monotone (would invalidate Tarski-fixpoint guarantees).

---

## §6 Tier X — Multi-quantale composition (cross-cutting)

X-series runs after Phase 1B; verifies multi-quantale composition NTT model from D.1 §4.2.

### X1 — TypeFacetQ + TropicalFuelQ independence

**Semantic axis**: verify two quantales co-exist as independent Q-modules

**Setup**:
- Existing TypeFacetQ cells (post-Step-2 universe cells)
- New TropicalFuelQ cells (post-Phase-1C canonical instance)
- Concurrent operations on both

**Tests**:
- X1.1 TypeFacetQ operations don't affect TropicalFuel cell value
- X1.2 TropicalFuel operations don't affect TypeFacet meta solutions
- X1.3 Both operate independently in same `prop-network` instance

**Methodology**: state both before + after operation; verify independence

**Hypothesis**: complete independence (different lattices; no cross-interference)

**Decision rule if hypothesis fails**: investigate shared state contamination

### X2 — Galois bridge round-trip (forward-capture for Phase 3C UC2)

**Semantic axis**: type-cost-bridge composition pattern

**Setup**:
- Hypothetical α: TypeFacetQ → TropicalFuelQ ("cost of elaborating type T")
- Hypothetical γ: TropicalFuelQ → TypeFacetQ ("types elaborable within budget B")
- For Phase 1B scope: declare bridge interface; SIMULATE α/γ via hand-coded mappings (small example: T={Nat=1, Bool=1, Pi=10, Sigma=10})

**Tests**:
- X2.1 α(T) returns expected cost for sample types
- X2.2 γ(B) returns expected type set for sample budgets
- X2.3 Round-trip: γ(α(T)) ⊇ {T} (Galois connection property: forward-then-backward over-approximates the original)
- X2.4 Composition with hypothetical second bridge (e.g., type-memory-bridge) exhibits quantale-of-bridges behavior (research §5.4)

**Methodology**: simulated bridges (no implementation in 1B); verify Galois property holds

**Hypothesis**: round-trip property holds for sample types

**Decision rule if hypothesis fails**: bug in bridge interface OR Galois property assumption misunderstood; revisit research §5.4

### X3 — Quantale-of-bridges composition

**Semantic axis**: research §5.4 — set of Galois bridges forms a quantale under composition

**Setup**:
- Two simulated bridges: type-cost-bridge + (hypothetical) type-memory-bridge
- Compose: type → cost AND type → memory (parallel composition)
- Compose: type → cost → cost-derived-memory (sequential composition)

**Tests**:
- X3.1 Parallel composition produces both costs independently
- X3.2 Sequential composition respects Galois adjunction at each step
- X3.3 Quantale operations on bridge-quantale: `(b1 ⊗ b2) ⊗ b3 = b1 ⊗ (b2 ⊗ b3)` (associativity)

**Methodology**: simulated bridges; assertion-based

**Hypothesis**: quantale-of-bridges composition holds

**Decision rule if hypothesis fails**: revisit composition pattern; may need to scope down to single-quantale-only for Phase 1B

---

## §7 Tier E — End-to-end programs (extending E1-E6)

E-series exercises realistic workloads through full pipeline. Existing E1-E6 in `bench-ppn-track4c.rkt`. New E7-E9 add tropical fuel scenarios.

### E7 — Realistic elaboration with fuel tracking

**Semantic axis**: full elaboration cost + fuel impact

**Setup**:
- Workload: `examples/2026-04-22-1A-iii-probe.prologos` (28 commands; representative elaboration profile)
- Pre-impl: counter-based fuel
- Post-impl: tropical fuel cell

**Wall-clock measurement**:
- Total elaboration time per workload
- Per-command verbose output (cell_allocs, prop_firings, fuel-related counters)

**Memory measurement**:
- Total allocation bytes per workload run
- Retention after run completes
- GC count + duration

**Hypothesis**:
- Wall: post-impl within 5% of pre-impl (counter and cell are both O(1) per decrement; constant factor difference)
- Memory: post-impl within 10% of pre-impl
- Cell_allocs delta: +N for the canonical fuel cells (cell-id 11/12 + threshold propagator) — bounded constant
- Per-command delta: should be near-zero for non-fuel-stressing commands

**Decision rule if hypothesis fails**:
- If wall regression > 10%: investigate hot-path overhead at decrement sites
- If memory regression > 20%: investigate retention semantics
- If cell_allocs delta > 10: unexpected cell allocation; investigate

### E8 — Deep type-inference workload (high decrement rate)

**Semantic axis**: stress the decrement path under realistic high-frequency workload

**Setup**:
- Workload: complex polymorphic identity composition (e.g., `[id [id [id ... [id 'nat 3N]]]]` 50-deep) — exercises many type metas + decrements
- Compare pre-impl and post-impl behavior

**Wall-clock + Memory measurement**: same dual-axis as E7

**Hypothesis**: high-frequency decrement scenario stresses the cell-write path; expect ~5-15% regression but bounded

**Decision rule if hypothesis fails**:
- If regression > 25%: revisit threshold propagator architecture (maybe inline check at decrement site as fast-path)

### E9 — Cost-bounded elaboration scenario (Phase 3C UC2 forward-capture)

**Semantic axis**: simulate Phase 3C UC2 cost-bounded elaboration via Galois bridge

**Setup**:
- Synthetic workload: elaborate a moderately complex program with EXPLICIT cost tracking
- Use simulated α: type → cost mapping
- Use tropical fuel cell to budget; verify γ direction (which types are elaborable within budget)

**Methodology**: hand-instrumented; not full Phase 3C; demonstrates the pattern works under Phase 1B substrate

**Hypothesis**: cost-bounded elaboration is feasible with current substrate; Phase 3C consumer can implement cleanly

**Decision rule if hypothesis fails**: revisit Phase 3C UC2 design (D.1 §9.7); might need additional substrate for budget-driven elaboration

---

## §8 Tier R — Memory-specific scenarios (memory as PRIMARY signal)

R-series tests where MEMORY is the primary signal (wall-clock secondary). These complement M/A/E series memory measurements with scenarios specifically designed to surface memory issues.

### R1 — Per-decrement allocation rate

**Semantic axis**: memory pressure under sustained decrement

**Setup**:
- Tight decrement loop: 100000 decrements, no GC trigger between
- Measure allocation bytes / sec
- Pre-impl: counter struct-copy rate
- Post-impl: cell-write rate

**Measurement** (allocation-focused):
- Total bytes allocated during loop
- Average bytes per decrement
- Peak allocation rate

**Hypothesis**:
- Pre-impl: ~200 bytes/decrement (struct-copy)
- Post-impl: ~250-400 bytes/decrement (tagged-cell-value entry)
- Rate: post-impl 1.25-2x pre-impl (bounded constant)

**Decision rule if hypothesis fails**:
- If post-impl > 5x: object-pool tagged-cell-value entries

### R2 — Retention after quiescence

**Semantic axis**: post-elaboration memory footprint

**Setup**:
- Run E7 workload to completion
- Force GC
- Measure retained bytes (`mem_retained_bytes` from heartbeat)

**Measurement** (retention-focused):
- Pre-impl: counter contributes ~0 retention (single int field in struct)
- Post-impl: tropical fuel cell + budget cell + threshold propagator + tagged-cell-value entries

**Hypothesis**:
- Pre-impl: ~25-50KB retention (per existing E-series baseline)
- Post-impl: + ~5-10KB for tropical fuel infrastructure (canonical instance + threshold prop)

**Decision rule if hypothesis fails**:
- If retention > 2x: investigate cell value layout
- If retention grows with workload size (vs constant): fuel cell value not garbage-collected per-cycle (worldview accumulation issue)

### R3 — GC pressure profile under high decrement rate

**Semantic axis**: GC behavior under load

**Setup**:
- Run A7 (high-frequency decrement) workload
- Capture per-iteration GC events (count + duration)

**Measurement**:
- GC count over total run
- GC duration cumulative
- Peak heap size

**Hypothesis**:
- Pre-impl: minor GC every ~10000 decrements (struct-copy GC pressure)
- Post-impl: similar minor GC frequency; possibly slightly higher due to tagged-cell-value entries

**Decision rule if hypothesis fails**:
- If GC count > 3x baseline: object pooling strategy needed
- If GC duration > 2x: investigate which allocations are surviving to old gen

### R4 — Memory cost of compound cell value vs flat tagged-cell-value

**Semantic axis**: cell value layout impact on memory

**Setup**:
- Allocate tropical fuel cell (atomic value: `0` or `+inf.0`)
- Compare vs hypothetical flat tagged-cell-value (single tag layer)
- Compare vs hypothetical compound cell value (hasheq with multiple worldview tags)

**Measurement**:
- Per-cell base memory
- Per-tag-layer marginal memory

**Hypothesis**:
- Tropical fuel cell is `'value` classification (atomic) — should NOT need compound layout
- Per-cell base: ~150-300 bytes (cell entry + initial tagged-cell-value)
- Per-additional-worldview-tag: ~50-100 bytes

**Decision rule if hypothesis fails**:
- If base > 1KB: investigate cell layout
- If per-worldview marginal > 200 bytes: investigate tag-entry overhead

### R5 — Long-running fuel cell retention under speculation accumulation

**Semantic axis**: tagged-cell-value retention under repeated speculation cycles

**Setup**:
- Run 1000 speculation cycles, each accumulating fuel cost; commit-or-rollback
- Measure cell value size growth + retention over cycle count

**Measurement** (retention-focused):
- Tagged-cell-value entry count per cycle
- Retention growth rate
- GC effectiveness at clearing rolled-back tags

**Hypothesis**:
- Per-cycle: 1 new tagged entry on commit; 1 entry retracted on rollback
- Cumulative: bounded by S(-1) retraction cleanup
- Retention: stable or slowly-growing; not unbounded

**Decision rule if hypothesis fails**:
- If retention grows unboundedly: bug in S(-1) tagged-cell-value cleanup
- If per-cycle entry count > 1: investigate tag-entry creation pattern

---

## §9 Tier S — Suite-level (existing infrastructure)

S-series leverages existing infrastructure (`tools/run-affected-tests.rkt` + `tools/benchmark-tests.rkt` + `data/benchmarks/timings.jsonl`). No bench code additions; configuration + comparison.

### S1 — Full suite wall time pre vs post

**Semantic axis**: suite-level regression detection

**Methodology**:
- Pre-impl: capture current wall time (currently 119.3s per S2.e-v close)
- Post-impl: re-run after Phase 1B+1C+1A-iii-b+1A-iii-c land
- Compare: must stay within 118-127s baseline variance band

**Decision rule**:
- If > 130s: regression > 10%; investigate per-file timing distribution (S2)
- If < 115s: improvement > 3%; capture as positive finding

### S2 — Per-file timing distribution

**Semantic axis**: identify files with disproportionate impact

**Methodology**:
- Use `racket tools/benchmark-tests.rkt --slowest 10` pre vs post
- Identify top-10 slowest files in each
- Investigate any file with > 2x its rolling median

**Decision rule**:
- File-level regression > 200%: investigate test file specifically
- New top-10 entrants: investigate

### S3 — Heartbeat counter deltas

**Semantic axis**: counter-level regression detection

**Methodology**:
- Per-file `cell_allocs`, `prop_firings`, `fuel-related counters` from `data/benchmarks/timings.jsonl`
- Compare pre vs post
- Per-test deltas + suite aggregate

**Decision rule**:
- Aggregate `cell_allocs` delta > +200: investigate which tests added cells (bounded delta from canonical fuel infrastructure expected: ~+5-10)
- Aggregate `prop_firings` delta > +100: investigate threshold propagator firing rate

### S4 — Probe verbose deltas

**Semantic axis**: per-command behavior verification

**Methodology**:
- Run `examples/2026-04-22-1A-iii-probe.prologos` with `#:verbose #t` pre vs post
- Compare per-command JSON output
- Verify semantic equivalence (output strings IDENTICAL post-Phase-1C)

**Decision rule**:
- Any output string mismatch: semantic regression — investigate
- Cell_allocs per-command delta > 5: investigate per-command cell allocation
- New counter values appearing: capture as expected (e.g., fuel-related counters)

---

## §10 Tier V — Parity validation (extending V1-V3)

V-series runs as regression tests in `tests/test-elaboration-parity.rkt`. Already established for prior phases per D.3 §9.1.

### V4 — Counter vs cell exhaustion equivalence (F-tropical)

**Semantic axis**: counter-vs-cell parity per D.3 §7.11

**Tests** (5+ representative workloads):
- V4.1 Typical elaboration: counter exhausts at step N; cell exhausts at equivalent cost-step
- V4.2 Prelude load: same exhaustion point
- V4.3 Deep type inference: same exhaustion point
- V4.4 Polymorphic resolution: same exhaustion point
- V4.5 Edge case: explicit budget override

**Hypothesis**: equivalent exhaustion points within step-counting equivalence (counter decrements 1/step; cell accumulates 1/step under uniform cost)

### V5 — ATMS-deprecated-API parity (1A-iii-b)

**Semantic axis**: behavior identical for non-ATMS-deprecated callers

**Tests**:
- V5.1 Pre-1A-iii-b: deprecated atms function calls; produce expected output
- V5.2 Post-1A-iii-b: deprecated atms function calls; produce error (correct behavior — function no longer exists)
- V5.3 Modern solver-state callers: behavior unchanged

### V6 — Surface ATMS AST elaboration parity (1A-iii-c)

**Semantic axis**: surface ATMS AST retirement parity

**Tests**:
- V6.1 Pre-1A-iii-c: surface forms parse + elaborate + reduce
- V6.2 Post-1A-iii-c: surface forms produce parse error (correct behavior — forms no longer exist)
- V6.3 Non-ATMS surface forms: behavior unchanged

---

## §11 Bench harness extension plan

### §11.1 Files to extend

| File | Extensions | LoC estimate |
|---|---|---|
| `racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt` | M7-M13 (7 micros) + A5-A12 (8 adversarial) + E7-E9 (3 E2E) + R1-R5 (5 memory-specific) | ~250-400 LoC |
| `racket/prologos/benchmarks/micro/bench-tropical-fuel.rkt` (NEW) | C1-C5 (algebraic correctness) + X1-X3 (multi-quantale composition) + dedicated tropical-fuel-specific micros | ~200-300 LoC |
| `racket/prologos/tests/test-elaboration-parity.rkt` | V4-V6 (parity validation) | ~80-150 LoC |
| `racket/prologos/tests/test-tropical-fuel.rkt` (NEW) | Phase 1B unit tests (covered by C-series + dedicated micros) | ~100-200 LoC |

**Pre-0 phase (NOW)**:
- Extend `bench-ppn-track4c.rkt` with Pre-impl baselines for M7-M13 + A5-A12 + E7-E9 + R1-R5 (counter-side)
- Document hypothesis tables + decision rules inline
- Run pre-impl baselines; capture data to `data/benchmarks/`

**Post-Phase-1B phase**:
- Create `bench-tropical-fuel.rkt` with C1-C5 + X1-X3
- Create `test-tropical-fuel.rkt` per D.1 §9.6
- Run C/X-series + Phase 1B comparison

**Post-Phase-1C phase**:
- Re-run M/A/E/R-series post-impl side
- A/B comparison data

**Post-Phase-1A-iii-b/c phase**:
- Re-run V-series

### §11.2 Bench-mem macro use

The existing `bench-mem` macro (bench-ppn-track4c.rkt:73) measures wall-clock + allocation bytes + post-GC retained bytes + GC count. **Use `bench-mem` for ALL M/A/E/R tests where memory is relevant** (not the simpler `bench` which is wall-clock-only).

Pattern:
```racket
(bench-mem "Mn label" RUNS body-expr)
;; → JSON output: { label, runs, mean_ms, alloc_bytes, retained_bytes, gc_count }
```

For tests where memory IS the primary signal (R-series + memory-focused M-series), report memory metrics first; wall-clock secondary.

### §11.3 A/B comparison via bench-ab.rkt

For E-series + R-series A/B comparisons across pre/post-impl boundary:
- Use `racket tools/bench-ab.rkt --runs 15 --output pre-impl-baseline.json benchmarks/micro/bench-ppn-track4c.rkt` for pre-impl baseline
- Re-run post-impl with `--ref pre-impl-baseline.json` for statistical comparison
- Mann-Whitney U test for significance

### §11.4 Heartbeat counter integration

Per `process-file path #:verbose #t` (from MEMORY.md "Track 7 Phase 0b Addition"): emits `VERBOSE:{json}` per command with 12 fields including `cell_allocs`, `prop_firings`, `cost_accumulated` (NEW for this addendum).

Add `cost_accumulated` (or similar) to PERF-COUNTERS for tracking tropical fuel impact at per-command level.

---

## §12 Execution methodology

### §12.1 Pre-0 baseline phase (NOW)

1. Extend `bench-ppn-track4c.rkt` with M7-M13 + A5-A12 + E7-E9 + R1-R5 sections (~250-400 LoC)
2. Each test gets:
   - Pre-impl baseline measurement code
   - Hypothesis comment block
   - Decision rule comment block
   - bench-mem macro for dual-axis measurement
3. Run baseline:
   ```
   racket racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt > data/benchmarks/tropical-pre0-baseline.json
   ```
4. Inspect data; verify reasonableness (no anomalies)
5. Document baseline in this Pre-0 plan as appendix (§12.5 below; populate post-execution)

**Estimated Pre-0 setup time**: 60-90 min for code addition; 15-30 min for execution.

### §12.2 Post-Phase-1B phase

1. Create `bench-tropical-fuel.rkt` with C1-C5 + X1-X3 + dedicated tropical-fuel micros (~200-300 LoC)
2. Run C-series for algebraic correctness verification (assertion-based)
3. Run X-series for multi-quantale composition verification
4. Capture data; compare against hypotheses

**If C-series fails**: critical bug; halt before Phase 1C migration.

**If X-series fails**: revisit multi-quantale composition NTT design (D.1 §4.2)

### §12.3 Post-Phase-1C phase

1. Re-run M/A/E/R series post-impl side
2. Compare to pre-impl baselines:
   ```
   racket tools/bench-ab.rkt --ref data/benchmarks/tropical-pre0-baseline.json benchmarks/micro/bench-ppn-track4c.rkt
   ```
3. Verify hypotheses; investigate any decision-rule-triggering deviations

### §12.4 Post-Phase-1A-iii-b/c phase

1. Run V-series parity tests
2. Verify ATMS retirement parity per V5/V6

### §12.5 Pre-0 baseline data (populated incrementally per tier execution)

#### M-tier baselines (executed 2026-04-26, commit `f6576479`)

Source: `racket/prologos/data/benchmarks/tropical-pre0-baseline-2026-04-26.txt`

| Test | Pre-impl wall | Pre-impl alloc | Pre-impl retention | Notes |
|---|---|---|---|---|
| M1 that-read :type | 30 ns/call | n/a (read-only) | n/a | Existing baseline (matches PRE0) |
| M1 that-read absent | 30 ns/call | n/a | n/a | Existing baseline |
| M2 fresh-meta | 40 μs/call | n/a (M-bench wall-only) | n/a | Existing baseline (matches STEP2 §11) |
| M2 solve-meta! | 44 μs/call | n/a | n/a | Existing baseline |
| M2 meta-solution | 47 μs/call | n/a | n/a | Existing baseline (CHAMP path) |
| M3 infer lam | 447 μs/call | n/a | n/a | Existing baseline |
| M3 infer app | 545 μs/call | n/a | n/a | Existing baseline |
| M3 infer Pi | 348 μs/call | n/a | n/a | Existing baseline |
| **M7.1 struct-copy decrement n=1** | **24 ns/call** | (see M7.mem) | (see M7.mem) | NEW — n-independent |
| **M7.2 n=100** | **25 ns/call** | (see M7.mem) | (see M7.mem) | n doesn't affect single-op cost |
| **M7.3 n=10000** | **24 ns/call** | (see M7.mem) | (see M7.mem) | n doesn't affect single-op cost |
| **M7.mem 10000 decrements** | **0.11 ms (11 ns/dec)** | **625 KB (62.5 bytes/dec)** | **-0.1 KB (no growth)** | **HYPOTHESIS CORRECTED**: actual is 62.5 bytes/dec (predicted 200-300 bytes); 4x more efficient |
| **M8.1 inline (<= fuel 0) not-exh** | **6 ns/call** | n/a | n/a | NEW — TIGHT bar for threshold |
| **M8.2 boundary** | 6 ns/call | n/a | n/a | NEW |
| **M8.3 exhausted** | 6 ns/call | n/a | n/a | NEW |
| **M9.1 net-new-cell N=1** | **16 μs/call** (incl make-prop-network) | **6.5 KB** | **0.3 KB** | NEW |
| **M9.2 N=5 sequential** | 17 μs (3.4 μs/cell) | 9.2 KB (1.8 KB/cell incl base) | 0.2 KB | NEW |
| **M9.3 N=50 sequential** | 61 μs (1.2 μs/cell) | 74.6 KB (1.5 KB/cell) | 0.2 KB | NEW |
| **M9.4 N=500 sequential** | **264 μs (0.5 μs/cell)** | **625 KB (1.25 KB/cell at scale)** | 0.3 KB | NEW — per-cell amortization confirmed |
| **M10 residuation operator** | N/A pre-impl | N/A | N/A | Deferred to post-Phase-1B (operator doesn't exist) |
| **M11.1 fixnum +** | **1 ns/call** | 0 | 0 | NEW — tropical tensor essentially free |
| **M11.2 large fixnum +** | 1 ns/call | 0 | 0 | NEW |
| **M11.3 +inf.0 + finite** | 1 ns/call | 0 | 0 | NEW (+inf.0 propagation works at fixnum cost) |
| **M12 SRE registration** | N/A pre-impl | N/A | N/A | Deferred to post-Phase-1B |
| **M13 prop-network-fuel access** | **6 ns/call** | 0 | 0 | NEW (struct-field access; matches M8 inline) |

#### A-tier baselines (existing A1/A2 + new A5-A12 PENDING)

| Test | Pre-impl wall | Pre-impl alloc | Pre-impl retention | Notes |
|---|---|---|---|---|
| A1a 10 metas same | 3.36 ms | 13354 KB | -8.2 KB | Existing baseline |
| A1b 20 metas different | 6.58 ms | 24513 KB | -18.6 KB | Existing baseline |
| A2a 10 spec cycles no branch | 0.07 ms | 57.3 KB | 1.2 KB | Existing baseline |
| A2b 10 spec cycles 3 metas | 0.09 ms | 102.0 KB | 1.4 KB | Existing baseline |
| **A5 cost-bounded vs flat** | TBD | TBD | TBD | NEW — pending A-tier execution |
| **A6 deep dep chain N=10/200** | TBD | TBD | TBD | NEW — Phase 3C UC1 forward-capture |
| **A7 high-freq 1k/100k decrement** | TBD | TBD | TBD | NEW — memory pressure |
| **A8 multi-consumer 10×1000** | TBD | TBD | TBD | NEW |
| **A9 100 spec cycles rollback** | TBD | TBD | TBD | NEW |
| **A10 5-branch fork** | TBD | TBD | TBD | NEW — Phase 3A forward-capture |
| **A11.1-4 pathological costs** | TBD | TBD | TBD | NEW |
| **A12 residuation boundaries** | N/A pre-impl | N/A | N/A | Post-Phase-1B (operator doesn't exist) |

#### E-tier baselines (existing E1-E4 + new E7-E9 PENDING)

| Test | Pre-impl wall | Pre-impl alloc | Pre-impl retention | Notes |
|---|---|---|---|---|
| E1 simple no metas | 55.23 ms | 17968 KB | -4.8 KB | Existing |
| E2 parametric Seqable | 169.53 ms | 346445 KB | -11.0 KB | Existing (alloc outlier — Phase 7 target) |
| E3 polymorphic id | 90.80 ms | 65419 KB | 9.5 KB | Existing |
| E4 generic arithmetic | 93.48 ms | 54278 KB | 26.0 KB | Existing |
| **E7 realistic + fuel** | TBD | TBD | TBD | NEW — pending E-tier extension |
| **E8 deep type-inference** | TBD | TBD | TBD | NEW |
| **E9 cost-bounded** | TBD | TBD | TBD | NEW — Phase 3C UC2 forward-capture |

#### R-tier (memory as PRIMARY signal) — PENDING execution

| Test | Pre-impl alloc rate | Pre-impl retention growth | GC count/dur | Notes |
|---|---|---|---|---|
| R1 per-decrement alloc rate | TBD | TBD | TBD | NEW |
| R2 retention after quiescence | TBD | TBD | TBD | NEW |
| R3 GC pressure under load | TBD | TBD | TBD | NEW |
| R4 compound vs flat layout | TBD | TBD | TBD | NEW |
| R5 long-running speculation | TBD | TBD | TBD | NEW |

#### S-tier — captured at suite-level

| Test | Pre-impl baseline | Notes |
|---|---|---|
| S1 full suite wall | 119.3s (S2.e-v close) | Existing |
| S4 probe verbose | 28 commands; cell_allocs=1181 | Existing |
| S2 per-file distribution | (use `tools/benchmark-tests.rkt --slowest 10`) | Existing tooling |
| S3 heartbeat counter deltas | (compare timings.jsonl pre vs post) | Existing tooling |

#### V-tier — N/A pre-impl (parity tests run post-impl)

V4-V6 verify counter-vs-cell + ATMS retirement parity. Run post-Phase-1C and post-Phase-1A-iii-b/c.

### §12.6 Key Pre-0 findings from M-tier execution (2026-04-26)

Inform D.2 design revision + Phase 1B/1C execution discipline:

**Finding 1 — Hypothesis correction on M7.mem allocation rate**:
- Predicted: 200-300 bytes/decrement
- **Actual baseline: 62.5 bytes/decrement** (4x more efficient than predicted)
- Implication: cell-write needs to stay under ~125 bytes/dec to satisfy DR (1.25-2x baseline). TIGHTER than previously thought; tagged-cell-value entry layout under universe-active worldview needs careful design.

**Finding 2 — M8 sets a TIGHT bar for threshold propagator**:
- Inline `(<= fuel 0)` check: 6 ns/call
- DR triggers if no-trigger threshold propagator overhead > 100% (12 ns total)
- A propagator fire (worklist entry + dispatcher + fire-fn) is realistically ~100-600 ns
- **Implication**: threshold propagator approach almost certainly FAILS the DR for the no-trigger case
- **Design response**: consider HYBRID approach — inline `(<= fuel 0)` fast-path at decrement sites (preserve current cost) PLUS threshold propagator for contradiction-write side effect. Inline check stays cheap; threshold propagator only fires on actual exhaustion (rare event).
- This reframes Phase 1C: the canonical fuel cell can have a threshold propagator, but the inline check at decrement sites should remain. The propagator's job is to write contradiction ON exhaustion, not to perform per-write check.

**Finding 3 — M9 per-cell amortization works**:
- N=1: 16 μs (incl make-prop-network setup) / 6.5 KB
- N=500: 0.5 μs/cell / 1.25 KB/cell at scale
- Implication: per-consumer fuel cell allocation is feasible at typical N (1-50 per net); marginal cost decreases at scale

**Finding 4 — M11 tropical tensor essentially free**:
- All variants: 1 ns/call; 0 allocation
- `+inf.0` propagation works at fixnum cost
- Implication: tropical tensor implementation has zero perf overhead concerns; representation choice (Q-1B-2: `+inf.0` vs sentinel) can be made on architectural grounds, not perf

**Finding 5 — Counter substrate is REMARKABLY cheap**:
- Combined: M7 (24 ns) + M8 (6 ns) + M13 (6 ns) = ~36 ns total per decrement+check+read cycle
- Cell-based path will be slower in absolute terms (cell-write ~30-50 ns + cell-read ~30-50 ns = 60-100 ns + threshold propagator overhead)
- The architectural-correctness trade-off (Q-A2 substrate-level + canonical instance) costs ~2-3x in absolute decrement+check cycle time
- **Decision implication for D.2**: this is acceptable per "structurally correct over hot-path optimal" framing IF the inline-check hybrid (Finding 2) preserves the per-decrement cost. Without hybrid, full cell-based path is expensive enough that we should reconsider.

---

## §13 Decision rules summary table

Consolidated decision rules — what design changes if hypothesis fails:

| Hypothesis failure | Design response | Affects |
|---|---|---|
| M7 wall > 2x struct-copy | Reconsider canonical instance approach (per-consumer only?); revisit Q-A2 | Phase 1B/1C |
| M7 memory > 3x struct-copy | Investigate tagged-cell-value overhead; non-tagged variant for canonical fuel cell | Phase 1B |
| M7 GC > 2x | Object pooling for tagged-cell-value entries | Phase 1B |
| M8 no-trigger wall > 100% inline | Reconsider threshold propagator architecture (inline check at decrement site as alternative) | Phase 1B/1C |
| M9 non-O(1) | Reconsider per-consumer feasibility; pool-based allocation | Phase 1B |
| M9 memory > 1KB/cell | Investigate cell value layout | Phase 1B |
| M10 wall > 100 ns | Optimize residuation operator (open-coded comparison) | Phase 1B |
| M11 wall > 50 ns | Investigate Racket `+` for relevant numeric domain | Phase 1B |
| M11 memory non-zero | Choose representation (Q-1B-2) more carefully | Phase 1B |
| M12 wall > 1 ms | Lazy property inference vs at-registration | Phase 1B |
| M13 wall > 100 ns | Pre-resolved cell-id cache | Phase 1C |
| A5 post-impl exhausts at step count | Bug in tensor accumulation | Phase 1B |
| A5 unbounded memory growth | Investigate tagged-cell-value retention | Phase 1B |
| A6 walk cost > 1ms for N=200 | Reconsider Phase 3C UC1 (lazy walk vs eager) | Phase 3C scope |
| A7 allocation rate > 5x | Object pooling | Phase 1B |
| A7 wall regression > 100% | Reconsider threshold propagator | Phase 1B |
| A8 non-linear scaling | Investigate per-consumer pollution | Phase 1B/1C |
| A9 memory leaks under rollback | S(-1) tagged-cell-value cleanup bug | Phase 1B + S(-1) coordination |
| A10 retention after resolution > O(M) | Retracted branch state leaks | Phase 3A scope |
| A11 post-impl incorrect exhaust point | Cost accumulation bug | Phase 1B |
| A12 boundary case incorrect | Residuation operator implementation bug | Phase 1B |
| C1-C5 fails | **Critical correctness bug — halt before Phase 1C** | Phase 1B |
| X1 cross-interference | Investigate shared state contamination | Phase 1B + multi-quantale design |
| X2 round-trip violates Galois | Bug in bridge interface OR Galois assumption misunderstood | Multi-quantale NTT |
| X3 quantale-of-bridges fails | Scope down to single-quantale-only for Phase 1B | Multi-quantale NTT |
| E7 wall regression > 10% | Investigate hot-path overhead | Phase 1C |
| E7 memory regression > 20% | Investigate retention semantics | Phase 1C |
| E8 regression > 25% | Reconsider threshold propagator (inline check fast-path) | Phase 1C |
| R1 alloc > 5x baseline | Object pooling | Phase 1B |
| R2 retention growth | Worldview accumulation issue | Phase 1B + S(-1) |
| R3 GC count > 3x | Object pooling | Phase 1B |
| R4 base > 1KB | Investigate cell layout | Phase 1B |
| R4 per-worldview > 200 bytes | Investigate tag-entry overhead | Phase 1B |
| R5 unbounded retention | S(-1) tagged-cell-value cleanup bug | Phase 1B + S(-1) |
| S1 wall > 130s | Suite regression > 10%; investigate S2 | Phase 1C |
| S3 cell_allocs delta > +200 | Investigate which tests added cells | Phase 1C |
| S4 output mismatch | Semantic regression | Phase 1C |

---

## §14 What Pre-0 might surface (design-affecting findings)

### §14.1 Likely outcomes (low risk)

- M7-M13 confirm cell ops are within constant factor of struct-copy / inline checks (per BSP-LE 0 baselines + S2 evidence)
- A-series confirm tropical fuel provides cost-aware exhaustion (not cost-blind step count)
- R-series confirm bounded memory growth (no unbounded accumulation)

### §14.2 Possible design-affecting findings (medium risk)

- M7 memory > 3x: would surface need for object pooling for tagged-cell-value entries
- M8 no-trigger overhead > 100%: would surface need for inline check fast-path at decrement sites
- A9 memory leak under rollback: would surface S(-1) cleanup issue requiring coordination
- A10 branch fork retention: would inform Phase 3A design for per-branch fuel cell management

### §14.3 Less likely but design-altering findings (high risk if surface)

- C1-C5 algebraic correctness failure: critical bug — halts Phase 1C
- A5 post-impl cost-blind: bug in tensor accumulation — critical
- X1 cross-quantale interference: revisit multi-quantale NTT design
- M9 non-O(1) per-consumer scaling: reconsider per-consumer feasibility

### §14.4 Unexpected findings (open)

Pre-0 may surface findings not anticipated in this plan. Examples from prior tracks:
- BSP-LE Track 0: transient CHAMPs slower at N=2-3 (prevented wrong optimization)
- SRE Track 1B: cold-start allocation dominated, not computation
- PPN 4C Phase 0 Pre-0: parametric Seqable allocated 343 MB / 19x baseline (drove Axis 1 architecture)

For tropical addendum: possible surfaces include surprising memory profile under speculation, unexpected GC behavior under high decrement rate, or compound cell value layout cost.

---

## §15 Cross-references

### §15.1 This addendum
- D.1 design: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — §13 sketches Pre-0 plan; this doc expands comprehensively

### §15.2 Methodology
- [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) Stage 3 "Pre-0 Benchmarks Per Semantic Axis"; "Measure before, during, AND after — and include memory cost"; "Memory cost is a separate axis from wall-clock"
- [DEVELOPMENT_LESSONS.org](principles/DEVELOPMENT_LESSONS.org) "Microbench-Claim Verification Pays Off Across Sub-Phase Arcs"
- [STEP2_BASELINE.md](2026-04-23_STEP2_BASELINE.md) §6 measurement discipline (bounce-back not gate); §6.1 microbench-claim verification rule

### §15.3 Bench infrastructure
- `racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt` — existing M1-M6 + A1-A4 + E1-E6 + V1-V3 tiers; bench-mem macro at line 73
- `racket/prologos/benchmarks/micro/bench-meta-lifecycle.rkt` — meta-specific benchmarks (Section A through F)
- `racket/prologos/benchmarks/micro/bench-alloc.rkt` — allocation benchmarks (per S2 baseline §3)
- `tools/bench-ab.rkt` — A/B comparison tool with Mann-Whitney U test
- `tools/run-affected-tests.rkt` + `tools/benchmark-tests.rkt` + `data/benchmarks/timings.jsonl` — suite-level

### §15.4 Phase consumers
- Phase 1B: tropical fuel primitive (D.1 §9)
- Phase 1C: canonical BSP fuel migration (D.1 §10)
- Phase 1V: VAG closes Phase 1 (D.1 §11)
- Phase 3C UC1/UC2/UC3: D.1 §9.7 anticipated use cases (forward-capture)

### §15.5 Stage 1 research
- [TROPICAL_QUANTALE_RESEARCH.md](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — algebraic foundations
- [MODULE_THEORY_LATTICES.md](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — Q-modules + residuation
- [ALGEBRAIC_EMBEDDINGS_LATTICES.md](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — universal engine vision

---

## Document status

**Pre-0 plan drafted** — ready for execution. Per D.1 §17 "What's next" + §13 expanded comprehensively here.

**Next action**: extend `bench-ppn-track4c.rkt` with Pre-0 baseline measurements per §11.1 + §12.1; estimated ~250-400 LoC additions + ~15-30 min execution. Output to `data/benchmarks/tropical-pre0-baseline.json`. Populate §12.5 baseline table post-execution.

**Memory characterization elevated to first-class** per user direction 2026-04-26: every M/A/E/R test gets dual-axis (wall + memory) measurement via `bench-mem`; R-series dedicated to scenarios where memory IS the primary signal. This addresses the DESIGN_METHODOLOGY mandate that memory is a separate axis from wall-clock catching different problem classes (alloc rate, retention growth, GC pressure, per-cell layout).

**Decision rules consolidated** at §13 — every test has a clear failure → design-response mapping. Pre-0 findings either confirm hypotheses (proceed to D.2 with minor refinements) or trigger design-affecting investigation (D.2 incorporates findings; possibly revisits architectural decisions per §14.3).

**Comprehensive coverage**: 38 distinct test specifications across 8 tiers (M/A/C/X/E/R/S/V); all relevant axes covered (per-operation cost, adversarial stress, algebraic correctness, multi-quantale composition, end-to-end realistic workloads, memory-as-primary-signal, suite-level regression, parity validation). User directive "most comprehensive ... gather the most information we can" satisfied.
