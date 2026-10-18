# PAR 4 D.3 — critique synthesis (waves 1 and 2)

**Of**: [D.2](../2026-10-15_PAR_4_D2_DESIGN.md) at `430e42bb`, its
[self-critique](2026-10-15_PAR_4_D2_SELF_CRITIQUE.md), the [wave-1 triage](2026-10-15_PAR_4_D3_WAVE1_TRIAGE.md)
(103 findings, clusters CL-1…CL-18) and the ten wave-2 returns
([briefing](2026-10-15_PAR_4_D3_WAVE2_BRIEFING.md); launched 2026-10-18 09:43, returned 10:49).

**Evidence**:
- Wave 1 is in `racket/prologos/benchmarks/par4/d3-wave1/`.
- Wave 2 is in `racket/prologos/benchmarks/par4/d3-wave2/<agent>/`. All ten returns, verbatim, are in
  `raw/wave2-returns.json`. My own reproductions are in `_handcheck/`. Large traces are gzipped, and W2-2's archived
  build tree was not kept: `W2-2/w22-variants.patch` and `apply-variants.py` regenerate it.

**Status**: this is the synthesis of record. Every finding from both waves gets one of four responses:
- **accept**;
- **amend**: the problem is accepted and the direction is changed;
- **reject**: the claim against D.2 does not hold;
- **defer**: to the K > 1 sequel (§4) or to another track.

The responses are mine. Each was weighed against [`DESIGN_PRINCIPLES.org`](../../../../principles/DESIGN_PRINCIPLES.org)
and the evidence, and the agents' returns were treated as input only. The per-finding table is Appendix A. D.3 is
written from this document. The owner decisions it raises are queued in §7 and are posed one at a time.

**Labels** continue the triage's sequences: `SC-22` onwards (self-corrections), `PD-8` onwards (production
defects), and `O-14` onwards (owner decisions; O-11…O-13 are pending in D.2 §15). No new prefix is introduced.

---

## 0. The result in brief

1. **K > 1 has no workload in this repository.** W2-1 and W2-8 established this independently, each with its own
   code. The binding limit is the dependency chain, not the unit of ownership:
   - The BSP trace's work/span is **1.28 / 1.49** on the two heavy files (W2-1). The DAG critical path is within
     2–3 % of the per-round span (W2-8).
   - The cap is the same for every unit tried: per cell, per (position, facet), per propagator, and ideal LPT
     placement. Asynchrony adds at most 2–3 % over rounds.
   - Per-component ownership fixes the balance: the busiest executor's share by time drops to ≈ 1/K. It still
     leaves time-weighted parallelism at **1.19 / 1.35**.
   - The best case is ≤ 1.28× / 1.49× on S0 fire time. Through Amdahl that is **≤ 1.05× / 1.06×** on command time.
   - The realized executors measure **0.84–0.96×** on the heavy files' S0 (W2-8).

   This settles CL-1 against the triage's own lean: the component-ownership direction would have bought balance and
   no speed (SC-22). It confirms C10-6, so the asynchronous half of D.2 §6.7 leaves PAR 4 (owner decision O-15).
2. **The sequential levers are large, measured and ordered.** W2-2 made one build with environment switches and
   timed 8 interleaved rounds under the suite lock. Heavy files, as-is → executor off → executor off with the keyed
   diff:
   - constraints-adversarial: **66.3 → 44.1 → 30.0 ms**;
   - type-adversarial: **63.5 → 40.9 → 32.1 ms**.

   That is 2.2× / 2.0× before any scheduler work. The medium tier gains 1.46×.
   - The keyed diff is a THEOREM under a stated hypothesis. It is checked by a monitor (0 mismatches in 2992 writes)
     whose power row is caught on 1980 writes.
   - Delta-carried writes reach 3.45× / 2.52× over today, but they are **not equivalent**: 2 of 1034 writes merge to
     a different value, on the non-join meta-vs-meta `:type` merge.
3. **Production gives wrong answers and hangs today.** These are correctness items for P0.5 and P1a, and they are
   independent of K. All of the following were reproduced by hand (§1):
   - Under the default `:strategy auto`, a single `not` goal sends a query to ATMS, and DEFERRED 177's wrong answers
     then appear in a plain `solve`.
   - Two further wrong-answer shapes exist on the shipped solver: a lost answer, and a duplicated answer that DFS
     rejects.
   - The production thread executor hangs silently when a fire raises in a round of ≥ 8. The LSP sends its error
     port nowhere.
   - An inline solver override resets every key it does not name. That turns a working well-founded query into an
     uncaught DFS depth error that aborts the whole file.
4. **Output parity has no power.** Three agents showed it independently:
   - W2-2: a deliberately wrong diff changed no printed result in 17/17 files.
   - W2-5: a worldview poison that changes 18 fires changed 0 of 1024 printed results.
   - W2-4: no test pins a wrong ATMS answer, and none could catch one.

   Every PAR 4 gate that reads "the suite is green" or "parity shows 0 differences" is therefore replaced by
   per-write and per-fire differential monitors, each with its power row (§5.4).
5. **P2 (DIRECT at K = 1) stays, but on a different case.** W2-9's defence holds. The case is semantic and
   structural:
   - writers that read-modify-write a non-join cell become serializable (row R2: BSP and BSP+Δ lose an update that
     DIRECT keeps);
   - the Tier-1 branch and its defect (DEFERRED 178) are deleted, and so is the drain.

   The speed case also holds, but it was overstated. My bound is **≤ ≈ 2.2× / 1.9×** over the P0.5 build, not W2-2
   Q4's 3.2–3.3× (§1, SC-23). The only other route to that gain is delta-carried writes, which are non-equivalent and
   duplicate DIRECT's write path. BSP stays as the replay oracle. C1-8's theorem is written into D.3 as the reason
   BSP's rounds are semantic. The lifted Kleene network is not built.

---

## 1. Hand checks

Each row was re-run or re-read by me. Where an agent's claim did not survive, the row says so.

| claim | agent | how I checked | result |
|---|---|---|---|
| one `not` goal under `:auto` reproduces 177's three rows in a plain `solve` | W2-4 | `tools/scratch-run.sh -t 140 …/W2-4/reach/reach-naf.prologos` | **reproduced** |
| `(pick ?x) (pick ?y) (= ?x ?y)` loses `{x 2, y 2}` under ATMS; `(pick ?x) (= ?x 2)` returns `{x 1} {x 2} {x 1}` | W2-6 | `…/W2-6/w26-crosssite.prologos`; output in `d3-wave2/_handcheck/mine-crosssite.out` | **reproduced**: ATMS `@[{:x 1, :y 1}]` against DFS `@[{:x 1, :y 1} {:x 2, :y 2}]`; ATMS `@[{:x 1} {:x 2} {:x 1}]` against DFS `@[{:x 2}]` |
| an inline override resets `:semantics` and aborts the file | W2-10 | `…/W2-10/u8a.prologos`, `u8b.prologos` | **reproduced**: without the override `@[]`; with `{:timeout 100}`, `solve: Depth limit exceeded (100)` and no later result is printed |
| the production thread executor hangs when a fire raises in a round of ≥ 8 | W2-10 | re-ran `…/W2-10/exec-exn.rkt`; read `propagator.rkt:3691-3728` | **reproduced, and the mechanism was read in the code**. N = 4: raises (sequential below the threshold of 8). N = 12: hangs, with the text on the run's error port. Each chunk thread calls `channel-put` only on success (`:3715-3721`) and the joiner blocks in `channel-get` (`:3726`). Power rows: no raise ⇒ every leg returns ok |
| keyed diff = full diff under H | W2-2 | read `propagator.rkt:1657-1694` (`pu-value-diff`) and `typing-propagators.rkt:447-470` (`attribute-map-merge-fn`) | **holds**: the merge folds from `old` and only `hash-set`s keys of `new`, so keys outside `new` stay `eq?` and the removed-key loop cannot fire |
| `current-impl-registry` is read inside the constraint-creation fire | W2-5 | read `constraint-propagators.rkt:55` | **holds**: a default argument `[impl-reg (current-impl-registry)]`, directly under a comment saying the registry is passed explicitly "to avoid parameter coupling" |
| P2 gives 3.2–3.3× / 2.0–2.1× over the build with the executor off and the keyed diff on | W2-2 Q4 | consistency check against W2-2's own timed legs | **does not survive as stated** (SC-23). Leg E (delta-carried writes, which remove almost all of `bulk-merge-writes`) is timed at 20.7 ms, and 539 of its 817 samples (66 %) are outside BSP. Delta writes change nothing outside BSP, so that ≈ 13.7 ms is a floor under any S0 scheduler. P2 over D (30.0 ms) is therefore ≤ ≈ 2.2× on constraints and ≤ ≈ 1.9× on type (35.1 ms over a ≈ 18.6 ms floor). ESTIMATE; it assumes D's time outside BSP equals E's. The sampler's 3.2× counts all of `bulk` as removable, including the topology and new-cell share it excludes for E |
| P2 needs no K > 1 to be worth building | W2-9 vs W2-2 | the two returns read together | **holds**: an equivalent gain exists only through DIRECT; the delta-write route is non-equivalent (W2-2-1) |
| the DAG ceiling is 1.28 / 1.49 | W2-1 vs W2-8 | the two returns compared; separate code (`gran_analyze.py`; `w28-*`) | **replicated**: 1.26–1.28 / 1.46–1.49 (W2-1) and 1.22–1.28 / 1.45–1.55 (W2-8). Both power rows report parallelism where it exists: pid homing ≈ 4 by count; grid12 4–16 |

All runs held one Racket process, with `timeout -k`. None needed the suite lock, because nothing was timed.

---

## 2. Self-corrections (continuing SC-21)

- **SC-22** (triage CL-1). The lean "make the component the unit of ownership" would have fixed balance and bought
  ≤ 1.05× on command time (W2-1 Q2; W2-8). The hub was the visible symptom; the dependency chain is the limit. D.2
  §2 item 3's model (fire time / min(width, K)) assumes every fire in a round is independent. That model class is
  wrong, and D.3 replaces it with work/span from the BSP trace (W2-1-1).
- **SC-23** (this synthesis, about W2-2 Q4). P2's gain over the P0.5 build is bounded by the floor outside BSP: at
  most ≈ 2.2× / 1.9×, not 3.2–3.3× / 2.0–2.1× (§1).
- **SC-24** (triage §4 PD-1). "Reach: above the DFS↔ATMS crossover (256)" understated the reach. One `not` goal in
  a clause of the queried relation is enough (`stratified-eval.rkt:265-270`; W2-4).
- **SC-25** (triage §7, W2-6's charge). `test-solver-context.rkt:341-362` does **not** pin today's semantics. It is
  the regression catcher, and it passes once the viewpoint is per query (W2-6 Q3). Only `test-tagged-cell-value.rkt`
  must flip.
- **SC-26** (triage CL-13 lean). The interim fix (capture the per-run parameterization and install it on each wake)
  fixes 12 of the 42 stale fire-read parameters. Direct assignments are not carried by `call-with-parameterization`
  (W2-5 Q2a).
- **SC-27** (D.1 SC-14). The ack point, not the resettable flag, is what makes `detect.rkt`'s scheme sound: cons is
  published after the drain (W2-3-4).
- **SC-28** (P0 §4.1). "0 premature declarations" was a check that could not fail: P0's rows contain no local
  cascade. On a CASCADE row, D.2's detector declares early in 7/7 trials (W2-3 Q1).
- **SC-29** (D.2 §2 item 3, P0 §10.1). The repository's K > 1 evidence measured parallel ceremony on networks that
  do not propagate. PAR 2's demos merge by union, so a narrowed domain merges back to the full one: 1 round, 0
  productive fires (W2-8-2).
- **SC-30** (DEFERRED 177's fix shape). The fix shape I filed ((a) read base ⊔ matching entries, (b) unify both
  sides, (c) flat ⊤) fixes its own three rows but not the two cross-site shapes in §1. Those also need a viewpoint
  per propagator and lifted fires (W2-6-1). Addendum filed on main (§6).
- **SC-31** (triage CL-16, from C10-5). "P1b matters only at K > 1" is false for three classes:
  - the S1 NAF handler's write to cell 1 is undone if the projection re-fires (W2-4-1);
  - fire-once on a growable latch breaks the Kleene reading of rounds (E2);
  - absence-reading fires break it too.

  At K = 1 these affect the replay oracle and answers, not races.

---

## 3. Wave-2 verdicts and my responses

| agent | question | verdict | my response |
|---|---|---|---|
| W2-1 | Q1 per-cell home rule, busiest share by time | holds with amendment: 0.986 / 0.967 by time (0.893 / 0.847 by count) | accept |
| W2-1 | Q2 per-component ownership recovers parallelism | **fails**: balance ≈ 1/K, parallelism 1.19 / 1.35, work/span 1.28 / 1.49 | accept; SC-22 |
| W2-1 | Q3a alternations ∝ BSP rounds (C9-11) | **fails on the corpus**: ≤ 2 switches per S0 run (mean 1.44–1.55); switches plus detections ≈ 0.75–0.8 × rounds | accept: C9-11 is rejected as stated; its cost direction holds and moves to the sequel |
| W2-1 | Q3b component fencing frees the hub | **fails**: 85–92 % of fire time is fenced per component, 97–99 % per cell | accept: D2P-5 selects the whole-network rule at either granularity |
| W2-1 | Q4 beyond the heavy files | holds with amendment: 6 of 17 run no BSP S0; S0 fire is 1.2 % of command | accept |
| W2-1 | P3 has a workload | **none**, for any unit or K ∈ {4, 8, 16} | accept; O-15 |
| W2-2 | Q1 executor off | 1.50–1.55× heavy; 1.28× medium tier; ≈ 7 ms of the saving is GC | accept; O-14 |
| W2-2 | Q2 keyed diff equivalence | holds: THEOREM + monitor 0/2992, power 1980/2992 | accept; it lands in P0.5 with its own baseline |
| W2-2 | Q3 C10's 4.4× / 2.2× | holds with amendment: 3.45× / 2.52× including the executor's removal; delta writes non-equivalent (2/1034) | accept; delta-carried writes are not built (§5.2) |
| W2-2 | Q4 P2's remaining gain | holds with amendment | **amend**: bounded at ≤ ≈ 2.2× / 1.9× (SC-23) |
| W2-3 | Q1 D.2's detector premature | holds: 22 steps under SC; 7/7 on CASCADE | accept; SC-28 |
| W2-3 | Q2 repairs | smallest sound repair: **SEEDS with a one-pass detector** (counted seeds, cons after drain, no idle indicator, read every cons then every prod); costs the same as D.2's scheme; credit costs 16–50× and cannot be keyed by region | accept; **deferred** with the sequel, whose seed carries it verbatim |
| W2-3 | Q2-FR, Q2-CONTRA, Q2-REGIONS | counted fire requests are needed by every repair; the boundary fires on quiescence ∨ contradiction with a parking handshake; a region closes only when its sums balance and every upstream region is complete | accept; deferred with the sequel; BC-4 gains the upstream condition |
| W2-3 | Q3a late-write check | a parking handshake; `'late-s0-write` becomes an executor-local assertion | accept; deferred |
| W2-3 | Q3b lanes as logs | removes one of the two ordering invariants | accept; deferred |
| W2-4 | PD-1 reach | wider than filed; in-repo programs do not hit it (12 of 293 auto-routed take ATMS; 460 solve lines match) | accept; SC-24; 177 addendum |
| W2-4 | PD-3 shared mutable state today | holds with amendment: the perf counters race (36–180 increments lost per run); the shared boxes are only read | accept; it becomes part of DEFERRED 181 |
| W2-4 | PD-2 reach | not reachable through today's production paths: the projection propagator is on every query worklist; NAF forks use fresh cells | accept; 178 addendum; P2 deletes Tier 1 |
| W2-4 | PD-5 reach | latent: maximum 1 outer iteration in 84 programs and 19 test files | accept |
| W2-5 | Q1 static census | 83 of 219 parameters are read in fire-reachable code; two that D.2 missed matter | accept; §6.5's inventory is rewritten |
| W2-5 | Q2 persistent executor | 80–98 stale; capture leaves 63–81; 29 wrong fires, all through `current-impl-registry` | accept; SC-26; deferred with the sequel, except the registry read (§5.3) |
| W2-5 | Q2 today's per-round threads | reads correct; the exposure is on the write side (lost assignments, read-modify-write races; on power rows, not reached by the corpus) | accept; folded into O-14's evidence |
| W2-6 | worldview proposals consistent | yes, with four amendments: A1 premise set P, A2 retire cell-1 as the tag source, A3 ⊤ under ev_W ⇒ nogood, A4 labelled outputs | accept; P1a rows 1–3 are rewritten on them |
| W2-7 | `:usage` | the chain forces "unknown = unused" or strictness; the interval lattice is the smallest exact carrier; the cell merge is never exercised | accept; row 4 leaves P1a's correctness list and becomes a carrier contract (W2-7-1) |
| W2-7 | row 8 | 94 erasures remain through `try-unify-pure`'s success branch; a third residual shape (applied metas) | accept; P1a row 8 computes a linear, occurs-checked σ; PC-2 lists three residual shapes |
| W2-7 | row 2 | flat ⊤ per key gives DFS's answers on 10/10, with the var-var fire lifted per entry and ⊤ read as the nogood of the joined labels | accept |
| W2-8 | defence: keep K > 1 in PAR 4 as round-synchronous BSP-K | concedes the asynchronous half; defends BSP-K (snapshot, dynamic placement, pid-order fold, K-independent, result-identical with a mutant power row; 1.83–2.78× on constructed narrowing networks) | **defer**: see below |
| W2-9 | defence: P2 at K = 1, BSP as oracle | P2's value is semantic and structural; the keyed diff lands first; delta writes are a substitute for DIRECT; the lifted network is sound but not cheaper | **accept**, with SC-23 bounding the speed half |

**Why BSP-K is deferred rather than kept** (my response to W2-8). It is a tradeoff analysis against the design
principles:
- **The defence is strong on soundness.** A K-independent fold needs no detector, fence or ownership, and its
  mutant power row shows that the result-identity check can fail.
- **It has no workload in the repository.** Its gains come from networks W2-8 constructed.
- **Today's thread-per-round executor is already a round-synchronous K > 1 executor of this kind.** W2-8 measured
  it at 0.84–0.96× on the heavy files' S0.
- **Deferring it forecloses nothing.** The executor seam `current-parallel-executor` (`propagator.rkt:3675`) survives
  O-14: W2-1, W2-5 and W2-8 all used it for injection. BSP stays as the oracle, so BSP-K's home stays too.
- **What the sequel inherits:** BSP-K as its first and cheapest step; W2-8's intersection-merge networks as its
  wide-workload gate, with productive fires > 0 asserted; and C6-5's machine budget, so K defaults to 1.

This is a lean for O-15, not a decision.

---

## 4. The K > 1 sequel: what moves, and what it inherits

If the owner takes O-15's lean, the following leave PAR 4 for a sequel track. The series is PAR; the owner names
the track. It is co-designed with BSP-LE 3 and PPN 4C, as C10-6 proposed.

| moves | inherits from this round |
|---|---|
| D.2 §6.7 entire: persistent executors, owned slots, lanes, ownership and home rules, detection, late writes, the contradiction stop | W2-3's SEEDS one-pass detector with its fences, counted fire requests, the parking handshake, region keys with upstream completeness; C6-3's memory-order citations; C4-8 / W2-3 Q3b's log-with-cursor lanes |
| the fence (D.2 §6.3) and the alternation | CL-4 (a)–(g) as requirements; W2-1's per-component numbers; W2-9-2's read-modify-write disposition |
| BSP-K (W2-8) | its K-independence argument and mutant row; W2-8's narrowing networks as the gate |
| persistent-executor fire context | W2-5's census, per-parameter attribution and fire-level differential; SC-26 |
| P1b's race-only dispositions | the classes that matter at K = 1 stay in PAR 4 (SC-31) |
| K as a machine budget | C6-5; W2-10-7's dispersion and oversubscription rows |
| reproducibility at K > 1 | W2-10-4's seeded simulated-K executor (CHESS, PCT) |
| C1-7's storage strategy and the γ1 question | the γ1 principle question moves with it (`DESIGN_PRINCIPLES.org:1106`) |

The sequel's entry condition: a workload whose S0 runs show work/span ≥ 3 and an S0 share ≥ 30 % (W2-1's
falsifier). BSP-LE 3's on-network search is the named candidate.

---

## 5. Responses by theme

Each theme names the D.3 section it lands in. D.3's section names are fixed here, so that Appendix A can cite them.

### 5.1 P0.5: the defect batch (correctness first)

P0.5 now carries the following, all independent of K:
- **Delete the production thread executor** (`driver.rkt:567`; O-14). The evidence:
  - cost 1.50–1.55× on the heavy files (W2-2);
  - a silent hang on an exception (DEFERRED 181);
  - counter races (W2-4);
  - lost direct assignments on power rows (W2-5).

  The executor seam stays (§3).
- **Delete the pool executor** (C7-3, PD-4) and **DEFERRED 150's tree path** (O-9, decided).
- **157(a) and (b)**, with W2-4-2's `truths` parity rows and the S1 NAF handler from W2-4-1 (157 addendum). These
  route through the merge only where the merge is a join (C2-8).
- **The keyed diff** for merges registered key-preserving, with W2-2's monitor and power row as a test. It gets a
  baseline of its own, B-P05′, and P2 is credited none of its gain (W2-9).
- **Exceptions become data at the fire wrapper** (W2-10-1), at K = 1 as well. See §5.5.
- **Interim fixes only if P2 slips**: DEFERRED 178 (P2 deletes Tier 1; W2-9-3).

Baselines:
- **B-P05′** = executor off, measured on W2-2's harness.
- **B-P05″** = B-P05′ plus the keyed diff.

P0's model rows are re-derived from sequential fire times (C7-1, C7-7).

### 5.2 P2: DIRECT at K = 1, with BSP as the oracle

**Kept, with its case restated** (W2-9; SC-23):
- read-modify-write writers on non-join cells become serializable (R2);
- one write path, so the per-fire log and the classification of writes against a snapshot go away;
- Tier 1 and the drain are deleted (CL-7, W2-9-3);
- the speed gain is bounded at ≤ ≈ 2.2× / 1.9× over B-P05″.

**Delta-carried writes are not built.** They are a substitute for DIRECT, they apply every write twice, and they
are not equivalent on the `:type` meta-vs-meta row (W2-2-1, W2-9).

**The replay** is BSP's inner loop:
- It compares the union of both runs' changed sets (C7-4), with executor mutants as power rows.
- C1-8's theorem is stated as the reason the rounds are semantic, under H and E1–E5 (C5-4).
- E1 was measured to hold on the corpus: 0 of 2 901 S0 fires read undeclared cells (W2-9-1). The census becomes a
  co-inductive monitor.
- **Until row 8 is a join**, the replay is expected to differ on that row. Differences there are classified, not
  counted as failures (W2-2-1).

### 5.3 Fire context

- **Delete the srcloc binding.** It has 5 reads, not 13 (SC-19; C1-9, C7-10).
- **The constraint-creation fire gets its registry as data.** The installer passes the value or the registry
  cell-id, and the default-argument read goes (W2-5-2).
- **Perf counters** leave fire bodies and are counted per epoch.
- **`current-worldview-bitmask`** is inventoried (C2-5) and retired through P1a row 1.
- The persistent-executor work moves to the sequel.

### 5.4 Gates and instruments (G-2's three layers)

- **Output parity is a smoke test, not evidence** (W2-2-2, W2-5-1, W2-4). Every gate gets a differential at the cell
  or fire level with a power row: the keyed-diff monitor, the fire-context differential, and a DFS-vs-on-network
  answer differential with C9's 5 programs, W2-7's Q4–Q8 and W2-6's R5/R6 in `test-solver-parity.rkt` (W2-6-4,
  W2-7-4).
- **Comparisons are taken modulo α-renaming of gensyms and metas.** Printed results already differ between
  identical sequential runs (W2-5-3, W2-8-3). Diagnostics are compared as sets.
- **P0-8 becomes the instrument set**: work/span per S0 run from the BSP trace (W2-1's `gran_analyze.py`), the E1
  census, the fire-context differential, and a run-boundary hook with a Tier-1 observer record (W2-4-3).
- **Per-file counts state their preload** (W2-1-4).

### 5.5 Faults versus contradictions (new in D.3)

W2-10-2's separation is accepted. It is information flow, and it is needed at K = 1:
- **A program contradiction** is ⊤ in a domain lattice. It is the user's error or a logical failure.
- **A system fault** is a monotone set of (reason, propagator, epoch) at the scheduler layer. It is never written
  into a cell that a consumer reads as a logical failure. Reasons include: an exception in a fire (DEFERRED 181),
  structure created in a fire (158), the strata-cap overflow (PD-5), fuel exhaustion and, in the sequel, late
  writes.
- **At the boundary**, one fault is re-raised, chosen canonically, with its propagator's source location.
- **Contradictions are sets**, reported canonically (C5-8, PD-6).
- **An in-fire diagnostic writes only monotone facts.** The derivation is computed at the boundary (W2-10-6),
  because a production consumer (E1006) exists.

### 5.6 Budgets and the surface contract (O-2 re-opened)

- CL-9 is accepted. Production budgets are calibrated in fires and visible to users.
- W2-10-3 adds the surface:
  - `:timeout` is implemented as ms × 1000 fires, so `:timeout 0` still returns every answer;
  - `:parallelism`, `:fairness` and `:scheduler-io` are validated and never read;
  - an inline override resets every unnamed key (DEFERRED 182).
- D.3 gets a surface-contract section, and the meaning of the budgets is posed to the owner (O-16).

### 5.7 P1a: merge laws, rewritten on wave 2

- **Row 1, the worldview.** Cell-1 := α(assumptions, decisions, nogoods), with one writer: the projection.
  - The premise set P carries committed speculation (A1). Readers read at W ∪ P.
  - Cell-1 retires as the tag source (A2).
  - `live` is read only at boundaries, over completed nogoods.
  - Guards and NAF write nogood environments. C8-5's anti-monotonicity is in the bit encoding: 0/144 rows are
    killed with environments, against 24/144 with bits.
  - The S1 NAF handler's AND-NOT goes (W2-4-1).
  - `make-branch-pu` is dead (W2-6 Q2).
- **Row 2.** ⊤ under ev_W is the nogood of the joined labels; with an empty label set, it is the query's failure.
  The var-var fire is lifted per entry (W2-7 Q4).
- **Row 3.** The ev_W read. The compat first-match path (`decision-cell.rkt:472`) and its three callers are deleted
  (W2-6 Q1(a)).
- **Row 4** leaves the correctness list. It becomes a carrier contract (interval coordinates, one writer per
  position) for when QTT moves on-network (W2-7-1; PPN contract).
- **Row 8.** Clash ⇒ ⊤ with the clash test "`try-unify-pure` fails". The success branch computes a linear,
  occurs-checked, scope-checked σ (W2-7-3). Three residual shapes go to PC-2: σ, disjunction, pattern constraint
  (W2-7-2). Role A on equality sub-cells is flagged to PPN 4C (W2-7 Q3).
- **Order.** Row 1 lands with or after P2's deletion of Tier 1, because Tier-1 dispatch reads cell-1 (W2-6-3).

Who owns the fix for DEFERRED 177, PAR 4's P1a or BSP-LE 3, is an owner decision (O-17), because it is the solver's
correctness, not PAR 4's speed.

### 5.8 P1b: the K = 1 core

P1b keeps three classes (SC-31):
- fire-once only on stable latches, with a trigger-held fired latch (CL-7);
- absence-reading fires rewritten under C3-11's one rule;
- the S1 NAF handler's cell-1 write.

The rest moves to the sequel. O-13 is re-posed narrowed.

### 5.9 Observation

- O-11 gains option (c): a post-hoc query against retained epoch records (W2-10-5).
- C8-11's on-network consumer (PPN Q-4B5.10) answers O-11's "settles it" clause.
- At K = 1, x⁰ₑ is a pointer, so RM-2 needs no measurement (C3-10).

---

## 6. Production defects: final table, and what was filed

| id | defect | reproduced | record |
|---|---|---|---|
| PD-1 | ATMS answers that DFS rejects. The reach is wider (one `not` goal under `:auto`), and there are two more shapes (§1) | yes (wave 1 and §1) | DEFERRED 177 + addendum (main) |
| PD-2 | Tier-1 non-fixpoint | yes (wave 1); **not reached by production paths** (W2-4) | DEFERRED 178 + addendum (main); deleted by P2 |
| PD-3 | thread executor: cost; counter races | measured (W2-2, W2-4) | folded into DEFERRED 181; O-14 |
| PD-4 | pool executor drops fires | measured (C7); dead code | P0.5 |
| PD-5 | strata outer-loop cap raises uncaught | latent (W2-4: max 1) | system fault (§5.5); BC-3 |
| PD-6 | the reported contradiction depends on order | measured (C5, C9) | §5.5 |
| PD-7 | the BSP-LE master's completion definition | probe (C8) | proposal to the owner (CL-17) |
| **PD-8** | a fire exception hangs the production executor on rounds ≥ 8; the LSP wedges with an empty log | **yes (§1)** | **DEFERRED 181** (main) |
| **PD-9** | an inline solver override resets every unnamed key; a well-founded query becomes an uncaught DFS depth error that aborts the file | **yes (§1)** | **DEFERRED 182** (main) |
| **PD-10** | the S1 NAF handler AND-NOTs cell-1 directly while the projection propagator also writes it; latent non-fixpoint | measured (W2-4-1: one re-fire turns light-vehicle's answer into one DFS rejects) | DEFERRED 157 addendum (main) |

---

## 7. Owner decisions raised (posed one per turn, in this order)

| label | question | lean | posed |
|---|---|---|---|
| **O-14** | remove the production thread executor (`driver.rkt:567`) in P0.5 | remove; keep the executor seam | **DECIDED (a) 2026-10-18**, with G-4 (§8) |
| O-15 | scope, reframed by G-4: how the exploration portfolio (§8) and PAR 4's K = 1 work are organised | PAR 4 = K = 1 + the shared substrate; a separate PAR track runs the portfolio concurrently, starting with the profile | **posed 2026-10-18**, D.2 §15 |
| O-16 | budgets and the surface contract: what `:fuel` and `:timeout` count; the dead strategy keys; override semantics (re-opens O-2) | after O-15 | queued |
| O-17 | who owns DEFERRED 177's fix: PAR 4 P1a rows 1–3, or BSP-LE 3 | after O-15 | queued |
| O-11, O-12, O-13 | re-posed with this round's amendments: O-11 gains (c); O-12 changes shape at K = 1 (no fence; the replay classifies row 8); O-13 narrows to the K = 1 core | with D.3 | queued |

Minor cross-track proposals go to the owner with D.3 rather than as decisions: PC-5 and PC-6, BC-2/3/4/6, the
BSP-LE master edit (C8-10), and branch `preduce-autonomy`'s pre-allocated cell ids (C8-12).

**Update 2026-10-18.**
- O-14 is DECIDED (a).
- The owner's guidance G-4, given with it, reframes O-15: the K > 1 work is not a sequel that waits, but an
  exploration program across several parallel and distributed architectures (§8).
- O-15 is posed in D.2 §15 on that framing.

---

## 8. After O-14: G-4 and the exploration portfolio (2026-10-18)

**G-4** (owner, given with O-14): *"we're also trying to explore the space of new frontiers of what is possible. …
The goal is to combine CALM with distributed, incremental compilation, and put these distributed, parallel compute
approaches into practicle compiler practice. So we should probalby be exploring multiple variations of
parallel/distributed architecture to discover what works best."*

**What this round's negative result does and does not say.**
- **It is a strong-scaling (Amdahl) result:** a fixed workload, within one command, at the granularity of fires and
  S0 runs. It measured work/span 1.28 / 1.49 there.
- **It says nothing about weak scaling** (Gustafson 1988; `docs/research/RESEARCH_PARALLEL.md` §2.3). Weak scaling
  is what happens to span when the problem grows with the processors.
- **In a compiler, the problem grows by adding definitions, modules, documents and edits, not by lengthening the
  inference chain of one command.** So the Gustafson axis lives at the coarser granularities, which nobody has
  measured.
- **There is a measured hint.** W2-1 found that the largest S0 run is only 8–11 % of a heavy file's S0 time, so
  T / max-run is 9–12. That is an upper bound on parallelism *across* S0 runs, if they are independent; their
  dependencies were not measured.

Hence the conjecture this program tests, labelled CONJECTURE: span grows sublinearly in program size at the
definition and module granularities, so scaled speedup exists there even though strong speedup does not exist
below them.

**The parallelism hierarchy of this compiler, finest to coarsest.** The theory column names what each level rests
on, so that a variant can be checked and critiqued.

| level | unit of parallel work | rests on | measured so far |
|---|---|---|---|
| fire | fires in one BSP round | BSP; Brent's work–span bound | work/span 1.28 / 1.49; realized 0.84–0.96× (W2-1, W2-8) |
| S0 run | asynchronous chaotic iteration within one run | Üresin–Dubois / Bertsekas asynchronous iteration; Mattern termination detection | ≤ 3 % over rounds (W2-8); sound detector found (W2-3) |
| across S0 runs | independent runs within one command | the same; independence measured from the trace | **not measured**; T / max-run 9–12 is the bound if independent |
| definition | top-level definitions and commands of one module | CALM: definition types are monotone interface cells; defaulting, zonk-final and diagnostics are boundaries | **not measured**; PPN 4C's batching is the precondition |
| module | modules in the import DAG | build-system theory (Mokhov, Mitchell and Peyton Jones, *Build Systems à la Carte*, 2018); the `.pnet` cache as a content-addressed artifact | **not measured**; the test runner's process-level parallelism is the existing precedent |
| machine | networks on separate processes or hosts exchanging cell deltas | CALM (Hellerstein and Alvaro, 2020); lattice dataflow (Hydroflow); distributed progress tracking (Naiad / timely dataflow, Murray et al., SOSP 2013) | **not measured** |
| search (orthogonal) | worldviews or OR-branches | OR-parallel logic programming (Aurora, Muse); ATMS worldviews are independent until a nogood joins them | **not measured**; BSP-LE 3 is the named workload |
| topology (orthogonal) | rewrites of disjoint sub-networks at the topology stratum | parallel rewriting in adhesive categories (PAR master Q2) | **not measured** |
| incremental (orthogonal) | the changed cone after an edit | an edit is a retraction. Making it monotone needs a version-indexed lattice, as in differential dataflow (McSherry et al., CIDR 2013): collections indexed by partially ordered times. **CONJECTURE**: the same construction places the edit's non-monotonicity at a version boundary for propagator cells | **not measured** |

**The first step is an instrument, not an executor.** A hierarchical parallelism profile reports work, span and
self-parallelism at every level of the table. Precedents: Kremlin's hierarchical critical-path analysis (Garcia et
al., PLDI 2011) and Cilkview (He, Leiserson and Leiserson, SPAA 2010). Requirements:
- It is run on today's corpus **and on generated programs of growing size**, which is the Gustafson test: does span
  grow slower than work, at which level?
- It needs no rebuild at the fire and S0-run levels. W2-1's `gran_analyze.py` and the BSP trace already give the
  per-run DAG.
- The levels across runs and definitions need a read trace on global-environment lookups per command.

It decides where the first prototype goes, and it can fail: it may find no level with slack.

**The portfolio.** `XV-n` is a variant; each has an entry condition and a kill criterion. Under G-4 a refuted
variant is a result (it maps an edge of the design space), and it is written up as such.

| id | variant | level | entry condition | kill criterion |
|---|---|---|---|---|
| XV-1 | round-synchronous BSP-K (snapshot, dynamic placement, pid-order fold) | fire | a workload with productive wide rounds; W2-8's intersection-merge networks as the first | no workload in which it beats the best sequential path by ≥ 1.5× |
| XV-2 | asynchronous owned-slot executors with W2-3's SEEDS detector | S0 run | the profile shows asynchrony buying > 10 % over rounds somewhere | the bound from the trace DAG stays within 3 % of rounds |
| XV-3 | parallel independent S0 runs within a command | across S0 runs | the profile shows independent runs that carry ≥ 30 % of S0 | measured independence below that |
| XV-4 | definition-level parallel elaboration over monotone interface cells | definition | PPN 4C's on-network elaboration exposes definition dependencies as cells | span ≈ work on scaled programs |
| XV-5 | module-level parallel and incremental build over `.pnet` artifacts | module | the module DAG is wide on scaled programs | the DAG is chain-shaped |
| XV-6 | networks across processes exchanging deltas at stratum boundaries; Naiad-style progress tracking for distributed quiescence | machine | XV-4 or XV-5 shows scaled speedup on one machine | communication cost exceeds the slack the profile shows |
| XV-7 | OR-parallel worldviews for search | search | BSP-LE 3's on-network search workload exists | the worldviews are not independent in practice |
| XV-8 | version-indexed cells for incremental re-propagation | incremental | a design note shows that propagator cells admit the construction | the construction needs a non-monotone step inside S0 |

**What every variant needs from PAR 4.** This is why PAR 4's K = 1 work is the substrate rather than a detour from
the frontier:
- **a fast sequential baseline** (P0.5, P2). Speedups are measured against the best sequential path, never against
  a slowed one. Bailey's *Twelve Ways to Fool the Masses* (1991) names that pitfall, and today's thread executor was
  an instance of it;
- **the fault channel** (§5.5): exceptions as data, a prerequisite for any concurrent variant (DEFERRED 181);
- **an oracle and differentials** (§5.2, §5.4): BSP replay at K = 1, per-write and per-fire differentials with power
  rows, and α-normalised comparison. This is what makes exploring many variants safe and cheap, because each
  variant is judged against one reference;
- **fire context without ambient parameters** (§5.3), for any thread that outlives a `parameterize`;
- **scheduler state keyed by network id** (CL-11), for concurrent networks at any level above the fire;
- **the executor seam**, kept by O-14.

**Two tensions to put to the owner** (proposals, not edits):
- `DESIGN_PRINCIPLES.org:856-860` defers the distributed-concurrent runtime "to the self-hosted era (post-PPN 4C,
  post-SH Series)". G-4 explores now. They are compatible if every variant lives at the scheduler and networking
  layer and leaves the networks unchanged, as `:837-850` and the *Anti-Pattern: Scheduler-Coupled Optimization*
  section that follows require. The deferral sentence should then say that the *production* runtime waits, and
  exploration does not.
- PAR master Track 3 (":auto heuristic + production deployment") assumed the thread executor that O-14 removes. Its
  row needs restating as a consumer of the portfolio's results.

---

## Appendix A. Every finding, with its response

The response is one of accept, amend, reject or defer. "Lands" names the D.3 section (§5 above) or the record.
Findings that appear in several clusters are listed once, under the cluster that carries them.

| finding | severity | cluster | response | lands | note |
|---|---|---|---|---|---|
| C2-3 | major | CL-1 | **accept** | D.3 value | three non-join facets; the hub |
| C3-1 | major | CL-1 | **accept** | D.3 value | locality is not balance (SC-13); balance is not speed (SC-22) |
| C4-2 | major | CL-1 | **accept** | D.3 value |  |
| C9-2 | blocker | CL-1 | **accept** | D.3 value |  |
| C7-2 | major | CL-1 | **accept** | D.3 value |  |
| C10-1 | major | CL-1 | **accept** | D.3 value |  |
| C10-2 | major | CL-1 | **accept** | D.3 value; scope |  |
| C2-1 | major | CL-2 | **accept** | §5.1; §5.4 | gate re-based on B-P05″ |
| C6-1 | major | CL-2 | **amend** | §5.1; O-14 | cost holds; races are on the perf counters, not the boxes (W2-4); plus DEFERRED 181 |
| C7-1 | blocker | CL-2 | **accept** | §5.1 | B-P05′ / B-P05″ from W2-2's harness |
| C7-3 | major | CL-2 | **accept** | §5.1 | pool executor deleted; K default 1 |
| C7-7 | major | CL-2 | **accept** | §5.4 | one instrument (W2-2's sampler) for the model rows |
| C10-4 | minor | CL-2 | **accept** | §5.4 | gate re-based |
| C1-4 | major | CL-3 | **defer** | §4 (sequel) | accepted; the repair is W2-3's SEEDS one-pass detector |
| C3-4 | major | CL-3 | **defer** | §4 (sequel) | as C1-4 |
| C3-5 | major | CL-3 | **defer** | §4 (sequel) | lanes carry (propagator, wake) beside (cell, delta) |
| C4-8 | minor | CL-3 | **defer** | §4 (sequel) | removes one of two invariants (W2-3 Q3b) |
| C5-1 | blocker | CL-3 | **defer** | §4 (sequel) | as C1-4 |
| C5-3 | major | CL-3 | **defer** | §4 (sequel); §5.2 | H restated for the async design in the sequel; E1–E5 at K = 1 in D.3 |
| C8-9 | minor | CL-3 | **defer** | §4 (sequel); BC-4 | keys necessary, not sufficient: upstream completeness (W2-3) |
| C1-1 | blocker | CL-4 | **amend** | §5.7; sequel | E keyed on combinator terms (`join:tagged d`), fail-closed; the fence itself leaves with K > 1 |
| C1-2 | major | CL-4 | **amend** | §4; D.3 scope | no fence at K = 1; "same code" retracted (C3-9) |
| C3-2 | major | CL-4 | **accept** | D.3 scope | D2P-5 selects the whole-network rule at both granularities (W2-1 Q3b) |
| C3-3 | major | CL-4 | **defer** | §4 (sequel) | THEOREM accepted; moot at K = 1 |
| C4-5 | major | CL-4 | **defer** | §4 (sequel) | THEOREM accepted; moot at K = 1 |
| C5-6 | major | CL-4 | **defer** | §4 (sequel) | moot at K = 1; W2-9-2 adds the read-modify-write class |
| C5-10 | minor | CL-4 | **accept** | D.3 scope |  |
| C9-1 | major | CL-4 | **defer** | §4 (sequel) | moot at K = 1 |
| C9-11 | major | CL-4 | **reject** | §4 (sequel) | refuted on the corpus: ≤ 2 switches per S0 run (W2-1 Q3a); its cost direction moves to the sequel |
| C2-4 | major | CL-6 | **accept** | §5.7 row 1 | 11 writers confirmed, 1 dead (W2-6 Q2) |
| C4-1 | major | CL-6 | **accept** | §5.7 row 3 | with W2-6 A3: ⊤ is detected in ev_W |
| C4-4 | major | CL-6 | **amend** | §5.7 row 1 | premise set P instead of deleting the fallback viewpoint (W2-6-2) |
| C4-7 | major | CL-6 | **accept** | §5.7 | W2-6 A4 |
| C8-5 | major | CL-6 | **amend** | §5.7 row 1; BC-2 | anti-monotone in the bit encoding; nogood environments (W2-6 Q1(d)) |
| C9-3 | major | CL-6 | **accept** | §5.7 |  |
| C9-4 | major | CL-6 | **accept** | §5.7 row 1 | W2-6 A2: cell-1 retires as the tag source |
| C1-3 | major | CL-7 | **accept** | §5.8; §5.2 | trigger-held fired latch; pruning leaves S0 |
| C2-10 | minor | CL-7 | **accept** | §5.8 | same as C1-3 |
| C5-9 | major | CL-7 | **accept** | §5.8 | as C1-3 |
| C9-6 | major | CL-7 | **accept** | §5.8 |  |
| C1-8 | major | CL-8 | **amend** | §5.2 | the theorem is adopted as why BSP's rounds are semantic; the lifted network is not built (W2-9: not cheaper) |
| C2-2 | major | CL-8 | **amend** | §5.2 | Tier 1 is deleted by P2, not kept (W2-9-3) |
| C3-8 | major | CL-8 | **amend** | §5.2; §5.4 | moot without a fence; the replay compares the union of changed sets |
| C5-2 | major | CL-8 | **amend** | §5.2 | P2 deletes Tier 1; production does not reach 178 (W2-4) |
| C5-4 | major | CL-8 | **accept** | §5.2; §5.4 | E1 measured on the corpus (W2-9-1); E2 fails; E4 goes with Tier 1 |
| C8-7 | major | CL-8 | **accept** | §5.9 |  |
| C7-4 | major | CL-8 | **accept** | §5.2; §5.4 |  |
| C2-9 | major | CL-9 | **accept** | §5.6; O-16 | O-2 re-opened |
| C5-5 | major | CL-9 | **accept** | §5.6 |  |
| C8-4 | major | CL-9 | **accept** | §5.5; BC-3 | PD-5 latent (W2-4); overflow is a system fault |
| C9-8 | major | CL-9 | **accept** | §5.6 |  |
| C7-8 | minor | CL-9 | **accept** | §5.6 |  |
| C5-7 | major | CL-10 | **defer** | §4 (sequel) | parking handshake; executor-local assertion (W2-3 Q3a) |
| C5-8 | major | CL-10 | **accept** | §5.5 | contradictions as sets, reported canonically |
| C9-7 | major | CL-10 | **amend** | §5.5; §4 | late writes are system faults, not contradictions (W2-10-2) |
| C6-3 | major | CL-10 | **defer** | §4 (sequel) |  |
| C6-4 | major | CL-10 | **amend** | §5.5; §5.1 | already a production defect at K = 1 (DEFERRED 181); exceptions become data |
| C1-5 | major | CL-11 | **accept** | §5.2; §4 | two-column model (real cells / scratch) for the K = 1 scheduler |
| C3-6 | major | CL-11 | **accept** | §5.2; §4 | as C1-5 |
| C3-7 | minor | CL-11 | **accept** | §5.2 | K is a per-run input |
| C4-9 | minor | CL-11 | **accept** | §5.2; §4 |  |
| C8-6 | major | CL-11 | **accept** | §5.2; BC-6 | scheduler state keyed by network id; forks minted ids |
| C9-10 | minor | CL-11 | **accept** | §5.9; §5.2 |  |
| C1-7 | major | CL-12 | **defer** | §4 (sequel) | the storage strategy and the γ1 question move with K > 1 |
| C3-9 | major | CL-12 | **accept** | D.3 scope | "K = 1 is the same code" retracted |
| C3-10 | minor | CL-12 | **accept** | §5.9 | x⁰ₑ is a pointer at K = 1; RM-2 needs no measurement |
| C1-9 | minor | CL-13 | **accept** | §5.3 | delete the srcloc binding (5 reads) |
| C2-5 | major | CL-13 | **accept** | §5.3 | worldview parameter inventoried; srcloc count corrected |
| C2-6 | major | CL-13 | **accept** | §5.3; §5.5 | one fire wrapper shared by every scheduler, with id watermarks |
| C6-2 | blocker | CL-13 | **amend** | §5.3; §4 | capture is not enough (SC-26); the registry becomes data; the rest goes with persistent executors |
| C6-6 | minor | CL-13 | **accept** | §5.3 |  |
| C7-10 | minor | CL-13 | **accept** | §5.3 |  |
| C2-8 | minor | CL-14 | **accept** | §5.1 | route through the merge only where the merge is a join; R2 row |
| C2-12 | minor | CL-14 | **accept** | §5.7 | table generated from a census of S0 writes |
| C4-3 | major | CL-14 | **amend** | §5.7 row 8; PC-2 | three residual shapes (W2-7-2); σ in the success branch (W2-7-3) |
| C4-6 | major | CL-14 | **amend** | §5.7 row 4; PPN contract | interval lattice as a carrier contract; row 4 leaves P1a's correctness list (W2-7-1) |
| C4-10 | minor | CL-14 | **accept** | §5.7 row 6 |  |
| C4-11 | minor | CL-14 | **accept** | §5.7 row 8 | folded into row 8 |
| C4-12 | minor | CL-14 | **amend** | §5.7 row 2 | ⊤ = nogood of the joined labels; var-var lifted per entry (W2-7 Q4, 10/10) |
| C4-13 | minor | CL-14 | **accept** | §5.7 | bridge diagram with its gaps |
| C8-1 | major | CL-14 | **accept** | §5.7 row 8; PC-2 | quantified by W2-7 Q3; Role A on equality sub-cells flagged to PPN 4C |
| C8-8 | major | CL-14 | **accept** | §5.7 | E keyed on combinator terms |
| C9-5 | major | CL-14 | **amend** | §5.7 row 2; §5.4 | the suite cannot catch it; answer differential in test-solver-parity.rkt |
| C9-9 | minor | CL-14 | **accept** | §5.7 row 4 | the merge is never exercised (W2-7 Q1(b)) |
| C7-5 | major | CL-14 | **accept** | §5.7 |  |
| C7-6 | major | CL-14 | **accept** | §5.7; §5.4 | a two-writer power fixture per row |
| C1-6 | major | CL-15 | **accept** | §5.8 | monotonicity class as a flags bit, fail-closed default |
| C3-11 | minor | CL-15 | **accept** | §5.8 | one rule: write everything known; every guard an upward-closed threshold |
| C8-3 | major | CL-15 | **amend** | D.3 contracts (PC-5) | bridges stay PPN 4C's S0 design; proposal to the owner |
| C6-5 | major | CL-16 | **defer** | §4 (sequel) | K defaults to 1 in the runner and the LSP (W2-10-7) |
| C6-7 | minor | CL-16 | **defer** | §4 (sequel) |  |
| C10-3 | major | CL-16 | **amend** | §5.1; §5.2 | keyed diff confirmed and lands in P0.5; delta writes not built (non-equivalent; a substitute for DIRECT) |
| C10-5 | major | CL-16 | **amend** | §5.8 | partly refuted (SC-31): three classes matter at K = 1 |
| C10-6 | major | CL-16 | **accept** | §4; O-15 | pending O-15 |
| C1-10 | minor | CL-17 | **amend** | §5.9 | O-11 re-posed with option (c) |
| C8-2 | major | CL-17 | **accept** | D.3 contracts |  |
| C8-10 | minor | CL-17 | **accept** | D.3 contracts | master edit proposed to the owner |
| C8-11 | minor | CL-17 | **accept** | §5.9 | answers O-11's "settles it" |
| C8-12 | minor | CL-17 | **accept** | D.3 coordinates | re-checked when D.3 is written |
| C2-7 | major | CL-18 | **accept** | D.3 coordinates; §5.9 | P6 list completed; observer consumers named |
| C2-11 | minor | CL-18 | **accept** | D.3 coordinates | regenerated from a committed grep script |
| C2-13 | minor | CL-18 | **accept** | §5.1 | 150's tree path, as decided at O-9 |
| C7-9 | minor | CL-18 | **accept** | §5.7 | aci-laws and f3b land as tests in P1a |
| W2-1-1 | blocker | wave 2 | **accept** | D.3 value | work/span model replaces fire time / min(width, K) |
| W2-1-2 | major | wave 2 | **accept** | §5.1 |  |
| W2-1-3 | major | wave 2 | **accept** | D.3 scope; O-15 |  |
| W2-1-4 | minor | wave 2 | **accept** | §5.4 |  |
| W2-2-1 | major | wave 2 | **accept** | §5.2; §5.7 row 8 | the replay classifies the row-8 difference until row 8 is a join |
| W2-2-2 | major | wave 2 | **accept** | §5.4 |  |
| W2-3-1 | minor | wave 2 | **defer** | §4 (sequel) |  |
| W2-3-2 | minor | wave 2 | **defer** | §4 (sequel) |  |
| W2-3-3 | minor | wave 2 | **defer** | §4 (sequel) |  |
| W2-3-4 | minor | wave 2 | **accept** | SC-27 |  |
| W2-4-1 | major | wave 2 | **accept** | §5.7 row 1; §5.8; DEFERRED 157 | PD-10 |
| W2-4-2 | minor | wave 2 | **accept** | §5.1; DEFERRED 157 |  |
| W2-4-3 | minor | wave 2 | **accept** | §5.4 |  |
| W2-5-1 | major | wave 2 | **accept** | §5.4 |  |
| W2-5-2 | major | wave 2 | **accept** | §5.3 |  |
| W2-5-3 | minor | wave 2 | **accept** | §5.4 | α-normalised comparison |
| W2-6-1 | major | wave 2 | **accept** | DEFERRED 177; §5.7 | SC-30 |
| W2-6-2 | major | wave 2 | **accept** | §5.7 row 1 |  |
| W2-6-3 | major | wave 2 | **accept** | §5.7 order |  |
| W2-6-4 | minor | wave 2 | **accept** | §5.4 |  |
| W2-7-1 | minor | wave 2 | **accept** | §5.7 row 4 |  |
| W2-7-2 | major | wave 2 | **accept** | PC-2 |  |
| W2-7-3 | major | wave 2 | **accept** | §5.7 row 8 |  |
| W2-7-4 | major | wave 2 | **accept** | §5.4 |  |
| W2-8-1 | major | wave 2 | **amend** | D.3 value; §4 | restatement accepted; cross-command batching is a CONJECTURE for the sequel and PPN 4C |
| W2-8-2 | minor | wave 2 | **accept** | §4; SC-29 | annotate P0 §10.1 |
| W2-8-3 | minor | wave 2 | **accept** | §5.5; §5.4 |  |
| W2-9-1 | minor | wave 2 | **accept** | §5.2; §5.8 | the E1 census becomes a co-inductive monitor |
| W2-9-2 | major | wave 2 | **defer** | §4 (sequel); §5.8 | moot at K = 1 (DIRECT serializes); the disposition is recorded for the sequel |
| W2-9-3 | minor | wave 2 | **accept** | §5.2; DEFERRED 178 |  |
| W2-10-1 | major | wave 2 | **accept** | §5.5; DEFERRED 181 | PD-8 |
| W2-10-2 | major | wave 2 | **accept** | §5.5 |  |
| W2-10-3 | major | wave 2 | **accept** | §5.6; DEFERRED 182; O-16 | PD-9 |
| W2-10-4 | major | wave 2 | **amend** | §4; §5.4 | the simulated-K executor goes to the sequel; α-normalised comparison at K = 1 |
| W2-10-5 | major | wave 2 | **accept** | §5.9 |  |
| W2-10-6 | major | wave 2 | **accept** | §5.5 |  |
| W2-10-7 | minor | wave 2 | **defer** | §4 (sequel); §5.4 |  |

**Totals** (140 findings: 103 from wave 1, 37 from wave 2): accept 96, amend 22, reject 1, defer 21.

Only one finding is rejected outright, because wave 2 was charged with settling the contested ones, and most of what it overturned were *directions*, which are recorded as amend: CL-1's component ownership, C1-8's lifted network, C4-4's deletion of the fallback viewpoint, C6-2's interim capture, C10-3's delta writes. The single reject (C9-11) is a claim that was refuted on the corpus.

