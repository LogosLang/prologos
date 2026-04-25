# PPN 4C Addendum Step 2 S2.c-iii Handoff

**Date**: 2026-04-24 (S2.c session close — S2.c-i + S2.c-ii delivered)
**Purpose**: Transfer context into a continuation session to pick up **Step 2 S2.c-iii — dispatch unification using `meta-domain-info` table + option 4 (parameter-read for cell-id)**.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user.

**CRITICAL meta-lessons from this session arc** (capture these — they inform S2.c-iii through S2.c-v decisions):

1. **PM 8F's `expr-meta-cell-id` cache field is a phantom optimization** (S2.c-i Task 1 microbench). Path 1 (cache) is **302 ns/call SLOWER** than Path 4 (parameter-read) under universe migration. The cache adds `with-handlers` overhead that exceeds the 80ns id-map savings it was designed to eliminate. Option 4 (parameter-read) won the cell-id decision decisively. Retroactive retirement of the field is flagged for Phase 4 CHAMP retirement; for S2.c, the new dispatch helpers simply don't reference the field.

2. **No T-3 'equality gap exists** (S2.c-i Task 2 audit). My initial 3a proposal (change `unify.rkt:71` `'equality` from `type-lattice-merge` → `type-unify-or-top`) was WRONG — would have silently broken `sre-make-equality-propagator`'s union-aware structural reasoning. The user's pushback ("Union types need set-union semantics") was protecting T-3's design intent. Audit confirmed unify-core's path for ground atom mismatches goes through `'conv` → `conv-nf`, never touching the SRE 'equality merge. Option 3a rejected; option 3c adopted (per-domain merges in `meta-domain-info` table directly, bypassing SRE 'equality dispatch). Permanent regression test at `tests/test-t3-equality-audit.rkt` (5/5 PASS).

3. **Cross-domain bridges remain — primitive needed component-path support** (S2.precursor + S2.c-i Task 3). Type and mult carry genuinely different lattices, so Realization B (shared carrier) doesn't apply. Bridge stays. But under universe migration, the bridge's α/γ propagators must declare `:component-paths` so they fire on specific components rather than wholesale on the universe cell. S2.precursor delivered the kwarg extension to `net-add-cross-domain-propagator`; S2.c-iv consumes it. Initial-Pi-elaboration audit (Task 3) confirmed exhaustively: `decompose-pi` is the SOLE bridge installer, fired from PUnify's topology handler, and `make-pi-reconstructor` (the only other Pi-writing-to-cell path) is itself installed by `decompose-pi`. No new invocation paths to handle.

4. **S2.c-ii closed the parameter-injection gap from S2.a-followup**. The 4 universe-merge parameters in `meta-universe.rkt` were declared with default fallbacks but never wired. Pre-S2.c-ii, all universe cells used `default-pointwise-hasheq-merge` (silent new-wins on collisions). Type accidentally worked (single Role B write per meta is the typical case post-T-3); mult would have silently broken under multi-write lattice join. Now wired correctly per option 3c.

5. **Hot-load is PROTOCOL not prioritization** — carried forward from prior handoffs. Tiering the §2 documents as "essential vs lower-priority" is rationalization for incomplete loading. The 35-doc list IS the substrate for mini-design dialogue. This was already strongly codified before this session; reinforced again by Task 2's audit revealing my 3a inference was misframed (the documents and code reality contradicted my plausible-sounding inference).

6. **Audit-first reveals misframed concerns** (1 data point this session). My 3a proposal was based on inferring "'equality means Role B" from the relation NAME. Audit revealed SRE convention is "'equality is the lattice JOIN," and post-T-3 that join is set-union (correct for union types). Lesson: don't infer relation semantics from names; check actual usage.

7. **Convergent design — multiple threads aligning on one architectural target** (1 data point). Option 3c (SRE-bypass for meta-cell merges) + Option 4 (parameter-read for cell-id) + F4 (dispatch unification) all point at a single `meta-domain-info` table-driven generic core. When threads converge naturally, the answer is principled. Watching list candidate.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C Phase 9+10+11 Addendum — substrate + orchestration unification (per D.3)
- **Parent track**: PPN Track 4C (per [`2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md)) — addendum is a BREAKOUT; cross-cutting concerns matrix in §5.5 of S2b handoff still applies
- **Phase**: 1A-iii-a-wide Step 2 (PU refactor) — Option B per D.3 §7.5.4 revised 2026-04-23
- **Sub-phase**: **S2.precursor ✅ + S2.c-i ✅ (all 3 tasks) + S2.c-ii ✅** (4 commits this session); **S2.c-iii NEXT** (dispatch unification)
- **Stage**: Stage 4 Implementation
- **Design document**: D.3 at [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — §7.5.13 captures full S2.c mini-design + audit findings + final architectural decisions
- **Last commit**: `bf25be40` (S2.c-ii — parameter injection per option 3c)
- **Branch**: `main` (ahead of origin by many commits; don't push unless directed)
- **Working tree**: clean except benchmark data + pnet cache artifacts + user's standup additions
- **Suite state**: **7917 tests / 126.4s / 0 failures** (within 118-127s baseline variance band; +5 tests from `test-t3-equality-audit.rkt`; +5.7s from `compound-tagged-merge` doing proper per-component lattice join vs prior new-wins)
- **Baseline doc**: [`2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — §12 "Actual vs Predicted" added 2026-04-24 post-S2.b-iv close

### Progress Tracker snapshot (D.3 §3, post-S2.c-ii close)

| Sub-phase | Status | Commit |
|---|---|---|
| 1A-iii-a-wide Step 1 (TMS retirement) | ✅ | 5 sub-phase commits |
| Path T-1 (documentation) | ✅ | `b7f8e58d` |
| Path T-2 (Open by Design) | ✅ | 3 commits + tracker |
| T-3 (set-union merge) | ✅ | 4 commits |
| Step 2 S2.a (infrastructure) | ✅ | `ded412db` |
| Step 2 S2.a-followup (lightweight refactor) | ✅ | `2bab505a` |
| Step 2 S2.b (TYPE domain) | ✅ CLOSED | 12+ commits ending `aeb0ff24` |
| **Step 2 S2.c mini-design** (D.3 §7.5.13) | ✅ | `107a37c6` (THIS SESSION) |
| **Step 2 S2.precursor** (cross-domain primitive) | ✅ | `1c3970d0` (THIS SESSION) |
| **Step 2 S2.c-i Task 2** (T-3 audit + regression test) | ✅ | `3ceec4fc` (THIS SESSION) |
| **Step 2 S2.c-i Tasks 1 + 3** (microbench + initial-Pi audit) | ✅ | `9e975d45` (THIS SESSION) |
| **Step 2 S2.c-ii** (parameter injection per option 3c) | ✅ | `bf25be40` (THIS SESSION) |
| **Step 2 S2.c-iii** (dispatch unification) | ⬜ **NEXT** | — |
| Step 2 S2.c-iv (fresh-mult-meta + cross-domain bridge) | ⬜ | — |
| Step 2 S2.c-v (probe + suite + measurement + S2.d gate) | ⬜ | — |
| Phase 1E (that-* storage unification) | ⬜ | — |
| Phase 1B (tropical fuel) | ⬜ | Follows 1E |

### Next immediate task — S2.c-iii dispatch unification

**Goal**: replace per-domain `*-meta-solved?` / `*-meta-solution` duplicated dispatch with a single `meta-domain-info` table-driven generic core, per D.3 §7.5.13.6 + option 4 (parameter-read for cell-id) per microbench winner.

**Per D.3 §7.5.13.6**, build:

```racket
;; Per-domain entries — single source of truth for dispatch
(define meta-domain-info
  (hasheq
    'type    (hasheq 'universe-cid current-type-meta-universe-cell-id  ; option 4
                     'merge type-unify-or-top              ; (matches S2.c-ii injection)
                     'contradicts? type-lattice-contradicts?
                     'bot? prop-type-bot? 'top? prop-type-top?
                     'champ-box current-prop-meta-info-box)  ; legacy CHAMP fallback
    'mult    (hasheq 'universe-cid current-mult-meta-universe-cell-id
                     'merge mult-lattice-merge
                     'contradicts? mult-lattice-contradicts?
                     'bot? mult-bot? 'top? mult-top?
                     'champ-box current-mult-meta-champ-box)
    'level   (hasheq 'universe-cid current-level-meta-universe-cell-id
                     'merge merge-meta-solve-identity
                     'contradicts? meta-solve-contradiction?
                     'bot? (lambda (v) (eq? v 'unsolved))
                     'top? meta-solve-contradiction?
                     'champ-box current-level-meta-champ-box)
    'session (hasheq 'universe-cid current-session-meta-universe-cell-id
                     'merge merge-meta-solve-identity
                     'contradicts? meta-solve-contradiction?
                     'bot? (lambda (v) (eq? v 'unsolved))
                     'top? meta-solve-contradiction?
                     'champ-box current-sess-meta-champ-box)))

;; Single dispatch core
(define (meta-domain-solution domain id [explicit-cid #f])
  (define net-box (current-prop-net-box))
  (define info (hash-ref meta-domain-info domain))
  (define cid (or explicit-cid ((hash-ref info 'universe-cid))))   ; option 4 — parameter-read
  (cond
    [(and cid net-box)
     (with-handlers ([exn:fail? (lambda (_) (champ-fallback domain id))])
       (let ([v (compound-cell-component-ref (unbox net-box) cid id)])
         (and v (not (eq? v 'infra-bot))
              (not ((hash-ref info 'bot?) v))
              (not ((hash-ref info 'top?) v))
              v)))]
    [else (champ-fallback domain id)]))

(define (meta-domain-solved? domain id)
  (and (meta-domain-solution domain id) #t))
```

**Backward-compat shims** (preserve all existing callers):
- `meta-solution(id)` → `(meta-domain-solution 'type id)`
- `meta-solution/cell-id(cid, id)` → `(meta-domain-solution 'type id cid)` — explicit-cid path retained for callers with `expr-meta` in hand
- `meta-solved?(id)` → `(meta-domain-solved? 'type id)`
- `mult-meta-solution(id)` → `(meta-domain-solution 'mult id)`
- `mult-meta-solved?(id)` → `(meta-domain-solved? 'mult id)`
- `level-meta-solution(id)` → `(meta-domain-solution 'level id)`
- `level-meta-solved?(id)` → `(meta-domain-solved? 'level id)`
- `sess-meta-solution(id)` → `(meta-domain-solution 'session id)`
- `sess-meta-solved?(id)` → `(meta-domain-solved? 'session id)`

**Estimated scope**: ~150 LoC + -100 LoC duplicated. Net-positive code reduction once the consolidation lands.

**Key design considerations** (carry from §7.5.13.6):
- Option 4 winning (per microbench) means the generic core uses `((hash-ref info 'universe-cid))` to read parameters, NOT `expr-meta-cell-id` field. Path 4 was 302ns FASTER than the cache field approach — significant.
- Backward-compat shims preserve existing call sites' signatures (some callers have explicit cell-id, some don't). Shims delegate to the generic core.
- For domains where the universe-cid parameter is NOT yet set (test contexts without driver callbacks; mult/level/session pre-S2.c-iv migration), the dispatch falls back to the legacy CHAMP-box path. Backward-compat preserved.

**Drift risks** for S2.c-iii (per §7.5.13.9):
- Inadvertently changing semantics for level/session readers (which we're not migrating per se in S2.c). Mitigation: backward-compat shims preserve exact existing behavior.
- Subtle differences in error handling (with-handlers semantics). Test carefully.
- meta-domain-info as a top-level constant — depends on what's accessible at define time. Some predicates may need late binding (e.g., `current-prop-meta-info-box` is a parameter). Use thunks or delayed lookup if needed.

---

## §2 Documents to Hot-Load (ORDERED)

**CRITICAL**: read every document IN FULL. The hot-load IS the substrate for mini-design dialogue. NO tiering.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org)

### §2.1 Always-Load

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md)
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — Stage 4 Per-Phase Protocol
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — Correct-by-Construction + Stratified Propagator Networks + Hyperlattice Conjecture
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — P/R/M/S lenses
6. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) (self-reference)
7. [`docs/tracking/MASTER_ROADMAP.org`](../MASTER_ROADMAP.org)
8. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md)

### §2.2 Architectural Rules (loaded via `.claude/rules/`)

9. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md)
10. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md)
11. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md)
12. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md)
13. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md)
14. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md)
15. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md)
16. [`.claude/rules/mempalace.md`](../../../.claude/rules/mempalace.md)
17. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 Session-Specific — THE DESIGN DOCUMENTS (READ IN FULL)

18. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — D.3 addendum design. **THE central reference for S2.c-iii**. Critical sections:
    - **§3 Progress Tracker** — S2.c-i + S2.c-ii ✅ rows added 2026-04-24
    - **§7.5.4** — Step 2 deliverables (Option B)
    - **§7.5.13** — S2.c sub-phase mini-design (FULL — 11 subsections)
    - **§7.5.13.4** — option 3a REJECTED, option 3c ADOPTED (T-3 audit findings); 5 sub-subsections of audit detail
    - **§7.5.13.5** — option 4 ADOPTED (microbench A/B + decision)
    - **§7.5.13.5.1** — bench results (3-path × 3-workload)
    - **§7.5.13.6** — dispatch unification (THIS is what S2.c-iii implements; the `meta-domain-info` table is sketched here)
    - **§7.5.13.7** — sub-phase partition (revised post-Task-2 audit; S2.c-ii REMOVED, renumbered)
    - **§7.5.13.10** — sub-phase completion criteria

19. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — PPN 4C parent design. Read same sections per prior handoffs: §1, §2, §6.3 (Phase 4 CHAMP retirement — Step 2 is intermediate), §6.7 (Phase 11 elaborator strata → BSP), §6.10 (Phase 9+10 union types via ATMS), §6.11 (Hyperlattice/SRE/Hypercube lens), §6.12 (Hasse-registry primitive), §6.13 (PUnify audit), §6.15 (Phase 3 mini-design — `:type`/`:term` tag-layer split), §6.16 (Phase 13 progressive SRE classification).

20. [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) — Track 4D vision (post-PPN 4C scope; Phase 1E is prelude)

### §2.4 Session-Specific — Baseline + Hypotheses

21. [`docs/tracking/2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — UPDATED 2026-04-24 with §12 "Actual vs Predicted" post-S2.b-iv close. Read §5 hypotheses + §6 measurement discipline + §12 (the post-S2.b finding section). S2.c-v measurement may be performed; reassess at each sub-phase per §6 ("bounce-back not gate") discipline.

### §2.5 Session-Specific — THE PRIMARY CODE FILES FOR S2.c-iii

**CORE infrastructure** (already complete from S2.b/precursor/c-ii — read for understanding):

22. [`racket/prologos/meta-universe.rkt`](../../../racket/prologos/meta-universe.rkt) — universe-cell parameters + helpers. **Critical for option 4 understanding**: `current-type-meta-universe-cell-id` etc. are parameters set by `init-meta-universes!`. Option 4 reads these directly via `((hash-ref info 'universe-cid))` thunk-style.

23. [`racket/prologos/elaborator-network.rkt`](../../../racket/prologos/elaborator-network.rkt) — **S2.c-ii landed parameter injection at module load** (lines ~1044-1075). The 4 universe-merge parameters are now wired to `compound-tagged-merge`-wrapped per-domain merges. S2.c-iii does NOT modify this module.

24. [`racket/prologos/decision-cell.rkt`](../../../racket/prologos/decision-cell.rkt) — `compound-tagged-merge` factory (line ~529). Used by S2.c-ii.

25. [`racket/prologos/cell-ops.rkt`](../../../racket/prologos/cell-ops.rkt) — re-exports for `elab-add-fire-once-propagator` + `elab-add-broadcast-propagator` (S2.b-iv added).

26. [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — **S2.precursor extended `net-add-cross-domain-propagator`** at line 3233 with kwargs (`#:c-component-paths`, `#:a-component-paths`, `#:assumption`, `#:decision-cell`, `#:srcloc`). S2.c-iv consumes these for the type↔mult bridge migration.

**S2.c-iii TARGET FILES** (these are what S2.c-iii will modify):

27. [`racket/prologos/metavar-store.rkt`](../../../racket/prologos/metavar-store.rkt) — **PRIMARY S2.c-iii target**. The 8+ duplicated dispatch functions are here:
    - Line ~2207: `meta-solution/cell-id(cell-id, id)` — type meta dispatch (centralized, post-S2.b-ii). EXPLICIT-CID PATH
    - Line ~2275: `meta-solution(id)` — wraps meta-solution/cell-id with #f
    - Line ~2186 (approx): `meta-solved?(id)` — type meta dispatch
    - Line ~2548: `mult-meta-solution(id)` — mult dispatch (id-map lookup or CHAMP fallback)
    - Line ~2518: `mult-meta-solved?(id)` — mult dispatch
    - Line ~2374: `level-meta-solved?(id)` — level dispatch
    - Line ~ (search): `level-meta-solution(id)` — level dispatch
    - Line ~2659: `sess-meta-solved?(id)` — session dispatch
    - Line ~ (search): `sess-meta-solution(id)` — session dispatch
    - **Add**: `meta-domain-info` table + `meta-domain-solution(domain, id, [cid])` + `meta-domain-solved?(domain, id)` core
    - **Convert** the 8+ existing functions to backward-compat shims delegating to the core

### §2.6 Session-Specific — Probe + Acceptance + Bench

28. [`racket/prologos/examples/2026-04-22-1A-iii-probe.prologos`](../../../racket/prologos/examples/2026-04-22-1A-iii-probe.prologos) — probe (28 expressions). Run pre + post each S2.c sub-phase; expect counter-identical output (pure refactor under S2.c-iii).

29. [`racket/prologos/examples/2026-04-17-ppn-track4c.prologos`](../../../racket/prologos/examples/2026-04-17-ppn-track4c.prologos) — PPN 4C acceptance file (broader regression).

30. [`racket/prologos/benchmarks/micro/bench-meta-lifecycle.rkt`](../../../racket/prologos/benchmarks/micro/bench-meta-lifecycle.rkt) — A/B + E + **F (NEW S2.c-i Task 1)**. Section F has the option 1/2/4 microbench. Re-run only if S2.c-iii regresses unexpectedly; standard cadence is to defer to S2.c-v.

31. [`racket/prologos/tests/test-t3-equality-audit.rkt`](../../../racket/prologos/tests/test-t3-equality-audit.rkt) — **NEW S2.c-i Task 2 artifact**. 5 regression tests verifying unify-core fails correctly on incompat ground atoms post-T-3 set-union. PERMANENT — keep across all future changes.

32. [`racket/prologos/tests/test-cross-domain-propagator.rkt`](../../../racket/prologos/tests/test-cross-domain-propagator.rkt) — **3 tests added in S2.precursor**. Contract verification for the new kwargs.

### §2.7 Session-Specific — Dailies + Prior Handoffs

33. [`docs/tracking/standups/2026-04-23_dailies.md`](../standups/2026-04-23_dailies.md) — **current dailies**. Contains the FULL S2.c session arc: S2.c handoff pickup → mini-design dialogue → S2.precursor → S2.c-i Tasks 2+1+3 → S2.c-ii. Read end-to-end for the design dialogue narrative.

34. [`docs/tracking/handoffs/2026-04-24_PPN_4C_S2c_HANDOFF.md`](2026-04-24_PPN_4C_S2c_HANDOFF.md) — **prior handoff** (this session's pickup point). Cross-cutting concerns matrix + S2.b CLOSED state + what was expected for S2.c (and what we adjusted via the conversational mini-design).

35. [`docs/tracking/handoffs/2026-04-24_PPN_4C_S2b-iv_HANDOFF.md`](2026-04-24_PPN_4C_S2b-iv_HANDOFF.md) — two handoffs back; S2.b-iv design dialogue context.

36. [`docs/standups/standup-2026-04-23.org`](../../standups/standup-2026-04-23.org) — user's standup for the working-day interval (write-once / read-only from Claude's side per CLAUDE.local.md).

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

### §3.1 Cross-domain bridge architecture — bridge stays + primitive component-path-aware

**Decided in S2.c mini-design (D.3 §7.5.13.2 + §7.5.13.2.1)**:

- Type and mult carry genuinely different lattices (type's full quantale vs mult's flat 3-element) → Realization B (shared carrier) doesn't apply per `structural-thinking.md` § "Direct Sum Has Two Realizations" heuristic.
- **Bridge stays as Galois projection** between domains.
- `decompose-pi` is the SOLE bridge installer (audit confirmed exhaustively in Task 3); fired from `make-structural-unify-propagator`'s topology handler.
- **S2.precursor delivered** kwarg extension to `net-add-cross-domain-propagator` (`#:c-component-paths`, `#:a-component-paths`, `#:assumption`, `#:decision-cell`, `#:srcloc`) — DELIVERED commit `1c3970d0`. All 4 production callers + ~12 test callers preserve backward-compat via empty-default kwargs.
- **S2.c-iv consumes the precursor** for the type↔mult bridge migration.

### §3.2 SRE 'equality merge stays as `type-lattice-merge` (set-union) — option 3c, NOT 3a

**Decided in S2.c-i Task 2 audit (D.3 §7.5.13.4)**:

- Original 3a proposal (change `unify.rkt:71` `'equality` from `type-lattice-merge` → `type-unify-or-top`) was **REJECTED**. Would have silently broken `sre-make-equality-propagator`'s union-aware structural reasoning.
- T-3's set-union semantics is the CORRECT design under union-aware types: when two cells must be "equal" with incompat values, both cells become the union, satisfying "equal to the same union."
- Audit traced runtime consumers: 5 in `sre-core.rkt`, all operating correctly under post-T-3 set-union (lattice join is the right semantics).
- `unify-core`'s ground-atom-mismatch path goes through `'conv` → `conv-nf` → returns `#f` directly. NEVER touches the SRE 'equality merge. Empirically confirmed via `tests/test-t3-equality-audit.rkt` (5/5 PASS).
- **Option 3c adopted**: per-domain meta-cell merges go DIRECTLY into `meta-domain-info` table, bypassing SRE 'equality dispatch. Each domain provides the merge it already uses (`type-unify-or-top` for type metas, `mult-lattice-merge` for mult, `merge-meta-solve-identity` for level/session).
- Original S2.c-ii (close T-3 gap) REMOVED from sub-phase plan.

### §3.3 Cell-id approach — option 4 (parameter-read) WINS DECISIVELY

**Decided in S2.c-i Task 1 microbench (D.3 §7.5.13.5.1-§7.5.13.5.2)**:

| Workload | Path 1 (cache field) | Path 2 (id-map) | **Path 4 (parameter)** |
|---|---|---|---|
| 1 meta | 625 ns | 423 ns | **323 ns** |
| 100 metas | 628 ns | 436 ns | **325 ns** |
| 1000 metas | 632 ns | 454 ns | **328 ns** |

- **Option 4 strictly dominates over option 2** by 100-125 ns/call (>50ns rule satisfied).
- **Option 4 is 302 ns/call FASTER than option 1** (PM 8F's cache field). PM 8F's optimization is a phantom — actively COSTING time, not saving it. Cache-vs-no-cache mechanism: cache path goes through `with-handlers` wrapper at `meta-solution/cell-id` line 2219, adding ~300ns of continuation-marker overhead.
- **Option 4 adopted**: `meta-domain-info` table reads universe-cid from parameters via thunks. No struct field cache, no id-map walk.
- **Sub-question — retire `expr-meta-cell-id` field retroactively**: STRONG yes, but DEFERRED to Phase 4 CHAMP retirement. For S2.c, option 4's helpers don't reference the field. Phase 4 cleans it up.

### §3.4 Parameter injection wired in S2.c-ii (option 3c executed)

**Delivered in commit `bf25be40`**:

- `elaborator-network.rkt` sets the 4 universe-merge parameters at module load:
  ```racket
  (current-type-universe-merge    (compound-tagged-merge type-unify-or-top))
  (current-mult-universe-merge    (compound-tagged-merge mult-lattice-merge))
  (current-level-universe-merge   (compound-tagged-merge merge-meta-solve-identity))
  (current-session-universe-merge (compound-tagged-merge merge-meta-solve-identity))
  ```
- All 4 universe cells now use canonical domain merges (was: silent `default-pointwise-hasheq-merge` for all 4, accidentally working for type but would have silently broken mult/level/session under collision scenarios).
- Contradicts? predicates kept at default `default-no-contradicts?` — per-component contradiction detection happens at `compound-cell-component-ref` read time. Cell-level contradiction for compound cells doesn't have meaningful semantics.

### §3.5 Cross-cutting concerns (from prior handoffs §5.5 — STILL APPLY)

| Parent Track Phase | Addendum Interaction | Watch |
|---|---|---|
| Phase 3 (`:type`/`:term` split) ✅ | Step 2 compound cells coexist with attribute-map's classify-inhabit-value | Universe cells don't duplicate/contradict attribute-map |
| Phase 4 (CHAMP retirement) ⬜ | Step 2 universe-cell shape compatible with attribute-map β2 collapse; `expr-meta-cell-id` field retirement absorbed here | Don't over-commit shape Phase 4 would rework |
| Phase 7 (parametric trait resolution) ⬜ | dict-cell-id propagators — S2.b-iv's bridge factory signature change is the stepping stone for Phase 7 | Bridge-fn setup in metavar-store.rkt:461 affected by S2.b changes |
| Phase 8 (Option A freeze) ⬜ | Reads `:term` facet via `that-*` | 1E unifies access; Step 2 substrate enables it |
| Phase 9 (BSP-LE 1.5 cell-based TMS) ⬜ = addendum Phase 3 | Step 2 tagged-cell-value substrate | Step 2 depends on S1 substrate (DONE) |
| Phase 9b (γ hole-fill) ⬜ | Shares hasse-registry-handle | Universe `'worldview` hasse-registry may be reused; Set-latch + broadcast pattern (S2.b-iv) consumed |
| Phase 10 (union via ATMS) ⬜ = addendum Phase 3 | Tagged entries per universe component | compound-tagged-merge supports branch-tagged writes; Set-latch + broadcast pattern consumed for per-branch ready latches |
| Phase 11 (strata → BSP) ⬜ = addendum Phase 2 | Meta universes affect retraction stratum | S(-1) retraction clears per-meta entries from universe cells |
| Phase 12 (Option C freeze) ⬜ | `expr-cell-ref` struct; reading IS zonking | Universe cell addressing via meta-id component-path |

---

## §4 Surprises and Non-Obvious Findings

### §4.1 PM 8F's expr-meta cell-id cache is a phantom optimization (S2.c-i Task 1)

Per microbench data above: cache path is **302 ns/call SLOWER** than parameter-read. The cache adds `with-handlers` continuation-marker overhead that exceeds the 80ns id-map savings it was designed to eliminate.

Implications:
- Option 4 (parameter-read) is BOTH architecturally cleanest AND fastest
- Retroactive retirement of `expr-meta-cell-id` field flagged for Phase 4 CHAMP retirement
- For S2.c, the new dispatch helpers don't reference `expr-meta-cell-id` — field becomes inert

**Codification candidate**: "phantom optimization detected via microbench" — cached optimizations from earlier-architecture eras may become net-negative after substrate changes. Microbench should be standard practice when migrating substrates that touch heavily-cached paths. 1 data point this session.

### §4.2 No T-3 'equality gap exists (S2.c-i Task 2)

My initial 3a proposal (change `unify.rkt:71` `'equality` to `type-unify-or-top`) was based on inferring "'equality should mean Role B" from the relation NAME. Audit revealed:
- SRE convention is "'equality is the lattice JOIN"
- Post-T-3, that join is set-union (Role A — accumulate via union for incompat atoms)
- Set-union IS the correct semantics for `sre-make-equality-propagator` under union-aware design (when two cells "must be equal" with incompat values, both become the union)
- `unify-core`'s ground-atom path doesn't touch the merge anyway — uses `conv-nf`

User's pushback was prescient:
> "§4 3a sounds like an issue that we needed to spend a lot of time on recently. Union types need set-union semantics."

Permanent regression test added: `tests/test-t3-equality-audit.rkt` (5/5 PASS). Documents design intent for future maintainers.

**Codification candidate**: "audit-first reveals misframed concerns" — don't infer relation semantics from names; check actual usage. 1 data point this session.

### §4.3 Convergent design — multiple threads aligning

Option 3c (SRE-bypass for meta-cell merges) + Option 4 (parameter-read for cell-id) + F4 (dispatch unification) all naturally converge on the `meta-domain-info` table architecture. When threads converge naturally, the answer is principled.

Also note: option 4's fastest path uses parameter-reads, which under PM Track 12 future migration become cell-reads. The "single source of truth" framing still holds — universe-cid is set at init time, read at use time, no caching.

### §4.4 Suite wall time +5.7s post-S2.c-ii

`compound-tagged-merge` is slightly slower than `default-pointwise-hasheq-merge` in the common case (proper per-component lattice join vs simple new-wins). +5.7s on full suite acceptable for correctness — within 118-127s baseline variance band. Will revisit if S2.c-v measurement raises concerns.

### §4.5 Carried forward from prior handoffs (still relevant)

- **Set-latch + broadcast complementary patterns** (codified in propagator-design.md). S2.b-iv applied this. Phase 9b γ hole-fill + Phase 10 union-via-ATMS will consume the same pattern.
- **Component-path discipline**: any propagator interacting with a structural cell MUST specify a component path. Carries forward to S2.c-iv's bridge migration.
- **BSP-LE read-logic override is INTENTIONAL** (`net-cell-read`'s tagged-cell-value dispatch at `propagator.rkt:968-975` uses OVERRIDE semantics for clause-propagator isolation under BSP-LE 2/2B). The b-iii follow-up's `resolve-worldview-bitmask` helper in `meta-universe.rkt` mirrors this exact logic.
- **5 integration-surfaced findings** across the T-3 + S2.b + S2.c arc (graduation-ready for `DEVELOPMENT_LESSONS.org`): Stage 2 audits for API migrations must include integration-test runs of realistic workloads, not just static site enumeration. Codification ready.

---

## §5 Open Questions and Deferred Work

### §5.1 S2.c-iii execution (immediate next)

**Concrete plan** per D.3 §7.5.13.6 + §3.3 above:

1. **Define `meta-domain-info` table** in `metavar-store.rkt` near the existing parameter declarations. Use thunks for `'universe-cid` entries (parameters are values, not functions; thunk-style late binding required).
2. **Implement `meta-domain-solution(domain, id, [cid])` core** — the single dispatch function. Option 4 path uses thunks to read parameters.
3. **Implement `meta-domain-solved?(domain, id)` core**.
4. **Implement `champ-fallback(domain, id)` helper** — shared CHAMP-box reader for legacy contexts (test fixtures, pre-init scenarios).
5. **Convert existing 8+ dispatch functions to backward-compat shims** delegating to the core. EXACT signatures preserved.
6. **Targeted tests**:
   - Existing tests for type/mult/level/session readers should ALL still pass (backward-compat preservation)
   - Add a new test verifying the generic core works directly (e.g., `(meta-domain-solution 'type id)` for a known meta)
7. **Probe + acceptance + full suite as regression gate**.
8. **Tracker + dailies + commit**.

**Estimated total**: ~150 LoC new code + ~-100 LoC duplicated logic absorbed into shims = net ~+50 LoC.

**Drift risks** (per §7.5.13.9 + revised analysis):
- Subtle semantic differences in `with-handlers` wrapping. Test carefully.
- Late-binding of parameters via thunks — ensure thunks are evaluated at call time, not at table-define time.
- Don't accidentally retire the explicit-cell-id path (`meta-solution/cell-id`'s arity-2 form) — many callers still use it.
- Domain-info table as a static `define` vs runtime construction — static is simpler if all entries are accessible at module load. May need slight refactoring if some predicates are defined later.

### §5.2 S2.c-iv execution (after S2.c-iii)

`fresh-mult-meta` universe-path migration (paralleling `fresh-meta`'s b-iii pattern from `cf60c397`) + cross-domain bridge migration:

1. `fresh-mult-meta` at `metavar-store.rkt:2460` — add universe-path branch that registers mult-meta-id as component of `current-mult-meta-universe-cell-id` (when set) instead of allocating per-meta cell.
2. `current-structural-mult-bridge` callback at `driver.rkt:2658` — pass meta-id (not just cell-id) to bridge installer; install bridge with `:c-component-paths (list (cons type-cell type-meta-id))` and `:a-component-paths (list (cons mult-cid mult-meta-id))`.
3. The α/γ closures in `elaborator-network.rkt` need updating to use `compound-cell-component-ref/pnet` and `compound-cell-component-write/pnet` for component-keyed access (NOT raw `net-cell-read`/`net-cell-write` which would return/write the whole hasheq under universe migration).
4. Probe + targeted regression.

Estimated: ~80-120 LoC.

### §5.3 S2.c-v execution (close)

- Probe + targeted suite + measurement
- Decide whether to update STEP2_BASELINE.md §12 with new measurement (or defer to S2.e per "bounce-back not gate" discipline)
- GO/no-go for S2.d (level + session migrations)

### §5.4 Watching-list carryovers / codification candidates

| Pattern | Data points | Promotion gate |
|---|---|---|
| Hot-load is protocol not prioritization | 2 (prior + this session) | 1 more → DEVELOPMENT_LESSONS.org |
| Set-latch + broadcast complementarity | 1 (codified in propagator-design.md) | Done; longitudinal observation |
| Broadcast `'()` accumulator + set-result | 1 | 1 more → propagator design refinement (`#:initial-acc` parameter) |
| Pipeline checklist: direct constructor calls | 1 | Add to `.claude/rules/pipeline.md` § "New Struct Field" |
| Per-checkpoint cadence value | 4+ | Ready for codification post-S2 |
| Micro-benchmarks vs real-workload | 3 (S2.a positive; S2.b mixed; S2.c-i decisive) | Ready for codification — pattern firmly established |
| `solve-meta!` regression follow-up | open | Investigate post-S2.e or as own work |
| `*-for-meta` scan functions retirement | open | Audit for production callers; retire if confirmed dead |
| Phantom optimization detected via microbench | 1 (S2.c-i Task 1) | 1 more → DEVELOPMENT_LESSONS.org |
| Audit-first reveals misframed concerns | 1 (S2.c-i Task 2) | 1-2 more → DEVELOPMENT_LESSONS.org |
| Convergent design — multiple threads → one architecture | 1 (S2.c-iii target via 3c+4+F4) | 1-2 more → codify |
| Stage-2-audit-must-include-integration-runs | 5+ across T-3 + S2.b + S2.c arc | **Graduation-ready** for DEVELOPMENT_LESSONS.org |
| Parameter-injection wiring is "design intent that gets forgotten" | 1 (S2.c-ii closed S2.a-followup gap) | 1-2 more → codify |

### §5.5 Architecture `#:initial-acc` parameter for broadcast (potential follow-up)

The wrapper pattern in `add-readiness-set-latch!` is a workaround for `net-add-broadcast-propagator`'s hardcoded `for/fold acc at '()`. A cleaner long-term refinement: add `#:initial-acc` parameter (defaulting to `'()` for backward-compat). Out of S2.c scope; flagged.

### §5.6 PM Track 12 absorptions (still relevant from prior handoffs)

When PM Track 12 (module loading on network) runs:
- Parameters (e.g., `current-type-meta-universe-cell-id`) become cells. Option 4's dispatch core picks this up automatically (the thunks become cell reads).
- Several Step 2 + S2.c scaffolding items retire (registries-as-parameters, struct-copy boundaries).

---

## §6 Process Notes

### §6.1 Refined Stage 4 content-location methodology (carried — used heavily this session)

Mini-design + mini-audit are CONVERSATIONAL and CO-DEPENDENT. Outcomes persist to the DESIGN DOC (not dailies, not separate audit files). Dailies hold the opening bookmark + commit story. THIS SESSION used the pattern extensively:
- D.3 §7.5.13 was created via conversational mini-design (commit `107a37c6`)
- D.3 §7.5.13.4 (option 3c finding) + §7.5.13.5.1 (microbench results) added DURING execution as audit findings persisted into the design doc
- §7.5.13.7 (sub-phase partition) revised post-Task-2 audit to remove S2.c-ii and renumber

This pattern is now firmly established. Data point #4-5 for "mini-design in existing design doc" — graduation-ready.

### §6.2 Per-phase completion 5-step checklist (workflow.md)

a. Test coverage (or explicit "no tests: refactor" justification)
b. Commit with descriptive message
c. Tracker update (⬜ → ✅ + commit hash + key result)
d. Dailies append (what was done, why, design choices, lessons/surprises)
e. THEN proceed to next phase

This session followed it consistently across 4 commits.

### §6.3 Conversational cadence

Max autonomous stretch: ~1h or 1 phase boundary. This session checked in at:
- After hot-load (mutual clarity check)
- After S2.c mini-design (4 architectural questions surfaced and converged through dialogue)
- After S2.precursor delivery
- After each S2.c-i task
- After S2.c-ii delivery
- Now (handoff decision)

Pattern: aggressive conversational checking-in, especially during the S2.c-i audit phase where each task surfaced different findings that required user direction.

### §6.4 Probe + acceptance file per sub-phase

- Probe (`examples/2026-04-22-1A-iii-probe.prologos`): 28 expressions; diff = 0 vs `data/probes/2026-04-22-1A-iii-baseline.txt` is the semantic gate
- Acceptance file (`examples/2026-04-17-ppn-track4c.prologos`): broader regression net
- Targeted tests via `racket tools/run-affected-tests.rkt --tests tests/...`
- Full suite at sub-phase close

This session ran probe after S2.precursor, S2.c-ii — both diff = 0 (counter values identical to baseline).

### §6.5 mempalace Phase 3 active

Post-commit hook auto-mines docs on commits touching `docs/tracking/**` or `docs/research/**`. Used twice this session for prior-art retrieval (T-3 audit search + cross-domain bridge inventory). Hits were relevant; cross-checked against current dailies/handoff per `mempalace.md` recency discipline.

### §6.6 Session commits (this S2.c arc)

| Commit | Focus |
|---|---|
| `107a37c6` | PPN 4C addendum: persist S2.c mini-design into D.3 §7.5.13 |
| `1c3970d0` | S2.precursor: net-add-cross-domain-propagator accepts component-path kwargs |
| `3ceec4fc` | S2.c-i Task 2: T-3 'equality audit — no gap exists; option 3a rejected |
| `9e975d45` | S2.c-i Tasks 1 + 3: microbench (option 4 wins) + initial-Pi audit (scenario B exhaustively confirmed) |
| `bf25be40` | S2.c-ii: parameter injection per option 3c — universe cells use canonical merges |

5 commits, ~600+ LoC net production + design doc + tests.

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (S2.c-iii execution)

1. Hot-load EVERY §2 document IN FULL (especially D.3 §7.5.13 — the central reference; key audit findings in §7.5.13.4-§7.5.13.5)
2. Summarize understanding back to user — especially:
   - S2.c-i + S2.c-ii deliveries (option 3c + option 4 + parameter injection in place)
   - The 7 lessons + drift risks from this session
   - S2.c-iii scope (dispatch unification with `meta-domain-info` table + option 4)
3. Open S2.c-iii through conversational mini-design (restate Step 2 deliverables for dispatch unification; partition into mechanical sub-steps; identify drift risks). May or may not need a deeper mini-design — D.3 §7.5.13.6 already has the architecture; it's mostly mechanical refactoring at this point.
4. Run mini-audit: enumerate all callers of the 8+ existing dispatch functions to ensure backward-compat shims preserve every call site. Persist findings if surprises emerge.
5. Execute per conversational cadence (max 1h autonomous; checkpoint at each natural boundary — table definition / core implementation / shims migration / tests / regression)
6. Per-phase completion protocol after each commit (test, commit, tracker, dailies, proceed)

### §7.2 Medium-term (post-S2.c-iii, through S2 completion)

- S2.c-iv (fresh-mult-meta + cross-domain bridge migration with component-paths) — uses S2.precursor's primitive extension + S2.c-iii's dispatch unification
- S2.c-v (probe + targeted suite + measurement + S2.d gate)
- S2.d (level + session domain migrations) — should be NEAR-ZERO work after S2.c-iii's dispatch unification (just register their `meta-domain-info` entries when their universes are wired)
- S2.e (factory retirement + final formal measurement vs §5 hypotheses + S2.c/d/e codifications)
- S2.f (peripheral cleanup)
- S2-VAG (Stage 4 step 5 Vision Alignment Gate)

### §7.3 Longer-term

- Phase 1E (`that-*` storage unification)
- Phase 1B (tropical fuel primitive) + 1C (canonical instance)
- Phase 2 (orchestration unification)
- Phase 3 (union via ATMS + hypercube)
- Phase V (capstone + PIR)

### §7.4 Post-addendum

- Main-track PPN 4C Phase 4 (CHAMP retirement) — absorbs `expr-meta-cell-id` field retirement (per §4.1 finding)
- PM Track 12 (module loading on network) — parameters (e.g., `current-type-meta-universe-cell-id`) become cells; option 4's thunk-based reads pick this up automatically
- PPN Track 4D (attribute grammar substrate unification)

---

## §8 Final Notes

### §8.1 What "I have full context" requires

Per HANDOFF_PROTOCOL.org §8.1:
- Read EVERY document in §2 IN FULL (35 documents — no skipping, no tiering)
- Articulate EVERY decision in §3 with rationale (especially §3.2 option 3c rationale + §3.3 microbench-driven option 4 + §3.5 cross-cutting concerns)
- Know EVERY surprise in §4 (especially §4.1 phantom optimization + §4.2 no T-3 gap)
- Understand §5.1 (S2.c-iii execution) without re-litigating

Good articulation example for S2.c-iii opening:

> "S2.c-iii implements dispatch unification using the `meta-domain-info` table-driven generic core, per D.3 §7.5.13.6. The core routes `meta-domain-solution(domain, id, [cid])` to the appropriate universe cell via parameter-read (option 4 — winner of S2.c-i Task 1 microbench by 100-302 ns/call). The 8+ existing per-domain dispatch functions (`meta-solution/cell-id`, `meta-solved?`, `mult-meta-solution`, `mult-meta-solved?`, level/session analogs) become backward-compat shims delegating to the core. ~150 LoC new + ~-100 LoC duplicated absorbed = net +50 LoC. Since S2.c-i + S2.c-ii already landed the architectural decisions (option 3c parameter merges, option 4 dispatch), this is mostly mechanical refactoring with backward-compat preservation as the key correctness gate. Runs probe + acceptance file + targeted tests + full suite per the standard cadence."

### §8.2 Git state at handoff

```
branch: main (ahead of origin/main by many commits; don't push unless directed)
HEAD: bf25be40 (S2.c-ii: parameter injection per option 3c)
prior session arc:
  9e975d45 S2.c-i Tasks 1 + 3: microbench + initial-Pi audit
  3ceec4fc S2.c-i Task 2: T-3 'equality audit
  1c3970d0 S2.precursor: cross-domain primitive component-path kwargs
  107a37c6 PPN 4C addendum: persist S2.c mini-design
  3f18f4a6 (prior handoff)
working tree: clean (benchmark/cache artifacts untracked; user's standup additions untouched per workflow rule)
suite: 7917 tests / 126.4s / 0 failures (within 118-127s baseline variance)
```

### §8.3 User-preference patterns (carried + observed this session)

- **Completeness over deferral** — "never move on until green"; the parameter-injection gap was caught + fixed inline rather than deferred.
- **Architectural correctness > implementation cost** — set-latch + broadcast realization (S2.b-iv) was scoped IN over a smaller alternative; this session's option 4 was scoped IN even though it required microbench evidence (the user's framing: "Option 4 looks like a good 'N+1' option" — acknowledged it as a STRICT improvement, not just an alternative).
- **Conversational mini-design** — design + audit outcomes persist to D.3, not dailies. Pattern continued. This session firmly established the "audit findings persist to design doc as new subsections" sub-pattern (§7.5.13.4.1, §7.5.13.5.1, etc.).
- **Codification when patterns recur** — set-latch promoted to prime design pattern (S2.b-iv); option 4's "phantom optimization" pattern flagged for codification this session.
- **Per-commit dailies discipline** — followed throughout this session.
- **Hot-load discipline strict** — followed at session start (~400-500K tokens loaded).
- **Audit-first methodology** — strongly used this session. Task 2 audit OVERRODE plausible-sounding inference (3a). Task 1 microbench OVERRODE PM 8F's stated rationale. Pattern firmly established.
- **Context-window awareness delegated to user** — user monitors and signals handoff timing. This handoff opened at user direction with ~15% context remaining + S2.c-iii being a discrete next sub-phase.
- **Decisive when data is clear** — when microbench delivered conclusive numbers, user agreed to option 4 immediately ("If the cache really is slower, then there is no argument for keeping it"). When audit revealed no gap, user accepted the conclusion and moved on. Data-driven decision-making was strong this session.

### §8.4 Session arc summary

Started with: pickup from `2026-04-24_PPN_4C_S2c_HANDOFF.md` (S2.c pending — TYPE domain CLOSED, mult domain expected).

Delivered:
- **S2.c mini-design** persisted into D.3 §7.5.13 (commit `107a37c6`) — 11 subsections, 4 architectural questions surfaced and converged through dialogue
- **S2.precursor** (commit `1c3970d0`) — `net-add-cross-domain-propagator` accepts `:c-component-paths` / `:a-component-paths` / `:assumption` / `:decision-cell` / `:srcloc` kwargs; universal infrastructure fix for 6 cross-domain bridges; backward-compat preserved via empty-default kwargs; 3 new contract tests
- **S2.c-i Task 2** (commit `3ceec4fc`) — T-3 'equality audit; option 3a REJECTED; option 3c ADOPTED; permanent regression test (`tests/test-t3-equality-audit.rkt`, 5/5 PASS); D.3 §7.5.13.4 expanded with 5 sub-subsections of audit detail; original S2.c-ii REMOVED from sub-phase plan
- **S2.c-i Tasks 1 + 3** (commit `9e975d45`) — microbench A/B (3 paths × 3 workloads, option 4 wins decisively by 100-302 ns/call across all workloads); initial-Pi-elaboration audit (scenario B exhaustively confirmed; bridge stays); D.3 §7.5.13.5.1 added with bench results
- **S2.c-ii** (commit `bf25be40`) — parameter injection per option 3c; 4 universe-merge parameters wired in elaborator-network.rkt with `compound-tagged-merge`-wrapped per-domain merges; closes the S2.a-followup design intent that was set up but never wired
- 9+ lessons captured (this session arc + carried forward) for codification
- Suite: 7917 tests / 126.4s / 0 failures
- Probe identical to baseline at every sub-phase

**5 commits this session arc; ~600+ LoC net production + design doc + tests; 4 architectural questions resolved with data; S2.c-iii is the next discrete sub-phase with all decisions pre-made.**

**The context is in safe hands.** S2.c-iii is well-scoped (mostly mechanical refactoring with clear architectural target documented in D.3 §7.5.13.6); S2.c-iv is well-scoped (consume S2.precursor's primitive + parallel S2.b-iii's pattern for fresh-mult-meta); S2.c-v measurement is the close. Next session opens with the standard hot-load protocol → mini-design dialogue (may be brief — architecture is settled) → execution.
