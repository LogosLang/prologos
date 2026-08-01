# Handoff — CIU Track 6 Path Selection: the REDESIGN is settled; implementation resumes at D4.P1

**Date**: 2026-07-28 · **For**: a fresh session continuing Path Selection at **D4.P1**.
Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol**: read this handoff §1–§6 FIRST, then §2a Always-Load,
> then EVERY §2c doc **in full** — then **summarize your understanding back to
> the owner and let them validate it BEFORE starting work.**

> ⚠ **The surface was REDESIGNED on 2026-07-28.** If you have any memory or
> summary describing "dot extracts · bracket selects · `:` iterates · `*`
> splats" or PS1–PS15, that is the **OLD, SUPERSEDED** surface. The live surface
> is the spec (§2c-1) as ADAPTED by D4 (§2c-2). Do not implement from the
> 2026-07-26 design doc.

---

## §1 — Current Work State (PRECISE)

- **Series / Track**: CIU Series → **Track 6**, Path Selection.
- **Normative SURFACE**: [`docs/research/2026-07-28_path-selection-spec.md`](../../research/2026-07-28_path-selection-spec.md)
  (v0.1, 676 lines, status-tagged per element). **Owner ruling on its standing**:
  it was written OUTSIDE this project, idealized — it is a **guide/suggestion,
  NOT a prescription**. Adapting it to grounded code reality is expected and
  correct; every adaptation is recorded in D4 §3.
- **IMPLEMENTATION design**: [`docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md`](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md)
  — the live doc. Progress Tracker at top; **per-phase sections in §5** (owner
  process ruling: one-line tracker rows do not scale).
- **PREDECESSOR** (superseded surface, kept as the record of rounds 1–8b + the
  landed P0–P2 implementation):
  [`2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`](../2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md).
  Carries a supersession banner. **Do not implement from it.**
- **HEAD**: `c284182a` · branch `main`, **~21 commits ahead of origin — do NOT
  push unless directed** (re-count; HEAD moved 36 commits under a prior session).
- **Suite**: GREEN **9238 / 474 / 0** (last full run at `ac89341f`; only docs +
  the acceptance file since). Acceptance: path-selection **28/28**, records
  **89/89**. `.pnet` is **v6**.
- **Working tree**: pre-existing **OWNER WIP only (41 entries)** — LEAVE ALONE.
  ⚠ Stage explicit paths; verify with `git diff --cached --name-status` (NEVER a
  `^[AM]` grep — it hides D-rows). **NEVER `git stash`** (owner stashes live).
  NO Co-Authored-By. Long commit messages via `git commit -F <file>`.

### Progress Tracker (authoritative copy lives in D4)

| Phase | Status |
|---|---|
| **D4.P0** acceptance corpus (augment the EXISTING file) | ✅ `e2674208` — 28/28 |
| **D4.P1** lexical seams + retirement batch (delivers spec Q8) | ⬜ **← NEXT** |
| D4.P2 grade-1 core (`.k`/`.N` + bare-path extraction) | ⬜ |
| D4.P3 blocks (`x{…}`, `^`, L4, honest nesting, STRICT merge) | ⬜ |
| D4.P4 broadcast ω (`:s`, fusion, map-generic, `*`, `.*`, `:<`, the 2b split) | ⬜ |
| D4.P5 Ruling B + L2 factoring | ⬜ |
| D4.PX binder-seam substrate (carried; position-flexible) | ⬜ |
| D4.P6 demand semantics (RULED STAGED; X.close-gated) | ⬜ |
| D4.X.close bench · DEFERRED · doc-truth · memory · **PIR** | ⬜ |

### NEXT IMMEDIATE TASK — open **D4.P1** with its mini-audit

P1 = everything tokenizer/grouping, and its **named deliverable is spec Q8**
(the precise lexical grammar), owner-reviewed before landing. Two halves:

**(a) The seams** — all ruled 2026-07-28, mechanism-level:
1. **`.{` = a `dot-lbrace` compound token** at the dot band (the `dot-lparen`
   `.( ` precedent; prefix-disjoint). `.` uniformly means DESCEND. ⚠ It is a
   NEW OPENER → the **three-layer co-update** is mandatory (frame dispatch +
   langle skip-set + group-items — the `31d27c83` lesson).
2. **Brace adjacency with HEAD-SYMBOL PRECEDENCE** — reader-form heads
   (`racket{…}`, 10 live FFI sites, no-space is its *documented canonical*
   form) are recognized BEFORE the select-block rule; spaced `{…}` is never a
   block. Census = THREE buckets (spaced · adjacent reader-form head ·
   adjacent select-block).
3. **Multi-digit `:N`** — `x:10` lexes as THREE tokens today. Lean = a
   digits-only `keyword-index` recognizer, **decided by probe** at the Q8
   review (probe `{:10 v}` + both-modes `:digits` census).
4. **Colon seam = POSITION-disjoint** — broadcast is expression-position only;
   annotation colons live in binder/head positions. P1 **census verifies** the
   disjointness (Rel T1 typed logic vars `?x:Int` especially).
5. ⚠ **`:<` (disclose, ADOPTED v1)** — `<` is a WS **angle-group opener** (the
   mixfix-swallow family). `users:<{…}` gets a **mandatory probe row** in Q8.

**(b) The retirement batch** (censuses FRESH from `wf_2830f0aa-9a4`, live counts):
dot-key `.:name` (**2 live**) + the `#.:name` / `#:keyword` twins (both RETIRE;
`#.name` SURVIVES) · broadcast `.*name` (**4 live**; migration target is now
**`:name`** under Q1; and `expr-broadcast-get` RETIRES with it per ruling 4b —
it is not repaired) · `m[:a]` static error + hint (grouping seat) ·
`x[]` / `_[sel]` / `.-1` rejections (`.-1` at the **classifier**; negative
bracket/`get` payloads at the grouping seat) · round-trip printing pins.

**Diagnostic seat (load-bearing)**: production has **NO reader rejects** — the
compat-path checks are DEAD code (sole non-test caller `tools/golden-capture.rkt`).
The **tilde-number classifier error** (`parse-reader.rkt:1108-1113`) is the ONLY
in-tree diagnostic that fires on every entry path. New guiding errors go there
or they land dead.

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always-Load**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
[[ciu-t6-records]] · `DESIGN_METHODOLOGY.org` (Stage-4 per-phase protocol) ·
`DESIGN_PRINCIPLES.org` · `CRITIQUE_METHODOLOGY.org` · `HANDOFF_PROTOCOL.org` ·
`MASTER_ROADMAP.org` · **CIU master `docs/tracking/2026-03-21_CIU_MASTER.md`**
(note the real filename — an old handoff cited a nonexistent `2026-03-28_`).

**§2b rules** (auto-load; the load-bearing ones for P1): **`prologos-syntax.md`
§ Reader** (both-modes census; recognizers delegate to the ONE `ident-continue?`
— never inline a charset, the F1b.7g drift class) · `pipeline.md` (§ Exhaustive
Walkers; the New-AST-Node checklist for P3/P4) · `testing.md` (failing-test-first;
read failure logs, never re-run the suite to diagnose) · `workflow.md` (the
5-step gate; adversarial VAG).

**§2c Session-Specific — READ IN FULL, IN THIS ORDER:**

1. **The SPEC** `docs/research/2026-07-28_path-selection-spec.md` (676 lines) —
   the surface. Read §1–§5 + §10 corpus carefully; §7 is staged/outlook.
   **Remember its standing: guide, not prescription.**
2. **D4** `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md` — Progress
   Tracker, §1.2 supersession table, **§2 grounded code reality (incl. §2.3 the
   CARRIER TABLE)**, **§3 the rulings ledger** (every ruling that governs P1 is
   there), §5.P1 (your phase), §8 risks, §9 the two-column principles gate.
3. **The D5 critique's residue** — there is no standalone critique file; the
   surviving findings and their dispositions are folded into D4 §3 + §8. The
   raw workflow output is `wf_2cef0199-18a` (13 agents; not required reading).
4. **The dailies** `docs/tracking/standups/2026-07-26_dailies.md` — STATE head +
   the newest LOG entries (the redesign, the D5 critique, D4.P0).
5. `racket/prologos/examples/2026-07-26-ciu-t6-path-selection.prologos` — the
   acceptance file (28 markers; §B/§C/§D/§I carry the phase-tagged targets P1's
   successors uncomment).
6. `racket/prologos/tests/test-path-selection.rkt` — the track test file (39
   cases; grow it per phase).
7. The predecessor design doc — **§3 grounded facts + §5.10 only**, for the
   landed-work rationale. Its SURFACE (§5.9 PS1–PS15) is superseded (its
   Status header, §5.9 heading and §2 tracker now carry supersession markers).

**A doc-truth sweep ran before this handoff** (`wf_f42f03ab-017`, 4 read-only
facets) and fixed **2 BLOCKING + 7 SIGNIFICANT** drift defects in these very
documents (`c284182a`) — the batch-ruling fold had updated the tracker and the
§3 ledger while leaving several §5 PHASE SECTIONS stale, which is exactly what
an implementer reads. **The lesson generalizes: when folding rulings, the phase
sections are the drift surface, not the tracker.** Both memory files were also
carrying the OLD surface as current and were corrected.

---

## §3 — Key Design Decisions (do NOT revisit without census-grade cause)

**The redesign's three commitments** (spec §1): the **key-sort thesis**
(ordinal keys contingent/re-derived, nominal keys essential/preserved) ·
**per-step result discipline** (`{…}` projects, `^` dissolves, bare paths
extract) · **selection is demand** (blocks = copattern sets over codata).
Plus grades 1/ω, laws L1–L7, Ruling B, and the W1–W4 walls.

**Owner rulings, 2026-07-28** (all in D4 §3; the ones governing P1 are starred):

- **Q1 = map-generic `:` YES** — `x:s` over a Map maps values, keys preserved.
  Consequences: path-position `.*` subsumed; ★ **`.*name`'s migration target is
  `:name`**. Independently corroborated: `map-map-vals` already exists as a
  native node and produces §10.5's expected result today.
- **`v[0]` KEEPS its current semantics** — the PS2 re-target flip is CANCELED.
  `.N` arrives ALONGSIDE, not instead. Two surfaces over ONE `(get expr N)`
  mechanism (the belt-and-suspenders framing was refuted).
- **Batch 1 — notation = TRANSLATION, not spec-editing.** The spec keeps its
  idealized notation (`〈T〉`, unions, selection-ordered rows); the **corpus file
  is the adaptation layer**, written in HEAD's printed forms via D4 §2.3.
  ★ §5.P0's protocol refined: divergence in **notation** = transcription
  (resolved by the table); divergence in **result** = semantics (resolved by
  ruling, never by quietly editing a marker).
- **2a — HONEST NESTING ADOPTED as spec'd**: a keyless block is an n-tuple at
  every n, including n=1. Owner: implicit splice would break the algebra, and
  **`:<` is the designed unwrap remedy**. Code reality agrees one layer down —
  the tuple carrier is a nat-keyed closed row (1-field rows representable;
  runtime `expr-rrb`); only the LITERAL inference arm collapses n=1 to PVec,
  and **selection never routes through the literal arm**.
- **2b — the HETEROGENEITY SPLIT** (adapting spec §5.3's single meet rule):
  **het tuple** (positions static — what `@[…]` gives) → broadcast projects
  **per-position, exactly**, a miss NAMES the position (strictly stronger than
  a meet); **PVec-of-union** (length unknown, via annotation) → the spec's rule
  over union components, **keys ⋂ / field types ⋃** = NEW machinery at P4.
  ★ **Polarity note**: the in-tree union arm is filter-on-miss (optimistic) and
  is CORRECT for a single `get` on one union-typed value; broadcast projects
  EVERY element so all-must-offer is sound there. Two ops, two polarities.
- **2c — Q2 DISSOLVED, off the critical path.** Type rows are canonically
  sorted (landed, load-bearing for `equal?`-as-row-identity); values are
  champ-hash ordered. Neither "source order" nor "selection order" is
  representable — and **the spec's own key-sort thesis rules it**: nominal key
  identity carries the meaning, order does not.
- ★ **3a `.{`** = dot-lbrace compound · ★ **3b** head-symbol precedence ·
  ★ **3c** `:N` probe-decided · ★ **3d** colon seam position-disjoint (see §1).
- **4a — demand semantics STAGED**: spec tag amended to `[ADOPTED — staged]`;
  an **X.close gate row** added; lazy leaves = own post-v1 design. The static
  half (copattern typing never forces) is true at v1 regardless.
- **4b — the STEP-LIST NODE**: ONE selection node family carrying the step list
  (keys · ordinals · broadcast markers · `^` continuations · blocks · disclose).
  **Typing WALKS the steps** (per-position exactness, the union meet, grade
  layer-counting — L1 fusion becomes a *fact*, not a rewrite); **reduction
  LOWERS per step** onto shipped machinery (`get`, `pvec-map`, `map-map-vals`).
  ★ `expr-broadcast-get` **retires** with `.*name`. One node family, not one
  per operator. P3's mini-audit prices the struct before code.
- **4c — row-map typing PER-FIELD in v1** (broadcast bodies are selector steps,
  not arbitrary terms — per-field is cheap); the weakening arrives explicitly
  with first-class selectors.
- **4d — dyn tails: SUPPORT-BOUNDEDNESS** (the old D3-M5 principle, survived):
  closed row → per-field · `(Map K V)` → uniform V→V′ · **dyn tail → loud
  static error** naming the remedies (seal / validate / annotate).
- **Q5 — DISCLOSE `<` ADOPTED IN v1**, bare form, spelled `:<` in broadcast
  composition; lands at P4. ★ P1 owes the angle-opener probe row.
- **Q4** `*` vector-only in v1. **Q6/Q7** moot under P3's strict waypoint →
  P5's mini-audit.

**What LANDED and must not be unwound**: P1's `.{`-as-mixfix retirement ·
**P2 COMPLETE** (5 slices, `ad75e57a`→`ac89341f`) = the **two-tier principle**:
assertive-tier runtime misses are LOUD + COUNTED (Map key miss naming available
keys · PVec/List/dynamic-tuple OOB naming index+length · site 7's fabricated
`none` closed structurally · BOTH def seams), via the carried-alpha strictness
slot on `expr-get`/`expr-map-get`, `definitely-not-map?` inverted to a positive
list. The honest tier (`nil-safe-get`/`nth`/`kv-get`) and the dynamic tier
(`get-in`/`update-in`) are untouched and test-PINNED as such.
**This is the grade-1 substrate the new surface runs on.**

---

## §4 — Surprises (HIGHEST RE-DERIVATION RISK)

1. **The mini-audit refutes-or-rescopes EVERY phase's premise.** Unbroken
   streak: F1b 7/7, P2 5-for-5, the P3 audit, and the D5 critique. **Never
   implement from a design row without opening the phase's mini-audit** (the
   `grounding-audit` workflow is the default opener).
2. **Probing before ruling changes the RULING** — promoted-overdue. This arc:
   round 7's realization rested on THREE premises a probe refuted; round 8's
   "compile-time arity error" claim was FALSE (cross-module constructor arity
   mismatch **compiles clean, exit 0** — only `match` patterns are loud);
   the D5 critique's "1-tuple unimplementable" was itself wrong one layer down.
3. **A failing test is only evidence if it fails for the reason you claim.**
   FOUR instances this arc — tests that false-greened or failed for the wrong
   reason under the `:no-prelude` fixture (`lt?` unbound; `cons`/`nil` unbound;
   a regex matching digits in a **temp-file path** inside a printed error
   struct). The track test file now carries a PRELUDE-backed second fixture +
   a fixture-sanity guard. Guard the premise, not just the conclusion.
4. **A green suite proves nothing for this class.** Three live defects sat
   under a green suite this arc: the permissive `expr-broadcast-get`
   (`ladmins.*nope` → `'[<error> <error>] : ?meta` at **0 errors**), the
   `def X :=` layout defect (now **issue #80**), and the loose-`.{` shatter.
5. **HEAD can move under a long session** — `8d2eb340` → `6a444cba`, **36
   commits**, mid-audit, from a concurrent session. Caught only because the
   grounding-audit template forces every facet to `git rev-parse HEAD` and cite
   it. **Re-verify HEAD before trusting any coordinate in this handoff.**
6. **The carrier gap was the D5 critique's headline** and is now D4 §2.3: the
   spec designs a type language, the compiler ships a different one. Before
   believing any result-shape claim, check the carrier table.
7. **Two documents, one truth**: where the spec and D4 differ, **D4's recorded
   adaptation wins** — but only where D4 records it. An unrecorded divergence
   is a bug in D4, not a licence.

---

## §5 — Open / Deferred (named + owned)

- **Spec Q8 (the lexical grammar)** — P1's own deliverable, owner-reviewed
  before landing. Carries the 3c probe decision + the `:<` angle-opener row.
- **Keyword-projection disposition** (`map :name users`) — likely SUBSUMED by
  broadcast (`users:name`); revisit when P4 lands (D4 §2.4).
- **The sexp special form (old PS14)** — the spec does not address sexp mode;
  carried as an open implementation item, no phase owns it yet (D4 §2.4).
  The 20 sexp brace-select tests (`tests/test-path-expressions.rkt`) are
  **audit-proven isolated** from WS retirements — they keep passing until a
  sexp phase re-points them.
- **Issue [#80](https://github.com/LogosLang/prologos/issues/80)** — `def X :=`
  + multi-key layout body fails; identical body without `:=` works. Filed +
  in DEFERRED. Corpus files sidestep it via the `def X` form.
- **Demand semantics** (spec §1.3) — STAGED; X.close-gated; lazy-leaf design is
  its own post-v1 phase (D4 §5.P6).
- **PX** — the lambda-adoption hole + the standalone-def seam; surface-
  independent, position-flexible, must land before X.close.
- **`pipeline.md` owes a `PNET_VERSION` line** — the project bumped 5→6 at
  slice 4 but the rule's New-Struct-Field checklist never mentions the cache
  version. Promote at X.close (D4 §8 R6).

---

## §6 — Process Notes

- Racket: `"/Applications/Racket v9.0/bin/racket"`; runner
  `tools/run-affected-tests.rkt` (**targeted mode after ANY production edit**);
  probe runner `tools/run-file.rkt` (`--check` for acceptance); all from
  `racket/prologos/`. Manual `raco make` needs `PLT_CS_COMPILE_LIMIT=1000000`.
- `tools/check-parens.sh <file>` after EVERY `.rkt` edit — **then COMPILE**
  (parens can balance while arity breaks; `raco make` is the real gate). Note
  check-parens is Racket-only — pointing it at Markdown produces noise.
- **Probes in the scratchpad, NEVER the repo.** Owner co-designs in PROSE with
  Q_N labels — not chips.
- **Commits trigger dailies** (STATE overwrite + LOG append). Per-phase 5-step
  blocking gate: tests → commit → tracker → dailies → next.
- **Full suite = regression gate ONLY** (read `data/benchmarks/failures/*.log`;
  run individual tests; a guard script blocks blind re-runs).
- **Adversarial VAG per phase**; the `grounding-audit` workflow is the default
  phase opener; **assert on every programmatic replacement** (count-checked
  `python3` edits are the house pattern).
- **Adversarial verify before committing a behavioural change** — 3–4
  perspective-diverse skeptics on the uncommitted diff caught nothing false
  this arc but confirmed several load-bearing invariants (e.g. the stdlib
  `kv-get` round-tripping `.pnet` with a solved strictness slot while its
  guard still yields `(none)`).
- **D4 is per-phase-sectioned** — put each phase's design, audit findings,
  rulings, censuses and test delta in **its own §5 section**, not in the
  tracker row.
