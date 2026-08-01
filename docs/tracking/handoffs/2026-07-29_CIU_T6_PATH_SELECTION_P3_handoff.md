# Handoff — CIU Track 6 Path Selection: the P3 co-design is COMPLETE; implementation opens at D4.P3a

**Date**: 2026-07-29 · **For**: a fresh session implementing **D4.P3a** (the
`expr-select` node + keyed blocks). Per `HANDOFF_PROTOCOL.org`.
**ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol**: read this handoff §1–§6 FIRST, then §2a Always-Load,
> then EVERY §2c doc **in full** — then **summarize your understanding back to
> the owner and let them validate it BEFORE starting work.**

> ⚠ **The surface was REDESIGNED 2026-07-28.** Anything phrased "dot extracts ·
> bracket selects · `:` iterates · `*` splats", or PS1–PS15, is the SUPERSEDED
> surface. The live law: **dot DESCENDS · brace SELECTS `x{…}` · `:`
> BROADCASTS · `^` RE-KEYS · `*` FLATTENS · `<` DISCLOSES.** The spec is a
> GUIDE, not a prescription; where it and D4 differ, **D4's recorded
> adaptation wins**, and an *unrecorded* divergence is a bug in D4.

---

## §1 — Current Work State (PRECISE)

- **Series / Track / Phase**: CIU → Track 6 Path Selection → **D4.P3a** (first
  of three slices of P3; Q_T5 split, forced ordering P3a → P3b → P3c).
- **HEAD at handoff write**: `569d7845` — ⚠ **re-derive with `git rev-parse
  HEAD`; a written coordinate goes stale the moment it is written** (three
  stale handoff coordinates this arc; one went stale within 2 commits).
- Local `main`, **MAIN CHECKOUT**. ⚠ If the session launches in a worktree,
  REMOVE it (owner ruling; it happened twice this arc — verify 0 unique
  commits + clean tree, `git worktree remove` + `git branch -d`).
- **Suite** GREEN **9370 / 475 / 0** (measured at P2 `3005170b`; docs-only
  commits since — verify with `git diff --name-only 3005170b..HEAD | grep
  '\.rkt$'` → expect empty). Acceptance **35/35**
  (`examples/2026-07-26-ciu-t6-path-selection.prologos`, gated by
  `tests/test-path-selection-acceptance.rkt`) + records **89/89**. `.pnet` v6.
- ⚠ **`origin/main` was PUSHED to `76214095` on 2026-07-29** (owner), so the
  unpushed set is SMALL — the docs commits since. An earlier draft of this
  handoff said "~49 unpushed", which was a stale model of remote state; verify
  with `git rev-list --count origin/main..HEAD`. **Still do NOT push unless
  directed.**
- **Working tree**: pre-existing **owner WIP only (41 entries) — LEAVE
  ALONE.** Stage EXPLICIT paths; verify with `git diff --cached
  --name-status` (never a `^[AM]` grep); **NEVER `git stash`**; NO
  Co-Authored-By; long messages via `git commit -F`.

### Progress Tracker (authoritative copy lives in D4)

| Phase | Status |
|---|---|
| P0 corpus · P1a retirements+seat · P1b-i/ii/iii seams · P2 ordinal `.N` | ✅ (`e2674208` · `859b529d` · `fc65ca54`/`1a1091d4`/`a6af2761` · `3005170b`) |
| **P3a — the node + KEYED blocks, no `^`** | ⬜ **← THIS SESSION** |
| P3b — the `^` family | ⬜ |
| P3c — keyless + L4 + honest nesting | ⬜ |
| P4 broadcast ω · P5 Ruling B · PX · P6 · X.close (PIR-gated) | ⬜ |

### NEXT IMMEDIATE TASK — D4.P3a, failing-test-first

**Read D4 §5.P3a — it is the work list.** In one line: mint
`surf-select`/`expr-select` (full pipeline.md § New AST Node cost, paid once),
parse the flat `$select-brace` payload into branches, type keyed blocks by
per-branch copattern demand under **D-lenient presence** (Q_T2), reduce with
the subject evaluated ONCE, run the **duplicate-output-key check BEFORE
`make-record`** (which silently last-wins otherwise), seat the
malformed-payload errors (empty block AHEAD of L4), refuse type position, and
emit branch-aware miss errors via `format-closed-row-miss`.

**Grounding: the P3 mini-audit ALREADY RAN** (`wf_2cef0199` was D5;
P3's is **`wf_27a84061-c7e`**, 7 facets + critic @ `76214095`, 13th
consecutive premise refuted) and its findings are folded into D4 §3/§5.P3.
**P3a opens with a LIGHT re-grounding only** (coordinate verification, the
key probes re-run) — NOT a fresh full audit. P3b/P3c likewise.

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always-Load**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
`ciu-t6-records.md` (**read the paragraph at the VERY END first** — the
mid-file ladder text is historical and marked as such) ·
`DESIGN_METHODOLOGY.org` (Stage-4 per-phase protocol) · `DESIGN_PRINCIPLES.org`
· `CRITIQUE_METHODOLOGY.org` · `HANDOFF_PROTOCOL.org` · `MASTER_ROADMAP.org` ·
CIU master `docs/tracking/2026-03-21_CIU_MASTER.md`.

**§2b rules** (auto-load; load-bearing for P3a): **`pipeline.md` § New AST
Node** (P3a pays it in FULL — note item 4 was corrected 2026-07-29: no
`definitely-not-map?` edit needed, coordinates re-pinned) + **§ Exhaustive
Walkers** (the generic transparent-struct fallback is the default; no binder in
`expr-select` ⇒ no depth routing) + **§ infer/inferQ are TWINS** (the lying
"Multiplicity violation" — P3a owes both arms, delegation model `cdb535ac`) ·
`testing.md` (targeted runner after ANY production edit; failing logs never a
re-run) · `workflow.md` (the 5-step gate; adversarial VAG; commits trigger
dailies) · `prologos-syntax.md` § Reader (both modes, always).

**§2c Session-Specific — READ IN FULL, IN THIS ORDER:**

1. **D4** `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md` — the
   Progress Tracker · **§3 the rulings ledger, ESPECIALLY the Q_T batch**
   (Q_T1–Q_T8, every P3 decision + its rationale) · **§5.P3 + §5.P3a/b/c**
   (the implementation shape — §5.P3a is THIS session's work list) · §2.3 the
   CARRIER TABLE · §Q8 (normative) · §8 risks (R6 as CORRECTED — no automatic
   PNET bump).
2. **The spec** `docs/research/2026-07-28_path-selection-spec.md` — §1.2 ·
   §3.3 (blocks + honest nesting) · §3.4 (`^`) · §3.6 (strict waypoint) ·
   §5.1–§5.2 (copattern typing) · §10.1 (the corpus P3a uncomments). Remember
   its standing: a GUIDE.
3. **The dailies** `docs/tracking/standups/2026-07-28_dailies.md` — STATE head
   + the last four LOG entries (P2, the Q_T rounds, the close).
4. `racket/prologos/examples/2026-07-26-ciu-t6-path-selection.prologos` — §B
   is P3's target block (tagged `[D4.P3]` plus the Q_T target rows; it does NOT
   carry per-SLICE tags — **§5.P3a/b/c's test deltas are the authoritative
   per-slice line lists**). §C's `{admins:name}` line and §B's `^_` line were
   both CORRECTED 2026-07-29 (P0-era transcription errors); §J is P2's landed
   section.
5. `racket/prologos/tests/test-path-selection.rkt` (the track file; P3a grows
   it) + `tests/test-path-selection-acceptance.rkt` (the marker gate — any
   mid-file uncomment renumbers, and the gate catches it).
6. `docs/tracking/DEFERRED.md` — CIU T6 items **9–14** (9 = the hint's
   cross-domain blindness · 11 = DISSOLVED to message quality by Q_T4a · 14 =
   the `spec` hole, WHY P3a ships its own type-position refusal).

---

## §3 — Key Design Decisions (do NOT revisit without census-grade cause)

The **Q_T batch** (all owner-ruled 2026-07-29, full rationale in D4 §3):

- **Q_T1 — ROUTE A**: mint `expr-select` NOW, grades-1-scoped. P5's spine
  identity needs a structured step representation; the error-surface argument
  REVERSES at the completed horizon (factored spellings + merge remedies need
  block context); option 2 is a strict prefix of option 3, so desugaring =
  one-phase scaffolding; ruling 4b had fixed the destination.
- **Q_T2 — presence: HORN D, LENIENT.** Select a field iff the subject's type
  SOURCES its presence as `'present`; `'unknown`-marked, unlisted-on-dyn, and
  `(Map K V)` subjects refuse loudly (the 4d remedy list:
  seal/validate/annotate). Result rows are closed all-`'present` HONESTLY
  (PS15), so "sealable, validatable" is true and the presence-blind seal is
  never asked to vouch for fabrication. **Probe fact**: dissoc on a CLOSED row
  simply REMOVES the field — `'unknown` exists only on dyn rows, so the
  corpus costs zero. The `.field`-vs-block asymmetry is DELIBERATE
  (exploration vs assertive construction).
- **Q_T3 — "level-local" = OUTPUT-level-local**: duplicate keys are checked
  AFTER `^`-splicing, on the keys that reach a result level. The syntactic
  reading ACCEPTS what Ruling B rejects — the one monotonicity break.
- **Q_T4a — `^` NEVER attaches to an ordinal** (no key to consume; non-local
  attachment rejected). Guided error naming the spelling `admins^first.0`.
- **Q_T4b — the `^` base rules**: output key = the branch's **surviving head
  key**; every `^` form acts **locally**; **rename is IN PLACE**
  (`server.host^h` → `{:server {:h …}}`); only dissolve removes a level; bare
  leaf `^` contributes the leaf VALUE as a keyless component. **`^_` =
  Reading N** (in-place, computed label).
- **Q_T7 — the `^-` collapse family IN SCOPE**: `h.k^-` → `{:k …}` ·
  `h.k^-k'` → `{:k' …}` · `h.k^-_` → `{:h-k …}` (flat provenance lives HERE,
  not in `^_`). Leading `-` after `^` is the collapse marker (a rename target
  starting with `-` is unsupported, eyes-open).
- **Q_T8 — parent-key collapse spelled `^..`** (NOT `^.` — probes confirmed
  the owner-flagged hazard twice: `a.b^.c` and `a.b^.0` with a missing space
  are silently IDENTICAL to legitimate mid-path dissolve forms; under `^..`
  both are LOUD). `ssl.enabled^..` ≡ `ssl^.enabled^ssl` → `{:ssl …}`;
  ancestors above the parent are kept. Edge: `^...` absorbs into `$rest` —
  the malformed seat rejects it.
- **Q_T5 — the split P3a → P3b → P3c**, ordering FORCED (splitter extends the
  payload parser; keyless needs bare-`^`). **Zero tokenizer changes in P3** ⇒
  no corpus A/B owed; gates = acceptance + targeted + suite + adversarial
  verify.

Standing from earlier batches, still governing: Q_R1 (`v[0]` ≡ `v.0`
byte-identical — do not break it) · the P2 two-tier principle (assertive
misses LOUD) · ruling 2c (type rows canonically sorted; values champ order) ·
Q_L2 (the sexp `.{` surface is FROZEN — `test-selection-paths.rkt` 56 cases +
`test-path-expressions.rkt` 20 must stay green untouched).

---

## §4 — Surprises (HIGHEST RE-DERIVATION RISK)

1. **`make-record` silently LAST-WINS on duplicate labels** (right-priority
   dedup, `{:a 1 :a 2}` → `{:a 2}` at 0 errors — probe-verified). The strict
   merge check MUST run before minting or the corpus negative passes silently.
2. **The `@[…]` literal collapses to PVec at EVERY homogeneous n**, not just
   n=1 (the homogeneity probe iterates under rollback). Both §B keyless lines
   are unreachable via literals — the nat-row mint is P3c's own machinery.
3. **The P1a NOT-YET gate has a HOLE at `spec`** (DEFERRED 14): `spec h
   cfg{version} -> Nat` is silently dropped at 0 errors AND registers its
   garbage datum (a following same-name `defn` error quotes the raw marker).
   Hits shipped `.`-access identically — pre-existing, filed, NOT P3's to fix,
   but WHY P3a ships its own type-position refusal.
4. **The `^_` acceptance line was an OLD-SURFACE import**: P0 transcribed the
   superseded "derive-ALL, flat" semantics into §B without the R5
   classification, and NO §10 example renames a leaf under a kept ancestor —
   the corpus could not discriminate in-place from collapsing. Corrected
   (`86f546b1`); the mechanism is recorded in D4 §3 so it cannot recur.
5. **A probe reshaped a ruling mid-deliberation**: dissoc-on-CLOSED removes
   the field outright (no `'unknown`), which collapsed Q_T2's case table.
   Also: a probe with a schema half HUNG at 2 min (the union-state BSP hang
   class is the suspect) — keep probes minimal, split them when they hang.
6. **§8 R6's PNET-bump obligation was FALSE** and one commit away from
   promotion into the ambient rules tier. New structs are additive
   (symbol-keyed tag table); a bump is owed only when an EXISTING shape's
   serialization changes.
7. **The fold-arm fixpoint requirement** (P1b-iii's BLOCKING class): the
   preparse fusion of `[base, $select-brace …]` must emit a NON-access-sentinel
   `$`-head, or re-entry swallows one more LEFT sibling per pass — silently.
   The baseless leg REMAINS as the "needs a subject" backstop.
8. **`pattern-var?` is the loud-if-missed site** for any new `$`-head: missing
   it makes the form inside a defmacro TEMPLATE a whole-file abort. Pin via
   macro USE, not registration (a registration-shaped pin stays green through
   the defect).
9. **State the layer with the measurement** — THREE layer-error strikes in one
   phase (`0e5a56a3`, `f6f30eaa`, P2's own comment). A "silent wrong answer"
   claim that is reader-layer-only will mis-frame a failing-test-first pin.

---

## §5 — Open / Deferred (named + owned)

- **DEFERRED 9** — the ordinal miss-hint's cross-domain blindness (`cfg.0` on
  a keyword row especially). Adjacent to P3a's error work; a one-line
  extension IF the owner wants it swept in, else leave.
- **DEFERRED 11** — DISSOLVED to message quality by Q_T4a; P3b's guided error
  covers it.
- **DEFERRED 14** — the `spec` hole (pre-existing; P3a refuses type position
  independently).
- **DEFERRED 5** — the `<`-adjacent grouper divergence: **P4's**, on the
  disclose surface.
- **P6 demand** — STAGED (4a); Route A keeps the door open (the node is the
  demand seat); the DECISION is due at P3 per §4, i.e. the owner should be
  checkpointed once blocks exist.
- **PX** — the binder-seam family (unannotated `defn` params fail for `.k`
  today; blocks on such params fail identically — that is PX's, not P3's).

## §6 — Process Notes

- **Racket**: `"/Applications/Racket v9.0/bin/racket"`; runner
  `tools/run-affected-tests.rkt --tests …`; probes `tools/run-file.rkt`
  (`--check` for acceptance); all from `racket/prologos/`. Manual `raco make`
  needs `PLT_CS_COMPILE_LIMIT=1000000`. `tools/check-parens.sh` after EVERY
  `.rkt` edit — **then COMPILE** (parens balance while arity breaks).
- **Failing-test-first**; the honest pin passes/fails for the reason its name
  claims (this arc produced a VACUOUS pin that matched digits in a temp-file
  path — assert on distinctive phrasing, never bare digits).
- **Adversarial verify before EVERY behavioural commit** — a BLOCKING catch in
  FIVE consecutive behavioural slices, none visible to a green suite. The
  adjudicator worktree-pins a baseline when a regression claim needs proving.
- **Owner co-designs in PROSE, one question per turn, with Q-labels** (batch
  letters used: L, M, N, R, T — next free letter for P3a's questions: **U**).
  The deliberative walk is load-bearing: it produced Q_T1's winning option and
  caught the Q_T4b misreading.
- **Per-phase 5-step blocking gate** (tests → commit → tracker → dailies →
  next) · commits trigger dailies (STATE overwrite + LOG append) · per-slice
  design/audit/rulings/test-deltas go in the slice's own D4 §5 section ·
  probes in the SCRATCHPAD, never the repo · full suite = regression gate ONLY
  (read `data/benchmarks/failures/*.log`).
- **The acceptance marker gate is live** (`test-path-selection-acceptance.rkt`)
  — mid-file uncomments renumber ~20 markers; land trailing markers first;
  the gate pins no-duplicate-indices.
