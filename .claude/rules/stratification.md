# Stratification on the Propagator Base

> **"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."**

Stratification is a first-class, composable mechanism on the propagator base. Multiple concrete strata coexist on the same network, orchestrated uniformly by the BSP scheduler. This document codifies the pattern, its instances, and the discipline for adding new strata.

## The Core Pattern

A stratum on the propagator base consists of:

1. **A request-accumulator cell** (hash-union merge semantics) that propagators write to when they need stratum-level processing.
2. **A handler function** with signature `(net × pending-hash) → net` that processes pending requests once S0 has quiesced.
3. **Registration** via `register-stratum-handler!` (in `propagator.rkt`). The scheduler's BSP outer loop iterates all registered handlers uniformly.

The pattern is uniform: topology changes, non-monotone NAF validation, guard evaluation (embedded in S0 via worldview bitmask), and any future stratum all use the same shape.

## The Strata We Have

The project has accumulated multiple concrete strata across tracks. Some use the generalized `register-stratum-handler!` mechanism (Track 2B Phase R4, 2026-04-14); others are pre-existing sequential functions invoked from main loops. Unifying them is ongoing architectural work.

### On the solver network (propagator.rkt / relations.rkt)

| Stratum | Kind | Introduced | Mechanism | Purpose |
|---|---|---|---|---|
| **S0** | monotone propagator firing | base | BSP outer loop fires worklist | Normal propagator computation under CALM monotone merge |
| **Topology** | structural changes between rounds | PAR Track 1 (2026-03-28, `775de006`) | `register-topology-handler!` (legacy box) | Adding new cells, new propagators mid-quiescence |
| **S1 NAF** | non-monotone worldview validation | BSP-LE Track 2B Phase R4 (2026-04-14, `8fbc342b`) | `register-stratum-handler! naf-pending-cell-id` | Fork+BSP+nogood evaluation of `not(G)` — inverts provability |
| **S0 Guard** | monotone condition evaluation | BSP-LE Track 2B Phase 3 (`83276b0d`) | Embedded in S0 via worldview bitmask | Guard goals as worldview assumptions; false guard → nogood |

### On the elaborator network (metavar-store.rkt, PM Series)

These strata predate the generalized `register-stratum-handler!` mechanism. They are invoked sequentially from the main resolution loop (`run-stratified-resolution!`), not via the BSP outer loop's stratum iteration. See `docs/tracking/principles/DESIGN_PRINCIPLES.org` § "Stratified Propagator Networks" for design framing.

| Stratum | Kind | Introduced | Mechanism | Purpose |
|---|---|---|---|---|
| **S(-1) Retraction** | non-monotone narrowing | PM Track 7 Phase 5 | `run-retraction-stratum!` (sequential, invoked from resolution loop) | Clean scoped cell entries for retracted assumptions; assumptions set can only shrink |
| **L1 Readiness** | readiness scan for constraints | PM Track 2 Phase 4 | `collect-ready-constraints-via-cells` (pure scan, observation only) | Identify constraints whose dependencies are now ground → produce action descriptors |
| **L2 Resolution** | non-monotone action interpreter | PM Track 2 Phase 4 | Action interpreter loop (executes descriptors from L1) | Trait lookup, instance commitment, unification retry — mutating commitments |
| **Stratum 3 (verification)** | session/effect verification (planned/referenced) | Architecture A+D (effect-executor.rkt:54) | Referenced in comments; implementation details vary | Ordering verification for effectful computation |

### The generalization gap

- **S0 + Topology + S1 NAF** use the BSP scheduler's general outer loop.
- **S(-1), L1, L2** use `run-stratified-resolution!`'s sequential invocation.
- **Stratum 3** is referenced in design but not fully realized.

These two orchestration mechanisms (BSP outer loop vs `run-stratified-resolution!`) solve the same problem — sequence strata according to fixpoint requirements — in two different places. Unifying them is a legitimate architectural follow-up: the BSP scheduler's stratum mechanism is strictly more general (request-accumulator cell + handler), and the metavar-store's sequential strata could be recast as stratum handlers on the same base.

Topology's `register-topology-handler!` is also a legacy box that predates `register-stratum-handler!`. Functionally equivalent, but kept separate for now — a small cleanup candidate.

### Termination guarantees (from GÖDEL_COMPLETENESS.org)

Each stratum has termination properties the scheduler relies on:

| Stratum | Level | Measure |
|---|---|---|
| S(-1) retraction | 1 (Tarski fixpoint) | Finite assumptions, monotone shrinking |
| S0 (value) | 1 (Tarski fixpoint) | Finite lattice, monotone joins |
| S1 NAF | 2 (Gauss-Seidel fixpoint) | Stratification + finite cells per fork |
| L1 readiness | 1 (Tarski fixpoint) | Pure scan, observation-only |
| L2 resolution | 2 (well-founded) | Cross-stratum feedback decreases type depth |
| Topology | 1 (finite request set) | Bounded cell/propagator allocation per round |

## When to Consider a New Stratum

Reach for a new stratum when a computation:

- **Is non-monotone**: it can retract information (the result can decrease, not just grow). S0 is monotone by CALM; non-monotone work belongs at a higher stratum.
- **Requires fixpoint of another stratum before evaluating**: e.g., NAF needs S0 quiescence before checking provability.
- **Is order-sensitive**: ordering comes from the stratum stack (Sk only fires after S0...S(k-1) quiesce), not from imperative control flow.
- **Changes network topology**: new cells, new propagators — belongs in the topology stratum.
- **Is context-dependent**: e.g., worldview-sensitive evaluation that needs a snapshot of S0 to reason about.

## When NOT to Consider a New Stratum

Not every non-standard computation needs its own stratum:

- **Worldview assumptions** (NAF, guard) can often be encoded via bitmask tagging on existing cells — no new stratum needed. Only reach for a separate stratum when validation requires a FIXPOINT, not a local check. S0 Guard is local (condition evaluated at installation); S1 NAF requires full S0 fixpoint then fork evaluation.
- **Constraint retries** that fire when inputs become ground are propagators with threshold conditions, not strata. If it can be expressed as a propagator that fires when its input cells' values reach a condition, it's S0.
- **Caching / memoization** — cells with monotone merge (hash-union, set-union) handle this within S0.
- **Priority scheduling within a round** — worklist ordering, not stratification. The BSP scheduler handles this.

The test: does this computation require other propagators to REACH QUIESCENCE first? If yes, stratum. If no, probably S0.

## The Request-Accumulator Pattern (Required Shape)

Every stratum handler follows the same pattern:

```racket
;; 1. Reserve a well-known cell-id for the request accumulator
(define my-stratum-request-cell-id (cell-id N))  ; N = next available

;; 2. Pre-allocate the cell in make-prop-network with hash-union merge
(net-cell-write net my-stratum-request-cell-id (hasheq))

;; 3. Propagators requesting stratum processing write to it
(net-cell-write net my-stratum-request-cell-id
                (hasheq request-id request-info))

;; 4. Handler processes pending requests after S0 quiesces
(define (my-stratum-handler net pending-hash)
  (for/fold ([n net])
            ([(req-id info) (in-hash pending-hash)])
    ;; process request — fork, quiesce, check, write outcome
    ...))

;; 5. Register at module load time
(register-stratum-handler! my-stratum-request-cell-id my-stratum-handler)
```

The BSP outer loop clears the cell after the handler runs; the handler is called again only if propagators write new requests.

## Design Discipline

### S0 vs Sk decision

When introducing a new gating-like mechanism, first ask:
- Can it be a *propagator* that reads inputs and writes a worldview assumption bit? (S0 Guard pattern)
- Does it require *another computation to reach fixpoint* before it can be evaluated? (S1 NAF pattern)

The first is cheaper (no fork, no separate round). Only use the second when forced.

### Fork-based handlers must clear the request cell on the fork

S1 NAF handler learned this the hard way: the fork inherits all cell state including the request-accumulator. Without `net-cell-reset` on the fork, the fork's own BSP re-processes the same stratum, forking again ad infinitum. Fuel bounds the damage; the idiom is:

```racket
(define forked (net-cell-reset (fork-prop-network main-net)
                               request-cell-id (hasheq)))
```

### Don't conflate structural and semantic narrowing

Structural narrowing (discrimination: "which alternatives' argument patterns match?") is S0-level. Semantic narrowing (provability: "did the clause body succeed?") requires evaluation, which for non-monotone cases is Sk-level. Using discrimination to answer a provability question mixes the layers (see BSP-LE Track 2B T-a Fix 2).

## Candidate Future Strata and Unification Work

The infrastructure is ready to support additional strata without new primitives:

- **S2 well-founded semantics**: odd NAF cycles (`p :- not q. q :- not p.`) require a three-valued fixpoint at a higher stratum than S1. The well-founded engine (`wf-engine.rkt`) currently runs as a separate solver; it could be unified as a stratum on the same base.
- **Cost-bounded exploration**: tropical thresholds for resource-aware search. A "cost exceeded" request triggers pruning.
- **Constraint activation levels**: constraint propagators that fire only when their dependencies reach a readiness threshold. Currently ad-hoc; could be a stratum.
- **Self-hosted compiler passes**: each pass (parsing, type inference, code generation) is stratum-separable. Running them as BSP strata on the same base gives incremental-compilation for free via cell persistence.

### Unification work (architectural follow-ups)

1. **Topology handler → general strata list** (small): replace `register-topology-handler!` with `register-stratum-handler!` using a reserved topology request-cell-id. Remove the legacy `topology-handlers` box and special-cased BSP iteration. Functional equivalence; removes an inconsistency.

2. **Elaborator strata (S(-1), L1, L2) → BSP scheduler strata** (larger): `run-retraction-stratum!` and the readiness/resolution strata in `metavar-store.rkt` are currently invoked sequentially from `run-stratified-resolution!`. Recasting them as BSP stratum handlers on the same base would give a single orchestration mechanism across solver and elaborator. Scope: medium; requires reconciling the two networks' scheduling semantics.

3. **Stratum 3 (verification)** — referenced in `effect-executor.rkt` but not fully realized. Future Architecture AD continuation work.

## References

### Solver network (BSP scheduler strata)
- `racket/prologos/propagator.rkt`:
  - `stratum-handlers` box (line 2439)
  - `register-stratum-handler!` (line 2441)
  - BSP outer loop stratum processing (line 2665)
  - `topology-handlers` box + `register-topology-handler!` (lines 2420-2423, legacy)
- `racket/prologos/relations.rkt`:
  - S1 NAF handler `process-naf-request` (~line 115)
  - `register-stratum-handler!` call (~line 245)

### Elaborator network (sequential strata in resolution loop)
- `racket/prologos/metavar-store.rkt`:
  - S(-1) Retraction: `run-retraction-stratum!` (~line 1392), `record-assumption-retraction!` (~line 1336)
  - L1 Readiness: `collect-ready-constraints-via-cells` (~line 904, "Readiness Scan (Stratum 1)")
  - L2 Resolution: action interpreter (~line 984, "Action Interpreter (Stratum 2)")
  - Main loop: `run-stratified-resolution!` (invokes S(-1) at ~line 1873)
- `racket/prologos/effect-executor.rkt:54`: Stratum 3 (verification) — referenced, not fully realized

### Design references
- BSP-LE Track 2B PIR §9.6, §12.8 — architectural contribution of generalized stratification
- PAR Track 1 PIR — topology stratum on the solver base
- PM Track 7 PIR — S(-1) retraction stratum
- PM Track 2 — L1/L2 readiness + resolution strata
- Architecture AD — Stratum 3 (session/effect verification)

### Principles
- `docs/tracking/principles/DESIGN_PRINCIPLES.org` § "Stratified Propagator Networks" — the design pattern
- `docs/tracking/principles/DEVELOPMENT_LESSONS.org` — stratification lessons (S(-1) retraction, topology stratum, value vs topology separation)
- `docs/tracking/principles/GÖDEL_COMPLETENESS.org` — termination guarantees per stratum (Tables at §286)
- `docs/tracking/principles/EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org` — effect stratification
- `.claude/rules/on-network.md` — design mantra (stratification must be on-network, not imperative)
- `.claude/rules/propagator-design.md` — propagator-level design checklist
- `.claude/rules/structural-thinking.md` — lattice lens; stratification as a module-theoretic concept
