# Tree-sitter Grammar Repair — TSG Track 1

**Status**: 🔄 in progress · **Opened** 2026-08-14 · **Blocks**
[SURF T1](2026-08-14_0003_SURFER_REENGINEERING.md) · **Owner ruling**: fix the
grammar before the surfer.

`editors/tree-sitter-prologos/grammar.js` was last touched **2026-03-11**
(`899b2263c`). The language has moved considerably since — LET (2026-07-31),
ARROW (2026-08-05), Rel T1 (2026-07-25) — and the grammar has not.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P0 | Corpus gate + baseline | ✅ | `check-corpus.sh` — commit `321391bf`. Baseline in §1 |
| P1 | Multi-clause `defn` (`\| pat -> body`) | ✅ | `3d43a89f`. Isolated fix only; the corpus gain arrived with P1b — [§5.p1](#p1) |
| P1b | Bare operators as atoms (`+ - * / \|>`) | ✅ | Unplanned; **it is what unblocked P1**. Error-bytes 13.9% → **10.0%** — [§5.p1b](#p1b) |
| P2 | `let` (LET track, 2026-07-31) | ✅ | All 8 documented shapes → 0. Corpus barely moves (−549 B) because the corpus barely uses `let` — [§5.p2](#p2) |
| P3 | `fn` lambda with typed params | ✅ | **Already fixed by P1b/P2** — every shape 0 errors, no work needed. The "(fn 272" cluster was a leading-token artifact — [§5.p3](#p3) |
| P3b | `<Type>` return annotations (`defn f [x] <Bool>`) | ✅ | The real gap behind `impl` 36% + `defn` 23%. 394 corpus lines. Clean files 19 → **21** — [§5.p3b](#p3b) |
| P3c | `require` / `imports` (the `ns` 16.9% cluster) | ✅ | `ns` was INNOCENT — one 19,280 B swallow in one file. Clean 21 → **22** — [§5.p3c](#p3c) |
| P4 | `trait` body | ⬜ | |
| P5 | `defr` + relational syntax (Rel T1) | ⬜ | `defr` appears **0** times in grammar.js |
| P6 | Re-baseline, regenerate, reinstall, font-lock check | ⬜ | `install.sh`; then unblock SURF T1 |
| P7 | TSG T1.close — gate wiring, DEFERRED triage, PIR-lite | ⬜ | Consider adding the gate to pre-commit |

---

## 1. Baseline (2026-08-14, `321391bf`)

Measured by `editors/tree-sitter-prologos/check-corpus.sh` over
`racket/prologos/lib`, `racket/prologos/examples`, `editors/emacs/test`:

```
files 142 | clean 18 (13%) | dirty 124 | ERROR 8336 | MISSING 122 | lines 36231
```

Worst files: `lib/examples/foray.prologos` 1013 · `core/conversions.prologos`
498 · `examples/2026-03-18-track7-acceptance.prologos` 356.

⚠ **The lib-only figure quoted when SURF T1 was blocked (73% dirty) was
optimistic** — over the full corpus it is **87%**. Recorded because the smaller
number is the one that would be remembered.

### Why this went unnoticed for five months

A stale grammar does not error. Tree-sitter *recovers*: it emits `ERROR` nodes
and carries on, so every consumer downstream — font-lock, folding, the surfer —
degrades **silently**. There was no symptom loud enough to prompt a look. That
is the same fail-open shape as `core.hooksPath` and the audit template's false
anchor (dailies (xiv)), and the reason P0 was a measurement tool rather than a
fix.

---

<a id="gaps"></a>
## 2. The gaps are FIVE constructs, not general rot

Isolated by parsing minimal snippets (2026-08-14). This matters: the error
*clustering* attributed 779 failures to `defn`, but that counts the leading token
of the line **containing** the error, and for a multi-clause `defn` that is the
`defn` line. The construct itself is fine.

| construct | ERROR nodes | verdict |
|---|---|---|
| `def a := 1` / `def a 1` | 0 | ✅ works |
| `defn` one-line body | 0 | ✅ works |
| `defn` typed param (`[x:Int]`) | 0 | ✅ works |
| `spec` arrow + bracket types | 0 | ✅ works |
| `match` with arms | 0 | ✅ works |
| bare top-level expression | 0 | ✅ works |
| `ns` | 0 | ✅ works |
| **`defn` multi-clause (`\| pat -> body`)** | 1–2 | ❌ **P1** |
| **`let` (layout form)** | 3 | ❌ **P2** |
| **`fn` lambda, typed param** | 2 | ❌ **P3** |
| **`trait` body** | 1 | ❌ **P4** |
| **`defr` (Rel T1)** | 3 | ❌ **P5** |

So the core declaration forms parse. Five constructs account for the corpus
damage, and multi-clause `defn` is the dominant one because it is everywhere.

---

## 3. Method

Repair is gated on the number, not on impression: run `check-corpus.sh`, change
one rule, run it again. Each phase records before/after in its section below.
`--max N` lets the gate ratchet downward as phases land.

⚠ **`install.sh` must be re-run for a change to take effect** — the corpus gate
measures the *installed* dylib in `~/.emacs.d/tree-sitter/`, not `grammar.js`.
Editing the grammar and re-running the gate without reinstalling measures the
old parser and reports no change, which reads as "my fix did nothing".

---

## 5. Per-phase records

<a id="p1"></a>
### 5.P1 — multi-clause `defn` (`3d43a89f`)

`defn_arm` was `| param_list body`: **no `->` at all**, and a bracketed param
list where the language writes patterns. `defn_form` additionally tied "has a
param list" to "is single-arity", so `defn nth [n xs]` + `|` clauses — the
common corpus shape — could not parse. Rewritten against `match_arm`, which
already worked and was the right model. `defn_arm_body` also accepts an indented
block (how a nested `match` is written in a clause).

Isolated: multi-clause with and without params both 1–2 errors → **0**.
Corpus at the time: **flat-to-worse** (156,370 → 158,746 error-bytes). Committed
as WIP with that stated, on the hypothesis that clause bodies were now reachable
and immediately hitting the *next* gap. P1b confirmed it.

<a id="p1b"></a>
### 5.P1b — bare operators as atoms

`identifier` requires a leading `[a-zA-Z_]`, so `+ - * /` could not be
identifiers, and no token existed for them anywhere: `[+ a b]` was unparseable.
Since Numerics N6e-E2 they are also first-class **values** (`reduce + 0 xs`), so
they belong in `atom`, not merely in head position. Corpus counts drove the set:
`+` 257 · `*` 100 · `-` 39 · `/` 23 · `|>`. `->` excluded — already `arrow_op`.

**Result — error-bytes 158,746 (13.9%) → 114,793 (10.0%)**: 43,953 bytes
recovered, 27.7% of the remaining error mass, in one rule. And it retroactively
paid for P1: the full `nth` clause probe — multi-clause + nested `match` +
`[- n 1]` — went from 2 errors to **0** only once both landed.

Regression-checked: `int*`, `p8+` still lex as identifiers (they start with a
letter); `->`, `>>` unaffected by longest-match. The spaced-`*` Sigma type
`<(x : A) * B>` still fails, but it failed **worse before** (4 errors → 3) and
does not occur in the lib corpus — pre-existing, not caused here.

⚠ **Lesson for the remaining phases**: P1 looked like a failure by its own
measurement and was one rule away from being a large win. A gap that sits
*downstream* of the one you fixed will mask the fix entirely. Do not revert on a
flat corpus number alone — check whether the construct now reaches new territory.

<a id="p2"></a>
### 5.P2 — `let`

`let_expr` **required `:=`**, allowed exactly **one** binding, and had no
bracket form. So the rare spelling parsed and every common one did not:
`let x := 4` worked; `let x 4` did not.

Rewritten: `:=` optional, `repeat1($.let_binding)` for aligned blocks and
sibling chains, plus `seq('[', repeat1($.let_binding), ']')` for the bracket
form. Binder is `typed_param_or_bare`, which already covers spaced `x : Int` and
fused `x:Int` — the lexer does not care about the spaces, so one rule serves.

All **8** documented shapes now parse at 0 errors: nested shorthand · sibling
chain · aligned block · `:=` · typed spaced · typed fused · bracket flat · the
blank-line-inside case. No regressions in defn / operators / match / spec / ns.

⚠ **But the corpus moved only 114,793 → 114,244 error-bytes (−549 B, 0.05pp)**,
clean files 18 → 19. Not a disappointment — a fact about the corpus: `let`
appears on **83 lines across 9 files**, against **1,423** `defn` lines. The LET
track landed 2026-07-31, three weeks ago, so the library predates it almost
entirely. The fix is for the code being written now, not the code already there.

**Method note, the mirror of P1's**: P1 was a real fix that the corpus number
hid. P2 is a real fix the corpus number cannot show, because the construct is
rare. Neither is measurable by error-bytes alone — the isolated shape probes are
what establish correctness, and the corpus number only tells you the *blast
radius*. Use both; do not let either alone decide.

**Discovered**: `[do [x := 1] x]` regressed 1 → 2 errors. Pre-existing failure,
absent from the lib corpus, logged in §6 rather than chased.

<a id="p3"></a>
### 5.P3 — `fn` lambda: nothing to do

Every `fn` shape already parsed at 0 errors before this phase started: bracket
and paren forms, typed and fused params, wildcard, multiplicity, literal bodies,
multiple param groups. P1b/P2 had fixed them as a side effect — `fn` bodies are
full of operators.

**The `(fn` 272 figure that put this on the plan was a leading-token artifact**,
the same one that inflated `defn` to 779: it counts the first token of the line
CONTAINING the error, and those lines began `(fn …` while the errors inside them
were operators. Third time this clustering has misdirected. Only *isolated
shape probes* establish which construct is broken; the clustering is a heat map
of where errors land, not of what causes them.

<a id="p3b"></a>
### 5.P3b — `<Type>` return annotations

Re-deriving the cluster from CURRENT error mass (rather than the stale March
figures) turned up: `impl` 36.0% · `defn` 23.0% · `ns` 16.9% · `trait` 4.4%.
Reading the actual `impl` bodies gave the cause immediately —

```
impl Eq Nat
  defn eq? [x y] <Bool>      <-- angle-bracket return type
    nat-eq? x y
```

`defn_form` accepted only the colon form `: Bool`. There was **no angle-delimited
type rule anywhere in the grammar**, while the corpus writes one on **394**
`defn` lines — so essentially every method inside every `impl` failed. Added
`angle_type` and accepted it in `defn`'s return position alongside `:`.

Result: the real `impl` block 2 → **0**; clean files 19 → **21**; ERROR count
4478 → 4000. Error-BYTES 114,244 → 117,147 (+2,903) — the P1 pattern again:
newly reachable regions now fail on gaps further in.

**Rejected and reverted in the same phase**: a `paren_type` rule for `<(Type 0)>`.
It did not fix its target (still 2 errors) and cost ~900 bytes, so it did not
earn its place and was backed out rather than left in as plausible-looking dead
weight.

<a id="p3c"></a>
### 5.P3c — `require` / `imports` (and `ns` was innocent)

The `ns` 16.9% cluster was **one `ERROR` node, in one file**: 19,280 bytes —
67% of `foray.prologos` — starting at line 1. `ns` itself parses at 0 and always
did. Fourth time the leading-token clustering has pointed at the wrong
construct; here it pointed at a construct with no defect at all.

The actual cause was on the next line:

```
require [prologos::data::nat    :as nat  :refer [add mult zero?]]
        [prologos::data::bool   :as bool :refer [not]]
```

`require_declaration` allowed exactly **one** bracket group and **one** clause,
while the language takes several groups (often on continuation lines) each
carrying both `:as` and `:refer`. Rewritten as `repeat1($.require_group)` with
`repeat($.require_clause)` inside; `imports_declaration` shared the defect and
the fix.

Verified: `:as`+`:refer` together, and 1/2/4 groups with real module paths, all
0 — including the real foray header. Clean files 21 → **22**.

⚠ **But corpus bytes moved only −56**, because foray's single 19,280 B swallow
was replaced by **207 smaller errors totalling 20,497 B**. The file is a
1,548-line deliberate kitchen-sink tour, so it hits every remaining gap at once
and now fails at all of them individually instead of once at the top.

**Metric skew worth knowing**: foray alone is 20,497 of 117,091 remaining
error-bytes — **17.5% of the whole corpus's error mass in one atypical file**.
Track-level byte percentages should be read with that in mind.

**Curiosity, logged not chased**: two-segment module names (`a::b`) fail where
three-segment ones (`prologos::data::nat`) parse. Synthetic-probe artifact —
every real corpus path has three segments.

---

## 6. Deferred / discovered

- Spaced `*` in Sigma types (`<(x : A) * B>`) — pre-existing, absent from lib.
- Two-segment qualified names `a::b` (three-segment ones are fine).
- `<(Type 0)>` — parenthesised type inside an angle type. A naive `paren_type` did NOT fix it (see §5.P3b); needs real diagnosis.
- `[x : Bool y : Bool]` — SPACED typed params, several in one list: `type_application` greedily takes `Bool y`. The fused `[x:Int]` form is fine.
- `do` bindings (`[do [x := 1] x]`) — 1 → 2 errors after P2; pre-existing, absent from lib.
- `clean` file count is still 18/142: most files carry several of the remaining
  gaps, so files only go clean when the LAST gap in them lands. Error-bytes is
  the metric that moves in the meantime.
