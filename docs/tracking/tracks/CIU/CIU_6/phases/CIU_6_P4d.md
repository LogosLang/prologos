# CIU 6 — D4, §5.P4d-0 + §5.P4d (+ §5.P4d-s7)

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 8633–9430 are lines N-8626 here; D4 lines 12937–13081 are lines N-12129 here.

---

<a id="p4d-0"></a>

### §5.P4d-0 — the `:{…}` mint + the sub-inner lift  (DEFERRED 42 + 46; opened 2026-08-05)

**The P4d prerequisite, landed ALONE** per the sequencing — it touches
`bcast-step-trigger?`, the one predicate both groupers share. Mini-audit
`wf_e15a1ef6-dfb` (4 facets + critic, ~1.1M tokens); every load-bearing claim
below re-verified on the main thread.

**⭐ WHAT THE AUDIT CORRECTED BEFORE IT COULD MISLEAD** (now folded into
DEFERRED at `2692a958`): the "minimal" memq widening produces a DEGENERATE datum
(`($bcast-step :)` + a separate brace) — the real mint WRAPS:
`($bcast-step ($select-brace …))`, keyed on the colon glued to the FOLLOWING
opener (base-adjacency alone breaks `def b: [List Nat]`, which works today) ·
46 was MISLOCATED (the arms exist; the LIFTS put `@sub` at branch-head) ·
40 = 46, filed twice with conflicting fixes; adjudicated · 39's five-site
exoneration was stale three days after it was written · ⚠ the parser's
`$bcast-step` fold arm has an unguarded `(symbol->string (cadr it))` that is a
WHOLE-FILE ABORT at HEAD (3 reproducers) and sits directly on the mint's path.

**Rulings**: [Q_U20](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u20) (sub-inner assembles at 'block, always) · the
parser guard is SITE-LOCAL; the class-level parse-path guard is its own slice
(DEFERRED 53) [owner, 2026-08-05].

**Slices**:
1. ⬜ uncomment the EIGHT corpus lines that already work at HEAD (own commit —
   never bundled, or the A/B is un-attributable; ⚠ marker renumbering).
2. ✅ `0c0ef6dc` the SITE-LOCAL parser guard — the three HEAD aborts are
   per-command now; pin failed as the abort itself (an ERROR escaping the test
   body), green after. Battery 356 → 357.
3. ✅ `667684ad` the WRAPPING mint — ONE shared trigger, both groupers, the tree
   twin fuses ('bcast-brace-group), the Q_N3 v2 guard gains its first colon row.
4. ✅ `667684ad` the LIFT DISCRIMINATION (Q_U20) — and the verify found TWO
   BLOCKING defects invisible to every gate (no test or corpus spells `^:{` or a
   binder `:{`): top-keys SPLICING a sub inner's keys (three grades, worst a
   symbol<? whole-file abort) and `unwrap-bcast-step` unwrapping ANY pair (a
   binder `:{` silently DEFINED a garbled Pi at 0 errors). Both fixed + pinned;
   spin-offs DEFERRED 54–55. **Both §3.2.1 extent members work end to end.**
5. ✅ `77259635` — EIGHT more corpus lines live incl. **both extent members**
   (acceptance 61/61 → **69/69**); the spurious-dot display fixed; the
   vector-element refusal names the broadcast alternative (DEFERRED 55 ✅).
   The L4/top-keys coherence landed earlier IN slice 4 as the B1 fix.

**A/B**: `tools/corpus-ab.rkt` as-is · Tier 1 = `foray.prologos` (the ONLY
minting file; owner WIP ⇒ working-tree inputs) · Tier 2 must-NOT-move =
`benchmarks/comparative/dependent-types.prologos` (the corpus's only spaced
colon-then-lbrace, a live data constructor) · control = a zero-colon zero-brace
file · file list by `find`, not `git ls-files` (a deleted-in-worktree file
would silently drop from both legs).

**Status: ✅ P4d-0 COMPLETE 2026-08-05** — `33d83989` · `0c0ef6dc` · `667684ad`
· `77259635`. DEFERRED 42 ✅ · 46 ✅ · 55 ✅; spin-offs 53 (parse-path guard
slice), 54 (goal-position row, → the 51/52 chip). Close-note in lieu of PIR
(sub-slice; the track PIR owns the full retro): the phase's finding is that
**both blocking defects were invisible to every gate** — no test or corpus
spelled `^:{` or a binder `:{` — and both were exactly the two static-drift
hazards the mini-audit had measured BEFORE implementation (top-keys vs
output-name; the any-pair unwrap). The audit → verify pipeline did its job
twice over. **P4d is UNBLOCKED.**

<a id="p4d"></a>

### §5.P4d — the CARRIERS  (opened 2026-08-07)

**Mini-audit** `wf_4bc76d94-a2d` (6 facets + completeness critic, ~1.34M tokens
@ `ea9c19e4`); every load-bearing claim below re-verified on the main thread.
**[Q_U19](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u19) RULED (A) at the opening** — the path-position refusal is
ratified; one guided message unifies the three routes (rides the diagnostics
slice).

**⭐ WHAT THE AUDIT CORRECTED before it could mislead:**

- **The scope statement conflated TWO carriers.** `regions`/`strings` are
  KEYWORD-ROWS (`expr-Record`, key-domain 'keyword), NOT `expr-Map` — separate
  type constructors, separate `select-row-of` arms. TWO typing arms; ONE shared
  reduction arm (both run on `expr-champ` — probed: `map-keys` serves both).
- **The het tuple is TYPING-ONLY.** Its runtime carrier is `expr-rrb` — the
  SAME as PVec — so `rrb-of`/`bcast-lift` already handle it; adding a reduction
  twin would be belt-and-suspenders. Map/keyword-row is the only carrier
  needing new reduction work. The single typing seat is `select-elem-of`
  (typing-core), whose carrier axis is a binary `if` its own comment already
  books for this dispatch; `rrb-of` (reduction) is currently UNREACHABLE
  through typing and goes LIVE the moment the typing gate widens — the two
  sides land ATOMICALLY (the P4c-4c discipline, recorded at the site).
- **The ω path already reaches the Q_U10 Map posture for Map-as-ELEMENT**
  (`ms : [PVec [Map Keyword Int]]` · `ms:a` → `@[1 3]` at 0 errors); only the
  CARRIER slot is gated. P4d is narrower than "add Map support to broadcast".
- **`quests:t` / `quests:{t r}` are OUT of the re-fate list** — live since
  P4d-0 (markers 43/44). Five stale D4 sites said otherwise; corrected this
  commit (see [Q_U9](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u9)'s correction block).
- **Q_U9's Functor door was FALSE WHEN WRITTEN** — `Functor List` live since
  2026-03-01. The refusal stands on its other grounds; the guided error drops
  the "no instance" clause. Full correction at [Q_U9](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u9).
- **The `bcast-carrier` message split is REQUIRED BY P4d, not optional within
  it**: one arm currently serves EVERY non-PVec subject and tells each — Set
  and List included — that "the map, keyword-row and heterogeneous-tuple
  carriers land at CIU T6 D4.P4d". That sentence goes false-and-unexplained
  for the out-of-scope carriers the moment the in-scope ones land.

**⭐⭐ NEW, in the blast radius — a LIVE type-soundness hole** (found by the
completeness critic; re-verified on the main thread): a het literal with a Map
element NEVER FORMS A TUPLE. `unify.rkt`'s deliberately-symmetric Record↔Map
COERCION arm (`:588-589` at `ea9c19e4` — its own comment says "fires in EITHER
argument ordering") is consumed by typing-core's pvec-literal-homogeneity probe
as an EQUALITY, so the FIRST element's type wins:
`def r1 := {:a 2 :b 3}` · `def m1 : [Map Keyword Int] := {:a 1}` ·
`@[r1 m1]` → `[PVec {:a Int :b Int}]` (a closed type `m1` does not satisfy) →
`mixed:b` → **`<error> : [PVec Int]` at 0 errors**; the reversed order is
benign (`[PVec [Map Keyword Int]]`). Order-dependence is what pins it on the
unify arm rather than a subtyping rule. Three P4d touchpoints: (a) het fixtures
with a Map element silently test the WRONG carrier; (b) it is the
buried-error-in-an-output-slot class DEFERRED 48 exists to prevent, via a route
48 does not cover; (c) the Map carrier work makes it MORE reachable.
**Disposition: co-design (fix-first as slice 0, vs DEFERRED + fence the
fixtures).**

**Carried into this phase**: the **C9 scalar-tier question** — a het tuple has
N position types; the tier is ONE scalar per `expr-select`; `select-tier-subject`
peels `expr-PVec?` only. D4's own P4 audit list said "rule it in P4c-4" and
P4c-4 closed without ruling it; DEFERRED 48 rules the ABORT uniform, not the
tier. Due at the het slice's mini-design. · DEFERRED **40-residual/45**
(`select-step-name` totality + the top-keys label twin — value-channel only,
never a raise) · DEFERRED **47** (the empty-PVec wording — a diagnostics-slice
rider) · the CALM restatement for `row-meet` (the "annotation-only at HEAD"
premise is FALSE — a PVec-of-union is INFERABLE via `nil-safe-get`'s Nil
append; the argument moves to the `has-unsolved-meta?`→⊥ ground).

**SLICING — ruled at the opening co-design [owner, 2026-08-07 — "(a) fix it
first as slice 0"]:**

- **✅ Slice 0 — the homogeneity-probe soundness fix — COMPLETE `00e52c42`
  (2026-08-07).** Landed WIDER than scoped, and the widening was the
  adversarial verify's doing (`wf_9d8f105c`, 3 skeptics):
  **(i)** the pvec-literal probe takes the `unify-ok ∧ conv` conjunct
  (failing-test-first — 3 RED pins reproduced the mistype, the
  order-dependence, and the buried `<error>`);
  **(ii)** ⭐ **the verify REFUTED the first cut with a BLOCKING reproducer**:
  `conv` was spelling-sensitive on UNIONS while the engine's own equality is
  SET-LIKE (`unify-union-components` sorts + dedups), so
  `@[[the <Int|String> 1] [the <String|Int> "x"]]` reclassified het —
  `conv-nf` gained a **union arm** (mutual containment over `flatten-union`;
  union-vs-non-union stays #f, matching unify's own deferred flavor-B case,
  so the two equalities agree in BOTH directions);
  **(iii)** ⭐ **the class had THREE members in ONE function, not one** — the
  list-literal probe (`'[{:b 2} m]` → `List {:b Int}` with a Map value
  inside, the unsound direction) and the map-literal KEYS probe (computed
  keys `{[expr] val}` make key types source-reachable; first-key-wins gave
  one value set two types) carried the identical defect. Same conjunct at
  both; the map-keys arm also gained the rollback wrapper its siblings
  already had. Skeptic 1 VERIFIED the rollback contract empirically (a
  mid-probe solve does NOT leak into the het row) and skeptic 3
  mutation-tested every pin against the pre-fix base worktree.
  **Gates**: battery **375/375** (+10) · neighborhood 344/344 (14 files incl.
  union/session/equality-audit — `conv-nf` is shared) · acceptance **69/69**
  by output diff · corpus A/B 13 files + control = **ZERO semantic diffs**
  (both artifacts explained: a tree-path string in an identical pre-existing
  error; a pre-existing `solve-mult-meta!` raise identical on both legs) ·
  perf A/B interleaved, no regression · **full suite 9916/485/0**.
  **Filed, not fixed** (all pre-existing, verify findings): logic-var
  elements infer `expr-hole` which WILDCARDS the probe (reachable via `defr`
  bodies — a mixed literal with a logic var collapses `[PVec _]`) ·
  `'postponed` counts as unify-ok (optimistic-collapse class, no source
  reproducer found) · the legacy no-net-box rollback path does not restore
  (unreachable in production) · `unify`'s refl arm runs `unify` where its
  own comment says `conv` (unreachable today — upstream infer fails first).
- **✅ Slice 1 — keyword-row + Map carrier — COMPLETE `14ef5e83`
  (2026-08-07).** `regions:host` → `{:ap "ap.…", :eu …, :us …} :
  {:ap String :eu String :us String}` at the production default; the genuine
  Map re-wraps uniform (`[Map K proj(V)]`). Mini-audit `wf_1ff4945e-810`
  (4 facets + critic; found the peel as a THIRD hardcoded-PVec site and the
  Map-carrier tier already solving assertive on a refusing node); adversarial
  verify `wf_89d6c7b7` (3 skeptics — ONE BLOCKING pin defect caught: the
  genuine-Map pin was VACUOUS, its regex matching the def echo's inner type).
  **Records the citations the slice's code comments carry:**
  · **Lean 1 DISSOLVED at implementation** — the co-design's
    "ordinal-over-nominal refuses" rested on ordinals indexing CARRIER keys;
    `bcast-apply` shows the inner step applies to VALUES only, so there is
    nothing to refuse: `users:0` is per-value ordinal projection, uniform
    with the live `m:0` over PVec, failing naturally with the guided ordinal
    message when values do not index. Pinned as the uniform semantics.
  · **The §10.6 carve-out** — `strings:home` was the ONE map-generic-tagged
    line inside a block D4 §5.P0 declared PERMANENTLY commented; carved out
    at this slice (the pivots stay v2-commented). The corpus note points here.
  · **Row-type ANNOTATIONS do not parse** (`def x : {:a Int}` →
    not-a-type-error) — a pre-existing surface gap, discovered scoping the
    genuine-Map pins. ⚠ Row-valued Maps are nonetheless CONSTRUCTIBLE by
    INFERENCE (`[map-map-vals [fn [s] {:host s}] mm]` → `[Map Keyword
    {:host String}]` — the verify refuted the first-cut "unconstructible"
    claim before it landed anywhere); the sub-inner over a row-valued Map
    SUCCEEDS (pinned), while a Map-VALUED value takes the standing Q_U10
    block-over-Map refusal (pinned).
  · **The mini-C9 scalar-tier consequence, measured**: a dyn-row FIELD's
    runtime miss is LOUD when a sibling field is a Map and QUIET when not —
    the ONE scalar tier couples siblings. Ruled-direction only
    (permissive→assertive), accepted eyes-open; the het slice's C9 ruling
    should subsume it.
  · The `bcast-carrier` message now names the truthful set ("PVec, Map, or
    **closed** keyword-row" — the verify caught it refusing a DYN keyword-row
    while naming "keyword-row" bare); dyn-tail's seal/validate-shaped remedy
    and the per-carrier split stay slice 4.
  **Gates**: battery **385/385** (+10 new, 8 re-pointed — all six family-A
  re-points verified to discriminate BOTH the revert and the atomicity
  break) · acceptance **71/71** (+2, markers regenerated via `--check`) +
  89/89 + 6/6 + 29/29 + 28/28 · corpus A/B vs `044a77d7` (19 files):
  EXACTLY the predicted diff set — the two corpus lines + foray's
  `regions:host`, each error→meaning (13→12) · **full suite 9928/485/0**.
- **✅ Slice 2 — het tuple — COMPLETE `ba1c055d` (2026-08-07).**
  `events:t` → `@[:click :key :click] : ⟨Keyword Keyword Keyword⟩` —
  per-position EXACT, output = the honest nat-row (P3c 2a; the Tuple→PVec α
  keeps PVec expectations satisfied). Mini-audit `wf_80ee26f2-7dd` · verify
  `wf_c92f4edd`. **Rulings landed [owner]**: **C9 = (a)** the conservative OR
  over positions (the ONE scalar tier; sibling-coupling accepted, scope is
  'path-only — the block arm is `(void)`) · output shape = nat-row · misses
  NAME the position/field · riders fixed value-channel · `events:x`
  battery-pinned (would be the corpus's first ERROR result; no convention).
  **The audit's refutation**: "one gate, zero new code" was FALSE — the tier
  peel was a SECOND independently-'keyword-gated site; both widened
  (`memq '(keyword nat)`), and the re-expressed s0c pin discriminates the
  half-shipped variant. **The `'bcast-at` wrapping fail**: label-aware walk
  (`record-map-field-types/labeled`, the adjacent sibling of the ONE
  reconstruction helper) + a recursive formatter arm — nested wraps compose
  ("fails at field :r1 — fails at position 1 — …"), and the slice-1 keyword
  twin (carrier fields unnamed) closed in the same stroke.
  `format-closed-row-miss` labels TOTALIZED (integer labels raised —
  unconstructible today, guarded by walker-totality).
  **DEFERRED 45 fixed structurally**: `select-branch-top-keys`' bcast arm
  answers `(list (select-step-output-name s))` — check ≡ meaning by shared
  computation; B1's sub special-case DISSOLVED; the verify's full
  OLD-vs-NEW-vs-consumers table found ZERO divergent shapes and a SECOND
  silently-repaired grade (dissolve inners `k^:w^:r` — now advertised +
  pinned). **DEFERRED 40**: the two path-append sites pair-guarded (the
  verify caught my first pin fixture VACUOUS — single-step, never reached
  the sites; re-pointed at the block-sort mid-branch shape); the ordinal leg
  recorded UNCONSTRUCTIBLE (`(@bcast (@ord N))` has no producer — the mint
  emits bare numbers, legitimate labels).
  **Carried out of the slice, recorded**: the Q_U20 block cell CONCRETE —
  in block position `hx{evs:t}` ≡ `hx{evs:{t}}` (a symbol inner threads the
  outer 'block and degenerates into its sub twin; the extract/assemble
  distinction Q_U20 ruled for 'path COLLAPSES) — material for the ruling ·
  the `@[]`-broadcast refusal misattributes "the subject" (a meta elem) ·
  `not-indexable`'s `x{k}` remedy is off-key inside a broadcast (both
  slice-4 fodder) · the peel's early stop IF two `@bcast` steps ever share
  ONE branch (unmintable today — flag, not defect).
  **Gates**: battery **395/395** (+11, 4 re-expressed; the verify's
  pin-vs-revert matrix shows every production half-revert caught) ·
  acceptance **73/73** ×2 (+2: `events:t` · `tree.entries:name` — the audit
  REFUTED its "PVec-of-rows" reading, `:entries` IS a het tuple, settling
  the three-way §10.8 contradiction; the recursive line stays W4-DEFERRED)
  + 89/89 + 6/6 + 29/29 + 28/28 · corpus A/B vs `5ef1cfac`: EXACTLY the two
  flips · **full suite 9940/485/0**.
- **✅ Slice 3 — PVec-of-union (keys-⋂ / types-⋃) — COMPLETE `1e8d0795`
  (2026-08-07).** Audit `wf_2759e5b0-220` · verify `wf_f24e650c`.
  **⭐ THE AUDIT RE-SCOPED THE SLICE**: the types-⋃ half **already shipped**
  (`build-union-type`), so `row-meet` was never wholly new; and keys-⋂ is a
  structural **NO-OP for Map components** (an open `[Map K V]` statically
  offers every keyword). The slice is therefore TWO halves over **disjoint**
  populations — the **GATE** for row components, the **TIER** for Map-bearing
  unions. It also found **TWO populations with opposite moral status**: a
  genuine non-offerer is a silent wrong answer the flip FIXES; a `Nil`
  remainder is a **correct answer** a naive flip would BREAK — which is the
  question ruling (a) settles.
  **⭐ Q_U21 RULED (a) [owner, 2026-08-07] — `Nil` IS SKIPPED.** `<T | Nil>`
  is the OPTION type; Nil is the absence marker, not a carrier alternative
  that happens to offer no keys. Preserves the `nil-safe-get` idiom;
  a genuine non-offerer (`Int`, a row lacking the key) still refuses.
  **Placement**: the gate lives in `select-bcast-inner-apply` (the per-element
  applier) so it covers exactly the population the tier witness does — union
  ELEMENT, union-typed row FIELD, union-typed tuple POSITION — and its mutual
  recursion with `select-union-lift` handles a component that only *whnfs
  into* a union (a type alias; the structural `flatten-union` cannot see
  through one). It deliberately does NOT reuse `select-project-field`'s union
  arm: that is the single-get OPTIMISTIC polarity, its own comment forbids
  broadcast reuse, and no polarity parameter is threaded down the
  five-signature walk.
  **⚠⚠ THE ACCEPTED CONSEQUENCE, NAMED — an OWNER QUESTION carried to the
  close**: because gate and tier must agree on what a component IS, a
  **Nil-bearing union stays PERMISSIVE**, so a genuine Map miss *inside* one
  is QUIET. That is (a)'s price at the VALUE layer, which the ruling (about
  the TYPE layer) did not reach. Recorded in the code at `tier-union-witness`.
  **The verify found FOUR defects, three of them mine**: (i) BLOCKING — my
  Nil pin was VACUOUS (one-element never-nil fixture) and a genuinely-absent
  element PANICKED, because the gate skipped Nil and the tier did not;
  (ii) BLOCKING — the witness fired on carriers the gate did not cover;
  (iii) HIGH — the bail DISCARDED the inner fail, so every per-component
  failure read as a key miss (false for ordinal inners and block-sort
  projections, and strictly worse than pre-slice in 6 spellings) — it now
  NESTS the inner reason on slice 2's `bcast-at` pattern; (iv) a regression I
  caught in my own RED/GREEN cycle — the witness applied on the NON-broadcast
  path, flipping single-get over a union from the ruled permissive `none` to
  a panic (a `peeled?` flag confines it; the verify proved the confinement
  complete by mutant). ⚠ Plus a **1-directive format string with 2 args**,
  which RAISED and was swallowed by `select-block-hint`'s blanket handler —
  the same class this arc has recorded before.
  **The fixture**: §10.7's "needs an ANNOTATION to build" was WRONG and
  unbuildable — a closed row is not writable in TYPE position. A
  **dynamic-bound `pvec-slice`** widens a het tuple to a PVec of the union of
  its position types (verified not an accident of the bound). The all-offer
  line is live; the refusing line stays commented (first-ERROR-result rule,
  as `events:x`) and is battery-pinned. ⚠ The fixture def initially SHADOWED
  an existing `mixed` in the file — caught by `--check`, renamed `widened`.
  **Gates**: battery **403/403** (+9, 1 re-fixtured, 1 re-expressed) ·
  neighborhood 291/291 · acceptance **77/77** (+4) + 89/89 + 6/6 + 29/29 +
  28/28 · corpus A/B vs `65cb5bce`: only the two known pre-existing artifacts
  · **full suite 9952/485/0**.
- **✅ Slice 4a — the advice stops lying, and starts FUSING — COMPLETE
  2026-08-07. ⚠⚠ ITS MACHINERY WAS RETIRED AT 4c — read this record as
  HISTORY, not as a description of HEAD.** (`61d64708` typing side · `d3947594` parser side; owner ruled
  fix-first, TWO commits). Opened because the slice-4 grounding found a LIVE
  defect inside slice 4's own target; audit `wf_37d324fe-045`, verifies
  `wf_a11a4ef7-900` + `wf_b73e7d14-3cc`.
  **The defect**: the `bcast-carrier` advice (`; otherwise spell it
  `[pvec-map [fn [m] m.NAME] xs]``) was gated on `(and label (symbol? label))`,
  and the LABEL cannot answer the question. FIVE populations walked through,
  each measured before implementation: a SUB inner (`m.{…}`, a parse error) · a
  GLUED ARROW (`m.a->b`, strands the `>`) · a CARET inner (`m.name` — writable,
  and WRONG: drops the rename) · a CHAIN (`m.a` for `:a:b` — writable, and
  wrong) · a NON-ASCII DIGIT key, whose advice was a **whole-file abort**
  (`pipeline.md` severity-1, unclaimed, closed as a side effect).
  ⚠ The old guard's own comment (\"`m.0` is not a thing a user can write\") was
  FALSE — `[pvec-map [fn [m] m.0] xs]` → `@[1 3] : [PVec Int]`; it suppressed
  correct advice while admitting broken advice.
  **The fix**: the step KIND decides, so the decision moved to where the step
  is. `select-fail` gains an `advice` field (all 21 constructors pass it
  explicitly — no defaulting wrapper, since the defect IS advice nobody decided
  to emit); `dot-writable-field-name?` lands in `parse-reader` beside the
  charset it delegates to (the F1b.7g drift class), deliberately conservative
  and pinned on its own contract.
  **⭐ The chain case made the advice COMPOSITIONAL, and that is the phase's
  idea.** `xs:a:b` is not one branch with two steps — Q_U13's NEST encoding
  gives every level its own `expr-select`, so the refusing node is the
  INNERMOST and `:b` lives in its PARENT; a step-local vouch structurally
  cannot see it. But `select-block-hint` descends outermost-first, so it HAS
  the chain and was discarding it. Carrying it down yields the FUSED spelling
  — the functor law, `fmap g ∘ fmap f = fmap (g ∘ f)`, the same identity
  [Q_U7](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u7) pins as the L1-fusion theorem. `xs:a:b` → `m.a.b`, depth 3 →
  `m.a.b.c`, **pinned as an EQUIVALENCE rather than as message text**.
  **⚠⚠ THE VERIFY CAUGHT TWO BLOCKING DEFECTS, BOTH MINE, BOTH NEW, BOTH
  INVISIBLE TO EVERY GATE** (battery, five acceptance files and the full suite
  were green over both): **(i)** the restructured walker searched each subject
  TWICE — explicitly, then again via the generic `expr-subfields` fallback
  where `subject` is field 1 — making it **O(2^depth)**: 5.3s / 14.9s / 46.3s
  at depths 14/18/20 against a flat ~4.3s base, on PLAIN DOT chains with no
  broadcast in them, since the hint runs on every infer failure. Output
  byte-identical: pure waste, and provably dead (the chain reaches only the
  advice STRING, never the walker's truthiness). **(ii)** fusion applied in
  BLOCK sort, where ω **assembles** rather than projects — `RP{items:aa}` ≡
  `[pvec-map [fn [m] m{aa}] P]` while `m.aa` differs, and at two steps the
  user's own expression is a hard ERROR while the advised path SUCCEEDS, so the
  message's two remedies contradicted. **My own new pin FROZE it**; it is
  inverted now. Block sort advises nothing: the \"needs a different delimiter\"
  rule the slice already applied to subs and carets, finally applied to the
  SORT axis.
  **The parser half** (`d3947594`): the sibling guard in
  `retired-selection-error`'s `bcast-step-binder` arm was **DEAD CODE** —
  `(pair? f)` where `f` is `(base-name detail)`, which returns a string on
  every branch — so a binder `:{` printed SYNTAX OBJECTS carrying absolute
  filesystem paths into the message, twice, the second time inside the advice.
  Its covering test accepted an alternative and pinned no content, which is why
  a green suite never saw it.
  **Gates**: battery **403 → 415** · acceptance **77/77** + four more, 0
  mismatched markers · full suite **9964 / 485 / 0**, `[485/485]` verified.
  **Filed**: DEFERRED **60** and **61** — ⚠ BOTH DISSOLVED/REWRITTEN at 4c,
  because their subject (the advice machinery) no longer exists.
  **⚠⚠ SUPERSESSION, 2026-08-08 (`a31b7475`)**: every mechanism this record
  describes is GONE — the `advice` field (struct back to 4 fields),
  `bcast-advice-chain`, `extend-advice-chain`, the `chain`/`rest` params, and
  `dot-writable-field-name?` + its export and contract pin. The fusion idea
  survives only as the RE-POINTED L1-fusion equivalence pin. 4c's remedy points
  back at the user's own spelling instead of teaching one, which left all of
  this without a consumer. The two BLOCKING defects and the whole-file-abort
  population remain accurate as history and are why the arc is worth reading.
- **✅ Slice 4b — the schema CARRIER gap — COMPLETE 2026-08-08** (`19ce05aa`;
  owner ruled it INTO slice 4 rather than papering over it with a message).
  Opened by the slice-4 mini-audit (`wf_3e586347-b98`), which found that
  `select-row-of` resolves a schema fvar to its closed row — so `p{name}` and
  `p.name` work — while `select-bcast-lift` tested `expr-Record?` on the RAW
  type and told the same value it "needs a … closed keyword-row subject". A
  message could only have papered over that.
  **⚠ The obvious framing was wrong, and measuring caught it before design**:
  this does NOT make `p:name` succeed on a FLAT schema. `:` projects from each
  field VALUE, so `{:name String}` + `:name` fails on a plain row too. What it
  buys is that a schema SUCCEEDS wherever its row succeeds (`rg:host` over a
  row of records → `{:eu "e", :us "u"} : {:eu String :us String}`, identical to
  the plain row) and FAILS the same way where its row fails (byte-identical).
  **⚠⚠ THE VERIFY REJECTED TWO SUCCESSIVE CUTS — three BLOCKING defects, all
  mine, all green on battery + five acceptance files + the full suite:**
  **(1) a CAPABILITY BYPASS** — `select-row-of` tests SELECTION first then
  schema and calls the order load-bearing (both registries accept one name); my
  first cut copied only the schema arm, so with a `schema P` + `selection P
  from P` collision `u.age`/`u{name}` were refused by the view while `u:h`
  returned the restricted field's contents at ZERO errors · **(2) a WIDTH LIE
  (extras)** — `schema` is OPEN by default and `schema->row` mints `'closed`;
  broadcast is the FIRST consumer that ENUMERATES the row, so a 3-key `Region`
  (the slice's own flagship example) gave `{:ap "a", :eu "e", :us "u"} :
  {:eu String :us String}`, and an extra key that cannot offer the field
  produced a silent `<error>` propagating into a `def` · **(3) a WIDTH LIE
  (absence)**, found by the RE-verify after 1 and 2 closed — every field is
  minted `'present` while the fill "happens at the seal boundary", and a
  `spec f -> S` RETURN has no fill, so a `:default`-ed field can be `'present`
  and ABSENT: `c:h` → `{:a "q"} : {:a String :b String}`, `broad.b` → a silent
  `<error>`.
  Plus a fourth I caught myself first: the lift resolved and
  `select-tier-subject` did not, so a Map miss inside a schema-typed row went
  QUIET where its row PANICS — slice 1's "one gate was two", one carrier over.
  **The shape**: ONE `bcast-resolve-subject`, called from BOTH sites, admitting
  only a non-selection, `:closed`, default-free schema. Each conjunct is a
  measured defect, named at the site; all three refusals are monotone.
  **Gates**: battery **415 → 421** · acceptance 0 mismatched across all five ·
  full suite **9970 / 485 / 0**, `[485/485]`.
  **Filed**: DEFERRED **62** (the precise presence gate — a broadcast-specific
  `schema->row` restores both refused populations) · **63** (inline nested
  schemas are always OPEN, so this lands only for top-level NAMED closed
  schemas, and the refusal leaks a generated `Region__us`) · **64** (both new
  gates are SILENT — "add `:closed`" is never said, and a collided selection
  gets a message `select-row-of` itself calls a lie; slice-4c work) · **65**
  (pre-existing: `lookup-schema-by-name` matches the SHORT name, so a `data`
  type can resolve to a same-named schema).
- **✅ Slice 4c — the per-carrier split, and 4a's advice machinery RETIRED —
  COMPLETE 2026-08-08** (`a31b7475`). Audit `wf_3e586347-b98` · verify
  `wf_d4e1de98-ff5`.
  **The finding that reshaped it**: the advice slice 4a vouched fires ONLY on
  subjects that already failed, and `pvec-map` needs a PVec — which never
  reaches this arm. The spelling could not work on its own audience.
  **⭐ The owner's call was not to fix the spelling but to stop teaching one**:
  converting fixes the CARRIER, and the user's own spelling then works
  (`[pvec-from-list L]` then `:name`, `:a:b`, `:{a b}` — all verified). Each arm
  names its own conversion and stops: List `pvec-from-list` · LSeq `into-vec` ·
  Set `[pvec-from-list [set-to-list xs]]` + the unordered caveat · open/dyn row
  `[validate Schema subj]` · unadmitted schema ('open / 'defaulted, each
  explained) · collided selection named as a VIEW · scalars and functions get
  nothing, because there is nothing true to say.
  **And that retired 4a's machinery** — no consumer left, and unused-but-correct
  is the dual-path shape the rules forbid. Deleted: the `advice` field (struct
  back to 4 fields), `bcast-advice-chain`, `extend-advice-chain`, the `chain`
  param, the `rest` param, `dot-writable-field-name?`. `select-block-hint`
  reverts to the pre-4a single-descent shape; the O(2^depth) walk did NOT return
  (depths 14/18/20 → 4.25/4.27/4.27s, flat). Nine advice pins deleted, TWO
  re-pointed because they incidentally pinned real semantics (block-ASSEMBLES-
  vs-path-PROJECTS; L1 fusion, which Q_U7 records and nothing else pins).
  **⚠⚠ The verify caught FOUR more false promises, all mine, all in the NEW
  text** — the same class the slice exists to remove, committed inside the fix
  for it: `bare-name` matched a user's own `data List` and offered it
  `pvec-from-list` (measured: "Could not infer type") · "and the same spelling
  works" is false whenever the STEP does not fit the converted elements (an
  ordinal inner; non-row elements) · the dyn arm's inherited `the Schema subj`
  is REFUSED for its whole audience, and **my pin asserted only the substring
  under a title claiming a verification never performed — its own fixture
  falsified it** · "mark it `:closed` and the broadcast works" was unconditional
  and false when reached from the dyn arm. Plus LSeq, the last convertible
  carrier, had no arm. All corrected; the dyn and LSeq pins now EXECUTE their
  remedies.
  **Gates**: battery **421 → 420** (a net −1: nine advice pins retired, eight
  carrier pins added) · acceptance 0 mismatched × 5 · full suite
  **9969 / 485 / 0**, `[485/485]`.
- **🔄 Slice 4d — the remaining diagnostics. Sub-slice 4d-1 ✅ COMPLETE
  2026-08-08 (Q_U19 route 1).** Audit `wf_a154667e-42f` · verify
  `wf_f178a813-a4c` (3 skeptics + adjudicator).
  **SHIPPED**: the ω audience gets its own `bcast-rekey-message`; the dot string
  at `parser.rkt`'s caret arm is BYTE-IDENTICAL; the arm dispatches on the step
  carrying the caret via `select-step-kind` (already imported, already answers
  `'bcast`). The `parse-error` is a per-command VALUE, never a raise. The
  "P4c-4b: the payload's THREE sub-cases" pin is RE-POINTED to the DECISION —
  it asserted `re-keys the OUTPUT`, which BOTH messages contain, so it could not
  discriminate and stayed green straight through the split.
  **⚠⚠ ROUTES 2 AND 3 WERE IMPLEMENTED AND REVERTED [owner: "ship route 1"]** —
  see **DEFERRED 75 / 76**. Route 2's datum-level arm **BROKE MONOTONICITY**
  (`^` is a bindable name, so `[snd2 xs:name ^]` is a program HEAD accepts and
  the arm made it an error) and route 3's gate widening **ate binder names**
  (`|.|` has one role; `|:|` has two). Both need a grouper-side adjacency mint —
  the same shape as P4d-0's `:{`, which landed alone for the same reason.
  **⭐ THE VERIFY EARNED ITS KEEP FOR THE FOURTH SLICE RUNNING**: the break was
  invisible to a GREEN battery, five green acceptance files, AND a two-direction
  mutation test that passed. ⚠ **Two of three skeptics wrongly cleared it** (they
  tested `defn ^`, which fails, never `def ^ :=`, which works) — the adjudicator
  and the main thread each reproduced it independently. And **mutation-testing
  refuted a pin title of mine**: "the split is PER-STEP, not per-branch" is not
  observable — Q_U13's NEST gives ONE carrier per level, so a per-branch `ormap`
  passes the whole battery. `findf` is honesty, not a fix; the pin and the
  comment now say so. Also corrected: `parser.rkt`'s claim that
  `make-select-bcast` has "ZERO production callers" (it has FOUR, same file).
  **Gates**: battery **420 → 425** · acceptance **77/77** + 89/89 + 6/6 + 29/29 +
  28/28 · full suite **10061 / 488 / 0**, `[488/488]` verified · the reverted
  surfaces A/B **byte-identical to baseline**.

- **✅ Slice 7 — A PAREN GOAL AS THE SUBJECT OF A POSTFIX ACCESS — COMPLETE
  2026-08-08** (`f54dfc6c`). Owner-requested. `(G):c` now solves, as do `.name`,
  `[0]` and chains; the `def`/`let` seams too. The witness had to be a DATUM
  sentinel, not a syntax property — `(G).0` and `[get (G) 0]` are byte-identical.
  Three owner rulings landed (let spellings agree · multi-line def · a value in
  parens is a *guided* error). Verify `wf_0511966a-d51` (4 skeptics + judge)
  found 3 defects of mine. Suite 10087/488/0. → [§5.P4d-s7](#p4d-s7)

- **✅ Sub-slice 4d-2 — THE BROADCAST AXIS + the stale-phase sweep — COMPLETE
  2026-08-08.** Verify `wf_6893b003-6ae` (3 skeptics + adjudicator).
  **SHIPPED**: a `'bcast-elem` wrapper for the PVec/Map carrier (whose `else` arm
  returned its inner fail RAW while the keyword-row arm wrapped), plus a
  broadcast AXIS on `format-select-fail` — **`#f` / `'elem` / `'at` / `'union`**.
  `subject-other` now names what actually failed, and `not-indexable`'s remedy
  moved INTO the cond that knows the truth. Three user-facing phase promises in
  `parser.rkt` reworded PHASE-FREE (the `.*name` one was promising a feature that
  had already shipped), three stale comments fixed, two slice-4a-origin test
  labels corrected `s4b` → `s4a`.
  **⚠⚠ THE VERDICT WAS FIX-FIRST, and every defect was in code I had just
  written.** The axis was **2-valued when the concept is 3-valued**: `bcast-at`
  (heterogeneous — ONE field/position) and `bcast-union` (ONE component) were
  handed `'elem`'s universal, so `r2:z` printed *"broadcast fails at field :b —
  … **each element** is not a record"* while `:a`'s value IS one — false, and
  self-contradictory with its own prefix four words earlier. Also: `xs:key` was
  emitted for **non-keyword-keyed Maps**, where no `:` spelling exists (a two-hop
  dead end); a remedy derived from ONE field's type was asserted over a whole
  heterogeneous broadcast; the `[else]` arm dropped a **working** `x{k}` for
  schema-typed subjects (right for scalars, wrong for an fvar — and a
  schema-typed subject is exactly what the sibling arms' own "seal it" remedy
  produces); and the call-site wrap re-wrapped a `bcast-union` fail, producing
  the mirror of the double-wrap its own comment claimed to avoid. All fixed and
  each reproducer re-run.
  **⭐ Two skeptic findings were REFUTED as stale** — they read a snapshot taken
  before the `subject-other` PVec-branch fix, which the adjudicator confirmed
  executes. Second arc running where skeptics agreed and were wrong.
  **Gates**: battery **425 → 430** · acceptance 0 mismatched × 5 · full suite
  **10066 / 488 / 0**, `[488/488]`. ⚠ An intervening run read **10061** with
  `all_pass: true` — a batch worker under-reported `test-properties.rkt` as 8
  when it is a deterministic 13. **DEFERRED 81**; the tell was that the total
  moved in a direction the battery delta could not explain.
  **Filed**: DEFERRED **77** (three sibling arms still misattribute; the tuple
  one advises a spelling that SUCCEEDS WITH THE WRONG MEANING) · **78** (the
  census grep structurally cannot see bare-token phase refs — the 10th arc of
  under-counting, in a census I had just widened) · **79** (pre-existing: the
  `let` fused-annotation message states two falsehoods) · **80** (the
  `bcast-step` arm may be dead) · **81**.
  **⬜ REMAINING in 4d**: nothing — 4d-1 and 4d-2 close it.

- **✅ Slice 5 — THE UNION META-FALLBACK NON-TERMINATION — COMPLETE 2026-08-08**
  (owner: *"fix this first … ship code we can be proud of"*). Verify
  `wf_d29c48fd-aed` (2 skeptics + adjudicator).
  **⚠⚠ FOUND AT THE CLOSE, FILED NOWHERE, IN P4d's OWN SLICE-3 CODE.**
  `select-union-lift`'s unsolved-meta arm called `select-bcast-inner-apply` with
  the SAME union `u`; that function's first arm dispatched straight back with the
  same union; `comps`/`offering` derive purely from `u`, so nothing changed
  between iterations — an unconditional infinite mutual recursion. On `sl:a:b`
  (DEFERRED 58's fixture plus ONE chain step): **`fuel exhausted`, exit 1, output
  EMPTY** — a def ABOVE it did not print. The **7th** whole-file abort in this
  track, violating the constraint the phase itself states. A single step could
  not reach it: it needs a union whose component set holds an unsolved META, and
  only a chain produces one.
  **The fix**: factor the non-union tail (`select-bcast-inner-apply/non-union`);
  the one call that passed an UNCHANGED value bypasses the union dispatch, while
  every call that passes a strictly SMALLER value keeps the full dispatcher — so
  the alias / component-whnfs-into-a-union recursion is untouched and
  well-founded by descent (verified: a three-way alias join is byte-identical).
  **⚠⚠ AND THE FIRST CUT TRADED THE ABORT FOR SOMETHING QUIETER AND WORSE.** With
  a union subject the tail reaches `select-project-field`'s union arm — the
  single-get optimistic filter, which **that arm's own comment forbids broadcast
  from reusing, twelve lines above the edit** ("never 'unify' them"). Its fold
  DROPS a meta, so the stored type came out CLEAN and
  `check-escaping-projection-metas` never fired: `def q := sl:a:b` was **ACCEPTED**
  where the SHORTER `def q := sl:a` is hard-refused — more projection, less
  knowledge, past the guard, at zero errors. And adding an empty `{}` component
  (strictly LESS information) flipped a CORRECT keys-⋂ refusal into acceptance.
  Neither skeptic connected it to the D23 guard; **the adjudicator did**.
  Closed by carrying the ORIGINAL metas into the result (a fresh one would not
  restore the guard — it keys on `meta-source-info-kind`). The remaining polarity
  question is **DEFERRED 82**, the swallowed `miss-closed` formatter **83**.
  ⚠ Also corrected: the fix's own termination comment claimed "this function does
  not mention `select-union-lift`" — a grep asserted as a proof. The honest
  invariant is about DESCENT, and it is now written that way.
  **Gates**: battery **431 → 432** · acceptance 0 mismatched × 5 · full suite
  **10068 / 488 / 0**, `[488/488]`.

- **✅ Slice 6 — SPLIT ABSENCE FROM KEY-MISS (Q1 / Q_U21's value layer) — COMPLETE
  2026-08-08** (`003f150b`). Audit `wf_22427256-c66` · verify `wf_aec25ca2-276`.
  **⭐ THE AUDIT REFRAMED THE QUESTION**: ruling (a) was ALREADY not holding at
  HEAD. C9's conservative OR arms the one scalar tier from a Map **sibling**, so
  an actually-absent element in `{:f <Nil|Map> :g Map}` PANICKED — the precise
  failure (a) exists to prevent — while in the same population a genuine miss was
  already LOUD by the same accident. **Owner ruled C9 GOVERNS**; Q_U21 (a) is
  scoped to "no armed sibling" and satisfied at the VALUE layer instead.
  **The split is a DELETION, not an arm**: the Nil short-circuit leaves
  `tier-union-witness` (so the tier arms and the miss is loud), and `champ-of`'s
  assertive-PATH arm is deleted (so it consults only the BLOCK tier). ⭐ The
  assertive tier's guarantee is about the **KEY** — `project`'s question, which
  keeps its arm. It was never about the element's SHAPE, and this file mints
  non-champ values AT MAP TYPE by ruling. Net **−2 arms**.
  **⚠⚠ MY FIRST CUT ADDED AN `expr-nil?` ARM INSTEAD, and the verify refuted it
  twice** — all three skeptics AND the adjudicator converged, and the adjudicator
  built and measured the better fix. (i) My width argument was a **TYPE-level
  claim defending a VALUE-level site**: the gate bounds component TYPES, not
  whether a value at `[Map K V]` is a champ — `ub.a` (the route my own comment
  called safe) yields `none : [Map …]`, and broadcasting it went `none` → PANIC, a
  value→error break, under a comment calling the bound "MEASURED". (ii) Sitting
  above the block arm it **silently weakened Horn D** on the reachable
  `map-assoc` dyn-key route; my own probe missed it by testing a typing-refused
  shape.
  **Gates**: battery **432 → 436** · acceptance 0 mismatched × 5 · full suite
  **10072 / 488 / 0**, `[488/488]`. **Filed**: DEFERRED **84** — the whole-node
  `return` still lets ONE absent element answer for the node (loudness by champ
  hash order; data discarded; a scalar at a container type). Needs a per-element
  vs node ruling plus an ordering-agreement pin.

- **✅ Q2 (the Q_U20 block cell) — ANSWERED 2026-08-08, and the question was
  MIS-POSED.** D4 recorded it as *"in block position `hx{evs:t}` ≡ `hx{evs:{t}}`
  … the extract/assemble distinction COLLAPSES"*. Measured: that holds for PLAIN
  and RENAME inners and FAILS for the caret family, both spellings succeeding at
  0 errors with different output keys, shapes and arities. So the "collapse" was
  never the content.
  **⭐ The content is a RULE the owner's own intuitions turned out to encode, and
  it is the SPEC's**: *a caret applies EXACTLY ONCE, at the level where it is
  written — and dropped means dropped* (§3.4). HEAD applies it **twice** through
  a broadcast and **zero** times through a sub-block, and correctly once on a
  plain dot path. Verified against the rulings, which the dot path satisfies
  exactly: `app{server.ssl.enabled^-}` → `{:enabled true}` (Q_T7, whole branch
  flat) · `^-ssl` → `{:ssl true}` · `^..` → `{:server {:ssl true}}` (Q_T8, one
  level, ancestors kept) · `^ssl` → `{:server {:ssl {:ssl true}}}` (rename in
  place). Four operators, four ruled meanings, all correct on one branch.
  **So the divergence is a DEFECT, not semantics — filed as DEFERRED 88** with
  its three measured members. ⚠ Correcting my own earlier framing to the owner:
  I first argued the divergence was correct structure ("two genuinely different
  nestings") and that making the spellings agree was disqualified from both
  sides. That was rationalising the implementation — I had not checked it
  against Q_T7, which rules `^-` as "collapses the whole branch FLAT". The
  owner's intuition was the ruling; my reading was not.
  **Arity settled separately by [Q_U22](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u22)** — `^` at a leaf stays
  arity-uniform, so the fix does NOT make `xs:{name^}` a second spelling of
  `xs:name`.

- **✅ Q3 (DEFERRED 58, the dyn channel) — ANSWERED 2026-08-08 by DECOMPOSITION,
  and it was mis-posed like Q2.** Filed as *"a THIRD admission channel through the
  UNION GATE"*. The controls refute that level: `d.a` on a bare open row gives
  `<error> : ?meta` at 0 errors with **no union and no broadcast**, and
  `dyns:a` does it with **no union**. The gate admits nothing special; it
  propagates what an open-row projection does everywhere.
  **⭐ The broadcast half needs NO new ruling — the 2b POLARITY already decides
  it.** `typing-core` states it twelve lines above the arm: *"Broadcast is the
  OTHER polarity (all-must-offer …) and must NOT reuse this arm."* An open row
  **MAY** offer the key: that satisfies single-get's OPTIMISTIC polarity and
  FAILS broadcast's ALL-MUST-OFFER one. So "may be present in the remainder"
  does **not** discharge "every component must offer" — `sl:a` must refuse
  exactly as `sl:{a}` already does, and the sort-dependence is a SYMPTOM, not
  the defect. Scoped to broadcast, so **D19 is not reopened**: single-get keeps
  its leniency by being the other polarity. **DEFERRED 58 re-scoped in place.**
  **The other half is NOT ours.** `def port : Int := cfg.port` is ACCEPTED and
  `[int+ port port]` yields `[int+ <error> <error>] : Int` at 0 errors — the D23
  guard refuses UNANNOTATED storage but its documented "annotate to discharge"
  takes an assertion the checker has no evidence for. That is the OPEN-ROW
  PROJECTION CONTRACT (D19/Q_T2/D23), which CIU T6 only surfaced — filed as
  **DEFERRED 89**. The honest shape already exists one function away:
  `nil-safe-get` types absence as `T | Nil`, so arithmetic cannot silently
  swallow it.
  ⚠ Method note, second time this session: the option I first offered the owner
  ("the value becomes `none`") was UNDER-SPECIFIED — measuring `nil-safe-get`
  showed the difference is not `none` vs `<error>` but whether the absence is in
  the TYPE. The worked demonstration corrected my own proposal.

  **The P4d close's three owner questions are now ALL discharged** — Q1 ✅ ruled
  and implemented (slice 6), Q2 ✅ answered (fix → DEFERRED 88), Q3 ✅ answered
  (broadcast half → 58 re-scoped; contract half → 89). What remains for the
  close is mechanical: five DEFERRED to re-home · P4e and P4c-5 have no tracker
  row to point at · the tracker flip · the close note.

- **⬜ Slice 4d — the remaining diagnostics** (what 4c did not reach). ⚠ The
  scope below is RE-DERIVED by the slice-4d mini-audit (`wf_a154667e-42f`,
  5 facets + critic @ `2fd6b68e`); every correction is measured, and the
  pre-audit plan was wrong in four places, marked ✗ inline.
  · **Q_U19's unified refusal** — the SITING is answered by precedent
    (`ordinal-rekey-message` is ONE string emitted from FOUR sites, written at
    P3b for **Q_T4a**, the identical "`^` has no key" question one construct
    over, with `retired-selection-marker` as the macros-side per-command
    channel). ✗ **But the precedent's SHAPE does not transfer**: that message is
    one string / four sites / ONE audience, whereas the string here is ONE site
    serving TWO audiences, so the work is a **SPLIT**. Owner ruled 2026-08-08:
    **dot string byte-identical, add a broadcast sibling**, and **all three
    routes** — which are three SEATS (segmentation · a fold arm · the
    tokenizer/gate), not one funnel. Full ruling + the per-step discriminator,
    the precedence constraint and the monotonicity bound: [Q_U19](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u19).
  · Re-point the **"P4c-4b: the payload's THREE sub-cases"** pin to the DECISION
    (it froze an ACCIDENT — it asserts today's routing), and the two re-pointed
    pins' section labels (the two kept slice-4a tests carried a `P4d-s4b` prefix — CORRECTED at 4d-2 to `P4d-s4a`).
    ✗ The "orphaned slice-4a test header" is **ALREADY FIXED** at `2b52af8b` —
    it now reads "Neither the append nor the guard exists at HEAD." DROPPED.
  · **DEFERRED 47 ≡ 59.1** — the `subject-other` non-PVec branch. ✗ Not "one
    string, one site": the missing-`bcast-at` prefix is CARRIER-specific (the
    `else` arm of `select-bcast-lift` returns the inner fail RAW while the
    keyword-row arm wraps), so *no prefix* and *"the subject" misattributes* are
    TWO independent defects, over a population of four shapes.
  · **59.2** — `not-indexable`'s `x{k}` remedy is off-key inside a broadcast.
    ✗ The existing `cond` does **not** discriminate the right cases: it
    discriminates CARRIER KIND and computes only the middle interpolation; the
    remedy sits in the UNCONDITIONAL template tail, and `format-select-fail`
    threads no broadcast axis at all.
  · **The stale phase references.** ✗ Not "two reachable in `parser.rkt`":
    `grep -rn 'Path Selection P' racket/prologos/*.rkt` returns **seven sites
    across four files** — three user-facing strings in `parser.rkt` (`P4`,
    `P4c-3`, and the `*` flatten "Until Path Selection P4d") plus comments in
    `parser.rkt`, `parse-reader.rkt`, `syntax.rkt` and `surface-syntax.rkt`.
    D4 assigns `*` flatten to **P4e**, so P4d's close makes that promise
    retroactively false. ⚠ The `*` refusal fires on a TRAILING star
    (`us:tags*`), not a leading one, and it is battery-pinned — text and pin
    move in lockstep.
  · Correct the false premise in the edited lines: `parser.rkt`'s comment
    claiming `make-select-bcast` has "ZERO production callers at HEAD" — it has
    **four**, in that file.
- Corpus re-fate rides each slice. **Gates**: failing-test-first batteries +
  authored fixtures; the corpus A/B is REGRESSION-ONLY for slices 1–4 (the
  carriers have ~no corpus coverage — the vacuous-green hazard, named) but
  LOAD-BEARING for slice 0.

<a id="p4d-close"></a>

##### §5.P4d CLOSE — ✅ COMPLETE 2026-08-08  (close note; the Stage-5 PIR belongs to X.close)

**THE FEATURE.** Broadcast (`:`) is LIVE at the production default over **PVec ·
Map · keyword-row · het tuple · union · closed schema**. The refusals left —
List · LSeq · Set · scalars · open-or-dyn rows · open-or-defaulted schemas ·
collided selections — each name their OWN conversion, and scalars correctly get
none, because there is nothing true to say.

**TWELVE SLICES**: 0 (`00e52c42`) · 1 (`14ef5e83`) · 2 (`ba1c055d`) ·
3 (`1e8d0795`) · 4a (`61d64708`) · 4a′ (`d3947594`) · 4b (`19ce05aa`) ·
4c (`a31b7475`) · 4d-1 (`bd8b8bcf`) · 4d-2 (`25f3f22d`) · 5 (`a945f390`) ·
6 (`003f150b`).

**RULINGS**: [Q_U19](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u19) (A) path-position `^`-on-broadcast REFUSED, and the
dot string stays byte-identical · **C9** (a) one scalar tier, conservative OR,
`'path`-scoped · [Q_U21](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u21) (a) `Nil` is SKIPPED · **C9 GOVERNS** where it
meets Q_U21 (a), which is scoped to "no armed sibling" ·
[Q_U22](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u22) `^` at a leaf is ARITY-UNIFORM · the carrier gap belongs in
slice 4 · **the remedy points back at the user's own spelling, not at a taught
spelling** — the ruling that retired 4a's entire advice machinery at 4c.

**THE THREE OWED OWNER QUESTIONS — ALL DISCHARGED**, and **two of the three were
MIS-POSED as filed**, which is the close's most transferable finding:
- **Q1** (the Nil-bearing union's quiet miss) — RULED and IMPLEMENTED as slice 6.
  ⭐ The close's audit found ruling (a) was ALREADY not holding at HEAD: C9's OR
  armed the tier from a Map SIBLING, so an absent element PANICKED — the precise
  failure (a) exists to prevent — while a genuine miss in the same population was
  already loud, by the same accident. Both inverted at once.
- **Q2** (the Q_U20 block cell) — ANSWERED. The recorded premise ("the
  extract/assemble distinction COLLAPSES") is TRUE only for plain and rename
  inners and FALSE for the caret family. The real content is the SPEC's own rule,
  which the owner's intuitions independently encoded: **a caret applies EXACTLY
  ONCE, at the level where it is written, and dropped means dropped** (§3.4). Fix
  → **DEFERRED 88**.
- **Q3** (DEFERRED 58, the dyn channel) — ANSWERED by DECOMPOSITION. Filed
  against the union gate; the controls show the same silence with NO union and NO
  broadcast. The broadcast half needed **no new ruling** — the 2b polarity
  already decides it ("may be present" does not discharge "must offer") → 58
  re-scoped in place. The annotation-lie half is NOT a Path Selection question →
  **DEFERRED 89**.

**GATE**: full suite **10072 / 488 / 0** (`[488/488]`, forced re-run) · battery
**420 → 436** · acceptance **77/77** + 89/89 + 6/6 + 29/29 + 28/28 · corpus A/B
REGRESSION-ONLY for this phase by construction (the carriers have ~no corpus
coverage — the vacuous-green hazard, named at the opening and still true).

**⭐⭐ THE METHOD FINDING, and it is the phase's real product.** **Every slice
shipped a defect of mine that a green suite, five green acceptance files and the
battery were ALL blind to** — and at 4d-1 a passing **two-direction mutation
test** was green over one too. The adversarial verify caught every one; twice the
ADJUDICATOR caught what all three skeptics missed or actively cleared. Named
sub-findings, each with a live instance:
- **A boolean over a 3-valued domain is a catch-all in disguise** (4d-2's axis).
- **A TYPE-level argument cannot bound a VALUE-level site** (slice 6's width claim
  — my comment called the bound "MEASURED" when the only measurement was a typing
  refusal that did not bear on the question).
- **A pin's NAME can be the lie** (4d-2's GUARD asserted three arms while testing
  the one that did not change; a real regression stayed green beneath it).
- **A skeptic's CLEARANCE is not evidence** — twice, skeptics agreed and were
  wrong (testing `defn ^` instead of `def ^ :=`; reading a stale snapshot).
- **A control probe is the cheapest way to find a mis-posed question** — Q2's
  pure-dot-path control and Q3's no-union/no-broadcast control each exposed, in
  one probe, that the filed framing named the wrong level.
- **When a design question resolves to "current behaviour is correct", check the
  RULING first.** I argued Q2's divergence was correct structure and offered a
  lean to rule it so, without checking Q_T7 — which rules `^-` as collapsing the
  whole branch FLAT. Rationalising the implementation.
- **Worked examples are a DEBUGGING instrument.** The owner asked for them
  because rule-labels were unparseable; they exposed a defect three audits had
  walked past, and twice corrected MY proposal rather than their understanding.

**CARRIED OUT, filed not hidden**: DEFERRED **75/76** (Q_U19 routes 2 and 3 —
implemented, verified, REVERTED for a monotonicity break; they need a
grouper-side adjacency mint and land TOGETHER) · **77** (three sibling arms still
misattribute; the tuple one advises a spelling that SUCCEEDS WITH THE WRONG
MEANING) · **78** (the census grep cannot see bare-token phase refs) · **79** ·
**80** · **81** (the suite can UNDER-REPORT `total_tests` while `all_pass` stays
true — cross-check against a delta you can predict) · **82** · **83** · **84**
(one absent element still answers for the whole node; loudness by champ hash
order) · **88** · **89**. Re-homed at this close: **45 ✅ · 47 ✅ · 59 ✅**
(all three were shipped but unmarked) · **61** (not scheduled — a feature
question, → X.close triage) · **63** (orphaned on the landed slice 4c → P4e).

**⚠ STRUCTURAL REPAIR made here**: **P4e** and **P4c-5** had NO Progress-Tracker
row despite sitting in the critical path, so "point at the next phase" had
nowhere to land. Rows added, with explicit anchors at the bullets that describe
them.

**Status: ✅ P4d COMPLETE.** Next: **[P4e](CIU_6_P4.md#p4e)**.


> *Here D4 continued elsewhere: D4 9431–9764 (§5.P4e-0) → [CIU_6_P4e-0.md](CIU_6_P4e-0.md); D4 9765–10213 (§5.P4e-1 + 1a + 1b) → [CIU_6_P4e-1.md](CIU_6_P4e-1.md); D4 10214–11225 (§5.P4e-1b-vi) → [CIU_6_P4e-1b-vi.md](CIU_6_P4e-1b-vi.md); D4 11226–11578 (§5.P4e-1b-v) → [CIU_6_P4e-1b-v.md](CIU_6_P4e-1b-v.md); D4 11579–12554 (§5.P4e-1b sequencing, 1b-iii, 1b-iv) → [CIU_6_P4e-1b-iii-iv.md](CIU_6_P4e-1b-iii-iv.md); D4 12555–12707 (§5.P4e-2) → [CIU_6_P4e-2.md](CIU_6_P4e-2.md); D4 12708–12761 (§5.PF) → [CIU_6_PF.md](CIU_6_PF.md); D4 12762–12775 (§5.P5) → [CIU_6_P5.md](CIU_6_P5.md); D4 12776–12785 (§5.PX) → [CIU_6_PX.md](CIU_6_PX.md); D4 12786–12814 (§5.P6) → [CIU_6_P6.md](CIU_6_P6.md); D4 12815–12828 (§5.X) → [CIU_6_X.md](CIU_6_X.md); D4 12829–12936 (§6 … §10) → [2026-07-28_CIU_T6_PATH_SELECTION_D4.md](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md).*

<a id="p4d-s7"></a>

### §5.P4d-s7 — A PAREN GOAL AS THE SUBJECT OF A POSTFIX ACCESS  ✅ 2026-08-08 (`f54dfc6c`)

Owner-requested. `(fruit-color "apple" c)` carried its implicit solve;
`(fruit-color "apple" c):c` did not, answering *"fc is a relation, not a
function"*. By referential transparency it must — the same value, the same
selection.

**Root cause.** The reader mints a postfix access as a **sibling** of its
subject: `(G):c` reads as `((G) ($bcast-step :c))`. So `parse-command-datum`
applied its goal test to the OUTER list and the goal was demoted from "the whole
command datum" to "element 0 of it".

**⭐ WHY THE FIX IS IN THE READER — the measurement that decides it.** The
tempting repair is to descend to the subject downstream and re-test
`prologos-paren-origin` there. Measured at `b6f773a8`, that is **unsound**:

| source | post-preparse datum | top `paren-origin` | subject `paren-origin` |
|---|---|---|---|
| `(G).0` | `(get (G) 0)` | `#f` | `#t` |
| `[get (G) 0]` | `(get (G) 0)` | `#f` | `#t` |

Byte-identical on both axes. `[get (G) 0]` is an application in ARGUMENT
position that must keep refusing (pinned at `test-solve-carrier.rkt`
"SCOPE BOUND"). Downstream there is nothing left to tell them apart — the
paren/bracket distinction exists ONLY in the reader.

The property is also **anti-correlated with the answer**: it SURVIVES in two
positions that must refuse (a `defn` body; a nested bracket `[[(G):c]]`) and is
STRIPPED in three that must solve (def RHS, aligned let RHS, every chain —
`syntax-locs-only` drops properties from moved nodes, and for chains the mark
migrates onto the bare `$select-path` head atom). So the carrier is the DATUM
sentinel `$goal-rhs`, on the argument `parse-reader.rkt` already records for the
`let` leg one level in: *preserve that bit in the DATUM, where stripping cannot
reach it.*

**⭐ THE MECHANISM ALREADY EXISTED.** `let [zb := (G):c] zb` WORKED at HEAD — the
bracket-`let` arm of `mark-binding-values` is the one arm with no element-count
gate, so it minted `$goal-rhs`, which landed in SUBJECT position and was consumed
there by `parse-datum`'s existing sentinel arm. This slice REACHES that
mechanism from the other command positions; it invents none. It is also why
CHAINS came free: the mint precedes the fold, which nests one carrier per level
with the subject always at index 1.

**The enumeration under-counted by three.** Beyond the reported `:c` `.0` `{c}`
`:{c}`: the PLAIN DOT `.name` (the commonest selection surface), `[0]`
(byte-identical to `.0`), and every CHAIN. `.{…}` and `.:name` are NOT members —
their fold arms DESTROY the base (`($retired-selection …)`), so there is no
subject to carry a goal; `subject-preserving-access-heads` excludes them by name.

**Owner rulings (2026-08-08), all landed.**
1. *"The `let`s shouldn't disagree whether they use a `:=` or not."* — the
   aligned/bare arm mints too. The other two spellings refuse an access on ANY
   value (DEFERRED 97), so they are out of reach from here.
2. *"The multi-line `def` shouldn't lose it's solve."* — a continuation-line
   value nests one level deeper, inside a LAYOUT group.
3. *"Wrapping other values in [parens] does seem like it should be a
   properly-guided error."* — the widening is INTENDED; base was the
   inconsistent side (bare `(mm)` already refused while `(mm).a` silently treated
   parens as grouping). The guided diagnostic moved to ELABORATION
   (`non-relation-goal-head-error`), where it survives the selection seat and
   gains a real srcloc — previously `<unknown>`.

**⚠ BRACKET GROUPS NOW CARRY A MIRROR MARK, and it is load-bearing.** A
multi-line value's layout group is byte-identical to a user bracket — same datum,
same span, no properties (measured) — so descending one level to reach the
multi-line value would ALSO descend into `def B := [(G):c]` and mint a goal in
argument position. `prologos-bracket-origin` makes *"unmarked ⇒ layout"*
structural. The descent is exactly one level.

**⚠ THE VERIFY FOUND THREE DEFECTS OF MINE — five slices running.** Sharpest: the
reader predicate tested only the sentinel HEAD while the preparse fold tests head
AND arity, so `($dot-access a b c)` was marked and never folded, leaking as
`Unbound variable $dot-access` where HEAD gave the relation diagnostic. **That is
the exact drift the head-set re-homing claimed to prevent, committed in the same
change** — sharing a list does not make two predicates agree; matching the arity
discipline does. Also: the `let` divergence and the multi-line `def` gap.
Separately, one of my own pins PASSED AT RED for the wrong reason (the oracle
compared a trailing `def after := 42` on both sides); rewritten to compare
against the explicit `[solve (G)]…` spelling.

**Evidence.** Suite **10087 / 488 / 0** (`[488/488]` verified). Battery 432, green.
A reader-level oracle over all 164 `.prologos` files: the mint fires in exactly
three places, all inside Q_C. Verified byte-identical to base: `defn`/`fn`
bodies, match arms, nested brackets, `[get (G) 0]`, sexp mode. No double solve,
no new whole-file abort, and **no silent wrong answer** — every affected case is
working-value → error, never a different value.

**⚠ THE CLOSE-OUT, and why it was needed.** The first landing met the acceptance
criteria but MISSED THE CHIP'S OWN GATE — *"adversarially verify before the
behavioural commit, and AGAIN if the change widens"*. It widened: the bracket
mark, the one-level descent, and the elaboration-time refusal were all added
AFTER the verify ran. The omission cost immediately —

- **The solve family had split in two.** The diagnostic was hoisted for
  `surf-solve` only, leaving `solve-one` / `explain` / the two `-with` arms
  refusing at RUNTIME with an `<unknown>` srcloc while `solve` refused at
  elaboration with a real one. Same message, two production sites: the drift
  class, self-inflicted, in the change whose commit message complains about
  drift. All five arms now share `non-relation-goal-head-error`, which takes a
  `who` so the text stays byte-identical to the runtime site's.

- **Acceptance §K added** (markers 83–89, appended after §J so nothing
  renumbers). It shows the working surface only — gate 1 requires ZERO errors,
  so the scope-guard refusals stay in `test-solve-carrier.rkt`.

- **The reader delta was benchmarked**, having been shipped unmeasured. Reader
  only, same corpus in both legs (main's `lib/examples` carries owner WIP, so
  each tree's own copy would vary the INPUT too), 6 interleaved rounds:
  base **4246.9 ms** mean vs changed **4284.3 ms** — **+0.88%**, against a
  within-leg spread of **3.35%**, with the first changed round FASTER than base.
  Below this setup's measurement floor. Deterministic size of the added work:
  **5160** bracket groups in the corpus ⇒ 5160 property writes per full read.

**Second verify verdict: SHIP** (`wf_6d3e6d28-359`). It judged the POST-fix state
(it noticed the tree had moved under its own lenses and pinned the files by
sha256 before trusting anything), re-ran the full suite `[488/488]` 10099, the
acceptance file (90 results, 0 errors), and confirmed the D1/D2 safety argument
EMPIRICALLY: `def m :=` ⏎ `(fc …):c` solves while `def m :=` ⏎ `[(fc …):c]`
refuses — the descent sees through a layout group but not through a user
bracket.

⚠ **It also corrected MY verify setup.** All three lenses were told to A/B
against the main checkout, on the strength of the four slice-7 files matching
`b6f773a8` — but main carries extra `reduction.rkt` (+41) and `typing-core.rkt`
(+40) commits, so it is NOT a pristine base for a comparison of TYPE ERRORS and
SRCLOCS, which is exactly what the lenses were comparing. The judge discarded it
and built a `git archive b6f773a8` export instead. No verdict changed here, but
it is the stale-base class `workflow.md` already warns about, arriving through
the instruction rather than through the agents.

**Deferred.** 84 (three `let` spellings + `def-` refuse an access on any value) ·
87 (a goal KEYWORD under an access gets the broadcast-carrier message) · 85 (an
empty group at command position aborts the file — pre-existing) · 86 (`'(…)` the
QUOTED GOAL, the owner's fourth request — a language feature needing a
first-class `Goal` type, which does not exist in the tree).


- **The spec** (normative surface): `docs/tracking/tracks/CIU/CIU_6/2026-07-28_path-selection-spec.md`
- Predecessor design (record of rounds 1–8b): `2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`
- Landed substrate: P2 commits `ad75e57a` · `88d1f746` · `b8f7cc27` · `d4f4b80f` · `ac89341f`
- P3 mini-audit: `wf_2830f0aa-9a4` (token registry, censuses, seats) — findings recorded in the predecessor's P3 row
- Records substrate: `2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` (D1–D29) · F1b PIR · Rel T1 PIR
- Rules: `prologos-syntax.md` § Reader · `pipeline.md` · `workflow.md` · `on-network.md`
