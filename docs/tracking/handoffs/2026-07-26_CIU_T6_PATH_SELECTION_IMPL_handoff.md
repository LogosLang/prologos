# Handoff — CIU Track 6 Path Selection: IMPLEMENTATION (P2.b →)

**Date**: 2026-07-26 · **For**: a fresh session continuing the Path Selection
implementation at **P2.b**. Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol**: read this handoff §1–§6 FIRST, then §2a Always-Load, then
> EVERY §2c doc **in full** — then **summarize your understanding back to the owner
> and let them validate it BEFORE starting work.**

> This is a **Stage-4 IMPLEMENTATION session** on a SETTLED design. The surface spec
> is design §5.9 (PS1–PS15) **as amended by §5.10 (the ✏ deltas WIN)**. Do NOT
> re-open settled rulings without census-grade evidence; per-phase protocol =
> mini-audit → failing-test-first → the 5-step completion gate → checkpoint.

---

## §1 — Current Work State (PRECISE)

- **Series / Track**: CIU Series → **Track 6**, Path Selection. Design **D.2 + full
  D.3 adjudication**: [`2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`](../2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md)
  (spec §5.9 + §5.10 deltas; conversation record §5.4–§5.8; grounded facts §3;
  prior art §4). Critique record:
  [`2026-07-26_CIU_T6_PATH_SELECTION_D3_CRITIQUE.md`](../2026-07-26_CIU_T6_PATH_SELECTION_D3_CRITIQUE.md)
  (adjudication CLOSED; 12 refuted findings retained — do not re-litigate).
- **HEAD**: `eac74bd6` · **Suite** GREEN **9164 tests / 472 files / 0** (measured at
  `ad75e57a`; docs-only since) · branch `main`, ahead of origin — **don't push unless directed**.
- **Working tree**: pre-existing **OWNER WIP only** (~41 entries: modified
  standups/examples incl. `lib/examples/foray.prologos`, deleted `MASTER_ROADMAP.md`/
  `LANGUAGE_VISION.md`, untracked LATTICE_/LAVAMOAT_/pldi/quantale files). **LEAVE
  ALONE.** ⚠ Stage explicit paths; verify with `git diff --cached --name-status`
  (NEVER a `^[AM]` grep — it hides D-rows). **NEVER `git stash`** (two owner stashes
  live). NO Co-Authored-By. Long commit messages via `git commit -F <file>`.
- ⚠ **A CONCURRENT session is running** the spawned task "Fix `<` swallowing lines
  inside `.( )` mixfix" (task_43ece3f8) — it may land changes to
  `parse-reader.rkt`. Check `git log` for its landing before P3 reader work; if it
  landed, the audit examples' `lt`/`le` conversions (P1) can optionally revert to
  mixfix `<`/`<=`.

### Progress Tracker (design §2 — the authoritative copy is in the design doc)

| Phase | Status |
|---|---|
| G grounding + prior art · S surface co-design · D.3 critique + adjudication | ✅ |
| P0 acceptance file (`examples/2026-07-26-ciu-t6-path-selection.prologos`, 21/21 `--check`) | ✅ `f47851a5` |
| P1 `.{` retired COMPLETELY + 4 audit examples repaired | ✅ `d18648f0` |
| P2.a Int gate + pvec guard + ground-expr? fallbacks + broadcast-get whnf | ✅ `ad75e57a` |
| **P2.b the loud-miss family — RULED (c), THE TWO-TIER PRINCIPLE** | ⬜ **← NEXT** |
| P3 reader/lexer (`.N` · `.:.`/`.:[` · `*` · retirement censuses · sexp form) | ⬜ |
| P4.a–d the selection node + typing (P4.d `v.i` cuttable) | ⬜ |
| PX binder-seam bugs (lambda-adoption hole + standalone-def seam) | ⬜ |
| P5 iteration `:` + keyword-projection `map :name users` | ⬜ |
| P6 migrations + supersessions | ⬜ |
| X.close — bench matrix · DEFERRED triage · doc-truth · memory fold · **PIR gates ✅** | ⬜ |

### NEXT IMMEDIATE TASK — implement P2.b (ruled round 7, spec in design §5.10)

**The two-tier principle**: assertive tier (`map-get`/`.field`/`v[k]`) = a failed
runtime lookup is a LOUD, COUNTED, panic-shaped error; honest tier
(`nil-safe-get`/`nth`/`kv-get`) unchanged. Implementation constraints (all
probe-grounded by the P2 mini-audit `wf_2c99bc25-940`, LOG entry in dailies):

1. **The runtime miss arm is TYPE-BLIND** (rows and dicts share the champ) → carry
   loudness via an **elaboration-time strictness mark on Map-typed subjects**;
   dyn-ROW misses keep D19's permissive display (pinned at
   `test-route-soundness-01.rkt:196` + records acceptance ;;77 — MUST NOT break).
2. Sites: map-get champ miss `reduction.rkt:2670-2675` · expr-get rrb OOB
   `:2698-2704` · list OOB `:2706-2713` · pvec-nth stuck-OOB `:2765-2771` ·
   pvec-update OOB `:2773-2780` · pvec-pop-on-empty `:2796-2798`. (Coordinates at
   `ad75e57a` — re-grep.)
3. `[map-get tup 1N]` on a PRESENT position **projects** (value agrees with typing);
   OOB = loud. (Likely via a dedicated rrb-subject arm in map-get's whnf.)
4. The loud realization is **panic-shaped and TOP-NODE-BOUNDED** (driver converts
   `expr-panic` → counted `prologos-error` at `driver.rkt:774-780` — top node only;
   nested misses print, count 0 — accepted + NAMED, the D22 precedent). A Racket
   raise would CRASH the file (no handler at the reduce seam) — not an option.
5. Break set: exactly 2 pins flip (`test-map.rkt:124-127`, `:137-143`). Failing
   tests FIRST in `tests/test-path-selection.rkt` (the track file, grown per phase).
6. Doc-truth rider: `examples/map-tutorial-demo.prologos` teaches error-on-miss 3×
   (:103, :143, :246-247) — (c) makes it TRUE; verify the wording still matches.
7. Option-wrap is REJECTED-WITH-REASON (census in §5.10 round 7) — do not re-open.

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always-Load**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
[[ciu-t6-records]] (carries the full ladder status) · `DESIGN_METHODOLOGY.org`
(**Stage 4 per-phase protocol**) · `DESIGN_PRINCIPLES.org` · `CRITIQUE_METHODOLOGY.org`
· `HANDOFF_PROTOCOL.org` · `MASTER_ROADMAP.org` · CIU master
(`2026-03-21_CIU_MASTER.md` — NOTE the real filename; a prior handoff cited a
nonexistent `2026-03-28_` name).

**§2b rules** (auto-load; the load-bearing ones HERE): `pipeline.md`
(§ Exhaustive Walkers — P2.a just used it; infer/inferQ twins) ·
`prologos-syntax.md` (§ Reader — P3's both-modes census discipline) · `testing.md`
(failing-test-first; the failure-log protocol; never re-run the suite to diagnose) ·
`workflow.md` (the 5-step gate; adversarial VAG).

**§2c Session-Specific — READ IN FULL, IN THIS ORDER:**

1. This handoff §1–§6.
2. **The design doc** — §5.9 THEN §5.10 (the deltas WIN; round 7 = P2.b's spec;
   round 6b = the standalone-def seam), §2 (tracker), §3 (grounded facts).
3. **The D.3 critique** — at least the Top-5, D3-B1/B2, and the Refuted appendix.
4. **The dailies** `docs/tracking/standups/2026-07-26_dailies.md` — STATE head +
   the LOG entries for P0/P1/P2.a/P2.b (they carry the mini-audit findings and
   near-misses; the P2.a entry has the census numbers).
5. `tests/test-path-selection.rkt` — the track's test file (14 cases; grow it).
6. `examples/2026-07-26-ciu-t6-path-selection.prologos` — the acceptance file
   (21 markers; §B/§C/§D/§E targets commented per phase).

---

## §3 — Key Decisions (do NOT revisit without census-grade cause)

- **PS1–PS15 (§5.9) as amended by §5.10.** The law: *dot extracts · bracket
  selects · `:` iterates · `*` splats*. Keyword keys = identities; nat keys =
  positions (renumber dense). Mixed assembly = static error. `^`/`^name`/`^_` on
  the key-generating segment; `^_` = full-path kebab-join derive (+ derive-ALL on
  splats). Collision + miss = loud static errors. Brackets 100% literal; dynamism
  is dot-only (`v.i`, P4.d). `v[0]` re-targets to `⟨elem⟩` with extraction at
  `v.0` (P3 `.N` lexing + census). `m[:a]` RETIRES. Selection results are ordinary
  closed rows (sealable/validatable/def-storable, presence SOURCED not fabricated).
- **Keyword-projection replaces dot-sections** (owner, D.3 round 6): `map :name
  users` via a CHECK-mode coercion arm — zero reader work; `.name`/`.[sel]`
  sections are WITHDRAWN (they never lexed — the fold absorbs the preceding token).
- **P2.b = the two-tier principle** (owner, round 7 — §1 above).
- **PX widened** (owner, round 6b): the lambda-adoption hole + the standalone-def
  seam (`def add5 := [+ 5 _]`, `[int+ 5 _]`, `[fn [r] r.name]` — all fail at the
  def-RHS, all work in argument position; the annotated def is the current hatch).
- **v1 adds ZERO propagators/cells** (§7; do-not-churn — the M-lens verifier
  ruled the escalation a category error). NTT model becomes mandatory at the
  future dedicated-selector node.
- **§9 supersessions**: CIU T2 items 2+4 superseded, item 1 landed in P2.a
  (`expr-union` ground-ness), item 3 = P3's prerequisite; T3 re-chartered later.

## §4 — Surprises (HIGHEST RE-DERIVATION RISK)

1. **The mini-audit refutes-or-rescopes EVERY phase's premise** (streak intact:
   F1b 7/7, P2 5-for-5). Never implement from the design row without the audit.
2. **P2's five**: the leg-3 repro needed a `(Map K V)`-TYPED subject (records are
   already loud) · PVec OOB is TWO divergent silent legs + two unenumerated
   siblings · the `none` degradation arm deliberately serves mixed-type unions ·
   the panic seam is TOP-NODE-ONLY (probe-pinned) · pvec-nth's discipline relied
   on the very gate being widened (suite-invisible without the new pins).
3. **Probing before ruling** — 5th+ data point this arc (the PS11 "probe-verified"
   annotation that wasn't; the census reversing the Option adjudication).
   PROMOTION OVERDUE: fold into the two-tier rule docs at the next close.
4. **`check-parens` cannot catch balanced-but-arity-broken edits** (the empty
   `(register-token-pattern!)` near-miss) — compile-before-test is the real gate.
5. **Champ/rrb tries store entries in raw VECTORS** — generic struct descent must
   handle vector+pair spines (`expr-substructs-all?` does now).
6. **`<` inside `.( )` silently swallows following lines** (form-extent scanner
   counts `<` as an opener) — the concurrent chip session is fixing it (§1 ⚠).

## §5 — Open / Deferred (named + owned)

- P2.b implementation detail left open: the exact strictness-mark mechanism
  (elaboration flag on `expr-map-get` vs a distinct node) — mini-audit it; the
  D22 seal-forcing + validate plan-bake are the in-tree precedents.
- P4.d `v.i` is CUTTABLE if it drags (Q_S1's `get` hatch loses nothing).
- The trait-op standalone-def case (`[+ 5 _]`) may need Num-T2/F-row defaulting —
  honest residue in PX; annotated-only fallback acceptable.
- Deferred with slots (PS13): ranges (owner's own future CIU track) · `**` ·
  splat respellings · nil-safe selection · omit-selectors · the write direction
  (read-only v1; source-overlap disjointness = the write phase's headline).
- Filed separately: `map-size`/`map-has-key` constant-rule unsoundness (§3.7).

## §6 — Process Notes

- Racket: `"/Applications/Racket v9.0/bin/racket"`; runner
  `tools/run-affected-tests.rkt` (targeted mode after ANY production edit); probe
  runner `tools/run-file.rkt` (`--check` for acceptance); all from
  `racket/prologos/`. Manual `raco make` needs `PLT_CS_COMPILE_LIMIT=1000000`.
- `tools/check-parens.sh <file>` after EVERY `.rkt` edit — then compile (the §4.4
  near-miss class).
- Probes in the scratchpad, NEVER the repo. Owner co-designs in PROSE with Q_N
  labels. Commits trigger dailies (STATE overwrite + LOG append). The
  grounding-audit workflow is the default phase opener; refute-by-default.
- Full suite = regression gate ONLY (read `data/benchmarks/failures/*.log`, run
  individual tests; the guard script blocks blind re-runs).
- Assert on every programmatic replacement (two prior incidents; a third — an
  unexpanded `$(git rev-parse)` in a heredoc — this arc).
