# Gate 1 — Tagged-Union Runtime Representation
**Date**: 2026-05-02
**Status**: Design (rev 1, defunctionalize-first variant)
**Branch**: `lowering-yolo`
**Predecessor**: [`2026-05-02_LOWERING_INVENTORY.md`](2026-05-02_LOWERING_INVENTORY.md)

## 1. Motivation

The Day-0 inventory showed that the existing `.prologos` corpus has **zero
`main`-bearing files** that exercise multi-arm sum-type lowering today.
That's because `ast-to-low-pnet` flatly refuses anything beyond 2-arm
Bool/Nat match, and the existing corpus respects that boundary.

Real Prologos programs use sum types pervasively: `Maybe`, `Either`,
`List`, `Result`, plus user-defined ADTs declared with `data`. Without
support for these in lowering, "lower an arbitrary Prologos program" is
nowhere close. Gate 1 closes the smallest possible useful piece of this
surface.

## 2. Scope (rev 1, conservative)

Rev 1 ships **first-order, finite-depth ADTs only**. Specifically:

  In scope:
    - User-declared `data T {α …} | C₁ : … | … | Cₙ : …` with each ctor
      having a fixed (compile-time-known) number of value fields.
    - Constructor application `(C arg₁ … argₖ)` where each `argᵢ` is
      either an Int, a Bool, or another ctor application of bounded
      depth (configurable, default 8). The depth bound is the
      defunctionalization unfold limit.
    - `match` (`expr-reduce`) with N arms (any N ≥ 1), where each arm
      binds the constructor's value fields with `binding-count` bvars.
    - First-class scrutinee returned from a function call IF that
      function's return value is finite-depth-statically-known
      (currently: only constant-folded literal returns; tail-rec
      iteration whose accumulator type is an ADT is **out of scope**).

  Out of scope (deferred to rev 2 / Gate 2):
    - Recursive, unbounded-depth ADTs (e.g. `List` of unknown length
      computed at runtime). These need a heap; rev 2.
    - Returning ADTs from recursive functions whose recursion isn't
      tail (covered by Gate 2 / PReduce).
    - Higher-order constructors (a ctor with a function-typed field).
      Covered by an eventual closure pass.

Rev 1 explicitly trades runtime flexibility for kernel simplicity:
**no kernel changes**, no GC, no heap allocator. Rev 2 (heap-allocated
ctor cells with a sidecar HAMT-backed payload store) is sketched in
§ 9 below.

## 3. AST shape we have to lower

From a probe (`/tmp/probe-maybe.prologos`):

```
data Maybe {A}
  none
  some : A

def main : Int := match (some Int 7)
  | none -> 0
  | some x -> x
```

elaborates to:

```
main = (expr-reduce
         (expr-app (expr-app (expr-fvar 'some) (expr-Int)) (expr-int 7))
         (list (expr-reduce-arm 'none 0 (expr-int 0))
               (expr-reduce-arm 'some 1 (expr-bvar 0)))
         #t)
```

Three things to notice:

  (a) **Constructors are fvars with no body** (`global-env-lookup-value
      'some` returns `#f`). They cannot be inlined. Today
      `try-inline-fvar-call` fails on them with "inlining depth limit"
      — a misleading symptom of the deeper "this is a ctor" issue.

  (b) **Type arguments are erased at runtime** but visible in the AST
      (the leading `(expr-Int)` to `some`). The ctor's value arity is
      what matters for cell allocation; type args contribute nothing.

  (c) **Multi-arm match** uses `expr-reduce-arm`, with `binding-count`
      saying how many value bvars the arm body sees. The binders refer
      to the ctor's value fields, in declaration order.

The ctor metadata we need is in `macros.rkt`'s `ctor-meta` registry:

```
(register-ctor! 'zero (ctor-meta 'Nat  '() '()      '()      0))
(register-ctor! 'suc  (ctor-meta 'Nat  '() (list 'Nat) (list #t) 1))
(register-ctor! 'true (ctor-meta 'Bool '() '()      '()      0))
...
```

Each user `data` declaration registers its ctors via `register-ctor!`
during elaboration. We can query `lookup-ctor` and `lookup-type-ctors`
from `macros.rkt`.

## 4. Defunctionalization plan (rev 1)

**Idea**: encode each ADT value as a **fixed-shape cell tuple**:

  - One **tag cell** holding the branch index (i64; 0 .. n_ctors - 1).
  - For each value field of each ctor of the type: one **field cell**
    of that field's type's domain.

The cell tuple's *shape* is determined entirely at compile time by the
type. Two values of the same ADT type share the same shape; only their
tag and field contents differ.

For `Maybe Int`:
  - tag cell      : Int domain, holds 0 (none) or 1 (some)
  - field cell #0 : Int domain, holds the `some` payload (undefined
                    when tag = 0)

For `Either Int Bool`:
  - tag cell      : Int domain, 0 (left) or 1 (right)
  - field cell #0 : Int domain (the Left payload)
  - field cell #1 : Int domain (the Right payload — Bool stored as i64)

For `List Int` (rev 1, finite-depth):
  - tag cell      : Int domain, 0 (nil) or 1 (cons)
  - field cell #0 : Int domain (the head; valid when tag = 1)
  - field cell #1 : a NESTED `List Int` cell tuple (recursive!)

For lists, the field-cell-#1 is itself a cell tuple of shape (tag, head,
tail). The nesting depth is bounded by the **defunctionalize unfold
limit** (default 8). When we unfold a literal `[1, 2, 3]` of type
`List Int`, we materialize:

```
list :=
  tag = 1, head = 1, tail =
    (tag = 1, head = 2, tail =
      (tag = 1, head = 3, tail =
        (tag = 0, head = ⊥, tail = ⊥)))
```

…as 4 nested 3-cell tuples = 12 cells. Shorter literals use fewer cells.
If the static literal exceeds the unfold limit we raise
`unsupported-construction` and the user falls back to the rev-2 heap
representation (which doesn't exist yet, so it's an error).

## 5. Construction lowering

`(expr-app (expr-app (expr-fvar 'C) ⟨type-args⟩) ⟨v₁⟩ … ⟨vₖ⟩)` where
`C` is a registered ctor with branch index `i` and arity `k` becomes:

```
;; in builder b, env env, expected ADT type T
(C v₁ … vₖ)  ⤳  
  let tag-cid    = emit-cell! b INT-DOMAIN-ID i in
  let field-cids = for each vⱼ: build vⱼ in env, get its top cell;
                   emit cell-decl-init / pad with ⊥ as needed
  in (vtree (tag-cid) (field-cids …))
```

The `vtree` representation generalizes pairs: the value is a Racket list
`(tag-cid field₁-cid field₂-cid …)` whose first element is always the
tag cell and remaining are field cells. We **already have vtrees** in
the lowering pipeline (Sprint F.3 added them for pairs); this just
extends them to N-ary tuples.

## 6. Match lowering

`(expr-reduce scrut arms _structural?)` where `arms` are
`(expr-reduce-arm cᵢ kᵢ bodyᵢ)` becomes:

  1. Build `scrut` to obtain the ADT vtree `vt = (tag-cid f₁ f₂ …)`.
  2. For each arm i:
     - Extend `env` by pushing `kᵢ` fresh bvars whose cells are the
       relevant field cells of `vt`. Field-binder mapping comes from
       the ctor metadata: for ctor `cᵢ` with arity `kᵢ`, bvars
       0..kᵢ-1 map to field cells `f_{first}`..`f_{first+kᵢ-1}` where
       `first` is the offset within the type's flat field layout.
     - Build `bodyᵢ` in this extended env to obtain `result-cidᵢ`.
  3. Tag-dispatch: build a ladder of (1,1) `kernel-int-eq-k` checks
     against the tag cell, feeding into nested `kernel-select`s. This
     is exactly the `build-nat-match` shape generalized to N arms.

For N = 2 arms this collapses to one `kernel-int-eq` + one
`kernel-select`, identical to today's `build-nat-match`.

For N arms, build a left-leaning chain:

```
sel(eq?(tag, 0), body₀, sel(eq?(tag, 1), body₁, ... sel(eq?(tag, N-2), body_{N-2}, body_{N-1})))
```

## 7. Field-cell layout

When we write `data Either {A B} | left : A | right : B`, the *flat
field layout* of the type is:

  Position 0  →  `left`'s field 0 (an `A`)
  Position 1  →  `right`'s field 0 (a `B`)

That is, ctors share a flat tuple; each ctor uses a contiguous slice.
This is the simplest scheme — it wastes cells (right-tagged values
have an unused position-0 cell), but with finite shapes it's only
O(sum-of-arities) wasted cells per value, which is fine.

The alternative, **union-shaped** layout where all ctors of arity k
share the same k slots, is more compact but requires per-ctor
"interpretation" of the same cells, and is harder to reason about
for cells that may flow to multiple ctors. **We pick flat layout for
rev 1.**

## 8. Acceptance suite (rev 1)

Six examples, all under `racket/prologos/examples/network/n9-sums/`:

  1. `maybe-some.prologos`     — `match (some 7) | none -> 0 | some x -> x` → 7
  2. `maybe-none.prologos`     — `match (none) | none -> 0 | some x -> x` → 0
  3. `either-left.prologos`    — `match (left 42) | left x -> x | right _ -> 0` → 42
  4. `either-right.prologos`   — `match (right 7) | left _ -> 0 | right x -> x` → 7
  5. `list-sum-3.prologos`     — sum of literal `[1, 2, 3]` (defunctionalize-unfold the `cons` chain, sum manually) → 6
  6. `nested-maybe.prologos`   — `match (some (some 5)) | none -> 0 | some inner -> match inner | none -> 1 | some x -> x` → 5

If all six pass via `tools/round-trip-acceptance.rkt` AND end-to-end
via `tools/pnet-compile.rkt → ./binary`, Gate 1 is met.

The suite **deliberately excludes**:
  - Recursive functions on lists (covered by Gate 2)
  - Unbounded list literals (rev 2)
  - Higher-order ctors (future)

## 9. Rev 2 sketch — heap-backed ctors (deferred)

For unbounded-depth ADTs we need a runtime heap:

  Kernel additions:
    - `prologos_ctor_alloc(branch_idx, n_fields, ...) → handle: u32`
    - `prologos_ctor_tag(handle) → branch_idx: i64`
    - `prologos_ctor_field(handle, i) → cell_id: u32`
    - Sidecar HAMT-backed payload store (matches the existing
      `runtime/prologos-hamt.zig` infrastructure).

  GC: the kernel keeps payload store entries alive as long as they're
  referenced by a live cell; full GC is a follow-up. For closed,
  finite programs the heap can simply grow (it's bounded by program
  termination).

  Lowering: ctor application emits `prologos_ctor_alloc`; `match`
  emits `prologos_ctor_tag` + `prologos_ctor_field` calls.

This is purely additive over rev 1 — the IR ctor / case nodes
introduced in rev 1 stay; only their lowering target changes from
"flat cell tuple" to "heap handle".

Rev 2 is **not** scoped into this Gate 1 implementation. It's
documented here so the rev-1 IR doesn't paint us into a corner.

## 10. Implementation phases (this gate)

  Phase 1: Author the n9-sums acceptance suite + add it to round-trip
           acceptance + verify all 6 fail with the expected error.
  Phase 2: Teach `ast-to-low-pnet` to recognize ctors via
           `lookup-ctor`. Extend `expr-app` dispatch: if the head is
           an ctor, lower as construction; if it's a function, fall
           through to existing logic.
  Phase 3: Implement `build-ctor-application` with vtree output
           (defunctionalized).
  Phase 4: Generalize `expr-reduce` arm dispatch to N arms, using ctor
           metadata to compute field-binder offsets.
  Phase 5: Validate: round-trip suite green, native binaries green,
           no regression in the 41 existing acceptance examples.

  No IR changes (no new node kinds). No kernel changes. No LLVM
  emitter changes (the existing `kernel-int-eq` / `kernel-select`
  fire-fns already cover the dispatch ladder).

  This is the rare gate where the *kernel* is already sufficient —
  the work is entirely in the lowering pass.

## 11. Risk register

  R1 — vtree explosion. A `List Int` of length L unfolds to ~3L
       cells. For L > 16 this could become measurable on the BSP
       scheduler. Mitigation: hard-cap unfold depth at 8 in rev 1,
       error out if exceeded, ship rev 2 if it bites.

  R2 — ctor type arg curry depth. `(some Int 7)` is `(expr-app (expr-
       app (expr-fvar 'some) (expr-Int)) (expr-int 7))` — two `app`
       layers. We need to peel through the type args, which are erased.
       Mitigation: a small helper `peel-ctor-args` that walks left,
       skipping type args (recognized as `(expr-Int)`, `(expr-Bool)`,
       `(expr-Type _)`, etc.) until the head fvar is found.

  R3 — field type heterogeneity. `Either Int Bool` mixes Int and Bool
       fields. We currently only have INT-DOMAIN-ID and BOOL-DOMAIN-ID
       cells; both are i64 under the hood. Mitigation: encode every
       field as INT-DOMAIN-ID (with #t→1, #f→0), preserving the i64
       marshaling that low-pnet-to-llvm and low-pnet-to-prop-network
       already use.

  R4 — interaction with existing 2-arm Bool/Nat code. Today
       `(expr-reduce scrut [arm-true; arm-false] _)` is special-cased
       at `build-select`. After rev 1, the new generic N-arm path
       would also handle these. Mitigation: detect Bool/Nat cases
       BEFORE the generic ctor path (preserving today's tighter
       dispatch via `kernel-select` directly without needing a tag
       cell).

## 12. What this gate does NOT do

  - It does NOT enable recursive functions on lists. `list-sum-3`
    works because we sum a *literal* `[1,2,3]` by unfolding at compile
    time and threading through `int-add`. A function like `defn sum
    [xs] reduce add zero xs` calling itself recursively will still
    hit the inlining-depth limit (Gate 2 territory).

  - It does NOT enable strings (Gate 3) or NAF (Gate 4).

  - It does NOT add a heap or GC (rev 2).

A clean Gate 1 unblocks Maybe/Either-style programs, which is enough
for many useful closed examples (decision procedures, lookup tables,
configuration-as-data). Combined with Gate 2 it unblocks list-and-
recursion programs.
