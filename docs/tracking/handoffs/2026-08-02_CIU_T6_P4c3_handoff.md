# Handoff — CIU T6 Path Selection: P4c-3's thirteen-site work + prereqs LANDED; the enable-set is still EMPTY and that is the open design

**Date**: 2026-08-02 · **For**: a fresh session continuing **D4.P4c-3** (and holding the PPN 4D seed).
Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol**: read §1–§6 here FIRST, then §2a, then every §2c doc
> **in full** — then **summarize your understanding back to the owner and let
> them validate it BEFORE starting work.**

> ⚠ The live surface law: **dot DESCENDS · brace SELECTS `x{…}` · `:`
> BROADCASTS · `^` RE-KEYS · `*` FLATTENS · `<` DISCLOSES.** The spec is a
> **GUIDE**; where it and D4 differ, **D4's recorded adaptation wins.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track / Phase**: CIU → Track 6 Path Selection → **D4.P4c-3**, status **🔄**.
- **Design doc**: `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md` (D4).
- **HEAD at write**: `e06b5048` — ⚠ **re-derive with `git rev-parse HEAD`.**
  HEAD moved mid-session repeatedly this arc, and origin advanced externally once.
- Local `main`, **MAIN CHECKOUT**. ⚠ If the session launches in a worktree, REMOVE it
  (it happened twice in the P3 arc; verify 0 unique commits first).
- **Suite** GREEN **0 failures / 479 files** (count is NONDETERMINISTIC — the gate is
  the zero, never the number) · **battery 325** (`grep -c '^(test-case'
  tests/test-path-selection.rkt` — **MEASURE, never derive**) · acceptance
  path-selection **52/52** + records 89/89 + width 6/6 + seal 29/29 + validate 28/28 ·
  **corpus A/B ZERO diffs / 163 files vs the PRE-MINT baseline**.
- **41 unpushed**, origin/main `07b79b52` — **do NOT push unless directed.**
- **Working tree**: pre-existing **owner WIP only (41 entries) — LEAVE ALONE.**
  Stage EXPLICIT paths · verify `git diff --cached --name-status` · **NEVER
  `git stash`** · no Co-Authored-By · long messages via `git commit -F`.
  ⚠ `.claude/` is gitignored — rules-file edits need `git add -f`.

### Progress

| Phase | Status |
|---|---|
| P0–P3 ✅ · P4a ✅ · P4b ✅ · P4c-1 ✅ · **P4c-2 ✅** (`b1399016` mint+unwrap · `cbd8d1a7` four misses · `8c4faee2` condition (c) · `68cdaae7` **the inverted default**) | done |
| **P4c-3 🔄** — prereqs ✅ (`8fa30336` DEFERRED 32 · `8c95d4ae` DEFERRED 36 RESOLVED) · thirteen-site kind ✅ `3b998aa8` · `[else]` split ✅ `f6310c27` | **← HERE** |
| P4c-4 (PVec broadcast + L1/extent) · P4c-5 (`.*name` retirement + residue) · P4d · P4e · P5 · PX · X.close (PIR-gated) | ⬜ |

### NEXT IMMEDIATE TASK

**The enable-set is `'()` and the open question is what fills it.** Everything
mechanical for P4c-3 has landed. What remains is a **design decision the owner
has explicitly reserved** — see §5. Do NOT grant a context without ruling it;
the moment the set is non-empty the dead-code window closes permanently.

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always-Load**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
`ciu-t6-records.md` (**the tail block = live state**) · `DESIGN_METHODOLOGY.org` ·
`DESIGN_PRINCIPLES.org` · `CRITIQUE_METHODOLOGY.org` · `HANDOFF_PROTOCOL.org` ·
`MASTER_ROADMAP.org` · CIU master `docs/tracking/2026-03-21_CIU_MASTER.md`.

**§2b rules** (auto-loaded; load-bearing here): **`on-network.md`** (the mantra —
it is what redirected this whole arc) · **`propagator-design.md`** (⚠ its
Broadcast section was CORRECTED 2026-08-02 — read the correction, not your
memory of it) · `pipeline.md` (§ Exhaustive Walkers; § ADDING A KIND is mirrored
in syntax.rkt and **syntax.rkt is the authority**) · `stratification.md` ·
`testing.md` · `workflow.md` · `prologos-syntax.md` § Reader.

**§2c Session-Specific — READ IN FULL, IN THIS ORDER:**

1. **D4** — §3's **Q_U16 / Q_U16b / Q_U7** blocks · **§5.P4c in full** (partition,
   prerequisites, the ten named hazards) · **§5.P4c-1 / §5.P4c-2** (the measured
   binder table, the inversion close) · **§Q8** (normative) · §2.3 · §8 R6 · §9.
2. `docs/tracking/DEFERRED.md` — **CIU T6 items 24–36**. 32 is 🔄 *mostly* fixed
   with the important half open; 36 is ✅ RESOLVED; 33/34/35 are live.
3. Dailies `docs/tracking/standups/2026-07-28_dailies.md` — STATE head + the last
   **5** LOG entries (the file interleaves arcs; read by TITLE).
4. Memory `ciu-t6-records.md` — the tail block.
5. **`docs/tracking/2026-05-19_PPN_4D_IMPLEMENTATION_DRAFT_NOTE.md` §12** — the
   reader-layer seed written this session. Read if the on-network reader is in
   scope; skip for pure P4c-3 work.
6. `racket/prologos/examples/2026-07-26-ciu-t6-path-selection.prologos` — 52 live
   markers; **the marker gate renumbers on mid-file uncomment — land trailing
   markers first.**

---

## §3 — Key Design Decisions (do NOT revisit without census-grade cause)

- **⭐ THE INVERTED DEFAULT (owner, `68cdaae7`).** Unwrap by DEFAULT; preserve
  only where `broadcast-enabled-contexts` grants it. That list is **EXPLICIT and
  EMPTY**, and the emptiness is deliberate staging: the sentinel has no consumer
  until P4c-4, so preserving anywhere buys nothing and costs a
  SPELLING-DEPENDENT surface. With it empty the mint is **provably equivalent to
  not minting** — the regression matrix is byte-identical to a real `182f1678`
  build, the corpus A/B is ZERO, and eight datum pins that had flipped forward
  **flipped BACK**, mechanically demonstrating mint ∘ unwrap = identity.
  ⚠ **THE ENUMERATION DOES NOT VANISH, IT MOVES** (to "where broadcast
  SURVIVES"). Only the failure DIRECTION changed. Do not overclaim it.
  Rejected-with-reason: the MODERATE form was built and MEASURED first — it left
  the sentinel alive in a flat `def y := users:name` but dead in an indented
  body, an accident of recursion order. Spelling-dependence is a hard
  disqualifier.
- **Q_U7 — `(@bcast step)` is a ONE-STEP wrapper.** `x:s:t` → TWO wrappers.
  Extent is STRUCTURAL, so broadcast-of-nothing is unconstructible. In the walks:
  **NAME/KEY = transparent (delegate to the wrapped step)**; **VALUE = guided
  NOT-YET naming P4c-4**, because delegating there would project off the
  CONTAINER instead of broadcasting over it.
- **Q_U16 / Q_U16b** stand as recorded (mint uniformly at grouping · `$bcast-step`
  joins `access-sentinel?` · the unwrap at the reader post-pass · `users:0` is a
  legal ω step). Inherited and locked: Q_U5 · Q_U6 · Q_U9 · Q_U13 NEST · Q_U15 ·
  the update-in ω fence · the whole-node abort · zero-propagator v1.
- **Next free Q-label: U17.**

---

## §4 — Surprises (HIGHEST RE-DERIVATION RISK)

1. **A GREEN SUITE IS NOT EVIDENCE FOR A TRIPWIRE — ONLY MUTATION IS.** Proven
   twice this arc. Mutation caught `bcast-step-datum?` as DEAD CODE (`stx->datum`
   peels ONE layer, so it never returned #t at any site) and caught the `[else]`
   defect below. The procedure is recorded at `tests/test-path-selection.rkt`
   (search "MUTATION"): force `broadcast-enabled-contexts` non-empty in a scratch
   build, probe, revert.
2. **THE `[else]` ARM WAS A SWITCH WIRED TO A BROKEN PATH** (`f6310c27`). The
   inversion wrote `(scan-for-param-heads (map unwrap-binders-deep kids))` — the
   map strips deeply FIRST, so the scan was DEAD WORK. Since `binder-param-head?`
   is consulted at exactly ONE site inside that scan, **`defn fn spec property
   functor rel defr defmacro` would have been blanket-stripped at the first
   grant**. Fixed by asking the SCANNER whether it recognized anything
   (`scan-for-param-heads/recognized`) rather than re-testing its arms.
3. **A ZERO CORPUS A/B IS NOT EVIDENCE OF SAFETY** for a surface the corpus does
   not exercise. All seven P4c-2 regressions were corpus-invisible for exactly
   the reason the commit that hit them had already documented. 2 data points;
   a 3rd should promote it to the rules tier.
4. **MEASURE PER SPELLING.** Single-line probes overstated two leaks; the
   idiomatic multi-line forms were already correct. Without re-measuring, the
   slice would have been mis-scoped.
5. **THE `ADDING A KIND` RECIPE HELD** — the sixth kind met all thirteen sites
   with no correction. First enumeration in this arc to survive a new member
   intact, and worth knowing because the arc's other lesson is the opposite.
6. **THE PARSE LAYER INSTALLS ZERO PROPAGATORS** — all seven files. What looked
   like "the reader is on propagators" is a cell LEDGER (1 make-prop-network, 5
   net-new-cell, 5 net-cell-write, 1 net-cell-read, straight-line net1→net6).
   PPN master rows 1 and 3 were annotated accordingly (`e06b5048`); their real
   deliverables stand, the ON-NETWORK claim does not.
7. **BROADCAST IS NOT PARALLELISM AT HEAD.** `broadcast-profile` is inert
   metadata with ZERO production readers; the executors chunk worklists of
   *propagator IDs*, so broadcast collapses N pids into 1 and then runs N items
   sequentially. The ambient rule asserted the opposite for months and is now
   corrected (`19ab78a9`).
8. **The `*`/`^` swallow hazard is STILL UNOWNED**: `ident-continue?` swallows
   them, so `users:tags*` / `users:name^alias` arrive as SINGLE tokens and no
   scheme inspecting token TYPE can see the operator. Rule it at P4c-3/4 rather
   than discover it.

---

## §5 — Open Questions and Deferred Work

**⬜ THE OPEN DESIGN — what fills the enable-set.** Two owner decisions, and
they must be ruled TOGETHER because 2 and 3 trade against each other:

- **Per-FORM or per-POSITION granting?** Per-form is cheap but transitive, so an
  unknown binder-introducing form nested in a preserved body inherits preserve
  and leaks into its own binder position — the forms at risk are exactly
  `capability`, `Pi`, `Sigma`, `DSend`, `DRecv`, the five the inversion fixed.
  Condition (c) would refuse them LOUDLY rather than prevent them.
  ⚠ **PROBED AND SETTLED**: per-position is **NOT computable at descent** —
  aligned `let` arrives as a flat mix and sibling chains as separate forms, both
  built by `absorb-let-siblings`/`classify-let-block` which run AFTER the child
  recursion. So per-position collapses into a separate PASS over the classified
  tree.
- **Is preserve TRANSITIVE?** Almost certainly yes (it is what makes
  `defn f [x] [g users:name]` work) — but transitive is also what carries the
  leak above.

**⚠ THE OWNER REJECTED THE SECOND-PASS SHAPE ON ARCHITECTURAL GROUNDS** —
"parsing on propagators would not admit an ordering requirement or phase
passes". That redirected the work toward an on-network disposition attribute,
which the audit then showed is **chartered, not new** (§6 below). The imperative
options are therefore NOT to be landed by default; re-open the question with the
owner.

**DEFERRED 32–36** (filed `85fe2df3`, updated `8c95d4ae`):
- **32 🔄** — over-reach survivors mostly fixed at `8fa30336`. **The remaining
  half is the important one and is a P4c-3 design input**: enabling a context is
  NOT just adding to the list, because the unknown-head default still strips
  bodies and a body sub-group's head is BY DEFINITION unknown.
- **33** — `parse-param-names-for` / `parse-defn-binder-seq` unhardened; they
  leak raw syntax objects AND an absolute path into user text. **Sweep by GREP,
  not by head** — the head-driven census is what missed them.
- **34** — `unwrap-let-block` possibly zero-coverage (SUSPECTED; the mutation
  matrix was not re-run).
- **35** — four cosmetic/doc-truth leftovers incl. a `#f` double-interpolation
  and an eq?-preservation comment that is false as written.
- **36 ✅ RESOLVED** — both untested doors probed clean (REPL/LSP matches
  process-file; `.pnet` round-trips with ZERO `bcast-step` in the artifact).
- **31** — the `ns` guard still RAISES (whole-file abort, the Q_L4 class).

---

## §6 — Process Notes

- **Racket**: `"/Applications/Racket v9.0/bin/racket"`; runner
  `tools/run-affected-tests.rkt --tests …`; probes via `tools/run-file.rkt`
  (`--check` for acceptance) — all from `racket/prologos/`. Manual `raco make`
  needs `PLT_CS_COMPILE_LIMIT=1000000`. `tools/check-parens.sh` after EVERY
  `.rkt` edit — **then COMPILE**.
- ⚠ **The targeted runner ABORTS `test-path-selection.rkt` at 30 s** and
  `--timeout` does not help. Use
  `racket -e '(require (file "…/tests/test-path-selection.rkt"))'` for the track
  file, the runner for the neighbourhood.
- **THE FALSE-ZERO FOOTGUN**: a reader harness without
  `register-default-token-patterns!` matches NOTHING. It has produced confident
  wrong numbers twice. **And a second false-zero now exists**: counting surviving
  `$bcast-step` in output is structurally ZERO while the enable-set is empty —
  count TRIGGER SITES in source instead.
- **Corpus A/B**: `git archive` BOTH legs onto ONE snapshot, worktree-pin the
  baseline, never `git stash`. `bench-ab.rkt` has **no `--ref`**.
- **Adversarial verify before EVERY behavioural commit** — it has caught
  something in 10 of the last 11 slices, including a live regression and a dead
  guard of my own.
- **`grounding-audit`** is the default opener for a grounding-heavy mini-audit;
  **`design-options-panel`** for adversarially-weighed options. Args as a JSON
  OBJECT. ⚠ **R-lens-verify anything load-bearing yourself** — this session the
  panel's synthesis found a real defect AND the audit refuted three of my own
  stated facts; conversely a prior panel's recommendation was wrong with three
  critics corroborating it.
- **Prior-art discipline**: this arc has logged FOUR prior-art misses. Search by
  CONCEPT before claiming anything is new near broadcast, per-node cells, or the
  reader.
- Per-phase 5-step gate · commits trigger dailies (STATE overwrite + LOG append) ·
  per-slice records in that slice's D4 §5 section · probes in the SCRATCHPAD,
  never the repo · full suite = regression gate ONLY ·
  **owner co-designs in PROSE, ONE QUESTION PER TURN**.

---

## §7 — The PPN 4D thread (context, not a task)

The owner observed this work belongs to PPN and that the reader must get
on-network eventually. The audit established it is **chartered, not new**:

- **PPN Track 4D — Attribute Grammar Substrate Unification** ⬜ is the umbrella
  (parsing + elaboration as one attribute grammar, ordering emergent from
  dataflow). Prerequisites: **4C complete + T-3 + PM Track 12** — 4C is 🔄, so
  4D is prerequisite-blocked.
- **Per-node cells → PPN Track 8**; **realization → NTT `:embedded` PU + `:diff`**;
  **ambiguity → PPN Track 5**; **the ω node → the broadcast-propagator node
  track** (chartered with an explicit trigger, and surfaced into the trackers
  this session as CIU master row **4B**).
- The reader-layer findings are seeded at **PPN 4D note §12** and linked from the
  PPN master.

**Nothing here is actionable now.** It is why the imperative disposition options
were not landed, and where the work goes when 4C clears.
