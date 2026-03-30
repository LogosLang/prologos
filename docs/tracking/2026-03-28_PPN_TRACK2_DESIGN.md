# PPN Track 2: Surface Normalization as Propagators — Stage 3 Design (D.1)

**Date**: 2026-03-28
**Series**: [PPN (Propagator-Parsing-Network)](2026-03-26_PPN_MASTER.md)
**Prerequisite**: [PPN Track 1 ✅](2026-03-26_PPN_TRACK1_DESIGN.md) (propagator reader), [SRE Track 2F ✅](2026-03-28_SRE_TRACK2F_DESIGN.md) (algebraic foundation)
**Audit**: [PPN Track 2 Stage 2 Audit](2026-03-28_PPN_TRACK2_STAGE2_AUDIT.md)
**PIR (predecessor)**: [PPN Track 1 PIR](2026-03-26_PPN_TRACK1_PIR.md) — deferred items §8

**Research**:
- [Tree Rewriting as Structural Unification](../research/2026-03-26_TREE_REWRITING_AS_STRUCTURAL_UNIFICATION.md) — rewriting IS SRE decomposition
- [Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — parse tree as module over rewrite ring
- [Algebraic Embeddings on Lattices](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — lattice embedding (Pocket Universe)
- [Hypergraph Rewriting + Propagator Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — DPO/adhesive, Engelfriet-Heyker
- [Development Lessons](principles/DEVELOPMENT_LESSONS.org) — CALM fixed topology invariant
- [Effectful Computation on Propagators](principles/EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org) — Layered Recovery Principle

**Cross-series**:
- [SRE Master](2026-03-22_SRE_MASTER.md) — SRE Track 2D (rewrite relation), Track 2F (algebraic foundation)
- [PRN Master](2026-03-26_PRN_MASTER.md) — hypergraph rewriting theory
- [PTF Master](2026-03-28_PTF_MASTER.md) — propagator kinds (Map, Reduce for rewrite pipeline)
- [PAR Master](2026-03-27_PAR_MASTER.md) — parallel rewriting (submodule independence)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0 benchmarks + adversarial | ✅ | `a0fd523`. Preparse invisible vs elaboration. 22-35μs/rule. |
| 1 | Parse tree node descriptors + rewrite infrastructure | ✅ | `27e8870`. surface-rewrite.rkt. 38 tag rules + rewrite-rule struct + apply-rules. |
| 1b | Tag-refinement stratum T(0) | ✅ | `b990292`. Wired into reader pipeline. 383/383 GREEN. |
| 2a | Simple rewrite rules (9 rules) | ✅ | `d1cc404`. 5 implemented + 3 handled by rewrite-tree (dot-access, dot-key, infix-pipe). |
| 2b | Recursive rewrite rules (5 rules) | ✅ | `99cccaa`. 4 implemented (cond, do, list-lit, lseq-lit) + quasiquote in Phase 3. |
| 3 | Complex rewrite propagators (4+1 rules) | ✅ | `2d3d1f7`. Quasiquote done. Pipe-fusion, mixfix, defn-multi, session-ws → handled by merge fallback. |
| 4 | Registry propagators | ✅ | Track 7 Phase 2. 24 cells, cell-primary reads, dual-write. |
| 5 | Spec/where injection | ✅ | `34988568`. Handled by spec-aware merge: defns WITH specs → preparse version (annotated). |
| 6a | Form-grouping stratum G(0) | ✅ | `8778dfe`. group-tree-node. Line→form structure bridge. |
| 6b | Pipeline-as-cell model | ✅ | `d67094d`. Monotone stage chain, advance-pipeline. |
| 6c | tree-parser.rkt (tree → surf-*) | ✅ | `6fa8b70`→`a3824c8`. 1250 lines, 26 tests. Core language + Pi/Sigma/arrows/match/builtins. |
| 6d | Integration + pipeline reorder | ✅ | `3bca61e`→`902b8cb`. G(0)→T(0)→rewrite→parse. Full tree pipeline on every file. |
| 6e | V(1) macro expansion | ✅ | Built-ins: rewrite rules. User macros: merge fallback to preparse. |
| 6f | V(2) spec injection | ✅ | Spec-aware merge: preparse for spec-annotated, tree parser for inferred. |
| 6g | **SWITCHOVER** | ✅ | `523f2f1`→`8d80c27`. **Tree parser output used for elaboration.** Merge: generated defs (preparse) + user forms (tree parser) + spec forms (preparse). 383/383 GREEN, 7529 tests. |
| 7 | Layer 2 integration | ✅ | ALREADY WORKING. expand-top-level processes tree parser's surf-* identically to parse-datum's. Verified: auto-implicits, defn desugaring. |
| 8a | Consumer migration (reader.rkt) | 🔄 | Attempted `50f60c3`. Compat-token type mismatch — 23 test failures. REVERTED. Needs compat-token → token matching or selective migration. |
| 8b | Consumer migration (macros.rkt) | ⬜ | Preparse still runs for registration + generation + spec injection + specialized forms. Partial retirement only — remove unused expand-* functions. |
| 8c | reader.rkt deletion | ⬜ | Blocked by 8a. 1898 lines. |
| 9 | A/B benchmarks + suite verify + PIR | ⬜ | Performance comparison, 383/383 GREEN, PIR |

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

### 3.0 Theoretical Grounding

Four principles ground this design:

**CALM (from [DEVELOPMENT_LESSONS.org](principles/DEVELOPMENT_LESSONS.org))**: Within a stratum, topology is fixed and all operations are monotone. Rewrites are NOT monotone (they replace values). Therefore rewrites MUST happen at stratum boundaries, not within a BSP round.

**The Layered Recovery Principle (from [EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org](principles/EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org))**: Non-monotone behavior is recovered by inserting control layers between phases of monotone computation. Rewrites are the control layer; value propagation is the monotone substrate.

**The Pocket Universe Principle (from [Lattice Embeddings research](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md))**: A cell value IS an entire lattice unto itself. An RRB vector of structured values is a lattice (ordered by subset/refinement). The SRE can decompose into this embedded lattice, operating on sub-structures without requiring per-element cells. PPN Track 1 proved this: 5 cells hold the entire parse state for a file. A `parse-tree-node` with RRB children IS a tree — a PVec of PVecs. Structural sharing makes transformations efficient (O(log n) path-copy per rewrite).

**The Module Theory lens (from [Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md))**: The parse tree is a module over the endomorphism ring of rewrite rules. Each rewrite rule is a ring element. Sub-tree decomposition is the module's direct-sum decomposition. Independent sub-trees can be rewritten in parallel (submodule independence = parallelizability).

### D.2 Self-Critique Findings

| # | Finding | Severity | Resolution |
|---|---------|----------|------------|
| P1 | Parse tree nodes only have `'line`/`'root` tags — no form-head tags | HIGH | **Tag-refinement stratum T(0)** between R(1) and V(0). SRE subtype refinement: `'line` → `':let`, `':defn`, etc. based on first-token inspection. See §3.1b. |
| P2 | Tree nodes have variable children count — `ctor-desc` needs fixed arity | MEDIUM | Per-variant descriptors (`:let-assign` arity 4, `:let-bracket` arity 2). Recognizer inspects first-child token + structure. |
| P3 | Big-bang vs incremental migration not specified | MEDIUM | **Incremental**: Phase 1-2 operate on tree nodes for NEW rules. Existing preparse continues on datums via compat. Phase 6 integrates pipeline. Phase 8 retires compat+datums. |
| P4 | 57 files import `reader.rkt` directly (not 51) | LOW | Phase 8a scope corrected. |
| P5 | Mixfix Pratt parser as specialized propagator violates Most General Interface | LOW | Technical debt noted. Future: Pratt parser expressible as rewrite rules when PRN gives expressive strategies. |
| P6 | Rewrite LHS and RHS have different `ctor-desc` (different tag, different arity) | LOW | Explicit in SRE idempotent relation: LHS-desc decomposes, RHS-desc reconstructs. Different descriptors, shared bindings. |
| P7 | Form identity: one-shot (Approach 3) vs lattice-narrowing (Approach 4) | DESIGN | **Approach 3 for Track 2** (tag as struct field, SRE subtype refinement). **Approach 4 awareness** for Track 3+ (tag as lattice cell, set-narrowing). Migration: field → cell read. See §3.10. |

### D.3 External Critique Findings

| # | Finding | Severity | Resolution |
|---|---------|----------|------------|
| E1 | T(0) under-specified for non-keyword forms and nested groups | HIGH | **Accept.** Add `tag-expr` catch-all for non-keyword lines. T(0) MUST recurse into all `parse-tree-node` children, not just top-level lines. Enumerate full tag list (no "..." elisions). |
| E2 | "14 simple rules" — at least 5 need recursive templates | HIGH | **Accept.** Reclassify: **9 simple** (static binding map), **5 recursive** (fold over children — cond, do, list-literal, lseq-literal, quasiquote), **4 specialized** (pipe-fusion, mixfix, defn-multi, session-ws). Add `template-fn` field to `rewrite-rule` for recursive rules. |
| E3 | O(forms × strata) cell allocation unnecessary | MEDIUM | **Reject.** Cells enable residuation — spec-injection propagator watches form cell + spec-store cell, fires when both available. Function composition cannot express "wait for a future value." Overhead (12.5ms for 100 forms × 5 strata) is within performance-free budget. |
| E4 | `ctor-desc` impedance mismatch with parse tree nodes | MEDIUM | **Accept partially.** Dead-weight fields (`binder-depth: 0`, `binder-open-fn: #f`) are cost of uniformity. Mixed children types handled by per-position lattice specs. Reconstructor closure cost is per-decomposition (cheap). Document as deliberate choice. |
| E5 | Dual-path dispatch unspecified | MEDIUM | **Accept.** Add `use-propagator-preparse?` parameter. Dual-path testing in Phase 6. Disable fallback in Phase 8b. Delete in Phase 8c. Learn from PPN Track 1's `use-new-reader?` experience. |
| E6 | Scope should split into two tracks | MEDIUM | **Reject.** Design is complete; implementation proceeds as one track. PIR covers the full scope. Splitting adds overhead without value. |
| E7 | V(0) priority ordering masks data dependency — CALM violation | HIGH | **Accept.** Promote to sub-strata V(0,0) implicit-map, V(0,1) dot-access, V(0,2) infix. Set-once cells between sub-strata. Priority reserved for independent rule conflicts, not data dependencies. BSP scheduler as default would catch this as wrong results — correct-by-construction fix is sub-strata. |
| E8 | NTT `rewrite` form is less "data" than claimed | LOW | **Accept.** 9 rules are inspectable data. 5 recursive rules need `template-fn`. Acknowledge in NTT §17.1. |
| E9 | Source ordering elimination untested | LOW | **Accept via provenance.** Source ordering for error messages is subsumed by provenance tracking — each cell write carries source position. The elaborator reads provenance, not form ordering. Add `source-position` field on form cells for provenance chain. Heyting algebra lens: errors carry structural conflict information derived from provenance. |
| E10 | Duplicate section numbers | LOW | **Accept.** Fix numbering. |

### 3.1 Architecture: Parse Tree as Pocket Universe

**Core insight (revised after Phase 6 finding)**: The parse tree from PPN Track 1 has THREE levels of structure, each built on the last:

1. **Tokens** — characters classified into token entries (PPN Track 1: tokenizer)
2. **Indent tree** — tokens grouped into line nodes by indent level (PPN Track 1: tree-builder)
3. **Form tree** — line nodes grouped into form nodes by brackets + grammar (NEW: form-grouping stratum)
4. **Normalized form tree** — forms rewritten by surface normalization rules (PPN Track 2: rewriting)
5. **Typed AST** — forms elaborated with types (PPN Track 3/4: parser + elaborator)

**The Phase 6 finding**: PPN Track 1's tree has levels 1-2 but NOT level 3. Line nodes contain ALL tokens on a line — `if (pred x) (rf acc x) acc` is one line node with 8+ children, not an `if` form with 3 argument sub-forms. Rewrite rules expect FORM structure (known arity), but the indent tree has LINE structure (variable tokens).

**Level 3 is the missing piece.** The current pipeline gets form structure from `group-items` (bracket grouping during datum extraction). This is an imperative function that walks the indent tree and groups tokens by bracket matching. In the Propagator Only architecture, level 3 becomes a **form-grouping stratum G(0)** that reads the indent tree + bracket-depth domain and writes a form-structured tree.

**The pipeline with all 5 levels:**

```
source text → PPN Track 1 reader → indent tree cell (level 2)
    → [T(0): tag refinement — 'line → form-specific tags]
    → [G(0): form grouping — line nodes → bracket-grouped form nodes]
    → [V(0,0)→V(0,1)→V(0,2): structural rewrites on form nodes]
    → [V(1): macro expansion]
    → [V(2): spec/where injection]
    → form-structured tree cell (level 4)
    → [parser extracts surf-* from rewritten tree]
    → elaborator
```

The form-grouping stratum G(0) is the bridge between indent structure and form structure. It produces nodes with KNOWN arity (determined by bracket matching + form head), which rewrite rules can safely match against.

**The Pocket Universe principle still applies**: the form-grouped tree is a structured value in a cell. SRE decomposes form nodes by tag + arity. The difference from the original design: the Pocket Universe contains FORM nodes (with known arity), not LINE nodes (with variable tokens).

**Form pipeline cells — stratified pipeline as lattice value (Pocket Universe):**

Each top-level form gets ONE cell. That cell holds a **pipeline value** — the form's current processing stage + its tree node at that stage. The stages form a finite chain (lattice):

```
'raw < 'tagged < 'grouped < 'v0-0 < 'v0-1 < 'v0-2 < 'v1 < 'v2 < 'done
```

```racket
(struct form-pipeline-value
  (stage        ;; symbol: position in the stage chain
   tree-node    ;; parse-tree-node at this stage
   registrations ;; (listof registry-entry) extracted from this form
   source-pos)  ;; source position for provenance (D.3 E9)
  #:transparent)
```

The merge function advances monotonically: writing a value at a LATER stage supersedes the earlier stage. Writing at the SAME or earlier stage is a no-op (already processed). This IS a lattice — the stage chain is a finite total order.

```racket
(define (form-pipeline-merge old new)
  (if (stage>? (form-pipeline-value-stage new)
               (form-pipeline-value-stage old))
      new    ;; advance: take later stage
      old))  ;; no-op: already at or past this stage
```

A **single form-pipeline propagator** watches the cell and fires whenever the stage advances. Each firing applies the NEXT transformation:

```
'raw      → refine-tag           → write 'tagged
'tagged   → group-tree-node      → write 'grouped
'grouped  → apply V(0,0) rules   → write 'v0-0
'v0-0     → apply V(0,1) rules   → write 'v0-1
'v0-1     → apply V(0,2) rules   → write 'v0-2
'v0-2     → apply V(1) macros    → write 'v1
'v1       → apply V(2) injection → write 'v2
'v2       → extract registrations → write 'done
```

**Why this is correct (CALM)**:
- Stage progression is monotone (stages only increase). Each fire advances the stage by exactly one step.
- Within each stage, the transformation is a pure function of the input tree node + registry cells.
- The cell's merge resolves competing writes by taking the later stage — no ambiguity, no conflict.
- The propagator fires at most 9 times per form (one per stage). Bounded termination.

**Why this is parallelizable (Module Theory)**:
- Each form's pipeline cell is INDEPENDENT. Form A and Form B advance their pipelines concurrently via BSP.
- Cross-form dependencies (spec injection in V(2)) are mediated by REGISTRY CELLS: the V(2) stage reads the spec-store cell. If the spec isn't registered yet (another form's 'done stage hasn't fired), the V(2) propagator residuates — it waits.
- Independent forms process in parallel. Dependent forms serialize naturally via cell watching. No explicit ordering needed — data flow IS the ordering.

**Why this resolves the atomicity problem**:
- There is no "old path OR new path" switch. There is ONE path: the form pipeline cell.
- Migration is per-STAGE, not per-form: initially the pipeline goes 'raw → 'tagged → 'done (tag refinement only, datum extraction handles the rest). Each implementation phase extends the pipeline to handle one more stage.
- Adding a stage is ADDITIVE — it doesn't break earlier stages or require a switch.
- When ALL stages are implemented, the pipeline goes 'raw → ... → 'done and datum extraction reads the 'done stage's tree node. `preparse-expand-all` becomes a no-op (all forms are already at 'done).

**Connection to Pocket Universe**: The pipeline IS the lattice embedded in the cell. The cell value is `(stage, tree-node, registrations)`. The stage ordering is the lattice ordering. The Pocket Universe contains the entire pipeline state — one cell, one value, one lattice.

**Recursive macros (V(1) sub-stages)**: A macro that expands to another macro creates sub-stages: 'v1-0, 'v1-1, ..., 'v1-N. The stage chain extends dynamically up to depth limit N=100. Each sub-stage is a macro expansion step. The cell value at 'v1-K is "K macro expansions applied." Merge takes the higher K. Bounded by fuel.

**The registry cells**: 24 cells, one per registry. Already exist from `init-macros-cells!`. Currently secondary (dual-write); become primary. Each registry cell holds a CHAMP map (name → entry). Registry cells use set-union merge (adding entries is monotone).

**The dependency cell**: Tracks which forms depend on which registry entries. When a form references a constructor/trait/spec, a dependency edge is recorded. The elaborator processes forms in dependency order — no Phase 5b hoisting needed.

### 3.1b Tag-Refinement Stratum T(0) (D.2 finding P1)

**Problem**: PPN Track 1's tree-builder assigns only `'line` and `'root` tags based on indent structure. It doesn't know about form heads (`let`, `defn`, `data`, etc.). SRE `ctor-desc` dispatch needs form-specific tags.

**Solution**: A **tag-refinement stratum T(0)** runs between R(1) (dependent registration) and V(0) (structural rewrites). For each `'line` node, T(0) inspects the first child token and assigns a form-specific tag via SRE subtype refinement.

```
Stratum T(0): Form-tag refinement
  Input: parse tree with 'line tags
  Output: parse tree with form-head tags (':let, ':defn, ':def, ':spec, etc.)
  Mechanism: SRE subtype relation ('line → ':let is a refinement)
  CALM-safe: produces new tree nodes with refined tags (set-once output cell)
```

**Scope (D.3 finding E1)**: T(0) MUST recurse into ALL `parse-tree-node` children — not just top-level lines. Bracket groups, indented blocks, and nested forms all need tag refinement. Non-keyword-headed lines receive `tag-expr` as the catch-all (bare expressions, applications, pipe at expression level). An unrefined `'line` node that matches NO keyword gets `tag-expr` and flows through V(0)→V(1)→V(2) without triggering any rewrite rules.

The refinement is a set of registered **tag-assignment rules**:

```racket
;; Tag assignment: 'line node whose first token is 'let → ':let-assign or ':let-bracket
(register-tag-rule!
 'let                                ;; first-token lexeme
 (lambda (children)                  ;; guard: inspect children for variant
   (and (>= (rrb-size children) 4)
        (token-entry? (rrb-get children 2))
        (equal? (token-entry-lexeme (rrb-get children 2)) ":=")))
 ':let-assign)                       ;; refined tag (arity 4: name, :=, val, body)

(register-tag-rule!
 'let
 (lambda (children)
   (and (>= (rrb-size children) 2)
        (parse-tree-node? (rrb-get children 1))))  ;; second child is bracket group
 ':let-bracket)                      ;; refined tag (arity 2: bindings, body)
```

**Why SRE subtype, not a custom mechanism**: Tag refinement IS structural subtyping — `':let-assign` is a subtype of `'line` (more specific, more structure known). Using SRE's existing subtype relation means:
- The algebraic-kind machinery (Track 2F) applies: tag refinement is a monotone endomorphism.
- The topology is fixed within T(0) — no new cells or propagators created.
- Future: Approach 4 (tag as lattice cell with set-narrowing) replaces T(0) with a within-stratum narrowing propagator. The migration is: `(parse-tree-node-tag node)` field read → `(net-cell-read net tag-cell-id)` cell read. Tag-assignment rules become narrowing propagators.

**Connection to PTF**: Tag refinement is a **Reduce** propagator in the taxonomy — reads multiple children to determine the whole node's identity. The Map-Reduce composition (tree-builder Maps lines → tag-refiner Reduces to form identity) is the same pattern as tokenizer→tree-builder in PPN Track 1.

### 3.2 SRE Decomposition on Parse Tree Nodes

After tag-refinement (stratum T(0)), parse tree nodes carry form-specific tags (`:let-assign`, `:defn`, etc.). These are registered as SRE `ctor-desc` entries in a `'surface` domain:

```racket
;; Example: let-assign descriptor (after T(0) has tagged the node)
(register-ctor! ':let-assign
  #:arity 4   ;; name, :=, val, body
  #:recognizer (lambda (v) (and (parse-tree-node? v)
                                (eq? (parse-tree-node-tag v) ':let-assign)))
  #:extract (lambda (v) (rrb-to-list (parse-tree-node-children v)))
  #:reconstruct (lambda (cs) (make-parse-tree-node ':let-assign (rrb-from-list cs)
                                                    (parse-tree-node-srcloc v)
                                                    (parse-tree-node-indent v)))
  #:component-lattices (list tree-lattice-spec tree-lattice-spec
                             tree-lattice-spec tree-lattice-spec)
  #:domain 'surface
  #:sample (make-sample-let-assign-node)
  #:component-variances '(= = = =))  ;; all invariant for rewriting
```

The SRE decomposes a `:let-assign` node into sub-cells for each child. Rewrite rules match against the tag + children pattern. The reconstruction propagator builds the output from the same sub-cells with a new tag/structure.

**Variable-arity forms (D.2 finding P2)**: Forms with multiple syntactic variants register as SEPARATE descriptors with different tags. Tag-refinement stratum T(0) assigns the specific variant tag:
- `:let-assign` (arity 4: name, `:=`, val, body)
- `:let-bracket` (arity 2: bindings-bracket, body)
- `:let-inline` (arity 3: name, type-annotation, val)

Each variant has fixed arity — the `ctor-desc` system works without modification.

**LHS ≠ RHS arity (D.2 finding P6)**: Rewrite rules have DIFFERENT descriptors for LHS and RHS. `expand-let-assign` matches `:let-assign` (arity 4) and produces `:fn-application` (arity 2: fn-form, arg). The SRE's idempotent (rewrite) relation handles this: LHS-desc decomposes, RHS-desc reconstructs, binding-map connects sub-cells across the arity change.

**Rewrite rules as SRE idempotent relations**: A rewrite rule is a **directional** SRE relation — match LHS (decompose), produce RHS (compose), using the same sub-cell bindings. This is the SRE Track 2D relation kind (idempotent endomorphism in Track 2F's algebraic foundation).

```racket
(struct rewrite-rule
  (name          ; symbol — for debugging/tracing
   lhs-desc      ; ctor-desc for LHS pattern (SRE decomposition)
   ;; EITHER static template (simple rules) OR template function (recursive rules):
   rhs-desc      ; ctor-desc for RHS template (SRE reconstruction) | #f for recursive
   binding-map   ; (hash lhs-idx → rhs-idx) | #f for recursive
   template-fn   ; (list-of-children → parse-tree-node) | #f for simple
   ;; Metadata:
   guard         ; (parse-tree-node → boolean) or #f — additional match condition
   priority      ; natural — higher fires first (for overlapping independent patterns)
   stratum       ; symbol — which rewrite stratum this rule belongs to
   source-pos)   ; source position of the rule definition (provenance — D.3 E9)
  #:transparent)
```

**Simple rules** use `rhs-desc` + `binding-map` (inspectable data).
**Recursive rules** use `template-fn` (pure function, not inspectable as data but inspectable as signature).
At most one of `{rhs-desc, binding-map}` or `template-fn` is non-`#f`.

Registration:

```racket
(register-rewrite-rule!
 (rewrite-rule 'expand-let-assign
               let-assign-desc        ;; matches :let-assign nodes
               fn-application-desc    ;; produces :fn-application nodes
               (hash 0 1 1 0 2 2)    ;; name→param, val→arg, body→body
               #f                     ;; no guard
               100                    ;; priority
               'V0))                  ;; stratum V0 (structural rewrites)
```

The 18 pure rewrites from the audit become 18 rule registrations. No functions, no closures — SRE descriptors + binding maps describing the transformation.

### 3.3 Specialized Propagators for Complex Rules

Not all rewrites are simple pattern→template transformations. The audit identified two categories:

**Simple rules** (9) — static binding map, pure pattern→template (D.3 finding E2):
`expand-let-assign`, `expand-let-bracket`, `expand-if`, `expand-when`, `expand-compose-sexp`, `rewrite-dot-access`, `rewrite-dot-key`, `rewrite-infix-pipe`, `rewrite-implicit-map`. These are captured fully by `rewrite-rule` structs with SRE descriptors and `binding-map`.

**Recursive rules** (5) — fold over variable-length children (D.3 finding E2):
`expand-cond` (nested if-chain), `expand-do` (nested let-chain), `expand-list-literal` (nested cons-chain), `expand-lseq-literal` (nested lseq-cell-chain), `expand-quasiquote` (tree walk with unquote holes). These use `rewrite-rule` structs with a `template-fn` field instead of static `rhs-desc` + `binding-map`. The `template-fn` is a pure function from matched children to output tree — inspectable as a function signature but not as static data.

**Complex rules** (4) — analysis + synthesis, require specialized propagator fire functions:

1. **`expand-pipe-block`** (loop fusion): Classifies pipe steps (fusible/terminal/barrier/plain), builds fused inline reducers, emits optimized code. A specialized propagator in stratum V(0) that reads the `:pipe-gt` node, runs the fusion analysis, and writes the optimized tree.

2. **`expand-mixfix-form`** (Pratt parser): Reads user-operator and precedence-group registries, runs a Pratt parser on the token sequence, produces prefix form. A specialized propagator in stratum V(0) that reads the `:mixfix` node + registry cells and writes the parsed tree.

3. **`desugar-defn-multi`** (pattern clause compilation): Multi-arity defn with pattern matching clauses compiled to single defn with match expression. A specialized propagator in stratum V(2) or Layer 2.

4. **`desugar-session-ws` / `desugar-defproc-ws`** (WS-mode session/process desugaring): Restructures flat WS pipe tokens into nested session/process structure. A specialized propagator in stratum V(0).

These are registered as propagators (not rewrite rules) attached to their specific node tags. They read from the same pipeline cells and write to the same output cells. The SRE's `ctor-desc` system handles their input/output decomposition — only the transformation logic is custom.

**Mixfix as design validation target**: The rewrite rule registry must support future syntax extensions (advanced mixfix, unicode operators, user-defined forms) via `register-rewrite-rule!` alone. If a future mixfix extension requires editing the engine, the architecture is wrong. The Pratt parser propagator reads operator/precedence registry cells — adding operators is a cell write, not an engine change.

**Technical debt (D.2 finding P5)**: The Pratt parser as a specialized propagator means mixfix doesn't use the rewrite rule mechanism — it uses a different mechanism. This violates Most General Interface. Future work (when PRN gives expressive rewrite strategies): the Pratt parser should be expressible as a chain of rewrite rules (each precedence level as a rule). This would validate the architecture's generality and eliminate the specialized propagator.

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

--- PIPELINE-AS-CELL MODEL (supersedes separate strata) ---

Registration strata (R(-1), R(0), R(1)):
  Run BEFORE form pipeline cells are created.
  Populate registry cells from raw parse tree.
  Same as current preparse Passes -1, 0, 1.

Form pipeline stages (per-form cell, monotone stage chain):
  'raw      → T(0): tag refinement (first-token → form-head tag)
  'tagged   → G(0): form grouping (bracket matching → known arity)
  'grouped  → V(0,0): implicit-map rewrite
  'v0-0     → V(0,1): dot-access rewrite
  'v0-1     → V(0,2): infix + simple + recursive rewrites
  'v0-2     → V(1): macro expansion (registry lookup + template)
  'v1       → V(2): spec/where injection (cross-form, residuating)
  'v2       → extract registrations + mark 'done
  'done     → consumed by parser / elaborator
```

**V(0) data dependency is structural (D.3 E7)**: implicit-map → dot-access → infix ordering is enforced by the stage chain. Stage 'v0-0 MUST complete before 'v0-1. No priority mechanism. Correct-by-construction.

**V(1) recursive macros**: extends stage chain: 'v1 → 'v1-1 → ... → 'v1-N. Merge takes higher N. Fuel limit 100.

**V(2) cross-form dependency**: V(2) reads spec-store cell. If spec unavailable, propagator residuates. When spec form reaches 'done, V(2) re-fires.

**Why this is correct (CALM)**: Stage progression is monotone. Each fire advances by one step. Merge takes later stage. Bounded termination (9 base stages + fuel for V(1)). Each stage's transformation is pure function of input + registry cells.

**Why this is parallelizable**: Independent forms advance pipelines concurrently via BSP. Cross-form dependencies serialize via registry cell watching. Submodule independence from Module Theory.

**Why this resolves atomicity**: No "old path OR new path" switch. ONE path: the pipeline cell. Migration is per-stage: initially 'raw → 'tagged → 'done. Each phase extends to handle one more stage. Adding a stage is additive. When ALL stages implemented, preparse-expand-all becomes a no-op.

**Connection to PRN/PReductions**: The pipeline-as-cell pattern generalizes to e-graph rewriting. Each saturation round adds equivalences (stage advance). Extraction chooses representative (reading 'done stage). PPN Track 2's form pipeline is a specialized instance.

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

Layer 2 (`expand-top-level`, `expand-expression`) operates on surf-* structs. With the parse tree as the canonical representation, two options:

**Option A: Parse tree → surf-* → Layer 2 rewrite rules.** The parser converts rewritten parse tree nodes to surf-* ASTs (existing code). Layer 2 rules are registered as SRE `ctor-desc` on surf-* structs (these are already fixed-arity structs — ideal for SRE). `desugar-defn`, `desugar-the-fn`, `infer-auto-implicits` become rewrite rules on surf-* constructors.

**Option B (PPN Track 3): Eliminate surf-*.** The parser becomes another rewrite stratum on the same parse tree. Elaboration reads parse tree nodes directly. No representation change between normalization and elaboration.

For Track 2: **Option A**. The parser bridge (parse tree → surf-*) is existing working code. Layer 2 rules on surf-* are a clean application of SRE. Option B is PPN Track 3's scope.

### 3.8 reader.rkt + macros.rkt Retirement Strategy

**Phase 7 has three sub-phases for explicit retirement:**

**Phase 7a: Consumer import migration (reader.rkt).** 51 files import from `reader.rkt` for `tokenize-string`, `read-all-forms-string`, `prologos-read-syntax-all`. Change all imports to `parse-reader.rkt` compat wrappers. This is mechanical (grep + replace). After this phase, no file imports `reader.rkt` directly.

**Code eliminated**: 0 lines (imports change only). But UNBLOCKS Phase 7c.

**Phase 7b: Consumer migration (macros.rkt).** `driver.rkt` calls `preparse-expand-all` → calls the new propagator-based expand. `elaborator.rkt` reads registries → reads cells directly. Tests reference `expand-*` functions → updated to test rewrite rules.

**Code eliminated**: ~3000-5000 lines of imperative preparse logic in macros.rkt. Registration functions remain (they write to cells).

**Phase 7c: reader.rkt deletion.** Remove the `use-new-reader?` parameter dispatch in `driver.rkt`. Delete `reader.rkt` (1898 lines). The new reader (parse-reader.rkt) is the only reader.

**Code eliminated**: 1898 lines (reader.rkt) + ~50 lines of dispatch logic.

**Total code elimination across Track 2**: ~5000-7000 lines (macros.rkt preparse + reader.rkt + dispatch logic).

### 3.9 Migration Strategy (D.2 finding P3)

**Incremental, not big-bang.** The design operates on parse tree nodes for NEW infrastructure (rule registry, tag refinement, rewrite engine). Existing preparse continues on datums via the compat layer during development. The transition is:

1. **Phases 1-3**: Build new infrastructure (descriptors, rules, tag refinement) alongside existing macros.rkt. Both code paths exist. New rules tested on parse tree nodes independently.
2. **Phase 4-5**: Registry propagators + spec injection as propagators. These replace macros.rkt's Pass 0/1/2 registration logic. The compat-layer datum extraction still feeds the parser.
3. **Phase 6**: Integration — wire the propagator pipeline into `driver.rkt`. The parse tree flows through T(0)→V(0)→V(1)→V(2), producing rewritten tree nodes. The compat layer extracts datums from the rewritten tree for the parser.
4. **Phase 7-8**: Retire compat layer. Parser reads rewritten tree directly (or via a thin bridge). Delete reader.rkt. Delete preparse logic in macros.rkt.

At no point does the entire pipeline switch at once. Each phase adds capability, and the existing path remains as fallback until the new path is verified.

**Dual-path dispatch (D.3 finding E5)**: A `use-propagator-preparse?` parameter (default `#f`) controls which path is active. Learning from PPN Track 1's `use-new-reader?` experience: Phase 6 flips to `#t` and runs full suite under both paths. Phase 8b disables the fallback. Phase 8c deletes the old code. Do NOT maintain two paths for more than 2 phases — the maintenance burden of keeping both paths correct is worse than the safety benefit.

### 3.10 Approach 4 Awareness: Form Tags as Lattice Cells (Future)

Track 2 uses Approach 3: form tags as struct fields, assigned once by SRE subtype refinement in stratum T(0). This is sufficient for current needs — form identity is determined by the first token, no ambiguity.

**Approach 4** (for PPN Track 3+): form tags become **lattice cells** with set-narrowing, paralleling PPN Track 1's token type narrowing (`seteq` of possible types, narrowed by intersection). Migration path:

- `(parse-tree-node-tag node)` (field read) → `(net-cell-read net (node-tag-cell-id node))` (cell read)
- Tag-assignment rules → narrowing propagators (write set intersections to tag cells)
- The parser contributes additional narrowing (grammar productions constrain form possibilities)
- The elaborator contributes type-derived narrowing (PPN Track 4)

The structural transition is the same pattern as PM Track 8 (parameters → cells). The refinement propagators don't change — they just write to cells instead of producing new structs.

**When Approach 4 is needed**: When form identity is genuinely ambiguous (user-defined macros that shadow built-in forms, grammar extensions that add new form types, contextual disambiguation). Track 2's one-shot assignment is the degenerate case of set-narrowing where the set immediately reaches a singleton.

### 3.11 Source Ordering via Provenance (D.3 finding E9)

Dependency ordering replaces Phase 5b hoisting (§3.12). But source ordering has secondary uses:
- Error messages reported in source order (user expectation)
- `eval` forms execute in source order (side effects)
- Multi-clause `defn` clauses merged in source order

**Resolution via provenance**: Each form cell carries a `source-position` field inherited from the parse tree node's `srcloc`. The provenance chain (which propagator wrote which cell, from what source) preserves source ordering information throughout the pipeline. The elaborator reads provenance for error reporting — errors are located by source position, not by processing order.

For `eval` execution order: the driver processes V(2) output cells in source-position order. Dependency ordering determines WHEN a form is ready; source-position determines the ORDER in which ready forms are elaborated.

For multi-clause `defn` merging: clauses carry source positions. The merger sorts by position. No explicit source ordering in the pipeline needed.

**Connection to Heyting algebra error reporting (from [Algebraic Embeddings](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md))**: Errors carry structural conflict information derived from the provenance chain — WHAT conflicted and WHY, not just WHERE. Pseudo-complement of the expected type in the actual type lattice gives the precise incompatibility. Source position is one dimension of provenance; algebraic conflict is another.

### 3.12 Deferred Items Incorporated (from PPN Master + Track 1 PIR)

| Source | Item | How addressed |
|--------|------|---------------|
| PPN Master line 43 | Mixfix deferred to Track 2 | §3.3: specialized Pratt parser propagator in V(0). Reads operator/precedence registry cells. |
| PPN Master line 43 | Token struct field migration | §3.1: eliminated. Parse tree IS the representation. No token struct migration needed — tree nodes contain RRB children. |
| PPN Master line 43 | Syntax-object elimination | §3.1: eliminated. Parse tree nodes carry srcloc directly. No syntax objects in the pipeline. |
| Track 1 PIR §8 | reader.rkt retirement (1898 lines) | §3.8 Phase 7c: explicit deletion phase after consumer migration. |
| Track 1 PIR §8 | Compat layer removal | §3.1: compat layer unnecessary. Parse tree is canonical. Phase 7a migrates remaining consumers. |
| DEFERRED.md | Advanced mixfix (unicode, postfix) | §3.3: design validation target. Future extensions via `register-rewrite-rule!` only. |

### 3.9 Dependency Ordering Replaces Source Ordering

Currently Phase 5b hoists generated defs (data constructors, trait accessors) before user defs. This is a source-ordering hack.

In the propagator design, **dependency ordering emerges from data flow**:
- A `defn foo` propagator watches the cells for types/constructors it references
- Those cells are written by `process-data` propagators
- `defn foo` fires AFTER its dependencies are available
- No explicit ordering needed — the data flow IS the ordering

Phase 5b becomes unnecessary. The hoisting is implicit in propagator firing order.

---

## §3.12 NTT Speculative Syntax — Full Pipeline Model

Following PPN Track 0's precedent (NTT Syntax Design §16), this section expresses the Track 2 architecture in [NTT syntax](2026-03-22_NTT_SYNTAX_DESIGN.md). This serves as: (a) design clarity check, (b) correctness reference for implementation, (c) NTT refinement — gaps identified feed back into the NTT design.

### Lattice Declarations

```prologos
;; The parse tree as an embedded lattice (Pocket Universe)
data SurfaceTree
  := surface-bot
   | surface-tree [nodes : PersistentVec SurfaceNode]
   | surface-error
  :lattice :embedded
  :inner   [PersistentVec SurfaceNode]
  :merge   pvec-point-update
  :bot     surface-bot
  :top     surface-error
  :diff    pvec-structural-diff

;; A surface node — the tree M-type from PPN Track 1
data SurfaceNode
  := node [tag : FormTag] [children : PersistentVec SurfaceChild]
         [srcloc : SrcLoc] [indent : Int]
  :lattice :structural
  :bot     node-bot
  :top     node-error

;; Children are either nodes or tokens
data SurfaceChild
  := child-node [n : SurfaceNode]
   | child-token [t : TokenEntry]
  :lattice :set-once
  :bot child-bot

;; Form tag lattice (Approach 3: field; Approach 4: cell)
data FormTag
  := tag-bot          ;; unrefined ('line from tree-builder)
   | tag-line         ;; indent-structural
   | tag-let-assign | tag-let-bracket | tag-let-inline
   | tag-defn | tag-def | tag-spec | tag-data | tag-trait | tag-impl
   | tag-if | tag-cond | tag-do | tag-when
   | tag-pipe-gt | tag-compose | tag-mixfix
   | tag-list-literal | tag-lseq-literal
   | tag-quote | tag-quasiquote
   | tag-session | tag-defproc | tag-proc
   | tag-defr | tag-solver | tag-eval
   | tag-ns | tag-imports | tag-exports | tag-foreign
   | tag-error         ;; contradictory / unrecognizable
  :lattice :value
  :bot tag-bot
  :top tag-error

;; Registry cells as embedded lattices
data RegistryCell {K V : Type}
  := registry-bot
   | registry [entries : Map K V]
  :lattice :embedded
  :inner   [Map K V]
  :merge   map-union
  :bot     registry-bot
  :diff    map-key-diff
```

### Rewrite Rules (PROPOSED NTT extension — see §3.12.1)

```prologos
;; PROPOSED FORM: rewrite — first-class DPO rewrite rule declaration
;; Represents the SRE idempotent relation: match LHS, produce RHS, shared bindings

rewrite expand-let-assign
  :lhs    [node tag-let-assign [$name $assign $val . $body]]
  :rhs    [node tag-fn-application [[fn [$name] . $body] $val]]
  :bind   {name -> fn-param, val -> arg, body -> fn-body}
  :stratum V0
  :priority 100

rewrite expand-if
  :lhs    [node tag-if [$cond $then $else]]
  :rhs    [node tag-match [$cond [clause true $then] [clause false $else]]]
  :bind   {cond -> scrutinee, then -> branch-1, else -> branch-2}
  :stratum V0
  :priority 100

rewrite expand-cond
  :lhs    [node tag-cond [$pipe $guard -> $body . $rest]]
  :rhs    [node tag-if [$guard $body [expand-cond-rest $rest]]]
  :bind   {guard -> cond, body -> then, rest -> else-chain}
  :stratum V0
  :priority 90

rewrite expand-list-literal
  :lhs    [node tag-list-literal [$x . $xs]]
  :rhs    [cons $x [expand-list-literal $xs]]
  :bind   {x -> head, xs -> tail}
  :stratum V0
  :priority 100

rewrite expand-dot-access
  :lhs    [node tag-dot-access [$target $field]]
  :rhs    [map-get $target $field]
  :bind   {target -> obj, field -> key}
  :stratum V0
  :priority 110   ;; higher than infix (must fire first)
```

### Tag Refinement Rules (PROPOSED NTT extension — see §3.12.2)

```prologos
;; PROPOSED FORM: refine — tag refinement via SRE subtype relation
;; Narrows a general tag to a specific variant based on structure inspection

refine FormTag
  :from tag-line
  :to   tag-let-assign
  :when [first-child-token-is "let"] [nth-child-token-is 2 ":="]
  :stratum T0

refine FormTag
  :from tag-line
  :to   tag-let-bracket
  :when [first-child-token-is "let"] [second-child-is-bracket]
  :stratum T0

refine FormTag
  :from tag-line
  :to   tag-defn
  :when [first-child-token-is "defn"]
  :stratum T0

refine FormTag
  :from tag-line
  :to   tag-data
  :when [first-child-token-is "data"]
  :stratum T0

;; ... (one refine per form head)
```

### Specialized Propagators

```prologos
;; Pipe fusion — complex analysis, not a simple rewrite
propagator pipe-fusion
  :reads  [pipe-in : Cell SurfaceNode]
  :writes [pipe-out : Cell SurfaceNode]
  :guard  [tag-is? pipe-in tag-pipe-gt]
  (let [steps := [classify-pipe-steps [node-children [read pipe-in]]]]
    [write pipe-out [fuse-pipe-steps steps]])

;; Mixfix Pratt parser — reads operator/precedence registries
propagator mixfix-parse
  :reads  [mixfix-in : Cell SurfaceNode]
          [op-registry : Cell (RegistryCell Symbol OpInfo)]
          [prec-groups : Cell (RegistryCell Symbol PrecGroup)]
  :writes [mixfix-out : Cell SurfaceNode]
  :guard  [tag-is? mixfix-in tag-mixfix]
  (let [ops := [read op-registry]
        precs := [read prec-groups]
        tokens := [node-children [read mixfix-in]]]
    [write mixfix-out [pratt-parse tokens ops precs]])
```

### Stratified Pipeline

```prologos
stratification SurfaceNormalization
  :strata [R-neg1 R0 R1 T0 V0 V1 V2]
  :scheduler :bsp

  :fiber R-neg1
    :mode monotone
    :networks [ns-loader import-resolver]

  :fiber R0
    :mode monotone
    :networks [data-registrar trait-registrar deftype-registrar
               defmacro-registrar bundle-registrar schema-registrar
               selection-registrar property-registrar functor-registrar]

  :fiber R1
    :mode monotone
    :networks [spec-registrar impl-registrar]

  :fiber T0
    :mode monotone
    :networks [tag-refiner]
    ;; Tag refinement: 'line → form-specific tags via SRE subtype

  :fiber V0
    :mode monotone
    :networks [structural-rewriter]
    ;; Priority-ordered: implicit-map (110) > dot-access (105) > infix (100)

  :fiber V1
    :mode monotone
    :networks [macro-expander]
    :recurse
      :trigger
        :condition [output-matches-macro-pattern]
        :when [lfp-reached]
      :grows-by 1
      :halts-when [no-match]

  :fiber V2
    :mode monotone
    :networks [spec-injector where-injector]

  :fuel 100
  :where [WellFounded SurfaceNormalization]
```

### Bridges

```prologos
;; Spec injection: registry → form (one-way)
bridge SpecToForm
  :from RegistryCell Symbol SpecEntry
  :to   SurfaceNode
  :alpha spec-inject-into-defn
  ;; No gamma — injection is one-way

;; Where-clause injection: reads from trait + bundle registries
bridge WhereToForm
  :from RegistryCell Symbol TraitEntry
  :to   SurfaceNode
  :alpha where-expand-constraints

;; Tag refinement: tree structure → tag lattice
bridge TreeToTag
  :from SurfaceNode
  :to   FormTag
  :alpha first-token-to-tag
  ;; No gamma — refinement is one-way (subtype)
```

### §3.12.1 NTT Gap: `rewrite` Form

NTT currently has `propagator` (fire function with `:reads`/`:writes`) but no way to declare a **rewrite rule** as a first-class form. Rewrite rules are data — LHS pattern, RHS template, binding map — not fire functions. The proposed `rewrite` form fills this gap:

| Keyword | Type | Description |
|---------|------|-------------|
| `:lhs` | Pattern | SRE decomposition pattern (LHS `ctor-desc`) |
| `:rhs` | Template | SRE reconstruction template (RHS `ctor-desc`) |
| `:bind` | Map | Sub-cell binding map (LHS child idx → RHS child idx) |
| `:stratum` | Symbol | Which rewrite stratum this rule belongs to |
| `:priority` | Nat | Higher fires first (for overlapping patterns) |
| `:guard` | Predicate | Optional additional match condition |

The `rewrite` form is the NTT surface syntax for `rewrite-rule` structs. The SRE's idempotent relation handles matching (`:lhs`) and reconstruction (`:rhs`). The `:bind` map connects sub-cells across arity changes.

**Why not just `propagator`?** A propagator has an opaque fire function body. A rewrite rule is INSPECTABLE DATA — the LHS and RHS patterns can be analyzed, composed, inverted (for bidirectional rewriting), and optimized (rule ordering, confluence checking). Making rules first-class enables: rule composition (`rewrite A := compose [rule1 rule2]`), rule inversion (`:bidirectional` flag), and static confluence analysis.

**Connection to PRN**: The `rewrite` form IS a DPO (Double-Pushout) rewrite rule in NTT syntax. PRN's hypergraph rewriting grammars would use the same form for graph transformation rules. PPN Track 2 is the first consumer; PRN generalizes.

### §3.12.2 NTT Gap: `refine` Form

NTT has no form for declaring **tag refinement** — monotone narrowing of a lattice value from general to specific based on structural inspection. The proposed `refine` form:

| Keyword | Type | Description |
|---------|------|-------------|
| `:from` | Lattice value | General tag (e.g., `tag-line`) |
| `:to` | Lattice value | Specific tag (e.g., `tag-let-assign`) |
| `:when` | Predicate list | Structural conditions for refinement |
| `:stratum` | Symbol | Which stratum performs the refinement |

**Why not `rewrite`?** Refinement changes the TAG but preserves children. Rewriting changes the STRUCTURE (different children, different arity). Refinement is monotone within a stratum (tag lattice narrows). Rewriting is non-monotone (requires stratum boundary). They are different algebraic operations — refinement is subtyping, rewriting is endomorphism.

**Connection to Approach 4**: When form tags become lattice cells (PPN Track 3+), `refine` declarations become set-narrowing propagators. The `refine` form is the declarative surface for both Approach 3 (struct field assignment) and Approach 4 (cell narrowing). The implementation changes; the declaration doesn't.

### §3.12.3 NTT Gap: Dynamic Pipeline Wiring

NTT's `connect` (in `network`) models static wiring between known cells. The form pipeline (V0→V1→V2) creates cells dynamically — each form gets a chain of set-once cells, one per stratum. The number of cells depends on the number of forms in the file.

This is the `functor` pattern — the pipeline is parameterized by the form list:

```prologos
;; PROPOSED: functor-parameterized pipeline
functor FormPipeline {form : SurfaceNode}
  interface
    :inputs  [raw : Cell SurfaceNode]
    :outputs [t0-out : Cell SurfaceNode
              v0-out : Cell SurfaceNode
              v1-out : Cell SurfaceNode
              v2-out : Cell SurfaceNode]

;; Instantiation: one pipeline per top-level form
network preparse-net : PreparseInterface
  embed pipeline-1 : FormPipeline form-1
        pipeline-2 : FormPipeline form-2
        ...
  connect parse-tree.form-1 -> pipeline-1.raw
          parse-tree.form-2 -> pipeline-2.raw
          ...
```

This uses existing NTT (`functor` + `embed`) but the instantiation is data-driven (one per form). The `...` is the gap — NTT doesn't have a way to express "one per element of a collection." This is the polynomial functor's data-dependent arity, already noted as an NTT design challenge (§5.3 in the NTT doc).

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

### Phase 1: Parse Tree Node Descriptors + Rewrite Infrastructure

**Deliverable**: `ctor-desc` registrations for surface form tags. `rewrite-rule` struct. `register-rewrite-rule!`. New module `surface-rewrite.rkt`.

**Scope**:
- Register `parse-tree-node` variants as SRE `ctor-desc` entries in a new `'surface` domain. Tags: `:let-assign`, `:let-bracket`, `:if`, `:cond`, `:do`, `:list-literal`, `:lseq-literal`, `:pipe-gt`, `:compose`, `:quote`, `:quasiquote`, `:dot-access`, `:dot-key`, `:infix-pipe`, `:implicit-map`, `:mixfix`, `:defn`, `:def`, `:spec`, `:data`, `:trait`, `:impl`, etc.
- Each descriptor has: recognizer (tag check), extractor (RRB children → list), reconstructor (list → parse-tree-node with new tag), lattice specs, variances.
- `rewrite-rule` struct with `lhs-desc`, `rhs-desc`, `binding-map`, `guard`, `priority`, `stratum`.
- `register-rewrite-rule!` writes to a rewrite-rule registry cell.
- Rule matching: scan registry cell, find first rule whose `lhs-desc` recognizer matches the input node.

**Tests**: Unit tests for descriptor registration, rule registration, pattern matching on parse tree nodes, template reconstruction.

### Phase 2: Simple Rewrite Rules (14 rules)

**Deliverable**: 14 simple rules registered as `rewrite-rule` structs with SRE descriptors.

**Scope**: Replace the 14 simple `expand-*` functions with rule registrations that operate on parse tree nodes:

| Rule | LHS tag | RHS construction |
|------|---------|-----------------|
| expand-let-assign | `:let-assign` | `((fn [name] body) val)` tree |
| expand-let-bracket | `:let-bracket` | nested fn applications |
| expand-if | `:if` | `(match cond \| true → then \| false → else)` tree |
| expand-cond | `:cond` | nested if tree |
| expand-do | `:do` | nested let tree |
| expand-list-literal | `:list-literal` | nested cons tree |
| expand-lseq-literal | `:lseq-literal` | nested lseq-cell tree |
| expand-compose | `:compose` | nested fn tree |
| expand-quote | `:quote` | datum constructor tree |
| expand-quasiquote | `:quasiquote` | datum constructor with unquote holes |
| rewrite-dot-access | `:dot-access` | `(map-get target :field)` tree |
| rewrite-dot-key | `:dot-key` | `(map-get target kw)` tree |
| rewrite-infix-pipe | `:infix-pipe` | canonicalized pipe tree |
| rewrite-implicit-map | `:implicit-map` | `$brace-params` restructured tree |

**Tests**: All existing preparse tests must pass. Each rule tested individually on parse tree node inputs.

### Phase 3: Registry Propagators

**Deliverable**: `process-data`, `process-trait`, etc. as propagators that write to registry cells.

**Scope**: Each `process-*` function becomes a propagator that: reads a "declaration datum" cell → parses the declaration → writes registry entries to the appropriate registry cell. The dual-write pattern becomes cell-only write.

**Tests**: All declaration processing tests. Registry reads return same values as before.

### Phase 4: Spec/Where Injection as Propagators

**Deliverable**: `maybe-inject-spec` and `maybe-inject-where` as data-flow propagators.

**Scope**: A propagator watches (form-cell, spec-store-cell). When both have values and names match, writes the injected form. For where-clause: watches (form-cell, trait-registry-cell, bundle-registry-cell).

**Tests**: All spec injection tests. Where-clause tests. Cross-form dependency tests.

### Phase 5: Spec/Where Injection as Propagators

**Deliverable**: `maybe-inject-spec` and `maybe-inject-where` as data-flow propagators in stratum V(2).

**Scope**: A propagator watches (form-cell, spec-store-cell). When both have values and names match, writes the injected form to v2-tree-cell. For where-clause: watches (form-cell, trait-registry-cell, bundle-registry-cell).

**Tests**: All spec injection tests. Where-clause tests. Cross-form dependency tests.

### Phase 6: Stratified Pipeline Integration

**Deliverable**: Wire the full propagator pipeline into `driver.rkt`. The parse tree flows through R(-1)→R(0)→R(1)→T(0)→V(0,0)→V(0,1)→V(0,2)→V(1)→V(2), producing rewritten tree nodes. `use-propagator-preparse?` parameter for dual-path dispatch.

**DEFERRED WORK CONSOLIDATED HERE** (from Phases 2a, 2b, 3):

| Rule | Deferred from | Why deferred | What Phase 6 must do |
|------|---------------|-------------|---------------------|
| rewrite-dot-access | Phase 2a | Tree has flat sentinel tokens; need tree-level sentinel detection | Adapt rule to read `$dot-access` token-entry type from tree children |
| rewrite-dot-key | Phase 2a | Same as dot-access | Adapt rule to read `$dot-key` token-entry type |
| rewrite-infix-pipe | Phase 2a | `$pipe-gt` at non-head position needs tree-level detection | Adapt rule to scan children for `$pipe-gt` tokens not at position 0 |
| expand-pipe-block | Phase 3 | Loop fusion deeply tied to datum structure (car/cdr inspection) | Either (a) adapt fusion logic to tree children, or (b) extract datum from tagged tree node, apply existing expand-pipe-block, convert result back |
| expand-mixfix-form | Phase 3 | Pratt parser needs operator/precedence registry cells | Wire registry cells into propagator; adapt Pratt parser to read from tree children as token sequence |
| desugar-defn-multi | Phase 3 | Pattern clause compilation tied to datum format | Adapt pattern compiler to tree node format |
| desugar-session-ws | Phase 3 | WS pipe restructuring tied to reader output format | Adapt session desugaring to tree indent+pipe structure |
| desugar-defproc-ws | Phase 3 | Same as session-ws | Adapt process desugaring to tree structure |

**Integration strategy**: For each deferred rule, Phase 6 chooses between:
- **(a) Tree-native**: Adapt the rule logic to operate directly on `parse-tree-node` children. Preferred when the adaptation is straightforward.
- **(b) Datum bridge**: Extract datums from the tagged tree node (via existing `flatten-with-boundaries` + `group-items`), apply the existing macros.rkt function, convert the result back to a tree node. Pragmatic when the logic is complex and datum-native.

Option (b) is a temporary bridge — it reuses existing tested logic while the tree-native version is developed. Phase 7-8 retires the bridges.

**Tests**: Full suite under `use-propagator-preparse? #t`. Dual-path comparison.

### Phase 7: Layer 2 Integration

**Deliverable**: `expand-top-level` operations as rewrite rules on surf-* forms.

**Scope**: Register surf-defn, surf-def constructors in the SRE ctor-desc registry. Layer 2 expansion rules (desugar-defn, desugar-the-fn, infer-auto-implicits) become rewrite rules on these constructors.

**Tests**: All Layer 2 expansion tests.

### Phase 8a-8c: Retirement

**Phase 8a**: Consumer migration — 57 files importing `reader.rkt` → import from `parse-reader.rkt`.
**Phase 8b**: Consumer migration — `driver.rkt` + `elaborator.rkt` + tests → use propagator pipeline. Disable `use-propagator-preparse?` fallback.
**Phase 8c**: Delete `reader.rkt` (1898 lines) + imperative preparse logic in `macros.rkt` (~3000-5000 lines).

**Tests**: 383/383 GREEN after each sub-phase.

### Phase 9: A/B Benchmarks + Suite Verify

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
