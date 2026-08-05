# ARROW — `->` inside identifiers (glued-vs-spaced)

**Series/Track**: ARROW Track 1 · **Stage**: 3 (design) → 4 (implementation)
**Base**: `b429d038` (main, 2026-08-05). All coordinates below re-verified against
this commit — see [§7](#coords) for why that matters.
**Owner rulings**: recorded in [§3](#rulings), taken 2026-08-05.

Goal: let a Prologos identifier contain `->`, so `defn centigrade->fahrenheit`
works. Today it does not, and the failure is a reader-layer mis-lex.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P0 | Guard the `inject-spec-into-defn` whole-file abort | ✅ **SUBSUMED** | Already fixed on main by `ae26f5403` (general preparse-seam guard). Not our work. [§6](#p0) |
| P1 | `->`-bearing identifier recognizer + tokenizer battery | ✅ | Two loop arms, not a new recognizer — see [§5](#p1). Corpus A/B **0 diffs / 161 files**. `tests/test-arrow-identifiers.rkt` (10). |
| P2 | Same rule for `recognize-keyword` (owner ruling R1) | ✅ | Landed **with** P1: splitting them would have shipped the F1b.7g drift for one commit. [§5](#p2) |
| P1b | Guided error for half-glued `a-> b` / `foo->` (owner ruling R2) | ⬜ | Deferred out of P1: must not raise in the tokenizer (whole-file-abort class). [§5](#p1b) |
| P3 | Un-comment the 2026-03-18 acceptance block | ⬜ | Corpus A/B already done in P1. [§5](#p3) |
| X.close | Bench/doc-truth sweep, DEFERRED triage, PIR | ⬜ | Per the objective PIR gate |

---

<a id="problem"></a>
## 1. The problem, precisely

`defn c->f [c:Posit32] : Posit32` fails with `defn: expected ':', got >`.

The defect is a **mis-lex**, not a parse bug. `recognize-symbol`
(`parse-reader.rkt:264`) consumes `c`, then consumes `-` (which **is** in
`ident-continue?`), then halts at `>` (which is **not**). The tokenizer is
strict priority-order, first-match-wins, **positional, with no backtracking**,
so `recognize-arrow` — which anchors on `-` *at the scan position* — never gets
a chance, because that `-` has already been eaten.

Measured token stream:

```
"c->f"      →  symbol "c-"   · rangle ">"  · symbol "f"
"int->str"  →  symbol "int-" · rangle ">"  · symbol "str"
```

Two consequences worth stating separately:

1. The identifier is silently **truncated to `c-`** (confirmed end-to-end:
   `Unbound variable c-`).
2. The stray `rangle` is **not inert** — in `make-bracket-depth-rrb` a `rangle`
   outside mixfix unconditionally pops the frame stack, so `[int->str x]` has
   its `[` frame destroyed. Downstream errors can therefore appear far from the
   cause.

<a id="history"></a>
## 2. It never worked; only the error is new

Bisected over 661 commits (`d8485097`..`df6eefd8`), automated, one compile per
step. First "bad" commit: **`2a7cbe45`** (2026-07-02, *loud error surfacing*).
That commit did **not** break arrow names — it stopped the driver silently
discarding the parse error.

At `d8485097` (2026-06-01), measured:

| input | result |
|---|---|
| `defn cToF …` + call (control) | defined, evaluates — 0 errors |
| `defn c->f …` alone | **0 errors — and nothing defined** |
| `defn c->f …` + call | `ERROR: Unbound variable` |

So the pre-`2a7cbe45` behaviour was a **silent wrong answer**: a clean bill of
health for a file whose function does not exist. The current error is strictly
better. The underlying limitation is unchanged and is documented in-tree since
2026-03-18 (`examples/2026-03-18-track7-acceptance.prologos:887-891`, the
`int->str` block, commented out with a "rename to an arrow-free helper"
workaround).

<a id="rulings"></a>
## 3. Owner rulings (2026-08-05)

| # | Question | Ruling |
|---|---|---|
| R1 | Does `recognize-keyword` get the rule too (`:a->b`)? | **Yes.** Consistency; this is the exact function that drifted in F1b.7g. |
| R2 | What do `A-> B` and trailing `foo->` do? | **Guided error**, naming the spacing rule. Not silence, not a raw parse error. |
| R3 | `A->B` in type position becomes one identifier (unknown type) rather than an arrow | **Fine.** |

<a id="rule"></a>
## 4. The rule — corrected statement

⚠ **The rule is NOT "no surrounding whitespace".** That phrasing (used when
this was first proposed) is wrong and would have mis-described 275 live sites
in `lib/` + `examples/` alone: the prefix arrow-type form glues `->` to an
opening bracket — `[-> [List A] [Option A]]` (208 `[->`, 67 `(->`).

**The rule is: `->` continues an identifier iff it is flanked by
identifier characters on BOTH sides.**

Because the scanner is mid-token when it reaches the `-`, "glued" is decidable
by construction — whitespace would already have ended the token. **No new
token-adjacency substrate is required.** This is the one place the original
scoping was too pessimistic.

Coherence, measured over the 306-file corpus (strings and comments stripped):

- 6,051 `->` total · **5,547 fully spaced** · **0 right-glued in code** ·
  13 left-glued, **all inside string literals** in `foreign racket`
  declarations. `recognize-string` consumes the whole span, so string interiors
  are never re-tokenized — the `foreign` spelling is safe under any rule.
- **Zero code regressions.** Glued `->` is *already* broken everywhere today:
  `spec A->B`, `| p->b`, and `<Int->Bool>` all fail at HEAD.

⚠ **What the rule must NOT be**: adding `>` to `ident-continue?`. There are
1,444 `>` chars immediately preceded by an ident char, and **1,416 of them
close an angle group** (`<Int | String>`). Unconditional admission stops every
angle group in the tree from closing. The rule's `-`-before-`>` requirement is
what keeps `Bool>` untouched.

<a id="precedent"></a>
### 4.1 The precedent — also corrected

⚠ The originally-cited precedent (the LET track's fused `x:Int` vs spaced
`x : Int`) **does not exist as framed**: that distinction is *adjacency-blind*,
`[x :Int]` behaves identically to `[x:Int]`.

The real precedent is **`recognize-narrow-var-annot`** (`?x:Nat` glued into ONE
token, priority **96**), whose in-tree comment explicitly rejects a
parser-layer rejoin as unsound — contiguity is only decidable in the tokenizer.
Same conclusion, sound reason. Registration priorities at base:
`arrow` **98** · `narrow-var-annot` **96** · `symbol` **50** · `rangle` **25**.

<a id="phases"></a>
## 5. Phases

<a id="p1"></a>
### P1 — the recognizer ✅

**Settled: two loop arms, NOT a new recognizer.** The design left this open
between a new high-priority recognizer (the `narrow-var-annot` shape) and an
arm inside `recognize-symbol`. The arm won, because the closer precedent is in
the *same function*: the `::` module-path continuation is already a fixed
two-char lookahead inside `recognize-symbol`'s scan loop, and `a->b` is exactly
that shape — a multi-char continuation *within* an identifier, not a new token
kind. `narrow-var-annot` needed its own recognizer because `?x:Nat` is a
different token shape; this is not.

Placement is load-bearing: the arm **must precede** the `ident-continue?` arm,
because `-` is itself an ident-continue char and would otherwise be eaten,
leaving `>` to end the token — that *is* the `c->f` → `c-` truncation.

Glued-ness needs no substrate: the scanner is mid-token, so whitespace cannot
occur there by construction.

Tests: `racket/prologos/tests/test-arrow-identifiers.rkt` (10 cases) asserting
the **token stream directly**. Half are labelled regression ANCHORS rather than
discriminators — spaced arrows, `[-> A B]`, angle-group closing, bare `a>b`.

<a id="p2"></a>
### P2 — `recognize-keyword` (R1) ✅

Landed **in the same commit as P1**, deliberately. Shipping the symbol arm
while `recognize-keyword` lagged would have *been* the F1b.7g drift the
function's own comment records — a one-commit window is still the bug.

<a id="p1b"></a>
### P1b — guided error for half-glued (R2) ⬜

`a-> b` and trailing `foo->` still truncate to `a-` + `rangle`, exactly as
before this change; pinned as the current state so P1b has a failing baseline.

Deferred out of P1 for a reason worth recording: the obvious implementation —
raise from the tokenizer — is the **whole-file-abort class** that `7d8520a0b`
promoted a lesson about on 2026-08-03 (*"a raise on the parse path is a
WHOLE-FILE abort"*). The guided error must therefore come from an error path,
not the scan. Candidate: extend `elaborator.rkt`'s `unbound-op-hint-table`
(which already maps `>` → the angle hint, and is the source of the misleading
"comparison keywords are spelled lt/le/gt/ge" the user saw) to recognise an
unbound name ending in `-` followed by a stray `>` and say *"`->` must be glued
on both sides to be part of a name"*. Error-path only, zero soundness effect —
the same shape as the #70-C hint.

<a id="p3"></a>
### P3 — acceptance ⬜

Corpus A/B is **done** (in P1): `tools/reader-corpus-ab.rkt`, both legs on one
pinned 161-file snapshot, **zero diffs**, 0 read-errors per leg. Remaining: un-
comment the `int->str` block in
`examples/2026-03-18-track7-acceptance.prologos`, waiting since 2026-03-18.

<a id="p0"></a>
## 6. P0 — subsumed, do not implement

While probing, `spec f Posit32->Posit32` + a `defn` was found to produce a
**whole-file abort with a raw Racket stack trace** from
`inject-spec-into-defn`. That was real on `a9c0c18d` but is **already fixed on
main** by `ae26f5403` ("the preparse seam is guarded"), a *general* guard.
Verified at base: the same input now yields
`0: ERROR: preparse: spec: spec type for f has no arrow but defn has 1 params`
and the following command still runs.

Related: `7d8520a0b` (2026-08-03) promoted the lesson *"a raise on the parse
path is a WHOLE-FILE abort"*, which had zero entries in either tier. The bug I
rediscovered is precisely that class, already codified.

<a id="coords"></a>
## 7. Base discipline — why this doc is pinned to `b429d038`

The grounding audit reported **HEAD divergence**: it read the main checkout
(then `ae26f540`) while the scoping session sat on branch
`eager-bartik-96e686` at `a9c0c18d`, 5 commits off a fork point at `a1bcad17`
while main had run 52 commits the other way. Confirmed: `ident-continue?` is
`:243` on that branch and `:242` on main — **already drifted by one line**.
Main has also touched all three target files since the fork
(`parse-reader.rkt` ×2, `macros.rkt` ×3, `tree-parser.rkt` ×3).

Everything here is therefore re-pinned to `b429d038`. This is the documented
worktree-staleness hazard; it also caught P0 as already-fixed work.

<a id="risks"></a>
## 8. Risks and open items

1. **Four identifier-charset sites, not one.** `ident-continue?` /
   `ident-start?` are file-private to `parse-reader.rkt`, and
   `racket/prologos/lsp/server.rkt` defines its **own `id-char?` three times**,
   none delegating (it cannot — the predicate is unexported). All three already
   omit six chars `ident-continue?` admits. This is a live, uncatalogued
   F1b.7g-class drift; an arrow rule that does not reach the LSP will make
   hover/goto mis-word arrow names.
2. **Sequencing with in-flight work.** `->` is a **binder-region terminator**
   in the CIU T6 P4c broadcast machinery (`binder-region-terminators` =
   `'(:= ->)`, four consulting sites). A rule that stops emitting a standalone
   `->` token in some positions touches a slice that was in flight at P4c-4c.
   Coordinate before landing P1.
3. **Live counter-precedent.** The project has already met a `<`/`>` vs
   angle-group collision and resolved it by **renaming** — `lt`/`le`/`gt`/`ge`
   exist precisely because `<`/`<=` collide — leaving dead `int<`/`int<=`
   parser-table entries and a broken pretty-print round-trip. Arrows getting
   whitespace-disambiguation while comparisons got renaming is a deliberate
   asymmetry; worth stating rather than drifting into.
4. **Asymmetry the rule introduces.** `a>b` and `a > b` tokenize identically
   today (bare `>` is glue-insensitive). After P1, `a->b` is one identifier
   while `a>b` remains three tokens.
5. **`->foo` stays divergent.** WS splits it; sexp reads it as one symbol. A
   both-sides rule does not close that gap.
6. **Sexp is already more permissive.** Outside angle groups `c->f` is one
   symbol today. But `<c->f>` shatters in sexp too — inside `<…>` the inner
   readtable makes `-` terminating. The WS/sexp census obligation applies.

<a id="value"></a>
## 9. Value

Zero corpus uses today. The value is entirely in unblocking an idiomatic
naming style (`char->integer`, `centigrade->fahrenheit`) that Scheme/Lisp
users expect and that the `.rkt` side of this very tree uses 3,626 times across
291 distinct lexemes — plus removing a silent truncation. Small, low-risk,
ergonomic.
