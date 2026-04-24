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

Any `for/fold` or `for/list` that processes independent items is a candidate for broadcast. If item i's result doesn't depend on item j's result, the items are embarrassingly parallel. Use `net-add-broadcast-propagator`: ONE propagator, ONE fire, ONE merge. The broadcast-profile metadata enables the scheduler to decompose across OS threads.

Red flags: `for/fold` that threads state through independent iterations. `for/list` that maps a function over items but could be a broadcast.

Broadcast is the polynomial functor made operational. A/B data: 2.3x faster at N=3, 75.6x at N=100 vs N-propagator model.

## Set-Latch for Fan-In Readiness

**Question**: Does this propagator fan multiple inputs into an "any/N/all inputs ready" signal?

Fan-in is the recurring problem: N independent sources signal "ready"; downstream needs to react when enough of them fire. The imperative instinct is a single propagator that reads all N inputs on every fire and does `for/or` / `count` / `for/and`. This pattern has three defects:

1. **Re-reads ALL inputs on every fire** — even when only one changed. Wasted work.
2. **Loses WHICH input fired** — identity collapsed into a Bool predicate result.
3. **Breaks under compound cells** — when multiple "inputs" share a compound carrier (e.g., universe cells holding per-meta components via hasheq), `(net-cell-read pnet cid)` returns the full compound value. The per-input predicate operates on the wrong level. This is exactly why PPN 4C S2.b's universe migration breaks the pre-existing fan-ins in metavar-store.rkt's constraint/trait/hasmethod readiness pipelines.

**The set-latch pattern**: a monotone-set latch cell + N per-input fire-once propagators + 1 threshold consumer.

```
Per input i ∈ sources:
  fire-once propagator (on source-i, :component-paths (list i))
    reads source-i's value via the appropriate dispatch (meta-solution/
    cell-id, compound-cell-component-ref/pnet, or net-cell-read for per-
    cell sources). If source-i is ready, writes (seteq i) to latch-cid.

latch-cid (domain 'monotone-set, merge merge-set-union)
  accumulates which inputs have fired — monotone, idempotent, CALM-safe.

threshold propagator (on latch-cid)
  fires action when (threshold? (cell-value latch-cid)).
  Typical: `(lambda (v) (not (set-empty? v)))` for "any ready";
          `(lambda (v) (>= (set-count v) k))` for "k-of-N";
          `(lambda (v) (= (set-count v) N))` for "all ready".
```

**Infrastructure available** (all first-class, tested):
- `'monotone-set` SRE domain (`infra-cell-sre-registrations.rkt`) — merge via `merge-set-union`, bot-value `(seteq)`
- `net-add-fire-once-propagator` (`propagator.rkt`, BSP-LE Track 2 Phase 5) — flag-guarded single-firing, supports `:component-paths`
- `make-threshold-fire-fn` / `net-add-threshold` (`propagator.rkt`) — threshold-gated firing

**Benefits**:
- **Component-path precision**: each per-input propagator fires ONLY when its input changes. Sibling input changes on a shared compound cell don't wake it up.
- **Identity preserved**: the latch retains WHICH inputs have fired. Callers can enumerate.
- **Monotone**: set-union merge is commutative, associative, idempotent. CALM-safe, coordination-free.
- **Fire-once semantics baked in**: each per-input propagator fires at most once (flag-guard on fire-once + latch is monotone). No spurious re-fires.
- **Generalizes**: the threshold predicate carries the specific semantics (any / k-of-N / all). Same structure, different thresholds.
- **Mantra-aligned**: all-at-once (N propagators installed in one pass), all-in-parallel (independent watchers), structurally emergent (latch state IS the readiness signal), information flows through cells, ON-NETWORK.

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

Replace with set-latch structure as above.

**Applications across Prologos**:
- Constraint retry readiness (`metavar-store.rkt:826+`) — PPN 4C S2.b-iv target
- Trait bridge retry (`metavar-store.rkt:466+`, `resolution.rkt:428+`) — same
- Hasmethod bridge retry (`metavar-store.rkt:618+`) — same
- Future Phase 10 fork-on-union per-branch ready latches
- Future Phase 9b γ hole-fill multi-candidate readiness

**Prime design pattern — consult before writing any fan-in.** Three concrete instances in the current codebase share the imperative fan-in shape; all three become failures under PPN 4C S2.b's universe migration. The set-latch is the architecturally-correct replacement, using only first-class primitives we already ship.

Codified 2026-04-24 after PPN 4C S2.b-iii + full-suite measurement surfaced the compound-cell incompatibility of the pre-existing fan-ins. Promoted to "prime design pattern" status — whenever a fan-in is contemplated, this pattern is the default answer, not an optimization to consider.

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
