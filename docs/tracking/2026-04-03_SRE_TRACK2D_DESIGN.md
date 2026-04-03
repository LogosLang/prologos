# SRE Track 2D: Rewrite Relation — Stage 3 Design (D.1)

**Date**: 2026-04-03
**Series**: [SRE (Structural Reasoning Engine)](2026-03-22_SRE_MASTER.md)
**Prerequisites**: [SRE Track 2F ✅](2026-03-28_SRE_TRACK2F_DESIGN.md) (Algebraic Foundation — relation infrastructure), [PPN Track 3 ✅](2026-04-01_PPN_TRACK3_DESIGN.md) (form cells, dependency-set pipeline)
**Audit**: [SRE Track 2D Stage 2 Audit](2026-04-03_SRE_TRACK2D_STAGE2_AUDIT.md)
**Principle**: Propagator Design Mindspace ([DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) § Propagator Design Mindspace)

**Research**:
- [Tree Rewriting as Structural Unification](../research/2026-03-26_TREE_REWRITING_AS_STRUCTURAL_UNIFICATION.md) — rewriting IS the 4th SRE relation
- [Hypergraph Rewriting + Propagator Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — DPO/SPO theory, adhesive categories, critical pairs, e-graphs, interaction nets, GoI
- [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — reduced product, semiring parsing

**Cross-series consumers**:
- [Grammar Form R&D](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) — concrete DPO/HR examples from lifted rules. Grammar productions ARE rewrite rule registrations.
- [PPN Track 4](2026-03-26_PPN_MASTER.md) — critical pair analysis + sub-cell interfaces consumed by elaboration-on-network
- [SRE Track 6 / PM Track 9](2026-03-22_SRE_MASTER.md) — reduction-as-rewriting shares the same relation mechanism. β/δ/ι rules as DPO spans.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0 benchmarks + critical pair analysis on existing 12 rules | ✅ | `299ead31`. 28 tests. Pipeline ~7μs. SRE tag 0.03μs. 1 critical pair found (expand-compose duplicate). See §Pre-0. |
| 1 | DPO span representation: `sre-rewrite-rule` struct | ⬜ | L (ctor-desc pattern), K (binding map), R (template), metadata (directionality, cost, confluence class) |
| 2 | Lift 6 simple rewrites to SRE pattern→template spans | ⬜ | expand-if, expand-let-assign, expand-let-bracket, expand-when, expand-dot-access, rewrite-implicit-map |
| 3 | Fold combinator as Pocket Universe | ⬜ | Right-fold over variable-length children. Monotone on descending element count. Lift expand-cond, expand-do, expand-list-literal, expand-lseq-literal. |
| 4 | SRE decomposition for rule matching (replace tag+guard) | ⬜ | `sre-decompose-generic` against LHS ctor-desc. Sub-structure matching, not just tag. |
| 5 | Explicit interface K: sub-cell binding map | ⬜ | Named bindings shared between L and R. Verifiable: R only references K's bindings. |
| 6 | Critical pair analysis infrastructure | ⬜ | Given two spans, determine LHS overlap. Classify: confluent (same result), conflicting (different results, needs priority). |
| 7 | Integration: replace apply-rules with SRE rewrite dispatch | ⬜ | Wire into existing form pipeline. Pipeline IS the monotone shell — no new stratification. |
| 8 | Verification + acceptance file + PIR | ⬜ | Full suite green, A/B benchmark, all 12 rules pass acceptance tests. |

---

## §1 Objectives

**End state**: The SRE has a REWRITE RELATION — the 4th relation type (after equality, subtyping, duality). Rewrite rules are first-class DPO spans (`L ← K → R`) with explicit interfaces, structural matching via SRE decomposition, and computable critical pair analysis. PPN 2-3's 12 surface rewrite rules are lifted from tag+guard+lambda to SRE spans. Recursive rewrites use a fold combinator in its own Pocket Universe. PPN Track 4 consumes the critical pair analysis and sub-cell interfaces directly.

**What is delivered**:
1. `sre-rewrite-rule` — DPO span struct with L (pattern), K (interface), R (template), metadata
2. 6 simple rules lifted to SRE pattern→template (expand-if, expand-let-assign, expand-let-bracket, expand-when, dot-access, implicit-map)
3. Fold combinator — a Pocket Universe that right-folds a step rule over variable-length children, monotone on descending element count. Lifts expand-cond, expand-do, expand-list-literal, expand-lseq-literal.
4. SRE decomposition replacing tag+guard dispatch in rule matching
5. Explicit interface K as named binding map — verifiable, not positional
6. Critical pair analysis — computable from rule catalog, classifies rule pairs as confluent/conflicting
7. Integration with existing form pipeline — rules fire within the monotone shell, no new stratification

**What this track is NOT**:
- It does NOT implement e-graph equality saturation — that's Track 6 scope. But the span representation carries directionality metadata (one-way vs. equivalence-preserving) so Track 6 can reuse it.
- It does NOT implement β/δ/ι-reduction as rewrite rules — that's Track 6. But β-reduction IS a DPO span, and Track 6 registers it using the mechanism Track 2D builds.
- It does NOT implement the `grammar` toplevel form — that's Grammar Form R&D. But Track 2D's 12 lifted rules are the concrete examples the grammar form design works from.
- It does NOT implement dynamic rule registration from user `defmacro` — that's a follow-up. The infrastructure supports it (register-rewrite-rule! already exists), but the SRE pattern→template format for user macros needs Grammar Form design.

---

## §2 The DPO Span as Information

### The Four Questions (Propagator Design Mindspace)

**What is the information?** A rewrite rule is a FACT: "when a cell value matches pattern L, the value can be transformed to template R, preserving interface K." This fact is data — a struct, not a function.

**What is the lattice?** The set of applicable rewrites for a cell forms a monotone set (rewrites can only be ADDED to the catalog, never removed). The form pipeline's dependency-set tracks which rewrites have FIRED — a powerset lattice, monotone under set-union.

**What is the identity?** A rewrite rule's identity is its span: L determines WHAT it matches, K determines WHAT it preserves, R determines WHAT it produces. Two rules with the same L, K, R are the same rule regardless of registration order.

**What emerges?** The fully-rewritten form emerges from the pipeline reaching quiescence — all applicable rewrites have fired, the dependency-set is complete. Normalization is NOT constructed step-by-step; it is READ from the pipeline cell at fixpoint.

### The DPO Span

```
L ← K → R

L: the LEFT pattern — what the rule matches (SRE ctor-desc)
K: the INTERFACE — what's preserved (named binding map)
R: the RIGHT template — what's produced (reconstruction from K's bindings)
```

**Metadata on the span**:
- `directionality`: `'one-way` (surface normalization — L consumed, R replaces) or `'equivalence` (e-graph — both L and R persist in the class). Track 2D implements one-way only; Track 6 adds equivalence.
- `cost`: tropical semiring value for optimization. Default 0. Grammar Form's optimization extensions use this for cost-weighted rewriting.
- `confluence-class`: `'strongly-confluent` (no critical pairs with any other rule in the stratum) or `'priority-resolved` (has critical pairs, resolved by priority ordering). Computed by critical pair analysis (Phase 6).
- `stratum`: which pipeline stratum this rule fires in. Inherited from PPN 2-3's existing stratification.

---

## §Pre-0: Benchmark Data and Findings

**Benchmark file**: `benchmarks/micro/bench-sre-track2d.rkt` (commit `299ead31`)
**28 tests across 5 tiers**: M1-M7 micro, A1-A5 adversarial, E1-E4 E2E, V1-V5 validation, C1-C3 confluence.

### Performance Baselines

| Operation | Cost | Design Implication |
|-----------|------|-------------------|
| Full pipeline per form (M1a) | 7μs | Dominated by pipeline iteration, not rule matching. SRE lift won't change this. |
| Pipeline overhead, no match (M1d) | 5.9μs | Framework floor — advance-pipeline loop cost. |
| SRE tag lookup (M2a) | 0.03μs | O(1) via prop:ctor-desc-tag. Replacement path is fast. |
| SRE tag + extract (M3a) | 0.03μs | Decomposition adds ~0μs. Extract-fn is struct accessor. |
| hash-ref named K (M5a) | 0.012μs | 3× list-ref (0.004μs). Both sub-0.02μs — negligible in 7μs pipeline. |
| build-node 4 children (M4a) | 0.3μs | Dominant per-step cost. Shared between old and new. |
| foldr 5 elements (M7a) | 0.04μs | Fold combinator overhead is construction, not iteration. |
| cond 20 arms (A1c) | 31μs | Linear scaling. No concern for fold Pocket Universe. |
| list 50 elements (A2c) | 35μs | Linear scaling. |

**Key insight**: Pipeline framework (~6μs) dominates. Rule matching is negligible. Track 2D's benefit is STRUCTURAL (explicit interfaces, critical pair analysis, DPO formalism) not performance.

### Critical Finding: expand-compose Duplicate Registration

The critical pair analysis found 1 overlap: `expand-compose` is registered TWICE in V0-2 with the same `tag-compose` LHS:
- **Line 908 (PPN Track 2)**: `for/fold` right-to-left composition. Registered first → always fires.
- **Line 1224 (PPN Track 2B)**: `foldl` left-to-right composition (`>>` semantics). Registered second → DEAD CODE.

These have DIFFERENT semantics (opposite composition order). The Track 2B version is correct for `>>` (pipe-forward = left-to-right). The Track 2 version does standard `compose` (right-to-left) which is wrong for `>>`. The duplicate registration made the Track 2B fix silently ineffective.

This validates the critical pair analysis design — it caught a real semantic bug in the existing rule set.

### Strata Distribution

All 13 rules are in V0-2. Strata V0-0, V0-1, V1, V2 are EMPTY. The stratification infrastructure is dormant — all rewrites fire in one stratum. Simplifies Track 2D integration.

### Design Impact

**No design changes.** The data confirms:
1. SRE lift is performance-neutral (pipeline dominates)
2. Named K (hash-ref) is negligible overhead vs positional (list-ref)
3. Fold scaling is linear — no concern for Pocket Universe
4. Critical pair analysis catches real bugs — validates Phase 6
5. Duplicate expand-compose fix is Track 2D Phase 2 scope

---

## §3 Design

### §3.1 Phase 1: DPO span representation

```racket
(struct sre-rewrite-rule
  (name              ;; symbol — debugging/tracing
   lhs-desc          ;; ctor-desc or pattern-desc — what the rule matches
   interface-keys    ;; (listof symbol) — named bindings in K
   rhs-template      ;; (hasheq symbol → template-expr) — how to build R from K
   guard             ;; (node → boolean) or #f — additional match condition (transitional)
   directionality    ;; 'one-way or 'equivalence
   cost              ;; number (tropical semiring value, default 0)
   confluence-class  ;; 'unknown, 'strongly-confluent, or 'priority-resolved
   priority          ;; natural — for priority-resolved rules
   stratum)          ;; symbol — pipeline stratum
  #:transparent)
```

The `lhs-desc` is an SRE ctor-desc for simple rules. For rules that need richer matching (sub-structure guards beyond tag), this becomes a `pattern-desc` — a ctor-desc plus sub-component patterns. Phase 4 designs this.

The `rhs-template` is a hash from K binding names to template expressions. A template expression is either:
- A binding reference: `'(ref name)` — use the bound sub-cell
- A constant: `'(const token)` — inject a constant value
- A construction: `'(build tag children...)` — build a new node from sub-expressions

### §3.2 Phase 2: Lift 6 simple rewrites

Each simple rule has fixed arity and clear interface. Example — `expand-if`:

**Current** (lambda):
```racket
(lambda (children srcloc indent)
  (define cond-child (list-ref children 1))
  (define then-child (list-ref children 2))
  (define else-child (list-ref children 3))
  (build-node tag-expr (list (make-token "boolrec") (make-token "_")
                             then-child else-child cond-child) srcloc indent))
```

**Lifted** (DPO span):
```racket
(sre-rewrite-rule
  'expand-if
  (lookup-ctor-desc 'if #:domain 'form)  ;; LHS: ctor-desc for if-forms
  '(cond then else)                        ;; K: named interface
  (hasheq 'result '(build expr             ;; R: template
            (const "boolrec") (const "_")
            (ref then) (ref else) (ref cond)))
  #f                                       ;; no guard
  'one-way 0 'unknown 100 'V0-2)
```

**The transformation**: positional `(list-ref children N)` → named `(ref name)`. The interface K declares the names. The template R references them. Verifiable: every `(ref X)` in R must have a corresponding `X` in K.

6 rules to lift: expand-if, expand-let-assign, expand-let-bracket, expand-when, expand-dot-access, rewrite-implicit-map.

### §3.3 Phase 3: Fold combinator as Pocket Universe

The 4 recursive rewrites (expand-cond, expand-do, expand-list-literal, expand-lseq-literal) all follow the same pattern: `foldr step-rule base-case elements`.

**The fold as a Pocket Universe**:

```
Cell value: fold-state
  elements:  (listof node) — remaining elements to fold
  accumulator: node — the built-up result so far

Lattice: descending chain on element count
  ⊤ = all elements remaining
  ⊥ = no elements remaining (fold complete)
  Merge: take the state with FEWER remaining elements (monotone toward completion)

Propagator: fires when elements is non-empty
  - Pops first element
  - Applies step-rule: (step element accumulator) → new accumulator
  - Writes new fold-state with (cdr elements), new accumulator

Quiescence: elements empty → accumulator IS the result
```

This IS a Pocket Universe — the fold state is an embedded lattice within the cell. The merge function understands the fold structure. Each step advances monotonically (element count decreases). Quiescence produces the result.

**The step-rule IS a DPO span**: L = `(element . rest)`, K = `{element, rest-accumulator}`, R = `(build tag element rest-accumulator)`. The fold combinator applies this span repeatedly.

**Concrete fold rules**:

| Rule | Step span | Base case |
|------|----------|-----------|
| expand-cond | `(arm . rest) → (if guard body rest)` | last arm → `(if guard body unit)` |
| expand-do | `(expr . rest) → (let [_ := expr] rest)` | last expr → identity |
| expand-list-literal | `(elem . rest) → (cons elem rest)` | `nil` |
| expand-lseq-literal | `(elem . rest) → (lseq-cell elem (fn [_:_] rest))` | `lseq-nil` |

### §3.4 Phase 4: SRE decomposition for rule matching

**Current**: `apply-rules` iterates rules, checks `eq?` on tag, calls guard predicate. O(N) in rules per stratum.

**Redesigned**: SRE decomposition matches the cell value against the LHS ctor-desc. The existing `prop:ctor-desc-tag` property on structs provides O(1) tag lookup. Decomposition binds the named interface K.

For simple rules (tag-only LHS), this is equivalent to the current dispatch but structured. For rules that need sub-structure matching (future: grammar form productions), decomposition is MORE EXPRESSIVE — it can match on child patterns, not just the outermost tag.

**Guard transitional path**: The `guard` field on `sre-rewrite-rule` is TRANSITIONAL. It allows existing guard predicates (e.g., expand-let-assign's check for `:=` token at position 2) to work during migration. The permanent mechanism: rich LHS patterns that express the guard structurally. The guard field is scaffolding, retired when the LHS pattern language is expressive enough.

### §3.5 Phase 5: Explicit interface K

The interface K is a `(listof symbol)` declaring the named sub-cells shared between L and R. Adding verification:

```racket
(define (verify-rewrite-rule rule)
  ;; Every (ref X) in R must have X in K
  (define k-names (sre-rewrite-rule-interface-keys rule))
  (define r-refs (collect-template-refs (sre-rewrite-rule-rhs-template rule)))
  (for ([ref-name (in-list r-refs)])
    (unless (member ref-name k-names)
      (error 'verify-rewrite-rule
             "RHS references ~a but K only declares ~a"
             ref-name k-names))))
```

This is the DPO INTERFACE PRESERVATION guarantee: R cannot reference bindings that K doesn't provide. It cannot fabricate sub-cells. It can only RECONNECT what L decomposed.

For the fold combinator: the step-rule's K includes `element` and `accumulator`. The fold guarantees these are the only inputs to each step.

### §3.6 Phase 6: Critical pair analysis

Two rules have a CRITICAL PAIR if their LHS patterns can match the SAME cell value and produce DIFFERENT results.

```racket
(define (find-critical-pairs rules)
  ;; For each pair of rules in the same stratum:
  ;; 1. Can their LHS descs match the same value?
  ;;    (same tag + overlapping guard conditions)
  ;; 2. If yes, do their RHS templates produce the same result
  ;;    given the same input?
  ;; 3. If different results → critical pair. Record it.
  ...)
```

For PPN 2-3's 12 rules: each rule has a UNIQUE LHS tag (tag-if, tag-cond, tag-do, etc.). No two rules share a tag within a stratum. **Result: zero critical pairs. The rule set is strongly confluent.** This means firing order within a stratum doesn't matter — the existing priority ordering is unnecessary (but harmless).

The analysis infrastructure is consumed by:
- **Grammar Form**: user-defined productions may introduce critical pairs. The analysis warns the user at grammar definition time, not at parse time.
- **PPN Track 4**: elaboration rules (type inference as rewriting) need confluence guarantees for the propagator scheduler.
- **SRE Track 6**: reduction rules (β/δ/ι) are confluent by the Church-Rosser property, but the analysis VERIFIES this computably.

### §3.7 Phase 7: Integration with form pipeline

The existing form pipeline in surface-rewrite.rkt has strata (V0-0 through V2) that call `apply-rules`. Phase 7 replaces `apply-rules` with SRE rewrite dispatch:

```racket
;; Old: iterate rules, match tag, call lambda
(define (apply-rules node stratum) ...)

;; New: SRE decompose against registered spans, apply template
(define (apply-sre-rewrite node stratum)
  (define rules (lookup-sre-rewrite-rules stratum))
  (for/first ([rule (in-list rules)]
              #:when (sre-matches-lhs? node (sre-rewrite-rule-lhs-desc rule)
                                       (sre-rewrite-rule-guard rule)))
    (define bindings (sre-decompose-for-rewrite node rule))
    (define result (instantiate-rhs-template rule bindings node))
    (values result #t)))
```

The pipeline infrastructure (dependency-set, `advance-pipeline`, `form-pipeline-value`) is UNCHANGED. Only the rule dispatch mechanism changes. This is a refactoring of Layer 3 (imperative lambdas → SRE templates) within the existing Layer 2 (on-network pipeline).

---

## §4 NTT Model

```
-- The rewrite relation as 4th SRE relation
lattice FormPipeline
  :carrier (PowerSet Transform) × TreeNode
  :bot     ({}, raw-node)
  :top     ({done}, final-node)
  :join    set-union on transforms, advance tree-node

relation rewrite
  :properties {directional}       -- NOT symmetric (unlike equality)
  :span [L <- K -> R]             -- DPO span
  :apply [cell-value ->
    | decompose(cell-value, L) -> bindings
    | instantiate(R, bindings) -> new-value
    | advance pipeline transform set]

-- Fold combinator as embedded Pocket Universe
cell fold-state
  :carrier (List Element) × Accumulator
  :lattice descending-chain on element count
  :propagator [state ->
    | empty?(elements) -> quiescent (accumulator IS result)
    | otherwise        -> apply step-rule to (head, accumulator)
                          write (tail, new-accumulator)]

-- DPO span with metadata
struct sre-rewrite-rule
  :lhs   ctor-desc               -- SRE pattern
  :k     (List Symbol)           -- named interface
  :rhs   template                -- reconstruction from K
  :dir   one-way | equivalence   -- Track 2D: one-way. Track 6: equivalence.
  :cost  Nat                     -- tropical semiring (default 0)
  :confluence strongly | priority-resolved | unknown
```

### NTT Correspondence Table

| NTT Construct | Racket Implementation | File |
|---------------|----------------------|------|
| `sre-rewrite-rule` | `sre-rewrite-rule` struct | sre-core.rkt or sre-rewrite.rkt (NEW) |
| `relation rewrite` | 5th `sre-relation` in sre-core.rkt | sre-core.rkt |
| `fold-state` | fold Pocket Universe in surface-rewrite.rkt | surface-rewrite.rkt |
| `apply-sre-rewrite` | replaces `apply-rules` | surface-rewrite.rkt |
| `verify-rewrite-rule` | interface verification | sre-rewrite.rkt (NEW) |
| `find-critical-pairs` | critical pair analysis | sre-rewrite.rkt (NEW) |
| `instantiate-rhs-template` | template instantiation from K bindings | sre-rewrite.rkt (NEW) |

---

## §5 Connections to Future Work

### E-graphs (SRE Track 6)

The span's `directionality` field distinguishes Track 2D's one-way rewrites from Track 6's equivalence-preserving rewrites. In the e-graph model, applying a rule with `'equivalence` directionality ADDS R to L's equivalence class (via the cell's merge function) rather than replacing L with R. The span representation is the same; the application semantics differ by directionality.

The type lattice's union-join (Track 2H) IS an equivalence class under the subtype ordering. E-graph equality saturation on types uses union-join as the class merge. Track 2D's span + Track 2H's union-join = the foundation for Track 6's type-level e-graph.

### Interaction Nets

PPN 2-3's 12 rules have zero critical pairs (unique LHS tags per stratum). This means the rule set is STRONGLY CONFLUENT — the interaction net property. Rules can fire in any order or in parallel within a stratum. The critical pair analysis (Phase 6) VERIFIES this computably.

For Track 6: β/δ/ι-reduction rules are confluent by Church-Rosser. The analysis provides computable verification. User-defined rewrite rules (from `grammar` form) may NOT be confluent — the analysis warns at definition time.

### GoI and Path Tracing

GoI models computation as paths through a graph. In the SRE, a rewrite's propagation path (LHS decomposition → K binding → RHS reconstruction → downstream effects) IS a GoI trace. The monotone pipeline guarantees order-independence (GoI's invariance result). Track 2D doesn't formalize this as GoI — but the architecture inherits the property.

### β-reduction as DPO Span

Track 2H's `type-tensor-core` (function application at the type level) IS a DPO span:
- L = `(Pi domain codomain) applied-to arg`
- K = `{codomain, arg}`
- R = `codomain[arg/binder]` (substitution)

Track 6 registers this as a rewrite rule. Track 2D provides the mechanism.

---

## §6 Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Template language insufficiently expressive for all 12 rules | Medium | Guard field provides transitional escape hatch. expand-quasiquote (tree walk) may stay as lambda initially. |
| Fold Pocket Universe adds allocation overhead | Low | Fold state is small (list + accumulator). Existing pipeline already allocates per-transform. |
| SRE decomposition slower than tag eq? for simple cases | Low | ctor-desc-tag via prop:ctor-desc-tag is O(1). No regression for tag-only matching. |
| Critical pair analysis is O(N²) in rules | Low | 12 rules → 66 pairs. Future grammar forms may have more — cache results. |
| expand-quasiquote doesn't fit fold pattern (recursive tree walk) | Medium | Leave as lambda initially. Design a tree-walk combinator if needed. |

---

## §7 Test Strategy

**Phase 0**: Pre-0 benchmarks
- Measure `apply-rules` dispatch cost per stratum
- Critical pair analysis on existing 12 rules (expect: zero pairs)
- Benchmark fold cost (list processing overhead)

**Per-phase**: Each lifted rule gets a targeted test comparing old lambda output to new template output on the same input.

**Phase 8**: Full suite GREEN + A/B comparison. Acceptance file exercises all 12 rules.

---

## §8 Cross-References

- [Stage 2 Audit](2026-04-03_SRE_TRACK2D_STAGE2_AUDIT.md) — 12 rules cataloged, DPO correspondence, on-network analysis
- [SRE Track 2H PIR](2026-04-03_SRE_TRACK2H_PIR.md) — type-tensor-core IS a DPO span at the type level
- [PPN Master Track 4](2026-03-26_PPN_MASTER.md) — consumes critical pair analysis and sub-cell interfaces
- [SRE Track 6 (Reduction-on-SRE)](2026-03-22_SRE_MASTER.md) — shares the rewrite relation mechanism; adds equivalence directionality
