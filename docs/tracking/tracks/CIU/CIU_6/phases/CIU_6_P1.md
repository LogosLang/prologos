# CIU 6 — D4, §5.P1 … P1b-i (+ §5.P1b-ii … P1b (superseded framing))

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 4310–4698 are lines N-4303 here; D4 lines 4976–5475 are lines N-4577 here.

---

<a id="p1"></a>

### §5.P1 — The lexical seams + the retirement batch

**SPLIT into P1a + P1b (owner Q_L6)** after the mini-audit
(`wf_789e4f0f-f02`, 7 facets + completeness critic @ `5c171caa`; raw output:
`/private/tmp/claude-501/…/tasks/w1vsud0hy.output` + per-agent journal in the
workflow transcript dir — session-local; the durable findings are THIS
section). The audit **refuted the phase's central ruling** (3d — see Q_L1),
found the `.{` glyph NOT free, re-scoped the `broadcast-get` retirement, and
proved the named diagnostic template is a whole-file abort. The unbroken
mini-audit-refutes-premise streak continues (8th consecutive).

**Audit record — the grounded facts P1a/P1b build on** (all main-session
R-lens-verified unless marked):

- **The dot band is EXACTLY five** recognizers, proven exhaustive (`char=? c1
  #\.` at parse-reader.rkt :713/:730/:748/:762/:771; `ident-start?` omits `.`):
  rest-89 · dot-key-88 · dot-lparen-87 · broadcast-87 · dot-access-86.
  Prefix-disjointness — not priority — is what makes a `dot-lbrace` token safe
  (dot-access :732 already excludes `{`; every other member requires a
  different second char). ⚠ D4 carried a stale 3-member cite of this band in
  one place alongside the correct 5-member cite (fixed with this fold).
- **The "three-layer opener co-update" is SIX sites**: registration
  (:1091-1092 shape) · extent frame dispatch (:1310) · extent langle skip-set
  (:1291-1292, in `langle-matched?` :1279) · group-items langle skip-set
  (:2356-2357, in `has-matching-rangle?` :2337) · group-items opener arm
  (:2498-2505) — the framing collapsed the two langle TWINS whose disagreement
  IS the `31d27c83` defect — **plus a SIXTH in a second file**:
- ⚠ **`surface-rewrite.rkt` still carries FULL `dot-lbrace` → retired-mixfix
  routing** (:516-521 `memq` arm → `'mixfix-group`/`mixfix-rbrace`; closer
  legs :507/:510/:537), production-reachable via `group-tree-node` ←
  driver.rkt:2432. `d18648f0`'s "grep = 1 hit" VAG was scoped to
  parse-reader.rkt only. Inert today ONLY because no recognizer emits the
  token — **registering `dot-lbrace` at P1b without this cleanup silently
  wakes retired mixfix semantics**. Hence P1a lands the cleanup BEFORE any
  re-mint. (Two facets found this independently.)
- **`.{` today** (probe): loose `|.|` + `$brace-params`, with FOUR distinct
  downstream errors depending on payload shape (even-count · bare-symbol ·
  unbound-`|.|`) — the design's single cited message was one of four.
- **Census corrections, and the RULE**: the audit's two "refutations" of the
  `.*name`=4 count both measured the DIRTY WORKING TREE (owner WIP had
  commented 3 of 4 sites; Q_L5 disregards those sketches). At HEAD the design
  is right: `.*name` = 4 (first-class-paths :185/:188/:192/:349) · dot-key
  `.:name` = 2 (first-class-paths:43 PREFIX form; punify-p3:441 POSTFIX form —
  two SHAPES, so the migration message covers both) · `racket{…}` = 10 (the
  facet counts of 12/14 included an out-of-tree emacs fixture + comments).
  **Every P1 census runs `git show HEAD:<file>`, never plain grep.**
- **`m[:kw]` is RULE-DEPENDENT**: 22 = loose `[:` lines · **16 =
  adjacency-verified lines (the actionable rule — the retirement discriminates
  on adjacency + keyword-literal payload)** · 30 = occurrences incl. `][:`
  chains. Suite cost: 5 pins flip (test-postfix-index-01:33-35;
  -03:119-124/:142-147/:195/:204); the discriminator must SPARE `m[k]` with
  `k : Keyword` (pinned -03:127-135; live surface-ergonomics:258).
- **The accepted gap is genuine noise**: `first-class-paths.prologos` has ZERO
  `;;N=>` markers and nothing references it outside docs/ — not suite-gated,
  not acceptance-gated. (Disambiguation: `tests/test-first-class-paths.rkt` IS
  suite-gated but is a different artifact whose broadcast coverage is
  commented out.)
- **`expr-broadcast-get` is permissive** (confirmed): `ladmins.*nope` →
  `'[<error> <error>]` at 0 errors — the live silent-wrong-answer under a
  green suite. Retiring the node deletes the defect.
- **Reject-batch reclassification**: `x[]`/`_[sel]`/`.-1`/negative payloads
  have ZERO existing coverage (net-new pins, not flips). Two are
  mis-classified: `v[-1]` is a SILENT WRONG ANSWER today (types `Int`, prints
  a stuck term, 0 errors) and the same defect rides bracket-free
  `[get v -1]`; `_[sel]` fails identically as `[get _ :a]`, so a bracket-only
  rejection leaves the partial-application idiom broken — both scoped
  judgments recorded in §5.P1a.
- **Reader-form heads have NO registry**: the set is `{racket}`, hard-coded
  TWICE (macros.rkt:2431/:2435; driver.rkt:3337), and there is NO module edge
  from parse-reader.rkt to macros.rkt — head recognition lives at PREPARSE
  while adjacency precedence must live at GROUPING. P1b creates the single
  source of truth (a leaf module or registration parameter); the F1b.7g
  inline-list drift class applies directly.
- **WS `racket{…}` has ZERO regression coverage**: `foreign.prologos` is
  `'skip`ed by the runner; all 13 `test-foreign-block.rkt` cases are
  sexp-mode. Ruling 3b's "round-trip pins" are NEW coverage, not preserved.
- **Brace adjacency has a FOURTH bucket** (left token = a CLOSING delimiter:
  `f[x]{a}`, `(g y){a}`) and the positional test's `(pair? result)` conjunct
  is load-bearing — it alone protects 13 live opener-adjacent sites
  (`'[{…}`, `@[{…}`). `$brace-params` is already TRIPLE-purposed (map literal
  · implicit type binder · foreign block) from one sentinel (:2496); the
  largest spaced population is BINDERS (`spec identity {A : Type}` is one
  space from a select block).
- **`:<` severity is INPUT-DEPENDENT**: with no depth-0 `>` in scope the
  probe degrades benignly to an operator reading; with a later depth-0 `>` it
  CROSS-LINE SWALLOWS (two top-level forms collapse into one — trigger:
  `langle-matched?` finds the `>`, close-type `#f` window runs to EOF). The
  Q8 probe row must test BOTH shapes or it reports "no problem".
- **`.` quadruple-duty disambiguation order exists NOWHERE in writing** — Q8
  owes it (R3). And the fourth duty is contested per Q_L2: sexp `.{` fan-out
  (15 live test sites) vs WS `.{` sub-block — divergence institutionalized.
- **Ungated collateral**: 2 golden fixtures embed `($dot-key :name)` (zero
  test callers — go silently stale, note only);
  `benchmarks/micro/bench-ppn-track2.rkt:174` measures a dot-key payload
  under the name "rewrite-dot-access" (already misnamed) — P1a re-points it.
- **Two separable defects → DEFERRED**: the tilde-number seat itself
  whole-file-swallows (a mid-file `~3` silently discards ALL output — the
  exact silence class the new seat exists to prevent); bare top-level `[]`
  hard-aborts with a raw contract violation (parse-reader.rkt:2160-2161
  position-0 stx → macros.rkt:2804 `max` on #f).

<a id="p1a"></a>

### §5.P1a — The retirement batch + substrate  ✅ `859b529d`

**✏ CLOSE NOTES (2026-07-28).** Suite **9253 / 474 / 0** · neighborhood
**477 / 16 files** · acceptance **28/28 + 89/89** · audit-06/-09
differential-identical to HEAD · −744/+320 across 23 files. Written
failing-first: 10 RED guided-diagnostic pins → green.

**What the adversarial verify caught** (3 perspective-diverse skeptics on the
uncommitted diff — the practice paid, and the headline is self-inflicted):
- **BLOCKING, and MINE — the seat introduced the abort it exists to prevent.**
  The marker arm called `(car args)` unguarded, so a user-written zero-arg
  `[$retired-selection]` RAISED at the parse seam and killed the whole file.
  Its three raw-sentinel siblings had carried `(pair? args)` from the start —
  I wrote the guard three times and omitted it on the fourth. Fixed + pinned
  (B5). **Lesson shape: when a new arm joins a family, diff it against its
  siblings, not against its own intent.**
- **SIGNIFICANT, pre-existing** — `pattern-var?` excluded the LIVE sentinels
  but not the retired `$dot-key`/`$nil-dot-key`, so a retired shape inside a
  `defmacro` TEMPLATE read as an unbound pattern variable and raised out of
  preparse: whole-file abort, a retired-surface path that BYPASSES the seat.
  The mini-audit had flagged the asymmetry (facet 3 finding 19); closed here
  because the phase owns that list. Pinned (B6).
- **MINOR** — negative NON-integer indices escaped the guard, and **probing
  corrected the skeptic's own mechanism**: `-1` arrives BARE but `-1.5`/`-2/3`
  arrive WRAPPED as `($decimal-literal -3/2)`/`($rat-literal -2/3)`, so no
  unwrapped numeric test can see them. Hence `negative-index-payload?`. Pinned
  (B7). *(Another "probe before believing the mechanism" data point — this
  time against a report, not a design.)*
- **CONFIRMED**: node deletion complete across reflection consumers + the pnet
  table; zero misfires on every must-survive surface; **`.( )` mixfix fully
  intact INCLUDING comparison chains** — the live pratt path implements them
  natively, so the deleted `expand-comparison-chain` was a redundant dead twin.

**Adaptations made during implementation** (design → code):
- **The seat's conversion point moved preparse → PARSER.** Error VALUES are
  already legal there and flow per-command; preparse Pass 2 has no per-form
  handler and datums are its only legal output. Consequence: retirement
  TOKENS stay as marker emitters, so **all reader token-layer pins stayed
  green** and the churn shrank to rewrite-units + E2E pins.
- **The `m[:kw]` hint in the design row was wrong** — it named `m[a]`, the
  *superseded* surface's spelling. Corrected to `m.a` / `[get m :a]`.
- **The nil-dot-key twins were already broken in WS**, and the mechanism is
  now known: the stx arm kept the RAW LEXEME (`#:name`) as the key, so the
  e2e path died as `Unbound variable`. Their retirement is a message upgrade,
  not a capability removal.
- **test-postfix-index-02 carried a rewrite-unit pin the audit's flip list
  missed** (`m[:key]` → `get`) — found by running, not by reading.

**Recorded, not fixed** (2 pre-existing whole-file aborts, both reproduce
identically at HEAD → DEFERRED): live `.( )` mixfix errors still RAISE
through preparse — the same failure class Q_L4 documents, and **the seat now
exists for them**; and a union-typed def + implicit-binder spec + call hangs
in typing. Also left: chained `m[:a][:b]` reports only the last key
(cosmetic, one correct-class error, continuation intact).

**Test delta**: +14 in `test-path-selection` (10 guided-diagnostic, 4
survivor incl. the direct `definitely-not-map?` conservative-default pin
replacing what the retiring walker tests incidentally carried), +3 defect
pins (B5/B6/B7); 11 flips across `test-dot-access-01/-02`, `test-nil-type`,
`test-postfix-index-02/-03`; the 2 P2.a walker pins retired WITH the node.

---

**Original work list** (as designed; all items landed):

**Work list** (order matters — substrate first):
1. **`surface-rewrite.rkt` `dot-lbrace` cleanup** — delete/re-point the
   :516-521 arm + :507/:510/:537 closer legs. ⚠ Probe first whether the
   `'mixfix-group` consumers (:1412/:1654/:1778/:1789) serve any OTHER live
   producer before touching them. Zero behavioral change expected; the
   `d18648f0` pins must stay green.
2. **The diagnostic seat** (Q_L4), mechanism REFINED by the audit's own
   grounding: the retirement TOKENS/RECOGNIZERS **STAY**, as marker emitters
   (their sentinels `$dot-key`/`$nil-dot-key`/`$broadcast-access` already ride
   the datum stream to every entry path); the preparse REWRITE arms (the
   semantics) are DELETED, normalizing each retired shape to ONE marker head
   `$retired-selection` with a kind tag; **the PARSER converts the marker to a
   per-command `parse-error` VALUE** with the kind-tailored migration message.
   Conversion sits at the parser, not preparse, because parse-error VALUES are
   already legal there and flow per-command (probe: `v[]` → "Unexpected
   datum: ()", file continues — facet 5 [12]), whereas preparse Pass 2 has NO
   per-form handler (macros.rkt:2803-2806) and datums are its only legal
   output. This is `$mixfix-retired`'s marker mechanism with the raise
   replaced by the POL.4 value conversion. Consequence for the test delta:
   ALL token-layer pins (test-parse-reader :395-399/:408-412/:438-442) STAY
   GREEN; only preparse-rewrite units + E2E pins flip. Verify per-command
   continuation E2E on every entry path the seat claims. Two riders recorded:
   the tree-spine merge survives on a latent `loc->line` `(cadr loc)` bug
   (driver.rkt:2468-2473 — noted, not depended on); the sexp tilde template's
   format string is itself malformed (`~ ` consumed by the formatter,
   sexp-readtable.rkt:310) — do not copy it verbatim.
3. **Dot-key family retirement**: `.:name` recognizer + BOTH macros arms (the
   prefix Pattern-2a :5453 leg AND the postfix fold-left :5508 leg — two
   shapes, one guided message naming `.name`); `#.:name` (`$nil-dot-key`) and
   `#:keyword` twins retire; **`#.name` SURVIVES** (must-not-break pins).
   Watch for duplicate/legacy grouping routes (the `d18648f0` two-route
   precedent).
4. **The full `broadcast-get` chain** (Q_L3): reader recognizer (:766, reg
   :1094-1095) · parser keyword (parser.rkt:146 + arm :2332-2350) · surf
   struct (surface-syntax.rkt:251/:894) · elaborator arm (:2394) · the
   `expr-broadcast-get` node per pipeline.md IN FULL (syntax/substitution/
   zonk/reduction whnf+nf arms/pretty-print/pnet-serialize/typing/qtt) ·
   ~~PNET_VERSION bump if the node is tag-registered … a version sweep is the
   only reliable cache invalidation~~ — ⚠ **STRUCK 2026-07-29**: refuted by §8
   R6 as corrected. The tag table is SYMBOL-keyed (additive), and
   `pnet-stale?` already invalidates on `infrastructure-stale?` + a source
   hash, so a bump is owed only when an EXISTING shape's serialization
   changes. P1a itself needed none. (Left visible rather than deleted: this is
   the second copy of the premise the `3cf60868` doc-truth commit was written
   to kill, found by the handoff verification — the "one correction, two
   copies" shape.) The `.*name` guided error names `:name` as the P4
   replacement (the accepted-gap noise, 4 sites). Post-keyword-removal
   diagnostic shapes pinned BOTH ways: `(broadcast-get x :f)` at command
   position = a POL.9 goal → "Unknown procedure"; `[broadcast-get x :f]` =
   unbound variable. Test delta: the 2 walker-safety pins RETIRE with the
   node; the `definitely-not-map?` conservative-default coverage they
   incidentally carried is REPLACED by a direct pin on an arbitrary unarmed
   node (the critic's C3 — do not silently drop the track file's only pin on
   the positive-list default).
5. **`m[:kw]` static error + hint** (preparse-postfix seat): counting rule =
   adjacency-verified (16 lines); ⚠ hint CORRECTED at implementation — the
   carried "names `m[a]` / `get`" was the SUPERSEDED surface's spelling
   (brackets are not selection under the new law; `m[a]` = `(get m a)` with
   unbound `a`). The hint names **`m.a`** (dot descends — works today) and
   **`[get m :a]`**. The 5 flipping pins updated; `m[k]` with `k : Keyword`
   variable stays green (the discriminator is keyword-LITERAL payload, sound
   at the preparse arm since `ident-start?` excludes `:`).
6. **Reject batch**: `x[]` + `_[sel]` graceful static errors at the grouping
   seat (net-new pins). `v[-1]`: static error at the grouping seat for the
   bracket spelling; the bracket-free `[get v -1]` twin is FLAGGED to P2
   (grade-1 core owns `get`'s index discipline) — recorded here so it is not
   lost. `.-1`: NO P1a action — with no `.N` recognizer there is nothing to
   reject yet; lands at P2 as the digit-required classifier design already
   states.
7. **Collateral**: re-point `bench-ppn-track2.rkt:174`'s payload + name; note
   the 2 stale golden fixtures (zero callers, no action).
8. **Recorded decisions**: the `expr?`-predicate gaps on the four surviving
   path siblings (`expr-get-in?`/`expr-update-in?`/`expr-path?`/`expr-Path?`
   — pre-existing, pipeline.md item 1) are LEFT NAMED for P2's mini-audit,
   not closed opportunistically here (retirement slice, not a repair slice).
   PNET: **no version bump** — the tag table is SYMBOL-keyed (removal shifts
   nothing) and zero `.pnet` caches carry the node (grep over all 39; no lib
   module ever used `.*name`); stated honestly: this rests on the
   cache-content census, NOT on `infrastructure-stale?`. Owner-WIP noise
   named eyes-open: `foray.prologos` (~18 live new-surface lines) +
   `today.prologos` (a live `.{` mixfix line) are ungated and will change
   behavior loudly across P1b/P3 — expected, not a regression.

**Test delta**: retirement pins (guided messages + file-continues E2E) in
`test-path-selection.rkt`; reader pins in `test-parse-reader.rkt`; the 5
`m[:kw]` flips in test-postfix-index-01/-03; the `#.name` + `m[k]`-variable
must-not-break pins; the conservative-default replacement pin; net-new reject
pins. Both modes where the surface exists in both. Failing-test-first.
Status: ✅ (see this section's close notes / the tracker).

<a id="p1b"></a>

### §5.P1b — The seams + the Q8 grammar  (SPLIT THREE WAYS, Q_M2)

**Mini-audit `wf_d0862784-5e5`** (6 facets + completeness critic @ `bc0c7578`;
27 critic findings, 22 capture gaps; load-bearing claims R-lens-verified on the
main thread). **9th consecutive phase whose premise the audit refuted.**

**The audit record — grounded facts P1b-i/ii/iii build on:**

- ⚠ **THE HAZARD IS INVERTED.** §5.P1b previously said "the SIX-site
  co-update (five parse-reader sites + the P1a-cleaned surface-rewrite)",
  which reads as DISCHARGED. It is not: `surface-rewrite.rkt:516` is the
  **general brace-opener arm**, alive, needing `dot-lbrace` as a **POSITIVE
  ADDITION**. Probe-verified: the spec flagship
  `app-config{server^.{ssl port} version}` groups **CORRECTLY TODAY** —
  `((app-config ($brace-params server^ |.| ($brace-params ssl port)
  version)))` — precisely BECAUSE `.{` lexes as two tokens and `lbrace` is
  handled at :516. Minting the token without that arm stops it firing, the
  inner `}` closes the OUTER block, and `version` is expelled. **P1b would
  REGRESS a currently-correct grouping** — the opposite of the "inert until
  wired" assumption the risk framing carried.
- **"Match your siblings" would INHERIT A LIVE BUG here.** `dot-lparen` is
  ABSENT from surface-rewrite entirely (0 grep hits), and that absence is a
  latent defect: `(a .( b ) c)` mis-groups at the tree layer with `c`
  EXPELLED. The ACTION (add the arm) is right; the precedent's FACT (no arm)
  must not be copied. P1a's lesson, inverted.
- **`hash-lbrace` is the complete-coverage precedent** (6/6 sites) — see Q_M5.
- **The `.` duty count is SIX, not four**: `.k` · `.N` (P2) · `.*` (retired,
  token still lexes) · `.{` · `.(` · `...` **plus** (5) the single-char
  FALLBACK — which is what `.{`, `.N` and a standalone `.` all hit today —
  and (6) the DECIMAL POINT inside number tokens (`3.14` → one token; the
  `v.0` vs `3.14` boundary is exactly what P2's `.N` must respect). Also
  `.-1` LEXES CLEANLY as dot-access with field `-1` (`ident-start?` includes
  `-`), so the carried "`.-1` = classifier rejection" ruling is about an
  existing well-formed token, not a shatter.
- **Priority numbers are DECORATIVE where they tie**: dot-lparen and
  broadcast-access both sit at 87; nil-dot-key and nil-dot-access both at 92.
  The registry is a plain mutable hash sorted by descending priority — ties
  break by UNSPECIFIED hash order. **Prefix-disjointness, not priority, is
  the safety property**; Q8 owes this as a standing invariant line, and a new
  `dot-lbrace` must take a unique priority without relying on one.
- **The registry has ONE hard-coded site, not two**: macros.rkt:2434/:2438
  (coordinates were stale by +3 after P1a). driver.rkt:3337 is
  `handle-foreign`'s `(foreign racket "module" …)` IMPORT DECLARATION — a
  different form with no brace. Q8 must decide explicitly whether the registry
  unifies block-head languages with import-declaration languages.
- **A zero-dependency LEAF MODULE is the only registry option with in-tree
  precedent**: there is NO cross-module registration idiom into parse-reader
  (its token-pattern registry is module-private, zero external callers), while
  four leaf-module precedents exist (`tropical-fuel-primitives.rkt`,
  `definition-entry.rkt`, `derivation-chain-types.rkt`, `source-location.rkt`)
  — one naming cycle-safety as its own rationale. The parameter option is
  additionally disqualified by the collection-path trap.
- **`(pair? result)` protects MORE than recorded**: 13 opener-adjacent lines
  in `.prologos` (9 of them ACCEPTANCE-gated) **plus 16 more in suite-gated
  test files**.
- **The sexp `.{` fan-out is ~2× the recorded size**: 27 test-cases / 50
  occurrences in `test-selection-paths.rkt` + 4/4 in `test-path-expressions`.
  Q_L2's isolation claim CONFIRMED (both route through
  `prologos-sexp-read-syntax`, never the WS reader).
- **A THIRD already-silently-broken-in-WS surface** in this neighbourhood: the
  WS side of the `selection` form (WS yields `:address` + loose `|.|` +
  `$brace-params`, never the trailing-dot string the validator splits) —
  alongside the narrow-var one and the `<` swallow. Recorded, not scoped in.
- **Bucket 4 (closing-delimiter-adjacent: `f[x]{a}`, `(g y){a}`, `{:a 1}{b}`)
  has ZERO live sites** — a free decision, but `(pair? result)` is TRUE for
  all three, so a naive `is-postfix?` generalization classifies them as select
  blocks by accident. P1b-iii must DECIDE, not discover.
- **Q8 owes a binder-adjacency THREE-WAY split**: `[fn [x :Int] x]` and
  `defn s [x :Int]` ACCEPT the spaced form (adjacency-blind); `parse-rel-params`
  (defr) EXPLICITLY ERRORS on it; expression position is where adjacency
  decides. Three positions, three rules.
- **Two additional opener enumerations, both currently inert** and excluded
  from "the six" with reason: parse-reader.rkt:1585-1586 (the disambiguator's
  negative-prefix list, a no-op arm today) and tools/golden-capture.rkt:89
  (dev tooling).
- **A SEVENTH site is conditional on a decision P1b-ii must make**: whether
  `dot-lbrace` mints a NEW GROUP TAG. surface-rewrite.rkt:519 derives the tag
  from the token type; a new tag needs a tree-parser dispatch arm or it hits
  the "Unhandled form" fallthrough. Reusing `'brace-group` avoids that but
  ERASES the `.{` distinction from the tree spine, which P3 will need.

<a id="p1b-i"></a>

### §5.P1b-i — Repairs, probes, and the Q8 draft  ✅ `fc65ca54`

**Intent**: land the repairs and settle the probe-decided items, so Q8 is
WRITTEN FROM measured facts rather than leans. No new surface syntax.

1. **THE Q_M1 POSITION PROBE — FIRST, and gating.** Hunt expression-position
   `:0`/`:1`/`:w`/`:m` in both modes and across the corpus at HEAD. If ANY
   exists, ruling Q_M1(b) re-opens BEFORE anything is built on it. (The seam
   has refuted position-disjointness once already.)
2. **The WS narrow-var repair** — a **MISSING JOINER, not a missing
   splitter**, so the standing no-second-splitter rule is satisfied. WS
   already delivers `?x` and `:Nat` as separate adjacent datums (probe:
   `[add ?x:Nat ?y:Nat] = 5N` → `((= (add ?x :Nat ?y :Nat) …))`); fusing them
   at the `=`/`#=` arms leaves `collect-narrow-vars+constraints`,
   `rewrite-constrained-vars`, `narrow-var-base-name` and
   `narrow-var-constraints` ALL untouched, and is a provable no-op in sexp
   mode — the two modes CONVERGE. Reuse `fused-type-annot?` (parser.rkt:5420)
   as the recognizer; do NOT reuse `split-fused-symbol` (it rejects chains,
   which the narrowing surface pins as supported). ⚠ Coordinates were STALE
   by 44 lines: `narrow-var-constraints` is at **:6915**, call sites
   **:3057/:3063/:3082**. Replace the VACUOUS pin
   (test-constraint-chain-01.rkt:186-193 — passes on substring `"x"`).
3. **The top-level `<` swallow fix (Q_M4)** — bound `langle-matched?`'s scan
   at the next top-level form start; plumb `content-line-indices` (already
   computed at Domain 2) into `make-bracket-depth-rrb` (Domain 4). Must admit
   CONTINUATION lines, reject NEW-FORM lines. The `31d27c83` pins
   (test-parse-reader.rkt:499-547 ×8 + test-mixfix-02.rkt:359-416 ×7) are the
   gate. **Failing-test-first on the `def p := 1 < 2` / `def q := 3 > 4`
   repro.** If messier than plumbing suggests: STOP and re-checkpoint.
4. **`def ?x` → guided error (Q_M3)**, riding the P1a marker seat.
5. **The remaining probes**: keyword-trailing `*` (confirm `recognize-keyword`
   delegates to `ident-continue?` — that delegation IS the F1b.7g anti-drift
   fix, so the split must happen at a CONSUMER; prior art:
   `validate-selection-paths` already splits `^` string-wise off a keyword
   lexeme and handles a whole-segment `"*"`); `:<` in BOTH shapes (should be
   SAFE once item 3 lands — re-probe to confirm rather than assume).
6. **Q8 DRAFT** from the results — owner-reviewed before P1b-ii/iii land.

**Test delta**: narrow-var real pins (replacing the vacuous one); `<`-swallow
pins both directions (swallow gone / multi-line angle still works); `def ?x`
guided-error pin; probe results recorded in this section. Status: ✅ `fc65ca54`.

---


> *Here D4 continued elsewhere: D4 4699–4975 (§Q8) → [2026-07-28_CIU_6_D4_LEXICAL_GRAMMAR.md](../2026-07-28_CIU_6_D4_LEXICAL_GRAMMAR.md).*

<a id="p1b-ii"></a>

### §5.P1b-ii — The `.{` opener  ✅ `1a1091d4`

**Mini-audit**: `wf_f91e5aac-df2` (5 facets + completeness critic, HEAD-pinned
`09a1f0d7`; a first run `wf_e34bc9f3-6a8` died on an auth expiry with zero
results). Every load-bearing finding below was **main-session R-lens-verified**.
It refuted the design on three points and **inverted the phase's hazard model**.

#### What the audit changed

1. **⚠ COORDINATES DRIFTED +136 to +148** on all five parse-reader cites (P1a +
   P1b-i both inserted). Only `surface-rewrite.rkt:516` was exact. HEAD truth is
   the table below. *Ninth consecutive phase with drifted coordinates.*
2. **⚠ THE HAZARD MODEL WAS INVERTED.** The design said a missing tree-parser
   arm "hits the *Unhandled form* fallthrough" — i.e. LOUD. **False.**
   `"Unhandled form"` (tree-parser.rkt:119) lives inside the nested `case` of the
   **top-level-form** arm; a GROUP tag can never reach it. The reachable arm is
   **tree-parser.rkt:189-193**, which calls `parse-expr-tree` **SILENTLY**
   whenever the node has children — always true for a brace group. Worse,
   `driver.rkt:2457-2459` admits tree output when *non-error ∧ same-form-type ∧
   same-line*, so **a silent garbage surf can BEAT preparse's correct one**. A
   missing arm is a silent-wrong-answer, not an error.
3. **⚠ THE "NEW TAG NEEDS AN ARM" OBLIGATION HAS THREE LIVE COUNTEREXAMPLES**:
   `set-group`, `at-group`, `tilde-group` are minted at surface-rewrite.rkt
   :519/:527/:528 with **zero** tree-parser arms and zero non-test consumers —
   they already ride the silent :189-193 path. Verified. Whether that is benign
   for them is **UNVERIFIED → filed** (DEFERRED), not assumed.
4. **MY OWN QUESTION'S PREMISE WAS WRONG.** I asked whether `dot-lbrace` belongs
   in the "langle skip-set" at all, reasoning a select block is not mixfix. The
   lists at :1427-1428 / :2504-2506 are **OPENER DEPTH-BALANCING** sets (paired
   increment/decrement inside the langle lookahead), **not** suppression sets.
   Adding `dot-lbrace` is **REQUIRED**; omitting it causes TWO failures — a
   spurious no-rangle-match, and a **WRONG-FRAME POP** in the frame dispatch
   (the `31d27c83` class). Angle suppression is separately keyed on frame kind
   `'mixfix` (:1442/:1458/:1465), which a `'brace`/`'rbrace` frame never sets —
   so **type-level angle groups keep working inside a select block**, which is
   the behaviour we want, and it falls out of Q_M5 rather than needing a rule.
5. **Q_M5 VALIDATED HARDER THAN ARGUED**: because the closer is plain `'rbrace`,
   **ZERO closer-side edits are needed** — every closer enumeration already
   lists `rbrace` (parse-reader.rkt :1430/:1470/:2507/:2734; surface-rewrite.rkt
   :504/:533). A sentinel closer would have added six sites **and** needed 4+
   translation arms (`langle-matched?` :1433 has NO translation; its twin
   :2510-2513 DOES — the asymmetry is itself the hazard).
6. **THE INVERTED HAZARD IS CONFIRMED AND SILENT.** Probed: the flagship groups
   correctly today (`(root (line app-config (brace-group server^ |.| (brace-group
   ssl port) version)))` — the surviving `|.|` is the direct evidence that `.{`
   lexes as two tokens). Without the :516 addition an unarm'd opener falls to
   surface-rewrite.rkt:539-540 `[else …]`, the inner `}` closes the OUTER group
   at :504-506, and the real outer `}` is discarded by the stray-closer arm
   :532-534 — **a silently wrong tree, no raise**.
7. **IT IS ≥8 EDIT REGIONS, NOT 6**: the recognizer is a separate edit from the
   registration, and surface-rewrite.rkt needs **:516 AND :519** unconditionally
   (the two-way `if` has no arm for a third token type — so :519 is not the
   "conditional seventh site" the design priced, it is mandatory either way).

#### The rulings [owner, 2026-07-28]

- **Q_N1 — TWO decisions, one layer apart; BOTH mint new.** The design named only
  the tree tag. There is a parallel **datum-layer** decision: which SENTINEL HEAD
  the new `group-items` arm emits (siblings mint distinct ones — `lbrace`→
  `$brace-params`, `dot-lparen`→`$mixfix`, `hash-lbrace`→`$set-literal`).
  **Ruled: new sentinel `$dot-brace` + new tree tag `'dot-brace-group` + write
  the tree-parser arm.** Rationale: (a) reusing `$brace-params` would give `.{`
  the **implicit-type-binder** meaning and a large consumer surface (driver
  capability extraction, form-cells, ~30 library sites) — the genuinely dangerous
  reuse, worse than the tree tag; (b) reuse is lossless *today* only because the
  loose `|.|` token survives grouping, and **P1b-ii's own mint destroys that
  signal** — a one-way loss, not a neutral choice; (c) **srcloc cannot recover
  it** — verified: `group-items-to-tree` is entered with the enclosing node's
  srcloc and all four mint sites (:501/:513/:520/:530) reuse the same binding, so
  every group in a form shares one srcloc, and the opener token is consumed.
- **Q_N2 — the `.( )` sibling bug is FILED, not fixed here.** It is real and
  worse than recorded: a **LAYER DIVERGENCE**, not a mis-group — probed,
  `(a .( b ) c)` keeps `c` at the datum layer (`((a ($mixfix b) c))`) and
  **EXPELS** it at the tree layer (`(root (line (paren-group a |.(| b) c))`), at
  zero errors. Not fixable by an arm: the `'mixfix-group` tag and its ~445-line
  consumer were DELETED at P1a, so a new arm has no tag to emit but
  `'paren-group` (erasing the distinction), and the angle half needs a `'mixfix`
  frame concept `group-items-to-tree` does not have. No test pins `.( )` at the
  tree layer either. → DEFERRED.
- **Q_N3 — ADD THE STRUCTURAL GUARD.** Nothing pins *"every registered opener
  token type has an arm in BOTH groupers."* surface-rewrite.rkt:539 is a bare
  `[else]` catch-all in a transforming walker — the exact red flag
  `pipeline.md` § Exhaustive Walkers names, and precisely the class that produced
  the `dot-lparen` bug. A contract test censusing the token-pattern registry's
  opener names against both arm lists makes the class impossible **by
  construction** rather than by checklist.

#### The edit regions (HEAD `09a1f0d7`, all re-verified)

| # | Site | HEAD coord | Edit |
|---|---|---|---|
| 1 | `recognize-dot-lbrace` | new, beside `recognize-dot-lparen` :756 | `.`+`{` → 2 |
| 2 | registration | :1136-area (dot band) | priority **87** (sibling of `dot-lparen`; safe by DISJOINTNESS, not number — Q8.5 inv. 1) |
| 3 | `langle-matched?` opener set | :1427-1428 | append `dot-lbrace` |
| 4 | frame dispatch | :1453-1454 | append to `'(lbrace hash-lbrace)` → `(cons 'brace 'rbrace)` |
| 5 | `has-matching-rangle?` opener set | :2504-2506 | append `dot-lbrace` — **identical to #3, the twin** |
| 6 | `group-items` arm | after the `lbrace` arm :2639-2645 | new arm → `$dot-brace`, closer `'rbrace`, srcloc span **2** |
| 7 | surface-rewrite.rkt | :516 **and** :519 | memq gains `dot-lbrace`; the tag `if` becomes a `cond` |
| 8 | tree-parser arm | :128-135 arm set | `[(dot-brace-group) …]` |

⚠ **Priority 90 is NOT free** — it is `char-lit` (:1182). Only 81, 82, 94 are
unused in 80-99. (We use 87 regardless; recorded so the next reader does not
interpolate.)

#### Test delta

- **Three flips**, not two: test-parse-reader.rkt:401-406 (`check-false (assq
  'dot-lbrace …)` — INVERTS) · test-mixfix-01.rkt:54-58 (compat-path
  `check-exn` — flips because the standalone-`.` rejection is **token-type**
  keyed, so folding both chars into one non-symbol token makes it unreachable) ·
  **test-mixfix-01.rkt:332-342** (a Level-3 WS pin the design never named).
- **The flagship needs an EXPLICIT NEW PIN — the corpus A/B cannot see it.**
  Verified: exactly **ONE** live non-comment `.{` exists in all 160 corpus files
  (`examples/2026-03-20-first-class-paths.prologos:331`); every
  `app-config{server^.{…}}` line in our own acceptance file is `;;`-commented.
- **The A/B must compare succeeded/failed TALLIES, not only `.golden` contents**:
  `tools/golden-capture.rkt:83` calls `tokenize-string`, whose standalone-`.`
  rejection is exactly what flip 2 disables, and it swallows per-file exceptions
  into a FAIL counter — so a file may move FAIL→SUCCESS, a diff of a different
  shape.
- **The Q_N3 guard** as a contract test.
- A **third opener enumeration** exists in the test oracle
  (tests/test-parse-reader.rkt:1015-1019, a verbatim copy of the production
  8-member list) — the guard should cover it or it drifts.

**Acceptance delta: ZERO markers uncommented** (P1b makes forms LEXABLE; the
semantics are P3's, and the file ties uncommenting to a verified result).

#### CLOSE NOTES ✅

**Gates**: suite **9279 / 474 / 0** · acceptance **28/28 + 89/89** · neighbourhood
battery 443/443 (incl. both sexp `.{` files and all three defmacro files) ·
**corpus A/B: 158 files, ONE diff, intended** — `first-class-paths.prologos:331`,
form count unchanged 52→52, `app-config |.| ($brace-params …)` →
`app-config ($dot-brace …)`.

**⚠ THE A/B WAS WRONG THE FIRST TIME, AND THE FAILURE IS INSTRUCTIVE.** Run 1
reported **5 diffs** — which were *exactly* the 5 owner-modified `.prologos`
files. Both legs read from different trees, so it compared *content*, not
readers. Re-run with both legs reading identical HEAD content and only the
reader differing → 1 diff. **This is the same dirty-tree trap that made two
facets of the P1 audit "refute" a correct design count.** An A/B over a dirty
tree measures the tree, not the change: pin BOTH legs' inputs, not just the code.

**⚠ ADVERSARIAL VERIFY CAUGHT A BLOCKING REGRESSION — MINE — AND THE SUITE WAS
GREEN.** `$dot-brace` was missing from `pattern-var?` (macros.rkt), so the new
sentinel read as a macro PATTERN VARIABLE: `.{ }` inside a defmacro **template**
made `datum-subst` raise, i.e. a **whole-file abort with zero results**, where
the same source gave a per-command error before the token existed. It is the
exact P1a headline defect class, at the exact site P1a fixed for
`$dot-key`/`$nil-dot-key` — **and Q8.5 invariant 3 names this obligation
explicitly**. I wrote that invariant and then did not follow it. Fixed +
pinned; the pin exercises macro **USE**, because P1a's sibling pin only
registers a macro and registration is harmless — a registration-shaped pin stays
green through the whole defect.

**The guided error was also wrong at first**: `.{ }` reported *"Unbound
variable"* until it was routed through P1a's marker seat — telling a user their
valid new syntax had a missing variable. Now: `` `.{ }` select blocks are not
supported yet — path selection lands them in CIU Track 6 P3. Field access works
today: `x.name` ``, per-command, file continues.

**Three SIGNIFICANT findings, all verified NOT regressions → DEFERRED items 3+4**:
the guided error is unreachable in arity-checking contexts (map literal, `fn`
params, `validate`) because `$dot-brace` stays a *sibling* item until P1b-iii
fuses it — ordering-dependent, named not fixed; `.{ }` inside `.( )` aborts; and
inside a parenless `defr` goal it is silent. The `.( )` one shares a root with a
pre-existing family: **`$set-literal` and `$mixfix` are ALSO still pattern-vars**
and abort identically in a macro template. DEFERRED item 3 records the
structural reading — `pattern-var?` is a hand-maintained NEGATIVE list whose
default is "pattern variable", the same inverted polarity `definitely-not-map?`
had before P2.b slice 1 inverted it. More exclusions is not the fix.

**What the Q_N3 guard bought**: it caught the third opener enumeration
immediately — the test oracle's verbatim copy of the production list
(test-parse-reader.rkt:1015) reported a real example file as unbalanced until
`dot-lbrace` was added there too.

Status: ✅ `1a1091d4`.

<a id="p1b-iii"></a>

### §5.P1b-iii — Brace adjacency + the head registry  ✅ `a6af2761`

**Mini-audit**: `wf_18992d66-b81` (6 facets + completeness critic, HEAD-pinned
`88b3019a`). Main-session R-lens-verified. It found a **BLOCKING problem with
Q_M8** and **located the root cause of P1b-ii's carried residual**.

#### ⚠ BLOCKING — Q_M8 as ruled would ship a SILENT WRONG ANSWER

The ruling's safety premise ("`:10` is rejected by the SAME `memq` arm that
already rejects `:7` — no new failure mode") is **FALSE for the 2-element `defn`
bare-param shape**. Probe-verified at `88b3019a`:

| Source | Result today |
|---|---|
| `defn g [x :7] x` | **SILENTLY ACCEPTED** → `g : [Pi [x :0 <[Type 0]>] x -> x]` — `:7` consumed as a **TYPE NAME**, a different function, 0 errors |
| `defn g [x :10] x` | LOUD parse-error |
| `defn g [x :0] x` | LOUD parse-error |
| `defn g [x :1] x` | LOUD parse-error |

So the *valid* multiplicities are loud here and **`:7` is the anomaly**.
Widening makes `:10` lex like `:7` — moving it **LOUD → SILENT WRONG**.

**Root cause — a site NO enumeration names**: `fused-type-annot?`
(parser.rkt:5459-5460) is a **SECOND hard-coded colon enumeration**, excluding
exactly `'(:0 :1 :w :m)` — four lexemes — against a recognizer minting **twelve**.
Everything outside those four falls through and is consumed as a type name. Its
own comment eight lines above warns *"a second copy is how the two paths would
drift"* — while being exactly that.

**Q_N4 [owner]: WIDEN THE SCOPE.** Fix `fused-type-annot?` **structurally**, not
by extending the list: **no type name starts with a digit**, so a digit-headed
colon symbol is never a type annotation. This co-migrates with the recognizer
widening AND **repairs the pre-existing `:7` silent-wrong-answer**. Q_M8 done
correctly makes the language *more* sound, not less.

#### The carried residual has a LOCATED cause

**`access-sentinel?` (macros.rkt:5446-5450)** gates the left-fold that fuses a
sentinel onto its base. It lists six predicates; `$dot-brace` is not among them —
verified, macros.rkt has exactly two `dot-brace` mentions, both the P1b-ii
`pattern-var?` fix. **That single omission IS the unreachable-guided-error gap.**

And **adjacency does NOT fuse** (Q4 answered: NO). `is-postfix?` only MARKS —
`xs[0]` yields two siblings — and the consuming fold lives one layer down in
`rewrite-dot-access`, gated by `access-sentinel?`. **Corollary the phase
inherits**: the new select sentinel reproduces the identical gap on day one
unless it also gets a predicate + an `access-sentinel?` entry + a fold arm.
Closing P1b-ii's residual and not opening a new one are **the same edit** — in
`macros.rkt`, a file this phase's stated scope ("entirely tokenizer/grouping")
does not name.

#### ⚠ Scope the design MISSED ENTIRELY — and it is worse than P1b-ii's

**§5.P1b-iii never mentions `surface-rewrite.rkt`**, the second grouper, which
has **ZERO adjacency machinery** (grep for `end-pos|start-pos|postfix|adjacen`
→ 0 hits). The two groupers therefore ALREADY diverge in shape on `xs[0]`
(datum `($postfix-index 0)` vs tree plain `bracket-group`).

Why this is worse here: `brace-group` already has a **NON-ERROR** tree handler
returning a map literal, and driver's error-recovery arm (driver.rkt:2557-2560)
lets a non-error tree surf **REPLACE** preparse's error surf. So a
parse-reader-only implementation does not merely lose a diagnostic — **the guided
"not until P3" error is SILENTLY SWALLOWED and the user gets a plausible wrong
map.** → **Q_N7 [owner]: implement adjacency in BOTH groupers.**

#### The rulings [owner, 2026-07-29]

- **Q_N4** — Q_M8 widens in scope: recognizer digit-run `digit+` **plus** the
  structural `fused-type-annot?` fix (see above).
- **Q_N5 — BUCKET 4 IS RULED "SELECT", EXPLICITLY.** ⚠ Inaction is **not** the
  status quo: for `f[x]{a}` **both** `is-postfix?` conjuncts already pass (the
  previous raw-vector item is the `rbracket`, byte-adjacent and
  `token-entry?`-passing; `result` already holds `f` + the postfix group), so a
  naive generalization rules bucket 4 **by accident**. The bracket band already
  answers the analogous question affirmatively (`xs[0][1]` chains through
  `is-postfix?` off an `rbracket`). Ruled to MATCH that precedent — by decision,
  not by default. Zero live sites (census: 160 files, 0 hits).
- **Q_N6 — the binder hazard is ACCEPTED.** `defn f{x} x` is a binder today
  (`($brace-params x)`, byte-identical to the spaced form) and becomes a select
  block after. **Zero live adjacent-brace binder sites**, but the exposure is
  real: **419 of 622 live spaced braces are implicit type binders** (vs 202 map
  literals — a 2.07× margin), and **384 of 622 sit immediately after an
  identifier on the same line**, i.e. one deleted space away. Accepted; **both
  spellings get pins**. No diagnostic attempted — grouping has no position
  concept, so it cannot tell binder position from expression position.
- **Q_N7** — adjacency lands in **both** groupers (above).

#### Q8.5 invariant 3 was UNDER-SPECIFIED — corrected in §Q8

It named two registrations. The audit's answer to Q1 is **NINE real ones**, and
**one of the two it named is a NO-OP**: the tree-parser memq (`:662`) is dead
code — both cond arms terminate in a `(char=? (string-ref s 0) #\:)` test, so a
`$`-headed item fails regardless, and every member of the list starts with `$`
or is `quote`. **The invariant written one commit before P1b-ii's regression, to
prevent exactly it, listed one real item and one no-op — under-specifying by
precisely the amount that let the regression through.** §Q8.5 is corrected.

#### Other audit findings folded

- **Coordinate drift, ELEVENTH consecutive phase**: `recognize-colon-annotation`
  is at :871 (design said :847); `is-postfix?` at :2631 (design ~:2441);
  `combine-foreign-blocks` at :2438 (design ~:2431 — which is `arrow-sym?`).
- **The head "registry" is ONE site, not two.** driver.rkt:3335-3339 is
  `handle-foreign` guarding the `(foreign racket "mod" …)` DECLARATION — head
  symbol `foreign`, `racket` in arg-1, a STRING required next. It never meets a
  brace group. The single grouping-relevant site is macros.rkt:2447. *The "no
  module edge" half stands, and so does the leaf-module conclusion.*
- **Registry home**: `parse-reader.rkt` requires only rrb/propagator/parse-lattice
  and `macros.rkt` does not require it — so a **new leaf module** requiring
  nothing project-local can be required by both with no cycle. `surface-rewrite`
  already requires parse-reader, so it inherits.
- **The editors already diverge**: `editors/emacs/prologos-mode.el:119` and
  `prologos-font-lock.el:220` hard-code the literal **adjacent** `"racket{"`, so
  the editor already requires adjacency while `combine-foreign-blocks` does not.
  P1b-iii *closes* a divergence — but a Racket-side registry cannot reach `.el`,
  so the residual is NAMED as accepted.
- **The back-compat pin the design leans on is SEXP-ONLY** and constrains nothing
  in WS (test-foreign-block's `run-ns` calls `process-string`; sexp `{`→
  `$brace-params` comes from the positionless readtable). The real justification
  for the head carve-out is the **10 live WS adjacent sites**.
- **`$brace-params` is ≥7-purposed → actually ELEVEN** (ten source-level + two
  synthesized). Missing from the design's list: spawn/session overrides
  (parser.rkt:6555), **schema construction `Person {…}` (macros.rkt:2011, 24 LIVE
  SITES — the closest semantic neighbour of a select block, all spaced)**, spec
  metadata blocks (nested brace-params), schema defaults injection (rewrites in
  place). **Independent corroboration of Q_M6**: the only existing
  map-vs-binder discriminator is CONTENT-based (first element is a keyword) and
  lives in preparse — a select block `x{name age}` has BARE-SYMBOL content, so
  reusing `$brace-params` would route select blocks into the binder path.
- **The opener-adjacent population is ~2× the design's 13** — 13 in `.prologos`
  plus 14 live `'[{` in `.rkt` test strings plus `#p({name email})` ≈ 28. If
  `(pair? result)` is dropped, every list-of-maps literal mis-reads its **first
  element only**, at zero errors.
- **⚠ THE GENERALIZATION SHAPE**: `lbrace` must **NOT** join the
  `(memq type '(lbracket lparen))` arm — that arm's closer is a two-way `if`
  selecting `'rparen` for anything not `lbracket`. **Identical to the shape
  P1b-ii hit in surface-rewrite.rkt.** Correct: hoist the adjacency test into a
  named helper consumed by both arms, leaving the brace arm's `'rbrace` intact.
- **P1b-iii FLIPS the P1b-ii FLAGSHIP pin** (test-parse-reader.rkt:438-442),
  written one commit ago — `app-config` is not a reader-form head, so that brace
  becomes a select block. §5.P1b-iii's test-delta named only "NET-NEW `racket{…}`
  pins"; a flip discovered at suite time reads as a regression.
- **The Q_N3 guard is STRUCTURALLY BLIND here, twice**: every row is uniformly
  SPACED (exactly the population that must not change), and it compares ITEM
  COUNTS while this phase's defect class is a **shape divergence at equal
  count**. The pre-existing `xs[0]` case proves the blindness is live. → extend
  it to be shape-aware.
- **⚠ THE A/B TRAP IS PRIMED AT THE WORST FILE**: `lib/examples/foreign.prologos`
  holds **10 of the 12** adjacent sites (83% of the surface) and **is one of the
  6 dirty `.prologos` files** (+19/−3 owner WIP). Both legs must read from a
  materialized `git show 88b3019a:` snapshot. Expected-diff set is **EMPTY for
  both halves** — any non-empty result is a bug, not a change to review.
- **Correction**: the design's "six currently-PASSING markers at RISK" does not
  reproduce — the acceptance file has exactly **two** live ident-adjacent bracket
  sites (`:122 party[0].name`, `:216 mixed[1]`).
- **`(> i 0)` is REDUNDANT** today — `(pair? result)` subsumes it — and becomes
  load-bearing only if that conjunct is removed.

#### The nine-tier registration surface (from Q1; §Q8.5 now carries it)

Not in scope here (no new TOKEN — the decision is positional at grouping): the
five token-layer enumerations P1b-ii co-updated. **In scope**: `group-items`
brace arm · `group-items-to-tree` (SILENT + load-bearing) · tree-parser dispatch
arm (its `else` silently calls `parse-expr-tree`) · `pattern-var?` (LOUD
whole-file abort — the P1b-ii regression) · preparse opacity (macros.rkt:1988) ·
sub-form recursion skip (:2536) · `combine-foreign-blocks` head (:2444) ·
**`access-sentinel?` + the `rewrite-dot-access` fold arm — named by NO
enumeration, and the site that produced the residual** · the parser head-dispatch
arm. Silent-degradation tier, pre-existing and family-wide, NOT chargeable here:
`pp-datum` (handles 11 heads, no access sentinels at all) and
`tools/form-deps.rkt:42`.

---

#### CLOSE NOTES ✅

**Gates**: suite **9304 / 474 / 0** · acceptance **28/28 + 89/89** · battery 501/501 ·
**corpus A/B 158 files, ZERO diffs on both halves** — the audit predicted an empty
expected-diff set and it held.

**⚠ ADVERSARIAL VERIFY CAUGHT THREE BLOCKING DEFECTS, ALL ONE ROOT CAUSE, ALL MINE.**
The fusion arm I added to `rewrite-dot-access` was **not idempotent**: it rewrote
`(x base ($select-brace a))` to `(x ($select-brace base a))` — still sentinel-headed,
so `select-brace?` matched it again. Since `preparse-expand-subforms` re-enters while
the datum keeps changing, each pass swallowed one more sibling to the LEFT:

| consequence | observed |
|---|---|
| multi-arity `defn` clause | `$pipe` head eaten → **clause SILENTLY DROPPED**, function evaluated with the wrong arms, **0 errors** |
| `defn g [x base{a}] x` | silently defined a **4-parameter** function |
| application head | `(h base ($select-brace a))` → `($select-brace h base a)` |

Every OTHER access-sentinel arm rewrites the sentinel AWAY (to `get`/`map-get`) and is
a fixpoint **by construction** — their predicates pin a fixed arity. Mine deliberately
accepted `>= 1`, which removed exactly that protection. **Fixed** by emitting the
NOT-YET marker (`$retired-selection` with a new `select-block` kind) — a non-sentinel
head, hence a fixpoint, and zero new registrations since that sentinel is already in
`pattern-var?` and already has its parser arm. Idempotence is now test-pinned.

The irony is worth recording: this phase's Q_N4 hunk exists to repair a
silent-wrong-answer, and the same commit introduced one.

**SIGNIFICANT findings — fixed in-phase:**
- **The registry did not do its job.** `reader-forms.rkt`'s docstring said "this is the
  ONE list" and that both grouping and preparse require it. **macros.rkt required it
  zero times** and `combine-foreign-blocks` still tested an inline `(eq? v 'racket)` —
  two lists, and the module unified nothing. Now wired; `lang` is derived from the head
  rather than hard-coded.
- **A VACUOUS PIN of my own.** A test titled "reachable inside fn params too" asserted
  on `[fn [x : Int] cfg{host}]` — the select block is in the **body**; the param list
  was untouched. It passed for a reason unrelated to its name. Renamed, and the real
  param-list case added.
- **The Q_N7 justification was FALSE.** The comment claimed that without the
  surface-rewrite fork the guided error "would be SILENTLY SWALLOWED". Disproved by
  construction (a third checkout, byte-identical output over 20 files):
  `same-form-type?` only pairs surf-infer/def/defn/defn-multi, so a preparse ERROR surf
  can never pair with a non-error tree surf — **preparse always wins when it errors**.
  The fork is KEPT (the groupers should agree, and the Q_N3 v2 guard pins it) but the
  justification is corrected in both the comment and here.
- **My diagnostic gave advice that does not work**: it recommended `[x : Int]`, which
  the defn form-shape gate rejects in the very shape that raises the error. Now
  recommends only `[x:Int]`.
- **The `pattern-var?` residual is 23 of 33, not 2** — including `$list-literal`, so a
  plain `'[1 2]` in a defmacro template is a whole-file abort TODAY. Comment corrected;
  DEFERRED item 8 carries the census.

**Filed, not fixed** (DEFERRED items 5–8): the two groupers still diverge on
`<`-adjacent braces — live at `foray.prologos:674`, on the **disclose surface P4 owns**;
binder-position select blocks get a raw-syntax diagnostic rather than the guided error;
and the `pattern-var?` polarity problem.

**What the Q_N3 v2 guard bought**: it is now shape-aware (tag ↔ sentinel across six
brace spellings) where v1 was blind twice over — all its rows were spaced, and it
compared counts when the defect class is shape-at-equal-count.

Status: ✅ `a6af2761`.

**Original design text (superseded in part by the above):**

The forced select-block sentinel (Q_M6) for the non-head-adjacent bucket only;
head-adjacent keeps `$brace-params` UNCHANGED (the spaced-`racket {…}`
back-compat pin, test-foreign-block.rkt:155-160). Leaf-module registry.
Generalize `is-postfix?` beyond `lbracket` while KEEPING `(pair? result)`.
Rule bucket 4. NET-NEW WS `racket{…}` pins — all 13 existing foreign-block
cases pass PARENTHESIZED SEXP source that never reaches `group-items`, so the
head-precedence rule is UNTESTABLE from them; 2 of the 10 live WS sites are
MULTI-LINE bodies, the shape most exposed and the one a single-line pin
misses. Sentinel registration checklist: `pattern-var?` + tree-parser
skip-list.

⚠ **Q_M8 — the `:N` DIGIT RUN WIDENS TO N here.** `recognize-colon-annotation`
(parse-reader.rkt:847) is hard-capped at 2 chars; widen its digit run to
`digit+` (keeping the `:w`/`:m` arms and the trailing `not ident-continue?`
guard, so `:0abc` still declines). This rides P1b-iii because until broadcast
exists `users:10` has no meaning. **Why it is safe, measured**: the recognizer
already accepts 12 lexemes while `mult-annot?` accepts 3, so `:10` is rejected
by the *same* `memq` arm that already rejects `:7` — no new failure mode. It
additionally repairs `{:10 v}`, which SHATTERS today while `{:0 v}`/`{:9 v}` do
not. Zero live `:2`–`:9`/`:m` uses, so nothing live moves. **Owes a corpus
A/B** (tokenizer change) and a pin on both halves: `users:10` one token, and a
binder-position `:10` still loudly rejected.

Status: ✅ (see this section's close notes / the tracker).

**Acceptance delta for ALL of P1b: ZERO markers uncommented** — every line
P1b makes LEXABLE is a P3/P4/P5 SEMANTICS target, and the file's convention
ties uncommenting to a verified `;;N=>` RESULT; there is no honest result for
"this now tokenizes." Reader pins go to `test-parse-reader.rkt`. ⚠ Six
currently-PASSING markers are at RISK if `(pair? result)` is dropped.

<a id="p1b-superseded"></a>

### §5.P1b — (superseded framing; see the three sub-sections above)  ⬜

**Work list**:
1. **`.{` = `dot-lbrace` re-mint** (ruling 3a): the SIX-site co-update (five
   parse-reader sites + the P1a-cleaned surface-rewrite). Prefix-disjoint by
   the audit's band proof; the WS-vs-sexp divergence documented per Q_L2.
2. **Brace adjacency with head-symbol precedence** (ruling 3b): the
   positional adjacency mechanism generalized off `lbracket`-only (keep the
   `(pair? result)` conjunct — 13 live sites depend on it); the FOUR-bucket
   census (spaced · adjacent reader-form head · adjacent select-block ·
   closing-delimiter-adjacent) run against HEAD; **the reader-form-head
   REGISTRY created** as the single source of truth consumed by both preparse
   and grouping (new leaf module or registration parameter — the module-edge
   gap is real); NEW WS `racket{…}` round-trip pins (zero exist today).
3. **Colon seam** (Q_L1): broadcast = expression-position adjacency EXCEPT
   `?`-headed subjects (the narrowing discriminator); **the WS narrow-var
   repair scoped in** (route `?x:T` through the POL.6 splitter or equivalent
   at the WS path; replace the vacuous test-constraint-chain-01:186-193 pin
   with a real one).
4. **`:N` multi-digit** — probe-decided at the Q8 review (`{:10 v}` probe +
   both-modes `:digits` census, per ruling 3c).
5. **Keyword-trailing `*`** — contextual split of `:diags*` (no charset
   change; F1b.7g delegation rule).
6. **`:<` probe row** — BOTH input shapes (benign no-`>` AND the depth-0-`>`
   cross-line swallow) in the Q8 grammar.
7. **Q8 — the deliverable**: the precise lexical grammar for the
   juxtaposition-sensitive characters, including the `.` quadruple-duty
   disambiguation ORDER (`.k` / `.N` / `.*`→retired / `.{`) and the `{`
   four-bucket order (reader-form head ≻ select-block ≻ literal; spaced never
   a block). **Owner-reviewed before landing.**

~~`^` is NOT touched in either half (parser-side split at P3, per the standing
ruling — no second splitter).~~ ⚠ **STRUCK**: superseded by **Q_M7** (§3) —
that ruling was NOT EXECUTABLE (`split-fused-symbol` splits on `":"`; the
tree's only `^` splitter is sexp-only AND keeps empty segments). **P3b builds
THE ONE splitter.** Struck rather than left, because "no second splitter" is
a premise that bites exactly at P3b.

**Test delta**: seam pins in `test-parse-reader.rkt` (RRB-native API — the
three-API finding standardizes here) both modes; the WS narrow-var repair pin
(replacing the vacuous one); WS `racket{…}` pins; adjacency-bucket pins incl.
the closing-delimiter bucket and the binder-brace must-not-change population.
Status: ⬜.

