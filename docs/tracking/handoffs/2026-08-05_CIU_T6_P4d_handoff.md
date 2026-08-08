> # ⚠⚠ SUPERSEDED — DO NOT RESUME FROM THIS FILE
>
> Written 2026-08-05, when P4d had not started. **P4d slices 0, 1, 2, 3, 4a, 4a′,
> 4b and 4c have all landed since** (2026-08-06…08, latest `a31b7475`). Every
> load-bearing line below is now false: "P4d ⬜ not started" · "HEAD `7edefc1a`,
> 9 unpushed" · "suite 9906/485/0 · battery 365 · acceptance 69/69" ·
> "Q_U19 ⬜ RULING OWED" (RULED (A) 2026-08-07) · "broadcast works for PVec only"
> (it now works over PVec · Map · keyword-row · het tuple · union · closed
> schema) · and its scope list, of which four items shipped and one
> (`row-meet`) never existed as a symbol.
>
> **Current state**: the STATE head of
> `docs/tracking/standups/2026-08-07_dailies.md`, and D4 `§5.P4d`
> (`docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md`, anchor `#p4d`).
> Kept for provenance — §3's rulings and §4's surprises remain accurate history.

# Handoff — CIU T6 Path Selection: **BROADCAST IS LIVE**; P4d proper is next

**Date** 2026-08-05 · **For** a fresh session opening **D4.P4d** (the carriers).
Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

> **Hot-load**: read §1–§6 here, then every §2c doc IN FULL, then **summarize
> your understanding back to the owner and let them validate it BEFORE starting
> work.** (Protocol steps 5–6. "I have full context" means every §2 document
> read, every §3 decision articulable, every §4 surprise known.)

> The live surface law: **dot DESCENDS · brace SELECTS `x{…}` · `:` BROADCASTS ·
> `^` RE-KEYS · `*` FLATTENS · `<` DISCLOSES.** The spec is a **GUIDE**; where it
> and D4 differ, **D4's recorded adaptation wins.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track / Phase**: CIU → Track 6 Path Selection → **D4.P4d** (the
  carriers), ⬜ **not started**. P4c and P4d-0 are ✅ COMPLETE.
- **Design doc**: `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md` (~5.9k
  lines, ~100 stable anchors). **Link by anchor, cite by NAME, never by line
  number** — coordinates drifted and burned this track repeatedly.
- **HEAD at write**: `7edefc1a` — ⚠ **re-derive with `git rev-parse HEAD`**.
  **9 unpushed**; ⚠ **origin has advanced EXTERNALLY four times** across this
  arc (most recently the ARROW track merged at `2c7d97bd`, now an ancestor).
  Always `git rev-list --count origin/main..HEAD`.
- Local `main`, **MAIN CHECKOUT**. If a session launches in a worktree, verify 0
  unique commits and remove it.
- **Gate**: suite **9906 / 485 files / 0** · battery **365**
  (`grep -c '^(test-case' racket/prologos/tests/test-path-selection.rkt` —
  MEASURE, never derive) · acceptance **69/69** + 89/89 + 6/6 + 29/29 + 28/28.
  ⚠ `git diff <suite-commit>..HEAD -- '*.rkt'` is EMPTY, so the figure carries.
- **Working tree**: owner WIP only — **LEAVE ALONE.** Stage EXPLICIT paths ·
  verify `git diff --cached --name-status` · **never `git stash`** · no
  Co-Authored-By · long messages via `git commit -F`.

### Progress

| Phase / Question | Status |
|---|---|
| P0–P3 · P4a · P4b · P4c-1…P4c-4b | ✅ |
| **P4c-4c** (PVec ω value semantics + DEFERRED 43 + **G2**) `ae26f540` | ✅ |
| **P4d-0** (the `:{` mint + Q_U20 sub-inner lift) `77259635` | ✅ |
| **Q_U17** (Path segment = `Step`) · **Q_U18** (PRESERVE + G4) · **Q_U20** (sub-inner assembles) | ✅ RULED |
| **P4d** — the CARRIERS | ⬜ **← HERE** |
| **Q_U19** (`^`-on-broadcast) — **DUE AT P4d** | ⬜ RULING OWED |
| P4e · P4c-5 · PF · P5 · PX · P6 · X.close | ⬜ |

### NEXT IMMEDIATE TASK

**P4d — the carriers.** Broadcast works for **PVec only**; every other carrier
takes a guided per-command refusal naming P4d. The scope, from the sequencing
table (`#p4c-sequencing`) and the audit's corpus enumeration:

- **Map / keyword-row** (`regions:host` — corpus `:156`/`:344`, `strings:home`
  `:354`)
- **Het tuple** (`events:t` `:358`, `events:x` `:359`, `tree.entries:name` `:364`)
- **PVec-of-union + `row-meet`**
- **The Q_U9 List refusal + its guided error** — ⚠ **Q_U9 says "Implementation:
  P4d" TWICE**; it is NOT optional here and it is NOT earlier.
- **The corpus re-fate** — the six ω lines blocked on carriers, re-derived.
- ⚠ **Q_U19 comes due**: `^` on a broadcast is ALREADY CONSTRUCTIBLE and the
  existing pin **freezes an ACCIDENT, not a ruling**. It needs an owner ruling
  before the corpus lines it touches are re-fated.

**Open with the standard mini-audit** (`grounding-audit`), then co-design with
the owner. Do NOT start from this list — re-derive it; the audit for P4d-0
corrected the DEFERRED entries' own claims on four counts.

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
`memory/ciu-t6-records.md` (**the tail = live state**) · `DESIGN_METHODOLOGY.org`
· `DESIGN_PRINCIPLES.org` · `CRITIQUE_METHODOLOGY.org` · `HANDOFF_PROTOCOL.org` ·
`MASTER_ROADMAP.org` · the **CIU master**.

**§2b rules** (ambient; load-bearing here): `pipeline.md` (**§ "A Raise on the
Parse/Expansion Path Is a WHOLE-FILE Abort"** — this arc added the 5th and 6th
instances and guarded one of the two halves; **§ Exhaustive Walkers**) ·
`prologos-syntax.md` (the surface law) · `testing.md` · `workflow.md` (tracker
Notes are HEADLINES + a LINK; the anchor convention) · `on-network.md`.

**§2c Session-specific — IN FULL, IN THIS ORDER:**

1. **D4** — `#p4d-0` and `#p4c-4c-close` (what just landed and how) ·
   `#p4c-sequencing` (**THE SCHEDULE — read before proposing any ordering**) ·
   `#q-u20` · `#q-u19` (**the ruling owed at P4d**) · `#q-u9` (the List refusal,
   incl. its correction block) · `#q-u7` · `#q-u10` (the Map posture) ·
   `#q-u16b` · `#q-u17` · `#pf`.
2. `docs/tracking/DEFERRED.md` — CIU T6 items **31–55**. Live: 31, 33, 34, 35,
   38, 39, 40 (residual), 41, 44, 45, 47, **53**, **54**. Resolved this arc: 42,
   43, 46, 48, 55. Spun to chips: 50, 51, 52.
3. **Dailies — BOTH, and know which is which:**
   - `docs/tracking/standups/2026-07-28_dailies.md` (**1247 lines — THE CIU T6
     AUTHORITY**). STATE head + the last ~6 LOG entries, read **by TITLE** — the
     file interleaves arcs. ⚠ **It is far past the ~400–500-line roll cap; roll
     it when P4d opens** (a topic boundary), seeding the STATE head forward.
   - `docs/tracking/standups/2026-08-05_dailies.md` (**ARROW track — a DIFFERENT
     arc**, separate worktree, now merged to main at `2c7d97bd`). Read for
     environment context only. Notable: its P0 was **SUBSUMED** by this arc's
     preparse-seam guard (`ae26f540`) — a cross-arc confirmation that the
     class-level fix was the right call.
   - (`2026-08-02_dailies.md` is the closed out-of-band `loc->line` arc.)
4. Memory `memory/ciu-t6-records.md` — **the tail block**.
5. The spec: `docs/research/2026-07-28_path-selection-spec.md` — **§3.2.1 is in
   the SPEC, not D4** (a facet could not find it; the extent pair lives there).

---

## §3 — Key Design Decisions (RATIONALE; do NOT revisit without census-grade cause)

- **⭐ Q_U20 (owner, 2026-08-05)** — a **SUB-INNER ω ASSEMBLES AT 'block,
  ALWAYS**. The lift threads ONE sort and the two inner kinds need OPPOSITE
  ones: a symbol inner EXTRACTS ('path; 'block would wrap `xs:a` as
  `[PVec {:a T}]`), a sub inner ASSEMBLES ('block; 'path fails its one-component
  constraint). A per-inner-kind semantics RULE of the lift, not inherited from
  context. `users:{a b}` = a PVec of NARROWED ROWS.
- **⭐ G2 (owner, 2026-08-04)** — the enable-set is **RETIRED**; preservation is
  UNCONDITIONAL. It had zero production setters, so broadcast was reachable only
  from tests (*Validated ≠ Deployed*). Both its justifications had expired.
- **⭐ Option B (owner, 2026-08-05)** — the **preparse seam is GUARDED**: a raise
  in the per-form pass becomes `($preparse-error msg)` → a per-command error.
  Chosen over enumerating directive heads because *"an enumeration leaves the
  next sentinel to rediscover the class"*. ⚠ **The PARSE half is still
  unguarded — DEFERRED 53, its own slice.**
- **⭐ DEFERRED 48 (owner, 2026-08-05)** — the whole-node abort stays **UNIFORM**
  across tiers. The tier is **INFERRED, not written**, so per-tier abort would
  make identical source behave differently on something invisible in it.
  Accepted cost, named: on a permissive carrier, broadcast loses data `pvec-map`
  would keep.
- **DEFERRED 43 (folded into P4c-4c)** — the strictness tier follows the ω
  unwrap. Scoped by measurement: non-ω nesting never had the bug, because NEST
  gives every level its own node and tier.
- **The `:{` mint WRAPS** (`($bcast-step ($select-brace …))`) and keys on the
  colon **GLUED ON BOTH SIDES**. The naive `memq` widening yields a DEGENERATE
  datum; base-adjacency alone breaks `def b: [List Nat]`.
- **Q_U18** — unknown-head → PRESERVE; grant G4. **Q_U17** — a Path segment is a
  first-class `Step` value (slice **PF**, before P5). **Q_U9** — `:` refuses over
  `List`; **implementation at P4d**.
- **Next free Q-label: U21.**

---

## §4 — Surprises and Non-Obvious Findings (HIGHEST RE-DERIVATION RISK)

1. **⭐⭐ EVERY GREEN GATE WAS BLIND TO THE CLASS THAT MATTERED — THREE TIMES.**
   G2's blocker (fused directive keywords → whole-file aborts) and P4d-0's two
   (top-keys splicing a sub inner's keys → a `symbol<?` abort; `unwrap-bcast-step`
   → a binder `:{` **silently defined a garbled Pi at 0 errors**) all passed the
   full suite, all five acceptance files AND the corpus A/B — because **nothing
   in the tree spelled the hazard**. The mini-audit measured both P4d-0 drifts
   BEFORE implementation; the adversarial verify turned them into reproducers.
   **Keep both stages.** A green suite is not evidence for a class no file spells.
2. **⚠ CONVERTING RAISES TO VALUES MAKES TEST-HELPER DESIGN LOAD-BEARING.**
   Option B changed the channel for every preparse raise (20 assertions, 9
   files) — and two failed for a reason that *could not exist under a raise*:
   `functor-for` returns a registry lookup and discards results; `run-last`
   returns `(last (run s))` while the refusal lands on the FIRST form. **Any
   helper that narrows the result set can now swallow a refusal and go green.**
   A sweep is UNCLAIMED (noted in DEFERRED 53).
3. **⚠ THE ARC'S RECURRING FAILURE — asserting a mechanism instead of measuring
   it.** ~7 false claims in comments and 4 vacuous pins this arc (two comparing
   a call to ITSELF), plus a wrong live diagnosis (an Emacs lock file blamed for
   a 10 GB runaway — it raises cleanly; the real cause was a harness looping a
   corpus in ONE process; the compiler is flat at 134 MB). **The reader datum is
   not the semantics. Measure, pin the measured datum, mutation-test anything
   claiming to discriminate.**
4. **A fact has a timestamp.** "A bare top-level ω is STRIPPED under every grant"
   was TRUE when recorded and FALSE one commit later (the PRESERVE flip), after
   it had already re-scoped a slice. **Re-derive; do not inherit.**
5. **DEFERRED entries can COLLIDE.** 40 and 46 were the SAME defect filed twice
   with CONFLICTING fixes and no cross-reference, and 39's prescribed fix
   COMPOSED with 40's into a whole-file abort. Adjudicated at `2692a958`. When
   two entries name the same helper, read both before acting on either.
6. **`bcast-step-trigger?`'s second consumer is a BEHAVIOURAL NO-OP** — the tree
   grouper's arm is byte-identical to its own `[else]`. "Both groupers share the
   predicate" is true of the DEFINITION only. (The new `:{` twin IS real —
   it fuses, because that mint is count-changing.)
7. **A drift copy survives**: `prev-token-reader-form-head?` is not exported, so
   `surface-rewrite.rkt` hand-inlines it — the F1b.7g class, sibling left behind.
8. **Corpus A/B hygiene**: the ONLY minting file is `foray.prologos`, which is
   **owner WIP** — so `--snapshot-inputs` measures a corpus WITHOUT the feature
   (a false all-clear across 304 files). Use `tools/corpus-ab.rkt` (code pinned
   per leg, **working-tree inputs**, one subprocess per file with caps) and
   ALWAYS carry a control file that cannot mint.
9. **The targeted runner ABORTS `test-path-selection.rkt`** (~65 s, over its
   30 s cap; `--timeout` does not help). Use
   `racket -e '(require (file "…/tests/test-path-selection.rkt"))'` for the track
   file, the runner for the neighbourhood.

---

## §5 — Open Questions and Deferred Work

- **⬜ Q_U19 — DUE AT P4d.** `^` on a broadcast: refuse, or re-key the broadcast
  output? Already constructible; **the existing pin freezes an ACCIDENT.**
- **⬜ DEFERRED 53** — the CLASS-level **parse-path guard**, its own slice. Three
  HEAD-reachable reproducers recorded. ⚠ Sweep for result-discarding test
  helpers FIRST (§4.2).
- **⬜ DEFERRED 54** — goal-position `:{` yields a silent `unknown` row.
  PRE-EXISTING class (the dot sibling behaves identically) — routed to the
  51/52 chip.
- **⬜ PF** — Q_U17's `Step` + `Cont` ADTs, the `path-segments` repair (same
  change), the 11-consumer migration. **Before P5.**
- **Live DEFERRED**: 31, 33, 34, 35, 38, 39, 40 (residual — its raise
  prescription is SUPERSEDED; value-channel only), 41, 44, 45, 47.
- **Chips running independently**: `task_204859b9` (defmacro fused annotations —
  PRE-EXISTING, not a G2 leak) · `task_4c00d3f0` (DEFERRED 51 + 52, the
  G2-surfaced relational regressions).

---

## §6 — Process Notes

- **Racket** `"/Applications/Racket v9.0/bin/racket"`; manual `raco make` needs
  `PLT_CS_COMPILE_LIMIT=1000000`. `tools/check-parens.sh` after EVERY `.rkt`
  edit, **then COMPILE**. All tooling runs from `racket/prologos/`.
- **`tools/corpus-ab.rkt`** is THE corpus A/B runner (added `ae26f540`). Do not
  hand-roll one — two hand-rolled harnesses reached 9.7 GB / 9.0 GB.
- **Mini-audit opens every sub-phase** (`grounding-audit`); **adversarial verify
  before EVERY behavioural commit** — it found BLOCKING defects in both slices
  of this arc, including several claims of mine it refuted outright. Budget for
  both. **R-lens-verify anything load-bearing yourself.**
- Failing-test-first, and **a pin must fail for the reason its name claims** ·
  mutation-test any pin claiming to discriminate · full suite = regression gate
  ONLY · per-phase 5-step gate · commits trigger dailies (STATE overwrite + LOG
  append) · per-slice records in that slice's D4 §5 section · tracker Notes are
  HEADLINES + a LINK (160–800 chars) · probes in the SCRATCHPAD, never the repo.
- **Owner co-designs in PROSE, ONE QUESTION PER TURN.**
- **Do NOT write a handoff or Relay Note unless the owner explicitly asks.**

**FIRST MOVE**: re-verify HEAD / suite / battery, read §2c, then **summarize your
understanding back to the owner before starting work.**
