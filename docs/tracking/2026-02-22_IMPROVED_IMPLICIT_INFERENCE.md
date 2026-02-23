- [Summary](#orgb8e3fe7)
- [Direction 1: Auto-introduce Unbound Type Variables](#orgbe2f747)
  - [Implementation Notes](#orgc02b404)
- [Direction 2: Kind Inference from `:where` Clauses](#org662ad22)
  - [Implementation Notes](#org38451c6)
- [Scope](#org5ac704f)
- [Priority](#org400146c)
- [Dependencies](#org5e7965d)



<a id="orgb8e3fe7"></a>

# Summary

Reduce the need for explicit `{A : Type}` implicit binders in `spec` signatures. Today, many specs redundantly annotate type variables that the system can already infer. Two improvements are proposed.


<a id="orgbe2f747"></a>

# Direction 1: Auto-introduce Unbound Type Variables

If a capitalized identifier `A` appears free in the type signature and is not bound by any explicit binder, auto-introduce `{A : Type}`.

```prologos
;; These would be equivalent:
spec length {A : Type} [List A] -> Nat
spec length [List A] -> Nat
```

This already works in many cases today. The proposal is to make it the documented, reliable behavior for all kind-`Type` variables.


<a id="orgc02b404"></a>

## Implementation Notes

-   Scan type tokens after `extract-implicit-binders` for unbound capitalized identifiers
-   Check they are not in scope as type constructors (e.g., `Nat`, `Bool`, `List`)
-   Default kind: `(Type 0)`
-   Only applies to kind `Type`; higher-kinded variables still need explicit binders (unless Direction 2 covers them)


<a id="org662ad22"></a>

# Direction 2: Kind Inference from `:where` Clauses

If `C` appears in `:where (Seqable C)` and `Seqable` is declared over `{C : Type -> Type}`, infer `C`'s kind from the where clause.

```prologos
;; These would be equivalent:
spec gmap {A B : Type} {C : Type -> Type} [A -> B] -> [C A] -> [C B]
  :where (Seqable C) (Buildable C)

spec gmap [A -> B] -> [C A] -> [C B]
  :where (Seqable C) (Buildable C)
```


<a id="org38451c6"></a>

## Implementation Notes

-   `propagate-kinds-from-constraints` already refines kinds from constraints when explicit binders are present
-   Extension: when no explicit binder exists for a variable, and a where-clause constraint pins its kind, auto-introduce the binder with the inferred kind
-   Also applies to inline constraints: `(Seqable C) -> ...` should infer `{C : Type -> Type}` from the trait declaration


<a id="org5ac704f"></a>

# Scope

After this work:

-   `{A : Type}` → almost never needed (kind-`Type` variables auto-introduced)
-   `{C : Type -> Type}` → unnecessary when `:where` pins the kind
-   Explicit binders remain for: pedagogic clarity, disambiguation, and the rare case where no constraining position exists (e.g., `spec empty {A : Type} [List A]`)


<a id="org400146c"></a>

# Priority

Medium-high. This interacts with the extended spec design (`:implicits` key provides an alternative for explicit cases) but is independently valuable. Should be implemented before or alongside Phase 1 of the extended spec.


<a id="org5e7965d"></a>

# Dependencies

-   `extract-implicit-binders` (macros.rkt)
-   `propagate-kinds-from-constraints` (macros.rkt)
-   Trait store for kind lookups
-   `process-spec` pipeline
