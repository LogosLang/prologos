# Collection Interface Unification — Stage 2/3 Design Document

**Date**: 2026-03-20
**Status**: Draft — awaiting critique
**Scope**: Close the gap between collection trait abstractions and compiler dispatch
**Prerequisite**: Collection traits (Seqable, Buildable, Foldable, Reducible, Indexed, Keyed, Setlike) exist and are instanced; generic-ops pipeline works; first-class path values landed
**Audit**: `docs/tracking/2026-03-20_COLLECTION_INTERFACE_AUDIT.md` (commit `e632dce`)
**Supersedes**: None (extends collection-traits + generic-ops infrastructure)

---

## Progress Tracker

| # | Phase | Description | Status | Commit | Notes |
|---|-------|-------------|--------|--------|-------|
| 0 | Acceptance file | Baseline canary + aspirational tests | ⬜ | | Extend existing first-class-paths acceptance |
| 1 | `ground-expr?` union fix | Add explicit `expr-union` case | ⬜ | | Immediate completeness fix |
| 2a | `expr-get` → Indexed dispatch | Elaboration-time: infer collection type, dispatch to `idx-nth` | ⬜ | | Core architectural change |
| 2b | `expr-get` → Keyed dispatch | Elaboration-time: `Map` key access through `kv-get` | ⬜ | | |
| 2c | `expr-get` typing unification | `infer` for `expr-get` uses trait-resolved types | ⬜ | | |
| 3 | Broadcast generalization | `.*field` works on PVec, Set, any Seqable | ⬜ | | |
| 4 | Dot-brace path expansion | `.{field1 field2}` reader syntax | ⬜ | | Reader + preparse |
| 5 | Union-aware trait dispatch | Trait methods resolve when all union members implement the trait | ⬜ | | Design-heavy; may defer |
| 6 | Open-map value typing | Design decision on unschema'd map access return type | ⬜ | | Design discussion |

---

## 1. Problem Statement

The collection trait system in Prologos is well-designed at the library level: `Seqable`, `Buildable`, `Foldable`, `Reducible`, `Indexed`, `Keyed`, and `Setlike` exist with instances for `List`, `PVec`, `Set`, and `Map`. Generic operations (`gmap`, `gfilter`, `gfold`, etc.) use the `Seqable → LSeq → Buildable` pipeline correctly.

However, the **compiler layer** bypasses these traits for all syntactic sugar operations:

- **Postfix indexing** (`xs[0]`): `surf-get` elaborates to `expr-get`, which pattern-matches on concrete constructors (`expr-champ`, `expr-rrb`, cons-chain) in `reduction.rkt` lines 2093–2122.
- **Dot-access** (`m.field`): Hardcoded to `expr-map-get`, which dispatches on `expr-champ` directly.
- **Broadcast** (`xs.*field`): `expr-broadcast-get` walks only cons/nil list structure (lines 3403–3449). PVec and Set produce stuck terms.
- **get-in / update-in**: Hardcoded to `expr-map-get` chains for navigation.

This creates a **two-tier system**: generic library functions work on any collection; syntactic sugar works only on specific concrete types. A user-defined type implementing `Indexed` gets `gfold` for free but NOT `xs[0]` — violating the Most Generalizable Interface principle.

### Root Cause: Phase Separation

Traits are compile-time constraints that generate dictionary parameters. The elaborator resolves `Indexed C` to a concrete dict and threads it as a lambda parameter. But `surf-get` elaborates directly to `expr-get` — an AST node that carries no dict and dispatches by constructor pattern-matching at runtime. The trait system is structurally disconnected from the syntactic sugar pipeline.

### What We Want

```prologos
;; Any type implementing Indexed gets postfix indexing
def xs := @[10 20 30]     ;; PVec
xs[0]                      ;; => 10 (via Indexed dispatch, not hardcoded expr-rrb)

;; Any Seqable gets broadcast
def scores := @[{:x 1} {:x 2} {:x 3}]   ;; PVec of Maps
scores.*x                  ;; => @[1 2 3] (not stuck)

;; Branching dot-access
def user := {:name "Alice" :age 30 :email "a@b.com"}
user.{name email}          ;; => {:name "Alice" :email "a@b.com"}

;; Schema-typed maps get precise field types
schema Point :x Int :y Int
def p : Point := {:x 0 :y 0}
p[0]                       ;; type error — Point is Keyed, not Indexed (correct)

;; Open-world maps: access is untyped (dynamic)
def m := {:a 1 :b "hello"}
m.a                        ;; => 1 : _ (dynamic, not union)
```

---

## 2. Gap Analysis

### What We Have

| Component | Status | Location |
|-----------|--------|----------|
| Trait definitions (Indexed, Keyed, Setlike, Seqable, etc.) | Complete | `lib/prologos/core/collection-traits.prologos` |
| Trait instances (List, PVec, Set, Map) | Complete | respective data modules |
| Generic ops pipeline (gmap, gfilter, gfold, etc.) | Complete | `lib/prologos/core/generic-ops.prologos` |
| Trait resolution + dict threading | Complete | `trait-resolution.rkt`, `elaborator.rkt` |
| `expr-get` AST node + typing | Complete (but hardcoded) | `syntax.rkt`, `typing-core.rkt` |
| `expr-broadcast-get` AST node | Complete (List-only) | 13-file pipeline |
| `get-in` / `update-in` with paths | Complete (Map-only) | elaborator + reduction |
| Schema narrowing for `map-get` | Complete | `typing-core.rkt` lines 1284–1296 |
| `ground-expr?` for union types | Missing `expr-union` case | `trait-resolution.rkt` line 82 |
| Dot-brace `.{...}` reader token | Missing entirely | `reader.rkt` |
| Union-aware trait resolution | Not implemented | `trait-resolution.rkt` |

### What's Missing

1. **Elaboration bridge**: `surf-get` → trait-dispatched call (instead of `expr-get`)
2. **Broadcast collection abstraction**: `to-seq` conversion before field extraction
3. **`.{...}` tokenization**: Reader does not recognize dot-brace
4. **Union trait dispatch**: `trait-resolution.rkt` has no `expr-union` handling
5. **Open-map typing policy**: Whether unschema'd maps return `_` or full union

---

## 3. Design Space (Evaluated Options)

### Option A: Elaboration-Time Trait Dispatch (Selected)

When `surf-get` is encountered, the elaborator:
1. Infers the collection type
2. If it implements `Indexed`, elaborates to `[idx-nth $dict coll key]`
3. If it implements `Keyed`, elaborates to `[kv-get $dict coll key]`
4. If type is unsolved meta, falls back to current `expr-get`

**Pros**: Zero runtime overhead — dict is resolved at compile time. Existing trait infrastructure does all the work. `expr-get` becomes a fallback for genuinely ambiguous cases only. New collection types implementing `Indexed` get postfix indexing for free.

**Cons**: Requires type information at elaboration time (available — `infer` already runs). Fallback to `expr-get` for unsolved metas means the old constructor-matching code stays as a safety net.

### Option B: Runtime Reified Dict Dispatch (Rejected)

Modify `expr-get` in reduction.rkt to look up and call trait dicts at runtime.

**Pros**: No elaboration changes.

**Cons**: Requires reifying trait dicts into runtime values (major architectural change). The trait system is compile-time — this would fundamentally alter its semantics. Performance overhead from runtime dict lookup on every index operation.

**Verdict**: Option A aligns with the existing trait architecture. Traits are compile-time; elaboration is where dispatch decisions belong.

### Option C: Broadcast via `gmap` Desugaring (Rejected)

Desugar `xs.*field` to `[gmap [fn [x] x.field] xs]`.

**Pros**: Minimal new code.

**Cons**: Inference fails — `gmap` with an untyped lambda `[fn [x] [map-get x :field]]` can't constrain `x`'s type. This was attempted during Phase 7b and abandoned in favor of the dedicated `expr-broadcast-get` node. The inference gap is fundamental: `map-get` doesn't generate type constraints on its first argument.

### Option D: Broadcast via Seqable Conversion (Selected)

In reduction, convert the target to a list via `Seqable.to-seq` (or directly match PVec/Set structure alongside cons/nil), then apply field extraction.

**Pros**: Straightforward. PVec and Set already implement `Seqable`. Can be done incrementally — add PVec/Set pattern-matching to the existing cons/nil walker in reduction.rkt.

**Cons**: Reduction-level approach (not elaboration-time). But broadcast is inherently a runtime operation — the target's length is dynamic, so reduction is the correct phase.

**Pragmatic approach**: In Phase 3, extend the reduction walker to recognize `expr-rrb` (PVec) and `expr-set` (Set) alongside cons/nil. This is simpler than threading a `Seqable` dict through broadcast. A future enhancement could use `to-seq` for user-defined Seqable types.

---

## 4. Detailed Design

### Phase 0: Acceptance File Extension

Extend `examples/2026-03-20-first-class-paths.prologos` with a new section `§I — Collection Interface Unification`:

```prologos
;; §I — COLLECTION INTERFACE UNIFICATION

;; I1: PVec indexing (already works via expr-get, but should use Indexed)
def pv := @[10 20 30]
pv[0]               ;; => 10
pv[2]               ;; => 30

;; I2: Broadcast on PVec (currently stuck — Phase 3 target)
;; def pv-maps := @[{:x 1} {:x 2} {:x 3}]
;; pv-maps.*x       ;; => @[1 2 3] or '[1 2 3]

;; I3: Dot-brace expansion (currently not tokenized — Phase 4 target)
;; def u := {:name "Alice" :age 30 :email "a@b.com"}
;; u.{name email}   ;; => {:name "Alice" :email "a@b.com"}
```

Run before and after each phase. Phase isn't done until acceptance section passes.

### Phase 1: `ground-expr?` Union Fix

**File**: `trait-resolution.rkt` line 82

**Change**: Add explicit `expr-union` case before the conservative default:

```racket
[(expr-union l r) (and (ground-expr? l) (ground-expr? r))]
```

Currently falls to `[_ #t]` — happens to be correct (conservative) but fragile. The explicit case is correct and makes the function self-documenting.

**Verification**: Run full test suite. No behavioral change expected (conservative default already returned `#t`).

### Phase 2: `expr-get` via Trait Dispatch

This is the core architectural change. It has three sub-phases.

#### Phase 2a: `surf-get` → Indexed Dispatch

**File**: `elaborator.rkt` (lines ~1801–1806)

**Current behavior**:
```racket
[(surf-get coll key loc)
 (let ([ec (elaborate coll env depth)]
       [ek (elaborate key env depth)])
   (cond [(prologos-error? ec) ec]
         [(prologos-error? ek) ek]
         [else (expr-get ec ek)]))]
```

**New behavior**:
```racket
[(surf-get coll key loc)
 (let ([ec (elaborate coll env depth)]
       [ek (elaborate key env depth)])
   (cond
     [(prologos-error? ec) ec]
     [(prologos-error? ek) ek]
     [else
      ;; Try to resolve collection type for trait dispatch
      (define coll-ty (whnf (infer ctx-current ec)))
      (cond
        ;; Schema/Selection — delegate to map-get (schema narrowing)
        [(and (expr-fvar? coll-ty)
              (or (lookup-schema-by-name (expr-fvar-name coll-ty))
                  (lookup-selection-by-name (expr-fvar-name coll-ty))))
         (expr-map-get ec ek)]
        ;; Map K V — use kv-get through Keyed trait
        ;; (Phase 2b — for now, delegate to expr-map-get)
        [(expr-Map? coll-ty)
         (expr-map-get ec ek)]
        ;; Fallback: expr-get (constructor dispatch in reduction)
        [else (expr-get ec ek)])]))]
```

Phase 2a adds the dispatch skeleton without changing behavior — every branch produces the same result as today. This validates the type-inference + dispatch structure.

**Key insight**: We infer the collection type at elaboration time. This is already available — `infer` runs during elaboration. The question is whether the type is solved at this point. For concrete collections (`'[1 2 3]`, `@[1 2 3]`), it is. For polymorphic parameters, it may be an unsolved meta — the `expr-get` fallback handles this.

#### Phase 2b: Map Access via Keyed

Once Phase 2a validates the dispatch skeleton, change the `Map` branch:

```racket
;; Map K V — use Keyed.kv-get
;; kv-get : {K V} -> (Keyed Map) -> Map K V -> K -> Option V
;; For backward compatibility, unwrap the Option (maps currently return V, not Option V)
[(expr-Map? coll-ty)
 ;; For now, keep expr-map-get — schema narrowing depends on it
 ;; Phase 2b focuses on ensuring the dispatch point exists;
 ;; full Keyed delegation requires Option-unwrapping wrapper
 (expr-map-get ec ek)]
```

**Design tension**: The current `expr-map-get` returns `V` directly. The `Keyed` trait's `kv-get` returns `Option V`. This is a semantic difference — `map-get` on a missing key currently errors at reduction; `kv-get` returns `none`. We should NOT change the behavior of `m.field` or `m[key]` to return `Option` without careful design discussion.

**Decision**: Phase 2b keeps `expr-map-get` for maps. The Keyed trait dispatch is available for explicit `[kv-get dict m :key]` calls. The syntactic sugar `m.field` and `m[key]` continue to return `V` directly (not wrapped in `Option`), preserving backward compatibility and schema narrowing.

**Future**: When we want `m[key]` to return `Option V` (safer semantics), that's a separate design decision affecting every map-access site in the language.

#### Phase 2c: Typing Unification

**File**: `typing-core.rkt` (lines ~1238–1259)

Currently, `expr-get` typing hardcodes `PVec A`, `Map K V`, `List A`, Schema, Selection. If Phase 2a dispatches some cases to `idx-nth` or `kv-get`, the typing for those calls goes through the normal trait-method typing path (already implemented).

The `expr-get` typing case narrows to handle only the fallback cases where elaboration couldn't resolve the type:

```racket
[(expr-get coll key)
 ;; This case now only fires for:
 ;; 1. Unsolved meta collection types (elaboration couldn't resolve)
 ;; 2. Backward compatibility with pre-Phase 2 elaborated code
 (let ([tc (whnf (infer ctx coll))])
   (match tc
     ;; PVec A → Int/Nat → A
     [(expr-PVec a)
      (if (or (check ctx key (expr-Nat)) (check ctx key (expr-Int))) a (expr-error))]
     ;; Map K V → K → V
     [(expr-Map kt vt)
      (if (check ctx key kt) vt (expr-error))]
     ;; Schema/Selection — delegate to map-get
     [(expr-fvar name)
      #:when (or (lookup-schema-by-name name) (lookup-selection-by-name name))
      (infer ctx (expr-map-get coll key))]
     ;; List A → Int/Nat → A
     [(expr-app f a)
      #:when (equal? f (list-type-fvar))
      (if (or (check ctx key (expr-Nat)) (check ctx key (expr-Int))) a (expr-error))]
     ;; Union type → try resolving each branch
     [(expr-union l r)
      ;; If both branches support indexing, return the union of result types
      (let ([tl (infer-get-result l key ctx)]
            [tr (infer-get-result r key ctx)])
        (if (and (not (expr-error? tl)) (not (expr-error? tr)))
            (build-union-type (list tl tr))
            (expr-error)))]
     [_ (expr-error)]))]
```

The `expr-union` case in typing is a stepping stone toward Phase 5 (union-aware trait dispatch). It addresses the `movie.genres[0]` issue: when `map-get` returns a union type, postfix indexing should still work if the union members all support it.

### Phase 3: Broadcast Generalization

**File**: `reduction.rkt` (lines 3403–3449)

**Current**: `expr-broadcast-get` walks only cons/nil structure via `list-nil?` and `list-cons?` helpers.

**New**: Add `expr-rrb` (PVec) and `expr-set` (Set) recognition alongside the existing list walker:

```racket
[(expr-broadcast-get target fields)
 (define nt (nf target))
 (define (extract-field elem fields)
   (foldl (lambda (fld acc) (nf (expr-map-get acc fld))) elem fields))

 ;; Existing list walkers (unchanged)
 (define (list-nil? e) ...)
 (define (list-cons? e) ...)

 ;; NEW: PVec → convert to list, then walk
 (define (pvec->list-elements e)
   (and (expr-rrb? e)
        (let ([r (expr-rrb-rrb e)])
          (for/list ([i (in-range (rrb-count r))])
            (rrb-get r i)))))

 ;; NEW: Set → convert to list, then walk
 (define (set->list-elements e)
   (and (expr-set? e)
        (hash-set-values (expr-set-hs e))))

 (cond
   ;; PVec: extract elements, map, rebuild as list
   [(pvec->list-elements nt)
    => (lambda (elems)
         (define results (map (lambda (e) (extract-field (nf e) fields)) elems))
         (foldr (lambda (x acc) (expr-app (expr-app (expr-fvar 'cons) x) acc))
                (expr-fvar 'nil) results))]
   ;; Set: extract elements, map, rebuild as list
   [(set->list-elements nt)
    => (lambda (elems)
         (define results (map (lambda (e) (extract-field (nf e) fields)) elems))
         (foldr (lambda (x acc) (expr-app (expr-app (expr-fvar 'cons) x) acc))
                (expr-fvar 'nil) results))]
   ;; List: existing cons/nil walker
   [else (map-over nt)])]
```

**Return type question**: When broadcasting over a PVec, should the result be a PVec or a List? For now, return a List (consistent with current behavior where broadcast returns cons-chain). A future enhancement could use `Buildable.from-seq` to preserve the input collection type.

**Typing**: `expr-broadcast-get` already returns a fresh meta. No typing changes needed — the meta unifies with the actual result type during type checking.

### Phase 4: Dot-Brace Path Expansion

**Goal**: `m.{name age}` as syntactic sugar for branching `get-in`.

#### WS Impact

1. **Reader** (`reader.rkt`): New token type `dot-lbrace` for `.{` (no space between dot and brace). The reader must distinguish:
   - `m.{name age}` → `dot-lbrace` token (branching access)
   - `m .{name age}` → separate `dot` + `lbrace` tokens (not dot-brace)
   - `{:a 1}` → `lbrace` token (map literal, no preceding dot)

2. **Preparse** (`macros.rkt`): `$dot-lbrace` sentinel rewrites to `(get-in target :name :age)` — reuses existing branching `get-in` path syntax. Key renaming (`^`) inside braces works naturally because `validate-selection-paths` already handles `^`.

3. **No new AST node**: Dot-brace desugars entirely at preparse level to existing `get-in` + keyword path syntax. No parser/elaborator/typing changes.

4. **Keyword/delimiter conflicts**: `.{` uses `{` which is the map literal delimiter. The reader distinguishes by requiring no space after `.` — same convention as `.*` (broadcast). The reader is already position-aware for dot-token handling.

#### Reader Changes

```racket
;; In the dot-token handler:
;; After recognizing '.' followed by an identifier (dot-access),
;; add a check for '.' followed by '{' (dot-lbrace)
(define (read-dot-token ...)
  (cond
    [(char=? next #\{)
     ;; .{ — branching dot-access
     ;; Read field names until }
     ;; Emit: $dot-lbrace sentinel with fields
     ...]
    [(char=? next #\*)
     ;; .* — broadcast access (existing)
     ...]
    [else
     ;; .ident — simple dot-access (existing)
     ...]))
```

#### Preparse Rewriting

In `rewrite-dot-access` or a companion function:

```
$dot-lbrace target field1 field2 ...
→ (get-in target :field1 :field2 ...)
```

This is the same expansion that `[get-in m :name :age]` already does — branching multi-path access returning a sub-map.

**With renaming**: `m.{name^n age^a}` → `(get-in m :name^n :age^a)` — works because `validate-selection-paths` already splits on `^`.

### Phase 5: Union-Aware Trait Dispatch

**Goal**: When `x : <Int | String>` and both `Int` and `String` implement trait `T`, then `[t-method x]` resolves.

This is the most architecturally significant phase. Current trait resolution (`trait-resolution.rkt`) has no mechanism for union types.

#### Design

When `resolve-trait-constraints!` encounters a constraint like `Show <Int | String>`:

1. Decompose the union into its members: `Int`, `String`
2. Check if ALL members have an impl for the trait
3. If yes, generate a **dispatch wrapper** that pattern-matches on the runtime value:
   ```racket
   ;; Generated: Show <Int | String> dict
   (lambda [x]
     (match x
       [(? int?) (show-Int-dict x)]
       [(? string?) (show-String-dict x)]))
   ```
4. If any member lacks an impl, the constraint fails (as today)

**Design concern**: This generates runtime dispatch code from compile-time type information. The trait system is currently pure compile-time (elaboration resolves all dicts). Introducing runtime dispatch for union types is a qualitative change.

**Pragmatic scoping**: For Phase 5, limit union-aware dispatch to the `expr-get` typing case (Phase 2c) — when a union-typed collection is indexed, try each branch. Full union-aware trait dispatch (arbitrary traits on union types) is a larger design decision and may be deferred.

### Phase 6: Open-Map Value Typing

**Goal**: Decide the return type of `map-get` on an open-world (unschema'd) heterogeneous map.

This is a **design philosophy question**, not an implementation question.

#### Options

**Option A — Status quo (union)**: `{:a 1 :b "hello"}` has type `Map Keyword <Int | String>`. Accessing `:a` returns `<Int | String>`. Precise but requires narrowing/match to use the value.

**Option B — Dynamic (`_`)**: `{:a 1 :b "hello"}` has type `Map Keyword _`. Accessing any key returns `_` (dynamic/inferred). More usable but loses type safety for map values.

**Option C — Schema-first**: Keep union typing for unschema'd maps (precise, push users toward schemas for usability). Schema'd maps return precise per-field types (already implemented).

**Recommendation**: Option C (schema-first). The union type is correct — it accurately reflects that `:a` and `:b` have different value types. The usability gap is a feature: it nudges users toward `schema` declarations for maps they access heavily. The `schema` system already provides exact per-field narrowing. Open-world maps are for dynamic/exploratory code where type safety is less critical; schemas are for structured data where it matters.

This is a design discussion, not a code change.

---

## 5. Design Decisions

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| D1 | Dispatch phase for `expr-get` | Elaboration-time (Option A) | Traits are compile-time; elaboration is where dispatch belongs |
| D2 | `m.field` returns `V` or `Option V` | `V` (direct) | Backward compatibility; `Option` wrapping is a separate design choice |
| D3 | Broadcast return type | List (match current behavior) | PVec-preserving broadcast is a future enhancement via Buildable |
| D4 | Dot-brace implementation level | Reader + preparse (no new AST) | Desugars to existing `get-in` — no parser/elaborator changes needed |
| D5 | Union trait dispatch scope | Limited to `expr-get` typing (Phase 2c) | Full union dispatch is architecturally significant; scope to immediate need |
| D6 | Open-map value type | Schema-first (Option C) | Union is correct; schema provides usability; nudges toward structured data |
| D7 | `expr-get` fallback | Keep constructor-matching as fallback | Unsolved metas and backward compatibility require it |

---

## 6. Phase Dependencies

```
Phase 0 (acceptance) ← independent, do first
Phase 1 (ground-expr?) ← independent, small fix
Phase 2a (dispatch skeleton) ← depends on: nothing
Phase 2b (Keyed dispatch) ← depends on: 2a
Phase 2c (typing unification) ← depends on: 2a
Phase 3 (broadcast) ← independent of Phase 2 (different AST node)
Phase 4 (dot-brace) ← independent of Phases 2-3 (reader/preparse only)
Phase 5 (union dispatch) ← depends on: 2c
Phase 6 (open-map typing) ← design discussion, no code dependency
```

Parallelizable: Phases 1, 3, and 4 are independent and can proceed in any order.
Critical path: Phase 0 → 2a → 2b → 2c → 5.

---

## 7. Key Files

| File | Phases | Changes |
|------|--------|---------|
| `trait-resolution.rkt` | 1, 5 | `ground-expr?` union case; union-aware dispatch |
| `elaborator.rkt` | 2a, 2b | `surf-get` dispatch skeleton |
| `typing-core.rkt` | 2c | `expr-get` union branch in `infer` |
| `reduction.rkt` | 3 | PVec/Set recognition in `expr-broadcast-get` |
| `reader.rkt` | 4 | `dot-lbrace` token type |
| `macros.rkt` | 4 | `$dot-lbrace` sentinel → `get-in` rewriting |
| `examples/2026-03-20-first-class-paths.prologos` | 0, all | Acceptance file extension |

---

## 8. Test Strategy

### Per-Phase Testing

| Phase | Level 1 (sexp) | Level 2 (WS string) | Level 3 (WS file) |
|-------|----------------|---------------------|--------------------|
| 1 | Full suite (no behavioral change) | N/A | N/A |
| 2a | `expr-get` dispatch skeleton | `xs[0]` on List/PVec | Acceptance file §I |
| 2b | Map access through dispatch | `m.field` variants | Acceptance file §I |
| 2c | Union-typed indexing | `movie.genres[0]` | Acceptance file §U |
| 3 | PVec broadcast | `@[{:x 1}].*x` | Acceptance file §I, §U |
| 4 | N/A (preparse only) | `m.{name age}` | Acceptance file §I |
| 5 | Union trait resolution | `<Int\|String>` Show | Acceptance file §I |

### Regression Strategy

- Full test suite after each phase (7308+ tests)
- Acceptance file after each phase (0 errors baseline)
- Benchmark comparison after Phases 2a and 3 (these touch hot paths)

---

## 9. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Type inference at elaboration too slow for `surf-get` | Performance regression on index-heavy code | Profile; fallback to `expr-get` if inference returns unsolved meta |
| PVec broadcast changes result type expectations | Downstream code expects List from broadcast | Document; broadcast always returns List for now |
| Dot-brace conflicts with map literal syntax | Parser ambiguity | `.{` requires no space after dot; same convention as `.*` |
| Union dispatch generates runtime code from compile-time info | Architectural precedent | Scope to `expr-get` typing only; design review before generalizing |
| Schema narrowing breaks under trait dispatch | Type regression for schema-typed maps | Phase 2a preserves `expr-map-get` for Schema/Selection types |

---

## 10. Relationship to Principles

| Principle | Current Status | After Implementation |
|-----------|---------------|---------------------|
| Collections decoupled from backends (§Decomplection) | **VIOLATED** | Compliant — `xs[0]` dispatches through Indexed |
| Most Generalizable Interface | **VIOLATED** | Compliant — `get` uses widest applicable trait |
| Seq as Universal Hub (§Collection Conventions) | Partial | Improved — broadcast uses Seqable for PVec/Set |
| Traits over concrete types | **VIOLATED** | Compliant — syntactic sugar goes through traits |
| Open extension, closed verification | Partial | Compliant — new Indexed types get `[n]` syntax |

---

## 11. Deferred / Out of Scope

- **Full Keyed dispatch for `m.field`**: Currently `m.field` → `expr-map-get` for schema narrowing. Full `Keyed` dispatch (returning `Option V`) requires a design decision on whether dot-access semantics change.
- **Broadcast preserving collection type**: `@[...]*field` returns List, not PVec. Preserving the input type requires threading `Buildable` through broadcast — future enhancement.
- **User-defined Seqable in broadcast**: Phase 3 hardcodes PVec/Set recognition. User-defined `Seqable` types in broadcast requires `to-seq` at reduction time (needs reified trait dicts).
- **Lens/Optics layer**: Composable get/set pairs as a library on top of paths. Orthogonal to this track.
- **`get-in` on mixed-collection paths**: `get-in` navigating through alternating Maps and PVecs (e.g., `m.users[0].name`). Requires Indexed + Keyed dispatch at each path segment. Future enhancement building on Phase 2.
