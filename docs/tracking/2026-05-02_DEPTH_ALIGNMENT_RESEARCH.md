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

---

## Revision 2 (2026-05-02) — Collaborator critique: CALM, stratification, Pocket Universes

After F.5/F.6 shipped, a collaborator pushed back with a deeper architectural critique. Quoting:

> "I would encourage it to think of doing this, not as 'propagator chains' to 'synchronize' — this will break under different schedulers. What it's doing is essentially non-monotonic. According to the CALM theorem, anything on a single stratum should be coordination-free. If you need coordination, ordering, retraction, topological network changes, negation, accumulation — anything non-monotonic, the answer is always: STRATIFICATION. Do this reduction as a stratification in its own PU (Pocket Universe). Review the prior art."

Research into the codebase confirms this is the project's stated discipline, and F.5/F.6 are implementing a tactical workaround to a problem whose strategic solution is stratification. This revision documents the critique, the prior art, and what the strategic solution would actually look like.

### What F.5/F.6 are actually doing (reframed)

The framing in §1-§9 above ("synchronous pipelining via Z⁻¹ delay elements") is operationally accurate but architecturally misleading. The accurate framing:

**Tail-recursive iteration is fundamentally non-monotonic.** State cells get *overwritten* each iteration with new values. That's a retraction (the previous iteration's value is gone), not a monotone refinement. Per CALM, retraction inside a stratum is an anti-pattern.

**F.5/F.6's identity bridges are forcing ordering inside a single S0 stratum** to make the non-monotone iteration produce coherent values. That ordering is exactly what CALM forbids: BSP guarantees coordination-free monotone fixpoints, which doesn't apply to our iteration semantics.

**What we should be doing**: stratify. Each iteration is a stratum boundary; within an iteration, all operations are monotone (read state, compute step, propose next state); between iterations, the iteration stratum non-monotonically commits next-state values to state cells.

### The project's canonical CALM rule

Per [`.claude/rules/stratification.md`](../../.claude/rules/stratification.md) lines 64-83 ("When to Consider a New Stratum"):

> "Reach for a new stratum when a computation:
> - Is **non-monotone**: it can retract information (the result can decrease, not just grow). S0 is monotone by CALM; non-monotone work belongs at a higher stratum.
> - Requires **fixpoint of another stratum** before evaluating: e.g., NAF needs S0 quiescence before checking provability.
> - Is **order-sensitive**: ordering comes from the stratum stack (Sk only fires after S0...S(k-1) quiesce), not from imperative control flow."

Tail-recursive iteration matches all three criteria. F.5/F.6 try to keep it inside S0 by inserting ordering machinery (depth bridges); the rule says: don't, escalate to a stratum.

### Prior art: PAR Track 0 CALM audit (2026-03-27)

The cleanest precedent is documented in `docs/tracking/2026-03-27_PAR_TRACK0_CALM_AUDIT.md`. SRE decomposition (`sre-core.rkt:456-435`) and narrowing (`narrowing.rkt:304-323`) had fire functions that performed non-monotone topology changes inside S0 — creating new propagators dynamically based on input values.

The fix direction: **don't do topology changes inside S0; emit a topology-change request as a cell value, and let the topology stratum process the request between rounds**. Same pattern: separate the monotone observation (request emission) from the non-monotone action (topology change), with a stratum boundary between them.

F.5/F.6 are doing the symmetric thing: rather than emitting "advance iteration" as a request handled by an iteration stratum, they're forcing the entire iteration into S0 with delay-line bridges. The right move is the same as PAR Track 0's: stratify.

### Prior art: SRE Track 2G scatter case (2026-03-30)

The canonical "we needed a Pocket Universe" case study. Phase 6 of SRE Track 2G originally proposed an elaborate PU with internal stratification for implication-rule scattering. The NTT model caught a non-monotone scatter operation hidden inside the design. The PIR's lesson (`SRE_TRACK2G_PIR.md` §5, Pattern 5):

> "NTT modeling catches architectural impurities (2/2 tracks that used it)."

The actual Phase 6 implementation was 30 lines of eager evaluation (no PU yet), with technical debt explicitly accepted: "Implication rules as eager function (not network propagators) — Elaborate Pocket Universe design is Track 3-4 scope. Scaffolding is 30 lines."

F.5/F.6 are in the same situation: they're scaffolding (eager bridges-as-ordering) standing in for a more architecturally-correct future (PU + iteration stratum).

### What "iteration as a Pocket Universe" would look like

Per the codebase definitions:

- **Pocket Universe** (`docs/research/2026-03-21_PROPAGATOR_NETWORK_TAXONOMY.md` §9.3 + `docs/research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md` §4.3a): a scoped sub-network with its own stratification + worldview, communicating with the parent network only via designated entry/exit cells.

- **Stratum** (`.claude/rules/stratification.md`): a request-accumulator cell + handler function, registered via `register-stratum-handler!`. After S0 quiescence, the BSP outer loop invokes registered handlers.

A PU + iteration stratum design for tail-recursion:

```
Parent network
   │
   │  init args (cells)
   ▼
┌──────────────────────────────────────────────┐
│ Pocket Universe: tail-rec iteration          │
│                                              │
│  S0 (within PU):                              │
│    state cells (a, b, n)                      │
│    step body propagators (read state →        │
│      compute "next-state proposals")          │
│    cond propagator (read state → compute      │
│      "should continue" Bool)                  │
│    monotone, coordination-free, BSP fixpoint  │
│                                              │
│  Iteration stratum (within PU):               │
│    Handler runs after S0 quiescence.          │
│    Reads cond cell + next-state-proposal      │
│      cells.                                   │
│    If cond = continue: commit proposals to    │
│      state cells (non-monotone overwrite),    │
│      reset S0 worklist, reenter S0.           │
│    If cond = halt: read result cell, exit PU. │
│                                              │
└──────────────────────────────────────────────┘
   │
   │  result (cell)
   ▼
Parent network
```

**Properties of this design**:

1. **CALM-compliant**: S0 within the PU is fully monotone. Each iteration's S0 fixpoint computes next-state PROPOSALS (monotone refinement), then exits to the iteration stratum which COMMITS them (non-monotone, but in its own stratum).

2. **No identity bridges needed**: depth alignment is handled by S0 fixpoint within an iteration. All step values coherently reflect "the current iteration's state" because they all read from the same state cells which are stable during S0.

3. **Termination is structural**: cond cell is read by the iteration handler, which decides whether to re-enter S0 or exit. No fuel needed; no cyclic feedback edges in the network.

4. **Scheduler-independent**: works under BSP, work-stealing, topological-order, or any other scheduler that guarantees S0 fixpoint before stratum handlers run. F.5/F.6's bridges, by contrast, are tied to BSP's specific snapshot-then-merge semantics — they would break under e.g. a Datalog-style seminaive scheduler that fires propagators in topological order.

5. **Composable**: PUs can nest. An iteration whose body itself contains an iteration becomes a PU within a PU.

### Cost of the PU + stratification approach

**Kernel changes required**:

1. **Nested networks**: the kernel must support sub-networks (cells + propagators scoped to a PU; not visible from outside). Currently the Zig kernel has one flat cell array.

2. **Stratum handler infrastructure**: between S0 rounds, run registered handlers. Currently the kernel only has S0; no handler hook.

3. **PU lifecycle**: install PU → run to S0 quiescence → invoke iteration handler → either re-enter S0 (advance iteration) or exit (read result cell, propagate to parent).

4. **Per-PU statistics**: rounds, fires, iteration count separate from the parent network's stats.

**Estimated effort**: ~5-10 days for the kernel infrastructure; ~2-3 days for the lowering changes (`ast-to-low-pnet.rkt` emits PU declarations instead of feedback edges); ~2-3 days for the LLVM lowering (`low-pnet-to-llvm.rkt` emits `prologos_pu_*` calls instead of identity bridges); ~2 days for tests + acceptance file updates.

**Total**: ~10-15 days of focused work. Substantial but well-scoped.

### Trade-off: what F.5/F.6 actually buy us, vs the strategic cost

This is the honest accounting:

**F.5/F.6's wins**:
- Shipped today, no kernel changes
- 34 acceptance examples pass
- Pell works
- ~10-25% structural overhead per program (real cost)

**F.5/F.6's hidden costs**:
- Architecturally violates CALM (non-monotone iteration enforced via ordering inside S0)
- Tied to BSP semantics; would break under other schedulers
- Doesn't match the project's stated stratification discipline
- Each future translator (NTT, expr-iterate, …) inherits the same anti-pattern
- The depth-balance invariant we added (F.6) is a SYMPTOM of the missing stratum: we're checking that bridges balance the network *because we need ordering inside what should be a monotone stratum*

**PU + iteration stratum's wins**:
- CALM-compliant; aligns with project discipline
- Scheduler-agnostic
- No bridge cells; smaller networks
- Composable (nested PUs)
- Each future translator gets stratification-aware lowering for free

**PU + iteration stratum's costs**:
- ~10-15 days of kernel + lowering work
- Multi-stratum runtime is genuinely new infrastructure
- Larger scope, more risk

### Revised recommendation

F.5 + F.6 are correctly identified as **scaffolding**, not the strategic solution. They ship today because the strategic solution (PU + iteration stratum) requires kernel infrastructure we don't have yet.

**Position F.5/F.6 explicitly as scaffolding** in the project tracking (analogous to SRE Track 2G's "30-line eager Phase 6 scaffolding"), with the strategic followup tracked as a future track.

**The strategic followup** ("Sprint G: tail-rec as Pocket Universe with iteration stratum") becomes the canonical tail-rec lowering once kernel multi-stratum infrastructure lands. At that point F.5/F.6's bridges + retiming + depth-balance invariant get retired.

**Don't do retiming optimization (F.6 was the optimization layer over F.5) beyond what's already shipped** — investing more in F.6's optimization is investing in scaffolding that gets retired when stratification lands.

**Reorder the SH track sequence** so PU + stratification is closer to the front:

| Sprint | Was (per SH_LOWERING_FEATURE_MAP) | Revised |
|---|---|---|
| F.5 / F.6 | tactical lag-matching | tactical scaffolding (shipped) — leave as-is |
| G | Heap + GC for runtime | **PU + iteration stratum** (architectural correctness — retires F.5/F.6) |
| H | Heap + GC for runtime | (was G) |

This reordering is justified by: F.5/F.6 are a known CALM violation. Each new translator we build on top inherits the violation. Retiring it earlier means less debt accumulation.

### Generalization beyond tail-rec

The same critique applies to several places in the project:

- **PReduce / Track 9** (per agent research §4): currently designed to fire reduction propagators in S0 alongside type propagators. But reduction is incremental and CAN retract if a meta solution changes. This is the same pattern: non-monotone behavior being forced into S0. The CALM-aware design would put reduction in its own stratum or PU.

- **SRE Track 2G Phase 6** (already known): eager evaluation as scaffolding; PU is Track 3-4 scope.

- **Constraint retry** (metavar-store.rkt): currently uses set-latch fan-in within a single stratum. Per the rules, this is correct — readiness AGGREGATION is monotone. But the action triggered (constraint retry) is non-monotone and lives in L2 Resolution stratum. So this case is already CALM-compliant.

- **The set-latch refactor I considered for F.5b**: would have been a wrong move. Set-latch is for monotone readiness aggregation, not for non-monotone iteration. Confirmed by the agent research: "Set-latch is the right pattern for fan-in readiness across heterogeneous sources, which we don't have yet at the runtime level."

### What the research doc said in revision 1 vs revision 2

**Revision 1**: "F.5 is the right pattern for our problem; retiming optimization (F.6) is the principled improvement."

**Revision 2**: "F.5/F.6 are tactical scaffolding for an architectural problem (non-monotone iteration in a monotone stratum). The strategic fix is PU + iteration stratum. Ship F.5/F.6, but mark them as scaffolding and prioritize the strategic followup."

The collaborator was right. Three reasons revision 1 missed it:

1. **Frame-confusion**: revision 1 framed the problem as "synchronous pipelining" — a hardware/circuit metaphor where Z⁻¹ delays are the primitive. That metaphor is operationally accurate but architecturally misleading; in our software substrate, the right metaphor is "non-monotone iteration in a CALM-aware stratification system."

2. **Tactical-vs-strategic conflation**: revision 1 evaluated each option's correctness + cost but didn't distinguish "is this a tactical fix or a strategic structure." F.5/F.6 are tactical; the strategic fix is PU + stratum.

3. **Underweighting prior art**: the project has a clear `stratification.md` rule and a documented CALM-audit precedent (PAR Track 0). Revision 1 cited propagator-design.md and on-network.md but missed stratification.md as the load-bearing rule.

### Lessons (process, distilled)

1. **The mantra catches structural debt; the rules catch CALM debt.** When a fix feels like it's solving a synchronization problem inside a monotone stratum, that's the smell. The answer is almost always "stratify, don't synchronize."

2. **"Pocket Universe" is the project's idiom for stratified-sub-network**. When in doubt about how to handle non-monotone sub-computations, reach for PU before reaching for in-stratum scaffolding.

3. **Tactical fixes aren't shameful, but mark them as such**. SRE Track 2G's 30-line eager Phase 6 was correct to ship. The mistake would have been pretending it was the architectural solution. F.5/F.6 should be marked the same way.

4. **The depth-balance invariant in F.6 is itself a smell**. Inventing a structural invariant to enforce ordering inside a monotone stratum is the opposite of CALM. Future "we need an invariant to enforce X inside a stratum" should trigger the question: "should X be a stratum?"

### Updated open questions

In addition to the open questions in revision 1:

6. **What's the minimum-viable kernel infrastructure for PU + iteration stratum?** Could it be implemented as a "scheduler outer loop with handlers", without rearchitecting cells? (Probably yes — the BSP-LE Track 2B project already has `register-stratum-handler!` as a pattern; we'd port that to the Zig kernel.)

7. **Can the PU realization be incremental?** Could we add stratum-handler infrastructure to the kernel WITHOUT immediately migrating F.5/F.6, and then migrate program-by-program? Or does it need to be all-or-nothing?

8. **What does this say about PReduce / Track 9?** PReduce currently designs reduction-on-S0; same critique applies. Should PReduce design be updated to use a reduction stratum or PU before implementation begins?

9. **NTT semantics + iteration**: when NTT lands, will user-written `propagator` declarations be allowed to express "this is an iteration; it lives in its own PU"? Or do iteration boundaries have to be inferred from the AST shape (as F.5's tail-rec recognizer does)?

These should drive the SH track resequencing if the critique is accepted.

### References (revision 2 additions)

- `docs/tracking/2026-03-27_PAR_TRACK0_CALM_AUDIT.md` — the canonical "non-monotone behavior in S0 → stratify" precedent
- `docs/research/2026-03-21_PROPAGATOR_NETWORK_TAXONOMY.md` §9.3 — Pocket Universe as structural decomposition
- `docs/research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md` §4.3a — Pocket Universe as worldview boundary (ATMS branches)
- `docs/tracking/2026-03-30_SRE_TRACK2G_PIR.md` §5 (Pattern 5), §8 — the "30-line eager scaffolding for what's structurally a PU" case study
- `docs/tracking/2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md` — PReduce design, currently with the same in-S0 anti-pattern
- `racket/prologos/propagator.rkt:2441` — `register-stratum-handler!` API (the runtime pattern to port)
- `racket/prologos/relations.rkt:115` — S1 NAF: example of a non-monotone stratum implemented via the handler API
- `racket/prologos/metavar-store.rkt:1392` — S(-1) Retraction: another non-monotone stratum precedent
