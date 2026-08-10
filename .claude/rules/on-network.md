# On-Network: The Self-Hosting Story

## The Design Mantra

> **"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."**

This is not a guideline. It is the gravity of the system. Every design decision — every propagator installation, every cell allocation, every loop, every parameter, every return value — must be challenged against each word:

- **All-at-once**: Is this processing N independent items sequentially? If item i doesn't depend on item j, they must not be sequenced. `for/fold` over independent items is step-think. Broadcast or simultaneous installation is the answer.
- **All in parallel**: Is there imposed ordering? BSP fires everything in a round simultaneously. If you're deciding what fires first, you're fighting the architecture. Ordering must EMERGE from dataflow depth, not from installation sequence or imperative dispatch.
- **Structurally emergent**: Does the computation's shape fall out of the lattice topology? Or is imperative control flow deciding what happens when? If a function reads a value and branches on it to decide what to install, that's imperative dispatch. If a propagator watches a cell and fires when it changes, that's emergent.
- **Information flow**: Do values move through cells via propagators? Or through return values, parameters, `for/fold` accumulators, imperative mutation? A function that returns a result is a function call. A propagator that writes to a cell is information flow. The distinction is architectural, not cosmetic.
- **ON-NETWORK**: Is this a cell with a monotone merge? Or is it a parameter, a struct field, a hasheq threaded through a loop? Off-network state is debt against self-hosting. Every `make-parameter` with a hasheq is a cell that hasn't been born yet.

**When to invoke**: At every decision point during propagator design and implementation. Before writing a `for/fold`. Before adding a parameter. Before returning a value instead of writing to a cell. Before choosing between imperative dispatch and reactive firing. The mantra is what you say while your hands are on the keyboard — the principles docs are what you read before designing.

Everything on the propagator network. No exceptions. Off-network state is debt against self-hosting.

Every Racket `make-parameter` holding a hasheq of "things the system knows about" is a candidate for migration to a cell on the network. The self-hosted compiler runs on propagator networks — every compiler data structure must be expressible as a lattice-valued cell.

## Migration Checklist

When encountering off-network state, ask:

1. **Is this data monotone?** (only grows, never shrinks) → cell with set-union/hash-union merge.
2. **Is this a registry?** (maps names to things) → hash-union cell. Table registry (Phase 8) is the pioneer. Module registry, relation store, trait dispatch tables follow.
3. **Is this computation?** (transforms inputs to outputs) → propagator.
4. **Is this a parameter?** → Question it. Can it be a cell? Parameters are ambient state — cells are explicit information flow.
5. **Is this using `for/fold` to iterate?** → Question it. Is this step-think? Can it be a broadcast or a merge?

## Red Flags

- `make-parameter` with a hasheq value → should be a cell
- `for/fold` threading a network through independent operations → should be all-at-once
- `parameterize` for scoping → should be per-propagator worldview bitmask
- Separate wrapper struct with its own network → dissolve into cells on the solver's network (Phase 5 dissolved `atms`, Phase 8 dissolved `table-store`)
- "We'll bring this on-network later" → technical debt that compounds. Do it now.

## The Lattice Test

Every cell value must be a lattice element with a monotone merge. If you can't define a merge function, the value doesn't belong on the network yet — but that's a design signal, not a permanent excuse. Find the lattice.

### ⚠ CHECK idempotence — do not document it (promoted 2026-08-05, 3 instances)

> Read the *two kinds* subsection below with this one: idempotence is required of a JOIN cell, and four registered merges are deliberately not joins.

`merge(x, x)` must equal `x`. This obligation was written in three ambient rule files and **enforced in none**, and the gap cost fourteen months.

**The failure shape**: a merge that unions two collections with a bare `append`. `(merge x x)` returns twice x's elements, so the cell's lattice VALUE is stable while its REPRESENTATION grows on every write. Change-detection sees a change every round, dependents re-fire, and the network **never quiesces** — a HANG, not a wrong answer. Read cost grows with the representation too, so it accelerates.

**Why it hides**: the merge's own comment usually asserts the property it violates. All three in-tree instances did — *"functionally equivalent to set-union for unique nogoods"*, *"the lattice is P(P(AssumptionId)) under set-union"*. The parenthetical does the work and nothing checks it.

| instance | found by | consequence |
|---|---|---|
| `tagged-cell-merge` / `make-tagged-merge` | a 14-month hunt, at the wrong layer | union-type type-checker hang; also took the LSP down |
| `nogood-merge` | `tests/test-merge-laws.rkt`, **first run** | live cell merge (`atms.rkt`), same latent hazard |
| `merge-hasheq-list-append` | same run | its 3 cells turned out write-only; retired instead |

**Do this**: add every new cell merge to the `MERGES` table in `tests/test-merge-laws.rkt` (24 covered of 29 registered). One `(E "name" fn samples)` row. Idempotence is checked unconditionally; `#:laws '(commutative associative)` is opt-IN, because several merges here are deliberately last-write-wins (`merge-hasheq-replace`). Pass an `equiv` when the carrier's representation is looser than its lattice value — a set carried as a list has an order set-union never claimed. A merge that is knowingly NOT a join (`merge-list-dedup-append`) is registered anyway and pinned as a known non-lattice, so the distinction stays visible instead of being omitted.

**Debug rule**: a propagator network that will not quiesce is a merge that is not idempotent **until proven otherwise**. Check the carrier before the join. The union-type hang was filed as *"the `:type`-facet union join not reaching a fixpoint"* and the join was innocent — that framing sent it at the type-lattice/quantale work for over a year, and the fix was 8 lines in the cell.

### The rule above is TOO STRONG: cells come in two kinds (2026-08-05)

"Every cell value must be a lattice element with a monotone merge" is the ideal, and **four registered cell merges are not joins — three of them correctly**. Enumerated by `tests/test-merge-laws.rkt`:

| merge | `merge(x,x)` | why non-idempotence is RIGHT |
|---|---|---|
| `add-usage` (`qtt.rkt`) | `(m1)+(m1) = (mw)` | semiring ADDITION. Using a linear resource twice makes it unrestricted — **idempotence would break QTT** |
| `merge-list-append` (`relations.rkt` answer cell) | `(append x x)` | Rel T1 POL.1: solution sets are BAGS, multiplicity IS the derivation count — idempotence would break `solve` |
| `warnings-facet-merge` | `(append x x)` | two identical warnings from two sites are two warnings |
| `merge-hasheq-list-append` | grows | no defence; its cells were write-only, now retired |

So the operative distinction is:

- **JOIN cells** — idempotent. CALM-safe, order-independent, any scheduler.
- **ACCUMULATOR cells** — not idempotent. Their correctness depends on a property **nothing checks**: that their writers never re-fire with a value already merged. That is a *scheduling* assumption smuggled into a *cell*, and it is exactly what `tagged-cell-merge` got wrong for fourteen months — an accumulator that believed it was a join.

**When you write a non-idempotent merge, you owe the reason at the merge** (which semiring, which owner ruling), **and you owe a check that its writers are write-once**. `merge-fn-registry.rkt` cannot help: a domain name records WHICH lattice, never WHETHER it is one.

**Fuel will not save you**: fuel is a FIRE-COUNT budget, decremented per propagator fired. It cannot bound the cost of ONE fire, so a single fire merging an unbounded value runs forever with fuel to spare. (Its `on-write-check` was also unreachable under speculation until 2026-08-05 — the hot fast path is gated on `(not under-speculation?)` and the slow path never consulted it.)

## Topology Requests for Dynamic Registration

When a propagator discovers it needs infrastructure that doesn't exist yet (e.g., a table cell for an unregistered relation), it emits a topology request. The topology stratum (between BSP rounds) processes the request, allocates cells, updates registries. This is the CALM-safe protocol for structural mutation.

Pre-quiescence allocation (during installation) is the common case. Topology requests are for mid-quiescence discovery.

## Cell / Propagator / Scheduler Orthogonality (load-bearing constraint on optimization placement)

The on-network mandate is necessary but not sufficient. The mandate says "put everything on the network"; the orthogonality principle says "put it at the RIGHT LAYER of the network."

Per [`DESIGN_PRINCIPLES.org` § Cell / Propagator / Scheduler Orthogonality](../../docs/tracking/principles/DESIGN_PRINCIPLES.org), the architecture has three orthogonal layers:
- **Cell**: state storage + read/write API; declares lattice + merge + (optionally) storage strategy
- **Propagator**: computational rule; reads cells, writes cells; declares dependencies + fire-pattern
- **Scheduler**: runs propagators against cells; determines firing order, parallelism, round structure

Optimizations on the on-network substrate should be located at the layer that owns the concern. **Specifically: optimization choices that respect on-network must ALSO respect scheduler-independence**.

**Red flag for on-network optimization**: when "this cell's behavior is faster under scheduler X" or "this propagator's optimization piggybacks on BSP's worklist drain," you've coupled on-network state to scheduler-specific execution. The state is technically on-network but its SEMANTICS depend on the scheduler — which violates CALM's order-independence and breaks portability across schedulers (Gauss-Seidel, BSP, Zig-LLVM, future distributed runtime).

**On-network optimization is principled when**:
1. The optimization is a property of the CELL (storage strategy, write-pattern, read-policy)
2. The optimization is a property of the PROPAGATOR (fire-pattern, dependency-notification policy)
3. The optimization's semantics are identical under any scheduler

**On-network optimization is principle-violating when**:
1. The optimization piggybacks on scheduler-specific machinery (e.g., BSP-round drain pass)
2. The cell or propagator's behavior depends on the scheduler's execution mode (sequential vs parallel; sync vs async)
3. Porting to a new scheduler requires re-implementing the optimization (not just inheriting it)

This rule is load-bearing for future tracks where optimization pressure is high (PReduce e-graph cost extraction; OE Series weighted parsing; SH Series self-hosted runtime). Without the orthogonality discipline, optimizations would couple to the current scheduler (Racket BSP) and have to be re-derived for each future scheduler. With the discipline, optimizations declared at cell + propagator level work under ANY scheduler — Prologos networks become genuinely portable.
