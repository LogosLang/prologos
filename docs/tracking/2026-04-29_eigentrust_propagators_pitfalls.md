# EigenTrust on Propagators — Pitfalls

_Track-specific landmines surfaced while implementing EigenTrust
directly on Prologos's propagator network infrastructure
(2026-04-29). For the surface-language pitfalls see
`2026-04-23_eigentrust_pitfalls.md`._

## 1. Fire-once + initial scheduling breaks chained propagators

**Expected:**
```racket
;; Chain: t_0 → step-1 → t_1 → step-2 → t_2 → ... → t_K.
;; Use net-add-fire-once-propagator because each step fires exactly once.
(net-add-fire-once-propagator net inputs outputs fire-fn)
```

**Actual:** all K fire-once propagators get scheduled at install
time (since their inputs already have values — t_0 was pre-loaded
with p, the constants are pre-loaded), then BSP fires them ALL
in round 1 on the same initial snapshot. Only step-1's read of
its input (t_0) sees a useful value (p); step-2..step-K read their
input cells which are still at their initial value (zeros).
Each step writes `α·p` (the formula's other term) and that's the
final result — every iteration cell ends up holding `α·p`, not the
correct trajectory.

**Why fire-once doesn't compose with chains:** fire-once means
"fire AT MOST ONCE per propagator". Once a propagator fires in
round 1, it never fires again — even if its input cell changes
later via a chain-upstream write. A chain depends on
re-firing-on-input-change, which is what _plain_ propagators do.

**Fix:** use `net-add-propagator` (no fire-once flag). Plain
propagators re-fire on input changes. After the first BSP round
all step-k cells have wrong values, but only t_1 (= step-1's output
from a correct read of t_0) is useful. In round 2, step-2 sees
t_1's correct value and re-fires (its other inputs — M, p, α —
haven't changed but cell-change detection only needs ONE input to
have changed). After K BSP rounds the chain has fully settled.

**Suggested doc fix:** the propagator-design checklist in
`.claude/rules/propagator-design.md` already says
> "If the propagator writes a result and never needs to fire again
>  (narrower, contradiction detector, type-write, usage-write,
>  constraint-creation), use `net-add-fire-once-propagator`."

Add a counter-example: "If the propagator is part of a chain
where it must fire when an upstream sibling produces output, use
plain `net-add-propagator`. Fire-once + chain = wrong result on
the first round." Or, equivalently: "fire-once is for
single-direction writes from inputs that are SET BEFORE the
propagator is installed — not for chains where some upstream input
is written by another propagator after install."

**Diagnostic clue:** if a chained propagator network produces the
"residual term only" (in EigenTrust: `α·p` instead of
`(1-α)·M·t_K + α·p`), it's the fire-once-on-uninitialised-input
pattern.

## 2. Cell merge function semantics during initial-value reads vs writes

**Observation:** `net-new-cell net initial-value merge-fn` stores
`initial-value` directly. The merge function is invoked only on
subsequent `net-cell-write` calls (`new = merge-fn(old, new-from-write)`).
A propagator that reads a cell BEFORE any write sees the initial
value untransformed — `merge-fn` plays no role.

**Why this matters:** in the chain implementation, the trust-vector
cells `t_1, …, t_K` are initialised to a zero vector (placeholder)
and overwritten by their step propagator. The first write goes
through `merge-fn`, but with `initial = zeros` and `new = step-result`
the merge result must be `step-result` regardless of `initial`.
We use `(λ (old new) new)` (last-write-wins). If we'd used a
"pointwise max" or "set-union" merge on a value-typed cell, the
zero-vector initial would survive the first merge in some
positions and silently corrupt the iterate.

**Suggested practice:** for value-typed (non-monotone) cells, use
last-write-wins explicitly. Combined with plain (not fire-once)
propagators, this gives "the cell holds the latest computed value"
semantics — which is what most numerical iterations want.

## 3. Vector equality of inexact (float) values fails `equal?`

**Observation:** Racket's `equal?` on two `(vector 0.1 0.2 0.3)`
values is `#t` only if the byte-identical floats are stored. After
arithmetic (e.g. `(+ 0.1 0.2)` vs `(+ 0.2 0.1)` — which can produce
different bit patterns due to non-commutative round-off) `equal?`
returns `#f` even though the values are mathematically equal.

**Consequence for tests:** rackunit's `check-equal?` against an
expected float vector is brittle. Use `check-=` with an explicit
tolerance, or compare each component within an epsilon, or check
properties (mass-preservation, magnitude bounds) rather than exact
equality.

**Workaround in this work:** the float variant's tests check that
the result is within ε of the exact-rational result. We compute
the rational version (which has `equal?`-stable output) and then
verify `|float-result[i] - rational-result[i]| < eps` for each i.

## 4. `for/sum` over an empty vector returns 0 (an exact integer), not 0.0

**Observation:** `(for/sum ([x (in-vector (vector))]) x)` returns
`0`, the exact integer. When the rest of the algorithm expects
flonums, this propagates an exact 0 through subsequent arithmetic.
Mixed exact/inexact arithmetic in Racket promotes to inexact, so
correctness is preserved, but type predicates like `flonum?` or
`(real? x)` checks may give surprising answers.

**Workaround:** seed `for/sum` with `0.0` explicitly:
```racket
(for/sum ([x (in-vector v)] #:when #t) x)  ;; 0 for empty
;; vs
(for/fold ([acc 0.0]) ([x (in-vector v)]) (+ acc x))  ;; 0.0 for empty
```

This is a Racket library hiccup (not a Prologos one), but it bites
when constructing the initial accumulator for a flonum dot product
on an empty vector — though for non-empty matrices we never hit
the empty case.

## 5. Fine-grained per-peer variant: cell-id arrays vs lookup overhead

**Observation:** the fine-grained variant allocates `K·n` cells
(one per peer per iteration) plus 4 constant cells. For W3
(K=4, n=4) that's 20 cells. Each fire function reads n+3 inputs
(`t_{k-1, 0..n-1}`, `M[i,:]` constant, `p[i]`, `alpha`).

**Naive implementation pitfall:** if you store cell-ids in a list
and `list-ref` in the fire function, you pay O(n) lookup per access
times O(n) access count = O(n²) per fire. For small n this is
swamped by `net-cell-read` costs but at scale it matters.

**Workaround:** store cell-ids in a vector of vectors
(`(vector-ref (vector-ref t-cids k) i)`) for O(1) access. Closures
capture the vector once at install time.

**Bonus:** the per-peer variant is more "on-network" (each peer's
trust is its own cell) but also has higher constant overhead. For
small n (≤ 4) the coarse variant is faster; for larger n the
fine-grained version's parallel-fire potential MIGHT win, but at
the matrix sizes EigenTrust is typically benchmarked on (n ≤ 100),
the constant-factor overhead per cell ($cell-id allocation + CHAMP
insert + dependent registration) dominates.
