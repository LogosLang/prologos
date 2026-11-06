# CIU 6 — D4, §5.P4c

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 7338–8632 are lines N-7331 here.

---

<a id="p4c"></a>

#### §5.P4c — The `:` gate + the ω wrapper + PVec broadcast  (co-design 2026-08-01; Q_U16/Q_U16b RULED)

**Grounding**: audit `wf_d7c035da-cee` (6 facets + completeness critic @
`532474c0`, 7 agents / 1.53M tokens) → adversarial options panel
`wf_6f15c6ae-6a7` (3 clusters × propose/critique + synthesis, 7 agents / 1.17M
tokens). Every load-bearing claim below was **R-lens-verified on the main
thread**; two of the panel's own numbers were wrong and are corrected here.
The rulings are §3's Q_U16 / Q_U16b.

##### PREREQUISITES — land FIRST, independently valuable, owed under every option

Both were raised by three independent critics, and both are **live defects at
HEAD**, not hypotheticals:

1. **Hoist `adjacent-to-base?` into `reader-forms.rkt`.** It is defined at
   parse-reader.rkt:3187-3193 (four conjuncts, consults NO token type), is NOT
   exported, has exactly two call sites (:3249 lbracket, :3305 lbrace) — and
   **surface-rewrite.rkt:550-556 hand-inlines the same four conjuncts** for
   lbrace only, its own comment admitting it "mirrors parse-reader's
   `adjacent-to-base?`", in a module that ALREADY requires reader-forms.rkt.
   That is a live F1b.7g drift instance. Landing the `:` mint in both groupers
   without hoisting writes the test a THIRD time. ⚠ D4's coordinate for this
   function (`:2632`) is **555 lines stale**.
2. **Make the `ns` name guard TOTAL.** namespace.rkt:895-896 enumerates only
   `$dot-access`/`$postfix-index`; probe: `ns foo:bar` → `((ns foo :bar))`, so
   the uniform gate FIRES and the guard would silently DROP the segment — a
   FOURTH instance of the `b0db8f3e` class, which D4 already records as having
   THREE unclosed instances. **Refuse any PAIR segment** rather than adding a
   fourth memq entry: that closes the class instead of extending it.

##### The partition

- **P4c-1 — prerequisites + the classifier promotion.** The two above, plus
  `colon-annotation` promoted to a real token type (Q_U16b) WITH an explicit
  `token-entry->stx` arm. No new surface; the corpus A/B must be **ZERO diffs**
  at this point, which is what makes it a clean attribution baseline.
- **P4c-2 — the mint + the binder unwrap** (the Q_U16 core). The grouping arm
  in BOTH groupers over the hoisted predicate; ~~`$bcast-step` into
  `access-sentinel?` + its fold arm~~ — ⚠ **THIS DID NOT LAND AND P4c-2 CLOSED ✅
  ANYWAY** (found 2026-08-02 at the P4c-3 close; `access-sentinel?` at
  macros.rkt:6128-6132 lists eight members and `$bcast-step` is not one —
  `broadcast-access?` there is the RETIRED `$broadcast-access`, a different
  head, which is what made the gap read as closed). **It is NOT a live defect**:
  with the enable-set empty no sentinel survives the post-pass, so the fold
  never meets one. It is a PREREQUISITE of the first grant, and it moves to
  P4c-4 with the grant — see §5.P4c-3. The accurate record of what landed is the
  in-code comment at parse-reader.rkt:2834-2835, not this line; the design doc
  was the drifting copy; the reader post-pass unwrap with its
  totality hardening and per-binding-form pins. **The corpus A/B lands here**
  with the named diff set below.
- **P4c-3 — the `(@bcast step)` step kind.** Its arm across P4a's THIRTEEN
  sites (the `ADDING A KIND` recipe at syntax.rkt:879-904 is the authority, NOT
  this document), plus the two shape-test helpers OUTSIDE the recipe, plus the
  branch-initial refusal. ⚠ **The enable-set does NOT land here** — owner ruling
  2026-08-02, see §5.P4c-3. It moves to P4c-4, where the thing it would switch
  on exists.
- **P4c-4 — PVec broadcast + the law pins + ⭐ THE ENABLE-SET.** The third
  dispatcher in both walks; the L1 fusion pin (`users:0:userName` → ONE layer)
  and the §3.2.1 extent pair; `quests:t`/`quests:{t r}` uncomment as PVec
  broadcasts. **Plus everything the first grant requires, moved here from
  P4c-3** (owner ruling 2026-08-02): `$bcast-step` into `access-sentinel?` + its
  fold arm (the P4c-2 line above) · the PRODUCER BRIDGE (`make-select-bcast` has
  ZERO production callers at HEAD — the parser's `bcast-step` arm emits the
  not-yet error instead of constructing, so no grant can yield a working
  broadcast) · a TEST SEAM (`broadcast-enabled-contexts` is an unexported
  `define`, not a parameter, so no context can be enabled from a test) · the
  per-context DISPATCH MECHANISM (only `(pair? …)` is consulted today) · and the
  unknown-head ruling that DEFERRED 32's open half names.
- <a id="p4c-5"></a>**P4c-5 — the `.*name` retirement + FULL residue disposal**, in the commit
  that discharges the parser's `:name` promise.

##### THE NAMED PREDICTED DIFF SET (A/B is MANDATORY; any diff outside is a bug)

Group-aware, independently re-derived at HEAD — **161 tracked `.prologos` ·
1532 `keyword` tokens · 289 `colon-annotation` tokens · SEVEN would-mint**
(repo-wide, 163 files: still seven):
`examples/2026-07-31-let-blocks.prologos:185,:186,:195` ·
`examples/2026-07-31-let-toplevel.prologos:37` (TWO tokens — **defn params, not
let**) and `:84` · `examples/homoiconicity.prologos:96` (`':hello`).
⚠ **Re-derive at implementation HEAD** — `examples/2026-03-20-first-class-paths.prologos`
and `lib/examples/foray.prologos` are BOTH dirty in the owner's tree, and an
A/B over a dirty tree measures the tree (3rd sighting of that class). Pin BOTH
legs' inputs with `git archive`, never a working-tree read.

##### HAZARDS THE AUDIT NAMED — none may be rediscovered mid-slice

1. **The `.prologos` safety net DOES NOT EXIST.** All three would-mint files are
   UNGATED; all six `process-file`-gated acceptance files contain ZERO. The only
   suite-RED tripwire is **eight verbatim datum pins** at
   `tests/test-parse-reader.rkt:494-516`, ALL of which flip — list them as
   **DELIBERATE** flips or they read as a regression. Safe-by-construction and
   **must NOT be touched**: `:512-513` (`x:0abc`/`x:10abc` — the annotation arm
   declines, the colon shatters) and `:522-523` (`{:10 v}`/`{:0 v}` —
   branch-initial, empty local result). **P4c should gate one would-mint file
   before the mint lands.**
2. **⚠ Admitting bare `colon` to the trigger BREAKS `:512-513`.** In both, the
   shattered bare `:` IS byte-adjacent with a non-empty result. This is a hard
   constraint on any attempt to reach the five shatter spellings.
3. **`ident-continue?` accepts `*` and `^`** (parse-reader.rkt:231/:237), so
   `users:tags*` and `users:name^alias` lex as **SINGLE keyword tokens** with
   the operator swallowed into the step NAME. Refusing them guidedly needs an
   explicit lexeme check on the minted name — an enumeration, to be named as
   such: *"incomplete because `ident-continue?` swallows the operator into the
   token; deferred for removal to the phase landing the `*` and `^` steps."*
   And `:name^alias` otherwise **slips past** parser.rkt:1316's `^`-refusal
   (via `select-step-name` returning the raw pair) — the refusal the b-ii-2b
   verify installed after five spellings were found silently ignored.
4. **Quote-adjacency is a THIRD bucket**: `':hello` → `(|'| :hello)` mints in
   EXPRESSION position where no binder unwrap can rescue it. Prior art for the
   decline conjunct: `prev-token-reader-form-head?` (parse-reader.rkt:3197-3201).
5. **The Q_N3 two-grouper agreement guard is BLIND to this sentinel** in both
   versions (v1 is count-comparing and the mint is count-preserving; v2 pairs a
   tree TAG with a datum sentinel, a correspondence only OPENERS have). The
   "one grouper only" failure is UNPINNED — a third guard shape is owed.
6. **§Q8.5's applicability table has NO ROW for this shape** (third consecutive
   under-specification of that invariant): `$bcast-step` is NO-NEW-TOKEN *and*
   NON-OPENER, while the table offers only OPENER and SELF-CONTAINED. Sentinel
   site 2 (`group-items-to-tree`) is **N/A** for a non-opener — proof in-tree:
   `tag-dot-access` is defined and exported with ZERO producers.
7. **TWO DISJOINT registration surfaces, neither cross-referencing the other**:
   §Q8.5's reader-sentinel sites AND P4a's 13-site step-vocabulary recipe. Carry
   both checklists side by side in the slice.
8. **`token-entry->stx`'s keyword arm is `(string->symbol lexeme)`**, so `:Int`
   already arrives as the colon-symbol `|:Int|`. The mint must WRAP it verbatim
   so the unwrap is `cadr`; a mint that strips and an unwrap that re-adds `:`
   is a second copy of the recognizer — the F1b.7g class.
9. **The scalar `tier` cannot express "some elements hit, some missed"** across
   a broadcast level (syntax.rkt:792-796; Q_U13's sufficiency argument is stated
   PER DESCENT LEVEL). Unaddressed anywhere — rule it in P4c-4.
10. **`parse-rel-params` (parser.rkt:6062/:6108) consumes `colon-symbol?`
    DIRECTLY** and never calls `fused-type-annot?`, so it is structurally
    invisible to a census keyed on the narrower predicate. `fused-type-annot?`
    is ELEVEN sites / 7 functions (not the design's four); counting
    `colon-symbol?` too gives **17 sites / 8 functions**.

##### DOC-TRUTH REPAIRS owed in this slice

D4:902 still says `quests:t` works "at P4d" and :3067 still says it "does NOT
uncomment" — both superseded by the solve→PVec spin-out; the corpus cite `:235`
is stale by 3 (the lines are `:232`/`:233`). §5.P4's Intent block at :3103-3105
still asserts the RETIRED pre-NEST model ("under the step-list node (4b)", "the
layer count is unfused-ω-steps"), both superseded by Q_U13/Q_U7. **§Q8.5's
silent-degradation tier is factually WRONG at HEAD** — `pp-datum` HAS an
access-family arm (`$select-path`, pretty-print.rkt:1691-1693) — and its sibling
path is `racket/prologos/tools/form-deps.rkt`, not `tools/form-deps.rkt`.
§Q8.5 invariant 1's "prefix-disjointness, not priority" framing is also wrong
for `:w`/`:m`: **both recognizers match at length 2 and priority 97>95 silently
decides.**

<a id="p4c-1"></a>

##### §5.P4c-1 — Prerequisites + the classifier promotion  ✅

**No new surface.** Three deliverables, two of which were LIVE defects.

1. **`adjacent-to-base?` is now THE definition, consumed by both groupers.**
   ⚠ **The options panel's recommended home was WRONG**, and checking the
   dependency gave a simpler answer: the predicate is over the `token-entry`
   STRUCT (parse-reader.rkt:183), so hoisting it to `reader-forms.rkt` would
   drag the struct along and break that module's deliberate "requires nothing
   project-local" invariant — the very property that made it the suggested
   home. `surface-rewrite.rkt` **already requires parse-reader.rkt** (:26), so
   EXPORTING is cycle-free by construction. The hand-inlined four-conjunct copy
   at surface-rewrite.rkt:550-556 is deleted; P4c-2 would have made it a third.
2. **The `ns` name guard is TOTAL, by POLARITY INVERSION.** It was a NEGATIVE
   list of two sentinel heads, which is why **`ns foo:bar` SILENTLY DROPPED
   `:bar` at ZERO errors** — probe-verified end-to-end, a LIVE `b0db8f3e`
   instance, not a prospective one. `ns` accepts exactly ONE option
   (`:no-prelude`), so the total form is a positive ALLOW-LIST: the same
   inversion `definitely-not-map?` took at P2.b slice 1. This CLOSES the class
   (D4 recorded three unclosed instances) instead of adding a fourth entry.
   ⚠ **Named consequence**: the guard RAISES rather than returning a
   per-command error value, so `ns foo:bar` goes from a silent drop to a
   WHOLE-FILE ABORT. Strictly better and monotone, but harsher than the
   discipline calls for — filed as **DEFERRED 31** (owner-requested), channel
   conversion deliberately out of this slice's scope.
3. **`colon-annotation` classifies to its own token type** (Q_U16b), with
   **EXPLICIT arms at BOTH `case type` sites** (`token-entry->stx` and its
   compat twin) rather than relying on `[else]` — whose safety would have been
   a coincidence of two identity-returning else-arms at the exact site this file
   documents as its silent-miss hazard.

**Test delta +9** (7 in the track file, incl. the ns refusal + its message +
the totality-preservation pair + the datum-invisibility pin; 3 in
`test-parse-reader.rkt` beside their siblings, where
`register-default-token-patterns!` is called at :23).

⚠ **THREE OF MY OWN PINS FAILED FOR THE WRONG REASON and were corrected before
implementation** — the discipline caught the author: one read `(car rs)` on a
lone `ns` line that yields NO results; one asserted a GUESSED datum baseline for
`{:0 v}` (it is `($brace-params :0 v)`) — a baseline pin asserting a guessed
baseline is worse than none; and two were mutually incoherent about the error
channel. **And the FALSE-ZERO footgun bit the author of the pins**: a direct
`tokenize-char-rrb` without `register-default-token-patterns!` returned every
character as its own `symbol` token — the exact hazard
`tools/reader-corpus-ab.rkt:74` carries a tripwire for.

**CORPUS A/B: 161 files, ZERO DIFFS**, both legs pinned to ONE immutable
`git archive` snapshot with only the code differing (the owner's tree has 6
dirty `.prologos` files; a working-tree read would have measured the tree —
3rd sighting of that class). That zero is the point of landing these three
together: it is the clean attribution baseline that makes P4c-2's SEVEN
predicted diffs attributable to the MINT alone.

Status: ✅ P4c-1 COMPLETE.

<a id="p4c-2"></a>

##### §5.P4c-2 — The mint + the reader-post-pass binder unwrap  (mini-design 2026-08-01)

**THE BINDER TABLE, MEASURED — not enumerated from memory.** Q_U16 booked "a
permanent hand-maintained enumeration" of binding forms. The mini-design
measured its actual membership at HEAD by probing which forms carry a fused
annotation that the mint would capture, and the result **corrects the design in
both directions and is materially larger than assumed**:

| MINT FIRES (binder position — unwrap owed) | MINT DOES NOT FIRE |
|---|---|
| `def x:Int` · `defn f [a:Int]` · `fn [x:Int]` · `spec g [a:Int]` · `let x:Int` · `property` · `functor` · `trait` METHOD params · **`$pipe` ARMS** (`defn` AND `match`) · `rel [a:Int]` · `defr [a:Int]` | **`?x:Nat` in ANY form** — glued into ONE token by `narrow-var-annot` (pri 96) · `schema`'s `:f` (branch-initial ⇒ empty local result) · SPACED `x : T` anywhere · map keys `{:a 1}` (branch-initial) · keyword args `f x :name` (spaced) |

`impl` needs NO entry — the walk recurses and the inner `defn` covers it.

**THREE findings the census produced that no prior enumeration named:**
1. **`$pipe` arms fire** — `match v | c a:Int -> a` → `($pipe c a :Int -> a)`,
   and `defn f | a:Int -> a` likewise. Named by neither the audit, the options
   panel, nor the first draft of this table (owner-caught).
2. **PATTERNS NEST**: `defn g | [cons h:Int t] -> h` →
   `($pipe (cons h :Int t) -> h)`. The unwrap CANNOT scan an arm's top-level
   items — it must recurse into pattern sub-groups.
3. **`defr`/`rel` ARE members via the BARE-NAME spelling** even though their
   `?`-prefixed form is immune. An earlier draft of this table declared `defr`
   OUT on the strength of the `?a:Nat` probe alone — an under-count committed
   and corrected inside one session, by measuring rather than listing.

**⚠ THE DISCRIMINATOR IS THE SPELLING, NOT THE FORM — and that changes Q_U16's
booked cost.** Every form with a bracketed param group is a member for the
bare-name spelling, so the table is NEAR-UNIVERSAL rather than the five entries
the ruling implied. A near-universal allow-list is a weaker structure than what
was accepted; recorded as a correction to the ruling's cost, not smuggled in.
**Owner ruled [2026-08-01]: take the table as measured**, with the loud-refusal
hardening at the 17 consumer sites so a MISSING entry surfaces as a guided
error on first use rather than as a wrong parse.

**⭐ THE TREE ALREADY SOLVES THIS COLLISION LEXICALLY, for one vocabulary.**
`?x:Nat` never fires because `narrow-var-annot` glues it into ONE token — the
`?` prefix is a lexical marker meaning "this is a binder", making the collision
STRUCTURALLY IMPOSSIBLE instead of managing it downstream. Recorded because it
is the shape a future simplification would take (and the shape X.close should
weigh), not proposed for v1: requiring a marker on ordinary binders would change
the fused surface the owner ruled MORE important than broadcast.

**Condition (a) is documented AT THE SEAT and is not theoretical**:
parse-reader.rkt:2586-2596 records that the first draft of this walk rebuilt
every stx-list and DROPPED SYNTAX PROPERTIES — including POL.9's
`prologos-paren-origin` — silently degrading an implicit-solve paren goal to an
APPLICATION. The unwrap must be eq?-preserving for untouched forms.

**Drift risks named before code**: the table missing a form (mitigated by the
consumer hardening) · the eq?-preservation trap above · twin drift between the
two groupers · the quote bucket (`':hello`) where the mint fires in EXPRESSION
position and no binder unwrap can rescue it.

**LANDED (the mint + the unwrap) — but P4c-2 is NOT COMPLETE**; condition (c)
is outstanding, see below.

**The mint**: one shared trigger `bcast-step-trigger?` (= `adjacent-to-base?` +
a token-type test + the quote decline), consumed by BOTH groupers rather than
copied. Positional, so `.N`/brackets/parens/closers joined the focus set free.
⚠ **The payload is wrapped VERBATIM** — `($bcast-step |:name|)`, not a stripped
`name`. My pins first asserted the stripped form; that would have forced the
unwrap to re-add `:`, i.e. a SECOND copy of the recognizer's accept-set — the
F1b.7g class. The unwrap is therefore a plain `cadr`.

**The unwrap** needed THREE rules the mini-design had not separated:
- **terminator-bounded** (`def` · `let` · `$pipe` arms) — up to `:=` / `->`,
  never past, so values and arm BODIES keep their broadcasts;
- **param-head SCAN** (`defn` `fn` `spec` `property` `functor` `rel` `defr`) —
  because `rel` is a SIBLING in `def q := rel [a:Int] …`, not a form head, and
  a head-test structurally cannot see it;
- **deep** (`trait`) — method params sit inside lists headed by the METHOD
  NAME, so there is nothing to key on. Safe ONLY because a trait body is
  signatures with no expression bodies; **this entry must narrow if `trait`
  ever gains default method bodies.**

**⚠ CORRECTION TO THIS DOCUMENT — the predicted A/B diff set is ZERO, not
SEVEN.** §5.P4c's named seven-site set was computed against the mint WITHOUT
Q_U16's unwrap. With the unwrap those sites ROUND-TRIP (mint→unwrap = identity),
so the datum never moves: **161 files, ZERO diffs**. Verified it discriminates
rather than trusting the number — zero-where-seven-was-predicted is exactly what
a silently-broken gate looks like. The same lexeme separates the two readings:
`users:Int` → `($bcast-step :Int)` while `let x:Int 5` → `(let x :Int 5 x)`.
A future reader must not treat the mismatch as a regression.

**⚠ A REGRESSION I INTRODUCED, caught by an EARLIER PHASE'S pin.**
`apply-binder-unwrap` did `(car kids)` unguarded — but `kids` is not always a
list: `classify-let-block`'s FAIL path returns a SYNTAX OBJECT wrapping
`($let-error …)`. A contained let-LAYOUT error became a `car: contract
violation`, i.e. a WHOLE-FILE ABORT. parse-reader.rkt carries a "CONTRACT
REPAIR" note documenting that exact hazard, and I reintroduced it roughly one
screen below the note. Caught by test-let-blocks' pin named *"a top-level
let-block LAYOUT error is CONTAINED, not a file abort"* — a pin written by an
earlier phase doing its job against a later phase's author.

**THE EIGHT DELIBERATE FLIPS** (tests/test-parse-reader.rkt:494-516) updated and
annotated IN PLACE as flips — third consecutive phase where the prior rung's
flagship pin flips. Their two neighbours must NOT move and are load-bearing:
`x:0abc`/`x:10abc` (annotation arm declines, colon shatters — OUTSIDE the
trigger) and `{:10 v}`/`{:0 v}` (branch-initial ⇒ empty local result).

**Also recorded — a second guessed baseline this session**: the quote-bucket pin
first asserted `(quote :hello)`; the datum is `(|'| :hello)`, the loose `'`
being exactly WHY the bucket needs a decline. A pin that asserts a REMEMBERED
baseline is the one shape that ships vacuously green.

Suite **9758 / 478 / 0** · battery 294 → **312** · acceptance 52/52 · A/B ZERO.

<a id="p4c-2-close"></a>

##### §5.P4c-2 CLOSE — the table's FOUR measured misses + condition (c)  ✅

**Owner ruled scope (ii)** at the re-grounding checkpoint: full unwrap-coverage
repair, not consumer-hardening alone. The reason is the table's own record —
**measuring it produced four distinct misses inside ONE session**, which
disqualifies the enumeration as the safety property and makes condition (c) the
mechanism rather than the belt. That is the INVERSE of how this document framed
the two, and the inversion is the slice's main design finding.

**⭐ A LIVE END-TO-END REGRESSION, found by re-grounding, invisible to every gate
this phase ran.** `defn- priv [x:Int] x` defines a 1-arity function at ZERO
errors on the pre-mint baseline and FAILS at `b1399016`. `private-form-base`
normalized the `-` suffix at PREPARSE — strictly AFTER the reader post-pass — so
at unwrap time the head is literally `defn-`, the `memq` misses, and the sentinel
leaks into the param group. **ELEVEN suffixed heads.** Isolated by an A/B against
a worktree pinned at `182f1678`. The corpus A/B stayed ZERO because no tracked
file pairs a private form with a fused annotation, and **all 18 P4c-2 pins are
reader-level**, so none could see it — the same blindness that lets
`def x:Int := 5` hold a green datum pin while aborting the whole file.
`private-form-base` MOVED to `reader-forms.rkt` (two consumers, two layers, and
parse-reader cannot require macros) rather than being copied — a second copy is
the F1b.7g class that module exists to forbid.

**The other three misses**: a leading implicit-binder group ATE the arming so the
real param group leaked (`spec f {A} [x:Int]`, idiomatic) · `defmacro`'s param
group binds and was in NO list · a flat single-line `$pipe` arm never reached the
arm rule (SPELLING-SPECIFIC — the multi-line form was correct, and is now pinned
so a fix cannot trade one spelling for the other).

**⚠ AND AN OVER-REACH THE RULING NEVER BOOKED — the opposite direction, which
condition (c) STRUCTURALLY CANNOT CATCH** because no sentinel survives for a
refusal arm to see. The terminator SEARCH ran to the end of the list when no
terminator was found, and `:=` is OPTIONAL in WS `let`: `let x 5` + a body
`users:name` came back with the broadcast silently STRIPPED. Same for arms-only
`defn` (the PRIMARY multi-arity form). Q_U16 booked three conditions; **none of
them covers this direction.** Inert only until P4c-3 gives the sentinel a
consumer — pinned now rather than discovered then.

**ROOT CAUSE, shared by three of the five**: `scan-for-param-heads` carried a
STICKY `armed?` flag that survived every intervening SYMBOL and was discharged by
the next LIST of any kind. That single shortcut produced both directions of
error, and it is why the FIRST `$pipe` arm unwrapped **by accident** — the
`($bcast-step …)` itself was being mistaken for the param group. Replaced with
explicit region consumption over the real grammar: HEAD · optional NAME · zero or
more `{…}` groups · ONE param group · then BODY, never touched.

**Condition (c) — the shape CHANGED once the sites were measured.** This document
scoped it as "convert silence into a guided error" at 17 predicate-keyed sites.
Both halves of that premise are wrong:
- **The 17 are not where a leak lands.** `parse-defn`'s DISPATCHER decides by
  content (its bare-params arm requires every element to be `symbol?`), so a
  leaked LIST declines every arm and never reaches the consumer the census named.
  The guard written at `parse-defn-bare-params`' `[else]` was **unreachable**.
  **FIFTH instance of the `parse-rel-params` blindness class** — a dispatcher is
  a binder consumer, keyed on neither predicate.
- **The failure mode is not silence.** Under maximal mutation every reachable
  form already failed LOUDLY — four different generic messages, two dumping raw
  syntax objects at the user. Only `def` was worse than silent (whole-file abort,
  PRE-EXISTING) — **since FIXED**: the spun-off chip landed and merged, and
  `def x:Int := 5` now defines cleanly at 0 errors (verified at the merge). So (c) is a **DIAGNOSTIC upgrade**, and is described
  as one rather than as the design framed it.

**⭐ MUTATION CAUGHT A DEAD GUARD OF MINE.** The first `bcast-step-datum?`
compared `(car d)` to the symbol directly, but `stx->datum` at these seats peels
ONE layer — the head arrives still wrapped — so the predicate never returned `#t`
at ANY site. Suite green, probes green, guards inert. Only emptying the binder
tables found it. **A green suite is not evidence for a tripwire.**

**The guards cannot carry a standing pin, and that is the desired end state**:
with the table correct nothing reaches them, and hand-feeding the leaked shape as
sexp does not work either (it goes through the SAME post-pass and is unwrapped —
probe-verified). The test file records the five-step MUTATION procedure instead.
Reachable and pinned: the expression-position message (replacing a LYING "Unbound
variable") and that it is PER-COMMAND.

Commits: `cbd8d1a7` (the four misses + the over-reach) · `8c4faee2` (condition (c)).
Gate: suite **0 failures / 478 files** (count nondeterministic per the standing
rule) · battery 312 → **321** · acceptance 52/52 + 89/89 + 6/6 + 29/29 + 28/28 ·
**corpus A/B ZERO diffs across 163 files against the PRE-MINT baseline**, both
legs on ONE `git archive` snapshot · row matrix identical to baseline in every
column.

<a id="p4c-2-inverted"></a>

##### §5.P4c-2 — THE INVERTED DEFAULT (owner ruling, `68cdaae7`)  ✅

The verify's three BLOCKING findings expanded to **seven measured regressions**
(comma false-mint · `Pi` · `Sigma` · `capability` · bracket-`let` · spliced-`let`
after `->` · `let` on a def RHS), each A/B'd against a real `182f1678` build.
Rather than a tenth round of enumeration, the owner ruled **option (2) — invert
the default**, plus the comma fix "and any other enumerations we can identify".

**THE RULING'S SHAPE.** The post-pass used to unwrap only inside RECOGNIZED
binder regions, so a missed head meant the sentinel survived into a binder
position and **broke working code**. Inverted, a miss can only mean *"broadcast
does not fire here yet"* — the annotation still works, the broadcast reports
loudly. Errors may become meanings, never the reverse: the same monotonicity
§9's strict-first waypoint is ratified on.

**⭐ THE ENABLE-SET IS EXPLICIT AND EMPTY.** `broadcast-enabled-contexts` = `'()`.
Not an omission — the sentinel has no consumer until P4c-3, so preserving it
anywhere buys nothing and costs a SPELLING-DEPENDENT surface. The moderate form
was built first and measured, and had exactly that defect: the sentinel survived
in a FLAT `def y := users:name` but not in an indented body — an accident of
recursion order, not a decision. Made uniform instead.

With the set empty the mint is **provably equivalent to not minting**, which is
what turns "regression-free" into a checkable property:
- the 15-probe matrix is **byte-identical** to a real `182f1678` build;
- corpus A/B **ZERO diffs / 163 files** against the PRE-MINT baseline;
- the eight "deliberate flips" in `test-parse-reader.rkt` **flipped BACK** to
  their pre-mint datums — a mechanical demonstration that **mint ∘ unwrap =
  identity** on every one of those shapes.

**⚠ THE ENUMERATION DOES NOT VANISH — IT MOVES.** Recognized heads still own
their bodies, so the table becomes *"where broadcast SURVIVES"*. Only the failure
DIRECTION changed. That was the whole of the ruling and it should not be
overclaimed as retiring the table.

**Other enumerations fixed, not merely listed**: the COMMA closed as a **class**
(`adjacent-to-base?` asks about the physically preceding token while the base it
means is the last thing in `result` — they disagree for every token grouping
consumes WITHOUT EMITTING; the quote decline was written for exactly this and its
own comment named the shape) · **region heads are not always form heads** (the
identical blindness already fixed for param heads) · the bracket bindings group ·
`unwrap-bcast-step`'s unguarded `cadr` (a whole-file abort, THIRD instance of
that shape in this track). The `capability`/`Pi`/`Sigma`/`DSend`/`DRecv` rows
were deliberately **not** added — the inverted default covers them and every
future form, which is the point. The guard the verify proved **dead by
construction** was deleted: a dead tripwire reads as coverage.

**Honest consequence**: the guided `bcast-step` / `bcast-step-binder` messages
are now UNREACHABLE — live code behind an empty enable-set, reachable at P4c-3
with the first enabled context. Kept rather than reverted; their pins restaged to
assert today's inert behaviour so nothing claims coverage it lacks.

**Still owed at P4c-3** (named so they are not rediscovered): the over-reach
survivors the verify found in property clauses / bare-`fn` / type unions become
live the moment a context is enabled · `parse-param-names-for` is an unhardened
binder consumer · the `*`/`^` swallowing hazard · **the blind spot nobody has
tested: the `.pnet` module-cache round-trip and the REPL/LSP reader entries** —
every probe in this arc used exactly two doors.

Gate: suite **0 failures / 478 files** · battery **322** · acceptance 52/52 +
89/89 + 6/6 + 29/29 + 28/28 · A/B ZERO/163 · matrix identical in all 15 columns.

Status: ✅ **P4c-2 COMPLETE** (`b1399016` · `cbd8d1a7` · `8c4faee2` · `68cdaae7`).

<a id="p4c-3"></a>

##### §5.P4c-3 — The `(@bcast step)` step kind  (close 2026-08-02)

**Deliverable: the KIND and its arms.** `(@bcast step)` added to
`select-step-kind`'s closed union and armed across the `ADDING A KIND` recipe's
THIRTEEN sites (`3b998aa8`). The recipe **held with no correction** — the first
enumeration in this arc to survive a new member intact, which is worth recording
precisely because the arc's other lesson is the opposite. The NAME/KEY walks
DELEGATE to the wrapped step (ω changes container ARITY, not key behaviour); the
VALUE walks emit a guided NOT-YET naming P4c-4, because delegating there would
project off the CONTAINER instead of broadcasting over it.

Prerequisites landed first per owner ruling: `8fa30336` (DEFERRED 32 over-reach
survivors) · `8c95d4ae` (DEFERRED 36 RESOLVED). Then `f6310c27`, the `[else]`
split — the inversion had written `(scan-for-param-heads (map unwrap-binders-deep
kids))`, stripping deeply FIRST, so the scan was DEAD WORK and the eight
param-head forms would have been blanket-stripped at the first grant.

##### ⭐ THE ENABLE-SET MOVES TO P4c-4 (owner ruling 2026-08-02)

The sub-phase opened on the question "what fills `broadcast-enabled-contexts`" —
per-FORM or per-POSITION granting, and is preserve TRANSITIVE. **The question is
not answerable as posed, and three MEASURED facts say why.**

1. **The enable-set is a boolean wearing a list's clothes.** Exactly three
   production references — the definition (parse-reader.rkt:2845), the `(pair?
   …)` predicate (:2847), and ONE consultation (:3007). **Nothing anywhere tests
   membership.** So "which contexts" is not a choice the code can express; any
   non-empty value flips the same global switch. And because that arm is FIRST
   in the `cond`, the first grant switches on ~80 lines of never-executed code
   at once — arms 2–5 plus ten helpers, including all three `8fa30336` fixes.
2. **Granting anything breaks the position broadcast is actually written in.**
   Matched A/B via the recorded MUTATION procedure (force non-empty, rebuild,
   probe, revert):

   | spelling | empty (HEAD) | non-empty |
   |---|---|---|
   | `def flat := users:name` | "Could not infer type" | guided not-yet — **survives** |
   | `defn armed \| 0 -> users:name` | generic param error | guided not-yet — **survives** |
   | `defn body-app [q] [one users:name]` | "Too many arguments" | **unchanged — STRIPPED** |

   The third is DEFERRED 32's open half. Head `one` is unknown to the `cond`
   AND to the scanner, so `recognized? = #f` and `[else]` blanket-strips
   (:3067-3069). ⚠ **That symptom is OVER-DETERMINED** — the strip and the
   missing `access-sentinel?` membership both produce it. The strip is confirmed
   by the code path, not by the probe alone.
3. **Flipping the unknown-head default to PRESERVE is refuted from the corpus.**
   `[add ?x:Nat ?y:Nat] = 5N` (examples/2026-03-09-fc-trait-rel-dom.prologos:141,
   runs 0 errors today) is a live BINDER position under an unknown head.
   `[one users:name]` is an EXPRESSION position under an unknown head. Both are
   `[SYMBOL item item]`. **The head-keyed walk cannot separate the two
   populations in either direction, and the corpus contains live examples of
   both.**

   ⚠ **REFUTED 2026-08-02 — this counter-example DOES NOT EXIST.** `?x:Nat` is glued into ONE TOKEN by `recognize-narrow-var-annot`, so the trigger can never fire on it; `[add ?x:Nat ?y:Nat] = 5N` mints NOTHING, under any grant. The claim was inferred from "this line runs 0 errors today" without checking whether it MINTS — and the tree's own comment said so. **PRESERVE has ZERO measured corpus regressions** (795-file census). See D4 `#q-u18`.

**And there is nothing behind the switch yet.** `make-select-bcast` has ZERO
production callers (syntax.rkt:177 provide + :907 definition only) — no producer
bridge exists, and the parser's `bcast-step` arm emits the not-yet error instead
of constructing (parser.rkt:863). `$bcast-step` is absent from `access-sentinel?`
(macros.rkt:6128-6132), so a survivor would not even fuse onto its base. **No
grant can make broadcast work in any position today; it can only change which
not-yet error you get, and break application position on the way.**

**Ruling**: P4c-3 closes on the kind + its arms, enable-set still `'()`. The set
and its five prerequisites move to P4c-4, where the consumer lives. This keeps
the mint equivalent-to-not-minting through the close, and means the unknown-head
default gets ruled against a WORKING consumer rather than against a not-yet
error — spending the ruling on a switch with something behind it.

⚠ **On "provably ≡ not minting"** (P4c-2's close): what holds BY CONSTRUCTION is
COUNT-PRESERVATION. Full equivalence rests on the shape-sensitive classifiers
being invariant, which is established EMPIRICALLY (A/B ZERO/163 + the 15-probe
matrix + the eight flipped-back pins). **A measured equivalence with a named
limit, not a proof** — and the limit is precisely the one the P4c-2 verify
already paid for: the corpus DOES carry fused spellings (`defn square [x:Int]`
at lib/examples/foray.prologos:116, `defr bool [?p:Int]` at :891, `let x:Int 4`
at examples/2026-07-31-let-blocks.prologos:185, and more), but it carries no
instance of the particular COMBINATION that broke — a private-suffix head paired
with a fused annotation — which is why that regression was A/B-invisible AND
invisible to all 18 reader-level pins. Corpus coverage is per-COMBINATION, not
per-feature; do not read "the corpus exercises fused annotations" as cover.
Related: `absorb-let-siblings`, `classify-let-block` and `mark-let-goal-rhs`
ALREADY SEE minted sentinels at HEAD — they run BEFORE `apply-binder-unwrap` in
the same visit (parse-reader.rkt:3220-3225). The empty enable-set protects the
pass's OUTPUT, not its internals.

<a id="p4c-3a"></a>

##### §5.P4c-3a — the FOURTEENTH site: `select-step-name` was ω-blind

D4's partition names "the two shape-test helpers OUTSIDE the recipe". Only
`select-step-cont` was covered — and covered by unwrapping at its call sites, not
in the helper. `select-step-name` was missed, and the recipe structurally could
not catch it: the recipe enumerates `case (select-step-kind …)` dispatchers and
this is an `if` over ONE predicate.

**The defect is an ASYMMETRY, which is why no P4c-3 pin caught it.** The branch
CLASSIFIER `select-branch-collapse` sees through the wrapper, so a `users:k^-`
branch sorts correctly as collapsing — and then the LABEL is taken from the RAW
leaf. Measured before the fix:

```
(select-branch-top-keys (list (make-select-bcast '(@key k collapse))))
  ⇒ ((@bcast (@key k collapse)))     -- a LIST, against a contract of
                                        "a key SYMBOL … or #f"
```

Three call sites share `[else (select-step-name (car (reverse b)))]` inside a
`col`-guarded branch: `select-branch-top-keys` (syntax.rkt), `branch-entries`
(reduction.rkt), `select-branch-entries` (typing-core.rkt). The latter two are
**MASKED** today — but for DIFFERENT reasons, and only one is evaluation order:
reduction computes the label first and discards it when `walk-to-leaf` raises,
while typing-core computes it INSIDE the continuation, which the raise precedes.
Both go live when P4c-4 removes the raise. **syntax.rkt's is live now**:
`select-branch-top-keys` is a pure STATIC key computation feeding the parser's
OUTPUT-key duplicate check and its L4 sort-homogeneity check, with nothing to
raise first, and a non-symbol component can never match under the duplicate
check's `eq?` — so duplicates would go UNDETECTED. Silent, the one outcome the
P4a totality dispatcher exists to prevent.

Fixed in the HELPER, not at the three call sites: a third copy of the unwrap is
the F1b.7g drift class this vocabulary has already paid for. Delegation is
recursive, matching `select-step-output-name`'s `[(bcast)]` arm.

⚠ **NO `syntax.rkt` LINE NUMBERS IN THIS SECTION, DELIBERATELY.** The first cut
of both the section and the in-code comment cited that file's coordinates, and
the comment's own +59 lines invalidated every one of them — the section's map
pointed into the middle of the comment that made it stale. That is the exact
class `19ab78a9` had fixed ONE COMMIT EARLIER. Anchor on NAMES; `grep` is the
index. (Caught by the adversarial verify, which is also how the `parser.rkt`
sibling below was found.)

<a id="p4c-3a-cont"></a>

##### §5.P4c-3a (cont.) — and the FIFTEENTH, found by my own false comment

Writing the fix, I asserted above `select-step-cont` that "every one of this
helper's call sites already unwraps, so it correctly stays ω-blind." **Checking
that assertion instead of shipping it refuted it.** `parser.rkt`'s
`^`-in-path-access refusal did not unwrap, and `select-key-step?` is false for a
wrapper, so the `ormap` silently missed a `^` inside one. Measured on the exact
lambda that line carried:

```
(@key k dissolve)            ⇒ dissolve   -- refusal fires
(@bcast (@key k dissolve))   ⇒ #f         -- refusal does NOT fire
```

That is the identical hole `branch-problem` documents **and unwraps for**, at a
sibling site in the same file that did not. **D4 had already booked this hazard
independently** at §4310 (`:name^alias` "slips past" the `^`-refusal) — so the
comment asserted completeness against a hazard its own design doc had recorded.

**⭐ AND THE FIX CHANGED SHAPE UNDER THE ADVERSARIAL VERIFY, which is the part
worth keeping.** My first cut kept `select-step-cont` ω-BLIND and hand-copied the
unwrap into the parser, justified as: its callers "ask SEVERAL questions (kind
AND cont)", so the unwrap belongs with the classification. The verify's sharpest
finding is that **this justification is false at precisely the site that received
the copy** — the refusal asks ONE question, and with a transparent accessor its
whole lambda collapses back to a bare `(ormap select-step-cont …)`. Two further
facts settled it: the enumeration in my comment said FIVE call sites and there
are **NINE**; and transparency is a measured NO-OP at the other eight (each has
already unwrapped and is looking at a `caret` step, or sits behind a `memq` guard
excluding `bcast`). So: **both accessors are now ω-transparent**, the hand-copy
is gone, and the standing obligation — which had already been sprung once — is
removed rather than pinned. My first cut had literally pinned the blindness as
INTENDED, which would have made the trap permanent and turned removing it into a
test failure.

Two more verify findings, both acted on: the fifteenth-site pin as first written
**defined a local COPY of the parser's predicate**, so reverting the production
fix left it green — a dead tripwire, the very thing P4c-2's close had already
deleted one instance of. It now exercises the shipped helper (checked: the
shipped and old-blind definitions disagree on the pinned input). And the
DEFERRED-39 sweep, which that item ASKED FOR and I had not run, has now been run
— it found **two more ω-blind sites** (`parser.rkt:1170`, `:1212`), both silent
and diagnostic-degrading, **deliberately left unfixed because no probe I wrote
reaches either one**; fixing a diagnostic that cannot be gated is the failure
mode, not the fix. Booked with mechanism + fix shape in DEFERRED 39, plus
DEFERRED 40 for `select-step-name`'s remaining non-totality (`(@ord N)` and
`(@sub …)` still return LISTS against the same contract — pre-existing, and
raising on `sub` could break a live guarded path, so it needs measurement).

⚠ **THE GENERALIZABLE POINT, and it is the one worth carrying forward.** The
`ADDING A KIND` recipe enumerates `case (select-step-kind …)` dispatchers, so it
structurally **cannot see** helpers shaped as an `if`/`and` over ONE predicate.
That is the same blindness-class the recipe's own header records for its first
cut (open-coded shape tests; `and`/`if`-shaped dispatchers) — so the recipe's
"held with no correction needed" is true *of the thirteen* and was never a claim
about the two helpers D4 named outside it. One of those two was covered, one was
not, and a fifteenth site nobody had named shared the defect. DEFERRED 39 books
the sweep BY SHAPE. The honest revision of the P4c-3 headline: the recipe held;
the boundary around the recipe did not.

Gate: suite **0 failures** · battery **325 → 328** · acceptance 52/52 + 89/89 +
6/6 + 29/29 + 28/28 (all matching the recorded baseline) · the five `^`-refusal
spellings re-probed end-to-end (all refused; plain access and `m{foo^alias}`
still work, so the added unwrap did not make the refusal blanket).

Status: ✅ **P4c-3 COMPLETE**. Status: ⬜ P4c-4..5.

<a id="p4c-4"></a>

##### §5.P4c-4 — PVec broadcast + the enable-set  (mini-design + mini-audit, opened 2026-08-02)

**Grounding**: audit `wf_b5bc52c5-bfd` (5 facets + completeness critic @
`c3bf0c63`, 6 agents / 1.13M tokens). Every load-bearing claim below was
**R-lens-verified on the main thread**.

**⚠ THE SLICE ORDER I FIRST RECOMMENDED WAS BACKWARDS, and grounding caught it.**
I proposed "fold membership + producer bridge first, so the unknown-head question
becomes decidable against a working consumer." Neither can be **observed**: with
the enable-set empty, `apply-binder-unwrap`'s first arm strips every sentinel in
every position, so nothing reaches the parser's `bcast-step` arm. Measured — five
surface spellings (`users:name`, `def a := …`, `[…]`, map-literal value, `|>`)
plus the literal internal head `($bcast-step :name)`: **ZERO occurrences** of the
guided not-yet message; the literal head yields `:name : Keyword`. So the
**TEST SEAM is a prerequisite, not a successor** — today the only validation
route is source mutation on a scratch build, which is precisely what let three
enumeration gaps through this arc.

**THE SLICE IS AT LEAST FOUR SITES, NOT TWO.** `macros.rkt:6125-6127` states the
obligation as three (a datum-level predicate + the `access-sentinel?` entry + the
fold arm), and `segment-select-items` needs its own arm or an unarmed
`($bcast-step …)` lands on its `[else]` and emits a plausible-but-wrong
diagnostic (`parser.rkt:1252-1255`).

**Verified about the fold**: `access-sentinel?` has exactly ONE production
consumer — the gate at `macros.rkt:6195` — and no seat carries its own member
list, so Q_U16's "inherits all four seats for free" **is true at the predicate
layer**. All four seat coordinates verify unchanged. ⚠ Two corrections: **all
FOUR seats run inside preparse** (`parse-reader.rkt:2769` says "two of which" —
third drift in that same comment block, in the SAFE direction, since it
strengthens Q_U16); and seat `:2714` is **re-entered FROM the parser** via
`parse-type-segment`, so "before the parser exists" is false of every
*invocation* though the reader post-pass still precedes it. **The fold arm
inherits a FIXPOINT OBLIGATION**: its emitted datum must NOT be sentinel-headed,
or `preparse-expand-subforms` re-enters and swallows one LEFT sibling per pass —
the P1b-iii bug that silently DROPPED a `defn` clause at zero errors.

**DEFERRED 39's two ω-blind sites are NOT reachable from the headline case** —
both need a multi-item payload and `$select-path` mints exactly one field per
level, so they go live only for a BLOCK-position broadcast. Whether they are in
scope depends on whether this slice lights up block position.

<a id="p4c-4-merge"></a>

###### ⭐ THE DUAL-SPINE MERGE — absent from every prior enumeration

Prologos runs TWO parsers and `merge-form` ends `[else tree-surf]`
(`driver.rkt:2503`, commented *"tree parser wins for user forms"*). What protects
every SIBLING selection surface is that it is deliberately **errored** on the tree
spine (`tree-parser.rkt:147` `select-brace-group`, `:177` `dot-access`), and
errored surfs are filtered out of `tree-by-line` (`#:when (not (prologos-error?
s))`, `:2473`), so preparse becomes authoritative. That file states the hazard
verbatim: *"a missing arm lets a garbage surf BEAT preparse's."*

**`$bcast-step` mints NO TAG, so it has no tag arm and that protection is
STRUCTURALLY UNAVAILABLE to it.** `same-form-type?` compares the OUTER form
(`surf-def` vs `surf-def`), not the body — so a `def q := users:name` whose tree
body is a garbage application would fall to `[else tree-surf]` and win.

**And it is defused today by a plain defect, not by design.** `loc->line`
(`driver.rkt:2443`) takes `(cadr loc)` for any list ≥2; tree NODES carry
`(line col start end)` (⇒ COL) and tree TOKENS carry `(0 0 start end)` (⇒ 0),
while preparse carries srcloc STRUCTS (⇒ real line). The keys are on different
scales, the lookup misses, preparse wins. **The broadcast is protected by
accident**, and the day that is corrected every latent tree surf goes live at
once. Filed OUT OF BAND with the blast radius deliberately unmeasured:
`docs/tracking/2026-08-02_LOC_TO_LINE_MERGE_DEFECT.md` (`388af899`).

~~**Recorded assumption of the producer bridge**: if that fix lands, the broadcast
needs its own tree-spine protection in the same change.~~

✅ **DISCHARGED 2026-08-02, and in the favourable direction — the assumption is
moot because THE TREE LEG IS GONE.** The out-of-band investigation this note
spawned (`388af899` → the arc merged at `1d23600e`) did not fix the key: it
measured that fixing the key makes things **worse**, and removed the leg instead
(`2d7813ef`). `merge-form`, `tree-by-line` and `loc->line` no longer exist in
`driver.rkt`. Verified at `0ca22343`: the only remaining mention is a historical
comment recording the removal.

**Three findings from that arc that this design should absorb**, because two of
them correct things recorded above:

1. **There was a THIRD defect, and it inverts the fix I proposed.** The two spines
   number lines on **different bases** — tree 0-based, preparse 1-based. So the
   arm-swap "minimal fix" in the spawned note's §3 would have paired form N's
   preparse surf with form N+1's tree surf: **176 of 242 hits mispaired (73%)**,
   and end-to-end `def a := 1` became `ERROR: Unbound variable`. My suggested fix
   would have shipped a silent wrong-answer bug. It was in nobody's enumeration —
   not the note's, not the P4c-4 mini-audit's, not five grounding facets'.
2. **The tree spine had won ZERO forms, ever.** `[else tree-surf]` never once
   fired in the life of that code. And correcting the key made the corpus
   REGRESS — errors 359 → 724 across 35 files with **not one improvement**, two
   clean files lost to whole-file aborts, 32 test files failing, from **14
   distinct defects across 4 layers**.
3. **The census settled what the merge even WAS**: the tree spine's datum path
   feeds `parse-datum`, *the same parser preparse uses*. It never adjudicated
   between two parsers — it compared one parser against itself across two
   READERS. So there was never a second opinion for the broadcast to lose to.

**Consequence for P4c-4b**: the producer bridge needs no tree-spine protection,
no tag, and no `merge-form` exception arm. That whole branch of the slice is
deleted rather than deferred.

⚠ **Carry the METHOD lesson, not just the outcome**: an error-COUNT gate could
not see the two whole-file aborts, and a full-output census found six value-level
flips with the count unchanged (`"localhost" : String` → `<error> : String`).
**Gate corpus work on FULL OUTPUT, never on error counts** — which is what
`pipeline.md` already says about whole-file aborts, now with a second instance.

**Mantra check, honestly**: this is reader/parser-layer work and the parse layer
installs **ZERO** propagators. "On-network" is not satisfied and cannot be by this
slice — it is off-network scaffolding whose chartered retirement is **PPN 4D**
(prerequisite-blocked on 4C + PM Track 12). Named rather than rationalized.

**Drift risks named at the open** (checkpoints for the mid-flight principles
challenge): the "four seats for free" claim (assume short until each seat's own
code is read — it held, but only at the predicate layer); `$bcast-step` has no
`pnet-serialize.rkt` registration and DEFERRED 36's ✅ is scoped to the empty
enable-set, so caching goes live with the first grant; scope creep from the
enable-set's MECHANISM into its POLICY (the unknown-head ruling); the `*`/`^`
swallow hazard, still unowned.

<a id="p4c-4b"></a>

###### §5.P4c-4b — the fold arm + the producer bridge + the not-yet CHANNEL  ✅ `6b22515d`

**The chain closes.** Reader PRESERVES (P4c-4a's grant) → the fold FUSES onto the
base → the parser CONSTRUCTS `(@bcast step)` → typing REFUSES through the failure
slot. Measured with a `def` grant:

```
def q := users:name   ⇒ broadcast `:name` — the ω value semantics land at P4c-4c…
def after := 42       ⇒ after : Int defined.       ← THE POINT
```

**⭐ THE CHANNEL FIX, WITHOUT WHICH THIS SLICE SHIPS A WHOLE-FILE ABORT.**
`select-bcast-not-yet` raises a raw `error`; `process-command/solve-guard` catches
ONLY `exn:prologos-solve`, deliberately. Unreachable before now — **the producer
bridge is exactly what reaches it.** Root cause: TWO PROPOSITIONS SHARING ONE
CHANNEL — *the compiler is broken* (`select-step-kind-unhandled`, raise is RIGHT)
and *the user wrote something unbuilt* (raise is WRONG). Split: typing returns
`(values #f (select-fail 'bcast-not-yet …))` through the slot these walks ALREADY
thread; reduction KEEPS its raise, because arriving at the value layer after
typing refused IS an invariant violation. Two arms, two questions.
⚠ **This corrects a claim I made to the owner** — that an error value would be
"invasive and need threading". It was not; the threading was already there. The
principled fix and the cheap fix were the same fix.

**The six parts.** `bcast-step?` + `$bcast-step` into `access-sentinel?` (the
P4c-2 deliverable that never landed under a ✅ — DEFERRED 37; it read as closed
because `broadcast-access?` there is the RETIRED `$broadcast-access`) · the fold
arm, the `$dot-access` arm VERBATIM except the payload rides WHOLE, so the emitted
head is `$select-path` and the **fixpoint obligation holds by construction** · the
`segment-select-items` arm + the PRODUCER BRIDGE (`make-select-bcast` had ZERO
production callers until this import).

⚠ **My first cut of the parser arm was WRONG and a probe caught it.**
`$select-path` consumes the SUBJECT itself and passes only `(cdr args)`, so for
`users:name` the ω step arrives FIRST with no `cur`. I treated that as
branch-initial and it refused the headline spelling with "needs a preceding
subject". `cur = #f` now STARTS a branch, as `plain-key?` does. W2's
branch-initial refusal is a BLOCK rule, and the mint cannot produce one there
anyway (it requires byte-adjacency to a base).

**The payload asymmetry — three sub-cases, two of them silent.** `$bcast-step`
carries the token VERBATIM so its payload is COLON-LEADING, where `$dot-access`
carries a bare symbol. Stripping and handing it to `plain-key?` is silently wrong
twice: `users:0` would be a NOMINAL key named `0` (Q_U16b rules it an ORDINAL —
now the number), and `users:tags*` would be a field LITERALLY NAMED `tags*`
(`ident-continue?` admits `*`, so it arrives as ONE token — now a guided
refusal). `users:name^alias` is the safe one: it routes to the ONE splitter.

**Riders.** The four "a wrapper never heads a branch" comments CORRECTED, polarity
inverted — the claim conflated a BLOCK surface rule (`x{:name}`) with a
representation invariant about a one-step `'path` branch, and three of the four
justified an arm by it. The `.pnet` gate item DROPPED (`expr-path` IS registered).

Gate: suite **9831 / 482 / 0** · battery 336 → **340** · acceptance 52/52 + 89/89
+ 6/6 + 29/29 + 28/28 · **corpus A/B: ZERO semantic diffs.**

**The A/B, and how it was scoped** — recorded because the scoping is the
interesting part. A full 139-file run was started and ABANDONED (≈40 s/file × 2
legs ⇒ hours). It was re-scoped to the **12 files that can possibly MINT** — an
`ident`/`)`/`]`/`}` byte-adjacent to `:` — because those are the only files where
`access-sentinel?`'s new member or the fold arm can fire. That is targeting, not
narrowing: for every other file the new predicate changes an `or`-chain's cost
and not its result. Both legs read ONE `git archive` snapshot (so the owner's
dirty tree cannot masquerade as a code delta) and the baseline was
**worktree-pinned** at `6b22515d^`; diffed on **FULL OUTPUT**, never error counts.

Raw: 4 of 12 differed. All four were internal-counter drift (`?meta2472` vs
`?meta2086`) — and the offset was a CONSTANT 386, which is the tell for a
startup/tree-state difference rather than a per-file one. **Discriminated rather
than assumed**: a control file that CANNOT mint shows the same drift, so it is
not the fold. Normalizing counters leaves **ZERO** semantic diffs across all 12,
the control **IDENTICAL**, and one residual that is the `run-file.rkt`
FILESYSTEM PATH inside a stack trace — worktree vs main checkout, an artifact of
the method itself.

⚠ **Two false greens of mine, both from grepping a keyword instead of counting
the outcome**: a module-load `unbound identifier` is not a `FAILURE`, and rackunit
reports an arity mismatch as `ERROR`. The batch runner's count caught both. Grep
the outcome, not a word.

Status: ✅ **P4c-4b COMPLETE**. Next: **P4c-4c** — the ω VALUE semantics (PVec
broadcast + the L1/extent law pins), which is what the not-yet now names.

<a id="p4c-4a"></a>

###### §5.P4c-4a — the test seam + per-context dispatch  ✅ `f31237fd`

`broadcast-enabled-contexts` was an unexported `define` and
`broadcast-preservation-active?` was `(pair? …)` — a boolean wearing a list's
clothes. Now a **guarded parameter**, exported, with the predicate testing
**membership keyed on the node's own head** (via `binder-head-base`, so the
eleven private-suffix spellings cannot drift). A grant scopes to the form it
names; the default stays empty, so production behaviour is byte-identical —
proven, not merely tested: `(memq X '())` is #f for every X and
`binder-head-base` is total and effect-free.

**The adversarial verify refuted TWO of my claims and found a real defect.**

1. **No guard**, admitting the whole-file-abort class: this parameter is set BY
   HAND from tests, so dropping the list is the natural typo, and
   `(parameterize ([… 'def]) …)` raised `memq: not a proper list` at READ time
   outside any per-command handler. **Fourth instance of that shape in this
   track**, with the first three documented one screen away. Guarding at the
   parameterize makes the membership test total by CONSTRUCTION.
2. **My totality comment was FALSE** — it argued from "`(memq #f …)` is #f for
   every list", but `(memq #f (list #f))` is `(#f)`, so a `'(#f)` grant would
   have granted every group-headed node.
3. **My scoping story was HALF TOLD**, and the missing half is the operative one.
   I documented only that an outer grant cannot reach INWARD. Outward runs the
   other way: an **ungranted ancestor destroys what a granted descendant
   preserved**, because the not-granted arm's `unwrap-binders-deep` recurses
   through already-visited sub-groups. So the rule is a **CHAIN** — node granted,
   every ancestor granted, and each ancestor's rule leaving that position alone.
   Pre-existing (the old global switch stripped these identically) but
   undocumented and untested, **and it is what decides whether P4c-4b's first
   real grant works.** Now documented at the definition site and pinned.
4. **"Mechanism only" was too strong.** The `[else]` arm's CODE is untouched; its
   REACHABILITY is not — previously every node reached the cond once anything was
   granted, now only granted heads do. Production is unaffected (default empty),
   so the honest claim is "**no production behaviour changes**", not "policy is
   untouched".

**DEFERRED 32's open half stays untouched and undecided, by design.** A pin
caught me encoding a wish about it: I asserted granting the INNER head `g` would
preserve inside `[g users:name]`; it does not, because `g` is unknown and the
unknown-head arm strips regardless. The failure was correct behaviour, and it
re-confirms P4c-3's measurement from a second direction — now by a shippable test
rather than a mutation.

**Perf, measured** (the predicate runs once per node): **+45 ns/call** (50.7 vs
5.9); ~681 calls on a 1164-line file against 139 ms reader wall ⇒ **~31 µs,
0.02%**. A 200-entry nonsense grant inflating `memq` ~40× is within noise across
three interleaved rounds — so suite wall movement is ambient, not this.

**Lint**: baselined by hand with rationale. **NOT** added to `test-support.rkt`'s
parameterize blocks despite `pipeline.md`'s checklist — five of those six blocks
are PER-RUN helpers, so registering it there would clear the grant inside the
very helpers a test uses to exercise it. Not `--save-baseline`d either, since
that would silently accept two parameters that are not mine (DEFERRED 41).

**Mutation-verified**: reverting to the old global `pair?` turns **2** pins red.
Said plainly because the first draft turned only ONE red and had to be
strengthened — and because at assertion granularity that is 2 of 12, i.e. four of
the six original test-cases are regression ANCHORS, not discriminators.

Gate: suite **9807 / 479 / 0** · battery 328 → **336** · acceptance 52/52 + 89/89
+ 6/6 + 29/29 + 28/28.

Status: ✅ **P4c-4a COMPLETE**. Next: **P4c-4b** — `access-sentinel?` membership +
the fold arm (with its FIXPOINT obligation: the emitted datum must not be
sentinel-headed) + the producer bridge + the `segment-select-items` arm, carrying
the [dual-spine merge assumption](#p4c-4-merge).

<a id="p4c-4c"></a>

##### §5.P4c-4c — the ω VALUE semantics  (RE-SCOPED 2026-08-02; owner-assented)

**⭐ THE SLICE AS ORIGINALLY SCOPED CANNOT LAND ITS OWN DELIVERABLES.** Three
independent READER facts each suffice to block it, all re-verified on the main
thread at `17086a09` (the critic found them; I re-ran its probes rather than
accept them):

1. **A bare top-level ω is STRIPPED under EVERY grant.** `users:name` →
   `((users :name))` even granting its own head, even under a broad grant — the
   unknown-head policy (DEFERRED 32's open half). **Every ω line in the
   acceptance file is a bare top-level command.**
2. **`:{…}` DOES NOT MINT** — `users:{t r}` reads as `users : ($select-brace t r)`,
   because `bcast-step-trigger?` gates on token TYPE and a lone `:` before an
   opener is neither `keyword` nor `colon-annotation`. That kills `quests:{t r}`
   **and both members of the §3.2.1 extent pair** — all named in the old scope.
3. **`broadcast-enabled-contexts` has ZERO production setters**, so `process-file`
   runs at default `'()` regardless of anything this slice does.

Of the four originally-named deliverables, only the L1 fusion pin has a mintable
line — and `users:0:userName` bare is stripped too, so even that needs `def`
position plus a grant reaching `process-file`.

**⚠ TWO CARRIER FACTS I ASSERTED WERE WRONG**, and each would have produced bad
code: `expr-hset` has **no arm in any of the four dispatchers** — Set is not a
selection carrier at all today, true of the struct and false of the machinery
(I would have written an arm that can never fire); and `expr-Record` is
**TYPE-only** — a het tuple's runtime value is an `expr-rrb` (I would have
mis-keyed the value arm).

**RE-SCOPED DELIVERABLE — PVec value semantics only**, which is what the scope
line always said and what the not-yet message promises a user:
- the THREE typing arms (`walk-to-leaf`, `select-branch-entries`,
  `select-below-field`) — return a TYPE into the `(values x fail)` slot;
- the THREE reduction arms (`walk-to-leaf`, `branch-entries`, `below-value`) —
  return a VALUE; these have **no failure slot**, escaping via `let/ec return`;
- ⚠ **a FOURTH site the partition did not name**: an `rrb-of`-style container
  guard. `champ-of` and `index-into` are the precedent; there is **no `rrb`
  twin**, and because reduction carries no failure slot a mid-descent
  non-container has no other way to report;
- the L1 fusion + §3.2.1 extent LAWS pinned in the battery in `def` position
  (which mints); their CORPUS lines wait on Q_U18 + the `:{` mint.

**Semantics, from the code**: `xs : [PVec {:name String}]` ⇒ `xs:name` is value
`@["…" …]` (`expr-rrb`) at type `[PVec String]`. Mirror `pvec-map : (A → B) →
PVec A → PVec B` and the `expr-pvec-map` whnf arm. The corpus pins the shape
three lines above the commented target with the explicit `map` spelling.

**⭐ SCOPE WIDENED 2026-08-04 [owner: *"G2 alongside P4c-4c"*] — G2 LANDS HERE.**
The slice is now TWO pieces, and the second is what makes the first observable:

- **(A) the PVec ω value semantics** — the six arms + the `rrb-of` guard above;
- **(B) G2 — retire the enable-set** (`broadcast-enabled-contexts` /
  `broadcast-preservation-active?`), making head-keyed preservation
  UNCONDITIONAL. Rationale + the full argument: [Q_U18](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u18)'s G2 block.

**Why together, stated so it is not re-litigated**: the PRESERVE flip is INERT
at the default, because parse-reader's FIRST arm deep-strips any node whose own
head is ungranted. So (A) alone ships value semantics for a surface reachable
only from the battery — the *Validated ≠ Deployed* shape the arc has already
named once. (B) alone ships reachability with nothing to evaluate to. Together
they are the first end-to-end user-visible broadcast.

**⚠ THREE OBLIGATIONS THAT ONLY EXIST BECAUSE (B) IS IN SCOPE**, none of which
prior P4c slices carried:
1. **The corpus A/B becomes load-bearing.** Every earlier slice could lean on
   "default `'()` ⇒ byte-identical"; that argument is gone. Re-derive the
   mintable-file set at HEAD rather than inheriting P4c-4b's 12, diff FULL
   OUTPUT, and carry a CONTROL file that cannot mint to discriminate counter
   drift.
   ⚠⚠ **CORRECTED 2026-08-04, WITHIN THE HOUR, BY MEASUREMENT — this obligation
   as first written produced a FALSE ALL-CLEAR.** It said *"pin BOTH legs to ONE
   `git archive` snapshot (the owner's tree is dirty)"*, inheriting P4c-4b's
   method wholesale. **Snapshot the CODE; run the INPUTS from the WORKING TREE.**
   The reason is specific and fatal: `lib/examples/foray.prologos` is the ONLY
   file G2 changes, and it is **owner WIP — 114 lines committed vs 946 in the
   working tree** (measured). A snapshot-INPUT A/B therefore compares a corpus
   that **does not contain the feature** and reports **ZERO diffs across all 304
   files** — a total false all-clear on the one slice where production behaviour
   actually moves. Measured against a real arm-deleted build, working-tree inputs
   give `304 compared · 1 CHANGED · foray.prologos, 13 of 201 forms`.
   ⚠ The dirty tree is still a hazard — it just moves: report **which side of the
   committed line each diff falls on**, so owner WIP cannot be read as a G2
   effect. Do NOT `git stash`.
   ⚠ And the **"12 mintable files" figure is NOT REPRODUCIBLE from its stated
   criterion** — the recorded rule ("an `ident`/`)`/`]`/`}` byte-adjacent to
   `:`") selects **161 of 163** files literally, **143** with comments stripped,
   and the true token-level predicate selects **3**. Whatever produced 12 was
   neither. Re-derive; do not inherit the number OR the rule.
2. **The battery inverts.** P4c-4a's pins were mutation-verified AGAINST the
   grant seam and one is named *"the flip is INERT AT DEFAULT"*. Enumerate the
   pins that go RED **and, separately, the pins that go VACUOUS** — the second
   class is the dangerous one — before touching the parameter.
3. **The accepted PRESERVE residual goes live.** Macro pattern variables
   (`pattern-var?` needs no sigil) were ruled an acceptable residual on the
   grounds of zero in-tree instances *and* an existing per-command
   `bcast-step-binder` guided error. Under G2 that arm is reachable in
   production for the first time — verify the ERROR CHANNEL, not just the
   message. Four whole-file aborts have shipped in this track by that exact gap.

<a id="p4c-4c-audit"></a>

**⭐ THE MINI-AUDIT — `wf_a24f3e0f-d84`** (7 facets + completeness critic,
HEAD-pinned; 8 agents / 1.66M tokens / 0 errors). It refuted FOUR recorded
facts, one of them written the same hour. **Every load-bearing item below was
re-verified on the main thread**, not adopted from the report.

**⚠⚠ 1. BLOCKING FACT #1 IS DEAD — a bare top-level ω is NOT stripped under
every grant.** Measured on the main thread:

```
default        : ((users :name))
grant '(users) : ((users ($bcast-step :name)))   ← PRESERVES
grant '(def)   : ((users :name))
```

It WAS true at `17086a09`, where the re-scope verified it. **The PRESERVE flip
(`e71ef6b8`) rewrote the `[else]` arm** (`:3210-3212`), and a bare top-level
command's head IS the subject symbol — so granting the subject preserves. The
re-scope generalised from the `'(def)` sub-case, which still strips.
⇒ **Acceptance markers ARE exercisable, and the L1 fusion pin does NOT need
`def` position.** The re-scope was right when written and went stale under the
very flip it was waiting on — *a fact has a timestamp, and this one outlived it
by one commit.*

**⚠⚠ 2. THE PARTITION IS INCOMPLETE — 3+3+1 is not the shape.** Verified:
`expr-PVec` occurs in the ENTIRE select region (700–1200) exactly ONCE, at
`typing-core.rkt:923`. **`select-row-of` has NO PVec arm**, so a PVec subject
falls to the `:758` catch-all `[(not (expr-Record? tm)) … 'subject-other]` —
**the three typing arms have nothing to delegate to.** That is a FOURTH typing
site, which D4 books elsewhere as *"a THIRD dispatcher (subject → elem-type)"*.
Three more the partition never named:
- **`select-below-components`** (`:1149-1152`) reaches site 2 by FALLTHROUGH and
  is the only caller carrying non-empty `seen` from a dissolve splice — so
  changing site 2's return for a bcast head silently changes dissolve splices;
- **the `expr-get-in` / `expr-update-in` family** (reduction `:3579-3581`,
  `:3588-3596`, `:4594-4595`, `:4603-4604`) walks path segments with **ZERO
  step-kind dispatch**. Probed: it returns `expr-error` at **zero errors** — the
  silent-wrong-answer class, not a raise;
- **a THIRD `bcast-step-binder` guard** at `parser.rkt:6382` (`parse-rel-params`)
  that the guard census resting under the residual argument had missed.

**⚠ 3. THE HEADLINE SPELLING REACHES SITE 2, WHOSE PROTOCOL IS DIFFERENT.**
Measured: `users:name` routes to `select-branch-entries` (`:1141`), which returns
a **COMPONENT LIST** (`:984`), not a type — sites 1 and 3 return types. Writing
`(values pvec-type #f)` at `:1141` by analogy with its siblings is the most
likely single way to get this slice wrong.

**⚠⚠ 4. THE PRESERVE RESIDUAL IS SEVEN SHAPES, NOT ONE — AND ONE IS SILENT.**
Measured against a REAL arm-deleted build (not a grant simulation). Leaks:
`[myform x:Int]` (the one the ruling named) · **`defmacro when [$c:Int $b]`** ·
`data Box := mk [x:Int]` · `capability C [x:Int] x` · `def g := [fn m:Int m]` ·
`def x:A:B := 5` · (`deftype` — but see below). Does NOT leak: `defn` · `defn-` ·
`spec` · `def` · `let` · trait methods · match arms · `?x:Nat`.
⭐ **Five are loud. `defmacro when [$c:Int $b] $c` is SILENT** — no diagnostic at
all; the macro registers with `($bcast-step :Int)` INSIDE its pattern.
**Q_U18 accepted the residual explicitly on the grounds that it is "LOUD and
RECOVERABLE" — that argument does not cover this member.** And the design named
the WRONG MECHANISM: it is not `pattern-var?`/unknown-head, it is
`param-group-candidate?` (`:3323-3334`) rejecting any `$`-headed group, and
**`defmacro` is a RECOGNISED head** — so this shape was never in the population
the ruling reasoned about.
✅ **OWNER RULED 2026-08-04: close the `defmacro` leak as part of this slice.**
G2 lands alongside as ruled; the acceptance argument is repaired rather than
re-opened.

**⚠ 5. THE GRANT SEAM CANNOT EXPRESS THE POST-G2 STATE.** `binder-head-base`
answers `#f` for a non-symbol and the parameter guard forbids `#f` in the list,
so **a group-headed node can never be granted** — and a bracketed top-level
command has exactly that shape. Three facets' grant-probes therefore contradicted
each other. ⇒ **Obligation #2 (RED vs VACUOUS pins) CANNOT be discharged through
the seam; it needs a real arm-deletion build.** The P4c-4a chain/totality pins
that read "[same]" under a grant do so as a SEAM ARTIFACT, not as evidence.

**⚠ 6. G2 DOES NOT FULLY DISSOLVE THE CHAIN.** Three deep-strippers survive arm
1's deletion: the `trait` arm (`:3129-3130`), the `$pipe` pattern region
(`:3121-3122`), and `take-param-region`'s implicit/param groups. Any reasoning of
the form *"after G2 nothing strips ancestrally"* is false for those three.

**⚠ 7. SCOPE LEAKAGE IS FORCED, not avoidable by discipline** — named so it can
be pushed back deliberately: `select-row-of`'s missing PVec arm needs a
subject→elem-type dispatcher (a P4d-booked item), and the `rrb-of` guard's ELSE
branch must decide what a NON-PVec container does — and Map (`regions:host`) and
het-tuple (`events:t`) subjects ARRIVE whether or not they are in scope.

**⚠ 8. THE `rrb-of` GUARD MUST REPORT VIA `(return (expr-panic …))`, NEVER
`error`.** With no failure slot the only two exits are the escape (per-command,
file continues) and a raise (whole-file abort). Writing `[else (error …)]`
re-creates exactly the abort P4c-4b removed. Note also `champ-of` and
`index-into` are **NOT twins** (unwrapper vs accessor) and `champ-of`'s message
asserts *"typing admitted the block"* unconditionally, which is FALSE under
`sort='path` — **copy `index-into`'s wording, not `champ-of`'s.**

**✅ CONFIRMED, and it gives the slice an ORACLE rather than a spec to
interpret**: the target semantics already work under the explicit spelling —
`pvec-map [fn [m] m.name] xs` → `@["a" "b"] : [PVec String]`. Mirror arm
`reduction.rkt:3306-3314`. And **the L1 fusion discriminator is the TYPE, not the
value**: naive nesting yields `[PVec [PVec String]]`; fusion must yield
`[PVec String]`, so a pin asserting only the value list does not discriminate.

**STALE COORDINATES CORRECTED** (all re-verified): the sole `let/ec` is
`reduction.rkt:1647`, **not `:1600`** — D4 cited `:1600` TWICE and that line is a
comment · `pvec-from-list` is `parser.rkt:3285-3290`, **not `:2966`** (which is
`surf-get`) · `DEFERRED.md:2986`'s three claims about the parameter are ALL now
false (it is at `:2933`, it IS a `make-parameter`, it IS provided at `:64`).
⚠ **"The four dispatchers"** (used above in the `expr-hset` note) is the number
**this track already refuted once** — D4's own §P4a record says THIRTEEN sites in
FIVE files. The `expr-hset` claim is true; the denominator is not.

**TEST-SURFACE FINDINGS**: `tests/test-parse-reader.rkt` has ~8 assertions that
go RED under G2 with **ZERO code reference to the parameter** — a grep-driven
retirement finds nothing there · the most dangerous VACUOUS case is
`test-path-selection.rkt:3958-3964`, the only standing coverage of
`binder-head-base`'s private-suffix normalization, whose live consumers all
SURVIVE G2 — it must be **re-expressed as a binder-behaviour pin, not deleted** ·
`bcast-e2e`'s subject is a **MAP**, so reusing it for a PVec law pin would pass
for the wrong reason · the battery is at **344 cases / 58 s**, approaching
`testing.md`'s 60 s absolute guidance.

<a id="p4c-4c-close"></a>

##### §5.P4c-4c CLOSE — ✅ COMPLETE 2026-08-05

**Four commits.** `51e260ab` the PVec ω value semantics · `bcdb4083` DEFERRED 43
(the strictness tier follows the unwrap) · `0fd2098c` DEFERRED 50 spun out ·
`ae26f540` **G2 + the preparse seam guard**.

**THE FEATURE ARRIVES**: `xs:name` → `@["a" "b"] : [PVec String]` at the
production default — no grant, no parameter. L1 fusion holds as a THEOREM at
depths 2/3/4 (each ω step consumes one layer and re-wraps one; nothing counts
layers), and the converse holds — `xs:tags` correctly REFUSES to fuse when the
user asked for two layers.

**⭐ THE DEFINING EVENT: the adversarial verify caught a BLOCKING regression that
EVERY gate was blind to.** G2 let `$bcast-step` survive into preparse-CONSUMED
forms (`require`/`ns`/`schema`/`foreign`) whose recognizers raise —
`require [prologos::data::nat:refer [add]]` went from 0 errors to a WHOLE-FILE
ABORT. Fifth instance of `pipeline.md`'s abort class in this track, with the
first four documented one screen away. **Zero corpus sites use a fused directive
keyword**, which is precisely why the suite, all five acceptance files AND the
corpus A/B passed over it; the adjacent population is ~2400 spaced occurrences,
each one deleted space away.

**Owner ruled option B** (guard the seam) over A (enumerate directive heads),
because an enumeration leaves the NEXT sentinel to rediscover the class.

**⚠ B'S REAL COST — the finding worth carrying forward**: converting raises to
VALUES makes previously-inert TEST-HELPER DESIGN load-bearing. 20 assertions
across 9 files changed channel, and two failed for a reason that *could not exist
under a raise*: `functor-for` returns a registry lookup and discards results;
`run-last` returns `(last (run s))` while the refusal lands on the FIRST form.
**Any helper that narrows the result set can now silently swallow a refusal and
go green.** Both fixed; a sweep for other result-discarding helpers is unclaimed,
deliberately not widened into this slice.
⚠ Only the 20 FAILING sites were converted, not all 31 `check-exn` sites in those
files — the other 11 still raise (they fail before the guarded seam), and
converting them would have weakened correct assertions.

**Rulings landed**: [Q_U18](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u18)'s G2 half · **DEFERRED 43** (the tier follows
the unwrap — and its own "not reachable in production" rationale was FALSE, which
the verify proved) · **DEFERRED 48 RULED UNIFORM** (the tier is INFERRED, not
written, so per-tier abort would make identical source behave differently on
something invisible in it).

**Gate**: suite **9847 / 482 / 0** · battery **356** · acceptance 52/52 + 89/89 +
6/6 + 29/29 + 28/28 · corpus A/B **5 of 6 identical incl. the control**; `foray`
(owner WIP, the only file with real mint sites) **29 → 21 errors, no value became
an error**.

**⚠ KNOWN PROPERTY OF B, recorded not hidden**: the guard is head-agnostic, so a
compiler-INTERNAL invariant violation during preparse also degrades to a
per-command error. Still fully reported, never silent — but it merges two
propositions into one channel, which this track deliberately SPLIT at P4c-4b.
Re-splitting needs a distinguished internal-error marker that keeps raising.

**⚠ METHOD, for the PIR**: this slice produced **five false claims in comments**
and **three vacuous pins**, every one from writing what I believed the code did
instead of probing first. Most were caught by the adversarial verify; three I
caught myself, only after distrusting the habit. The same error appeared in a
live diagnosis (naming an Emacs lock file as the memory-runaway cause before
testing it — it was not). ONE finding about method, not eight incidents.

**Spun out**: DEFERRED **50** (defmacro fused annotations — chip
`task_204859b9`; PRE-EXISTING, not a G2 leak) · **51** (parenless `&>` loses the
relation) · **52** (goal arity error → silent empty bag).
**Tooling**: `tools/corpus-ab.rkt` — one subprocess per file with wall + memory
caps, encoding the corrected A/B method.

**Status: ✅ P4c-4c COMPLETE.** Next: the `:{` mint (**alone** — it touches
`bcast-step-trigger?`, the ONE predicate both groupers share, so mixing it makes
the A/B un-attributable), then **P4d**.

<a id="p4c-sequencing"></a>

##### §5.P4c — THE SEQUENCING after the P4c-4c re-scope  (owner-assented 2026-08-02)

**Nothing is dropped. The order changes**, because three reader-layer facts gate
the corpus half. Most of the deferred work was ALREADY scheduled by this
document — reading it rather than re-homing by instinct is what surfaced that,
and it corrected a recommendation of mine (I proposed the Q_U9 List refusal for
P4c-4c; Q_U9's own ruling says **"Implementation: P4d"**, twice).

| Deferred piece | Home | Note |
|---|---|---|
| map-generic over Map/keyword-row (`regions:host`) | **P4d** | already scoped |
| het-tuple per-position EXACT (`events:t`) | **P4d** | the 2b heterogeneity split |
| PVec-of-union + `row-meet` | **P4d** | already scoped |
| **Q_U9 List refusal + guided error** | **P4d** | ⚠ NOT P4c-4c — Q_U9 says so itself |
| `quests:t` / `quests:{t r}` corpus lines | ~~P4d~~ **✅ LIVE at P4d-0** | markers 43/44 (`33d83989` + `77259635`) — the solve→PVec spin-out re-fated them upstream; P4d's list shrinks by one |
| `*` flatten (`:diags*`) | **P4e** | P4c-4b's guided refusal is the correct interim |
| `.*` row-splat · disclose `<`/`:<` | **P4e** | already scoped |
| **the `:{…}` reader mint** | **[P4d-0](CIU_6_P4d.md#p4d-0)** ✅ `77259635` | + 46 (Q_U20) + 55; both extent members in the corpus; **P4d unblocked** |
| **unknown-head policy + first production grant** | **[Q_U18](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u18) ✅ RULED** | PRESERVE + **G4** (test-only until P4c-4c). ~~Owed with it: the digit-hole fix~~ — **not a defect**, both spellings already refused. **G2 ✅ RULED 2026-08-04: ALONGSIDE P4c-4c**, not after |
| **`^`-on-broadcast** | **[Q_U19](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u19) ✅ RULED 2026-08-07** | **(A) the path-position refusal is RATIFIED** — no key to re-key on a bare ω output; block-position `^` already re-keys and STAYS. ONE guided message unifies the three routes, at P4d's diagnostics slice |

~~**THE CRITICAL PATH** (revised after Q_U18's ruling): the **PRESERVE flip + the
digit-hole fix** (inert at default, testable through the P4c-4a grant seam, so
safe to land early) → **P4c-4c** (PVec value semantics) → **the G4 grant fires**
at/after P4c-4c, and **G2 is re-evaluated there** → the `:{` mint → **P4d**~~

**THE CRITICAL PATH — REVISED 2026-08-04 after the G2 ruling.** The PRESERVE
flip ✅ landed (`e71ef6b8`); the digit-hole fix is **struck** (it was never a
defect). What remains:

~~**P4c-4c + G2 as ONE slice**~~ ✅ **LANDED 2026-08-05** (`ae26f540`) — value
semantics + unconditional preservation + the preparse seam guard; G4 discharged
BY the slice. See [§5.P4c-4c CLOSE](#p4c-4c-close). Remaining:
the `:{` mint (**alone** — it touches
`bcast-step-trigger?`, the one predicate both groupers share, so mixing it makes
the A/B un-attributable) → **P4d** (carriers + the Q_U9 List refusal + the corpus
re-fate, with [Q_U19](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u19) ruled) → **P4e** (`*` flatten · `.*` row-splat ·
disclose) → **P4c-5** → **PF** (Q_U17's `Step`/`Cont` ADTs + the `path-segments`
repair) → **P5**.

⚠ The merge of P4c-4c and G2 does NOT re-home anything else. Everything in the
table above keeps its stated home; the one change is that the G4 discharge and
the G2 retirement now happen INSIDE P4c-4c instead of bracketing it.

✅ **Q_U18 IS RULED** — and the "Validated ≠ Deployed" gap it named is now
**SCHEDULED rather than open-ended**: G4 makes P4c-4c its discharge point. ⚠ The
half of P4c-3's reasoning that said "cannot decide it in either direction" was
**refuted** — see Q_U18's correction block; the PRESERVE counter-example does
not exist, because `?x:Nat` is one glued token.

