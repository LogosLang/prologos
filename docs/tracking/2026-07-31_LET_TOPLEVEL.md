# LET — TOP-LEVEL SCOPE

**Status**: ✅ COMPLETE 2026-07-31 · **Branch** `focused-morse-3454bf` (not pushed) ·
**Gate**: full suite **9637 / 477 / 0**; 9 acceptance files **317/317**

## The ruling (owner, 2026-07-31)

> "The scope of a top-level `let` ceases at the beginning of the next toplevel
> form. It's really only intended for interactive use. A program with a toplevel
> let would be a bit odd, and wouldn't 'do' anything, but it shouldn't be an
> error or invalid, either, nor even a warning per se. The let also doesn't bind
> for the whole file, only the limited, local scope. The real use-case of a top
> level `let` is interactively building up some computation, then being able to
> wrap it in a `defn` afterwards as a form of iterative design."

## The use case, end to end

Verified in the real REPL (`make-repl-session` + `repl-eval!`), one
blank-line-terminated submission per step:

```
let a := 4              defn twice-sum [a:Int b:Int] : Int
let b := 5      ─────▶    let c := [+ a b]
let c := [+ a b]            [* c 2]
  [* c 2]
⇒ 18 : Int              ⇒ twice-sum : Int Int -> Int defined.  ⇒ [twice-sum 4 5] = 18
```

The left form and the `defn` body are the same text. That is the whole feature.

## What was actually wrong

The opening framing (mine) was that "top-level `let` is refused". **That was
wrong**, and the grounding refuted it: a top-level `let` **with a body** already
worked in all four spellings. Three separate defects were in play.

### D1 — the guard was not about top level (RETIRED)

`macros.rkt` raised ``"`let` is not allowed at top level. Use `def` instead."``
The condition was `(memq ':= rest)` ∧ `(symbol? (car rest))` ∧ *exactly one token
after the FIRST `:=`* — a self-described "simple heuristic" that never consults
position, and could not: `expand-let` has no way to know where it is. Consequences:

- **It fired on a NESTED bodyless let**, naming a location the form is not in and
  prescribing `def`, which is not legal inside a `defn` body. A lying diagnostic.
- **Its stated premise was false** — the comment claimed "top-level let has no
  body because there's no enclosing scope"; top-level lets with bodies worked.
- **It covered ONE of six bodyless spellings**, so the rest slipped past it.

### D2 — two SILENT WRONG ANSWERS (fixed)

`let x:Int 5` and `let y <Int> 5` (bodyless) printed `5 : Int` with **zero
errors**, having bound the name to the *annotation* and evaluated the value as
the body. The annotation was silently discarded.

The pin for this is deliberately not "does it print 5" — it printed 5 before.
It is `let b1:Int "hi"` **must reject**, which it now does.

### D3 — a second WHOLE-FILE ABORT (fixed)

Distinct from the `classify-let-block` one fixed in `53251a80`.
`normalize-let-binding-group` raises `let-syntax-error` (`macros.rkt:2437`,
`:2445`), reached from `merge-sibling-lets` → `merge-let-sequence` →
`split-last-let`'s `$let-block` arm — which runs in `preparse-expand-subforms`,
**outside** `expand-let`'s `with-handlers`. A raw Racket exception escaped and
the file produced **zero results**.

The family's marker-channel note asserted the opposite, as a parenthetical:

> "…and all 13 are beneath expand-let's dynamic extent (verified —
> merge-sibling-lets and its helpers raise nowhere)."

**Both halves false.** There are **20** `let-syntax-error` call sites, and two of
them are in a `merge-sibling-lets` helper that does raise. A `(verified)` in a
comment is an assertion, not evidence — this one shipped a defect behind the word.

## Why the sibling chain never merged

`merge-sibling-lets` (`macros.rkt:2256`) *already* handled the shape — its own
comment shows `let x := 10 / let y := add x x / y`. But its sole production call
is from `preparse-expand-subforms` (`:2635`): it merges lets that are **children
of an enclosing form**. Top-level forms are children of nothing, so it never ran
there. That is why nested chains worked and top-level ones did not.

## The realization

| Piece | Where | What |
|---|---|---|
| Bodyless is legal | `expand-let-impl` | the refusal is gone; `let-bodyless?` decides and a `$let-noop-body` placeholder fills the body slot, so each branch slices unchanged |
| The no-op's meaning | `let-bindings->nested-fn` | the placeholder resolves to the **last bound name**, so `let x := 5` ⇒ `((fn (x : T) x) 5)` — value type-checked, scope ends with the form, nothing leaks, echoes the value |
| Spelling coverage | `let-bodyless?` | +2 arms (angle-typed, bracket) — now **the** bodyless test for the family, which is what closes D2 for good |
| One funnel, actually | Branches 3 + 3f | these two built `((fn …) …)` by hand, bypassing the funnel — the reason the placeholder leaked to users as an unbound `$let-noop-body` until they were routed through it |
| Top-level merge | `merge-toplevel-sibling-lets`, called from `preparse-expand-all` | folds a run of consecutive top-level lets into one form |
| Containment | `merge-sibling-lets` | the family's **second** error boundary + a precise per-run handler |

### Two things the merge deliberately does NOT do

**It never absorbs a FOLLOWING form as the body** — unlike the subform-level
merge. Two reasons, and the first is the ruling: in

```
let p := 1
let q := 2
[+ p q]          ;; column 0 — the NEXT top-level form
```

`p` and `q` are correctly out of scope and line 3 errors. Second, the following
form may be a `def`/`defn`/`data`, which is not an expression and must never be
swallowed. Test-pinned.

**It is eq?-preserving when nothing merges.** Round-tripping every top-level form
through `datum->syntax` would drop `'prologos-paren-origin` /
`'prologos-defrhs-command` and silently break POL.9b (`def x := (goal …)` ≡
`:= solve (…)`) — the very property the SolveCarrier P2 sentinel rests on.
Test-pinned.

### The error boundary is two-layer, on purpose

- **Per-run** (the `[else]` arm of `merge-sibling-lets`): collapses a failing run
  to a single `($let-error msg)` form. This is what makes the MESSAGE good —
  returning the run unmerged instead leaves a multi-body `defn`, whose own arity
  error then *masks* the let message the user needed.
- **Outer** (`merge-sibling-lets`'s entry): the containment INVARIANT — no
  let-syntax raise escapes, ever. Not a duplicate of the inner one; the inner
  shapes the result, this one guarantees there is a result. It exists because the
  family's other boundary asserted exactly this invariant as "(verified)" while
  it was false, and the cost was a whole-file abort.

## The one design choice

A bodyless `let` **echoes its bound value** (`let x := 5` ⇒ `5 : Int`), because
the desugaring makes the bound name the body. The alternative was a Unit-valued
no-op printing nothing. Showing the value is more use at a prompt and costs no
machinery — but it is a choice, not a consequence, and it is the one thing here
worth revisiting if it reads wrong in practice.

## Superseded tests

Four pins asserted the retired behaviour and were updated in place, each with a
note saying what superseded it and what property survived:
`test-let-blocks.rkt` (3 cases) and `test-let-multiline-ws.rkt` (1). In every
case the CONTAINMENT property the case was written for is unchanged and still
pinned; only the "this is an error" half moved.

## Files

- `racket/prologos/macros.rkt` — the refusal, `let-bodyless?`, the funnel, both boundaries, the top-level merge
- `racket/prologos/parse-reader.rkt` — (D3's sibling, fixed earlier at `53251a80`)
- `racket/prologos/examples/2026-07-31-let-toplevel.prologos` — acceptance, 21/21
- `racket/prologos/tests/test-let-blocks.rkt` — +6 pins, 4 superseded pins updated
- `racket/prologos/tests/test-let-multiline-ws.rkt` — 1 superseded pin updated
