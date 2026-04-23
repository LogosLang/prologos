# PPN Track 4C Phase 9+10+11 Addendum — T-2 + Step 2 + Remaining Addendum Handoff

**Date**: 2026-04-22 (end of substantial session arc)
**Purpose**: Transfer context from this session into a continuation session. This session arc delivered: T-3 T3-C3 re-audit + Commits A/A.2-a/A.2-b/A.2-c/B (4 staged T-3 commits), PPN Track 4D vision research, charter-alignment re-sequencing, 1A-iii-a-wide Step 1 substrate migration (5 sub-phase commits + docs), T-1 scaffolding-retirement-plan documentation. Queue-next is **T-2 (Map type inference open-world realignment)**.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user.

**CRITICAL meta-lessons carried forward from this session**:

1. **Four "accidentally-load-bearing mechanism" findings** total across the addendum. Two of four (B6, S1.a) surfaced by INTEGRATION-TEST FAILURES during migration, not static audit. Strong codification candidate: *Stage 2 audits for API migrations must include integration-test runs, not just static site enumeration.*

2. **Charter alignment as a new design filter**: tactical cleanup tracks should be framed against end-state architecture, not as local optimizations. T-1's scope collapsed from "new API design" to "documentation-only pass" once this filter was applied. Codified in D.3 §7.5.10.

3. **Role A vs Role B decomplection pattern** (T-3 legacy): accumulate-via-set-union (Role A, `type-lattice-merge`) vs enforce-equality (Role B, `type-unify-or-top`). Applied as template throughout the addendum.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C Phase 9+10+11 Addendum — substrate + orchestration unification (per D.3)
- **Phase**: Phase 1A (substrate migration) — T-3 Role A/B decomplection + 1A-iii-a-wide Step 1 DELIVERED; T-1 DELIVERED; **T-2 NEXT**
- **Stage**: Stage 4 Implementation (per DESIGN_METHODOLOGY.org per-phase protocol)
- **Design document**: D.3 at [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md)
- **Last commit**: `b7f8e58d` (T-1 documentation pass)
- **Branch**: `main`
- **Working tree**: clean (benchmark + cache artifacts modified, not production)
- **Suite state**: 7908 tests, 126.7s, 1 pre-existing batch contamination (`test-facet-sre-registration` — passes individually; unrelated to T-3/Step-1/T-1; confirmed via stash test during T-3 Commit B validation)
- **Probe baseline**: `data/probes/2026-04-22-1A-iii-baseline.txt` (28 expressions, 0 errors). Probe diff = 0 across all session commits.

### Progress Tracker snapshot (D.3 §3, post-T-1)

Key post-T-3, post-Step-1, post-T-1 rows:

| Sub-phase | Status | Commit |
|---|---|---|
| T-3 mini-design | ✅ | `9c3172e0` |
| T-3 Stage 2 audit | ✅ (INCOMPLETE → extended via T3-C3 §7.6.14) | `6fddc5f7` |
| T-3 Commit A (Role B migration + helper) | ✅ | `37aaba2b` |
| T-3 T3-C3 re-audit | ✅ (§7.6.14) | includes 3 staged A.2 commits |
| T-3 Commit A.2-a (architectural C1 fix) | ✅ | `a5a33a71` |
| T-3 Commit A.2-b (helper + B1/B2) | ✅ | `f85dd50a` |
| T-3 Commit A.2-c (B3/B4/B5) | ✅ | `105bcdae` |
| T-3 Commit B (set-union fallthrough + B6 + tests) | ✅ | `e07b809f` |
| **T-3 COMPLETE** | ✅ | 4 commits A→B |
| Charter-alignment re-sequencing | ✅ | `16bddd26` |
| Track 4D proposed | ✅ | `4812892c` |
| 1A-iii-a-wide Step 1 Sub-phase S1.a (+4th LB finding fix) | ✅ | `3b6aefdb` |
| 1A-iii-a-wide Step 1 Sub-phase S1.b | ✅ | `2c8871ec` |
| 1A-iii-a-wide Step 1 Sub-phase S1.c | ✅ | `d220ca51` |
| 1A-iii-a-wide Step 1 Sub-phase S1.d | ✅ | `9f47ffe9` |
| 1A-iii-a-wide Step 1 Sub-phase S1.e | ✅ | `b1468220` |
| **1A-iii-a-wide Step 1 COMPLETE** | ✅ | §7.5.11 + dailies close (`c5dc11dc`) |
| **T-1** (documentation-only) | ✅ | `b7f8e58d` |
| **Path T-2** (Map open-world realignment) | ⬜ **NEXT** | — |
| **1A-iii-a-wide Step 2** (PU refactor) | ⬜ | vision-advancing capstone |
| Phase 1B (tropical fuel primitive) | ⬜ | |
| Phase 1C (canonical BSP instance) | ⬜ | |
| Phase 1V (VAG) | ⬜ | |
| Phase 2A/B/V (orchestration) | ⬜ | |
| Phase 3A/B/C/V (union types + hypercube) | ⬜ | |
| V (capstone + PIR) | ⬜ | |

### Next immediate task

**T-2 mini-design audit per Stage 4 Step 1 protocol.**

Per D.3 tracker T-2 row:
> Reframed 2026-04-22. T-3 + open-world may land `_` value type by default; verify typing-core.rkt:1196-1217's explicit `build-union-type` becomes redundant OR migrate to `_` per ergonomics. Mostly mechanical post-Step-1.

**Key questions for T-2 mini-design** (preview surfaced end-of-session, user hasn't seen yet):
1. Does T-3's set-union merge now subsume the explicit `build-union-type` at map-assoc's widening else-branch (typing-core.rkt:1211-1217)?
2. What's the "open-world `_`" migration per Prologos ergonomics principle — should `{:name "alice" :age 30}` infer to `(Map Keyword _)` (open-world wildcard) rather than `(Map Keyword Int | String)` (narrow union)?
3. If migrating to `_`, what about `with-speculative-rollback` at map-assoc (:1205) — does it become entirely unnecessary?

**Expected T-2 scope**: mostly mechanical. Small code changes or none at all. Documentation-heavy if we confirm redundancy without migrating to `_`.

### Acceptance criteria for T-2 close

- Probe (`examples/2026-04-22-1A-iii-probe.prologos`) diff = 0 against baseline OR expected diff documented and architecturally justified
- `test-mixed-map.rkt` passes (mixed-map value-widening path)
- `test-union-types.rkt` passes including canary at :234 (`(infer <Nat | Bool>) = [Type 0]`)
- Full suite regression check
- D.3 tracker + dailies updated per per-phase completion protocol

---

## §2 Documents to Hot-Load (ORDERED)

**CRITICAL**: read every document IN FULL. No skimming.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org)

### §2.1 Always-Load

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md)
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — Stage 4 Per-Phase Protocol especially
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — especially Correct-by-Construction + Decomplection + Hyperlattice Conjecture
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — P/R/M/S lenses
5a. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) — updated 2026-04-22: MASTER_ROADMAP.org + current series master now in Always-Load
5b. [`docs/tracking/MASTER_ROADMAP.org`](../MASTER_ROADMAP.org) — **NEW in Always-Load** (2026-04-22). ~25K tokens. Single source of truth for all series/tracks/design docs/PIRs. For "how it all connects" orientation.
5c. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md) — **current series master** for this track (PPN). Read this for the PPN-series narrative through Track 4C + Track 4D proposed.

### §2.2 Architectural Rules

6. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — design mantra
7. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE, Module Theory Realization B
8. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — cell allocation efficiency (PU heuristic)
9. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — per-commit dailies discipline
10. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — diagnostic protocol
11. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md)
12. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md)
13. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 Session-Specific — THE DESIGN DOCUMENTS (READ IN FULL)

14. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — **D.3, THE addendum design**. ~1400 lines. New/updated sections this session:
    - **§3 Progress Tracker** (updated multiple times — reflects post-T-1 state)
    - **§7.5.10** (NEW) "Charter alignment — re-sequencing post-T-3" — codifies the tactical-framing-against-end-state principle
    - **§7.5.11** (NEW) "1A-iii-a-wide Step 1 summary (2026-04-22) — DELIVERED" — full Step 1 VAG + commits + 4th finding detail
    - **§7.6** (T-3 subsections) — Role A/B decomplection, Commit A-B structure
    - **§7.6.14** "T3-C3 re-audit results" — Categories A (migrated), B (B1-B5 Role B sites), C (C1 architectural), L (legitimate)

15. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — **PPN 4C parent design**. 2222 lines. Read §1 Thesis, §2 Progress Tracker, §6.3 CHAMP retirement (Phase 4 — our immediate follow-on), §6.10 Union types via ATMS (Phase 10), §6.1.1 Provenance O3, §6.11 SRE lens, §6.15 Phase 3 mini-design (already complete, but context for T-2 Map work).

16. [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) — **NEW this session**. ~300 lines. Proposes PPN Track 4D (post-PPN-4C). Vision-stage research note tying the 3-accidentally-load-bearing pattern to the larger attribute-grammar unification architectural goal. Context for why the addendum's scope is what it is.

### §2.4 Session-Specific — Related Tracking Docs

17. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md) — PPN Series Master. Updated this session with Track 4D entry + "PPN 4C Phase 1A-iii-a-wide Step 1 + T-1 (2026-04-22)" design-input section for Track 12 handoff.

18. [`docs/tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`](../2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) — PM Series Master. Updated this session with T-1 handoff: PM Track 12 now has THREE unlocks from PPN 4C (1e-α, 1e-β-iii, **1A-iii-a-wide Step 1 + T-1**). Light cleanup sub-phase spec for `with-speculative-rollback` retirement added.

19. [`docs/tracking/DEFERRED.md`](../DEFERRED.md) — updated with "PM Track 12 design input from PPN 4C Phase 1A-iii-a-wide Step 1 + T-1 (2026-04-22) — `with-speculative-rollback` retirement" entry under Off-Network Registry Scaffolding section.

20. [`docs/tracking/MASTER_ROADMAP.org`](../MASTER_ROADMAP.org) — Track 4D entry added this session (item 13).

### §2.5 Session-Specific — THE PRIMARY CODE FILES FOR T-2

21. [`racket/prologos/typing-core.rkt`](../../../racket/prologos/typing-core.rkt) **lines 1196-1217** — `expr-map-assoc` typing rule. THE site T-2 analyzes. Current code:
    ```racket
    [(expr-map-assoc m k v)
     (let ([tm (infer ctx m)])
       (match tm
         [(expr-Map kt vt)
          (cond
            [(not (check ctx k kt)) (expr-error)]
            ;; Value fits existing value type — no widening needed
            ;; Phase 5: speculative rollback with network fork/restore
            [(with-speculative-rollback
               (lambda () (check ctx v vt))
               values
               "map-value-widening")
             (expr-Map kt vt)]
            ;; Value doesn't fit — widen via union
            [else
             (let ([tv (infer ctx v)])
               (if (expr-error? tv)
                   (expr-error)
                   ;; whnf resolves solved metas so build-union-type
                   ;; sees concrete types, not raw meta references
                   (expr-Map kt (build-union-type (list (whnf vt) tv)))))])]
         [_ (expr-error)]))]
    ```
    T-2 question: is the `else` branch's explicit `build-union-type` redundant post-T-3 (set-union merge at cell level already unions)? Is the whole speculation redundant if we migrate to open-world `_`?

22. [`racket/prologos/type-lattice.rkt`](../../../racket/prologos/type-lattice.rkt) — post-T-3 state. Set-union merge at line 159 (`[else (build-union-type (list (resolve-top v1) (resolve-top v2)))]`). `type-unify-or-top` helper for Role B. Both exported.

23. [`racket/prologos/elaborator-network.rkt`](../../../racket/prologos/elaborator-network.rkt) — post-S1.a state. `elab-fresh-meta` at :114-139 uses `tagged-cell-value` + `make-tagged-merge type-unify-or-top` + custom contradicts? wrapper. `identify-sub-cell` at :337-358 uses `type-unify-or-top` as merge-fn for structural sub-cells.

24. [`racket/prologos/elab-speculation-bridge.rkt`](../../../racket/prologos/elab-speculation-bridge.rkt) — post-T-1 state. Restructured module docstring with ARCHITECTURAL STATE section. Inline comments in `with-speculative-rollback` body labeled as 3 stages (Stage 1 scaffolding snapshot, Stage 2 on-network worldview-cache write, Stage 3 thunk w/ full-worldview). S1.a's visibility fix at the parameterize (full worldview = outer | worldview-cache | hyp-bit).

25. [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — post-S1.b/c/d state. TMS mechanism retired entirely: no `tms-cell-value` struct, no `tms-read`/`write`/`commit`, no `make-tms-merge`, no `net-new-tms-cell`, no `current-speculation-stack`. Net-cell-read uses per-propagator bitmask OVERRIDE (not OR) of worldview-cache — intentional for BSP-LE 2/2B clause isolation per lines 962-975.

26. [`racket/prologos/typing-propagators.rkt`](../../../racket/prologos/typing-propagators.rkt) — post-T-3 state. `make-union-fire-fn` at line ~1248 (parallels `make-pi-fire-fn`); expr-union install case rewritten (no branching at infer time); `type-map-write-unified` helper at ~551 (Role B equality-enforce write); dead atms.rkt imports removed; union-assumption-counter removed.

### §2.6 Session-Specific — TESTS + PROBE

27. [`racket/prologos/tests/test-mixed-map.rkt`](../../../racket/prologos/tests/test-mixed-map.rkt) — THE T-2 canary test file. `{:name "alice" :age 30}` mixed-value-type map scenarios. Post-Step-1-fix, all pass.

28. [`racket/prologos/tests/test-union-types.rkt`](../../../racket/prologos/tests/test-union-types.rkt) — line 234: `(infer <Nat | Bool>) = "[Type 0]"` canary for expr-union typing.

29. [`racket/prologos/tests/test-type-lattice.rkt`](../../../racket/prologos/tests/test-type-lattice.rkt) — 5 updated assertions for set-union semantics (Role A behavior on incompatible atoms).

30. [`racket/prologos/examples/2026-04-22-1A-iii-probe.prologos`](../../../racket/prologos/examples/2026-04-22-1A-iii-probe.prologos) — 6-scenario behavioral probe (28 expressions). §3 exercises mixed map (`{:name "alice" :age 30}`) — THE T-2 scenario.

31. [`racket/prologos/data/probes/2026-04-22-1A-iii-baseline.txt`](../../../racket/prologos/data/probes/2026-04-22-1A-iii-baseline.txt) — baseline for probe diff = 0 check.

32. [`racket/prologos/examples/2026-04-17-ppn-track4c.prologos`](../../../racket/prologos/examples/2026-04-17-ppn-track4c.prologos) — PPN 4C acceptance file for broader regression check.

### §2.7 Session-Specific — DAILIES + PRIOR HANDOFF

33. [`docs/tracking/standups/2026-04-22_dailies.md`](../standups/2026-04-22_dailies.md) — **Claude's dailies for this session arc**. Covers:
    - T-3 Commit A.2-a/A.2-b/A.2-c/B arc
    - Track 4D vision research creation
    - Charter-alignment re-sequencing dialogue
    - 1A-iii-a-wide Step 1 sub-phases S1.a-e
    - T-1 delivery
    - Lessons distillation candidates (3 promoted post-T-3, 2 watching post-Step-1)

34. [`docs/tracking/handoffs/2026-04-22_PPN_4C_T-3_HANDOFF.md`](2026-04-22_PPN_4C_T-3_HANDOFF.md) — **prior handoff** that started this session. Context continuity.

35. [`docs/standups/standup-2026-04-22.org`](../../standups/standup-2026-04-22.org) — user's standup opened this session.

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

### §3.1 T-3 Role A/B decomplection — DELIVERED (4 commits)

- `type-lattice-merge` = Role A (accumulate via set-union)
- `type-unify-or-top` = Role B (enforce equality; returns type-top on structural mismatch)
- Load-bearing two-commit ordering: Commit A migrates Role B sites BEFORE Commit B changes merge semantics
- 4 staged commits: A.2-a (architectural C1 fix, expr-union write `(expr-Type lv)`), A.2-b (type-map-write-unified helper + B1/B2), A.2-c (cell merge-fn swaps B3/B4/B5), B (set-union fallthrough + B6 integration-time finding)
- Probe diff = 0; test-union-types:234 canary passes; full suite green
- F7 distributivity conjecture DISPROVEN (see §4)

### §3.2 Charter-alignment re-sequencing — 2026-04-22

User's "step back" question: "if we actually use BSP-LE 2/2B's work for speculation, what need is there for rollback at all?" traced to the PPN 4C end-state architecture. Under Phase 4 + Phase 9 + Phase 10 + Phase 11 + PM 12 (all planned), `with-speculative-rollback` doesn't exist. Snapshot is scaffolding for off-network residue.

**Re-sequencing** (D.3 §7.5.10):
```
CURRENT (parallel-unblocked):  T-1  ‖  T-2  ‖  1A-iii-a-wide Step 1  ‖  Step 2
PIVOTED (dependency-ordered):  1A-iii-a-wide Step 1 → T-1 → T-2 → Step 2
```

Rationale: Step 1 IS the addendum's Phase 1 substrate migration charter continuation (§7.5.3). Post-Step-1, T-1 becomes tractable cleanup (not new API design).

**Framing principle** (codified inline, watching for 2-3 more data points before promotion): *Tactical cleanup tracks should be framed against end-state architecture, not as local optimizations.* See D.3 §7.5.10 for full codification.

### §3.3 PPN Track 4D proposed — 2026-04-22 (`4812892c`)

Vision research at [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md). Motivated by the 3-accidentally-load-bearing pattern (extended to 4 this session) as structural fingerprint of sources-of-truth fragmentation. Thesis: collapse fragmented typing/elaboration/reduction subsystems into a unified attribute-grammar substrate where each typing rule is a declarative grammar production with attribute-equations compiled to propagator installations.

**Prerequisites**: PPN 4C complete (including this addendum) + T-3 landed + PM Track 12 scoping decided.

**Scope estimate**: comparable to PPN 4C (multi-month). Stage 1 research + Stage 2 audit + Stage 3 design cycle when prerequisites met.

Linked from PPN Master (new Track 4D row) + MASTER_ROADMAP.org (item 13).

### §3.4 1A-iii-a-wide Step 1 — DELIVERED (5 sub-phase commits)

D.3 §7.5.11 has full summary. Staged:
- **S1.a** (`3b6aefdb`): elab-fresh-meta migration + 4th accidentally-load-bearing finding fix (visibility scope in with-speculative-rollback parameterize)
- **S1.b** (`2c8871ec`): 3 TMS fallback branches retired
- **S1.c** (`d220ca51`): TMS API retired wholesale (~258 lines from propagator.rkt) + pnet-serialize cleanup
- **S1.d** (`9f47ffe9`): current-speculation-stack parameter retired
- **S1.e** (`b1468220`): test-tms-cell.rkt deleted + cell-ops.rkt stale comments updated

**VAG all 4 questions pass** (D.3 §7.5.11).

### §3.5 T-1 — DELIVERED as documentation-only pass (`b7f8e58d`)

Charter-alignment re-framing reduced T-1's scope from "new API design" to pure scaffolding-labeling + stale-comment cleanup.

Changes:
1. `elab-speculation-bridge.rkt` module docstring restructured with ARCHITECTURAL STATE section distinguishing on-network substrate (permanent) from scaffolding (retires with Phase 4 + PM 12). Inline code comments labeled as 3 stages.
2. PM Master updated with "PPN 4C Phase 1A-iii-a-wide Step 1 + T-1 (2026-04-22)" design-input section. Specifies PM 12 light cleanup sub-phase: 6 caller migrations to `speculate` form + mechanism retirement. ~20-30 min mechanical work.
3. DEFERRED.md parallel entry cross-referencing PM Master detail.

No code changes. 103 targeted tests GREEN.

### §3.6 T-2 scope confirmed — post-Step-1 mechanical verification

Per D.3 tracker + §7.5.10:
- Verify map-assoc's `with-speculative-rollback` becomes redundant under T-3 set-union merge
- Decide on open-world `_` value type per Prologos ergonomics principle
- Mostly mechanical post-Step-1

---

## §4 Surprises and Non-Obvious Findings

### §4.1 FOUR "accidentally-load-bearing mechanism" findings (THE critical pattern)

Pattern is now at **4 data points**, with **2 of 4 surfaced by INTEGRATION-TEST behavior, not static audit**:

| # | Site | Load-bearing mechanism | How surfaced |
|---|---|---|---|
| 1 | Attempt 1 (1A-ii) | TMS dispatch at `propagator.rkt:1248` with empty stack updated BASE | Broad regression (pre-T-3 session) |
| 2 | Sub-A (1A-iii) | `with-speculative-rollback` bitmask ignored by TMS; elab-net snapshot did the real work | Investigation (pre-T-3 session) |
| 3 | Commit B (T-3) | `type-lattice-merge(Nat,Bool)=type-top` triggered sexp-infer fallback at typing-core.rkt:459 | **Integration test failure** (test-union-types:234 canary) |
| 4 | **S1.a (THIS SESSION)** | `with-speculative-rollback`'s bitmask parameterize OVERRODE worldview-cache in net-cell-read (per-propagator takes priority semantic for BSP-LE 2/2B clause isolation), losing visibility of prior commits | **Integration test failure** (test-mixed-map nested/mixed maps) |

**Codification candidate** (watching, 2 data points for integration-test-surfacing specifically):
> *Accidentally-load-bearing mechanisms are often surfaced by integration-test behavior, not static audit.* Stage 2 audits that grep for inline predicates catch SOME sites. They miss sites where a mechanism's BEHAVIOR — not its obvious API — is load-bearing downstream. Implication: Stage 2 audits for API migrations must include integration-test runs of realistic workloads, not just static site enumeration.

Promotion gate: 1 more data point (3 total integration-test-surfaced findings) probably warrants DEVELOPMENT_LESSONS.org entry.

### §4.2 F7 distributivity conjecture DISPROVEN

T-3 Commit B surfaced that distributivity of meet over subtype-join for Pi types does NOT hold in general under set-union merge (test-sre-track2h.rkt). Counterexample: `a = Pi mw Nat Bool`, `b = a`, `c = Pi mw Int Bool`. Under pre-T-3, `meet(a, c) = bot` (dom merge → top). Under post-T-3 Commit B, `meet(a, c) = Pi mw (Int | Nat) Bool`. The rhs then hits pre-existing `subtype?` atom-vs-union limitation, producing a union.

This is a mathematical finding, not a code bug. Test updated to document the counterexample as regression guard. Commutativity still holds.

### §4.3 BSP-LE 2/2B read-logic override is INTENTIONAL (not a bug)

`net-cell-read`'s tagged-cell-value dispatch at propagator.rkt:968-975 uses OVERRIDE semantics (per-propagator `current-worldview-bitmask` REPLACES worldview-cache when set). Intentional for clause-propagator isolation (each clause sees only its own branch's entries).

S1.a's 4th finding was NOT that this is wrong globally. It's that `with-speculative-rollback`'s specific use case (sequential try-else over prior-committed speculations) needs FULL worldview, not just hyp-bit. Fix is localized to the parameterize in `with-speculative-rollback`, not global read-logic.

### §4.4 Four mechanisms for speculation worldview (Finding 1 from §7.5.8)

D.3 catalogs them. Post-Step-1 state:

| # | Mechanism | Status |
|---|---|---|
| 1 | `current-speculation-stack` parameter | **RETIRED** (S1.d) |
| 2 | `current-worldview-bitmask` parameter | Per-fire-function override; scaffolding tied to PM Track 12 |
| 3 | `worldview-cache-cell-id` cell | **Authoritative on-network worldview** |
| 4 | `elab-net` snapshot via `current-prop-net-box` | **Scaffolding** tied to Phase 4 + PM 12 retirement |

Post-Step-1: mechanisms #2+#3 are the permanent substrate; #4 is explicitly labeled scaffolding with retirement plan.

### §4.5 test-facet-sre-registration pre-existing batch contamination

This test FAILS in batch runs (3-5 assertions about merge-fn-registry lookups returning #f for `constraint-merge`, `warnings-facet-merge`, `add-usage`) but PASSES when run individually. Related to PRELUDE DRIFT warning in every test run. Verified unrelated to T-3/Step-1/T-1 via stash test during T-3 Commit B validation. Pre-existing issue; not a session regression.

### §4.6 Integration-test audit methodology

B6 (T-3 Commit B's elab-fresh-meta merge-fn) was found when Commit B's test-elaborator-network.rkt contradictory-values test failed. S1.a's 4th finding was found when test-mixed-map regressed. Both would have been missed by static audit alone.

Implication for future API migration work: include `process-file` probe runs + realistic-workload test runs as part of Stage 2 audit, not just static grep enumeration.

### §4.7 The Role A/B pattern as design template

T-3's decomplection (`type-lattice-merge` = Role A accumulate; `type-unify-or-top` = Role B equality-enforce) was applied 9 times:
- 4 Role B sites migrated (A.2-a/b): make-unify-propagator, elab-add-unify-constraint, make-structural-unify-propagator, pair-decomp topology handler
- 3 cell merge-fn swaps (A.2-c): classify-inhabit classifier×classifier, cap-type-bridge function-type cell, session-type-bridge Send/Recv message-type cells
- 1 meta cell site (B6): elab-fresh-meta type meta cell
- 1 sub-cell pattern (B6 extension): identify-sub-cell 3 variants

Pattern generalizes beyond T-3. Future lattice work should consider Role A vs Role B per call site.

---

## §5 Open Questions and Deferred Work

### §5.1 T-2 scope (NEXT SESSION'S MAIN WORK)

**Questions to resolve in mini-design**:

- **Q-T2-1**: Is map-assoc's explicit `build-union-type` at typing-core.rkt:1211-1217 redundant post-T-3? Trace: `tv = infer ctx v`, then `build-union-type (list (whnf vt) tv)`. Under T-3 set-union merge, writing tv to the Map's value-type cell would auto-union. But the explicit build-union-type constructs the TYPE EXPRESSION, not a cell write. The widening returns a new `(expr-Map kt <widened>)` type. So it might NOT be directly redundant — depends on how the result type propagates into subsequent operations. AUDIT NEEDED.

- **Q-T2-2**: Should `{:name "alice" :age 30}` infer to `(Map Keyword _)` (open-world) rather than `(Map Keyword Int | String)` (narrow union)? Per Prologos ergonomics design (referenced in D.3 §7.5.8 Finding 2), maps should be "open-world" — the value type is `_` unless a schema narrows. Narrow unions are "overly narrow, contradicts language vision."

- **Q-T2-3**: If migrating to `_`, what about `with-speculative-rollback` at map-assoc (:1205)? Under `_` value type, `check ctx v _` always succeeds; speculation becomes unnecessary entirely for map-assoc. Caller removal would be in scope.

- **Q-T2-4**: Scope boundary — does T-2 also touch typing-core.rkt:1291 / :1325 (union-map-get-component / union-nil-safe-get)? These also use `with-speculative-rollback` and operate on Map types. If they're semantic partners to map-assoc, T-2 might touch them too. If orthogonal (union-map-get is about disambiguating union type at read-time), they stay in their current form.

### §5.2 Step 2 (PU refactor — vision-advancing capstone)

Per D.3 §7.5.4. Scope:
- 4 per-domain compound PU cells (type-meta-universe, mult-meta-universe, level-meta-universe, session-meta-universe)
- Shared hasse-registry handle across universes
- `elab-meta-read` / `elab-meta-write` API with domain dispatch
- ~5-10 files affected (solve-meta-core!, elab-cell-read/write callers, propagator installations)
- Significant migration

Step 2 is significantly larger than Step 1. It's the Phase 1A vision-advancing capstone. Follows T-2.

### §5.3 Remaining addendum phases (post-Phase-1A)

- **Phase 1B**: Tropical fuel primitive (SRE domain + primitive API)
- **Phase 1C**: Canonical BSP fuel instance migration (prop-network-fuel → cell)
- **Phase 1V**: Vision Alignment Gate for Phase 1
- **Phase 2A**: Register S(-1), L1, L2 as BSP stratum handlers
- **Phase 2B**: Retire run-stratified-resolution-pure + dead run-stratified-resolution!
- **Phase 2V**: VAG for Phase 2
- **Phase 3A/B/C/V**: Fork-on-union + hypercube + residuation error-explanation
- **Phase V**: Capstone + PIR

### §5.4 Post-addendum

- **Main-track PPN 4C Phase 4**: CHAMP retirement — meta-info migrates to AttributeMap `:type` facet β2. Immediate follow-on per user Q-Pivot-3 direction.
- **Main-track PPN 4C Phase 5-12**: per D.3 parent design. Phase 11b (diagnostic infrastructure), Phase 12 (zonk retirement via Option C expr-cell-ref), etc.
- **PM Track 12**: Module loading on network. Includes:
  - Submodule scope primitive (design input from PPN 4C 1e-α)
  - Clock/timestamp cell activation (design input from PPN 4C 1e-β-iii)
  - `with-speculative-rollback` light cleanup sub-phase (design input from THIS T-1)
- **PPN Track 4D**: Attribute Grammar Substrate Unification. Proposed this session. Multi-month. Prerequisites: PPN 4C complete + PM 12 scoping decided.

### §5.5 Codification candidates (for DEVELOPMENT_LESSONS.org or DESIGN_METHODOLOGY.org)

Per watching list, data-point count:

| Pattern | Data points | Promotion gate |
|---|---|---|
| Fragmentation of sources of truth (sources-of-truth accidentally-load-bearing) | **4** (attempt-1, Sub-A, Commit B, S1.a) | Ready for codification post-T-2 |
| Integration-test-surfaced findings (subset) | 2 (Commit B's B6, S1.a) | 1 more data point → codify |
| Role A/B API decomplection | 1 (T-3 template) | 1-2 more instances → codify |
| Charter alignment (tactical-framing-against-end-state) | 1 (T-1 reframing) | 2-3 more → codify |
| Implementation ordering as load-bearing principle | 1 (T-3 A→B) | 2-3 more → codify |

---

## §6 Process Notes

### §6.1 Charter-alignment as a Stage 3 design filter

Codified in D.3 §7.5.10 as inline principle. When a tactical cleanup task surfaces, check whether it's a LOCAL view of a LARGER architectural change already planned. If yes, frame tactical work as way-station with scaffolding + retirement plans, not as destination.

Observed transformation: T-1 scope collapsed from "new API design (with-transactional-rollback)" to "documentation-only pass" once this filter applied.

### §6.2 Conversational mini-design cadence sustained

Each mini-design opened dialogue, resolved via questions/options with user leans, executed atomically, checkpointed. Arc: T-3 Commit A.2-a/b/c/B → Step 1 sub-phases S1.a-e → T-1. 15+ commits, coherent throughout.

### §6.3 Per-commit dailies discipline sustained

Each meaningful commit triggered a dailies update. The dailies file (`2026-04-22_dailies.md`) captures the full session arc with commit-by-commit detail.

### §6.4 Probe diff discipline

Every migration sub-phase ran the probe against baseline. Result = 0 diff confirmed no semantic regression. Probe file at `examples/2026-04-22-1A-iii-probe.prologos`; baseline at `data/probes/2026-04-22-1A-iii-baseline.txt`.

### §6.5 Integration-test discipline (new observation)

Two of four accidentally-load-bearing findings this addendum were surfaced by integration-test runs (not static audit). Convergent evidence that Stage 2 audits for API migrations should include realistic-workload integration tests, not just grep-based site enumeration. Watching for 1 more data point before codification.

### §6.6 Multi-hypothesis parallel diagnostic (still valid)

User teaching from 2026-04-22 earlier session: "test multiple hypotheses at once." Applied in S1.a's 4th-finding diagnostic — narrowed cause to `with-speculative-rollback` parameterize scope in ~15 minutes instead of 45 via multi-hypothesis analysis.

### §6.7 Commit span this session

From `f42434ea` (2026-04-22 T-3 handoff) through `b7f8e58d` (T-1 delivery). Key landmarks:
- `164ca4ab` — working day interval opened (standup + dailies)
- `4812892c` — Track 4D vision research committed
- `a5a33a71` → `e07b809f` — T-3 Commit A.2-a through B (4 commits)
- `bd8c3326` — T-3 close (tracker + dailies)
- `16bddd26` — charter-alignment re-sequencing committed
- `3b6aefdb` → `b1468220` — Step 1 sub-phases (5 commits)
- `c5dc11dc` — Step 1 close (§7.5.11 + dailies)
- `b7f8e58d` — T-1 delivery

~18 production commits + tracker/dailies commits. Substantial session.

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (T-2 execution)

1. Hot-load every §2 document IN FULL
2. Summarize understanding back to user (especially 4-accidentally-load-bearing pattern + charter-alignment principle + Role A/B decomplection)
3. Open T-2 mini-design audit per Stage 4 Step 1 protocol
4. Resolve design questions (Q-T2-1 through Q-T2-4 above; expect user to lean on Q-T2-2 given ergonomics principle surfaced during T-3 Sub-A investigation)
5. Execute T-2 (expected scope: mechanical verification or small migration)
6. Validate: probe diff = 0 (or expected diff documented), targeted tests green, full suite regression
7. Close T-2 with per-phase protocol (tests, commit, tracker, dailies)

### §7.2 Medium-term (post-T-2)

- **1A-iii-a-wide Step 2** (PU refactor) — significantly larger than Step 1; vision-advancing capstone of Phase 1A. Per D.3 §7.5.4.
- **Phase 1B** (tropical fuel primitive)
- **Phase 1C** (canonical BSP instance migration)
- **Phase 1V** (Vision Alignment Gate)

### §7.3 Longer-term

- Phase 2 (orchestration unification)
- Phase 3 (union types via ATMS + hypercube)
- Phase V (capstone + PIR)
- Post-addendum: main-track Phase 4 (immediate follow-on per user Q-Pivot-3)
- Eventually: PM Track 12 + PPN Track 4D

---

## §8 Final Notes

### §8.1 What "I have full context" requires

- Read EVERY document in §2 IN FULL
- Articulate EVERY decision in §3 with rationale — especially §3.2 (charter-alignment re-sequencing) + §3.4 (Step 1 sub-phase structure) + §3.5 (T-1 as docs-only)
- Know EVERY surprise in §4 — especially §4.1 (4 accidentally-load-bearing findings) + §4.3 (BSP-LE read-logic override is intentional) + §4.6 (integration-test audit methodology)
- Understand the open questions in §5.1 but DO NOT pre-resolve them

Good articulation example for T-2:
> "T-2's scope was reduced to 'Map open-world realignment' post-Step-1. The key question is whether typing-core.rkt:1196-1217's explicit `build-union-type` becomes redundant under T-3 set-union merge, OR whether we should migrate to `_` open-world value type per Prologos ergonomics design (narrow unions like `(Map Keyword Int | String)` were flagged as 'overly narrow, contradicts language vision' in D.3 §7.5.8 Finding 2). If migrating to `_`, `with-speculative-rollback` at map-assoc (:1205) becomes redundant entirely. T-2 is mostly mechanical — either audit + doc (if redundancy only), or small code migration (if `_` adoption). The broader `with-speculative-rollback` retirement is not in scope for T-2 — it's scheduled for PM Track 12's light cleanup sub-phase per T-1's PM Master handoff."

### §8.2 Git state

```
branch: main
HEAD: b7f8e58d (T-1: with-speculative-rollback scaffolding-retirement plan)

Recent commits:
  b7f8e58d  T-1 DELIVERED: scaffolding-retirement plan + PM Master note
  c5dc11dc  D.3 §7.5.11 + dailies: Step 1 COMPLETE (5 sub-phases)
  b1468220  S1.e: delete test-tms-cell.rkt + clean cell-ops stale comments
  9f47ffe9  S1.d: Retire current-speculation-stack parameter
  d220ca51  S1.c: Retire TMS API wholesale
  2c8871ec  S1.b: Retire 3 TMS fallback branches in propagator.rkt
  3b6aefdb  S1.a: elab-fresh-meta → tagged-cell-value (+ 4th LB fix)
  16bddd26  D.3 §7.5.10 + dailies: charter-alignment re-sequencing
  bd8c3326  Dailies + D.3 tracker: T-3 COMPLETE
  e07b809f  T-3 Commit B: type-lattice-merge set-union + B6 + tests
  105bcdae  T-3 Commit A.2-c: Role B cell merge-fn swaps B3/B4/B5
  f85dd50a  T-3 Commit A.2-b: type-map-write-unified + B1/B2
  a5a33a71  T-3 Commit A.2-a: expr-union architectural fix
  4812892c  PPN Track 4D proposed: Attribute Grammar Substrate Unification
  164ca4ab  Open 2026-04-22 working day interval: standup + dailies

working tree: clean except benchmark data + .lsp/ artifacts
```

### §8.3 User-preference patterns observed

- **Conversational mini-design in existing design doc** — user rejected separate Stage 1-3 artifacts for T-3, established mini-design dialogue pattern that persists in D.3. Continued through Step 1 + T-1.
- **Architectural completeness > implementation cost** — "without concern of the implementation cost. Pragmatic implementation shortcuts should never be on the table." Established in 1A-iii-a-wide scope direction; applied throughout this session.
- **Principled over mechanical** — user preferred T3-C3 systematic re-audit over quick fixes; accepted charter-alignment reframing for T-1; agreed to document scaffolding rather than remove it.
- **Multi-hypothesis diagnostic** — user taught this pattern; applied in S1.a's 4th-finding narrowing.
- **Context awareness delegated to user** — "I'm closely monitoring context-window; explicit handoff at 85-90%." This handoff came at user request, not my suggestion.
- **Step back, charter-align** — user periodically pauses to ask "are we building for the right things here?" Both times this session (T-1 scope + Step 1 re-sequencing), the answer reshaped the work.
- **Accept leans with quick yes; insist on depth for architectural decisions** — "Let's proceed" is common acceptance; significant architectural questions get detailed engagement.

### §8.4 Gratitude + session arc

User's decisive observations this session:
- "If we actually use BSP-LE 2/2B's work for speculation, what need is there for rollback at all?" → surfaced Level-3 ideal (no rollback under end-state) and charter alignment
- "The whole goal for PPN 4C is to bring elaboration on-network" → reframed T-1 from isolated cleanup to substrate-migration prerequisite
- "Phase 4 is immediately to follow the addendum" → kept Phase 4 separate from addendum scope
- "Probably a note on PM 12 (PM Master document) – could be a light cleanup phase there" → exactly the right pattern; scaffolding with tracked retirement

Each redirected toward a better architectural framing. Honor this pattern.

### §8.5 Session outcome vs goal

Session started with T-3 T3-C3 re-audit pickup (from handoff `2026-04-22_PPN_4C_T-3_HANDOFF.md`). Delivered:
- T-3 complete (4 commits)
- Track 4D vision proposed
- Charter-alignment re-sequencing
- 1A-iii-a-wide Step 1 delivered (5 sub-phase commits; 4th accidentally-load-bearing finding + fix)
- T-1 delivered (documentation-only pass)
- Ready for T-2

Multiple architectural findings promoted to codification candidates. PM Track 12 handoff spec established for `with-speculative-rollback` retirement. PPN series advanced toward "elaboration completely on-network" charter.

**The context is in safe hands.**

---

## §9 Phase 2 MemPalace Integration (NEW — appended 2026-04-22 post-initial-handoff)

**Status**: Committed as `06d4ab6c`. Activates on next Claude Code session start (after hot-load + restart).

### §9.1 What happened

Phase 1 evaluation: ran 17 queries over 23,497 drawers of `docs/` (91% indexed mine). 12/17 queries ≥4/5 canonical hits. The standout: Q10 ("map open world _ value type ergonomics") returned D.3 §7.6.7 "Implications for T-2 (Map open-world)" as top-1 — the EXACT canonical section for the T-2 mini-design we're about to open. That validates the use case.

Real failure mode confirmed (F7 canary): `mempalace_search "F7 distributivity"` returns the pre-T-3 "F7 conjecture holds" claim from SRE Track 2H D.1 + Track 2H PIR §7 "we got lucky" AHEAD of the 2026-04-22 disproof in dailies. Semantic search has no recency weighting; verbose stale discussion outranks terse recent update. **Use as a hazard-flag, not a veto**: cross-check every result against current dailies/handoff/design-doc before acting.

Temporal graph investigated and rejected as recency mitigation: mempalace ships `knowledge_graph.py` with bitemporal triples (`valid_from`/`valid_to`), but `miner.py` has zero `add_triple` calls — after a full mine, `~/.mempalace/knowledge_graph.sqlite3` does not exist. The KG requires manual fact assertion to be useful. That duplicates what dailies + PIR discipline already does. Don't bother unless a compelling use emerges.

### §9.2 Integration surface (what's committed)

- `.mcp.json` at project root — registers mempalace MCP server via `uv tool run --from mempalace python -m mempalace.mcp_server`. Portable across dev machines with `uv` + `uv tool install mempalace`.
- `.claude/rules/mempalace.md` (133 lines) — full guardrails: use cases, F7 canary codified, anti-patterns (no hooks, no JSONL mining, no write tools without explicit user direction), cross-check discipline, re-mine cadence, success criteria, uninstall path.
- `CLAUDE.md` rules line extended with `@.claude/rules/mempalace.md`.
- `.gitignore` auto-extended by `mempalace init` for `mempalace.yaml` + `entities.json`.

### §9.3 Activation path for the continuation session

1. Verify `.mcp.json` loaded — `mcp__mempalace__search`, `mcp__mempalace__status`, etc. appear in the tool list.
2. Verify rule loaded — `.claude/rules/mempalace.md` content should be in CLAUDE.md-derived context via the `@` import.
3. Per-dev setup already done on this machine — local palace at `~/.mempalace/palace/` is 185MB with 23,497 drawers indexed.
4. If re-mine is needed: `mempalace mine /Users/avanti/dev/projects/prologos/docs --wing prologos` (~42 min first run, incremental after). Only re-mine after substantial `docs/tracking/**` or `docs/research/**` commits.

### §9.4 What to do with mempalace during T-2

- Try `mempalace_search "Map open world ergonomics"` or equivalent before re-reading §7.6 — it returned §7.6.7 as top-1 in Phase 1 eval.
- Cross-check any result that informs the design decision against the current dailies (`2026-04-22_dailies.md`) + this handoff's §1 + D.3's §7.6 / §7.5.8 Finding 2.
- If mempalace retrieval saves time, note it in dailies. If it misleads, note that too. Phase 2 is a monitored experiment.

### §9.5 What NOT to do

- DO NOT install the Stop or PreCompact hooks. They inject `"decision": "block"` system messages (prompt-injection path). MCP-only integration is the line.
- DO NOT mine JSONL session transcripts. Our commit-linked docs are the source of truth, not conversation history.
- DO NOT use `mempalace_add_drawer` / `mempalace_delete_drawer` without explicit user direction.
- DO NOT trust mempalace for "current state of X" questions. Those go through current dailies + handoff + design doc.

### §9.6 Broader context-scaling exploration (dialogue 2026-04-22)

User surfaced a meta-pain: "context of our project has grown quite a bit, and each session loses the context of everything it has done before — I'm constantly needing to point to prior art, repeat design principles and restate overarching visions." Concrete ask: is there a practice/tool that helps us "hold in our mind" what we've done and how it connects?

Websearch done 2026-04-22 ([AI coding agent persistent memory MCP markdown](https://github.com/zilliztech/memsearch), [basicmachines-co/basic-memory](https://github.com/basicmachines-co/basic-memory), [Claude Code docs](https://code.claude.com/docs/en/memory), [builder.io CLAUDE.md guide](https://www.builder.io/blog/claude-md-guide), [Claude Memory Bank](https://github.com/russbeye/claude-memory-bank)). Synthesis:

**Patterns we ALREADY use**:
- Markdown-first persistent memory ✓ (`docs/tracking/**`, principles, dailies)
- Curated MEMORY.md index ✓
- Daily session logs ✓ (dailies)
- Layered CLAUDE.md + per-dir rules ✓ (`.claude/rules/*.md`)
- `@path/to/file` imports (up to 5 levels) ✓ (we use for rules)

**Concrete improvement landed 2026-04-22 (this session)**:
- Added MASTER_ROADMAP.org + current series master to HANDOFF_PROTOCOL.org Always-Load. High-leverage, single change. Answers the user's "should the roadmap be a hot-load item?" question — yes, codified.

**Potential further wins (NOT doing now — deferred)**:
- **Concept-map document** (idea): `docs/tracking/principles/CONCEPT_MAP.org` tracing "principle → tracks that embodied it → PIR lessons → refinements in later tracks." Stitches the narrative the user is missing. PIRs' §16 longitudinal surveys have fragments; DEVELOPMENT_LESSONS.org accumulates; no one doc traces the arc. Would need real work to produce AND maintain. Evaluate after Phase 2 mempalace data arrives.
- **`@` import MASTER_ROADMAP.org directly into CLAUDE.md** (alternative to handoff-list inclusion): makes it always-loaded without requiring per-handoff listing. Trade-off: 25K tokens loaded every session whether needed or not. Defer until we confirm via practice that the roadmap is consulted ≥50% of sessions.
- **basic-memory** (alternative tool): markdown-first local knowledge graph built from wiki-links, MCP-accessible. Philosophy "files are source of truth" aligns with us better than mempalace's verbatim vector approach. Complementary, not replacement. Defer — don't add a second memory system before Phase 2 mempalace is evaluated in real use.

**User's stated constraint (firm)**: NO prompt injection. Rules out any tool that modifies outgoing prompts via hooks. All alternatives explored respect this — MCP-only is the architectural gate.

### §9.7 For the continuation session — summary

- Phase 2 mempalace is live. Use `mcp__mempalace__search` as "semantic grep" over our docs.
- Cross-check every hit against current dailies + handoff.
- MASTER_ROADMAP.org is now in the Always-Load list — use it for "where does X live" questions.
- T-2 is still the immediate next work. Start with `mempalace_search` on the T-2 question (expected to return D.3 §7.6.7 per Phase 1 eval).
- If mempalace is helping, note it in the dailies. If the recency problem bites us even once, note that too — Phase 2 validation needs both positive and negative data points.
