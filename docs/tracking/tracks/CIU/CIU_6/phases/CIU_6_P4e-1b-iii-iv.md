# CIU 6 — D4, §5.P4e-1b sequencing, 1b-iii, 1b-iv

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 11579–12554 are lines N-11572 here.

---

<a id="p4e-1b-sequencing"></a>

##### §5.P4e-1b-sequencing — the remaining slices  (decided 2026-08-12; owner delegated the slicing)

Set after [Q_U47](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u47) + [Q_U48](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u48) and the 1b-iii-C grounding audit
(`wf_00c82b4e-219`, 6 facets + critic, HEAD-pinned `0feca574`). **The organizing
constraint is that 1b-iii has TWO reverts, and the shape that finally worked was
B1/B2 — land the machinery INERT, then migrate the seat.** C repeats it.

| slice | content | why it is safe alone |
|---|---|---|
| **1b-iii-C1** ✅ `4f30a171` | **The SHARED JOIN, hoisted and returning BARE.** `star-join-type` (typing-core) + `star-join-value` (reduction) at module level, both exported; each twin's existing caller now wraps keyless (its remainder-empty case). `select-below-field` exported as C2's seat. syntax.rkt doc-truth. ⚠ **RE-SCOPED mid-slice**: the tail ARMS moved to C2 — see the note below. | Pure extraction. Battery 498 → **501**, 0/0 by direct require; every pre-existing pin green IS the regression proof (the B1 pins already exercise depth-1 through both twins). **Mutation-tested PER TWIN**, inverted in place: re-wrapping typing's return → 3 FAILURE + 3 ERROR, reduction's → 2 FAILURE + 4 ERROR, the C1 pin among them each time. ⚠ Both mutant runs **exited 0**. E2E star surface byte-identical to pre-C1; neighbourhood 318 `[4/4]`; acceptance 0 errors. |
| **1b-iii-C2** ✅ `68014124` (instrument `d8776b66`) | **THE DEEP FLATTEN IS LIVE.** `cfg{db.hosts*}` → `{:db @[1 2]}` · `two{a.{x y}*}` → `{:a @[1 2 3]}` · depth 3 works. Pre-check narrowed via `select-branch-deep-star?`; ONE star-TAIL arm per twin (`select-steps-star-tail?`, exactly `(sₙ ★)`) returning C1's join BARE; both shields out; `star-dup-key` seat; L4 message de-lied; `star-deep-prefix` re-scoped to the ordinal gap. | ⭐ **Two of the three landings needed NO CODE** — the dissolve and ord-branch arms already wrap keyless, and `select-below-components` needed no twin arm at all. Battery 504 → **521**, 0/0 · neighbourhood `[4/4]` · acceptance 0 errors · ✅ **suite 10188/488/0 at `428e0c80`** · adversarial verify **rounds 1, 2 AND 3 DONE** (`wf_bf354f2d-675`, `wf_87b2134b-d05`, `wf_1bb04012-af2`) — 3 BLOCKING at `eee68262`, R2's F1/F3/F4 at `73c56b2c`+`28b524d7`, R2's tail at `7ed99f39`+`6a64f2b2`, **R3 at `428e0c80` (round 2's own remedy rewrite repeated the class it fixed)**. Records: [§5.P4e-1b-iii-C2](#p4e-1b-iii-c2) · [the R2 tail](#p4e-1b-iii-c2-r2-tail) · [R3](#p4e-1b-iii-c2-r3) |

<a id="p4e-1b-iii-c2"></a>

**§5.P4e-1b-iii-C2 — what the slice found.**

⭐⭐ **Q_U47 IS IMPLEMENTED BY NOT IMPLEMENTING IT.** Nothing computes the
landing. The pre-check narrows, the deep star falls through to the head dispatch,
one tail arm returns the join BARE, and whichever caller catches it supplies the
wrapper — so the rule *"the component the remainder would produce"* holds because
the caller **is** that remainder's arm. Measured consequence: the KEYED case is
the key arm's existing re-nest, and the two KEYLESS cases (`cfg{db^.hosts*}`,
`vh{0.{0}*}`) required **no new code** — the dissolve and ord-branch arms already
wrap `(cons #f …)`. `select-below-components` was scoped for a twin arm and
needed none: it routes a non-terminal sub to `select-branch-entries`, where
`(hosts ★)` is not DEEP and so takes the remainder-empty keyless landing.

⭐ **THE EXPRESSIVITY ARGUMENT THAT DECIDED Q_U47 IS NOW PINNED — and my first
live check FAILED TO DEMONSTRATE IT.** Q_U44's written-order recovery
generalizes to depth: on `w := {:zz {:u @[1 2]} :aa {:v @[3 4]}}`,
`w{zz.u* aa.v*}*` → `@[3 4 1 2]` (canonical) versus `w{zz^.u* aa^.v*}*` →
`@[1 2 3 4]` (written). The first probe used `:p`/`:q` written p-first, where
canonical and written order **coincide** — it printed the same vector twice and
proved nothing. *An ordering claim needs keys whose orders differ, or its pin is
vacuous.*

**THE TWO HOLES, CLOSED.** The dup seat was measured open first:
`cfg{db.hosts* db}` → `{:db {:ports @[80], :hosts @[1 2]}}` at **zero errors**,
the star's surviving `:db` silently overwritten. New kind `star-dup-key`, added
to the battery's hand-written render loop in the same commit (it cannot
self-report an unlisted kind). The L4 message asserted the STAR is the keyless
branch — true only while every star landed keyless — so a deep KEYED star beside
a keyless sibling was told the reverse of what happened.

**TWO DEFECTS THE RUN CAUGHT, both from assuming the twins are symmetric:**
· **ARM ORDER.** Reduction's `@sub` arm matches ANY sub-headed step list and
  panics when anything follows it, so with the tail arm placed after it
  `two{a.{x y}*}` and `vh{0.{0}*}` died in *"steps after a terminal sub-block"*.
  Typing's sub arm carries a `(null? (cdr steps))` guard and has no such hazard —
  exactly the asymmetry that makes "the same edit in both files" wrong in one.
· **THE ORDINAL GAP'S SPELLING.** `nested{a.0*}` is a PARSE error and never
  reaches the seat; the reaching spelling is the BRACKET one, `a[0]*` — which is
  what [DEFERRED 116](../../../../DEFERRED.md) proposes deprecating, so that deprecation
  would make this ruled gap unreachable.

**⭐⭐ VERIFY ROUND 1 (`wf_bf354f2d-675`, 4 lenses + adjudicator) — THREE BLOCKING
regressions, fixed at `eee68262`; the battery, neighbourhood and acceptance were
GREEN over every one.** All three re-measured on the main thread before acting.

**ONE ROOT CAUSE, THREE SYMPTOMS.** `below-components` / `select-below-components`
is a SECOND route into the branch machinery, reached through a DISSOLVED head,
and C2 treated only the `below-value` route. **The comment that closed the
question is the one that caused it**: *"`select-below-components` needs NO twin
of this arm … Verified, not assumed"* — typing's twin was verified; reduction's
sibling was never opened.

| # | measured at `68014124` | fix |
|---|---|---|
| 1 | **silent wrong answer, ORDER-DEPENDENT** — `s7{a^.{b.c*} b}` → `{:b @[9]}` vs `s7{b a^.{b.c*}}` → `{:b @["x" "y"]}`: same selection, branches swapped, different VALUE and TYPE, zero errors. The dup gate's `ormap select-star-step?` saw only TOP-LEVEL steps, so a star inside a `(@sub …)` was invisible and a dissolved head spliced its keyed component in. **Verbatim the failure that gate was added to prevent, one nesting level down.** | `select-branch-has-star?/deep` (syntax.rkt), recursing into sub-payloads |
| 2 | **silently answered the question [Q_U46] RESERVED** — `y{a[0]*}` refused while `y{a^[0]*}` answered `⟨[PVec Int]⟩`, deleting a layer the ordinal never made and contradicting a refusal the same run printed two lines earlier. The ordinal check shipped at ONE seat; the dissolved spelling reaches the layer through the other. | `select-step-makes-no-layer?` at **both** layer-computing seats |
| 3 | **twin divergence** — `cfg{db^.{hosts ports}*}`: typing ACCEPTED, reduction PANICKED with *"steps after a terminal sub-block (the parser grammar forbids this shape)"*, asserting impossible a shape C2 made reachable. ⭐ The parser never forbade it — the depth-≥2 SHIELD did. | reduction's `below-components` matched to typing's twin: terminal-only, else delegate |

⚠ **AND THE ENUMERATION THAT HID IT WAS WRONG ON ITS FACE.** `star-join-type`'s
header — the argument justifying the whole C1/C2 design — listed **THREE**
callers and named `select-below-components` as the third. There are TWO; it
delegates and wraps nothing. *An enumeration that is wrong about ITSELF is how a
seat gets skipped.* Corrected, as was the `select-star-step?` PRECONDITION header
(stale for all of C2 — the **fourth** instance of that shape and the **second**
in that same comment; rewritten to state the CONTRACT rather than the STATE so it
survives the next slice).

**STILL OWED FROM ROUND 1 — three diagnostic-quality MAJORS, C2's own:**
· the tail arm computes its label from the two-step list `(sₙ ★)`, so every
  failure routed through it echoes only the last two steps where the sibling seat
  prints the whole branch — diagnostic quality now depends on which seat caught it;
· `star-dup-key`'s remedy *"drop the `*` so the layers nest"* is **itself an
  error** on the very example the commit cites (dropping the star does not change
  the branch's surviving key); the parser's own pre-existing message offers the
  third option that generalises (group same-head branches into one sub-block);
· `star-l4-mixed` still misleads when BOTH branches are starred at different
  depths — both remedies are non-actions and the fix is the OPPOSITE of one of
  them (you must ADD a caret).

**FILED, PRE-EXISTING**: [DEFERRED 117](../../../../DEFERRED.md) (the L4 gate shares the dup
gate's top-level-only blindness — deliberately NOT widened here, per *Watching
9*, and the two must be widened together) · **118** (the block-band ω with a
symbol inner assembles instead of extracting — and it is why one C2 pin is green
for the wrong reason) · **119** · **120** · **121** (the p4e1 Level-2/Level-3
divergence that PARKED the dup pin).

**⭐⭐ VERIFY ROUND 2 (`wf_87b2134b-d05`, 4 lenses + adjudicator) — 13 lens
findings → 7 survivors, 1 KILLED by the adjudicator's own re-run, 6 deduped to 3
root causes. Round 1's three fixes all HOLD (re-measured on the main thread
first).** The adjudicator was asked outright whether round 1's shape repeats:
**it answered YES, TWICE**, and opened both siblings.

| # | severity | finding | disposition |
|---|---|---|---|
| **F1** | **BLOCKING** | a `^` fused into a star-bearing segment is taken VERBATIM as field-name text in the DOT and ω bands | ✅ FIXED `73c56b2c` |
| **F3** | MAJOR (latent) | round 1's fix reached BOTH typing seats and NEITHER reduction one; the unguarded seat asserted the invariant in PROSE, the other kept a hand-copied `memq` | ✅ FIXED `28b524d7` |
| **F4** | MINOR | `select-branch-has-star?/deep` said "ANYWHERE" and recursed into `(@sub …)` only — blind to `(@bcast (@sub …))` | ✅ FIXED `28b524d7` |
| **F2** | MAJOR | a parse-level state leak drops `def s0\|s1\|s7 := …`; **invalidates [DEFERRED 121](../../../../DEFERRED.md)'s diagnosis** | ⬜ [DEFERRED 122](../../../../DEFERRED.md) |
| **F5** | MINOR | a sibling `@sub` arm still asserts *"the parser grammar forbids this shape"* for a shape C2 made reachable | ✅ FIXED `7ed99f39` |
| **F7** | MINOR | the round-1 fix spliced two definitions between a PRECONDITION header and the function it guards | ✅ FIXED `7ed99f39` |
| F6 | MINOR | a pre-existing PATH-band message; explicitly NOT a round-2 finding and NOT a regression | ⬜ with DEFERRED 105/116 |

<a id="p4e-1b-iv-verify"></a>

##### §5.P4e-1b-iv verify — 2 BLOCKING + 9  (`dbb8a55d` · `729ac3b0`)

`wf_0df64e7f-231`, 4 lenses + adjudicator: 16 raw → 11 survivors, none killed
outright, 5 merged to 2 root causes. Suite **10206/488/0**, battery **539**.
⭐ **The sibling question answered YES FOUR TIMES** — asking it outright has now
produced findings in THREE consecutive rounds.

**BLOCKING ×2:**
· **A TYPE/VALUE SPLIT, in my own fix.** [Q_U20] rules that a SUB inner assembles
  at `'block` ALWAYS; typing forces it with a literal at two sites, reduction's
  `bcast-apply` fed the chain the OUTER sort. B2's `'path` fix reached both
  landing HELPERS and **neither twin's FEED**. Measured at 0 errors:
  `vv:{a*}` → value `@[@[{:x 1}] @[{:x 2}]]` against type `[PVec {:x Int}]`, and
  it PROPAGATED — `r:x` → `none : [PVec Int]`, a well-typed expression whose
  value is `none`.
· **[DEFERRED 117] discharged**, and its exposure was understated: on the
  UNTOUCHED vector path `nv{m k^.{a*}}` is a WHOLE-FILE ABORT and the swapped
  order silently drops a key at 0 errors. ⭐ The landmine held — gate and `findf`
  moved in ONE edit, plus reduction's twin.

**THE SEMANTIC ONE**: a TRANSPARENT ordinal changed whether the landing spliced.
`select-steps-star-tail?` was used caller-side as a proxy for "did the tail arm
fire" and is a false negative through no-layer steps — `vk1{0.m*}` spliced,
`vk2{0 .0.m*}` did not. Minted `select-steps-yield-bare-join?`; the ARM keeps its
exactly-two test, because a KEYED prefix must re-nest and that reason simply does
not apply to a step making no layer.

**FOUR MESSAGES Q_U49 HAD FALSIFIED**, each remedy RUN: `star-dup-key` named an
UNSPELLABLE remedy (a starred segment cannot carry a rename — `seg^k*` is a parse
error) and mis-diagnosed lifted keys; `star-l4-mixed`'s rule was negated (a
nominal star lands KEYED) and its remedy pointed the wrong way (`mx{a* c^}` is an
error, `mx{a* c}` works); the re-scoped `star-nominal` promised bare `*` works
where it PERMANENTLY refuses; `star-map-opaque` rendered the LAYER when it fired
from the CONTENT arm. The ω arm also skipped its siblings' classification and
gave the N-copies argument to zero-key element rows.

⚠⚠ **AND ONE FILED GAP WAS NOT ONE** — the verify's S8 said the two permanent
typing refusals lack sibling arms in `star-join-value`. **I wrote one and it
broke a working shape**: `rrb layer + champ contents ⇒ oops` made `vhm{0.{0}*}`
panic where typing splices — reduction refusing where typing ACCEPTS, the
divergence inverted. Both refusals are TYPE properties invisible at the value
layer (an opaque Map and a closed record are both champs; an ω container and a
legal Seat B keyless layer are both rrbs). **The asymmetry is inherent, not an
omission**, and that is now recorded at the seat.

⚠ Recorded, not fixed: [DEFERRED 124](../../../../DEFERRED.md) — `*_` is structurally
unspellable at the closer-adjacent seat, so the upcoming `*_` slice must not
assume coverage there.

<a id="p4e-1b-iv"></a>

##### §5.P4e-1b-iv — the NOMINAL splice  (A `b216f926` · B1 `714607dc` · B2 `0e2f5af7`)

**[Q_U49] shipped at all four seats.** Measured live: `mn{a*}` → `{:x 1}` ·
`mn{a* b}` → `{:b {:y 2}, :x 1}` · `mn{a b}*` → `{:y 2, :x 1}` ·
`cfgn{db^.conf*}` → `{:x 1}` · `cfgn{db.conf*}` → `{:db {:x 1}}` (KEYED, nests) ·
`vhm{0.{0}*}` → `{:x 1}`. Vector contrast UNCHANGED (`mv{a* b}` still L4).
Suite **10203/488/0**, battery 521 → **536**.

⭐ **TWO THINGS CAME OUT CHEAPER THAN THE AUDIT PRICED THEM.** Seat B cost a
`select-steps-star-tail?` test per twin, not a contract change (the audit's
estimate is what would have chosen the wrong ruling — see [Q_U49](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u49)). And
on the type side **the splice is a NO-OP CONVERSION**: a level component
`(key-or-#f . record-field)` and a row field `(key . record-field)` are the same
shape, so [Q_U38](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u38)'s splice-vs-sibling and splice-vs-splice checks cost
**no code** — the level's existing `(filter values (map car cs))` fold sees the
lifted keys. Verified: `coll{inner* other*}` and `collw{inner* k}` both refuse.

⚠ **B1's SCOPE WAS WRONG WHEN I ANNOUNCED IT, and the correction is the
lesson.** I told the owner B1 was "a signature change, not an arm addition",
carrying the audit's *"1b-iv changes both helpers' SIGNATURES"*. Checked before
implementing: `join-contents` already receives the CONTENTS; the layer's keys are
discarded because that IS the layer delete, and they are needed for `*_`
PROVENANCE only — which Q_U49 put out of scope. B1 is 93 lines of pure insertion.
**The audit's claim is true of `*_` and I generalised it without measuring.**

⚠⚠ **THREE DEFECTS SELF-CAUGHT BY RUNNING THE UN-PARKED PINS, all introduced by
B2 itself:**
1. **The `'path` carrier regression** — splicing regardless of sort broke
   `cfg{database}*` and `mn{a b}*` ("the subject is not a record"): a path
   selector must yield exactly ONE component. ⭐ The fix is the RULE, not a
   patch — **splicing needs an enclosing level to splice into, and a `'path`
   landing has none; its join IS the value**, which is exactly Q_U40's
   `m{a b}*` → `{:x 1, :y 2}`, a case the sort-blind version could not produce.
2. **The EMPTY-layer sort flip**, predicted verbatim by the audit (*"arm order,
   not a ruling, decides the empty join's SORT"*): `(andmap … '())` is `#t`, so
   an empty layer matched the champ arm and `@[]` became `{}`. A `pair?` guard
   restores it; the case stays unruled, so it must not MOVE.
3. **`*_` fell into the nominal join on the VALUE side**, dropping key-synthesis.
   Typing's guard is not a defence — this seat's doctrine is that reduction must
   not depend on typing having run. Caught by A's seat pin, written for exactly
   this.

⚠ **TWO OF MY OWN PINS WERE WRONG**: `coll{inner* inner}` does NOT collide
(`inner*` lifts `:k`, the plain branch keeps `:inner`), and two pins asserted a
full rendered line and reddened on ORDER while the semantics were right —
`make-record` canonicalizes, the champ carries HASH order. That is Q_U38's third
fact, which says to pin value and type SEPARATELY.

**KINDS**: `star-nominal` RE-SCOPED to the `*_` not-yet (leaving "the nominal
case is the next slice" would have made it a lie the moment the shield fell);
`star-omega-nominal` and `star-map-opaque` minted, each with its message and the
battery render-loop entry in the same commit.
⚠ **OPEN — the ω tension**: `star-omega-nominal` refuses on Q_U38's
possibility rule, but [Q_U40](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u40)'s own `rowsm:cfg*` worked example assumes
DISJOINT keys — true of that value, not expressible in its type. Recorded rather
than silently decided; wants a ruling or a DEFERRED.

<a id="p4e-1b-iii-c2-r3"></a>

**⭐⭐ VERIFY ROUND 3 (`wf_1bb04012-af2`, 4 lenses + adjudicator) — 14 raw → 7
SURVIVORS + 2 charged elsewhere, 5 killed or merged by the adjudicator's own
re-runs. Fixed at `428e0c80`. THE HEADLINE IS THAT ROUND 2's REMEDY REWRITE
REPEATED THE CLASS IT WAS FIXING**, and the reason it could is the sharper
finding. All re-measured on the main thread before acting.

| # | severity | finding | disposition |
|---|---|---|---|
| **#1** | MAJOR | `star-l4-mixed`'s round-2 remedies were derived from ONE example and are NON-ACTIONS in three other measured populations; the action that works is never named | ✅ FIXED `428e0c80` |
| **#2** | MAJOR | the ONLY pin covering the keyed-star population is VACUOUS **from birth** (`d8776b66`) — it dies at field resolution and never reaches the L4 seat | ✅ FIXED `428e0c80` |
| **#3** | MAJOR | DEFERRED 123 is LIVE, not latent — and has a SECOND collapse channel (the ω marker) its diagnosis never named | ✅ entry corrected |
| **#5** | MINOR | the rule round 2 stated is **directionally backwards**, and vacuous for a branch-final operator | ✅ FIXED `428e0c80` |
| **#7** | MINOR | the round-2 pins under-discriminate (bare `c2-refused?` negatives; a regex blind to the widening) | ✅ FIXED `428e0c80` |
| **#8** | MINOR | *"sub-block grouping does not survive a star"* is an OVERCLAIM — it survives when ALL grouped branches are starred | ✅ narrowed + both spellings pinned |
| **#9** | MINOR | DEFERRED 123's repair scope charges for a **reduction twin that does not exist** | ✅ entry corrected |
| #4 | MAJOR | [DEFERRED 117](../../../../DEFERRED.md) reproduces at HEAD and its exposure is UNDERSTATED — a whole-file abort from ordinary surface syntax | ⬜ pre-existing, deferral stands |
| #6 | MINOR | LATENT — typing's `select-step-name` `[else s]` renders a raw IR step list into a user-facing message; the comment above it asserts that cannot happen | ⬜ constructed-IR only |

**⭐⭐ #1 + #5 + #2 ARE ONE STORY, AND IT IS THE MOST INSTRUCTIVE OF THE SLICE.**
Round 2 fixed two messages whose remedies did not work. Its replacement for
`star-l4-mixed` was derived from the ONE example in front of it —
`m2{a* d.c*}`, where the STAR branch happened to be the KEYLESS one — so both
remedies were written as things to do to a *sibling*. Measured outside that
shape: `pc{db.hosts* ports*}` returns the error **byte-identical**,
`pc{db.hosts* ports^^}` is a parse error, and at depth 3 `d3{a* x^.y.z*}` is
byte-identical to the unfixed spelling. The action that works is on the STAR
branch (`pc{db^.hosts* ports^}` ✓, `d3{a* x^.y^.z*}` ✓) and was never named.
· **#5 is why it read as fine**: the rule was stated as *"no step survives AFTER
it"*, but `*` is branch-FINAL, so the condition is **vacuously true** and the
sentence asserts every star lands keyless — while `e3{a.b.c*}` lands KEYED. The
sibling message authored in the SAME commit said it correctly (*"the steps
BEFORE the star"*). One rule, two messages, opposite directions.
· **#2 is why nothing caught it**: the only pin covering the keyed-star
population has been vacuous since `d8776b66` — `C2V`'s `cfg` nests `:ports`
under `:db`, so `cfg{db.hosts* ports^}` died at field resolution and never
reached the L4 gate. Its negative half is `#t` for that unrelated error and its
`check-false` matched nothing. **A vacuous pin does not merely fail to catch a
defect; it licenses a rewrite to specialise to the wrong population.**
⭐ **The repair is to derive the message from the RULING rather than the
example** — state Q_U47's remainder rule and let the action follow from it.

⚠ **AND THE FIX FOR A LYING MESSAGE MUST NOT ITSELF OVERCLAIM** (#8). Round 2
wrote *"sub-block grouping does not survive a star"*; measured, it survives when
**every** grouped branch is starred (`cfg{db.{hosts* ports*}}` → `{:db @[@[1 2]
@[80]]}`). Narrowed, with BOTH spellings pinned so the next session that tries
the natural all-starred form finds the record already knows.

⚠ **TWO CORRECTIONS TO [DEFERRED 123](../../../../DEFERRED.md), BOTH MINE, ONE DAY OLD**
(#3, #9): it is LIVE (`rec3{a.b a^r.b.zzz}` names ``(branch `a.b`)`` while
`rec3{a.b}` alone SUCCEEDS — a valid sibling named as the failing branch); it
has a second collapse channel (the ω marker); and its repair scope charged for a
**reduction twin that does not exist** (reduction: 0 `append path`, 0
`select-fail`, no `path` parameter at all). That last clause read as an ATOMIC
co-migration obligation and would have sent the next session hunting a seat that
isn't there. ⭐ **It survived a whole verify round because pins assert kinds and
code, never prose.**

<a id="p4e-1b-iii-c2-r2-tail"></a>

**⭐⭐ ROUND 2's TAIL — F5, F7, the three diagnostic MAJORS and DEFERRED 122's
rename, closed at `7ed99f39` + the majors commit. Two of the four went a
different way than the work order said, and BOTH divergences came from
measuring instead of adopting.**

· **F5 — the sibling's fix was the WRONG fix.** Round 1 repaired
`below-components` by going terminal-only-else-delegate; `below-value` cannot,
because its fallthrough is the `memq` arm which LISTS `sub` — an entry its own
P4a site-8 comment records as dead *only while this arm guards on `@sub` alone*.
Delegating would revive it and project a RAW STEP LIST as a nominal key, the
class D4.P4a removed. So: wording corrected, guard untouched. Owner ruled the
cheap honest-message fix and to record it latent.
· ⚠ **AND "LATENT, NO PIN CAN REACH IT" WAS FALSE — caught by sweeping for
echoes of the string being renamed.** No SURFACE spelling reaches the residue
(`(sub ★)` is taken by the tail arm above), but the P3a-verify pin constructs it
directly as IR — `'((a (@sub (b)) c))` — and had been GREEN for its whole life
across a message asserting a prohibition that never existed, because it asserted
only `expr-panic?`. *Watching 5* verbatim, the second time this slice has paid
for it. The message is pinned now.
· **F7** — `select-steps-star-tail?`'s "⚠ EXACTLY TWO" precondition was ~40 lines
and two definitions from the function it guards; the definition moved up under
its header. Verified pure motion (added and removed blocks byte-identical).
· **MAJOR (b), `star-dup-key`** — *"drop the `*`"* removed. Wrong BY
CONSTRUCTION under [Q_U47] (the surviving key comes from the remainder, which
the star never touches) and MEASURED: `cfg{db.hosts db}` is still refused, so
the advice only relocated the error to the parser's gate. ⚠ The round-1 record's
proposed replacement (sub-block grouping) measured as an **L4 error** and was
NOT adopted — pinned so it cannot be adopted from the record later. Shipped
remedies, each RUN: `cfg{db^d2.hosts* db}` ✓, `cfg{db.hosts* db^d2}` ✓ (hence
"EITHER branch"), `cfg{db.hosts*}` alone ✓.
· **MAJOR (c), `star-l4-mixed`** — the old list was a NON-ACTION for half its
population: with both branches starred at different depths, "star the siblings
too" is already done and "drop the `^`" names a caret that is not there. ⭐ The
root error was talking about STARS when Q_U47 makes the landing a property of
the REMAINDER — MEASURED, `m2{a* b*}` works (both branch-initial) while
`m2{a* d.c*}` does not, though both are "starred on each". The message now
states the RULE and the fix is ADDING a caret (`m2{a* d^.c*}` ✓). The reverse
direction is not spellable (`a^k1*` → *"a rename target may not contain `*`"*).
· **MAJOR (a) — TRIED, MEASURED, REVERTED, and filed as [DEFERRED 123](../../../../DEFERRED.md).**
The tail arm's label echoes `(sₙ ★)` (`y2{a.b[0]*}` → ``0*``) where the sibling
seat labels from the whole branch. `(append path steps)` looks free — `path` IS
the consumed prefix, measured `()` at top level so it does not double-count —
but `path` stores bare NAMES, so `y3{a^.b[0]*}`, `y3{a.b[0]*}` and
`y3{a^r.b[0]*}` ALL rendered ``a.b.0*``: in a multi-branch block that names a
SIBLING as the failing branch. **A label that identifies too little beats one
that identifies the wrong thing** — this round's own doctrine, applied against
my own fix. ⭐ And the lossiness is SYSTEMIC: `format-select-fail`'s `branch-str`
already dot-joins `path` for every other fail kind, so it carries the same
collapse today, unmeasured.
· **DEFERRED 122** — the parked pin un-parked by renaming its subject `s7` →
`subj`, and its comment corrected (it repeated 121's disproved diagnosis).
**Mutation-verified against the defect it exists for**: with round 1's `/deep`
recursion reverted, `subj{a^.{b.c*} b}` → `{:b @[9]}` at zero errors and the pin
reddens with that output in its message. The mechanism behind 122 is still NOT
located; the rename is a workaround and says so.

**⭐⭐ F1 — AND IT IS THE SAME CLASS A THIRD TIME, IN THE SIBLING FUNCTION.**
`split-caret-lexeme` has guarded *"the CONT contains a `*`"* since DEFERRED 90,
and that guard's own comment records the class being UNDER-COUNTED once already.
The MIRROR — *"the NAME contains a `^`"* — was never written in
`split-star-lexeme`, which returned the prefix VERBATIM. **Silent wrong answer,
because a caret-suffixed field name is spellable** (re-measured on the main
thread before acting):
```
def q := {:db {:hosts @[1 2] :hosts^ @[99]}}
q{db.hosts^*}  ⟹  {:db @[99]}   at ZERO errors   ← a field the user never wrote
```
⚠ **Only ONE of three bands was safe, and only by ARM ORDER**: `re-key-sym?`
precedes `star-sym?` branch-initially, so `cfg{db^*}` reaches the caret splitter.
The `$dot-access` and ω bands call their star arms FIRST, making that guard
structurally unreachable. **DEFERRED 90 declares the precedence requirement
"✅ DISCHARGED" — and every worked example in it is BRANCH-INITIAL**, i.e. the one
band where the guard is reached. An enumeration that is band-incomplete, and its
own examples are why nobody noticed.
⚠ **PROVENANCE splits by band**: the DOT band is a **C2 REGRESSION** (the depth-≥2
shield caught it — a mid-branch caret-star has ≥2 prefix steps BY CONSTRUCTION —
and C2 removed the shield); the ω band is pre-existing from the B2 mint.
The guard went in `split-star-lexeme` rather than the two arms, because there it
covers every caller BY CONSTRUCTION — the arms' ORDER is what failed — and FIRST,
for the same reason its sibling's is hoisted.

**F3 — round 1's fix generating round 1's own defect class.** The hoist existed
so the rule could be asked *at every layer-computing seat*; `grep -rn
select-step-makes-no-layer` returned **zero hits in reduction.rkt**. The
unguarded seat carried the invariant as PROSE on the blank line C2's shield had
occupied, six lines under a header forbidding the excuse — `pipeline.md`
§ "Exhaustive Walkers" red flag #1 verbatim — while its sibling twelve lines away
already panicked on the same condition. Two seats, opposite policies.
⚠ **HONEST BOUND, recorded because the alternative overclaims**: F3(a) is LATENT
and **could not be exercised**. Disabling TYPING's guard to make reduction's fire
still refused `y{a^[0]*}`, through a DIFFERENT typing arm (`star-leaf`) — so the
shape is prevented by two independent typing routes and the new guard is
unreached. Correct on the twins' doctrine, and unexercised; the NEXT shield
removal is what makes it load-bearing, which is exactly how round 1's defect #3
became reachable.

**⚠ A LANDMINE, written down BEFORE it is stepped on.** [DEFERRED 117](../../../../DEFERRED.md)
says widen the L4 gate to `/deep`. But `star-l4-mixed`'s diagnostic renders
`(findf … (ormap select-star-step? br))` using the **old top-level test**. Widen
the gate without the `findf` and it returns `#f` into `pp-select-branch` on the
ERROR path — the whole-file-abort shape this track has already shipped once.
**The two must move in one edit.**

**⚠ AND THE RECORDED FIX FOR ONE OWED MAJOR IS ITSELF WRONG — measured.** The
round-1 record proposes adopting the parser's *"group same-head branches into one
sub-block"* remedy for `star-dup-key`. Measured: `cfg{db.{hosts* ports}}` → an
**L4 mixed-sorts error**. Following the record would have replaced a non-working
remedy with a different non-working remedy — the defect class being fixed,
repeated. **Verified-working remedies**: the `^k'` rename
(`cfg{db^d2.hosts* db}` → `{:d2 @[1 2], :db {…}}`) for the dup, and **ADDING** a
caret (`m{a* b^.c*}` → `⟨…⟩`) for the both-starred L4 case. ⭐ And the dup
remedy's defect is STRUCTURAL, not per-example: under [Q_U47](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u47) the
surviving key comes from the REMAINDER, which the star never touches, so dropping
the star can NEVER resolve a collision.

⚠ **KNOWN NARROWNESS, pinned rather than hidden**: the ordinal refusal's label
renders `0*` (the tail steps) rather than the branch the user wrote. The tail arm
only has the tail; compounded by DEFERRED 113. The REASON is accurate, which is
what Q_U46 asked for; the ECHO is not yet.

**⭐⭐ THE IMPLEMENTATION SHAPE — CORRECTED 2026-08-12 BY TRACING THE ARMS, and
both errors were mine, written an hour earlier in this same section.** Q_U46's
text and the first cut of this table said *"split the prefix into (outer-steps,
last-step) … then re-nest through the outer steps"*, and that C1 should
*"factor the re-nest decision as a flag"*. **Neither survives contact:**

1. **THERE IS NO PREFIX SPLIT. The landing EMERGES from which caller receives the
   bare join** — which is what makes Q_U47's rule ("the component the remainder
   would produce") true by construction rather than by computation. One shared
   helper returns the joined VALUE; three callers wrap it, and each is already
   the remainder's own arm:
   · **`star-branch-entries`** — remainder EMPTY → `(cons #f joined)`, keyless.
     Depth-1, unchanged.
   · **`select-below-field`**'s new star-TAIL arm → returns the join **BARE**;
     the key arm above it (typing-core.rkt, *"(cons label (record-field bt …))"*)
     re-nests it under the surviving label. **The re-nest is genuinely free.**
   · **`select-below-components`**'s twin arm → `(cons #f joined)`, keyless,
     spliced at the level by the `'dissolve` arm.
   Traced: `cfg{db.hosts*}` reaches the second (keyed `:db`), `cfg{db^.hosts*}`
   the third (dissolve splices, keyless), and `vh{0.{0}*}` the ord-branch head
   arm, which already wraps `(cons #f …)` — so its keyless landing falls out with
   no star-specific code at all.
2. **THE ARM DISPATCHES ON "`steps` ENDS IN A STAR", NOT ON `(car steps)`.** A
   star is never the HEAD of a below-walk's step list; it is always the tail. An
   arm keyed on `(car steps)` — the obvious reading of "add a `star` arm" — would
   never fire.
3. **THEREFORE `*-` IS NOT A FLAG ON THIS PATH.** Under caller-re-nests the
   caller would wrap `*-`'s join too, which is exactly what `*-` must not do. Its
   implementation is instead `walk-to-leaf` — the **collapse descent `^-` itself
   uses** — returning a keyless component at the branch level. So
   [Q_U48](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u48)'s *"`*-` is to `*` what `^-` is to `^`"* is truer than the
   ruling claimed: they share an IMPLEMENTATION, not merely a shape.

⚠⚠ **C1 WAS RE-SCOPED MID-SLICE, AND THE REASON IS A VERIFICATION-STANDARD ONE
THAT ONLY APPEARED WHEN I TRIED TO WRITE THE PIN.** C1 was to land both star-TAIL
arms INERT, B1-style, verified by direct unit call. On the typing side that works
(`select-below-field` is now exported; a pin on `[hosts ★]` fails at HEAD by
returning the 1-tuple). **The reduction side has no such seam**: both
`star-entries` and `below-value` live *inside* `select-reduce`'s ~470-line scope
and neither is exportable, while `select-reduce` itself refuses a deep branch at
the shield. So that C1 would have shipped the typing arm directly pinned and the
reduction arm **mutation-tested only** — at the seat whose own comment says
landing either alone is *"not a half-measure but a REGRESSION"*, and where a
twin-order divergence already cost a whole-file abort. Verifying one twin to a
lower standard than the other is the wrong trade here.
**So C1 became the EXTRACTION** — hoist the join to module level in both files,
which makes both twins equally pinnable *and* escapes the `sort` shadow the audit
independently flagged — and **the tail arms moved to C2**, where they are thin
(call the helper, wrap per caller) and land together with the E2E that observes
them. The substance is verified symmetrically; the wiring ships with its
instrument.

⚠ **AND THE PRE-CHECK NARROWING IS SAFE, VERIFIED — but only because two [leaf]
classifiers already handle `star` deliberately.** C2 narrows the branch-level
star pre-check to the remainder-empty case so deep branches fall through to the
head dispatch. That exposes them to `select-branch-collapse` and
`select-branch-keyless?`, which B1 deliberately ordered AFTER the star arm.
Checked at HEAD: `select-branch-collapse` answers `#f` for a star with a recorded
reason (*"a `^-` collapse lifts exactly ONE flat entry … while a star lifts
MANY"*), and `select-branch-keyless?` answers `#f` (KEYED), so neither routes a
deep star into `walk-to-leaf` — which has **no star arm and raises**. The
narrowing is therefore safe *today*; if either classifier's star answer ever
moves, `walk-to-leaf` is the abort it lands in.
| **1b-iv-A** ✅ `b216f926` | **The instrument + the twin-order fix.** Failing-test-first pins for every seat in [Q_U49](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u49)'s worked table, `'block`-sorted or E2E (a `'path` pin discards the key and cannot tell keyed from keyless — the flip this slice rules on). **PLUS the `'flatten-synth` arm-order divergence, fixed FIRST**: typing tests it at position 3 of `join-contents` (after the nominal bucket) while reduction tests it as its FIRST cond arm, so the moment a nominal `*_` passes typing, reduction panics *"this join is positional"* — false for a champ layer. Latent today ONLY because typing refuses nominal first, i.e. masked by exactly the shield 1b-iv removes. Fourth instance of the class in this slice, and the first one caught BEFORE implementing. | Pure instrument + a defect fix whose shield is still up. |
| **1b-iv-B1** ✅ `714607dc` | **The nominal join lands in BOTH twins, INERT.** ⚠ **This is a SIGNATURE change, not an arm addition** — both twins DISCARD the layer's keys before joining (typing maps `record-field-type` over fields; reduction's `champ-values/canonical` ends `(map cdr …)`), and a keywise join needs them. So: a keyed-contents channel in both, the keywise join itself, and the content-vs-content collision refusal at the join. Still unreachable — the nominal refusal arm stays ahead of it. | The B1 shape that finally worked for 1b-iii after two reverts: semantics atomic across the twins, verified by direct call, zero surface change. |
| **1b-iv-B2** ✅ `0e2f5af7` | **THE SPLICE GOES LIVE.** Remove the nominal shield for the DECIDABLE case; splice at the callers — free at Seat A (`star-branch-entries` already returns a component list; the dissolve route delegates to it) and a `select-steps-star-tail?` test at the ord-branch arm for Seat B keyless. [Q_U38](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u38)'s splice-vs-sibling and splice-vs-splice checks come FREE at the existing level dup gate. ⚠ `expr-Map` contents split off with their own PERMANENT-refusal kind (no enumerable keys ⇒ never provable, never refutable). | Thin wiring + the E2E that observes it, landing together. |
| **1b-iv-C (scope flag, NOT this slice)** | `*_` is NOT carried by [Q_U49](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u49): its PREFIX SOURCE is under-specified and [Q_U41](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u41)'s two worked examples disagree (deleted layer's key vs contents' keys). Needs a ruling before code. Q_U39 separately defers the closer-adjacent band, so Q_U41's own showcase spelling is unreachable anyway. | Named rather than silently deferred. |
| **1b-v — the `*_` slice** 🔄 **A/B1/B1b/B2a + verify SHIPPED; B2b (the mint) remains** | [Q_U39](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u39)'s closer-adjacent **mint** (two bare sentinels, `$postfix-star-synth`) **+ `*_`'s SEMANTICS** — the shield lift, [Q_U51](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u51)'s prefix join, the **key threading** both twins skip, and the ω/broadcast Record arm's missing cont test. Scoped by [Q_U52](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u52): the mint alone would ship a better error message and leave Q_U51's capability non-existent. | The prefix rule is RULED and forced; the mint adds ONE spelling so the sentinel question collapses to two bare atoms. Record: [§5.P4e-1b-v](CIU_6_P4e-1b-v.md#p4e-1b-v) |
| **1b-v-B2b — the reader MINT** ✅ `940c9c88` | Widen the gate's lexeme conjunct to EXACT table membership; route the emit through the same lookup ([DEFERRED 129](../../../../DEFERRED.md)); [DEFERRED 130](../../../../DEFERRED.md)'s two refusal messages ride along. **MINIMAL by ruling** — reader-only, so the three live bands cannot regress. Preconditions the grounding found: the battery's `p4e-star-type` / `p4e-last-star-type` helpers are exact-lexeme `"*"` and structurally blind to `*_` ([DEFERRED 133](../../../../DEFERRED.md)), and the DEFERRED-108 snapshot needs a deliberate re-baseline. | Scoped by [Q_U53](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u53) part 1: the miss-case is ruled out at the GATE, not handled at the emit. Record: [§5.P4e-1b-v-B2b](CIU_6_P4e-1b-v.md#p4e-1b-v-b2b) · shipped: [§5.P4e-1b-v-B2b-shipped](CIU_6_P4e-1b-v.md#p4e-1b-v-b2b-shipped) |
| **1b-v-C — the FOLD** ✅ `24fc1be4` (pins) · `a492bbb7` | `split-star-lexeme`'s suffix dispatch AND the printer's cont→lexeme delegate to the family table, so the four bands and every star label share ONE semantic authority; site 3 (`form-deps`) DERIVED, site 4 (the matrix) PINNED. Behaviour-preserving on every input. | [Q_U53](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u53) part 2 + [Q_U54](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u54) (the printer folds too; site 3 derived, site 4 pinned). Record: [§5.P4e-1b-v-C](CIU_6_P4e-1b-v.md#p4e-1b-v-c) |
| **1b-vi — the star-COLLAPSE slice** 🔄 (**opened 2026-10-13**, CIU 6 branch `ciu6-path-selection`; grounding: [audit](../audits/2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md); [Q_U55](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u55) ✅ A — refuse, `^-` aligned; [Q_U56](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u56) ✅ (a) — `*->` guided in selection territory; [Q_U57](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u57) ✅ P — `*-_` names the whole collapsed path; [Q_U58](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u58) ✅ M + slicing A→B→C→D; **implementing — tracker [§5.P4e-1b-vi](CIU_6_P4e-1b-vi.md#p4e-1b-vi)**) | **`*-`** ([Q_U48](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u48)) · the **`*-_`** decision · the cont-axis **totality dispatcher** · plus TWO owed rulings [Q_U52](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u52) surfaced: what "total collapse" does to a **renamed** ancestor (`^p` and `^` are mutually exclusive spellings of one step), and the **`*->` token boundary** (`>` breaks the identifier, so `x{a*-> b}` would become a `*-` step plus a stray `>`). | Split from 1b-v because those two are RULINGS, not implementation, and because `*-` is the spelling that forces the totality work. ⭐ Sequenced AFTER the fold [owner] so ruling `*-` costs a table row, not four edits. |
| **P4e-2** | the `.*` retirement inventory (`.*` → a guided refusal naming `x:*`, JD-1) + ravel as **`x:*`** ([Q_U63](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u63) = J): the `:*` production, ε as `(@bcast ε)`, the JD-2…4 messages and waypoint, the laws; plus DEFERRED 185's reader seats | ⚠ RE-SCOPED 2026-11-02 by Q_U63 · 🔄 **OPENED 2026-11-03**: design target + sub-slice plan A–F in [§5.P4e-2](CIU_6_P4e-2.md#p4e-2); mini-audit RA-1…13 in [its own document](../audits/2026-11-03_CIU_6_P4e-2_GROUNDING_AUDIT.md); E(ii) (`xs:0*` as a meaning) decided to ride, owner 2026-11-03; **A ✅ `8ecb7cbc`** (the stage table, 585) |

**⚠ TWO HOLES C2 OPENS, AND THEY ARE C2's TO CLOSE** — both found by the
grounding audit, neither in any prior record:

1. **The duplicate-output-key check has NO SEAT ANYWHERE.**
   `select-branch-top-keys` returns `'()` for every star branch (syntax.rkt), so
   the parser's `dup-output-key` cannot see a deep star's surviving key; typing
   still asserts the parser owns uniqueness (typing-core.rkt, *"duplicate-free
   … BY CONSTRUCTION"*); and nothing checks downstream. The moment a deep star's
   key survives, `cfg{db.hosts* db}` is a **silent last-win** at both layers
   (`make-record`'s `;; last write wins` and `entries->value`'s `champ-insert`).
   **C2 opens the seat Q_U38 named, with its star-vs-written-sibling arm; 1b-iv
   extends the SAME seat to the general rule (star-vs-star lifted keys, the
   `'dyn` tail).** That is one seat built incrementally, NOT the dual-path
   scaffolding 1b-ii refused — each arm is the real check, not a placeholder.
   ⚠ It cannot be closed earlier: it is unreachable until C2 makes a deep star's
   key survive, so there is nothing to test against before then.
2. **The `star-l4-mixed` message acquires a lying population.** It hardcodes that
   the star branch is the KEYLESS one and `findf`s the first star branch
   regardless of which side is keyless (typing-errors.rkt + typing-core.rkt), so
   a deep KEYED star beside a keyless sibling (`cfg{db.hosts* ports^}`) would be
   told it *"contributes a KEYLESS component"* — the opposite of what happened.
   Message-only, at a site C2 makes reachable, so it lands with C2.

**⚠ THE INSTRUMENT OBLIGATION, and it is the reason C's battery is written
FIRST.** *Deleting the shield produces a GREEN WRONG ANSWER, not a failure.*
Under the shipped branch-root algorithm with the shield merely removed,
`rows{k:s*}` returns the RAW field keyless at **0 errors** — the silent
wrong answer the shield's own comment predicts. And five of the six deep-shape
battery pins assert `#rx"."`, which matches anything. Three consequences:
· **write the depth-≥2 assertions BEFORE touching either shield**;
· **new pins must be `'block`-sorted or E2E** — every existing star unit pin uses
  `'path`, whose arm extracts `(record-field-type (cdr (car comps)))` and
  DISCARDS the key, so a `'path` pin cannot tell keyed from keyless and would be
  vacuous for exactly the flip C rules on;
· **the headline pin is the WEAK one** — a key `sₙ` yields exactly ONE content, so
  `cfg{db.hosts*}`'s concat is an identity and cannot discriminate a broken join
  (and it is what `^..` already does — MEASURED `{:db @[1 2]}`). The
  discriminating shapes are the multi-content ones, `two{a.{x y}*}` and
  `cfg{db.{hosts ports}*}`, and they are also where the slice's real new power
  lives.

**⚠ BAND AGREEMENT IS STRUCTURAL, NOT ALGORITHMIC — do not pin it as if the path
band implemented this.** Q_U13's NEST mints one `$select-path` carrier per level,
so the path band never builds a multi-step prefix and `cfg.db.hosts*` succeeds at
depth 1 without the shield ever firing. **Q_U46/Q_U47 are a BLOCK-BAND-ONLY
change.** And the bands genuinely DISAGREE on ω — MEASURED `rows.k:s*` →
`@[1 2 3]` against the block-band target `{:k {:s @[1 2 3]}}`, because the block
ω preserves the inner key and the path ω does not. Band agreement is a valid pin
for the KEY case only.

**Recorded as settled, so it is not re-opened**: the twins' `seen` contract is
uniform (both FORWARD — the record's claim that typing resets was stale, fixed at
B1), and the empty-layer asymmetry (typing refuses, reduction mints `@[]`) is a
DELIBERATE B1 decision in the safe direction, not an open question.

**Out of the P4e line entirely**: [DEFERRED 116](../../../../DEFERRED.md), the bracket-ordinal
redundancy — it touches the reader's adjacency mint, nowhere near this seat.

<a id="p4e-1b-iii"></a>

##### §5.P4e-1b-iii — the VECTOR semantics  (mini-audit 2026-08-11 · ⬜ not implemented)

**⭐⭐ THE FINDING: THE STAR IS A BRANCH-LEVEL TRANSFORM, NOT A STEP ARM — and
that is now the THIRD walk with the same requirement.** `branch-entries`
(reduction.rkt) opens with branch-level pre-classifications — `col` (collapse),
then `select-branch-keyless?` — and only then dispatches on the head step. The
star belongs with the first group, for the same reason that moved the
[Q_U43](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u43) arm at 1b-ii: **the star removes the label the preceding step
would have contributed.** `cfg{database}*` must not yield `{:database …}` — the
`:database` key IS the layer being deleted — but that label is decided in the
`key`/`caret`/`sub` arm at the branch HEAD, long before a trailing star is
looked at. A `case` arm for `'star` fires too late to unmake it. Same for the
typing twin `select-branch-entries` (typing-core.rkt), which has the identical
cond shape and returns `(values components failure)`.

**THE ALGORITHM, one rule, checked against four cases.** *Take the deleted
layer's CONTENTS — a Map's VALUES or a vector's ELEMENTS — and JOIN them; the
join's sort follows the contents.* With `prefix` = the branch's steps before the
star, the layer is `(below-value v prefix seen)` — or `v` itself when the star is
branch-initial. ⚠ `below-value` RE-NESTS (`cfg{database}` → `{:database …}`),
which is exactly right here: that re-nested value IS the layer being deleted.

⚠⚠ **THE SENTENCE ABOVE IS SUPERSEDED AT DEPTH ≥ 2 BY [Q_U46](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u46), AND IT IS
THE SENTENCE THE IMPLEMENTATION INHERITED.** "The below-walk over the WHOLE
prefix is the layer" describes the BRANCH-ROOT reading. It is correct at prefix
depth ≤ 1 — where every worked example in every ruling lives, so the divergence
was invisible — and WRONG at depth ≥ 2, where Q_U40's own words ("the layer the
PRECEDING step contributed") and this sentence give different answers. Q_U46
rules the preceding-step reading. **Read at depth ≥ 2: the layer is the one the
LAST PREFIX STEP made; steps above it re-nest around the join unchanged.** The
branch-root reading is additionally self-defeating — a bare chain re-nests to a
single-key map at every level, so its contents are always exactly one thing and
the "join" is an identity unwrap that `^` already spells.

| spelling | layer | contents | join |
|---|---|---|---|
| `cfg{database}*` | `{:database {…}}` | one Map | `{:url …, :pool-size …}` ≡ `cfg.database` |
| `cfg{database*}` | `{:database {…}}` | one Map | splices at the BLOCK level |
| `m2{a b}*` | `{:a {:x 1} :b {:y 2}}` | two Maps | `{:x 1, :y 2}` |
| `rowsv:tags*` | `@[@[1 2] @[3]]` | two vectors | `@[1 2 3]` — spec's `ω·ω→ω` |
| `vv:{0 1}*` | `@[⟨1 2⟩ ⟨3 4⟩]` | two tuples | `⟨1 2 3 4⟩` — the ravel |

**1b-iii implements ONLY the all-contents-are-vectors rows** (concat, total, no
collision possible). Map contents are 1b-iv.
⚠ **The condition is on the CONTENTS, not the layer** — a Map layer whose values
are vectors joins by CONCAT and is therefore 1b-iii, not 1b-iv. "The sort follows
the CONTENTS" is Q_U40's wording and it decides this.

**SEAT MIGRATION, owner-assented 2026-08-11.** The parser cannot know the sort —
that is the whole basis of Q_U38/Q_U43 — so `segment-select-items` must MINT the
step unconditionally and the nominal refusal moves DOWNSTREAM to typing, keeping
its *"(flatten) is not implemented yet"* text (nominal genuinely lands at 1b-iv).
Consequence: several P4e-1a pins move seat and must be migrated **with the
reasoning recorded, not silently** — including `[c{a}]*`, whose predecessor
analysis is parser-side and needs re-checking rather than re-pointing.

**Reduction's non-vector arm is an INVARIANT guard, not a user error** — typing
runs first and carries the user-facing refusal, so a non-vector reaching the
value layer is a compiler-invariant violation. That is the established split at
this seat (the `bcast` arm's own comment states it).

**Scoped OUT of 1b-iii, to be refused loudly**: a MID-branch star
(`cfg{database*.x}`). Q_U40 defines the star against the preceding layer; a step
AFTER it descends into the joined result, which is meaningful but unruled. 1b-iii
handles a TRAILING star only.

**Sites**: `segment-select-items` ×4 bands (the `$postfix-star` item + the three
fused-identifier bands via `split-star-lexeme`) · `branch-entries` +
`below-value` (reduction) · `select-branch-entries` + `select-below-field`
(typing) · the vector parked tests · the migrated 1a pins.
**Value accessors, verified**: `expr-champ-racket-champ` + `champ-entries` ·
`expr-rrb-racket-rrb` + `rrb-size`/`rrb-get` · assembly via `entries->value`,
whose keyed/keyless fork reads the FIRST component's key.

**⛔ ATTEMPT 1 (2026-08-11) — BUILT, VERIFIED, REVERTED.** Patch parked at the
session scratchpad (`slice-1b-iii-attempt1.patch`, 393 lines), same disposition
as 1a-iii attempt 1. The build was CLOSE — the headline cases were right
(`rowsv:tags*` → `@[1 2 3] : [PVec Int]`, `vv{0 1}*` → `@[1 2 3 4]`, nominal
refusing, battery 482 green, neighbourhood 325 green) — and it was **wrong in
the one place the whole slice turns on**. Adversarial verify `wf_ba4a51b3-2f8`;
all three re-measured on the main thread before the revert.

**⭐⭐ THE ROOT CAUSE IS ONE THING, AND I HAD WRITTEN IT DOWN MYSELF.**
`select-branch-top-keys` returns `'()` for a star-bearing branch — [Q_U43](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u43)'s
recorded *absence* of a check — and the comment I wrote at that arm in **1b-ii**
says, verbatim: *"safe ONLY because the star cannot reach this walk at 1b-ii (the
parser refuses first). THE CARVE-OUT AT THE TWO GATES IS 1b-iv WORK."* **The
seat migration IS what makes the star reach a block.** I invalidated my own
stated precondition one slice later and did not re-read the warning I had left
at the exact site. The carve-out is not 1b-iv work; **it is the price of the seat
migration and must land WITH it.**

**THE THREE VERIFIED DEFECTS:**
1. **WHOLE-FILE ABORT — a `^` after a star.** `cfg{database*.host^}` → empty
   output, not even the `data` decl. A **TWIN ORDER DIVERGENCE**: reduction
   checks the star FIRST (before `col`/`keyless?`), typing checks it LAST — so a
   caret leaf routes into `walk-to-leaf`, which has no `star` arm →
   `select-step-kind-unhandled` → raise. ⚠ **The typing arm's own comment
   asserted the parity that does not exist** (*"BRANCH-LEVEL, before the head
   dispatch, for the same reason as the reduction twin"*). `^_` does NOT abort
   (neither collapse nor dissolve), which is why the shape hides.
2. **WHOLE-FILE ABORT — a star beside a keyed sibling.** `m{name tags*}` →
   `symbol<?: contract violation … given: #f`, empty output. The star's keyless
   component reaches `make-record 'keyword` with a `#f` label, because L4
   (`mixed-sorts?`) cannot see it — Q_U43's `'()` again.
3. **SILENT WRONG ANSWER — the same block, branches reordered.** `m{tags* name}`
   → `@[@[@[1 2] @[3]] "x"] : ⟨[PVec [PVec Int]] String⟩` at **ZERO errors**;
   `:name` is silently discarded, because `entries->value` reads only the FIRST
   entry's key to choose keyed-vs-keyless. **So one illegal block either takes
   the file down or silently loses data purely by the order the user wrote the
   branches in.**

**TWO FURTHER FINDINGS, both real, neither blocking:**
- **Champ order.** A Map layer whose values are vectors concatenates in CHAMP
  HASH order: `mm{zz aa mm}*` and `mm{mm aa zz}*` are **byte-identical** and
  neither is written order. That path is deliberately in 1b-iii's scope ("the
  sort follows the CONTENTS"), and its own comment cites §3.6 rule 5's *written
  order* — which a champ cannot honour. Needs a ruling or a scope cut.
- **Diagnostic degradation.** The refusal stopped naming the user's spelling:
  six structurally different spellings all render the byte-identical message with
  a bare `*`. HEAD interpolated `database*` / `:tags*` / `.name*`. The
  typing-errors comment claims the wording is preserved — the wording is, the
  **interpolated argument** is not, and that was the guided part. Corollary:
  `star-not-yet-message` (parser.rkt) reaches **zero callers**.

**⛔ ATTEMPT 2 (2026-08-11) — BUILT, VERIFIED, REVERTED. Round 2 found defects
IN THE FIXES, which is this track's single most reliable pattern.** Patch parked
(`slice-1b-iii-attempt2.patch`, 603 lines). Verify `wf_096fc42a-87d`; both
blocking defects re-measured on the main thread before the revert.
All four round-1 fixes DID hold — `cfg{database*.host^}` became a per-command
error, both branch orders of `m{name tags*}` gave the guided L4 error, Q_U44's
canonical order and the owner's `mm{zz* aa* mm*}*` recovery spelling both worked,
battery 486 / 0 / 0, neighbourhood 382. **Two NEW defects, both introduced by the
fixes themselves:**
1. **⭐⭐ BLOCKING — SILENT WRONG ANSWER, and a REGRESSION the seat migration
   introduced.** The `$postfix-star` arm ignores `cur` and unconditionally calls
   `(closed-acc)`, so a postfix `*` arriving INSIDE a block is silently re-based
   onto the SUBJECT as its own extra branch. Measured with
   `vh := @[@[@[1 2]] @[@[3]]]`: `vh{0.{0}*}` → `@[@[@[1 2]] @[@[1 2] @[3]]]` at
   **ZERO errors** — the second component is `concat(vh)`, the flatten of the
   WHOLE SUBJECT rather than of the sub-block the star was written on. At HEAD
   this arm was a guided per-command error. Its own comment justifies ignoring
   `cur` with "the star arrives alone" — true only for the OUTER `$select-path`
   carrier, not for an in-block arrival. Same class as round 1's
   `m{tags* name}`, one layer in.
   ⚠⚠ **FRAMING CORRECTED 2026-08-12, by reading the parked patch rather than
   inheriting this record — and the correction changes the FIX.** This entry
   first read *"all three sibling star arms respect `cur`; this one alone does
   not"*. **TWO do**: the ω arm and the `$dot-access` arm, both genuine
   CONTINUATION arms. The third — `star-sym?`, the fused `database*` band —
   **also calls `(closed-acc)` unconditionally, and is CORRECT to**, because a
   bare name always starts a branch (it sits beside `plain-key?`, which does the
   same). `closed-acc` is `(if cur (cons (reverse cur) acc) acc)`, so calling it
   closes the branch in progress and opens a new one holding only the star —
   which IS the branch-initial reading, i.e. operate on the subject.
   **The real defect**: the bare `$postfix-star` sentinel is the one arm
   reachable in **BOTH** positions — branch-initial as the outer `$select-path`
   carrier, continuation when written in-block — and it assumes only the first.
   So the fix is a **position decision, not a transplant from a sibling**, and
   the missing pin must spell a postfix star **AFTER A SUB-BLOCK**, where `cur`
   is non-empty (`vh{0.{0}*}` is that shape).
   ⚠⚠ **THE PARENTHETICAL THIS CORRECTION ORIGINALLY CARRIED IS ITSELF FALSIFIED
   — see [the attempt-3 audit](#p4e-1b-iii-audit3) finding A5.** It read *"`vh{0*}`
   is not — there the star fuses into the lexeme and takes the `star-sym?` arm"*.
   MEASURED at HEAD: nothing fuses (the mint needs a preceding CLOSER and `0` is a
   number token), so `0` and `*` are separate items and the message is
   `split-star-lexeme`'s first-star-at-zero. It reaches `star-sym?` only on the
   `[(not name) (fail cont)]` leg. **The correction was right about the defect and
   wrong about the neighbouring band, by inheriting a reading instead of measuring
   it — the same failure it was written to fix.** A1's position rule (derived from
   the mint) is the durable statement; this cell is kept as written rather than
   silently repaired, because the pattern is the finding.
2. **⭐ BLOCKING — Q_U44's fix does not implement the order it claims.**
   `champ-values/canonical` sorts by `(format "~a" key)`, which for a keyword key
   renders the TRANSPARENT STRUCT `#(struct:expr-keyword NAME)`. The trailing `)`
   (ASCII 41) makes the order diverge from `symbol<?` whenever one key is a
   strict prefix of a sibling whose next char is below `)` — `!`, `$`, `%`, `&`,
   `'`, all legal in Prologos identifiers. Measured: `bang := {:a @[1] :a! @[2]}`
   types as `{:a … :a! …}` (symbol<? order) but `bang{a a!}*` → `@[2 1]`, `:a!`'s
   value FIRST. **The code comment AND the new battery pin both assert
   "canonical = `symbol<?` over the keys" — a claim the implementation does not
   keep**, and no test key set separates them. Two further consequences of
   sorting a struct's DISPLAY form: mixed key kinds order by struct NAME, and
   renaming `expr-keyword` would silently reorder every flatten in the language.
   Fix is to sort on the keyword's NAME with `symbol<?`, matching `make-record`.
**Three MAJOR non-blocking findings, all diagnostic quality:**
· the MID-BRANCH star's message is a LYING DIAGNOSTIC — label degrades to a bare
  `*` (because `select-step-name` of a star is `#f`) and the text claims the
  shape "needs the nominal (Map-valued) case" even when the contents are ALL
  VECTORS. The accurate sentence already exists in reduction.rkt and is
  unreachable by design. `*_` mid-branch is worse: it renders bare `*` too,
  because the suffix is read off `(car (reverse b))`, which is not the star.
· a LEAF-contents refusal says "not implemented yet" for what Q_U40 rules a
  PERMANENT error — there is no future case that will make a String leaf join.
· `(list #f)` is honest for what 1b-iii ACCEPTS but is also applied to shapes it
  REFUSES, where it PRE-EMPTS the star's own message with an L4 sort error.

<a id="p4e-1b-iii-a"></a>

##### §5.P4e-1b-iii-A — make the observations trustworthy  (✅ 2026-08-12)

The audit's findings do not fit one atomic slice, and B below is irreducible (the
seat migration forces the twins' arms; an arm that refuses in one slice and joins
in the next is the dual-path scaffolding 1b-ii refused to build; and the join
forces the classification, or `mm{zz* aa}` reaches `make-record` with a `#f` label
and raises). So A absorbs everything star-free, and B is pre-pinned instead of
made smaller. **Thesis: you cannot verify semantics with a broken instrument and a
lying echo.** Battery 481 → **484**; every item landed INERT for star behaviour.

| # | landed | finding |
|---|---|---|
| 1 | `f0d91853` | **The battery's own instrument was vacuous.** `p4e1-has?` ormapped EVERY output including setup `def` lines, so an expectation that is a substring of a subject's printed type could never fail — measured on the attempt-2 patch's headline pin against the STARLESS control. Fixed LOUDLY (restrict to the final command's output) so vacuous pins redden rather than needing to be guessed at; `p4e1-any-has?` is the visible opt-out, `p4e1-type=?` compares types exactly. ⚠ **My first pin for it OVER-CLAIMED** — it asserted the restriction kills the `[PVec Int]` regex, which it cannot, because the WRONG answer contains that substring too. The two defects are independent; the pin now separates them and pins the containment half as STILL LIVE. ⚠ Exactly ONE pin reddened across 35 call sites, and it was mine — which does NOT vindicate the other 34: the loud fix only catches a pin depending EXCLUSIVELY on setup output. |
| 4 | `43c91859` | **The two rotted PRECONDITIONS replaced with a checkable invariant** — the structural point of the slice. `select-branch-keyless?`'s *"the parser refuses the star before any branch walk runs"* becomes *"every production consumer pre-checks for a star before consulting this"*, with all three named and the grep that audits them. `select-branch-top-keys`' *"safe only while the star cannot reach a block; THE CARVE-OUT IS 1b-iv WORK"* becomes what must actually be checked, and now **forbids the parked patch's `(list #f)`** in writing. A third instance of the same comment class was found in the BATTERY and corrected. Q_U45's legality pair parked. |
| 2 | `e38845a9` | **Canonical key order gets ONE definition** — comparator in `syntax.rkt` (the only home upstream of both twins), walker at `reduction.rkt` MODULE level because `select-reduce`'s `sort` parameter shadows Racket's `sort` for ~470 lines. It returns `#f` rather than inventing an order for a key it cannot speak for. ⭐ **The pin's KEY SET is the finding**: `{:a :a!}` separates `symbol<?` from the struct-display order where attempt 2's `aa`/`mm`/`zz` set agreed under both — and the pin carries an explicit MUTATION GUARD asserting they disagree, so it tells us if it ever stops being evidence. **Mutation-tested**: attempt 2's exact ordering turns it red. |
| 3 | `dd5d145c` | **The FAIL-KIND axis was a silent trapdoor.** `format-select-fail`'s `[else #f]` falls through to the generic message, and NESTED it is a contract violation a blanket handler swallows. Measured: all 14 live kinds have arms, so it was UNREACHABLE — a pure trapdoor — and 1b-iii-B adds THREE kinds to this axis. Made total, and it **reports rather than raises**: a raise in the message formatter is a whole-file abort on the `infer` path. |
| 5 | [DEFERRED 113](../../../../DEFERRED.md) | **`pp-expr`'s `'path` arm hardcodes `.`** while `pp-select-branch` honours `first?` — the identical bug one arm over was fixed at P4d-0 slice 5 and the sibling never swept. ⚠ **FILED, NOT FIXED, and the reason is a correction to the audit**: its user-visible claim (`c{a}*` echoes as `c{a}.*`) **did not reproduce** — the probe's diagnostics never route through that arm. The CODE SHAPE is verified; the rendering is not. What is owed is a diagnostic that actually reaches it. |

**⚠ B IS NOT IRREDUCIBLE — CORRECTED 2026-08-12, and I had asserted otherwise.**
Setting B up, the split fell out: land BOTH TWINS' REAL ARMS **INERT** first, then
migrate the parser seat. At HEAD the parser still refuses, so no star reaches the
twins and the arms are correct-but-unreachable code — exactly how 1a-ii landed the
Tier-O arms. ⚠ This is NOT the refusing-arm scaffolding 1b-ii rejected: that was a
placeholder a later slice would REPLACE, whereas these are the actual join, merely
not yet live. Twin atomicity is preserved (both in one commit) and the largest
chunk of risk leaves the migration commit.

| slice | content | why it is safe alone |
|---|---|---|
| **1b-iii-B1** ✅ `1c0c5123` | Both twins' star arms at MATCHING positions (FIRST, ahead of `col`/`keyless?`) · the layer walk · vector concat via A's helper + `rrb-concat` · **EIGHT fail kinds** (not three — mid-branch · leaf-PERMANENT · nominal · hetero · ω-tuple · not-yet · open-row · synth-positional · l4-mixed each say the TRUE thing) · typing's L4 check in `select-level-components` (Q_U43's migration; both branch orders guided) · `seen` FORWARDED in both twins · reduction's 4 assembly sites through ONE star-gated `level-entries` guard | ✅ SHIPPED INERT. Battery 484 → **494** failing-test-first (10 pins failing at HEAD for the right reason, then green) · E2E star surface **byte-identical to HEAD** · neighbourhood 416 `[8/8]` · **mutation-tested PER TWIN** — each twin's pins redden exactly their own side. ⚠ The first mutant protocol was broken TWICE: `git checkout` as mutant-restore left a STALE `.zo` (exposed by a typing-only raise signature in mutant B's output) and then DISCARDED the uncommitted implementation itself. **Never git-checkout to undo a mutant over uncommitted work — invert the mutant, force the rebuild.** |
| **1b-iii-B2** ✅ `d5934397` | **THE FLATTEN IS LIVE** — the four bands MINT; the position rule lands as DERIVED (`cur = #f` ⇔ subject; non-`#f` ⇔ cons; position H decided: the star PRESERVES `cur-subbed?`) · `star-not-yet-message` retired definition-and-all · nominal bucket refined mid-slice (nat-record contents took "Map-valued" — measured live, fixed: keywise-joinable only) · **four** seat-sensitive pins migrated, found EMPIRICALLY (exactly C31's shape), each with proposition-survives reasoning · live pins: seven arrival positions + Q_U44 E2E (canonical + recovery, pinned as differing) + Q_U45 E2E (arity non-equivalence + the legality pair's vector half); Map halves stay parked for 1b-iv · ⭐ the migration handed **DEFERRED 113 its owed reproduction** (`users.:tags*` — the hardcoded `.`, live on a real diagnostic) | Measured live: `rowsv:tags*` → `@[1 2 3] : [PVec Int]` (ω·ω→ω) · canonical `@[3 4 5 6 1 2]` · recovery `@[1 2 3 4 5 6]` · ravel `@[1 2 3 4]` · L4 guided BOTH orders naming `tags*` · leaf PERMANENT · nominal not-yet · round 1's abort and round 2's silent wrong answer both dead. Battery 494 → **497** 0/0 · neighbourhood 416 `[8/8]` · acceptance 0 errors · adversarial verify delegated (`wf_30884180-93c`), rounds 2–3 budgeted; full suite queued behind it |

⚠ **B1's own traps, from the audit**: the twins DIVERGE on an empty layer
(typing's `(pair? contents)` refuses, reduction's `(andmap … '())` mints `@[]`)
and on `seen` (reduction forwards it, typing resets to `'()`) — decide both
explicitly, they are twin-contract questions nobody has ruled · typing's contents
arm needs the TAIL and PRESENCE guards the tree already ships
(`closed-keyword-row?`, syntax.rkt) or a `'dyn` row silently joins a SUBSET ·
reduction's non-vector arm is an INVARIANT guard reached via
`(return (expr-panic …))`, **never `error`** · and `champ-values/canonical`
returns `#f` for an un-orderable key, which is NOT "empty" — panic on it.

**⭐⭐ VERIFY ROUND 1 (`wf_30884180-93c`, 2026-08-12) — five distinct defects, the
battery green over every one; fixed/shielded at `5e4a3338`.** Deduped: the
star-omega-tuple format arm RAISED on every render (1 `~a`, 2 args) and the
blanket hint handler swallowed it to the bare generic — fixed, plus a RENDER
LOOP pinning all ten kinds' messages, which immediately caught two MORE wording
defects (open-row never named `*`; l4's remedy was abstract) · union contents
were branded PERMANENT — routed to hetero · an ω behind a key returned the RAW
field at 0 errors and `mm3{zz.q*}` took a false nominal — the **depth-≥2
divergence**, SHIELDED (below) · a match extra-pattern abort (pre-existing →
DEFERRED 103-sibling note) · `#p(a.b*)` (pre-existing →
[DEFERRED 114](../../../../DEFERRED.md)).

<a id="q-deep-prefix"></a>

**✅ RULED 2026-08-12 — [Q_U46](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u46) adopts B-splice: the star deletes the
layer its PRECEDING step made, and the join lands BARE below the surviving key.
The two gaps (an ordinal prefix; L2's normal form across a star) are ruled GUIDED
ERRORS. The shield below becomes the implementation target: replace the
`star-deep-prefix` refusal with the preceding-step layer walk in BOTH twins, keep
the refusal for the ordinal-prefix gap. Original framing retained for the
record:**

**⚠⚠ THE OWNER QUESTION — WHICH LAYER DOES A DEEP FLATTEN DELETE?** At prefix depth ≥ 2,
§5.P4e-1b-iii's own algorithm sentence (*"the below-walk over the prefix … that
re-nested value IS the layer"* — the branch-ROOT layer) and [Q_U40](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u40)'s
rule (*"the layer the PRECEDING step contributed"*) **give different answers**,
and every worked example in the ruling's battery is depth ≤ 1 where they
coincide. Worked divergence: `mm3 := {:zz {:q @[1 2]}}`, `mm3{zz.q*}` — the
ruling reads *delete `q`'s layer, keep `zz`'s nesting* → `{:zz @[1 2]}`; the
shipped sentence deletes the re-nest's OUTER layer → a false nominal refusal
(and, one shape over, an ω behind a key silently returned the raw field). Both
twins now REFUSE prefix length ≥ 2 (`star-deep-prefix`, guided, naming the
unruled question); depth ≤ 1 — every ruled example, the headline ω·ω→ω, Q_U44's
spellings — stays live. When ruled, the D4 algorithm sentence must be corrected
to match, and the shield becomes the implementation of the answer.

**B's pre-pinned set, still to write**: the six arrival positions · the legality
pair (parked) · the ω non-equivalence (parked, uncomment) · L★'s vector
non-equivalence (parked) · the discriminating key set (landed) · a tripwire
planting a star in a `rest` position at the four `select-step-kind-unhandled`
sites, so C32's unreachability argument stops living in an audit.

⚠ **THE PARKED PATCHES LIVE IN A PRIOR SESSION'S SCRATCHPAD**, not the current
one: `/private/tmp/claude-501/-Users-avanti-dev-projects-prologos/311a1847-2220-4539-bd51-0e2270a3625f/scratchpad/slice-1b-iii-attempt{1,2}.patch`
(attempt 2 = 427 added lines, six files: parser +42/−10 · reduction +105 ·
syntax +21/−1 · typing-core +78 · typing-errors +17 · battery +151/−29; it
`git apply --check`s clean at `7fd25f35`). Every "parked at the session
scratchpad" above means THAT path.

<a id="p4e-1b-iii-audit3"></a>

##### The attempt-3 mini-audit (2026-08-12, `wf_bbf1169e-340`) — the four-item list was NOT the work

6 partitioned read-only facets + the adversarial completeness critic, HEAD-pinned
`7fd25f35`, ~1.55M tokens, **37 critic findings · 17 capture gaps · 16 R-lens
targets**. Every claim below was R-lens-verified on the main thread before being
recorded. **Three of the four recorded items stand; the audit found the list is a
subset, and one of the four rested on a sentence that does not exist.**

**⭐⭐ A1 — THE POSITION RULE IS DERIVABLE, TOTAL, AND NEEDS NO `cur-subbed?`
TEST.** The reader mints `postfix-star` only for a `*` byte-adjacent to a
preceding token in `group-closer-types = '(rbracket rparen rbrace)`
(parse-reader.rkt:2081, :1619) — and a block's own `{` is an **OPENER**. So a bare
`$postfix-star` **can never be the first item of a block or sub-block payload**.
Therefore:
> `cur = #f` ⇔ the outer `$select-path` carrier ⇔ operate on the **SUBJECT**;
> `cur` non-`#f` ⇔ in-block ⇔ **CONS onto the branch**.

Derived from the mint, not transplanted from a sibling arm — which is what the
record's "respect `cur` like its siblings" framing would have produced.

**⭐ A1b — SIX ARRIVAL POSITIONS, MEASURED; THIS DOCUMENT RECORDED ONE.** All six
reach parser.rkt:1447 (probed at HEAD): (A) branch-initial outer carrier `c{a}*`
· (B) after a `.{…}` sub-block `vh{0.{0}*}` (`cur-subbed?`=#t) · **(C) after an
ORDINAL step `cfg{database[0]*}` (`cur-subbed?`=#f — in no record)** · (D) after
an in-block ω `m{k:{a}*}` · (E) after `^`-dissolve + sub `cfg{database^.{host}*}`
· (F) one level down via the recursive call `cfg{database.{host[0]*}}` (`sub?`=#t)
· plus mid-payload with a SIBLING after it, `cfg{database.{host}* name}`. **A fix
keyed on `cur-subbed?` covers one of six**; the `cur` rule covers all.

**⛔ A2 — `(list #f)` REFUSES [Q_U40](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u40)'s OWN HEADLINE EXAMPLE.** The patch's
Q_U43 pre-check answers `(list #f)` for every star branch — KEYLESS — and leaves
both parser gates live. Trace `m2{a* b}`: branch 1 → `(#f)`, branch 2 → `(b)`, so
`mixed-sorts?` (parser.rkt:1335) is `(and #t #t)` → **L4 error at the parser**,
against a spelling Q_U40 rules legal and calls the reason the branch form is
*strictly more expressive*. `(list #f)` is right for VECTOR contents and wrong for
MAP contents and **the parser cannot tell which** — the whole reason Q_U43 moved
the check to typing. See [Q_U45](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u45); found by the owner's uniformity
observation, not by a facet. *(Derived from the patch against the live gate; the
patch is not applied, so this is a failing-test-first pin, not a measurement.)*

**⛔ A3 — THE THIRD INSTANCE OF THE REVERT SHAPE IS SITTING UNTOUCHED.** Two
comments in `syntax.rkt` carry the SAME precondition the seat migration deletes,
and the patch addresses one:
· `select-branch-top-keys`' pre-check — *"Safe only while the star cannot reach a
  block; THE CARVE-OUT AT THE GATES IS 1b-iv WORK"* (syntax.rkt:1333-1337);
· `select-branch-keyless?` — *"the #f here is INERT (the parser refuses the star
  before any branch walk runs) and must not be read as a classification"*
  (syntax.rkt:1294-1301), **untouched by the patch, and its `(check-false …)` pin
  untouched too**.
After the patch, two classifiers in one file give **opposite** sort answers for
the same star branch (keyless vs keyed), both pinned. ⚠ And the pre-check's own
comment says `'()` *"moves both gates to typing"* — the patch's typing hunks
contain **no collision check and no sort check at all**, so a comment asserts as
done a migration that exists in no tree.

**⛔ A4 — THE MID-BRANCH SENTENCE DOES NOT EXIST.** This document said *"the
accurate mid-branch wording already exists in reduction.rkt and is unreachable"*.
**MEASURED: `grep flatten reduction.rkt` → 5 hits, all `flatten-union` /
`flatten-app`.** The sentence exists only inside the parked patch. The claim was
written from the patch's perspective as if applied — and attempt 3 starts from
HEAD, so it would have searched for it and found nothing.

**⛔ A5 — MY OWN 2026-08-12 PARENTHETICAL IS FALSIFIED, and it made an
unimplemented band look implemented.** I wrote that `vh{0*}` "is not that shape —
there the star fuses into the lexeme and takes the `star-sym?` arm". **MEASURED at
HEAD: `vh{0*}` → `` `*` — `*` is postfix; it attaches to the END of a segment ``**
— `split-star-lexeme`'s first-star-at-zero message, which can only arise if the
lexeme IS `*`, i.e. `0` and `*` are SEPARATE items and **nothing fuses** (the mint
needs a preceding CLOSER; `0` is a number token). It does take `star-sym?`, but on
the `[(not name) (fail cont)]` leg. **The in-block ordinal band `m{0*}` is
unimplemented and its message tells the user to do what they already did** — the
DEFERRED 101 "unspellable ordinal splat", still live. Same failure class as the
one that correction was fixing: I inherited a reading instead of measuring.

**⛔ A6 — Q_U44 NAMES HALF OF `make-record`.** syntax.rkt:1406-1413 DEDUPS
last-write-wins via `make-hash` and THEN forks on key-domain — `symbol<?` for
`'keyword`, `<` for `'nat`. A helper written to the ruling as stated cannot serve
a nat-domain layer, and non-keyword champ keys are reachable at runtime.

**⛔ A7 — THE HEADLINE NEW INSTRUMENT IS VACUOUS AND ITS COMMENT CLAIMS THE
OPPOSITE.** `p4e1-has?` (tests:6314) `ormap`s over **all** per-command output
**including the setup `def` lines**, and `def rowsv` itself renders
`rowsv : [PVec {:tags [PVec Int]}]` — which contains `[PVec Int]`, as does the
WRONG answer `[PVec [PVec Int]]`. The patch's type-collapse check therefore cannot
fail, while its comment calls it *"the assertion that caught the implementation's
one real defect"*. **Systemic**: any expectation whose regex is a substring of a
subject's printed value or type is silently vacuous.

**FURTHER VERIFIED FINDINGS, each a slice obligation** — `star-not-yet-message`
has FOUR callers (not the census's 5); the patch removes all four but not the
DEFINITION, leaving dead code carrying a live-contract comment (parser.rkt:1254) ·
`format-select-fail` ends in `[else #f]` (typing-errors.rkt:600), so splitting the
fail kind into three walks into a SILENT catch-all — and three nesting sites
`string-append` the recursive result, so a `#f` there is a contract violation that
`select-block-hint`'s blanket handler (:603, one of FOUR in that file) swallows ·
the same star raise is a WHOLE-FILE ABORT on the primary `infer` path and a
silently-swallowed `#f` on the hint path · the typing arm lacks a TAIL guard (a
`'dyn` row exposes only KNOWN fields ⇒ silent SUBSET join) and a PRESENCE guard,
both of which the tree already ships (`closed-keyword-row?`, syntax.rkt:1435) ·
the twins DIVERGE on an empty layer (typing's `(pair? contents)` refuses;
reduction's `(andmap … '())` mints `@[]`) and on `seen` (reduction forwards,
typing resets to `'()`) · `rrb-concat` already exists and the patch open-codes the
join · the parser's gate-safety comment (parser.rkt:1323) claims
`select-branch-top-keys` is "the SHARED walk … typing + reduction use" — **it has
ZERO references in either file** · `pp-expr`'s `'path` arm hardcodes a `.`
(pretty-print.rkt:592), so `c{a}*` will echo as the nonexistent `c{a}.*` — the
identical bug one arm over was fixed at P4d-0 slice 5 and the sibling not swept ·
the ω non-equivalence pin is fully COMMENTED at tests:6975-6998 and the patch does
not uncomment it · `*_` has **no postfix carrier at all** (`c{a}*_` → bare
`Unbound variable`; the mint is `(string=? lexeme "*")`), so the arm's hardcoded
`'flatten` is right by accident and `*_` is classified KEYED, not keyless — the
patch pins the wrong answer.
**Confirmed as recorded**: the `sort` shadow (reduction.rkt:1643→:2111, and the
two live `(sort ` calls both sit OUTSIDE it, so 1b-iii's helper is the first thing
that would trip it) · `entries->value`'s first-component fork, whose twin
`select-assemble-row` RE-INDEXES, so `m{tags* name}` silently re-indexes while
`m{name tags*}` RAISES — same block, reordered · attempt 2 did fix the twin ORDER
divergence.

**WHERE A CANONICAL-ORDER HELPER BELONGS** (none exists — the tree's three champ
sorts are all `(format "~a" key)` or diagnostic-only): the COMPARATOR in
`syntax.rkt`, which already owns `expr-keyword`, `make-record` and `record-field`
and requires neither champ nor rrb; the champ WALKER at `reduction.rkt` MODULE
level, outside the `sort` shadow. `typing-core` requires `reduction`, one-way, so
reduction cannot import from typing.

**⚠ ONE AUDIT CLAIM DOWNGRADED**: a facet traced `c{a}*.host*` to a whole-file
abort; the critic showed the nearest reachable shape refuses cleanly and that
reaching the raise needs a branch that both STARTS with a star and CONTINUES —
which A1's position rule proves impossible. **That is an argued-unreachable
precondition living in an audit, which is precisely the artifact class that caused
both reverts.** It owes a comment at the four `select-step-kind-unhandled` sites
plus a tripwire planting a star in a `rest` position — not a note in a document.

**WHAT ATTEMPT 2 MUST DO DIFFERENTLY**: land the parser gates' star carve-out
**with** the seat migration, not after it; place the typing star check ahead of
`col`/`keyless?` so the twins genuinely match (and pin the caret-after-star case,
which nothing covered); decide the champ-order question; restore per-spelling
interpolation in the message. ⚠ The battery was GREEN over all three defects —
482 cases, plus a 325-test neighbourhood. **No spelling in the battery mixed a
star with a keyed sibling, and none put a caret after a star.**

