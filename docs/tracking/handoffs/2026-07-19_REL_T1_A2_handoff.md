# Handoff — Rel Track 1 Aspect-A (NAF fix), resuming at A.2b

**Date**: 2026-07-19 · **Handoff for**: a fresh session to open **A.2b** (tabling
worldview-preservation) as its own Stage-3 design. Per `HANDOFF_PROTOCOL.org`.

---

## §1 — Current Work State (PRECISE)

- **Series / Track**: Rel Series → **Track 1, Relational Language Usability**.
- **Design doc**: `docs/tracking/2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`
  (Aspect-A core LOCKED = E-with-B; §5 A.2 + A.2b are the load-bearing sections).
- **HEAD**: `cb0fb1e4` (`feat(Rel T1 A.2 core): per-binding NAF belief-clear for fact generators`).
  Chain: `cb0fb1e4` A.2 core ← `80a2963d` A.1 ← `860248bf` P0 ← `9caf0ca5` lock ←
  `680e0146` design artifact ← `b1e881c7` interval open.
- **Suite**: GREEN **8927 / 466 / 0**. **Working tree**: pre-existing OWNER WIP only
  (foray.prologos, standups, deleted MASTER_ROADMAP.md/LANGUAGE_VISION.md, example
  edits) — LEAVE ALONE; all my work is committed.
- **Progress tracker** (from the design doc):

  | Phase | Status | |
  |---|---|---|
  | P0 acceptance | ✅ | `examples/2026-07-19-rel-t1-acceptance.prologos` (3 NAF faces) |
  | A.1 top-level echo | ✅ | `expr-not-goal?` arm in reduction.rkt's 3 runners → `solve-single-goal` |
  | **A.2 core** | ✅ | `naf-per-binding-mask` (relations.rkt); FACT-generator `{both}` repro fixed |
  | **A.2b** | ⬜ **NEXT** | **tabling worldview-preservation** (root cause found; DFS-defer REJECTED) |
  | A.3 static floundering | ⬜ | range-restriction in `install-conjunction` |
  | A.4 guard | ⬜ | crash residuation + static floundering |
  | B / C / D + polish | ⬜ | Aspects still in design |

- **NEXT IMMEDIATE TASK**: open **A.2b as its own Stage-3 design** — grounding →
  options → adversarial critique — on making **tabling preserve per-branch
  worldviews** so on-network NAF is correct over tabled (rule/recursive) generators.
  Do NOT DFS-defer.

---

## §2 — Documents to Hot-Load (ORDERED)

**Always-load** (skim if fresh): `CLAUDE.md` + `CLAUDE.local.md`; `MEMORY.md` +
[[rel-t1-relational-usability]]; `DESIGN_METHODOLOGY.org`; `DESIGN_PRINCIPLES.org`;
`CRITIQUE_METHODOLOGY.org`; this protocol; `MASTER_ROADMAP.org`;
`docs/tracking/2026-07-19_REL_MASTER.md`. Rules auto-load (internalize on-network.md,
propagator-design.md, structural-thinking.md, stratification.md, testing.md, workflow.md).

**Session-specific (READ IN FULL)**:
1. `docs/tracking/2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md` — the Stage-3
   design. **§5 A.2 (settled E-with-B) + §5 A.2b (ROOT CAUSE + owner ruling)** are the
   crux. Progress tracker at §2.
2. `docs/tracking/standups/2026-07-19_dailies.md` — the STATE head + LOG (the full
   arc: grounding → options-panel → probes → lock → P0 → A.1 → A.2 core → A.2b root
   cause). The last two LOG entries are A.2 core + A.2b root cause.
3. **The code** — for A.2b, read (verify line numbers at HEAD first):
   - `relations.rkt` `install-clause-propagators` (:2425) → the **tabling** dispatch
     (:2451-2467); `install-table-producer` (:2727), `install-table-consumer` (:2687)
     — where per-branch worldviews are flattened.
   - `relations.rkt` `process-naf-request` (~:181) + `naf-per-binding-mask`
     (just above it) — the A.2-core E-with-B mechanism that A.2b must feed.
   - `relations.rkt` `dissolve-solver-pu` (:2766) — the tagged-entry enumerator +
     `bitmask-visible?` filter (the belief-layer read A.2b must keep honoring).
   - `atms.rkt` `solver-assume` (:255, per-branch bit), `solver-state-with-worldview`
     (:588, belief-subset write), `solver-state-solve-all` (:658, DEAD compat shim).
4. `docs/tracking/2026-07-19_REL_SOLVE_TYPING_NOTE.md` — the seed (its `&>`-inversion
   framing is SUPERSEDED; see §4).

---

## §3 — Key Design Decisions (RATIONALE)

1. **Aspect-A NAF fix = E-with-B (belief-layer per-binding narrowing).** Generalize
   the S1 handler's single-shared-bit worldview-cache AND-NOT to per-binding: enumerate
   the generator's tagged bindings, test the negation per binding, clear
   `(OR failing-bits) & ~(OR passing-bits)`. *Why*: NAF/guard have ALWAYS belief-narrowed
   the derived worldview-cache (the established idiom); a NAF contradiction IS a belief
   statement; belief-narrowing coexists with dissolution + belief-subset enumeration.
   *Rejected*: **Option D (existence-narrowing `decisions-state`)** — a bigger,
   first-of-its-kind unexercised change that would re-fire the projection and clobber
   belief-subset enumeration; the "narrow the primary is purer" premise was refuted by
   the code (the idiom is belief-narrowing). **Option A (fresh `solver-amb` bits)** —
   intrinsic dual-bit, principle-dominated by B; unneeded (no computed enumerating
   generator exists). **Option C (compound nogood)** — nogoods aren't projected into
   worldview-cache. **Option G (anti-join)** — deferred detection optimization (§5.G).
2. **DFS-defer REJECTED (A.2b) — the principled fix is tabling worldview-preservation.**
   *Why*: deferring rule/recursive NAF to the DFS solver is off-network scaffolding; the
   mantra + "all solvers (DFS/NAF/WF) correct" require on-network NAF correct for EVERY
   generator shape. So A.2b fixes the ROOT (tabling flattens worldviews), not the symptom.
3. **NTT model = for/fold over the pending set in the S1 VALUE-tier handler** (NOT a
   broadcast — that was a category error for nested-scheduler between-round work);
   parallelism is a deferred scheduler-layer concern.
4. **A.1 scope = the `not` arm only** — the reachable top-level solve grammar is
   app/rel/unify/is/not; guard/cut/conjunction are clause-body-only (no dead arms).

---

## §4 — Surprises & Non-Obvious Findings (HIGHEST-RISK to get wrong)

1. **`&>` is the rule-clause separator (Prolog `:-`), NOT a guard/negation operator.**
   The seed note's "`&>` inversion bug" is REFUTED/SUPERSEDED. The real bug is the
   on-network NAF **single-bit COLLAPSE** (over the generator var) → `{both}` /
   `{neither}` / partial-drop.
2. **A.2b ROOT CAUSE — tabling flattens per-branch worldviews.** Rule subgoals
   (recursive or not) go through tabling; the producer reads args via `logic-var-read`
   (worldview-filtered → collapsed) and writes a flat untagged tuple; the consumer
   writes under ONE worldview. So a tabled generator's output var has NO per-branch
   tags. This is a GENERAL seam (not NAF-specific) — any on-network feature needing
   per-branch structure over a tabled relation hits it.
3. **belief-vs-existence is a deliberate architectural split** (atms.rkt:583-596):
   `decisions-state` = which assumptions EXIST; `worldview-cache` = which are BELIEVED
   (a possible SUBSET). NAF/guard belief-narrow the cache directly. E-with-B lives here.
4. **`solver-state-solve-all` is DEAD CODE** (compat shim, no production caller) — the
   free-var solve enumerator is `dissolve-solver-pu`, which HONORS the belief-clear via
   `bitmask-visible?`. The E-with-B contingent-clobber is UNREACHABLE (value-tier handler,
   no post-clear decisions-state write, no S0 restart).
5. **"recursion is correct" was a coincidental single-element test.** All free-var
   on-network NAF is buggy (fact/rule/recursive); only GROUND queries (0 query-vars →
   DFS) are correct. The P0 acceptance caught this.
6. **The generator-shape probe:** the ONLY enumerating goal kind is `app` (facts +
   rules); no `member`/`between` builtin exists. Fact generators tag per-row (distinct
   retractable bits); rule/recursive don't (tabling — #2).

---

## §5 — Open Questions & Deferred Work

- **A.2b (NEXT)**: tabling worldview-preservation — table-cell format + producer
  projection + consumer re-tag; blast radius = dissolution, memoization, WF. Its own
  Stage-3 (grounding → options → critique). *Design questions to open*: does the table
  carry (worldview . tuple) pairs? Does the consumer re-tag under each answer's
  worldview? Interaction with memoization/tabling-correctness + the WF engine?
- **A.3** static floundering gate (range-restriction in `install-conjunction`) —
  independent of A.2b, smaller.
- **A.4** guard: FFI-crash residuation (reuse discrimination residuate-on-bot) + static
  floundering; guard's own per-binding leak (S0 fire-once shape ≠ NAF's S1) — scope TBD.
- **Aspects B/C/D + polish** — still in design (typed rows keying Q-B; schema-as-facts;
  fact-representation research Stage 0/1; dedup / `_anon` keys / declaration-order keys).
- **Deferred to UCS**: `?v:Type` CLP domain-constraint *resolution* (static reading only here).

---

## §6 — Process Notes

- **Per-change gate**: `check-parens` → `raco make driver.rkt` → PROBE-FIRST via
  `tools/run-file.rkt` (from `racket/prologos/`) → targeted `--tests` → full `--all`
  → commit (`git commit -F -`, stage ONLY my files, NO Co-Authored-By). Runner is at
  `racket/prologos/tools/run-affected-tests.rkt` (run from `racket/prologos/`).
- **Conversational cadence**: checkpoint at each phase boundary; the owner sets pace.
- **Grounding-audit-as-opener** + **independent options-panel** for high-stakes forks,
  then **R-lens-verify** the load-bearing claims surgically (main session), then
  **owner co-design** (prose + Q_N labels; NOT AskUserQuestion chips —
  [[design-dialogue-preference]]).
- **NTT model REQUIRED** + SRE lattice lens for the propagator/tabling A.2b design.
- **Premise-refutation discipline** (this arc, 5×): always run the independent
  critique/probe BEFORE locking a design premise — the main session was confidently
  wrong 5 times, each caught by a panel/probe/acceptance.
- **A tracked design that completes GETS a PIR** (objective trigger; mandatory `X.close`).
