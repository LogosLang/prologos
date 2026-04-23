# EigenTrust in Prologos — Surprising Language Gotchas

_Session: 2026-04-23. Implementing the EigenTrust reputation algorithm
(Kamvar-Schlosser-Garcia-Molina 2003) exposed several Prologos
language/elaboration behaviors that felt like they should have worked
but did not. These notes are for future readers who hit the same walls,
and as potential backlog items._

## 1. Primitive operators are not first-class values in `zip-with` / `map`

**Expected:**
```prologos
[zip-with rat+ xs ys]          ;; elementwise add — looks obvious
[map rat-abs xs]               ;; elementwise abs — looks obvious
```

**Actual:** `Unbound variable rat+`, `Multiplicity violation` in the
elaborator. `rat+` (and its siblings `rat*`, `rat-`, `rat-abs`,
`int+`, `int*`, …) are preparser keywords backed by `expr-rat-add`-style
AST structs, not regular functions. They are only legal in call
position with the right arity; they cannot be bound to a variable,
stored in a data structure, or passed to a higher-order combinator.

**Notable asymmetry:** `[foldr int+ 0 '[1 2 3 4 5]]` **does** work (used
in `2026-04-17-ppn-track4c-adversarial.prologos` and
`2026-03-25-track10b.prologos`). So `foldr` somehow accepts these
tokens even though `zip-with` and `map` do not. Either `foldr` has a
special-case in the preparser or the test coverage gap is larger than
we think.

**Workaround:** explicit recursion or a named `fn` wrapper —
```prologos
spec add-vec [List Rat] [List Rat] -> [List Rat]
defn add-vec [xs ys]
  match xs
    | nil       -> nil
    | cons x as -> match ys
      | nil       -> nil
      | cons y bs -> cons [rat+ x y] [add-vec as bs]
```

**Suggested fix:** make every `expr-*-add`/etc. elaborate into a
concrete lambda when used in non-application position, or at least
surface a consistent "not first-class" error across all call sites.

## 2. Closure capture in `map` triggers QTT multiplicity violations

**Expected:**
```prologos
spec scale-vec Rat [List Rat] -> [List Rat]
defn scale-vec [s xs]
  [map (fn [x : Rat] [rat* s x]) xs]
```

**Actual:** QTT multiplicity error — `s` is being captured at
multiplicity 1 (linear) but used once per element of `xs`. The
elaborator does not auto-infer an unrestricted multiplicity for the
closure argument.

**Workaround:** explicit recursion that threads `s` through directly.
Same pattern as workaround #1.

**Suggested fix:** default captured type variables to `mw` when the
closure is the argument to a generic combinator whose spec is
polymorphic in multiplicity. Documented hint in CLAUDE.md
("Dict params use mw not m0") already covers dict params — extend the
same logic to ordinary closures.

## 3. `0/1` and `1/1` inside nested list literals silently become `Int`

**Expected:**
```prologos
def C : [List [List Rat]]
  := '['[0/1 1/2 1/2] '[1/2 0/1 1/2] '[1/2 1/2 0/1]]
```

**Actual:** `Type mismatch [List [List Rat]] <could not infer>
'['[0 1/2 1/2] …]`. The WS reader (or a preparse pass) canonicalises
`0/1` → `0` and `1/1` → `1` *before* list-literal type inference,
so the outer `'[…]` sees a mix of `Int` and `Rat` tokens and picks
`Int` as the element type, against the outer type annotation.

**Workaround:** bind `def rz : Rat := 0/1` at top level and splice
the reference in:
```prologos
def rz : Rat := 0/1
def C : [List [List Rat]] := '['[rz 1/2 1/2] '[1/2 rz 1/2] '[1/2 1/2 rz]]
```

The reference is opaque to the simplifier, so the type stays `Rat`.

**Suggested fix:** preserve the `Rat` type of a literal when the
surrounding context (either annotation or enclosing list element
type) demands it. This is the mirror image of the "don't coerce
across number types" principle — here the parser is effectively
coercing `Rat → Int` silently.

## 4. Mutual recursion between top-level `defn`s is unsupported

**Expected:** two `defn`s that reference each other (a two-state
iterator with an advance/check split) elaborate like mutually
recursive functions in every other ML-family language.

**Actual:** forward references fail with `Unbound variable <name>`
for whichever of the pair comes first in the file. Noted as a known
issue in `examples/2026-03-16-track4-acceptance.prologos`:

> `;; BUG (L3): forward reference to odd? at file level — mutual
> recursion not supported.`

**Workaround:** collapse both functions into one, pass extra
arguments to avoid the cross-call. For EigenTrust I carry both
`t` (previous iterate) and `tnew` (current iterate) so each round
computes `eigentrust-step` exactly once without a second `defn`.

**Suggested fix:** a `defns` (plural) block or an inference pass
that gathers all mutually-referencing `defn`s in a module before
binding them.

## 5. `let` with a multi-line indented body confuses the WS reader

**Expected:**
```prologos
(let [tnew := [eigentrust-step c p alpha t]]
  match [rat-lt [linf-norm [sub-vec tnew t]] eps]
    | true  -> tnew
    | false -> [eigentrust-iterate c p alpha eps [int- budget 1] tnew])
```

**Actual:** `let: let with bracket bindings requires: (let [bindings…] body)`.
Working `let` examples in the codebase have either (a) the body on the
same physical line as `let ...]`, or (b) a very specific two-space
indentation with a pure expression body — nested `match` inside a
`let` body doesn't parse under WS.

**Workaround:** lift the `let` out into an extra parameter passed
through the recursive call (option #4 above).

**Suggested fix:** align the WS `let` parser with the usual
"continuation lines are indented further than `let`" rule that
`defn`/`match` already honour.

## 6. Multi-line `spec` with line-comments between tokens breaks

**Expected:**
```prologos
spec eigentrust-step
     [List [List Rat]]   ;; matrix C
     [List Rat]          ;; pre-trust p
     Rat                 ;; damping
     [List Rat]          ;; current t
     -> [List Rat]       ;; next t
defn eigentrust-step [c p alpha t] …
```

**Actual:** `spec: spec type for eigentrust-step has no arrow but defn
has 4 params`. The preparser's token-scan doesn't cross comment-end
lines consistently, so it sees only some of the continuation tokens
and thinks the spec is missing its `->`.

**Workaround:** collapse to one line.

**Suggested fix:** ignore line comments in spec-type scanning the same
way they are ignored elsewhere.

## 7. Multi-arity `defn | pat -> body | pat -> body` is single-argument only

**Expected:**
```prologos
defn sum-rows
  | nil            -> nil
  | cons r nil     -> r
  | cons r rest    -> [add-vec r [sum-rows rest]]
```

The three-clause form, with a literal `nil` in the second position of
the second clause, looks like a standard ML/Haskell pattern.

**Actual:** `Unbound variable sum-rows::1` — the compiler generates a
per-clause helper and then fails to resolve it. The issue might be the
nested literal pattern; it might also be that multi-clause `defn` only
works for single-argument cases (cf. `is-zero | zero -> true | suc _ ->
false`).

**Workaround:** nested `match` inside a `defn [args] body`.

**Suggested fix:** either support general pattern matrices in
multi-clause `defn`, or raise a clear error that says "multi-clause
defn accepts only a single argument pattern."

## 8. Exact-Rat arithmetic slows power iteration by many orders of magnitude

**Observation:** a 3×3 damped power iteration with `alpha = 1/10` and
40 steps did not terminate within 5 minutes; the same problem with 15
steps completed in ~2 minutes; switching to matrices that avoid `rz`
(no `0/1 → Int 0` workaround) cut the same 20-step workload to ~47
seconds.

The asymptotic cause is that each Rat multiplication can grow the
numerator and denominator by a small factor, so after *k* steps
denominators can reach ≈ (10 · max-matrix-denom)^k. The simplification
pass runs on every operation but doesn't prevent the growth when the
iterates don't share a common denominator.

**Consequence:** EigenTrust is great for correctness tests (exact
arithmetic means golden-output testing is trivial) but a poor fit for
deep-iteration benchmarks. A future `Float` / `Posit32` variant of the
same algorithm would let us benchmark at larger n and deeper iteration
counts.

## Summary of the implementation-shape constraints (List + Rat)

After all of the above, the List + Rat EigenTrust implementation obeys
these rules:
* Every vector/matrix helper is explicit structural recursion; no
  `map`, `zip-with`, or `foldr` over Rat lists.
* Every `fn` closure avoids capturing by inlining the captured value
  as a function argument.
* Every Rat constant that lives inside a nested `'[…]` literal is
  either a proper fraction like `1/2` or a top-level `def` of Rat
  type.
* Every `spec` fits on one line, with arrow and all argument types
  flush.
* Every iteration is one `defn` — the `(t, tnew)` pair trick avoids
  mutual recursion and the broken WS `let`.
* Benchmark matrices are small (3×3, 4×4) with modest iteration
  counts (≤ 15) so exact-Rat arithmetic stays tractable.


## Addendum (2026-04-23, same day): Posit32 and PVec variants

After the initial List+Rat version shipped, the user asked for Posit
variants and PVec variants to compare performance across
{List, PVec} × {Rat, Posit32}. That surfaced several more behaviors.

### 9. Posit32 literals survive nested list/PVec literals — `Rat` quirks do not apply

**Observation:** where `'[0/1 1/2]` fails (`0/1` reads as Int `0`) and
`@[0/1 1/2]` succeeds (PVec preserves Rat type), `'[~0.0 ~0.5]` and
`@[~0.0 ~0.5]` *both* preserve `Posit32`. The `~0.0` / `~1.0` literal
form does not have a bare-Int alias, so the preparser cannot silently
reinterpret it.

**Consequence:** the Posit variants can write matrices directly
without the `rz : Rat := 0/1` splice workaround. One less line of
ceremony.

### 10. PVec `@[...]` literals preserve element types where `'[...]` does not

**Observation:** `@[0/1 1/2]` elaborates as `PVec Rat` with `0/1`
stored as the Rat value whose numerator is 0. The List literal
`'[0/1 1/2]` silently coerces the same `0/1` to Int. Either a reader
difference or a type-propagation difference in elaboration; either
way the PVec path is more permissive.

**Consequence:** for Rat-typed matrices, PVec is more ergonomic than
List — no splice workaround is needed. For Posit-typed matrices both
containers are equally ergonomic.

### 11. Lazy argument reduction makes deep iteration scale as O(k²) for
    non-fixed-point iterates

**Observation:** `eigentrust-iterate` passes its recursive call the
expression `[eigentrust-step c p alpha tnew]` *unreduced* as the new
`tnew`. Each subsequent iteration forces reduction of the whole
argument chain. When every intermediate value differs bit-for-bit
(Posit32, or non-fixed-point Rat), the reducer redoes O(n) levels on
every iteration — total ~O(k²) terms expanded across k rounds — plus
whatever constant the pattern-match compiler adds on top.

Concretely:
- List+Rat, 10 iters on 4×4 uniform (starting *at* the fixed point
  where every step returns exactly the same Rat): ~36 s total (fine,
  because the term tree collapses to a single repeated value).
- List+Posit, 10 iters on the same workload (starting at the fixed
  point, but Posit32 step introduces tiny rounding so the tree does
  *not* collapse): does not terminate within 2 min.
- List+Posit, 5 iters on an asymmetric 3×3 matrix: does not terminate
  within 3 min.

**Workaround:** use converging workloads (eps > 0) where the iterator
exits after 1–2 rounds, or use exact-Rat fixed-point matrices where
every step returns the identical value. Deep iter-budget-driven
workloads blow up regardless of matrix size.

**Suggested fix:** force reduction of the `tnew` argument before the
recursive tail call — either via a primitive `seq`/`force` form, or
by making the reducer aggressively normalise `eigentrust-step` results
to `[posit32 bitpattern]` / `'[rat literals]` WHNF.

### 12. PVec indexing is Nat-only; Int indices and `from-int` don't bridge

**Observation:** `pvec-nth : PVec A → Nat → A`. There is no
`pvec-nth-int` (unlike `nth-int` for Lists). There is `from-nat :
Nat → Int` but no `from-int : Int → Nat`. So an algorithm that already
has Int counters (for `int-le budget 0` termination checks) has to
carry a second Nat counter in parallel when it wants to index a PVec.

**Workaround:** use `zero`/`suc i` Nat counters for PVec indexing and
keep `Int` only for the iteration budget. The PVec variants of this
algorithm do exactly this and it doubles the arity of every inner
helper (`-go` functions now take both `i : Nat` and `n : Nat`).

**Suggested fix:** add `pvec-nth-int`, `pvec-length-int`, and friends
— mirror the `nth-int` / `length-int` / `take-int` / `drop-int`
quartet that already exists for List.

### 13. Index-based recursion over PVec is forced because `pvec-map`
    and `pvec-fold` have the same closure-capture issue as `map`

**Observation:** every `pvec-map`/`pvec-fold` call that wants to
capture a scalar (e.g. `pvec-map (fn [x] [rat* s x]) v`) would hit
the QTT multiplicity issue from gotcha #2. Since there's no
`zip-with` equivalent for PVec (i.e. no `pvec-zip-with`), elementwise
operations on two PVecs must be written as explicit
index-threaded-accumulator recursion: `acc` grows via `pvec-push`,
inputs are read via `pvec-nth`.

**Consequence:** the PVec variants each have one extra `*-go`
function per primitive (scale-vec-go, add-vec-go, sub-vec-go,
linf-norm-go, col-dot-go, ct-times-vec-go) that the List variants
don't need. That's 6 extra top-level defns, roughly doubling the
file size.

**Suggested fix:** either fix closure multiplicity inference, add
a `pvec-zip-with` primitive, or both.

### 14. PVec does not print with the same syntax it reads

**Observation:** the reader accepts `@[1/4 1/4 1/4 1/4]` and the
type-checker reports the value as `(PVec Rat)` — but the output
pretty-printer writes `(PVec Rat)` in parens where the type signature
of a `spec` would say `[PVec Rat]`. Not a correctness issue, but a
cosmetic divergence between how types are *read* (`[...]`) and how
they're *printed* (`(...)`).

### 15. Multi-line `def X : T := body` silently suppresses evaluation of downstream top-level expressions

**Observation:** when a `def` with a type annotation is split across
two lines —
```prologos
def c-asym-3 : [List [List Rat]]
  := '['[rz 1/2 1/2] '[rz rz ro] '[ro rz rz]]
```
— subsequent top-level expressions in the file that depend on the
bound name appear to execute (they type-check, they return values) but
the reducer never fires. `PHASE-TIMINGS` reports `reduce_ms = 0`, and
the computed value is never printed to stdout by `driver.rkt`. The
same file with the def collapsed to one line —
```prologos
def c-asym-3 : [List [List Rat]] := '['[rz 1/2 1/2] '[rz rz ro] '[ro rz rz]]
```
— reduces normally (`reduce_ms = 38_855` for a 3-iter benchmark).

**How it was surfaced:** `bench-phases.rkt` reported `reduce_ms = 0`
for a benchmark file whose algorithm was clearly expensive. Running
the same expressions via `process-string-ws` (the test-support path)
reduced correctly. Diffing a working scratch file against the benchmark
file narrowed the trigger to the two-line `def` form, specifically the
form
```
def NAME : TYPE
  := BODY
```

**Consequence:** benchmarks that use multi-line `def`s for fixtures
silently measure zero reduce time, regardless of workload. This is
load-bearing for benchmark validity.

**Workaround:** collapse every `def NAME : TYPE := BODY` to one
physical line. All four EigenTrust benchmark files have been updated
accordingly; see the bench-phases numbers go from "~250 ms reduce_ms"
(silent bug) to "20–40 s reduce_ms" (real) after the change.

**Suggested fix:** either make the WS reader produce identical surf
trees for the one-line and two-line forms, OR have the
elaborator/preparser reject the broken form with a clear error. The
current failure mode (silent suppression of evaluation) is the worst
of both worlds.
