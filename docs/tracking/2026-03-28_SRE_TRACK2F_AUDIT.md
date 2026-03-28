# SRE Track 2F: Algebraic Foundation — Stage 2 Audit

**Date**: 2026-03-28
**Track**: SRE Track 2F (Algebraic Foundation)
**Source**: PTF Track 1 Phase 3 design recommendation
**Research**: `docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`

---

## Audit A: Implementation Specifics

### 1. Consumers of `sre-relation-name`

**12 call sites across 3 production files + 2 test files:**

| Site | File | Line | Decision |
|------|------|------|----------|
| Merge lookup | sre-core.rkt | 100 | `(sre-domain-merge-registry domain) rel-name` → per-relation merge function |
| Phantom skip | sre-core.rkt | 423 | `(eq? 'phantom)` → skip constraint propagator |
| Decomp key | sre-core.rkt | 464 | `rel-name` included in pair-key for dedup cache |
| Propagator select | sre-core.rkt | 522 | 4-way `case` → equality/subtype/duality/phantom propagator |
| Direction flip | sre-core.rkt | 578 | `(eq? 'subtype-reverse)` → reversed directional check |
| Duality decomp key | sre-core.rkt | 689 | `rel-name` in pair-key |
| Duality decomp key | sre-core.rkt | 712 | `rel-name` in pair-key |
| Duality phantom skip | sre-core.rkt | 764 | `(eq? 'phantom)` → skip |
| Duality decomp key | sre-core.rkt | 799 | `rel-name` in pair-key |
| Bot handling | sre-core.rkt | 853 | `(not (eq? 'duality))` → both cells must be non-bot |
| Topology dispatch | sre-core.rkt | 871 | `(eq? 'duality)` → dual-pair path vs generic path |

Test files: 5 assertions in test-sre-subtype.rkt (lines 54-88), 2 in test-sre-duality.rkt (lines 134-141).

### 2. Duality's `component-lattices` vs `component-variances`

**Critical finding**: Session constructors use `component-lattices` ONLY; non-session constructors use `component-variances` ONLY. The two mechanisms never overlap.

- **7 session constructors** (Send, Recv, DSend, DRecv, AsyncSend, AsyncRecv, Mu): `#:component-lattices` with `type-lattice-spec` / `session-lattice-spec`. NO `#:component-variances`.
- **13 type constructors** (Pi, Sigma, App, Eq, Vec, Fin, pair, lam, PVec, Set, Map, suc, List): `#:component-variances` with `+`/`-`/`=`/`ø`. NO `#:component-lattices`.

Duality's `sub-relation-fn` (line 238-253) reads `component-lattices` and maps:
- `'type` sentinel → `sre-equality` (payload is cross-domain)
- else → `sre-duality` (continuation stays in session domain)

This is functionally equivalent to a variance annotation with two values: `'t` (type-domain = equality) and `'d` (session-domain = duality). The mechanism differs only because it was implemented separately.

### 3. Merge Functions Per Relation

`sre-domain-merge` (line 99-100) looks up in domain's merge-registry by relation name. Each domain provides a `(relation-name → merge-fn)` function.

Merge semantics by relation:
- **Equality**: flat merge (structural equivalence; mismatch → contradiction)
- **Subtype**: ordering merge (a ≤ b; may accumulate information)
- **Duality**: same as equality (involution is symmetric)
- **Phantom**: no merge (no constraint)

### 4. Propagator Constructor Differences

| Aspect | Equality | Subtype | Duality |
|--------|----------|---------|---------|
| Propagates information? | Yes (merge both cells) | No (check only) | Yes (swap constructor) |
| Writes on success? | Yes | No (only on contradiction) | Yes |
| Directional? | No | Yes (detects reverse) | No |
| Variance dispatch? | N/A | Yes | No (uses lattices) |
| Special data needed? | No | No | dual-pairs table |

**Assessment**: The three propagators CANNOT be trivially unified into one — they have fundamentally different operational semantics. But the DISPATCH to them (line 522) can be table-driven.

### 5. Reconstructors

Reconstructors are **relation-independent** (line 857-868). Same `sre-make-generic-reconstructor` for all relations. They rebuild parent from sub-cells via `ctor-desc-reconstruct-fn`.

### 6. Error Messages

3 internal error sites reference relation names. No user-visible error messages use relation names.

### 7. Test Coverage

| Relation | Tests | Assessment |
|----------|-------|------------|
| Equality | ~20 (indirect) | Adequate |
| Subtype | ~50 | Comprehensive |
| Duality | ~62 | Comprehensive |
| Phantom | 1 | Acceptable (no-op) |
| **Total** | ~177 | |

### 8. `requires-binder-opening?`

Used at 3 sites, ALL in sre-core.rkt. Only equality has `#t`. Controls whether binder-depth>0 constructors need fresh meta substitution during decomposition. Temporary scaffolding for Track 1B Phase 3/4 migration.

---

## Audit B: Module-Theoretic Coverage Map

### All Structural Operations in the Architecture

| # | Operation | File(s) | Algebraic Kind | Uses SRE? | Gap |
|---|-----------|---------|----------------|-----------|-----|
| 1 | Type constructor decomposition | sre-core.rkt | identity/monotone/antitone/idempotent | ✅ | — |
| 2 | Structural unification | unify.rkt, elaborator-network.rkt | identity | ✅ | — |
| 3 | Bidirectional type inference | typing-core.rkt | monotone (infer) / antitone (check) | ⏸️ partial | Hardcoded Pi/Sigma alongside generic |
| 4 | Pattern matching (narrowing) | narrowing.rkt | idempotent (projection) | ❌ | DT traversal, not SRE decomposition |
| 5 | Trait resolution | trait-resolution.rkt | monotone (narrowing candidates) | ❌ | Imperative pattern matching against registry |
| 6 | Reduction / normalization | reduction.rkt | idempotent (to normal form) | ⏸️ partial | Narrowing yes, beta/iota no |
| 7 | Module loading | namespace.rkt, driver.rkt | monotone (info accumulation) | ❌ | Registry lookup |
| 8 | Constraint propagation | constraint-propagators.rkt | monotone (both directions) | ❌ | Custom propagators |
| 9 | Effect dispatch | effect-executor.rkt | monotone | ❌ | Custom dispatch |
| 10 | Session duality | sessions.rkt, sre-core.rkt | antitone | ✅ | — |
| 11 | Macro expansion | macros.rkt | idempotent | ❌ | Imperative tree walking |
| 12 | Multi-arity dispatch | multi-dispatch.rkt | monotone | ❌ | Imperative arity lookup |
| 13 | Coercion | elaborator.rkt, reduction.rkt | non-ring (lossy morphism) | ❌ | Registry lookup |
| 14 | Parametric instantiation | elaborator.rkt | non-ring (∀ elimination) | ❌ | Imperative |
| 15 | Bilattice operations | bilattice.rkt | antitone pairing | ❌ | Custom lattice |

### Operations Outside the Four Algebraic Kinds

| Operation | Why it doesn't fit | Kind needed |
|-----------|-------------------|-------------|
| Coercion | Non-injective, non-surjective; not structure-preserving | Morphism in Set/Category |
| Parametric instantiation | ∀→∃ reduction; many-to-one | Functor application |
| Trait dispatch | Selection from candidates; non-deterministic until ground | Monoid action / selection |
| Effect dispatch | Handler selection from set of alternatives | Effect algebra |
| Union elimination | Case analysis over coproduct branches | Coproduct handling |
| Narrowing search (Or-nodes) | Non-deterministic choice points | Choice monad / ATMS |

### Future Series Needs

| Series | Relation kinds needed | SRE Track 2F implication |
|--------|----------------------|--------------------------|
| PRN | Rewriting (idempotent), bidirectional rules, cost-weighted selection | Table must support idempotent kind with tropical enrichment |
| PPN | Surface transformation, grammar production, ambiguity resolution | Table must support rewriting + quotient extraction |
| CIU | Trait dispatch, keyed/indexed access, iteration protocol | Galois bridges for dispatch; decomposition for container access |
| BSP-LE | NAF (non-monotone), tabling, e-graph quotient | Stratification for non-monotone; quotient cells for e-graph |

---

## Synthesis: What SRE Track 2F Should Build

### In-scope (implementation)

1. **Kind-variance table as data** — the endomorphism ring decomposition. Single function: `(algebraic-kind-for variance relation-kind) → sub-relation-kind`. Replaces 3 hand-written `sub-relation-fn` closures.

2. **Unified duality variances** — session constructors get duality-specific variance values (`'d` for dual-continuation, `'t` for type-component) in the same `component-variances` field. `component-lattices` mechanism retired for sub-relation dispatch. (Lattice specs may still be needed for merge selection — separate concern.)

3. **Table-driven propagator dispatch** — the 4-way `case` at line 522 reads the table to select propagator constructor. New relation kinds add a row, not a branch.

4. **Topology handler unification** — the duality/non-duality fork becomes: "does this kind have the antitone property?" Read from table.

5. **Nomenclature alignment** — relation name values reflect algebraic kind: consider `'identity`, `'monotone`, `'antitone`, `'idempotent`, `'phantom` alongside current names. Or add algebraic-kind as a derived property of the existing names.

### In-scope (design only, implementation deferred)

6. **Extensibility for 6 non-ring operations** — the table should be designed to ACCOMMODATE coercion, parametric instantiation, trait dispatch, etc. even though Track 2F doesn't implement them. Design the extension mechanism.

7. **Merge function selection** — currently per-relation per-domain via closure. Should it become table-driven too? Or is the closure approach correct (domain-specific merge requires domain knowledge)?

### Out of scope

8. Moving narrowing, reduction, macro expansion, trait resolution onto SRE — these are PPN/PRN/CIU/BSP-LE tracks that build ON the algebraic foundation.
