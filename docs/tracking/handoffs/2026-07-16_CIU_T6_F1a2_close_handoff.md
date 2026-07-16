# Handoff — CIU Track 6 F1: F1a.2 CLOSED (Open deleted, D1-b done); resume at F1b Stage-3 opening

**Date**: 2026-07-16 · **Author**: the session that ran F1a-col-3 → col-4 (col CLOSED) → the full F1a.2 arc (p0–p3, Open deleted).
**Resume target**: **F1b** — erasure-mode width + label-keyed depth, Map↔schema seal, the Q4/meta-refusal tightening pass, presence marks. **F1b is its OWN Stage-3**: it opens with research grounding + a design dialogue with the owner, NOT implementation. Do not write F1b code before that co-design happens.

> ⚠ On-disk is authoritative. RUN `git log --oneline -15` + `git status --short` FIRST. Re-verify every coordinate cited anywhere (they drift — this arc re-grepped stale spans three separate times).

---

## §1 Current work state (precise)

- **Series/Track/Phase**: CIU Track 6, phase F1. **F1a-core ✅ · F1a-col ✅ · F1a.2 ✅ — all CLOSED.** F1b ⬜ (next, own Stage-3). F-row ⬜ (inherits the §12.5 pins).
- **HEAD**: `088ddf7f` (docs: F1a.2 close) atop `4892fda3` (p3 refit) / `e4fad7d7` (p2 deletion) / `6a2bc9d5` (p1b flip) / `07c0e70f` (p1b-pre) / `bec0c058` (p1a) / `803a57e4`+`767bbcae` (p0) / `7d2019ad`+`a3b38e97` (col-4/close) / `f6716b3a` (col-3).
- **Suite**: GREEN **8682 / 455 / 0** (~130s healthy-ambient). **Acceptance**: `examples/2026-07-06-ciu-t6-f1-records.prologos` **78/78** via `tools/run-file.rkt --check`; suite-gated by `tests/test-f1-records-acceptance.rkt`.
- **`expr-Open` NO LONGER EXISTS.** `grep expr-Open racket/prologos/*.rkt` = 0 code hits (the syntax.rkt TOMBSTONE + historical comments only). PNET_VERSION = 2; no cache carries the tag.
- **What works end-to-end (WS)** — everything from the col handoff PLUS: bare `{}` : `{ | _}` (D17 keyword-committed empty dyn row); assoc chains grow EXACT rows (`[map-assoc [map-assoc {} :a 1] :b "s"] : {:a Int :b String | _}`); unknown-field projection on dyn rows mints a fresh meta (D19; displays `?metaN` — the Q4 posture); mixed-key literals type ⋃observed (`{"a" 1 "b" "x"} : (Map String <Int|String>)`, D18 via `expr-map-literal`); annotation escape hatch (`def m : (Map String V) := {}`) works; dynamic-key assoc keeps knowns + `'dyn`; dynamic dissoc/update-in → `{| _}` (D20); bare-union-typed defs type-check (the p0 three-checker fix).
- **Working tree**: pre-existing OWNER WIP ONLY (same ~15 tracked items + untracked owner files as the col handoff — standups, roadmap-`.md` deletions, `lib/examples/foray|foreign.prologos`, etc.). **LEAVE ALONE; stage only your files.** The "PRELUDE DRIFT DETECTED" runner warning is pre-existing owner-WIP-adjacent noise — non-blocking, do not "fix".
- Racket: `"/Applications/Racket v9.0/bin/racket"` (quoted); runner `cd racket/prologos && racket tools/run-affected-tests.rkt`.

## §2 Documents to hot-load (ordered)

**Always-load** (per HANDOFF_PROTOCOL.org §2a): `CLAUDE.md`+`CLAUDE.local.md`; `MEMORY.md` (memories: `ciu-t6-records` — updated through this close; `design-dialogue-preference`); `DESIGN_METHODOLOGY.org`; `DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org`; `HANDOFF_PROTOCOL.org`; `MASTER_ROADMAP.org`; CIU series master `docs/tracking/2026-03-21_CIU_MASTER.md`. Rules auto-load — internalize `testing.md` (the failure protocol was exercised heavily) and `pipeline.md` (this arc added TWO AST nodes and deleted one).

**Session-specific (read IN FULL, in order):**
1. **F1 design doc** — `docs/tracking/2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md` (~330 lines). §2 tracker (every row now ✅ through F1a.2, with per-phase commit notes); **§12 = the F1a.2 mini-design** (§12.2 disposition table — what each producer became; §12.3 the row-comparison semantics grid incl. meta-V-refused-from-dyn; §12.4 the per-op dyn table AS IMPLEMENTED; §12.5 the F-row pins + descope record; **§12.7 close notes** — read for the debt list F1b inherits); §11a–d the F1a/col history.
2. **Track doc** — `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` §2a: **D1–D20 locked** (rounds 1–5; round 5 = the F1a.2 decisions D16–D20) + the **OPEN Path-Selection surface notes** (postfix `coll[…]`, broadcast `coll.[…]`, result-shape crux — owner co-design required BEFORE any surface work).
3. **Dailies** — `docs/tracking/standups/2026-07-05_dailies.md` (checkpoints 1–9 = the whole F1 arc; 6–9 = F1a.2). The dailies file is LONG; checkpoints 5–9 suffice if pressed.
4. The syntax.rkt **tombstone** (grep `expr-Open — DELETED`) — the two-role history in situ.
5. For F1b research seeding: design doc §3b (the frontier-research synthesis — Tang erasure-mode width, seal-as-tabulation, monomorphic-seals-only) + `docs/research/2026-07-06_ROWS_COALGEBRA_PROPAGATOR_NOTE.md`.

## §3 Key design decisions (do NOT relitigate)

D1–D15 as in the col handoff (D15 = observational literal typing). **New this arc (round 5, owner-locked 2026-07-15):**
- **D16** — bare `'dyn` SYMBOL tail (bounds-free ★; zero carrier churn); **expr-Map SURVIVES** (key-domain cannot express `Map String V` — full Q_E(b) absorption = ONE future carrier change bundling bounds + key-domain generalization + Map dissolution); five-producer mint scope; degrades keep known fields; ONE comparison semantics (design doc §12.4) realized at two layers (pure fragment in subtype-predicate — its knowns-only check IS C_ConsL absorption; ctx/meta adapters in typing-core); solve-first absorption (structural: all row arms both-sides-concrete).
- **D17** — bare `{}` = keyword-committed empty dyn row (owner-SIGNED semantics change; string-keyed assoc onto unannotated `{}` now errors; the annotation form is the escape hatch and works). The commitment lives in the ROW's key-domain — the seed's K slot stays a META (see §4.4).
- **D18** — mixed-key literal value slot = `⋃observed` via the `expr-map-literal` literal-extent node; NO global Map-assoc widening.
- **D19** — projection on dyn = fresh meta ONLY; observation recording DESCOPED to F-row (pins at §12.5); unsolved projection metas DISPLAY as metas (Q4 — tighten at F1b, DEFERRED.md).
- **D20** — dynamic update-in AND dynamic dissoc on a record → `{| _}` (drop all facts — the only sound option pre-presence-marks); S9's `(Map Keyword Open)` degrade was never implemented and never will be.

## §4 Surprises and non-obvious findings (highest re-derivation risk)

1. **ROUTE SENSITIVITY is a standing probe discipline** (bit twice: col-4's `pvec-from-list-fn`, p0's union fix). Inline literals elaborate in CHECK mode (per-element against one meta — the C2 class); def-bound values go through infer + the α. Annotated defs re-check in typing-core; unannotated defs are re-checked ONLY by checkQ-top. **Always probe all four cells: inline/def-bound × annotated/unannotated** before any pin-vs-fix decision.
2. **The union-expected bug class lived in THREE checkers** (checkQ, typing-core check — found during verification) and was invisible because union results were only ever bare-eval'd in tests, never `def`'d. The fix shape after the p3 refit: branch split EXACTLY as it always was (left rollback-probed, right BARE), whole-union conversion via infer+unify on the BOTH-FAIL path only. Do NOT re-wrap the right branch — the p0 version's wrap paid a meta-snapshot+fork per successful right-branch check.
3. **Sequential bench invocations are NOT an A/B under long-session ambient.** The p3 close bench showed +9–19% "regression" that was ENTIRELY machine drift (15-hour session; bench CVs 3–9% vs ≤1% healthy; same-code A/B legs ±5%). The decisive instruments: pinned **worktree at the base commit benched in the same window** (the safe form of `bench-ab --ref` while owner WIP occupies the main tree) + **interleaved ABAB wall runs** + per-command PHASE-TIMINGS. The saved `f1a2-close*.json` benches carry this caveat — re-bench fresh before any cross-session comparison.
4. **The D17 seed's K slot must stay a META.** A concrete `(expr-Keyword)` breaks the annotation escape hatch through the tail-blind B1 empty-seed arm (it unifies ONLY the key types — `Keyword` vs `String` fails). Probe-caught pre-commit.
5. **qtt map-empty DELEGATES the type when the v-slot is a Record** (the S4 pattern): checkQ-top must see the ROW type; `(Map ?km row)` is rightly refused by the pure α key-gate (meta K). Also p0: **inferQ had NO expr-meta arm** — unsolved metas in type-arg positions tu-errored as spurious "Multiplicity violations" (checkQ-top's reporter is generic — a multiplicity error on a zero-variable expression = a misreported structural #f).
6. **D18's ⋃observed structurally cannot ride the assoc chain** (the seed pre-dates entry elaboration; a fresh-meta value slot breaks heterogeneous literals). The mechanism is the D15 literal-extent recipe — `expr-map-literal (keys vals chain)`, typed all-at-once, chain = runtime + usage-free in qtt (the col-2 double-count lesson).
7. **Engine topology**: subtype-predicate deliberately requires neither typing-core nor unify (and unify requires IT) — the "one engine" is ONE SEMANTICS at two layers, and the pure helpers' tail-blindness is DELIBERATE C_Cons absorption (documented in-place). classify's `'sub` goals are pure unify pairs, NO rollback, NO subtype kind — per-field `(or unify subtype?)` disjunctions are inexpressible as goals.
8. Still-load-bearing from earlier arcs: the pnet vector-impostor class (pipeline.md #6 — PNET_VERSION is now 2); coordinate drift (re-grep before trusting ANY doc/handoff line number); the stale-log failure category; `record-value-union` is now NON-EMPTY-BY-CONTRACT (it errors on empty — use `record-value-bound ctx rec`, whose empty-closed arm mints the Q6 fresh meta).

## §5 Open questions and deferred work

- **F1b (NEXT — own Stage-3, owner co-design FIRST)**: erasure-mode width + label-keyed depth subsumption (Tang §6 upcast-erasure posture; `subtype-predicate.rkt` still has no record-subtype judgment — D11 holds); **Map↔schema named monomorphic SEAL** (seal-as-tabulation, fill-or-error; §3b research); the **tightening pass** (Q4: unsolved projection metas currently display — candidates: zonk-final default-to-error or annotation-derived bounds; PLUS the engine's meta-V-refusal-from-dyn conservatism — same pass; DEFERRED.md entry); **presence marks** activation (dissoc-dynamic currently drops all facts, D20 — presence `'unknown` is the refinement); rank≤2 audit + weak-preservation docs per §3b. Opening protocol: research grounding (the §3b synthesis + fresh reads) → grounding audit → design options → owner dialogue → D-numbers.
- **F-row inherits the §12.5 pins**: per-command observation cell keyed `(row-id × label)` w/ hash-union + collision-unify; the ρ row-kinded-meta sketch; the bounded-tail Galois end-state (`'closed ⊐ (dyn K V) ⊐ (dyn K ?)`); the tail-blind-walker audit checklist.
- **Heterogeneous key-types design space** (owner-flagged, DEFERRED.md): strings/maps/arbitrary keys as first-class row key-domains — opens with the Q_E(b) carrier change, NOT before.
- **Path Selection = OPEN owner design conversation** (track doc §2a): postfix `coll[…]`, broadcast `coll.[…]`, result-shape crux. NOTHING built until that dialogue happens.
- Housekeeping at F1b opening: refresh `MASTER_ROADMAP.org` + CIU master rows for the F1a/col/F1a.2 closes (the workflow rule: design docs/PIR-level closes trigger roadmap updates); DEFERRED.md triage per workflow.md.
- Known-limit pins that stand: generic folds over ROW-typed lists value-stall (S10-at-list-level, CIU T3/T5's turf; `(List ⋃)` via to-list = the escape hatch); B3's degenerate cross-command stale-meta class; the mixed-key chain's zonk-unsolved value meta (harmless, displays only under `infer` of the raw chain).

## §6 Process notes / gates

- **Per-change gate** (unchanged, exercised ~10× this arc): `tools/check-parens.sh <f>` per `.rkt` → `raco make driver.rkt` → **PROBE-FIRST** (scratch `.prologos` via `tools/run-file.rkt` — caught FOUR pre-commit defects this arc: the Int-index value-stall, the D17 K-slot hatch break, the qtt map-empty gap, plus the col-4 route-sensitivity refutation) → targeted `--tests` → full `--all --force-rerun --no-precompile` (output→FILE; failures→`data/benchmarks/failures/*.log`; NEVER re-run to diagnose) → commit (`git commit -F -`, stage only your files, NO Co-Authored-By).
- **Bench discipline (NEW, §4.3)**: interleave or worktree-pin; never trust sequential bench windows on a loaded machine; PHASE-TIMINGS is the cheap per-command instrument.
- **The ladder pattern held** and is reusable: spec-table-first (§12.4 AS SPEC) → consumers-first dead-code-safe (p1a, "validated NOT deployed" marked honestly) → ONE atomic mint-flip + cache-version bump (p1b) → mechanical deletion (p2) → gate + close (p3). Negative differentiating probes (rejections the old mechanism structurally couldn't produce) are what make "the new arms are live" provable.
- **Owner dialogue** = PROSE, options in spaced blocks, Q_N labels; decisions get D-numbers in the track doc §2a. Design dialogue + novel-design implementation = MAIN-SESSION; grounding audits (`grounding-audit` workflow) + design options (`design-options-panel` workflow) delegable — both earned their keep repeatedly, AND both had findings refuted by main-session R-lens probes (the panel's from-list-fn adjudication; the audit's route claim in col-2). **R-lens-verify before trusting; probe both routes.**
- Dailies: `docs/tracking/standups/2026-07-05_dailies.md` is the living log (checkpoints 1–9); owner standups in `docs/standups/` are WRITE-ONCE.

---
*Handoff for the F1b opening. Resume: hot-load §2, verify §1 on-disk, then open F1b as a Stage-3 (research + grounding + options + OWNER CO-DESIGN) — not as implementation.*
