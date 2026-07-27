# Scheduler O(network-size) → O(network-diff) Optimization

**Status**: 🔄 grounding-audit in progress (implementation not started)
**Opened**: 2026-06-03
**Kind**: Standalone scheduler-layer optimization (Cell/Propagator/Scheduler Orthogonality)
**Surfaced by**: PPN 4C Addendum Phase 4B, Probe 2 (network-soup accumulation) → Q-4B.9
**NOT part of 4B**: this is a general scheduler-layer fix that benefits ALL persistent-network work (registry networks, future incremental-editing/LSP, 4B's persistent-mnr residuation). Tracked standalone; cross-referenced from the addendum design `2026-04-21_PPN_4C_PHASE_9_DESIGN.md` §18.21.10 (diagnosis origin).
**Repo at open**: HEAD `d6247221`; production `.rkt` clean at `27ad9708`; branch `main` (9+ ahead of origin — don't push); suite **8327 / 0**.

---

## §1 Progress Tracker

| Step | Description | Status | Notes |
|---|---|---|---|
| Baseline | reproduce Probe-2 bench (`bench-scheduler-accumulation.rkt`) | ✅ | 22.3× / 25× / write-only FLAT @ `d6247221` (2026-06-03); see §3 |
| Bench fix | escape `~1` in the trailing GATE `printf` (exit-0) | ✅ | trivial; gate now exits clean |
| Grounding-audit | parallel HEAD-pinned facets + completeness critic | ✅ | `wf_78a9d79b-341` (2026-06-03); synthesis + open design decisions → §6; all load-bearing claims R-lens-verified |
| D-S.3 investigation | is the cold-CHAMP mid-fire drop real? | ✅ | `wf_28e9d770-ad6`; latent-not-live + harmless → ASSERT (debug). §7.1 |
| Design LOCKED | converged mini-design (S.1-S.4 + D-S.3) | ✅ | §7 (2026-06-03, co-designed) |
| S-a | `champ-diff` in champ.rkt + `tests/test-champ-diff.rkt` (differential oracle + edge cases) | ✅ | 12 tests green (450 randomized oracle trials + collisions + high-bit + deps-only + O(changed)); champ.rkt compiles; no callers yet |
| S-b | rewire `fire-and-collect-writes` → `champ-diff`; delete 2 folds; debug ASSERT; fix stale comment | ✅ | bench **22×→0.7 (flat)**; 53 targeted + 3 D-S.3 tests green; acceptance+probe 0 errors; adversarial 1-err confirmed PRE-EXISTING (behavior-preserving) |
| S-c | gate (full suite + bench A/B + acceptance; suite-wide invariant-on validation) | ✅ | **GATE GREEN (2026-06-03)**: full suite **8342/0** (flag OFF, prod config); suite-wide invariant validation (flag ON) — invariant holds across all 8341 prod-path tests (lone fail = our own off-by-default test, scaffold artifact); bench **22.3×→0.6/1.1 flat**; acceptance+probe 0 errors. See §10. |

**Per-phase completion protocol** (DESIGN_METHODOLOGY.org Stage 4): each step ends with (a) test coverage, (b) commit, (c) tracker update, (d) dailies, (e) proceed.

---

## §2 Diagnosis (re-grounded @ HEAD `d6247221`)

The O(network-size) per-quiescence cost is in **`fire-and-collect-writes`** (`propagator.rkt:2835-2929`). When a propagator fire changes the cells CHAMP, two computations each `champ-fold/hash` over **all N cells of the result network** (+ a `champ-lookup` per cell):

- **`undeclared-writes`** (`propagator.rkt:2869-2890`) — folds all result cells; for each existing cell (`(< (cell-id-n cid) snapshot-next-id)`) not already a declared output, `champ-lookup`s the snapshot and compares values. Catches contradiction/leaked writes to non-output cells.
- **`new-cells`** (`propagator.rkt:2894-2910`) — folds all result cells; for each, `champ-lookup`s the snapshot to decide "is this cell new?"; for new ones, extracts merge-fn/contra-fn/widen-fn/cell-dir from the 4 fn-CHAMPs.

→ **O(N log N) per fire**, regardless of how few cells actually changed.

Already O(diff) and NOT the problem:
- **`value-writes`** (`:2858-2865`) — loops only over `output-cids` (declared outputs). O(outputs).
- **`new-propagators`** (`:2914-2923`) — range over `[snapshot-next-prop-id, result-next-prop-id)`. O(new props).

The two `(eq? snap-cells result-cells)` guards (`:2873`, `:2897`) short-circuit only the **no-change** case to O(1); any real write defeats them and the whole-CHAMP fold runs.

**Why it's O(N)**: the immutable-CHAMP + per-propagator sparse cell-id namespaces don't track *which* cells changed; the scheduler re-derives the delta by scanning the whole result. (The `new-cells` code comment claims "O(new cells) via structural comparison of persistent tries" but the implementation `champ-fold`s all cells.)

**Confirmed by elimination** (Probe 2d): worklist is O(1) (2 in / 0 out), `add-propagator` flat, `bulk-merge-writes` O(writes), GC ~1% — the two folds are the only O(N) thing in the path.

---

## §3 Baseline measurements (2026-06-03, @ `d6247221`)

`racket benchmarks/micro/bench-scheduler-accumulation.rkt` (N=1000 commands on a persistent network, per-command quiescence):

| Variant | first50 | last50 | ratio | mem/cmd |
|---|---|---|---|---|
| accum, no self-clean | 0.0169 ms | 0.3772 ms | **22.3×** | 727 B |
| accum, self-clean (P2) | 0.0136 ms | 0.3388 ms | 25× | 161 B |
| write-only (no props/quiescence) | 0.0014 ms | 0.0011 ms | **0.8× (FLAT)** | — |

Reproduces the Probe-2 numbers (§18.21.9). **Interpretation**: per-command quiescence grows ~22× over 1000 commands (≈ O(N) per command → O(N²) over a file). Write-only is FLAT → the cost is in `run-to-quiescence`/`fire-and-collect-writes`, **not** the cells (CHAMP write is O(1)-ish) and **not** propagator-count (self-clean cut memory 4.5× but left time growth unchanged).

---

## §4 O(diff) feasibility — eq?-pruned CHAMP structural diff

The result network = `snapshot + O(writes)` CHAMP-inserts → it **shares structure** with the snapshot; the two tries differ in only O(changed) nodes. An **eq?-pruned structural diff** (recurse into `result-cells` vs `snap-cells` only where child sub-trie node refs differ by `eq?`; structurally-shared equal sub-tries are `eq?` and skipped wholesale) is **O(changed)** — it replaces all the full scans with one pass. It is the root-level `(eq? snap-cells result-cells)` guard **pushed recursively down the trie**.

- **Semantics-preserving** (CALM — same writes collected → same fixpoint).
- **Scheduler-layer** (cell/propagator semantics untouched) — Cell/Propagator/Scheduler Orthogonality. Benefits any persistent-network consumer, not just 4B.

**Load-bearing correctness premise** (to verify in the audit, §6): champ insert preserves `eq?` on untouched sub-nodes — sound AND O(changed). The transient/owner-ID (`edit` field) path is the risk: a node mutated in place could be `eq?` to the snapshot's yet have different content (→ unsound). The audit settles whether the result CHAMP is fully persistent (`edit = #f`) at the point `fire-and-collect-writes` diffs it.

---

## §5 Fix options (sequenced)

1. **(quick, partial)** Guard `new-cells` on `(= snapshot-next-id result-next-id)` (`net-new-cell` bumps `next-cell-id` on every create, even namespaced — `champ.rkt:~1329`) → skips the `new-cells` fold when the fire created no cell (the residuation common case: write an existing cell). **~2 lines, safe, ~2×** — but **still O(N)** (`undeclared-writes` fold remains). Use as an empirical validation of the diagnosis before the bigger primitive.
2. **(full, the target)** A CHAMP **eq?-pruned structural-diff primitive** in `champ.rkt` (~40-80 LoC + tests; HAMT edge cases: collision nodes, content-vector packing, transient/owned nodes) → rewire `fire-and-collect-writes`' scans into one O(changed) diff that returns the changed + new cell-ids, classified (declared-output → merge; undeclared → direct-set) and with fn-CHAMP entries fetched for new cells. **True O(diff).**
3. **(alt, not preferred)** Per-fire write-log on `net-cell-write` → read O(writes). Avoids champ-diff but touches the hotter `net-cell-write` path.

`undeclared-writes` has no cheap guard (no signal for "an undeclared write happened" without scanning) → only the structural diff (Option 2) makes it O(diff).

---

## §6 Grounding-audit synthesis (`wf_78a9d79b-341`, 2026-06-03 — main-session R-lens-verified)

4 read-only HEAD-pinned facets + completeness critic (5 agents). All coordinates VERIFIED @ `d6247221`. Every load-bearing claim independently R-lens-verified in the main session (champ-insert eq?-sharing champ.rkt:161-229; net-cell-write persistent insert :1925/:2023; provide list champ.rkt:12-40; cell-id-hash :606; prop-net-cold :439-443; bulk-merge-writes :2936-3026; the 3C.b.5.c bug typing-propagators.rkt:1208-1233).

### §6.1 Verified findings

**Diagnosis confirmed + SHARPENED (key new finding):**
- C1-C4 confirmed: `undeclared-writes` (:2869-2890) + `new-cells` (:2894-2910) each `champ-fold/hash` over ALL result cells + `champ-lookup` per cell → O(N log N)/fire. `value-writes` (O(outputs)) + `new-propagators` (O(new) via next-prop-id range) are already O(diff).
- **The O(N) cost is driven by ORDINARY value-writes to existing (declared-output) cells — NOT undeclared-writes or new-cell allocation.** A plain `(net-cell-write out v)` to a declared output rebuilds the cells root → `(eq? snap-cells result-cells)` false → BOTH folds scan the whole network and find ZERO undeclared/new = **100% wasted re-scan**. The single most common write path → the optimization's win is **BROAD, not edge-case**. (The GATE bench self-clean=#f variant is exactly this; self-clean=#t adds a dependents-CHAMP rewrite, same effect.)
- The live fast-path guard is `(eq? snap-cells result-cells)` (:2873/:2897). `result-next-id` (:2847) is a **DEAD binding** (never read) — the design's "Option-1 next-id guard" would *revive* it.

**Soundness — VERIFIED SOUND (O(changed) + correct):**
- `champ-insert` preserves `eq?` on untouched sub-nodes: child-update returns the same node when `(eq? new-child child)`; the changed path is rebuilt by `vector-copy` (siblings carried by reference → `eq?`); insert returns the SAME root when unchanged; all new nodes `edit=#f` (champ.rkt:166-168, 194-198, 219-229). → eq?-pruned diff is **sound AND O(changed)**.
- The fire-path cells CHAMP is FULLY PERSISTENT (`edit=#f`) at the diff point: `net-cell-write` uses persistent `champ-insert` on both paths (:1925, :2023), never owned-transient; the only owned-transient sites (net-add-propagator, broadcast) `tchamp-freeze-owned` BEFORE exposing the network. The FAST-BUT-UNSOUND case (mutated owned node still `eq?`) cannot arise. Soundness is **caller-dependent** (champ.rkt doesn't enforce freeze-before-expose) → the primitive documents + asserts the persistent-vs-persistent precondition via `champ-all-persistent?` (exported, champ.rkt:40).
- **Collision nodes are UNREACHABLE for cell-id-keyed CHAMPs**: `cell-id-hash` is the identity on the Nat (perfect hash, propagator.rkt:606) → distinct cell-ids never collide. All prop-network CHAMPs are collision-free.

**The output contract (what the replacement must preserve):**
- 5-field `fire-result` struct (:2833): value-writes / new-cells / new-propagators / contradiction / undeclared-writes. ALL 5 scheduler-executor callers (sequential :3126, parallel :3466, thread :3518, pool :3721, streaming :3756) funnel into ONE `bulk-merge-writes`; tree-reduce's `merge-fire-results` appends the 5 fields → the primitive MUST keep the 5-field shape. No Gauss-Seidel/widening/narrowing caller routes through `fire-and-collect-writes` (they're independent oracles).
- **The 3-way classification (value→merge / undeclared→direct-set / new→register) is load-bearing** — a real bug (PPN 4C 3C.b.5.c, typing-propagators.rkt:1208-1233): an undeclared write became LAST-WRITE-WINS instead of monotone set-union; the fix declared the cell as output (→ merge path). The replacement must reproduce: value-writes through merge (net-cell-write :2987); undeclared as direct-set (inline `struct-copy` + manual enqueue, bypass merge, :3002-3015); the partition computed from output-set membership + `(< (cell-id-n cid) snapshot-next-id)`, **threaded into the diff (NOT structural)**.
- new-cells = 6-tuple `(cid cell merge-fn contra-fn widen-fn cell-dir)`; bulk-merge re-inserts into cells + merge/contra/widen/dir in lockstep (:2962-2972), idempotent existence guard (:2960).

**Structural constraint**: `champ-node`/`champ-collision`/`champ-root` + node accessors are NOT in the provide list (champ.rkt:12-40). **The diff primitive MUST be defined inside champ.rkt + added to provides** (it can't be written in propagator.rkt against current exports).

### §6.2 Capture-gaps (pre-existing; flagged)

- **cell-domains / cell-decomps / pair-decomps DROPPED for mid-fire-created cells.** prop-net-cold has 6 cell-id-keyed cold CHAMPs (propagator.rkt:439-443); the new-cells capture (:2905-2908) + bulk-merge re-insert (:2962-2972) carry only 4 (merge/contra/widen/dir). cell-domains (Phase 1c, written :1330-1332), cell-decomps, pair-decomps are NOT carried → a cell allocated mid-fire that resolves a domain loses its domain entry on re-apply. **Pre-existing latent drop, orthogonal to this optimization** ("whether a domain-bearing cell is allocated mid-fire" is inferred-plausible, not traced to a concrete site). Decision → §6.3 D-S.3.
- **Test coverage gaps** the primitive's tests must fill: undeclared-writes (contradiction→input-only cell), new-cell-during-fire, namespaced parallel new-cell alloc, champ-collision nodes — NONE have unit coverage today. `--all` globs only `tests/test-*.rkt` (run-affected-tests.rkt:372-376) → tests go in a NEW `tests/test-champ-diff.rkt` (a champ.rkt `module+ test` block is NOT run by the suite).
- Stale in-code coordinates: typing-propagators.rkt:1211/1227/1230-1231 cite stale propagator.rkt line numbers (structural description correct; numbers drifted). This doc's coordinates are correct @ HEAD.

### §6.3 Open design decisions (co-design — gate the LOCKs)

- **D-S.1 — primitive scope**: (a) cells-specific (assert/`error` on a champ-collision node — safe, since cell-id CHAMPs are collision-free) vs (b) general `champ-diff` (structural collision compare → reusable for any persistent-network work, but its own tests are the first to construct a collision node). *Lean (b)* general + collision branch + persistent-precondition assert, since standalone-reusable is the stated point — with a forced-collision unit test (custom colliding hash, per the existing inline champ test pattern).
- **D-S.2 — signature / rewiring**: keep `value-writes` computed separately from `output-cids` (O(outputs)); replace ONLY the two O(N) folds with one eq?-pruned parallel walk of (snap-cells, result-cells) → `(values changed-existing new-keys)`; `fire-and-collect-writes` partitions changed-existing by output-set → undeclared, builds the 6-tuple for new-keys. Threads output-set + snapshot-next-id. (Exact signature co-designed at mini-design.)
- **D-S.3 — capture-gap**: perpetuate the cell-domains/cell-decomps/pair-decomps drop (behavior-preserving; flag in DEFERRED) vs fix-as-bonus. *Lean perpetuate* (keep the optimization behavior-preserving; fix the drop separately if a concrete mid-fire domain-bearing cell surfaces).
- **D-S.4 — Option-1 first?**: the audit fully confirms the diagnosis; Option 1 (revive `result-next-id` to guard the new-cells fold) is a ~2× partial that validates empirically but is subsumed by Option 2. *Lean*: optional quick confidence check, else straight to Option 2 under the Stage-4 protocol.

---

## §7 Converged design — LOCKED (2026-06-03, co-designed)

| # | Decision | Resolution | Principle |
|---|---|---|---|
| S.1 / D-S.1 | collision handling | **general** `champ-diff`, handles collision nodes structurally | Correct-by-Construction — don't depend on the unverified "collisions unreachable" claim: the trie uses only the low 35 hash bits, so namespaced cell-ids (`(ns<<32)\|local`, ns≥8 reaches bit ≥35) *can* land in a collision node |
| S.2 | retire old folds? | **YES — one production path** (`champ-diff`); the two `champ-fold` scans are deleted from `fire-and-collect-writes` | Correct-by-Construction — no dual production path |
| S.2 (i/ii) | parity oracle | **(i) permanent** ~10-line naive model in the test as a standing randomized differential guard (a test reference impl, NOT a production fork) | model-based testing |
| S.3 / D-S.3 | the `cell-domains`/`cell-decomps`/`pair-decomps` drop | **ASSERT (debug-mode)** invariant at the new-cells capture point + regression test; NOT capture-all-7, NOT defer | Correct-by-Construction (make the latent silent-drop loud); Decomplection (perf change stays behavior-identical); let-pain-drive-design (no speculative capture machinery) |
| S.4 | Option 1 first? | **No — straight to Option 2** | Completeness |
| cleanup | stale comment | fix propagator.rkt:2170-2171 ("net-new-cell will error during BSP fire rounds" — false; contradicts the CALM contract at :17-22) | honest docs |

### §7.1 D-S.3 investigation result (why ASSERT, not fix/defer)

`wf_28e9d770-ad6` (4 facets + critic; load-bearing facts main-session R-lens-verified). The drop **splits by CHAMP**:
- **`cell-decomps` + `pair-decomps`** — written ONLY by decomposition, which is dispatcher-gated: in-fire it emits a topology *request* (a captured value-write); the actual write runs in a `#:tier 'topology` handler between rounds on the canonical net (`current-bsp-fire-round?`=#f). **Structurally unreachable in-fire.** Linchpin (verified): `current-bsp-fire-round? #t` is set at EXACTLY one site (propagator.rkt:2844).
- **`cell-domains`** — written by `net-new-cell` *itself*; `net-new-cell` IS allowed + captured in-fire. **Reachable-by-primitive, unreachable-by-current-callers** — a caller-invariant, not a structural impossibility. (The "CALM guard errors on in-fire net-new-cell" belief came from the STALE comment at propagator.rkt:2170-2171.)
- **Impact if ever triggered**: at worst wasteful-but-correct; `cell-domains` is self-healing (re-derivable from the captured merge-fn; sole consumer is a debug-lint `enforce-component-paths!`). No corruption path.

→ Not a live bug, not structurally impossible: a latent gap guarded only by convention. **ASSERT** makes the invariant structural (loud failure if any future caller violates it) at zero production cost (debug-gated) + behavior-preserving — addressing it *now* without speculative capture machinery.

### §7.2 The `champ-diff` primitive (champ.rkt, exported)

`(champ-diff snap-root result-root same?) → (values changed new)`:
- Parallel walk of `result` vs `snap`, **`eq?`-pruning at every node** (identical sub-tries skipped wholesale — the existing root-level `(eq? snap-cells result-cells)` guard pushed recursively down the trie). **O(changed)**.
- For each key present in `result`: absent in snap → `new`; present + `(same? old-val new-val)` → skip; present + not-same → `changed`. Reports result-side adds/changes; does NOT report deletions (documented precondition: `result ⊇ snap`, which holds on the fire path — cells are never removed).
- `same?` is **caller-supplied** (champ.rkt stays prop-cell-agnostic — layering). `fire-and-collect-writes` passes prop-cell-VALUE equality (so dependents-only entry changes are correctly skipped, matching the old fold).
- **Collision nodes** handled structurally (compare entries lists; `eq?` fast-path).
- **Precondition** (documented + debug-assertable via the exported `champ-all-persistent?`): both CHAMPs persistent (`edit=#f`). Sound for the fire path — `net-cell-write` uses persistent `champ-insert`; owned-transient sites freeze-before-expose.

### §7.3 Rewiring `fire-and-collect-writes` (S-b)

Replace the two O(N) folds (undeclared-writes :2869-2890 + new-cells :2894-2910) with ONE `champ-diff`; partition its `changed`/`new` via output-set + snapshot-next-id (classification stays in the caller, NOT structural): `changed ∩ output-set` → already in value-writes (skip); `changed ∖ output-set` → undeclared; `new` → 6-tuple. `value-writes` (output-cids, O(outputs)) + `new-propagators` (next-prop-id range) unchanged. 5-field `fire-result` shape preserved. **+ the D-S.3 debug-mode ASSERT**: each new cell carries no `cell-decomps`/`pair-decomps`/`cell-domains` entry.

### §7.4 Differential oracle (permanent — S.2 (i))

`tests/test-champ-diff.rkt` keeps a ~10-line naive model (full-scan classify) and asserts `champ-diff` ≡ model on randomized `(snap, result)` pairs — a standing regression guard. Not a production path.

### §7.5 Sub-phase partition

| Sub | Deliverable | Gate |
|---|---|---|
| **S-a** | `champ-diff` in champ.rkt + provides; `tests/test-champ-diff.rkt` (differential oracle + forced-collision + new-key + namespaced-id + dependents-only-change + no-change eq? + deep/wide tries) | test green in isolation; nothing else touched (`champ-diff` has no callers yet) |
| **S-b** | rewire `fire-and-collect-writes` → `champ-diff`; delete the 2 folds; add the debug-mode D-S.3 assert; fix the stale comment :2170-2171 | probe-diff = 0; targeted scheduler tests pass |
| **S-c** | gate | bench ratio 22×→~1; full suite 8327/0; acceptance file via `process-file` |

### §7.6 Out of scope (tracked)

- The `cell-domains`-in-fire path is *latent-not-live*; the ASSERT makes it loud. A real fix (route any future in-fire domain-cell creation through topology, or extend capture) is deferred to *when the assert fires* (with the concrete case in hand) — DEFERRED.md noted.
- DEVELOPMENT_LESSONS.org "CALM Requires Fixed Topology" describes the guard as *erroring* on in-fire topology change; the actual mechanism is request-emission (dispatcher self-gate). Lessons-doc accuracy note (low priority).

---

## §8 Gate

- `racket benchmarks/micro/bench-scheduler-accumulation.rkt` — per-command quiescence **flattens** (accum ratio ~22× → ~1).
- **Full suite GREEN (8327 / 0)** — `fire-and-collect-writes` is core scheduler; every test runs through it. Mandatory full-suite regression (not a casual edit).
- **Acceptance file** via `process-file` (Level-3).

**RESULT — GATE GREEN (2026-06-03), @ HEAD `756e1794` (S-b, production fire path = `champ-diff`):**
- Bench: accum ratio **22.3×→0.6** (no self-clean) / 25×→1.1 (self-clean) — flat; per-cmd quiescence ~0.006 ms independent of N. O(N²)/file accumulation gone.
- **Full suite (production config, flag OFF): 8342 / 0** (104.3s). Behavior-preserving regression gate passed.
- **Suite-wide invariant validation (flag ON via temporary default-flip, reverted via `git checkout`): 8341/8342** — every production-path test passed *with the D-S.3 invariant asserting*. The lone failure was `test-scheduler-odiff.rkt:52` (the *"silent when OFF (default)"* test, broken only by the scaffold's default-flip; it also confirmed the assert fires correctly on a real domain-cell-mid-fire). → **the D-S.3 caller-invariant now holds as a measured fact across the entire suite**, not just static analysis.
- Acceptance `2026-04-17-ppn-track4c.prologos` + probe `2026-04-22-1A-iii-probe.prologos` via `tools/run-file.rkt`: **0 errors**.

---

## §9 Cross-references

- **Origin / diagnosis**: `2026-04-21_PPN_4C_PHASE_9_DESIGN.md` §18.21.9 (Probe 2) + §18.21.10 (Q-4B.9 diagnosis + fix options).
- **Code**: `propagator.rkt:2835-2929` (fire-and-collect-writes), `:2936-3026` (bulk-merge-writes), `:3201-3442` (run-to-quiescence-bsp); `champ.rkt:54` (champ-node), `:63` (champ-collision), `:66` (champ-root), `:1306-1375` (net-new-cell + next-cell-id bump).
- **Bench**: `benchmarks/micro/bench-scheduler-accumulation.rkt` (durable gate).
- **Principles**: DESIGN_PRINCIPLES.org § Cell / Propagator / Scheduler Orthogonality (scheduler-layer optimization, semantics-preserving, portable across schedulers); .claude/rules/on-network.md.
- **Methodology**: DESIGN_METHODOLOGY.org Stage 4 implementation protocol; .claude/rules/testing.md (full-suite regression gate).

---

## §10 Outcome / close (PIR-lite, 2026-06-03)

**Status: COMPLETE.** `fire-and-collect-writes` per-quiescence cost is now O(network-diff), not O(network-size). Commit chain on `main`: `4b201433` (doc+grounding) → `15249534` (design LOCKED §7) → `1f1171ca` (S-a `champ-diff` + tests) → `756e1794` (S-b rewire) → S-c (this close, doc-only — no production `.rkt` change; the gate is verification).

**What was built**: a general eq?-pruned CHAMP structural-diff primitive (`champ-diff`, champ.rkt, exported) replacing the two O(N) `champ-fold` scans in the BSP fire path. Scheduler-layer, semantics-preserving (Cell/Propagator/Scheduler Orthogonality). One production path (the old folds deleted). Permanent differential oracle (`test-champ-diff.rkt`, 450 randomized trials) + the D-S.3 debug-gated invariant (`current-check-fire-invariants?`, default #f).

**Metrics**: bench accum ratio 22.3×→0.6 (flat); full suite 8327→8342 (+15 tests: 12 champ-diff + 3 D-S.3), 0 failures; net production LoC ≈ flat (champ-diff added, two folds removed).

**Lessons / data points** (candidates for distillation):
- *Adversarial grounding caught a convenient-but-false audit claim*: the "collisions unreachable (perfect hash)" claim was wrong — the trie uses only the low 35 hash bits, so namespaced ids collide; the general primitive + a forced-collision test (hash 0 vs 2³⁵) empirically confirmed it. Correct-by-Construction over "can't-happen" assumptions.
- *Investigate-don't-defer*: the D-S.3 "perpetuate + defer" instinct was the anti-pattern; the investigation (`wf_28e9d770-ad6`) showed it's neither a live bug nor structurally impossible (a caller-invariant resting on a stale code comment), and the principled response was to make the invariant structural (ASSERT) + validate it suite-wide — not defer.
- *Validation scaffold pattern*: flip a debug-gated invariant's default ON for one suite run to convert a static caller-invariant into a measured suite-wide fact, then `git checkout`-revert. The lone "failure" was the off-by-default unit test — a benign, expected scaffold artifact.
- *Stale-doc hazard*: propagator.rkt:2170-2171 ("net-new-cell will error during BSP fire rounds") was false and misled both the framing and a grounding facet; fixed in S-b. DEVELOPMENT_LESSONS "CALM guard errors" framing is similarly aspirational vs the actual request-emission mechanism (low-priority lessons-doc note, §7.6).

**Out of scope (tracked, §7.6)**: the `cell-domains`-in-fire path is latent-not-live (now guarded loudly by the debug assert; a real fix deferred to *if the assert ever fires*).

**Cross-track**: resolves PPN 4C Addendum Phase 4B's **Q-4B.9** (§18.21.10) — the scheduler O(diff) fix that de-risks 4B's persistent-mnr residuation (and benefits all persistent-network work). 4B mini-design resumes from here with the fix in place.

---

## §11 Implications for cell-architecture choices (compound/PU vs separate cells)

A reusable design heuristic distilled from the 2026-06-03 perf discussion. This optimization changed the **economics** of the compound-cell-vs-separate-cells decision that recurs across tracks (4B env cells, PM Track 12 registries, PReduce e-class cells). The decision is **semantically free** (CALM — same fixpoint either way); only the cost model moved.

**What changed.** `fire-and-collect-writes`' per-fire delta-extraction is now O(changed), **independent of cells-CHAMP cardinality N**. Previously it was O(N) *per fire* — a hidden, *ongoing* tax that scaled with the total cell count and was paid on every fire across the whole network. That tax fell on the **separate-cells** strategy (more cells → bigger N → costlier every fire) and was dodged by compound cells (N components collapse to ONE cells-CHAMP entry the fold saw as a single item). **It is now gone.** So compound cells had a *hidden fourth perf advantage* — keeping the cells-CHAMP small so the scheduler's per-fire scan stayed cheap — that no longer exists.

**What did NOT change** (compound cells still win these; the fix didn't touch them):
- *Allocation*: 1 cell vs N CHAMP inserts at creation (the classic propagator-design.md § Cell Allocation Efficiency claim — still true).
- *Memory*: 1 entry + a hasheq vs N entries (4A.0: 170 KB vs 270 KB @ N=100).
- *Tree depth*: fewer cells → shallower cells-CHAMP → a log-factor on all per-cell ops.
- *Reads*: a **worldview-tagged** component read (`compound-cell-component-ref/pnet`, 3-unwrap: cell-read + hash-ref + tagged-cell-read) is ~2.5× a plain cell-read (4A.0: 100–111 ns vs 44–47 ns). NB: a *plain* map-in-a-cell reads cheaply — the read penalty is specific to the **tagged/component-path PU**.

**The load-bearing distinction — perf-motivated vs correctness-motivated compound cells:**
- Reaching for a PU **to keep the network small for scheduler speed** → **retired**. Separate cells no longer impose a global per-fire externality on the rest of the network.
- Reaching for a PU for **worldview/speculation tagging (Module-Theory Realization B), wake precision via `:component-paths`, or an embedded structure-aware-merge lattice (partial info / SRE decomposition)** → **unchanged.** These are correctness/expressiveness reasons; the optimization is orthogonal, and the tagged-read cost is the intrinsic price of those semantics, not a scheduler artifact.

**Heuristic for "N related values":**
- **Separate cells** when values are read independently / on a hot path, need first-class per-value identity (cell-id addressability for diagnostics / LSP / `.pnet` / derivation chains), or want simple per-value wake precision. (The old "but it bloats the network and taxes every fire" objection is gone.)
- **Compound/PU cell** when (a) the group is genuinely accessed/merged as a unit, (b) memory or allocation churn dominates, (c) you need worldview/speculation tagging on a shared carrier (Realization B — often decisive on its own), or (d) the value is an embedded lattice with a structure-aware merge.

**Concrete**: this retroactively de-risked the 4A.0 **Variant D** choice (separate per-name env cells over compound) — 4B's persistent mnr with N per-name cells would have paid O(N²)/file under the old fold; now O(changed). The separate-cells choice is cheaper exactly where 4B needs it.

**Principle**: per Cell/Propagator/Scheduler Orthogonality the layers are *semantically* orthogonal but were *economically* coupled (scheduler per-fire cost depended on cell-layer cardinality). The fix **decoupled the economics** — compound-vs-separate is now decidable on the **local merits of the group** (reads / memory / identity / speculation), without a global per-fire-cost externality from network size.

*Status*: 1 data point (this optimization). **Graduation candidate** for `propagator-design.md` § Cell Allocation Efficiency (which today argues the compound-cell efficiency case) once exercised across 4B / PM Track 12 / PReduce e-classes — then codify the nuance there with the accumulated evidence.
