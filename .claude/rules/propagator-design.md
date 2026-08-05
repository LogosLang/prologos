# Propagator Design Checklist

> **"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."**

Before applying any checklist item below, challenge the design against the mantra (see `on-network.md` § The Design Mantra). The checklist catches implementation-level mistakes. The mantra catches architectural ones — step-think disguised as propagator code, imperative dispatch wearing a cell-shaped hat, `for/fold` loops that should be broadcasts. If the mantra challenge fails, no amount of correct checklist application saves the design.

Every propagator installation MUST be evaluated against these patterns. This is not optional — violations produce architectural debt that compounds across tracks.

## Fire-Once Propagators

**Question**: Does this propagator produce output exactly once?

If the propagator writes a result and never needs to fire again (narrower, contradiction detector, type-write, usage-write, constraint-creation), use `net-add-fire-once-propagator`. The flag-guard makes subsequent scheduling an instant no-op.

Anti-pattern: installing a fire-once propagator with plain `net-add-propagator`. It still works, but fires repeatedly as a no-op, consuming scheduling overhead on every input cell change.

## Broadcast Propagators

**Question**: Does this code process N independent items?

Any `for/fold` or `for/list` that processes independent items is a candidate for broadcast. If item i's result doesn't depend on item j's result, the items are embarrassingly parallel. Use `net-add-broadcast-propagator`: ONE propagator, ONE fire, ONE merge.

Red flags: `for/fold` that threads state through independent iterations. `for/list` that maps a function over items but could be a broadcast.

Broadcast is the polynomial functor made operational — at the INSTALL layer.

### ⚠ BROADCAST IS NOT PARALLELISM TODAY — corrected 2026-08-02, MEASURED

This section previously said "the broadcast-profile metadata enables the
scheduler to decompose across OS threads" and cited "2.3x faster at N=3, 75.6x
at N=100". **Both were misleading, and because this file is AMBIENT the error
was in front of every session.** What is true at HEAD:

- **`broadcast-profile` is INERT metadata.** It has ZERO production readers —
  `grep -rn 'propagator-broadcast-profile\|broadcast-profile-items\|broadcast-profile-item-fn\|broadcast-profile-merge-fn'` returns exactly 3 hits, ALL
  assertions in `tests/test-decision-cell.rkt`. Nothing decomposes it.
- **The fire-fn is a sequential `for/fold`**, and says so at its own site
  ("Today: sequential loop", `propagator.rkt`).
- **Adopting broadcast is currently ANTI-parallel** where the item count is the
  parallelism you wanted. The executors chunk the worklist of PROPAGATOR IDS
  (`(quotient (length pids) ncores)`), so folding N propagators into 1 removes
  exactly the units the runtime decomposes — and then runs the N items
  sequentially on one thread.
- **The real 2.3×/75.6× effect is INSTALL-OVERHEAD amortization**, not parallel
  speedup: one CHAMP install + one worklist entry + one dependency filter
  instead of N. That is a genuine and often decisive win — just not the one the
  old sentence claimed. `docs/research/2026-07-23_FACT_REPRESENTATION_QUERY_OPTIMIZATION.md` §6 had already established this; the correction never
  reached this tier, which is why it kept being repeated.

**So: reach for broadcast to amortize INSTALL and scheduling cost, and when the
polynomial-functor shape is the honest description of the computation. Do NOT
reach for it expecting threads.** If you need actual parallelism across items,
that is unbuilt work — the profile is the hook it would use, and wiring it is a
named, unclaimed piece of substrate.

⚠ Four further contract facts, each verified, that a caller must know:
`items` is a plain eager list FIXED AT INSTALL (never read from a cell, so an
extent known only after evaluation cannot be expressed) · exactly ONE output
cell · `flags` is literal `0`, so it is **not** fire-once and recomputes all N
items on every input change · the accumulation is a LEFT fold from `'()`, so the
`append`/`set-union` merge the docstring itself recommends is **O(N²)** in the
item count.

## Set-Latch for Fan-In Readiness

**Question**: Does this propagator fan multiple inputs into an "any/N/all inputs ready" signal?

Fan-in is the recurring problem: N independent sources signal "ready"; downstream needs to react when enough of them fire. The imperative instinct is a single propagator that reads all N inputs on every fire and does `for/or` / `count` / `for/and`. This pattern has three defects:

1. **Re-reads ALL inputs on every fire** — even when only one changed. Wasted work.
2. **Loses WHICH input fired** — identity collapsed into a Bool predicate result.
3. **Breaks under compound cells** — when multiple "inputs" share a compound carrier (e.g., universe cells holding per-meta components via hasheq), `(net-cell-read pnet cid)` returns the full compound value. The per-input predicate operates on the wrong level. This is exactly why PPN 4C S2.b's universe migration breaks the pre-existing fan-ins in metavar-store.rkt's constraint/trait/hasmethod readiness pipelines.

**The set-latch pattern (structural shape)**: a monotone-set latch cell + N-input readiness watcher + 1 threshold consumer.

The STRUCTURE is invariant; the REALIZATION of the per-input watcher layer admits two strategies (broadcast for parallel-ready N items, fire-once for legacy per-cell). For mixed-domain inputs (some shared-carrier-with-tags, some legacy per-cell), partition and use broadcast for the universe sub-set + fire-once for the per-cell sub-set — both share the same latch.

```
;; Universe sub-set (shared carrier with component-keyed tagging — preferred when applicable):
broadcast propagator (on shared-carrier-cid, items = list of input identities)
  :component-paths (list (cons shared-carrier-cid id-1) (cons shared-carrier-cid id-2) ...)
  item-fn: (id, input-vals) → if ready (extract id's component from input-vals[0])
                              then (seteq id) else #f
  result-merge-fn: merge-set-union
  output: latch-cid

;; Per-cell legacy sub-set (one cell per input, pre-shared-carrier migration):
Per input i ∈ legacy-sources:
  fire-once propagator (on cell-i)
    reads cell-i's value via net-cell-read.
    If ready, writes (seteq i) to latch-cid.

latch-cid (domain 'monotone-set, merge merge-set-union, bot (seteq))
  accumulates which inputs have fired — monotone, idempotent, CALM-safe.

threshold fire-once propagator (on latch-cid)
  fires action-thunk when (threshold? (cell-value latch-cid)).
  Typical: `(lambda (v) (not (set-empty? v)))` for "any ready";
          `(lambda (v) (>= (set-count v) k))` for "k-of-N";
          `(lambda (v) (= (set-count v) N))` for "all ready".
```

**Infrastructure available** (all first-class, tested):
- `'monotone-set` SRE domain (`infra-cell-sre-registrations.rkt`) — merge via `merge-set-union`, bot-value `(seteq)`, proper join-semilattice
- `net-add-broadcast-propagator` (`propagator.rkt`, BSP-LE Track 2 Phase 1B) — ONE propagator + N items + broadcast-profile metadata for parallel decomposition; supports `:component-paths` (Phase 5.1b extension at line 1638)
- `net-add-fire-once-propagator` (`propagator.rkt`, BSP-LE Track 2 Phase 5) — flag-guarded single-firing, supports `:component-paths`
- `make-threshold-fire-fn` / `net-add-threshold` (`propagator.rkt`) — threshold-gated firing

**Benefits**:
- **Component-path precision**: each watcher fires ONLY when one of its declared inputs changes. Sibling input changes on a shared compound cell don't wake it up. Both broadcast and fire-once support `:component-paths` with cons-pair shape `(cons cell-id path)`.
- **Identity preserved**: the latch retains WHICH inputs have fired. Callers can enumerate.
- **Monotone**: set-union merge is commutative, associative, idempotent. CALM-safe, coordination-free.
- **Fire-once semantics baked in**: each input contributes at most once (broadcast's item-fn returns `#f` when not ready; fire-once flag-guard prevents per-input re-fire; latch is monotone). No spurious re-fires.
- **Generalizes**: the threshold predicate carries the specific semantics (any / k-of-N / all). Same structure, different thresholds.
- **Mantra-aligned at multiple layers**:
  - **all-at-once**: all watchers installed in one helper call (broadcast = 1 install for N items; fire-once = N installs sharing structure)
  - **all-in-parallel**: N items processed in 1 broadcast fire with broadcast-profile metadata enabling future scheduler decomposition; or N independent fire-once propagators that BSP can fire in parallel rounds
  - **structurally emergent**: latch state IS the readiness signal — no control flow decides "are we ready"
  - **information flow through cells**: input change → watcher → latch → threshold → output cell
  - **on-network**: every step is `net-cell-read` / `net-cell-write`

**Why broadcast at install layer (not N fire-once everywhere)**:
- A/B data per § Broadcast Propagators below: 2.3× faster at N=3, 75.6× at N=100 vs N-propagator model
- ONE propagator install vs N — saves CHAMP install overhead + worklist entries + filter-dependents-by-paths evaluations per BSP round
- Broadcast-profile metadata is the polynomial-functor-made-operational: scheduler can partition items across threads at fire time, automatic with no caller code changes
- For mixed-domain inputs (universe + legacy per-cell), broadcast handles the universe sub-set, fire-once handles the per-cell sub-set — both write to the SAME latch via `merge-set-union`. As legacy domains migrate to shared-carrier, the fire-once branch shrinks naturally.

**Anti-pattern** (the thing this pattern replaces):

```racket
;; Red flag: fan-in fire-fn doing for/or over all dep reads on every fire
(define-values (enet-f _) 
  (elab-add-propagator net dep-cids (list threshold-cid)
    (lambda (pnet)
      (define any-ready?
        (for/or ([cid (in-list dep-cids)])
          (let ([v (net-cell-read pnet cid)])
            (and (not (prop-type-bot? v)) (not (prop-type-top? v))))))
      (if any-ready? (net-cell-write pnet threshold-cid #t) pnet))))
```

This pattern has three defects (re-reads ALL inputs per fire, loses identity, breaks under compound cells) AND is the N-propagator model's antithesis of broadcast (sequential `for/or` instead of parallel item processing). Replace with the set-latch+broadcast structure above.

**Applications across Prologos**:
- Constraint retry readiness (`metavar-store.rkt:826+`) — PPN 4C S2.b-iv target
- Trait bridge retry (`metavar-store.rkt:466+`, `resolution.rkt:428+`) — same
- Hasmethod bridge retry (`metavar-store.rkt:618+`) — same
- Future Phase 10 fork-on-union per-branch ready latches (where N = union arity)
- Future Phase 9b γ hole-fill multi-candidate readiness (where N = candidate count, potentially large — broadcast's parallel decomposition becomes load-bearing)

**Prime design pattern — consult before writing any fan-in.** Three concrete instances in the current codebase share the imperative fan-in shape; all three become failures under PPN 4C S2.b's universe migration. The set-latch + broadcast composition is the architecturally-correct replacement, using only first-class primitives we already ship.

**Observation: set-latch and broadcast are complementary, not substitutes**:
- Set-latch is the STRUCTURAL shape for fan-in readiness (where N independent inputs feed an aggregate readiness signal via monotone accumulation + threshold-gated action emission)
- Broadcast is the REALIZATION strategy for processing N independent items in 1 propagator with parallel decomposition

Both apply at different conceptual layers. The architecturally-aligned fan-in uses BOTH: set-latch's structural shape (latch + threshold + watcher) + broadcast's realization at the watcher layer for the shared-carrier sub-set. Per-cell legacy sub-sets fall back to fire-once until they migrate to shared-carrier.

Codified 2026-04-24 after PPN 4C S2.b-iii + full-suite measurement surfaced the compound-cell incompatibility of the pre-existing fan-ins. Refined 2026-04-24 post-mini-audit to specify broadcast realization at the install layer (per the user prompt: "is this also parallel ready according to the all-at-once, all in parallel part of our propagator mantra?") and document the complementary relationship with broadcast. Promoted to "prime design pattern" status — whenever a fan-in is contemplated, this pattern is the default answer, not an optimization to consider.

### Watcher realization variants (3rd added 2026-05-22 from PPN 4C Phase 3A.b)

The watcher-layer realization has three known variants — pick the one matching your input topology:

| Variant | Input topology | Realization |
|---|---|---|
| **(A) Universe sub-set** (codified 2026-04-24) | N inputs as components of ONE compound cell (e.g., universe-cell with hasheq of meta-id → tagged-cell-value) | ONE `net-add-broadcast-propagator` with `:component-paths`, items = component keys, item-fn reads per-component from input-vals |
| **(B) Per-cell legacy sub-set** (codified 2026-04-24) | N inputs across N separate cells (pre-shared-carrier migration) | N `net-add-fire-once-propagator` calls, one per input cell |
| **(C) N-worldview sub-set** (NEW 2026-05-22) | ONE cell × N **worldview-filtered views** (per-branch isolation under speculation) | N `net-add-fire-once-propagator` calls, each wrapped at branch wv via `wrap-with-worldview(branch-bit)`; each reads the SAME cell under its own bitmask via tagged-cell-value subset filtering |

**Variant (C) origin** — PPN 4C Phase 3A.b (D.3 §9.3.4): fork-on-union branches share the attribute-map carrier; each branch's read needs to filter to its own worldview's tagged entries. Variants (A) and (B) don't fit this topology — (A) requires component-keyed compound cells (worldview tagging is orthogonal to component keying); (B) requires N separate cells (we have ONE cell with N worldview-filtered views).

**Carrier prerequisite for Variant (C)**: the carrier cell must be `tagged-cell-value`-aware. For carriers created plain (like the attribute-map), call `promote-cell-to-tagged net cid` at fork-installation time to lazy-promote — the 5-production-site canonical pattern from `relations.rkt` (NAF :2034, guard :2079, fact-row :2481, multi-clause :2564, :2944). Skipping this step breaks per-branch isolation structurally; tagged-wrapping in `net-cell-write` is gated by `(tagged-cell-value? old-val)` and silently merges plain. (PPN 4C Phase 3A.b prior-session diagnostic point.)

**Mantra alignment for Variant (C)**: N independent fire-once propagators wrapped at distinct worldviews = N parallel watchers under BSP scheduling; each watches its own worldview-filtered view of the shared carrier; per-branch isolation is structurally emergent from `tagged-cell-read`'s subset semantics. All-at-once + all-in-parallel preserved at the install layer; structurally-emergent contradiction signal at the read layer; information flow via tagged-cell-value entries written to cells.

### Threshold-consumer realization variants (3rd added 2026-05-22 from PPN 4C Phase 3A.b)

The latch + watcher composition feeds a threshold-gated action emission. Two realizations exist; pick by atomicity requirement:

| Variant | Mechanism | Atomicity | When to use |
|---|---|---|---|
| **Within-round (threshold propagator)** | `net-add-threshold` / `make-threshold-fire-fn` watches the latch cell; fires action-thunk when threshold predicate holds; runs DURING BSP rounds when latch changes | Incremental — fires as soon as predicate becomes true, may fire multiple times as latch accumulates (depending on threshold semantics) | Readiness fan-in: "are all N inputs ground?" → fire-as-soon-as-ready makes the consumer responsive |
| **Between-round (stratum handler)** (NEW 2026-05-22) | `register-stratum-handler!` on the latch (which doubles as a stratum-request cell); the handler runs BETWEEN BSP rounds; reads the full accumulated set once per round; emits the action once per round atomically; auto-resets via `#:reset-value` | Atomic per round — exactly one fire per round; all in-round writes batched | Narrowing-style actions: "atomic worldview narrowing on contradicted branches" → between-round atomicity prevents partial narrowing visible mid-round to sibling branches |

**Between-round origin** — PPN 4C Phase 3A.b (D.3 §9.3.4) `process-fork-contradiction` handler: accumulated branch aids in cell-16 → handler reads set once → atomic `worldview-cache &= ~(bits-of contradicted-aids)`. The narrowing must be atomic per round; otherwise mid-round partial narrowing could prematurely retract a branch before sibling branches' watchers fire. Mirrors PPN 4C Phase 2A.a `process-retraction` pattern.

**Mantra alignment for between-round variant**: all-at-once at the action layer (one narrowing per round, batched across all in-round watcher writes); structurally-emergent (the action consumes the round's accumulated state, not individual events); information flow via cell-15/16-style request accumulator cells; on-network (latch cell + stratum-handler registration + cell-narrowing-write all on-network).

**Anti-pattern**: don't use within-round threshold propagator for narrowing-style actions where partial mid-round narrowing would be visible to sibling propagators in the same round. The cascade can prematurely-retract correct branches whose watchers haven't fired yet. Stratum handler IS the architecturally-correct mechanism for round-atomic actions; threshold propagator IS the architecturally-correct mechanism for incremental-readiness actions. Different domains, different consumers.

### Tier 2 SRE registration for latch cells (added 2026-05-22 from PPN 4C Phase 3A.b cleanup)

The latch cell SHOULD be SRE-registered to the `'monotone-set` domain (`infra-cell-sre-registrations.rkt:130-142`). The canonical merge is `merge-set-union` (proper join-semilattice over set-union). For modules that cannot require `infra-cell.rkt` (e.g., `propagator.rkt` due to the propagator → infra-cell cycle), define the merge LOCALLY with the same semantic and call `register-merge-fn!/lattice local-merge-fn #:for-domain 'monotone-set` to link to the existing domain via Tier 2 reverse-lookup.

Why this matters: SRE classification gives the latch cell architectural alignment with the set-latch pattern, structural classification for `:component-paths` enforcement, and SRE-validated algebraic property declarations (commutative, associative, idempotent). Skipping the registration drift is the "check codebase for existing helpers" miss codified in `DEVELOPMENT_LESSONS.org` § "Mini-Audit Must Verify Carrier Capability AND Check For Existing Helpers."

## Component Indexing

**MANDATORY**: Any propagator watching a compound cell (hasheq, scope-cell, decisions-state, commitments-state) MUST declare `#:component-paths` specifying which components it watches.

Without component-paths, the propagator fires on EVERY component change — including components it doesn't read. This defeats the purpose of compound cells and produces thrashing / system degradation.

Pattern: `#:component-paths (list (cons cell-id component-key) ...)`

Also applies to `net-add-broadcast-propagator` (extended in Phase 5.1b to accept `#:component-paths`).

**NTT refinement** (persisted lesson, 2026-04-17): in the NTT `propagator` form ([NTT Syntax Design §4](../../docs/tracking/2026-03-22_NTT_SYNTAX_DESIGN.md)), `:component-paths` should be an obligation *derivable by the type checker* from any `:reads` / `:writes` cell whose lattice is declared `:lattice :structural`. Omitting it when reading a structural cell should be a **type error**, not a discipline-maintained rule. This refinement is deferred until NTT design work is in scope again (gated on PPN 4 completion) but is load-bearing for the "user-declared propagators type-check for architectural coherence" vision. Recorded here to prevent re-discovery across sessions.

## Per-Propagator Worldview (`current-worldview-bitmask`)

For concurrent execution of multiple clauses/branches on the SAME network, each propagator's fire function sets its own worldview bitmask. This controls:
- `net-cell-write`: tags writes with the propagator's bitmask (not the cache cell)
- `net-cell-read`: filters reads by the propagator's bitmask (not the cache cell)
- `current-speculation-assumption`: returns bitmask as assumption identity

Use `wrap-with-worldview(fire-fn, bit-position)` to wrap fire functions.

CRITICAL: BSP `fire-and-collect-writes` MUST use `net-cell-read-raw` (not `net-cell-read`) for snapshot/result diffing. Otherwise, per-propagator worldview filtering makes tagged entries invisible to the diff, silently dropping writes.

## Cell Allocation Efficiency

**Question**: Are these cells cohesive? Do they always change together?

A set of related values (e.g., all variables in a clause scope) should be ONE compound cell with component-indexed access, not N separate cells. Compound cells reduce CHAMP operations from N inserts to 1 insert.

Examples:
- Logic variable scope: one `scope-cell` per clause instantiation (not one cell per variable)
- Decision state: one `decisions-state` compound cell (not M separate decision cells)
- Commitment tracking: one `commitments-state` compound cell (not K separate commitment cells)

The general principle: separate cells for separate concerns, compound cells for cohesive scopes.

## Fire Function Network Parameter (CRITICAL)

**RULE**: A propagator's fire function MUST use its `net` parameter for ALL cell reads and writes — never a captured outer-scope network variable.

Fire functions are closures that capture their lexical environment at installation time. If the outer scope has a variable named `n` (common in `for/fold` accumulators) and the fire function's lambda parameter is `net`, writing to `n` inside the fire function writes to the INSTALLATION-TIME network, not the BSP SNAPSHOT network. BSP merges the fire function's returned network with the snapshot — a stale installation-time network overwrites all cell changes made since installation.

```racket
;; WRONG — captures outer 'n', writes to stale network
(define (fire net)
  (define val (net-cell-read net some-cid))  ;; reads correctly from snapshot
  (net-cell-write n result-cid val))         ;; writes to STALE outer 'n' ← BUG

;; CORRECT — uses lambda parameter 'net' for both read and write
(define (fire net)
  (define val (net-cell-read net some-cid))
  (net-cell-write net result-cid val))       ;; writes to BSP snapshot ← CORRECT
```

This bug is silent — no error, no crash. The fire function returns a stale network, BSP merges it, and cell values written by other propagators or construction-time code are silently lost. Diagnosed in Track 2 (Bug #2: `fire-and-collect-writes` used `net-cell-read` for diffing) and Track 2B Phase 1a (discrimination propagator captured `n` instead of `net`).

**Prevention**: Name the fire function parameter `net` and NEVER use single-letter network variables (`n`, `m`) inside fire function bodies. If the outer scope uses `n`, the shadowing is invisible. Alternatively: define fire functions at module level (not inside `for/fold`) to eliminate the closure capture risk.

## Assumption-Tagged Dependents

When a propagator belongs to a branch (e.g., a clause in multi-clause execution), tag it with `#:assumption aid #:decision-cell dcid`. The scheduler's `filter-dependents-by-paths` checks viability via on-network decision cell read — when the assumption is eliminated, the propagator becomes inert without explicit removal.

## Cell / Propagator / Scheduler Orthogonality

Propagator design must respect the architectural orthogonality between **Cell**, **Propagator**, and **Scheduler** layers (per [`DESIGN_PRINCIPLES.org` § Cell / Propagator / Scheduler Orthogonality](../../docs/tracking/principles/DESIGN_PRINCIPLES.org)).

**Optimization location rule** — locate optimizations at the layer that owns the concern:

| Concern | Layer |
|---|---|
| State storage strategy (hot/warm/cold; specialized storage for monotone counters; unboxed-fixnum fast-path under no-speculation) | **Cell** |
| Fire-pattern (fire-once; broadcast; set-latch fan-in; threshold-gated firing) | **Propagator** |
| Dependency notification (skip per-write notification for monotone-counter cells; only notify on threshold crossing) | **Cell + Propagator** (cell declares fire-on policy; propagator declares fire-pattern) |
| Scheduling efficiency (BSP barriers; round-robin vs priority; work-stealing; LLVM-lowered firing) | **Scheduler** |

**Anti-pattern: scheduler-coupled propagator optimization**:

When tempted to "piggyback this propagator's behavior into BSP's worklist drain pass" or "make this propagator fire-pattern depend on whether the scheduler is sequential or parallel," STOP. The optimization couples to scheduler-specific machinery and breaks portability across schedulers (Gauss-Seidel, BSP, Zig-LLVM, future distributed runtime).

Find the equivalent optimization at the cell or propagator level:
- Cell declares specialized storage strategy → fast-path applies under any scheduler
- Propagator declares fire-pattern + dependency-policy → scheduler just drains worklist as usual

Per the CALM theorem: monotone computation on fixed topology converges to the same fixpoint regardless of evaluation order. The order is the scheduler's concern. If a propagator's correctness depends on scheduling order, it has a layering violation.

**Historical example (rejected, 2026-05-14)**: during PPN 4C tropical fuel addendum design, an "Option E (BSP-aware piggyback)" piggybacked threshold checks into BSP's worklist drain pass. Rejected because Gauss-Seidel scheduler has no equivalent drain pass; Zig-LLVM scheduler would have entirely different round structure. The correct optimization (cell-level specialized-storage + propagator-level fire-on-threshold-crossing) was adopted instead. See [`DESIGN_PRINCIPLES.org` § Cell / Propagator / Scheduler Orthogonality](../../docs/tracking/principles/DESIGN_PRINCIPLES.org) for the load-bearing principle.
