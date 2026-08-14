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
| P4 | `trait` body | ✅ | **Biggest win of the track**: error-bytes 10.2% → **4.2%**, −69,008 B in one rule — [§5.p4](#p4) |
| P5 | `defr` + relational syntax (Rel T1) | ✅ | Was absent entirely; 6/7 shapes → 0. Clean 23 → **25** — [§5.p5](#p5) |
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

<a id="p4"></a>
### 5.P4 — `trait` bodies

The body accepted only `spec_form | defn_form | def_form`. But a trait method
signature is **bare** — `eq? : A A -> Bool`, with no `spec` keyword — so the one
thing every trait actually contains could not parse, and each trait failed
*entirely*, swallowing its whole body. Traits are large; that is where the mass
was.

Added `trait_method` (bare `name : type`) and `trait_metadata` (`:doc "…"`, and
`:laws` with an indented list of `- :name/:forall/:holds` entries).

⚠ **Conflict worth remembering**: a trailing `optional($._newline)` inside each
child was a genuine ambiguity, because the trait body already offers `_newline`
as a sibling choice. `match_arm` and `data_constructor` carry the same trailing
optional safely — their parents do *not* offer `_newline` alongside. Removing it
from the children resolved it; do not copy that idiom without checking the parent.

**Result — error-bytes 117,091 → 48,083 (10.2% → 4.2%)**: −69,008 bytes, 59% of
all remaining error mass, from one rule. Clean files 22 → **23**. The largest
single win of the track by a wide margin.

Still open: the `:laws` block itself (2 errors) — the `:forall` cluster. Bare
methods, arrow methods and `:doc` are all 0.

<a id="p5"></a>
### 5.P5 — `defr` (Rel Track 1)

`defr` appeared **zero** times in `grammar.js` while the corpus carries **207**
such lines — purely additive, not corrective. Added `defr_form` with a `||` FACT
block (rows across lines, `|`-separated on a line) and a `&>` RULE clause, plus
`relation_params` over logic variables.

6 of 7 shapes → 0: one/multi-row facts, arity-2 rows, `|` separators, `&>` with
paren goals, and `&>` with `not`. Clean files 23 → **25**. Error-bytes
48,083 → 53,574 (+5,491) — newly reachable relational code failing deeper in.

Open: the BARE-HEAD `&>` continuation form (`&> fruit-color fruit color` with
sibling goals on following lines). The paren-goal form works.

---

<a id="locality"></a>
## 7. ⭐ The metric this track should have been using — LOCALITY

Owner note, 2026-08-14: `foray.prologos` is a scratchpad. It deliberately holds
forms that do not run, some kept broken on purpose as reminders. It is not
dirty by accident.

> *"a grammar that can still be functional in presence of dirty code is a
> valuable thing"*

That is the right frame, and it retires the instinct to exclude foray as noise.
**Editor support is always operating on half-written code** — the buffer is
mid-edit essentially all the time. So the property that matters is not "the
corpus parses at 0", it is:

**a broken form damages ITSELF and stops there.**

Font-lock and the surfer stay usable in a file with a bad form in it, provided
the error does not swallow the rest. That reframes several results in this
track: P3c replaced foray's single 19,280 B swallow with 207 small errors, which
the byte metric scored as a REGRESSION and locality would have scored as a large
win — the damage went from 67% of the file to a set of local spots.

**IMPLEMENTED 2026-08-14.** `check-corpus.sh` now reports, per file, the size of
the LARGEST error node and the fraction of the file it covers; the table sorts
by that fraction, and the summary counts **swallows** — files where one error
node covers ≥20%.

**A/B against the original pre-repair grammar, which is the honest track number:**

| | before | after |
|---|---|---|
| files SWALLOWED (one error ≥20% of file) | **9** | **6** |
| worst single error, as % of its file | **100%** | **51%** |
| clean files | 18 | 25 |
| error-bytes | 13.6% | 4.7% |

A file existing as **one entire ERROR node** — 100% — is gone. The worst case
halved. Ordinary files now sit at 3–6% local damage.

⭐ And the reframing pays for itself immediately on the file that prompted it:
**foray dropped out of the swallowed list entirely** (67% before P3c, now under
18%). By bytes, P3c looked like a −56 B nothing; by locality it was the fix that
made the owner's scratchpad usable in an editor.

**Remaining swallows, worst first** — the actionable endgame list:
`core/fio.prologos` 51% · `examples/narrowing-demo` 33% ·
`examples/2026-03-30-ppn-track2b` 33% · `book/lattices` 31% ·
`examples/2026-04-22-1A-iii-probe` 31% · `data/reason` 20%.

<a id="sameline"></a>
### 7.2 The five remaining swallows are ONE cause — and it is the same blocker

Diagnosed 2026-08-14 by reading each file's largest ERROR node. Three of the
five open at an identical construct:

```
defn apply-op [f x y] [f x y]      narrowing-demo, from line 300
defn add-ten  [x] [int+ x 10]      ppn-track2b,    from line 81
defn p1-inc   [n] [int+ n 1]       1A-iii-probe,   from line 61
```

**A SAME-LINE `defn` body.** `defn_form` demanded `$._indent`, so a one-line
defn was unrepresentable — and **255 corpus lines write it**, at 3–4 errors
each. It is the single largest remaining gap by occurrence.

⏸️ **BLOCKED, attempted and reverted**, and it is the SAME ambiguity family as
the paren match arm in §7.1:

- first `defn f <A -> B>`: a body may begin with `<`, which is also how the
  `<Type>` return annotation begins — undecidable until the closing `>`;
- restricting the body to non-angle forms then exposed the real one:
  `defn add-ten [x] [int+ x 10]` — **`param_list` and `grouped_expr` are BOTH
  `[…]`**, so nothing distinguishes "the first bracket group is the params"
  from "it is the body" without lookahead.

Conflict declarations do not close it; each one exposes the next. The fix is the
same design task as §7.1 — **decide bracket-group ROLE by position/lookahead in
one place**, rather than by rule shape. Doing that would unblock the same-line
defn body AND the paren match arm together, which is the whole remaining
swallow list bar `lattices` and `reason`.

Not attempted here: `book/lattices` (opens at `defn top [] <Parity>` inside an
impl — same-line-adjacent) and `data/reason` (opens at a multi-line bracket
continuation). Both plausibly the same root; unverified.

<a id="fio"></a>
### 7.1 `core/fio.prologos` (51%) — half done, half BLOCKED

Two causes, diagnosed by locating the largest ERROR node (lines 39–80) and
reading it:

1. **QTT multiplicity arrows `-0>` / `-1>`** (`spec fio-write Handle -1> String
   -> Handle`). Only `->` existed, so `-1>` lexed as `-`, `1`, `>`.
   ✅ **FIXED** — `linear_arrow: token(/-[0-9]+>/)` as an alternative in
   `arrow_type`. 14 occurrences corpus-wide.
2. **Inline paren match arms** (`match h (mk-handle idx -> body)`) — the
   sexp-style one-line arm, as opposed to the indented `|` form.
   ⏸️ **BLOCKED, attempted and backed out.**

**Why (2) is blocked, so it is not re-attempted the same way**: `(` + something
+ `->` is genuinely ambiguous between `paren_expr` and a match arm until the
`->` is reached, and the ambiguity is not one conflict but a FAMILY — it
reappeared for `true` (`atom` vs `literal_pattern`), then `identifier` (`atom`
vs `identifier_pattern`), and would continue through `constructor_pattern` vs
`application`. Declaring conflicts pairwise chases it forever. A real fix needs
pattern-vs-expression resolved at one place — e.g. parse the arm interior as an
expression and reinterpret, or gate on `->` lookahead — which is a design task,
not a rule tweak.

fio therefore stays at 51% until (2) lands; the arrow fix alone does not move it,
because the arrow sits *inside* the region the match arm already swallowed.
9 occurrences corpus-wide, but they are what makes fio the worst file.

---

## 6. Deferred / discovered

- Spaced `*` in Sigma types (`<(x : A) * B>`) — pre-existing, absent from lib.
- `defr` bare-head `&>` continuation form (paren-goal form works).
- `:laws` blocks inside traits (`- :name/:forall/:holds`) — the `:forall` cluster.
- Two-segment qualified names `a::b` (three-segment ones are fine).
- `<(Type 0)>` — parenthesised type inside an angle type. A naive `paren_type` did NOT fix it (see §5.P3b); needs real diagnosis.
- `[x : Bool y : Bool]` — SPACED typed params, several in one list: `type_application` greedily takes `Bool y`. The fused `[x:Int]` form is fine.
- `do` bindings (`[do [x := 1] x]`) — 1 → 2 errors after P2; pre-existing, absent from lib.
- `clean` file count is still 18/142: most files carry several of the remaining
  gaps, so files only go clean when the LAST gap in them lands. Error-bytes is
  the metric that moves in the meantime.
