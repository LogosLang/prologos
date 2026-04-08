# Session Handoff: BSP-LE Track 2 + Hypercube Pivot

**Date**: 2026-04-08
**From session**: BSP-LE Track 2 Phases 1-3 implementation + design critique cycle + hypercube research
**To session**: Hypercube design addendum + remaining Phase 4-11 implementation
**Protocol**: [HANDOFF_PROTOCOL.org](../principles/HANDOFF_PROTOCOL.org)

---

## §1: Current Work State

**Track**: BSP-LE Track 2 — ATMS Solver + Cell-Based TMS
**Design document**: `docs/tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md` (D.6, 1445 lines)
**Last commit**: `fd82dac7` — Phase 2 CORRECTION (parameter → on-network cell read)

### Progress Tracker (from design doc)

| Phase | Status | Commit | Key deliverable |
|---|---|---|---|
| 0 | ✅ | multiple | Benchmarks + acceptance file (baseline passes L3) |
| 1 | ✅ | `fb0650a3` | decision-cell.rkt + broadcast propagator + 35 tests |
| 2 | ✅ | `0a78069a` + `fd82dac7` | Assumption-tagged dependents, on-network viability, make-branch-pu, 7 tests |
| 3 | ✅ | `a38baefb` | Per-nogood commitment cell + broadcast commit-tracker + narrower + contradiction detector, 9 tests |
| 4 | ⬜ | — | Speculation migration (6 files) |
| 5 | ⬜ | — | ATMS struct dissolution |
| 6 | ⬜ | — | Clause-as-assumption in PUs |
| 7 | ⬜ | — | Goal-as-propagator dispatch |
| 8 | ⬜ | — | Producer/consumer tabling |
| 9 | ⬜ | — | Two-tier activation + parameter removal |
| 10 | ⬜ | — | Solver config wiring |
| 11 | ⬜ | — | Parity validation + inert-dependent checkpoint |

**Suite state**: 394/394 files, 7660 tests, 142.6s, all pass
**Acceptance file**: `examples/2026-04-08-bsp-le-track2.prologos` — Section A (baseline) passes L3

### Next Immediate Tasks

1. **Hypercube design addendum** — fold hypercube/Boolean-lattice insights into the Track 2 design. Affects Phases 6-10 (scheduling, exploration order, nogood propagation). SRE lattice lens on Boolean powerset adjacency.
2. **Phase 4**: Speculation migration (6 files) — after addendum settles design questions for later phases.

---

## §2: Documents to Hot-Load

### Always-Load

| # | Document | Lines | Path |
|---|---|---|---|
| 1 | Project instructions | ~100 | `CLAUDE.md` + `.claude/rules/*.md` |
| 2 | Memory index | ~200 | `MEMORY.md` |
| 3 | Design Methodology | ~800 | `docs/tracking/principles/DESIGN_METHODOLOGY.org` |
| 4 | Design Principles | ~730 | `docs/tracking/principles/DESIGN_PRINCIPLES.org` — includes Hyperlattice Conjecture |
| 5 | Critique Methodology | ~350 | `docs/tracking/principles/CRITIQUE_METHODOLOGY.org` — P/R/M lenses + SRE lattice lens |
| 6 | Acceptance File Methodology | ~200 | `docs/tracking/principles/ACCEPTANCE_FILE_METHODOLOGY.org` |
| 7 | This protocol | ~120 | `docs/tracking/principles/HANDOFF_PROTOCOL.org` |

### Session-Specific (READ IN FULL)

| # | Document | Lines | Why |
|---|---|---|---|
| 8 | **Track 2 Design (D.6)** | 1445 | THE design. Every phase, every NTT construct, every critique resolution. Read ALL of it. |
| 9 | Self-critique | ~230 | `docs/tracking/2026-04-07_BSP_LE_TRACK2_SELF_CRITIQUE.md` — 17 findings, resolutions |
| 10 | External critique + response | ~120 | `docs/tracking/2026-04-08_BSP_LE_TRACK2_EXTERNAL_CRITIQUE.md` — 16 findings |
| 11 | Stage 1/2 audit | ~400 | `docs/research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md` — research synthesis + codebase audit |
| 12 | **Hypercube conversation** | ~550 | `docs/standups/standup-2026-04-08.org` § "Hypercube Conversation" — the research that triggers the addendum |
| 13 | Parallel propagator scheduling research | ~200 | `docs/research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md` |
| 14 | Propagator taxonomy | ~215 | `docs/research/2026-03-28_PROPAGATOR_TAXONOMY.md` — broadcast, scatter, gather kinds |
| 15 | Current dailies | ~100 | `docs/tracking/standups/2026-04-08_dailies.md` |
| 16 | Acceptance file | ~350 | `racket/prologos/examples/2026-04-08-bsp-le-track2.prologos` |

### Key Source Files to Understand

| File | Lines | What Phase 1-3 built here |
|---|---|---|
| `decision-cell.rkt` | ~350 | Decision domain lattice, commitment cell, nogood-install-request |
| `propagator.rkt` | ~2400 | broadcast-profile, dependent-entry (with decision-cell-id), make-branch-pu, install-per-nogood-infrastructure, topology handler |
| `tests/test-decision-cell.rkt` | ~310 | 35 tests for decision + broadcast |
| `tests/test-branch-pu.rkt` | ~175 | 7 tests for PU lifecycle + assumption tagging |
| `tests/test-per-nogood.rkt` | ~130 | 9 tests for commitment + narrowing |

---

## §3: Key Design Decisions (DO NOT REVISIT WITHOUT GOOD REASON)

### Architectural Decisions

1. **No worldview cell** — worldview EMERGES from decision cells. No `worldview-cid` on the network. Consistency = per-decision contradiction detection, not global fan-in. (Self-critique P4, external critique 1.2)

2. **Decision cells are PRIMARY, worldview is derived** — SRE lattice lens revealed this inversion. Nogoods narrow DECISIONS, not worldviews. (Session design conversation)

3. **ATMS struct fully dissolved into cells** — all 7 fields → cells. No off-network state. `atms.rkt` becomes query function library. (Self-critique P4, design conversation)

4. **Broadcast propagator (not N-propagator)** — A/B benchmark: 2.3× at N=3, 75.6× at N=100. ONE propagator, N items, constant infrastructure overhead. `broadcast-profile` struct for scheduler decomposition. (Phase 1Bi data, M1 critique)

5. **Assumption-tagged dependents with ON-NETWORK viability** — `dependent-entry` carries `decision-cell-id`. `filter-dependents-by-paths` reads the decision cell directly from the network. NO parameter. Emergent dissolution: branches die by information flow through decision cells. (Phase 2 design + Phase 2 CORRECTION after parameter violation caught)

6. **Per-nogood commitment cell as structural unification** — cell value IS the provenance. Broadcast commit-tracker writes assumption-ids (not Bools) to component positions. Narrower fires at N-1 threshold. Contradiction detector writes cell value to nogoods cell. (Phase 3 mini-design, SRE lattice lens)

7. **Two-tier activation via topology stratum** — `:auto` is the correct default. Deterministic code pays no overhead. Transition is topology request (PAR Track 1 protocol). (Self-critique P1, confirmed by user pushback)

8. **Component-path invariant (§3.1a)** — any propagator reading a compound cell MUST declare component-paths. Type error in NTT without them. Prevents thrashing. (Design audit + BranchPU interface fix)

9. **Retraction-as-lattice-narrowing** — deferred to Phase 11 checkpoint pending instrumentation data. S(-1) cleanup as `current-dependents ∩ viable-dependents`. Emergent, parallel, on-network. Pattern generalizes to any accumulating network metadata. (Design conversation)

### Process Decisions

10. **Conversational implementation cadence** — max 1h autonomous stretch. Each phase ends with dialogue checkpoint. (Track 4B retrospective)

11. **Phase completion is 5-step blocking checklist** — (a) test coverage, (b) commit, (c) tracker, (d) dailies, (e) proceed. "Will add tests later" is invalid. (Track 4B retrospective)

12. **SRE lattice lens mandatory** — every lattice design decision gets 5-question SRE analysis. (Track 2 finding: worldview misidentified as primary)

13. **Separate critique files** — not inline in design doc. Persistent paper trail. (Session convention)

---

## §4: Surprises and Non-Obvious Findings

1. **`check-true` requires exactly `#t`** — `member` returns list tail (truthy but not `#t`). Use `check-not-false`. (Phase 1 testing)

2. **Commitment cell's `contradicts?` parameter halts the network** — cell-level contradiction stops ALL propagation. The contradiction detector PROPAGATOR must handle the logic, not the cell parameter. Domain-specific contradiction ≠ network-level halt. (Phase 3 integration test failure)

3. **`current-assumption-viable?` was a parameter violation** — ambient state determining on-network scheduling. Same anti-pattern as `current-speculation-stack`. Fixed: `dependent-entry` carries `decision-cell-id`, viability checked via `net-cell-read`. The Network Reality Check should have caught this at Phase 2 commit. (Phase 2 CORRECTION)

4. **Struct field additions break batch workers** — `propagator` gained `broadcast-profile` (Phase 1Bii), `dependent-entry` gained `decision-cell-id` (Phase 2 correction), `perf-counters` gained `inert-dependent-skips` (Phase 2). Each caused stale `.zo` failures in 4-6 test files. The pattern recurs every track — struct field changes require full recompile.

5. **Broadcast is 75.6× faster than N-propagator at N=100** — infrastructure overhead is constant (~2.7μs) not linear. The N-propagator model was architecturally wrong. (Phase 1Bi A/B data)

6. **The per-nogood watcher without component-paths THRASHES** — fires on every decision cell narrowing, even irrelevant ones. Superseded by commitment-cell decomposition with component-indexed writes. (Design audit, §3.1a invariant)

---

## §5: Open Questions and Deferred Work

### The Hypercube Pivot (IMMEDIATE — shapes Phases 6-10)

The ATMS worldview space IS a hypercube Q_n (Boolean lattice 2^n). This was discovered via a research conversation captured in `docs/standups/standup-2026-04-08.org` § "Hypercube Conversation". Key implications:

1. **Gray code traversal** for worldview exploration — maximizes CHAMP structural sharing. Shapes Phase 6 (`atms-amb` branch ordering).
2. **Subcube pruning** for nogoods — structural O(1) identification of all affected worldviews. May enhance Phase 3's per-nogood narrowing.
3. **Hypercube all-reduce** for BSP barriers — optimal synchronization topology. Shapes Phase 9-10 (scheduling).
4. **Adjacency metric** on the powerset lattice — Hamming distance. New SRE property to analyze.

The user wants a **design addendum** — tightly linked to the current design, as thorough as the D.6 document, incorporating the hypercube structure through the SRE lattice lens. This is the next task.

### Deferred with Tracking

- **Phase 11 checkpoint**: Review inert-dependent instrumentation data. If >50 inert per hot cell → S(-1) lattice-narrowing cleanup. (Design §2.4, Phase 11 item 6)
- **SRE domain registration**: Decision domain registered with SRE form registry. Deferred to Phase 5 (needs solver context). (Phase 1 decision)
- **Tropical hitting set for ATMS diagnosis**: Designed (§2.6e) but implementation deferred. Self-referential: solver diagnoses itself on fresh network. (Design conversation)

---

## §6: Process Notes

### Gates and Invariants (APPLY AT EVERY COMMIT)

- **Network Reality Check**: Which `net-add-propagator` calls? Which `net-cell-write` produces result? Can you trace cell → propagator → cell → result? (Phase 2 violation caught by user: parameter read instead of cell read)
- **Vision Alignment Gate**: On-network? Complete? Vision-advancing?
- **§3.1a Component-Path Invariant**: Any propagator reading a compound cell MUST declare component-paths.
- **Phase completion checklist**: (a) tests, (b) commit, (c) tracker, (d) dailies, (e) proceed.

### Testing Conventions

- Shared fixture pattern for `process-string` tests
- `check-not-false` for membership tests (not `check-true`)
- Struct field additions require full recompile (`raco make driver.rkt`)
- Per-phase tests — not deferred to Phase T

### Design Conventions

- Mini-design conversation before each phase (review design + critique docs)
- SRE lattice lens for any new lattice
- Broadcast propagator for any data-indexed parallel operation (not N-propagator)
- "for each" / "scan" / "iterate" are step-think red flags
- Data-driven topology descriptors (not callbacks) for topology requests
