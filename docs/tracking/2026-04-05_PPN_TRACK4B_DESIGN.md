# PPN Track 4B: Side-Effect Migration — Stage 2/3 Design

**Date**: 2026-04-05
**Series**: [PPN (Propagator-Parsing-Network)](2026-03-26_PPN_MASTER.md) — Track 4B
**Predecessor**: [PPN Track 4A D.4](2026-04-04_PPN_TRACK4_DESIGN.md) — Elaboration as Attribute Evaluation
**Predecessor PIR**: [PPN Track 4A PIR](2026-04-04_PPN_TRACK4_PIR.md)
**Status**: Stage 2 (Audit complete) / Stage 3 (Design thinking in progress)

---

## §0 Objectives

**End state**: Retire the imperative `infer/check` fallback. 100% of type inference is on-network. ALL side effects (trait resolution, constraint creation, meta solving, multiplicity checking, coercion warnings) are propagator firings or cell operations.

**Track 4A delivered**: 46% on-network typing, ephemeral PU architecture, SRE typing domain (~150 expr kinds), bidirectional app writes, context-as-cells. Zero regressions.

**Track 4A identified the blocker**: the imperative `infer` produces side effects alongside type computation. Moving type computation on-network (46%) is straightforward. Moving side effects on-network is the remaining 54%.

**What Track 4B delivers**:
1. Constraint creation as cell operations (unification constraints on the ephemeral typing PU)
2. Trait resolution as constraint propagators (P1 pattern: type → constraint narrowing)
3. Meta solution bridging (ephemeral → main network via PU output channels)
4. Multiplicity checking as propagator computation (QTT on-network)
5. Coercion warning emission as cell-based detection
6. Retire the imperative fallback (infer-on-network/err becomes the ONLY path)

---

## §1 Stage 2 Audit Findings

### The Side-Effect Inventory

The imperative `infer` produces these side effects alongside type computation:

| Side Effect | Imperative Function | Propagator Equivalent (exists) | Status |
|-------------|--------------------|---------------------------------|--------|
| Create meta | `fresh-meta` | Meta position in type-map (⊥) | Track 4A Pattern 2 |
| Solve meta | `solve-meta!` | Cell write (downward write fills position) | Track 4A Pattern 1 |
| Create unification constraint | `add-constraint!` | `elab-add-unify-constraint` → structural-unify-propagator | **Ready** |
| Resolve trait | `resolve-trait-constraint!` | `resolve-trait-constraint-pure` + bridge fire fn | **Ready** |
| Resolve hasmethod | `resolve-hasmethod-constraint!` | `resolve-hasmethod-constraint-pure` | **Ready** |
| Retry constraint | `retry-unify-constraint!` | `retry-unify-constraint-pure` + action-retry-constraint | **Ready** |
| Check multiplicity | `checkQ` / `compatible` | Mult cells + type↔mult bridge | **Ready** |
| Emit warning | `emit-*-warning!` | None (accumulating cell needed) | **New** |

### Existing Infrastructure (from Stage 2 audit)

**All pieces exist.** The constraint narrowing patterns (P1-P4), structural decomposition, trait resolution (monomorphic + parametric), multiplicity bridge, and resolution dispatcher are all implemented. The gap is WIRING — connecting these to the ephemeral typing PU.

### The Architectural Question: PU Output Channels

Track 4A's ephemeral PU model (create, run, read, discard) works for pure type computation. But side effects need to PERSIST — constraint cells, meta solutions, and trait resolutions must survive the ephemeral network's lifecycle.

---

## §2 The Propagator Design Mindspace: Four Questions for Side Effects

### Question 1: What is the INFORMATION?

Each side effect IS information:
- "These two types must agree" (unification constraint)
- "This trait instance resolves to this dictionary" (trait resolution)
- "This meta has this value" (meta solution)
- "This variable is used N times" (multiplicity)
- "This operation involves cross-family coercion" (warning)

All of these are FACTS that accumulate monotonically. They fit the lattice model.

### Question 2: What is the LATTICE?

- **Constraint**: pending → resolved → contradicted (Phase 6 lattice, already built)
- **Trait resolution**: unresolved → resolved(dict-expr) (same constraint lattice structure)
- **Meta solution**: ⊥ → concrete type (type lattice on meta positions)
- **Multiplicity**: m0 ≤ m1 ≤ mw (mult lattice, already on-network)
- **Warning**: empty → (listof warning) (accumulating set, monotone)

### Question 3: What is the IDENTITY?

Each side effect has a CELL:
- Unification constraint = a PAIR of type-map positions that must agree (the merge at a shared position)
- Trait constraint = a constraint cell watching argument type positions
- Meta solution = a type-map position transitioning from ⊥ to concrete
- Multiplicity = a mult cell bridged to a type cell
- Warning = a warning cell accumulating diagnostics

### Question 4: What EMERGES?

The fully-typed, fully-resolved, fully-checked expression EMERGES from all cells reaching quiescence:
- All type-map positions have concrete types (no ⊥, no metas)
- All trait constraints are resolved (dict-metas filled)
- All multiplicity checks pass (usage compatible with declarations)
- All warnings accumulated (reported to user)
- Contradiction (type-top) at any position = type error with ATMS trace

---

## §3 Architecture: PU with Output Channels (Option C from §15)

### The Model

The typing PU has DEFINED OUTPUT CHANNELS — cells on the MAIN elab-network that the PU writes to. The PU is ephemeral internally, but its outputs persist.

```
Main elab-network:
  form cell ← parse tree + pipeline (existing)
  typing result cell ← root type (PU output channel 1)
  meta solution cells ← one per meta (PU output channel 2)
  trait constraint cells ← one per trait constraint (PU output channel 3)
  mult check cells ← one per variable (PU output channel 4)
  warning accumulator cell ← diagnostics (PU output channel 5)

  Ephemeral typing PU (internal prop-network):
    Type-map positions (expression → type)
    Context positions (scope → context cell value)
    Constraint positions (unification → agreement check via merge)
    Trait resolution propagators (P1 pattern: type → constraint narrowing)

    Quiesces internally → writes outputs to main network channels
    GC'd after quiescence
```

### How It Works

1. **Create output channel cells** on the main elab-network (one per meta, one per trait constraint, one for the root type, one for warnings).

2. **Create ephemeral typing PU** (fresh prop-network).

3. **Install typing propagators** (existing: `install-typing-network` + SRE domain).

4. **Install constraint propagators** inside the PU:
   - For each `expr-app` with a Pi function type: the bidirectional write to the arg position IS the unification constraint (type-lattice-merge).
   - For structural decomposition (Pi vs Pi): install `make-structural-unify-propagator` on sub-cells within the PU.
   - For trait constraints: install P1 propagator (type → constraint narrowing) within the PU.

5. **Run to quiescence** on the ephemeral network.

6. **Bridge outputs to main network**:
   - Read root type from type-map → write to typing result cell on main network.
   - For each solved meta position: call `solve-meta!` on the main elab-network.
   - For each resolved trait constraint: the constraint cell value persists.
   - For multiplicity: the mult cell values persist via bridge.
   - For warnings: accumulate to warning cell.

7. **Discard ephemeral PU** (GC).

### Why Output Channels, Not Integrated Network

The Track 4A investigation showed that adding typing propagators to the MAIN elab-network causes accumulation (timeout regression). The ephemeral PU avoids this. Output channels bridge the boundary cleanly — the PU's COMPUTATION is ephemeral, the RESULTS persist on the main network.

This is the same pattern as PPN Track 1-2: the parse tree PU computes internally, then `extract-surfs-from-form-cells` reads the result and dispatches it to the main pipeline.

---

## §4 Phase Plan

| Phase | Description | Depends On |
|-------|-------------|-----------|
| 1 | Output channel infrastructure: create cells on main network, bridge API | — |
| 2 | Trait constraint propagators in the typing PU (P1 pattern) | Phase 1 |
| 3 | Meta solution bridging (ephemeral → main via solve-meta!) | Phase 1 |
| 4 | Structural unification propagators in the PU (Pi/Sigma decomposition) | Phase 1 |
| 5 | Multiplicity checking propagators | Phase 1 |
| 6 | Warning emission as cell accumulation | Phase 1 |
| 7 | Retire imperative fallback (infer-on-network/err becomes sole path) | Phases 2-6 |
| T | Dedicated test file | Throughout |
| 8 | Phase 4b zonk retirement (from Track 4A) | Phase 7 |
| 9 | Phase 8 scaffolding retirement (from Track 4A) | Phase 7 |
| 10 | Verification + PIR | All |

### Parallelization

Phases 2-6 are PARALLEL after Phase 1. Each adds one side-effect category to the PU with its output channel. They can be developed and tested independently.

---

## §5 Prior Art and Existing Infrastructure

### Constraint Narrowing (constraint-propagators.rkt)

P1-P4 patterns are implemented and tested. P1 (type → constraint) is the core pattern for trait resolution. The typing PU installs P1 propagators alongside typing propagators — when a type-map position gains a value, the P1 propagator narrows the trait constraint.

### Structural Decomposition (elaborator-network.rkt)

`make-structural-unify-propagator` + `maybe-decompose` handle Pi/Sigma/app/generic structural unification. Sub-cells are created for decomposition, reconstructors rebuild parent types. Bare metas are reused via `identify-sub-cell` + `current-structural-meta-lookup`.

This infrastructure operates on the prop-network — it can be used INSIDE the ephemeral PU directly.

### Trait Resolution (trait-resolution.rkt + resolution.rkt)

`resolve-trait-constraint-pure` + `resolve-hasmethod-constraint-pure` are PURE FUNCTIONS (enet → enet*). They can be called from the PU output bridge without imperative state.

`make-trait-resolution-bridge-fire-fn` is already a PROPAGATOR fire function that wraps trait resolution. It syncs the elab-network, resolves, and writes back.

### Multiplicity (qtt.rkt + elaborator-network.rkt)

Mult cells exist. `elab-add-type-mult-bridge` creates cross-domain propagators (type → mult). The QTT inference (`inferQ`) computes usage alongside types. The mult lattice (m0 ≤ m1 ≤ mw) is already on-network.

---

## §6 Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Accumulation regression (from Track 4A Pattern 2) | High | Ephemeral PU with output channels — typing propagators don't persist on main network |
| Constraint propagator interaction with existing resolution loop | Medium | Phase 2 tests validate P1 pattern in isolation before integration |
| Meta solution bridging creates double-solve errors | Medium | Guard: only bridge metas that are unsolved on the main network |
| Performance regression from output channel overhead | Low | Track 4A showed cell ops are 300-1000× cheaper than typing computation |
| Multiplicity checking changes error behavior | Medium | Phase 5 validates error parity with imperative checkQ |

---

## §7 Cross-References

- [PPN Track 4A D.4](2026-04-04_PPN_TRACK4_DESIGN.md) — §15 Typing PU Architecture, §17 Three Frontiers
- [PPN Track 4A PIR](2026-04-04_PPN_TRACK4_PIR.md) — side-effect boundary finding, longitudinal survey
- [SRE Track 2H](2026-04-02_SRE_TRACK2H_DESIGN.md) — type-lattice quantale (merge = unification)
- [SRE Track 2D](2026-04-03_SRE_TRACK2D_DESIGN.md) — DPO rewrite rules, critical pair analysis
- [PPN Track 3](2026-04-01_PPN_TRACK3_DESIGN.md) — form cells, pipeline PU pattern
- [PM Track 8](2026-03-22_TRACK8_PIR.md) — elaboration network, ATMS, TMS worldview
