# Research: Propagator Taxonomy — Parallel Profiles

**Date**: 2026-03-28
**Stage**: 0 (Research — informs design language and parallel scheduling)
**Context**: PAR Track 2 proved true parallel execution. PPN Track 1's set-latch pattern revealed a recurring structural pattern (fan-in → fan-out) that maps to array programming's reduce → map. This document formalizes propagator kinds by their parallel profile.

---

## 1. Motivation

Our propagators are currently untyped — the network treats all propagators identically. But they have distinct parallel profiles:

- Some read one cell and write one cell (map)
- Some read many cells and write one cell (reduce/barrier)
- Some read one cell and write many cells (broadcast/scatter)
- Some read many and write many (general)

Knowing the profile enables:
- **Scheduling optimization**: Map propagators benefit most from parallelism. Reduce propagators benefit from parallel input computation but serialize at the merge point.
- **Design language**: NTT syntax could express propagator kinds, making network architecture self-documenting.
- **Pipeline composition**: Multi-stage pipelines (lexer → tokenizer → tree builder) have stage-level parallel profiles.

---

## 2. Propagator Kinds

### 2.1 Map (1 → 1)

**Pattern**: Read one input cell, compute, write one output cell.
**Parallel profile**: Embarrassingly parallel. N map propagators fire independently.
**Examples**: Type lattice merge, value propagation, cell copy.
**BSP behavior**: All fire in one round. Maximum parallelism.

```
:propagator copy-value
  :reads  [cell-a]
  :writes [cell-b]
  :kind   :map
```

### 2.2 Reduce / Barrier (N → 1)

**Pattern**: Read N input cells, apply reduction, write one output cell. May have a readiness condition (fire only when all inputs are non-bot).
**Parallel profile**: Inputs can be computed in parallel (round K). Reduce fires when all inputs arrive (round K+1). Serializes at the output.
**Examples**: PPN set-latch (tree builder), narrowing rule evaluation (all bindings ready → evaluate RHS), constraint satisfaction (all domains narrowed → check).
**BSP behavior**: Waits for all inputs via residuation (fires, checks, returns net unchanged if not ready). When ready, fires once and writes result.

```
:propagator build-tree
  :reads  [token-rrb indent-rrb bracket-depth-rrb]
  :writes [tree-cell]
  :kind   :reduce
  :barrier all-non-bot
```

The **set-latch** is a special case of reduce where the merge function is set-union and the barrier is "set is complete" (no more elements expected). This is the PPN Track 1 pattern where all tokens must be collected before the tree builder fires.

### 2.3 Broadcast / Fan-Out (1 → N)

**Pattern**: Read one input cell, write to N output cells.
**Parallel profile**: The single fire produces N independent writes. Under BSP, these writes are applied in one merge pass. Downstream propagators (watching the N outputs) fire in the next round — in parallel.
**Examples**: SRE reconstructor (compound type → sub-cell values), parse tree → consumer notifications, session type → channel cells.
**BSP behavior**: Fires once, produces N writes. The writes themselves don't benefit from parallelism (they're in one fire function), but the DOWNSTREAM propagators do.

```
:propagator reconstruct-pvec
  :reads  [elem-cell]
  :writes [pvec-cell]
  :kind   :broadcast
```

### 2.4 Scatter (N → M)

**Pattern**: Read N inputs, write M outputs. The general case.
**Parallel profile**: Depends on the relationship between inputs and outputs. If each input maps to a disjoint subset of outputs (partitioned scatter), parallelism is high. If all inputs affect all outputs (full cross-product), parallelism is limited.
**Examples**: SRE structural decomposition (compound type → sub-cells + sub-propagators), elaborator Pi decomposition.
**BSP behavior**: Fires when any input changes. May produce topology (new cells, new propagators) — deferred to next round.

```
:propagator sre-decompose
  :reads  [cell-a cell-b]
  :writes [sub-cell-a sub-cell-b]
  :kind   :scatter
  :topology-creating #t
```

### 2.5 Gather (N → M, convergence)

**Pattern**: Read N inputs, accumulate into M outputs. Like reduce but with multiple output channels.
**Parallel profile**: Similar to reduce — inputs computed in parallel, gathering serializes.
**Examples**: Constraint propagation where multiple type cells narrow a constraint cell, multi-source session type checking.

```
:propagator gather-constraints
  :reads  [type-cell-1 type-cell-2 type-cell-3]
  :writes [constraint-cell]
  :kind   :gather
```

---

## 3. Compound Patterns

Real pipelines compose these kinds:

### 3.1 Map-Reduce

**Pattern**: N map propagators → 1 reduce propagator.
**Array programming analog**: `map f xs |> fold g init`
**Parallel profile**: Round 1: N maps fire in parallel. Round 2: reduce fires.
**Example**: PPN lexer (map: classify each character) → tokenizer (reduce: assemble tokens from classified characters).

### 3.2 Reduce-Broadcast (Fan-In → Fan-Out)

**Pattern**: N inputs → reduce → 1 intermediate → broadcast → M outputs.
**Array programming analog**: `fold |> scatter`
**Parallel profile**: Round 1: inputs computed in parallel. Round 2: reduce fires. Round 3: M downstream propagators fire in parallel.
**Example**: PPN token assembly (reduce: set-latch collects all tokens) → tree builder (broadcast: tree structure feeds consumers).

### 3.3 Scatter-Gather (Diamond)

**Pattern**: 1 input → scatter → N intermediates → gather → 1 output.
**Array programming analog**: `map f |> fold g` (but with topology creation in scatter phase)
**Parallel profile**: Round 1: scatter fires (topology creation — deferred). Round 2: N intermediate propagators fire in parallel. Round 3: gather fires.
**Example**: SRE structural decomposition of `PVec Int = PVec Nat`: scatter creates sub-cells + sub-propagators, intermediates unify sub-components, gather (reconstructor) rebuilds compound type.

---

## 4. Parallel Profile Annotations

Each propagator kind has quantifiable parallel characteristics:

| Kind | Fan-in | Fan-out | Parallelism | BSP Rounds | Topology |
|------|--------|---------|-------------|-----------|----------|
| Map | 1 | 1 | N independent | 1 | No |
| Reduce | N | 1 | Inputs parallel, reduce serial | 2 | No |
| Broadcast | 1 | N | Fire serial, downstream parallel | 2 | No |
| Scatter | N | M | Depends on partitioning | 2+ | Often |
| Gather | N | M | Inputs parallel, gather serial | 2 | No |

### `:auto` Heuristic Integration

The propagator kind informs the `:auto` scheduling heuristic:

- **Round with mostly Map propagators**: High parallelism. Use parallel executor if N > threshold.
- **Round with a single Reduce**: Low parallelism in this round. But the NEXT round (downstream of reduce) may be highly parallel.
- **Round with Scatter (topology-creating)**: Sequential in BSP (topology deferred). But subsequent rounds may have high parallelism from newly created propagators.
- **Pipeline detection**: If the network forms a pipeline (map → reduce → broadcast → map → ...), the scheduler can predict future parallelism from the pipeline structure.

---

## 5. Connection to NTT Syntax

In the NTT design language, propagator kinds could be first-class:

```ntt
;; Map propagator
:propagator :map type-merge
  :reads  [cell-a]
  :writes [cell-b]
  :fire   (fn [net] (net-cell-write net cell-b (net-cell-read net cell-a)))

;; Reduce propagator with barrier
:propagator :reduce build-tree
  :reads  [token-rrb indent-rrb bracket-depth-rrb]
  :writes [tree-cell]
  :barrier (fn [net inputs] (andmap non-bot? inputs))
  :fire    (fn [net] (build-tree-from-domains ...))

;; Scatter propagator (topology-creating)
:propagator :scatter sre-decompose
  :reads  [cell-a cell-b]
  :writes :dynamic  ;; outputs determined at fire time
  :fire   (fn [net] (sre-maybe-decompose ...))
  :topology #t
```

The `:kind` annotation enables:
- Static pipeline analysis (detect map-reduce patterns at network construction time)
- Scheduling hints (the runtime knows which rounds will benefit from parallelism)
- Documentation (the network topology is self-describing)

---

## 6. Connection to Array Programming

The propagator kinds map directly to array programming primitives:

| Propagator Kind | Array Op | APL/J | NumPy | Parallel Primitive |
|----------------|----------|-------|-------|-------------------|
| Map | map/each | `f"` | `np.vectorize` | `parMap` |
| Reduce | fold/reduce | `f/` | `np.reduce` | `parReduce` |
| Broadcast | broadcast | `f"0 1` | `np.broadcast` | `scatter` |
| Scatter | scatter | — | `np.put` | `scatter` |
| Gather | gather | — | `np.take` | `gather` |

This suggests that a future array programming sublanguage for Prologos could compile directly to propagator networks with the appropriate kinds, inheriting the parallel execution infrastructure automatically.

---

## 7. Connection to the Hyperlattice Conjecture

The Hyperlattice Conjecture states: "Any computation can be expressed as a fixpoint over interconnected lattice structures."

Propagator kinds describe HOW lattices interconnect:
- **Map**: Point-to-point lattice connection
- **Reduce**: Many-to-one lattice convergence
- **Broadcast**: One-to-many lattice divergence
- **Scatter/Gather**: Lattice restructuring (topology change)

The kind taxonomy is the **morphology** of the hyperlattice — describing the shapes of connections between lattice cells. Just as the lattice ORDER describes what values a cell can hold, the propagator KIND describes how cells influence each other.

---

## 8. Next Steps

1. **Annotate existing propagators**: Survey all propagator creation sites, classify by kind. This is an audit (Stage 2) that informs future optimization.
2. **Add kind field to propagator struct**: `(struct propagator (inputs outputs fire-fn kind))`. Kind is optional (defaults to `:general`).
3. **Use kind in `:auto` heuristic**: When deciding parallel vs sequential, weight by the kinds of propagators in the worklist.
4. **NTT syntax integration**: Express kinds in the design language.
5. **Pipeline detection**: At network construction time, detect map-reduce and scatter-gather patterns. Use for scheduling prediction.

---

## Sources

- PPN Track 1: Set-latch pattern in parse-reader.rkt (tree builder barrier)
- PAR Track 2: Parallel stress tests (fan-out vs chain performance profiles)
- PAR Track 2 Research: Souffl&eacute; semi-naive evaluation (partitioned relations)
- Hyperlattice Conjecture (docs/research/2026-03-26_LATTICE_FOUNDATIONS.md)
