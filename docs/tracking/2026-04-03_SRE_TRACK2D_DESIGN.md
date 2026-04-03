# SRE Track 2D: Rewrite Relation — Stage 3 Design (D.5)

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
| 1 | Form tags as first-class ctor-descs in `'form` domain + DPO span struct | ✅ | `1b059003`. sre-rewrite.rkt: DPO span, pattern-desc, PUnify holes, monotone registry, verification, critical pairs, form-tag ctor-descs. |
| 2 | Lift simple rewrites to SRE spans | ✅ | `25a697aa`. 5 rules (if-3, if-4, when, let-assign, let-bracket). match-pattern-desc + instantiate-template. Compose dup noted. |
| 3a | Fold combinator as PU micro-stratified | ✅ | `e67f0820`. run-fold (right-fold, Option C). 3 fold rules: list-literal, lseq-literal, do. Cond stays as lambda (arm-splitting limitation). |
| 3b | Tree-structural combinator as Pocket Universe | ✅ | `dbf793d5`. tree-structural-rewrite + quasiquote-position-fn. Per-position classification + nested recursion + fold composition. |
| 4 | pattern-desc + per-rule propagators (replace iteration dispatch) | ✅ | `c86594be`. make-rewrite-propagator-fn (fire fn factory), apply-sre-rewrite-rule, apply-all-sre-rewrites. |
| 5 | K as sub-cells (PUnify pattern) with verification | ✅ | `59609525`. rewrite-binding-context abstracts hash vs cells. Fresh per fold step (NAF-LE). Verification from Phase 1 intact. |
| 6 | Critical pair analysis infrastructure | ✅ | `43773669`. analyze-confluence + report. Arity-aware overlap. 9 rules → 0 critical pairs (strongly confluent). |
| 7 | Integration: wire per-rule propagators into form pipeline | ⬜ | Rules fire as propagators within pipeline's monotone shell. |
| 8 | Verification + acceptance file + PIR | ⬜ | Full suite green, A/B, all 13 rules pass. |

---

## §1 Objectives

**End state**: The SRE has a REWRITE RELATION — the 4th relation type (after equality, subtyping, duality). Rewrite rules are first-class DPO spans (`L ← K → R`) with explicit interfaces, structural matching via SRE decomposition, and computable critical pair analysis. PPN 2-3's 12 surface rewrite rules are lifted from tag+guard+lambda to SRE spans. Recursive rewrites use a fold combinator in its own Pocket Universe. PPN Track 4 consumes the critical pair analysis and sub-cell interfaces directly.

**What is delivered**:
1. Form tags as first-class ctor-descs in a `'form` domain — SRE-native, structural decomposition, Grammar Form registration target
2. `sre-rewrite-rule` — DPO span with `pattern-desc` LHS, K as sub-cells (PUnify pattern), template-tree R (parse-tree-node with PUnify holes)
3. `pattern-desc` — extends ctor-desc with positional child patterns, literal matching, variadic tail, arity alternatives. Retires guard field. Grammar Form compilation target.
4. Per-rule propagators — each rule watches a form cell, fires on LHS match, writes RHS. No iteration dispatch. Parallel-safe (zero critical pairs). Cell merge resolves conflicts for user-defined rules.
5. Simple rules lifted to SRE spans. Fix expand-compose duplicate. Templates as parse-tree-nodes with PUnify holes (structural unification fills holes, not imperative walk).
6. Fold combinator — Option C PU micro-strata. One cell, progress tracks internally, no per-step allocation. Track 6 can upgrade to Option B (per-step cells) if reduction interleaving needed.
7. Tree-structural combinator — PU with embedded per-position lattice. PUnify fills holes in parallel. Lifts expand-quasiquote.
8. K as sub-cells (PUnify pattern) — decomposition writes sub-cells, reconstruction reads. Verification: template holes ⊆ K bindings. DPO interface preservation.
9. Rule registry as cell — Grammar Form writes dynamically. Implement as module-level hash with cell-compatible API; Grammar Form upgrades to network cell.
10. Critical pair analysis — computable from pattern-desc LHS overlap, consumed by PPN Track 4 + Grammar Form

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

### §3.1 Phase 1: Form tags as first-class + DPO span

**Form tags as ctor-descs** (R1 fix, First-Class by Default principle):

Form tags (`tag-if`, `tag-cond`, etc.) become first-class SRE citizens in a `'form` domain. Each tag gets a registered ctor-desc:

```racket
(register-ctor! 'if
  #:arity 3   ;; cond, then, else (excluding tag token)
  #:recognizer (lambda (v) (and (parse-tree-node? v)
                                (eq? (parse-tree-node-tag v) 'if)))
  #:extract (lambda (v) (cdr (rrb-to-list (parse-tree-node-children v))))  ;; drop tag token
  #:reconstruct (lambda (vals) (make-node 'if vals))
  #:domain 'form)
```

This enables: SRE structural decomposition of form nodes, critical pair analysis via ctor-desc overlap, and Grammar Form dynamically registering new form tags as ctor-descs.

**Rule registry as cell** (M1):

```racket
;; API compatible with future network cell. Grammar Form writes dynamically.
;; Implement: module-level hash. Permanent: cell on the network.
;; INVARIANT (F5): rules are ONLY added, never removed or overwritten.
;; This enforces monotonicity — the rule catalog only grows.
;; The hash never calls hash-remove!. Grammar Form migration to cell
;; is straightforward: register = cell write (monotone add).
(define (register-sre-rewrite-rule! rule) ...)   ;; = cell write (monotone)
(define (lookup-sre-rewrite-rules stratum) ...)   ;; = cell read
```

**DPO span struct**:

```racket
(struct sre-rewrite-rule
  (name              ;; symbol — debugging/tracing
   lhs-pattern       ;; pattern-desc — LHS pattern for matching
   interface-keys    ;; (listof symbol) — named K bindings (= sub-cell names)
   rhs-template      ;; parse-tree-node with PUnify holes — the reconstruction template
   directionality    ;; 'one-way (Track 2D) or 'equivalence (Track 6 e-graph)
   cost              ;; number (tropical semiring, default 0)
   confluence-class  ;; 'unknown | 'strongly-confluent | 'priority-resolved
   stratum)          ;; symbol — pipeline stratum
  #:transparent)
```

**RHS template as parse-tree-node with PUnify holes** (R2, not a separate template language):

The template IS a parse-tree-node — same data type as input and output. Leaf positions that reference K bindings are PUnify meta-cells (holes). Instantiation = PUnify structural unification fills holes by information flow, not imperative substitution walk.

```
Template for expand-if:
  (expr [boolrec  _  (hole 'then)  (hole 'else)  (hole 'cond)])
       constant const  ← K ref ←    ← K ref ←     ← K ref ←

Instantiation: PUnify unifies each hole with its K sub-cell value.
Parallel — holes fill independently as sub-cells receive values.
```

Variadic splicing: `(splice 'body)` markers in the template mean "concat this K binding's RRB at this position." RRB supports `rrb-concat` natively.

**Hole representation** (F4 — single unambiguous definition):

A hole in a template is a `parse-tree-node` with tag `'$punify-hole` and a single child: a token whose lexeme is the K binding name. PUnify recognizes this tag and unifies the node with the named K sub-cell value.

```racket
;; Creating a hole:
(define (make-hole binding-name)
  (parse-tree-node '$punify-hole
                   (list->rrb (list (token-entry (seteq 'binding) binding-name 0 0)))
                   #f 0))

;; Recognizing a hole (PUnify integration):
(define (punify-hole? node)
  (and (parse-tree-node? node)
       (eq? (parse-tree-node-tag node) '$punify-hole)))

(define (punify-hole-name node)
  (token-entry-lexeme (rrb-get (parse-tree-node-children node) 0)))
```

A splice marker uses tag `'$punify-splice` — same structure, different tag. PUnify splices the K binding's children into the parent RRB at this position via `rrb-concat`.

This is the ONLY notation for holes — `(hole 'name)` in prose, `$punify-hole` in code. The NTT model uses `(hole 'name)` as sugar.

**guard field REMOVED** — superseded by pattern-desc (Phase 4). Arity alternatives (expand-if has 3-arg and 4-arg) handled by registering multiple rules (one per arity pattern), consistent with DPO (one span per rule).

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

### §3.3a Phase 3a: Fold combinator — Option C (PU micro-stratified)

The 4 recursive rewrites (expand-cond, expand-do, expand-list-literal, expand-lseq-literal) all follow the same pattern: `foldr step-rule base-case elements`.

**Accumulation is non-monotone** (NAF-LE pattern). The accumulator value at each step is NOT "more information" — it's a DIFFERENT value. Sequential aggregation is fundamentally non-monotone. Requires stratification.

**The fold's sequentiality is SEMANTIC, not algorithmic** (F1). For `foldr step base [e1, e2, e3]` producing `step(e1, step(e2, step(e3, base)))`, each step's input IS the previous step's output. This is a data dependency chain — the INFORMATION has sequential structure. The fold's chain IS its lattice ordering. This is not control flow wearing a lattice hat; it is genuinely sequential information expressed as a chain lattice within the Pocket Universe.

**Option analysis**:
- **Option B (full cells)**: Each fold step is a separate cell + propagator on the network. Per-step allocation. Enables interleaving fold steps with other network activity. Track 6 scope (β-reduction may need interleaving with type constraint propagation).
- **Option C (PU micro-strata)**: ONE cell. The PU value tracks progress internally. Micro-strata execute within a single pipeline cycle. No per-step cell allocation. Fold completes before next pipeline stratum fires. Observable: PU value shows current progress + accumulator at any point.

**Track 2D implements Option C.** Rationale: surface rewrites don't need interleaving — the fold is purely syntactic. Option B is Track 6 scope (reduction may need type feedback between steps). Option C is sufficient, observable, and avoids the allocation cost of 20 cells + 20 propagators for a 20-arm cond.

```
Cell value: fold-pu-state (Pocket Universe)
  progress:    Nat — micro-stratum index (ASCENDING — monotone dimension)
  accumulator: node — built-up result (changes between micro-strata, gated by progress)
  elements:    (listof node) — original input (immutable)
  step-rule:   sre-rewrite-rule — the DPO span to apply per step

Merge: take value with higher progress (monotone on progress).
Micro-strata execute within a single advance-pipeline cycle.
Observable: any observer of the cell sees current (progress, accumulator).
Quiescence: progress = length(elements) → accumulator IS the result.
```

**Relationship to form pipeline** (F6 — reframed): The fold PU and form pipeline BOTH use progress tracking with a monotone dimension. But they are DIFFERENT structures. The form pipeline is a PARALLEL transform computation — transforms are independent (confirmed by critical pair analysis). The fold PU is a STRATIFIED SEQUENTIAL computation — each step depends on the previous accumulator. Both embed non-monotone state changes inside a monotone cell, but the dependency structures differ (DAG vs chain). Do not conflate them.

**The step-rule IS a DPO span**: L matches `(element . rest-state)`, K binds `{element, accumulator}`, R reconstructs via PUnify template instantiation. Each micro-stratum applies the span once and advances progress.

**Concrete fold rules**:

| Rule | Step span | Base case |
|------|----------|-----------|
| expand-cond | `(arm . rest) → (if guard body rest)` | last arm → `(if guard body unit)` |
| expand-do | `(expr . rest) → (let [_ := expr] rest)` | last expr → identity |
| expand-list-literal | `(elem . rest) → (cons elem rest)` | `nil` |
| expand-lseq-literal | `(elem . rest) → (lseq-cell elem (fn [_:_] rest))` | `lseq-nil` |

### §3.3b Phase 3b: Tree-structural combinator as Pocket Universe

**expand-quasiquote** doesn't fit simple spans or fold — it's a recursive tree transformation with splicing. But imperative tree-walking is the wrong abstraction (PPN Track 1-2 lesson). The SRE can reason about tree structure ALL AT ONCE.

**The tree-structural combinator as Pocket Universe** (M3):

One PU cell with an embedded per-position lattice. The PU value tracks which positions have been processed. Merge = set-union on processed positions. The RRB-as-tree value holds the partially-rewritten tree. Same pattern as the form pipeline — one cell, embedded progress lattice. No cell-per-position explosion.

```
Cell value: tree-pu-state (Pocket Universe)
  tree:       parse-tree-node — the input tree
  processed:  (seteq position) — which positions done (ASCENDING — monotone)
  result:     parse-tree-node — partially-rewritten tree

Lattice: ascending on processed-count.
Merge: set-union on processed. RRB merge for result.

Per-position processing (within PU):
  - SRE recognizes the node at this position (ctor-desc tag match)
  - If $unquote: PUnify fills the hole with the spliced expression
  - If regular token: datum-conversion produces the constructor call
  - Positions are INDEPENDENT → PU can process them in any order (parallel within PU)

Reconstruction: when all positions processed → result IS the final tree.
```

**PUnify fills holes, not an imperative walk** (R2). The quasiquote template is a parse-tree-node with PUnify meta-cell holes at `$unquote` positions. PUnify's structural unification fills holes by information flow — each hole resolves independently as its corresponding K sub-cell receives a value. No sequential tree traversal.

**Position indexing and splice handling** (F9):

Positions in the tree PU use PRE-SPLICE indices. The processed-set tracks which original positions have been handled. When splicing at position K adds N new children, the splice is a REFINEMENT of position K — monotone (position K goes from "unprocessed" to "processed, expanded to K.0, K.1, ..., K.N"). Post-splice positions are hierarchical (K.0, K.1), not shifted integers. This preserves monotonicity: no existing processed position is invalidated by a splice at another position.

```
Pre-splice tree:  [token₀, $unquote₁, token₂, node₃]
Processed-set:    {} → {0} → {0, 1} → {0, 1, 2} → {0, 1, 2, 3}
Position 1 splice: $unquote₁ resolves to (expr a b)
Post-splice:       [token₀, expr-a, expr-b, token₂, node₃]
Position indices:  [0,       1.0,    1.1,    2,      3]
```

The processed-set is stable: adding position 1 never changes position 2's index. Splicing refines a position into sub-positions (1 → 1.0, 1.1) — monotone within the position's value.

**Recursive sub-trees**: If node₃ contains its own quasiquote structure, it gets its OWN nested tree PU — a Pocket Universe within a Pocket Universe. Each PU processes its level independently. Reconstruction composes results when all levels complete.

**The tree combinator generalizes the fold**: a fold IS a tree-structural operation on a list-shaped tree where positions are ORDERED (fold step depends on prior accumulator). The tree combinator relaxes the ordering constraint — positions are independent. Track 2D implements the fold (sequential accumulation, PU micro-strata) and the tree combinator (parallel recognition, PU embedded lattice). Future grammar forms use whichever fits their production shape.

### §3.4 Phase 4: SRE decomposition + pattern-desc for rule matching

**Current**: `apply-rules` iterates rules, checks `eq?` on tag, calls guard predicate. O(N) in rules per stratum.

**Redesigned**: SRE decomposition matches the cell value against a `pattern-desc` — an extension of ctor-desc with sub-component patterns.

**pattern-desc** (minimum viable, retiring guards):

```racket
(struct pattern-desc
  (tag              ;; symbol — outermost tag (existing ctor-desc tag)
   child-patterns   ;; (listof child-pattern) — per-position patterns
   variadic-tail    ;; symbol or #f — K binding for remaining children
   )
  #:transparent)

(struct child-pattern
  (position         ;; natural — which child
   kind             ;; 'token | 'node | 'any — what type of child
   literal          ;; string or #f — for token literal matching (e.g., ":=")
   bind-name        ;; symbol or #f — K binding name (e.g., 'value)
   )
  #:transparent)
```

**Example** — expand-let-assign (currently uses guard for `:=` check):

```racket
(pattern-desc
  tag-let-assign
  (list (child-pattern 0 'token "let" #f)       ;; literal "let" at pos 0
        (child-pattern 1 'any #f 'name)          ;; bind child 1 as 'name
        (child-pattern 2 'token ":=" #f)         ;; literal ":=" at pos 2 (replaces guard!)
        (child-pattern 3 'any #f 'value))        ;; bind child 3 as 'value
  'body)                                          ;; variadic tail as 'body
```

This retires the guard field for expand-let-assign and expand-let-bracket. The guard was an arbitrary predicate; the pattern-desc is STRUCTURAL — verifiable, composable, and the same representation Grammar Form compiles to.

**Connection to Grammar Form R&D**: The `pattern-desc` IS what a grammar production's LHS compiles to. The user writes:

```
production let-assign
  | "let" name:ident ":=" value:expr body:expr+ -> ...
```

This compiles to a `pattern-desc` with literal matches, typed bindings, and variadic tail. Track 2D designs the internal representation; Grammar Form R&D designs the surface syntax. Same thing at different levels.

**Richer patterns (future, Grammar Form scope)**:
- Nested patterns: child matches another pattern-desc
- Alternatives: child matches one of several patterns
- Optional children: 0 or 1 occurrence
- Repetition with separator: `expr ("," expr)*`

Track 2D implements minimum viable (tag + positional + literal + variadic). Grammar Form extends as needed.

**Per-rule propagators** (M2 — replacing iteration dispatch):

Each registered rewrite rule becomes a propagator watching the form cell:

```
For each rule R in the catalog:
  Create propagator P_R:
    Watches: form cell C
    Fires when: pattern-desc of R matches C's value
    Body: decompose C → K sub-cells, PUnify fills template holes → write result to C
```

No iteration. No priority ordering. All matching propagators fire. With zero critical pairs (current 13 rules — unique tags per stratum), exactly ONE propagator fires per form cell. Cell merge resolves conflicts if Grammar Form introduces overlapping rules.

**Dispatch cost**: ctor-desc tag on the `'form` domain provides O(1) tag lookup. Each rule's propagator checks its pattern-desc against the cell value. With one propagator per tag and unique tags, this is O(1) effective dispatch. Pattern-desc child matching adds O(K) per matched rule where K ≤ 5. Negligible vs. the 7μs pipeline overhead.

**Arity alternatives**: expand-if has 3-arg and 4-arg forms. Register as TWO rules (one per arity pattern). Each becomes its own propagator. Only the one matching the actual arity fires. Consistent with DPO: one span per rule.

### §3.5 Phase 5: K as sub-cells (PUnify pattern) with verification

**K bindings are sub-cells, not a hash** (M4). The PUnify model: LHS decomposition creates sub-cells for each K binding. RHS template holes are PUnify meta-cells that reference these sub-cells. When decomposition writes a value to a sub-cell, the corresponding template hole resolves. Reconstruction fires when all holes are filled.

```
LHS decomposition:
  form cell value matches pattern-desc
  → creates sub-cells: K_cond, K_then, K_else
  → writes extracted children to sub-cells

RHS reconstruction:
  template parse-tree-node has PUnify holes at K positions
  → PUnify unifies each hole with its sub-cell
  → when all holes filled: reconstruction propagator fires
  → writes completed result back to form cell
```

**Efficiency**: K sub-cells are a fixed set per rule (e.g., `{cond, then, else}` for expand-if). Created once per rule application. PUnify fills holes in parallel — independent holes resolve independently. No sequential substitution walk.

For the fold combinator: K sub-cells are `{element, accumulator}`. Created once per fold instance.

**Sub-cell reset within PU micro-strata** (F3): Each micro-stratum writes NEW values to K sub-cells. This is non-monotone — PUnify cells normally only gain information. The fold PU manages this via explicit sub-cell reset at micro-stratum boundaries, gated by progress advancement. This is the NAF-LE pattern applied to sub-cells: non-monotone state changes are legal WITHIN a stratification boundary, gated by the monotone progress dimension. The sub-cell reset is an explicit operation within the PU, not a violation of PUnify's monotonicity — the PU's stratification boundary authorizes it, just as the form pipeline's tree-node changes between transforms.

**Verification** (DPO interface preservation):

```racket
(define (verify-rewrite-rule rule)
  ;; Every hole in the RHS template must correspond to a K binding
  (define k-names (sre-rewrite-rule-interface-keys rule))
  (define holes (collect-punify-holes (sre-rewrite-rule-rhs-template rule)))
  (for ([hole-name (in-list holes)])
    (unless (member hole-name k-names)
      (error 'verify-rewrite-rule
             "RHS has hole ~a but K only declares ~a"
             hole-name k-names))))
```

R cannot reference bindings that K doesn't provide. R cannot fabricate sub-cells. R can only RECONNECT what L decomposed. This is verifiable at rule registration time — before any rule fires.

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

### §3.7 Phase 7: Wire per-rule propagators into form pipeline

**No iteration dispatch** (F2 — stale D.1 code removed). The Phase 4 per-rule propagator design IS the integration. Each registered rule creates a propagator that watches the form cell:

```
Registration (at rule register time):
  For each rule R:
    Create propagator P_R on the form cell
    P_R fires when: cell value matches R's pattern-desc
    P_R body: decompose → K sub-cells → PUnify fills template → write result

Pipeline integration:
  advance-pipeline no longer calls apply-rules for rewrite strata.
  Instead: advance-pipeline advances the pipeline transform-set.
  The transform advancement TRIGGERS form cell value change.
  Per-rule propagators WATCH the cell and fire when their LHS matches.
  Quiescence = all applicable rules have fired for this transform step.
```

The pipeline infrastructure (dependency-set, `advance-pipeline`, `form-pipeline-value`) is UNCHANGED in structure. The change: rewrite strata don't call an iteration function — they advance the pipeline, and propagators fire. The pipeline's monotone shell (transform-set advancement) coordinates WHEN propagators become relevant. The propagators decide WHAT fires.

**Conflict merge** (F7): If two propagators fire for the same form cell (critical pair — not in current 13 rules, but possible with Grammar Form user-defined rules), the cell's merge function resolves. The merge for conflicting rewrites = **top (contradiction)** — two different rewrites for the same form IS an ambiguity error. This matches the type lattice pattern (incompatible information → contradiction). The critical pair analysis (Phase 6) PREDICTS this at registration time; the cell merge CATCHES it at runtime.

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

-- Form tags as first-class ctor-descs
domain form
  :ctor-descs [tag-if, tag-cond, tag-let-assign, ...]  -- registered per tag
  :recognizer [v -> parse-tree-node? AND tag matches]

-- Per-rule propagator (replaces iteration dispatch)
propagator rewrite-rule-P
  :watches form-cell
  :fires-when (pattern-desc matches cell-value)
  :body [
    decompose cell-value via pattern-desc → K sub-cells
    PUnify fills template holes from K sub-cells
    write reconstructed result to cell]
  :parallel all matching rules fire. zero critical pairs → one fires.

-- K as sub-cells (PUnify pattern)
-- Decomposition WRITES sub-cells. Reconstruction READS sub-cells.
-- Holes = $punify-hole tagged nodes in template tree (F4).
sub-cells K
  :created-by LHS decomposition
  :consumed-by RHS template (PUnify fills $punify-hole nodes)
  :verification template-holes ⊆ K-names (at registration time)
  :fold-reset sub-cells reset at PU micro-stratum boundary (F3, NAF-LE)

-- Conflict merge for overlapping rewrites (F7)
-- Two propagators fire for same cell → merge resolves
merge form-cell
  :compatible same-rewrite-result → identity
  :conflicting different-results → top (contradiction = ambiguity error)

-- Fold combinator: Option C (PU micro-strata, one cell)
cell fold-pu
  :carrier Nat × Accumulator × (List Element)
  :monotone-dim progress (ascending: 0 → N)
  :non-monotone-dim accumulator (gated by progress — NAF-LE pattern)
  :micro-strata within single pipeline cycle (no per-step cells)
  :K sub-cells {element, accumulator} — reused across micro-strata
  :upgrade-path Option B (per-step cells) for Track 6 reduction interleaving

-- Tree-structural combinator: PU with embedded per-position lattice
cell tree-pu
  :carrier TreeNode × (SetEq Position)
  :monotone-dim processed positions (ascending)
  :per-position PUnify fills holes independently (parallel within PU)
  :reconstruction when all positions processed

-- Pattern-desc: extends ctor-desc for Grammar Form compilation target
struct pattern-desc
  :tag          symbol                     -- outermost form tag
  :children     (List child-pattern)       -- per-position: kind, literal, bind-name
  :variadic     symbol | #f               -- K binding for rest-of-children
  -- Arity alternatives: register multiple rules (one per arity)
  -- Guards RETIRED: structural patterns replace arbitrary predicates

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
| `sre-rewrite-rule` | `sre-rewrite-rule` struct | sre-rewrite.rkt (NEW) |
| `pattern-desc` | `pattern-desc` struct (extends ctor-desc) | sre-rewrite.rkt (NEW) |
| `relation rewrite` | 5th `sre-relation` in sre-core.rkt | sre-core.rkt |
| `fold-state` | micro-stratified fold Pocket Universe | surface-rewrite.rkt |
| `tree-rewrite-state` | tree-structural combinator Pocket Universe | surface-rewrite.rkt |
| `apply-sre-rewrite` | replaces `apply-rules` | surface-rewrite.rkt |
| `match-pattern-desc` | pattern-desc matching (retires guards) | sre-rewrite.rkt (NEW) |
| `verify-rewrite-rule` | interface K verification | sre-rewrite.rkt (NEW) |
| `find-critical-pairs` | critical pair analysis | sre-rewrite.rkt (NEW) |
| `instantiate-rhs-template` | template instantiation from K bindings | sre-rewrite.rkt (NEW) |

---

## §D.3 Self-Critique Findings

Three lenses: Reality Check (R), Principles (P), Propagator Mindset (M).

| Finding | Lens | Resolution |
|---------|------|------------|
| R1: parse-tree-nodes have no ctor-descs — SRE dispatch doesn't apply | R | Form tags registered as ctor-descs in `'form` domain (§3.1). First-Class principle. |
| R2: Template language underspecified for nested construction | R | Templates ARE parse-tree-nodes with PUnify holes (§3.1). RRB nesting IS nested construction. PUnify fills holes by unification, not imperative walk. |
| R3: Fold micro-strata conceptual, not architectural | R | Option C: PU micro-strata within single pipeline cycle (§3.3a). Option B (per-step cells) is Track 6 upgrade path for reduction interleaving. |
| R4: 13 rules, not 12 (expand-compose duplicate) | R | Fixed in Phase 2. Noted throughout. |
| P1: Template verification depends on template expressiveness | P | Templates are data (parse-tree-nodes + holes), not code. Verification = holes ⊆ K (§3.5). Correct-by-Construction. |
| P2: pattern-desc doesn't handle arity alternatives | P | Multiple rules per form (one per arity). expand-if → 2 rules. Consistent with DPO: one span per rule. |
| P3: RHS template should be ordered (list), not unordered (hash) | P | Template IS a parse-tree-node (inherently ordered via RRB). K bindings are sub-cells (unordered). Separate concerns. |
| M1: Rule registry is mutable hash, not cell | M | API designed for cell compatibility. Grammar Form writes dynamically. Module-level hash is initial implementation. |
| M2: apply-rules iteration is algorithmic dispatch | M | **Per-rule propagators.** Each rule watches form cell. Fires on match. Parallel. Cell merge resolves conflicts. |
| M3: Tree combinator cell explosion | M | **Pocket Universe** with embedded per-position lattice. One cell. PUnify fills holes within PU. |
| M4: K bindings as value hash (scaffolding) | M | **K as sub-cells** (PUnify pattern). Decomposition writes, reconstruction reads. Reused across fold micro-strata. |

---

## §D.5 External Critique Findings

Propagator information flow lens. 12 findings, responses inline.

| Finding | Issue | Resolution |
|---------|-------|------------|
| F1: Fold "What Emerges?" conceals sequential core | **Accept framing** | Fold sequentiality is SEMANTIC (data dependency chain), not algorithmic. Chain IS the lattice. §3.3a updated. |
| F2: Phase 7 integration is iteration, contradicts Phase 4 propagators | **Accept** | Phase 7 rewritten: per-rule propagators fire within pipeline, no iteration. §3.7 updated. |
| F3: K sub-cell reuse across fold micro-strata is non-monotone | **Accept** | Sub-cell reset within PU micro-strata boundary (NAF-LE pattern). §3.5 updated. |
| F4: Hole representation underspecified | **Accept** | Single definition: `$punify-hole` tag + binding name child. §3.1 updated. |
| F5: Rule registry retirement plan vague | **Partially accept** | Monotonicity invariant enforced (no deletion). Cell migration = Grammar Form scope. §3.1 updated. |
| F6: Fold analogy to form pipeline is misleading | **Accept** | Reframed: fold = stratified sequential (chain), pipeline = parallel (DAG). Different structures. §3.3a updated. |
| F7: Cell merge for conflicts unspecified | **Accept** | Conflicting rewrites → top (contradiction). Ambiguity error. Matches type lattice pattern. §3.7 updated. |
| F8: Adhesive category structure not exploited | **Pushback** | Assumption noted. Parse trees likely adhesive (sub-structure of adhesive e-graphs). Formal verification = research scope. |
| F9: Tree-structural combinator under-designed | **Accept** | Pre-splice position indexing. Splice = position refinement (monotone). Nested PUs for recursive sub-trees. §3.3b expanded. |
| F10: Directionality field well-designed | Positive | No action. |
| F11: Dispatch/execution should decouple | **Pushback** | Correct for zero critical pairs. Decoupling = Grammar Form scope. Rule struct supports retrofit. |
| F12: Cost field has no consumer | **Pushback** | Forward-compatible with named consumer (Grammar Form/Track 6). Keep. |

---

**DPO formalism — adhesive category assumption** (F8): The design uses DPO span notation throughout. The hypergraph research (§3.3) establishes that e-graphs are adhesive, granting local Church-Rosser, parallelism, and concurrency guarantees. Parse trees with RRB children are a strict sub-structure of e-graphs (no equivalence classes). We ASSUME parse trees are adhesive (reasonable — they're term trees, which are adhesive by the presheaf result). Formal verification is research scope, not Track 2D implementation scope. If the assumption fails, the DPO guarantees weaken — but the implementation is still correct (we verify confluence empirically via Phase 6 critical pair analysis, not by categorical proof).

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
