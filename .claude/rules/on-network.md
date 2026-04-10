# On-Network: The Self-Hosting Story

Everything on the propagator network. No exceptions. Off-network state is debt against self-hosting.

## The Mandate

"All-at-once, all-parallel, structurally emergent information flow on-network."

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
