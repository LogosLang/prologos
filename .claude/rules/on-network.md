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

## Topology Requests for Dynamic Registration

When a propagator discovers it needs infrastructure that doesn't exist yet (e.g., a table cell for an unregistered relation), it emits a topology request. The topology stratum (between BSP rounds) processes the request, allocates cells, updates registries. This is the CALM-safe protocol for structural mutation.

Pre-quiescence allocation (during installation) is the common case. Topology requests are for mid-quiescence discovery.
