# Handoff — CIU T6 Path Selection: **P4e-1a IS COMPLETE**; P4e-1b (the `*` semantics) is next

**Date** 2026-08-11 · **For** a fresh session opening **D4.P4e-1b**.
Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

> **Hot-load**: read §1–§6 here, then every §2c doc IN FULL, then **summarize your
> understanding back to the owner and let them validate it BEFORE starting work.**
> (Protocol steps 5–6. "I have full context" means every §2 document read, every
> §3 decision articulable, every §4 surprise known.)

> The live surface law: **dot DESCENDS · brace SELECTS `x{…}` · `:` BROADCASTS ·
> `^` RE-KEYS · `*` FLATTENS · `<` DISCLOSES.** The spec is a **GUIDE**; where it
> and D4 differ, **D4's recorded adaptation wins.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track / Phase**: CIU → Track 6 Path Selection → **P4e** (the `*`
  family) → **P4e-1a ✅ COMPLETE**; **P4e-1b ⬜ not started**.
- **Design doc**: `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md` (~8.1k
  lines, ~100 stable anchors). **Link by anchor, cite by NAME, never by line
  number** — coordinates drifted and burned this track repeatedly.
- **HEAD at write**: `e5e6cbe7` — ⚠ **re-derive with `git rev-parse HEAD`**.
  **6 unpushed**; ⚠ origin has advanced EXTERNALLY several times across this arc
  (the owner pushes). Always `git rev-list --count origin/main..HEAD`.
- Local `main`, **MAIN CHECKOUT**. If a session launches in a worktree, verify 0
  unique commits and remove it.
- **Gate**: suite **10143 / 488 / 0** (`--all --force-rerun`, `[488/488]`) ·
  battery **476** (`grep -c '^(test-case' racket/prologos/tests/test-path-selection.rkt`
  — MEASURE, never derive) · acceptance **84/84** (diff-verified, not eyeballed).
- **Working tree**: owner WIP only — **LEAVE ALONE.** Stage EXPLICIT paths ·
  verify `git diff --cached --name-status` · **never `git stash`** · no
  Co-Authored-By · long messages via `git commit -F`.
- **Registers**: DEFERRED **next free 113** · **next free Q-label U38**. Allocate
  from the register in `DEFERRED.md` § NUMBERING, never `max(heading)+1`.

### Progress

| Phase | Status |
|---|---|
| P0–P3 · P4a–P4d · P4c-5 | ✅ |
| **P4e-0 slice A** (the `postfix-star` TOKEN TYPE) `e7a49228` | ✅ |
| **P4e-0 slice B** (R4 tokenizer repair) `0e007864` | ⛔ BUILT · VERIFIED · **REVERTED** (DEFERRED 105) |
| **P4e-1a-i** (arrival matrix + rebuilt gate) `ff9b7d81` | ✅ |
| **P4e-1a-ii** (Tier-O arms, inert) `dc458109` | ✅ |
| **P4e-1a-iii** (rename + fuse + refusals) `9cac0099` | ✅ (**attempt 1 reverted** at `bd2c3575`) |
| **Q_U36** (positive-list fuse) · **Q_U37** (territory-scoped refusal) | ✅ RULED |
| **P4e-1b** — the `*` SEMANTICS | ⬜ **← HERE** |
| P4e-2 (`.*` ravel, Q_U26) · `*_` provenance (Q_U24) · P4c-5 · PF · P5 · PX · P6 · X.close | ⬜ |

### NEXT IMMEDIATE TASK

**P4e-1b — make `*` MEAN something.** P4e-1a delivered the *surface*: `xs:{a}*`
and `c{a}*` now reach a guided **"(flatten) is not implemented yet"**; everything
outside selection territory is refused, guided. 1b is the semantics behind that
message — [Q_U23](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u23): `*` deletes
the layer the preceding step created.

⚠ **TWO OBLIGATIONS COME DUE WITH IT, both recorded and neither optional:**

1. **The Map ruling.** Q_U23 claims the nominal-join collision "needs no P5
   machinery, because P3a already landed strict merge". **REFUTED, measured**:
   `make-record`'s body is `;; last write wins` (`syntax.rkt`), and
   `dup-output-key` / `mixed-sorts?` fold over **written** branches at parse time
   (`parser.rkt`), so the landed gate structurally **cannot see subject-derived
   keys**. A star over a `Map` needs an owner ruling: refuse, or defer to a
   runtime merge?
2. **The `.*` retirement inventory.** Q_U23 retires `.*` as row-splat with **no
   inventory taken** of what consumes it. Known consumers measured during 1a-i:
   `wildcard-seg?` (`elaborator.rkt`, plus capability-subsumption and a selection
   wildcard error) and two `parser.rkt` sites keyed on `'*` / `'**`.

**Open with the standard mini-audit** (`grounding-audit`), then co-design with the
owner. Do NOT start from this list — re-derive it; every audit this arc corrected
the design doc's own claims.

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
`memory/ciu-t6-records.md` (**the live-state block = current truth**) ·
`DESIGN_METHODOLOGY.org` · `DESIGN_PRINCIPLES.org` · `CRITIQUE_METHODOLOGY.org` ·
`HANDOFF_PROTOCOL.org` · `MASTER_ROADMAP.org` · the **CIU master**
(`docs/tracking/2026-03-21_CIU_MASTER.md`).

**§2b rules** (ambient; load-bearing here): `pipeline.md` (**§ "A new sentinel, an
old recognizer"** — ⚠ its abort claim was CORRECTED at `79e34380`, read the
correction; **§ Exhaustive Walkers**) · `prologos-syntax.md` (the surface law) ·
`testing.md` (⚠ the intermittency + the `scratch-run.sh` discipline) ·
`workflow.md` (tracker Notes are HEADLINES + a LINK; the anchor convention) ·
`on-network.md`.

**§2c Session-specific — IN FULL, IN THIS ORDER:**

1. **D4** by ANCHOR — `#p4e-1a` (**the three slices + BOTH attempt records; the
   resume context**) · `#q-u37` (**the ruling that unwound attempt 1**) ·
   `#q-u36` · `#q-u23` (**the target semantics, incl. the refuted strict-merge
   claim**) · `#q-u35` · `#q-u31` · `#q-u26` (`.*` ravel) · `#q-u24` (`*_`
   provenance) · `#star-census` · `#p4e-0-a3` (slice A + its three verify rounds).
2. `docs/research/2026-08-09_STAR_SURFACE_CENSUS.md` — **the design's measured
   input** (860 lines; Tiers A–D/G/O). ⚠ Its **Tier-O O7** (conditional/recursive
   membership) is what Q_U36 discharges; its **MISS 3** (the carrier population is
   11, not 4) is what the arrival matrix now encodes.
3. `docs/tracking/DEFERRED.md` — **101** (the unspellable carriers — the design gap
   itself) · **103**'s undischarged sibling · **104** · **105** (R4 not
   independently landable) · **106–112** (this arc's filings; see §5).
4. **Dailies**: `docs/tracking/standups/2026-08-11_dailies.md` (**current, the
   STATE head**) and `2026-08-10_dailies.md` (**LOG xxvi–xxix = the whole P4e-1a
   arc**, read for the surprises).
5. `racket/prologos/tools/star-arrival-matrix.rkt` — **the enumeration artifact**;
   both the dump and the battery READ it. Run it: `racket tools/star-arrival-matrix.rkt`
   from `racket/prologos/`.

---

## §3 — Key Design Decisions (RATIONALE; do NOT revisit without census-grade cause)

- **⭐⭐ Q_U37 (owner, 2026-08-11) — THE REFUSAL IS DECIDED IN TERRITORY.** The fold
  fuses ONLY in selection territory and otherwise **leaves the star in place** for
  the seat that owns the territory: `parse-datum` (expression → Q_U35's message),
  `unwrap-angle-type` (type → the add-a-space message), the quote/quasiquote
  lowerings (data → captured as the `*` the user wrote). It is Q_U34's own logic
  extended one layer in.
- **⭐ Q_U36 (owner, 2026-08-11) — THE FUSE ARM IS A POSITIVE LIST** over the
  PREDECESSOR (`star-fusable-heads` = `$select`/`$select-path`), with Q_U35's
  refusal as a genuine `else`. It discharges the census's ⭐BLOCKING **Tier-O O7**
  by never asking whether the STAR is a member — it asks about a *different datum*.
  Rejected: enumerate the non-selection heads (the six carriers D4 omitted are the
  standing proof that side is not knowable in advance).
- **The fuse WRAPS** — `c{a}*` → `($select-path ($select c a) $postfix-star)`, one
  carrier per LEVEL, so the star arrives as an ITEM of the enclosing selection and
  `segment-select-items` produces `star-not-yet-message` **for free**. ⚠ The
  emitted head must NOT be an `access-sentinel?` member or
  `preparse-expand-subforms` re-enters and swallows a LEFT sibling (the P1b-iii
  defect: a silently dropped `defn` clause at zero errors).
- **Q_U31's refusal RIDES the rename**, it cannot precede it: glued and spaced
  Sigma were datum-identical until the rename, and family 2
  (`param-type->angle-type`) SYNTHESIZES its `$angle-type` at preparse, so a
  reader-seated refusal structurally cannot reach it. ⚠ The live family-2 route is
  the **spec** spelling (`spec g ([List Nat]* Nat) -> Int`), NOT the defn spelling
  — the defn form dies at a generic shape check first.
- **Error ECHOES render the user's spelling** (`unmint-star-for-echo`, macros.rkt),
  while `pp-datum` deliberately prints the INTERNAL name. Same symbol, opposite
  obligations: an echo is source read back; a printed post-preparse datum
  containing the sentinel IS the defect.
- **DEFERRED 108's abort set is 19** and is PINNED as a measured snapshot. The fuse
  retired two (`match-scrut/{select-brace,bcast-brace}`). An intermediate cut
  measured 13 by *shielding* six more with the wrong mechanism; those returned
  when Q_U37 removed it — honest, and their fix belongs to `compile-match-tree`.

---

## §4 — Surprises and Non-Obvious Findings (HIGHEST RE-DERIVATION RISK)

1. **⭐⭐ THE INSTRUMENT CAN SHAPE THE CODE, AND THAT IS A DEFECT.** Slice 1a-i's
   gate asserted *"no unconsumed star survives PREPARSE"*. Satisfying it forced the
   fold to refuse at preparse-**everywhere** — which **PRE-EMPTED the Sigma seat**
   (Q_U31's guided refusal shipped **structurally unreachable**, green under every
   gate) and **broke the quasiquote lowering**. One wrong assumption, two symptoms;
   two patches would have been two workarounds. The fix was a RULING (Q_U37).
   **When an instrument and the design disagree, ask which is wrong first.**
2. **⭐ THE OBSERVABLE WAS WRONG, NOT MERELY NARROW.** 1a-i's first gate grepped
   user-visible output for `$postfix-star`; simulating the rename showed it could
   fire in only **72 of 190** cells — in the rest, clean and planted output is
   **byte-identical**, because an unconsumed sentinel is an EXTRA DATUM and the
   form fails on SHAPE before anything renders the symbol. Coverage is now stated
   as measured (datum 187/220 · message 92/220 · union 208/220), not claimed total.
3. **⭐ A FALSIFIED RATIONALE DOES NOT LICENSE REVERSING THE DECISION IT WAS
   OFFERED FOR.** `datum-subst-list`'s splice arm is justified by an invariant
   `$postfix-star` (the first bare-symbol sentinel) falsifies — so I "completed"
   the fix and turned an existing pin red. The raise is a RULING (`446070fc`); only
   its stated reason was wrong. **Grep for a pin before completing someone's fix.**
4. **⭐ THE ERROR-ECHO SEAT IS INVISIBLE TO A CONTEXT-INDEXED GATE.** The rename
   changed what two messages echoed back (`*` → `$postfix-star`) in **def-name** and
   **fn-binder** positions — neither is an "arrival context", so the matrix-indexed
   leak pin structurally could not see them. **When a datum is renamed, sweep the
   sites that ECHO SOURCE, not just the sites that consume it.**
5. **`pipeline.md` WAS STALE AND AMBIENT.** It said a `pattern-var?` miss makes
   `'[1 2]` in a `defmacro` template a whole-file abort *today*. Measured: it yields
   `v : [List Int]` at 0 errors — DEFERRED 3 was discharged at `446070fc`.
   Corrected at `79e34380`, which also added: **INVOKE the macro when testing a
   template** (a `defmacro` only defined never runs `datum-subst` — that is how the
   stale claim survived).
6. **The generating matrix did not exist.** D4's "40 of 44 across ELEVEN contexts"
   was true and *unfalsifiable* — the generator was never committed. Regenerated:
   the real surface is **11 minting carriers × 19 arrival contexts**, and the
   census had said "the population is 11, not 4" **one day earlier**, in the
   document D4 cites as its input.
7. **Verify rounds do not converge quickly.** Slice A took three (each finding a
   defect in the previous round's FIX); 1a-iii took a reverted attempt plus two
   rounds. Every one under a green battery + acceptance + neighbourhood.
8. **⚠ THE SUITE IS ~16% INTERMITTENT AND PRE-EXISTING.**
   `racket/prologos/data/benchmarks/timings.jsonl` (note: under `racket/prologos/`,
   not repo root) records 470 full-suite runs: **74 with `all_pass=False`**, and
   `test-properties.rkt` is randomized (13 cases in 412 runs, 8 in 57), so a ±5
   swing is NORMAL. **Query it BEFORE any base A/B.** Never compile while a suite
   is in flight.
9. **The corpus A/B is a NULL INSTRUMENT for the star.** Every closer-glued `*` in
   the corpus is inside a COMMENT — one live occurrence tree-wide. A green corpus
   A/B here proves nothing; say so rather than citing it.

---

## §5 — Open Questions and Deferred Work

- **⬜ Q_U23's Map ruling** — due at P4e-1b (see §1). Refuse, or runtime merge?
- **⬜ The `.*` retirement inventory** — due with Q_U26/P4e-2.
- **Filed this arc**: **106** (the `let` nested-shorthand sentinel leak — bounds
  Q_U35's blast-radius claim) · **107** (carrier+star in PATTERN position, unruled;
  Q_U32 covered only BARE `*` and its refusal never landed) · **108** (a trailing
  `*` in pattern/match-scrutinee position is a WHOLE-FILE ABORT — 19 cells, PINNED;
  the `pattern-pos` half is DEFERRED 103's sibling) · **109** (a selection sentinel
  in a `spec` type region mis-fuses with `$angle-type` as its subject, and the seam
  prints raw SYNTAX OBJECTS) · **110–112** (the pipe-terminal fused star; the
  wrong-seat messages; the star-free `$facts-sep` leak).
- **Live DEFERRED**: 31, 33, 34, 35, 39, 40-residual, 41, 44, 54, 56, 57, 58, 62,
  63, 65, 75/76, 77–84, 88, 89, 91, 92, 93–101, 104, 105, 106–112.
- **⬜ PF** — Q_U17's `Step`/`Cont` ADTs + the `path-segments` repair. **Before P5.**
- **Chips running independently**: `task_204859b9` · `task_4c00d3f0` ·
  `task_e1c15ee6`.

---

## §6 — Process Notes

- **Racket** `"/Applications/Racket v9.0/bin/racket"`; manual `raco make` needs
  `PLT_CS_COMPILE_LIMIT=1000000`. `tools/check-parens.sh` after EVERY `.rkt` edit,
  **then COMPILE**. All tooling runs from `racket/prologos/`.
- ⚠ **The targeted runner ABORTS `test-path-selection.rkt`** (~75 s vs its cap) —
  use `racket -e '(require (file "…/tests/test-path-selection.rkt"))'` for the track
  file, the runner for the neighbourhood.
- ⚠ **Probes: `tools/scratch-run.sh`, one file per process, never a loop in one
  process** (two hand-rolled harnesses once reached 9.7 GB). Reap afterwards.
- **Mini-audit opens every sub-phase** (`grounding-audit`); **adversarial verify
  before EVERY behavioural commit, and AGAIN if the slice widens.** Budget for the
  second and third round — this arc has never had one round suffice.
- **R-lens-verify anything load-bearing YOURSELF.** Failing-test-first, and a pin
  must fail for the reason its name claims · mutation-test any discriminating pin ·
  **count ERROR as well as FAILURE** · full suite = regression gate ONLY
  (`--all --force-rerun`) · per-phase 5-step gate · commits trigger dailies (STATE
  overwrite + LOG append) · per-slice records in that slice's D4 §5 section ·
  tracker Notes are HEADLINES + a LINK (160–800 chars).
- **Owner co-designs in PROSE, ONE QUESTION PER TURN, WITH WORKED EXAMPLES.**
- **Do NOT write a handoff or Relay Note unless the owner explicitly asks.**

**FIRST MOVE**: re-verify HEAD / suite / battery, read §2c, then **summarize your
understanding back to the owner before starting work.**
