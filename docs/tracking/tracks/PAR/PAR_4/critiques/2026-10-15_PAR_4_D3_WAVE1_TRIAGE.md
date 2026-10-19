# PAR 4 D.3 — wave 1 triage

**Of**: [D.2](../2026-10-15_PAR_4_D2_DESIGN.md) at `430e42bb`, and its
[self-critique](2026-10-15_PAR_4_D2_SELF_CRITIQUE.md).

**Wave 1**: ten critics, C1–C10, working in isolation. Plan: [`…_D3_CRITIQUE_PLAN.md`](2026-10-15_PAR_4_D3_CRITIQUE_PLAN.md).
Briefing: [`…_D3_WAVE1_BRIEFING.md`](2026-10-15_PAR_4_D3_WAVE1_BRIEFING.md). Launched 2026-10-15 22:59; all ten had
returned by 23:29.

**Evidence**: every critic's probes and outputs are in `racket/prologos/benchmarks/par4/d3-wave1/<critic>/`.
- The raw JSON returns of C1–C5, C8 and C9 are in `raw/`.
- C6, C7 and C10 returned inline. Their findings are indexed in `wave1-findings-index.json` and summarised in the
  clusters below.

**Status**: this is a hand triage and an input to wave 2. No finding has a response of record yet; responses come
in the synthesis after wave 2. Where a cluster below gives a disposition, it is a *lean*.

**Labels**: `CL-n` is a cluster of findings, `PD-n` a production defect found by the round, `W2-n` a proposed
wave-2 agent. `SC-11` onwards continue D.1's self-corrections (SC-1…SC-10 are in D.1 Appendix A). Each prefix was
grepped across `docs/tracking`, with 0 prior uses.

## 0. The result in brief

The ten critics returned 103 findings: 5 blockers, 69 major and 29 minor. Merged, they form 18 clusters.

The critics' strongest points in favour agree with each other:
- Building correctness before parallelism is right.
- Running K = 1 before K > 1 is right.
- The join-combinator direction holds wherever it was probed. C4's law checks found 0/0/0/0 violations for the
  two-phase set, the flat-⊤ maps and the interval lattice. The ground type merge was clean on 400 pairs. C9's
  base-joined labelled read was order-independent under all six runs.

Five things change D.2 most:

1. **CL-1. The attribute map is one hub cell.** Seven critics found this; four measured it independently, and their
   counts agree.
   - The attribute map is the first output of 84–89 % of the fires in the heavy files.
   - Its installed merge reaches `type-unify-or-top` through the `:type` facet. That is three non-join facets, not
     the two D.2 §13 says.
   - D.2's per-cell fence therefore fences it. D.2's home rule (a fire runs on the owner of its first output) also
     puts 85–89 % of fires on one executor *whatever the fence does*.
   - Effective parallelism comes out at 1.09–1.18 for every K. The models assumed 3.1–11.8.
   - P0's "≤ 10 % foreign writes" measured locality, not balance. A fire with one output can never be foreign
     under that metric (`benchmarks/par4/p0-profile.rkt:216-218`).
2. **CL-2. Production BSP is not sequential.** Three critics replicated this.
   - `driver.rkt:567` installs a thread-per-round executor globally.
   - On the heavy files it makes the fire phase 2.5–3× slower than sequential firing, and the whole run 1.4–1.6×
     slower.
   - Every P0 per-file timing includes this executor. P2's gate (≥ 1.4×) can be met by switching the executor off,
     with no DIRECT code at all.
3. **CL-3. The quiescence detector, as written, declares quiescence too early.** Three model checks, written
   independently, each found a short trace that reaches it.
   - The epoch counter that replaced D.1's reset flag cannot record that an executor became busy again within the
     same epoch.
   - D.2 also dropped D.1 §5.3's counted fire requests.
   - After a contradiction stop, the counters never balance.
4. **CL-4. The fence is ill-defined.**
   - No monotone map from SRE's four-valued property lattice can fail closed. Three critics proved this.
   - Merge identity is per closure, not per merge function.
   - The fence confines writes, not information flow, so S-9 fails (measured).
   - The fenced sub-run's result depends on worklist order.
   - Each alternation between fenced and unfenced work is a barrier.
5. **CL-5. The round found production defects that exist independently of PAR 4.** Two of them I reproduced by
   hand (§4):
   - the ATMS solver returns answers that DFS rejects (filed as DEFERRED 177);
   - the Tier-1 flush returns a network that is not a fixpoint (DEFERRED 178).

## 1. Spot checks made by hand

Delegated output is input, so the claims that carry the triage were re-checked by hand at HEAD (production `racket/`
is identical to main `c1f389ab`).

| claim (critics) | check | result |
|---|---|---|
| a global thread executor (C2-1, C6-1, C7-1) | read `driver.rkt:563-568` | **confirmed**: `(current-parallel-executor (make-parallel-thread-fire-all))`, with the comment "PAR Track 2 R2: Enable parallel thread executor globally" |
| the attribute map's `:type` facet merges with `type-unify-or-top` (C2-3, C4-2, C9-2, C10-2) | read `typing-propagators.rkt:400-419` and `classify-inhabit.rkt:167-171` | **confirmed**; an unknown facet also falls to `[else new-v]`, i.e. last writer wins (`:419`) |
| there is one attribute-map cell (C2-3, C9-2) | read `typing-propagators.rkt:2994-2999` | **confirmed**: `(net-new-cell pnet (hasheq) attribute-map-merge-fn)` |
| Tier 1 drops dependents (C2-2, C5-2) | read `propagator.rkt:3431-3446`; re-ran C2's `probe-tier1.rkt` | **confirmed**: A = 7 and B = 0, and still B = 0 after a second run. Controls: Tier 2 gives B = 7, the drain gives B = 7 |
| `tagged-cell-read` drops the base (C4-1, C9-3) | read `decision-cell.rkt:452-477` | **confirmed**: the base is returned only when no entry matches (`:470`); with no domain merge, the first match wins (`:473`) |
| the ATMS solver returns wrong answers (C9-5) | re-ran C9's `c1-overwrite.prologos` and `c4-varvar.prologos` with `tools/scratch-run.sh` | **confirmed**: table below |
| `current-source-loc` has 13 production reads (D.2 §6.5) | grep over production files, comment lines dropped | **wrong in D.2**: 5 reads (`propagator.rkt:2289, 2372, 2460`; `driver.rkt:681`; `elaborator.rkt:1149`), none inside a fire |
| the pool executor drops work (C7-3) | read `propagator.rkt:3819-3836` | **confirmed in shape**: it dispatches min(k, n) thunks. `current-worker-pool` has no setter in production (`:3744`), so this path is dead today |

The ATMS solver against DFS, both run in the same file:

| query | `:strategy atms` | `:strategy depth-first` (correct) |
|---|---|---|
| `two ?x` with `(= x 1) (= x 2)` in one clause | `@[{:x 2}]` | `@[]` |
| `(rel [?x] (= ?x 1) (pick ?x))`, where `pick` ∈ {x = 1, x = 2} | `@[{:x 2} {:x 1}]` | `@[{:x 1}]` |
| `clash` with `(= x 1) (= y 2) (= x y)` | `@[{:x 1, :y 2}]` | `@[]` |
| `agree` with `(= x 1) (= y 1) (= x y)` (control) | `@[{:x 1, :y 1}]` | `@[{:x 1, :y 1}]` |

**Not checked by hand** (wave 2 settles these):
- C6-1's claim that today's thread executor runs fires that race on shared mutable state;
- C10-3's estimate for "P2-lite";
- C6's memory-order litmus counts;
- C4-4's measurement that `solve-all` loses an answer when cell-1's merge is `ior`.

## 2. Self-corrections (continuing D.1's SC-n)

Each correction is stated where the wrong claim was made. The documents get callouts in this commit, and D.3 makes
the corrections in its text.

- **SC-11**. D.2 §1 says "today's *sequential* scheduler", and §0 row 1 and §2 build their models on P0's timings.
  - In production, BSP fires every round of eight or more propagators on freshly created OS threads
    (`driver.rkt:567`).
  - P0 did not see this, so its per-file timings, and the H-S and K models built on them, include the cost of
    creating threads (C2-1, C6-1, C7-1).
  - The P0 record gets a callout.
- **SC-12**. D.2 §13 row 1 says the attribute map is "non-join only through two facets". It is three: `:type` merges
  with `type-unify-or-top`.
  - §2 item 3 and R-1 named the fence as the only limit on K > 1. The hub concentrates fires on one executor
    whether or not it is fenced (CL-1).
- **SC-13**. P0 Q4's "≤ 10 % foreign writes" cannot see load balance (C10-1). D.1, the relay note and D.2 §6.7 all
  read it as evidence that round-robin ownership is adequate.
- **SC-14**. D.2 §0 row 12 and §6.7 replaced D.1's reset flag with an `idle-epoch` max-counter and called it an
  improvement. It makes the detector unsound (CL-3).
  - D.2 also dropped D.1 §5.3's counted fire requests.
  - P0 §4.1's 198–485 ns measured `detect.rkt`'s resettable-flag scheme, which is sound, so it is not evidence for
    D.2's scheme.
- **SC-15**. Self-critique D2L-4 says "the fence is a monotone map … contradicted ⇒ fenced". No monotone map from
  SRE's FOUR lattice fails closed (C1-1, C3-3, C4-5). The fence is a gating read taken at the topology stratum.
- **SC-16**. "Ownership is the theorem's hypothesis, not an optimisation" (the relay note §1, the Stage 1 synthesis,
  D.1) is wrong.
  - The cited theorems (Üresin–Dubois 1990; Bertsekas 1983) update a component by *replacing* it, computed from one
    view.
  - D.2's cells instead *join* the contributions of several writers, each computed from its own stale view.
  - Refine the state to (cell, writer) components and each refined component has exactly one writer. The theorem
    then applies, and the joins carry correctness. Apt 1999's generic chaotic iteration gives the same result
    (C5-3).
  - Owning a cell's *storage* is therefore a cost and realization choice, not a hypothesis of the theorem.
  - This loosens the design: ownership may move between epochs, and a home rule may be chosen for balance (CL-1).
- **SC-17**. D.2 §6.5 says `current-source-loc` has 13 production reads. It has 5, all at install time or
  re-binding, none inside a fire.
  - The private-key continuation mark costs 32 B per fire in D.2's shape, not 0 B. The 0 B probe let the compiler
    drop the mark (C6-6).
  - With no reader inside a fire, the binding can simply be deleted (C1-9, C2-5, C7-10).
- **SC-18**. D.2 §6.6 blames fire-once for the "27 test files [that] fail under" the drain. P0 §2.5 attributes 2 of
  the 27 to fire-once and about 25 to the missing stratum layer (C1-3, C2-11, C7-10).
- **SC-19**. D.2 §10.2 S-6 says that below the bound, `'tropical-fuel-exhausted` happens "under every schedule".
  - It does not: exhaustion below the bound depends on the schedule. One fixpoint costs 1 change or 16, depending
    on order (C5-5, C7-8, C9-8).
  - Σ heights is not computable for types, term sets or attribute maps, so "budgeted at that bound" names no
    number.
  - The S-6 fixture as written counts fires, not ascents (C7-8).
- **SC-20**. Self-critique D2R-4 and D.2 §6.6 say the Tier-1 flush "is already DIRECT at K = 1 and stays as it is".
  Tier 1 does not reach a fixpoint (reproduced; PD-2).
  - D2R-2's "7 constructor sites" is 2 (C2-11).
- **SC-21**. D.2 §5 says "K = 1 is the same code with one executor", but §6.6 (the CHAMP network) and §6.7 (owned
  slots) describe two representations and two write paths (C1-7, C3-9).

## 3. Clusters

Each cluster lists its findings, how they were replicated, the claim, the directions proposed, and a lean. A lean
is one of: accept · accept the problem but not the solution · reject · defer · decide in wave 2.

### CL-1 — the hub cell and the home rule (blocker)

**Findings**: C2-3, C3-1, C3-2, C4-2, C7-2, C9-2, C10-1, C10-2. Related: C9-11, C3-8.

**Replication**: four separate probes measured the same thing, and their counts agree.

| critic | probe | counts |
|---|---|---|
| C3 | `home_fence_probe.rkt` | constraints-adversarial: executor 1 gets 1020 of 1142 fires (89.3 %); type-adversarial: 84.7 % |
| C7 | `placement.rkt` | effective parallelism 1.09–1.15 at K ∈ {4, 8, 16}, against the model's 3.1–11.8. Power row: homing by propagator id gives 2.89–10.87 |
| C10 | `hub-probe.rkt` | busiest executor's share: 0.893 and 0.847 |
| C9 | `c9-census.rkt` | the attribute map takes 74–80 % of productive fires. Power row: on `c2-naf` the top cell is not the attribute map |

**Directions**: six critics converge.
- Make the *component* (position, facet) the unit of ownership, of E and of the fence.
- The attribute map is a product lattice (SRE: structural), and the dependency keys already exist:
  `#:component-paths` at `typing-propagators.rkt:1761-1787`.
- Alternative: one cell per position. That is PPN 4C's design surface.

**Open**: the shares were measured by fire count, not fire time. Nobody has measured what parallelism is left at
component granularity.

**Lean**: accept. W2-1 measures the numbers at component granularity.

### CL-2 — the production thread-per-round executor (blocker for attribution)

**Findings**: C2-1, C6-1, C7-1, C7-3, C7-7, C10-4.

**Replication**:

| critic | measurement (production executor vs sequential) |
|---|---|
| C2 | wall 63 vs 42 ms |
| C7 | work 56–57 vs 39–41 ms on constraints-adversarial; 1.41–1.58× on type-adversarial |
| C6 | executor time on wide rounds 16–17 vs 3 ms; 107 KB vs 2.1 KB allocated per fire; about 592 threads per run |

The pool executor also drops fires when a round is wider than k (C7-3: 16 of 23 reached at K = 8). It is dead in
production.

**Lean**: accept.
- P0.5 deletes both executors, in the same class as DEFERRED 150.
- B-P05 is pinned with both gone, and the P0 models are re-derived from sequential fire times.
- This changes a production default, so it is posed as an owner decision in D.3 (O-14).
- C6-1's correctness claim (fires racing on shared boxes today) goes to W2-4.

### CL-3 — the quiescence detector (blocker)

**Findings**: C1-4, C3-4, C3-5, C5-1, C4-8, C8-9, C6-3, C6-4.

**Replication**: three independent model checks found the same premature declaration:
- C1, `detector-model.rkt`;
- C3, `detector_model.py`, exhaustive;
- C5, `c5-detector-model.py`, exhaustive. Its shortest trace is 9 steps.

The trace: executor B goes idle. A sends B a delta and goes idle. B drains the delta (cons += 1), and the join
enqueues local work that sends no messages. Both scans then see Σprod = Σcons with every idle mark = e, so the
detector declares quiescence while B still has work.

**Other gaps**:
- Fire requests for dependents homed on another executor are uncounted. With them uncounted, quiescence is declared
  early or at a wrong fixpoint (C3-5, C5-1).
- After a contradiction stop the counters never balance, so the detector never declares (C5-1).
- A Racket exception in an executor kills its thread, and the detector then hangs (C6-4).

**Repairs proposed**:
- an activity counter whose parity says busy or idle (C5);
- a quiet mark (e, consᵢ) (C3);
- cons published only after the local cascade drains (C1, C5);
- credit recovery, which turns the global decision into a monotone threshold (C1; Mattern 1989, Huang 1989);
- counted fire-request messages;
- a boundary triggered by quiescence ∨ contradiction;
- lanes modelled as logs with cursors (C4-8);
- regions keyed by network id (C8-9).

**Lean**: accept the problem. W2-3 chooses the repair.

### CL-4 — the fence (major; shapes the design)

**Findings**: C1-1, C1-2, C1-6, C3-2, C3-3, C3-8, C4-5, C5-6, C5-10, C8-7, C8-8, C9-1, C9-11, C10-2.

**Problems found**:
- (a) **No monotone fail-closed map exists** (C1-1, C3-3, C4-5). This is a theorem: in FOUR, unknown ⊑ confirmed, so a
  monotone map that sends confirmed to free must send unknown to free too. C4 enumerated all 16 maps and found none
  that fails closed. Separately, an undeclared merge whose samples fail lands at *refuted*, which D.2 does not map.
- (b) **Merge identity is per closure.**
  - `elab-fresh-meta` builds a tagged merge per meta (`elaborator-network.rkt:138-143`).
  - `promote-cell-to-tagged` builds a fresh closure per promotion (`propagator.rkt:1814`).
  - Registry lookup on the installed merge returns `#f` (C1-1, C8-8 measured).
  - A tagged merge returns its entries in an order that depends on input order, so a check that uses `equal?` fences
    every tagged cell (C8-8).
- (c) **The fence confines writes, not information flow.** C9-1 measured that a converted (join) cell downstream of a
  fenced cell differs between K = 1, K > 1 and BSP, so S-9 fails. The replay monitor cannot tell this from a bug
  (C3-8).
- (d) **The sub-run's result depends on worklist order** (C5-6, row K-WL). A fenced half can oscillate until fuel runs
  out (K-OSC).
- (e) **Each alternation is a barrier.** On a dependency chain, the number of alternations equals the number of BSP
  rounds (C9-11, A3: d = 64 crossings gives 63 alternations against 128 BSP rounds).
- (f) **D.2's own decision rule already picks the whole-network rule.** D2P-5 says to take it if P0-8 finds a small
  share outside fenced writers; the hub measurements give 11–16 % (C3-2, C10-2).
- (g) **The fence is keyed on output merges, so it fails open for non-monotone fires** whose outputs are joins (C1-6).

**Directions on the table**:
- (i) run the whole network at K = 1 while any of its cells is fenced;
- (ii) a fence per component, with the fenced writes kept as data (a set of (writer, value)) and folded in a
  canonical writer order at a sub-boundary, the same at every K (C1-2);
- (iii) fence the downstream cone, as a monotone "order-exposed" mark propagated at the topology tier (C9-1), or as a
  taint lattice over round records (C3-8).

Under every option the fence becomes a fail-closed gating read at the topology stratum, keyed on merge descriptors
or combinator terms rather than closures.

**Lean**: accept the problems. The choice between (i), (ii) and (iii) waits on W2-1's numbers and is then an owner
decision in D.3.

### CL-5 — production defects

See §4.

### CL-6 — tagged reads and the worldview (major)

**Findings**: C4-1, C9-3, C9-4, C9-5, C4-4, C2-4, C4-7, C8-5, C4-12.

**What the critics agree on**:
- **The read.** It should be the evaluation map ev_W(t) = base ⊔ ⨆{v | b ⊆ W}: ATMS label semantics, and a join
  homomorphism into the domain at each worldview W (C4-1, C9-3).
- **Cell-1 is two things today** (C4-4, C2-4):
  - an *information* lattice. That half should become a derived projection from the decisions and nogoods.
  - a read *viewpoint*. That half should become an argument W carried per propagator or per query, never a read of
    a network-wide cell.
  - Cell-1 has 10–11 production writers in three classes: ior-add, AND-NOT clear, and wholesale replacement.
  - Making today's cell-1 merge `ior` makes `solve-all` lose an answer (C4-4, measured).
- **Labelled fires** are either additive, and lifted entry by entry, or evaluated on the union-closure of their input
  labels (C4-7). A write to a plain cell must never drop a label (C9-4).
- **Guards and NAF** write invalidation only at boundaries, over completed inputs. The per-binding mask is
  anti-monotone in the set of passing rows (C8-5).
- **`unify-fire`** should write each side's value into the other, so a conflict reaches the merge (C4-12, C9-5).

**Lean**: accept. D.2's row 1 alone is not enough. W2-6 checks that these proposals are consistent with each other.

### CL-7 — fire-once (major)

**Findings**: C1-3, C2-10, C5-9, C9-6. See also SC-18.

**Problems**:
- The self-clear removes the propagator from its input cells' dependent lists (`propagator.rkt:3540-3542`). That is a
  topology edit made inside S0. At K > 1 those cells belong to other executors, so it becomes a write to another
  executor's records.
- `fired-set` is a local mutable hash, outside the network.
- BSP's "productive" (the output differs from the snapshot) and DIRECT's "productive" (the fire changed the live
  cell) give different fired sets (C9-6, measured).

**Consensus direction**:
- fire-once becomes a per-propagator fired latch: a monotone set, consulted when the propagator is dequeued;
- "productive" means "the trigger held", which is independent of schedule;
- pruning dependents leaves S0, either becoming a topology action at the boundary or disappearing.

**Lean**: accept.

### CL-8 — Kleene, the replay and the monitors (major)

**Findings**: C5-4, C5-2, C2-2, C1-8, C7-4, C3-8, C2-7, C7-6, C8-7.

**"BSP's rounds are the Kleene iterates" holds only under five extra conditions** (C5-4). The probes show each
condition fails somewhere today:
- E1: a propagator's read set ⊆ its declared inputs. Fails: K-UR gives o = 1 where the least fixpoint is o = 5.
- E2: fire-once is used only on stable latches. Fails: K-FO gives b = 1 against Kleene's 2.
- E3: a boundary write that lowers a cell enqueues that cell's readers. `net-cell-reset` does not.
- E4: no Tier-1 flush moves the origin of the rounds.
- E5: no truncation by fuel or contradiction mid-round.

**The monitors need more power**:
- The replay monitor compares only DIRECT's changed set, so a missed wake-up (the likeliest DIRECT bug) is never
  compared. It should compare the union of both runs' changed sets (C7-4).
- The X4 power row tests the fenced case. Executor mutants are needed as power rows: drop one enqueue, skip one
  self-clear (C7-4).
- The merge-order census lives inside the BSP inner loop that P2 replaces. It should move into the replay (C7-4).
- Five of P1a's "census R → 0" gates cannot fail on the suite, because R is already 0 on those cells (C7-6).

**Contested**: C1-8 says the round structure can be a network transform. Lift each cell to a value per Kleene depth;
any fair scheduler then computes the Kleene sequence, and BSP need not stay as a permanent oracle. The cost is a
CONJECTURE. The consumers today are the LSP and VS Code's round view (C2-7).

**Lean**: accept C5-4's restatement and C7-4's repairs. Decide in wave 2 between BSP as the oracle and the lifted
network (W2-9 weighs it).

### CL-9 — fuel and termination (major)

**Findings**: C2-9, C5-5, C7-8, C9-8, C8-4.

**What O-2 ("fuel counts changes") meets in production**:
- Production budgets are calibrated in fires, and users can see them:
  - `TYPING-FUEL-LIMIT` = 200 (`typing-propagators.rkt:2978`);
  - `:timeout` is converted to fuel = ms × 1000;
  - `:fuel` is documented as a "propagator firing limit" (`macros.rkt:1009`);
  - user-level `net-new` takes fuel.

  Counting changes instead is a change to the language.
- Σ heights is not computable for these lattices. Below the bound, exhaustion depends on the schedule (SC-19).
- **Directions**: each merge declares its chain bound beside E's verdict; fuel is counted per executor and per epoch,
  and summed at the boundary.

**A latent production defect**: the strata outer loop raises an uncaught exception after 20 iterations
(`propagator.rkt:3619-3634`). C8 measured it at topology-discovery depth 23 (PD-5). BC-3 sends every SLG table
creation through this loop.

**Lean**: accept the problems. O-2 is re-opened as an owner decision in D.3.

### CL-10 — late writes, memory ordering, contradiction, exceptions (major)

**Findings**: C5-7, C6-3, C9-7, C5-8, C6-4.

**Memory ordering**:
- R-2 can be closed by citing the Racket Reference, §11.7 and §1.1.12 (C6-3).
- Every channel needs a stated ordering. Unfenced lane appends tore 47–61 k times in 23–25 M checks. A
  store-buffering litmus test showed 84–92 k violations per 1 M with only the automatic `dmb ishst` before pointer
  stores; adding `memory-order-release` in between brought it to 0.
- The late-write check is Dekker-shaped. Check-then-write misses a late write even under sequential consistency. It
  needs a store→load fence on both sides, or a parking handshake, after which it is a co-inductive assertion rather
  than inductive evidence (C5-7).

**Contradiction and exceptions**:
- The contradiction payload should be a set. Today `net-cell-write` keeps the last writer and `bulk-merge-writes`
  the first, so which contradiction is reported depends on order (C5-8, C9-7).
- An exception in an executor should become a contradiction fact (C6-4).

**Epochs**: the alternation's half-quiescence must not write `boundary-epoch` (C9-7).

**Lean**: accept. W2-3 covers it with CL-3.

### CL-11 — an honest model of the scheduler state (major)

**Findings**: C1-5, C3-6, C3-7, C4-9, C9-10, C8-6.

**What the §9 model leaves out or gets wrong**:
- It omits draining lanes, the worklist, `fired-set` and the per-epoch reset of `exec-changed`.
- No phase allocates the scheduler network.
- K as a max-cell can never go down, but K = 1 per network and the parity runs need it to.
- The assignment is derived, not stored.
- Records grow forever on a persistent network.
- Scheduler state is a process-wide singleton, but the NAF handler forks and quiesces inside a boundary
  (`relations.rkt:206-283`). Forks have no identity of their own (`prop-network` has no id field).

**Direction**: two columns.
- Real cells live on the run's own network, as the fuel cell does.
- Scratch state is labelled as such.
- K becomes a per-run input.
- The assignment becomes a derived read.
- Records become a stream.
- Scheduler state is keyed by network id, and forks get minted ids.

**Lean**: accept.

### CL-12 — the representation, and what K = 1 means (major)

**Findings**: C1-7, C3-9, C3-10.

**Two directions**:
- Declare the owned slot as a storage strategy behind `specialized-cell-meta`, used at every K, so that P2 already
  tests P3's data path (C1-7). This touches the γ1 principle, "the CHAMP remains primary"
  (`DESIGN_PRINCIPLES.org:1106`).
- Retract "same code", and give P3 a gate row of its own (C3-9).

C3-10 adds that materialization costs O(|changed| log n) through the changed sets, and that x⁰ₑ is a pointer at
every K. RM-2 then needs no measurement.

**Lean**: accept the problem. C1-7's direction is the better one, but it proposes a revision to a principle, so it
goes to the owner in D.3.

### CL-13 — ambient state and fire context (blocker, C6-2)

**Findings**: C6-2, C2-5, C2-6, C1-9, C6-6.

**Problems**:
- An executor created once keeps its creation-time parameter values, and never sees direct assignments made later.
  C6 measured this; Reference §11.3.2 documents it.
- Production has 219 `make-parameter`, and per-command direct assignments in `reset-meta-store!`
  (`metavar-store.rkt:2876-2909`).
- `current-worldview-bitmask` (31 lines) was never inventoried (C2-5).
- 158's structure check sees only fires that produce a `fire-result`. Fires also run through four other paths: Tier
  1, the drain, widen/narrow, and P2's own executor (C2-6).

**Directions**:
- delete the srcloc binding;
- check for new structure with id watermarks in a fire wrapper that every scheduler shares;
- as an interim, capture the per-run parameterization once and install it on each executor wake (48 B, 18 ns);
- add a census trap for parameter reads at K > 1.

**Lean**: accept. W2-5 sizes the problem.

### CL-14 — the merge rows (major and minor)

| row | finding | direction |
|---|---|---|
| 8, the type merge (C4-3, C8-1) | The clash test must be "`try-unify-pure` fails", not "the heads differ". A test on heads still erases 1 196 contradictions. 87 % of today's fallback hits are clashes; all 532 blocked cases are unsolved multiplicity metas or unions holding a meta. **Role A** (`type-lattice-merge`, union semantics, PPN 4C T-3) and **Role B** (`type-unify-or-top`) need different rules: clash ⇒ ⊤ is wrong for Role A. | The residual is the most general unifier, which lives on the meta cells, or a disjunction realised by fork-on-union (C4-3) |
| 4, `:usage` (C4-6, C9-9) | C9 proves the 3-element chain monotone. C4 shows that adding ⊥ for an unsolved multiplicity breaks either scaling or associativity. | The interval lattice (C4-6). One writer per position, and alternation as a gated join (C9-9). **Contested**: W2-7 |
| 2, the flat bands (C9-5, C4-12) | ⊤ is never reached: `unify-fire` drops var-var conflicts and the tagged read drops the base. What ⊤ means is unspecified. | In a branch, ⊤ is that branch's nogood; in the base, it is the query's failure |
| 6, the ready queue (C4-10) | There is no priority field, and the cell is reset after every handler run. | Priority derived from the kind of action; a request set indexed by epoch |
| 7, cell-15 (C4-11) | The cell is derived from `:type`. | Fold it into row 8 |
| 9 and 157(a) (C2-8) | Applied through the merge, the snapshot value still loses updates on replacement merges. `bilattice.rkt:167` writes no cell at all. | Route through the merge only for cells whose merge is a join |
| the nine cells (C2-12) | Cell-19 (`union-derivation-chains-merge`) is missing. | Generate the table from a census of S0 writes |
| E (C7-5, C8-8, C1-1) | A generic seeded non-join cannot catch fail-open behaviour confined to one arm. Merge identity is per closure. | Mutants per arm; counts of which arms the samples reach; `join:tagged d` as a combinator |
| the gates (C7-6) | Census R → 0 cannot fail for rows 1, 2, 7, 8 and 9. | A two-writer power fixture per row |

**Lean**: accept the rows. W2-7 settles row 4 and row 8's universe.

### CL-15 — P1b (major)

**Findings**: C1-6, C3-11, C8-3, C9-6, C10-5.

**Directions**:
- Declare a fire's monotonicity class at the propagator layer (a flags bit), with a fail-closed default. Per-fire
  property tests belong in the co-inductive column (C1-6).
- Replace the taxonomy with one rule: a fire writes everything it knows, and every guard is an upward-closed
  threshold. Two of the eight absence-reading sites fit none of D.2's dispositions (C3-11).
- Moving the trait/hasmethod bridges to a "declared stratum" contradicts PPN 4C Phase 7, which designs them as S0
  propagators over ATMS candidates (C8-3).
- P1b matters only at K > 1 (C10-5).

**Lean**: accept C1-6 and C3-11. C8-3 crosses tracks and goes to the owner.

### CL-16 — value, scope and phase order (major)

**Findings**: C10-3, C10-5, C10-6, C7-3, C7-7, C6-5, C6-7, C10-4.

**"P2-lite"** (C10-3):
- Most measured time is `pu-value-diff` walking the whole attribute map (235–352 positions) for a write that
  changes 1–2 paths.
- A keyed diff costs 83 ns against 23.8 µs, with identical output on all 224 and 203 captured pairs. Its power row,
  a keyed diff that drops one key, mismatches every pair.
- **ESTIMATE**: a keyed diff plus writes carried as deltas gives about 4.4× and 2.2× on the two heavy files with no
  scheduler change. P2 alone gives about 1.9× and 1.49×. P2's marginal gain after P2-lite is ≤ 1.28× and ≤ 1.09×.

**Phase order**:
- P2's inputs are P0.5 plus a core of P1a (C10-5).
- Move P3, P1b and the fence to a K > 1 sequel co-designed with PPN 4C and BSP-LE 3 (C10-6).
- P3 needs a pass threshold, and K's default stays 1 until a measurement says otherwise (C7-3).
- Add a B-P1 baseline. P0's model instruments are not compatible with each other (C7-7).

**K as a machine budget** (C6-5):
- The runner launches about 18 workers, so K = 8 per worker means 144 executors on 18 cores.
- Spinning executors make each stop-the-world GC about 5× longer; parked ones cost nothing.
- A semaphore hop measures 15 µs here, against P0's 7.3 µs.

**Lean**: accept the problems. The scope decision is the owner's, after W2-1 and W2-2.

### CL-17 — cross-track (major)

**Findings**: C8-1…C8-12.

- **PC-1** must be tied to PPN 4C's Phase 4 and PM 12. Reading a cell *inside* the merge does not discharge it (C8-2).
- **New contracts**:
  - PC-5: the trait and hasmethod bridges (C8-3).
  - PC-6: rows 4–7 change cells that PPN designed. PPN's own lattice catalog (`PPN_TRACK4C_DESIGN.md:1299-1318`)
    already declares the ready queue a free join-semilattice and the worldview a derived value; D.2 should cite it.
- **BC-2**: the guard mask is anti-monotone (C8-5).
- **BC-3**: the strata-loop cap (PD-5).
- **BC-6**: nested runs inside a handler (C8-6).
- **Detection keyed by region** (PPN GR-6) (C8-9).
- **The BSP-LE master's completion definition is unsound even under BSP** (C8-10, probe). That is a proposed edit to
  the master.
- **O-11's settling evidence exists**: PPN Q-4B5.10's first-class diagnostic datum is an on-network consumer (C8-11).
- **Branch `preduce-autonomy`** changes `propagator.rkt` by +207 lines and pre-allocates cell ids 20 and 21 (C8-12).

**Lean**: accept. Edits to the master and the roadmap are proposals to the owner.

### CL-18 — coordinates and test artefacts (minor)

**Findings**: C2-7, C2-11, C2-13, C7-9, C7-10.

**Problems**:
- §12.2's coordinates drifted.
- P6's deletion list is incomplete. It misses the thread executor, `make-parallel-fire-all`, the drain variants,
  widen/narrow, and `:execution :sequential`, which is the user's route to the drain.
- The streaming executor and `current-worker-pool` are already dead.
- `aci-laws.rkt` and `f3b-witness.rkt` live in a skill, not the repository.
- No tests in the repository pin warning order or the ready queue's intent.

**Lean**: accept. Regenerate §12.2 from a committed grep script, and land the witnesses as tests in P1a.

## 4. Production defects found by the round

| id | defect | status | record |
|---|---|---|---|
| **PD-1** | the ATMS solver returns answers DFS rejects, through three mechanisms: the tagged read drops the base (`decision-cell.rkt:470`); `unify-fire` drops var-var conflicts (`relations.rkt:2112-2120`); `scope-cell-merge` lets the newer value win per key (`decision-cell.rkt:938`). Reach: `:strategy atms`, and `'auto` (the default, `solver.rkt:77`) above its DFS↔ATMS crossover (`:76`). It is the same under every schedule, so PAR 4's census and replay cannot see it | **reproduced by hand** | DEFERRED 177 |
| **PD-2** | the Tier-1 flush returns a network that is not a fixpoint (`propagator.rkt:3431-3445`) | **reproduced by hand**; how often production reaches it is not measured | DEFERRED 178 |
| PD-3 | the thread-per-round executor (`driver.rkt:567`) costs 1.4–1.6× on the heavy files and about 111 KB per thread created; C6 claims fires race on shared boxes today | cost replicated by 3 critics; the race claim goes to W2-4 | posed as O-14 in D.3 |
| PD-4 | the pool executor drops fires when n > k | measured (C7); dead in production | P0.5 deletes it |
| PD-5 | the strata outer loop raises an uncaught exception after 20 iterations | measured (C8); latent today | W2-4 checks reach |
| PD-6 | which contradiction is reported depends on install order (last writer in `net-cell-write`, first in bulk) | measured (C5, C9) | CL-10 |
| PD-7 | the BSP-LE master's definition of completion is unsound even under BSP | probe (C8) | a proposed edit to the master (CL-17) |

## 5. Coverage

Findings that name each D.2 section, and the critics that raised them. Computed from the findings' `section` fields
(`wave1-findings-index.json`).

| § | findings | critics | | § | findings | critics |
|---|---|---|---|---|---|---|
| §0 | 9 | 5 | | §6.8 | **1** | **1** |
| §1 | **2** | **2** | | §7 | 10 | 7 |
| §2 | 14 | 7 | | §8 | 10 | 7 |
| §4 | 5 | 4 | | §9 | 22 | 8 |
| §5 | 19 | 7 | | §10 | 19 | 8 |
| §6.1 | 8 | 3 | | §11 | 16 | 3 |
| §6.2 | 3 | 3 | | §12 | 14 | 5 |
| §6.3 | 39 | 9 | | §13 | 9 | 7 |
| §6.4 | 9 | 8 | | §14 | 13 | 7 |
| §6.5 | 12 | 7 | | §15 | 7 | 5 |
| §6.6 | 27 | 9 | | §16 | 9 | 7 |
| §6.7 | 33 | 10 | | | | |

**Under-covered**:
- §6.8 (P4/P5, a deliberate deferral) and §1 (scope; touched through CL-16).
- §6.1, §6.2 and §11 have three critics each. §11 was C8's charge.

**A gap no critic was charged with**: the experience of users and developers at K > 1 and after P2. That covers:
- determinism of diagnostics (which contradiction and which error are reported);
- the LSP and editor round view;
- reproducibility and flaky tests under nondeterministic schedules;
- user-visible `:fuel`, `:timeout` and `:execution` semantics;
- progressive disclosure.

## 6. Contested points (input to wave 2)

1. **`:usage`**: is the chain (C9-9) or the interval lattice (C4-6) right? They disagree only about ⊥ (unsolved
   multiplicity).
2. **The value of P2-lite** (an ESTIMATE, C10-3) against P2's model.
3. **The fence's form**: (i) whole network at K = 1, (ii) a canonical fold per component, or (iii) cone or taint.
4. **The replay**: BSP as a permanent oracle (D.2; D.1 GT-2), or a lifted Kleene network (C1-8).
5. **The detector's repair**: a parity counter, a quiet mark, cons counted after the cascade, or credit recovery.
6. **Fire context**: marks (D.2), no ambient channel at all (C1-9), or a captured parameterization (C6-2). These are
   compatible: delete the srcloc binding, and treat the rest as CL-13.
7. **Whether P3 belongs in PAR 4 at all** (C10-6) or in a sequel.

## 7. Proposed wave 2 (ten agents)

Every wave-2 agent gets:
- the wave-1 briefing's rules;
- this triage;
- the raw outputs directory;
- the clusters it addresses.

**Settlers.** Each runs probes with power checks and returns a verdict.

| id | settles | charge |
|---|---|---|
| W2-1 | CL-1, CL-4, CL-16 | With the thread executor off, on the heavy files and a corpus sample, measure under **per-component** (position, facet) ownership and fencing: the busiest executor's share *by fire time*; the fenced share by time; fenced↔free crossings per S0 run. Also measure the per-cell rules, to calibrate against C3, C7 and C10. This decides whether P3 has a workload in this track |
| W2-2 | CL-2, CL-16 | In a scratch copy (`git archive`, never a worktree), apply three variants: (a) the thread executor removed, (b) a keyed diff for pointwise merges with an equivalence monitor and its power row, (c) both. Measure command time A/B/C/D on the heavy files and the medium tier, interleaved, holding the suite lock. This decides how the gain splits between P0.5, P2-lite and P2 |
| W2-3 | CL-3, CL-10, CL-11 | Build one exhaustive model, K = 2–3, with local cascades, counted fire requests, contradiction, nested regions and a store-buffering memory abstraction. Check every proposed repair in it and choose the smallest sound one. Then measure its cost in a microbenchmark in the style of `detect.rkt`, including the cascade case |
| W2-4 | CL-5 | For PD-1, PD-2, PD-3 and PD-5: how production reaches each (when `'auto` picks ATMS; which tests and examples reach PD-1; Tier-1 reach, bounded statically; whether fires on the thread executor touch shared mutable state today, reproduced or bounded, using `current-parallel-executor` as the injection point, with no rebuild). Return entries ready for DEFERRED |
| W2-5 | CL-13 | A static census from S0 fire bodies to parameter reads. Classify each parameter by how it is assigned: `parameterize`-scoped, direct per-command assignment, install time, or module level. Say which would be wrong on a persistent executor, and which are wrong on today's thread executor (shared with W2-4) |
| W2-6 | CL-6 | Check the worldview proposals for mutual consistency: the ev_W read with the base; cell-1 split into information and viewpoint; static labels with labelledness closed downstream; invalidation only at boundaries; `unify-fire` writing both sides. Check them against the 10–11 writers and the tests that pin replacement semantics (`test-tagged-cell-value.rkt:213-224`, `test-solver-context.rkt:341-362`): which tests must flip, and why |
| W2-7 | CL-14 | `:usage`: the chain against the interval lattice with ⊥, at every arity, under the one-writer obligation. Row 8: the clash test on a richer universe (dependent codomains, Sigma, applications). A census of installed type merges, Role A against Role B, on S0-written cells over a sample of the suite |

**Defenders.** Each argues back from the codebase and the principles.

| id | defends | charge |
|---|---|---|
| W2-8 | K > 1 in PAR 4 (against CL-1, CL-4, C10-6) | The strongest case for keeping P3 in this track, and the design that would make it pay |
| W2-9 | DIRECT at K = 1 (P2), and BSP as the oracle (against C10-3, C10-6, C1-8) | What DIRECT gives beyond speed: the undeclared-write class vanishes (C2-8), no snapshot ceremony, one fire-once semantics, a substrate for K > 1. Whether P2-lite is a step toward DIRECT or a replacement for it. Whether a lifted Kleene network is cheaper than keeping BSP |

**Gap critic.**

| id | covers | charge |
|---|---|---|
| W2-10 | the uncovered theme (§5) | The experience of users and developers at K > 1 and after P2: determinism of diagnostics; the LSP and VS Code round view; flaky tests; user-visible `:fuel`, `:timeout` and `:execution`; progressive disclosure |

**Rules beyond wave 1's**:
- W2-2 alone may build, in its scratch copy. It builds with `PLT_CS_COMPILE_LIMIT=1000000` and `-j 4`, and times
  only while holding the suite lock (`benchmarks/par4/hold-suite-lock.rkt`).
- No agent creates a git worktree or writes to `.git`.
- Settlers report a verdict per contested point, with its power check.
- Defenders must engage the strongest form of the finding they answer.

After wave 2, the synthesis of record is written by hand. It gives every finding one of the four responses, and
leads to D.3 and owner decisions O-14 onwards. Those include the thread executor (CL-2), the fence's form (CL-4),
re-opening O-2 on fuel (CL-9), the representation and γ1 (CL-12), the cross-track contracts (CL-17), and scope
(CL-16).
