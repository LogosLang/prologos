# Attribute Grammar Substrate Unification — Vision Research

**Stage**: 0 (Vision — pattern-motivated, informed by theory)
**Date**: 2026-04-22
**Series**: PPN (proposed Track 4D, post-4C)
**Status**: Vision document. Research + design cycle triggered by PPN 4C addendum T-3 findings (three accidentally-load-bearing mechanisms in a single track).

**Related documents**:
- [PPN Master](../tracking/2026-03-26_PPN_MASTER.md) — series tracking
- [`grammar` Toplevel Form Vision](2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) — user-facing surface (Track 3.5 + 7)
- [Hypergraph Rewriting + Propagator Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — Engelfriet-Heyker equivalence
- [PPN Track 4C Phase 9+10+11 Design D.3](../tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — T-3 findings that motivated this
- [DESIGN_PRINCIPLES.org](../tracking/principles/DESIGN_PRINCIPLES.org) — Hyperlattice Conjecture, Correct-by-Construction
- [MEMORY.md](../../MEMORY.md) — 14-pipeline problem statement
- [Module Theory on Lattices](2026-03-28_MODULE_THEORY_LATTICES.md) — attributes as modules

---

## 1. Abstract

Prologos's elaboration currently distributes type information across at least seven distinct locations — `syntax.rkt`, `typing-core.rkt` (sexp-based), `typing-propagators.rkt` (on-network), `elaborator-network.rkt` (meta cells), `zonk.rkt`, `unify.rkt`, `reduction.rkt`. Each location maintains its own view of "what is the type of this expression," and the consistency between these views is maintained by discipline, not by structure.

The PPN Track 4C addendum T-3 cycle produced three consecutive "accidentally-load-bearing mechanism" findings — each a case where the primary pipe appeared to work but the real work was being done by an accidentally-coincident side path. The pattern is not bad luck. It is the **structural signature of fragmentation**: when there are multiple sources of truth, correctness becomes a conspiracy between them, and migrations expose which one was load-bearing.

This note proposes **Track 4D: Attribute Grammar Substrate Unification** — collapsing the fragmented typing/elaboration/reduction subsystems into a single declarative attribute-grammar substrate, with each typing rule expressed as a grammar production with attribute-equations, compiled to propagator installations. This is the prerequisite to Track 7 (user-defined grammar extensions) and the structural fix for the fragmentation pattern.

---

## 2. The Fragmentation Problem

### 2.1 Concrete data — three accidentally-load-bearing findings (PPN 4C T-3)

| # | Location | The "primary" pipe | The accidentally-load-bearing path |
|---|---|---|---|
| 1 | Attempt 1 (1A-ii) | `current-worldview-bitmask` + tagged-cell-value branches | TMS dispatch at `propagator.rkt:1248` used `current-speculation-stack='()` to update BASE, making union inference accidentally work |
| 2 | Sub-A (1A-iii) | `with-speculative-rollback` bitmask parameterize + worldview-cache | `elab-net` snapshot/restore was the only thing doing try-rollback work; bitmask was ignored by TMS path |
| 3 | Commit B (T-3) | `type-lattice-merge` Role A accumulate (new set-union semantics) | `type-lattice-merge(Nat,Bool)=type-top` caused sexp `typing-core.rkt:459` fallback to return `[Type 0]` correctly for `(infer <Nat | Bool>)` |

Each finding has the same shape: the code APPEARED to produce correct answers via the architecturally-stated mechanism, but the REAL answer was being produced by a coincident side path. When the coincidence was removed (migration), the bug surfaced.

### 2.2 Type information lives in 7+ places

| Location | Role | Source of truth? |
|---|---|---|
| `syntax.rkt` | `expr-*` structs (type expressions are syntax) | Syntactic structure |
| `typing-core.rkt:440+` | Sexp-based `infer`/`check` | **Fallback target** — the accidentally-correct path |
| `typing-propagators.rkt` | On-network typing rules | Primary attempt, ad-hoc per form |
| `elaborator-network.rkt` | Meta cells with merge functions | Solving substrate |
| `zonk.rkt` | Meta defaulting + reconstruction | Post-processing |
| `unify.rkt` | Unification with side effects | Alternative solving path |
| `reduction.rkt` | `whnf` resolution | Affects what counts as "the type" |

Each location has its own invariants. Each has its own way of asking "what is the type here." Keeping them consistent is the elaboration engineer's discipline, not a structural guarantee.

### 2.3 Why this is a structural problem, not an engineering problem

Per DESIGN_PRINCIPLES.org § Correct-by-Construction: *"Prefer designs where correctness is a structural property of the architecture, not a property maintained by discipline."* Fragmentation fails this test. Every new language feature touches all seven locations. Every migration risks exposing a hidden coincidence. The three T-3 findings are not failures of vigilance — they are the expected fingerprint of the architecture.

The Hyperlattice Conjecture says: every computable function is a fixpoint on lattices, with optimal parallel decomposition falling out of the lattice's Hasse structure. Elaboration is a computable function. It should be a single fixpoint, not seven coordinated ones.

---

## 3. The Vision: Attribute Grammar as Unified Substrate

### 3.1 Core proposition

Every expression position carries an attribute-record. Every typing rule is a declarative grammar production with attribute-equations over this record. Grammar rules compile to propagator installations. The propagator network IS the attribute grammar runtime. Parsing, elaboration, typing, QTT, reduction, and zonking become COMPONENT ATTRIBUTES of the same unified substrate — each a facet on the same record, each with its own lattice, all connected by attribute-equations.

### 3.2 The `that`-based user surface

Internal today:
```racket
(that-read attribute-map position ':type)    ;; read classifier
(that-write net position ':type value)       ;; write classifier
```

User-surface tomorrow (per `grammar` vision):
```prologos
grammar if
  :parse       if $cond $then $else
  :type        { cond :type Bool
                 then :type $T
                 else :type $T
                 :type $T }
  :reduce      | if true  $t _ -> $t
               | if false _  $e -> $e
  :components  [cond : Bool, then : $T, else : $T]
```

The `{ ... }` attribute-equation block is a declarative description of how attributes flow. Compiled, it produces:
- A propagator reading `cond`'s `:type` facet and writing `type-top` if incompatible with `Bool`
- A propagator unifying `then` and `else`'s `:type` facets
- A propagator writing the unified type to the enclosing position's `:type` facet

Internal typing rules in `typing-propagators.rkt` become library-level productions using the same mechanism. The 30+ ad-hoc `make-*-fire-fn` helpers collapse into: *interpret grammar rule → generate propagator installations*.

### 3.3 Sources of truth collapse

| Before | After |
|---|---|
| `typing-core.rkt:459` sexp infer for expr-union | ONE grammar rule for `union` production |
| `typing-propagators.rkt:1878-1920` ad-hoc union typing | Same rule, compiled to propagators |
| `elaborator-network.rkt` meta cells for type vars | Attribute-record facets, Lattice-Q-module structure |
| `unify.rkt` unification with side effects | Attribute-equation dispatch via PUnify |
| `zonk.rkt` meta defaulting | Readiness-stratum propagator on attribute-record |
| `reduction.rkt` `whnf` affecting types | `:whnf` facet on attribute-record |

One source of truth per attribute. One substrate. No coincidences to be load-bearing.

### 3.4 Connection to 14-pipeline collapse

CLAUDE.md catalogues the 14-file AST pipeline. Under attribute grammar unification:

- **syntax.rkt** → `expr-*` structs remain as the STRUCTURAL skeleton (SRE ctor-descs); attribute-records attach facets
- **surface-syntax.rkt** → `:surface` facet on attribute-record
- **parser.rkt** → `:parse-tree` facet; PPN Tracks 1-3 already put this on-network
- **elaborator.rkt** → declarative grammar rules + attribute-equations
- **typing-core.rkt** → production-by-production grammar rules
- **qtt.rkt** → `:usage` facet
- **reduction.rkt** → `:whnf` facet
- **substitution.rkt** → attribute-equation for scope-opening
- **zonk.rkt** → readiness-stratum propagator
- **pretty-print.rkt** → `:display` facet
- **unify.rkt** → PUnify on attribute-record components
- **macros.rkt** → user-facing `grammar` productions (Track 7)
- **foreign.rkt** → `:foreign` facet

All firing simultaneously on the same network to single fixpoint. Adding a new form = adding one `grammar` rule. The pipeline exhaustiveness checklist (`.claude/rules/pipeline.md`) dissolves — there are no stages to keep in sync.

### 3.5 Why this enables Track 7 (user-defined grammar extensions)

Track 7 (CAPSTONE) requires user-defined extensions to participate in parsing, type checking, reduction, pretty-printing, and tooling — seven views per `grammar`-toplevel-form research. If internal typing rules are ALREADY declarative grammar productions, user-defined extensions are just more productions on the same substrate. Without Track 4D unification, Track 7 exposes a user surface whose internal implementation would still require touching all 14 pipeline files per extension — which is exactly what it's supposed to fix.

---

## 4. Relationship to Existing Tracks

### 4.1 PPN Track 4A/B/C (elaboration on-network)

4A/B brought typing data INTO cells. 4C brings ALL elaboration (typing, constraints, mult, warnings) on-network. 4D takes the next step: make typing RULES themselves declarative, not ad-hoc propagator installation code. Tracks 4A-C are prerequisites (the cell substrate must exist first); 4D generalizes them from "elaboration on-network" to "elaboration as grammar-on-network."

### 4.2 PPN Track 3.5 (`grammar` form research)

Track 3.5 designs the user-facing `grammar` form syntax. 4D implements the underlying substrate — the interpreter/compiler for `grammar` rules. They can proceed in parallel once 4C is complete: 3.5 surfaces the syntax, 4D builds what the syntax compiles to.

### 4.3 PPN Track 7 (user-defined grammar extensions)

Track 7 is CAPSTONE — user-facing deployment of `grammar` extensions. It becomes achievable once 4D unifies the internal substrate. Without 4D, Track 7's user surface would still need 14-file pipeline touches per extension (defeating its purpose).

### 4.4 SRE series

SRE provides `ctor-desc` structural decomposition, which IS the parsing-direction of a grammar production. 4D uses SRE's structural decomposition as the substrate for attribute attachment. SRE Track 2H's lattice redesign (subtype, union, meet, tensor) provides the algebraic foundation 4D attributes accumulate over.

### 4.5 BSP-LE series

BSP-LE Track 2B's Module Theory Realization B (tagged-cell-value with bitmask layers on shared carrier) is the pattern attribute-records use for per-facet tagged access. 4D consumes this substrate without modification.

### 4.6 PRN series (theory)

PRN is the abstract theory of propagator-rewriting networks. 4D contributes back: declarative attribute grammar as a rewriting paradigm; grammar rules as typed hyperedge replacement. PRN's rewrite-rule primitives (when formalized) become 4D's compilation target for grammar rules.

---

## 5. Research Inputs

### 5.1 Theory

- **Engelfriet-Heyker equivalence**: parse trees and attribute grammars are interchangeable; attribute evaluation IS fixpoint on lattices. [HR grammars research](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) covers this.
- **Attribute grammar literature**: Knuth's original formulation (1968). Higher-order attribute grammars (Vogt, Swierstra, Kuiper 1989). Reference attributes (Hedin 1994, Magnusson-Hedin JastAdd).
- **Silver / JastAdd** (Hedin, Van Wyk, Magnusson): aspect-oriented attribute grammars. Practical large-scale implementations. Module-like composition.
- **Categorical foundations**: attributes as functors; attribute-equations as natural transformations. [Categorical Foundations research](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) already covers polynomial functors.

### 5.2 Prologos-specific prior art

- **Facet architecture** (PPN 4B-4C): `:type`, `:term`, `:context`, `:usage`, `:warnings` are facets on a shared attribute-record. Track 4D generalizes: facet = attribute.
- **`classify-inhabit-value` tag-dispatch** (PPN 4C Phase 3): already an attribute-grammar-style per-facet merge. Track 4D recognizes this pattern as an attribute-grammar rule.
- **`make-pi-fire-fn`** (typing-propagators.rkt:1236): the TEMPLATE for declarative attribute-equation compilation. `:reads dom-pos :type, cod-pos :type; :writes position :type` — this IS an attribute-equation.
- **SRE ctor-desc**: declarative structural decomposition already exists for parsing. Track 4D extends it to elaboration.
- **That-read / that-write**: user-facing API exists in `typing-propagators.rkt:485`. Becomes the entry-point for user-defined attributes.

### 5.3 Operational patterns

- **Per-registration evaluators** (PPN Master §4.2, from BSP-LE 2B A2 scoping): analyze structure at registration time, install type-specific evaluator. Track 4D generalizes: analyze grammar rule at registration, install attribute propagators.
- **Module Theory direct-sum tagging** (PPN Master §4.1): bitmask layers on shared carrier. Track 4D's attribute-record IS this pattern.
- **Skip-the-mechanism over optimize** (PPN Master §4.3): if a typing rule's output is ground at registration time, skip propagator installation entirely.

---

## 6. Proposed Track Scope (Preliminary)

### 6.1 Explicit non-goals

- NOT replacing SRE's structural decomposition (consumes it)
- NOT replacing BSP-LE 2B's tagged-cell-value mechanism (consumes it)
- NOT replacing PPN 4C's elaborator-network attribute-record architecture (generalizes it)
- NOT user-surface `grammar` syntax design (that's Track 3.5)
- NOT user-facing deployment (that's Track 7)

### 6.2 Rough phase structure (to be refined in Stage 1-2)

**Phase A — Grammar rule representation** — define the declarative form (internal data structure, not user syntax). Fields: pattern (SRE ctor-desc reference), attribute-equations (facet-input → facet-output with lattice), guards, reduction rules.

**Phase B — Grammar rule compiler** — interpret a grammar rule → produce propagator installations + dependent-set registrations. Single entry point replacing the ~30 ad-hoc `make-*-fire-fn` helpers in typing-propagators.rkt.

**Phase C — Migration of existing typing rules** — rewrite each expr-foo case in typing-propagators.rkt as a grammar rule. Concurrent A/B (old path vs grammar-compiled path). Atomic cutover per rule.

**Phase D — Sexp-infer retirement** — once grammar-compiled path is primary for all forms, retire `typing-core.rkt:440+` sexp-based `infer`/`check` AS FALLBACK. Keep `typing-core.rkt` only for bootstrapping.

**Phase E — Unification consolidation** — PUnify becomes attribute-equation-dispatch via SRE relation. `unify.rkt`'s side-effecting paths collapse into the grammar substrate.

**Phase F — Zonking as attribute-grammar readiness stratum** — `zonk.rkt` becomes a readiness propagator stratum on attribute-records. Meta defaulting = attribute-equation with defaults.

**Phase G — Reduction as facet** — `:whnf` facet on attribute-records; reduction rules as grammar productions in `:reduce` direction. `reduction.rkt` absorbs.

**Phase V — Vision alignment gate + PIR.**

Scope estimate: COMPARABLE to PPN Track 4C (multi-month, multi-sub-phase track). Likely >3000 LoC of code changes + substantial architectural documentation. Proper Stage 1 research + Stage 2 audit + Stage 3 design cycle required before implementation.

### 6.3 Prerequisites

1. **PPN 4C complete**, including the addendum (substrate + orchestration unification). Attribute-record architecture stable.
2. **T-3 landed** (Commit B, set-union merge for type lattice). Lattice semantics correct before building on it.
3. **PM Track 12 scoping decided** (module loading on network). 4D's grammar rule registry should co-locate with module-loading infrastructure, not re-invent it.
4. **Benchmark baseline established**: grammar-compiled path must not regress elaboration performance vs ad-hoc propagator installation.

### 6.4 Expected deliverables

- `grammar-rule.rkt` module: declarative rule representation + compiler
- Migration of all ~30 typing rules from typing-propagators.rkt to declarative form
- `typing-core.rkt` sexp-infer retirement (phase D)
- Attribute-grammar test harness (verify each rule's propagator compilation + execution)
- Principle codification: DEVELOPMENT_LESSONS.org entry on fragmentation-of-sources-of-truth
- Integration path documented for Track 7

---

## 7. Open Questions

These are candidates for Stage 1 research dialogue — NOT pre-resolved:

**Q1**: Can grammar rules be first-class values (reified as `grammar-rule` structs) or are they compile-time only? First-Class by Default suggests yes; engineering complexity may push toward no for this track, yes in Track 7.

**Q2**: How does the grammar compiler interact with speculation/ATMS branching (PPN 4C Phase 3 union types)? Does speculation manifest as an attribute dimension, or as a substrate-level concern?

**Q3**: What's the relationship between attribute lattices and the existing SRE domain registrations? Is an attribute a wrapped SRE domain, or is an SRE domain an attribute specialization?

**Q4**: Higher-order attribute grammars (attributes whose values are themselves grammar rules, enabling language-extensible language extensions). Track 4D scope, or Track 7+ scope?

**Q5**: Incremental re-evaluation (PPN Track 8): attribute-grammar literature has substantial work on incremental attribute evaluation. Does Track 4D's substrate make Track 8 trivial, or does Track 8 need additional infrastructure?

**Q6**: Debugging + observability: attribute-records should support inspection ("what attribute values exist at this position?"). Is this a separate layer or intrinsic to the substrate?

**Q7**: Bidirectionality: grammar rules should support both directions (parsing = input → attributes; generation = attributes → output). How does the substrate handle this? Track 9 (self-describing serialization) depends on the answer.

---

## 8. Watching-List Entry (for post-T-3 codification)

Candidate for DEVELOPMENT_LESSONS.org:

> **Fragmentation of sources of truth is architectural debt; accidentally-load-bearing patterns are its fingerprint.** When multiple locations each hold partial views of the same information (the "type of this expression" living in 7+ places), migration of ANY one location will surface hidden dependencies on coincidental correctness in the others. The structural fix is unification under one substrate, not more-careful-migration. Three consecutive findings in PPN 4C Addendum T-3 (attempt-1 TMS dispatch, Sub-A with-speculative-rollback, Commit B contradiction-fallback) confirm the pattern. Track 4D's charter.

---

## 9. Summary

PPN Track 4D proposes collapsing Prologos's fragmented typing/elaboration/reduction subsystems into a unified attribute-grammar substrate, where each typing rule is a declarative grammar production with attribute-equations compiled to propagator installations. This is the structural fix for the fragmentation-of-sources-of-truth pattern observed across PPN 4C Addendum T-3's three accidentally-load-bearing findings. It's the prerequisite to Track 7 (user-defined grammar extensions) and the operational realization of the Hyperlattice Conjecture applied to elaboration: elaboration as a single fixpoint on a unified attribute-lattice, rather than seven coordinated ones.

This is a Stage 0 vision document. Stage 1 research and Stage 2 audit follow once PPN 4C addendum (including T-3) completes and PM Track 12 scoping is decided. Stage 3 design roadmap is expected to be of comparable scope to PPN 4C itself.
