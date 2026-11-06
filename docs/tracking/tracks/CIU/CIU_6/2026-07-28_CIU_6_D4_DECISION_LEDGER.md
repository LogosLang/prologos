# CIU 6 — D4, §3 decision ledger

Part of [D4](2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 198–4232 are lines N-191 here.

---

<a id="s3"></a>

## §3 Rulings ledger

**The spec's standing [owner, 2026-07-28]**: the spec was formed OUTSIDE the
project, idealized — it is a **suggestion and guide, not a prescription**;
adaptation to grounded code reality is expected. Where D4 adapts, the
adaptation is recorded here with its reason.

**Adopted [owner, 2026-07-28]:**
- The spec's **[ADOPTED]** elements are normative for v1 *as adapted below*.
- **Q1 = YES**: map-generic `:` (spec §3.2.3 + §5.4 row-map typing). With it:
  path-position `.*` is subsumed; `.*name`'s migration target is **`:name`**.
- **`v[0]` keeps its current working semantics for now** — the PS2 flip is
  canceled; no census-flip of `v[literal]` sites.

**The D5-critique batch rulings [owner, 2026-07-28]** — note: the "D5 critique"
was a 13-agent adversarial workflow (`wf_2cef0199-18a`, 6 lenses +
refute-by-default verifiers) adjudicated conversationally; it has **no
standalone document**. Its surviving, R-lens-verified findings are recorded in
§2.3 (the carrier table), the rulings below, and §8 (risks):
- **Notation = translation, not spec-editing (Batch 1, option b).** The spec
  keeps its idealized notation; the CORPUS FILE is the adaptation layer,
  written in HEAD's printed forms via the §2.3 translation table. §5.P0's
  normativity protocol is refined: divergence in NOTATION is transcription
  (resolved by the table); divergence in RESULT is semantics (resolved by
  ruling). Fixtures normalize to the `def X` implicit-map form (the
  `def X :=` layout defect is filed — **issue #80** + DEFERRED) and carry
  `defn now`/`defn env` stubs with indicative values.
- **2a — HONEST NESTING ADOPTED (spec §3.3 as written).** A keyless block is
  an n-tuple at every n, including n = 1. Owner rationale: implicit splice
  would break the algebraic properties of path selections; **the disclose
  operator `<`/`:<` is DESIGNED as the unwrap remedy** for wanting the bare
  value (a strong signal on spec Q5 — see the open list). Code reality
  AGREES once seen at the right layer: the tuple carrier is a nat-keyed
  closed record (1-field rows representable; runtime rep = `expr-rrb`, the
  same carrier the landed P2 substrate projects from) — only the LITERAL
  inference arm collapses n=1 to PVec, and selection never routes through
  the literal arm. The block constructor mints nat-rows directly.
- **2b — THE HETEROGENEITY SPLIT ADOPTED.** Spec §5.3's single meet rule is
  adapted per-carrier, because HEAD has TWO het carriers:
  · **Het tuple** (`⟨row₁ row₂ …⟩`, positions statically known — what `@[…]`
    literals produce): broadcast projects **per-position, exactly** — no
    meet needed, and a miss errors NAMING THE POSITION. Strictly stronger
    than the spec's rule where it applies.
  · **PVec-of-union** (`[PVec <A|B>]`, length unknown): the spec's rule,
    restated over UNION COMPONENTS — every component must offer the key
    (keys ⋂), result field type = ⋃. NEW machinery, small, booked at §5.P4.
  · **Polarity note (write it down or it becomes a bug)**: the in-tree union
    projection arm is filter-on-miss (optimistic) and is CORRECT for what it
    serves — a single get on one union-typed value, which IS one branch.
    Broadcast projects EVERY element, so all-must-offer is the sound
    polarity there. Two operations, two polarities, no conflict.
- **2c — Q2 DISSOLVED, off the critical path.** Q2-type: CLOSED by landed
  code (type rows canonically sorted — load-bearing for `equal?`-as-row-
  identity, `syntax.rkt:749-756`, not churnable). Q2-value: **carrier-
  determined (champ) order — DERIVED FROM THE SPEC'S OWN KEY-SORT THESIS**,
  not conceded to the implementation: §1.1 says nominal keys' identity
  carries the meaning and their order does not, so selection-order display
  would contradict the spec's foundation. Corpus markers transcribe to champ
  order (deterministic per key set). §5.P3's gate is REMOVED.

**The Batch-3/4 rulings [owner, 2026-07-28 — all as recommended]:**
- **3a — `.{` ADOPTED** as the mid-path sub-block: a `dot-lbrace` compound
  token at the dot band (the `dot-lparen` precedent; prefix-disjoint; P1 owns
  the THREE-layer opener co-update). `.` uniformly means DESCEND.
- **3b — brace adjacency with HEAD-SYMBOL PRECEDENCE**: known reader-form
  heads (`racket{…}`, future language ids) recognized BEFORE the select-block
  rule; spaced `{…}` is never a block. P1 census = three buckets (spaced ·
  adjacent reader-form head · adjacent select-block); the 10 FFI sites +
  `test-foreign-block.rkt` become round-trip pins; guiding diagnostic on
  selecting from a reader-form head.
- **3c — multi-digit `:N`: lean keyword-index token, DECIDED BY PROBE at
  P1's Q8 review** (`{:10 v}` probe + both-modes `:digits` census).
- **3d — colon seam resolved by POSITION**: broadcast is expression-position
  only; annotation colons live in binder/head contexts. P1 census VERIFIES
  the disjointness (Rel T1 typed-var sites `?x:Int` especially).
- **4a — demand semantics STAGED**: spec §1.3 tag amended to
  [ADOPTED — staged]; an X.close gate row added; lazy leaves = own post-v1
  design (§5.P6). The static half (copattern typing never forces) is true at
  v1 regardless.
- **4b — the STEP-LIST NODE**: one selection node family carrying the step
  list (keys · ordinals · broadcast markers · `^` continuations · blocks ·
  disclose). Typing WALKS the steps (per-position tuple exactness, the union
  meet, grade-layer counting structural — L1 fusion becomes a fact, not a
  rewrite). Reduction LOWERS per step onto shipped machinery (`get`,
  `pvec-map`, `map-map-vals`). `expr-broadcast-get` RETIRES with `.*name`
  rather than being repaired. The P3 mini-audit prices the struct before code.
- **4c — row-map typing PER-FIELD in v1**: broadcast bodies are selector
  steps, not arbitrary terms — per-field is cheap; the weakening arrives
  (explicitly) with first-class selectors. The `def := [map-map-vals …]`
  qtt lying-diagnostic (pre-existing) gets a P4 probe.
- **4d — dyn-tail: SUPPORT-BOUNDEDNESS carries** (the old surface's surviving
  D3-M5 principle): closed row → per-field · `(Map K V)` → uniform V→V′ ·
  dyn tail → loud static error naming the remedies (seal / validate /
  annotate).
- **Q5 — DISCLOSE `<` ADOPTED IN v1 [owner]**, bare form, spelled `:<` in
  broadcast composition; lands at P4 (in-step). ⚠ P1 grammar obligation:
  `<` is a WS angle-group opener (the mixfix-swallow family) — `users:<{…}`
  gets a mandatory probe row in Q8.
- **Q4** — `*` stays vector-only in v1 (spec's own answer). **Q6/Q7** — moot
  under P3's strict waypoint; deferred to P5's mini-audit.

**The P1-opening ruling [owner, 2026-07-28]:**
- **THE `.*name` MIGRATION GAP IS ACCEPTED, DELIBERATELY.** Ruling Q1 makes
  `.*name`'s migration target `:name`, which does not land until **P4** — so
  retiring the surface at P1 leaves its live sites broken for three phases.
  The alternative considered and **REJECTED** was migrating those sites to a
  working spelling now (e.g. `[map [fn [r] r.x] …]`). Owner rationale: *"my
  concern with migrating is that we'll also forget to migrate back; at least
  the gap creates noise along the way until it is fixed."* The breakage is
  therefore a deliberate **reminder instrument**, not debt — it is the thing
  that makes P4 unforgettable. Two obligations follow, both on §5.P1:
  (a) the audit must confirm the file(s) carrying those sites are **NOT
  suite- or acceptance-GATED** — accepted noise and a red suite are different
  things, and if they ARE gated the ruling needs revisiting; (b) the breakage
  must be **per-command and non-fatal** (the `d18648f0` precedent: a retired
  form yields a generic per-command error and the file CONTINUES), never the
  raw-Racket-abort shape `.{` had before its retirement.

**The P1 mini-audit rulings [owner, 2026-07-28]** (audit `wf_789e4f0f-f02`, 7
facets + completeness critic @ `5c171caa`, all load-bearing findings
main-session R-lens-verified; full findings in §5.P1):

- <a id="q-l1"></a>**Q_L1 — colon seam: the `?`-PREFIX DISCRIMINATOR adopted; the WS repair is
  SCOPED IN.** Ruling 3d's position-disjointness is **REFUTED at HEAD**:
  narrowing-query typed logic vars (`[add ?x:Nat ?y:Nat] = 5N` — 6 live sites,
  consumer `narrow-var-constraints` parser.rkt:6871) are `ident:Ident`
  annotations in EXPRESSION position, a different subsystem from POL.6.
  Resolution: broadcast never claims a `?`-headed subject — the discriminator
  already exists in the surface. Rider: that surface is ALREADY silently
  broken in WS (the splitter runs on a glued symbol only the sexp reader
  produces; the sole WS test is VACUOUS — passes on substring "x"), so P1b
  repairs it, else P1 cannot tell new breakage from old.
- <a id="q-l2"></a>**Q_L2 — the WS-vs-sexp `.{` divergence is INSTITUTIONALIZED** (the POL.9
  precedent): sexp `.{` = selection-path fan-out (15 live test sites,
  parser.rkt:3481) STAYS; WS `.{` = the mid-path sub-block (ruling 3a).
  Documented eyes-open; convergence belongs to the future sexp phase (§2.4).
- <a id="q-l3"></a>**Q_L3 — `broadcast-get` retires as the FULL CHAIN at P1a**: reader token +
  parser keyword (parser.rkt:146, arm :2332-2350) + surf struct
  (surface-syntax.rkt:251/:894) + elaborator arm (:2394) + the expr node +
  its 2 walker-safety pins. Census: the keyword form has **ZERO live users**
  — this is dead-API removal, not capability retirement. Basis: ban-dual-paths
  (keeping it beside P4's `:` is two mechanisms for one operation);
  "partial retirement" is a red-flag phrase; and the audit itself proved
  partial retirements rot (`d18648f0`'s surviving surface-rewrite leg).
  Completeness-over-deferral: no unbuilt dependency exists, so no deferral is
  licensed.
- <a id="q-l4"></a>**Q_L4 — the diagnostic seat is BUILT at P1a**: reader emits a retirement
  MARKER FORM; preparse converts it to a per-command **`parse-error` VALUE**.
  Prior art: `$mixfix-retired` (deleted `d18648f0`) proves the marker
  mechanism end-to-end; its flaw was RAISING (`expand-mixfix-retired` called
  `error`) — which is exactly why audit-09 aborted with zero output. The
  named tilde template is probe-proven a WHOLE-FILE ABORT (structural: the
  reader tokenizes the entire file before any command runs, driver.rkt:2226),
  which would contradict the accepted-gap ruling's own premise (noise, not
  silence) and the spec §3.6/Q8 error-surface obligations.
- <a id="q-l5"></a>**Q_L5 — the working-tree `.[x]` / `.[a.b]` spellings are PRIOR SKETCHING —
  disregard** [owner]. In neither the spec nor D4; all censuses run against
  HEAD (`git show HEAD:<file>`), never the dirty tree (the audit's two
  wrongly-"refuted" counts both measured owner WIP).
- <a id="q-l6"></a>**Q_L6 — P1 SPLITS into P1a (retirements + substrate) / P1b (seams + Q8)**:
  audit-discovered scope (the surface-rewrite cleanup, the reader-form-head
  registry, the diagnostic seat, the 4-site chain, net-new pins) made the
  single phase too large for one gated slice.

**The P1b mini-audit rulings [owner, 2026-07-28]** (audit `wf_d0862784-5e5`, 6
facets + completeness critic @ `bc0c7578`; every load-bearing finding
main-session R-lens-verified; full record in §5.P1b):

- <a id="q-m1"></a>**Q_M1 — `:N` disambiguated by POSITION (option b).** ⚠ The audit's largest
  find: `:0`/`:1`/`:w`/`:m` are NOT unclaimed lexical space — they are the
  **QTT multiplicity vocabulary** (`recognize-colon-annotation`,
  parse-reader.rkt:847-860), consumed at 18 sites across
  parser/macros/driver/tree-parser. Probe-verified: `users:0` → `(users :0)`
  and `[fn [x :0 Int] x]` → `(fn (x :0 Int) x)` are **the same lexeme**.
  Ruling 3c framed `:N` as a multi-digit question settled by a `{:10 v}`
  probe — that probe cannot see this collision. Resolution: multiplicity
  annotations are binder/param position, broadcast is expression position.
  ⚠ **OBLIGATION, not an assumption**: position-disjointness was ALREADY
  REFUTED ONCE on this seam (ruling 3d, by the narrowing typed-vars). P1b-i's
  FIRST probe hunts expression-position `:0`/`:w`/`:m`; a counterexample
  re-opens Q_M1 before anything is built on it.
- <a id="q-m2"></a>**Q_M2 — P1b SPLITS THREE WAYS** (audit-recommended, owner-approved), with
  an ORDERING CONSTRAINT the design had not stated: **`.{` must be re-minted
  BEFORE or WITH lbrace adjacency**, because `.{` today presents a loose `|.|`
  token whose end-pos abuts the `{`, so adjacency-first would turn every
  in-flight `x.{…}` into a select block anchored on a bare dot.
- <a id="q-m3"></a>**Q_M3 — `def ?x` becomes a GUIDED ERROR.** Q_L1's "the discriminator
  already exists in the surface" is a **namespace RESERVATION we are making**,
  not a property we inherit: `def ?cfg := {:a 1}` is legal at HEAD and
  `?cfg.a` → `1 : Int` at 0 errors (probe-verified). Owner rationale: `?` is a
  **modality** marker (functional narrowing; `defr` logic-var params), so a
  `def` binding was never meant to be one — reserving it costs nothing now and
  prevents the surprise later. No present soundness issue; the reservation is
  prophylactic.
- <a id="q-m4"></a>**Q_M4 — the TOP-LEVEL `<` SWALLOW IS FIXED IN P1b-i [owner]**, not
  documented as a hazard. The audit REFUTED the design's framing: the
  swallower is a bare depth-0 `<`, NOT `:<` — probe-verified, `users<{a}`
  (no colon) and even `def p := 1 < 2` / `def q := 3 > 4` (no colon, no brace)
  collapse into ONE form at **ZERO errors**. Mechanism now pinned:
  `langle-matched?`'s terminating arm is `(and close-type (eq? type
  close-type) …)`, but at top level `close-type` is `#f`, so it can never
  fire and the scan runs to `[(>= i n) #f]` — the end of the whole token
  stream. Fix: **bound the scan at the next top-level form start**; the
  information already exists one domain earlier (`content-line-indices`,
  Domain 2, computed before Domain 4's `make-bracket-depth-rrb`), so this is
  plumbing + a termination arm, not new analysis. Owner: *"This has been an
  issue to fix for a while, and there is a stronger need now than ever
  before."* ⚠ Constraint: multi-line angle groups (`<(x : Int)\n -> Int>`)
  were DELIBERATELY kept working at `31d27c83` — the bound must admit
  CONTINUATION lines while rejecting NEW-FORM lines, and the 15 pins from
  that commit are the gate. If it proves messier than the plumbing suggests,
  STOP and re-checkpoint rather than let the slice swell.
- <a id="q-m5"></a>**Q_M5 — ruling 3a's PRECEDENT is CORRECTED**: the model is **`hash-lbrace`
  (6/6 sites, plain `'rbrace` closer, probe-verified nesting)**, NOT
  `dot-lparen`. Citing dot-lparen silently imported its `'mixfix-rparen`
  sentinel, which exists to carry SEMANTIC MODE, not to disambiguate a
  closer — and a sentinel closer would reproduce the `31d27c83` cross-line
  swallow, because the extent scanner stores REAL token types as frame
  closers (parse-reader.rkt:1311) and `langle-matched?` has no translation
  arm. **`dot-lbrace` uses plain `'rbrace`.** The word "closer" never appeared
  in ruling 3a.
- <a id="q-m6"></a>**Q_M6 — a DISTINCT SENTINEL for the select block is FORCED, not
  preferable.** Adjacency is DESTROYED at the datum layer (probe: `x{a b}`
  and `x {a b}` are byte-identical, as are `racket{42}` / `racket {42}` and
  `spec identity {A : Type}`), so "a fourth fork on `$brace-params`" is not
  implementable by position at all — and `$brace-params` turns out to be
  **≥7-purposed** (map literal · implicit type binders · foreign block ·
  solver config · defproc capability binders · selection path fan-out ·
  foreign-import capability annotations), every fork position-disambiguated.
  ⚠ Constraint: `combine-foreign-blocks` (macros.rkt:2431-2437) has **NO
  adjacency test**, so spaced `racket {code}` is accepted today and is
  back-compat-PINNED — therefore the head-adjacent bucket keeps emitting
  `$brace-params` UNCHANGED and only the non-head-adjacent select block gets
  the new sentinel. Any new sentinel owes `pattern-var?` (macros.rkt:1144+)
  AND tree-parser.rkt's inline skip-list — **P1a's own headline defect
  class**.
- <a id="q-m7"></a>**Q_M7 — the standing `^` ruling is CORRECTED (it was not executable).**
  "`^` splitting is P3-parser-side via POL.6 `split-fused-symbol` — no second
  splitter" names the WRONG primitive: `split-fused-symbol` (parser.rkt:5437)
  splits on `":"`, has two binder-path callers, and REJECTS >2 segments; the
  tree's ONLY `^` splitter is parser.rkt:3543 inside `validate-selection-
  paths` — which is the SEXP-ONLY surface Q_L2 freezes. **P3 has no reusable
  WS-path `^` primitive** and must either lift the sexp one or write the
  primitive the old ruling forbade. Recorded now so P3 does not build on a
  false premise.
  *(Coordinates re-verified at the P3 audit: `split-fused-symbol` is at
  parser.rkt:5540 — the ruling's :5437 had drifted +103 — and the sexp `^`
  splitter at :3578 inside `validate-selection-paths` (:3567), drift +35.
  A SECOND reason it is unliftable, found there: it calls a LOCAL hand-rolled
  `string-split` (parser.rkt:3762-3770) that does NOT drop empty segments —
  `a^` becomes a rename to the EMPTY keyword and `a^b^c` is silently absorbed
  as one caret-bearing keyword. The F1b.7g drift class, live in the very
  primitive the old ruling proposed to lift.)*
- <a id="q-m8"></a>**Q_M8 — ORDINALS ARE MULTI-DIGIT IN BOTH BANDS [owner, 2026-07-28].** The
  owner ruled against P1b-i's draft recommendation: *"An ordinal broadcast could
  and should very much be multi-digit, practically — just as an ordinal `.Ndd`."*
  The recommendation was **wrongly premised**, and the refutation is measured:
  · **The overlap is TWO lexemes, not a space.** `recognize-colon-annotation`
    (parse-reader.rkt:847) accepts **12** lexemes — `:0`–`:9`, `:w`, `:m` — while
    `mult-annot?` (parser.rkt:3904) accepts **3** — `:0 :1 :w`. So **nine of the
    twelve already lex as one token and already are not multiplicities**;
    probe-verified, a binder-position `:7` gives a clean loud *"Expected binder
    [x <T>] or (x : T)"*. Ordinal ∩ multiplicity = **`:0` and `:1` only**.
  · **Those two are already discriminated**: of 289 live multiplicity tokens,
    287 spaced + 2 opener-preceded, **zero focus-adjacent** (Q8.3).
  · **So widening the digit run from 1 to N is not widening a collision** — it
    finishes a job the recognizer already half-did. `mult-annot?`'s `memq`
    rejects `:10` by the identical path it rejects `:7`: same arm, same error,
    **no new failure mode and no new error surface on the multiplicity side.**
  · **It also repairs a latent defect unrelated to Path Selection**: `{:0 v}`,
    `{:1 v}`, `{:9 v}` are legal map keys today and **`{:10 v}` SHATTERS** into
    `: 10`. Arbitrary and user-surprising.
  · **Blast radius is nil**: zero live uses of `:2`–`:9` or `:m` at HEAD, so the
    already-over-accepted range is unexercised.
  · **On the dot side the ruling FIXES A SILENT WRONG ANSWER** (Q8.1): `x.1.2`
    reads as the rational **6/5** and `x.10.20` as **51/5** today. A dot-anchored
    `digit+` recognizer kills it structurally — multi-digit is the *same*
    one-line `digit+` that fixes the rational, not an extra.
  **Implementation homes** (neither moves into P1b-ii): the `:N` widening rides
  the colon seam at **P1b-iii** (until broadcast exists `users:10` has no
  meaning); `.N` lands at **P2** as designed. Both owe a corpus A/B, being
  tokenizer changes. *Watching data point: probing before ruling changed the
  ruling — this time against MY OWN recommendation, on a premise I stated
  confidently and had not measured to its edges.*

**The P2 mini-audit rulings [owner, 2026-07-29]** (audit `wf_22020418-a5f`, 6
facets + completeness critic @ `c5153685`; every load-bearing claim
main-session R-lens-verified before adjudication. **12th consecutive phase
whose premise the mini-audit refuted or rescoped.** The doc-truth half landed
separately at `0e5a56a3` per owner ruling Q_R6):

- <a id="q-r1"></a>**Q_R1 — `.N` REUSES `$postfix-index`; it does NOT mint a new sentinel.**
  The audit's decisive finding: §5.P2 never ruled the sentinel choice, and it
  is the decision that sets the phase's whole cost. Both naive `$dot-access`
  reuses are BROKEN — a numeric payload **hard-raises** at macros.rkt:5556
  (`symbol->string` on `10`, i.e. a whole-file abort) and a symbol payload
  `|10|` silently yields `(map-get x :10)`, the wrong NODE (no PVec leg) with
  the wrong KEY DOMAIN. Reuse is verified near-free: `$postfix-index` is
  ALREADY in `pattern-var?` (macros.rkt:1152) and ALREADY in the
  `access-sentinel?` fusion gate (:5496), and its fold arm ALREADY terminates
  `[else `(get ,target ,key)]` (:5625) — the exact target §5.P2 specifies. So
  `v[0]` and `v.0` become **byte-identical datums**, which makes the owner's
  standing "two surfaces over ONE mechanism" ruling literally true at the datum
  layer rather than merely architecturally.
  **Costs, accepted with eyes open**: (a) `.0` and `[0]` are datum-
  indistinguishable, so spelling-specific diagnostics are forfeited and
  X.close's open "does bracket-postfix retire?" question is prejudged toward
  keeping them unified; (b) of the fold arm's four retirement guards only
  `postfix-hole` is reachable from a `digit+` payload, so `_.0` would print
  BRACKET-flavoured advice (*"use `[fn [m] m[k]]`"*) — **P2 fixes that message
  to be spelling-agnostic.** Decisive reason: the nine-tier sentinel surface
  produced the BLOCKING defect in *both* of the last two slices, and reuse
  avoids it entirely (no new `pattern-var?` entry, no new pp-datum/form-deps
  omission — the residual stays 23-of-33, not 24-of-34).
- <a id="q-r2"></a>**Q_R2 — COPY the `:N` twin's TRAILING GUARD.** The just-landed colon half
  consumes `digit+` and THEN declines on `ident-continue?`
  (parse-reader.rkt:907). `.N` copies it. This governs five shapes that each
  lex as ONE numeric token today — `x.0N` → `($nat-literal 0)` · `x.1e3` →
  **1000** · `x.1/2` → `($rat-literal 1/2)` · `x.1f` → float · `x.1p8` → posit
  — and with the guard all five DECLINE and stay exactly as they are today,
  minting no new error surface. **`xs.0N` is a NAMED NON-GOAL**: `0N` is the
  project's own Nat spelling and `expr-get` accepts Nat *or* Int, so it reads
  as sensible Prologos, but supporting it needs `digit+` plus an optional `N`
  and that is not this phase. Recorded so the next reader does not think it
  was missed.
- <a id="q-r3"></a>**Q_R3 — the DOT BAND STAYS ADJACENCY-FREE, ruled rather than inherited.**
  The band has no adjacency gate at all (`adjacent-to-base?` is called only
  from the bracket and brace arms), so `x .0` and `x. 0` both read `((x |.|
  0))` and a spaced `.0` WILL select after P2. `.k` never enforced adjacency
  either, so requiring it for `.N` alone would create a NEW inconsistency
  *inside* the band, and retrofitting the whole band is out of scope. Blast
  radius is nil by census. Per Q_N5's precedent this is RULED, not discovered.
- <a id="q-r4"></a>**Q_R4 — `m.0` MOVES OUT of the `§10.6` v2 block.** The corpus
  self-contradicted: `m.0` sat inside a block headed *"v2, PERMANENTLY
  commented (spec §7.3)"* while its own annotation said *"works at D4.P2 via
  .N"*. It moves to a live section rather than the header being amended.
  Ordering also matters and the audit priced it: `run-file.rkt` keys `;;N=>` to
  **RESULT INDEX**, so uncommenting `party.0.name` (line 118) costs **23**
  marker renumbers while a trailing addition costs **zero** — land the trailing
  ones first.
- <a id="q-r5"></a>**Q_R5 — the `.N` ERROR SURFACE IS IN SCOPE.** P2 owns the first user-facing
  ordinal-access diagnostics, and the two out-of-range paths are wildly
  asymmetric: PVec at RUNTIME is excellent (`panic: get: index 9 out of bounds
  for PVec of length 3`) while a CLOSED nat-row (het tuple) out-of-range is
  caught statically and reported as a bare *"Could not infer type"* — no arity,
  no positions, no path — because `closed-row-miss-hint` is **KEYWORD-GATED**
  (typing-errors.rkt:148, :151). Het tuples are exactly the carrier the
  acceptance file pins (`mixed`, `events`), so this is the FIRST thing a user
  hits on the new surface.
- <a id="q-r6"></a>**Q_R6 — the doc-truth batch lands SEPARATELY**, before P2's code. Done:
  `0e5a56a3`. It corrected a self-contradiction in **owner-reviewed normative
  text** (§Q8.1's five-vs-six), a **layer error** that had already propagated
  into a session summary (the "0 errors" claim), a **false illustration** in
  §Q8.5 invariant 2 that no facet caught, invariant 3's opener-shaped token
  layer plus four stale coordinates including the fusion gate it exists to
  name, and §8 R3's retired-`.*` quadruple-duty claim.

**Recorded adaptation (Batch-1 discipline — an UNRECORDED adaptation is a bug
in D4, so it is recorded here rather than applied silently):** `.N` routing
through `expr-get` means that on a `(Map Int V)` subject it resolves to a
**NOMINAL key lookup wearing ordinal notation**, against the spec's own
key-sort thesis (spec §2.1 reads `.N` as "ordinal access (index)"). Blast
radius is low — `(Map Int V)` requires an annotation to reach — and unifying
the spellings is the point of Q_R1, so the adaptation is ACCEPTED. Named so it
cannot be rediscovered as a defect.

**The P3 co-design rulings [owner, 2026-07-29]** (the COMPLETE Q_T batch —
Q_T1–Q_T8, ruled across four deliberative rounds,
in PROSE per the standing discipline; audit `wf_27a84061-c7e` fed them —
**13th consecutive phase whose premise the mini-audit refuted or rescoped**):

- <a id="q-t3"></a>**Q_T3 — "level-local" means OUTPUT-level-local.** The L4/strict-merge checks
  run over the keys that reach a result level AFTER `^`-splicing. Ruled because
  the syntactic-block reading ACCEPTS `cfg{server^.{port} database^.port}` —
  two dissolving branches landing `:port` at the same output level — which
  Ruling B B4 REJECTS, and that is the one direction that breaks the strict
  waypoint's monotonicity guarantee ("every error today can become a meaning
  later"). Probe-verified that the naive lowering would silently last-win it.
- <a id="q-t4a"></a>**Q_T4a — `^` NEVER attaches to an ordinal; it is a guided spelling error.**
  Owner: an ordinal returns the value at an index, not a key-value; and
  non-local attachment (my PS6 reading, scanning left past ordinals to the
  key-generating segment) "breaks composition, first-class re-use, and
  expectations." The expressivity lives at the right place already:
  `cfg{admins^first.0}` renames the NOMINAL segment then descends → `{:first
  ⟨admins[0]⟩}`. Consequence: DEFERRED 11 dissolves into a MESSAGE-QUALITY
  item — `x.0^` / `x[0]^` / `{admins.0^first}` all need one guided error
  ("an ordinal has no key; rename the nominal segment"), not a semantics.
- <a id="q-t4b"></a>**Q_T4b — THE `^` BASE RULES** (the mutual-clarity round; misread by me, now
  pinned): a branch's output key is its **surviving head key**; every `^` form
  acts **locally on its own segment**; **rename is IN PLACE**; only
  `^`-dissolve removes a level; bare leaf `^` contributes the leaf VALUE as a
  keyless component (no keys ⇒ no ancestry question). So `server.host^h` →
  `{:server {:h …}}` and `server^.host^h` → `{:h …}`. The spec flagship
  re-derives exactly under these rules.
  **Where the misreading came from, recorded so it cannot recur**: (1) NO §10
  example renames a leaf under a KEPT ancestor — every spec rename sits under
  a dissolved ancestor or at the branch head, so the corpus cannot
  discriminate in-place from collapsing; (2) the acceptance file's §B `^_`
  line (written at P0) showed a FLAT result imported from the SUPERSEDED
  surface's D3-era "`^_` = derive-ALL" ruling — an old-surface semantic in the
  new corpus without the §8 R5 NOTATION-vs-SEMANTICS classification. The line
  is corrected in this commit.
- <a id="q-t4b-prime"></a>**Q_T4b′ — `^_` takes READING N (local, like its siblings)**: it is `^k'`
  with a computed label — rename the leaf IN PLACE to the path-synthesized
  key. `cfg{server.host^_}` → `{:server {:server-host …}}`. The flat
  "provenance" behaviour is NOT lost — it is the explicit collapse spelling
  `server.host^-_` (Q_T7), which is where a structural effect belongs.
- <a id="q-t7"></a>**Q_T7 — the `^-` COLLAPSE family is IN SCOPE at P3.** `^-` collapses the
  whole branch flat: `h.k^-` → `{:k …}` · `h.k^-k'` → `{:k' …}` · `h.k^-_` →
  `{:h-k …}` (the flat provenance recovery). Makes `i^.h^.k` ergonomically
  `i.h.k^-`. Lexing verified: `k^-` / `k^-k2` / `k^-_` each glue into ONE
  token; the splitter's continuation grammar is `-`?·{ε | label | `_`}.
  ⚠ Eyes-open cost: after `^` a leading `-` IS the collapse marker, so a
  rename target literally beginning with `-` is unsupported.
- <a id="q-t8"></a>**Q_T8 — the parent-key collapse is IN SCOPE, spelled `^..` (not `^.`).**
  `ssl.enabled^..` ≡ `ssl^.enabled^ssl` → `{:ssl …}`; ancestors above the
  parent are kept (`server.ssl.enabled^..` → `{:server {:ssl …}}`). The owner
  flagged the `^.` parse hazard and pre-authorized `^..`; probes CONFIRMED the
  hazard is real and `^..` dissolves it: `a.b^.c` (missing space) reads
  IDENTICALLY to the legitimate mid-path dissolve `a`·`b^`·`.c` — a silent
  one-space meaning flip between two well-typed keyed forms with NO type-error
  net (the §2.2 mitigation does not apply here) — and `a.b^.0` collides the
  same way with ordinals. Under `^..` both no-space shapes contain a bare
  `|.|` mid-branch and are LOUD malformed-payload errors. Edge recorded:
  `a.b^...` absorbs into `$rest`; the malformed-payload seat must reject a
  `$rest` item in a block payload.
- <a id="q-t6"></a>**Q_T6 — the `spec` type-position hole is FILED** (DEFERRED 14), not fixed in
  P3. Pre-existing (the shipped `.`-access is dropped identically) and rooted
  in `spec`'s error architecture (a preparse command inside a `void`-ing
  handler), not in selection. ⚠ The C30 open question is now ANSWERED — it is
  the WORSE reading: the dropped spec's type datum IS registered (the
  follow-up `defn h` error QUOTES the raw `($retired-selection …)` marker
  from the stored spec), so the hole stores garbage rather than losing a
  declaration.
- <a id="q-t1"></a>**Q_T1 — ROUTE A: mint the `expr-select` node NOW, scoped grades-1-only
  [owner, 2026-07-29].** Decided from the COMPLETED-feature horizon, on four
  legs: (1) **P5's spine identity is a comparison over a structured step
  representation** ("source-directed steps with `^`-continuations erased") —
  a desugared block leaves nothing to compare; (2) **the error-surface
  argument REVERSES at the completed horizon** — P5's "SHOULD print the
  factored spelling" and even P3's strict-merge remedies need BLOCK CONTEXT
  at error time, which desugaring forfeits permanently while inheriting only
  generic messages (the audit's C9/G7 diagnostic concern is answered by
  wiring `format-closed-row-miss` — a standalone, reusable fn — into the
  node's own typing arm, WITH branch context: same quality, better ceiling,
  and the work persists); (3) **option 2 is a strict PREFIX of option 3**
  (surf node + parser + elaborator are shared; the routes differ only in what
  the elaborator arm emits), so route B's elaborate-time lowering would be
  scaffolding with a designed ONE-phase lifetime that P4 must tear out (the
  dual-path ban forbids keeping it); (4) ruling 4b already fixed the node as
  the destination — only timing was open, and the audit priced it. Honest
  price accepted: ~13 files, the inferQ/checkQ twins (delegation model
  `cdb535ac`), walkers via the generic transparent-struct fallback (no
  binder ⇒ no depth routing), NO PNET bump (symbol-keyed tag table,
  verified), subject evaluated ONCE in the node's reduction (no let/fn
  workaround). P3 is a MULTI-SLICE phase; Q_T5 organizes it.
- <a id="q-t2"></a>**Q_T2 — PRESENCE: HORN D, LENIENT [owner, 2026-07-29].** The rule: **a
  block may select a field iff the subject's type SOURCES that field's
  presence as `'present`; everything else is a loud static error** naming the
  4d remedy list (seal / validate / annotate). The result row is closed,
  all-`'present`, honestly — PS15's sourced-presence qualifier satisfied, so
  §B's "sealable, validatable" claim is TRUE, and the presence-blind seal
  (verified: zero `record-field-presence` reads in either seal fn) is never
  asked to vouch for fabricated presence.
  · **LENIENT**: a dyn row's LISTED-`'present` fields are selectable (their
    presence IS sourced — PS15's own criterion); only `'unknown`-marked and
    unlisted fields refuse. Consistent with 4d: broadcast needs the WHOLE
    support (dyn tail ⇒ loud), a block names SPECIFIC fields, so
    support-boundedness (D3-M5) is satisfied per-field.
  · **Probe fact that reshaped the case table**: `map-dissoc` on a CLOSED row
    simply REMOVES the field (still closed, no `'unknown` mark; projecting it
    is already a loud miss). `'unknown` arises only from dissoc-on-DYN — so
    closed rows cannot carry unknown presence, and the corpus (all closed
    rows) costs ZERO.
  · **The deliberate asymmetry, ruled not absorbed**: bare `.field` on a dyn
    row stays D19-permissive (exploration); a BLOCK on the same row refuses
    (construction is assertive-tier — it mints a committed, sealable value).
  · Rejected-with-reason: Horn A (stamp `'present` always) fabricates
    presence on dyn subjects and the blind seal then guarantees it — the
    seal's contract broken exactly where PS15 warned; Horn B (`'unknown` in a
    closed row) is unsound TODAY for the same blind-seal reason and mints a
    carrier state no walker has ever seen; Horn C (presence-aware seal) is
    complementary to B, not an alternative to D, and is F1b-scope growth
    mid-phase. All refusals are MONOTONE (F-row/P6 can later relax them).
- <a id="q-t5"></a>**Q_T5 — P3 SPLITS THREE WAYS: P3a → P3b → P3c [owner, 2026-07-29 — "that
  shape looks good to me"].** **P3a** = the node + keyed blocks, no `^` (the
  full pipeline cost paid once; D-lenient presence from day one; strict merge
  for plain keys BEFORE `make-record` can last-win; the malformed-payload
  seat; the type-position refusal; §9's learnability pair). **P3b** = the `^`
  family (the ONE splitter; five operators; the output-level-local merge
  re-check with the Q_T3 monotonicity case as its named pin; the Q_T4a
  ordinal-`^` guided error). **P3c** = keyless + L4 + honest nesting (the
  nat-row mint at EVERY n; ordinal branches `{N M}`; the L4 mixing error; the
  `⟨String⟩` pins; the G11 one-space pair). **Ordering is FORCED, not
  chosen**: a→b because the splitter extends the payload parser and every `^`
  semantic runs through the node's arms; b→c because both §B keyless corpus
  lines use leaf-`^`, so tuples cannot ship before bare-`^` means something.
  Rejected-with-reason: folding P3c into P3a puts the tuple mint ahead of the
  bare-`^` semantics it depends on — the forward-reference-between-slices
  shape that made P1b split three ways. **P3 needs ZERO tokenizer changes**
  (every ruled spelling already lexes, probe-verified), so NO corpus A/B is
  owed anywhere in the phase; gates = acceptance + targeted batteries + full
  suite + the pre-commit adversarial verify (a BLOCKING catch in five
  consecutive behavioural slices — load-bearing, not optional). P3b/P3c open
  with LIGHT mini-audits (coordinate re-verification against `wf_27a84061-c7e`,
  not full re-audits). **The Q_T batch is COMPLETE.**

**The P3a-close checkpoint rulings [owner, 2026-07-30]:**
- <a id="q-u1"></a>**Q_U1 — P3a owns EVERY no-`^` block line** (the §5.P3a corpus list was
  corrected against the file; `6d919142`).
- <a id="q-t2-adaptation"></a>**Q_T2 adaptation RATIFIED** — "annotate its row type" dropped from the
  refusal remedy lists ("annotate comes back when it's real"); DEFERRED 19
  carries the re-entry trigger.
- <a id="q-u2"></a>**Q_U2 — mid-branch ordinal steps take READING A** ["Reading A stands —
  ordinal blocks own the re-derivation"]. A grade-1 `.N` step inside a keyed
  branch DESCENDS, contributing NO output level — ordinal keys are
  contingent, there is no identity to preserve; nominal ancestry above and
  below survives (`cfg{admins.0.name}` → `{:admins {:name "Alice"}}`).
  Re-derivation (fresh indexing) is reserved for ordinal BLOCKS — `{N M}`,
  including the 1-tuple `.{0}` per honest nesting — so `.0` (one focus, no
  shape) and `.{0}` (1-tuple) stay DISTINCT and the step/block grade
  distinction survives; the in-block step matches the bare path's landed P2
  extraction, with ancestry kept. Consistent with Q_T4a's recorded
  consequence ("renames the NOMINAL segment then descends").
  **Implementation: P3c** (rides the ordinal machinery; P3a's parser refusal
  lifts there; P3b untouched).
- <a id="q-u3"></a>**Q_U3 — the P6 demand DECISION takes option (c)** ["defer it — (c)
  stands"]: demand semantics deferred to a named post-v1 phase; §5.P6
  carries the ruling + the charter stub; the 4a X.close gate stays armed.

**The P3b-close checkpoint ruling [owner, 2026-07-30]:**
- <a id="q-u4"></a>**Q_U4 — `^_`/`^-_` synth scope: SUBJECT-ROOT is PREFERRED; the flip is
  DEFERRED until it next matters.** P3b implemented branch-of-its-block
  scope (`server.{host^_}` → `{:server {:host …}}` while the dot spelling
  gives `{:server {:server-host …}}`). Owner: the local reading is "not a
  bad assumption" but of lesser utility — **a sub-branch is LESS likely to
  share a common leaf key**, so the synth's disambiguating power wants the
  full path; not a high-priority feature, "switch when it matters next."
  Natural trigger: P5's L2 factoring (which makes the divergence observable
  and wants the two spellings equal) or the first user-visible need.
  DEFERRED 23 carries the trigger + the one-line flip site.

**The P4 co-design rulings [owner, 2026-07-31]** (Q_U5/Q_U6 — ruled in a
deliberative walk that REVERSED the frame twice: the mini-audit
(`wf_8458c23b-312`, 5 facets + critic @ `02dd27d7` — **14th consecutive
premise refuted**) fed an adversarial options panel (`wf_82e56156-b28`)
whose own CRITIC overturned the proposers' lean by probe, and the OWNER'S
challenge then overturned the critic's framing of what blocks. ⚠ The LET
track's merge (`5e16ead4`) landed MID-WALK — audit coordinates are
@ `02dd27d7`; re-pin before use):

- <a id="q-u5"></a>**Q_U5 — THE SELECTOR REPRESENTATION: ONE REIFIED CARRIER (panel option
  B), MONOMORPHIC AT P4.** `expr-path` and `expr-select` unify on one
  reifiable selector carrier; `#p(…)`, `x{…}` and path position become
  spellings of ONE representation; the vacuous ground `Path` type is
  superseded. The walk that got here: (1) the owner REJECTED the brace-only
  answer ("loses information on its spine … doesn't reach the generalized
  first-classness we want"); (2) the panel's proposers leaned "charter the
  reification" on the premise that B needs row polymorphism — an unbounded
  extension; (3) the panel's critic REFUTED the conclusion by probe
  (monomorphic source-annotated projection types cleanly at HEAD: `spec g
  P -> Int` / `defn g [r] r.a` ✓); (4) the owner refuted the PREMISE'S
  FRAMING: the records system was BUILT from row polymorphism + codata —
  verified: the carrier comment STAGES the row variable (syntax.rkt:672
  "`ρ` row-meta = **F-row**"), the records design §151 names open rows as
  THE row-polymorphic case, D12 ships substrate-level codata, and every P4
  carrier's element/field type is KNOWABLE (PVec elem-type · Map k/v ·
  nat-row per-position · keyword-row per-label). So B splits: **(i) the
  carrier unification needs ZERO new typing** (every P4 site has a known
  source row) and lands NOW — it is the half that cannot be retrofitted;
  **(ii) bound-selector precision** (`Selector src dst` / D11's
  `HasField`-constraint idiom) rides **F-row's EXISTING entry gate**
  (DEFERRED: "generate `p : {:x _ | _}` from `p.x`, solve structurally") —
  a named deferral onto an already-chartered absorber, NOT a new charter.
  Rejected-with-reason: **A** (brace-only node + untouched `expr-path` =
  C without the honesty; unnamed dual carrier) · **C** (charter the
  reification = a SECOND charter over First-Class Paths **Phase 8**,
  already chartered 2026-03-20 as "Out of scope" and idle since — the
  belt-and-suspenders blocking red flag + the Validated≠Deployed sibling) ·
  **D** (selector-as-Datum: Datum's syntactic order ≠ selection order, so
  L2/Q6 leave the carrier) · **E** (selector-as-function — and record the
  GENERAL RESULT: a selector typed as its own APPLICATION erases the
  spine; function types are not lattice elements, so no Pi/section/
  closure/lens-as-function representation can support P5's spine equality
  or Ruling-B pointwise merge. This is the positive argument FOR the data
  carrier, and it rules out the §7.7 lens FRAMING as a representation
  while keeping lenses as an INTERPRETATION).
- <a id="q-u6"></a>**Q_U6 — WHOLESALE PATH-POSITION MIGRATION AT P4, with the three-stage
  sequencing.** Dot AND colon path steps mint the node; the preparse
  `map-get`/`nil-safe-get`/`get` fold legs retire into `$select` minting.
  NOT colon-only: that leaves path text on two representations
  discriminated by a step's GRADE (complection; P5 would normalize across
  both). Grounded costs: the fold's callers are a NON-issue —
  probe-verified all **FOUR** production callers (map-literal values ·
  subforms re-entry · pipe pre-fold · mixfix; the 4th is P3a's own
  addition, missed by every enumeration — 6th consecutive under-count)
  depend ONLY on arity collapse and are head-agnostic (`$select` and
  `map-get` fold identically through all four). The REAL cost is the
  BEHAVIOR-PRESERVATION CHECKLIST: `.field`'s landed behavior must survive
  under the carrier's `'path` sort — Q_T2's ruled asymmetry is LIVE
  (probe: `dyn1.host` → `"h" : ?meta` D19-permissive vs `dyn1{host}` →
  loud Horn-D refusal), so ONE carrier carries TWO typing postures by
  sort; plus the P2 `closed-row-miss-hint` family (via
  `projection-parts`), nil-safe variants, and `get-in`/`update-in`
  retargeting. **Sequencing (ruled)**: (1) totality dispatcher +
  strategy-independent repairs (no new surface) → (2) carrier unification
  + wholesale migration with the behavior checklist → (3) the ω semantics
  on top. Sub-slice partition finalizes after Q_U7/Q_U8.

- <a id="q-u7"></a>**Q_U7 — THE ω STEP IS A ONE-STEP WRAPPER: `(@bcast step)` [owner,
  2026-07-31 — "(b) stands"].** `users:name` → `[(@bcast name)]` ·
  `users:{a b}` → `[(@bcast (@sub …))]` · `x:s:t` → `[(@bcast s) (@bcast t)]`.
  **Ruling 4b is RESTATED**: the ω step is a one-step wrapper; EXTENT is
  structural (the spec's "broadcasts exactly the NEXT step" is the
  representation 1:1 — a broadcast-of-nothing is UNCONSTRUCTIBLE, and the
  §3.2.1 extent pair is two visibly different datums); **L1 fusion is a
  THEOREM the battery pins** (`users:0:userName` → ONE layer), not a
  property the representation maintains — fusion is FREE under any
  candidate (each ω step consumes one container layer and re-wraps one;
  fmap∘fmap = fmap arithmetically; nothing computes a layer count); the
  old "layer count = unfused-ω-steps" clause is RETIRED as
  descriptive-not-normative (§10.4's layers come from data shape + `*`).
  Rejected-with-reason: the flat nullary marker (extent-by-adjacency ⇒
  representable malformed states + a backward scan, the structurally-
  emergent red flag) · the run-carrying wrapper (the surface never writes
  runs ⇒ the parser must MERGE adjacent wrappers — exactly the
  normalization pass 4b's rationale forbids; spends the terminal-`@sub`
  invariant for no v1 consumer; P5 recovers runs by a trivial fold over
  consecutive wrappers) · the per-step grade field (taxes the entire
  landed vocabulary for one grade). In the components walk ω is
  key-transparent like ordinal steps — a WRITTEN arm under the P4a
  totality dispatcher; branch-initial `:` stays refused in v1 (W2/spec
  §7.3), so a wrapper never heads a branch. The wrapper is plain data,
  so it survives the Q_U5 carrier unification unchanged (a marker's
  meaning depends on neighbors — exactly what a reified composable
  selector must not do).

- <a id="q-u8"></a>**Q_U8 — THE `:` GATE: UNIFORM POSITIONAL SENTINEL-MINT AT GROUPING +
  PARSER POSITION-DISPATCH [owner, 2026-07-31 — "uniform mint"].** At
  grouping, a `keyword` or `colon-annotation` token BYTE-ADJACENT to a
  non-empty local result mints the new access sentinel
  **`($bcast-step payload)`** — the `adjacent-to-base?` shape, landed in
  BOTH groupers (Q_N7 twin), positional NOT enumerated (`.N`/brackets/
  braces join the focus set free; six enumeration under-counts this arc).
  `$bcast-step` IS an access sentinel (fuses onto its base via the fold —
  the `$postfix-index` pattern) and pays the NINE-site §Q8.5 registration
  surface. The `ident:ident` collision (annotation vs broadcast) is
  position-dependent and ONLY the parser knows position, while adjacency
  is destroyed below grouping (Q8.5 inv 2) — so grouping PRESERVES the
  distinction and the parser DISPATCHES: expression position reads the
  sentinel as the ω/broadcast step; **binder position UNWRAPS it as the
  annotation** (`fused-type-annot?`'s 4 sites · LET's binder consumer ·
  the spec-param and `$brace-params` binder paths — census-gated).
  Shattered spellings (`users:{a b}` = bare `:` + adjacent group;
  `users:<{a}`) become grouping arms over EXISTING tokens — **zero
  tokenizer changes**. **Corpus A/B MANDATORY** (grouping changes datums)
  with a NAMED predicted diff set: exactly the fused-binder sites (3
  `.prologos` let lines at HEAD flip datum shape, not behavior — the
  parser unwraps); any diff outside the set is a bug. **The LET merge
  IMPROVED the safety net**: the fused-annotation hazard class went from
  ZERO instances (A/B-blind at `02dd27d7`) to 3 acceptance lines + 12
  suite-gated embedded pins + 17 defn-param shapes — a naive gate now
  turns the suite red instead of shipping silently. Rejected-with-reason:
  mint-suppression in grouping-recognizable contexts (reintroduces an
  enumerated context list — the under-count class); parser-only (cannot
  see adjacency, Q8.5 inv 2); a fused tokenizer token (same collision,
  bigger surface).

**The P4 pre-implementation PAUSE rulings [owner, 2026-07-31]** — all three
items of the hold-point, ruled before P4a opened:

- <a id="q-u9"></a>**Q_U9 — `:` REFUSES over `List`, with a guided error [owner, 2026-07-31].**
  Broadcast covers the carriers the KEY-SORT THESIS reaches; `List` is not one
  of them, so `quests:t` does not uncomment and the corpus line's fate changes.
  The grounded argument (probed at `711a9bde`, not asserted):
  **(i) `List` is the only candidate with no native carrier** — `Map`→
  `expr-champ`, `PVec`→`expr-rrb`, `Set`→`expr-hset`, het-tuple→`expr-Record`
  (nat key-domain), while `List` is a USER-SPACE inductive
  (`data List {A} | nil | cons : A -> List A`,
  `lib/prologos/data/list.prologos:12`) with no struct in `syntax.rkt`.
  Broadcasting it would make the compiler-native `select-reduce` pattern-match
  constructor applications of a STDLIB type — a dependency direction no other
  selection carrier has, and a slope with no principled stopping point short of
  trait dispatch (`Option`, `Either`, `LSeq`, user functors).
  **(ii) The key-sort thesis (spec §1.1) does not reach a cons-spine**: every
  other carrier has a key domain (ordinal or nominal); a List's positions are
  recoverable only by walking. This is the SAME argument §3.2.3 used to
  ADOPT map-generic `:` ("a vector-only `:` leaves the thesis decorative
  exactly where it matters") — pointed the other way.
  **(iii) The remedy exists, is one primitive, and preserves precision** —
  probe at HEAD, 0 errors: `def qv := [pvec-from-list quests]` →
  `qv : [PVec {:g String :r Int :t String}]` (the row SURVIVES), and the
  landed grade-1 machinery reaches in (`qv[0].t` → `"Rescue the cat"`).
  `pvec-from-list : List A → PVec A` is a live compiler primitive
  (`parser.rkt:2966`).
  **(iv) Monotone** — spec §3.6's own migration principle: errors may become
  meanings, never the reverse.
  **Deliverable, not a shrug**: the refusal is a GUIDED error naming
  `pvec-from-list` and stating that the row type is preserved (iii proves it).
  **The principled door is NAMED**: `:` refuses over `List` *because `List` has
  no `Functor` instance* — the higher-kinded trait vocabulary (`Functor`,
  `Foldable`, `Seqable`, `Buildable`, `Reducible`, `Indexed`, `Keyed`,
  `Setlike`) is ALREADY DECLARED WITH LAWS at
  `lib/prologos/core/collection-traits.prologos:41-177` and has **ZERO live
  instances tree-wide** (the only three mentions are commented aspirations in
  the 2026-03-21 Track 8 acceptance file). So the exit is "inhabit a
  designed-but-uninhabited surface, then route `:` through `Functor`" — seeded
  as a candidate CIU track, NOT chartered here.
  Recorded counter-argument (it is real, and it is why the carrier question
  moved rather than dying): `solve` returns `List`, and solve rows are exactly
  what this feature exists for — Rel T1 landed typed solution rows so
  relational output would compose with records. The resolution is **upstream,
  not here**: `solve-*`/`explain-*` should return `PVec` (spun out as its own
  mini-track — seam measured at TWO lines, `solve-row-type`'s `'list` arm
  `typing-core.rkt:4338` + `racket-list->prologos-list` `reduction.rkt:905`;
  consumer census 2 live `.prologos` sites + ~31 mechanical test type-string
  pins + the `nil`→`@[]` empty shape). That fixes the ergonomics at the source
  WITHOUT widening selection's carrier semantics. **Implementation: P4d**
  (the refusal + its guided error); nothing before P4d reads this decision —
  verified, `quests:t` sits COMMENTED at corpus `:235`, so it produces no
  datums and P4c's reader-datum A/B does not touch it.

  > **✅ THE UPSTREAM FIX HAS LANDED — 2026-07-31.** The spun-out mini-track is
  > COMPLETE: `solve`/`solve-with`/`explain`/`explain-with` now return `PVec`
  > (`b2c4366a`), and the `let x := (goal …)` implicit-solve gap found alongside
  > it is closed (`b5b641b9`). Doc: `docs/tracking/2026-07-31_SOLVE_CARRIER_SPINOUT.md`.
  > **So the Q_U9 refusal now costs solve rows NOTHING** — `def quests := solve
  > (quest t g r)` is already `[PVec {…}]`, and `quests:t` will work at P4d with
  > no `pvec-from-list` hop at all. The corpus example's two `map` sites needed
  > no source change (see the correction below).
  >
  > **Two claims in the paragraph above did NOT survive contact — correct them
  > before relying on either:**
  > 1. **"Seam measured at TWO lines" — it was SEVEN.** The two named are real,
  >    but the census missed the three DISPLAY walkers (`display-row-type-parts`
  >    + `display-result-rows` in typing-core, `pp-solve-echo-ordered` in
  >    driver), each of which fails **silently** — the B3.2 coinductive echo
  >    refinement and the POL.3 declaration-order echo just quietly stop firing.
  >    It also missed `pnet-serialize.rkt`, where the carrier reaches module
  >    caches via POL.10 and hit a **live hash-persistence defect** (`rrb-root`'s
  >    `tail` is a raw Racket vector and `deep-s->v` has no `vector?` arm, so
  >    champ rows leaked through with `equal-hash-code` values baked in).
  > 2. **"2 live `.prologos` sites" need rewriting — they did NOT.** The census
  >    read `spec map … [List A] -> List B` and concluded `map` is
  >    List-monomorphic; that spec is one *instance* under container-generic
  >    dispatch. `map`/`filter`/`length`/`first` all carry the PVec carrier
  >    through unchanged, so only the `;;NN=>` markers moved. A `spec` line is
  >    evidence about an instance, not about dispatch.
  >
  > The `~31 mechanical test pins` and the `nil`→`@[]` empty-shape call were
  > both accurate.
  >
  > **⚠ TWO FURTHER CORRECTIONS — the P4d opening audit, 2026-08-07:**
  > 1. **The lines ARE uncommented now** — `quests:t` went live at P4d-0
  >    slice 1 (`33d83989`) and `quests:{t r}` at slice 5 (`77259635`);
  >    acceptance markers 43/44, passing. The statements above ("does not
  >    uncomment"; "sits COMMENTED at corpus `:235`… the A/B does not touch
  >    it") and their two §5.P4 restatements are OBE — the solve→PVec spin-out
  >    re-fated them upstream, and P4d's re-fate list shrinks by one.
  > 2. **The Functor door's census was FALSE WHEN WRITTEN, not stale**:
  >    `Functor List` has been LIVE since 2026-03-01 (`6dffa9a6` —
  >    `core/list.prologos` `spec list-functor [Functor List]` /
  >    `def list-functor map`), and `Functor PVec` alongside it
  >    (`core/pvec.prologos` `pvec-functor`). The "ZERO live instances
  >    tree-wide" census missed both. **The refusal RULING STANDS** on its
  >    other grounds — (i) no native carrier, (ii) the key-sort thesis does
  >    not reach a cons-spine, (iv) monotone — but the guided error must NOT
  >    claim the absence, and the named exit is no longer "inhabit an
  >    uninhabited surface": the surface is inhabited, and the remaining exit
  >    work is routing `:` through it (still a candidate track, NOT P4d).
- **The `update-in` ω FENCE — RATIFIED [owner, 2026-07-31].** `update-in`
  accepts **grade-1 selectors only**; an ω-bearing selector refuses LOUDLY.
  Broadcast WRITES are spec §7.7 traversal territory, explicitly not v1.
  Monotone (the refusal can become a meaning later). Load-bearing because
  Q_U5's carrier ABSORBS First-Class Paths' `#p(…)` — including its **working
  write direction** — so without the fence the unified carrier would silently
  widen `update-in`'s domain the moment ω steps become constructible.
- **The WHOLE-NODE ABORT — RATIFIED [owner, 2026-07-31].** A runtime miss
  INSIDE a broadcast aborts the WHOLE selection — the single `let/ec`
  (`reduction.rkt:1600`), no partial results, no `expr-panic` buried in an
  output slot. Consistent with the P2.b two-tier discipline; stated and
  PINNED so a "map semantics" intuition cannot drift it later. This is the
  same fact the P4a LOWER-vs-WALK fail-first fixture settles by test.

**The P4b opening ruling [owner, 2026-07-31]:**

- <a id="q-u10"></a>**Q_U10 — WHOLESALE STANDS; the `'path` sort GAINS A MAP POSTURE**
  ["(a) — keep wholesale, give the 'path sort a Map posture"]. The P4b
  mini-audit (`wf_1cb9d606-89c`, 5 facets + completeness critic @ `2cef148b`,
  1.17M tokens) produced a **BLOCKING objection to Q_U6 as written**, which
  this ruling resolves.
  **The objection, probe-verified at HEAD**: `.field` on a `(Map K V)` subject
  WORKS (`m.a` → `1 : Int`, 0 errors, via `expr-map-get`,
  typing-core.rkt:2205-2213) while `{field}` on the SAME subject REFUSES
  STATICALLY (`select-row-of`'s `[(expr-Map? tm) … 'subject-map]`,
  typing-core.rkt:663). So wholesale `$select` minting for `.field` would
  **silently delete a working surface** — and not an obscure one: it is
  DOCUMENTED in the ambient rules (`prologos-syntax.md:117` "Dot access is for
  map keys — `user.name` → `[map-get user :name]`"), TAUGHT as the headline
  ergonomic in `examples/map-tutorial-demo.prologos:219-225` against an
  explicit `[Map Keyword Nat]` def, and PINNED E2E at
  `tests/test-dot-access-02.rkt:112-119` — a pin BOTH fold-census facets
  missed, because it asserts a **value**, not a datum, so it fails by TYPE
  ERROR rather than shape mismatch. A migration plan phrased as "update the
  datum assertions in the migrating commit" structurally cannot catch it.
  **The ruling**: wholesale stands (the complection Q_U6 rejected is still the
  thing to avoid), and the `'path` sort gains a **Map posture** — `.field` on
  a Map subject keeps `map-get` semantics under the unified carrier.
  **Consequence, accepted eyes-open**: design claim C2 ("ZERO new typing
  work") is **REFUTED** and formally withdrawn. Sort dispatch has to exist
  anyway for Q_T2's dyn-row asymmetry; Map is a THIRD posture in a table we
  are already building, not a new mechanism. Therefore **design-round item 5's
  semantic table is TWO-DIMENSIONAL — indexed by (subject kind × sort), not by
  sort alone.** Rejected-with-reason: **(b)** narrow the migration to the
  reified spellings only (`#p(…)` + `x{…}`), leaving `.field` on `map-get` —
  preserves the Map surface for free but leaves path text on TWO
  representations discriminated by subject type, which is exactly the
  complection Q_U6 was ruled to prevent; **(c)** migrate only record-typed
  subjects — incoherent, elaboration precedes typing so the discriminator is
  not available where the mint happens.

- <a id="q-u11"></a>**Q_U11 — RETIRE the silently-broken `#p(…)` vocabulary, with a guided
  error** ["(a) — retire them with a guided error", owner 2026-07-31]. Opening
  P4b-i by probing the encoding, the path literal turned out to carry FOUR
  spellings of which only ONE works:

  | spelling | at `099ef690` |
  |---|---|
  | `#p(a)` · `#p(a.a1)` | **live** — `get-in m p` returns the value |
  | `#p(a.*)` · `#p(a.**)` | defines as `Path`, then `get-in` → **`<error>` VALUE at ZERO ERRORS** |
  | `#p(a.{b c})` | same — `<error>` value, 0 errors |

  The broken half is the **P2.b fabrication class, live**: a value where an
  error is owed, unconstrainable because the vacuous ground `Path` type
  discards the branches (`typing-core.rkt:2050-2051` matches `_`). Their own
  acceptance file has them COMMENTED OUT
  (`examples/2026-03-20-first-class-paths.prologos:80,83,86`), so there is no
  live corpus use. **Retired rather than carried across the carrier
  unification** — carrying them would move a silent-wrong-answer into the new
  carrier and make "ends single-carrier" hollow (the blocking
  belt-and-suspenders shape); fixing them into working semantics would be new
  behaviour inside a slice that is meant to be behaviour-preserving, and
  multi-branch collides with the `(car branches)` truncation P4b-iii repairs.
  Monotone. Refusal fires at ELABORATION — at the literal, not its use — via
  the `parse-error` seat (a per-command error VALUE, never a raise), the same
  seat the `update-in` guards use at elaborator.rkt:2347/:2351.
  ⚠ **The P4b mini-audit did NOT catch this.** Its F3 confirmed
  "`#p(a.b.c)` round-trips" and "`get-in` works" — both TRUE, for the subset
  anyone probed. The fuller vocabulary was never run end-to-end. **15th
  consecutive premise refutation of this arc, and this time the refuted
  premise was the audit's own.**

  **TWO further findings surfaced while implementing the refusal** (both
  diagnosed by READING THE DATUM after two wrong guesses, per the diagnostic
  protocol — a branch-COUNT guard and a keyword-SHAPE guard both missed):
  1. **P1b-ii silently broke `expand-brace-branches`.** That expander keys on
     `$brace-params` (parser.rkt, inside `validate-selection-paths`), but
     P1b-ii re-minted `.{` from `$brace-params` to `$dot-brace` and the test
     was never re-pointed. So the brace expansion **stopped firing** and has
     been dead since — a regression nobody noticed, because its only consumer
     was already producing `<error>` values at 0 errors.
  2. **A brace spelling never arrives as a group at all.** The WS reader
     collapses `#p(a.{a1 a2})` into ONE symbol — `(path |:a.{a1 a2}|)` — so
     `parse-path-string` splits on `.` and mints `#:a` and `#:{a1 a2}` as
     ORDINARY KEYWORDS. Both pass any keyword test; the malformed thing is the
     segment's CONTENT. The guard is therefore a shattered-NAME test
     (whitespace or bracket characters in the segment), not a count or a shape
     test. The old `[else (expr-keyword seg)]` coerced this — and rename pairs
     — into a keyword wholesale: the same silent-catch-all class P4a spent its
     whole phase eliminating, one arm away from it.

- <a id="q-u12"></a>**Q_U12 — "WHOLESALE" MEANS THE `$dot-access` LEG ONLY; b-ii SPLITS THREE
  WAYS** ["(b) — $dot-access leg only, split it like b-i", owner 2026-07-31].
  The b-ii mini-audit (`wf_f8568392-b44`, 5 facets + critic @ `2e3fc14e`,
  1.22M tokens) found the ruling's own term ambiguous in a way nobody had
  anticipated: **the sort axis is THREE-valued, not two.**
  `rewrite-dot-access` has THREE live access legs minting THREE DIFFERENT
  nodes, each with its own subject-dispatch table:

  | leg | mints | block counterpart |
  |---|---|---|
  | `$dot-access` | `expr-map-get` | `x{…}` |
  | `$nil-dot-access` (`#.f`) | `expr-nil-safe-get` | **NONE** — `#{…}` does not exist |
  | `$postfix-index` (`[k]`) | `expr-get` | — |

  And the two PATH nodes have **divergent subject tables**: `expr-map-get`
  has a union leg `expr-get` lacks; `expr-get` has PVec **and List** legs
  `expr-map-get` lacks — so **`List` is a subject row the 2-D table's own
  enumeration omitted.**
  **The ruling**: b-ii migrates the **`$dot-access` leg only**. This is NOT
  the complection Q_U6 rejected — that objection was one SORT on two
  representations, whereas nil-safe access and ordinal/dynamic indexing are
  genuinely DIFFERENT SORTS, not spellings of one thing. Scoping to the
  named-step sort is where the Map posture and the (subject × sort) table
  actually live. `#.field` and `[k]` keep their nodes; their migration is a
  named follow-up, not an omission.
  **b-ii splits like b-i**: **b-ii-1** the Map posture + the semantic table
  (typing side) → **b-ii-2** the fold migration → **b-ii-3** the `_.field`
  rescue. Each with its own failing-test-first pass, because the per-caller
  obligations are **NOT uniform** (below).

**The P4c opening rulings [owner, 2026-08-01]:**

- <a id="q-u16"></a>**⭐ Q_U16 — THE BINDER UNWRAP MOVES TO A READER POST-PASS; Q_U8 SURVIVES,
  ONE LAYER EARLIER.** ["That looks like the appropriate shape."]
  **Q_U8 as ruled was NOT IMPLEMENTABLE**, and the refutation is verified, not
  argued. The P4c grounding audit (`wf_d7c035da-cee`, 6 facets + completeness
  critic @ `532474c0`, 7 agents / 1.53M tokens) found that §Q8.5 invariant 3
  site 8 (join `access-sentinel?` + take a `rewrite-dot-access` arm) and Q_U8's
  parser position-dispatch are **MUTUALLY EXCLUSIVE**: the preparse fold RUNS
  OVER BINDER POSITIONS. Main-session probe at HEAD, with the existing
  structural analogue: `ns t` + `defn f [x.a] x` → **`f : _ _ _ -> _ defined.`
  — a THREE-arity function at ZERO errors.** So `[x:Int]` would never reach the
  parser's binder consumers intact, and the parser cannot dispatch by position
  at a seat the sentinel never arrives at.
  **The escape that was tried and DOES NOT WORK** (recorded because it was the
  main session's own lean, and the adversarial options panel `wf_6f15c6ae-6a7`
  killed it): drop `access-sentinel?` membership and let the PARSER fuse, on the
  `$brace-params` precedent. Refuted on two independent grounds. (i)
  `rewrite-dot-access` has **FOUR call seats** — macros.rkt:2004 (map-literal
  contents) · :2714 (main preparse) · :6564 (the `|>` expander) · :6950 (the
  `$mixfix` expander) — and **TWO run inside PREPARSE, before the parser
  exists**, so `users:name` would work in plain application and break inside
  pipes, `.( )` operands and map literals. (ii) The `$brace-params` precedent is
  the WRONG STRUCTURAL CLASS: it is self-contained and never fuses onto a base,
  whereas **every base-consuming marker in the tree without exception is an
  `access-sentinel?` member**. Measured at HEAD: `[f x{a}]` groups to
  `(f x ($select-brace a))` and the FOLD makes it `(f ($select x a))`; without
  the fold `[f users:name]` stays three items and `f` receives TWO arguments.
  **THE RULING — the owner's reframe, and it keeps BOTH surfaces**
  [owner: "I want to keep the fused syntax (even more important than
  broadcast), and I have a strong preference for `:` as the broadcast glyph"]:
  1. **Mint UNIFORMLY at grouping** — Q_U8's positional rule stands verbatim,
     no context list, no tokenizer change.
  2. **`$bcast-step` JOINS `access-sentinel?`** and takes its fold arm, so it
     inherits all FOUR seats for free — which is exactly what the rejected
     escape could not do.
  3. **The binder UNWRAP moves to the READER POST-PASS** —
     `transform-let-blocks-stx` (parse-reader.rkt:2716), verified a GENERAL
     recursive syntax walk run from the reader's own entry point, already doing
     head-keyed structural classification (`let-headed?` · `classify-let-block`
     · `mark-let-goal-rhs` · `skip-reader-form-body`), and running at READER
     time — therefore **provably before all four fold seats**.
  **The owner's discriminator, and why it moved one axis over.** The proposal
  was to disambiguate on *whether the symbol left of `:` is a collection*. The
  premise is CORRECT and measured — the contexts genuinely differ (of **289**
  live multiplicity tokens **287 are SPACED**; the whole measured collision is
  **SEVEN** sites, every one a fused TYPE annotation in a BINDER position;
  broadcast lives in EXPRESSION position). But "is it a collection" is a **TYPE**
  question and the mint fires THREE LAYERS before typing — the same
  discriminator **Q_U10 already rejected as its option (c)** ("incoherent,
  elaboration precedes typing so the discriminator is not available where the
  mint happens"). It is not total even at typing: in `x:Int` the `x` is being
  BOUND and has no type yet by definition. The distinction that IS available
  early is **binder position vs expression position** — the same instinct,
  applied at the axis the pipeline can actually see.
  **BONUS, and it is why this is a repair rather than scaffolding**: the fold
  running over binder positions is a **LIVE LATENT DEFECT** today (`defn f
  [x.a] x` → 3-arity at zero errors). P4c is the phase that SURFACES it, not
  the phase that causes it.
  **COST, BOOKED PLAINLY — do not soften this**: the binding-form head list is
  a **PERMANENT hand-maintained enumeration with a SILENT failure mode** and
  **no retirement plan**. Not "almost a plan." Three conditions ride with it:
  (a) the unwrap is `eq?`-preserving BY CONSTRUCTION (the file already carries
  that warning at :2559); (b) **every binding form gets a test pin so a new form
  without an entry fails RED**; (c) the binder entries are made TOTAL, so an
  unrecognized shape is LOUD — otherwise a missed form reproduces the 3-arity
  class the ruling exists to fix.
  Rejected-with-reason: **moving the broadcast glyph off `:`** (would dissolve
  the cluster, but revisits the six-glyph mnemonic family — owner: strong
  preference for `:`; also BLOCKED, nobody verified a candidate glyph lexes
  intact where `:` does not) · **retiring the fused `[x:Int]` annotation** (the
  cheapest resolution by far — 7 corpus sites + 8 datum pins — but the owner
  ruled the fused surface MORE important than broadcast) · **parser-side fusion
  without membership** (the four-seat refutation above).

- <a id="q-u16b"></a>**Q_U16b — `users:0` IS A LEGAL ω STEP** [owner, 2026-08-01]. So the gate
  serves BOTH bands, and the discrimination question is LIVE.
  **Consequence, measured**: `colon-annotation`'s registered classifier returns
  **`'symbol`** (parse-reader.rkt:1166) while `keyword` returns `'keyword`
  (:1226), so the ordinal band is type-INDISTINGUISHABLE at grouping. Had the
  answer been NO, a gate keyed on `(eq? type 'keyword)` would have been
  dispatchable at HEAD with zero new machinery (colon-annotation would-mint is
  **ZERO** by census), six of the eight flipping datum pins would stop flipping,
  and the L1-fusion pin would have had to move off its corpus line. The owner
  took the fuller surface; the L1 pin **keeps** `users:0:userName`.
  **MECHANISM — settled by MEASUREMENT, not by ruling**: promote
  `colon-annotation` to a real token type. The rival (carry a pattern-provenance
  field on `token-entry`) was costed by the panel at three mutually incompatible
  numbers (25 / 10 / ~14–16) with OPPOSITE verdicts drawn from them; the main
  session enumerated exhaustively at HEAD — **25 constructor sites across 7
  files** (14 production · 11 test/bench) plus 1 `struct-copy`, and
  **`sre-rewrite.rkt` holds 4 of them, borrowing `token-entry` as a
  general-purpose term carrier** (`'binding`/`'sample`/`'constant`). That makes
  the provenance field a struct-OWNERSHIP question, not a field addition.
  Classifier-promotion wins on cost by an order of magnitude. ⚠ Ship it with an
  EXPLICIT arm at `token-entry->stx`, never relying on the `[else]` — its safety
  today is a coincidence of two else-arms doing the identity thing at the exact
  site the file documents as its silent-miss hazard, and coincidental safety
  expires silently. The provenance field is filed on its OWN merits
  (`$exp-literal` + `$rat-literal`, both self-documented as identity-erased),
  NOT as this gate's justification, and NOT as a scheduled revert of the
  classifier change — they are RIVALS carrying the same information, and "ship
  one with a revert clause" is the dual-path shape the rules block.

- <a id="q-u17"></a>**⭐ Q_U17 — A PATH SEGMENT IS A FIRST-CLASS `Step` VALUE.
  RULED B2** [owner, 2026-08-02 — "Assent to B2; place it as its own slice"].
  Opened at the owner's request, their stated concern being "bring Path
  Selection closest to FIRST-CLASSNESS". **Placement: its own slice — `PF`**
  (not inside P4c), because the `Step` reification and the `path-segments`
  repair are one change (U17b) and **P5's B3 same-spine merge depends on it**.
  **The defect.** The step vocabulary is a CLOSED UNION of SIX kinds, but the
  first-class API declares `segments : Path -> [List Keyword]` — true of exactly
  ONE kind. And `path-segments` **already whole-file aborts** (pre-existing,
  `f072c115`): it hand-builds a Prologos cons-chain where the marshaller wants a
  RACKET list, so that type has NEVER marshalled and `from-segments` /
  `path-append` are dead with it. **Path first-classness today is DECLARED, NOT
  DELIVERED.** Eleven production sites (path-ops ×5, reduction ×4, elaborator ×2)
  read segments as bare symbols via `(expr-keyword seg)` — a silent type lie for
  four of the six kinds. ω is the sixth member of an already-false contract; it
  does not create the gap, it makes it unignorable.
  **Proposed ruling — B2, REIFY a `Step` ADT**: `data Step` mirroring
  `select-step-kind`'s six kinds, `Path` stays GROUND and unparameterized,
  `segments : Path -> [List Step]`. Modelled on the `Datum` reification (8
  constructors, `prologos::data::datum`) — the pattern, NOT Datum-as-carrier,
  which Q_U5 already rejected.
  **Every alternative disqualified, each on a named ground**: **B1 defer** — by
  *Spec as Living Interface* (a live lie about a function that also aborts), NOT
  by First-Class-by-Default, whose foreclosure clause does not bite because Q_U5
  already made the first-class decision and the pending composition is NAMED;
  and there is **no zero-cost B1**, since the honest minimum deletes three dead
  declarations. **B3 parameterize** — UNNECESSARY: `step-sub` recurses through
  `List`, not `Path` (exactly as `datum-cons` recurses through `Datum`), so no
  parameterization and no mutual recursion is needed. **B4 un-unify** — reverses
  Q_U5's central ruling, reached through a four-step walk including an owner
  rejection. **B5 narrow** — First-Class by Default names this case almost
  verbatim (premature opacity). **B6 eliminator-first** (emergent, and the
  sharpest) — expressively EQUAL to B2, differing only in whether the
  intermediate is a first-class VALUE; under the Hyperlattice reading **a `data
  Step` is a lattice element** (mergeable, cell-storable, unifiable) and **a
  continuation is not** — the same argument Q_U5 used against selector-as-
  function. Disqualified because **P5's scope includes "B3 same-spine merge"**
  (verified from the tracker), which requires structural path comparison.
  **U17b — the repair and the typing are ONE change.** `racket-list->prologos-list`
  already exists in the marshaller, so the abort is fixed by returning a Racket
  list — but the repair must decide WHAT it returns. Fix it to keywords and the
  lie is re-enshrined; fix it to `Step` and the spec becomes true. Marshalling
  template already in-tree: `datum->datum-expr`.
  **U17c — P4c-4b PROCEEDS UNCHANGED** (all three panel clusters agree). The
  encoding is not where first-classness is won or lost: `(@bcast step)` is a
  unary constructor of a closed union with ONE producer and ONE classifier, so
  converting it later is cheap *because that is already the ADT shape*. Two
  riders, both main-thread verified: the `.pnet` gate item **drops** (`expr-path`
  IS registered — `regN! expr-path`), and the four "a wrapper never heads a
  branch" comments should be corrected in the same commit, polarity inverted
  (the index must PERMIT ω-at-head) — three of them justify an arm by a claim
  the same file refutes.
  **COST, honestly**: TWO ADTs, not one — the `cont` vocabulary
  (`dissolve | synth | collapse | collapse-synth | (rename . k) |
  (collapse-rename . k)`) reifies alongside `Step`. And it inherits the tax the
  `Datum` module documents in its own comment: wildcard `_` in a match over a
  user data type "triggers a type-inference limitation that causes module
  loading to fail", so every `Step` consumer enumerates all six arms. A known
  inference bug, not a design property — but real today.
  **INCOMPLETE BECAUSE** the eleven consumer sites migrate through one
  marshaller, which is not P4c-4b's work; deferred to the slice that also
  repairs `path-segments` (the same change, per U17b) — **now slice `PF`**.
  Grounding: options panel `wf_68178bd3-eea` (7 agents / 1.24M tokens), every
  load-bearing claim R-lens-verified on the main thread.
  **Next free Q-label after this: U20.**

- <a id="q-u18"></a>**⭐ Q_U18 — RULED IN FULL [owner, 2026-08-02].**
  **(i) The unknown-head default flips to PRESERVE** ("worth the trade").
  **(ii) The grant is G4** — hold TEST-ONLY until P4c-4c's value semantics land,
  then grant. **G2 (retire the enable-set) is the recorded LEAN, NOT a ruling** —
  to land with or after P4c-4c, and **RE-EVALUATED at that point**.
  *(Original framing, kept because the correction below is the point:)* the
  unknown-head policy AND the first production grant are ONE decision, and it
  GATES EVERY CORPUS UNCOMMENT.
  Opened 2026-08-02 at the P4c-4c mini-audit. They look like two questions and
  are one: the policy is *why* there is no production grant, so until it is
  ruled the entire broadcast surface is reachable only from tests. **That is the
  "Validated ≠ Deployed" shape and it should be named as such**, not left in
  DEFERRED.
  **THE MEASUREMENT THAT FORCES IT** (re-verified on the main thread at
  `17086a09`): a **bare top-level ω is STRIPPED under EVERY grant** —
  `users:name` → `((users :name))` even when its own head `users` is granted,
  even under a broad grant — because the head is unknown to both the cond and
  the scanner, so `[else]` blanket-strips. **Every ω line in the acceptance file
  is a bare top-level command**, so no acceptance marker can be exercised at
  all. Compounding: `broadcast-enabled-contexts` has **ZERO production setters**,
  so `process-file` runs at default `'()` regardless.
  **WHY IT IS HARD, and it is not new**: P4c-3 measured that the head-keyed walk
  **cannot decide it in EITHER direction** — strip kills application-position
  broadcast, preserve regresses live binder positions under unknown heads
  (`[add ?x:Nat ?y:Nat] = 5N`) — ⚠ **THAT HALF IS REFUTED, see below**, and both spellings were claimed to be `[SYMBOL item item]`,
  structurally indistinguishable at the reader. So Q_U18 is not "pick an arm";
  it is "find the discriminator, or rule that broadcast ships only where a
  recognized head scopes it." DEFERRED 32's open half is this question.
  **DUE**: before ANY corpus uncomment. Nothing in P4c-4c or P4d's carrier work
  depends on it; every acceptance-marker deliverable does.

  **⭐⭐ CORRECTION 2026-08-02 — THE COUNTER-EXAMPLE AGAINST *PRESERVE* DOES NOT
  EXIST, AND THIS REOPENS THE QUESTION.** `?x:Nat` is glued into **ONE TOKEN** by
  `recognize-narrow-var-annot`, so `bcast-step-trigger?` can NEVER fire on it.
  Measured at `526d3de1`: `[add ?x:Nat ?y:Nat] = 5N` reads as
  `((= (add ?x:Nat ?y:Nat) ($nat-literal 5)))` — byte-identical under a grant of
  `add`; **no `$bcast-step` is minted**. So the two spellings are NOT both
  `[SYMBOL item item]`: one is `[SYMBOL glued-token glued-token]`, the other
  `[SYMBOL base ($bcast-step …)]`.
  ⚠ **`parse-reader.rkt`'s OWN COMMENT already said this** — *"Immune by
  construction: `?x:T` (glued to ONE token by narrow-var-annot)"* — in the very
  file being edited. The false claim was INFERRED from "this corpus line runs 0
  errors today" **without checking whether it MINTS**; that is the
  assert-a-mechanism-instead-of-measuring-it failure this arc keeps recording,
  and the tree contained the refutation in a comment.
  **WHAT NOW HOLDS, MEASURED**:
  · **PRESERVE has ZERO measured corpus regressions** — an exhaustive census over
    **795 `.prologos` files plus WS strings embedded in `.rkt` tests** found NO
    live site that is "plain-identifier fused annotation · binder position ·
    unknown head". Every binder-shaped site is either under a head the walk
    already recognizes (`defn` ×5, `let` ×4, `defr` ×1) or is `?`-glued and never
    mints.
  · The five "measured casualties" of the pre-inversion default (`capability`,
    `Pi`, `Sigma`, `DSend`, `DRecv`) have **ZERO fused-annotation sites** in
    `lib` or `examples` — they were **SYNTHETIC PROBES**, not corpus sites. Real,
    but they price the risk very differently from "the corpus breaks".
  · **The `?`-glue has ONE HOLE: digit-headed segments.** `?x:0` DOES mint
    (`((def q := ?x ($bcast-step :0)))`); `?x:Nat`, `?x:w`, `?x:Int:Even` all
    glue. Verified.
  · **The one PRINCIPLED counter-example** is macro pattern variables:
    `pattern-var?` accepts any symbol not in ~20 enumerated reader sentinels, so
    `[myform x:Int]` is a genuine binder under a genuinely unknown head. **Zero
    instances in tree; constructible in one line.**
  **⭐ AND A THIRD SEAT THE FRAMING MISSED**: `parser.rkt` already ships a
  `bcast-step-binder` diagnostic kind distinct from the expression-position
  `bcast-step`, raised from **THREE binder consumers**, whose message reads
  *"this is a BINDER position … the fused spelling should work here"*. **The
  parser can already tell the two apart — because a binder consumer knows it is
  one.** So the honest form of Q_U18 may not be "which arm does the READER pick"
  but "**why is the reader deciding this at all?**"
  Grounding: options panel `wf_46bd24b7-5ca` (7 agents / 1.32M tokens); both
  refutations re-verified on the main thread before being recorded.

  ---

  **⭐ THE RULING (policy half) — owner, 2026-08-02: "worth the trade".**
  **The unknown-head arm flips from STRIP to PRESERVE.** Adopted as option `O1`,
  *"the sigil already IS the discriminator"* — and the word **already** is what
  makes it a ruling rather than a gamble:
  · `recognize-narrow-var-annot` GLUES `?x:Nat` into ONE TOKEN, so the
    logic-variable binder population **cannot mint, by construction** — not by
    enumeration, not by a maintained table. That is the discriminator the
    question was hunting for, and it was already in the tree one layer below
    the walk.
  · **PRESERVE therefore has ZERO measured corpus regressions** (795-file
    census). The evidence that had motivated STRIP was thinner than recorded:
    the five "measured casualties" were **synthetic probes**, not corpus sites.
  ~~**OWED WITH IT — the one real defect the sigil analysis exposed**: close the
  DIGIT-HEADED HOLE.~~
  ⚠ **CORRECTED 2026-08-02, BEFORE ANY CODE — "the one real defect" IS NOT ONE.**
  I recorded the digit hole from the READER DATUM alone (`?x:0` does not glue and
  does mint) without probing what the spelling MEANS end to end. Measured:
  **`?x:0` and `?x:w` are BOTH ALREADY REFUSED**, by an existing guided
  diagnostic that names them explicitly — *"`:0` is not a type — a fused
  parameter annotation must name one, as in `x:Int` (digit-headed `:0`/`:7` and
  `:w`/`:m` are multiplicities)"*. Only `?x:Nat` is legal (`r : _ defined.`).
  **So there is NO legal spelling at risk**, and the gluing asymmetry between
  `?x:0` and `?x:w` is invisible: both reach the same refusal by different routes.
  Narrower still: the PRESERVE flip only changes the **unknown-head** arm, and
  `defr`/`defn`/`spec`/… are all RECOGNIZED, so the scanner answers for them and
  the flip never runs there. The residual is `?x:0` **under an unknown head** —
  an already-illegal spelling under a head the walk does not know. The
  consequence is a **diagnostic-quality change** (the `bcast-step-binder` message
  instead of the sharper multiplicity one), not a break.
  **NOTHING IS OWED AS A PREREQUISITE.** If the sharper diagnostic is worth
  protecting that is a diagnostic-quality item, booked rather than landed here.
  ⚠ Third time this session a recorded mechanism claim fell to an end-to-end
  probe, and the pattern each time was **reading the datum and inferring the
  meaning**.
  **THE ACCEPTED RESIDUAL, named rather than smoothed over**: `pattern-var?`
  accepts any symbol not in ~20 enumerated reader sentinels, so macro pattern
  variables need no sigil — `[myform x:Int]` is a genuine binder under a
  genuinely unknown head. **Zero instances in tree; constructible in one line.**
  Under PRESERVE it takes the EXISTING `bcast-step-binder` arm, a per-command
  guided error already saying *"this is a BINDER position … the fused spelling
  should work here"*. So the failure is LOUD and RECOVERABLE.
  ⚠ **This is a knowing, narrow exception to the INVERTED DEFAULT's criterion**
  ("a miss must never mean *your working code now errors*"), and it is recorded
  as such: it errors only for code that **does not exist in the tree**, the
  diagnostic already exists, and the alternative — STRIP — makes broadcast in
  application position permanently unreachable, which the acceptance-marker
  evidence shows is most of the feature. **Trade accepted by the owner on that
  framing.**
  **⭐ THE GRANT — RULED G4** [owner, 2026-08-02]: **hold TEST-ONLY until
  P4c-4c's value semantics land, then grant.** The enable-set STAYS, production
  stays at default `'()`, and broadcast remains reachable only from tests until
  there is something for it to evaluate to. Sequencing, not mechanism — and the
  honest reading of "Validated ≠ Deployed": the gap is now **scheduled and
  named**, with P4c-4c as its discharge, rather than left open-ended.

  **⭐ G2 IS NOW RULED — IT LANDS *ALONGSIDE* P4c-4c** [owner, 2026-08-04:
  *"G2 alongside P4c-4c"*]. G2 = retire the enable-set entirely; head-specific
  dispatch becomes unconditional. The re-evaluation the ruling below scheduled
  was **held at the P4c-4c opening and resolved there**, on the §4.1 framing:
  the flip is inert until G2, so G2 is not cleanup but *the thing that delivers
  the feature*, and P4c-4c's value semantics are what make the working set
  observable — which is the input to the G2 decision. Landing them together is
  what makes that input available at the moment it is needed, instead of
  shipping value semantics for a surface nothing can reach.
  ⚠ **CONSEQUENCE, and it is the operative one for the slice**: G2 is the FIRST
  change in this arc where **production behaviour actually moves.** Every prior
  P4c slice was byte-identical at the default `'()` and could lean on that; from
  here the **corpus A/B is load-bearing, not a formality**, and the P4c-4b
  targeting (12 mintable files) must be RE-DERIVED rather than inherited.
  ⚠ **And the test surface inverts**: P4c-4a's pins were mutation-verified
  AGAINST the grant seam, and one is named for *"the flip is INERT AT DEFAULT"*.
  Retiring the seam turns some of those pins RED and — the worse case — makes
  others **VACUOUS**. Both classes must be enumerated separately before the edit;
  a pin that silently stops discriminating is the failure this track keeps
  paying for.
  The argument FOR G2, recorded at the time it was still a lean and unchanged by
  the ruling:
  · its stated justification has expired TWICE — "the sentinel has no consumer
    until P4c-3" (the consumer exists) and gating the head-keyed decision (now
    settled by (i));
  · keeping a mechanism alongside a settled decision is this project's
    **belt-and-suspenders red flag**, not defence-in-depth;
  · the **CHAIN rule** — an ungranted ancestor strips a granted descendant,
    granting `wrap` does not help while granting `defn` does — exists ONLY
    because there is an "ungranted" state to inherit. G2 dissolves it.
  ~~**RE-EVALUATION TRIGGER**: at P4c-4c's close~~ — **HELD AND RESOLVED at the
  P4c-4c OPENING instead** (owner, 2026-08-04): G2 lands **alongside** P4c-4c,
  not after it. The trigger is struck rather than deleted because the reason it
  moved is the substance: waiting for the close would have meant shipping value
  semantics for a surface that nothing outside the battery can reach.

  **✅ THE FLIP LANDED — `e71ef6b8`** (suite 9835/482/0 · battery 340 → 344 ·
  acceptance unchanged · default behaviour pinned unchanged). Two findings from
  landing it, both recorded because they correct this very entry:

  1. ⚠ **THE "ONE REAL DEFECT" — the digit-headed hole — IS NOT A DEFECT.** See
     the struck text above: `?x:0` AND `?x:w` are BOTH already refused by an
     existing guided diagnostic. No legal spelling was at risk. Nothing owed.
  2. ⚠⚠ **THE FLIP IS INERT IN PRACTICE UNTIL G2, WHICH REFRAMES G2 ENTIRELY.**
     It works — with the inner head granted, `[one users:name]` becomes
     `(one users ($bcast-step :name))`, and it nests. But the enable-set's FIRST
     arm strips any node whose OWN head is not granted, and granting every
     function name is absurd. **So the flip alone does NOT unlock
     application position.** G2 is not "retire expired scaffolding" — it is
     **the thing that delivers the feature**. Pinned in the battery
     ("Q_U18: the flip is INERT AT DEFAULT") so it cannot be forgotten.
     ⇒ **When G2 is re-evaluated at P4c-4c's close, weigh it as a FEATURE
     decision, not a cleanup.** Consider whether the re-evaluation belongs
     ALONGSIDE P4c-4c rather than strictly after, since P4c-4c's value semantics
     are what make the working set observable, and that observation is the input
     to the G2 decision.
     ✅ **THAT IS WHAT THE OWNER RULED, 2026-08-04 — ALONGSIDE.** See the G2
     block above; the re-evaluation trigger moved from P4c-4c's close to its
     opening.

  **⚠ SEQUENCING NOTE — (i) IS INERT AT DEFAULT AND CAN LAND EARLY.** The
  unknown-head arm only runs when preservation is ACTIVE; at `'()` the first arm
  blanket-strips and that arm never executes. So the PRESERVE flip **and the
  digit-hole fix** are testable through the P4c-4a grant seam and safe to land
  before the grant itself — they change nothing a user can see until G4 fires.

- <a id="q-u19"></a>**⭐ Q_U19 — `^` ON A BROADCAST: THE PATH-POSITION REFUSAL IS
  RATIFIED; ONE GUIDED MESSAGE UNIFIES THE THREE ROUTES [owner, 2026-08-07 —
  "(A) ratify and unify the diagnostics"].**
  **The P4d opening audit reframed the question before it was asked** (measured
  at `ea9c19e4`, re-verified on the main thread): `^` on an ω step **already
  re-keys, semantically, in BLOCK position** — `cfg{admins:name^alias}` →
  `{:admins @[{:alias "a"} …]} : {:admins [PVec {:alias String}]}` at 0 errors,
  and the sub-block spelling `xs:{name^alias}` → `[PVec {:alias String}]`
  likewise — so the choice was never *refuse vs build re-keying*; it was
  whether the PATH spelling should join a shipping block behaviour. **Ruled NO,
  on the structural asymmetry**: in block position the ω output HAS a key (the
  block entry) for `^` to rename; in path position `xs:name` is
  `[PVec String]`, BARE — there is no key to re-key, which is what the existing
  refusal already says. Option (B) — path-position promote, `xs:name^alias` ⇒
  `[PVec {:alias String}]` — REJECTED: it INVENTS a key rather than renaming
  one (a different operation wearing rename's spelling), and the block spelling
  already expresses that intent. Monotone (spec §3.6): the ratified refusal can
  become a meaning later at zero cost.
  **The measured path-position surface was THREE behaviours, two unguided**
  (all per-command, no aborts — each probed with a following `def` that
  survives):
  · `xs:name^alias` / `xs:name^` / `xs:name^_` → the pre-existing guided
    refusal — whose text says "a **field access** has no output key", the wrong
    noun for an ω step;
  · `xs:{name}^alias` / `xs:{name}^` → **`Unbound variable ^`** (unguided);
  · `xs:0^alias` → **`Unbound variable :`** (unguided, blaming the wrong
    token).
  **Deliverables (P4d, riding the diagnostics slice)**: ONE broadcast-aware
  guided refusal covering all three routes — name the ω step, state the
  no-output-key ground, and point at the block spelling that works
  (`xs:{name^alias}`, probe-verified above); route both unbound-variable
  fall-throughs into it; update the "P4c-4b: the payload's THREE sub-cases" pin
  to pin the DECISION (it froze an accident; it must now fail for the reason
  its name claims). ⚠ The original entry's "under a grant" clause is OBE — G2
  retired the grant, so the surface is reachable UNCONDITIONALLY at the
  production default.

  **⭐⭐ AMENDED 2026-08-08 [owner — "leave the dot string alone, add a broadcast
  sibling"; then "all three"]. READ THIS BEFORE TOUCHING ANY CODE — the text
  ABOVE, written before the slice-4d mini-audit, would authorise the one edit
  this ruling FORBIDS.** "Unify" means ONE NEW message that the three routes
  funnel into — it does **NOT** mean editing the existing string.
  · **The dot string stays BYTE-IDENTICAL.** `re-keys the OUTPUT` is ONE
    production site (`parser.rkt`, the `[(ormap select-step-cont (car branches))]`
    arm) serving TWO audiences — dot, where "a **field access** has no output
    key" is the CORRECT noun, and broadcast, where it is wrong, ever since
    P4c-3a made `select-step-cont` ω-transparent (`syntax.rkt`'s
    `select-step-cont` recurses through `select-bcast-inner` — that recursion IS
    the routing). The complaint at the bullet above is about the BROADCAST
    audience only. Its DOT pin (`"verify S2: \`^\` in a DOT access REFUSES"`)
    must keep passing untouched; only the ω pin moves.
  · **The discriminator is PER-STEP, not per-branch.** `ormap` returns the CONT
    and DISCARDS which step carried it. Measured at `2fd6b68e`: `ys.a:b^c` (caret
    on a genuine ω step) and `xs:a.b^c` (caret on a DOT step, in a chain the user
    opened with `:`) BOTH take the message today. Find the step (`findf`), then
    ask `select-step-kind` — it already returns `'bcast` (`syntax.rkt`) and is
    ALREADY imported by `parser.rkt` (`select-bcast-step?` is provided but NOT in
    the `only-in` list; the in-file idiom is the kind dispatcher). Zero new
    plumbing.
  · **The three routes fail at THREE LAYERS — this is three seats of work, not
    one funnel** (owner ruled "all three" 2026-08-08): route 1 fails INSIDE
    `segment-select-items`, post-mint (small, clean); `xs:{name}^alias` never
    ENTERS segmentation (`^` is ident-CONTINUE but not ident-START, so the caret
    survives as a bare sibling OUTSIDE the brace group and the form becomes an
    APPLICATION) — a FOLD arm, on the `ordinal-rekey` element-wise precedent;
    `xs:0^alias` mints NO sentinel at all — it fails in the TOKENIZER and the
    fold's entry gate never opens.
  · **The route-1 spelling set UNDER-COUNTS: the COLLAPSE family also reaches
    it.** `xs:name^-` takes the message (measured), matching the dot pin's own
    four spellings.
  · **⚠ PRECEDENCE CONSTRAINT**: `xs:name^^a` takes `split-caret-lexeme`'s
    WELL-FORMEDNESS error first ("one `^` per segment…"). The sibling must NOT be
    installed above it, or a true specific message is replaced by a generic one —
    the class the slice-3 verify already caught once in this track.
  · **⚠ MONOTONICITY**: the refusal stays `'path`-SCOPED. Block-position ω-caret
    is LIVE at 0 errors today (`cfg{admins:name^alias}`, `xs:{name^alias}`) and
    the acceptance file carries commented `[D4.P5]` block-position targets — a
    wider refusal would refuse a spelling the track has committed to meaning.
  · ⚠ A FALSE PREMISE SITS IN THE EDITED LINES: `parser.rkt`'s comment four lines
    above the string claims `make-select-bcast` "has ZERO production callers at
    HEAD". It has FOUR, all in that file. Correct it in the same diff.

  *(Original entry, kept for the record:)* Opened 2026-08-02 at the P4c-4c
  mini-audit. Under a grant the parser ALREADY builds
  `(@bcast (@key name (rename alias)))` — it is constructible today — and it
  lands on the pre-existing `^`-in-path-access refusal **only because
  `select-step-cont` was made ω-transparent at P4c-3a**. Whether the intended
  behaviour is *refused, guided* or *re-keys the broadcast output* is stated
  nowhere. The pin at `tests/test-path-selection.rkt` ("P4c-4b: the payload's
  THREE sub-cases") therefore froze an ACCIDENT, not a ruling.

- <a id="q-u20"></a>**⭐ Q_U20 — A SUB-INNER ω ASSEMBLES AT 'block, ALWAYS
  [owner, 2026-08-05 — "Assent — sub-inner assembles at 'block, always"].**
  The lift threads exactly ONE sort, and the two inner kinds need OPPOSITE ones:
  a SYMBOL inner extracts ('path — 'block would wrap `xs:a` as `[PVec {:a T}]`),
  a SUB inner assembles ('block — 'path fails its one-component constraint). So
  the lift takes a PER-INNER-KIND sort decision: `users:{a b}` over
  `[PVec {:a A :b B}]` is a PVec of NARROWED ROWS, `[PVec {:a A :b B}]`, by
  applying the sub-block's OWN branches to each element at 'block and
  re-wrapping. The spec (§3.2.1) and the corpus's own expected values both state
  this reading; the extent pair only makes sense under it. Hard-coded as a
  semantics RULE of the lift rather than inherited from context — that is the
  ruling, not an implementation accident. Grounding: mini-audit
  `wf_e15a1ef6-dfb` (its sub-inner facet measured the sort collision at both
  layers).

- <a id="q-u22"></a>**⭐ Q_U22 — `^` AT A LEAF IS ARITY-UNIFORM: n=1 YIELDS
  `⟨T⟩`, NOT THE BARE VALUE [owner, 2026-08-08].** Raised co-designing Q2: the
  owner's reading of *"dropped means dropped"* (spec §3.4) predicts that
  `xs:host^` should give `@["a" "b"]` — the values, unwrapped — where HEAD gives
  a vector of 1-tuples. **Ruled the other way, and NOT on implementation cost.**
  Two dropped keys at one level are FORCED to be positional (you cannot put two
  unnamed things in a record), so keyless→tuple is settled at n=2 by the live
  unzip `party:{name^ level^}` → `[PVec ⟨String Int⟩]`. Collapsing n=1 to the
  scalar would make the operator ARITY-DEPENDENT — one dropped key unwraps, two
  tuple up — which breaks the algebra's uniformity for a cosmetic gain. Owner:
  the coherence of the algebra is the deciding reason, and **`<` (disclose/pick)
  plus `join` recover the ergonomics** that the bare-value reading was reaching
  for, so nothing is lost expressively.
  ⚠ Second, independent ground, recorded because it survives even if the
  algebra argument is later revisited: n=1 unwrapping would make `xs:{name^}`
  a SECOND SPELLING of `xs:name`, which is exactly what slice 4c's owner ruling
  retired ("stop teaching a second spelling"). The bare-value spelling already
  exists and is `xs:name`.
  **Consequence for Q2, accepted eyes-open**: `cfg{servers:host^}` reads as
  `{:servers @[⟨"localhost"⟩ …]}` under the caret-once fix — honest, uniform,
  and less pretty than the owner's intuition. That is the trade, named.

- <a id="q-u23"></a>**⭐ Q_U23 — `*` IS SORT-GENERIC: IT DELETES THE LAYER THE
  PRECEDING STEP CREATED. `.*` row-splat RETIRES as a separate operator
  [owner, 2026-08-08 — "Good on the stronger form of `*` with no `^`"].**
  Opened by the owner at the P4e design round with the question *"is `m{k}` not
  the same as `m{k.*}`?"* — and it is. Measured at HEAD: `cfg{database}` →
  `{:database {…}}`, which is exactly the corpus's own recorded expected value
  for `app-config{database.*}`. **`.*` is an IDENTITY wherever the head key
  survives**, because projection-with-ancestry re-nests whatever the splat
  lifted under the surviving key. It does work only after `^` has dissolved that
  key — and even then only alongside SIBLINGS, since `cfg{database^.*}` alone is
  byte-identical to `cfg.database`.
  **The ruling**: one rule, one operator — *`*` deletes the layer the preceding
  step created; the SORT follows the layer.* So `:diags*` deletes the vector
  layer `:diags` made (mapcat), and `database*` deletes the nominal layer the
  `database` branch made (splat). `cfg{database* version}` →
  `{:url …, :pool-size 10, :version "1.0.0"}`, all-keyed, no `^`.
  **This CLOSES spec §8 Q4** ("`*` on Map layers — is there a nominal join?")
  in the affirmative, by the same argument §3.2.3 used to adopt map-generic `:`:
  a vector-only `*` leaves the key-sort thesis decorative exactly where it
  matters. `.*` was the residue of a unification that stopped one step short —
  path-position `.*` was already subsumed by map-generic `:`.
  **Rejected-with-reason**: `database^.*` and `database^*` (the owner's first
  spelling) — both over-spell, because `^` dissolves a key `*` was going to
  delete anyway, and renaming before a delete is inert. ⚠ Neither could be read
  as a SEQUENTIAL composition in any case: **measured**, `cfg{database^ version}`
  is an **L4 mixed keyed/keyless** error, so `^` alone makes the branch keyless
  and any repair-by-`*`-afterwards has an ill-sorted intermediate. A `^*`
  spelling would have had to be ONE glued continuation, like Q_T7's `^-`.
  **The one honest asymmetry, recorded**: vector join is TOTAL (concatenation
  cannot collide); nominal join CAN collide. Collisions route to §3.6 Ruling B —
  and P4e needs no P5 machinery for it, because P3a already landed strict merge
  for plain keys before `make-record` can last-win (PS7's shippable waypoint).
  GROQ's last-wins is the precedent the spec explicitly rejects.
  **Lexical dividend — ⚠⚠ MATERIALLY UNDER-SCOPED AS FIRST WRITTEN; CORRECTED
  2026-08-08 BY THE P4e MINI-AUDIT (`wf_5fb7131d-63a`), re-measured on the main
  thread.** The original claim read: *"Spelled `database* there is no `.` to
  shatter — both bands go through ONE trailing-star splitter."* **That is true
  ONLY for IDENTIFIER-headed layers.** The reader's star-fusion is
  IDENTIFIER-SPECIFIC, not sort-generic: `ident-continue?` admits `*`, so the
  star joins an identifier token — but a NUMBER token and a CLOSER token END
  before it. Measured at HEAD:
  · `cfg{database*}` **FUSES** → `field :database*` (one nominal key) ✅
  · `m{0*}` **SHATTERS** → L4 mixed keyed/keyless ❌
  · `m{0 *}` → the **BYTE-IDENTICAL** L4 error, so glued and spaced carry NO
    distinction — **the ordinal splat is UNSPELLABLE**, the information is
    destroyed at the reader exactly as it is for `.*` ❌
  · `m:0*` → **`Unbound variable :`** — adding ONE character DESTROYS an
    existing `$bcast-step` mint, so the landed ω `*` guard (the `#rx"[*]"` arm,
    which keys on the `$bcast-step` PAYLOAD) structurally CANNOT fire on it ❌
  · `m:0 *` → `Could not infer type [m.:0 [arithmetic::* …]]` — the star became
    ARITHMETIC MULTIPLY applied to the selection ❌

  > **⚠ THE ERROR TEXTS ABOVE ARE STALE — re-measured 2026-08-10 at `19560a7c`.
  > THE STRUCTURAL CLAIMS ALL HOLD; THE SYMPTOMS MOVED, because the P4e-0 revert
  > was PARTIAL.** `d0ac2a58` took out the count-changing MINT but left the
  > guided-error surface `bfba68d5` had added (`parser.rkt` gained 169 lines in
  > the WIP; 54 came out). So attempt 3 does **not** open on a clean
  > pre-attempt-1 tree. At HEAD:
  > · `cfg{database*}` → *"`*` (flatten) is not implemented yet — `database*`
  >   would delete one layer of what the preceding step produces"* — still FUSES
  >   (it reaches the consumer as one nominal key), then guides-refuses. Claim ✅
  > · `m{0*}` and `m{0 *}` → **both** *"`*` — `*` is postfix; it attaches to the
  >   END of a segment"*, not the L4 mixed keyed/keyless error recorded above.
  >   **BYTE-IDENTICAL still holds**, which is the load-bearing half — the
  >   ordinal splat remains UNSPELLABLE. Claim ✅, symptom changed.
  > · `m:0*` → `Unbound variable`. Claim ✅ — one character still destroys the
  >   `$bcast-step` mint.
  > · `m:0 *` NOT re-confirmed: the 2026-08-10 probe used `m := @[10 20 30]`, a
  >   different subject from the original, so it errored on the broadcast before
  >   reaching the star. **Unverified at HEAD**, not refuted — re-probe with the
  >   original subject before relying on it.
  >
  > **The lesson is the recorded one**: *a fact has a timestamp.* The symptom
  > text is not the mechanism; pin the mechanism.

  So the grouping fix this ruling claimed the `database*` spelling had DELETED
  is **still owed for every non-identifier layer head** (ordinal, sub-block,
  bracket/paren closers). The dividend is real but its scope is the nominal and
  keyword layers ONLY — which are the layers this ruling's EXAMPLES use, and not
  the layers its RULE generalizes over. **The sort-generic rule stands as
  SEMANTICS; its lexical realization does not follow for free.**
  What DOES survive: the routing half. `$select-path` (the bare dot path,
  outside any block) calls the same `segment-select-items` fold as the block and
  ω bands, so ONE splitter can serve every identifier-headed surface — at ≥3
  call sites, mirroring `split-step`'s three, because the ω payload arrives
  colon-leading and string-stripped while the others arrive as bare symbols.

- <a id="q-u24"></a>**⭐ Q_U24 — `*_` IS THE PROVENANCE VARIANT, AND IT LANDS
  WITH BARE `*` [owner, 2026-08-08 — "Yes to land `*_` with bare `*`"].**
  Proposed by the owner as a shorthand for the collision case. `*_` splats and
  synthesizes each lifted key from the deleted layer:
  `cfg{database*_ version}` → `{:database-url …, :database-pool-size …,
  :version …}`. **It is the answer to Q_U23's one asymmetry**: it removes
  nominal-join collisions BY CONSTRUCTION rather than erroring, and it rescues
  the per-level case — `regions*_` → `{:ap-host …, :eu-host …, :us-host …}` —
  which under bare `*` collides on every key of a homogeneous Map-of-Map and is
  therefore almost always an error. **They land together** because shipping bare
  `*` alone would deliver an operator whose headline nominal use fails on every
  realistic input, teaching a refusal whose remedy we already have.
  **Precedent**: Q_T7's `^-_`, which D4 already describes as "the flat
  *provenance* recovery… **which is where a structural effect belongs**."
  ⚠ **REQUIRED RULING, do not inherit the wrong parent**: `^_`'s stated rule is
  *"Dropped means dropped — `^`-dissolved segments do not contribute"* (spec
  §3.4), whereas `*_` wants the DELETED key as the prefix. `*_` follows `^-_`'s
  rule, NOT `^_`'s. Inheriting `^_`'s silently degrades `*_` to bare `*`.
  **Spelling**: `*_` is ONE glued continuation, matching `^-_`'s shape. `*^_`
  does not type — `^_` synthesizes ONE key while a splat lifts many.

- <a id="q-u25"></a>**⭐ Q_U25 — BRANCH-INITIAL `:` IS SCOPED INTO P4e FOR THE
  ORDINAL² TRANSPOSE; ORDINALS NEED NO `^` [owner, 2026-08-08 — "the inner
  broadcast should be scoped in now… ordinals don't need `^`, since they already
  return their value-at-index"].** The owner reached this exploring a matrix
  rotate, from an explicitly APL-inspired reading.
  **The owner's refinement CORRECTS THE SPEC against a landed ruling.** Spec
  §10.6 writes the v2 transpose `m{:0^ :1^ :2^}`, but **Q_T4a rules that `^`
  NEVER attaches to an ordinal** — measured at HEAD, `values:{0^}` is the
  guided error *"an ordinal has no key."* The two cannot both stand; the spec
  sketch predates the ruling. §3.3 already makes ordinal branches keyless BY
  BEING ORDINAL ("keyless branches: `^`-terminated, **or ordinal `{N M}`**"), so
  the `^` was never introducing a key — it was marking keyless, which ordinals
  already are. **The correct spelling is `values{:0 :1 :2}`.**
  **⭐ CONSEQUENCE — W2's EXIT IS SMALLER THAN IT WAS WRITTEN.** Spec §7's W2
  ("Pure transposes — ordinal² and nominal²") states its exit as *"generalize
  `^` to set (§7.3) **+** admit branch-initial `:`."* The first conjunct is
  needed only for the **nominal²** pivot (`strings{:home^home …}`, where `^home`
  is a genuine rename). For the **ordinal²** matrix, keylessness is free — so
  the ordinal half is reachable with branch-initial `:` ALONE, no v2 `^`-as-set.
  **⚠⚠ "AND NO NEW TYPING MACHINERY" — REFUTED 2026-08-08 by the P4e mini-audit
  (`wf_5fb7131d-63a`), reproduced on the main thread. The claim is struck.**
  ~~measured, `values{0 1 2}` → `⟨[PVec Int] [PVec Int] [PVec Int]⟩` — the
  transpose's target type ALREADY types and prints. Same type, different value;
  only the branch head changes from indexing to broadcasting.~~
  **THE SUPPORTING MEASUREMENT WAS STRUCTURALLY INCAPABLE OF DETECTING THE
  DIVERGENCE IT WAS CITED TO RULE OUT** — it used a **SQUARE** (3×3) matrix,
  where `{0 1 2}` is the IDENTITY and where the identity and the transpose share
  a type. Re-run NON-SQUARE (2×3), it collapses: `nm{0 1}` →
  `⟨[PVec Int] [PVec Int]⟩` — **TWO** components, the ROWS, while the transpose
  of a 2×3 has **THREE**. The probe only ever proved the target type is
  EXPRESSIBLE, which was never in doubt.
  **And the branch head alone does not get there**, because a branch inherits
  the BLOCK sort, which WRAPS: measured, `nm:0` → `@[1 4] : [PVec Int]` (the
  column, at `'path`) but `nm:{0}` → `@[@[1] @[4]] : [PVec ⟨Int⟩]`. So
  `{:0 :1 :2}` yields `⟨[PVec ⟨Int⟩] × 3⟩`, a transpose wearing an extra
  1-tuple layer — not the transpose.
  **What the refutation LEAVES INTACT, and it is the useful half**: the correct
  COLUMN already exists at `'path` (`nm:0` → `@[1 4]`). So the missing piece is
  **per-position SORT CONTROL at a branch head** — the transpose is three
  `'path` columns assembled — NOT new extraction machinery. That is a narrower
  job than "build a transpose", but it **collides with the landed `'block`
  collapse** and is therefore real design work, not a spelling change.
  ⚠ **Q_U25 (ii) is consequently CONTINGENT**: its keyless/no-`^` half stands on
  its own (verified — ordinal and ω-over-ordinal branch heads are already
  keyless), but *admitting the SPELLING does not produce the TRANSPOSE*.
  **✅ OWNER RULED 2026-08-08 — branch-initial `:` STAYS IN P4e SCOPE** ("if it
  is just a `cond` arm, then I see little reason not to include it"). The arm is
  indeed one `cond` arm — the `kw-sym?` refusal in `segment-select-items`, which
  fires on precisely this spelling today.

  **⭐ WHAT THE ARM ACTUALLY DELIVERS, and why it is COHERENT rather than
  broken** (settled 2026-08-08; a hypothesis that it was a live Q_U20 violation
  was FORMED AND TESTED TO DESTRUCTION — recorded because the negative result is
  the load-bearing part). The extra `⟨⟩` layer is **two landed rulings applied**,
  not a defect:
  · A broadcast step's sort is inherited at `select-bcast-inner-apply/non-union`,
    where the SUB inner is hard-coded `'block` (Q_U20) and the non-sub inner
    threads the inherited sort. Measured, the SAME step differs by context:
    `cfg.servers:host` → `@["a" "b"] : [PVec String]` ('path, extracts) vs
    `cfg{servers:host}` → `{:servers @[{:host "a"} …]} : {:servers [PVec {:host
    String}]}` ('block, assembles a keyed row).
  · **That wrap is CORPUS-PINNED as CORRECT** — acceptance marker **19**,
    `app-config{admins:name}` → `{:admins @[{:name "Alice"} {:name "Bob"}]}`,
    live and passing, and carrying its own "CORRECTED 2026-07-29 (handoff
    verification)" note. So block-context assembly is intended.
  · For an ORDINAL inner there is no key (`select-step-output-name` → `#f`), so
    the block assembles ONE KEYLESS component — which by **[Q_U22](#q-u22)**'s
    arity-uniform rule is `⟨T⟩`, not the bare value. Hence
    `⟨[PVec ⟨Int⟩] × 3⟩`.
  **So bare columns would require OVERTURNING Q_U22**, which was ruled on
  algebra coherence and explicitly rejected the bare-value reading. The arm is
  therefore correct as-is, and what it ships is **honest-nested columns**.
  ⚠ Q_U22's own text names the recovery: *"`<` (disclose/pick) plus `join`
  recover the ergonomics."* BOTH are P4e operators — so whether the bare-column
  transpose is spellable END TO END inside P4e depends on whether the recovery
  can attach at a branch head. ⚠ The obvious spelling `{:0*}` is **BLOCKED by
  the ordinal-star shatter** recorded under [Q_U23](#q-u23) (`m{0*}` ≡ `m{0 *}`),
  so this is NOT free. **OPEN — carried into P4e's slicing.**
  **⚠ THE COST, named**: `{:0}` is not free — measured, it is claimed by the
  landed diagnostic *"block keys are written bare — `x{0}`, not `x{:0}`"*, which
  assumes a leading colon in a block is a TYPO. Admitting branch-initial `:`
  makes `{:name}` legal and that guided error loses its case, so a user who
  writes `x{:name}` meaning `x{name}` gets a well-typed WRONG ANSWER instead of
  a correction. §3.6's monotonicity permits it (errors may become meanings), but
  **the diagnostic must be REPLACED, not deleted**: `x{:name}` over a subject
  whose elements do not offer `name` must fail in the broadcast reading's terms.
  This is the arc's recurring shape — a guided error becoming a silent
  divergence — and it is the single largest hazard in P4e's new scope.
  ⚠ This LIFTS a v1 refusal ([Q_U7](#q-u7): "branch-initial `:` stays refused in
  v1… so a wrapper never heads a branch"). The mini-audit must re-derive what
  depends on that invariant — P4a's totality dispatcher and the components walk
  are the named suspects.
  **`:*` DEFERRED, with the boundary stated.** The owner asked whether
  `values{:*}` could be a shorthand. It is not silly, but it needs `*` to mean
  *"every index at this level"* — a BRANCH-GENERATOR, which neither is nor
  derives from Q_U23's layer-delete (join collapses `m (m a) → m a`; a generator
  expands one written branch into n). They coincide in the splat case by
  accident, which is what made the unification look total. It is also
  well-typed EXACTLY where the axis length is in the type: `⟨T₁ T₂ T₃⟩` is a
  closed nat-keyed row and expands; `[PVec _]` does not, so `values{:*}` over
  `[PVec [PVec Int]]` cannot be typed at all. `{:0 :1 :2}` is v1 because the
  count is WRITTEN. This is W2's own alternative exit ("free once rows/lengths
  are statically known") and §5's L6 pairing of AoS↔SoA with length-indexed
  vectors — the array-programming reading is gated on the types learning to
  carry length, not rejected.

- <a id="q-u26"></a>**Q_U26 — RAVEL IS BARE `.*` [owner, 2026-08-08 — "Perhaps
  we can reclaim the `.*` spelling as ravel, then?"].** `values.*` →
  `@[1 2 3 4 5 6 7 8 9]`; APL's `,`. Whole-container join, the sibling of
  Q_U23's per-step `*`.
  > ⚠ **SPELLING SUPERSEDED 2026-11-02 by [Q_U63](#q-u63) = J** (owner). Ravel is `x:*`, the identity
  > broadcast then the join; `.*` is not reclaimed and gets a guided refusal naming `x:*` (JD-1). The
  > MEANING decided here (a one-level whole-container join) stands. The text below is kept as decided.
  **Why NOT `xs*`** (the owner's first spelling, withdrawn on the measurement):
  `*`-suffixed identifiers are an established convention here — ⚠ **`int*` alone
  appears 148 times** (HEAD-pinned `git grep -o 'int\*' HEAD -- '*.prologos'`;
  **130** comment-stripped. The figure first written here was **121**, measured
  against a DIRTY working tree with `.claude/worktrees/` copies inflating a
  root-level recursive grep — corrected 2026-08-08; the direction is unanimous,
  so the withdrawal is STRENGTHENED, only the arithmetic was off), and it is the
  worked example in our own ambient syntax rules (`[int* _ 2]`), alongside
  `rat*`, `p32*`, `trait*`, `p8*`, `p*`, `ordering*`. So `values*` in SUBJECT
  position is indistinguishable from a name, and resolving it by "split the star
  if the whole token is unbound" would make meaning depend on the binding
  environment — the silent-swallow hazard `parser.rkt` already names for
  `:tags*`. It also does not fit Q_U23's rule: `*` deletes the layer *the
  preceding step* made, and a bare subject is not a step.
  ⚠⚠ **THE CENSUS MEASURED THE WRONG HAZARD CLASS ALONGSIDE THE RIGHT ONE**
  (audit `wf_5fb7131d-63a`, reproduced): bare `*` is not merely a legal
  identifier CHARACTER — it is a **BOUND FIRST-CLASS BINARY FUNCTION**. Measured,
  `def s := *` → `s : _ _ -> _ defined.` That is why a star after a CLOSER
  becomes an APPLICATION rather than a shatter: `m:0 *` →
  `Could not infer type [m.:0 [prologos::core::arithmetic::* …]]`. Any
  star-bearing selection surface must contend with `*` being a live VALUE in
  expression position, not only with names that end in it.
  **`.*` is AVAILABLE**: the P4c-5 `.*name` retirement always carries a TRAILING
  NAME (it is the old `broadcast-get`, migration target `:name`), so bare `.*`
  does not collide with it. ⚠ **Measured cost**: `values.*` does NOT survive the
  reader at HEAD — it shatters to `values | . | *` and reports
  `Unbound variable .`. So reclaiming `.*` puts BACK the grouping fix that
  Q_U23's move to `database*` had deleted. Accepted eyes-open: one grouping fix
  now buys a genuinely new operator instead of a spelling that was an identity
  half the time.
- <a id="q-u27"></a>**⭐ Q_U27 — `*` IS SORT-GENERIC IN THE SURFACE TOO, NOT ONLY
  IN THE SEMANTICS. THE READER WORK IS TAKEN ON [owner, 2026-08-08 — "Let's take
  on the sort-generic and make it available in a way that makes us proud of
  accomplishing a work brought to completeness"].** Closes the hole the P4e
  mini-audit opened under [Q_U23](#q-u23): the rule generalizes over layers but
  the LEXING did not, leaving `m{0*}` byte-identical to `m{0 *}` — an
  **unspellable case in a ruled operator**, which this track's own record says
  comes back.
  **THE ARCHITECTURE IS A HYBRID, AND IT IS FORCED — one sentinel, two sources.**
  Grounded on the landed mechanism, re-verified on the main thread:
  · **Non-identifier heads** (ordinal, `}`/`]`/`)` closers, sub-blocks) — the
    star is ALREADY its own token, byte-adjacent to the base. So this is the
    **`adjacent-to-base?` mint**, the [Q_U8](#q-u8) shape: a star token adjacent
    to a non-empty local result mints the sentinel. Every one of these carriers
    joins **FREE**, because `adjacent-to-base?` *"consults no token type"* — its
    own comment names `.N`, brackets, braces, parens and closers as joining the
    focus set at no cost. This is the same predicate `bcast-step-trigger?` and
    `bcast-brace-trigger?` are built from.
  · **Identifier heads** — the star is ALREADY FUSED (`database*` is ONE token,
    because `ident-continue?` admits `*`), so adjacency cannot see it. This is
    the **post-tokenization splitter**, the `split-caret-lexeme` shape, at
    `segment-select-items`' call sites.
  · The two sources MUST converge on ONE sentinel so the consumer is one arm.
  **Why the hybrid is forced rather than chosen**: removing `*` from
  `ident-continue?` would break `int*` (148 HEAD-pinned uses) and its family, so
  the fusion cannot be prevented; and the adjacency mint cannot see a fused
  token. Neither mechanism alone covers both. ⚠ *Architecture PROPOSED here from
  verified mechanism; the slice's own mini-round confirms before it lands.*
  **NON-NEGOTIABLE CARRY-OVERS from the landed twins** — each already cost a
  BLOCKING regression once: (i) **ONE definition consumed by BOTH groupers**
  (the F1b.7g drift class; `surface-rewrite.rkt` hand-inlines a non-exported
  sibling today). (ii) **The decline is a CLASS, not a list** — copy
  `(not (prev-token-not-emitted? vec i))`; its comment records that shipping it
  "as a list of one" cost a blocking regression. (iii) **Corpus A/B MANDATORY
  with a NAMED predicted diff set** — grouping changes datums (Q_U8's precedent).
  (iv) The mint slice lands **ALONE** (the P4d-0 precedent: a shared grouper
  predicate makes a bundled A/B un-attributable).
  **Ravel's recognizer is separate and its discrimination is clean**: bare `.*`
  fails today because `recognize-dot-access` explicitly declines `.*` and the
  `.*name` retirement recognizer requires an identifier AFTER the star. So
  **presence-of-trailing-identifier IS the discriminator**, and it already lives
  in the recognizer — `.*name` keeps the retirement error, bare `.*` mints ravel.
- <a id="q-u28"></a>**⭐ Q_U28 — A TRAILING `*` SHADOWS A LITERAL FIELD NAME
  SILENTLY, EXACTLY AS `^` DOES [owner, 2026-08-08 — "Match the `^` reading for
  now"].** No type-time disambiguation check: the operator always wins, its
  reading does not depend on what the subject happens to contain, and a
  genuinely star-bearing key is reached the same way a caret-bearing one is.
  **THE PRECEDENT, MEASURED at HEAD** (not asserted — this was the worked
  demonstration the owner asked for):
  · `q := {:a^b 5 :a {:b 9}}` · `q{a^b}` → **`{:b {:b 9}}`** — the RENAME wins;
    the literal `:a^b` (value `5`) is unreachable through the block band.
  · `q.a^b` → a GUIDED error (*"`^` re-keys the OUTPUT of a selection… Use a
    select block if you want to rename"*) — the band that cannot express the
    operator refuses with guidance rather than falling back to the literal name.
  · **`[map-get q :a^b]` → `5`** — the ESCAPE HATCH works. **Shadowing is
    confined to the SELECTION SURFACE**, which is what makes the trade payable.
  ⚠ **"Matching `^`" is about SHADOWING, not about band availability.** `^` is
  refused in the dot band because a field access has no output key to re-key;
  `*` has no such problem — `r.ab*` descends and then deletes a layer, which is
  meaningful. Do NOT inherit `^`'s dot-band refusal along with its shadowing.
  **The exposure is narrower than it looks, and the slice must PIN this**: the
  genuinely SILENT case needs the subject to carry BOTH `:ab` (row-valued) and
  `:ab*`. With only `:ab*` present, the splat of `ab` is a field-MISS and errors
  anyway. *(Predicted, not measured — the surface does not exist yet; pin it.)*
  ⚠ **"FOR NOW" IS DOING REAL WORK, and the revisit is NOT free.** Adding the
  disambiguation error later turns a MEANING into an ERROR — the direction
  §3.6's monotonicity principle **forbids**. So if we ever want it, it must be
  decided before this surface has users. Recorded as a named cost, not a
  reversible default. Census at the ruling: **ZERO star-bearing field names
  exist in the tree** (HEAD-pinned; the only `.prologos` hit is `:diags*`, the
  operator itself in a commented corpus line, and the `.rkt` hits are the
  battery pin plus English prose), so the trade is currently free of victims.
- <a id="q-u29"></a>**⭐ Q_U29 — A MID-LEXEME `*` IS A GUIDED ERROR IN ALL THREE
  BANDS (option 2) [owner, 2026-08-08 — "Option 2"].** A star in a lexeme is the
  OPERATOR or it is nothing; there is no field-name fallback. `r{c*d}` and
  `r.c*d` become guided errors; `xs:c*d` is unchanged (already refused).
  **THE MEASURED STATE THIS REPLACES** — the three bands disagreed, and had for
  the whole track:
  | lexeme | `r{…}` block | `r.…` dot | `xs:…` ω |
  |---|---|---|---|
  | `ab*` (trailing) | `{:ab* 1}` field | `1` field | REFUSED |
  | `c*d` (mid) | `{:c*d 2}` field | `2` field | REFUSED |
  The ω guard is `#rx"[*]"` — **ANY-star, not trailing-star**, and its own
  comment misdescribes itself as trailing-only. So option 2 does not invent a
  refusal; it PROPAGATES the one the ω band already had, and retires a live
  three-way divergence.
  **Rejected-with-reason**: **option 1** (mid-star stays a field name
  everywhere) — uniform, but it DROPS the ω band's live refusal, acquiring
  permissive drift as a side effect of adding an operator, which is the
  direction this project does not drift by accident · **option 3** (keep today's
  per-band divergence) — smallest diff, but it institutionalizes `r{c*d}`
  working while `xs:c*d` refuses, the "two spellings of one form disagreeing"
  class DEFERRED 32 was filed for.
  **Why the breaking half is payable**: census at the ruling found **ZERO
  star-bearing field names in the tree** (HEAD-pinned over tracked sources; the
  only `.prologos` hit is `:diags*`, the operator itself in a commented corpus
  line, and the `.rkt` hits are the flatten battery pin plus English prose in a
  Racket comment). The break costs nothing that exists. And the ESCAPE HATCH is
  measured: `[map-get r :c*d]` → `2`.
  **Precedent it follows**: `split-caret-lexeme` REFUSES >1 caret and a leading
  caret rather than falling back to a field name — malformed operator position →
  guided refusal is already the house pattern for this family.
  **The error must name the escape**, per the "remedy points at a reachable
  spelling" rule: *"`*` is the layer-delete operator and attaches at the END of a
  segment; `c*d` is neither a field nor an operator. A field literally named
  `c*d` is reached with `[map-get r :c*d]`."*
- <a id="q-u30"></a>**⭐ Q_U30 — ALL SEVEN CARRIERS ARE IN SCOPE, TOKENIZER REPAIR
  INCLUDED [owner, 2026-08-09 — "I'd like to be able to reach all seven, so
  tokenizer repair included"].** This is the ruling that SIZES the design.
  Measured by the star-surface census (`wf_19cd5077-15b`): of the seven target
  carriers, **1 of 7** as-spelled (`m{0*}`) reaches the selection surface today ·
  **5 of 7** do when rewritten in-block · **2** (`x.0*`, `xs:0*`) reach nothing
  under ANY spelling without a tokenizer repair. So the in-block narrowing
  (census option R8) is REJECTED and R4 is IN: the two declining recognizers —
  `recognize-dot-ordinal` and `recognize-colon-annotation` — get a `*`-SPECIFIC
  relaxation of their trailing guards.
  ⚠ Those guards exist to protect `x.0N` / `x.1e3` / `:10abc` (Q_R2), so the
  relaxation must be keyed on `*` alone and must not re-open the numeric-suffix
  ambiguity. ⚠ They are TWINS — the P4e-0 attempt fixed the colon one and left
  the dot one untouched, which is how `x.0*` kept destroying the
  `$postfix-index`. Both move together or neither does.

- <a id="q-u31"></a>**⭐ Q_U31 — THE GLUED SIGMA SPELLING IS REFUSED; `*` AT TYPE
  LEVEL REQUIRES SPACES [owner, 2026-08-09 — "I'm fine with needing the spaces
  between a sigma spelling (I think that's more preferred for convention
  anyways)"].** `<(x : Nat)* Nat>` is legal today and elaborates correctly, with
  **ZERO corpus sites** — every written Sigma is spaced. It was attempt 1's
  headline casualty.
  **What the ruling BUYS, and it is structural, not cosmetic**: with the glued
  spelling refused, `*` is no longer genuinely ambiguous inside an angle group,
  so the design does NOT have to thread a context test through the grouper to
  protect Sigma. The census had this blocking the entire `'rangle` axis
  (constraint G1, 7 `star-symbol?` call sites reachable from 17
  `parse-infix-type` sites).
  **Cost**: one guided error at a `star-symbol?` call site. Monotone — the
  refusal may become a meaning later, never the reverse.
  ⚠ The refusal must be a PARSER-layer `parse-error` VALUE, not a preparse
  raise — see [DEFERRED 102](../../../DEFERRED.md) for why that distinction is
  load-bearing (the parser path is abort-safe under a `data`; the preparse path
  was not, until this session).

- <a id="q-u32"></a>**⭐ Q_U32 — A BARE `*` IS REFUSED IN PATTERN POSITION; EVERY
  ARITHMETIC USE IS UNTOUCHED [owner, 2026-08-10 — "The `*` is used as
  multiplication… so as long as those aren't touched, I think it's fine to rule
  against bare `*` showing up in pattern positions"].** This discharges
  [DEFERRED 103](../../../DEFERRED.md) as a LANGUAGE RULING and removes the constraint
  that a star mint be pattern-position-aware at a stage that cannot know it is
  in a pattern.
  **THE GUARD RAIL, PINNED BY MEASUREMENT** (`19560a7c`, all 0 errors) — these
  must not move, and a P4e pin must assert them:
  `* 3 5` → `15` · `[* 3 5]` → `15` · `map [* _ 2] '[1 2 3]` → `'[2 4 6]` ·
  `map [* 3 _] '[1 2 3]` → `'[3 6 9]` · `.(4 * 5)` → `20` (mixfix) ·
  `|> 5 [* _ 2] [* _ 3]` → `30` · `reduce * 1 '[2 3 4]` → `24` ·
  `let op *` / `[op 3 4]` → `12`.
  ⚠⚠ **THE DISCRIMINATOR IS POSITION, NOT SPELLING — and this is the finding
  that makes the ruling implementable rather than obvious.** The owner named
  four arithmetic uses; the sweep found a fifth class they did not: since
  Numerics N6e-E2 **operators are first-class values**, so `reduce * 1 xs` and
  `let op *` put a **BARE** `*` in argument and binding position and both must
  keep working. A refusal keyed on "a bare `*` token" therefore breaks live
  surface. It must key on the POSITION being a pattern.
  **THE DOMAIN, MEASURED** — what the refusal covers, all at `19560a7c`:
  · `match q | * -> 99` → `99`, **0 errors** (a legal catch-all binder today)
  · `match q | 2 * -> 99 | n -> n` → `Could not infer type`, **second arm
    silently deleted** — the DEFERRED 103 defect
  · `defn f | * -> 1` → `f : _ -> Int defined.`, `f 3` → `1`, **0 errors**
  · `defn f | red* -> …` → loses `f` itself → `Unbound variable`
  · `let [a *] pair` → *"pair expects 2 arguments, got 1"* — bracket
    destructuring reads as APPLICATION, so it is **not** in the domain.
  **CONSEQUENCE, ACCEPTED EYES-OPEN**: the ruling is BROADER than the defect. Two
  of the four covered shapes (`| *` alone, `defn f | *`) are legal and *harmless*
  today — they bind a variable named `*`. Refusing them too is the simpler rule
  and is monotone (a refusal may become a meaning; the reverse is barred by spec
  §3.6), and a rule that refused only the arm-deleting subset would have to
  discriminate on sibling-arm count at the same seat.
  **DESIGN DIVIDEND, and it is the point**: DEFERRED 103 framed this as needing
  pattern-awareness "at a stage that does not know it is in a pattern" — but the
  refusal does not have to live at the reader. The arm loss is observable at the
  pattern compiler, which knows exactly that it is in a pattern. Siting it there
  keeps the star mint's stage free of a context test, the same way
  [Q_U31](#q-u31) kept one out of the grouper. ⚠ Stated as an OBSERVATION for the
  mini-design to verify, **not** as a ruling on the site.
  ⚠ Sibling NOT discharged: `compile-match-tree`'s abort on a multi-form LITERAL
  arm (`| 2 3 ->`) is star-free and still live — see DEFERRED 103.
  *(The Q-label register lives at the end of [§ the census](#star-census) — one
  source, deliberately.)*

- <a id="q-u33"></a>**⭐⭐ Q_U33 — ADOPT R10, THE TOKEN-*TYPE* MINT: A SPACE IS
  SIGNIFICANT FOR `*` [owner, 2026-08-10 — "Let's take it, yes"].** At the
  TOKENIZER, where byte-adjacency is still visible, a `*` byte-adjacent to a
  preceding CLOSER gets a DISTINCT TOKEN TYPE instead of `'symbol`. **Counts are
  unchanged at every layer**, so A4 and the ≥15 item-counters never engage —
  which is precisely what killed attempt 1. `x{a}*` is the star step; `x{a} *`
  remains the first-class multiplication operator.
  ⚠ **CORRECTION to this ruling as first written (2026-08-10, measured before it
  shipped): there is NO "half-glued" error case for `*`, and the ARROW T1
  analogy does NOT carry.** ARROW's `->` is infix, so it has two sides and a
  broken middle; `*` here is postfix, and its right-hand side is already
  resolved by G3 identifier fusion — `ident-start?` admits `*`, so `*foo` is an
  ORDINARY IDENTIFIER. Measured: `[f x]*foo` → `(((f x) *foo))` and
  `[f x] *foo` → the **byte-identical** datum; only `[f x]* foo` makes the star
  a lone token. So the both-sides-glued shape never reaches R10 at all — it is
  an identifier, exactly as `int*` is at its 170 sites. **R10 fires only when
  the `*` is a LONE token byte-adjacent to a preceding closer.** No new
  diagnostic is owed here. (Written from the ARROW precedent by analogy, then
  probed — the assert-instead-of-measure failure this arc keeps recording,
  caught this time inside my own ruling text.)
  **⭐⭐ THE MEASUREMENT THAT FORCES IT — adjacency is the ONLY discriminator, and
  it exists only ABOVE the datum layer.** I looked for a cheaper one and the
  probes refuted it twice (2026-08-10, `4ea024f9`):
  · The datum ERASES glued-vs-spaced: `[f x]*` and `[f x] *` are **both**
    `(((f x) *))`, and `(f x)*` is byte-identical to both — which is also the
    shape of `bundle Bx := (Add Sub)*`.
  · **Hypothesis 1, REFUTED**: "the preceding item's sentinel head discriminates
    six of the eight sibling carriers" (`$select-brace`, `$bcast-step`,
    `$list-literal`, `$vec-literal`, `$brace-params`, `$mixfix` are all distinct
    heads). It does not, because the star's meaning depends on GLUING, which the
    datum has already lost.
  · **Hypothesis 2, REFUTED**: "sibling position is uninhabited by working
    arithmetic, so the erasure is harmless." It is inhabited —
    `pick [xs] *` → `[fn [x] [fn [y] [?m x y]]]` at **0 errors**, and identically
    for `pick cfg{database} *`, `pick '[1 2] *`, `pick @[1 2] *`,
    `pick {:a 1} *`. A bare `*` after a group is LIVE SURFACE in argument
    position (it is the first-class operator — the Q_U32 guard rail).
  So a datum-layer rule is unavailable for **every** sibling carrier, not just
  the two bare-group ones. This is the census's headline finding carried all the
  way to semantics, and it explains BOTH prior failures structurally rather than
  as mistakes: attempt 1 took adjacency from the grouper and paid with a count
  change; attempt 2 went below the grouper and had no adjacency left to carry.
  **WHAT IT COSTS, named**: a space becomes semantically load-bearing for `*`,
  and unlike `:` and `->` the spaced form here has a LIVE COMPETING MEANING.
  **Paid in theory, not in practice**: the census measured **ZERO** code sites
  for `)*` `]*` `}*` `>*`, so no file in the tree changes meaning.
  **PRECEDENT**: byte-adjacency already decides `:` ([Q_U8](#q-u8) mints
  `$bcast-step` only when the colon is glued to a non-empty local result), and
  ARROW T1 made `->` glued-vs-spaced significant with half-glued a guided error.
  **Rejected-with-reason**: narrowing back to the in-block spelling (census R8) —
  already rejected by [Q_U30](#q-u30), which put all seven carriers in scope ·
  a datum-layer marker (census R2, attempt 2) — refuted above, twice · a
  different spelling (census R9) — `$star` is already a live Sigma spelling with
  zero producers, `**` is `pow` in the mixfix table, and a `:`-keyword spelling
  collides with the `$bcast-step` mint.
  ⚠⚠ **THE HOME IS CORRECTED — "at the TOKENIZER" (as this ruling first said) is
  the ONE home that does not work.** Settled by measurement at the attempt-3
  mini-audit (`wf_c062f617-251` + a main-thread token probe), and the ruling's
  SUBSTANCE is what saves it: a **TYPE** discriminates where a **CHARACTER**
  cannot. A recognizer sees only the previous CHARACTER, and **`>` is not a
  closer character** — it is the last char of `->` `->>` `&>` `|>` `+>` `-N>`,
  all of which classify to `'symbol` and outrank `symbol`'s own priority.
  Measured, all byte-adjacent, all five would MINT under a char lookback:
  · `a &>* b` · `x |>* y` · `a ->* b` · `s ->>* t` · `p +>* q`
    → char-lookback mints **#t (WRONG)** · type-lookback mints **#f** ✅
  · `[f x]*` (`rbracket`) · `cfg{a}*` (`rbrace`) · `<a>*` (`rangle`)
    → **both** mint #t ✅ — and note `<a>*`'s closer is a real `rangle` TYPE
      while `&>` is `symbol`, so the type separates them perfectly.
  **Therefore the type must be assigned at a TOKEN-LEVEL pass that can see the
  previous token's TYPE — `disambiguate-tokens` is the only one that does** (it
  already re-types by previous-token type and carries exact
  `start-pos`/`end-pos`; it is where `>>` is merged). Cost: one extra round on
  files that currently do zero.
  ⚠ **And a grouper-level mint does not rescue it either**: `adjacent-to-base?`
  gives byte-adjacency to the previous TOKEN, which is `#t` for `&>*` as well —
  so the closer test is needed there too, AND the postfix mint at the grouper is
  **count-CHANGING**, which is attempt 1 exactly. Count-preservation is why the
  ruling is a TYPE mint and not a fusion.
  ⚠ Composes with [Q_U30](#q-u30)'s **R4** (relax the twin recognizers' trailing
  guards so `x.0*` / `xs:0*` stop destroying their own carriers) — same file,
  same kind of edit, and the twins are twins in OBLIGATION but **not in code**
  (`ascii-digit?` vs `char-numeric?`).

- <a id="q-u34"></a>**⭐ Q_U34 — `.( … )` IS ARITHMETIC TERRITORY: NO STAR MINT INSIDE
  MIXFIX [owner, 2026-08-10].** A closer-adjacent `*` inside a `.( … )` group is
  NOT minted. Accepted narrowing, named: **a star STEP cannot appear inside
  `.( … )`.**
  ⚠ **RECORDED LATE (2026-08-10) — the ruling was cited in code, tests and a
  commit message before it had an entry here.** `Q_U34` appeared 6 times across
  `parse-reader.rkt`, `test-path-selection.rkt` and D4 while the register still
  read "next free U34", i.e. the label was never allocated. That is the
  cited-but-unrecorded class this track fights, committed by me. Fixed with the
  entry, not with a note.
  **WHY**: `)*(`  is genuinely BOTH readings — postfix star on a closed group,
  and infix multiply — and no lookback separates them. Measured:
  `.((1 + 2)*(3 + 4))` → `21` at 0 errors with the star minted, before the gate.
  **What separates them is CONTEXT, and it is measurable**: infix `*` exists ONLY
  inside mixfix (`rec.n * 2` at command position is an error; `.(rec.n * 2)` is
  42). So outside mixfix a closer-adjacent star is unambiguous; inside it,
  arithmetic wins.
  **Realisation**: a frame stack in `disambiguate-tokens` mirroring
  `make-bracket-depth-rrb`'s — nine openers from the SHARED enumeration,
  kind-sensitive `lparen`, top-of-stack test, and a MATCHED-closer pop. Each of
  those four qualifiers was earned by a defect: the first cut pushed 4 of 9
  openers, used `memq` over the whole stack, and popped on any closer. See
  [§5.P4e-0 attempt 3 slice A](phases/CIU_6_P4e-0.md#p4e-0-a3).

- <a id="q-u35"></a>**⭐ Q_U35 — `*` AFTER A NON-SELECTION EXPRESSION IS REFUSED
  [owner, 2026-08-10 — "For now, yes, refuse. It's out of scope for this to be a
  non-selection expression for now"].** `[f x]*` and `(f x)*` take a guided
  refusal; `*` stays a PATH-SELECTION operator only.
  **THE GAP IT CLOSES**: [Q_U23](#q-u23) defines `*` as deleting the layer **the
  preceding STEP** created — and these two carriers have no preceding step. The
  preceding thing is an arbitrary application, so the rule was simply undefined
  for them. Either the star becomes a VALUE-LEVEL flatten (a different feature,
  with its own typing and the `Functor`/`Foldable` trait question
  [Q_U9](#q-u9) already named as the principled door) or it is refused.
  **⭐ WHAT THE REFUSAL BUYS, and it is structural**: it keeps the star sentinel
  INSIDE the selection surface. Measured before the ruling, `postfix-star` also
  mints in ordinary application arguments (`f [g x]* y`), map-literal values
  (`{:k [f x]*}`) and nested brackets — all legal today, since `*` is a
  first-class operator (the [Q_U32](#q-u32) guard rail). Under a datum rename each
  would have become `Unbound variable $postfix-star`, a leaked internal sentinel.
  Refusing dissolves that whole blast radius instead of arming it site by site.
  **COST, stated**: slice A delivers **TWO** usable carriers (`x{a}*`,
  `xs:{a}*`), not four. `[f x]*` / `(f x)*` get a guided refusal naming the
  separate-flatten spelling — the same shape Q_U9 uses for `List`.
  **Monotone** (spec §3.6): the refusal may become a meaning later, never the
  reverse. Zero corpus sites for either spelling.
  ⚠ Does NOT change [Q_U30](#q-u30)'s seven-carrier scope; it rules on what two of
  them MEAN. `xs:0*` / `x.0*` remain blocked on [DEFERRED 105](../../../DEFERRED.md).

- <a id="q-u36"></a>**⭐⭐ Q_U36 — THE FUSE ARM IS A POSITIVE LIST OVER THE
  PREDECESSOR, AND THAT IS WHAT MAKES P4e-1a TRACTABLE [owner, 2026-08-10].**
  The rule is: **fuse iff the head of the PRECEDING item is in the small closed
  set of SELECTION heads**; [Q_U35](#q-u35)'s guided refusal is the genuine
  `else` catch-all. Never an enumeration of the heads to REFUSE.
  **WHY IT IS A RULING AND NOT A CODING PREFERENCE — it resolves the census's
  own ⭐BLOCKING item.** Tier-O **O7** records that `$star-step`'s membership is
  *"CONDITIONAL AND RECURSIVE — a flat head list cannot say member-iff-its-
  payload-is-a-member"*, and that is precisely the shape that killed slice B;
  `access-sentinel?`'s in-file comment reaches the same verdict independently
  (*"a sentinel that cannot be expressed in the head-set vocabulary the rest of
  the family shares is a design smell, and it was pointing at the real defect the
  whole time"*). A positive PREDECESSOR test sidesteps O7 entirely: it never asks
  whether the star is a member, only whether the thing before it is a selection
  head — a flat closed-set test on a **different datum**. O7 was not carried into
  P4e-1's OWED list; it is discharged here.
  **WHAT IT BUYS, and it is the whole scope argument**: the P4e-1a mini-audit
  (`wf_9bbe5f5a-9e0`) measured the arrival surface at **10 minting carriers × 19
  arrival contexts**, not the 4 × 11 this document had enumerated (see
  [§5.P4e-1a](phases/CIU_6_P4e-1.md#p4e-1a)). Under a NEGATIVE list that 4.3× under-count is a defect
  generator — it is exactly the bad-enumeration class that produced the last
  three blocking defects. Under a POSITIVE list the population stops bearing on
  CORRECTNESS at all: every carrier in every context either fuses (selection
  predecessor) or refuses (everything else), by construction. The inventory
  remains load-bearing for **gate coverage**, which is a test obligation, not a
  code one.
  **In-tree precedent, named**: `pipeline.md`'s `definitely-not-map?` inversion
  (CIU T6 P2.b slice 1) — a positive list with a conservative `#f` default, so a
  new node is safe BY CONSTRUCTION. Same direction, same reason.
  Rejected-with-reason: enumerate the non-selection heads (the six carriers this
  document omitted are the standing proof that the non-selection side is not
  knowable in advance); make `$postfix-star` a head-set member (O7 — its
  membership is conditional, and `access-sentinel?` requires `(list? x)` so a
  bare atom can never satisfy it anyway).

- <a id="q-u37"></a>**⭐⭐ Q_U37 — THE STAR'S REFUSAL IS DECIDED IN TERRITORY,
  NOT AT PREPARSE-EVERYWHERE [owner, 2026-08-11 — assent to the recommended
  course after the 1a-iii verify].** The fold fuses ONLY in selection territory
  ([Q_U36](#q-u36)'s positive predecessor test) and otherwise **LEAVES THE STAR
  IN PLACE** for the downstream seat that owns the territory:
  · **expression territory** → `parse-datum`'s guided [Q_U35](#q-u35) refusal
    (the single choke point every head-dispatched arm misses);
  · **type territory** (`<…>`, incl. preparse-synthesized `$angle-type`) →
    `unwrap-angle-type`'s [Q_U31](#q-u31) Sigma-specific refusal;
  · **data territory** (quasiquote) → NOTHING is rewritten; the star is captured
    as the `*` the user wrote (the lowering normalizes the sentinel back).
  **WHY IT IS A RULING**: it is [Q_U34](#q-u34)'s own logic extended one layer in
  — `.( … )` is arithmetic territory, so no mint inside mixfix; `<…>` is where
  `*` is Sigma's SEPARATOR; a quasiquote body is data. The 1a-iii attempt's
  refusal-at-preparse marker assumed every star was the fold's business, and the
  adversarial verify measured the two consequences at once: the marker PRE-EMPTED
  the Sigma seat (its guided refusal shipped unreachable — Q_U31's message never
  fired) and it put a three-element list where the quasiquote lowering expects a
  symbol. One wrong assumption, two symptoms; two patches would have been two
  workarounds.
  **NAMED COST, accepted eyes-open**: slice 1a-i's preparse datum invariant ("no
  unconsumed star survives preparse") is RESTATED — preparse genuinely cannot
  decide every case, because the context that decides lives downstream. The gate
  becomes: *an unconsumed star is refused (or captured as data) by the seat that
  owns its territory, and the internal name never reaches the user* — enforced by
  the E2E message/abort/leak pins plus per-seat positive pins, not by a blanket
  preparse scan. Narrowing an instrument to fit code is the move this arc warns
  against; the narrowing here is to the semantic claim, and the claim was wrong.

- <a id="q-u38"></a>**⭐⭐ Q_U38 — A NOMINAL-JOIN COLLISION IS REFUSED, AND
  CONSERVATIVELY ON THE `'dyn` TAIL [owner, 2026-08-11 — "Refuse, and
  conservatively on the dyn tail"].** A `*` whose lifted keys would collide —
  with a sibling branch's written key, or with another splat's lifted key — is a
  guided error, not a silent merge. Where the subject's row is CLOSED the
  collision is provable and refused on proof; where the row is `'dyn`-tailed the
  lifted key set is only a LOWER BOUND, and the refusal fires on POSSIBILITY.
  **WHAT THIS OVERTURNS**: [Q_U23](#q-u23)'s "P4e needs no P5 machinery for it,
  because P3a already landed strict merge" — **REFUTED, and by twice as much as
  the refutation first written**. There are **TWO** silent last-write-wins sites,
  not one: `make-record` (syntax.rkt, `;; last write wins`) is the TYPE-level
  constructor and IS on the select path via `select-assemble-row`
  (typing-core.rkt), and its VALUE twin `entries->value` (reduction.rkt) folds
  `champ-insert`, which also overwrites. The design named one and stopped.
  **WHY THE LANDED GATE CANNOT DO IT — the mechanical root**:
  `select-branch-top-keys` (syntax.rkt) takes **exactly one parameter**, the
  branch's step list. No ctx, no type, no subject. `dup-output-key` and
  `mixed-sorts?` (parser.rkt) are pure static folds over it, so **no arm added
  there can express a subject-derived key**. The check therefore MOVES to typing,
  at the row-assembly seat, which is the first place a closed row's fields are
  visible. ⚠ `mixed-sorts?` is the more dangerous of the two blind gates — it
  runs one line BEFORE `dup-output-key` and is the sole guarantor of an invariant
  both assembly points consume by inspecting their FIRST component only, so its
  residue is a silently WRONG CARRIER for the level, not an error.
  **THE ENTAILMENT, accepted eyes-open**: on an open-tailed subject, `*` plus ANY
  sibling branch is refused; a star as the SOLE branch has nothing to collide
  with and stays legal.
  **⚠ A THIRD FACT NO FACET FOUND, and it constrains how the rule may be
  PHRASED**: the two layers disagree about field ORDER. `make-record`
  CANONICALIZES (sorts by label after deduping); `entries->value` does NOT (the
  champ carries insertion order). Measured at HEAD: value `{:url "u",
  :pool-size 10}` against type `{:pool-size Int :url String}` from one
  expression. So a rule phrased as *"the later one wins"* is well-defined only
  against the ENTRIES list and never against the printed row — which is one more
  reason the answer is refusal rather than a merge. Any test pinning splat output
  must pin value order and type order SEPARATELY.
  **CALIBRATION, stated because it is the honest cost**: "strict merge" is a
  SELECT-SURFACE-ONLY policy. Map literals have no duplicate gate (`{:a 1 :a 2}`
  → `{:a 2}`, 0 errors), `map-merge` is documented right-wins, `record-extend` is
  explicitly right-priority. This ruling makes selection stricter than every
  surface beside it. Accepted: the star is a STRUCTURAL operator and a silently
  dropped layer is the failure this whole arc exists to avoid.
  **The remedy the refusal names is [Q_U24](#q-u24)'s `*_`** — see
  [Q_U39](#q-u39) for where it is spellable. ⚠ `*_` removes collisions in the
  ORDINARY case, **not universally** — a sibling literally named `database-url`
  still collides, and two layers can synthesize the same key (`{:a-b {:c 1} :a
  {:b-c 1}}` → both `a-b*_` and `a*_` yield `:a-b-c`). The refusal machinery
  covers `*_` too; it just fires rarely there instead of nearly always.
  **Substrate note**: a defined-collision primitive already exists and is unused
  — `champ-insert-join` (champ.rkt) takes a `join-fn`, **zero production
  callers**. It has NO type-layer twin (`make-record` has three parameters and no
  join), so a merge ruling would have needed new type-side substrate either way.
  ⚠ Prior ruling that already conceded the premise: the parser refuses `*` with
  `^` because *"a splat lifts N keys, so there is no single output key for `^` to
  re-key"* (parser.rkt) — the cont axis is already closed to `*`.

- <a id="q-u39"></a>**⭐ Q_U39 — THE CLOSER-ADJACENT `*_` MINT IS A FOLLOW-ON
  SLICE, NOT PART OF THE SEMANTICS SLICE [owner, 2026-08-11 — "Split it into a
  follow-on slice makes sense to me"].** P4e-1b lands the flatten, [Q_U38](#q-u38)'s
  refusal, and `*_` **in the fused-identifier band only** — which costs nothing
  lexically, because it already works there. Giving `c{a}*_` / `xs:{a}*_` a
  spelling is its own slice, with its own adversarial verify.
  **THE MEASURED ASYMMETRY** (all at HEAD, one probe): `cfg{database*_}`,
  `cfg.database*_` and `rows:tags*_` all reach the guided message and are
  DISTINGUISHED from their bare-`*` twins (`split-star-lexeme` already returns
  `'flatten-synth`). `cfg{database}*_` and `rows:{tags}*_` give a bare
  **`Unbound variable`** — the mint gate is `(string=? lexeme "*")`, EXACT
  equality (parse-reader.rkt), so `*_` after a closer lexes as an ordinary
  identifier. ⚠ The diagnostic does not even name `*_`; same wording defect as
  `values.*`.
  **WHY SPLIT RATHER THAN WIDEN**: `$postfix-star` is deliberately a BARE ATOM,
  and that choice is what made 1a-ii's Tier-O arms TWO LINES instead of a
  checklist. Adding `*_` means a second bare sentinel or a payload — and a
  payload re-opens the arity/head-set questions 1a settled. Either way it re-runs
  `pipeline.md` § "a new sentinel, an old recognizer" (leak gate · fuse arm ·
  `unmint-star-for-echo` · `pattern-var?` · `parse-datum` · `unwrap-angle-type`)
  **one slice after we last ran it** — the mid-flight widening *Watching 9*
  records as where this arc introduces its defects (3 data points).
  **THE COST, named**: for one slice the two result-level carriers get a refusal
  that must teach a REWRITE into the other band (`m{a b}*` → `m{a*_ b*_}`), not a
  one-character suffix fix — a wart the user meets exactly when already stuck,
  and a partial departure from Q_U24's "land together" rationale. Monotone, so
  the spelling can be added at any time.
  **⚠ SELF-CORRECTION, recorded because it nearly priced the decision wrong**: I
  first told the owner that widening the mint "costs a monotonicity break." **Too
  strong.** `c{a}*_` is an ERROR today (`Unbound variable`) unless the user has
  deliberately written `def *_ := …` — which does work (measured: `*_ : Int
  defined.`). So widening is **error → meaning** in every practical case, i.e.
  monotone; the non-monotone sliver is only the deliberately-bound case, and it
  is the SAME trade [Q_U33](#q-u33) already accepted for bare `*`, where the cost
  was strictly HIGHER (`*` is a live first-class operator with ~76 spaced
  arithmetic sites). The overstatement made `*_` look more expensive than it is,
  at the exact moment `*_` was the remedy under discussion.

- <a id="q-u40"></a>**⭐⭐ Q_U40 — THE STAR ATTACHES *OUTER*: IT DELETES THE LAYER
  THE PRECEDING STEP CONTRIBUTED [owner, 2026-08-11 — "OUTER seems to be looking
  like the right shape"].** The rule, in one sentence:
  > **`*` deletes the container layer contributed by the preceding step, joining
  > its contents into the enclosing level. The join's SORT follows the CONTENTS**:
  > vectors **concatenate**; Maps **join keywise** ([Q_U38](#q-u38) refuses
  > collisions, [Q_U41](#q-u41)'s `*_` is the remedy); keyless/ordinal components
  > **concatenate in written order** (spec §3.6 rule 5); leaves **error** (rule 4).

  **ONE rule across BOTH axes** — block and broadcast, nominal and vector. That
  uniformity is the ruling's whole case: it is [Q_U23](#q-u23)'s "sort-generic"
  read literally, and it is the only reading under which spec **§8 Q4**'s
  affirmative answer does work on both axes.
  **THE WORKED BATTERY** (subjects measured at HEAD; `rowsv := @[{:tags @[1 2]}
  {:tags @[3]}]`, `rowsm := @[{:cfg {:a 1}} {:cfg {:b 2}}]`,
  `m := {:a {:x 1} :b {:y 2}}`):
  · `rowsv:tags*` → `@[1 2 3]` — contents are vectors, concat. **The spec's own
    `ω·ω→ω` and its normative example** (`build.modules:diags*:msg`, §10.4).
  · `rowsv:{tags}*` → **refused** — every element contributes `:tags`; the
    remedy is the DESCENT spelling, not `*_` (see Q_U41).
  · `rowsm:cfg*` → `{:a 1, :b 2}` — Maps, distinct keys, keywise join.
  · `rowsm:{cfg}*` → `{:cfg {:a 1, :b 2}}` — same key, both Map-shaped, spec
    §3.6 rule 2 recursing.
  · `m{a b}*` → `{:x 1, :y 2}` · `cfg{database}*` ≡ `cfg.database` (n=1 is an
    identity, exactly as `{p^}` is an honest 1-tuple at n=1 per §3.3).
  · ~~`vv:{0 1}*` → `⟨1 2 3 4⟩` — **a matrix RAVEL falls out with no special
    case**~~; ordinal/keyless layers concatenate and so **can never collide**, so
    Q_U38's refusal structurally never fires on them.
    > ⚠ **CORRECTION (2026-11-02; finding RV-1 of [Q_U63](#q-u63), probe research/P4e-2/probe-p4e2-a
    > line 12).** The `vv:{0 1}*` line was an expectation written as a measurement. Measured, it is
    > refused: "`*` (flatten) is not implemented yet for tuple elements under a broadcast … the
    > concatenated arity is (tuple arity × the container's runtime length), which no static type
    > carries". The ravel itself is spelled `vv:*` under Q_U63 = J.
  **⭐ THE EQUATIONAL LAW IT PRODUCES** (call it **L★**), in the family of §3.6's
  `{p:a p:b} ⟶ p:{a b}`:
  > **`x{p₁* … pₙ*} ≡ x{p₁ … pₙ}*`** — distributing the star over every branch
  > equals starring the result — **PROVIDED the preceding step is a BLOCK, with
  > no intervening ω** ⚠ **AND the branches' contents are MAPS —
  > [Q_U45](#q-u45), 2026-08-12.**

  ⚠⚠ **DO NOT READ THE QUALIFIER BELOW AS COMPLETE — [Q_U45](#q-u45) WIDENED IT.**
  The ω qualifier recorded here is necessary and NOT sufficient: L★ also fails for
  VECTOR contents with no ω anywhere, and it fails on **ARITY**, not on order
  (`mm{zz* aa*}` is an n-TUPLE of vectors; `mm{zz aa}*` is one flat vector). The
  Map side is equal only because a Map-valued branch star SPLICES its keys, which
  is the same operation the result form's keywise join performs — and every worked
  example in this ruling's battery used Maps, which is why the gap survived. Q_U45
  also records the surface-observable form: `m2{a* b}` is LEGAL (splice `a`, keep
  `b`'s key) while `mm{zz* aa}` is an L4 mixed-sorts error.

  ⚠ **THE QUALIFIER WAS MISSING WHEN THIS RULING WAS FIRST WRITTEN, and the
  owner's question is what found it** (2026-08-11, same session). **Under a
  BROADCAST the two spellings act on DIFFERENT LAYERS and are NOT equivalent** —
  branch stars delete into the **per-element block level**, while a trailing star
  deletes the **container layer the ω step contributed**. One level apart.
  Measured subject `m : [PVec {:a {:x Int} :b {:y Int}}]`:
  · `m:{a* b*}` → `@[{:x 1, :y 2} {:x 3, :y 4}]` — per-element splice, two in two out
  · `m:{a b}*` → **error** — cross-element join; `:a` shared → recurse → `:x`
    shared on LEAVES (§3.6 rule 4)
  Without the ω the law holds (`m2{a* b*}` ≡ `m2{a b}*` ≡ `{:x 1, :y 2}`).
  **The divergence is a FEATURE** — per-element splice and cross-element join are
  both wanted and the surface distinguishes them exactly where the semantics
  differ — but a test must pin the **NON**-equivalence under broadcast, not only
  the equivalence without one, or the next reader will assume the law is
  unconditional. ⚠ Note also that a star written INSIDE a block was never subject
  to this ruling's OUTER/INNER question at all: it belongs to its branch
  unambiguously. Q_U40 governs only a star written AFTER a closer.

  The BRANCH form is nonetheless **strictly more expressive**, because the stars
  need not be uniform: `m{a* b}` → `{:x 1, :b {:y 2}}` (splice `a`, KEEP `b`'s
  key), which the result form cannot express. Selective splice vs total splice;
  the law says the total form is the all-branches special case.
  **REJECTED, each with its reason:**
  · **INNER** (the star joins the innermost step) — on the broadcast axis it
    degenerates to a **NO-OP**: `rowsm:cfg*` ≡ `rowsm:cfg`. That is precisely the
    "identity wherever the head key survives" defect [Q_U23](#q-u23) diagnosed
    when it retired `.*`; shipping a new operator whose broadcast behaviour is
    silently nothing repeats the thing that ruling fixed.
  · **SPELLING-DETERMINED** (fused ⇒ inner, closer ⇒ outer) — free structurally,
    but two near-identical spellings would mean materially different things with
    no visual cue.
  · **BLOCK-GENERIC / VECTOR-ONLY-UNDER-BROADCAST** — refuses 4 of 7 battery
    cases including the ordinal ravel, and once the rule above is stated as ONE
    sentence the "unruled" framing stops being accurate. Conservatism buying
    nothing.
  **⚠ SELF-CORRECTION, and it was the objection that had been blocking OUTER**: I
  argued that OUTER's cross-element join is the "coincidental" merge §3.6 forbids.
  **Mis-aimed.** Ruling B governs merging *sibling branches within a block* — its
  witness test is about ZIPPING TWO BRANCHES. A star-induced layer-delete is a
  **fold over ONE container**, which is the explicit act §3.1 sanctions
  (*"deleting a layer is only ever the explicit act `*`"*). The spec never
  subordinates the star's join to Ruling B's witness requirement; inheriting its
  COLLISION discipline (what Q_U38 did) is a separate and deliberate choice.
  **IMPLEMENTATION DIVIDEND**: OUTER's representation is **the one already
  shipped** — the closer-adjacent fuse emits `($select-path <preceding step>
  $postfix-star)`, a wrapper around the whole preceding step, which IS the OUTER
  shape. Only the fused-identifier band (`:tags*`, `.a*`) needs normalizing
  OUTWARD, lifting the star from inside the lexeme to the wrapper. INNER would
  have required normalizing the other way.
  **⚠ OPEN, and 1b must settle it**: same output key with BOTH values VECTORS
  (the `rowsv:{tags}*` shape). §3.6 rule 2 needs Maps, rule 3 needs two branches
  with identical spines — so it falls to rule 4's error. Whether same-key vector
  values should instead CONCATENATE is a choice the star's join has to make and
  Ruling B does not cover. Refusing is monotone; decide it explicitly rather than
  inheriting rule 4 by accident.
  **⚠ [DEFERRED 105](../../../DEFERRED.md) — the REPRESENTATION half of its blocker is
  DISCHARGED, the COUNT half is NOT.** 105 records that R4 "cannot land until the
  star's DATUM REPRESENTATION is decided — a wrapper sentinel, or a widened
  `$postfix-index` arity." Q_U40 decides it: the wrapper. But 105's actual defect
  was that restoring the carrier TOKEN makes the star a separate datum ITEM, and
  the fuse that now consumes that item runs inside preparse — so whether the
  count-gated form validators observe the pre-fuse or post-fuse datum is
  **unmeasured**. Do NOT reopen R4 on the strength of this ruling alone.

- <a id="q-u41"></a>**⭐ Q_U41 — `*_` IS NOMINAL-ONLY; OVER A POSITIONAL LAYER IT
  IS A GUIDED REFUSAL [owner, 2026-08-11].** `*_` synthesizes each lifted key
  from **the deleted layer's KEY** — so it applies exactly where the deleted
  layer HAS keys: a block branch, a block result, or a **map-generic broadcast**
  (§3.2.3). Over a deleted VECTOR layer it refuses and names the alternative.
  **THE MECHANISM IS `^_`'s, and that is why this is not a special case.** §3.4:
  *"synthesize the key from the surviving path (`a.b^_ ⇒ :a-b`)"*. A positional
  layer has no surviving key to synthesize from. ([Q_U24](#q-u24)'s ruling that
  `*_` follows `^-_`'s rule rather than `^_`'s is untouched — that is about
  COLLAPSE vs relabel-in-place, a different axis, and `split-star-lexeme` already
  records it at its own site.)
  **`*_`'s BEST CASE is the map-generic broadcast — and it is Q_U24's own
  motivating example, which [Q_U40](#q-u40) is what makes reachable.** Measured
  at HEAD, `regions := {:eu {:host "eu.example.com" :port 80} :us {…}}` gives
  `regions:{host port}` → `{:eu {:host … :port …} :us {…}}`, keys preserved. So:
  · `regions:{host port}*` → **refused**, both elements contribute `:host`+`:port`
  · `regions:{host port}*_` → `{:eu-host …, :eu-port 80, :us-host …, :us-port 443}`
  **INDEX-SYNTHESIS REJECTED** (`rowsv:{tags}*_` → `{:0-tags …, :1-tags …}`),
  three reasons in increasing seriousness:
  1. **Often not typeable.** `rowsv : [PVec …]` — the length is not in the type,
     so the output row's field COUNT would be runtime-determined, which a closed
     row cannot express. It would type only over a TUPLE (`rowsm : ⟨… …⟩`,
     static arity) — i.e. the feature would work for some vector subjects and not
     others, on a `PVec`-vs-`⟨⟩` distinction the user never wrote.
  2. **It inverts the key-sort thesis.** §1.1 + §8 Q2: *"nominal key IDENTITY
     carries the meaning, order does not."* Index-derived keys make POSITION
     carry nominal meaning. Spec **§8 Q3** (nominal→ordinal demotion order) is
     still OPEN and *"requires a canonical key order or a prohibition"*; this is
     the same frontier from the other side, equally unruled. If index-provenance
     is ever wanted, **§8 Q3 is where it belongs** — monotone either way.
  3. ~~**It is the wrong remedy for the actual mistake** — the user who wrote
     `rowsv:{tags}*` meant `rowsv:tags*`.~~ **STRUCK by [Q_U42](#q-u42)
     (2026-08-11, same session).** Under Q_U42 `rowsv:{tags}*` is not a mistake
     at all: it CONCATENATES to `{:tags @[1 2 3]}`, and the two spellings mean
     different, both-useful things that track the language's own
     descent/projection distinction — `rowsv:tags*` → `@[1 2 3]` (key dropped)
     versus `rowsv:{tags}*` → `{:tags @[1 2 3]}` (key kept). **Q_U41's CORE is
     untouched** (provenance needs a key; a positional layer has none) and
     arguments 1 and 2 stand on their own; this third one does not, and is struck
     rather than quietly reworded so the reversal stays visible.
  **THE REFUSAL'S TWO BRANCHES**, restated under Q_U42:
  · the plain `*` already does the job → say so. `rowsv:{tags}*_` is refused
    because the deleted layer is POSITIONAL, and the advice is **drop the
    underscore**: `rowsv:{tags}*` → `{:tags @[1 2 3]}` is what was wanted.
  · there is no join to be had at all → **drop the star**. Measured:
    `pair := @[{:host "a"} {:host "b" :port 1}]` (heterogeneous ⇒ a tuple) has
    `pair:{host}*` erroring on LEAVES (§3.6 rule 4) and `pair:host*` likewise, so
    `pair:host` → `@["a" "b"]` is already the answer. Forcing a join there is an
    attempt to turn positional data into nominal data — §8 Q3's territory, not
    the star's.

- <a id="q-u42"></a>**⭐ Q_U42 — THE KEYWISE JOIN CONCATENATES SAME-KEY VECTOR
  VALUES [owner, 2026-08-11 — "(b) Concatenate gives our spellings more
  expressivity, and I think brings us closer to our design goals"].** When
  [Q_U40](#q-u40)'s join recurses into a shared output key whose two values are
  both VECTORS, it **concatenates** them rather than erroring.
  **WHERE IT ARISES — one level DOWN, not at the top.** `rowsv:{tags}*` deletes
  the ω layer and joins the two Maps keywise; both carry `:tags`, and the values
  are `@[1 2]` and `@[3]`. Spec §3.6 rule 2 wants both Map-shaped (no); rule 3
  wants two branches with identical spines (no — these are two ELEMENTS of one
  traversal, not sibling branches). So the default was rule 4's *"at least one
  side a leaf → error"*, reached **by elimination rather than by anyone having
  considered vectors**. That is why it needed a ruling instead of an inheritance.
  **THE ARGUMENT, and it is Q_U40's own**: the top-level rule already says
  *vectors concatenate*. Erroring one level down would make the SAME operator say
  "vectors concatenate" at depth 0 and "vectors error" at depth 1. Under Q_U42
  the join is ONE recursive rule at every depth — **Maps recurse · vectors
  concat · keyless components concat · leaves error** — which is the uniformity
  Q_U40 was adopted for. It composes: `d := @[{:a {:t @[1]}} {:a {:t @[2]}}]`
  gives `d:{a}*` → `{:a {:t @[1 2]}}` (recurse on `:a`, concat on `:t`).
  **RULING B DOES NOT FORBID IT.** Its *"zipping vectors that merely happen to be
  siblings has no witness and stays an error"* forbids POINTWISE merge without an
  alignment witness. Concatenation is TOTAL and needs no witness. §3.6 is silent
  on concat, not against it. *(Recorded explicitly because the opposite reading —
  taking a Ruling B line as governing an operation it does not govern — is the
  error that had blocked [Q_U40](#q-u40) for two rounds.)*
  **COST, stated**: concat merges data without provenance — which element did
  each item come from? Accepted, because the identical concern applies to the
  ALREADY-ADOPTED top-level mapcat (`rowsv:tags*` → `@[1 2 3]` loses exactly the
  same provenance, spec §3.5), so it does not distinguish the readings.
  **NOTHING ELSE MOVES**: non-vector shared values are unaffected —
  `pair:{host}*` errors on leaves under either reading.
  **CONSEQUENCE, and it is why this is not a small ruling**: it makes
  `rowsv:{tags}*` a FEATURE rather than a refusal, and the two star spellings now
  track the language's own descent/projection distinction —
  `rowsv:tags*` → `@[1 2 3]` (key dropped) versus `rowsv:{tags}*` →
  `{:tags @[1 2 3]}` (key kept). It also STRIKES [Q_U41](#q-u41)'s third
  supporting argument; see there.

- <a id="q-u44"></a>**⭐ Q_U44 — A KEYED LAYER'S POSITIONAL JOIN TAKES CANONICAL
  KEY ORDER, AND `x{a* b* c*}*` IS THE ORDER-RECOVERING SPELLING [owner,
  2026-08-11].** When [Q_U40](#q-u40)'s join concatenates the values of a **keyed**
  layer into a vector, the contents are ordered by **canonical key order** (the
  `symbol<?` order `make-record` already canonicalizes with) — not by champ hash
  order, and not by written order.
  **THE DEFECT IT REPLACES, measured at 1b-iii attempt 1**: contents were read
  via `champ-entries`, so `mm{zz aa mm}*` and `mm{mm aa zz}*` were
  **byte-identical** at `@[3 4 1 2 5 6]` — neither written order nor anything a
  reader could predict, and liable to move if the champ implementation changes.
  **⭐ WHY THE TWO SPELLINGS STILL AGREEING IS *CORRECT*, not a residual wart.**
  Under canonical order those two spellings still produce the same answer, and
  that is right: spec §1.1 + §8 Q2 rule that *nominal key IDENTITY carries the
  meaning, order does not*, so for a KEYED block the two spellings **are the same
  selection**. Hash order was not wrong for collapsing them — it was wrong for
  being ARBITRARY and UNSTABLE. Canonical order removes exactly that and leaves
  the key-sort thesis intact. *(Recorded because the first analysis of this
  question treated the collapse as the defect and recommended refusal on that
  basis — the wrong diagnosis produced the wrong recommendation.)*
  **THE ORDER-RECOVERING SPELLING [owner]**, and it introduces no new mechanism:
  ```
  mm := {:zz @[1 2] :aa @[3 4] :mm @[5 6]}
  mm{zz aa mm}*      →  @[3 4 5 6 1 2]     canonical (aa · mm · zz)
  mm{zz* aa* mm*}*   →  @[1 2 3 4 5 6]     WRITTEN order
  ```
  Each inner star deletes its own branch's key layer — whose contents are a
  SINGLE vector, so no order is fabricated — and contributes it as a **KEYLESS**
  component. Three keyless components make a keyless level, which spec §3.3
  defines as *"tuple components in written order"*. The outer star then deletes a
  layer that is genuinely ordered. **The user recovers order by opting into
  KEYLESSNESS, which is already the language's own carrier of positional
  meaning.**
  **The pairing is [Q_U38](#q-u38)'s shape**: a principled default plus a
  first-class way to ask for the other thing (there, refuse + `*_`; here,
  canonical + `{a* b* c*}*`).
  **Rejected-with-reason**: *written order by default* — contingent on an
  OrderedMap the language does not have; deriving it would force the star's two
  halves to compute contents differently by layer sort. *Outright refusal* —
  costs expressivity the design intends, and the "surprising order" objection
  dissolves once the remedy is IN the language.
  **⚠ OBLIGATION IT CREATES**: `mm{zz* name}` mixes a KEYLESS branch with a KEYED
  one — an L4 sort error, and exactly attempt 1's defect #2 shape (which aborted
  in `make-record` instead of erroring). The parser-gate carve-out must make that
  a **guided** L4 error: users following the documented recovery spelling will
  hit it whenever they mistype, so this is now an ergonomics requirement, not
  only a correctness one.
  **Next free Q-label: U45.**

- <a id="q-u45"></a>**⭐⭐ Q_U45 — L★'s QUALIFIER WIDENS: THE DISTRIBUTION LAW HOLDS
  ONLY WHERE THE JOIN IS KEYWISE. THE VECTOR CASE IS A DELIBERATE
  NON-EQUIVALENCE, NOT A COLLISION WITH [Q_U44](#q-u44) [owner, 2026-08-12].**

  **THE LAW, stated once — it is cited constantly and was written down nowhere in
  one piece, which is why the defect below survived three sessions:**
  > **L★  `x{p₁* … pₙ*}  ≡  x{p₁ … pₙ}*`** — *star every branch* equals *star the
  > whole result.*

  **THE AMENDMENT — one clause; NO program changes meaning.** L★ holds provided
  the preceding step is a BLOCK, **with no intervening ω, AND the branches'
  contents are Maps** — equivalently, the star's join is KEYWISE, so each branch
  star's contribution is **absorbed** by the enclosing level rather than
  **stacked** as a keyless component. `mm{zz aa}*` and `mm{zz* aa*}` keep exactly
  the values [Q_U40](#q-u40) and Q_U44 already give them; what changes is that we
  stop asserting they are equal, and the vector case is PINNED as a
  non-equivalence beside the ω one.

  **⭐⭐ WHY IT FAILS FOR VECTORS — ON *SHAPE* BEFORE ORDER EVER ENTERS.** This
  was first framed (by me) as an ordering conflict with Q_U44. It is not. With
  `mm := {:zz @[1 2] :aa @[3 4] :mm @[5 6]}`:

  | spelling | result | why |
  |---|---|---|
  | `mm{zz aa mm}*` | `@[3 4 5 6 1 2]` : `[PVec Int]` | ONE keyed layer deleted; contents = three vectors; concat in CANONICAL order (aa·mm·zz) |
  | `mm{zz* aa* mm*}` | `@[@[1 2] @[3 4] @[5 6]]` : `⟨[PVec Int] …⟩` | each branch deletes ITS OWN key layer, whose contents are a *single* vector → **one keyless component each**; three of them = a TUPLE, written order |
  | `mm{zz* aa* mm*}*` | `@[1 2 3 4 5 6]` : `[PVec Int]` | Q_U44's recovery — the outer star deletes that keyless layer; keyless contents concat in WRITTEN order |

  Rows 1 and 2 are L★'s two sides, and they differ in **ARITY** — an n-tuple of
  vectors against one flat vector. Row 2 is Q_U44's own text, not an inference
  (*"whose contents are a SINGLE vector, so no order is fabricated — and
  contributes it as a KEYLESS component"*). The Map side is equal because a
  Map-valued branch star **splices its keys** into the enclosing block level,
  which is the same operation the result form's keywise join performs:
  `m2{a* b*}` ≡ `m2{a b}*` ≡ `{:x 1, :y 2}`. **Every worked example behind L★
  used Maps. That is why nobody caught it.**

  **⭐ AND THE NON-EQUIVALENCE IS Q_U44's MECHANISM SEEN FROM THE OTHER SIDE, not
  a conflict with it.** Q_U44's whole device is *order is recovered by opting into
  KEYLESSNESS*. The distributed form IS opting into keylessness. Rows 1 and 3 —
  both flat — differ only in order, and that difference is precisely what Q_U44
  sells. Row 4 makes the other half visible: `mm{aa zz mm}*` is byte-identical to
  row 1, because §1.1 + §8 Q2 rule that for a KEYED block, key IDENTITY carries
  the meaning and order does not.
  ⚠ **A precision the deliberation turned on**: the Map join is order-insensitive
  because the RESULT IS A MAP (a Map's identity is its key→value association;
  order never enters), **NOT** because of the champ's hash ordering — hash order
  was the DEFECT Q_U44 killed. Order has to be *manufactured* only when Map
  contents are flattened INTO a vector, and that is exactly where Q_U44 rules
  canonical. Three regimes: **Map→Map, order never arises · Map→vector, order is
  manufactured ⇒ CANONICAL · keyless→vector, order is already there ⇒ WRITTEN.**

  **⭐⭐ THE SURFACE-OBSERVABLE FORM, and it is the better test [owner's
  observation, 2026-08-12 — "in the vector cases they all must have `*`
  postfixed, whereas in the Map case it would not be an error if one branch were
  and the other not"].** Absorption shows up as a LEGALITY difference, not only an
  equality one:
  ```
  m2{a* b}    →  {:x 1, :b {:y 2}}   LEGAL — splice `a`, KEEP `b`'s key
  mm{zz* aa}  →  L4 mixed keyed/keyless — one keyless component beside one keyed
  ```
  A Map-valued branch star contributes KEYED components, which sit happily beside
  an unstarred keyed branch; a vector-valued branch star contributes ONE KEYLESS
  component, which cannot. **This is checkable without computing the answer**, so
  it is what the battery should assert. Q_U40 already names `m{a* b}` as the
  reason the branch form is *strictly more expressive*.

  **⛔ AND IT FALSIFIES THE PARKED PATCH'S `(list #f)`** — see
  [§5.P4e-1b-iii](phases/CIU_6_P4e-1b-iii-iv.md#p4e-1b-iii) finding A2. Classifying every star branch KEYLESS
  at the parser makes `m2{a* b}` an L4 error, i.e. **the patch refuses Q_U40's own
  headline expressivity example.** `(list #f)` is right for vector contents and
  wrong for Map contents, and the parser cannot tell which — which is the whole
  reason Q_U43 moved the check to typing.

  **COST, accepted eyes-open**: L★'s side condition stops being SYNTACTIC ("is
  there an ω in the spelling?") and becomes SEMANTIC ("are the contents Maps?"),
  so a user cannot apply the law by pattern-matching on syntax, and P5's L2
  factoring cannot use it as a rewrite without a type-directed guard. Mitigation:
  that is where the information already lives — Q_U38 and Q_U43 moved the star's
  collision and sort checks to TYPING for exactly this reason, so a type-directed
  side condition on a star law is consistent with the design rather than a new
  exception.
  **Rejected-with-reason** (all three break something landed): *make a vector
  branch star SPLICE its elements* — does not even rescue L★ (`@[1 2 3 4]` vs
  `@[3 4 1 2]`) and destroys Q_U44's recovery, which works *because* the inner
  star contributes one component and fabricates no order · *make the result form
  written-order* — contradicts Q_U44 head-on, needs an OrderedMap the language
  does not have, and would make `mm{zz aa}*` differ from `mm{aa zz}*`, breaking
  the §1.1/§8 Q2 thesis · *refuse a star over a keyed layer with vector contents*
  — kills the headline concat case and runs against [Q_U42](#q-u42), which ruled
  the analogous shape one level down to CONCAT rather than error.
  **Next free Q-label: U46.**

- <a id="q-u46"></a>**⭐⭐ Q_U46 — A DEEP `*` DELETES THE LAYER ITS *PRECEDING STEP*
  MADE, AND THE JOIN LANDS **BARE** BELOW THE SURVIVING KEY ("B-splice")
  [owner, 2026-08-12].** Discharges [the deep-prefix question](phases/CIU_6_P4e-1b-iii-iv.md#q-deep-prefix)
  and lifts the 1b-iii shield.

  **THE RULE, in one sentence:**
  > For a branch `s₁.s₂ … sₙ*`, the star deletes the layer **sₙ** contributed,
  > joins that layer's contents, and the result lands as the **value** of the
  > still-surviving `sₙ₋₁` — every prefix step above re-nests around it
  > unchanged.

  **WORKED, on `cfg := {:db {:hosts @[1 2] :ports @[80]}}` and
  `two := {:a {:x @[1] :y @[2 3]}}` (starless baselines MEASURED at `68604a07`):**

  | spelling | starless baseline | **Q_U46 (B-splice)** | the REJECTED branch-root reading |
  |---|---|---|---|
  | `cfg{db.hosts*}` | `{:db {:hosts @[1 2]}}` | `{:db @[1 2]}` | `{:hosts @[1 2]}` |
  | `two{a.{x y}*}` | `{:a {:x @[1] :y @[2 3]}}` | **`{:a @[1 2 3]}`** | `{:x @[1] :y @[2 3]}` |
  | `rows{k:s*}` | `{:k @[{:s @[1]} {:s @[2 3]}]}` | **`{:k {:s @[1 2 3]}}`** | the RAW field, 0 errors |

  **⭐⭐ WHY — AND THE ARGUMENT IS MECHANICAL, NOT AESTHETIC.** The branch-root
  reading takes the layer to be the WHOLE re-nest, and a bare chain re-nests to a
  SINGLE-KEY map at every level — so its contents are always **exactly one
  thing**, and "join one thing" is the identity. **Under branch-root a deep star
  can never JOIN; it only unwraps one level of ancestry, which `^` already
  spells** (MEASURED: `cfg{db^.hosts}` → `{:hosts @[1 2]}` is byte-identical to
  what branch-root would produce). That is precisely the defect
  [Q_U23](#q-u23) diagnosed when it retired `.*` — *"an IDENTITY wherever the
  head key survives"* — and [Q_U22](#q-u22)'s bar on teaching a second spelling.
  Under Q_U46 the innermost layer's contents can be MANY (a sub-block's fields,
  an ω's per-element values), so the star genuinely joins.
  **Spec support**: §3.5 *"Postfix, **after the step whose result it flattens**"*
  — the only sentence naming which step, and it names the preceding one.
  **Band agreement**: the PATH band already implements this (MEASURED
  `cfg.db.hosts*` → `@[1 2]`, i.e. `hosts`' layer deleted, not `db`'s), because
  Q_U13's NEST caps a path prefix at one step. Q_U46 makes
  `cfg{db.hosts*}` the projection of that same answer under the surviving key;
  branch-root keeps a DIFFERENT key and so breaks Q_U40's *"ONE rule across BOTH
  axes"*.
  **THE EXPRESSIVITY IT BUYS, and it is exactly two idioms** — everything else in
  the family is already spellable and was verified so:
  1. **group N sibling fields into ONE vector under a chosen key** —
     `two{a.{x y}*}` → `{:a @[1 2 3]}`. ⚠ `^` CANNOT reach it: MEASURED,
     `two{a.{x y}^..}` is refused (*"a `^` operates on the segment to its
     LEFT"*), because the segment to its left is a `}`.
  2. **cross-element ω join with ancestry kept** — `rows{k:s*}` →
     `{:k {:s @[1 2 3]}}`. ⚠ The block band's ω KEEPS the inner key (MEASURED:
     `rows3{k:s}` removes `:t` per element but keeps `:s`), so the contents are
     Maps and the join is KEYWISE — the inner `:s` survives. This corrects an
     earlier prediction of `{:k @[1 2 3]}` in the co-design.
  **REJECTED, each with its reason:**
  · **branch-root** (the shipped algorithm sentence) — the identity/duplicate
    argument above; also its one non-duplicate shape was a MEASURED silent wrong
    answer (`rows{k:s*}` returning the raw field at 0 errors).
  · **B-tuple** (the join lands as an honest 1-tuple, `{:a ⟨@[1 2 3]⟩}`) —
    consistent with §3.3's honest nesting, but it makes `zz.q*` byte-identical to
    the SHIPPED `zz.{q*}` (MEASURED `{:zz ⟨@[1 2]⟩}`), trading one
    duplicate-spelling objection for another AND losing the flat result that is
    the shape a user writes by hand.
  · **permanent refusal** (keep the shield; rule `.{…}`/`^..`/`^-` the sanctioned
    deep spellings) — costs both new idioms for no correctness gain, and the
    shield's own message already concedes the question is answerable.
  **⚠ HONEST COST, stated**: for a plain key-terminal chain, Q_U46's answer
  DUPLICATES `^..` (MEASURED: `cfg{db.hosts^..}` → `{:db @[1 2]}`). The
  difference from branch-root is WHERE: Q_U46 duplicates only in the DEGENERATE
  case (one content, where joining and unwrapping coincide) and is new whenever
  there are several; branch-root duplicates in EVERY case.
  **TWO GAPS, RULED AS GUIDED ERRORS [owner, same turn]:**
  1. **An ORDINAL prefix has no "preceding step's layer"** — [Q_U2](#q-u2)
     Reading A says an ordinal step contributes NO output level, so
     `nested{a[0]*}` has nothing for the rule to quantify over. **Guided error**,
     naming the reason.
  2. **L2's normal form is not legality-preserving across a star** — MEASURED:
     `bd{modules:{diags* name}}` is an L4 mixed keyed/keyless error, so
     `{p:a* p:b} ⟶ p:{a* b}` cannot be applied blind. **Guided error** at the
     seat; the law's side condition is filed as [DEFERRED 115](../../../DEFERRED.md) for
     P5, which owns L2.
  **⚠ D4's OWN ALGORITHM SENTENCE IS SUPERSEDED** — see
  [§5.P4e-1b-iii](phases/CIU_6_P4e-1b-iii-iv.md#p4e-1b-iii): *"the below-walk over the prefix … that re-nested
  value IS the layer"* described the branch-root reading and is the sentence the
  implementation inherited. Corrected there.
  **Next free Q-label: U47.**

- <a id="q-u47"></a>**⭐⭐ Q_U47 — THE JOIN LANDS AS THE *REMAINDER'S* COMPONENT:
  KEYED WHERE A STEP SURVIVES TO NAME IT, KEYLESS OTHERWISE [owner, 2026-08-12 —
  "I'm favoring the shape of A… that's looking closer to design intent in the
  spec"].** Discharges the gap [Q_U46](#q-u46)'s sentence left open: *"lands BARE
  as the value of the still-surviving `sₙ₋₁`"* has no referent when nothing above
  `sₙ` names a key.

  **THE RULE, one sentence with no exceptions:**
  > The join lands as the component that **branch-minus-star-minus-`sₙ`** would
  > produce — **keyed** if that remainder names a key, **keyless** otherwise,
  > *including when the remainder is empty*.

  **THE FOUR SHAPES IT COVERS** (subjects `cfg := {:db {:hosts @[1 2] :ports
  @[80]}}` · `mm := {:zz @[1 2] :aa @[3 4]}` · `vh := @[@[@[1 2]] @[@[3]]]`;
  depth-1 MEASURED at HEAD, the rest are this ruling's targets):

  | spelling | remainder | lands | note |
  |---|---|---|---|
  | `mm{zz*}` | `'()` | **keyless** | MEASURED `@[@[1 2]] : ⟨[PVec Int]⟩` — the shipped answer, unchanged |
  | `cfg{db.hosts*}` | `[db]` | keyed `:db` | `{:db @[1 2]}` |
  | `cfg{db^.hosts*}` | `[(@key db dissolve)]` | **keyless** | the dissolve splices; nothing survives to name it |
  | `vh{0.{0}*}` | `[(@ord 0)]` | **keyless** | an ordinal head names nothing |

  **⭐ WHY — THE MACHINERY ALREADY HOLDS THE ANSWER.** MEASURED by direct call at
  HEAD: `select-branch-top-keys '(db)` → `(db)` · `'((@key db dissolve))` →
  `(#f)` · `'((@ord 0))` → `(#f)`. The classifier already answers *keyless* for
  exactly the shapes a refusal would have rejected, so refusing means writing a
  guard against a correct answer the code is holding.
  **⚠ THE TWO CANDIDATE RULES DIVERGE, AND THE OBVIOUS ONE IS WRONG** — MEASURED:
  drop-the-star-only gives `'((@key db dissolve) hosts)` → `(hosts)`, which
  fabricates a key the output does not carry (the exact class Q_U43's `'()`
  exists to prevent); drop-star-**AND**-`sₙ` gives `(#f)`, which is correct
  because the join REPLACES `hosts`' component and a dissolved head then splices
  it keylessly. The two agree on every plain-key branch, which is why the wrong
  rule looks safe.
  ⚠⚠ **IMPLEMENTATION TRAP, MEASURED**: `select-branch-top-keys '()` **RAISES**
  (`car: contract violation`). The empty remainder is the depth-1 case — i.e. the
  most common one — so a literal "drop two, then ask" implementation crashes
  immediately. The empty case must be answered without calling it.

  **WHAT IT BUYS — [Q_U44](#q-u44) GENERALIZES FROM DEPTH 1 TO ANY DEPTH.** Q_U44
  rules that a keyed layer joins in CANONICAL order and that written order is
  recovered by opting into KEYLESSNESS (`mm{zz* aa* mm*}*` → `@[1 2 3 4 5 6]`).
  Under Q_U47 the same idiom works at depth — with `d := {:p {:u @[1]} :q {:v
  @[2]}}`, `d{p.u* q.v*}*` joins in canonical order while `d{p^.u* q^.v*}*` is
  keyless-and-therefore-written-order. Under a refusal the second is unwritable.
  This is a shipped ruling composing with itself, not a new idea.
  **REJECTED, each with its reason:**
  · **guided refusal for the unnamed case** — refuses shapes the classifier
    already answers; makes the rule an exception the user must learn with no
    surface cue (*"`*` works at depth, unless the step above happens to be
    dissolved or an ordinal head"*); costs the written-order-at-depth idiom. It
    is the *"conservatism buying nothing"* shape [Q_U40](#q-u40) already rejected
    once, when the same argument killed its block-generic option.
  · **split it** (refuse the ordinal-head case, allow the dissolve case) — two
    structurally identical situations behaving differently, which is the
    objection that killed Q_U40's SPELLING-DETERMINED option.
  · **refuse everywhere, including depth-1** (uniform in the other direction) —
    **disqualified three ways**: non-monotone (spec §3.6 bars meaning →
    refusal), it breaks shipped and pinned behaviour, and Q_U44's recovery
    spelling DEPENDS on depth-1 landing keyless, so it would delete a ruling made
    four days earlier.
  **COST, accepted eyes-open**: monotonicity is SPENT here — a meaning cannot
  later become a refusal, so the refusal option is gone for good. And
  `vh{0.{0}*}`'s battery pin (`test-path-selection.rkt`, written deliberately at
  1b-iii-B2) flips from refusal to keyless success; the flip must carry its
  reasoning, not be re-pointed silently.

  **⚠⚠ WHAT THIS DOES *NOT* RULE — AND Q_U40'S OWN HEADLINE EXAMPLE IS THE
  UNANSWERED CASE.** Q_U47 rules the LANDING for **vector** contents. Q_U40's
  `m{a* b}` → `{:x 1, :b {:y 2}}` is depth-1 with **nominal** contents, where the
  join SPLICES its fields into the level rather than landing as one component —
  whereas depth-1 vector contents land as ONE keyless component (MEASURED
  `mm{zz*}` → `⟨[PVec Int]⟩`). So splice-vs-single-component for a nominal join,
  at any depth, is **1b-iv's question** and is deliberately left open here.
  Recorded because the two readings look like one rule until the contents differ.
  **Next free Q-label: U48.**

- <a id="q-u48"></a>**⭐ Q_U48 — `*-` IS THE STAR FAMILY'S *TOTAL COLLAPSE*, AND
  ITS SEMANTICS ARE FORCED RATHER THAN CHOSEN [owner, 2026-08-12 — "the `*-` and
  the `^-`, with a reading of, pick the key and bring it to the top, flatten"].**

  **THE RULE:**
  > `*-` flattens **and** collapses every surviving ancestor: the join lands
  > **KEYLESS at the branch's top level**, whatever the remainder would have
  > named.

  **IT IS TO `*` WHAT `^-` IS TO `^` — the total form beside the selective one**,
  and the caret family's behaviour is MEASURED at HEAD (`dd := {:p {:u @[1] :w
  @[9]} :q {:v @[2]}}` · `e3 := {:a {:b {:c @[1 2]}}}`):
  · `dd{p.u^-}` → `{:u @[1]}` · `dd{p^.u}` → `{:u @[1]}` — **identical at depth 2**
  · `e3{a.b.c^-}` → `{:c @[1 2]}` · `e3{a^.b^.c}` → `{:c @[1 2]}` — `^-` ≡
    dissolving EVERY ancestor, exactly as [Q_T7](#q-t7) says
  · `e3{a.b^.c}` → `{:a {:c @[1 2]}}` — the SELECTIVE form says something the
    total form cannot, which is why both earn their keep
  The star family inherits that shape verbatim: `d{p.u*- q.v*-}*` ≡
  `d{p^.u* q^.v*}*` **at depth 2** (the owner's observation, and it holds), and
  they separate at depth ≥ 3 — `e3{a.b.c*-}` collapses all ancestry while
  `e3{a.b^.c*}` keeps `:a`.

  **⭐ THE SEMANTICS ARE FORCED, NOT CHOSEN.** Two readings are available and only
  one coheres. Reading 1 (adopted): land keyless at the top. Reading 2, the
  literal parallel to `^-`'s *"collapse ancestry, KEEP the leaf key"*, would give
  `dd{p.u*-}` → `{:u @[1]}` — **incoherent**, because `*` deletes the layer `u`
  contributed and `:u` is the key naming that layer, so re-attaching it puts back
  exactly what the operator removed. That is [Q_U23](#q-u23)'s identity defect,
  the one that retired `.*`. So `*-` must land keyless — which is the owner's own
  reading, arrived at independently.
  **⚠ IT THEREFORE DEPENDS ON [Q_U47](#q-u47)**: `*-`'s landing is Q_U47's
  keyless case made unconditional. Under a refusal ruling `*-` would have had to
  invent keyless landing for itself.
  **THE LEXICAL SURFACE IS ALREADY FREE, MEASURED**: `dd{p.u*-}` at HEAD does not
  fall through to an unbound variable — `u*-` fuses into ONE lexeme (`-` is an
  `ident-continue?` char) and reaches `split-star-lexeme`, which returns the
  guided *"`*` is the layer-delete operator and attaches at the END of a
  segment"*. That is exactly where `*_` sat before [Q_U39](#q-u39). So in the
  FUSED-IDENTIFIER band `*-` costs one arm in the splitter's continuation grammar
  plus one `(@star cont)` value (`'flatten-collapse`) and **no reader change at
  all** — strictly cheaper than `*_`'s closer-adjacent mint, which is why that
  one needed its own slice.
  **NOT A SECOND SPELLING** (the [Q_U22](#q-u22) bar): total and selective are
  different expressivity, proven by the measured `e3{a.b^.c}` above — the same
  justification Q_T7 already accepted for `^-` beside `^`.
  **SLICE PLACEMENT — the star-SUFFIX slice, after 1b-iv** (see
  [§5.P4e-1b-sequencing](phases/CIU_6_P4e-1b-iii-iv.md#p4e-1b-sequencing)). Ruled now rather than later for a
  concrete implementation reason: Q_U47's landing is CONDITIONAL (re-nest iff the
  remainder names a key) and `*-`'s is UNCONDITIONAL (never re-nest). They are one
  code path with a flag, and knowing that now keeps 1b-iii-C from baking the
  condition in.
  **⚠ OPEN, deliberately not ruled**: `*-_` (collapse + provenance, the analogue
  of `^-_`'s flat provenance recovery — MEASURED `dd{p.u^-_}` → `{:p-u @[1]}`).
  It is the obvious next member and it interacts with [Q_U41](#q-u41)'s
  nominal-only scoping for `*_`. Decide it WITH the suffix slice, not before.
  **Next free Q-label: U49.**

- <a id="q-u49"></a>**⭐⭐ Q_U49 — A NOMINAL JOIN *SPLICES* ITS FIELDS INTO THE
  ENCLOSING LEVEL, AT EVERY SEAT [owner, 2026-08-13 — "take (a) — land it B1/B2
  style"].** This answers the question [Q_U47](#q-u47) deliberately left open.

  **THE RULE:**
  > When `*` deletes a layer whose CONTENTS are Maps, the keywise join contributes
  > **KEYED COMPONENTS** to the enclosing level — it splices. When the contents are
  > vectors it contributes ONE KEYLESS component, as it does today. The landing's
  > sort follows the CONTENTS, which is [Q_U40](#q-u40)'s rule applied literally.
  > ⚠ Unchanged where a key SURVIVES: `cfgn{db.conf*}` → `{:db {:x 1}}`. The
  > remainder names the landing per Q_U47, so the fields nest INSIDE `:db` and no
  > splice question arises. **The splice is only ever about the KEYLESS landing.**

  **⭐ IT IS NOT AN EXCEPTION TO THE SPEC — IT IS WHAT "THE SORT FOLLOWS THE
  CONTENTS" MEANS.** Measured at HEAD, the vector half already behaves this way:
  a vector-valued join contributes a keyless component, so `mv{a* b}` is an L4
  error (keyless star beside a keyed sibling) while `mv{a* b*}` is a 2-tuple. A
  Map-valued join contributes KEYED material, and keyed material at a level IS
  components-with-keys. So Q_U40's `m{a* b}` → `{:x 1, :b {:y 2}}` is the same
  rule, not a special case. The rejected reading — land as ONE keyless component
  — would make a Map-valued join contribute a KEYLESS one, i.e. the sort would
  follow the WRAPPER rather than the contents, contradicting Q_U40 directly.

  **⭐⭐ AND [Q_U45](#q-u45)'s L★ DECIDES IT INDEPENDENTLY.** L★ says
  `x{p₁* … pₙ*} ≡ x{p₁ … pₙ}*` holds for MAP contents and fails for vectors ON
  ARITY. The vector half is measured exactly so (`mv{a* b*}` → `⟨[PVec Int]
  [PVec Int]⟩` vs `mv{a b}*` → `[PVec Int]`). Under SPLICE the Map half holds:
  `mn{a* b*}` and `mn{a b}*` both give `{:x 1, :y 2}`. Under one-component it
  gives `⟨{:x 1} {:y 2}⟩` vs `{:x 1, :y 2}` — **unequal, so one-component
  FALSIFIES a ruling already made.**

  **THE EXPRESSIVITY ARGUMENT, and it is decisive on its own**: under
  one-component `mn{a*}` → `⟨{:x Int}⟩` — the star deletes the `:a` layer and the
  keyless wrapper immediately puts one back, net zero — and `mn{a* b}` is an L4
  error, so a nominal splat could never combine with a sibling. The nominal star
  would be a no-op with extra steps. Splice is what makes it the FIELD-LIFTING
  operator the feature exists for.

  **⚠ THE COST MODEL THAT ALMOST CHOSE THE OTHER OPTION WAS WRONG, and it was the
  grounding audit's most consequential structural claim.** The audit reported
  splice as *"IMPOSSIBLE at the ordinal-head route without changing the
  below-walk's return contract in BOTH twins"*, which argued for splicing only at
  Seat A and refusing Seat B. **Refuted by reading the arm**: the ord-branch
  caller has `rest` — the very step list it passed to `select-below-field` — in
  scope, and `select-steps-star-tail?` is already exported and already used two
  arms away. So the caller can ask *"is this returned type a BARE star join?"*
  with an exact, local test: true precisely when the tail arm fired at this
  level, false for `(b c ★)` where the walk re-nests. Reduction's twin has
  `(cdr b)` in the same position. Splice at Seat B is therefore **a predicate
  test at one arm per twin, not a contract change** — and with that saving gone,
  the Seat-A-only option bought nothing but an arbitrary refusal.
  ⭐ **The lesson is the R-lens one**: the audit's cost estimate, not its facts,
  is what would have made the wrong ruling. Verify the load-bearing claim.

  **THE FOUR SEATS, worked** (`mn := {:a {:x 1} :b {:y 2}}`,
  `cfgn := {:db {:conf {:x 1} :other {:y 2}}}`, `vhm := @[@[{:x 1}] @[{:y 2}]]`):
  · **A1 remainder-empty** `mn{a*}` → `{:x 1}` · `mn{a* b}` → `{:x 1, :b {:y 2}}`
  · **A2 dissolved head** `cfgn{db^.conf*}` → `{:x 1}`
  · **B keyed** `cfgn{db.conf*}` → `{:db {:x 1}}` — unchanged, no splice
  · **B keyless (ordinal head)** `vhm{0.{0}*}` → `{:x 1}` — the shape the
    refuted cost model would have refused.

  **WHAT IT BUYS THE COLLISION RULE FOR FREE**: spliced fields become keyed
  components AT THE LEVEL, so the existing dup gate's `(filter values (map car
  cs))` fold catches splice-vs-sibling and splice-vs-splice with **no new code**.
  Only content-vs-content collisions INSIDE one join need a new check, and that
  belongs at the join itself. [Q_U38](#q-u38)'s seat is therefore two arms, not
  a new mechanism.

  **SCOPE — what this ruling does NOT settle, flagged rather than silently
  deferred**: (1) `expr-Map` contents have **no enumerable keys**
  (`(struct expr-Map (k-type v-type))`), so a collision there is neither provable
  nor refutable — under Q_U38's refuse-on-possibility that is a PERMANENT refusal,
  not a not-yet, and it needs its own fail kind because today's message promises
  "the nominal case is the next slice". (2) `*_`'s PREFIX SOURCE is
  under-specified — [Q_U41](#q-u41)'s two worked examples disagree about whether
  the synthesized key comes from the deleted layer's key or the contents' keys —
  so `*_` is NOT in this slice's scope on the strength of this ruling alone.

- <a id="q-u50"></a>**⭐⭐ Q_U50 — THE ω "TENSION" DISSOLVES: THE TYPE SYSTEM
  ALREADY DISCRIMINATES [owner, 2026-08-13 — "yes to the ω dissolution"].**
  [Q_U40](#q-u40)'s worked battery claims `rowsm:cfg*` → `{:a 1, :b 2}`;
  [Q_U38](#q-u38) refuses a nominal ω join on POSSIBILITY, because under ω one
  element type stands for every element. Filed at the 1b-iv verify as a
  contradiction between two rulings. **It is not one — MEASURED:**
  ```
  rowsm := @[{:cfg {:a 1}} {:cfg {:b 2}}]  ⟹ ⟨{:cfg {:a Int}} {:cfg {:b Int}}⟩  TUPLE
  rowsm:cfg*                                ⟹ {:a 1, :b 2}          ✓ Q_U40's claim
  homog := @[{:cfg {:a 1}} {:cfg {:a 2}}]  ⟹ [PVec {:cfg {:a Int}}]           PVEC
  homog:cfg*                                ⟹ refused, `star-omega-nominal`  ✓ Q_U38
  ```
  **THE DISCRIMINATOR IS THE SUBJECT'S OWN TYPE, and the language already
  computes it.** A vector literal whose elements have DIFFERENT row types cannot
  be a `PVec` — it types as a TUPLE with per-position types, so the join's
  contributors are individually known and non-collision is **provable**. A
  vector whose elements share a row type is a `PVec` with a RUNTIME length —
  the same keys N times, N unknown — so a collision is **possible**.
  ⭐ **This is Q_U38's rule doing real work rather than over-refusing**: it
  refuses exactly where the type cannot rule a collision out, and gets out of the
  way where it can. `star-omega-nominal` fires on precisely the `PVec` side.
  **NO CODE CHANGE.** Owed: the message should name the tuple case as the remedy
  it currently lacks (a fixed-arity literal with distinct element rows joins).

- <a id="q-u51"></a>**⭐⭐ Q_U51 — `*_`'s PREFIX SOURCE IS FORCED, AND `*_` SHIPS
  WITH [Q_U39](#q-u39)'s MINT, NOT IN THE FUSED BAND ALONE [owner, 2026-08-13 —
  "take (b) with Q_U39's mint"].**

  **THE PREFIX RULE, in one sentence:**
  > Each lifted field's key is `<the key its content sat under in the deleted
  > layer>-<the field's own key>`.

  ⭐ **IT IS FORCED, NOT CHOSEN** — the same shape as [Q_U48](#q-u48). The rival
  reading is "prefix = the SEGMENT the star attaches to"; in the fused band they
  COINCIDE (the layer is always the re-nest `{:seg {…}}`), and in a multi-content
  layer there is no single segment for it to name, so only the content-key
  reading is total. It also honours Q_U24's explicit instruction to inherit
  `^-_`'s rule rather than `^_`'s: the DELETED key is the prefix, not the
  surviving path (`^_` measured for contrast: `e2{a.b^_}` → `{:a {:a-b 1}}`).

  **⚠ THE FILED DISAGREEMENT WAS A FALSE ALARM.** The 1b-iv grounding audit read
  Q_U24's two examples as two rules. Measured, they are two EXPRESSIONS with
  different layers, and one rule covers both:
  | spelling | layer (measured) | contents | prefix |
  |---|---|---|---|
  | `cfg{database*_}` | `{:database {:url … :pool-size …}}` | one, under `:database` | `database` |
  | `regions{eu*_}` | `{:eu {:host … :port …}}` | one, under `:eu` | `eu` |
  | `top{regions*_}` | `{:regions {:eu … :us …}}` | one, under `:regions` | `regions` |

  **⭐⭐ AND THE REASON IT SHIPS WITH THE MINT: `*_`'s ENTIRE JUSTIFICATION IS
  CURRENTLY UNSPELLABLE.** [Q_U24](#q-u24) adopted `*_` as the collision remover
  — *"it removes nominal-join collisions BY CONSTRUCTION"* — and a cross-content
  collision needs a layer with SEVERAL contents. Measured:
  ```
  mn{a b}*   ⟹ {:y 2, :x 1}       multi-content layer, closer-adjacent band
  mn{a b}*_  ⟹ Unbound variable    …but `*_` cannot be written there [DEFERRED 124]
  mn{a*_}    ⟹ layer {:a {:x Int}} the only spellable band: ONE content, ALWAYS
  ```
  A fused `seg*_`'s layer is the re-nest of ONE step, so it has exactly one
  content BY CONSTRUCTION and a cross-content collision cannot arise. Shipping
  `*_` there delivers `:database-url` — real, and useful — but the operator
  **cannot do the thing it was adopted for**, and its closer-adjacent refusal
  could not even be exercised.
  **THE EXPRESSIVITY ARGUMENT, which is what decided it**: `cfg{database*_}` has
  workarounds (`cfg{database^.url database^.pool-size}`, or renames) — it is
  convenience. `regions:{host port}*_` → `{:eu-host …, :us-port …}` has NONE:
  bare `*` refuses (every region contributes `:host`), and no spelling flattens a
  homogeneous Map-of-Map while keeping provenance. **That capability is the whole
  reason the operator exists, and it lives entirely in the band we cannot yet
  write.** So the mint is not a nicety attached to the slice — it is the slice.
  ⚠ Rejected alternative (a) "ship the fused band now": it would field an
  operator that works where it is not needed and is unspellable where it is, and
  would rule the prefix on evidence drawn ONLY from single-content layers — the
  derive-from-the-example failure that cost three message rewrites this session.
  ⚠ Rejected (c) "rule now, implement later" as second-best: more honest than
  (a), but it leaves the not-yet live in a band where the answer is now known.

- <a id="q-u52"></a>**⭐⭐ Q_U52 — 1b-v IS THE MINT *PLUS* `*_`'s SEMANTICS; `*-`
  AND `*-_` SPLIT OUT TO 1b-vi [owner, 2026-08-13 — "Ok on the (b) lean"].**

  **THE QUESTION, which the 1b-v grounding audit's four facets all failed to ask
  and its completeness critic did**: is 1b-v a MINT, or is it the SEMANTICS? Both
  facets scoped the slice as *reader gate + `parser.rkt`'s closer-band cont
  channel + sentinel shape*. Measured, that scope delivers **a better error
  message at one band** and leaves [Q_U51](#q-u51)'s motivating capability
  non-existent — which is the shape Q_U51 itself rejected when it declined "ship
  the fused band now".

  **WHAT `regions:{host port}*_` → `{:eu-host …, :us-port …}` ACTUALLY NEEDS,
  beyond the mint** (all measured at HEAD): lifting the typing shield that sends
  every `*_` over Map contents to `star-nominal`'s not-yet · implementing
  Q_U51's prefix join in `star-nominal-join-type` · the **key threading** both
  twins skip (typing maps `record-field-type` over fields; reduction's
  `champ-values/canonical` ends `(map cdr …)`) · and the ω/broadcast **Record**
  arm, which has **no cont test at all** — `homog:cfg*` and `homog:cfg*_` produce
  BYTE-IDENTICAL message bodies, so `*_` there is today neither served nor
  distinctly refused.

  **WHY `*-` SPLITS OUT — three reasons, none of them "it is big":**
  1. **It carries two UNRULED questions.** A *renamed* ancestor survives a deep
     star (`t4{a^p.b.c*}` → `{:p {:b {:x 1}}}`, measured) and `^p`/`^` are
     mutually exclusive spellings of one step — so "total collapse" has no
     defined answer for an explicit rename, and the dissolve-equivalence route
     cannot even pose the question. `^` after `:` is refused outright (Q_U19), so
     a broadcast ancestor is unwritable too. Those are rulings, not code.
  2. **`*->` IS NOT ONE TOKEN** — `>` breaks the identifier (measured:
     `mn{a*-> b}` errors at `a*-`, with `>` separate). The moment `*-` is an
     operator, `x{a*-> b}` becomes a valid `*-` step plus a stray `>`, and
     `<(x : A)*- B>` acquires a new reading. The caret family never had this
     hazard; `*-` inherits it from `->` (ARROW T1's territory).
  3. **The cont axis has no totality dispatcher.** `select-star-cont` is a bare
     `cadr`; all **six** production readers are BINARY tests on `'flatten-synth`,
     so a third value silently reads as bare `*` — including `pp-expr`, which
     would render `*-` as `"*"` and feed that wrong echo into every `*-` label.
     The P4a totality doctrine has never been applied here. That work belongs
     with the spelling that needs it.
     ⚠ **CORRECTED 2026-08-13 (the B2b grounding, `wf_7f5bda0c-500`): this said
     FIVE, and five was WRONG WHEN WRITTEN — not stale.** The readers are
     `pretty-print.rkt:186`, `reduction.rkt:1895`, `reduction.rkt:1902`,
     `typing-core.rkt:1766`, `typing-core.rkt:1784`, `typing-core.rkt:1850`.
     `git log -S` puts the phrase's introduction at `2625b38f` (slice 1b-v-B1);
     reading that commit's own blobs gives six. The number was inherited from the
     source comment at `reader-forms.rkt:256`, which carried it first — so this
     is a **two-carrier** error and correcting either one alone leaves the other
     lying. Both fixed in the same commit as this note.

  **CONSEQUENCE FOR THE SENTINEL SHAPE** — this is what makes the scope ruling
  also settle the shape question. Under (b) the mint adds **ONE** spelling, so it
  is **two bare sentinels**, not four: `$postfix-star` (unchanged) and a new one
  for `*_`. The payload option's whole cost was the arity/head-set decision at
  `access-sentinel?`, and the N-sentinel option's loudest cost was believed to be
  `pattern-var?`'s whole-file abort — **which is FALSE at HEAD** (see the record
  below). With one new spelling and no abort, N-bare-sentinels wins on every axis.
  ⭐ **AND THE NAME IS LOAD-BEARING, CHEAPLY**: the leak gate and four sibling
  pins match an **unanchored substring** `#rx"\$postfix-star"`, so naming it
  `$postfix-star-synth` keeps five existing gates covering it FOR FREE. Any other
  name silently narrows them. (`p4e1-star-class` is an identity test and needs the
  new name added regardless.)

- <a id="q-u53"></a>**⭐⭐ Q_U53 — THE EMIT'S MISS-CASE IS RULED OUT AT THE *GATE*,
  NOT HANDLED AT THE EMIT; AND THE FAMILY GETS ONE SEMANTIC AUTHORITY, FOLDED IN
  ITS OWN SLICE BEFORE 1b-vi [owner, 2026-08-13 — "C, and land the fold before
  1b-vi"].**

  **THE QUESTION.** B2b routes the reader's sentinel emit through
  `postfix-star-lexeme->sentinel`, which returns `#f` on a table miss. What should
  the emit do in that miss-case?

  **PART 1 — THE MISS-CASE IS NOT GIVEN A BEHAVIOUR. IT IS MADE UNREACHABLE.**
  The gate's lexeme conjunct becomes an EXACT-membership test against the family
  table, and the emit performs the same lookup on the same entry's lexeme. Then
  *"the emit missed"* ≡ *"the gate would not have minted"* — and the gate did
  mint. `postfix-star-lexemes` (reader-forms.rkt) already exists for exactly this
  and has **zero consumers**; it is one of two unexercised exports B1 landed.

  ⭐ **THE THREE ALTERNATIVES ARE DISQUALIFIED INDEPENDENTLY, EACH BY MEASUREMENT
  (grounding `wf_7f5bda0c-500`, 5 facets + critic, all R-lens-verified in the main
  session):**
  · **A bare `#f` is a SILENT WRONG ANSWER that reaches user-visible data.** It
    passes TWO permissive `[else]` arms (`parse-reader.rkt:2612` inner, `:2710`
    outer — neither validates), and both quote lowerings test the star sentinel
    FIRST and fall through to the boolean arm (`macros.rkt:7864` precedes `:7877`;
    twin at `:7913`/`:7926`), so it lands as `(datum-bool false)` inside a `Datum`
    — and data territory is exactly where [Q_U37](#q-u37) routes non-fusable
    stars. ⚠⚠ **It is WORSE than the sentinel leaking**: `$postfix-star`
    deliberately has NO `pp-datum` arm so that a leak prints its internal name,
    whereas `#f` hits the boolean arm (`pretty-print.rkt:1652`) and prints
    `false`. The debugging tool someone chasing a star leak reaches for would show
    nothing wrong.
  · **A fallback to `$postfix-star`** is [DEFERRED 129](../../../DEFERRED.md)'s hazard
    relocated from gate to emit, and is Q_U52 §3's cont-axis defect one layer up:
    the user's spelling silently means bare `*`.
  · **A raise is an UNCATCHABLE whole-file abort.** `parse-reader.rkt` contains
    **ZERO** `with-handlers` (verified, `grep -c` → 0), and the G2 preparse-seam
    guard that degrades raises to per-command errors lives inside
    `preparse-expand-all`, which `driver.rkt` calls strictly AFTER
    `read-all-syntax-ws` — so it structurally cannot catch one.

  ⭐ **CONSEQUENCE — THE "SHOULD WE ALSO PLANT AN ASSERTION?" QUESTION DISSOLVES,
  rather than being decided.** The only assertion mechanism available at the
  reader IS the raise, and the raise is disqualified on its own merits. So there
  is no belt-and-suspenders tension to adjudicate: **the canary belongs in a TEST
  that pins gate-and-table agreement, never in the emit.**

  **WHY THE READER MUST NOT CREATE THE CASE AT ALL** — the house already answered
  this one band over, and chose NEITHER silent-default NOR raise.
  `split-star-lexeme` (parser.rkt:1213–1267) is a TOTAL lexeme→cont dispatch whose
  `[else]` returns a user-facing message that the caller turns into a per-command
  `parse-error` **value** (`fail`, parser.rkt:1305). It picked the error channel
  available at ITS layer. The reader has no such channel, so it must not
  manufacture the case. This is also the spec's own posture: §2.2 mitigates
  juxtaposition ambiguity by making *"the confusing spelling also the ill-typed
  one"* — surfaced at the owning seat, never silently resolved.

  **PART 2 — ONE SEMANTIC AUTHORITY, FOLDED IN ITS OWN SLICE, BEFORE 1b-vi.**
  ⚠⚠ **B1's claim that "the family lives as ONE table" IS NOT TRUE AT HEAD.** Four
  sites independently encode which star spellings exist and what each means:

  | # | site | what it knows | who reads it |
  |---|---|---|---|
  | 1 | `reader-forms.rkt:267` the table | lexeme ↔ sentinel ↔ cont | the CLOSER-ADJACENT band's cont (parser.rkt:1506) + the echo seat and both quote lowerings (macros.rkt:6954, :7864, :7913) |
  | 2 | `parser.rkt:1213` `split-star-lexeme` | suffix → cont (`""`→flatten, `"_"`→flatten-synth) | the FUSED, `$dot-access` and ω bands (parser.rkt:1518, :1640, :1669) |
  | 3 | `tools/form-deps.rkt:48` `syntax-keywords` | the sentinel NAMES | 9 `set-subtract` sites in that tool |
  | 4 | `tools/star-arrival-matrix.rkt:149` `star-spellings` | the four SPELLINGS | the mint verifier |

  ⭐ **SITES 1 AND 2 ANSWER THE SAME QUESTION FOR DISJOINT BANDS, so nothing
  cross-checks them.** MEASURED at HEAD in one file: `mn{a*_}` (fused, site 2) →
  `{:a-x Int}` ✅ · `mn{a}*_` (closer, site 1) → `ERROR: Unbound variable` ❌ ·
  `mn{a}*` (control) → `{:x Int}` ✅. Same operator, two authorities, and they
  agree today only because one author wrote both.

  **THE FOLD**: `split-star-lexeme`'s suffix dispatch reconstructs the operator
  lexeme (`(string-append "*" k)`) and asks the table. Worked: `a*` → `k=""` →
  `"*"` → `flatten`; `a*_` → `"*_"` → `flatten-synth`; `a*xyz` → `"*xyz"` → not in
  table → the SAME `star-mid-lexeme-message` as today. **Behaviour-preserving on
  every input**, and the totality of the `[else]` is untouched.

  ⚠ **SITES 3 AND 4 GET PINS, NOT FOLDS — and site 4's reason is load-bearing.**
  `star-spellings` is DELIBERATELY a superset of the table (it lists `*-`/`*-_`,
  which do not mint) because [DEFERRED 127](../../../DEFERRED.md)'s entire repair was that
  the instrument must be able to SEE a non-minting spelling in order to report it
  as 0. **Deriving site 4 from the table would re-blind the mint verifier** — so
  the correct assertion is CONTAINMENT (every table lexeme ∈ `star-spellings`;
  every table sentinel ∈ `syntax-keywords`), never derivation.

  **THE SEQUENCING, AND WHY (owner chose C over B):** B2b lands MINIMAL — gate +
  emit + [DEFERRED 130](../../../DEFERRED.md) — keeping its risk surface READER-ONLY so the
  three live bands cannot regress. The fold is its own following slice, so a
  regression in the reader change and a regression in the parser change have ONE
  suspect each. This is the shape that has actually worked in this phase (A → B1 →
  B2: land machinery inert, then migrate the seat). **The fold lands BEFORE
  1b-vi** [owner] so that ruling `*-` costs a table row rather than a table row
  plus a parser edit plus two tool lists.

  **THE EXPRESSIVITY ARGUMENT, which is not about `*_`:** it is what the NEXT
  continuation costs to RULE. The family will grow at least twice more — 1b-vi's
  `*-`/`*-_`, and spec [§8 Q4](2026-07-28_path-selection-spec.md)
  (`*` on Map layers) is still OPEN. Under one authority that is a one-line table
  edit; under two it is four edits whose half-states are each a live defect (see
  the drift table in [§5.P4e-1b-v-B2b](phases/CIU_6_P4e-1b-v.md#p4e-1b-v-b2b)). Spec §7.5 marks
  first-class selectors "load-bearing" — selectors reify as data — and a table
  with a lexeme column IS that reification started early; two hand-written
  dispatches are not. This ruling is also a down-payment on spec **§8 Q8**
  (*"lexical grammar … including error-message obligations"*), which is open and
  is precisely this question.

- <a id="q-u54"></a>**⭐ Q_U54 — 1b-v-C FOLDS THE FIFTH ENCODER TOO: THE PRINTER's
  cont→lexeme JOINS THE TABLE; SITE 3 IS DERIVED, SITE 4 IS PINNED [owner,
  2026-09-08 — "Let's go with B, yes"].**

  **THE QUESTION** (the 1b-v-C grounding, `wf_8c8b9fc2-54b`): [Q_U53](#q-u53)
  part 2 enumerated FOUR sites that encode the star family. Its completeness
  critic found a **fifth**, and it is user-facing: `pretty-print.rkt`'s star arm
  derives the SPELLING from the CONT with both lexemes hardcoded —
  `[(star) (if (eq? (select-star-cont s) 'flatten-synth) "*_" "*")]` — and
  `typing-core` builds every star refusal label through `pp-select-branch`. It
  predates the table (slice 1b-ii). It is exactly the hazard [Q_U52](#q-u52) §3
  named in words: *"`pp-expr` would render `*-` as `"*"` and feed that wrong
  echo into every `*-` label."*

  **WORKED ON 1b-vi's `*-`.** Under *A* (fold the splitter only): add the table
  row, the reader mints, every band works — and the first type error on a `*-`
  step is labelled `*`. The message says the user wrote `x{a*}`; they did not.
  Under *B*: the printer asks the table for the cont's lexeme and prints `*-`;
  the row is the whole change, and a rendering pin per row makes a half-done
  row loud. **B is ruled.** Cost: one accessor (`postfix-star-cont->lexeme`, a
  row lookup — the table had no cont→lexeme direction), one require edge
  `pretty-print.rkt → reader-forms.rkt` (cycle-free: reader-forms is a pure
  leaf), one arm. ⚠ The CARET family's `cont->string` sits directly above that
  arm, equally hardcoded, and has NO table at all — out of scope; the fold
  touches the star arm only.

  **SPEC**: §8 Q8's second clause — errors *"SHOULD print the normalized /
  remedied spelling"* — is what the printer arm violates the moment the family
  grows; §7.5's first-class selectors want operators as data, and a printer
  that hardcodes the spelling is the last place the vocabulary lives as prose.
  **EXPRESSIVITY**: the fold's point is that ruling `*-` costs a table row.
  Under A it costs a row AND a printer edit that nothing turns red for.

  **THE AMENDMENT TO Q_U53's TEXT, accepted**: "sites 3 and 4 get pins, never
  derivation" over-generalized. The reason — an instrument must stay a SUPERSET
  or it re-blinds itself ([DEFERRED 127]) — is true of **site 4** only
  (`star-spellings`, `tools/star-arrival-matrix.rkt`), which is PINNED
  (`postfix-star-lexemes ⊆ star-spellings`; the tool already has `provide` +
  `module+ main` and the battery already requires it — the earlier claim that
  "no test requires a tools/ module" was FALSE, five do). **Site 3**
  (`syntax-keywords`, `tools/form-deps.rkt`) wants EXACTLY the sentinel names,
  so it is DERIVED from the table (`(map car postfix-star-sentinel-table)`);
  it cannot lag. That also avoids restructuring a SCRIPT (`command-line` and
  the whole analysis run at module level; requiring it from the battery fails
  under `batch-worker` — measured by the audit) just to pin it. ⚠ Site 3
  already omits five ACCESS sentinels — a recorded pre-existing hole this does
  not touch.

  **THE OBLIGATIONS THE RULING INHERITS** (all verified): the hoisted
  `^`-in-name guard stays BEFORE the table lookup; the lookup is on the
  RECONSTRUCTED operator `(string-append "*" k)`, never the fused lexeme (the
  table is exact; `"a*"`→#f is pinned); `parser.rkt`'s `only-in` must widen
  (it lacks `postfix-star-lexeme->sentinel`); the six band×spelling cells with
  ZERO pins are pinned at their MEASURED baselines before the fold; every
  refusal message is pinned in FULL (today the mid message is pinned by the one
  word `map-get`); the tripwire adds `reader-forms.rkt` to its watch list (a
  table-only widening would otherwise slip past it); `syntax.rkt`'s vocabulary
  comment stops naming the splitter as the source. Record:
  [§5.P4e-1b-v-C](phases/CIU_6_P4e-1b-v.md#p4e-1b-v-c).

- <a id="q-u55"></a>**Q_U55 — WHAT TOTAL COLLAPSE DOES TO AN ANCESTOR THAT CARRIES AN
  EXPLICIT KEY CONTINUATION [✅ DECIDED 2026-10-13, owner — "I'm good with Option A
  (refuse) on Q_55. And that we fix `^-` to be in line with the behavior as well, for
  consistency."].** The first of the two decisions [Q_U52](#q-u52) §1 deferred. Grounding:
  [`audits/2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md`](audits/2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md) F1–F4.

  **DECIDED — A, OBSERVABLE-OR-REFUSED, ONE RULE FOR BOTH COLLAPSE FAMILIES.** Reason: it is
  the monotone waypoint (B and C both stay reachable without breaking a program), it turns
  today's silent drop into a guided error, and fixing `^-` costs nothing (0 uses, 0 pins).
  **The rule, made exact by measurement** (probe `probe-1bvi-g`): the only key continuations
  spellable on an ANCESTOR are dissolve `^` and rename `^k'` — `^_` ("attaches to the
  branch's LAST segment") and the `^-` family ("a LEAF continuation") are already refused
  mid-path. So: under a total collapse (`*-`, `^-`, `^-k'`) a **rename on an ancestor is
  refused** with a guided message naming both remedies (drop the rename for total collapse;
  keep the level with the selective spelling, e.g. `t5{a^p.b^.c*}`); under a provenance
  collapse (`^-_`, and `*-_` iff its prefix rule reads the surviving path — decided with
  `*-_`) the rename is observable and stays legal; a **dissolve `^` on an ancestor stays
  legal** (redundant, same output). C stays the recorded successor if real code ever wants
  "collapse all but the named levels". **Implementation shape**: the check is purely
  syntactic (every ancestor's continuation and the leaf's collapse are in the step list),
  so it lives in the ONE shared branch walk the parser's output-level checks already use —
  not in typing; the `^-` half lands in the same 1b-vi slice as the `*-` mint, pinned
  failing-first in both families (`e3{a^p.b.c^-}` today `{:c @[1 2]}` → refused;
  `e3{a^p.b.c^-_}` → `{:p-b-c @[1 2]}` unchanged).

  **THE QUESTION IS ABOUT THE COLLAPSE FAMILY, NOT THE STAR.** A segment carries one
  operator suffix (`c^-*` is refused), so `*-` is `^-` composed with `*`, spelled as a
  star continuation; its treatment of ancestors IS `^-`'s. And `^-` has the hole
  today, unruled, unpinned and unused (0 hits in corpus and tests):
  `e3{a^p.b.c^-}` → `{:c @[1 2]}` (the rename silently DROPPED) while
  `e3{a^p.b.c^-_}` → `{:p-b-c @[1 2]}` (the rename HONORED, through provenance).
  So the caret family observes an ancestor's continuation only through `_`.

  **WORKED, on `t5 := {:a {:b {:c {:m {:x 1} :n {:y 2}}}}}`** (measured: `t5{a^.b^.c*}`
  → `{:m {:x 1} :n {:y 2}}`, the shape Q_U48 gives `t5{a.b.c*-}`; `t5{a^p.b^.c*}` →
  `{:p {:m {:x 1} :n {:y 2}}}`). What is `t5{a^p.b.c*-}`?
  · **A — refuse (observable-or-refused)**: a guided error — the name `p` can never
    appear under a total collapse; drop `^p` for total collapse, or keep the level with
    the selective star `t5{a^p.b^.c*}`. Legal wherever the continuation IS observable
    (under `*-_` / `^-_`, if `*-_` takes `^-_`'s full-path prefix). A dissolve `^` on an
    ancestor stays legal (redundant, same outcome). For one rule across both families,
    `e3{a^p.b.c^-}` becomes the same error (today `{:c …}`; 0 uses, 0 pins).
  · **B — total wins (today's `^-`)**: `{:m {:x 1} :n {:y 2}}`; `^p` is dead syntax.
  · **C — explicit wins (a caret is a per-level instruction, the collapse marker sets
    the DEFAULT for unspoken levels)**: `{:p {:m {:x 1} :n {:y 2}}}` ≡ `t5{a^p.b^.c*}`.
    For one rule, `e3{a^p.b.c^-}` becomes `{:p {:c @[1 2]}}`.

  **TRADEOFFS.** *Correct by Construction* (DESIGN_PRINCIPLES): B fails it (a written
  instruction with no effect); A and C satisfy it. *Monotone migration* (spec §3.6; §1.2
  PS7 "errors may later become meanings, never vice versa"): A is the waypoint from which
  both B and C remain reachable without breaking a program; B and C are meanings, and each
  forecloses the other. *Simplicity of Foundation* ("complexity through composition, not
  special cases"): C composes (explicit beats default — no side condition); A adds a
  legality side condition (observable-or-refused); B composes trivially. *Expressivity*: C
  adds a shorter spelling of "collapse all but the named levels" (saves one caret per
  unnamed ancestor); A and B add nothing over the selective form.
  *Ergonomics*: A's error teaches the selective form; C must be learned, and the name
  "total collapse" stops being accurate; B fails silently. *Evidence of demand*: none for
  C (0 uses of a re-keyed ancestor under `^-`). The broadcast-ancestor half of Q_U52 §1
  does not separate the options (no caret can follow `:`, Q_U19) and is unobservable
  until [DEFERRED 167](../../../DEFERRED.md) (in-block L1) lands.

- <a id="q-u56"></a>**Q_U56 — THE `*->` BOUNDARY IS A GUIDED DIAGNOSTIC, NOT A CONSTRUCT
  [✅ DECIDED 2026-10-13, owner — "Yes, that looks like a guided diagnostic as per (a)"].**
  The second of [Q_U52](#q-u52)'s deferred questions (§2). The owner asked what `*->`
  denotes. Answer: nothing. It names a collision first written in Q_U52 (`783be940`), not
  a designed form. `-` continues an identifier and `>` does not, so a star glued to `->`
  always lexes as `…*-` then `>`. Measured (probe `probe-1bvi-g`): 0 glued `*->` anywhere;
  in TYPE territory it is already silently not an arrow (`spec s4 Nat *-> Nat` → "has no
  arrow"; ~~`<(x : Nat)*- Nat>` → bare "Type mismatch"~~ **withdrawn**: probe g's spaced
  control failed the same way, so that row measured the defn body, not the lexing;
  isolated with bare type expressions (`probe-1bvi-o`) `<(x : Nat)*- Nat>` — glued or spaced
  — is a nameless "Unbound variable"), before 1b-vi exists.
  **DECIDED — (a)**: 1b-vi gives a glued `*->` in SELECTION territory a guided refusal
  ("`*->` reads as `*-` then `>` — put a space"), produced by the selection consumer, never
  raised at the reader (a reader raise is a whole-file abort). The type-territory messages
  predate the slice and are filed as [DEFERRED 168](../../../DEFERRED.md). Pin in 1b-vi: once the
  closer band mints `*-`, `<(x : Nat)*- Nat>` reaches Q_U37's type-territory refusal and gets
  Q_U31's "needs a SPACE" message (predicted). **Measured at 1b-vi-D-2b (probe-1bvi-aa):** the
  refusal is Q_U37's as predicted, but the MESSAGE is the star-family one 1b-v built for `*_`
  ("inside `<…>`, `*-` is a path-selection star operator, not a type operator — it has no
  type-level reading, glued or spaced…"), because that arm reads the table — the prediction of
  Q_U31's text was wrong, and the row now pins the measurement. And the selection-territory
  text: the consumer receives `a*-` then `>` for BOTH `a*-> b` and `a*- > b`, so it cannot tell
  glued from spaced, and the illustrative "put a space" is not a remedy (`x{a*- > b}` still
  fails). The decision — a guided refusal from the consumer — is unchanged; the text says what is
  true of both shapes and offers the remedy that runs (drop the `>`). A third shape, `a*->b`, is
  ONE token (`->` continues an identifier, as in `int->string`) and gets its own text. Rejected: (b) one message in every territory
  now (reaches into spec parsing the slice does not otherwise touch); (c) nothing special.

- <a id="q-u57"></a>**Q_U57 — `*-_`'s PREFIX: THE DELETED LAYER's KEY ONLY, OR THE WHOLE
  COLLAPSED PATH? [✅ DECIDED 2026-10-13, owner — "`P`'s table and rationale stand as
  reasoned, let's go with that."].** **DECIDED — P**: the prefix names everything the
  operator deleted — the collapsed ancestors' surviving output names (renames honoured,
  `^`-dissolved dropped, ordinals nameless: `^-_`'s rule) followed by the content's key,
  then the field's own key. Reason: it is the only rule under which `*-_` does what
  provenance exists for (E3), it subsumes L (dissolving ancestors with `^` yields L's answer,
  E6), and it lets the existing caret vocabulary edit the prefix. Accepted cost: I1 (`-`
  orthogonal to `_`) does not hold across the two families — in the star family `-` changes
  landing AND naming; flat names meet hyphen-join clashes more often, refused loudly by the
  strict merge. Consequences fixed by this decision: under `*-_` an ancestor rename IS
  observable, so Q_U55 keeps it legal there; with no ancestor (E1, E10) `*-_` ≡ `*_`.
  [Q_U48](#q-u48) left
  `*-_` (total collapse + provenance) open "to be decided WITH the suffix slice".
  [Q_U51](#q-u51) fixed `*_`'s prefix as *"the key its content sat under in the DELETED
  layer"*; the question is what counts as deleted once `-` has also collapsed every ancestor.
  **L (layer only)** — `*-_` = `*-`'s landing + `*_`'s prefix; **P (path)** — the prefix is
  every name the operator deleted: the collapsed ancestors' surviving output names (renames
  honoured, `^`-dissolved ones dropped, ordinals contributing nothing — exactly `^-_`'s
  rule) followed by the content's key. **N (not now)** — leave `*-_` unminted, with a guided
  "not yet". Both L and P are MEASURABLE TODAY through equivalent spellings: L ≡ `^` on
  every ancestor + `*_`; P ≡ every lifted field spelled out with `^-_` (probe
  `probe-1bvi-h`, research/P4e-1b-vi):

  | # | input under `*-_` | L | P |
  |---|---|---|---|
  | E1 | `app{database*-_}` (no ancestor) | `{:database-url … :database-pool-size 10}` | same — L = P = `*_` at depth 1 |
  | E2 | `app{server.ssl*-_}` | `{:ssl-enabled true :ssl-cert …}` | `{:server-ssl-enabled true :server-ssl-cert …}` |
  | E3 | `env{prod.db*-_ dev.db*-_}` | **ERROR** duplicate `:db-port` | `{:prod-db-url … :prod-db-port … :dev-db-url … :dev-db-port …}` |
  | E4 | `cloud{regions:{host port}*-_}` | `{:eu-host … :eu-port … :us-host … :us-port …}` | `{:regions-eu-host … :regions-us-port …}` |
  | E5 | `app{server^srv.ssl*-_}` | refused (Q_U55 — rename unobservable) | `{:srv-ssl-enabled … :srv-ssl-cert …}` |
  | E6 | `app{server^.ssl*-_}` | `{:ssl-enabled … :ssl-cert …}` | `{:ssl-enabled … :ssl-cert …}` — dissolving under P gives L's answer |
  | E7 | `t5{a.b.c*-_}` | `{:c-m {:x 1} :c-n {:y 2}}` | `{:a-b-c-m {:x 1} :a-b-c-n {:y 2}}` |
  | E8 | `vv{a.b*-_}` (vector contents) | refused (Q_U41: no fields to prefix) | refused — same |
  | E9 | `app{server.ssl*-_ server.port}` | `{:ssl-enabled … :ssl-cert … :server {:port 8080}}` | `{:server-ssl-enabled … :server-ssl-cert … :server {:port 8080}}` |
  | E10 | `env{prod dev}*-_` (closer seat — no ancestors) | `{:prod-db {…} :dev-db {…}}` | same — `*-_` ≡ `*_` with nothing to collapse |

  For contrast at E2/E3: `*_` keeps ancestry (`{:server {:ssl-enabled …}}`, `{:prod {:db-url …}
  :dev {:db-url …}}`); `*-` alone collides at E3 (duplicate `:port`). Hyphen-join is not
  injective (`{:a {:b-c 1}}` and `{:a-b {:c 2}}` both name `a-b-c`); measured (probe
  `probe-1bvi-i`), the strict merge refuses such a clash loudly (`duplicate output key
  :a-b-c`) — P's flat names meet it more often than L's, never silently.

  **THE TWO INVARIANTS CANNOT BOTH HOLD.** *I1 — `-` is orthogonal to `_`*: in the caret
  family `^_` and `^-_` share one naming rule (the full path) and differ only in landing; L
  keeps that for the star (`*_` and `*-_` share the deleted-key rule). *I2 — provenance names
  everything the operator deleted*: Q_U24's own principle ("the DELETED key is the prefix"),
  which `^-_` satisfies (it collapses the ancestors and names them) and `*_` satisfies (it
  deletes one layer and names it); P extends it to `*-_`. **TRADEOFFS.** *Purpose* (Q_U24/Q_U51:
  provenance exists to remove collisions by construction): L fails at E3, the sibling case,
  because the collapse removed exactly the keys that told the siblings apart; P succeeds.
  *Expressivity*: P ⊇ L — every L output is reachable under P by dissolving ancestors with
  `^` (E6), while P's output under L needs every field spelled out with `^-_`. *Composition*
  (Simplicity of Foundation): under P the caret vocabulary edits the prefix — `^` drops a
  segment, `^k'` renames it (E5, E6); under L, carets on ancestors do nothing, and by Q_U55
  a rename there is refused. *Ergonomics*: L's keys are shorter; P's grow by one segment per
  collapsed ancestor (shorten with `^`/`^k'`). *Uniformity*: L preserves I1; P makes the `-`
  change both landing and naming. *Monotonicity*: N is the waypoint; L and P are meanings, but
  P does not foreclose L's outputs (they stay spellable), whereas L forecloses P's (only by
  enumeration). L and P agree at E1, E8, E10, so those cases cannot decide it.

- <a id="q-u58"></a>**Q_U58 — WHERE TOTAL COLLAPSE IS REPRESENTED, AND HOW 1b-vi IS SLICED
  [✅ DECIDED 2026-10-13, owner — "Ok with lean on M. Proposed sequencing looks good to
  me."].** Posed once Q_U57 closed the last semantic question. Two facts measured first:
  provenance is branch-local (`probe-1bvi-k`: `e3{a.{b.c^-_}}` → `{:a {:b-c …}}`), so
  `*-_`'s ancestor prefix is static per branch; and the one existing parser rewrite (`^..`,
  `parser.rkt:1464`) labels a refusal by path names, never with the user's spelling
  (`probe-1bvi-j`), while star refusals print the stored steps (`typing-core.rkt:1628`).
  Options: **D** rewrite in the parser (`a.b.c*-` → `a^.b^.c*`) — cheapest, but every
  refusal label quotes a spelling the user did not write, which [Q_U54](#q-u54) decided
  against; **M** mark in the parser, act in the walkers — the parser runs Q_U55's check and
  marks each ancestor with a new `collapsed` continuation that prints as a plain key, the
  star carries the `*-` / `*-_` continuation (rendered from the table), and the walkers treat
  `collapsed` as a dissolve for PLACEMENT and as a kept key for NAMING; **W** walkers only —
  a flag threaded through both twin walkers, the shape 1b-iii needed two reverts to land.
  **DECIDED — M.** Reason: the collapse is recorded once, on the step, at the seat Q_U55's
  check already runs, so no walker infers it; labels are true by construction; placement
  reuses the dissolve arms, as C2's landings did (a prediction until 1b-vi-C runs). Cost
  accepted: one new step continuation, which brings in the totality sites the audit counted
  (F6). **The slicing was decided with it**: A pins first → B the `^-` fix (Q_U55's caret
  half, independent of the star) → C the machinery, inert → D the mint (two table rows, the
  `*->` message, the pre-mint pins flipped) → a verify round → the suite gate. Tracker:
  [§5.P4e-1b-vi](phases/CIU_6_P4e-1b-vi.md#p4e-1b-vi).

- <a id="q-u59"></a>**Q_U59 — WHERE NOTHING CAN COLLAPSE, `*-` ≡ `*` AND `*-_` ≡ `*_`
  (path position, the closer seat, depth 1) [✅ SETTLED 2026-10-14, owner — "Ok as settled,
  with medium confidence"].** Derived from Q_U57's rule rather than decided separately: in
  path position no step has an output key (measured, `probe-1bvi-m` — every caret form there
  is refused, "a field access has no output key"), so the operator deletes no ancestor level
  and P names none. **What the medium confidence is about, stated so it has an object:** a
  meaning shipped here cannot later become a DIFFERENT meaning without breaking programs. The
  monotone waypoint would have refused `*-` / `*-_` where nothing collapses ("nothing to
  collapse — write `*`"). It was not taken because the block cases E1 and E10 are the same
  situation and Q_U55 already keeps a redundant dissolve legal. **Revisit trigger:** a real
  program wanting a path-position `*-_` to name the projected path (`x.a.b*-_` → `a-b-…`). That
  would contradict P's own principle (the operator deleted nothing there), so it would be a
  new rule, not a correction. Pinned by rows X-dot±, X-wpath±, E1±, E10±.

- <a id="q-u60"></a>**Q_U60 — THE EQUIVALENCES BECOME GENERATED LAWS [✅ DECIDED 2026-10-14,
  owner — "fold it in"].** Offered at the 1b-vi-A checkpoint (VAG (c)): 31 hand examples
  state Q_U48 / Q_U57 by instance; a generator states them as laws. **Placement (recorded as
  my call within the decision):** the generator lands as 1b-vi-B's FIRST step, inside the
  stage table — its `^-` half is B's red step, its `*-` half flips at D. **Scope:** over the
  `t5` tree, every leaf position at depth 1–3 × every assignment of {kept, `^`, rename} to its
  ancestors, for `^-`, `^-k'`, `*-` and `*-_`, plus `*-` over the vector fixture `v3`. Each
  generated row's law is either an equivalence with today's spelling (dissolve every
  ancestor; the `^-_` enumeration of the lifted fields) or Q_U55's refusal.

- <a id="q-u61"></a>**Q_U61 — A PLAIN `*` UNDER AN ORDINAL HEAD: DOES A KEYLESS LANDING
  SPLICE THROUGH THE ORDINAL'S TUPLE AT EVERY DEPTH, OR NEVER? [✅ DECIDED 2026-10-14, owner —
  "Reading S looks good to me." Posed the same day — "open up what the behavior looks like …
  numerous worked examples … checked against our original design spec and intents"].**
  **DECIDED — S: splice through, at every depth.** Implemented as [1b-vi-E](phases/CIU_6_P4e-1b-vi.md#p4e-1b-vi-e). Found at 1b-vi-D-2a as an observation; measured in full
  by probe-1bvi-ac (45 lines; `t5 := {:a {:b {:c {:m {:x 1} :n {:y 2}}}}}`, `ot := @[t5's value]`,
  `ot2 := @[{:a {:b {:k 1}}} {:a {:b {:k 2}}}]`, `vhm := @[@[{:x 1}] @[{:y 2}]]`).

  **Scope of S (stated 2026-10-19, when [Q_U62](#q-u62) was decided B; UC-9).** S governs the
  ordinal branch's OWN step chain: the steps from the head to its star, and the chain may pass
  through a sub-block that the star follows (`ot{0.a^.{b}*}` → `{:c …}`, the same as
  `ot{0.a^.b*}`: probe-1bvi-ah:9/10). A star INSIDE a sub-block after the head belongs to the
  sub-block's branch. It lands in the sub-level (Q_U49), and the sub-level is the element's one
  component: `ot{0.a^.{b*}}` → `@[{:c …}]` (ae:9) vs `ot{0.a^.b*}` → `{:c …}` (ae:10). The spec
  states neither S nor this scope; the note is proposed to the owner (UC-4), not applied.

  **The rules on record.** Spec §3.3: an ordinal branch is a KEYLESS component, honestly nested
  (`ot{0.a^}` → `@[{:b …}]`, measured). [Q_U47](#q-u47): the join lands as the component the
  REMAINDER (branch − star − sₙ) would produce — keyed iff the remainder names a key; "an ordinal
  head names nothing". [Q_U49](#q-u49): a keyless landing of Map contents SPLICES into the
  enclosing level — decided AT THE ORDINAL HEAD: "Seat B keyless (ordinal head) `vhm{0.{0}*}` →
  `{:x 1}`".

  **Measured today** (key head beside ordinal head):

  | key head | → | ordinal head | → today | Q_U47 + Q_U49 predict |
  |---|---|---|---|---|
  | `t5{a*}` | `{:b …}` | `ot{0.a*}` | `{:b …}` | `{:b …}` ✓ |
  | `t5{a.b*}` | `{:a {:c …}}` | `ot{0.a.b*}` | `@[{:a {:c …}}]` | keyed remainder (`a`) inside the ordinal's component ✓ |
  | `t5{a^.b*}` | `{:c …}` | `ot{0.a^.b*}` | **`@[{:c …}]`** | remainder `0.a^` names nothing → splice → `{:c …}` ✗ |
  | `t5{a^.b^.c*}` | `{:m … :n …}` | `ot{0.a^.b^.c*}` | **`@[{:m … :n …}]`** | `{:m … :n …}` ✗ |
  | `v3{a^.b^.c*}` | `⟨[PVec [PVec Int]]⟩` | `ov3{0.a^.b^.c*}` | **`⟨⟨[PVec [PVec Int]]⟩⟩`** | ONE keyless component, `⟨[PVec [PVec Int]]⟩` ✗ |
  | — | | `ot2{0.a* 1.a*}` | refused, dup `:b` | refused ✓ (both splice `:b`) |
  | — | | `ot2{0.a^.b* 1.a^.b*}` | **`@[{:k 1} {:k 2}]`** | refused, dup `:k` ✗ |

  So today is NEITHER reading: depth 1 splices (decided), depth ≥ 2 wraps (never decided). The
  cause is mechanical — seat B's test `select-steps-yield-bare-join? rest` is true only when sₙ★
  directly follows the ordinal, so a dissolved ancestor in between routes the join into the
  ordinal's component. **Census** (tests + examples + lib, control 18 shapes found in the probe):
  9 pinned ordinal-head stars, ALL depth 1; **0** pins at depth ≥ 2.

  **The two coherent readings.**
  - **S — splice through, at every depth** (Q_U47 + Q_U49 applied literally). Changes the four ✗
    rows; flips 0 existing pins. One rule at an ordinal head for every family: a keyless landing
    escapes to the block — `*` (this), `*-` (D-2a), `^-` (P3c's pinned reading). Restores Q_U48's
    `*-` ≡ "`^` on every key ancestor, then `*`" at ordinal heads. COST: `ot2{0.a^.b* 1.a^.b*}`
    goes from a 2-tuple to a dup-key refusal — but the tuple stays spellable without the star,
    `ot2{0.a^.b^ 1.a^.b^}` → `@[{:k 1} {:k 2}]` (measured), and the refusal can say so.
  - **W — the ordinal wraps, always** (spec §3.3's honest nesting wins). Changes `ot{0.a*}` →
    `@[{:b …}]`, `vhm{0.{0}*}` → `@[{:x 1}]`, `ot2{0.a* 1.a*}` → a 2-tuple; flips all 9 pins and
    REVERSES Q_U49's decided seat-B example. COST: at an ordinal head the star then duplicates
    `^` — `ot{0.a*}` would equal `ot{0.a^}` (`@[{:b …}]`, measured) — which is Q_U49's own
    "no-op with extra steps" argument, one head kind over. And the collapse families would still
    escape (P3c), so the ordinal head would mean different things to `*` and `*-`.

  **My recommendation: S** (medium-high confidence): it is what Q_U47/Q_U49 already say, the
  wrap at depth ≥ 2 has no decision or pin behind it, it makes one rule for all three families,
  and W's honest-nesting gain is already available through `^`. The honest cost of S is the
  spec's own principle: §3.3's honest nesting yields at an ordinal head whenever a star's landing
  is keyless — as Q_U49 already made it yield at depth 1.
  **Adjacent, not part of this question:** `ot2{0.a.b*-_ 1.a.b*-_}` is refused (dup `:a-b-k`)
  because ordinals contribute nothing to a provenance prefix (Q_U57, `^-_`'s rule) — positional
  provenance would be a separate question.

  **Next free Q-label: U62.**

- <a id="q-u62"></a>**Q_U62 — AN ORDINAL HEAD, THEN A SUB-BLOCK THAT HOLDS THE STAR: DOES
  Q_U61'S PASS-THROUGH CROSS THE SUB-BLOCK? [✅ DECIDED 2026-10-19, owner — "On the language design
  front, I want to balance ergonomics, expressivity, composition, and correctness. I think I'm landing
  B still as well. Happy for a critique or pushback on these dimensions and choices, but if B is clear
  on this, then let's go with that for now." Critiqued on those four dimensions ([DC-n](#q-u62-dc)):
  B is clear. Earlier the same night: OWNER LEAN B (slight), critiqued ([UC-n](#q-u62-critique)); R
  worked out beside B at the owner's request ([R beside B](#q-u62-r)). Posed 2026-10-18 at the
  [1b-vi verify](phases/CIU_6_P4e-1b-vi.md#p4e-1b-vi-verify) (finding VS-3); opened with worked examples the same day at the
  owner's request — "walk through the design space in played out examples". Not a regression: E
  changed none of these.]**

  **DECIDED — B: braces scope a landing.** A star inside an ordinal-headed sub-block lands in the
  sub-level, and the sub-level is the element's ONE tuple component (Q_U49's "enclosing level", spec
  §3.3's slot). A star in the ordinal branch's own chain — including one written after the braces —
  passes through (S, Q_U61). Both readings stay spellable and factored: one component `x{N.{X}}`
  (≡ `x{N}:{X}`), spliced `x{N.{X'}*}` with the stars moved outside the braces (DC-1). B is what the
  code already does, so no semantics change; the follow-ups are pins, two messages and a statement of
  S's scope (UC-7…9, DC-7).

  **The question in one line.** `ot{0.a^.b*}` splices (S, [Q_U61](#q-u61)); `ot{0.a^.{b*}}` wraps
  (today). Is the wrap the rule (B), or a gap S should close (S+)?

  **Where the code decides it.** The ordinal-head arm (`typing-core.rkt:2205`; twin
  `reduction.rkt:2380`) descends transparently only when `select-steps-yield-bare-join?`
  (`syntax.rkt:1125`) sees a step-chain tail `(… sₙ ★)`. A sub-block is not one, so the `else` arm
  makes the sub-level the ordinal's one component.

  **The rules on record, quoted.** Spec §3.3: keyless branches (`^`-terminated, or ordinal) are
  "tuple components in written order"; "Honest nesting: `{p₁^ … pₙ^}` denotes an n-tuple *always* —
  including n = 1 … There is no implicit splice." Spec §3.4: `^`'s empty continuation, "mid-path:
  dissolve the level, splice content upward". [Q_U47](#q-u47): the join lands as the component
  "branch-minus-star-minus-`sₙ`" would produce — computed in the star's OWN branch.
  [Q_U49](#q-u49): Map contents "contribute KEYED COMPONENTS to the **enclosing level** — it
  splices". [Q_U61](#q-u61): at an ordinal head a star whose remainder names no key passes through.
  Spec §4's L2 (`{p:a p:b} ⟶ p:{a b}`) is stated for broadcast spines under Ruling B merges, not
  for ordinal prefixes.

  **Worked examples** — research/P4e-1b-vi/probe-1bvi-ae (74 lines at `48fe3b48`); `ae:N` = line N
  of its `.out`; `{:c …}` = `{:c {:n {:y 2}, :m {:x 1}}}` and `{:b-c …}` the same contents under
  `:b-c`. The S+ column is the step-chain spelling S already decides, measured beside it.

  *A — the shapes VS-3 found.*

  | spelling | today (= B) | S+ would give | read off |
  |---|---|---|---|
  | `ot{0.a^.{b*}}` | `@[{:c …}]` ae:9 | `{:c …}` | `ot{0.a^.b*}` ae:10 |
  | `ot{0.{a^.b*}}` | `@[{:c …}]` ae:11 | `{:c …}` | ae:10 |
  | `oo{0.{0.a^.b*}}` | `@[{:c …}]` ae:12 | `{:c …}` | `oo{0 .0.a^.b*}` ae:13 |
  | `ot2{0.a^.{b*} 1.a^.{b*}}` | `@[{:k 1} {:k 2}]` ae:14 | refused, dup `:k` | `ot2{0.a^.b* 1.a^.b*}` ae:15 |

  *B — key heads: a one-branch sub-block is transparent only where a dissolve splices it.*

  | sub-block | → | step chain | → |
  |---|---|---|---|
  | `t5{a.{b}}` | `{:a {:b {:c …}}}` ae:16 | `t5{a.b}` | the same, ae:17 |
  | `t5{a^.{b*}}` | `{:c …}` ae:18 | `t5{a^.b*}` | the same, ae:19 |
  | `v3{a^.b^.{c*}}` | `@[@[@[1 2] @[3]]]` ae:22 | `v3{a^.b^.c*}` | the same, ae:23 |
  | `t5{a^.b^.c^.{m^}}` | `@[{:x 1}]` ae:24 | `t5{a^.b^.c^.m^}` | the same, ae:25 |
  | `t5{a.b.c.{m^}}` | `{:a {:b {:c @[{:x 1}]}}}` ae:20 | `t5{a.b.c.m^}` | **`@[{:x 1}]` ae:21 — differ** |

  The rows that agree all pass through a dissolve, which splices the sub-level into a BLOCK (§3.4).
  Without one, honest nesting shows (ae:20 vs ae:21): `p.{q}` ≡ `p.q` is not a law at key heads.

  *C — an ordinal head with NO star: the sub-block is the ordinal's one component, always.*

  | spelling | → |
  |---|---|
  | `ot{0.a^}` | `@[{:b {:c …}}]` ae:26 |
  | `ot{0.{a^}}` | `@[@[{:b {:c …}}]]` ae:27 |
  | `ot{0.a^.b^}` | `@[{:c …}]` ae:28 |
  | `ot{0.a^.{b^}}` | `@[@[{:c …}]]` ae:29 |
  | `ot{0.a^.b^.c^.{m n}}` | `@[{:n {:y 2}, :m {:x 1}}]` ae:30 |
  | `ot{0.a^.b^.c^.{m^ n^}}` | `@[@[{:x 1} {:y 2}]]` ae:31 |

  An ordinal head is a SLOT: whatever its branch delivers is one component (ae:29, against the key
  head's ae:24, where the dissolve fed a block). B keeps this unconditional; S+ adds one exception, a
  sub-block whose every branch is a pass-through star.

  *D — multi-branch sub-blocks, factored and unfactored.*

  | spelling | today (= B) | S+ |
  |---|---|---|
  | `ot{0.a^.b^.c^.{m* n*}}` | `@[{:y 2, :x 1}]` ae:34 | `{:y 2, :x 1}` (ae:35) |
  | `ot{0.a^.b^.c^.m* 0.a^.b^.c^.n*}` | `{:y 2, :x 1}` ae:35 | the same |
  | `ot{0.a^.b^.c^.{m* n}}` | `@[{:n {:y 2}, :x 1}]` ae:36 | the same (not every branch passes) |
  | `ot{0.a^.b^.c^.m* 0.a^.b^.c^.n}` | refused, L4 ae:37 | the same |

  Under S+, deleting ONE star (`n*` → `n`, row 1 → row 3) moves the WHOLE sub-block from spliced
  to wrapped: where `m*`'s fields land depends on a sibling. Under B the braces alone decide. Row 4:
  factoring across an ordinal prefix is not a law today under either reading.

  *E — a realistic subject:* `fleet := @[{:meta {:id {:n 1}} :net {:tls {:port 443}} :tags @[1 2]}
  {:meta {:id {:n 2}} :net {:tls {:port 8443}} :tags @[3]}]`.

  | intent | under B | under S+ |
  |---|---|---|
  | element 0's lifted fields, spliced | `fleet{0.meta^.id* 0.net^.tls*}` → `{:n 1, :port 443}` ae:41 | that, or `fleet{0.{meta^.id* net^.tls*}}` |
  | element 0 as ONE record component | `fleet{0.{meta^.id* net^.tls*}}` → `@[{:n 1, :port 443}]` ae:40 | `fleet{0}:{meta^.id* net^.tls*}` → the same, ae:72 |
  | elements 0, 1 as records, one shape | `fleet{0.{meta^.id* net^.tls*} 1.{meta^.id* net^.tls*}}` → `@[{:n 1, :port 443} {:n 2, :port 8443}]` ae:42 | `fleet{0 1}:{meta^.id* net^.tls*}` → the same, ae:50 |
  | the same, unfactored | refused, dup `:n` ae:43 | the same |
  | records of DIFFERENT shapes | `fleet{0.{meta^.id* net^.tls*} 1.{meta^.id*}}` → `@[{:n 1, :port 443} {:n 2}]` ae:67 | **no spelling found**: the sub-blocks splice into a dup `:n`, and `{0 1}:` takes one shape |
  | one lifted field per element | `fleet{0.{meta^.id*} 1.{net^.tls*}}` → `@[{:n 1} {:port 8443}]` ae:68 | `fleet{0.meta^.id^ 1.net^.tls^}` → the same, ae:70 (S+ reads ae:68's spelling as `{:n 1, :port 8443}`, ae:69) |
  | lifted fields beside a kept key | `fleet{0.{meta^.id* tags}}` → `@[{:n 1, :tags @[1 2]}]` ae:47 | the same; unfactored is refused, L4 ae:48 |
  | every element | `fleet:{meta^.id* net^.tls*}` → `@[{:n 1, :port 443} {:n 2, :port 8443}] : [PVec {:n Int :port Int}]` ae:44 | the same |

  *F — only at a HEAD.* After a dissolved key a bare number makes no level (Q_U2), and a sub-block
  splices there today: `w{v^.0.a^.{b*}}` → `{:k 1}` ae:52, ≡ `w{v^.0.a^.b*}` ae:51;
  `w{v^.{0.a^.b*}}` → `{:k 1}` ae:53. The question exists only where an ordinal HEADS a branch.

  *G — every star family behaves alike.* `ot{0.{a.b*-}}` → `@[{:c …}]` ae:54 vs `ot{0.a.b*-}` →
  `{:c …}` ae:55 · `ot{0.a^.{b*_}}` → `@[{:b-c …}]` ae:57 vs `ot{0.a^.b*_}` → `{:b-c …}` ae:58 ·
  `ot{0.{a.b.c^-}}` → `@[{:c …}]` ae:59 vs `ot{0.a.b.c^-}` → `{:c …}` ae:60 · `ot{0.a.{b*-}}` →
  `@[{:a {:c …}}]` ae:56 (Q_U55: the collapse is branch-local and `a` survives — wraps under both).
  One decision covers `*`, `*-`, `*_`, `*-_` and `^-`.

  *H — the star OUTSIDE the braces is already decided.* `vhm{0.{0}*}` → `{:x 1}` ae:64 ([Q_U49](#q-u49)'s
  seat B) vs `vhm{0.{0}}` → `@[@[{:x 1}]]` ae:65. Under B, where the star stands is the spelling:
  outside the braces it is the ordinal branch's own star and escapes; inside, it belongs to the
  sub-level. Vector contents: `ov3{0.a^.b^.{c*}}` → `@[@[@[@[1 2] @[3]]]]` ae:61 vs the chain's
  `@[@[@[1 2] @[3]]]` ae:62.

  **The options, played out.**
  - **B — braces scope a landing (today).** A star lands in the level whose braces enclose it; an
    ordinal head is a slot holding what its branch delivers, the one exception being S's star in the
    branch's own step chain.
  - **S+ — a sub-block of pass-through stars passes through.** Changes A, D row 1, E's ae:40 / 42 /
    67 / 68, G's sub-block rows, H's ae:61 — each to its step-chain spelling.
  - **S1 — only a ONE-branch sub-block is transparent** (`0.P.{X}` ≡ `0.P.X`). Rejected-with-reason:
    `p.{q}` ≡ `p.q` holds nowhere as a law (ae:20/21, ae:27, ae:29), so S1 stacks a second exception
    (one branch, star-bearing, ordinal-headed) on top of S.
  - **F — factoring over an ordinal prefix** (`0.P.{q r}` ≡ `{0.P.q 0.P.r}`). **Refuted by
    measurement**: without stars it would split one component into two (ae:30), and with a kept key
    the factored program is legal where the unfactored is refused (ae:36 vs ae:37). Ordinals are
    positions, not keys; L2 is a keyed-merge law (spec §4, Ruling B case 3).
  - **R — refuse an ordinal-headed sub-block holding a pass-through star**, deciding later.
    Rejected-with-reason: it refuses ae:42 and ae:67, shapes nothing else spells under B.

  **Weighed adversarially.**
  - *Principles.* B is derived, not added: Q_U47 and Q_U49 place a landing by the star's own branch
    and its ENCLOSING level, which for `{b*}` is the sub-level; §3.3 then makes the sub-level the
    ordinal's one component. S+ needs a new rule — a level that is itself a landing — which no decision
    states and §3.3's "no implicit splice" argues against. B keeps placement LOCAL (D rows 1 and 3).
  - *Ergonomics.* For S+: someone who learned S as "a star escapes an ordinal" expects ae:9 to splice,
    and B answers `@[…]` silently — no refusal tells them. For B: `0.{…}` means "element 0, reshaped,
    as one component" unconditionally (C, E), which is how a reader parses braces, and the splice is
    one edit away (the unfactored chain).
  - *Expressivity.* Under B every S+ answer is spellable: S+ fires only when every sub-branch is a
    pass-through star, so the unfactored step chains always exist (ae:35, ae:41). Under S+ the B
    answers come back through `{N M}:` (ae:50, ae:72) or `^` (ae:70) EXCEPT records of different
    shapes per element (ae:67). So B ⊇ S+ — an argument over the operators, not a proof.

  ~~**Lean: S+, medium.** It is Q_U47's test applied to a remainder that contains a sub-block, and
  under a key head a one-branch sub-block after a dissolve is already transparent~~ **CORRECTED the
  same day, after probe-1bvi-ae.** That lean read Q_U47's remainder ACROSS the sub-block; Q_U47
  computes it inside the star's own branch, and Q_U49 splices into the ENCLOSING level, which is the
  sub-block. The key-head evidence (ae:18/19) is the dissolve feeding a block (§3.4); without a
  dissolve a one-branch sub-block is not transparent there either (ae:20/21).
  **Lean: B, medium-high.** It is what the rules on record already say; it keeps an ordinal-headed
  sub-block one component unconditionally (C); it keeps placement local (D); and it is the more
  expressive reading (ae:67).
  **Counter-case (S+), at its strongest:** Q_U61 chose S over honest nesting so that a star at an
  ordinal head escapes; under B that sentence needs a qualifier ("in the branch's own step chain"),
  and `ot{0.X}` ≡ `t5{X}` stays a law of step chains only. If S's intent is "escape" rather than
  "Q_U47 and Q_U49 applied literally", S+ is its natural extension.
  **Settling evidence:** whether braces should bound where a star lands (B), or only where names are
  visible (S+).

  **Side findings (SB-n), each measured:**
  - **SB-1 — the dup refusal's tuple remedy is false where an element has several branches.** On
    `fleet{0.meta^.id* 0.net^.tls* 1.meta^.id* 1.net^.tls*}` (ae:43) it says "To keep each element
    as its own tuple component, end EVERY branch here with `^`"; run, that gives a 4-tuple of
    branches, `@[{:n 1} {:port 443} {:n 2} {:port 8443}]` (ae:71). The true remedy depends on this
    decision — under B the sub-block (ae:42), under S+ `{0 1}:` (ae:50) and nothing for different
    shapes. A VF-3-class defect in `0988a4f0`; fixed after Q_U62 is decided.
  - **SB-2 — the L4 refusal at an all-ordinal level does not offer the factored sub-block**, the
    spelling that works under both readings (ae:37's input; ae:36 → `@[{:n {:y 2}, :x 1}]`).
  - **SB-3 — `vhm{0.{0*}}` reports "`*` is postfix; it attaches to the END of a segment"** (ae:66),
    though the star does end segment `0`. ~~[Q_U46](#q-u46)'s gap 1 made a star after an ordinal a
    GUIDED error naming the reason (an ordinal makes no layer); this spelling misses it.~~ **Withdrawn**
    (2026-10-19, measured at the 1b-vi close): Q_U46's guided refusal was reached by ONE spelling,
    the bracket `y{a[0]*}`. Every other spelling missed it: `vhm{0*}` and `vhm{0.{0*}}` said
    "`*` is postfix", `y{a.0*}` said "stray `.`", and `vhm.0*` / `vv:0*` / `y.a.0*` said a bare
    "Unbound variable". The block band is fixed at [the close](phases/CIU_6_P4e-1b-vi.md#p4e-1b-vi-close) (`a9788c0a`); the
    reader seats go with P4e-2. Pre-existing.
    Filed with SB-4 as [DEFERRED 185](../../../DEFERRED.md) (2026-10-19).

  <a id="q-u62-critique"></a>**Critique of the joint lean B (UC-n), 2026-10-19** — the owner's slight
  lean agrees with mine, so the stance is now joint and gets its own critique (standing process).
  - **UC-1 (for B, measured) — B has an UNCONDITIONAL compositional law.**
    `x{0.P.{X}}` ≡ the element's key-head reading `y{P.{X}}`, WRAPPED (value in `@[…]`, type in `⟨…⟩`).
    research/P4e-1b-vi/probe-1bvi-af (generated, 102 pairs at `0e562181`): six families (`*`, `*-`,
    `*_`, `*-_`, `^-`, `^-_`) × 15 leaf positions and kept/dissolved ancestor assignments over
    `t5`/`ot`, plus vector contents over `v3`/`ov3` — the law holds on **98 / 98** comparable pairs;
    the other 4 are refused identically on both sides (`*_` over vector contents). Negative control:
    for a STEP CHAIN the wrapped law fails where S passes (`ot{0.a^.b*}` → `{:c …}`, ae:10), so the
    comparison discriminates. Under S+ (derived from S's table, not measured) the same 98 split in
    two: the 26 whose `P` dissolves every ancestor (or is empty) would read UNwrapped, the other 72
    wrapped — a two-case law whose case depends on `P` and on `X`'s family together.
  - **UC-2 (for B, the spec's stated rationale — argument, not measurement).** Spec §3.3 grounds
    honest nesting in "uniformity, the fusion law, and forward-compatibility with first-class
    selectors, where branch count becomes runtime-known"; §7.5 (OUTLOOK, load-bearing) repeats it.
    Under B, `0.{S}` needs only `S`'s RESULT (a record or a tuple, then wrapped): compositional in the
    selector. Under S+ it needs an intensional property of `S` — whether every branch passes its
    landing through — so a first-class selector's type would have to carry that property for the
    parent level's sort to stay static. Not impossible; a cost S+ adds to §7.5.
  - **UC-3 (against B) — the silent surprise.** Someone who learned S as "a star escapes an ordinal"
    writes `ot{0.a^.{b*}}` and gets `@[{:c …}]`; B has nothing to refuse, so no message helps. A
    warning on a legal program is not proposed. Mitigation: the acceptance file shows `0.{…}` as
    "element N as one component" beside the escaping spellings.
  - **UC-4 (against B) — statement debt.** Q_U61's S has to carry its scope ("a star in the ordinal
    branch's OWN step chain"), and the spec states neither S nor its scope yet — a departure to record
    (a proposal; the spec is a guide reviewed per slice).
  - **UC-5 — the monotone-migration hedge, R.** A refusal shipped today can become a meaning later
    without breaking a program; a meaning cannot. With the owner's confidence "slight", that argues
    for R as a waypoint. Weighed: R refuses ae:42 and ae:67 now — the per-element records, and
    SB-1's remedy under B with them — while the risk it hedges (wanting S+ later) has no demand
    evidence (census 0 under both readings). R fits uncertainty about the DIRECTION; B fits
    uncertainty about the MARGIN.
  - **UC-6 (my own claims, re-checked).** "B ⊇ S+": S+ fires only when every sub-branch passes, so
    the unfactored step chains always exist, recursively for nested sub-blocks — still an argument
    over the operators. "No S+ spelling for ae:67": searched `{N M}:` (one shape only), `^` (one
    field per element), a key-naming branch (adds a key) and a block over `{0 1}`'s tuple (the same
    question one level down); none inside the selection algebra. "B is what the rules say": Q_U49's
    "enclosing level" re-read, quoted above.
  **My lean after the critique: B, firmed from medium-high to high** — UC-1 turns "B is coherent" into
  a measured unconditional law, and UC-2 is the spec's own load-bearing reason; UC-3 and UC-4 are
  documentation costs, not incoherence. B over R, because R's cost is concrete and its hedge has no
  demand behind it.
  <a id="q-u62-r"></a>**R worked out beside B** (owner, 2026-10-19 — "I'd have to see R worked out
  alongside B in multiple, clear, worked examples to make a weigh-in on either. I don't have an
  intuition for what R is, otherwise."). research/P4e-1b-vi/probe-1bvi-ag (80 lines at `4765f8a1`);
  `ag:N` = its line N.

  **What R is.** R refuses exactly the shapes where B and S+ disagree — an ordinal head over a sub-block
  whose every branch is a star that would pass through — and leaves everything else as it is today
  (B and S+ agree there). R is not implemented, so its refusal is design; what IS measured is what a
  user writes instead, and both recipes are spellings that run today:
  - **one component** (B's meaning): the broadcast over a one-element ordinal block, `x{N}:{P.{X}}`;
  - **spliced** (S+'s meaning): the unfactored step chains, which S already decides.

  So the three options differ only in what `x{N.{X}}` is a synonym for, on these shapes: under **B** it
  means `x{N}:{X}`; under **S+** it means the unfactored chains; under **R** it means nothing yet.

  **The shapes R refuses, side by side.**

  | program | B gives | under R | B's meaning, spelled under R | S+'s meaning, spelled under R |
  |---|---|---|---|---|
  | `ot{0.a^.{b*}}` | `@[{:c …}]` ae:9 | refused | `ot{0}:{a^.{b*}}` → `@[{:c …}]` ag:7 | `ot{0.a^.b*}` → `{:c …}` ae:10 |
  | `oo{0.{0.a^.b*}}` | `@[{:c …}]` ae:12 | refused | `oo{0}:{0.a^.b*}` → `@[{:c …}]` ag:9 | `oo{0 .0.a^.b*}` → `{:c …}` ae:13 |
  | `ot2{0.a^.{b*} 1.a^.{b*}}` | `@[{:k 1} {:k 2}]` ae:14 | refused | `ot2{0 1}:{a^.b*}` → `@[{:k 1} {:k 2}]` ag:10 | `ot2{0.a^.b* 1.a^.b*}` → refused, dup `:k` ae:15 |
  | `ot{0.a^.b^.c^.{m* n*}}` | `@[{:y 2, :x 1}]` ae:34 | refused | `ot{0}:{a^.b^.c^.{m* n*}}` → `@[{:y 2, :x 1}]` ag:12 | `ot{0.a^.b^.c^.m* 0.a^.b^.c^.n*}` → `{:y 2, :x 1}` ae:35 |
  | `fleet{0.{meta^.id* net^.tls*}}` | `@[{:n 1, :port 443}]` ae:40 | refused | `fleet{0}:{meta^.id* net^.tls*}` → `@[{:n 1, :port 443}]` ag:13 | `fleet{0.meta^.id* 0.net^.tls*}` → `{:n 1, :port 443}` ae:41 |
  | `fleet{0.{meta^.id* net^.tls*} 1.{meta^.id* net^.tls*}}` | `@[{:n 1, :port 443} {:n 2, :port 8443}]` ae:42 | refused | `fleet{0 1}:{meta^.id* net^.tls*}` → `@[{:n 1, :port 443} {:n 2, :port 8443}]` ag:14 | the unfactored chains → refused, dup `:n` ae:43 |
  | `fleet{0.{meta^.id*} 1.{net^.tls*}}` | `@[{:n 1} {:port 8443}]` ae:68 | refused | `fleet{0.meta^.id^ 1.net^.tls^}` → `@[{:n 1} {:port 8443}]` ag:16 | `fleet{0.meta^.id* 1.net^.tls*}` → `{:n 1, :port 8443}` ae:69 |
  | `fleet{0.{meta^.id* net^.tls*} 1.{meta^.id*}}` | `@[{:n 1, :port 443} {:n 2}]` ae:67 | refused | **no spelling**: `{0 1}:` takes one shape (ag:21 gives both elements a port) | refused, dup `:n` ag:22 |
  | `ot{0.{a.b*-}}` | `@[{:c …}]` ae:54 | refused | `ot{0}:{a.b*-}` → `@[{:c …}]` ag:17 | `ot{0.a.b*-}` → `{:c …}` ae:55 |
  | `ot{0.a^.{b*_}}` | `@[{:b-c …}]` ae:57 | refused | `ot{0}:{a^.b*_}` → `@[{:b-c …}]` ag:18 | `ot{0.a^.b*_}` → `{:b-c …}` ae:58 |
  | `ov3{0.a^.b^.{c*}}` | `@[@[@[@[1 2] @[3]]]]` ae:61 | refused | `ov3{0}:{a^.b^.c*}` → `@[@[@[@[1 2] @[3]]]]` ag:20 | `ov3{0.a^.b^.c*}` → `@[@[@[1 2] @[3]]]` ae:62 |

  **Over R's WHOLE refused population in probe-1bvi-af's grid** (26 shapes — `*` 5, `*-` 5, `*_` 4,
  `*-_` 4, `^-` 4, `^-_` 4): the one-component recipe reproduces B's value **26 / 26**, the spliced recipe
  reproduces S+'s reading (the unwrapped key-head value) **26 / 26**, and the two differ on all 26.

  **What R leaves alone** (the same under B, S+ and R): `ot{0.a^.b^.c^.{m* n}}` → `@[{:n {:y 2}, :x 1}]`
  ag:23 · `fleet{0.{meta^.id* tags}}` → `@[{:n 1, :tags @[1 2]}]` ag:24 · `ot{0.a.{b*}}` →
  `@[{:a {:c …}}]` ag:25 · `ot{0.a^.b^.c^.{m n}}` → `@[{:n {:y 2}, :m {:x 1}}]` ag:26 · `vhm{0.{0}*}` →
  `{:x 1}` ag:27 · every step chain (`ot{0.a^.b*}` → `{:c …}`, ae:10).

  **R's message — PROPOSED text, not implemented**, rendered from the user's branch by the one branch
  printer (as VF-1's broadcast refusal is):
  > `ot{0.a^.{b*}}` — every branch of the sub-block after the ordinal is a star whose fields could pass
  > through it, and whether they stay inside element 0 or pass through the ordinal to this level is not
  > decided yet (Q_U62). For element 0 as one component, write `ot{0}:{a^.{b*}}`; for its fields at this
  > level, `ot{0.a^.b*}`.

  It must offer only the recipe that works: on the two-element row the spliced chains collide (ae:43), and
  on the different-shapes row neither recipe exists, so the message can only say to select each element
  in its own block (`fleet{0}:{meta^.id* net^.tls*}`, ag:13).

  **Changing course later.**

  | starting from | later decision | programs written in the meantime |
  |---|---|---|
  | R | B or S+ | nothing breaks: only refused programs gain a meaning |
  | B | S+ | the refused-under-R shapes change: wrapped → spliced (a type change, `⟨{…}⟩` → `{…}`, so consumers fail type-checking rather than run wrong); tuples → duplicate-key refusals (ae:14, ae:42) |
  | S+ | B | the reverse: spliced → wrapped, and the duplicate-key refusals become tuples |

  **R, weighed against B.**
  - *What R buys:* neither reading is foreclosed, so the later decision breaks nothing (the monotone-
    migration rule).
  - *What R costs:* (1) records of different shapes per element (ae:67) have no spelling until the
    decision; (2) the natural spelling `x{N.{…}}` is an error, and the user must learn `x{N}:{…}`, a
    broadcast over a one-element block; (3) its trigger reads every sub-branch — `{m* n*}` refused,
    `{m* n}` accepted (ag:23); (4) its message needs per-shape care (above); (5) Q_U62 stays open, owing
    a DEFERRED entry and a trigger to decide it (first-class selectors, §7.5, or first demand).
  - *What it shows about B:* on every shape R refuses, B's `x{N.{X}}` is exactly `x{N}:{X}` (measured
    26 / 26 and on every hand row). B adds over R only the different-shapes records (ae:67) and the
    shorter spelling; S+ adds over R only the shorter spelling of the unfactored chains.
  - *Rejected variant R2* — refuse every ordinal-headed sub-block holding any star: it would also refuse
    ag:23 and ag:24, where B and S+ agree, so it forecloses nothing more and costs more.

  <a id="q-u62-dc"></a>**Critique of the decision on the owner's four dimensions (DC-n), 2026-10-19** —
  research/P4e-1b-vi/probe-1bvi-ah (25 lines at `b511593d`); `ah:N` = its line N.
  - **DC-1 — ergonomics and expressivity, for B (a prediction, confirmed).** Under B the SPLICED reading
    is spelled factored too: keep the keys inside the braces and put one star after them.
    `fleet{0.{meta^.id net^.tls}*}` → `{:n 1, :port 443}` ah:4, ≡ the unfactored
    `fleet{0.meta^.id* 0.net^.tls*}` → `{:n 1, :port 443}` ah:5 · `ot{0.a^.b^.c^.{m n}*}` → `{:y 2, :x 1}`
    ah:7 ≡ ah:8 · `ot{0.a^.{b}*}` → `{:c …}` ah:9 ≡ `ot{0.a^.b*}` ah:10. So B's whole rule for a user is
    one sentence — *a star inside the braces lands in the element; a star after the braces escapes it* —
    and the verbosity objection (repeating `0.` for each subtree) dissolves. Limit: the outer star needs
    container contents; over lifted scalars it is a permanent guided refusal
    (`fleet{0.{meta^.id* net^.tls*}*}`, ah:12).
  - **DC-2 — composition, against B (measured).** [Q_U45](#q-u45)'s L★, `x{p₁* … pₙ*} ≡ x{p₁ … pₙ}*` for
    Map contents (the law [Q_U49](#q-u49) cites), does not survive an ordinal head's braces under B.
    It holds at key heads (`t5{a.b.c.{m* n*}}` ≡ `t5{a.b.c.{m n}*}`, ah:17/18; dissolved, ah:19/20) and at
    an ordinal head with a kept key (`@[{:a {:b {:c {:y 2, :x 1}}}}]` both sides, ah:21/22); it FAILS
    exactly where B and S+ disagree — `ot{0.a^.b^.c^.{m* n*}}` → `@[{:y 2, :x 1}]` ah:23 vs
    `ot{0.a^.b^.c^.{m n}*}` → `{:y 2, :x 1}` ah:24. Under S+ it would hold. This is DC-1's other face: at an
    ordinal head the star's position relative to the braces carries meaning, which is what lets both
    readings be written, and what a star-moving rewrite must respect. Consequence: L★ as a REWRITE (P5's
    normal forms; messages printing a factored spelling) needs a side condition — not across an
    ordinal head's braces when every ancestor between them dissolves. Filed as an addendum to
    [DEFERRED 115](../../../DEFERRED.md) (L2's star side condition; P5 owns both; main `e751736c`).
  - **DC-3 — composition, for B (measured instances).** B adds an equivalence between ordinal sub-blocks and
    broadcast, `x{N.{X} M.{X}}` ≡ `x{N M}:{X}`: `@[{:k 1} {:k 2}]` both, ah:13/14; `@[{:n 1} {:n 2}]`
    both, ah:15/16; and 26 / 26 single-element shapes (probe-1bvi-ag). Under S+ it fails. It gives P5's
    L2 normal form ("ω steps outermost-shared", spec §4) something to choose: the broadcast form when the
    sub-blocks agree, the sub-blocks when they differ (ae:67). PENDING for P5 as **DC-7** (non-blocking).
  - **DC-4 — correctness.** B is today's tested behaviour, and its law (UC-1) is a test oracle; but no pin
    holds it, so a later edit could flip it unnoticed — UC-7 pins it now. A later CHANGE of decision would
    surface as a type change (`⟨{…}⟩` ↔ `{…}`), so consumers fail type-checking rather than run wrong.
    Exactness: B's advantage is not implementation risk — S+ would be one widened shared predicate
    (`select-steps-yield-bare-join?`, `syntax.rkt:1125`, read by both twins) — it is that B needs no new
    rule at all. Open correctness debts: SB-1's false remedy (UC-8) and the comment at
    `typing-core.rkt:2192` that calls this undecided.
  - **DC-5 — ergonomics, against B (residual).** At an ordinal head braces are not mere grouping: adding
    them changes the result (ae:9 vs ae:10), while after a dissolve at a key head they do not (ae:18/19).
    Types surface it at the use site; SB-1's corrected message and an acceptance example teach the rule.
  - **DC-6 — "for now".** Starting from B, a later change breaks programs written meanwhile (the
    migration table above), at the type level. Acceptable with zero uses today. The natural moment to
    revisit is P5's L★ side condition (DC-2) or first-class selectors (§7.5, where UC-2 argues for B).
  **Is B clear on the four dimensions?** Yes. Expressivity: B is the strongest of the three — every S+
  answer is spellable, factored (DC-1), and the different-shapes records exist only under B (ae:67).
  Composition is a trade with a winner: B keeps an unconditional law (UC-1) and gains one (DC-3) at the
  price of L★'s side condition at one shape (DC-2), where S+ keeps L★ but splits UC-1 in two cases.
  Correctness favours B mildly (no new rule; an oracle). Ergonomics: B's rule is one local sentence
  (DC-1); its cost is DC-5.

  **Left open by B (non-blocking; done after the decision — UC-7, UC-8 and UC-9 at [1b-vi-F](phases/CIU_6_P4e-1b-vi.md#p4e-1b-vi-f)):**
  - **UC-7** pin B as generated laws — UC-1's grid as `wrapped` rows in the stage table;
  - **UC-8** SB-1 and SB-2 under B — the remedy "group each element's branches in one sub-block after
    its ordinal" (ae:42, ae:67, ae:36), offered only where every branch is ordinal-headed and the
    grouping is spellable (a rest that already opens with a sub-block cannot be grouped — to measure);
  - **UC-9** restate S's scope in [Q_U61](#q-u61)'s entry and propose the spec note (UC-4).
  - **DC-7** (P5, non-blocking) — the normal form between `x{N.{X} M.{X}}` and `x{N M}:{X}` (DC-3), and
    L★'s side condition at an ordinal head (DC-2, DEFERRED 115).

- <a id="q-u63"></a>**Q_U63 — DOES RAVEL `.*` ADD EXPRESSIVITY, OR ONLY NOTATION? [✅ DECIDED J
  2026-11-02, owner — "OK to take the leans in a batch. Let's proceed accordingly." — after the lean
  of 2026-10-19 ("I'm liking J. It reads well to me."), critiqued ([JC-n](#q-u63-jc)). The seven
  sub-decisions JD-1…7 are decided at their leans in the same answer. Opened 2026-10-19 at the
  owner's request: "On 2. I want to open up whether this syntax/spelling offers any true increase in
  expressivity?"]**

  **DECIDED — J: ravel is `x:*`, a broadcast of the identity, then the join.** It is built from `:`
  and `*` under [Q_U40](#q-u40)'s rule. The parser builds `(@bcast ε)` with ε an explicit identity
  step, so the broadcast's one-step invariant (`syntax.rkt:891`) holds. Its meaning on every
  container is the broadcast's followed by the existing join (JC-2): `m:*` joins a Map's values,
  `x.N:*` flattens element N, `x:*:*` is rank-3 full ravel, and `x:*_` carries provenance. It
  supersedes [Q_U26](#q-u26)'s SPELLING (`.*` is not reclaimed); Q_U26's meaning stands.
  **Implementation: P4e-2** (re-scoped below; the 1b-vi close comes first). It covers the `:*`
  production, ε, the JD-2…4 messages and the laws listed under the critique. **Spec departures,
  proposed to the owner, not applied:** §2.1's `.*` row (already superseded as row-splat by Q_U23)
  becomes "no operator; a guided refusal naming `x:*`", and §3.5 gains join at the focus, `x:*`.

  **The question as posed.** P4e-2's premise is [Q_U26](#q-u26) (decided 2026-08-08): "`values.*` →
  `@[1 2 3 4 5 6 7 8 9]`; APL's `,`. Whole-container join, the sibling of Q_U23's per-step `*`." This
  question asks whether that operator lets a program say something it cannot say today. Probes:
  research/P4e-2/probe-p4e2-a (24 lines) and -b (12 lines), at `55b7df16`; `a:N` / `b:N` = their lines.

  **The rules on record, quoted.** [Q_U40](#q-u40): "`*` deletes the container layer contributed by
  the preceding step, joining its contents into the enclosing level." Spec §3.5: "The algebra is a
  functor language that graduates to a monad only through this explicit act."

  **The theory that makes the question checkable.** In monad terms `:` is fmap, and a star after a step
  `s` is join after fmap `s`, i.e. bind (concatMap): `rowsv:tags*` → `@[1 2 3]` (a:7). Q_U26's `.*` is
  JOIN alone, at the focus, with no step before it. The monad law join = bind id says `.*` can be
  written in the path language exactly when an identity step ε exists (`x.*` ≡ `x:ε*`), or when some
  fixed spelling stands in for ε. "True increase" is Felleisen's (1991, *On the Expressive Power of
  Programming Languages*, SCP 17): a construct adds expressive power iff it is not macro-expressible,
  i.e. no translation φ(F(e)) = C[φ(e)] with C a FIXED context.

  **Measured (probe-p4e2-a / -b):**

  | intent | spelling today | result | runtime lengths? |
  |---|---|---|---|
  | join after a step (bind) | `rowsv:tags*` | `@[1 2 3]` (a:7) | yes |
  | ravel through a named step | `w.v*` / `w{v*}` | `v` unchanged (a:8) / a 1-tuple of `v` (a:9): a key step's layer holds ONE item, so its join is the identity | — |
  | ravel, positions written out | `values{0 1 2}*` | `@[1 2 3 4 5 6 7 8 9]` (a:11) | no — needs the outer length |
  | too few positions | `values{0 1}*` | `@[1 2 3 4 5 6]` (a:14), row 2 silently absent | |
  | too many positions | `values{0 1 2 3}*` | ERROR panic (a:15) | |
  | per element, under ω | `vv:{0 1}*` | refused, "not implemented yet … no static type carries" (a:12) | |
  | flatten element 0 | `t3{0*}` | refused: Q_U46's reserved gap (a:16); written out, `t3{0.{0 1}*}` → `@[@[1 2 3]]` (a:17) | no |
  | full ravel, rank 3 | `t3{0 1}*{0 1 2}*` | `@[1 2 3 4]` (a:20) | no |
  | a Map's values, unnamed | `m.*` | Unbound variable (a:21); `m{a b}*` → `{:y 2, :x 1}` (a:10) needs every key | |
  | Q_U26's ravel itself | `values.*` | Unbound variable (a:6) | |
  | an identity step | `values:*`, `values{}*`, `values:{}*` | unbound / empty-selection refusals (b:6–8): none exists | |
  | outside the path language | `[prologos::data::list::concat '['[1 2] '[3]]]` | `'[1 2 3]` (b:10) | yes |

  **The answer, by level** (an argument over the measured operator set, not a theorem):
  1. *In the whole language: no increase.* `e.*` ⟶ `[concat e]` is a fixed context (Lists, b:10). For
     PVec the library has only a binary `concat` (`core/collections.prologos:43`); a fold or a library
     flatten closes that. A library gap, not a language one. Measured for List only.
  2. *In the selector language: yes, by exactly one primitive.* Without ε, every ravel writes out
     positions, a context that depends on the data's runtime length. So it is not macro-expressible
     there, and the increase is join-at-the-focus = bind with the identity step. It matters as far as
     selectors are first-class values (spec §7.5, "[OUTLOOK, load-bearing]"): a stored selector
     cannot call `concat`.
  3. *One gap, three faces.* The same primitive is missing at (a) a subject of runtime length
     (`values`); (b) an element reached by an ordinal (`t3.0`: [Q_U46](#q-u46)'s reserved gap, whose
     refusal says "select the element first and flatten separately", a remedy no selector can spell
     today); (c) a Map's values without naming its keys (`m`).

  **Options, for deliberation:**
  - **K — `.*` is join at the focus, one level** (Q_U26 as decided). Ravel of rank r is r−1 `.*`s.
    Closes (a)–(c). Costs: Q_U26's accepted reader-grouping fix; and one glyph, two meanings — in
    `selection` declarations `:address.*` is a synonym of a bare `:address` ("unrestricted",
    `typing-core.rkt:2639`; `tests/test-selection-paths.rkt:58`), i.e. an identity, not a join (RV-3).
  - **E — an identity step ε** (spelling open), the unit of path composition. Ravel is derived
    (`x:ε*`), and so are a Map's values (`m:ε`) and element-flatten (`t3.0:ε*`). The functor law
    `x:ε ≡ x` becomes a checkable identity. `.*` becomes unnecessary, or sugar for `:ε*`. Predicted
    values equal the written-out rows (a:11, a:20, a:10); not measured, since ε does not exist.
  - **A — APL's full ravel in one `.*`** (rank → 1; APL's `,` is full, and Q_U26 cites it). Type-directed
    recursion: one spelling at every rank, which matters for a first-class selector applied at several
    ranks. Its meaning on Maps and heterogeneous tuples is undecided. Not a join, so it does not
    compose with `*`'s laws.
  - **N — no path operator.** A library `flatten` / `concat` only; the smallest path language. (a)–(c)
    stay unspellable inside a selector.
  Whichever option: one level (μ) or full (APL)? Q_U26's example (rank 2) does not tell them apart.

  ~~**My lean: E over K, medium.**~~ **Superseded** by the worked-out lean below (option J, which this pass
  found: E's identity kept in the IR without a surface token). The gap is the missing UNIT, and join is already the star's job. E adds
  the identity element to the path algebra and derives ravel, a Map's values, and element-flatten
  from operators that exist. K adds a second join beside `*` that differs only in where the layer
  comes from. **Counter-case:** ε does nothing alone, and users will ask what `x.ε` is for; `.*` reads
  as one idea, and K was already decided. **What would settle it:** whether selectors will be stored
  and composed as values (§7.5), and whether faces (b) and (c) are wanted. No census can show that;
  it is the owner's call.

  <a id="q-u63-worked"></a>**Worked out (2026-10-19, second pass — the owner: "I think it would do us well to
  work out these options in worked examples, and consider their design tradeoffs against our design
  principles and expressivity. I'm still not seeing a clear choice among what has been considered.")**
  Probe research/P4e-2/probe-p4e2-c (29 lines at `cee02607`; `c:N` = its line N). None of the options
  exists, so each value below is the value of TODAY's nearest spelling, which the option must equal;
  the probe measures that spelling.

  **A fifth option, found by writing the spellings out — J: `x:*`, "broadcast the identity, then join".**
  Under Q_U40's rule the star deletes the layer the preceding step made. A broadcast over the identity
  makes exactly the layer whose contents are the elements, so `values:*` IS join, built from `:` and `*`
  as users learn them from `rows:tags*` (spec §3.5's own example is `build.modules:diags*:msg`). The
  parser builds `(@bcast ε)` with ε an explicit identity STEP in the IR, so the invariant at
  `syntax.rkt:891` ("a broadcast-of-nothing is UNCONSTRUCTIBLE") stays true. J is E with the identity kept
  in the algebra and given no surface token.

  **The intents, under every option** (fixtures as in the probe; `{:c …}`-style abbreviations not used):

  | # | intent | today's nearest spelling → measured | K `.*` | E `:ε*` | J `:*` | A full ravel | N library |
  |---|---|---|---|---|---|---|---|
  | 1 | flatten a matrix of ANY length | `values{0 1 2}*` → `@[1 2 3 4 5 6 7 8 9]` (c:9); the same selector on `vv` → panic (c:10) | `values.*` | `values:ε*` | `values:*` | `values.*` | `[flatten values]`: no PVec flatten exists |
  | 2 | rank 3, one level | `t3{0 1}*` → `@[@[1 2] @[3] @[4]]` (c:12) | `t3.*` | `t3:ε*` | `t3:*` | **not expressible**: A always goes to rank 1 | `[flatten t3]` |
  | 3 | rank 3, full | `t3{0 1}*{0 1 2}*` → `@[1 2 3 4]` (c:13) | `t3.*.*` | `t3:ε*:ε*` | `t3:*:*` | `t3.*` | `[flatten [flatten t3]]` |
  | 4 | flatten element 0 | `t3.0{0 1}*` → `@[1 2 3]` (c:14) | `t3.0.*` | `t3.0:ε*` | `t3.0:*` | `t3.0.*` | `[flatten t3.0]` |
  | 5 | a Map's values, keywise | `m{a b}*` → `{:y 2, :x 1}` (c:16) | `m.*` | `m:ε*` | `m:*` | undefined on Maps | no Map join exists |
  | 6 | …with provenance | `m{a b}*_` → `{:a-x 1, :b-y 2}` (c:17) | `m.*_` (a new family member) | `m:ε*_` | `m:*_` (the family, free) | undefined | none |
  | 7 | a Map of vectors | `mv{a b}*` → `@[1 2 3]` (c:18) | `mv.*` | `mv:ε*` | `mv:*` | `mv.*` | none |
  | 8 | records, keywise; the collision | `rr{0 1}*` → `{:a 1, :b 2}` (c:19); `rc{0 1}*` refused, "would silently drop one" (c:20) | `rr.*` | `rr:ε*` | `rr:*` | `rr.*` | none |
  | 9 | flatten, then project | `groups{0 1}*:name` → `@["a" "b" "c"]` (c:21) | `groups.*:name` | `groups:ε*:name` | `groups:*:name` | `groups.*:name` | a function result, then a path |
  | 10 | (bind, which exists) | `teams:members*:name` → `@["a" "b" "c"]` (c:22) | same | same | same | same | same |
  | 11 | in BLOCK position | path `tw.teams:m*` → `@[1 2 3]` (c:28); block `tw{teams:m*}` refused (c:26): DEFERRED 167's class | `x{a.*}`: a new block arm | `x{a:ε*}`: waits on 167 | `x{a:*}`: waits on 167 | new arm | n/a |

  **Laws each option makes checkable.** Bind = map then join (the monad law `m >>= f = join (fmap f m)`):
  `x:k*` ≡ `x:k:*` under J, ≡ `x:k.*` under K, ≡ `x:k:ε*` under E; on known lengths `groups:*:name` ≡
  `groups{0 1}*:name` (c:21). Functor identity `x:ε ≡ x` is a surface law under E only; under J it holds
  in the IR. A has no join law (it is not a join).

  **Weighed against the principles, as `DESIGN_PRINCIPLES.org` words them:**

  | principle (quoted) | K `.*` | E `:ε*` | J `:*` | A full | N |
  |---|---|---|---|---|---|
  | Simplicity of Foundation — "Complexity is built through composition, not special cases" | ✗ `.` + `*` does not compose: under Q_U40 a `.` makes no layer, so `.*` is its own rule | ✓ one new step kind; ravel composed | ✓ no new token; ravel composed from `:` and `*`; one grammar production (`:` then a star) | ✗ its own rule plus a type-level rank recursion | ✓ nothing added |
  | Correct by Construction / Correctness Through Types | ~ a new typing rule (it can reuse the join) | ✓ reuses Q_U40's join and Q_U38's collision refusal (c:20) unchanged | ✓ same as E; `(@bcast ε)` keeps the one-step invariant | ✗ needs `Flatten : Type → Type`; tuples and Maps unruled | ✓ |
  | First-Class by Default (§7.5 selectors) | ~ a step, but not decomposable | ✓ ε is the unit of path composition | ✓ ε is the unit, in the algebra (PF's `data Step` gains one kind) | ✓ the one rank-polymorphic selector | ✗ a stored selector cannot flatten |
  | Progressive Disclosure; Pragmatism with Rigor — "not Greek letters" | ✗ `.*` reads as a wildcard, and IS one in `selection` declarations (RV-3) | ✗ a visible token that does nothing alone | ✓ "each, joined", the reading of `rows:tags*` without a field | ✓ one familiar word, "flatten everything" | ✓ a named function |
  | The Most Generalizable Interface | ✓ any container the join takes | ✓ | ✓ | ~ vectors only, until Maps/tuples are ruled | ~ one function per collection, unless a generic `join` |
  | expressivity in selectors (Felleisen) | closes faces (a)–(c) | closes (a)–(c) | closes (a)–(c) | closes (a)–(c) at rank 1 only; loses one-level ravel (row 2) | none |
  | migration and record | Q_U26 as decided; claims the glyph retired as row-splat (spec §2.1) | revises Q_U26 | revises Q_U26 | revises Q_U26 | revises Q_U26; the monotone waypoint |

  **Hazards found while writing the spellings.**
  - **K:** one character apart, opposite meanings. `x{a*}` splats `a`'s fields into the block; `x{a.*}`
    would join `a`'s values and keep them under `:a`. Likewise `w.v*` is the identity (a:8) while
    `w.v.*` would ravel.
  - **J:** `w.v*` vs `w.v:*` is the same distance. But the `:` is the visible "for each" users already
    read in `rows:tags*`, and the meaning follows from it.

  **What J settles elsewhere.** Q_U46's reserved gap keeps its refusal (`t3{0*}`), and its remedy text,
  which DEFERRED 185 left open, becomes `t3.0:*`. P4e-2's `.*` reclamation is not needed. Its
  retirement inventory still runs, and the `selection`-declaration wildcard (RV-3) keeps its meaning
  with no clash.

  **Lean, revised: J, medium-high** (it supersedes "E over K").
  - *Why:*
    - the only option built entirely from operators and rules already on record;
    - no new surface token;
    - the whole star family follows for free (`m:*_`, row 6);
    - first-class selectors get their unit;
    - the glyph collisions of K disappear.
  - *Counter-case:*
    1. J revises an owner decision (Q_U26, K).
    2. `:*` is a glued form readers have not seen; they must learn that a `:` can stand with no field.
    3. In block position J waits on DEFERRED 167 (row 11).
    4. A's one-word "flatten everything" is the most familiar surface for newcomers. It is also the
       only rank-polymorphic selector, if first-class selectors are applied at several ranks.
  - *What would settle it:* whether first-class selectors are expected to be rank-polymorphic. If yes,
    A earns a place beside J (as a library selector, not as the join). Also, whether keeping Q_U26's
    spelling outweighs K's two hazards.

  <a id="q-u63-jc"></a>**Critique of the joint lean J (JC-n), and the sub-decisions inside it (JD-n), 2026-10-19.**
  Probe research/P4e-2/probe-p4e2-d (16 lines at `21ac833a`; `d:N` = its line N).
  - **JC-1 — for (ergonomics, the owner's reason).** `values:*` reads "each, joined": the reading of
    `rows:tags*` without the field, and of spec §3.5's normative `build.modules:diags*:msg`.
  - **JC-2 — for (composition; measured substrate).** J's meaning on every container is the broadcast's
    meaning followed by the existing join, so J needs no per-container rule:
    - over a Map the broadcast layer is KEYED (`mh:x` → `{:a 1, :b 2}`, d:7), so `m:*` joins values
      exactly as `m{a b}*` does (c:16, c:18);
    - over a tuple it works per position (`hv:x` → `@[1 "a"]`, d:9);
    - after an ordinal step it works (`groups.1:name` → `@["b" "c"]`, d:10), which is the `t3.0:*` route;
    - the existing refusals carry over unchanged: a PVec of one record type collides by construction
      (`star-omega-nominal`), and leaves have no join.

    A claim to pin once built, not a theorem yet: the identity broadcast must be the identity at BOTH
    twins.
  - **JC-3 — against (the broadcast's extent rule).** [Q_U7](#q-u7) made extent structural: `:`
    broadcasts exactly the next step. J adds the one place no step is written. In the IR it is still one
    step, `(@bcast ε)`, so the invariant holds. In the SURFACE it is an elision: one grammar production,
    `:` immediately followed by a star lexeme. A bare `x:` stays a refusal.
  - **JC-4 — against (discoverability).** Every near-miss is a bare "Unbound variable" today: `values*`,
    `values.*`, `values: *`, `values:**`, `values:.*` (d:11–15). J ships with guided refusals naming
    `x:*`, each remedy run (JD-4). `values*` cannot be taken: `*`-suffixed identifiers are a convention
    ([Q_U26](#q-u26)'s 148 `int*` uses).
  - **JC-5 — against (block position).** `x{a:*}` sits on the in-block broadcast, which does not apply
    its step until DEFERRED 167 is fixed (c:26 vs c:28). Without a waypoint, users would get 167's
    misleading "Map-valued contents" message (JD-3).
  - **JC-6 — precision (one level).** J is one join. Full ravel is `x:*:*`, written per rank, and a typed
    program knows its ranks statically. A rank-polymorphic "flatten everything" exists only as A. It
    matters only for first-class selectors applied at several ranks (§7.5).
  - **JC-7 — the record.** J supersedes [Q_U26](#q-u26)'s spelling (`.*` is not reclaimed); its
    MEANING (whole-container join) stands. The P4e tracker row, P4e-2's scope and spec §2.1's `.*` row
    change with it. P4e-2's reader work moves from `.*`'s grouping fix to recognizing `:*`.
  - **JC-8 — monotone migration.** Every spelling J uses is unbound today (d:6), so adopting it breaks
    nothing. Reversing it after programs use it would. With the owner's "liking" and my medium-high,
    the question is decide-now versus decide-at-P4e-2's-audit. The audit only sizes the reader work;
    it cannot change the meaning.

  **Laws J makes checkable** (to pin as generated laws, as [Q_U60](#q-u60) did):
  - bind = join ∘ fmap: `x:k*` ≡ `x:k:*`;
  - known-length ravel: `x:*` ≡ `x{0 … n−1}*` (c:9);
  - a Map's values: `m:*` ≡ `m{k₁ … kₙ}*` and `m:*_` ≡ `m{k₁ … kₙ}*_` (c:16–18);
  - naturality of join: `x:*:k` ≡ `x{0 … n−1}*:k` (c:21);
  - the functor identity `x:ε ≡ x`, in the IR.

  **Sub-decisions inside J (JD-n). ✅ ALL SEVEN DECIDED 2026-11-02 AT THEIR LEANS, as a batch (owner:
  "OK to take the leans in a batch."). Each "Lean" below is the decision:**
  - **JD-1 — what `x.*` becomes.** Lean: a guided refusal naming `x:*` (and `x:name` for `.*name`, as
    P4c-5 planned). Not kept as sugar: two spellings of one operator is the shape Q_U23 retired `.*`
    for.
  - **JD-2 — `x:*-` and `x:*-_`.** Nothing lies between the identity broadcast and the star, so nothing
    can collapse. Lean: accept them as `x:*` and `x:*_`, per [Q_U59](#q-u59) ("where nothing can
    collapse, `*-` ≡ `*`"). Alternative: refuse them as redundant.
  - **JD-3 — block position before DEFERRED 167.** Lean: a guided waypoint refusal for `x{a:*}`, naming
    the path form `x.a:*` (and a record literal for the key), in the shape of VF-1's waypoint. It
    widens to the meaning when 167 lands.
  - **JD-4 — the near-misses.** Lean: guided refusals for `x.*`, `x: *`, `x:**` (→ `x:*:*`), `x:.*` and
    a bare `x:`, each naming the spelling that runs. For an unbound `x*` with `x` bound, a hint, if it
    is cheap.
  - **JD-5 — full ravel.** Lean: no operator, `x:*:*` per rank. A as a library selector is deferred to
    §7.5 / PF, non-blocking.
  - **JD-6 — ε in PF's `data Step`.** The identity becomes a seventh step kind in [Q_U17](#q-u17)'s
    closed union. PF owns it; non-blocking.
  - **JD-7 — `selection` declarations.** Lean: untouched. Their `.*` / `.**` mean "unrestricted"
    (RV-3), a different form; P4e-2 does not rewrite it.

  **RV-4.** `tw{teams:m*}` is refused with a message about "Map-valued contents" (c:26), while the path
  `tw.teams:m*` → `@[1 2 3]` (c:28). In a block the broadcast does not apply its step (DEFERRED 167's
  `w4{a:b}` returns `a` untouched), so the star meets the team records. Filed as an addendum to 167.

  **Side findings (RV-n):**
  - **RV-1.** Q_U40's record says `vv:{0 1}*` → `⟨1 2 3 4⟩`, "a matrix RAVEL falls out with no special
    case". Measured, it is refused as not-yet (a:12). The record states a design expectation as if
    measured.
  - **RV-2.** A runtime miss under a star printed the panic as a VALUE: `values{3}*` →
    `(panic "select: index 3 …").* : [PVec Int]` at zero errors (probe-p4e2-b.pre-fix-a9788c0a.out
    line 4; `values{0 1 2 3}*` likewise, probe-p4e2-a.pre-fix-a9788c0a.out line 15). Fixed at the
    1b-vi close (`55b7df16`): a panic subject propagates.
  - **RV-3.** `.*` in `selection` declarations means "unrestricted" (≡ bare), and `.**` likewise
    (`typing-core.rkt:2639`). Reclaiming `.*` for ravel in paths gives the glyph two meanings across
    two forms; P4e-2's retirement inventory must decide that form's spelling either way.

  **Next free Q-label: U64.**

- <a id="q-u43"></a>**⭐ Q_U43 — THE L4 SORT CHECK MOVES TO TYPING FOR STAR-BEARING
  BRANCHES, AS [Q_U38](#q-u38)'s COROLLARY [owner, 2026-08-11 — "move the sort
  check to typing per Q_U38's corollary"].** Q_U38 moved the COLLISION check;
  this moves the SORT (L4 keyed-vs-keless) check, which rides the identical walk
  with the identical blindness.
  **WHY IT IS FORCED, discovered writing 1b-ii's arms.** `select-branch-top-keys`
  is documented *"Fully static; the parser's duplicate check AND the L4
  sort-homogeneity check both run on these"*, and returns one component per
  surviving output — a key SYMBOL (keyed) or `#f` (keyless). **A star branch's
  components are SUBJECT-DERIVED**: neither their identity nor their SORT is
  knowable from the step list. Every available answer is wrong differently:
  · `'()` — contributes nothing, which is exactly the silent miss the P4a comment
    says it fixed (*"a sixth kind silently contributed NO component, so the L4
    sort check and the duplicate check would both simply not see it"*);
  · `(list #f)` — declares the branch KEYLESS, wrong whenever the contents are
    Maps, and would raise a spurious L4 mixed-sorts error against keyed siblings;
  · `(list s)` — a key literally named `(@star …)`.
  So the star breaks the function's stated contract for one kind. ⚠ The audit's
  critic had already flagged `mixed-sorts?` as **the more dangerous of the two
  blind gates** — it runs one line BEFORE `dup-output-key` and its residue is a
  silently WRONG CARRIER for the whole level rather than an error.
  **WHAT LANDS**: `select-branch-top-keys` gets an explicit `'star` arm that
  RECORDS that it cannot answer; the parser's two gates carve out star-bearing
  branches with the reason at the site; typing performs both checks where the
  subject's row is visible. ⚠ The carve-out is **1b-iv work** — under 1b-ii the
  star refuses before any walk reaches it, so the arm ships INERT and the
  obligation is written where 1b-iv picks it up. Building the carve-out now would
  be mid-flight widening (*Watching 9*).
  **Next free Q-label: U44.**

- <a id="star-census"></a>**⭐ THE STAR-SURFACE CENSUS IS THE DESIGN'S INPUT
  [owner-commissioned, 2026-08-09].** After two failed attempts, the owner ruled
  that attempt 3 opens from a MEASURED MAP rather than an intuition about where
  a star can safely fire. Run: `wf_19cd5077-15b` (5 axes + completeness critic +
  synthesis, ~1.39M tokens). It produced a ranked constraint set (Tiers A–D,
  G, O), a pipeline surface map, a carrier table, a discriminator inventory and
  **twelve** enumerated approaches. Load-bearing results, each re-measured on the
  main thread before being recorded here:
  · **The reader ERASES glued-vs-spaced for every non-identifier carrier.** So in
    any probe triple the SPACED leg *is* the count-preserving simulation and the
    CONTROL leg *is* the count-changing one — attempt 1's defect was measurable
    before it was written.
  · **24 form-level item-counting consumers**, not the 14 an earlier sweep found;
    nine have no `process-*` function and are invisible to the obvious grep.
  · **The two biggest finds are NOT star defects** — [DEFERRED 102](../../../DEFERRED.md)
    (the abort seam, now FIXED at `41458174`) and **103** (a bare `*` is a legal
    irrefutable PATTERN that silently deletes later `match` arms).
  · **A 1-element sentinel list is NOT unprecedented** — `($select-brace)`
    head-only is already `#t` for both consumers; it is the brace/any-arity
    class, at the cost of the arity check. (I had asserted the opposite.)
  · **`group-items-to-tree`'s output is DISCARDED in production** (2 writes, 0
    reads), and it already diverges from the datum grouper in six arm families —
    so the twin obligation may be the Q_N3 guard rather than correctness.
  · **`$star` is a live, undocumented, zero-producer Sigma spelling** reachable
    from user source; `star-symbol?` was built to accept a sentinel.
  ⚠ **THE FULL ARTIFACT IS NOW IN THE TREE** — the six bullets above are the
  summary; the ranked constraint set (Tiers A–D, G, O), the pipeline surface map,
  the carrier table, the discriminator inventory and the **twelve** enumerated
  approaches were extracted from the run transcript on 2026-08-10 to
  [`docs/tracking/tracks/CIU/CIU_6/research/2026-08-09_STAR_SURFACE_CENSUS.md`](research/2026-08-09_STAR_SURFACE_CENSUS.md).
  Until then they existed ONLY in a session transcript, which is not durable
  storage — and the owner's ruling is that attempt 3 opens from the MEASURED MAP,
  which cannot be honoured against an unreadable artifact.
  (Q-label register: see [Q_U48](#q-u48), the latest ruling — **next free U49**.)

**Open, GATING (spec §8):**
- ~~**Q8** (the precise lexical grammar)~~ — **CLOSED 2026-07-28**: written at
  P1b-i, **owner-reviewed**, and ruled (Q_M8 the sole amendment). §Q8 is now
  normative for P1b-ii/iii and P2.
- Keyword-projection disposition (§2.4) — revisit when P4 lands broadcast
  (likely subsumed by `users:name`).
**Carried from the P3 mini-audit [owner, 2026-07-28], still standing:**
- `#:keyword` retires with the `#.:name` twin (`#.name` survives).
- ~~`^` splitting is **P3**-parser-side via POL.6 `split-fused-symbol` — no
  second splitter~~ — **SUPERSEDED by Q_M7 above**, which found this ruling not
  executable (`split-fused-symbol` splits on `":"` and rejects >2 segments; the
  tree's only `^` splitter is the sexp-only `validate-selection-paths`). It is
  struck here rather than left standing, because two contradictory statements
  eleven lines apart in the same section is exactly how P3 would inherit the
  false premise Q_M7 was written to prevent.
- ~~`.-1` = classifier-level rejection~~ — **SUPERSEDED** by §Q8.1 + §5.P2:
  `.-1` (and `.+1`) LEX CLEANLY as dot-access with a signed field, so the
  rejection is a CONSUMER decision, not a classifier one; pinned at P2.
  Negative bracket/`get` payloads = a static error at the grouping seat
  alongside `m[:a]` (landed P1a).
- ~~`.:.`/`.:[` tokens defer to P5~~ — **MOOT**: the new broadcast is bare
  `:s`; no `.:` tokens exist in the surface at all.

---

