# SRE Track 2D — Stage 2 Audit: Rewrite Relation

**Date**: 2026-04-03
**Scope**: PPN 2-3's rewrite infrastructure mapped to DPO/SRE concepts. Identifies what's on-network, what's imperative, and what Track 2D lifts onto the SRE.

**Motivation**: PPN Track 3 established HR productions for parsing. The research note ([Tree Rewriting as Structural Unification](../research/2026-03-26_TREE_REWRITING_AS_STRUCTURAL_UNIFICATION.md)) identifies tree rewriting as the 4th SRE relation. This audit examines PPN 2-3's ACTUAL rewrite infrastructure to scope Track 2D's deliverables and provide concrete examples for Grammar Form R&D.

---

## §1. Three Layers of PPN 2-3 Rewriting

PPN 2-3's rewriting is NOT purely imperative. It has three layers at different points on the imperative-to-on-network spectrum:

### Layer 1: Rewrite Rule Registry (data-oriented, not yet SRE)

`surface-rewrite.rkt` has a rewrite rule registry with `rewrite-rule` struct:

```racket
(struct rewrite-rule
  (name          ;; symbol — for debugging/tracing
   lhs-tag       ;; symbol — which form tag this rule matches
   rhs-builder   ;; (children srcloc indent → parse-tree-node) — builds output
   guard         ;; (parse-tree-node → boolean) or #f — additional match condition
   priority      ;; natural — higher fires first for overlapping patterns
   stratum)      ;; symbol — which rewrite stratum: 'V0-0, 'V0-1, 'V0-2, 'V1, 'V2
  #:transparent)
```

12 rules registered via `register-rewrite-rule!`. Dispatch via `apply-rules` — iterate rules for a stratum, match on tag + guard, apply first match.

**Assessment**: This IS a rewrite rule system — registered rules with LHS/RHS, stratification, priority. Close to what Track 2D envisions. The gap: LHS is tag+guard (not SRE pattern), RHS is arbitrary lambda (not SRE template), interface is implicit.

### Layer 2: Form Pipeline as Dependency-Set Pocket Universe (ON-NETWORK)

`form-pipeline-value` is a Pocket Universe on the elab-network:
- **Carrier**: `(seteq transforms)` × `tree-node` × `registrations` × `source-pos`
- **Lattice**: Powerset of completed transforms (Boolean lattice). Merge = set-union.
- **Dependency DAG**: `transform-deps` declares which transforms must complete before each fires.
- **Advance**: `advance-pipeline` checks deps, fires first ready transform, returns new pipeline value.

This IS on-network. The form cell holds a `form-pipeline-value`. The pipeline merge is monotone (set-union). The dependency-set controls firing order — independent transforms fire in parallel (critical pair analysis from D.5b confirms G(0) and T(0) have no overlap).

Each pipeline stratum (V0-0 through V2) calls `apply-rules` for its rule set. The pipeline provides the monotone execution shell; the rules provide the transformations.

### Layer 3: RHS Builders (imperative lambdas)

The actual RHS construction is a Racket lambda per rule. Examples:

- `expand-if`: rearranges 4 children into `(boolrec _ then else cond)`
- `expand-let-assign`: wraps val+body into `((fn [name] body) val)`
- `expand-cond`: recursively folds arms into nested if-chain
- `dot-access`: rewrites `a.b` into `(map-get a :b)`
- `implicit-map`: rewrites indentation blocks into map literals

These lambdas receive `children` (extracted from matched node) and construct new tree nodes positionally. They are imperative — list indexing, length checks, recursive loops.

---

## §2. DPO Correspondence

| DPO Concept | PPN 2-3 Implementation | Gap |
|-------------|----------------------|-----|
| LHS pattern (L) | `rewrite-rule.lhs-tag` + `guard` | Tag only, not sub-structure. Guard is arbitrary predicate, not SRE pattern. |
| RHS template (R) | `rewrite-rule.rhs-builder` lambda | Arbitrary function, not declarative template. |
| Interface (K) | **Implicit** — children extracted from LHS reused in RHS | Positional (list index), not structural (named sub-cells). |
| Rule application | `apply-rules`: iterate rules, match tag+guard, apply first | Priority-ordered, not SRE decomposition dispatch. |
| Stratification | `stratum` field + `transform-deps` dependency DAG | ✅ Already formalized. Monotone via powerset lattice. |
| Confluence | Priority ordering within stratum | No formal critical pair analysis on rule LHS overlap. |
| Interface preservation | Children passed through lambda | Not verified — lambda could drop or fabricate children. |

**Key gap**: The INTERFACE (K) is implicit. In DPO, the interface declares what's preserved between LHS and RHS — the shared structural components. In PPN 2-3, children are passed positionally. The rhs-builder can access any child by index, drop children, or fabricate new ones. There's no formal guarantee that the interface is preserved.

---

## §3. Rule Catalog

12 registered rewrite rules across 5 strata:

### Stratum V0-0: Implicit map (1 rule)

| Rule | LHS tag | RHS | Interface (implicit) |
|------|---------|-----|---------------------|
| `rewrite-implicit-map` | `tag-indent-block` | Map literal `{:key val ...}` | Children = key-value pairs |

### Stratum V0-1: Dot access (1 rule)

| Rule | LHS tag | RHS | Interface |
|------|---------|-----|-----------|
| `expand-dot-access` | `tag-dot-access` | `(map-get obj :key)` | obj, key |

### Stratum V0-2: Infix + simple + recursive (7 rules)

| Rule | LHS tag | RHS | Interface | Recursive? |
|------|---------|-----|-----------|------------|
| `expand-if` | `tag-if` | `(boolrec _ then else cond)` | cond, then, else | No |
| `expand-let-assign` | `tag-let-assign` | `((fn [name] body) val)` | name, val, body | No |
| `expand-let-bracket` | `tag-let-bracket` | `((fn [name] body) val)` | name, val, body | No |
| `expand-cond` | `tag-cond` | Nested if-chain | arms (each: guard, body) | **Yes** — folds arms |
| `expand-do` | `tag-do` | Nested let-chain | statements | **Yes** — folds stmts |
| `expand-when` | `tag-when` | `(if cond body unit)` | cond, body | No |
| `expand-pipe` | `tag-pipe` | Nested application chain | stages | **Yes** — folds stages |

### Stratum V1: Macro expansion (1 rule)

| Rule | LHS tag | RHS | Interface |
|------|---------|-----|-----------|
| `expand-defmacro` | (dynamic, from macro registry) | (dynamic, macro template) | (dynamic, macro bindings) |

### Stratum V2: Spec/where injection (2 rules)

| Rule | LHS tag | RHS | Interface |
|------|---------|-----|-----------|
| `inject-spec` | defn with spec | annotated defn | spec type, defn body |
| `inject-where` | form with where-clause | expanded form | main form, where bindings |

### Rule Classification for SRE Lifting

| Category | Rules | SRE Expressibility |
|----------|-------|-------------------|
| **Simple rewrite** (fixed arity, no recursion) | expand-if, expand-let-assign, expand-let-bracket, expand-when, expand-dot-access, rewrite-implicit-map | ✅ Directly expressible as SRE pattern → template with named sub-cells |
| **Recursive rewrite** (variable arity, fold) | expand-cond, expand-do, expand-pipe | ⚠️ Need recursive template or fold combinator. Not directly a single DPO rule — more like a rule SCHEMA that generates a chain of DPO applications. |
| **Dynamic rewrite** (user-defined) | expand-defmacro | ⚠️ Pattern and template from user macro definition. SRE needs to accept dynamically registered ctor-descs from `defmacro`. |
| **Context-dependent** | inject-spec, inject-where | ⚠️ Cross-form information flow — spec cell feeds into defn. Currently scaffolding (parameter reads). Track 4 scope. |

---

## §4. What's On-Network vs Imperative

| Component | Status | Evidence |
|-----------|--------|---------|
| Form pipeline (dependency-set Pocket Universe) | **ON-NETWORK** | Cell merge = set-union. Transform deps control firing. Monotone. |
| Pipeline stratum execution ordering | **ON-NETWORK** | `transform-deps` hash + `transform-ready?` predicate. |
| Rewrite rule REGISTRY | **Data-oriented** | `rewrite-rule-registry` hash. Rules are data (struct). Not yet SRE ctor-descs. |
| Rule DISPATCH (apply-rules) | **Imperative** | Iterates rule list, matches tag, calls lambda. Not SRE decomposition. |
| RHS construction (rhs-builder lambdas) | **Imperative** | Arbitrary Racket code. Positional children access. |
| Interface (K) preservation | **Unverified** | Children passed implicitly. No formal interface declaration. |
| Rule commutativity / critical pairs | **Unverified** | Priority ordering used. No formal analysis. |

---

## §5. What Track 2D Lifts

Track 2D's job: take what's ALREADY data-oriented and ON-NETWORK (Layers 1-2) and lift the IMPERATIVE parts (Layer 3) onto the SRE.

### 5.1 Simple rewrites (6 rules) → SRE pattern→template

The 6 simple rewrites have fixed arity, no recursion, and clear interfaces. Each maps to:
- **LHS**: SRE ctor-desc with named components (not just tag)
- **RHS**: SRE reconstruction template referencing named components
- **K**: The named components shared between LHS and RHS

Example — `expand-if`:
```
LHS:  (if cond then else)  →  ctor-desc 'if, components: [cond, then, else]
K:    {cond, then, else}
RHS:  (boolrec _ then else cond)  →  reconstruct from K, adding constant '_'
```

### 5.2 Recursive rewrites (3 rules) → rule schemas or fold-combinators

`expand-cond` folds N arms into nested if-chains. This isn't a single DPO rule — it's a rule APPLIED REPEATEDLY until the input is consumed. Options:
- **Rule schema**: generate one DPO rule per arity (cond-1-arm, cond-2-arms, ...). Finite but combinatorial.
- **Fold combinator**: a higher-order rewrite operation that folds a rule over a list. This is `foldr` on the SRE — applies a base-case rule and a step rule recursively.
- **Recursive template**: the RHS template can reference itself (like a recursive macro). Needs termination guarantee.

### 5.3 Dynamic rewrites (1 rule) → user-registered ctor-descs

`defmacro` patterns and templates come from user code. Track 2D needs to accept dynamically registered rewrite rules from the macro system. The `grammar` toplevel form is the permanent mechanism; `defmacro` is the existing one.

### 5.4 Context-dependent rewrites (2 rules) → cross-cell propagators

Spec/where injection reads information from OTHER forms (spec declarations). This is cross-form information flow — exactly what PPN Track 3's spec cells provide. Track 2D may not need to address these — they're Track 4 scope (on-network elaboration).

---

## §6. Monotonicity Resolution

The form pipeline already resolves the "rewriting isn't monotone" tension:

1. Each transform fires ONCE per form cell (dependency-set tracks completion).
2. The pipeline value advances monotonically: `{} → {grouped} → {grouped, tagged} → ... → {done}`.
3. The tree-node within the pipeline value changes with each transform — but the PIPELINE VALUE (transforms-set × tree-node) only increases.
4. DPO interface preservation adds a guarantee: the sub-cells (children) bound by the LHS are preserved in the RHS. The tree changes, but the structural components are reconnected, not destroyed.

This means Track 2D does NOT need a new stratification mechanism for rewriting. The existing form pipeline IS the monotone shell. The SRE rewrite relation fires within this shell.

---

## §7. Cross-References

- [Tree Rewriting as Structural Unification](../research/2026-03-26_TREE_REWRITING_AS_STRUCTURAL_UNIFICATION.md) — the research insight that motivates Track 2D
- [Hypergraph Rewriting + Propagator Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — DPO/SPO theory, adhesive categories, critical pairs
- [Grammar Toplevel Form](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) — the user-facing expression of rewrite rules
- [PPN Track 3 Design](2026-04-01_PPN_TRACK3_DESIGN.md) — form cells, dependency-set pipeline, tree-canonical parsing
- [SRE Master](2026-03-22_SRE_MASTER.md) — Track 2D row
