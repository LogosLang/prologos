# CIU 6 — D4, §5.P4e-1 + 1a + 1b

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 9765–10213 are lines N-9758 here.

---

<a id="p4e-1"></a>

### §5.P4e-1 — the `*` SEMANTICS  (opened 2026-08-10 · ⬜ **1a designed, tests written, NOT implemented**)

**Where it stands**: the design is settled, the arrival inventory is generated, and
P4e-1a's failing tests are written and **parked COMMENTED** in the battery (the
acceptance-file idiom). No implementation. Resume by uncommenting them.

**⭐ WHY THE MINT NEEDS THIS PHASE AT ALL.** Slice A's `postfix-star` token type is
**datum-invisible by design** — that is what kept the corpus A/B baseline clean,
and it is also why the mint is **INERT**: `token-entry->stx` renders it as a plain
`*`, so no consumer can see it. Measured: the carriers give `Could not infer type`,
identical to their spaced controls, so there is currently **ZERO observable
difference** between glued and spaced. A consumer therefore CANNOT be built without
making the datum visible — the two out-of-band channels are both dead (syntax
properties AND srcloc are destroyed by preparse for `cfg{a}*` / `xs:{a}*` on a
`def … :=` RHS, while surviving at command position, so either would work for half
the carriers and silently fail on the surface users actually write).

**⭐⭐ THE CORRECTION TO [DEFERRED 105](../../../../DEFERRED.md), and it is what makes
semantics-first viable.** 105 recorded "the datum representation must be decided" as
ONE gate. It is TWO, and they separate:
· For slice A's carriers the star **already occupies a datum item** — measured,
  `def b := cfg{a}*` reads `(def b := cfg ($select-brace a) *)`. Renaming that
  item's VALUE is **COUNT-PRESERVING** and never engages what killed slice B.
· For `xs:0*` / `x.0*` the star has **no item at all** (they shatter), and restoring
  the carrier is what changes the count. That blocker is untouched.
**Four carriers clear, two blocked.** Not "avoids" and not "reaches from the other
side" — a partition, and the slicing must say so.

**THE DESIGN.** Emit `$postfix-star` at `token-entry->stx`; fuse at
`rewrite-dot-access` — the seat this repo already uses for `$dot-access` /
`$bcast-step`. Rule: a `$postfix-star` immediately following a **selection-shaped**
item fuses into a star step; anywhere else it is [Q_U35](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u35)'s guided refusal.
⚠ `access-sentinel?` tests HEADS of sub-lists, so a bare `$postfix-star` ATOM does
not trip `rewrite-dot-access`'s gate — it needs its own gate clause, and
`ordinal-rekey-shatter?` is the in-file precedent for exactly that (a sentinel-FREE
shape with its own clause).

**⚠⚠ THE ARRIVAL INVENTORY — GENERATED, NOT READ.** A `postfix-star` token reaches
a datum in **40 of 44** carrier × context spellings, across **ELEVEN** contexts:
command position · `def` RHS · application argument · bracket application · nested
bracket · map-literal value · vector literal · list literal · select-block item ·
`defn` body. Only the four mixfix spellings do not — [Q_U34](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u34)'s gate working.
**So the rename puts a sentinel into eleven contexts at once**, and a bare sentinel
reaching the user is the class the revert `d0ac2a58` itemised. [Q_U35](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u35) is
what makes it tractable: everything outside selection is REFUSED, not armed.
(The inventory was generated over a carrier × context matrix rather than read off
the code — the last three blocking defects in this arc were all bad enumerations.)

**OWED before implementing**:
- The Tier-O sentinel obligations (`pipeline.md` § "A new sentinel, an old
  recognizer"), **`pattern-var?` first** — a miss there is a whole-file abort in a
  `defmacro` template.
- ⚠ [Q_U23](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u23)'s claim that the nominal-join collision "needs no P5 machinery,
  because P3a already landed strict merge" is **REFUTED by the grounding**:
  `make-record`'s body is `;; last write wins`, and `dup-output-key` / `mixed-sorts?`
  fold over **written** branches at parse time, so the landed gate structurally
  cannot see SUBJECT-DERIVED keys. A star over a `Map` needs a ruling: refuse, or
  defer to a runtime merge?
- ⚠ [Q_U31](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u31)'s stated cost ("one guided error at a `star-symbol?` call site")
  is **not implementable as written** — glued and spaced Sigma are datum-identical,
  so `star-symbol?` (a datum test) cannot tell them apart. The refusal must key on
  the `postfix-star` TOKEN TYPE or on srcloc adjacency. And `$star` escapes a
  type-keyed refusal entirely (`<(x : Nat)$star Nat>` → `[Sigma Nat Nat]`, 0 errors).
- `.*` retires per Q_U23 with **no inventory taken** of what currently consumes it.

<a id="p4e-1a"></a>

#### §5.P4e-1a — the mint gets a consumer  (opened 2026-08-10 · ⬜ **3 slices, not started**)

Mini-audit `wf_9bbe5f5a-9e0` (4 facets + completeness critic); every load-bearing
claim below re-verified on the main thread. Rulings: **[Q_U36](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u36)** (the
positive-list fuse) and the sequencing below.

**⭐⭐ THE INVENTORY IN [§5.P4e-1](#p4e-1) IS A 21% SUB-FRAME. GENERATED, NOT READ.**
"40 of 44 across ELEVEN contexts" is TRUE — the audit regenerated it and D4's
4 × 11 frame reproduces **exactly**, all 40 non-mixfix cells arriving and all 4
mixfix cells blocked. But the frame is not the blast radius:

| | D4 §5.P4e-1 | MEASURED |
|---|---|---|
| minting carriers | 4 | **10** |
| arrival contexts | 10 (prose says 11; the 11th is mixfix, where nothing arrives) | **19** |
| cells | 44 (40 arrive) | **280 (190 arrive)** |

The six carriers this document never counted — `.(1 + 2)*` · `'[1 2]*` ·
`@[1 2]*` · `#{1 2}*` · `{:a 1}*` · `` `[a 1]* `` — each arrive in 19 of 20
contexts, and they mint for a PRINCIPLED reason: `]` `}` `)` are all in
`group-closer-types`. (`#p(a)*` does NOT mint in any context — `#p(a)` lexes as
ONE `path-literal` token, so no `rparen` precedes the star. It is misread as
arithmetic today, but it is outside slice A's mint domain.) The nine further
arrival contexts: pattern position · spec/type position · set literal · `defr`
fact row · goal argument · `let` binding value · `match` scrutinee · quasiquote
body · `defmacro` template.
⚠ **The census had already found this** (`2026-08-09_STAR_SURFACE_CENSUS.md`
MISS 3: *"the population is 11, not 4"*), and this document cites that census as
"the design's input" while its inventory does not carry MISS 3 forward. The
census's completeness critic additionally PREDICTED the pattern-position miss —
*"will still miss that `*` IS ALREADY A BINDING PATTERN"* — and that prediction
is live below.
⚠ **The generating matrix did not exist in the tree.** `1476734b` touched two
files (this doc + the battery); there was no generator, table or data file, so
the claim was **unfalsifiable at HEAD**. That is the bad-enumeration shape this
arc keeps paying for. **Slice 1a-i lands a durable generator.**

**WHY [Q_U36](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u36) DISSOLVES THAT.** Under a NEGATIVE list the 4.3× under-count
is a defect generator. Under a POSITIVE predecessor test the population stops
bearing on correctness — every cell fuses or refuses by construction — and the
inventory becomes a GATE-COVERAGE obligation. That is the difference between
this being a scoping crisis and a test-widening task.

**⚠ TWO PRE-EXISTING SENTINEL HOLES, and the differential is what proves they are
pre-existing** — filed [DEFERRED 106](../../../../DEFERRED.md) + [107](../../../../DEFERRED.md), NOT
fixed here (they reproduce without the star; *Watching 9* says mid-flight
widening is where this arc introduces defects):
1. **The `let` nested-shorthand binding value is not reached by any of the four
   `rewrite-dot-access` seats.** At HEAD `let k c{a}*` reports
   `let: unrecognized format: (let k c ($select-brace a) * k)` — a raw sentinel
   at the user. The differential settles authorship: `let k c.a` gives
   `(let k c ($dot-access a) k)`, the same leak with no star. Spelling-sensitive
   within `let` itself (the ALIGNED form folds correctly), so one gate row would
   not find it. ⚠ This BOUNDS [Q_U35](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u35)'s "refusing dissolves that whole
   blast radius" — true only WHERE THE FUSE SEAT RUNS.
2. **Carrier-plus-star in PATTERN position mints, and is unruled.**
   `defn h | [f 1]* -> 1 | z -> 2` silently drops arm 2 and changes arity, with a
   diagnostic that never mentions the star. The `c.a` differential is worse —
   `h defined (arities: 1, 3)` at **ZERO errors**. [Q_U32](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u32)'s measured
   domain is BARE `*` only, and its refusal **has never landed**.

**FOUR MORE VERIFIED FINDINGS** (each corrects something shipped):
- ⭐ **The slice-A pin's harmlessness argument names a DEAD PATH.** It says the
  glued Sigma is safe because *"`tree-parser.rkt` finds the Sigma `*` by LEXEME,
  not by type"*. True of tree-parser, irrelevant to production:
  `merge-preparse-and-tree-parser` (driver.rkt) now returns only filtered
  `preparse-surfs` — the tree leg is gone. The live path is preparse →
  `parse-datum` → `star-symbol?`. The pin's CONCLUSION (the sequencing
  constraint) is right; its MECHANISM is false, and a right conclusion from a
  wrong premise is how the next reader gets it wrong.
- ⭐ **[Q_U31](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u31) has TWO identity families, not one call site.**
  `star-symbol?` (`parser.rkt`, 7 call sites) **and** `param-type->angle-type`
  (`macros.rkt`, `(memq '* ptype)`), whose own comment says it exists because
  *"without this, `(A * B)` … gets delegated to parse-datum which treats `*` as a
  variable name"* — exactly what the rename causes. Zero corpus instances, so it
  would land silently. ⚠ A reader-seated refusal cannot reach family 2, because
  its `$angle-type` is SYNTHESIZED AT PREPARSE — which is why the refusal rides
  the rename rather than preceding it.
- The rename is probe-verified to break Sigma: `parse-datum` on
  `($angle-type (x : Nat) $postfix-star Nat)` returns a `surf-app` chain
  containing `surf-var $postfix-star` where today it returns `surf-sigma`.
- `access-sentinel?` opens `(and (list? x) (pair? x) …)`, so a bare atom can
  never satisfy it (`(access-sentinel? '$postfix-star)` → `#f`); the gate needs
  its own disjunct, `ordinal-rekey-shatter?` being the in-file precedent. The
  fold's tail UNWRAPS a one-element result, and `preparse-expand-subforms`
  RE-ENTERS whenever the fold changed the datum — so the emitted head must not be
  an `access-sentinel?` member or the P1b-iii left-sibling-swallow returns.

**THE SLICING — three, and the last is necessarily atomic** (owner-assented
2026-08-10). It inverts slice A's failure mode, where the risky change went
first and every verify round then found a defect in the previous round's FIX:

1. ✅ **1a-i — the generator + the widened gate** (`ff9b7d81`). Battery 465 → 466,
   file 74 s → 79 s, neighbourhood 322 green.
   **⭐⭐ THE FINDING: THE OBSERVABLE WAS WRONG, not merely narrow.** The gate
   first grepped user-visible output for `$postfix-star`. The adversarial verify
   simulated 1a-iii by planting the sentinel in each cell and running the gate's
   own machinery: it could fire in **72 of 190** cells, and in the rest clean and
   planted output is **byte-identical** — an unconsumed sentinel is an EXTRA
   DATUM, so the form fails on SHAPE long before anything renders the symbol.
   The invariant is **"no unconsumed `$postfix-star` survives PREPARSE into the
   datum"**, now the primary assertion. Measured and stated, not rounded to
   "total": **datum 187/220 · message 92/220 · UNION 208/220**, complementary
   rather than nested, 12 residual blind cells clustering in `let-bracket` (8),
   `quasiquote-body` (3), `let-nested` (1) — DEFERRED 106's own seat.
   The verify found **four more defects in my code** (a `defmacro-tmpl` row that
   never registered a macro so `datum-subst` never ran, while 33 output lines
   made it look healthy; whole contexts skipped when a batch raised; an
   unreachable `pair?` assertion; a mint pin asserting cardinality not
   membership) and I found a fifth before it (`star-cell-source` took a string
   while every caller passed the record — `format`'s `~a` hid it and every count
   and both mutation tests still agreed). Matrix now **11 × 19 = 209** cells +
   5 controls; DEFERRED 108 re-measured 19/280 → 21/320.
2. ✅ **1a-ii — the Tier-O arms, inert** (`dc458109`). Battery 466 → 469,
   neighbourhood 287 green. **TWO lines of production code**, and that is the
   finding: the generated inventory said *no arm needed* far more often than
   *arm* — `access-sentinel?` + the head sets, `flatten-ws-datum`, and both
   preparse lists all require a PAIR, so a bare atom can never reach them
   (Q_U36's point, arriving as a coverage dividend).
   ⚠ **The handoff's premise was stale**: a `pattern-var?` miss is NOT a
   whole-file abort any more. DEFERRED 3 was discharged at `446070fc`, and
   `pipeline.md` + `macros.rkt`'s own comment were both wrong about it —
   corrected in this slice. The residual raise is `datum-subst-list`'s SPLICE arm
   alone: unreachable from WS (`...` reads as `$rest`), and G2-degraded in sexp.
   **⭐⭐ TWO REVERSALS OF MY OWN WORK.** (i) I fixed the splice arm structurally
   — its stated invariant *is* falsified by `$postfix-star`, the first
   bare-symbol sentinel — and the neighbourhood turned `test-defmacro`'s "the
   SPLICE branch keeps its unbound error" RED. That raise is a **ruling**; only
   its rationale was false. *A falsified rationale does not license reversing the
   decision it was offered for.* (ii) I gave `pp-datum` an arm rendering the
   sentinel as `*`; the verify showed every CONSUMED marker deliberately has no
   arm and prints its internal name, because **appearing there is the defect** —
   `*` would hide a leak inside `expand`. Both reversals are pinned with their
   reasoning so the next bare-symbol sentinel does not re-derive them.
3. ✅ **1a-iii — the atomic change** (`9cac0099`, attempt 2 per [Q_U37](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u37);
   attempt 1 recorded below). Battery 469 → 476 · neighbourhood 497 across 14
   files · acceptance 84/84 by diff · **full suite 10143 / 488 / 0** · five
   mutations kill. `xs:{a}*` and `c{a}*` reach `star-not-yet-message`; the two
   parked tests are LIVE; `[f x]*` takes the guided refusal; the glued Sigma
   takes the angle-generic type-seat message at both families (the live family-2
   route is the SPEC spelling); quote/quasiquote capture the star as `*`.
   **The fuse RETIRED two whole-file aborts** (DEFERRED 108: 21 → 19 — the
   usable carriers in match-scrutinee now get a guided message).
   **⭐⭐ ROUND 2'S VERIFY FOUND THE RENAME LEAKING THROUGH ERROR ECHOES** — the
   def seam and the fn binder error both echo source datums, and the rename
   silently changed the echoed content from `*` to the internal sentinel, in two
   seats the matrix's leak pin structurally cannot see (off-matrix positions).
   Fixed via `unmint-star-for-echo`: error echoes render the USER'S spelling
   (capture-fidelity, same argument as the quasiquote arm — and the OPPOSITE of
   `pp-datum`, where the internal name is deliberately the tell). Also: the
   family-2 pin was VACUOUS (`|defn requires` alternation — an instrument hedged
   into its own blind spot; the defn spelling dies before the arm is reached)
   and its comment asserted the dead route; both corrected, and the fifth mutant
   (the `memq '$postfix-star` disjunct) now kills. The preparse-RAISED set is a
   pinned snapshot (3 cells, all star-free pre-existing). Filed: **DEFERRED
   110** (pipe-terminal fused star — `expand-pipe-block`'s one-element unwrap
   spreads a fused node; pre-existing, pinned AS an accident) · **111** (the
   raw-datum-echoing error-site CLASS: two instances fixed, census unclaimed) ·
   **112** (`$facts-sep`, star-free, rel-territory).

   **⭐ THE FUSE SEAT IS GROUNDED — the open question from the P4e-1a audit is
   ANSWERED, and the answer is favourable** (measured at `79e34380`; this is the
   one thing 1a-iii most needed settled before writing code):
   - **`rewrite-dot-access` does NOT have the selection-CLOSING property that
     killed attempt 2.** That property belongs to `segment-select-items`, which
     [DEFERRED 101](../../../../DEFERRED.md) records is *"reached ONLY from the args of a
     `$select`/`$select-path` node, and the fold CLOSES the selection as it goes
     — so a non-sentinel marker is left a SIBLING of the finished node, outside
     the args."* `rewrite-dot-access` is a **different fold**: it keeps each
     wrapped node in its accumulator, where the next sentinel can consume it.
     The design's choice of seat is sound, not lucky.
   - **Its arms already have exactly the postfix shape the star needs.** The
     `$dot-access` arm takes `(car acc)` as the target and replaces it with
     `($select-path target field)` — *consume the preceding element*, which is
     what a postfix `*` is. The ω arm added at P4c-4b is that arm verbatim except
     the payload rides WHOLE. A star arm is the same shape a third time.
   - **⚠ THE FIXPOINT OBLIGATION IS THE ONE TO RESPECT.** The emitted head must
     NOT be an `access-sentinel?` member, or `preparse-expand-subforms` re-enters
     and **swallows one LEFT sibling per pass** — the P1b-iii defect that
     silently dropped a `defn` clause at zero errors. Verified: neither
     `arity2-access-sentinel-heads` nor `brace-access-sentinel-heads` contains
     `$select-path`, which is why the existing arms emit it.
   - **The refusal message already exists and is reachable for free.**
     `star-not-yet-message` (parser.rkt) fires from `segment-select-items`, i.e.
     from the ARGS of a `$select`/`$select-path` node — so a star fused INTO
     those args inherits the message the parked test expects, rather than needing
     a new diagnostic. Its own comment already says so: *"Giving them this same
     message is P4e-1's first deliverable; until it lands, do not read this
     comment as a contract."*

   **⛔ ATTEMPT 1 (2026-08-11) — BUILT, VERIFIED, REVERTED; patch parked at the
   session scratchpad (`slice-1a-iii.patch`), findings recorded here, ruling
   [Q_U37](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u37).** The build was CLOSE and most of it survives into attempt 2:
   the rename, the gate disjunct, the Q_U36 fuse, both Q_U31 family edits and the
   parked-test uncomment were all correct in content. What was wrong was WHERE
   one decision was made — the fold emitted Q_U35's refusal as a
   `($retired-selection star-no-selection)` marker at preparse, EVERYWHERE.
   The adversarial verify measured the two consequences of that one assumption:
   1. **The marker PRE-EMPTED the Sigma seat.** Inside `$angle-type` contents the
      star was rewritten before `unwrap-angle-type` could see it, so the Q_U31
      Sigma refusal this slice added **shipped unreachable** — its guided message
      never fired, the generic Q_U35 text fired instead. A refusal written and
      landed, and structurally dead on arrival.
   2. **The marker broke the quasiquote lowering** — a three-element list where a
      symbol was expected, in data territory where nothing should be rewritten.
   Plus four smaller: the `xs[0]*` matrix-row comment contradicts the positive
   list (bracket-postfix is NOT on the carrier per §2.4, so the refusal is
   correct-for-now — fix the COMMENT) · the backstop's message text was a
   verbatim duplicate of the marker's · the fold's fixpoint comment no longer
   covered the widened gate · prose in a code slot.
   **MEASURED WINS TO RE-EARN in attempt 2** (they were real, and the abort pin
   is where they show): the fuse retired the two `match-scrut` aborts for the
   usable carriers (21 → 19), and the preparse marker retired six `pattern-pos`
   aborts (19 → 13). Attempt 2 keeps the first (the fuse stays) and gives back
   the second (the marker goes) — the six `pattern-pos` cells return to
   DEFERRED 108's pre-existing residue, which is honest: they were shielded by
   the wrong mechanism, not fixed.

**Scope OUT, with reasons** — [Q_U23](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u23)'s Map/strict-merge ruling (this
slice ships the *not-yet message*, never the flatten, so the semantics are not
reached) · the `.*` retirement inventory (Q_U23's own surface) · DEFERRED 106 +
107 (pre-existing, differential-proven).

<a id="p4e-1b"></a>

#### §5.P4e-1b — the `*` SEMANTICS  (opened 2026-08-11 · ⬜ mini-audit DONE, rulings [Q_U38](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u38)+[Q_U39](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u39), **not implemented**)

Mini-audit `wf_4b91ca25-73a` (5 partitioned read-only facets + completeness
critic, HEAD-pinned `4cf8cad3`). **Every load-bearing claim below was
R-lens-verified on the main thread** — two of the critic's were corrected in the
process, and one facet's headline was discarded.

**WHAT THE AUDIT SETTLED** (each re-measured here, not inherited):

- **The collision refutation is TWICE AS WIDE as recorded** — two last-write-wins
  sites, not one. `make-record` is the TYPE-level constructor and IS on the
  select path (`select-assemble-row`, typing-core.rkt); `entries->value`
  (reduction.rkt) is its VALUE twin, a `champ-insert` fold. → [Q_U38](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u38).
- **Both parse gates are blind for a MECHANICAL reason**: `select-branch-top-keys`
  takes exactly ONE parameter. Not an oversight — a structural bound. → Q_U38.
- **The two layers disagree about field ORDER** (`make-record` sorts;
  `entries->value` does not). No facet found this; the critic did. → Q_U38.
- **`*_` is already live in the fused-identifier band and absent from the
  closer-adjacent one**, mint gate `(string=? lexeme "*")`. → [Q_U39](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u39).
- **[Q_U23](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u23)'s identity claim CONFIRMED at BOTH layers** — and it had been
  covered by NO facet; the critic measured it. `cfg{database.{url pool-size}}` ≡
  `cfg{database}` and `cfg{database^.{url pool-size}}` ≡ `cfg.database`,
  byte-identical, robust to branch reorder. **This is the strongest evidence that
  the splat's plumbing already exists and behaves as Q_U23 predicts.**
- **[Q_U23](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u23)'s splitter claim CONFIRMED verbatim** — `split-star-lexeme`
  has exactly THREE call sites, mirroring `split-step`'s three, and the ω payload
  does arrive colon-leading and string-stripped while the others arrive bare.
- **[Q_U24](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u24)'s inheritance CONFIRMED** — `^-_` carries `'collapse-synth`
  (a collapse; ONE flat entry lifts) while `^_` carries `'synth` (relabel in
  place, nesting preserved), and `split-star-lexeme` already records at its own
  site that `'flatten-synth` inherits `^-_`'s rule.
- **Not blocked on PF.** The step vocabulary is plain s-expressions, so a star
  kind needs no ADT. `path-segments`'s whole-file abort is pre-existing, filed,
  and off the star's path — but the PF repair INHERITS the star as a marshalling
  obligation (`(expr-keyword seg)` assumes bare symbols; a star step is a list).

**⚠ CORRECTIONS TO THE AUDIT ITSELF — it is not authoritative either:**

1. **The critic's headline capture-gap is a REPRESENTATION QUESTION, not a
   refutation.** It found (verified) that the ω band's local `push` wraps every
   minted step in `make-select-bcast` unconditionally, so a star landing there
   rides as the ω INNER — `(@bcast <star-step>)` — and called that a
   contradiction of Q_U23's own headline example. **The structural fact holds;
   the contradiction does not follow.** Read through the layer model, inner
   placement may be RIGHT: `xs:diags` yields a vector whose inner layer is what
   each `diags` contributed, and "delete the layer the preceding step created"
   plausibly means splice each element's contribution into the parent. The star
   also rides inside the `:diags*` TOKEN, so the surface puts it there lexically
   too. **OPEN — owner ruling owed; see below.**
2. **"At least 20 sites" is NOT verified and must not be quoted.** The recipe IS
   stale — `select-step-kind` dispatches at parser.rkt (the `^`-in-path-access
   refusal) and typing-core.rkt (`select-tier-subject`'s ω peel) are outside its
   13-site list, both confirmed by independent census, and its boast that the
   sixth kind *"met all thirteen … with no correction needed"* is therefore
   false. But the open-coded classifier grep returns 16 sites outside
   `syntax.rkt` and several sit INSIDE functions the recipe already names.
   The honest number needs per-site enclosing-function attribution — slice work,
   not a citable figure.
3. **Facet 2's headline is DISCARDED.** It opened *"REFUTES THE FACET'S OWN
   FRAMING: `make-record` is NEVER called on a runtime selection result"* and
   called the main-thread measurement mis-anchored. It is right that
   `make-record` is type-level; its framing would have cost us the refutation.
   `select-assemble-row` puts it squarely on the select path. The design's defect
   was UNDER-COUNTING, not mis-naming.

**CAPTURE GAPS carried forward** (not 1b's work unless marked):

- **Three ω-inner dispatchers are load-bearing and none is on the recipe**:
  `bcast-apply` (reduction.rkt), `select-bcast-lift` and
  `select-bcast-inner-apply/non-union` (typing-core.rkt). All three branch on
  `select-sub-step?` and fall through to a symbol/generic path otherwise — so a
  star inner would be handled SILENTLY as a symbol. **This IS 1b's work** if the
  ω placement question resolves inner.
- `select-step-name` / `select-step-cont` end in permissive `[else s]` / `[else #f]`
  tails and sit outside the recipe BY DESIGN. A star kind would get the RAW STEP
  LIST back from the first (the DEFERRED 40/46 raw-list-in-a-message class) and
  `#f` from the second — and `#f` is what `findf select-step-cont` and
  `branch-problem`'s positional check key on. **1b's work.**
- **`select-sorts` is `'(path block)` — the SELECTOR sort, not a container sort.**
  Two facets caught this independently. "The sort follows the layer" reads as a
  claim about `select-sorts` and is NOT one; the container decision is a separate
  keyed/keyless fork inside `entries->value`. **Correct the vocabulary before
  "sort-generic" is used again.**
- **The rule is not total over the vocabulary**: an ordinal STEP `.N` contributes
  NO output level (Q_U2 Reading A), and a `'path` selection builds no layer at
  all. Two different reasons, both needing a stated disposition.
- **The `.*` retirement's TEST surface was swept by nobody** — `test-selection-paths.rkt`
  carries **17** lines with a live `.*`/`.**` spelling (measured) across a
  56-case file, plus `test-path-selection.rkt`'s `#p(a.*)` refuse-loudly pins.
  That is the bulk of what a retirement must move. **P4e-2, not 1b.**
- **`selection-field-unrestricted?` (typing-core.rkt) is the ONLY place the
  selection `*`/`**` carries TYPE-level meaning** and is absent from every
  consumer list this design has written. **P4e-2.**
- **The retirement inventory intersects uncommitted owner WIP** —
  `lib/examples/foray.prologos` documents `.*` as the splat operator and is
  MODIFIED in the working tree. Any sweep that edits it collides.
- A repo-root grep picks up `.claude/worktrees/` and silently double-counts
  against a stale branch. **Scope every sweep to `racket/`, `docs/`, `tests/`.**

**SCOPE, per [Q_U39](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u39)**: 1b lands the flatten + Q_U38's refusal + `*_` in
the fused-identifier band. OUT: the closer-adjacent `*_` mint (own slice);
the `.*` retirement + ravel (P4e-2); DEFERRED 106–112.

**THE ω PLACEMENT IS RULED — [Q_U40](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u40) OUTER**, with [Q_U41](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u41)
scoping `*_` to nominal layers. The semantics are now fully specified; what
remains before code is the slicing plan. Three consequences for the
implementation:

1. **The representation is already in the tree.** OUTER is the shape the
   closer-adjacent fuse emits (`($select-path <step> $postfix-star)`), so only
   the FUSED-IDENTIFIER band needs normalizing outward — lifting the star out of
   the lexeme to the wrapper. That is the opposite direction from what INNER
   would have needed, and it is why the placement was worth settling before
   writing anything.
2. **The three ω-inner dispatchers are OFF the hook.** `bcast-apply`,
   `select-bcast-lift` and `select-bcast-inner-apply/non-union` became
   load-bearing only under INNER. Under OUTER the star never appears as an ω
   inner, so their absence from the recipe stops being 1b's problem. ⚠ The recipe
   is still stale (two confirmed `select-step-kind` sites outside its 13, and its
   "met all thirteen" boast is false) — that remains 1b's, since 1b mints a kind.
3. **Ordinals are the collision-free axis.** §3.6 rule 5 concatenates keyless
   components in written order, so [Q_U38](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u38)'s refusal structurally never
   fires on an ordinal layer and `vv:{0 1}*` → `⟨1 2 3 4⟩` needs no special case.

**THE LAST SEMANTIC QUESTION IS CLOSED — [Q_U42](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u42): same-key VECTOR values
CONCATENATE.** So the star's join is one recursive rule at every depth — Maps
recurse · vectors concat · keyless concat · leaves error — and nothing about the
semantics is now inherited by elimination. Two corrections landed with it, both
found by the owner's questions rather than by a gate: [Q_U40](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u40)'s law needed
the **no-intervening-ω qualifier** (branch stars delete into the per-element block
level; a trailing star deletes the container layer the ω step contributed — one
level apart, so `m:{a* b*}` ≢ `m:{a b}*`), and [Q_U41](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u41)'s third supporting
argument is **struck**.

**THE SLICING PLAN (proposed, mirroring this track's own ω precedent — P4c-3
landed the KIND with a guided not-yet, P4c-4c landed the semantics):**

| slice | content | test delta |
|---|---|---|
| **1b-i** ✅ `226844f1` | recipe corrected + battery parked. **Measured: 59 live dispatch sites · 35 in the 13 named functions · 2 deliberately-outside-and-undocumented (`select-step-name`/`select-step-cont`, the vocabulary's only SILENT trapdoors) · 8 genuinely OMITTED** — and FOUR of the eight are ω functions `(@bcast step)` itself introduced, so the "met all thirteen" boast is struck: an enumeration cannot be validated by the member it was written for. ⚠ My first attribution pass over-counted ~3× (41 vs 8) by matching only column-0 `define`; six recipe entries are themselves nested | +0 live (deliberate) · battery 476 → 476 |
| **1b-ii** ✅ `dbb9ec77` | `(@star cont)` joins the closed union; the two trapdoors DECIDED (`select-step-name` → #f explicitly, `select-step-cont` → #f deliberately — the star's cont is not a CARET cont); [Q_U43](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u43)'s pre-check. ⭐ **The failing test caught my Q_U43 arm in the wrong place** — it went in the head `case`, which dispatches on `(car b)` while a star is almost always LAST, so the branch reported `'(database)`: a key the star had DELETED. Moved to an `ormap` pre-check. ⚠ typing/reduction NOT armed — a refusing arm would be replaced by iii/iv's real one (ban-dual-paths) | +5 live · 476 → **481** |
| **1b-iii** ⛔ attempts 1 AND 2 BUILT · VERIFIED · **REVERTED** | **VECTOR semantics**, typing + reduction ATOMICALLY (spec v1's `ω·ω→ω`). Collisions structurally impossible — concat is total. **Audit finding + the algorithm: [§5.P4e-1b-iii](CIU_6_P4e-1b-iii-iv.md#p4e-1b-iii)** | the vector battery |
| **1b-iv** | **NOMINAL semantics** + [Q_U38](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u38)'s typing-seated collision refusal + `*_`, together per [Q_U24](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u24) | nominal battery · collision refusals · `*_` |

The iii/iv split is **the spec's own migration path** (§3.5 "v1: vector layers
only" → §8 Q4's extension): monotone, each half independently gateable, and it
keeps the riskiest work — a collision check at a NEW seat in typing — out of the
slice that first makes the star mean anything.

⚠ **A test must pin the NON-equivalence under broadcast**, not only the law
without one. ⚠ The refusal channels are `bcast-carrier` (typing-errors.rkt) and
`(return (expr-panic …))` through reduction's single `let/ec` — a raw `error`
here is a WHOLE-FILE ABORT, which is why P4c-4c retired its predecessor rather
than leaving it in the tree.

