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
| P5b | Bracketed patterns in clause heads (`\| [zero] -> …`) | ✅ | Found while diagnosing §7.0.4. Generated first try, no conflicts. 4.7% → **4.5%** |
| P5c | `=` unify operator (narrowing goals) | ✅ | No `=` token existed at all; 65 corpus lines. Clean 25 → **26** — [§5.p5c](#p5c) |
| P5d | Angle-typed params `[iv <Interval>]` + swallow triage | ✅ | 136 corpus lines; first try, no conflicts. Clean 26 → **27** — [§5.p5d](#p5d) |
| P5e | `string` made a single token (`;` inside a string was lexed as a comment) | ✅ | **`data/reason` cleared**; swallows 6 → **5** — [§5.p5e](#p5e) |
| P5f | **Same-line `defn` bodies** — scanner-level, after 3 rule formulations failed | ✅ | **Swallows 5 → 2**, bytes 4.6% → **2.7%**, clean 27 → **29** — [§5.p5f](#p5f) |
| P5g | **Inline paren match arms** (`match h (pat -> body)`) - the `fio` swallow | done | **Swallows 2 -> 1**, worst 51% -> **31%**; fio's worst error 1852 B -> **156 B** - see 5.P5g |
| P5h | **`impl` paren type args** — the `lattices` swallow | ✅ | **SWALLOWS 1 → 0**; worst 31% → **13%**; bytes 2.6% → **1.8%** — [§5.p5h](#p5h) |
| P5i | **Map literals** via a `_map_open` scanner token — the contested `{` | ✅ | Plain rule regressed (swallows 0→2); lexical split holds swallows at **0**, bytes 1.8% → **1.7%** — [§5.p5i](#p5i) |
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

<a id="p5d"></a>
### 5.P5d — angle-typed params, and the swallow-list triage

**Triage first, per the tell** — sort missing-vs-contested before spending.

| file | cause | verdict |
|---|---|---|
| `ppn-track2b` 33% | opens at `defn add-ten [x] [int+ x 10]` | **BLOCKED** — same-line `defn` |
| `1A-iii-probe` 31% | opens at `defn p1-inc [n] [int+ n 1]` | **BLOCKED** — same-line `defn` |
| `narrowing-demo` 33% | residue is same-line `defn` | **BLOCKED** |
| `lattices` 31% | line 524 `defn top [] <Parity>` | **CONTESTED** — see below |
| `reason` 20% | reproduces standalone at lines 67–120 | minimisable, **next target** |

§7.2's guess was right: three of six swallows are blocked behind the deferred
construct and are not targets.

**LANDED — `angle_param` (`11f7df6e`).** `typed_param` required the colon, so
`[iv <Interval>]` — **136 corpus lines** — could not parse. Generated first try,
no conflicts, no regressions: the missing-shape signature exactly.
Clean **26 → 27**, MISSING **90 → 72**, ERROR 3721 → 3657, bytes 4.5% → 4.4%.

**`lattices` — differential established, cause NOT yet fixable.** Isolated by
delete-line and then substitution on the full file:

| line 524 | worst error |
|---|---|
| `defn top [] <Parity>` | **8024** |
| `defn top [] : Parity` | **8024** |
| `defn top []` | 253 |
| `defn top [q] <Parity>` | 253 |
| `defn top <Parity>` | 253 |

So the trigger is **an EMPTY param list followed by ANY return type**. It does
NOT reproduce in a minimal snippet — only against the real 216 lines that follow
— which is the contested signature, not a missing shape.

**Tried and REVERTED**: splitting `param_list` into an explicit `[]` branch
instead of `repeat`'s zero case. Numbers came back byte-identical (clean 27,
3657, 50826), so the ambiguity hypothesis is WRONG and the change earned
nothing. Backed out, same discipline as `paren_type`.

⚠ **Method correction worth keeping**: prefix-bisect (`sed -n '523,Np'`) reported
a false cause — truncating mid-`impl` manufactures an error at the cut. The
relay note warned of exactly this. **Delete-window and substitution on the FULL
file are the sound techniques**; prefix truncation is not.


<a id="p5e"></a>
### 5.P5e — `string` was not a token (semicolons ate the rest of the line)

`data/reason`'s swallow minimised, by delete-line on the FULL file, to line 69 —
and the operative content was `[join "; " …]`. **A string containing a
semicolon.**

`string: $ => seq('"', /[^"]*/, '"')` is a **seq**, so its three pieces are
separate tokens and `extras` can be interleaved between them. `extras` includes
`comment: token(seq(';', /.*/))`. So a `;` inside a string was lexed as a
COMMENT, eating the closing quote and the rest of the line. Measured:
`[join "; " xs]` failed, `[join ", " xs]` parsed. 29 corpus strings contain one.

Fix: `token(seq('"', /[^"]*/, '"'))` — atomic, same language, nothing can
intrude. Regression-checked: plain strings, escapes, empty strings, real
comments, comment-only lines all still correct.

**Result — `data/reason` CLEARED; swallows 6 → 5.**

⚠ **And `1A-iii-probe` grew 31% → 53%**, taking the "worst" headline from 51% to
53% and bytes 50,826 → 52,682. Verified: it still opens at line 61
`defn p1-inc [n] [int+ n 1]` — the **blocked** same-line `defn`. The file is
entirely inside that construct's blast radius and simply reaches further before
failing. It resolves when same-line `defn` lands, not before.

**This is why swallow COUNT is the better headline than worst-percentage**: the
count fell (a file genuinely cleared) while the max rose (a blocked file
extended). Reporting only the max would have called a real fix a regression.


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

<a id="bracketrole"></a>
### 7.0 The bracket-role design — ATTEMPTED, and what it actually needs

Attempted 2026-08-14 and reverted. Recording the conflict CHAIN, because each
attempt got one step further and the sequence is the finding:

1. `[$.param_list, $.grouped_expr]` declared at the real decision point —
   **this worked**, where earlier leaf-pair declarations
   (`atom`/`literal_pattern`) had not. Conflict moved on.
2. `defn f <A -> B>` — body-may-start-with-`<` vs the `<Type>` return
   annotation. Removed by restricting the same-line body to non-angle forms
   (positional: an angle group there is ALWAYS a return type).
3. `defn f [x] • [` — the parser had already REDUCED the first group to
   `grouped_expr`. Restructured so the same-line variant is one explicit
   sequence `params THEN body`, making the first group params *by
   construction*.
4. `defn f [x] [g x] • [` — and here it still stands: a `grouped_expr` body
   followed by another `[` is ambiguous with `application`
   (`expression expression`), which would consume it as an argument.

**So the remaining question is not "params or body" — that is solved — it is
"where does a same-line body END".** `[int+ x 10] [more]` is one application in
expression position and two things in defn position. That is a genuine
whole-line-scope question, and the honest options are:

- **(a) a scanner token.** The external scanner already emits INDENT/DEDENT/
  NEWLINE; a `_line_end` token would let the body rule say "to end of line",
  which is exactly the constraint. Most faithful to a layout language, and the
  scanner is the layer that owns layout.
- **(b) accept the greedy read.** ❌ **DISQUALIFIED BY MEASUREMENT
  (2026-08-14).** Two shapes were checked:
  · *sibling* groups on the defn line (`defn f [x] [a] [b]`): **0 genuine
    cases**. The 5 apparent hits are NESTED groups inside one body
    (`defn on [f g x y] [f [g x] [g y]]`), which greedy parses correctly.
  · a same-line defn followed by a **next line starting with `[`**: **7 real
    occurrences**, e.g. `defn my-id …` then `[my-id 42]`. Newlines are
    `extras`, so a greedy application body **absorbs the following top-level
    form as an argument**. That is a whole-form swallow — exactly the locality
    failure §7 exists to eliminate, and it would be self-inflicted.
- **(c) `prec.dynamic`** to prefer ending the defn over extending the
  application. Cheapest, least principled, and needs a corpus check that it
  never picks wrong.

⚠ **Do not attempt this again by adding conflict declarations.** Four rounds
established that they move the failure rather than remove it.

<a id="p6-lineend"></a>
#### 7.0.1 `_line_end` IMPLEMENTED — and the ruling was necessary but NOT sufficient

Attempted 2026-08-14 (post-rewind), reverted to known-good. The scanner half
**works**; the ruling's premise was right and its sufficiency was wrong.

**What is settled — the scanner design is sound.** `LINE_END` added to
`enum TokenType` (last, so existing indices do not shift) and `$._line_end` to
`externals` (same position — the two orders MUST match). It is emitted
**zero-width**: `mark_end()` before any lookahead, so it consumes nothing and
the INDENT/DEDENT/NEWLINE machinery still sees the newline on the next call.
That separation is essential — a `_line_end` that swallowed the newline would
destroy the DEDENT closing an enclosing `impl`. Also emitted at EOF, so a
same-line `defn` as the final line can close. It generated and behaved.

**What is NOT settled — conflicts #2 and #4 are COUPLED, and that is new.**
Three further rounds, and they oscillate:

| move | outcome |
|---|---|
| same-line body = `expression` | **#2** — `<` is `angle_expr` (body) or `angle_type` (return) |
| body restricted to non-angle head | **#4** — `defn f [x] [g x] • [` |
| declare `[$._same_line_head, $.expression]` | **#2 returns** — the declaration itself makes `expression` reachable after `param_list` |
| also restrict arguments to non-angle | **#4 returns** |
| both restrictions + the declaration | **#2 returns** |

So it is not that declarations "move the failure" — it is sharper than that:
**#4 can only be resolved by admitting `expression` in that position, and doing
so is exactly what recreates #2.** They cannot both be closed by rule shaping.

**PROPOSED ROOT FIX (untried, and the next thing to attempt):** #2 exists only
because `angle_type` and `angle_expr` are two DIFFERENT rules that both match
`<…>`. Unify them into a single `angle_group` rule and let position decide the
LABEL rather than the parse — then #2 cannot arise, and #4's declaration becomes
safe because `_line_end` is there to kill the wrong branch. That attacks the
coupling at its root instead of alternating between its two ends.

⚠ Do not resume by re-trying the table above; those five combinations are
exhausted.

<a id="p6-angle"></a>
#### 7.0.2 `angle_group` unification LANDED — and the same-line variant GENERATES but must not ship

**Landed and kept**: `angle_expr` and `angle_type` are now ONE rule,
`angle_group`, used in expression position, type position, and as a `defn`
return type. Conflict #2 is dissolved **by construction** — there is nothing to
decide between, because there is only one rule; position decides the LABEL, not
the parse. Verified regression-free twice: clean 25, swallows 6, worst 51%,
error-bytes 4.7%, and `<Bool>` returns / angle types / angle expressions /
spec arrows / trait / defr / linear arrows all at 0.

**Attempted on top, and REVERTED**: the same-line `defn` body.

What it established, which four earlier rounds never reached:

1. **It generates.** With #2 dissolved, `_line_end` plus two conflict
   declarations (`[$._same_line_head, $.expression]`,
   `[$.defn_form, $.expression]`) produce a parser.
2. **The target shapes parse**: bracketed bodies, bare applications, atoms,
   `<Bool>` returns — all 0.
3. **`_line_end` does its job, verified on the TREE not the error count**:
   `defn my-id [x] x` followed by a line starting with `[` yields **two
   `top_level` nodes**. No swallow. The mechanism is sound.
4. ⛔ **But it is catastrophic at corpus scale.** Clean files rose 25 → 30, and
   **swallows rose 6 → 17 with SIX FILES parsing as a single 100% `ERROR`
   node** (`numerics-tutorial-demo` 28.5 KB, `book/lattices` 25.5 KB,
   `unified-matching` 16.4 KB, `2026-03-26-ppn-track0`, and two `audit/` files).
   Error-bytes 4.7% → **17.6%**.

**Diagnosis**: the two conflict declarations are too BROAD. They admit
`expression` at a decision point reachable from far more contexts than the
same-line defn, so GLR takes a wrong global branch and a whole file dies. The
per-shape probes cannot see this — every isolated probe passed. **Only the
locality metric caught it**, which is the second time §7 has earned its keep.

**Next attempt should narrow the declaration, not the body.** The body
restriction (`_same_line_head`, no angle) is fine and did its job; it is the
conflict pairs that need to be scoped so they cannot fire outside a `defn`
line — or replaced by something that does not open `expression` at all.

⚠ Do not ship a same-line variant on a green ERROR-count or on green shape
probes. It was green on both while destroying six files.

<a id="p6-narrow"></a>
#### 7.0.3 Narrowing the declaration — tried, and it is NOT the cause

Second formulation, 2026-08-14. Reverted.

**The diagnosis that motivated it was right, and useful.** Bisecting a 100%
file located the trigger exactly: two bare top-level `[…]` forms in a row —

```
[zero? 0N]

[add 3N 4N]
```

**with no `defn` anywhere in sight.** `[$._same_line_head, $.expression]` had
made those alternative reductions of the same `grouped_expr`, destabilising
top-level parsing everywhere. So the declarations really were too broad.

**But removing them did not help — it made it worse.** The narrowest possible
formulation — plain `expression` body, no shadow rules, no return-type slot,
**no conflict declarations at all**, and it generates cleanly — measured:

| | baseline | broad declarations | no declarations |
|---|---|---|---|
| swallows | **6** | 17 | **24** |
| worst single error | **51%** | 100% | **100%** |
| error-bytes | **4.7%** | 17.6% | **20.2%** |
| clean files | 25 | 30 | 28 |

⛔ **So the conflict declarations are not the cause. The same-line variant
itself destabilises the grammar at scale**, in both formulations.

**And it is invisible to probes, structurally.** Every isolated shape passed
both times — target bodies, the swallow hazard (verified on the TREE: two
`top_level` nodes), all regressions. With the narrow formulation the trigger
line still failed at line 91 of the file, yet **none of the minimal repros
reproduce it**: `def` + two bare forms, indented defn + bare form, two bare
forms with a comment between — all 0. The failure needs ~90 lines of
accumulated parser state. That is global instability, not a local rule error.

**Where this leaves it.** Three attempts (§7.0, §7.0.1, §7.0.3) across two
independent formulations. The angle unification (§7.0.2) was a genuine advance
and is landed; `_line_end` is sound and its mechanism verified. What is NOT
established is that `defn params expression _line_end` can coexist with a
grammar where `expression` is also a top-level form.

<a id="p6-why"></a>
#### 7.0.4 WHY long files destabilise — ANSWERED: it degrades ERROR RECOVERY

Answered 2026-08-14 by mechanical reduction. **It is not length.**

⚠ **The first reduction produced an ARTIFACT, and that is worth recording.**
Delta-debugging the failing prefix on the property "the whole file is one
ERROR" minimised to a single line — `defn nat-double` — because *any truncated
form* satisfies it. The reducer was right; the property was wrong. Checked
against the old grammar: that bare header errors under BOTH. **A reduction
property must be DIFFERENTIAL** (fails under new AND NOT under old), or it
minimises to "incomplete input".

**The real construct**, from the same file:

```
defn nat-double
  | [zero]  -> zero
  | [[suc k]] -> suc [suc [nat-double k]]
```

| grammar | result |
|---|---|
| HEAD (no same-line variant) | **3 local ERRORs** |
| with same-line variant | **ONE ERROR spanning the whole file** |

**The mechanism: the same-line variant degrades tree-sitter's ERROR RECOVERY.**
A second continuation at the `defn` decision point means that when input matches
NEITHER, GLR has explored both branches and can no longer localise — a contained
3-error region becomes a total swallow.

**The corpus numbers said this and I misread them twice.** Clean files ROSE
(25 → 28/30) while swallows rose (6 → 24). Files that parsed cleanly stayed
clean, and some newly became clean from same-line support; only files that were
ALREADY failing got catastrophically worse. That is an amplifier, not a new
defect.

**Consequence for the plan.** Same-line `defn` is blocked by neither conflicts,
declaration breadth, nor `_line_end` — all solved. It is blocked by the corpus
still containing constructs the grammar cannot parse, each of which it amplifies
from local to total. **Attempt it LAST**, once the remaining gaps are closed.

**Discovered en route, unrelated**: `| [zero] -> zero` — a BRACKETED PATTERN in
a clause head — is not accepted by `pattern` (`constructor_pattern` is
`identifier pattern_arg+`; there is no bare `[…]` alternative). A genuine gap. Verified restored to known-good after the revert: clean 25, swallows
6, worst 51%, and multi-clause defn / impl+`<Bool>` / trait / defr / linear
arrows all still parse at 0.

**RULING (2026-08-14, measured): take (a), the `_line_end` scanner token.** (b)
is disqualified above; (c) `prec.dynamic` would face the same next-line hazard
and would hide it behind a heuristic rather than state it. The scanner already
owns layout, and "a same-line body ends at the line" is a layout fact — putting
it anywhere else is what has failed four times.

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

**§7.1.1 — the "parse the interior as an expression" recommendation was TRIED
(2026-08-14) and does not dissolve it either.** Reverted.

The idea was this section's own: parse the arm's left side as expressions rather
than patterns, resolving pattern-vs-expression at ONE place. It is sound as far
as it goes — the pattern/expression conflict family really does disappear. But a
NEW family replaces it, and the conflict walked three positions:

1. `'match' atom • '('` — is the `(` an application argument to the scrutinee,
   or the first arm?  Declared `[$.expression, $.match_expr]`; narrow and
   defensible.  Conflict moved.
2. `'match' atom match_expr_repeat2 • '('` — the same question once per
   repetition step.  Dropped `repeat1` to a single arm (corpus-justified: only
   **4** lines carry two inline arms).  Conflict moved again.
3. `'match' atom '(' defr_rule_repeat1 '->' • '['` — now INSIDE the arm, and
   pulling in `defr_rule`, because `&> expression+` also competes for
   `( … -> … )`.

**So the blocker is not pattern-vs-expression specifically. It is that
`( … -> … )` is claimed by `paren_expr`, by the inline match arm, AND by
`defr_rule`** — three rules over one shape. Resolving two of the three still
leaves a conflict.

⚠ Do not re-attempt by moving the interior between patterns and expressions;
both sides have now been tried. A fix has to make `( … -> … )` unambiguous
ACROSS all three claimants at once — most plausibly by giving the arrow inside
parens a distinguishing token, or by admitting the arm only where `defr` cannot
appear.

fio stays at 51%.

<a id="p5b"></a>
### 5.P5b — bracketed patterns in clause heads

Found while diagnosing §7.0.4, not planned. `| [zero] -> zero` and
`| [[suc k]] -> …` did not parse: `[ pattern… ]` was accepted as an ARGUMENT
(spelled inline inside `pattern_arg`) but was not a `pattern` in its own right.

Added `grouped_pattern` and **shared it with `pattern_arg`** rather than
spelling the shape twice — two rules over one shape is exactly what made `<…>`
ambiguous for four rounds (§7.0.2). It generated first try with **no conflict
declarations**, which is itself the signal that the shape was simply missing
rather than contested.

Error-bytes 54,367 → **51,390** (4.7% → 4.5%); swallows unchanged at 6, worst
unchanged at 51%, clean files unchanged at 25. Regression-free across
head-tail patterns, constructor patterns, wildcards, literals, multi-pattern
clauses, impl/trait/defr/let, and bare top-level forms.

Modest — but it moves one axis and worsens none, which is not true of most of
today's attempts.

<a id="p5c"></a>
### 5.P5c — `=`, the unify operator (narrowing goals)

`narrowing-demo` (33%) turned out to be 549 lines of commentary around ~35 lines
of code, and those lines are dominated by narrowing goals: `[add ?x ?y] = 7N`,
`add ?x ?y = 0N`, `(= ?x 5)`.

**The grammar had no `=` token anywhere.** 65 corpus lines use one. Added `=` to
the `operator` atom rather than inventing a top-level goal rule — that keeps
both `(= a b)` and `x = y` working through the ordinary application path and
adds no competition for any existing shape. Longest-match keeps `:=` intact
(verified: `def a := 1`, `let x := 4` unaffected).

Clean files 25 → **26**; ERROR count 3876 → 3721; error-bytes 51,390 → 51,250.
Regression-free.

⚠ **narrowing-demo is NOT cleared**: down to **2** error nodes from 19, but
still 33% swallowed. Its residue is two same-line `defn [n] : Nat [add n n]`
lines — the contested construct deferred by §7.0.4. It cannot go clean until
that lands, which confirms the ordering rather than contradicting it.

**Pattern worth noting across P5b and P5c**: both were MISSING shapes, both
generated first try with no conflict declarations, both were regression-free.
That is now a reliable tell — a shape the grammar simply lacks costs one rule;
a shape two rules already compete for costs a design.

<a id="p5f"></a>
### 5.P5f — same-line `defn` bodies (the one that needed a design)

`defn add-ten [x] [int+ x 10]` — **255 corpus lines**, and the blocker for three
of the five remaining swallows.

**Why three rule formulations failed.** The competition is at the TOKEN level:
`[x]` and `[int+ x 10]` are both bracket groups, so no rule can tell a second
param list from a body. Every grammar-level formulation put a second
continuation at the `defn` decision point, and that degraded tree-sitter's
**error recovery** — measured at the time: swallows 6 → 17 → **24**, worst
51% → **100%**, *while clean files rose*. Constructs that had failed with three
local errors became whole-file swallows. All three were reverted.

**The design that works: move the decision into the SCANNER.**
`_same_line_body` is a zero-width external token. The scanner marks the end
before peeking, skips spaces/tabs, and emits it when what follows is neither a
newline, EOF, nor a comment. The branch is then chosen by ONE token on ONE
character of lookahead — an ordinary shift, not an ambiguity. Generated first
try, **no conflict declarations**.

⭐ **The load-bearing detail is not in the scanner but in the grammar**: the
same-line branch makes the **param list REQUIRED**. That is what keeps
`_same_line_body` out of `valid_symbols` until the params have been consumed.
Make it `optional` and the scanner fires immediately after `defn NAME`, takes
`[x]` as the body, and strands the real one. The scanner cannot distinguish
"before params" from "after params" on its own — the grammar has to withhold the
token, and `valid_symbols` is the channel that does it.

**Measured** (baseline → after): swallows **5 → 2** · error-bytes 4.6% →
**2.7%** (−21,432 B, 41% of the remaining mass) · clean files 27 → **29**.
Cleared `ppn-track2b`, `1A-iii-probe` and `narrowing-demo` — all three of the
files whose first failing line was a same-line `defn`.

**Method note**: the shape probes were green for the *reverted* formulations too.
Only the swallow count separated a fix from a catastrophe, and it separated them
by a factor of twelve (2 vs 24). On this grammar, locality is not a nicer
headline — it is the only measurement that distinguishes the two outcomes.

<a id="p5g"></a>
### 5.P5g - inline paren match arms (`fio`)

`match h (mk-handle idx -> ...)` - arms written inline in parens, the sexp arm
spelling used inside a WS file. This was fio's 51% swallow.

**Why precedence could not fix it.** Three rules claim `( ... -> ... )`:
`paren_expr`, the arm, and `defr_rule`. But the blocking ambiguity is not that
outer choice - it is the INTERIOR: at `(true ...` the parser must decide between
`atom` and `literal_pattern`, and the only distinguisher, `->`, is arbitrarily
far ahead. That is an LR(1) problem; a `prec` on the arm cannot reach it. The
earlier attempts produced a cascading conflict family, exactly as recorded.

**The fix - unbounded lookahead in the scanner.** `_arm_lparen` is a `(` emitted
ONLY when the matching `)` has a `->` before it at depth 0. Strings and comments
are skipped so an arrow inside them cannot decide it. `paren_expr` then begins
with a DIFFERENT TOKEN, and the interior ambiguity is gone by construction
rather than by precedence. `prec(10)` remains but now does only the narrow job it
can: arm-arrow vs `arrow_op`-as-atom after the `->`.

**The bug that made it look like a failure**: the scanner is entered wherever the
parser stopped, which for `match h (...)` is the SPACE before the paren, not the
paren. The first version tested `lookahead == '('` immediately, never fired, and
every probe still read 2 errors against a cleanly generated grammar. Skip
horizontal whitespace first, with `skip_ch` so it stays out of the token.

**Measured**: swallows **2 -> 1** - worst **51% -> 31%** - error-bytes 2.7% ->
**2.6%**. fio's own worst error 1,852 B (51%) -> **156 B (4%)**, total 1,908 ->
212: an 89% reduction, all remaining damage local.

**This is the second time the scanner solved what rules could not** (P5f the
first). The pattern is explicit: when the disambiguator is arbitrarily far from
the decision point, no rule or precedence helps, and the external scanner - which
may look ahead without bound - is the right layer. Reach for it FIRST next time,
not after three rule formulations.

Residual in fio: `foreign racket "..." [name :as alias : Type -> Type]`, 3 errors
per line. Separate gap, logged below.

<a id="p5h"></a>
### 5.P5h — `impl` paren type args (and the map-literal attempt, reverted)

**`impl Lattice (Map K V)`** — a parenthesised type argument. `impl_form`'s type
was `repeat1(choice(identifier, grouped_type))` and `grouped_type` is `[…]`
only, so paren args had no rule. Only **8** corpus lines use the shape; one of
them detonated the 8,024-byte swallow.

⭐ **The diagnosis is the story.** The ERROR node started at line **524**; the
cause was at line **263** — 260 lines earlier. No amount of reading the error
site could have found it, and the leading-token clustering pointed at `impl`,
which is only where recovery happened to begin. **Delete-window bisection on the
FULL file** found it: deleting lines 260–339 collapsed the error while every
other window left it intact. This is the method correction from earlier in the
track paying off — prefix truncation would have manufactured a cut-point error
and pointed somewhere else again.

⚠ **Two probes were CONFOUNDED and briefly sent me wrong**: I compared
"paren type + `where`" against "paren type, no `where`" while also varying the
BODY (`{}` vs `x`). The `where` clause was innocent; the real second finding was
that `{}` fails. Vary one thing.

**Result: swallows 1 → 0** · worst single error 31% → **13%** · error-bytes
2.6% → **1.8%** · clean files 34. **No file in the corpus now has a single error
covering 20% of it.**

**REVERTED in the same phase — map literals.** `{}` and `{:name "alice"}` have
no rule at all (`{` was only ever `implicit_params`), and **644 corpus lines**
contain one, so it looked like the next big win. Added, all shapes parsed, and
implicit params still worked — but measured: **swallows 0 → 2**, error-bytes
1.8% → 3.7%, MISSING 75 → 154. Reverted.

⭐ **The tell held again.** `{` is already claimed by `implicit_params`, so this
is a CONTESTED shape, and contested shapes resist rule-shaping — exactly like
same-line `defn` and `fio`. The uncontested additions this session
(`type_arg_group`, `angle_param`, `=`, `defr`, operators, `string`) all landed
first try. Map literals need the same treatment same-line `defn` got: a
disambiguation, not a rule. Logged in §6.

<a id="p5i"></a>
### 5.P5i — map literals, and the contested-shape recipe applied a second time

`{}` and `{:name "alice"}` — **644 corpus lines**, no rule at all: `{` was only
ever `implicit_params`.

**The plain rule regressed catastrophically** (measured in P5h and again here):
swallows 0 → 2, error-bytes 1.8% → 3.7%, MISSING 75 → 154, with
`arithmetic.prologos` going **28 B → 2,894 B** and `equality.prologos`
**26 B → 1,779 B**. Neither file contains a map literal — this was a global
error-recovery collapse, the same signature the rejected same-line-`defn` rules
produced.

**The fix is the same recipe as P5f: make the two `{`s two TOKENS.** A scanner
token `_map_open` consumes a `{` only when its next non-space character is `:`
(a keyword key) or `}` (empty map). Implicit params always open with an
identifier, so no parser state ever has to choose.

| | plain rule | `_map_open` |
|---|---|---|
| swallows | 0 → **2** | 0 → **0** |
| error-bytes | 1.8% → 3.7% | 1.8% → **1.7%** |
| MISSING | 75 → **154** | 75 → 76 |
| ERROR count | — | 3528 → **3087** |

⚠ **The bug that made it look inert at first**: the external scanner runs
*before* `extras` are skipped, so `lexer->lookahead` at entry is the SPACE after
`:=`, not the brace. The token never fired and the `{` came back as a
one-character ERROR. Skip spaces/tabs first — but never newlines, which belong
to the INDENT logic. `_same_line_body` needed the same care.

⭐ **The contested-shape recipe now has two data points and a name.** When a
shape is claimed by an existing rule, do not shape rules — **split the token in
the scanner on one character of lookahead**, so the parser never chooses. Used
for same-line `defn` (P5f) and map literals here. Both landed with no conflict
declarations; both had rule-shaped predecessors that collapsed recovery.

---

## 6. Deferred / discovered

- Spaced `*` in Sigma types (`<(x : A) * B>`) — pre-existing, absent from lib.
- `defr` bare-head `&>` continuation form (paren-goal form works).
- `:laws` blocks inside traits (`- :name/:forall/:holds`) — the `:forall` cluster.
- `foreign` with `:as alias : Type -> Type` inside the bracket group - fio's residual.
- Two-segment qualified names `a::b` (three-segment ones are fine).
- `<(Type 0)>` — parenthesised type inside an angle type. A naive `paren_type` did NOT fix it (see §5.P3b); needs real diagnosis.
- `[x : Bool y : Bool]` — SPACED typed params, several in one list: `type_application` greedily takes `Bool y`. The fused `[x:Int]` form is fine.
- `do` bindings (`[do [x := 1] x]`) — 1 → 2 errors after P2; pre-existing, absent from lib.
- `clean` file count is still 18/142: most files carry several of the remaining
  gaps, so files only go clean when the LAST gap in them lands. Error-bytes is
  the metric that moves in the meantime.
