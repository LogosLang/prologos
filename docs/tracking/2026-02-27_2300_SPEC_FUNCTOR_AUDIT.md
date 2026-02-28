# Spec / Functor / Trait / Property Configuration Language Audit

**Date**: 2026-02-27 (revised after independent critique)
**Scope**: Ergonomics, expressivity, and correctness of metadata configuration systems
**Method**: Phase 1–2 of design methodology (research + gap analysis + critique cycle)
**Reference**: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.md`

---

## Part I: Current State Inventory

### 1.1 Implementation Status

All four configuration keywords completed Phase 1 (syntax + storage):

| Keyword    | Struct                        | Store                      | Tests  | Stdlib Files              |
|------------|-------------------------------|----------------------------|--------|---------------------------|
| `spec`     | `spec-entry` (8 fields)       | `current-spec-store`       | ~100+  | (used everywhere)         |
| `property` | `property-entry` (6 fields)   | `current-property-store`   | 73     | `algebraic-laws.prologos` |
| `functor`  | `functor-entry` (4 fields)    | `current-functor-store`    | 11     | `type-functors.prologos`  |
| `trait`    | `trait-meta` (4 fields)       | `current-trait-registry`   | many   | (throughout stdlib)       |
| `bundle`   | `bundle-entry` (4 fields)     | `current-bundle-registry`  | many   | (throughout stdlib)       |
| `??`       | `expr-typed-hole` (1 field)   | (in parse tree)            | 9      | —                         |

### 1.2 Struct Field Inventories

**spec-entry** (macros.rkt:284):
```
type-datums, docstring, multi?, srcloc, where-constraints,
implicit-binders, rest-type, metadata
```

**property-entry** (macros.rkt:4995):
```
name, params, where-clauses, includes, clauses, metadata
```

**property-clause** (macros.rkt:4986):
```
name, forall-binders, holds-expr
```

**functor-entry** (macros.rkt:5234):
```
name, params, unfolds, metadata
```

**trait-meta** (macros.rkt:3797):
```
name, params, methods, metadata
```
✅ `metadata` field added (G5 implemented).

**bundle-entry** (macros.rkt:3983):
```
name, params, constraints, metadata
```
✅ `metadata` field added (G6 implemented).

---

## Part II: Metadata Key → Type Theory / Category Theory Mappings

### 2.1 Spec Keys → Type Theory

| Key | Type-Theoretic Interpretation | Phase | Status |
|-----|-------------------------------|-------|--------|
| `:implicits` | Implicit *and* erased Pi binders: `{A : Type}` → `Π(A :0 Type). ...` | 1 | ✅ Implemented |
| `:where` | Trait-dict Pi binders: `(Ord A)` → `Π($Ord-A : Ord A). ...` | 1 | ✅ Implemented |
| `:doc` | No type content — documentation | 1 | ✅ Implemented |
| `:examples` | Ground witnesses of the function type | 1 | ✅ Stored; Phase 2 runs them |
| `:see-also` | No type content — cross-reference | 1 | ✅ Implemented |
| `:since` | No type content — versioning | 1 | ✅ Stored |
| `:deprecated` | No type content — warning metadata | 1 | ✅ Implemented + warning emission |
| `:properties` | Universal Pi: `Π(x:A). P(x)` — each `:holds` is a proof obligation | 1 | ✅ Stored; Phase 2 checks them |
| `:pre` | Refined domain: `Π(x:A). P(x) → B` — proof arg added | 2 | ✅ Parsed + stored (inert); mutual exclusion with `:invariant` enforced (G1) |
| `:post` | Refined codomain: `A → Σ(r:B). Q(r)` — Sigma return | 2 | ✅ Parsed + stored (inert); mutual exclusion with `:invariant` enforced (G1) |
| `:invariant` | Full dependent: `Π(x:A). Σ(r:B). R(x,r)` — relates args to return | 2 | ✅ Parsed + stored (inert); mutual exclusion with `:pre`/`:post` enforced (G1) |
| `:refines` | Erased Sigma: `Σ(r:B). P(r) :0` — value + compile-time proof (erased at runtime) | 3 | ⬜ Designed, not parsed |
| `:measure` | Well-founded ordering: `Args → Nat` for termination | 3 | ⬜ Designed, not parsed |
| `:decreases` | Structural descent indicator | 3 | ⬜ Designed, not parsed |
| `:proof` | Proof strategy hint (`:auto` triggers logic engine) | 3 | ⬜ Designed, not parsed |
| `:mixfix` | No type content — operator registration | 1 | ✅ Implemented |

**Observation**: All Phase 1 keys are implemented. Phase 2 keys (`:pre`, `:post`, `:invariant`) have clear type-theoretic interpretations but no parser support yet. Phase 3 keys (`:refines`, `:measure`, `:decreases`, `:proof`) are purely design-stage.

### 2.2 Functor Keys → Category Theory

| Key | CT Interpretation | Plain English | Phase | Status |
|-----|-------------------|---------------|-------|--------|
| `:unfolds` | Object mapping: `F : Ob(C) → Ob(D)` | "What this expands to" | 1 | ✅ Required, implemented |
| `:doc` | — | Documentation | 1 | ✅ Implemented |
| `:laws` | Category axioms (assoc of ∘, id laws) | "Rules these follow" | 1 | ✅ Parsed + stored |
| `:compose` | Morphism composition: `∘ : Hom(B,C) × Hom(A,B) → Hom(A,C)` | "How to chain two" | 2 | ⬜ Stored in metadata, not active |
| `:identity` | Identity morphism: `id_A ∈ Hom(A,A)` | "The do-nothing version" | 2 | ⬜ Stored in metadata, not active |
| `:see-also` | — | Cross-references | 1 | ✅ Stored |
| `:transforms` | Natural transformation: `η : F ⇒ G` | "Convert between functors" | 4 | ⬜ Not yet designed in detail |
| `:adjoint` | Adjunction: `F ⊣ G` | "Paired functor" | 4 | ⬜ Not yet designed in detail |

### 2.3 Property Keys → Proof Theory

| Key | Proof-Theoretic Interpretation | Status |
|-----|-------------------------------|--------|
| `:where` | Hypothesis context: `Γ, C₁(A), C₂(A) ⊢ ...` | ✅ Implemented |
| `:includes` | Conjunction introduction: `P ∧ Q` | ✅ Implemented (with flattening) |
| `:name` (on clause) | Named proposition label | ✅ Implemented |
| `:forall` (on clause) | Universal quantification: `∀(x:A). ...` | ✅ Implemented |
| `:holds` (on clause) | Proposition to prove/test: `P(x)` | ✅ Implemented |

### 2.4 Trait Keys → Interface Theory

| Key | Meaning | Status |
|-----|---------|--------|
| `:laws` | Property references that instances must satisfy | ✅ Parsed, stored in `current-trait-laws` |
| `:doc` | Documentation | ✅ Stored in `trait-meta` metadata field (G5); `trait-doc` accessor |
| `:deprecated` | Deprecation notice | ✅ Stored + warning emission during type-checking (G5 + G7) |
| `:see-also` | Cross-references | ✅ Stored in `trait-meta` metadata field (G5) |

---

## Part III: Gap Analysis

### 3.1 Ambiguity / Conflict Analysis

**G1: `:pre` + `:post` vs `:invariant` — semantic conflict, not overlap**

These keys have *genuinely different* type-theoretic interpretations:
- `:pre` (P) = proof obligation on the **caller** — refined domain: `Π(x:A). P(x) → B`
- `:post` (Q) = proof obligation on the **implementer** — refined codomain: `A → Σ(r:B). Q(r)`
- `:invariant` (R) = single relational assertion bundled into return: `Π(x:A). Σ(r:B). R(x,r)`

They are NOT equivalent or subsumptive:
```prologos
;; :pre + :post (independent assertions — caller proves P, implementer proves Q)
spec foo A -> B
  :pre (fn [a] (positive? a))
  :post (fn [a b] (> b a))
;; TT: Π(a:A). Positive(a) → Σ(b:B). b > a

;; :invariant (single relational assertion — implementer proves everything)
spec foo A -> B
  :invariant (fn [a b] (and (positive? a) (> b a)))
;; TT: Π(a:A). Σ(b:B). Positive(a) ∧ b > a
```

**Risk**: Having all three creates an ambiguous desugaring — the `:pre` proof argument interacts differently with `:invariant` than with `:post`.

**Recommendation**: If `:invariant` is present alongside `:pre` or `:post`, emit an **error** (not warning): "`:invariant` and `:pre`/`:post` have different proof obligation semantics and cannot be combined. Use `:pre` + `:post` for split obligations, or `:invariant` for a single relational assertion."

**G2: `:implicits` metadata vs inline `{A : Type}` kind disagreement**

Current behavior: merge and warn on duplicate names. But what if they disagree on kinds?
```prologos
spec foo {A : Type} [A -> B] -> B
  :implicits {A : Type -> Type}    ;; conflict!
```

**Risk**: Silent kind override or cryptic type error.

**Recommendation**: When deduplicating, if the same name appears in both with *different* kinds, emit an error: "implicit binder `A` declared as `Type` inline but `Type -> Type` in `:implicits`."

**G3: Property `:where` vs spec `:where` constraint mismatch**

```prologos
spec sort [List A] -> [List A]
  :where (Eq A)           ;; only Eq
  :properties (sortable-laws A)   ;; requires (Ord A)
```

If `sortable-laws` has `:where (Ord A)` but the spec only constrains `(Eq A)`, the property is unverifiable for the spec's constraint set.

**Risk**: Phase 2 property checking would need to synthesize an `Ord A` dictionary that isn't available.

**Important subtlety**: Constraint implication through bundles matters here. `bundle Comparable := (Eq, Ord)` means `(Ord A)` implies `(Eq A)` (since `Ord` may require `Eq`). So a spec with `:where (Ord A)` *does* satisfy a property requiring only `(Eq A)`. The check must follow implication, not literal equality.

**Recommendation**: At Phase 2, when activating property checking:
1. Build a constraint implication graph from `bundle` declarations (leveraging existing `expand-bundle-constraints`)
2. Check that property constraints are *satisfied by* (not literally equal to) spec constraints
3. Emit an error if not: "property `sortable-laws` requires `(Ord A)` but spec `sort` only provides `(Eq A)`. Did you mean `:where (Ord A)`?"

**G4: Functor name collision with `data` definitions**

```prologos
data Result {A} = ok A | err String    ;; algebraic data type
functor Result {A} :unfolds [Either String A]   ;; transparent alias
```

Both register via `process-deftype`. The second overwrites the first.

**Risk**: Silent clobbering of data constructors.

**Recommendation**: In `process-functor`, check `(lookup-ctor func-name)` and `(hash-ref (current-deftype-macros) func-name #f)` before registration. If a `data` definition exists, emit an error: "functor `Result` conflicts with existing data type `Result`."

### 3.2 Structural Gaps

**G5: `trait-meta` lacks a `metadata` field**

`spec-entry`, `property-entry`, and `functor-entry` all have a `metadata` hash field. `trait-meta` does not — it has `(name params methods)` only.

The `process-trait` function *does* parse metadata via `parse-spec-metadata` (line 4826) and extracts `:laws` (line 4860). But `:doc`, `:deprecated`, `:see-also` values parsed from the same block are silently discarded — they exist in `trait-metadata` local variable but are never stored.

**Impact**: Traits cannot carry documentation, deprecation warnings, or cross-references in the registry. Any future tooling (doc generation, deprecation linting) has no data to work with.

**Fix**: Add `metadata` field to `trait-meta`:
```racket
(struct trait-meta (name params methods metadata) #:transparent)
```
Thread `trait-metadata` hash into the struct at line 4869.

**G6: `bundle-entry` lacks a `metadata` field**

Same issue. `bundle-entry` has `(name params constraints)`. No room for `:doc`, `:deprecated`, `:see-also`.

**Fix**: Add `metadata` field to `bundle-entry`:
```racket
(struct bundle-entry (name params constraints metadata) #:transparent)
```

**G7: No `:deprecated` warning for trait method usage**

`:deprecated` on `spec` works — `typing-core.rkt:270-279` checks during type-checking of `expr-fvar`. But there's no corresponding check for deprecated traits, deprecated functor names, or deprecated properties.

**Fix**: Extend the deprecation check in typing-core.rkt to also check `lookup-trait`, `lookup-functor`, and `lookup-property` when the name is referenced.

### 3.3 Surface Pi/Sigma Type Leaks

**Where Pi/Sigma types currently appear in surface signatures:**

| Situation | Current Surface | Can It Be Hidden? |
|-----------|----------------|-------------------|
| Length-indexed vectors | `spec replicate <(n : Nat) -> A -> [Vec A n]>` | **YES**: `:implicits {n : Nat}` → `spec replicate A -> [Vec A n]` when `n` appears in arg type. BUT: when `n` appears ONLY in return type, it can't be an implicit (no inference site). Need `:depends {n : Nat}` or keep angle brackets. |
| Existential returns | `spec filter ... -> <(result : [List A]) * [SubList result xs]>` | **YES**: `:refines` designed for this. `spec filter [A -> Bool] -> [List A] -> [List A]` with `:refines (fn [r xs] [sub-list? r xs])` compiles to the Sigma. |
| Transducer types | `<(S :0 Type) -> [S -> B -> S] -> S -> A -> S>` | **YES**: `functor Xf` already hides this. ✅ |
| Lens/optics types | `<{F : Type -> Type} -> (Functor F) -> [A -> [F B]] -> S -> [F T]>` | **YES**: `functor Lens` hides this. ✅ |
| Dependent eliminators | `spec vec-head <(n : Nat) -> [Vec A [suc n]] -> A>` | **MOSTLY**: `:implicits {n : Nat}` works because `n` appears in `[Vec A [suc n]]`. But the `[suc n]` index IS part of the surface type `[Vec A [suc n]]`. The Pi is hidden; the dependent *index* is visible. This is acceptable — the index is semantically meaningful. |
| Proofs as arguments | `spec divide Int Int -> [Not [Eq Int y 0]] -> Int` | **YES**: `:pre` designed for this. `spec divide Int Int -> Int` with `:pre (fn [_ y] [not [eq? y 0]])` hides the proof argument entirely. |

**Verdict**: The design covers all common cases. The only remaining surface leaks are:
1. **Dependent indices in type applications** (e.g., `[Vec A n]`) — these SHOULD be visible; they're the whole point.
2. **Return types that depend on runtime values not appearing in arguments** — these are genuinely irreducible Pi types. Extremely rare in practice.

**New opportunity: `:depends` key**

For the case where a runtime value appears in the return type but not in any argument:
```prologos
;; Currently requires angle brackets:
spec replicate <(n : Nat) -> A -> [Vec A n]>

;; With :depends, could write:
spec replicate Nat -> A -> [Vec A n]
  :depends {n : Nat}  ;; "n is a runtime value that the return type depends on"
```

`:depends` differs from `:implicits` in that `:implicits` are *erased* (multiplicity 0), while `:depends` names are *relevant* (multiplicity ω) — they are actual runtime arguments. The key maps to: "this argument is both a runtime parameter AND a type-level variable."

**Assessment**: This is a genuine ergonomic win for a narrow but important class of dependent signatures. Worth designing but low priority — angle brackets are adequate.

### 3.4 Missing Dependent Type Concepts

| Concept | Needed? | Design Approach | Priority |
|---------|---------|-----------------|----------|
| Dependent pattern matching (with-views) | Yes, eventually | `defn` concern, not spec/functor | Deferred |
| Inductive families (indexed types) | Already supported | `data Vec : Nat -> Type -> Type` works today | — |
| Universe polymorphism | Automatic | Universe inference handles it; `:implicits {l : Level}` for explicit | — |
| Proof irrelevance / erasure | Already supported | QTT `:0` multiplicity | — |
| Coinductive types / codata | Future | New `codata` keyword with `:observations` | Far future |
| Higher Inductive Types (HITs) | No | Out of scope for Phase 0 | — |
| Telescopes | Already supported | `:implicits` with multiple brace groups | — |
| Equality types / transport | Partially | `Eq` type exists; `transport`/`subst` not yet | Future |
| Recursion schemes | Opportunity | `:fold`/`:unfold` on `functor` — see §4.2 | Medium |

### 3.5 Missing Category Theory Concepts

**Concepts that fit as `functor` metadata:**

| CT Concept | Proposed Key | Meaning | Priority |
|------------|-------------|---------|----------|
| Variance annotation | `:variance` | `:covariant` (default), `:contravariant`, `:invariant`, `:phantom` | Medium |
| Initial algebra (fold) | `:fold` | The catamorphism / fold operation for this type | Medium |
| Terminal coalgebra (unfold) | `:unfold` | The anamorphism / unfold operation | Medium |
| Free construction | `:free-over` | "This is the free X over Y" (e.g., Free monad over functor) | Low |
| Monoidal structure | `:tensor` / `:unit` | For applicative-style `⊗ : F A × F B → F (A × B)` | Low |
| Kan extension | `:left-kan` / `:right-kan` | Extremely advanced; theoretical completeness | Far future |

**Concepts that DON'T fit under `functor` — where they belong:**

| CT Concept | Correct Keyword | Rationale |
|------------|----------------|-----------|
| Monads | `trait` + `bundle` | Monad is an interface (bind/return), not a type alias |
| Comonads | `trait` + `bundle` | Same — interface (extract/extend) |
| Arrows | `trait` + `bundle` | Interface (arr/>>>/first) |
| F-algebras | `trait` OR `functor` | If algebra IS the recursion scheme → `:fold` on `functor`. If algebra is an interface over arbitrary carriers → `trait` |
| Profunctors | `trait` | Interface (dimap), multi-param |
| Adjunctions between traits | Future meta-level | Relates two traits; no current keyword fits cleanly |

**Concepts that might warrant `schema`:**

| Concept | `schema` Fit | Alternative |
|---------|-------------|-------------|
| Closed record types | ✅ Natural fit | `data` with named fields |
| Validated maps | ✅ With `:validates` | Manual `data` + smart constructors |
| Row polymorphism | Possible with `:extends` | Requires type system extension |
| Database schemas | ✅ With `:primary-key`, `:index` | External tooling metadata |
| API contracts | ✅ With `:required`, `:optional` | `spec` on constructor |

**Assessment**: `schema` is a worthwhile future keyword for closed-world product types with validation metadata. It should NOT try to subsume `trait` concerns (open-world, implementation requirements). A `schema` is a value description; a `trait` is a behavior requirement. Keep them separate.

---

## Part IV: Opportunity Analysis

### 4.1 Near-Term Opportunities (Phase 1 completion / bug fixes)

**O1: Add `metadata` field to `trait-meta` and `bundle-entry`**
- Enables `:doc`, `:deprecated`, `:see-also` on traits and bundles
- Consistent with spec-entry, property-entry, functor-entry
- Effort: ~30 lines (struct change + threading in process-trait/process-bundle)
- Impact: Unblocks documentation generation for traits

**O2: Functor name collision detection**
- Check for existing `data` definitions before registering functor-as-deftype
- Effort: ~10 lines in process-functor
- Impact: Prevents silent clobbering bugs

**O3: `:implicits` kind conflict detection**
- When merging inline and metadata implicits, check kind agreement
- Effort: ~15 lines in process-spec
- Impact: Better error messages

### 4.2 Medium-Term Opportunities (Phase 2 extensions)

**O4: `:variance` on `functor`**
```prologos
functor Predicate {A : Type}
  :variance :contravariant
  :unfolds [A -> Bool]
  :doc "A predicate over A (contravariant in A)"
```

Variance annotations enable:
- Automated subtyping for functor-wrapped types
- Correct HKT trait instance derivation
- Better error messages ("expected covariant position, got contravariant")

**Phased implementation** (variance is only useful if verified):
- Phase 1: Store `:variance` in functor metadata (inert)
- Phase 2: Infer variance from `:unfolds` structure (detect covariant/contravariant/invariant positions)
- Phase 3: Check declared variance against inferred — error on mismatch: "functor `Bad` declares `:covariant` for `A` but `A` appears in contravariant position in `:unfolds [A -> Int]`"

**O5: `:fold` / `:unfold` on `functor` (recursion schemes)**
```prologos
functor ListF {A R : Type}
  :doc "Base functor for List (for recursion schemes)"
  :unfolds [Either Unit [Pair A R]]
  :fold fold-list       ;; catamorphism: ListF A R → R
  :unfold unfold-list   ;; anamorphism: R → ListF A R
```

This captures the algebra/coalgebra duality directly on the type. Phase 2+ could auto-derive `cata`, `ana`, `hylo` from these.

**O6: Parse (but don't activate) Phase 2 spec keys**

Add parser support for `:pre`, `:post`, `:invariant` NOW, storing them in spec metadata. This allows users to write future-proof specs today. The keys are inert until Phase 2 activates them.

Implementation: Already handled — `parse-spec-metadata` stores unrecognized keys via the Postel principle. But explicit recognition (with validation of their expected shapes) would be better than silent acceptance.

**O7: `:exists` clause on `property`**

Currently only `:forall` / `:holds` (universal). Add `:exists` for existential properties:
```prologos
property has-fixed-point {A : Type} {f : [A -> A]}
  - :name "fixed-point-exists"
    :exists {x : A}
    :holds [eq? [f x] x]
```

Maps to `∃(x:A). f(x) = x` — an existential proposition. At Phase 2 (QuickCheck), this means "find a witness." At Phase 3 (verification), this is a proof obligation to construct a witness.

### 4.3 Long-Term Opportunities (Phase 3+)

**O8: `:depends` key on spec — considered and deferred**

For dependent return types where the dependency is a runtime argument (not erased):
```prologos
spec replicate Nat -> A -> [Vec A n]
  :depends {n : Nat}     ;; first arg is also a type-level dependency
```

Maps to: `Π(n : Nat). Π(a : A). Vec A n` where `n` has multiplicity ω (not erased).

**Reconsidered**: The connection between `Nat` (the positional type) and `n` (the named dependency) is ambiguous — which `Nat` argument does `n` refer to? The angle-bracket syntax already handles this case clearly and explicitly:
```prologos
spec replicate <(n : Nat) -> A -> [Vec A n]>
```

**Verdict**: Angle brackets are the right tool for truly dependent signatures. `:depends` adds complexity for a narrow case. **Deferred** — revisit only if angle brackets prove ergonomically unacceptable in practice.

**O9: `schema` keyword (preliminary)**

```prologos
schema User
  name : String
  age : Nat
  email : String?
  :doc "A user account record"
  :validates
    - :name "age-positive"
      :holds [> .age 0N]
```

Field declarations use `name : Type` (colon-based, consistent with trait method syntax). Metadata keys use `:keyword` prefix (consistent with spec/functor metadata). This separates "fields are data" from "metadata is configuration."

Desugars to a `data` definition with a single constructor + validation. Metadata:

| Key | Meaning | TT Interpretation |
|-----|---------|-------------------|
| (field keys) | Required fields with types | Product type components |
| `:optional` | Optional fields | Fields with `A?` type |
| `:defaults` | Default values for fields | Constant morphisms |
| `:validates` | Cross-field invariants | Refinement / Sigma |
| `:extends` | Schema extension | Dependent record extension |
| `:doc` | Documentation | — |
| `:examples` | Example instances | Ground witnesses |

**Design question**: Should `schema` be a new top-level keyword, or metadata on `data`? Arguments for separate keyword: closed-world semantics, validation-first, approachable to non-PL-theorists. Arguments against: keyword proliferation, overlap with `data`. **Recommendation**: Separate keyword is cleaner — `schema` reads as "data shape specification" while `data` reads as "algebraic type definition."

**O10: `:coherence` on trait**

For traits where at most one valid instance should exist per type:
```prologos
trait Eq {A : Type}
  :coherence :canonical    ;; at most one instance per A
  :laws (eq-laws A)
  spec eq? A A -> Bool
```

This is relevant for typeclasses with global uniqueness (Eq, Ord, Hash). Prevents orphan instance proliferation. Not urgent but important for a mature trait system.

---

## Part V: Keyword Symmetry Table (Updated)

```
                ┌─────────────────────────────────────────────────────┐
                │              CONFIGURATION KEYWORDS                  │
                ├──────────┬──────────────────────────────────────────┤
                │ Keyword  │ What it configures                       │
                ├──────────┼──────────────────────────────────────────┤
Function        │ spec     │ Type signature + metadata for functions  │
                │          │  :implicits, :where, :doc, :examples,   │
                │          │  :properties, :pre, :post, :invariant,  │
                │          │  :refines, :measure, :deprecated, ...   │
                ├──────────┼──────────────────────────────────────────┤
Behavior        │ trait    │ Method signature requirement             │
                │          │  :laws, :doc, :deprecated, :coherence   │
                ├──────────┼──────────────────────────────────────────┤
Behavior group  │ bundle   │ Conjunction of trait requirements        │
                │          │  :doc, :deprecated                      │
                ├──────────┼──────────────────────────────────────────┤
Proposition     │ property │ Reusable law/invariant group             │
                │          │  :where, :includes, clauses             │
                │          │  (each clause: :name, :forall, :holds)  │
                ├──────────┼──────────────────────────────────────────┤
Type abstract.  │ functor  │ Named type with algebraic structure      │
                │          │  :unfolds, :compose, :identity, :laws,  │
                │          │  :variance, :fold, :unfold, :doc, ...   │
                ├──────────┼──────────────────────────────────────────┤
Data shape      │ schema   │ Closed record + validation (FUTURE)      │
(future)        │          │  field keys, :validates, :extends, :doc │
                ├──────────┼──────────────────────────────────────────┤
Exploration     │ ??       │ Typed hole for interactive development   │
                │          │  Reports expected type + context         │
                └──────────┴──────────────────────────────────────────┘
```

### Cross-Cutting Metadata Keys

These keys have the same semantics across all keywords that support them:

| Key | Semantics | Supported On |
|-----|-----------|-------------|
| `:doc` | Human-readable documentation string | spec ✅, functor ✅, property (via metadata), trait ✅ (G5), bundle ✅ structural (G6) |
| `:deprecated` | Deprecation notice (string or #t) | spec ✅, trait ✅ (G5+G7 — with warning emission), functor ✅ (G7 — with warning emission), bundle ✅ structural (G6) |
| `:see-also` | Cross-references to related definitions | spec ✅, functor ✅, trait ✅ (G5), bundle ✅ structural (G6) |
| `:since` | Version/date introduced | spec ✅, others ⬜ |
| `:examples` | Concrete input/output pairs | spec ✅, schema (future) |
| `:laws` | Property references (what laws must hold) | trait ✅, functor ✅, spec (via :properties) |
| `:properties` | Property references on functions | spec ✅ |

---

## Part VI: Correctness of Mappings — The Type-Theoretic Reading

### 6.1 The Graduation Path (Verified)

The Extended Spec Design's graduation path remains sound:

| Phase | `:properties` | `:pre` / `:post` | `:refines` |
|-------|--------------|-------------------|------------|
| 1 (now) | Stored, inert | Not parsed | Not parsed |
| 2 (medium) | QuickCheck (random test) | Runtime contract (blame tracking) | Runtime assertion |
| 3 (long) | Proof obligation | Refined Pi type | Sigma compilation |

Each spec metadata key has a clear, unambiguous type-theoretic interpretation that upgrades from testing to proving without syntax changes. **No conflicts in this mapping.**

### 6.2 Category-Theoretic Reading of `functor` (Verified)

A `functor` declaration with all metadata provides the *data of a category*:

```
functor F {A B : Type}             -- Parameterized type constructor
  :unfolds <...>                   -- Type-level function (object mapping)
  :compose f-compose               -- Morphism composition ∘
  :identity f-id                   -- Identity morphism id
  :laws (f-laws A B)               -- Category axioms verified by properties
```

This describes the category where:
- Objects: types `A`, `B`, ...
- Morphisms: values of type `F A B`
- Composition: `f-compose : F B C → F A B → F A C`
- Identity: `f-id : F A A`
- Laws: associativity + left/right identity

**Naming note**: The keyword `functor` names a *parameterized type with algebraic structure*, not a functor in the strict CT sense (which would be a mapping between categories). This pragmatic naming was a deliberate design choice (see Extended Spec Design Part VII) — `functor` captures "structure-preserving mapping" in the informal sense that programmers use. The Haskell community uses "Functor" similarly (their `Functor` typeclass is technically an endofunctor on Hask). We follow this tradition.

Natural transformations (`:transforms`) and adjunctions (`:adjoint`) are correctly deferred — they relate *between* functors/categories, requiring a meta-level that Phase 1 doesn't support.

### 6.3 The `property` ↔ `trait` ↔ `spec` Triangle (Verified)

```
trait defines WHAT operations exist        → method signatures
property defines WHAT laws they obey       → propositions
spec attaches BOTH to a function           → :where + :properties
instance provides HOW (implementations)    → method bodies
(future) evidence provides HOW (proofs)    → property witnesses
```

This triangle is clean. No conceptual leaks or overlaps. The only structural gap is G5 (trait lacks metadata field), which is a mechanical fix.

---

## Part VII: Roadmap

### Tier 1: Structural Fixes ✅ COMPLETE

| ID | Task | Effort | Files | Status |
|----|------|--------|-------|--------|
| G5 | Add `metadata` field to `trait-meta` | ~30 LOC | macros.rkt | ✅ |
| G6 | Add `metadata` field to `bundle-entry` | ~20 LOC | macros.rkt | ✅ |
| G4 | Functor/data name collision detection | ~10 LOC | macros.rkt | ✅ |
| G3 | Property/spec `:where` subset validation stub | ~15 LOC | macros.rkt (warning only) | ✅ |
| G2 | `:implicits` kind conflict error | ~15 LOC | macros.rkt | ✅ |
| G7 | Deprecation warnings for traits + functors | ~20 LOC | typing-core.rkt | ✅ |
| G1 | `:invariant` / `:pre`+`:post` mutual exclusion | ~10 LOC | macros.rkt | ✅ |
| G8 | Error message audit for all gap scenarios | ~20 LOC | macros.rkt | ✅ |
| G9 | Test cases for each gap (collision, conflict, mismatch) | ~50 LOC | tests/ | ✅ (39 tests in test-config-audit.rkt) |

### Tier 2: Phase 2 Key Activation ✅ COMPLETE

| ID | Task | Effort | Dependencies | Status |
|----|------|--------|--------------|--------|
| O6 | Explicit parsing of `:pre`, `:post`, `:invariant` (store only) | ~40 LOC | None | ✅ |
| O4 | `:variance` on `functor` (store + doc) | ~30 LOC | G5 done | ✅ |
| O5 | `:fold` / `:unfold` on `functor` (store + doc) | ~20 LOC | None | ✅ |
| O7 | `:exists` clause on `property` | ~40 LOC | None | ✅ |
| O11 | `:refines :relevant` flag for extractable Sigma proofs | ~20 LOC | None | ✅ (handled by default clause) |

### Tier 3: Phase 2 Backends (large effort, separate design)

| ID | Task | Effort | Dependencies |
|----|------|--------|--------------|
| — | QuickCheck execution of `:holds` clauses | Large | `Gen` trait, random generation |
| — | `:examples` type-checking and execution | Medium | Phase 2 test infrastructure |
| — | `:pre`/`:post` contract wrapping with blame | Large | Runtime wrapper generation |
| — | `:compose`/`:identity` active verification | Medium | Property checking framework |

### Tier 4: Phase 3+ Features (future design)

| ID | Task | Dependencies |
|----|------|-------------|
| O8 | `:depends` key on spec (deferred — angle brackets sufficient) | Needs multiplicity-aware implicit handling |
| O9 | `schema` keyword | Separate design document |
| O10 | `:coherence` on trait | Instance resolution overhaul |
| — | `:refines` → Sigma compilation | Verification infrastructure |
| — | `:transforms` / `:adjoint` on functor | Meta-level functor relations |
| — | Opaque functors (no `:unfolds`) | Abstract type boundaries |

---

## Part VIII: Interaction with QTT and Effects

### 8.1 `:implicits` — Implicit vs Erased (Clarification)

These are orthogonal concepts in type theory:

| Concept | Meaning | Example |
|---------|---------|---------|
| Implicit | Inferred by compiler, not written by user | `{A}` |
| Erased | Not present at runtime (multiplicity 0) | `:0` |
| Explicit + erased | User writes it, but runtime erases it | `<{n :0 Nat}>` |
| Implicit + relevant | Inferred, but present at runtime | Rare |

In Prologos, `:implicits` binders are *both implicit and erased* by design — matching Agda's `{A : Type}`. This is the correct default for 99%+ of cases. The rare "implicit but relevant" case (runtime-present but compiler-inferred) is served by:
1. Auto-implicit inference (already infers type vars from usage sites)
2. Angle brackets for explicit dependent Pi (when you need the name at runtime)

**Decision**: `:implicits` stays erased-only. No multiplicity annotations on `:implicits` — this would violate progressive disclosure by layering QTT syntax onto a convenience feature.

### 8.2 `:refines` — Erasure Semantics (Clarification)

`:refines` compiles to `Σ(r:B). P(r)`, but is the proof component `P(r)` extractable at runtime?

**Default**: Erased. The proof has multiplicity 0 — the type checker verifies it statically, but the runtime value is just `r`, not a pair `(r, proof)`. This aligns with QTT's erasure model: type-level information is erased by default.

**Future option**: `:refines :relevant` for extractable proofs (the runtime value IS a pair). This is needed for programs that compute with proofs (e.g., proof-carrying code, certified programs). Deferred to Phase 3.

### 8.3 Linearity Interaction with `:pre` / `:post`

QTT multiplicities interact with metadata predicates:
```prologos
spec close (h :1 Handle) -> [IO Unit]
  :pre (fn [h] (open? h))    ;; Uses h! But h is linear!
```

**Resolution**: `:pre` / `:post` / `:invariant` predicates operate on **multiplicity-0 copies** (observations without consumption). The predicate sees the value but does not consume it. This is consistent with QTT's erasure model — the check is a compile-time obligation that doesn't affect runtime resource usage.

At Phase 2 (runtime contracts), the wrapper must also observe without consuming. For linear resources, this means the contract check must precede the function call and the resource flows through untouched.

### 8.4 Effects Interaction (Deferred)

Prologos does not currently have a general effect system (session types handle communication effects). When a general effect system is added, metadata interactions will need a separate design pass. Key question: can `:pre` predicates be effectful? (Answer should be NO — predicates must be pure to ensure they don't interfere with the function's resource behavior.)

---

## Part IX: Limitations and Tradeoffs (renumbered from VIII)

### What We Can't Capture

1. **Higher-dimensional category theory** (2-categories, ∞-categories): These require morphisms-between-morphisms, which our flat keyword structure can't express. This is acceptable — no practical programming language captures these.

2. **Adjunctions as first-class**: `F ⊣ G` relates two functors with universal properties. Expressing this requires a declaration that BINDS two functor names together. No single keyword naturally captures this. Possible future syntax: `adjunction Free Forgetful :unit ... :counit ...`.

3. **Monad transformers as CT concept**: Monad transformers are natural transformations between monad categories. They're better captured as `trait MonadTrans {T : (Type -> Type) -> Type -> Type}` than as functor metadata.

4. **Enriched categories**: Categories where hom-sets have additional structure (e.g., hom-objects are lattices). This is what the propagator/lattice system partially captures, but there's no general keyword for it.

### Tradeoffs Accepted

1. **Metadata keys are inert until Phase 2+**: Users can write `:pre`, `:post`, `:properties` today, but they're decorative until backends exist. **Tradeoff**: Early syntax stabilization vs. false sense of verification. **Mitigation**: Document clearly that Phase 1 stores but doesn't check.

2. **`functor` is overloaded**: It serves as both "simple type alias" (`functor FilePath :unfolds String`) and "rich categorical structure" (`functor Xf ... :compose ... :identity ... :laws ...`). **Tradeoff**: One keyword vs. conceptual purity. **Assessment**: Progressive disclosure makes this work — simpler uses look simpler.

3. **`:laws` on trait are advisory**: Writing `:laws (eq-laws A)` on a trait doesn't actually check anything yet. **Tradeoff**: Documentation value now vs. enforcement later. **Assessment**: Acceptable — the syntax is stable and the infrastructure is ready for Phase 2.

---

## Appendix: Complete Metadata Key Reference

### spec

| Key | Value Type | Phase | TT Mapping | Status |
|-----|-----------|-------|------------|--------|
| `:implicits` | brace-param groups | 1 | Erased Pi binders | ✅ |
| `:where` | constraint list | 1 | Dict-passing Pi binders | ✅ |
| `:doc` | string | 1 | — | ✅ |
| `:examples` | `(expr => expr)` list | 1 | Ground witnesses | ✅ stored |
| `:properties` | property-ref list | 1 | Universal Pi types | ✅ stored |
| `:see-also` | symbol list | 1 | — | ✅ |
| `:since` | string | 1 | — | ✅ |
| `:deprecated` | string or #t | 1 | — | ✅ + warnings |
| `:mixfix` | sub-metadata | 1 | — | ✅ |
| `:pre` | `(fn [args...] Bool)` | 2 | Refined domain Pi | ✅ parsed + stored (inert) |
| `:post` | `(fn [args... ret] Bool)` | 2 | Sigma return type | ✅ parsed + stored (inert) |
| `:invariant` | `(fn [args... ret] Bool)` | 2 | Dependent Pi+Sigma | ✅ parsed + stored (inert) |
| `:refines` | `(fn [ret] Bool)` | 3 | Erased Sigma | ⬜ designed |
| `:measure` | `(fn [args...] Nat)` | 3 | Well-founded order | ⬜ designed |
| `:decreases` | symbol or datum | 3 | Structural descent | ⬜ designed |
| `:proof` | datum or `:auto` | 3 | Proof strategy | ⬜ designed |
| `:depends` | brace-param groups | 3 | Relevant Pi binders (ω) | ⬜ considered, deferred |

### functor

| Key | Value Type | Phase | CT Mapping | Status |
|-----|-----------|-------|------------|--------|
| `:unfolds` | type-expr | 1 | Object mapping | ✅ required |
| `:doc` | string | 1 | — | ✅ |
| `:laws` | property-ref list | 1 | Category axioms | ✅ stored |
| `:see-also` | symbol list | 1 | — | ✅ |
| `:compose` | identifier | 2 | Morphism composition | ⬜ stored, not active |
| `:identity` | identifier | 2 | Identity morphism | ⬜ stored, not active |
| `:variance` | keyword | 2 | Functor variance | ✅ parsed + stored (inert) |
| `:fold` | identifier | 2 | Catamorphism (F-algebra) | ✅ parsed + stored (inert) |
| `:unfold` | identifier | 2 | Anamorphism (F-coalgebra) | ✅ parsed + stored (inert) |
| `:free-over` | identifier | 3 | Free construction | ⬜ proposed |
| `:tensor` / `:unit` | identifiers | 3 | Monoidal structure | ⬜ proposed |
| `:transforms` | nat-trans-ref | 4 | Natural transformation | ⬜ designed |
| `:adjoint` | functor-ref | 4 | Adjunction partner | ⬜ designed |

### property

| Key | Value Type | Phase | PT Mapping | Status |
|-----|-----------|-------|------------|--------|
| `:where` | constraint list | 1 | Hypothesis context Γ | ✅ |
| `:includes` | property-ref list | 1 | Conjunction ∧ | ✅ |
| clause `:name` | string | 1 | Proposition label | ✅ |
| clause `:forall` | brace-params | 1 | Universal ∀ | ✅ |
| clause `:holds` | expr | 1 | Proposition body | ✅ |
| clause `:exists` | brace-params | 2 | Existential ∃ | ✅ parsed + stored (inert) |

### trait

| Key | Value Type | Phase | Status |
|-----|-----------|-------|--------|
| `:laws` | property-ref list | 1 | ✅ |
| `:doc` | string | 1 | ✅ stored (G5) |
| `:deprecated` | string or #t | 1 | ✅ stored + warning emission (G5+G7) |
| `:see-also` | symbol list | 1 | ✅ stored (G5) |
| `:coherence` | keyword | 3 | ⬜ proposed |

### bundle

| Key | Value Type | Phase | Status |
|-----|-----------|-------|--------|
| `:doc` | string | 1 | ✅ structural (G6) |
| `:deprecated` | string or #t | 1 | ✅ structural (G6) |
| `:see-also` | symbol list | 1 | ✅ structural (G6) |

---

## Appendix B: Critique Response Record

Independent critique received and processed per design methodology Phase 3 (critique cycle).

### Accepted (incorporated into revision)

| Point | Critique | Response |
|-------|----------|----------|
| G1 upgrade | `:pre`/`:post`/`:invariant` warning → error | **Accepted**: these have genuinely different TT semantics (caller vs implementer proof obligations). Upgraded to error. |
| G3 implication | Constraint implication via bundles, not literal subset | **Accepted**: `(Ord A)` implies `(Eq A)` through bundle declarations. Check must follow implication graph. |
| :refines erasure | Clarify erased vs relevant Sigma | **Accepted**: default erased (multiplicity 0). Future `:refines :relevant` for extractable proofs. Added O11. |
| CT interpretation | "Functor" describes category data, not a CT functor | **Accepted the correction**: fixed language to say "data of a category." Retained naming rationale (deliberate pragmatic choice). |
| :variance phasing | Need inference + checking, not just storage | **Accepted**: added three-phase approach (store → infer → check). |
| :depends weakening | Angle brackets already handle this; `:depends` is ambiguous | **Accepted**: downgraded to "considered and deferred." |
| Schema syntax | Use `name : Type` not `:name Type` for field declarations | **Accepted**: consistent with trait method syntax. |
| Linearity note | `:pre`/`:post` on linear resources needs clarification | **Accepted**: predicates operate on multiplicity-0 copies (observation without consumption). Added §8.3. |
| Roadmap additions | G8 (error message audit) + G9 (gap test cases) | **Accepted**: added to Tier 1. |
| O11 | `:refines :relevant` flag | **Accepted**: added to Tier 2. |

### Rejected (with rationale)

| Point | Critique | Rationale for Rejection |
|-------|----------|----------------------|
| Struct inheritance | Base struct `entry-base` for all entries | Racket struct inheritance complicates `match` patterns throughout 14-file pipeline. The structs have fundamentally different shapes. Adding `metadata` field independently to each is simpler and less disruptive. |
| `:w` on `:implicits` | Allow relevant (non-erased) implicit binders | Violates progressive disclosure. `:implicits` is a convenience feature; layering QTT multiplicity syntax onto it defeats the purpose. The rare case is served by auto-implicits + angle brackets. |
| `profunctor` keyword | Separate top-level keyword for profunctors | Keyword proliferation. Profunctors are interfaces (`dimap`), correctly modeled as `trait Profunctor`. `:variance` on `functor` covers mixed variance annotation. |
| O12 | Named arguments in spec signatures (outside angle brackets) | Separate design concern that intersects with `:implicits`, `:depends`, and auto-implicit inference. Angle brackets already provide named dependent arguments. |

### Deferred (acknowledged, future scope)

| Point | Critique | Deferral Rationale |
|-------|----------|--------------------|
| S1 | Test coverage quality metrics | Valid but separate audit. Functor's 11 tests are appropriate for Phase 1 (metadata-only). |
| S2 | Error message quality audit | Partially addressed by G8. Full error message audit is implementation-phase work. |
| M1 | Runtime semantics for each key | Phase 3 design concern. This audit is Phases 1-2 (research + gap analysis). |
| M2 | Effects interaction | Prologos has no general effect system yet. Noted that `:pre`/`:post` predicates must be pure. |
| M4 | Tooling integration (LSP, IDE) | Explicitly out of scope per user brief ("not yet ready to consider editor-connected features"). |
