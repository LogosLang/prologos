# CIU 6 — D4, §5.P4e-1b-v

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 11226–11578 are lines N-11219 here.

---

##### §5.P4e-1b-v — WHAT SHIPPED  (A → B1 → B1b → B2a → verify, 2026-08-13)

**`*_` IS LIVE in the three bands that spell it.** Measured:
`mn{a*_}` → `{:a-x 1}` · `cfg{database*_}` → `{:database-pool-size 10,
:database-url "u"}` (**[Q_U24]'s own motivating example**) · `mn.a*_` →
`{:a-x 1}` · `regions{eu*_}` → `{:eu-port 80, :eu-host "e"}` (**[Q_U51]'s table
row**) · `rmdup:cfg*_` → `{:us-x 2, :eu-x 1}` (**the capability Q_U51 calls the
whole point** — per-content prefixes keeping a SHARED `:x` apart, where bare `*`
must refuse) · `rowsn:cfg*_` → refused, positional ([Q_U41]).
The CLOSER-ADJACENT band is still `Unbound variable` — that is **B2b**'s.

| slice | content | gate |
|---|---|---|
| **A** ✅ `317ae5af` | The instrument. The arrival matrix could not SEE the spelling it verifies (exact-lexeme gate + a bare `*` hardcoded in all 11 carrier sources); now templated per spelling with the CONTROLS asserting a DECLARED outcome. ⭐ The controls were the real defect: they passed "must be 0" because the gate returned `#f` when there was no star token AT ALL, so "correctly does not mint" and "I cannot see this token" were one observation. Mutation-tested: the old gate makes them report *"EXPECTED symbol, saw none"*. Also: ran the four pre-written 1b-v pins BEFORE touching them and found ALL FOUR unusable. | `*` 209/209, `*_`/`*-`/`*-_` 0/209 — the pre-mint RED, visible for the first time |
| **B1** ✅ `2625b38f` | The cont channel, INERT. The closer-adjacent band never called `split-star-lexeme` and hardcoded `'flatten` in both legs. The family lives as ONE table in `reader-forms.rkt` (bidirectional — `unmint-star-for-echo` and both quote lowerings must render the lexeme the USER WROTE); ten dispatch sites delegate to one predicate. ⭐ Ordering is the design: widening the reader FIRST would make `x{a b}*_` silently MEAN `x{a b}*`. | inert E2E across every band; **liveness proved by mutation** — flipping the table's cont moves the closer band ONLY, the dot band unchanged |
| **B1b** ✅ `d09d4a49` | The `*_` join in both twins, INERT. The signature change `*` never needed: both twins discarded the layer's keys. Separator defined ONCE in syntax.rkt (shared with `^-_` per [Q_U24]). | mutation-tested PER TWIN — ⭐ and doing it properly found MY OWN pin structure masking a twin (one `test-case`, rackunit aborts at first failure, so mutating both twins gave ONE failure) |
| **B2a** ✅ `161e8bc1` | The shield removed; `keys` threaded, and `#f` IS [Q_U41]'s refusal condition carried in the data. | ⚠⚠ **THE TWINS DISAGREE ABOUT WHAT A KEY IS** — type rows are keyed by SYMBOLS, value champs by `expr-keyword` STRUCTS. `star-nominal-join-*` never noticed because bare `*` passes keys through untouched; `*_` is the first operation here that READS one. WHOLE-FILE ABORT. ⭐ The B1b direct-call pin did not catch it because it built champs with SYMBOL keys — **a shape production never produces**. The E2E probe caught it in one run. |
| **verify** ✅ `b12d02ed` + `cb555002` | `wf_fc98d241-4e5` — 29 raw → 16 survivors, 3 killed (one on the adjudicator's own re-measurement). 12 fixed; 4 filed as [DEFERRED 129–132](../../../../DEFERRED.md). | suite **10217/488/0** |

**⭐⭐ THE VERIFY'S ANSWER TO THE STANDING QUESTION: YES, SIX TIMES** — and in
three of them a comment IN THE TREE asserted the sibling was safe, including one
in B2a's own commit body (*"`star-synth-positional`'s message now MEANS what it
says"*) and one in a test comment beside it. The three MAJORs:
· **S1** — ONE message served TWO producers whose truths are COMPLEMENTARY, so
  each falsified a different half of one sentence and one falsified the REMEDY: a
  KEYED row was told "no keys to draw from" with its key right there, and a
  nat-domain layer was told "use bare `*` to flatten positionally" while bare `*`
  joined it KEYWISE in the same run. ⭐ The adjudicator CORRECTED a lens on the
  fix: threading `keys` into the sibling arm is not the cure ([Q_U49] keeps a
  vector join one keyless component), so the KIND is split — no key to prefix
  WITH vs no FIELDS to prefix — and both now render the LAYER, which this was the
  one star kind not to do.
· **S2** — the ω branch tested the cont in its FIRST sub-arm only, so five
  siblings handed `*_` bare `*`'s message VERBATIM (`homog:cfg*` and
  `homog:cfg*_` were BYTE-IDENTICAL). ⭐ Fixed with ONE arm at the branch head,
  not five: an ω layer IS a `PVec`, so Q_U41 holds for every sub-case.
· **S3** — `*_`'s collision reported bare `*`'s reason, which the same run
  disproves (the contents carry DIFFERENT keys and bare `*` joins fine). The
  value twin got a synthesis-specific escape at B1b and the USER-FACING type twin
  did not.
Also: **`star-nominal` RETIRED** — zero producers, and its message still said the
synthesis rule "is not yet ruled". ⭐ It stayed green because the battery's render
loop PRODUCES every kind by hand — **rendering a kind proves nothing about
whether anything produces it**. And **two landmines sitting directly under B2b**:
the PARKED pin's invalid `\*` escape (unparking it would make the battery fail to
READ) and `p4e1-star-class`'s identity test (a genuine `*_` leak would classify
`'gone` and PASS — the one gate the name-prefix trick cannot rescue).

⚠ **THE INSTRUMENT'S OWN HEADROOM IS BEING SPENT FAST.**
`test-path-selection.rkt` measured **145.5s** at the end of this arc, against
121.9s two arcs ago and the 300s limit `a4cbe7b8` installed. Battery 539 → 550.
At ~24s per slice the headroom bought at `a4cbe7b8` is ~6 slices, not indefinite.

<a id="p4e-1b-v-b2b"></a>

##### §5.P4e-1b-v-B2b — the mint: grounding + the ruling it produced  (2026-08-13, `wf_7f5bda0c-500` — 5 facets + completeness critic; every load-bearing claim R-lens-verified in the main session)

**Ruled as [Q_U53](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u53).** This section carries the evidence the ruling rests
on. ⚠ The audit ran at `96ef73f0`, two commits past its `66db7703` pin (both are
path/hook repairs touching no audit-relevant file); the critic flagged the drift
itself, which is the behaviour the HEAD-pin discipline exists to produce.

**⭐⭐ THE FACT THAT REFRAMED THE QUESTION, AND NO FACET STATED IT — the critic
did.** `$postfix-star-synth` **has ZERO producers anywhere in the tree.**
Verified: the table row (reader-forms.rkt:269), one comment (:258),
`tools/form-deps.rkt:48`, and six test pins. No emit site. Meanwhile all TEN
production consumers of `postfix-star-sentinel?` (parser.rkt:421, :652, :1506;
macros.rkt:1175, :5183, :6954, :6985, :7049, :7864, :7913) handle it for free
because the predicate is table-driven. **The downstream is fully wired and the
upstream is empty**, so B2b's emit would be the FIRST AND ONLY producer — which
makes the miss-case not a behaviour change to an existing path but *the initial
contract of a path that does not yet exist*.

**⭐ AND THE THREE "LIVE" BANDS NEVER TOUCH THE TABLE.** `*_` works in the fused,
`$dot-access` and ω bands via `split-star-lexeme`, which maps the suffix AFTER the
star straight to a cont and never consults `postfix-star-sentinel-table`. Measured
in one file at HEAD:

| band | source | authority | result |
|---|---|---|---|
| fused | `mn{a*_}` | `split-star-lexeme` | ✅ `{:a-x Int}` |
| closer-adjacent | `mn{a}*_` | the sentinel table | ❌ `ERROR: Unbound variable` |
| control | `mn{a}*` | the sentinel table | ✅ `{:x Int}` |

**THE DRIFT TABLE — what a half-done 1b-vi produces** (the argument for Q_U53
part 2; sites numbered as in the ruling's table):

| edited | not edited | what the user gets |
|---|---|---|
| site 1 | site 2 | `cfg{db}*-` collapses; `cfg{db*-}` refused — **the same operator working in one band and refused in another** |
| site 2 | site 1 | the mirror image |
| 1 + 2 | site 3 | works; `form-deps` gains a spurious cross-form edge |
| 1 + 2 + 3 | site 4 | works; **the arrival matrix reports `*-` at 0/209 and calls it covered** — DEFERRED 127 reoccurring in the tool built to prevent it |

Rows 1–2 are the one-seat-not-its-sibling shape that has produced a blocking
defect in FOUR consecutive verify rounds on this phase.

**FOUR ENUMERATIONS THE AUDIT FOUND WRONG, three of them ours:**
· **[DEFERRED 129](../../../../DEFERRED.md)'s "keep ONE token type … the compat remap" names
  ONE site; there are NINETEEN** — 3 production (parse-reader.rkt:2089, :2341,
  :2590), 2 TOOL (`tools/star-arrival-matrix.rkt:193`, `:217`), 14 battery rows.
  ⭐ The two tool sites are the ones that bite: DEFERRED 127 widened that
  instrument's LEXEME test to `star-spellings` and left its TYPE test bare, so a
  token-type split silently re-blinds the mint verifier.
· **Q_U52 §3's "all five `select-star-cont` readers" is SIX, and was wrong when
  written** — corrected in both carriers (see Q_U52's own note).
· **`parse-reader.rkt:2339-2340` calls `tools/golden-capture.rkt` "the sole
  non-test consumer" of the compat token type.** It is not —
  `benchmarks/micro/bench-ppn-track1.rkt:117` reads `(token-type tok)` too
  (verified on the main thread after the critic flagged it UNVERIFIED). Display-only
  and harmless, but the enumeration under-counts and will under-count again.
· **A FOURTH family copy nobody had named**: `tools/form-deps.rkt:48`. No facet's
  grep shape found it — it is neither a lexeme table nor a type switch. Its own
  comment already anticipates B2b and was deliberately kept AHEAD of the mint.

**AND A PRECONDITION FOR B2b's OWN TESTS** — [DEFERRED 133](../../../../DEFERRED.md): the
battery helpers `p4e-star-type` / `p4e-last-star-type` are exact-lexeme `"*"`, so
they return `#f` on a `*_` source and **cannot tell "correctly did not mint" from
"I cannot see this token."** That is verbatim the DEFERRED-127 defect, one layer
down; the repair landed in the tool and never propagated to the suite. Any B2b row
written with these helpers has no power until they are widened.

<a id="p4e-1b-v-c"></a>

##### §5.P4e-1b-v-C — THE FOLD: one semantic authority  (pins `24fc1be4` · the fold `a492bbb7`, 2026-09-08)

**Ruled by [Q_U53](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u53) part 2 and [Q_U54](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u54).** Grounding
`wf_8c8b9fc2-54b` (5 facets + critic); verify `wf_34ba9e6b-dea`.

**WHAT CHANGED.** `split-star-lexeme`'s two suffix arms (`""`→flatten,
`"_"`→flatten-synth) — a second copy of the spelling↔cont pair serving the
fused/dot/ω bands — became ONE clause: reconstruct the operator lexeme
`(string-append "*" k)`, ask `postfix-star-lexeme->sentinel`, take its cont.
The `^`-guard stays above it; the `[else]` is untouched. The PRINTER's star arm
(`(if (eq? cont 'flatten-synth) "*_" "*")` — the **fifth encoder** the ruling's
"four sites" had missed, user-facing through every star refusal label) asks the
table via a new `postfix-star-cont->lexeme`, rendering an unknown cont LOUDLY as
`«unrendered-star-cont:…»` instead of a silent `*`. `tools/form-deps.rkt`'s
`syntax-keywords` DERIVES the star family from the table — correct BY
CONSTRUCTION (`(map car table)` is the two removed literals). ⚠ **The "report
byte-identical old vs new" I first offered as evidence is a ZERO-POWER
instrument** (the verify measured identity even with `syntax-keywords` EMPTY:
the report prints counts, and references are consulted only under a
module-level SCC, of which there are none). Step A (`24fc1be4`) had already
exported `star-spellings` so the battery PINS site 4 (never derivation — that
list is a superset by DEFERRED 127's design) and widened the tripwire to
`reader-forms.rkt`.

**⭐ THE LIVENESS PROOF IS AN ASYMMETRY, MEASURED TWICE.** Flip the `*_` row's
cont to `flatten` in the table (the "`*_` silently means `*`" mutant):
BEFORE the fold → **4** red cases (the table pin, the two closer-band pins, the
printer pin); AFTER → **14**, none vanished — the ten new reds are every
fused/dot/ω `*_` pin (C-1, C-4, C-6a/b, the B2a E2E and refusal pins) and the
printer's render pin. Same operator, ONE authority, every band. Reverted
byte-identical under a checksum each time; a real rebuild forced each time.

**PINS FIRST, AND THEY WERE MOSTLY ABSENT.** The grounding found six band×spelling
cells with ZERO pins and the "byte-identical messages" obligation unenforced.
Step A (`24fc1be4`) pinned all six at baselines MEASURED this session and every
refusal message in FULL, one cell per test-case; plus the printer's containment
(C-8) and the matrix's (C-9). ⭐ **A facet was wrong about C-5**: it said
`x.a^*_` takes the star splitter's guard; measured, the top-level dot band's
caret arm comes first and it takes the CARET guard — guard routing is per band
and is now pinned as measured (C-7c makes the fused band's interception
explicit).

**WHAT THE GROUNDING CORRECTED, ours again**: "no test requires a `tools/`
module" (B2b step 1) — five do, and the battery itself has required the matrix
since 1a-i; my grep was single-line-blind. Q_U53's "sites 3 and 4 get pins,
never derivation" over-generalized DEFERRED 127's reason to a list that wants
exactly the names — amended in Q_U54. The two tools are not alike: the matrix is
a library, `form-deps` a SCRIPT whose `command-line` runs at module level (a
battery require breaks `batch-worker` — measured by the audit).

**THE VERIFY (`wf_34ba9e6b-dea`, 4 lenses + adjudicator): NO BLOCKING FINDING** — the
splitter proven at the FUNCTION boundary (a 26-lexeme differential against the
old arms, all `SAME`), the `.pnet` round-trip `eq?`-stable, no abort path. ⭐ **The
standing question answered outright: the one-seat-not-its-sibling shape appeared
ONLY BY OMISSION, in the TEST TIER** — the new loud tell and the accessor's `#f`
miss had no pin while their sibling marker `«unrendered-step-kind»` is pinned
both ways; a regression back to a silent `*` would have passed. Pinned as C-10 /
C-11, power proven by mutating the printer arm back. **The enumeration of what
remains hardcoded, restated without "exactly"**: the five typing/reduction
`select-star-cont` readers (silent bare-`*` on an unknown cont — 1b-vi's
totality dispatcher); **`typing-errors.rkt`'s PROSE column — 15 formatters whose
sentences spell `*`/`*_` per KIND while the LABEL beside them is now
table-driven — the printer defect's twin one seat over, true today, live at
1b-vi exactly as the printer would have been; it belongs in 1b-vi's totality
inventory**; `reduction.rkt`'s two `oops` strings; the two DEFERRED-130 arms'
`(string=? lex "*")` selectors (ruling-derived, deliberate); the matrix's
`star-spellings` (a tool literal, pinned); the battery's regex (wider by
design); the grammar ([DEFERRED 144]). And the CARET family carries the
identical two-copy shape (parser literal arms ↔ pretty-print's `cont->string`
with a silent `[else "^?"]`) with no table — filed as [DEFERRED 145](../../../../DEFERRED.md).

Battery **571 → 573** · matrix `*_` 209/209 unchanged · acceptance `--check`
88/88 ([90] ≡ [91], now through ONE authority) · suite **✅ **10248 / 488 / 0**, 189.0 s**.

<a id="p4e-1b-v-b2b-shipped"></a>

##### §5.P4e-1b-v-B2b — WHAT SHIPPED  (step 1 `862fc7e3` · the mint `940c9c88`, 2026-09-08)

**`*_` IS LIVE AT THE CLOSER-ADJACENT SEAT.** Both parked pins now hold:
`regions:{host port}*_` synthesizes `:eu-host … :us-port` ([Q_U51]) and
`rowsv:{tags}*_` refuses naming `*_` ([Q_U41]). The arrival matrix reads **`*_`
209/209** (was 0/209 — the deliberate RED), **`*-`/`*-_` still 0/209**, every
control asserting its declared outcome. Acceptance 0 errors, markers 0–88 — and
**§L appended (markers 90–93)**: L1 (closer seat) and L2 (fused band) print
**byte-identical** answers for the same subject — the two authorities' agreement,
now measured in the acceptance file rather than asserted — plus [Q_U51]'s ω form
`regions:{host port}*_` and the bare-`*` contrast. ⚠ **[DEFERRED 144]**: the
tree-sitter `flatten_step` is a bare `*`, so the closer-seat `*_` mis-parses in
the editor; §L puts it in the corpus, which makes the gap MEASURABLE by
`check-corpus.sh`. Filed for X.close (1b-vi changes the token again), per the
grammar rule's "or file a DEFERRED entry saying why not".

| step | content | gate |
|---|---|---|
| **1** ✅ `862fc7e3` | [DEFERRED 133] — the battery helpers widened to a star-operator REGEX (not a fifth spelling list), reporting `'none` not `#f`. | RED first (`actual: #f`); ⭐ the power-check caught a VACUOUS pin in the new rows and it was replaced with one measured `OLD=postfix-star NEW=symbol`. 550 → 553 |
| **2** ✅ | the instrument RUN RED: `*_` 0/209. | on record before any edit |
| **3+4** ✅ `940c9c88` | ONE conjunct: `(string=? lexeme "*")` → `(postfix-star-lexeme->sentinel lexeme)`; the emit the SAME call on the SAME entry. No fallback, no raise ([Q_U53] part 1). [DEFERRED 130] rides: both refusal arms render the lexeme the user wrote — bare-`*` text BYTE-IDENTICAL, the multiplication clause rendered for `*` alone (it is a fact about `*`, derived from the ruling, not the example). | RED first — **5 FAILURES / 0 ERRORS**, each case red for its own reason, then 559 all-pass |
| **5** ✅ | the 1b-v pin block UN-PARKED as TWO test-cases (lesson #3: one case lets a red synthesis pin mask the refusal pin). | both green at first run |

**THE CANARY [Q_U53] ASKED FOR, and where it lives.** Four test-cases on the
**same token entry**, through the exported `token-entry->stx`: the gate mints
every table lexeme · the emit produces each lexeme's OWN sentinel · an
unreserved spelling (`*--`) neither mints nor becomes a sentinel. ⭐ Sharper than
a full `read-all-syntax-ws` read, which would need a driver export and — worse —
sees the form AFTER preparse has fused the sentinel away ([Q_U37]), so the
identity under test is already gone.

**MUTATION-TESTED, and it is DEFERRED 129's exact shape.** Emit hardcoded back
to `'$postfix-star` with the gate left widened, checked against LIVE source under
a checksum: `cfg{a}*_` → **gate=`postfix-star`, emit=`$postfix-star`** — the
`x{a b}*_`-means-`x{a b}*` wrong answer, by the emit route. The canary's emit
half goes red there while its gate half stays green: independently powered.
Revert byte-identical; `parse-reader`'s `.zo`/`.dep` deleted afterward so the
rebuild is REAL and not the SHA short-circuit's guess about a moved timestamp.

⭐ **THE DEFERRED-108 "IT WILL GO RED" CLAIM IS FALSE — a verify finding is a
hypothesis too, for the FIFTH round running.** The snapshot did not move:
`star-cell-source`'s spelling parameter DEFAULTS to `"*"` and the battery's gate
passes three arguments, so that gate has only ever seen bare `*`. It was measured
rather than pre-emptively re-baselined, which is the only reason the record now
says the true thing.

Battery **553 → 559**, `--tests` PASS 101.2 s (the file is holding at ~101 s —
the instrument-headroom worry from the 1b-v close has NOT worsened this slice).
Suite: **✅ **10230 / 488 / 0**, 172.1 s**.

<a id="p4e-1b-v"></a>

##### §5.P4e-1b-v — the grounding audit  (2026-08-13, `wf_cc1a72a0-75b` — 4 facets + a completeness critic that had to be RE-RUN after the first crashed)

⭐⭐ **THE AUDIT MOVED THE SLICE IN BOTH DIRECTIONS, and the critic moved it more
than the facets did.**

**SMALLER THAN Q_U39 FRAMED IT.** `*_` is **already fully parsed** and already
reaches a dedicated, operator-naming refusal in **three of the four bands** —
`split-star-lexeme` returns `'flatten-synth`, and the fused, `$dot-access` and ω
bands all thread that `cont` into `make-select-star`. **Only the closer-adjacent
band is deficient, and it never calls the splitter at all**: `parser.rkt`'s
`$postfix-star` arm hardcodes `'flatten` in BOTH legs. So the mint is a TWO-SITE
change (the reader gate, that parser arm), not "mint a new operator".

**⚠ DEFERRED 124's MECHANISM IS WRONG — verified on the main thread, not taken
from the report.** It records that `x{a b}*_` "lexes as `*` applied to `_`".
MEASURED through `tokenize-string`: it is **ONE symbol token `*_`**. `*` is
`ident-start?` and `_`/`-`/`*` are all `ident-continue?`, so `recognize-symbol`
swallows the lot. Independent confirmation by a second route: `mn{a}* _` (spaced)
gives *"Could not infer type"* — the star DOES mint and a lone `_` lands in
argument position — while `mn{a}*_` gives *"Unbound variable"*. Different errors,
therefore not the same parse. **The conclusion in 124 stands; the cause does
not** — and it changes the fix, because relaxing the gate's lexeme test is then
SUFFICIENT and no token-splitting is needed.

**⚠⚠ AND THE FACET'S HEADLINE FOOTGUN IS FALSE AT HEAD — I repeated it to the
owner before the critic tested it.** The facet marked "verified" that each new
bare sentinel MUST join `pattern-var?`'s exclusion list or a `defmacro` template
raises out of preparse (the whole-file-abort class). Its evidence was the comment
block above `pattern-var?`. **That comment is stale**; the structural fix landed
2026-08-01 (`datum-subst` asks whether the symbol is a DECLARED macro parameter,
so an unbound one passes through). MEASURED: `defmacro lit [] '[1 2]` + `[lit]`
⟹ **0 errors**. ⭐ `.claude/rules/pipeline.md` ALREADY carries this correction,
including the sentence *"macros.rkt's own comment above `pattern-var?` still
carries the stale claim"* — so the ambient rule was right, the facet quoted the
stale artefact, and I relayed the artefact. **A stale in-code comment outranked a
corrected ambient rule in my own reading.** This removed the loudest argument
against N-bare-sentinels, from the wrong side of the ledger.

**THE CENSUS WAS ENUMERATING THE WRONG THING.** The count (15 production lines)
is right, but 2 are *emits* and 1 a table entry — and emits cannot MISS a new
spelling, they re-emit whatever already matched, so they fail differently.
⭐ More importantly the census enumerated the sentinel **NAME**, while three
hazard sites key on the **CHARACTER**: `recognize-broadcast-access`,
`tree-parser.rkt`'s WS-mode Sigma detector (the twin of `parser.rkt`'s Q_U31
angle refusal, keyed on lexeme rather than sentinel), and `recognize-dot-access`'s
"not `.*`" guard.

**⭐ A LIVE COLLISION NOBODY HAD NAMED**, and it is the character-level census
that found it: the retired-broadcast recognizer **already owns** `.*_` and `.*-`
— MEASURED, `rv.*_` ⟹ *"broadcast `.*_` was retired — its replacement is `:_`"*.
[Q_U26](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u26) rules ravel to be bare `.*`, so if the star's continuation
grammar is `{"" _ - -_}` then `.*_` is ravel-with-synth and today emits a message
about a feature retired for unrelated reasons. **[DEFERRED 125].**

**THE ANGLE BAND IS A FOURTH CARRIER OF DEFERRED 124's DEGRADATION** (measured):
`<(x : Nat)*_ Nat>` ⟹ *"Unbound variable"*, where the bare form takes Q_U31's
guided refusal. **[DEFERRED 126].**

**⚠⚠ THE INSTRUMENT IS WORSE THAN BLIND — it would report FULL COVERAGE of a
question it had stopped asking.** `tools/star-arrival-matrix.rkt` gates on
`(string=? (token-entry-lexeme …) "*")` — the same exact-lexeme shape as the mint
it exists to verify — AND its 11-carrier table hardcodes a bare `*` in every
source string. After a widening it reports 190/190 covered and 0 cells for the
new spelling, silently. ⭐ Its CONTROLS are the sharper half: they pass because
`star-last-token-type` returns `#f` when there is no `*` token at all, so **the
instrument cannot distinguish "correctly does not mint" from "I cannot see this
token"** — which is exactly the distinction the widening turns into the whole
question. **[DEFERRED 127].**

**⭐ A NAMING DECISION THAT IS CHEAP NOW AND EXPENSIVE LATER.** The leak gate and
four sibling pins match an **unanchored substring** `#rx"\$postfix-star"`, so
naming the new sentinel `$postfix-star-synth` keeps five gates covering it for
free; any other name silently narrows them. `p4e1-star-class` is an identity test
and needs the new name regardless. Ruled into [Q_U52](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u52).

**RULINGS THAT HAVE DIVERGED FROM HEAD, and 1b-v would inherit all three:**
· **[Q_U42](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u42) diverges in BOTH its examples**, not just the headline one —
  `rowsv:{tags}*` and the compose example `dcomp:{a}*` both take the
  `star-omega-nominal` refusal where the ruling claims an answer. Fixing "the one
  example" would leave the ruling still diverged.
· **[Q_U45](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u45)'s literal output text is stale** — it states `{:x 1, :y 2}`;
  HEAD prints `{:y 2, :x 1}`. The *equivalence* the ruling actually claims holds;
  only the printed order differs. ⭐ So **even a ruling's own example text is not
  a safe pin source** — "derive from the ruling, not the example" one layer down.
· **The pre-written 1b-v pin block** (commented out in the battery) has 2 of 4
  checks unexercisable (closer-adjacent) and **the other 2 STALE** — their
  regexes predate kinds 1b-iii/1b-iv minted (a backticked key; `star-content-collision`
  replacing "duplicate output key"). Uncommenting as-is gives 4 failures.

**AND A RE-BASELINE NOBODY HAS SCHEDULED**: the DEFERRED-108 snapshot pins 19
whole-file-aborting cells **as a set, compared whole**. A reader widening changes
which sources abort, so it will go red and needs a deliberate re-baseline — not a
bug, and it will look like one.

**`*-`, STRESS-TESTED AND SPLIT OUT** — see [Q_U52](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u52) for the ruling. The
critic could not falsify the "dissolve every ancestor, then `*`" equivalence on
any shape where BOTH sides are writable, which is the useful result: it converts
*"is this equivalent?"* into *"which shapes is `*-` even defined for?"* — a
question Q_U48 has not been asked. Two families where the dissolve route cannot
be written: a RENAMED ancestor, and a BROADCAST ancestor.

