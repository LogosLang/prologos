# Depth Alignment in BSP Propagator Networks — Research

**Created**: 2026-05-02
**Status**: Stage 0/1 — research synthesis. Documents the trade-off space discovered while iterating on Sprint F.5 (lag-matching bridges) and explores in detail one rejected option (scheduler-level depth tracking) so future work can reference it without re-deriving.
**Origin**: User pushback on Sprint F.5's network-level fix — "shouldn't this be solved in the scheduler instead?"
**Cross-references**: [`SH_LOWERING_FEATURE_MAP.md`](2026-05-01_SH_LOWERING_FEATURE_MAP.md), [`BSP_NATIVE_SCHEDULER.md`](2026-05-01_BSP_NATIVE_SCHEDULER.md), [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md), [`.claude/rules/structural-thinking.md`](../../.claude/rules/structural-thinking.md).

## Problem statement

In the Zig-runtime BSP propagator network, when a tail-recursive computation has nested arithmetic (e.g., Pell's `int-add(int-mul(2, b), a)`), the inputs to the outer `int-add` arrive at different BSP rounds. `int-mul(2, b)` takes one extra round to commit its result vs `a` which is read directly from state. The outer `int-add` reads inputs from the snapshot in its firing round; if the snapshot has stale values for some inputs and fresh values for others, the result mixes iterations of the recurrence and produces wrong values that propagate through feedback into the state cells.

**Sprint F.5** fixed this by inserting identity-propagator "bridges" — Z⁻¹ delay elements — on shorter paths so all inputs to a multi-input propagator have equal depth (max-input-depths + 1). All paths through the network are then balanced; reads at each BSP round are coherent.

The architectural question that prompted this research: is putting *delay elements in the network* the right design, or should the *scheduler* handle synchronization automatically?

## Theoretical framework

### Synchronous dataflow languages (Lustre, Esterel, Faust, SCADE)

The canonical primitive is the **unit-delay operator**: Lustre's `pre`/`->`, Faust's `mem`, Esterel's `pause`. Compilers verify the **synchronous hypothesis** — at every logical clock tick, every signal has exactly one well-defined value — and reject programs where two paths into a combinational node have different cycle counts unless `pre` is inserted to balance them.

So the formal answer in this lineage is: **explicit unit-delay nodes, with a typing discipline**. F.5's identity bridges are `pre` operators in disguise.

### Kahn process networks / static dataflow

Pure KPN doesn't have this problem because channels are unbounded FIFOs; depth differences manifest as latency, not data corruption. Static dataflow (Lee–Messerschmitt SDF) restores it: the compiler computes a balanced periodic schedule from token production/consumption rates. Path-balancing is automatic in the schedule, not in the network structure.

### Signal flow graphs / DSP design

Standard form is the Z-transform: `z⁻¹` denotes a unit delay. Circuits are normalized so every cycle has at least one `z⁻¹` and every fan-in node sees inputs of equal latency. Tooling (Simulink, Ptolemy) inserts delay buffers automatically.

### BSP literature (Valiant 1990; Pregel; GraphLab; Giraph)

BSP itself has no depth problem within a superstep — the model *is* "all messages from round k delivered before round k+1." Pregel programs use vote-to-halt + multi-superstep convergence, with no notion of intra-step combinational depth: every operation is one superstep. The implicit answer: **make every operator one superstep** — no nested combinational logic. If you have nested arithmetic, you've collapsed two BSP steps into one and the model breaks.

### Hardware retiming (Leiserson–Saxe 1991)

Retiming is the canonical compile-time pass: given a circuit with delays and combinational logic, move delays across gates to minimize clock period subject to functional equivalence. It's an LP / min-cost-flow problem; runs in polynomial time. The relevant sub-problem for us is **register balancing** — distribute delays so all paths into each combinational node have equal register count.

### Software pipelining / modulo scheduling (Rau, Lam)

Used in VLIW compilers. Builds a steady-state schedule where loop iterations overlap; resolves cross-iteration dependencies via rotating register files or explicit MOV inserts. The conceptual cousin of F.5: extra MOVs on short paths so iterations align.

### Token-tagged dataflow (MIT Tagged-Token, Manchester Dataflow Machine, Naiad, Differential Dataflow)

Each value carries an iteration tag (or multi-dimensional timestamp); an operator fires only when *all* inputs with matching tags have arrived. No structural alignment needed — the matching store does it dynamically at runtime cost (hash-keyed buffer per operator, frontier propagation in Naiad).

## Survey of techniques

| # | Technique | Description | Trade-offs |
|---|---|---|---|
| 1 | **Identity bridges (F.5)** | Insert no-op propagators on shorter paths | ✅ zero kernel change, local fix, structurally explicit. ❌ O(depth) extra cells/props per misaligned op; static depth only |
| 2 | **Retiming pass** | Compile-time min-cost-flow that places delays optimally | ✅ provably optimal in delay count; well-understood. ❌ requires building DAG and running LP — but tractable |
| 3 | **Set-latch handshake** | Each consumer waits until all producers have signaled "ready in round k" | ✅ matches `propagator-design.md`'s codified pattern. ❌ requires monotone-set cells + round-tagging — neither in i64 kernel |
| 4 | **Token-tagged dataflow** | Each value carries iteration tag; operator fires when matching tags align | ✅ most general. ❌ every cell becomes `(tag, i64)`; rearchitects kernel; per-operator matching store |
| 5 | **Speculative execution + rollback** | Fire eagerly with stale inputs; detect mismatch; rollback | ✅ keeps pipeline full. ❌ per-cell version vectors, rollback log; non-monotone, breaks CALM |
| 6 | **Manual barriers (CUDA `__syncthreads`)** | Programmer inserts sync points | ❌ BSP already has barriers per round; this is what we have, doesn't address sub-step ordering |
| 7 | **Pure FRP `Behavior`/`Signal`** | Continuous-time semantics; sample at well-defined times | ❌ implementations either compile to synchronous-dataflow (back to (1)) or pull-based lazy eval (different evaluation model entirely) |
| 8 | **Scheduler-level depth tracking** | Annotate per-cell depth/round; gate firing in scheduler | (Detailed below — rejected but documented) |
| 9 | **Software clock domains** | Insert latching cells at boundaries where rates differ | ❌ Same kernel cost as set-latch; only relevant for multi-rate, which we don't have |

## Scheduler-level depth tracking (detailed exploration)

The user's instinct: depth is a temporal/synchronization concern, which feels like a scheduler responsibility. This section explores what implementing it in our Zig kernel would actually require.

### Design sketch

Each cell gains metadata: `last_changed_round`, the BSP round when its value last actually committed (changed). When a propagator fires, the scheduler checks: are all my inputs at "matching" round numbers? If yes, fire. If no, defer to a later round.

Concrete kernel additions:

```zig
// New per-cell metadata (16 KB at MAX_CELLS=1024 with u64 fields)
var cell_last_round: [MAX_CELLS]u64 = [_]u64{0} ** MAX_CELLS;

// New per-propagator metadata: compile-time-computed depth
var prop_depth: [MAX_PROPS]u32 = undefined;

// Modified install: caller (codegen) passes precomputed depth
export fn prologos_propagator_install_2_1_with_depth(
    tag: u32, in0: u32, in1: u32, out0: u32, depth: u32
) u32 { ... prop_depth[pid] = depth; ... }

// Modified cell_write: tag the round
fn cell_write_in_round(id: u32, value: i64, round: u64) void {
    if (cells[id] != value) {
        cells[id] = value;
        cell_last_round[id] = round;
        // schedule subscribers
    }
}

// Modified fire: gate based on input round coherence
fn fire_against_snapshot(pid: u32, current_round: u64) bool {
    const r0 = cell_last_round[prop_in0[pid]];
    if (prop_shape[pid] >= SHAPE_2_1 and cell_last_round[prop_in1[pid]] != r0) {
        // inputs at different rounds — defer this fire
        return false;
    }
    if (prop_shape[pid] == SHAPE_3_1 and cell_last_round[prop_in2[pid]] != r0) {
        return false;
    }
    // ... existing fire logic
    return true;
}
```

### What this buys

The Low-PNet IR no longer needs identity bridges. A program with mixed-depth step expressions emits exactly the propagators needed:

- Pell pre-F.5: 24 cells / 21 props (with bridges)
- Pell with scheduler depth tracking: ~12 cells / 10 props (no bridges)

That's roughly 50% reduction in cell/prop count for depth-2 programs. For depth-1 programs (fib, sum, factorial), savings are smaller (~3 cells per program from removed pre-select uniform lift bridges).

### What it costs — the actual gory details

#### 1. The "round number" is ambiguous in cyclic networks

BSP rounds are linear (1, 2, 3, ...). But the FEEDBACK identity propagator (next-state → state) writes to a state cell, advancing its `last_round`. This conflates "logical iteration" with "BSP round." Concretely:

For Pell's iteration:
- Round 5: state[a] commits new value (iteration 1's result).
- Round 6: subscribers of state[a] fire (int-mul, int-add). They WROTE on round 5's snapshot (= iteration 0 values). Their outputs commit at round 6 with `last_round = 6`.
- Round 7: int-add fires reading state[a] (last_round=5) and int-mul output (last_round=6). **Round mismatch.**

But this mismatch is *correct* — int-mul's output reflects iteration 0's state, while state[a] now holds iteration 1. They're FROM DIFFERENT ITERATIONS, just like F.5's lag-mismatch problem.

Fix attempt: maintain a separate **"iteration"** counter per cell. The feedback identity advances `iteration` of state cells; arithmetic propagators inherit the *minimum* iteration across their inputs. Propagators fire only when all input iterations match.

But this requires explicit feedback-edge marking (which propagators advance iteration vs which don't), and the kernel doesn't know which is which — the install API doesn't distinguish.

#### 2. Compile-time depth annotation API

The kernel needs each propagator to know its depth. So `propagator_install_*` gains a `depth` parameter, computed by the lowering. This means the lowering still needs the depth tracking we have today (`cell-depth` map in the builder). The only thing that changes: instead of inserting bridges, emit propagator with depth annotation.

So the depth-tracking infrastructure on the lowering side **does NOT go away** — it migrates from "insert bridges" to "annotate propagators."

#### 3. Pre-fire gate adds branching to fire dispatch

Every propagator fire now does 1-2 extra cell-array reads + comparisons before the actual fire. For tight inner loops (millions of fires), this overhead is real. Estimate: per-fire overhead increases ~2-5ns (from current ~12-20ns).

For Pell at N=92, with 50% fewer fires (no bridges), the wall time would be:
- Current: 1868 fires × 15.3 ns = 28.6 μs
- Hypothetical: 934 fires × ~18 ns (gate overhead) = 16.8 μs

Savings: ~12 μs. Real but small at our current scale.

#### 4. Worklist semantics get complicated

When a fire is *deferred* (inputs not at matching rounds), what happens?

Option A: Re-enqueue at end of round; fire again next round. Risk: infinite re-queue if rounds never align (bug somewhere).
Option B: Delete from current worklist; re-add when ANY input changes again. Risk: missed fires if inputs settle but propagator was missed.

Both options need careful invariants to avoid deadlock or starvation. In F.5's bridge approach, the BSP scheduler is "dumb" — it just fires what's enqueued. With scheduler-level gating, the scheduler becomes responsible for FAIRNESS and PROGRESS guarantees.

#### 5. Multi-thread BSP (Sprint D) becomes much harder

The round counter and per-cell `last_round` are SHARED STATE across threads. Updates need synchronization. With F.5's bridge approach, threads see the same snapshot and write to disjoint `pending_writes` regions — no shared mutable state during fires. With scheduler-level depth tracking, every fire does a synchronized read of `cell_last_round`. This is a significant scaling penalty.

#### 6. Doesn't compose with future worldview tags

When PPN convergence brings worldview-tagged cells to the runtime, every cell becomes `(worldview_bitmask, value)`. If we ALSO add `last_round` per cell, we have THREE pieces of metadata per cell (value, worldview, round). Token-tagged dataflow (option 4) generalizes both worldview tags AND iteration tags into one `timestamp` field. Adding scheduler-level `last_round` NOW would create a parallel metadata mechanism that gets ripped out when token-tagged lands.

#### 7. Compile-time savings disappear

The Low-PNet IR is "smaller" (no bridges) but the LLVM IR is "larger" (extra parameter to every install_2_1 / install_3_1 call, depth computation per call site, gate check inline). For typical programs, the IR diff is roughly a wash.

### Estimated cost

| Component | Effort |
|---|---|
| Kernel: per-cell + per-prop metadata fields | ~0.5 day |
| Kernel: modified install + cell_write + fire dispatch | ~1 day |
| Kernel: worklist re-enqueue / fairness guarantees | ~1-2 days |
| Lowering: emit depth annotations instead of bridges | ~1 day |
| Tests: cyclic network correctness, deferred fire, no-deadlock | ~1-2 days |
| Multi-thread compatibility audit (when Sprint D lands) | ~unknown |
| **Total** | **~5-7 days minimum** |

### Verdict on scheduler-level depth tracking

**Rejected.** Concrete reasons:

1. **Off-network metadata violates the design mantra**. Per `.claude/rules/on-network.md`: "everything on the propagator network. No exceptions. Off-network state is debt against self-hosting." Per-cell round counters in scheduler memory are exactly off-network state.

2. **Cyclic-network ambiguity is a real correctness hazard**. The "round" concept doesn't naturally extend to feedback loops. To fix it, we'd need to model "iteration" separately from "round," which is a big jump toward token-tagged dataflow without committing to the full architecture.

3. **Worst-case savings are modest**. For typical programs, ~50% reduction in cell/prop count for depth-2 programs (Pell), ~20% for depth-1 (fib). Wall time savings ~10-20 μs at our current scale.

4. **Multi-thread cost is significant**. Sprint D's plan for shared-nothing BSP becomes shared-something — a step backward for parallelism.

5. **Doesn't compose with future tags**. When worldview/iteration tagging arrives, this work gets retired.

The trade-off would be acceptable IF (a) we had no other depth-alignment options, (b) cell/prop budget were tight in our common case, or (c) we were committing to non-token-tagged for the long-term. None of these hold.

## Mantra alignment scorecard

| Technique | "All-at-once" | "All in parallel" | "Structurally emergent" | "On-network" | Verdict |
|---|---|---|---|---|---|
| 1. Identity bridges (F.5) | ✓ | ✓ | ✓ (depth IS topology) | ✓ (cells + props) | **Aligned** |
| 2. Retiming pass | ✓ | ✓ | ✓ | ✓ (compile-time over (1)) | **Aligned** |
| 3. Set-latch | ✓ | ✓ | ✓ | ✓ (codified in design rules) | **Aligned** |
| 4. Token-tagged | ✓ | ✓ | ✓ (tags ARE structure) | ✓ (per-cell tags) | **Aligned long-term** |
| 5. Speculation | ✗ | ✗ | ✗ | ✗ (rollback log) | **Violates CALM** |
| 6. Manual barriers | — | ✓ (BSP=barriers) | ✗ | — | **Already have it; doesn't solve** |
| 7. FRP | ✗ | depends | ✗ | ✗ (different model) | **Wrong paradigm** |
| 8. Scheduler depth | ✓ | ✗ (synchronized state) | ✗ (off-network) | ✗ (in-scheduler metadata) | **Violates mantra** |
| 9. Clock domains | ✓ | ✓ | ✓ | ✓ (cell-based) | **Aligned but unneeded** |

## Long-term trajectory

| Future feature | Affects depth alignment? | Best fit |
|---|---|---|
| **Sprint D — multi-thread BSP** | Yes — shared metadata is costly | Bridges (thread-local fires) > scheduler depth (shared `last_round`) |
| **PPN Track 4 — compiler on network** | Yes — compiler will need iteration semantics | Token-tagged (matches worldview tags) |
| **PReduce / Track 9** | Maybe — readiness through value lattice | Set-latch (value-domain readiness) > depth tracking |
| **Effects / capabilities runtime** | Yes — non-monotone choices | Token-tagged (handles speculation cleanly) |
| **Logic / solve runtime** | Yes — backtracking + alternatives | Token-tagged (worldview-aligned) |
| **NTT — user-written propagators** | Yes — explicit depth in source? | Retiming pass over user-declared topology |

**Debt-free path**: bridges (F.5) today → retiming pass (F.6 candidate) → token-tagged (when worldview tags land at runtime).

**Debt-creating paths**: scheduler-level depth tracking, speculation, manual barriers.

## Recommendation

**Primary**: keep F.5's identity-bridge runtime; add a compile-time **retiming pass** over Low-PNet IR before code emission.

The retiming pass:

1. Builds a DAG of Low-PNet propagators with edge weights = combinational depth (= 1 per binary op, 0 per identity).
2. For each multi-input propagator, computes `max_depth(inputs)` and inserts `max_depth - depth_i` identity bridges on each shorter input path.
3. **Coalesces** redundant bridges — if multiple consumers share a producer at depth d and need it at depth d', share the bridge chain.
4. Asserts post-condition: every multi-input propagator has equal depth on all input paths.

**Cost**: ~1.5 dev-days (1 day pass + ½ day tests + property-test on bridge invariant). Zero kernel changes.

**Wins**:
- Bridge coalescing reduces cell/prop count for programs with multiple lifts from the same source (estimated 25-30% reduction for Pell-shape programs)
- Decouples depth alignment from the tail-rec recognizer; future translators (NTT, expr-iterate) get balancing for free
- Provides a checkable post-condition; F.5's invariant becomes property-tested rather than per-pattern-trusted

**Defer**:
- Token-tagged dataflow until worldview/iteration tags land at runtime layer (likely PPN convergence or Sprint D's multi-thread design)
- Set-latch refactor until kernel has monotone-set + threshold-gate primitives
- Scheduler-level depth tracking — never; off-network metadata, debt-creating

**Test plan**:
1. **Depth-balance invariant**: post-pass property test that every multi-input propagator's input cells have equal max-distance from any source cell. Random-expression-tree → retime → check invariant.
2. **Iteration correctness**: every existing tail-rec acceptance file passes (regression).
3. **Coalescing**: a synthetic program where 5 consumers share a producer at depth 3 should have 3 (not 15) identity bridges. Assert via `prologos_get_stat` for prop count.
4. **No-regression on simple programs**: fib, sum, factorial cell/prop counts at most ±1 from current (allowing for coalescing wins on the pre-select uniform lift).

## Lessons distilled (process)

1. **The mantra catches off-network state proposals reliably.** When the user pushed back with "shouldn't this be in the scheduler?", the rule book had the answer in `on-network.md`. Took a research detour to confirm, but the rules pointed the right direction.

2. **Naming things correctly accelerates reasoning.** Calling F.5's bridges "scaffolding" yesterday led me to think they should be replaced. Calling them "Z⁻¹ delays" or "synchronous pipelining stages" reveals they're the canonical primitive of synchronous dataflow.

3. **Trade-off matrices need three columns: cost / benefit / mantra alignment.** Two-column comparisons (cost / benefit) miss the architectural debt creation. The mantra column is what flagged scheduler-level tracking as wrong despite its perf savings.

4. **Token-tagged dataflow is the long-term shape**. It's currently latent in the project (worldview-bitmask tagging at the elaborator). When/if runtime cells gain tags, F.5's bridges become a special case, not technical debt — they get retired naturally.

5. **The Leiserson-Saxe retiming algorithm is directly applicable**. We don't need to invent a new technique; the retiming pass IS the formal name for what F.5 does ad-hoc.

## References

### Theoretical
- Valiant, "A Bridging Model for Parallel Computation" (1990, BSP)
- Leiserson & Saxe, "Retiming Synchronous Circuitry" (1991, Algorithmica)
- Lee & Messerschmitt, "Static Scheduling of Synchronous Data Flow Programs" (1987, IEEE Trans. Computers)
- Murray et al., "Naiad: A Timely Dataflow System" (SOSP 2013)
- Halbwachs et al., "The Synchronous Data Flow Programming Language LUSTRE" (1991)

### Project artifacts
- [`docs/tracking/2026-05-01_BSP_NATIVE_SCHEDULER.md`](2026-05-01_BSP_NATIVE_SCHEDULER.md) § BSP cycle structure
- [`docs/tracking/2026-05-01_SH_LOWERING_FEATURE_MAP.md`](2026-05-01_SH_LOWERING_FEATURE_MAP.md) § "Sprint F.5: lag-matching bridges"
- [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md) § Set-Latch for Fan-In Readiness
- [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md) § Migration Checklist
- [`.claude/rules/structural-thinking.md`](../../.claude/rules/structural-thinking.md) § "Direct Sum Has Two Realizations"
- `racket/prologos/ast-to-low-pnet.rkt:103-180` — F.5's `emit-aligned-propagator!` and `lift-cell-to-depth`
- `runtime/prologos-runtime.zig:1-66` — Zig kernel surface
- `runtime/test-bsp-feedback.c` — kernel-level BSP feedback validation

## Open questions for future research

1. **What happens when union-typed conditional has branches of different depths?** F.5 currently doesn't lower union types. When it does, the per-component select cascade may have branches with different depths. The retiming pass should handle this naturally; verifying is open work.

2. **Can DAG depth analysis identify "always-fresh" cells?** Some cells (literals, init constants) never change — propagators reading them never have stale values from those inputs. Depth analysis could exclude them, reducing bridges. Estimated savings: 1-2 bridges per literal-input propagator. Small.

3. **Does retiming with multi-output propagators (when we add them) compose?** Currently all our propagators are (k, 1). Future operators with (k, m) shape complicate retiming. Open.

4. **What's the cost model for depth-balance bridges in cache terms?** Bridge cells live in the same i64 cell array as data cells. If they're heavily used in inner loops, cache pressure goes up. Empirical investigation worthwhile when scale grows.

5. **At what scale does token-tagged dataflow become competitive?** For our current kernel (i64 cells, simple kernels), bridges win on simplicity. For ~10K-cell programs with deep nesting and multi-rate behavior, the constant overhead of `(tag, value)` cells might be amortized by removing thousands of bridges.

This research note will be revisited if/when worldview tagging lands at the runtime layer; the conclusions above may invert at that point.
