# CIU 6 — D4, §5.P3

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 5745–6104 are lines N-5738 here.

---

<a id="p3"></a>

### §5.P3 — Blocks  ✅ COMPLETE (P3a `290f77f9` · P3b `36ce601c` · P3c `1b021d57` — the Q_T batch; split per Q_T5)

**The §3 Q_T rulings govern this phase.** The mini-audit (`wf_27a84061-c7e`,
7 facets + critic @ `76214095` — 13th consecutive premise refuted) fed a
deliberative one-question-per-turn co-design with the owner; every ruling and
its rationale is in the §3 ledger. This section is the IMPLEMENTATION shape.

**What the audit established** (all probe-verified, load-bearing for the
slices): the KEYED result needs no new row machinery (an all-keyword map
literal already mints the corpus's closed rows — but Route A was ruled anyway,
on completed-architecture grounds, Q_T1); the KEYLESS sort CANNOT be desugared
(`@[…]` collapses to PVec at EVERY homogeneous n, so both §B keyless lines are
unreachable via literals); STRICT MERGE cannot be inherited (`make-record`
silently last-wins — the check runs BEFORE minting); the P1a gate has a HOLE
at `spec` (DEFERRED 14 — P3 ships its OWN type-position refusal); and NO
tokenizer changes are needed (every ruled spelling already lexes), so NO
corpus A/B is owed.

<a id="p3a"></a>

#### §5.P3a — The node + keyed blocks, no `^`  ⬜  ← the fresh session opens here

**Work**: `surf-select` + `expr-select` per pipeline.md § New AST Node in
FULL — struct + provides + `expr?` · `shift`/`subst` · zonk ×3 · `whnf`/`nf`
(+ `whnf-trivial?` if stuck-classified) · `pp-expr` · **pnet-serialize
REGISTRATION (no bump — §8 R6 as corrected)** · `infer`/`check` · **the
`inferQ`/`checkQ` twins** (delegation model `cdb535ac`: TYPE delegated to
`infer`, USAGE mirroring `checkQ`) · surf struct + parser arm + elaborator
arm. No binder ⇒ no depth routing; cold walkers ride the generic
transparent-struct fallback.

**The preparse seam** (replaces P1a's NOT-YET marker for the shapes this
slice handles): the fold arm fuses `[base, $select-brace …]` into a
`$`-headed, NON-access-sentinel datum head (the fixpoint requirement — hazard
1; the baseless leg REMAINS as the "needs a subject" backstop per the audit's
C23). That new head pays its SUBSET of the nine-site surface: `pattern-var?`
(the loud-if-missed site) + the parser head arm; NO reader token ⇒ no
token-layer sites; it must NOT join `access-sentinel?` (that is what makes the
fold a fixpoint).

**Semantics**: payload segmentation (a non-sentinel item OPENS a branch;
following access sentinels ATTACH; `$dot-brace` recurses); typing = per-branch
copattern demand with **Q_T2 D-lenient presence** (sourced-`'present` or a
loud refusal naming seal/validate/annotate) + assembly into a CLOSED keyword
row; reduction = subject evaluated ONCE, then per-branch extraction; **the
duplicate-output-key check runs BEFORE `make-record`** (plain keys at this
slice; remedies `^k'`/`^_` named in the message); the malformed-payload seat
(empty block `x{}` gets its OWN arm AHEAD of L4 — zero branches is vacuously
both sorts and `record-value-union` raises on empty; bare keyword items;
`$rest`; stray `|.|`; bracket groups); the TYPE-POSITION refusal; miss errors
via `format-closed-row-miss` WITH branch context (the audit's C9 answered).

**Test delta** (⚠ corpus list CORRECTED 2026-07-30 — ruled **Q_U1** [owner]:
**P3a owns EVERY no-`^` block line**; the list below was previously written
against no file — it named `{name}`, which does not exist in §B (a
mis-transcription), and left three no-`^` lines unassigned, the §9
"assigned to NO PHASE" class landing on this slice's own work list): node
pins (fixpoint incl. LEFT siblings · `pattern-var?` via macro USE, not
registration — the P1b-ii lesson) · E2E keyed corpus — `{database}` ·
`{server.{host port}}` · `{server.{ssl.{enabled}}}` (was unassigned) ·
`def sub := app-config{server.{host}}` + re-projection · `regions{eu us}`
(§I :320, was unassigned — a plain keyed n-ary selection over a closed-row
subject; its own `[D4.P3]` line tag is correct, the §10.5 heading's
`[D4.P4]` covers only the broadcast lines) · the error battery (`{zzz}`
names available fields + the branch · `{}` · duplicate plain keys ·
dyn-subject refusal · `(Map K V)`-subject refusal · type-position) · twins
pins (a block in a `def`/`defn` body under QTT) · **§9's learnability
pair**: `x.a.b` vs `x{a.b}` side by side, and the block-side miss message
names the extraction spelling. NOT P3a's despite its `[D4.P3]` tag: §G's
seal/validate pair (acceptance :240-245) uses `server^.{host port}` —
mid-path dissolve ⇒ **P3b's** (its delta now names it, per Q_U1). Gates:
targeted battery · acceptance `--check` · full suite · adversarial verify.

**CLOSE NOTES ✅ `290f77f9`** (opened `6d919142` with Q_U1; failing-test-first
— 34 pins RED at open, each failing on the NOT-YET marker, i.e. for the
reason its name claims).

**Gates**: suite **9418 / 475 / 0** (from 9370 — +48) · acceptance **41/41**
(from 35; the 6 new markers value-verified before pinning; the renumber
gate-checked, no duplicate indices) · battery **136/136** · neighborhood
**623/623 over 21 files** (incl. the pipe-compose and schema/seal families
the verify fixes touched) · **zero tokenizer changes ⇒ no corpus A/B owed**
(Q_T5, as predicted).

**⚠ THE ADVERSARIAL VERIFY CAUGHT A BLOCKING DEFECT — 6th consecutive
behavioural slice, and this one was a SILENT WRONG VALUE at 0 errors.**
Block-form `|>` with a select init: head-macro dispatch runs BEFORE the
access-sentinel fold, and the pipe's step builder appends its accumulator
into whatever datum a step is — appending into a raw `$select-brace` payload
CORRUPTED it (`|> cfg{server} f` → `($select-brace server cfg)` → the later
fold fused the corrupted select onto the FUNCTION). With an adversarial `f`
whose row offered the keys, the wrong select evaluated silently. Pre-P3a the
same input was a guided error — the slice turned a refusal into corruption,
which is exactly what the verify exists to catch. **Fix**: a pipe-local
pre-fold (`expand-pipe-block` runs `rewrite-dot-access` over its raw parts
first — sound because the fold is a fixpoint). The general
head-macros-before-fold ordering is DEFERRED 17 (the if/cond/let siblings
are LOUD-but-lying and dot-identical, i.e. pre-existing).

**Three SIGNIFICANT, all fixed pre-commit**:
1. **The `$select` subject was never preparse-expanded** — the fold-arm
   comment's premise ("already expanded when fused") was FALSE: the fold at
   the subforms seam runs BEFORE per-subform recursion. Compound subjects
   (bracket groups, map literals with dot-access values, selects-of-selects)
   froze raw sentinels into lying downstream errors. Fix: `$select` is now
   PARTIALLY opaque — the subject expands, the payload stays protected.
2. **Schema-sealed subjects refused wrong-kinded** (found by TWO skeptics
   independently) — `sealed{name}` hit 'subject-other while the refusal
   messages named "seal the subject" as remedy #1, a circular dead-end. Fix:
   `select-project` projects THROUGH schema fvars via `schema->row`
   (all-'present by construction — the strongest Horn-D source; the
   dot-access arm has carried the same leg since F1). SELECTION-typed
   subjects stay refused on read-capability grounds (DEFERRED 20).
3. **`^`-bearing items fabricated field misses** (`cfg{version^}` → "field
   :version^ is not present … spelled `.version^`") on exactly the spellings
   the duplicate message recommends. Fix: a P3b-pointer arm in the
   segmentation seat, symmetric to the ordinal arm's P3c pointer, gating
   both branch-head and dot-access-attach positions. ⚠ P3b REPLACES this
   gate with the real splitter.

**Q_T2 adaptation — RATIFIED [owner, 2026-07-30: "the adaptation stands —
annotate comes back when it's real"]**: the remedy list as ruled named seal /
validate / **annotate** — the verify found "annotate its row type" has NO
working spelling at HEAD (row-literal annotations refuse everywhere; zero
in-tree uses — DEFERRED 19), i.e. the P1b-iii advice-that-does-not-work
class. The messages name only the two VERIFIED remedies (seal via
`the Schema subj`, validate); annotate re-enters when row annotations become
writable (DEFERRED 19 carries the trigger).

**Also hardened at the verify**: ground non-map subjects PANIC at the whnf
arm (was a silent stick, asymmetric with the loud nested descent —
`definitely-not-map?` consulted); trailing steps after a terminal `@sub`
PANIC instead of silently vanishing (constructed-IR only; the parser grammar
forbids the shape); two dead negative pins fixed (an open row prints `{… |
_}` — the pipe is INSIDE the braces, so the original `} |` regexp could
never fire); `~s` for string items (a bare `s` rendering was
indistinguishable from the valid spelling); the sub-block empty message no
longer claims `{}` is a map literal.

**Scope rulings surfaced mid-slice**: mid-branch ordinal steps
(`{admins.0}`) are REFUSED loud — ruled **Q_U2 Reading A** at the close
checkpoint (descent, no output level; lifts at P3c); multi-arity defn clauses with HETEROGENEOUS result
types fail PRE-EXISTING with a lying unannotated-param diagnostic
(select-free control `| 0 -> {:a 1} | n -> 5` pinned it; filed as a spawned
task) — the multi-arity pin uses same-row arms with distinct VALUES.

**Pre-existing, filed not fixed** (DEFERRED 15–20): the def-RHS block-pipe
(baseline worktree-pinned at clean `6d919142`) · the do-expander
whole-file-abort family · the head-macro raw-sentinel family · the dyn-assoc
type/value desync selection would otherwise launder · row annotations ·
selection-subject capability alignment.

**P3b watch items** (from the verify): the fold fuses against ANY left
sibling incl. non-expression sentinels (`$angle-type` in the pre-existing
spec-hole context, `:=` — both loud or pre-dropped today; the splitter round
should decide a fusable-base posture) · the `re-key-sym?` gate is P3b's
demolition site · `format-select-fail`'s 'unknown wording will misreport a
future 'optional mark (no producer today).

<a id="p3b"></a>

#### §5.P3b — The `^` family  ✅ `36ce601c`

**Work**: the ONE splitter over glued lexemes (Q_M7: nothing liftable — the
sexp splitter keeps empty segments, F1b.7g class), continuation grammar
`-`?·{ε | label | `_`}, plus `^..` recognized over the bare-`|.|` datum shapes
(`[seg^, |.|, |.|]`); dissolve/splice (mid-path `^`); in-place rename `^k'`;
`^_` Reading N (computed label, in place); the `^-` collapse family
(`^-` / `^-k'` / `^-_` — leading `-` after `^` reserved); `^..` parent-key
collapse (ancestors above the parent kept); **the output-level-local
duplicate check** (Q_T3) with `cfg{server^.{port} database^.port}` as the
NAMED monotonicity pin; the Q_T4a ordinal-`^` guided error (one message, all
spellings: `x.0^`, `x[0]^`, `{admins.0^first}` → "an ordinal has no key;
rename the nominal segment: `admins^first.0`"); the malformed-`^` battery
(`a^b^c` · lone `^` · spaced `^b` · `^...`-absorbs-`$rest` rejected).

**Test delta**: splitter unit pins per continuation · the flagship E2E ·
rename/dissolve/`^_`/`^-`/`^-_`/`^..` corpus lines · §G's seal/validate pair
(acceptance :240-245 — `[D4.P3]`-tagged but `^`-bearing, assigned HERE per
Q_U1) · duplicate-leaf error naming remedies · the monotonicity pin · the
ordinal-`^` battery. Gates as P3a.

**CLOSE NOTES ✅ `36ce601c`** (failing-test-first — 29 pins RED at open,
each failing on the P3a re-key pointer / stray-`.` text / unbound-`^` it was
named for; the light re-grounding re-verified the demolition-site coordinates
+ the hazard-4 lex shapes + the Q_T3 naive-lowering baseline before any code).

**Gates**: suite **9469 / 475 / 0** (from 9418 — +51) · acceptance
**50/50** (from 41 — the six §B `^` lines + the §G seal/validate pair, all
value-verified before pinning; renumber gate-checked, no duplicate indices) ·
track battery **178** test-cases · neighborhood **433/433 over 10 files** ·
**zero tokenizer changes ⇒ no corpus A/B owed** (Q_T5, as predicted — the
`^-`/`^-k'`/`^-_` glue and the `^..`→`|.| |.|` shatter were probe-confirmed
at the re-grounding).

**Shipped**: `split-caret-lexeme` (THE ONE SPLITTER; continuation grammar
`-`?·{ε | label | `_`}; refuses >1 `^`, `--`-leading, digit-leading and
keyword rename targets) · the `(@key name cont)` step vocabulary + the
SHARED branch walk in syntax.rkt (`select-branch-top-keys` /
`select-synth-name` — parser check, typing and reduction consume the SAME
walk, the twins lesson applied to check+meaning) · mid-path dissolve/splice ·
in-place rename · `^_` Reading N (seen-steps threading — the first battery
run caught the truncated-branch synth) · the `^-` family · `^..` desugared
at segmentation to the ruled `[P^ L^P]` (fused `^..enabled` / `^..{…}`
continuations agree with the spaced spelling) · the Q_T3 OUTPUT-level
duplicate check (the monotonicity pin errors) · Q_T4a's ONE message across
all three datum shapes (segmentation arms + an ELEMENT-WISE `ordinal-rekey`
marker in the preparse fold) · the malformed-`^` battery · keyless leaf `^`
refuses with the P3c pointer (the boundary note honored — parsed, refused).

**⚠ THE ADVERSARIAL VERIFY CAUGHT A BLOCKING DEFECT — 7th consecutive
behavioural slice, and it was MINE.** The first `ordinal-rekey` seat
replaced the WHOLE datum with the guided marker: a `match` arm containing
`v[0]^` lost its `->` and hit the pre-existing arrowless-arm raw crash — a
WHOLE-FILE abort (zero commands) where HEAD recovered per-command. The same
root cause swallowed a defn clause (lying "defn requires…" diagnostic),
broke map-literal arity ("even number of elements" on a well-formed
literal), and shredded pipe inits. **Fix: ELEMENT-WISE replacement** (the
P1a dot-key precedent — the marker replaces base+ordinal+caret only,
siblings survive), + 11 regression pins. The crash SITE (arrowless match
arms raw-crash on their own) is pre-existing and filed (DEFERRED 22).

**Eight SIGNIFICANT, all fixed pre-commit**: fused `^..` continuations
missed the two-bare-dot lookahead → INVERTED stray-dot advice ("write the
path with no spaces" on a spaceless input) — the lookahead now accepts
fused `($dot-access …)`/`($dot-brace …)` second dots, and the `^.`
near-miss + renamed-leaf-`..` shapes get a `^..`-aware message ·
`k^...label` leaked the internal `($rest-param …)` sentinel verbatim (the
`$rest` arm now matches the tagged shape) · **the duplicate message's `^_`
remedy REPRODUCED the collision in both canonical dup classes**
(dissolved-ancestry synth = the colliding leaf name, correct per Q_T4b′ —
so `^_` was dropped from THAT message, the advice-that-does-not-work class;
`^k'` + sub-block grouping are probe-verified live) · the P3c ordinal-step
pointer now NAMES its phase, closing the Q_T4a advice loop (the ruled
example `admins^first.0` lands on it until P3c) · a VACUOUS `#rx"-"` pin of
mine matched the temp-file path in the transparent error struct (the arc's
own trap, third sighting) · digit-leading rename targets (`k^0`, `k^-0`)
minted a dot-unreachable `:0` field at 0 errors — refused (the one minor
the adjudicator promoted) · `{0^first}` escaped the ONE Q_T4a message ·
`server^{x}` lost its segment name to a "field" placeholder.

**Interpretation pinned eyes-open — RULED Q_U4 at the close checkpoint
[owner, 2026-07-30]**: `^_`/`^-_` synth scope shipped as
**branch-of-its-block** (`server.{host^_}` → `{:server {:host …}}` vs the
dot spelling's `{:server {:server-host …}}`). The owner ruled SUBJECT-ROOT
is preferred (a sub-branch is less likely to share a common leaf key) but
not high priority — the flip is DEFERRED until it next matters (P5's L2
factoring is the natural trigger; DEFERRED 23 carries it).

**Filed, not fixed**: DEFERRED 21 (`k^:x` keyword rename target — the
splitter's `#\:` arm is WS-dead, sexp-only reachable; degraded-not-lying) ·
DEFERRED 22 (arrowless match arms raw-crash — pre-existing, the Q_L4
marker-seat class, the P3b BLOCKING finding's crash site).

**P3c watch items**: the keyless-leaf refusal + the ordinal-step refusal
are P3c's demolition sites (their pins flip); Q_U2's discriminating pair
`admins.0` vs `admins.{0}` is P3c's; the `^..`-fused sub-block continuation
(`^..{…}`) now parses through the desugar — P3c's keyless work must keep it
keyed-only.


<a id="p3c"></a>

#### §5.P3c — Keyless + L4 + honest nesting  ✅ `1b021d57`

**Work** (⚠ boundary note: P3b ships the SPLITTER and every MID-PATH `^`
semantic; the LEAF-position keyless reading lands HERE, because a keyless
branch only means something once the tuple carrier exists — so P3b's close
leaves a leaf `^` parsed-but-refused, and P3c makes it assemble):
bare leaf `^` = keyless component (the branch contributes the leaf VALUE);
**mid-branch ordinal STEPS per Q_U2 Reading A** (the P3a refusal lifts: `.N`
in a keyed branch descends, NO output level — typing = the element type via
the existing PVec/het-tuple arms, reduction = the existing rrb path; the
test delta adds the DISCRIMINATING PAIR `admins.0` vs `admins.{0}` — descent
vs 1-tuple); ordinal branches `{N M}`; the nat-row mint at EVERY n — 1-tuples and
homogeneous n included, which is the entire reason selection routes around
the literal arm (ruling 2a as corrected by the audit); L4 sort homogeneity
(all-keyed → Map, all-keyless → tuple, MIXING errors level-locally — both
sorts must exist before the error is expressible, hence this slice); honest
nesting display (`⟨String⟩` at n=1 — a pin, not a decision: `pvec-slice`
already mints and prints it).

**Test delta**: `{server.host^ database.url^}` → `⟨String String⟩` ·
`{version^}` → `⟨String⟩` · `{N M}` ordinal selection with fresh indices ·
the L4 mixing error (`{version^ server.port}`) · **the G11 one-space pair
pinned side by side** (`{a^0}` keyed-rename-to-`:0` vs `{a^ 0}` keyless
2-tuple). Gates as P3a; P3c closes the phase → the P3 close notes + the
per-phase 5-step gate.

**CLOSE NOTES ✅ `1b021d57` — P3 (BLOCKS) IS COMPLETE** (failing-test-first
— 16 pins RED at open on the three P3c pointers; the light re-grounding
probed the demolition sites, the `pvec-slice` ⟨⟩ mint, and the G11 conflict
before any code).

**Gates**: suite **9497 / 475 / 0** · acceptance **52/52** (from 50 — §B's
two keyless lines, value-verified) · track battery **204** test-cases ·
neighborhood **410/410 over 11 files** · **zero tokenizer changes across the
WHOLE PHASE** (Q_T5's exemption held P3a→P3c; no corpus A/B ever owed).

**Shipped**: the KEYLESS sort — `^`-terminated branches contribute leaf
VALUES; ordinal branches `{N M}` re-derive in written order; the nat-row
mint at EVERY n (ruling 2a — `cfg{version^}` → `@["1.0.0"] : ⟨String⟩`,
honest, never a collapsed PVec) · **Q_U2 Reading A** — ordinal STEPS descend
with no output level; the discriminating pair pinned (`{admins.0}` →
`{:admins row}` ≠ `{admins.{0}}` → `{:admins ⟨row⟩}`); the `(@ord N)` head /
bare-number step distinction keeps dissolve-splice continuations keyed ·
**L4** at the OUTPUT level over the shared walk's components (spliced
keyless into a keyed level errors; sub-levels check themselves) · **B5** —
keyless levels concatenate, NO dup check (`{version^ version^}` = legal
⟨String String⟩) · typing `select-index-of` (PVec / closed-nat-row with
static OOB) + the components model `(key-or-#f . field)`; reduction mirrors
with `rrb-from-list` + bounds-checked `index-into` (PVec runtime OOB panics
LOUDLY with the length — the P2.b tier) · the three P3-pointer arms
demolished; **the Q_T4a advice loop closes END-TO-END** (`{admins^first.0}`
executes: rename, then descend).

**Two twin-drift catches at the RED battery** (mine, pre-verify):
reduction's `below-value` dropped the `seen` synth threading, and the whnf
arm admitted only champ subjects — ordinal blocks over vectors would have
panicked as non-maps.

**⚠ THE ADVERSARIAL VERIFY: NO BLOCKING — the FIRST slice in EIGHT without
one.** 2 SIGNIFICANT + 3 MINOR, all fixed pre-commit:
1. (SIGNIFICANT, mine, the Exhaustive-Walkers twin-drift class) ordinal
   heads + keyless/collapse LEAVES pre-classify into `walk-to-leaf`, whose
   dispatch missed the `(@ord N)` pair — `admins{0.name^}` got a LYING
   "not a record" on a PVec the keyed twin works on; on records the hint's
   swallow-all ate a format throw → a BLANK generic. Fixed with the @ord
   arm in BOTH walks ATOMICALLY — the adjudicator flagged that fixing
   typing alone would have converted the loud lie into a runtime champ-of
   panic (i.e. CREATED a blocking).
2. (SIGNIFICANT) `{N.M}` fused-decimal spellings leaked the internal
   `($decimal-literal q)` sentinel with the rational value — the guided
   collision arm names `x{N .M}` / `x{N.{M}}` (the leak itself was
   pre-existing; the diff made the advice false — adjudicator-split).
3. (MINOR) `.-1` was invisible in the vector-subject message; the wording
   predated live ordinals — label filled at the fail consumers, PVec
   teaching refreshed.
4. (MINOR) in-block `v[0]` silently aliased `.0` — RATIFIED-BY-PIN as the
   Q_R1 "two surfaces, one mechanism" identity extended into blocks;
   head-position `{[0]}` guided to the bare spelling.
5. (MINOR) two stale P3a-era pin titles asserted new error classes through
   loose `#rx"ordinal"` matches — retitled + tightened.

**Interpretation pinned eyes-open**: `{0.name^-}` (ordinal head + collapse
leaf) re-keys to `{:name …}` — the collapse's whole point is producing a
key, so it overrides the head's keyless sort; the three walks agree
(collapse-first classification). The G11 pair landed AS AMENDED (both
halves loud: the digit-target refusal vs the cross-domain refusal — the
one-space flip crosses a loud wall; the recorded rename-to-`:0` reading was
overtaken by the P3b verify's dot-unreachability ruling).

**P3c watch items → P4**: the components model is the broadcast assembly's
natural substrate (a broadcast step's per-element results are components);
the `not-indexable`/`subject-tuple` messages will need `:s` teaching when
broadcast lands; DEFERRED 9's cross-domain hint family now has the
`tuple-or-vector` message as its pattern.

