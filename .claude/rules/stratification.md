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

| Stratum | Kind | Introduced | Handler Registration | Purpose |
|---|---|---|---|---|
| **S0** | monotone propagator firing | base | (no handler — S0 is the base BSP round) | Normal propagator computation under CALM monotone merge |
| **Topology** | structural changes between rounds | PAR Track 1 (2026-03-28) | `register-topology-handler!` (legacy, predates generalization) | Adding new cells, new propagators mid-quiescence |
| **S1 NAF** | non-monotone worldview validation | BSP-LE Track 2B Phase R4 (2026-04-14) | `register-stratum-handler! naf-pending-cell-id` | Fork+BSP+nogood evaluation of `not(G)` — inverts provability |
| **S0 Guard** | monotone condition evaluation | BSP-LE Track 2B Phase 3 | Embedded in S0 via worldview bitmask (no separate handler) | Guard goals as worldview assumptions; false guard → nogood |

Topology's `register-topology-handler!` is a legacy box that predates the general mechanism. It is a cleanup candidate (see architectural follow-ups) — functionally equivalent to `register-stratum-handler!` but with its own separate registry. Future work should unify it into the general strata list.

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

## Candidate Future Strata

The infrastructure is ready to support additional strata without new primitives:

- **S2 well-founded semantics**: odd NAF cycles (`p :- not q. q :- not p.`) require a three-valued fixpoint at a higher stratum than S1. The well-founded engine (wf-engine.rkt) currently runs as a separate solver; it could be unified as a stratum on the same base.
- **Cost-bounded exploration**: tropical thresholds for resource-aware search. A "cost exceeded" request triggers pruning.
- **Constraint activation levels**: constraint propagators that fire only when their dependencies reach a readiness threshold. Currently ad-hoc; could be a stratum.
- **Self-hosted compiler passes**: each pass (parsing, type inference, code generation) is stratum-separable. Running them as BSP strata on the same base gives incremental-compilation for free via cell persistence.

## References

- `racket/prologos/propagator.rkt`:
  - `stratum-handlers` box (line 2439)
  - `register-stratum-handler!` (line 2441)
  - BSP outer loop stratum processing (line 2665)
- `racket/prologos/relations.rkt`:
  - S1 NAF handler `process-naf-request` (~line 115)
  - `register-stratum-handler!` call (~line 245)
- BSP-LE Track 2B PIR §9.6, §12.8 — the architectural contribution of generalizing stratification.
- PAR Track 1 PIR — the topology stratum (first stratum on the base).
- `.claude/rules/on-network.md` — the design mantra that demands stratification be on-network, not imperative.
- `.claude/rules/propagator-design.md` — propagator-level design checklist.
- `.claude/rules/structural-thinking.md` — lattice lens; stratification as a module-theoretic concept.
