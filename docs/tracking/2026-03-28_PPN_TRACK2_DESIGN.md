# PPN Track 2: Surface Normalization as Propagators — Stage 3 Design (D.1)

**Date**: 2026-03-28
**Series**: PPN (Propagator-Parsing-Network)
**Prerequisite**: PPN Track 1 ✅ (propagator reader), SRE Track 2F ✅ (algebraic foundation)
**Audit**: `docs/tracking/2026-03-28_PPN_TRACK2_STAGE2_AUDIT.md`
**Research**: `docs/research/2026-03-26_TREE_REWRITING_AS_STRUCTURAL_UNIFICATION.md`

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0 benchmarks + adversarial | ✅ | `a0fd523`. Preparse invisible vs elaboration. 22-35μs/rule. |
| 1 | Rewrite rule registry | ⬜ | Rule struct, registration, cell-based lookup |
| 2 | Pure rewrite engine | ⬜ | 18 built-in rules as registered rewrites |
| 3 | Registry propagators | ⬜ | process-data/trait/spec → cell writes |
| 4 | Spec/where injection as propagators | ⬜ | Cross-stratum data flow |
| 5 | Fixpoint convergence | ⬜ | preparse-expand-form → propagator quiescence |
| 6 | Layer 2 integration | ⬜ | expand-top-level on network |
| 7 | macros.rkt retirement | ⬜ | Consumer migration, dead code removal |
| 8 | A/B benchmarks + suite verify | ⬜ | Performance-neutral, 383/383 GREEN |

**Phase completion protocol**: After each phase: commit → update tracker → update dailies → run targeted tests → proceed.

---

## §1 Objectives

Replace the imperative preparse pipeline in `macros.rkt` (9763 lines) with registered rewrite rules on the propagator network. Each syntactic transformation becomes a data-driven rule. The pipeline's 5-pass stratification emerges from propagator data flow, not from imperative loop ordering.

**Propagator Only constraint**: No algorithms. The rewrite rules are lattice values. The fixpoint computation IS propagator quiescence. Ordering emerges from data dependencies, not code structure.

**End deliverables**:
1. All 18 pure rewrites as registered SRE rewrite rules
2. 24 registries as cell-only (retire parameter dual-write)
3. Spec/where injection as data-flow propagators
4. preparse-expand-form convergence via propagator quiescence
5. Source ordering replaced by dependency ordering (Phase 5b unnecessary)
6. macros.rkt reduced by ~3000-5000 lines
7. 383/383 GREEN, zero behavioral change
8. Performance-neutral (A/B within noise)

---

## §2 Current State (from Audit)

### What works
- 48 preparse/expand functions across 2 layers
- 5-pass pipeline with strict forward DAG
- 24 registries with dual-write (parameter + cell)
- 18 pure rewrites with zero side effects
- Depth-100 fixpoint guard on macro expansion

### What's imperative
- 9763 lines of match/cond dispatch on form heads
- 5 passes enforced by sequential for-loops (not data flow)
- Registration = side effects (parameter mutation)
- Spec injection = cross-pass registry lookup
- Source ordering preserved by accumulator + Phase 5b hoisting
- Layer 2 (surf-* expansion) is a separate tree walk

### What the audit revealed
- **No backward dependencies**: Pass N never reads Pass N+1 results
- **Pass 0 is embarrassingly parallel**: all forms WRITE only, no READS
- **All rewrites are MONOTONE**: pure pattern→template, CALM-safe
- **Fixpoint is bounded**: depth-100 guard, structural progress per step
- **Dual-write infrastructure exists**: cells are already live, just not primary

---

## §3 Design

### 3.1 Architecture: Pipeline of Set-Once Cells (CALM-Compliant)

**CALM constraint (from DEVELOPMENT_LESSONS.org)**: Within a stratum, topology is fixed and all operations are monotone. Rewrites are NOT monotone (they replace values). Therefore rewrites MUST happen at stratum boundaries, not within a BSP round.

**The Layered Recovery Principle (from EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org)**: Non-monotone behavior is recovered by inserting control layers between phases of monotone computation. Rewrites are the control layer; value propagation is the monotone substrate.

**Form pipeline cells**: Each form progresses through a pipeline of **set-once cells**, one per rewrite stratum. A form that passes through 3 rewrite stages has 3 cells:

```
raw-datum-cell (⊥ → raw datum, set-once)
    → [V0 structural rewrite stratum]
v0-datum-cell (⊥ → structurally rewritten datum, set-once)
    → [V1 macro expansion stratum]
v1-datum-cell (⊥ → macro-expanded datum, set-once)
    → [V2 spec/where injection stratum]
v2-datum-cell (⊥ → injected datum, set-once)
    → [consumed by parser]
```

Each cell is set-once: ⊥ → value, never overwritten. This is trivially monotone. The "replacement" that rewrites perform happens BETWEEN strata — each stratum reads the previous stratum's output cell and writes to its own output cell. No cell is ever written twice.

**The registry cells**: 24 cells, one per registry. Already exist from `init-macros-cells!`. Currently secondary (dual-write); become primary. Each registry cell holds a CHAMP map (name → entry). Registry cells use set-union merge (adding entries is monotone).

**The dependency cell**: Tracks which forms depend on which registry entries. When a form references a constructor/trait/spec, a dependency edge is recorded. The elaborator processes forms in dependency order — no Phase 5b hoisting needed.

### 3.2 Rewrite Rules as Data

A rewrite rule is a first-class value:

```racket
(struct rewrite-rule
  (name          ; symbol — for debugging/tracing
   pattern       ; datum pattern with holes (e.g., '(let $name := $val $body))
   template      ; datum template with same holes (e.g., '((fn [$name] $body) $val))
   guard         ; (datum → boolean) or #f — additional match condition
   priority      ; natural — higher fires first (for overlapping patterns)
   stratum)      ; natural — which pass/stratum this rule belongs to
  #:transparent)
```

Registration is declarative:

```racket
(register-rewrite-rule!
 (rewrite-rule 'expand-let
               '(let $name := $val . $body)
               '((fn [$name] . $body) $val)
               #f    ;; no guard
               100   ;; priority
               0))   ;; stratum 0 (pure rewrite)
```

The 18 pure rewrites from the audit become 18 rule registrations. No functions, no closures — just data describing the transformation.

### 3.3 Pattern Matching via SRE

Rewrite rule matching uses the SRE's **idempotent relation** (Track 2D: rewriting). The pattern is the LHS, the template is the RHS. SRE decomposition extracts bindings (the `$name`, `$val`, `$body` holes). SRE reconstruction builds the output from the same bindings.

This reuses existing SRE machinery:
- `sre-decompose-generic` for LHS matching
- Reconstruction propagators for RHS composition
- Sub-cell binding for shared variables

The only new piece: the rewriting relation is **directional** (match LHS → produce RHS, not bidirectional unification). This is the SRE Track 2D relation kind — already designed in the algebraic foundation (Track 2F's endomorphism ring has an 'idempotent row in the variance-map).

### 3.4 Stratified Execution (CALM-Compliant)

The pipeline maps to propagator strata. Each stratum has FIXED topology and monotone operations within it. Rewrites happen AT stratum boundaries (Layered Recovery Principle).

```
Stratum R(-1): Namespace/imports
  Propagators: ns-loader, import-resolver
  Writes to: trait-registry cell (prelude), module-registry cell
  Topology: fixed (no new cells/propagators)

Stratum R(0): Declaration pre-registration
  Propagators: data-registrar, trait-registrar, deftype-registrar,
               defmacro-registrar, bundle-registrar, etc.
  Reads: raw-datum-cells
  Writes to: ctor-registry cell, trait-registry cell, preparse-registry cell, etc.
  CALM-safe: all WRITE to registry cells (set-union merge, monotone)

Stratum R(1): Dependent registration
  Propagators: spec-registrar, impl-registrar
  Reads: trait-registry cell, bundle-registry cell (from R(0))
  Writes to: spec-store cell, impl-registry cell
  CALM-safe: reads are of cells written in prior stratum (fixed)

--- REWRITE STRATA (Layered Recovery) ---

Stratum V(0): Structural rewrites
  Input cells: raw-datum-cells (set-once, from R(0))
  Output cells: v0-datum-cells (set-once, written here)
  Rules: implicit-map → dot-access → infix (priority-ordered WITHIN stratum)
  Topology: fixed (input cells + output cells created at stratum setup)
  CALM-safe: each propagator READS input cell, WRITES output cell (both set-once)
  Priority ordering within V(0):
    1. implicit-map (reshapes form structure — must fire first)
    2. dot-access (depends on implicit-map output)
    3. infix operators (depends on dot-access output)
  These are priorities, not sub-strata — they fire in priority order
  within one BSP round on fixed topology.

Stratum V(1): Macro expansion
  Input cells: v0-datum-cells (set-once, from V(0))
  Output cells: v1-datum-cells (set-once, written here)
  Rules: preparse-registry lookup + template substitution
  Topology: fixed
  CALM-safe: reads input + registry cells, writes output cell

  RECURSIVE MACROS: A macro that expands to another macro form
  creates a CHAIN of V(1) sub-strata:
    V(1,0): first expansion
    V(1,1): expand the expansion
    V(1,2): expand again
    ...
    V(1,N): no more macros match → terminal
  Each sub-stratum reads the previous sub-stratum's output cell.
  Depth limit: N ≤ 100 (same as current guard).
  This is the Layered Recovery Principle applied recursively:
  each macro expansion is a non-monotone step (replacement)
  recovered by a stratum boundary.

Stratum V(2): Spec/where injection
  Input cells: v1-datum-cells (set-once, from V(1))
  + spec-store cell (from R(1))
  + trait-registry cell (from R(0))
  + bundle-registry cell (from R(0))
  Output cells: v2-datum-cells (set-once, written here)
  Rules: spec injection, where-clause expansion
  Topology: fixed
  CALM-safe: reads from prior strata, writes set-once output
```

**Why this is correct**: Every cell is set-once. Every merge is monotone (⊥ → value for form cells, set-union for registry cells). Every stratum has fixed topology. CALM applies within each stratum. Rewrites happen at stratum boundaries — the Layered Recovery Principle. The same architectural pattern that PAR Track 1 used for SRE decomposition requests.

**Connection to PRN/PReductions**: This pipeline-of-strata pattern is exactly how e-graph rewriting would work. Each saturation round adds equivalences (monotone within the round). Extraction (choosing a representative) is non-monotone — it's the stratum boundary. PPN Track 2's rewrite strata are a specialized instance of the general pattern that PReductions will generalize to arbitrary rewrite systems.

### 3.5 Spec/Where Injection as Data Flow (Stratum V(2))

Currently imperative: "look up spec by name, if found, splice type tokens into defn."

As propagator in stratum V(2): a **spec-injection propagator** watches:
- The v1-datum-cell (macro-expanded form from V(1))
- The spec-store cell (from R(1))

When both have values AND the defn's name matches a spec entry:
1. Extract spec type tokens
2. Splice into the defn datum
3. Write the injected form to the **v2-datum-cell** (NOT back to the input cell)

The output cell (v2-datum-cell) is set-once. The input cell (v1-datum-cell) is never modified. This is CALM-compliant — no replacement, only forward progression through the pipeline.

If the spec doesn't exist yet (form processed before its spec is registered), the propagator **residuates** — it waits for the spec-store cell to update. When a spec is registered (from processing another form's R(1) stratum), the injection propagator re-fires. This is the narrowing pattern from BSP-LE, operating across strata.

Where-clause injection works the same way: watches v1-datum-cell + trait-registry + bundle-registry. Fires when all available. Writes to v2-datum-cell.

### 3.6 Fixpoint = Stratified Quiescence

`preparse-expand-form` currently runs a recursive loop with depth-100 guard. In propagator terms, this becomes **stratified quiescence** — each stratum reaches its own fixpoint, then the next stratum begins.

**Within a stratum (e.g., V(0) structural rewrites)**:

1. Propagators read input cells (set-once, from prior stratum)
2. Rules match against input datum, priority-ordered
3. Highest-priority matching rule fires, computes result
4. Result written to output cell (set-once)
5. Quiescence: all output cells written → stratum complete

No re-firing within a stratum. Each propagator fires at most once (reads set-once input, writes set-once output). CALM is trivially satisfied.

**Across strata (the outer loop)**:

1. R(-1) completes → R(0) begins (topology: create registration propagators)
2. R(0) completes → R(1) begins (topology: create dependent-registration propagators)
3. R(1) completes → V(0) begins (topology: create structural rewrite propagators)
4. V(0) completes → V(1) begins (topology: create macro expansion propagators)
5. V(1) completes → V(2) begins (topology: create injection propagators)
6. V(2) completes → forms ready for parser

Each transition is a Layered Recovery boundary: the previous stratum's monotone computation reaches fixpoint, then a control layer sets up the next stratum's topology (new cells, new propagators), then the next stratum's monotone computation begins.

**Recursive macros (V(1) sub-strata)**:

A macro that expands to another macro creates chained V(1) sub-strata. Each sub-stratum reads the previous sub-stratum's output and writes to a new cell. The chain terminates when no macro matches the current output.

Termination: bounded by depth limit (100 chained sub-strata). Each sub-stratum produces a structurally smaller or different datum (macros consume their head symbol). The depth limit is a correct-by-construction guard — same as the current `preparse-expand-form` depth parameter, but expressed as a stratum count.

**Connection to e-graph rewriting (PReductions)**: In an e-graph, each saturation round adds equivalences to e-classes (monotone: e-classes grow). Extraction chooses a representative (non-monotone: selection discards alternatives). PPN Track 2's pipeline-of-strata is the same pattern: each stratum adds information (writing a set-once cell), and the transition to the next stratum is the "extraction" step (choosing which representation to process next). PReductions will generalize this from a linear pipeline to a lattice of strata.

### 3.7 Layer 2: Post-Parse Expansion

Layer 2 (`expand-top-level`, `expand-expression`) operates on surf-* structs, not datums. Two approaches:

**Option A: Separate rewrite engine for surf-* forms.** Layer 2 rules match surf-* patterns. The SRE already handles arbitrary structs via `ctor-desc`. Register surf-defn, surf-def, surf-the-fn as constructors with rewrite rules.

**Option B: Unify representations.** Don't parse to surf-* at all — keep datums through elaboration. The parser becomes a datum-to-datum transformer (a rewrite rule itself). Elaboration reads datums directly.

Option A is the incremental path (keeps existing parser). Option B is the principled path (removes the parser as a separate stage — it becomes another rewrite stratum). PPN Track 3 (parser as propagators) would implement Option B. For Track 2, Option A is sufficient.

### 3.8 macros.rkt Retirement Strategy

Phase 7 migrates consumers from macros.rkt functions to the propagator-based system. The audit identified the consumers:

- `driver.rkt` calls `preparse-expand-all` → calls the new propagator-based expand
- `elaborator.rkt` reads registries → reads cells directly
- Tests reference `expand-*` functions → updated to test rewrite rules

The migration is incremental: each Phase (2-6) replaces a subset of macros.rkt functions. The file shrinks progressively. Phase 7 removes what remains.

### 3.9 Dependency Ordering Replaces Source Ordering

Currently Phase 5b hoists generated defs (data constructors, trait accessors) before user defs. This is a source-ordering hack.

In the propagator design, **dependency ordering emerges from data flow**:
- A `defn foo` propagator watches the cells for types/constructors it references
- Those cells are written by `process-data` propagators
- `defn foo` fires AFTER its dependencies are available
- No explicit ordering needed — the data flow IS the ordering

Phase 5b becomes unnecessary. The hoisting is implicit in propagator firing order.

---

## §4 Phase Details

### Phase 0: Pre-0 Benchmarks ✅

**Deliverable**: Baseline timing. Benchmark file: `benchmarks/micro/bench-ppn-track2.rkt` (`a0fd523`).

#### Micro-benchmarks (M1-M5)

| Measurement | Result | Design Impact |
|-------------|--------|---------------|
| M1: Pipeline total (warm) | 111-122 ms per program | Preparse is a fraction; elaboration dominates |
| M2: Per-rule expansion | 22-35 μs median | Propagator fire function budget: ~30μs/rule |
| M3: Registry read (param) | 5 μs | Cell read (~25μs CHAMP) is 5× slower — acceptable |
| M3: lookup-spec (miss) | 8 μs | Scan cost per defn for spec injection |
| M4: Fixpoint convergence | Most forms: 1 iteration | Propagator fires once per form (common case) |
| M4: Non-matching forms | 0 iterations | No rule matches → no propagator fire needed |
| M5: Rule scan (no-match, symbol) | 10 μs | Floor cost for forms that don't match any rule |
| M5: Rule scan (no-match, list) | 21-24 μs | Nested list scanning more expensive |

**Key finding**: Per-rule expansion is 22-35μs. This is the propagator fire function cost. With 18 rules, a full scan on a non-matching form costs 10-24μs. Most forms converge in 0-1 iterations — the propagator fires at most once per form.

#### Adversarial benchmarks (A1-A4)

| Test | Median (ms) | Notes |
|------|-------------|-------|
| A1: 100 defmacros + 100 uses | 176 | Registry growth + scan: ~1.8ms for 100 macro lookups |
| A2: 30-deep macro chain | 104 | Fixpoint depth 30: ~3.5ms expansion overhead |
| A3: 50 spec+defn pairs | 409 | Spec injection is the most expensive cross-pass operation |
| A4: 20-clause defn | 203 | Pattern clause compilation dominates, not preparse |

**Key finding**: A3 (50 spec+defn pairs, 409ms) shows that spec injection scales linearly with defn count. This is the most performance-sensitive path — each defn triggers a spec lookup + datum splicing. The propagator design's residuation pattern (watch spec-store cell, fire when spec available) must not add overhead to this path.

#### E2E benchmarks (E1)

| Program | Total (ms) | Notes |
|---------|-----------|-------|
| simple-typed | 123 | Baseline: minimal program |
| bool-logic | 197 | Medium: data + pattern matching |
| church-folds | 155 | Medium: higher-order + recursion |
| dependent-types | 119 | Light: few forms |
| higher-order | 176 | Medium |
| implicit-args | 232 | Medium-heavy: implicit resolution |
| nat-arithmetic | 123 | Light |
| pairs-sigma | 175 | Medium |
| pattern-matching | 212 | Medium: multi-clause defn |
| recursive-types | 140 | Light-medium |
| constraints-adversarial | 699 | Heavy: many trait constraints |
| solve-adversarial | 620 | Heavy: relational search |
| type-adversarial | 3771 | Very heavy: reduction-dominated (reduce_ms=2838) |

**Key finding**: Preparse is invisible compared to elaboration for complex programs. The heaviest programs spend >90% of time in type checking, reduction, and constraint resolution — not in surface normalization. This gives the design **complete performance freedom**: any approach that doesn't add >10% to the simple-typed baseline (123ms) is acceptable.

#### Design implications from benchmarks

1. **Performance-free design space.** Preparse overhead is lost in noise relative to elaboration. Use whatever approach is clearest and most extensible — don't micro-optimize.
2. **Spec injection is the sensitive path.** 50 spec+defn = 409ms. The propagator design's residuation pattern must not add per-defn overhead. One cell-read (25μs) per defn × 50 defns = 1.25ms — acceptable.
3. **Rule scan cost is bounded.** 18 rules × 24μs = 432μs per form at worst. With ~100 forms per file, that's 43ms — within the 123ms baseline. Acceptable but not trivial.
4. **Fixpoint convergence is fast.** Most forms need 0-1 iterations. The propagator fires once per form, quiesces, done. No need for complex fuel-limit mechanisms for typical programs.
5. **Complex rules (pipe fusion, mixfix) dominate their own cost.** These should be specialized propagators, not pattern→template rules.

### Phase 1: Rewrite Rule Registry

**Deliverable**: `rewrite-rule` struct, registration, cell-based lookup.

**Scope**: New module (or section in a new `surface-rewrite.rkt`). The rule registry is a cell holding a list of rules. `register-rewrite-rule!` writes to this cell. Rule lookup scans the list for matching patterns.

**Tests**: Unit tests for rule registration, pattern matching, template substitution.

### Phase 2: Pure Rewrite Engine

**Deliverable**: 18 built-in rules registered as rewrite rules. A `rewrite-form` function applies all matching rules to a datum.

**Scope**: Replace the 18 `expand-*` functions with 18 rule registrations. The `rewrite-form` function takes a datum, scans registered rules, applies the first match, returns the result. This is the core of the propagator fire function.

**Tests**: All existing preparse tests must pass. Each rule tested individually.

### Phase 3: Registry Propagators

**Deliverable**: `process-data`, `process-trait`, etc. as propagators that write to registry cells.

**Scope**: Each `process-*` function becomes a propagator that: reads a "declaration datum" cell → parses the declaration → writes registry entries to the appropriate registry cell. The dual-write pattern becomes cell-only write.

**Tests**: All declaration processing tests. Registry reads return same values as before.

### Phase 4: Spec/Where Injection as Propagators

**Deliverable**: `maybe-inject-spec` and `maybe-inject-where` as data-flow propagators.

**Scope**: A propagator watches (form-cell, spec-store-cell). When both have values and names match, writes the injected form. For where-clause: watches (form-cell, trait-registry-cell, bundle-registry-cell).

**Tests**: All spec injection tests. Where-clause tests. Cross-form dependency tests.

### Phase 5: Fixpoint Convergence

**Deliverable**: `preparse-expand-form` replaced by propagator quiescence.

**Scope**: A "form expansion" propagator watches the form cell and the rule registry cell. When the form matches any rule, applies the rule and writes the result. The form cell's merge is replacement (idempotent). Quiescence = no more matches. Fuel limit = 100 writes per cell.

**Tests**: Recursive macro expansion tests. Depth limit tests. User-defined macro tests.

### Phase 6: Layer 2 Integration

**Deliverable**: `expand-top-level` operations as rewrite rules on surf-* forms.

**Scope**: Register surf-defn, surf-def constructors in the SRE ctor-desc registry. Layer 2 expansion rules (desugar-defn, desugar-the-fn, infer-auto-implicits) become rewrite rules on these constructors.

**Tests**: All Layer 2 expansion tests.

### Phase 7: macros.rkt Retirement

**Deliverable**: Consumer migration. Dead code removal.

**Scope**: driver.rkt calls the new propagator-based expansion. elaborator.rkt reads cells directly. Tests updated. macros.rkt reduced to registration-only code (no imperative expansion logic).

**Tests**: 383/383 GREEN.

### Phase 8: A/B Benchmarks + Suite Verify

**Deliverable**: Performance comparison (before vs after). Full suite verification.

---

## §5 Principles Alignment

| Principle | How this design serves it |
|-----------|---------------------------|
| Propagator Only | No algorithms. Rewrite rules are data. Fixpoint is quiescence. Ordering is data flow. |
| Data Orientation | Rules are structs, not closures. Registries are cells, not parameters. |
| Correct-by-Construction | Dependency ordering emerges from data flow — can't process a form before its dependencies. Fuel limit prevents divergence. |
| Completeness | 18 rewrites + registrations + injection — the full pipeline, not a partial conversion. |
| Decomplection | Rewrite rules separated from registration logic. Layer 1 separated from Layer 2. |
| First-Class by Default | Rewrite rules are first-class values. User-defined macros (defmacro) register rules at runtime. |
| Composition | Rules compose via fixpoint — applying rule A may enable rule B. The system discovers the composition. |

---

## §6 WS Impact

None directly — this track changes the INTERNAL expansion pipeline. User-facing syntax is unchanged. However, after Track 2, adding new syntax becomes: "register one rewrite rule" instead of "edit macros.rkt + 13 other pipeline files."

---

## §7 Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Pattern matching overhead | Medium | Pre-0 benchmarks. Rule matching is O(rules × form size). With 18 rules, overhead is bounded. |
| Loop fusion complexity | Medium | `expand-pipe-block` may need its own stratum. Don't force it into simple pattern→template. |
| Defmacro compatibility | Low | User-defined macros register rules at runtime. Same mechanism as built-in rules. |
| Phase 5b removal regression | Low | Dependency ordering is correct-by-construction. Any form that references an unregistered constructor will residuate, not silently fail. |
| Layer 2 representation gap | Medium | Option A (separate surf-* rules) is safe. Option B (unified representation) deferred to PPN Track 3. |
| Suite time regression | Low | Pre-0 establishes baseline. If rewrite overhead >5%, investigate. |
