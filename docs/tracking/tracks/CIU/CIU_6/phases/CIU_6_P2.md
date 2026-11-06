# CIU 6 — D4, §5.P2

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 5476–5744 are lines N-5469 here.

---

<a id="p2"></a>

### §5.P2 — Grade-1 core

**Intent**: `.k`/`.N` access + bare-path extraction — the spec's grade-1
fragment, on the P2 substrate.

**Grounded head start** (audit + probes): `.N` extraction works END-TO-END
today via a `(get expr N)` fold arm — `expr-get` types PVec (Nat-or-Int) +
Record/tuple(nat-row, EXACT per-position via `record-project`) + Map +
selection-fvar + schema-fvar + List, terminating `[_ (expr-error)]`
(typing-core.rkt:1861-1885); the two-tier principle makes misses loud.
*("site 7 projects" was an UNRESOLVABLE citation — corrected 2026-07-29. It
meant the P2.b round-8 audit's **site 7**, the `[map-get tup 1N]`
fabricated-`none` case closed structurally at `88d1f746`; it is a
predecessor-doc label, not a D4 §7.)* The fold target is `get`, NOT `map-get` (probe: map-get's infer has no
PVec leg). `.k` nominal access already works (dot-access → map-get fold).

**Work**: the `.N` recognizer (dot-anchored, prefix-disjoint inside the
**SIX**-member band {rest-89 · dot-key-88 · dot-lparen-87 · dot-lbrace-87 ·
broadcast-87 · dot-access-86} — ⚠ **this cite has now been wrong THREE TIMES**
(three → five → six); §Q8.1 is normative and was itself self-contradictory
until 2026-07-29. Per Q8.5 invariant 1 the safety property is
**disjointness, not priority**) · the nat-dot fold arm → `(get expr N)` · chain
forms (`admins.0.name`) · extraction typing = the existing arms (no new nodes
expected — flag if that breaks).

⚠ **Q_M8 — `.N` TAKES `digit+`, NOT ONE DIGIT.** Multi-digit ordinal access
is owner-ruled. It is not extra work: the same one-line `digit+` that admits
`x.10` is what kills the rational mis-lex, because a dot-anchored recognizer
consumes `.1` before `decimal-literal` (which anchors at a **digit**) can ever
anchor. `x.1.2` → `($decimal-literal 6/5)` and `x.10.20` → `51/5` at the
reader.

⚠ **"AND THAT FIXES A LIVE SILENT WRONG ANSWER … both at 0 errors" was a LAYER
ERROR — struck 2026-07-29.** End to end all three forms are **LOUD** (`ERROR:
Unbound variable`; `m.-1` → `Could not infer type`; 4 errors, re-probed at
`c5153685`) because the stranded bare `|.|` is unbound. See §Q8.1 for the
two-layer pin this forces. **Failing-test-first on the rational pair at BOTH
layers**, not just on `x.10`, and never framed as "was silently 6/5".

Clarification carried from Q8.1: `.-1` **lexes cleanly** as dot-access with
field `-1` (`ident-start?` admits `-`). A digit-required `.N` correctly declines
it, but the carried "`.-1` = classifier rejection" ruling is therefore about a
**well-formed token** and is a CONSUMER decision, not a classifier one.

#### Mini-audit `wf_22020418-a5f` — what it changed  (6 facets + critic @ `c5153685`)

**12th consecutive phase whose premise it refuted or rescoped.** The doc-truth
half landed separately (`0e5a56a3`, ruling Q_R6). What it changed about the
WORK:

1. **The sentinel choice was never ruled, and it sets the whole cost** → Q_R1
   (reuse `$postfix-index`). Both naive `$dot-access` reuses are broken: a
   numeric payload hard-raises (whole-file abort), a symbolised one silently
   mints the wrong node with the wrong key domain.
2. **The fold arm's fixpoint question is ANSWERED, not open.** The existing
   fold is a fixpoint *by construction* because no arm's output is
   sentinel-headed: re-entry is gated on the datum having CHANGED
   (macros.rkt:2527-2534) and the ormap gate short-circuits (:5537), so pass 2
   is a no-op. Every live arm emits `map-get` / `nil-safe-get` / `get` /
   `$retired-selection`, none of which matches any of the eight
   `access-sentinel?` predicates. **`(get target N)` inherits the property** —
   which is a second, independent reason Q_R1's reuse is the safe option, since
   P1b-iii's BLOCKING defect was exactly a non-fixpoint fold.
3. **`token-entry->stx`'s `case type` is the site that matters, and a miss
   there is SILENT** (parse-reader.rkt:2264; copy the `dot-access` template at
   :2265-2270). ⚠ Build the payload with **`string->number`**, not the
   siblings' `string->symbol` — that is what makes it byte-identical to
   `v[0]`'s bare fixnum and thus what makes Q_R1 actually hold.
4. **Two work items are FREE or already done.** "Chain forms
   (`admins.0.name`)" is free — chains arrive as flat top-level siblings and
   the existing single fold-left handles them in one pass. "Bare-path
   extraction" already works at top level, `def` RHS, HOF lambda, and spec'd
   `defn`; the ONLY gap is a `defn` with an UNANNOTATED param, which is the
   **§5.PX** inference family, not a `.k`/`.N` gap. §5.P2's Intent silently
   promised that; it does not deliver it and should not pretend to.
5. **The A/B diff set is predicted EMPTY** — zero non-comment `ident.digit`
   occurrences across all 160 tracked `.prologos` at HEAD, computed with the
   REAL tokenizer over a clean `git archive HEAD` snapshot. ⚠ **The dirty-tree
   trap is quantified in advance at exactly ONE site**:
   `lib/examples/foray.prologos:787` (`app-config[admins.0[name^ role^]]`),
   owner WIP, absent at HEAD. **If the A/B reports one diff in `foray`, that is
   THE TREE, not the change.**
6. **`rewrite-dot-access` has THREE production callers, not one** —
   macros.rkt:1957 (`preparse-map-literal-contents`, map-literal VALUES),
   :2527 (the re-entry), :6236 (`expand-mixfix-form`, the `.( … )` token stream
   before pratt-parse). A `.N` arm placed *inside* `rewrite-dot-access`
   inherits all three free; anywhere else silently misses `{:k x.0}` and gives
   "Unexpected token after expression" for `.(x.0 + 1)`.
7. ⚠ **A FALSE PREMISE in the predecessor is struck**: its D3-era prescription
   was "one fold arm plus **stopping that re-entrancy**". The re-entrancy is
   **LOAD-BEARING** — `v[idx.i]` → `20 : Int` works *only* because the payload
   is re-preparsed. Do not stop it. What it actually gets wrong is narrow (a
   LITERAL-headed payload, `v[1.b]`, folding to `(map-get 1 :b)`) and the
   result is an unguided error, not a wrong value.

#### Work (as ruled)

- **The recognizer**: dot-anchored, `digit+`, with the Q_R2 `ident-continue?`
  trailing guard; prefix-disjoint from all SIX band members (§Q8.1); priority
  87 or 88, placed in source order inside the dot cluster — but per §Q8.5
  invariant 1 the safety argument is **disjointness, not the number**. Use
  `(char<=? #\0 c #\9)` rather than `char-numeric?` (Unicode-wide vs
  `string->number`'s narrower domain — a NARROWING, so the F1b.7g rule
  permits it).
- **The token→datum arm** at `token-entry->stx` (site f), payload via
  `string->number`, minting `$postfix-index`.
- **No fold-arm change is expected** (Q_R1 reuse) — but VERIFY, and flag if the
  existing arm needs anything.
- **Q_R5's error surface**: un-gate `closed-row-miss-hint` for the nat
  key-domain so het-tuple out-of-range names arity and index instead of "Could
  not infer type"; and make the `postfix-hole` message spelling-agnostic (it
  currently gives bracket advice, which `_.0` would now reach).
- **NEW-instance guards P2 must not introduce** (the audit's "does P2 create a
  new instance" pass): `namespace.rkt:888`'s ns-dot guard raises only for
  `$dot-access`, so `ns foo.2` would **SILENTLY DROP** the segment —
  reintroducing exactly the bug `b0db8f3e` fixed. Extend its memq. Same class:
  `reconstitute-selection-paths`/`-path-list` (macros.rkt:2695, :2700) are
  `$dot-access`-only, so a WS selection path with an ordinal segment
  (`:items.0`) is not reconstituted — verify and fix or file.
- **Commit the corpus A/B harness.** There is NO committed harness; it is
  re-derived every phase, which is how P1b-ii's first run measured the tree.
  Two live footguns to encode: `tokenize-char-rrb` reads a MUTABLE registry
  populated only inside the reader entry points, so a direct call matches
  NOTHING (one facet's first scan returned a FALSE ZERO for exactly this — put
  a tripwire in); and the walker must skip leading-`.`/`~` basenames (a
  dangling Emacs lock symlink for the acceptance file exists right now).
- **§Q8.3 one-liner for P4** (forward obligation the audit found): the new
  `.N` token becomes the adjacency PREDECESSOR of a following `:name`
  (`xs.0:name`), so §Q8.3's FOCUS-BEARING token set must admit it or broadcast
  silently fails to fire at P4. One line now prevents a P4 rediscovery.

#### Named NON-goals and pre-existing exclusions (so P2 is neither blamed nor tempted)

- **`xs.0N`** — sensible-looking Prologos that the Q_R2 guard declines. Named,
  not missed.
- **`expr-pvec-nth` REJECTS Int literals on a nat-row while `expr-get` ACCEPTS
  them** (typing-core.rkt:2228-2235, deliberate and commented). After P2, `t.1`
  (→ `get`, Int OK) and `[pvec-nth t 1]` (Int → error) answer differently for
  the same subject. **Do NOT "fix" this** — `.N` routes through `get`.
- **`\.` is ALREADY mis-lexed** (`recognize-backslash-char` rejects `.`) and is
  the SOLE bare-dot token in the whole HEAD corpus (space-followed, so P2 does
  not touch it). `\.5` newly changes. Pre-existing; excluded.
- **`compat-tokenize-string` RAISES "Unexpected character: ."** on a bare `.`
  while the production path emits `|.|` silently (parse-reader.rkt:2136-2138).
  After P2 that raise stops firing for `.digit` inputs. Its sole dependent test
  uses a SPACED dot so stays green — but it is a bare `(check-exn exn:fail? …)`
  with no message match; tighten it while in the area.
- **DEFERRED items 1–8**: none are fixed by P2. **Item 8 must not be
  disturbed** — `pattern-var?`'s 23-of-33 residual (including `$list-literal`,
  so `'[1 2]` in a defmacro template is a whole-file abort TODAY); the ruled
  fix is INVERTING the predicate's polarity, not adding exclusions, and Q_R1
  means P2 adds no entry at all. Item 5 (`<`-adjacent grouper divergence, live
  at `foray.prologos:674`) is **P4's**, on the disclose surface.

#### Test delta

Failing-test-first, and the rational pair is pinned at **BOTH LAYERS** per the
§Q8.1 correction: (a) reader/datum pins (`x.10` · `x.1.2` · `x.10.20` — today
`($decimal-literal 6/5)` / `51/5`, after `(get (get x 1) 2)`), (b) end-to-end
pins framed *"was a misleading error, now computes the right value"* — never
"was silently 6/5". Plus: the four subject types (PVec / het tuple / Map /
List) in-bounds and out-of-range · **the `v[0]` ≡ `v.0` datum-identity pin**
(what makes Q_R1's "two surfaces, one mechanism" checkable rather than
asserted) · the Q_R2 guard's five declining shapes · the Q_R3 spaced-`.0`
ruling · `.-1`/`.+1` as a consumer decision · the fixpoint pin (once ≡ twice,
modelled on tests/test-path-selection.rkt:867-879 from P1b-iii) · the
lying-diagnostic repairs (`{:a m.0}` · `[fn [v] v.0]` · bare `m.0`) · the ns
guard · a both-modes census note (sexp is structurally unaffected — the sexp
readtable binds no `#\.`, and the sexp IR spelling for ordinal access is
already `(get x 0)`, so `.N` adds NO new divergence, unlike `.{`'s Q_L2).

⚠ **Probe trap the audit flagged twice**: `prologos-read` (parse-reader.rkt:3130)
is the **WS** reader. A "sexp mode" probe routed through it silently measures WS
and manufactures a phantom divergence — use `prologos-sexp-read`.

Corpus: `m.0` moves out of the §10.6 v2 block (Q_R4) and trailing markers land
before line-118's 23-renumber edit. Status: ⬜.

#### CLOSE NOTES ✅ `3005170b`

**Gates**: suite **9370 / 475 / 0** (from 9304/474 — +66 tests, +1 file) ·
acceptance path-selection **35/35** (from 28) + records **89/89** ·
neighborhood battery **558 / 16 files** · reader corpus A/B **158 files, ZERO
diffs**, both legs pinned to identical HEAD content. The audit PREDICTED an
empty diff set and it held, and its quantified dirty-tree prediction held too:
the one site a working-tree A/B would have flagged is `foray.prologos:787`
(owner WIP, absent at HEAD), which does read differently under `.N`.

**Shipped**: the `recognize-dot-ordinal` recognizer (`digit+`, Q_R2 guard,
ASCII-digit gate, priority 87 by disjointness) · the `token-entry->stx` arm
minting `$postfix-index` with a `string->number` payload · Q_R5's ordinal
miss-hint · the `namespace.rkt` new-instance guard · a spelling-agnostic
`postfix-hole` message · plus two pieces of committed infrastructure the track
had been re-deriving by hand (below).

**⚠ THE ADVERSARIAL VERIFY CAUGHT A DIAGNOSTIC REGRESSION I INTRODUCED** — 5th
behavioural slice running, and still nothing a green suite could see.
`ordinal-key-index` accepted ANY `expr-int` including NEGATIVE, dropping the
`exact-nonnegative-integer?` half of the guard it mirrors
(`record-project`'s literal-nat leg) — the **infer/inferQ-twin drift shape**.
Because the ordinal branch sits FIRST in `closed-row-miss-hint`'s `or`, a
negative literal produced a hint asserting an expression was out of range when
that expression **type-checks fine** (`record-project` routes a negative literal
to the dynamic path, which succeeds as the union of positions) — *and* that
false hint SUPPRESSED the correct keyword closed-row-miss hint on the same
expression. Strictly worse than the message it replaced.
The adjudicator **worktree-pinned a baseline and A/B'd**, which is what turned
this from "a gap" into "a REGRESSION" and made it commit-blocking. It is
unreachable from `.N` (which cannot lex a sign) and from `het[-1]` (the
`postfix-neg` marker intercepts) — the reachable surface is the paren-keyword
form `(get het -1)`, which is **exactly why no `.N` test caught it**. Fixed +
3 pins.

**Two more verify fixes**: the `token-entry->compat` sibling arm (**four lenses
found it independently** — the token fell through to `|.10|`, contradicting both
its dot-band siblings and Q_R1's numeric payload) and `closed-nat-row?` used
instead of hand-inlining its three-way conjunction.

**⚠ AND A LAYER ERROR IN MY OWN COMMENT — the THIRD instance of that class in
this phase**, after `0e5a56a3` (§Q8 contradicting itself) and `f6f30eaa` (the
phase headline). It called the `char-numeric?` counterfactual a "SILENT WRONG
DATUM … worse than" the audit's predicted `exact?: contract violation`. Both
halves were layer-confused: the `#f` payload is silent only at the DATUM layer
(end-to-end it is a LOUD per-command error with the file continuing, i.e. LESS
severe), and the audit's prediction describes the SHIPPED path correctly — it
was right, not superseded. The same comment block gets the distinction right 30
lines earlier. **Corrected in the comment.**

**Three of my own TEST defects, caught before the commit**: a **VACUOUS pin that
PASSED** (bare `#rx"9"`/`#rx"3"` matched DIGITS IN THE TEMP-FILE PATH inside a
printed error struct — the identical trap this arc already hit); a
**MIS-PREMISED pin** (`.( v.0 )` is a single-operand mixfix that errors
identically on the baseline with a plain `.name`); and a **ruling I had stated
wrong from the audit's own text** — a space BEFORE the dot is irrelevant, but a
space AFTER it means there is no `.N` lexeme at all, contiguity being inherent
to a token. The audit conflated the two spaces.

**Design claims the audit corrected**: two work items were FREE or already done
(chains fall out of the existing fold-left; bare-path extraction already works
in 3 of 4 positions, the 4th being §5.PX's inference family, which §5.P2's Intent
silently promised) · the predecessor's "stop that re-entrancy" prescription is a
**FALSE PREMISE** — the re-entrancy is LOAD-BEARING, `v[idx.i]` works only
because the payload is re-preparsed · `rewrite-dot-access` has **THREE**
production callers, so the `.N` arm inherits map-literal values and the `.( … )`
token stream free.

**New committed infrastructure** (both were being re-derived by hand every
phase, which is how P1b-ii's first A/B measured the tree):
- **`tools/reader-corpus-ab.rkt`** — refuses to guess a corpus (`--corpus is
  REQUIRED`) so both legs must be handed the same snapshot, and carries a
  TRIPWIRE for the mutable-registry footgun that gave one audit facet a
  confident FALSE ZERO.
- **`tests/test-path-selection-acceptance.rkt`** — this file's siblings were all
  gated; it was not, so "N/N markers" had been hand-verified since P0. Fine while
  phases only APPENDED; P2 uncomments mid-file and shifts ~20 markers, which is
  precisely the situation that produced the Rel T1 misnumbering defect. Also
  pins that no two markers claim the same index — P2's own first attempt did
  exactly that.

**DEFERRED 9–13**: the ordinal hint's cross-domain blindness (`cfg.0` especially
— the adjudicator's pick as the most plausible first-contact error, in mild
tension with Q_R5's own rationale) · a possibly-unreachable zero-arity branch
(the VAG's red flag) · **the trailing guard blocking `^`, a landmine for P3's
RE-KEY** (`x.0^` declines while `x[0]^` lexes — the two spellings Q_R1 unified
would diverge on exactly the character P3 introduces) · `reconstitute-path-list`'s
`$dot-access`-only walk · the `tokenize-string` raise→token flip.

