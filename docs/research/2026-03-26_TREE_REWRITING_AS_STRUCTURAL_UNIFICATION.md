# Tree Rewriting as Structural Unification — Design Note

**Date**: 2026-03-26
**Stage**: 0 (Design insight from PPN Track 1 critique discussion)
**Series touches**: PPN (Track 2), SRE, PRN

**Related documents**:
- [PPN Track 1 Design](../tracking/2026-03-26_PPN_TRACK1_DESIGN.md) — tree mutation API
- [SRE Research](2026-03-22_STRUCTURAL_REASONING_ENGINE.md) — structural decomposition
- [Grammar Toplevel Form](2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) — multi-view grammar spec
- [PRN Master](../tracking/2026-03-26_PRN_MASTER.md) — theory series
- [PPN Master](../tracking/2026-03-26_PPN_MASTER.md) — Track 2 notes

---

## 1. The Insight

A `defmacro` rewrite — "pattern `when $cond $body` matches sub-tree T,
replace with `if $cond $body unit`" — IS structural unification:

```
DECOMPOSE: structural-relate(T, when(cond, body))
  → binds sub-cells: cond = T's first child, body = T's second child

COMPOSE: structural-relate(result, if(cond, body, unit))
  → builds new form from the SAME sub-cells + constant `unit`
```

The DECOMPOSITION is the SRE's `sre-decompose-generic` (pattern match).
The COMPOSITION is the SRE's reconstruction propagator (template
instantiation). The sub-cells (`$cond`, `$body`) are the structural
components that both sides share.

Tree rewriting is NOT a separate mechanism from structural unification.
It IS structural unification with a directional relation: match LHS
(decompose), produce RHS (compose), using the same sub-cell bindings.

## 2. How This Maps to the SRE

### Current SRE relations

| Relation | Direction | What it does |
|----------|-----------|-------------|
| Equality | Symmetric | Both sides converge to same value |
| Subtyping | Directional | Check a ≤ b with variance |
| Duality | Involutive | Swap constructor pairs (Send↔Recv) |
| **Rewriting** | **Directional** | **Match LHS → produce RHS** |

Rewriting is a NEW relation type for the SRE. Like subtyping, it's
directional (LHS → RHS, not symmetric). Unlike subtyping, it REPLACES
the cell value (subtyping only checks, rewriting TRANSFORMS).

### The SRE operation for rewriting

```racket
;; Proposed: sre-rewrite
;; Decompose cell value against LHS pattern.
;; If match: compose RHS from bound sub-cells, write to cell.
;; If no match: leave cell unchanged.

(define (sre-rewrite cell-value lhs-pattern rhs-template)
  ;; 1. Attempt decomposition: cell-value against lhs-pattern
  ;;    → binds sub-cells (pattern variables)
  ;; 2. If match: compose rhs-template with bound sub-cells
  ;;    → produces new cell value
  ;; 3. Write new value to cell
  ;; 4. If no match: return cell unchanged
  ...)
```

This uses EXISTING SRE machinery:
- `sre-decompose-generic` for LHS matching (already exists)
- Reconstruction propagators for RHS composition (already exist)
- Sub-cell binding (the `get-or-create-sub-cell` pattern)

The only NEW piece: the DIRECTIONAL semantics (match→replace, not
match→unify). This parallels how subtyping added directionality to
equality — the mechanism is the same, the relation is different.

## 3. Implications for PPN Track 2

Track 2 (surface normalization) rewrites trees: defmacro expansion,
let/cond desugaring, implicit map rewriting. Currently these are
IMPERATIVE tree walks in macros.rkt (~3000 lines).

With SRE-based rewriting:

1. Each `defmacro` pattern-template pair REGISTERS as an SRE rewrite
   rule: LHS constructor = the macro's pattern form, RHS = the template.

2. The SRE fires rewrite propagators when a cell's value matches a
   registered LHS pattern.

3. Normalization = QUIESCENCE. When no more rewrite rules match anywhere
   in the tree, normalization is complete.

4. `let`/`cond`/`when` desugaring are ALSO rewrite rules — registered
   alongside defmacro patterns. No special-casing.

This REPLACES macros.rkt's imperative tree walking with SRE rule
registration + propagator quiescence. The same mechanism that handles
type-level structural decomposition handles surface-level macro
rewriting.

### The layering

| Layer | What it provides | Track |
|-------|-----------------|-------|
| Tree mutation | `tree-replace-children`, `tree-splice` | PPN Track 1 |
| SRE rewrite | `sre-rewrite(cell, lhs, rhs)` | PPN Track 2 |
| Rule registration | `register-rewrite-rule!(name, lhs, rhs)` | PPN Track 2 |
| DPO framework | Interface preservation guarantees | PPN Track 3.5 |
| User-facing grammar | `grammar` toplevel form | PPN Track 7 |

Track 1's tree mutation functions are the LOW-LEVEL operations that
the SRE calls internally. Track 2 wraps them in SRE-based rewriting.
Track 3.5 adds theoretical guarantees. Track 7 exposes to users.

## 4. Connection to PRN

This confirms the PRN thesis: macro expansion, type inference,
parsing, and reduction are ALL structural rewriting on the same
substrate. The SRE provides the mechanism. The relation type
(equality/subtyping/duality/rewriting) determines the semantics.
The lattice provides correctness. The propagator network provides
execution.

Macro rewriting adds "rewrite" to the SRE's relation catalog.
This is the FOURTH relation (after equality, subtyping, duality).
Each was discovered through implementation:
- Equality: SRE Track 0 (type unification)
- Subtyping: SRE Track 1 (variance-aware decomposition)
- Duality: SRE Track 1 (session type dual pairs)
- **Rewriting: PPN Track 1/2 (macro pattern→template)**

PRN predicts: more relations will emerge as more systems use the SRE.
Coercion (Track 1's 5th relation, partially implemented) and
isomorphism (curry/uncurry) are candidates.

## 5. The Key Observation

The tree mutation API in Track 1 (`tree-replace-children`, `tree-splice`)
is CORRECT and NECESSARY — it's the mechanical foundation. But it's not
the RIGHT ABSTRACTION for Track 2. Track 2's abstraction is:

```
"When this pattern matches, replace with this template."
```

This is `sre-rewrite`, not `tree-replace-children`. Track 1 provides
the mechanics. Track 2 provides the abstraction. The SRE bridges them.

Track 2's design should be INFORMED by this insight: surface
normalization is SRE rewrite rule registration, not imperative tree
walking. The 3000 lines of macros.rkt preparse become ~200 lines of
rule registrations + the SRE's existing execution machinery.
