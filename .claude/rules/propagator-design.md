# Propagator Design Checklist

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

## Component Indexing

**MANDATORY**: Any propagator watching a compound cell (hasheq, scope-cell, decisions-state, commitments-state) MUST declare `#:component-paths` specifying which components it watches.

Without component-paths, the propagator fires on EVERY component change — including components it doesn't read. This defeats the purpose of compound cells.

Pattern: `#:component-paths (list (cons cell-id component-key) ...)`

Also applies to `net-add-broadcast-propagator` (extended in Phase 5.1b to accept `#:component-paths`).

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

## Assumption-Tagged Dependents

When a propagator belongs to a branch (e.g., a clause in multi-clause execution), tag it with `#:assumption aid #:decision-cell dcid`. The scheduler's `filter-dependents-by-paths` checks viability via on-network decision cell read — when the assumption is eliminated, the propagator becomes inert without explicit removal.
