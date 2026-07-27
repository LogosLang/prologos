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

**UNIFIED onto the generalized mechanism (PPN 4C 2B, 2026-05-20).** These strata originally predated `register-stratum-handler!` and were invoked sequentially from `run-stratified-resolution!`. That loop is RETIRED (it was confirmed dead code per PM Track 8 A5 + R3 external critique, 2026-04-18 — zero production callers); the strata now run as uniform BSP stratum handlers. See `docs/tracking/principles/DESIGN_PRINCIPLES.org` § "Stratified Propagator Networks" for design framing.

| Stratum | Kind | Introduced | Mechanism (current) | Purpose |
|---|---|---|---|---|
| **S(-1) Retraction** | non-monotone narrowing | PM Track 7 Phase 5; unified PPN 4C 2B (2026-05-20) | `process-retraction` registered via `register-stratum-handler!` on the retraction request cell (cell-13 writes via pure `record-assumption-retraction`) | Clean scoped cell entries for retracted assumptions; assumptions set can only shrink |
| **L1 Readiness** | readiness scan for constraints | PM Track 2 Phase 4 | `collect-ready-constraints-via-cells` (pure scan, observation only) feeding the resolution handler's request cell (cell-14) | Identify constraints whose dependencies are now ground → produce action descriptors |
| **L2 Resolution** | non-monotone action interpreter | PM Track 2 Phase 4; unified PPN 4C 2B (2026-05-20) | `process-resolution` registered via `register-stratum-handler!` on the resolution request cell | Trait lookup, instance commitment, unification retry — mutating commitments |
| **Stratum 3 (verification)** | session/effect verification (planned/referenced) | Architecture A+D (effect-executor.rkt:53-54) | COMMENT-ONLY — referenced in comments; no realization exists | Ordering verification for effectful computation |

### The generalization gap (largely closed 2026-05-20)

- **S0 + Topology + S1 NAF + S(-1) + L2** all use the BSP scheduler's general outer loop via `register-stratum-handler!` (8 production registration sites across elaborator-network.rkt, metavar-store.rkt, narrowing.rkt, relations.rkt, propagator.rkt, typing-propagators.rkt).
- **Stratum 3** is referenced in design but not realized at all (comment-only at effect-executor.rkt:53-54) — any design that "hands off to Stratum 3" (e.g., PReduce Track 7) is designing against an unbuilt boundary and must say so.

(Amended 2026-06-10, PReduce SM4 F3a: the legacy `register-topology-handler!` box was
RETIRED 2026-04-16 — topology handlers are `register-stratum-handler! #:tier 'topology`
(propagator.rkt:3153-3159, :3193-3197). The earlier "kept separate" note was stale.)

**Tier vocabulary (2026-06-10, normative)**: handlers register with `#:tier 'value` or
`#:tier 'topology`; "strata" in claim-counting contexts means rule-DISPATCH strata (S0,
S(-1)); other handlers are tier-ordered INSTANCES of existing kinds. The PReduce Track 0.1
stratum-assignment table (D.1 §5.1) is the worked normative example — this file + that
table are the single source for stratum semantics; series masters carry claims + pointers
only. CAUTION (verified 2026-06-10): handler ordering is silent registration append-order
(propagator.rkt:3213) and the process-tier window auto-resets request cells unconditionally
(:3466-3468) — an explicit `#:after` declaration + keep-pending idiom are REQUIRED substrate
work before any order-sensitive handler pair lands (PReduce Track 1/5).

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
- **Cost-bounded exploration** — **DISSOLVED 2026-06-10 (PReduce SM4 F3b)**: realized at
  the CELL layer by PPN 4C Phase 1B (fuel `#:on-write-check` writes contradiction
  structurally, propagator.rkt:1083/:1898-1953; "no separate threshold propagator" per
  D.4); pruning = the existing contradiction → nogood → worldview-narrowing machinery.
  Not a stratum, by this file's own admission test.
- **Constraint activation levels**: constraint propagators that fire only when their dependencies reach a readiness threshold. Currently ad-hoc; could be a stratum.
- **Self-hosted compiler passes**: each pass (parsing, type inference, code generation) is stratum-separable. Running them as BSP strata on the same base gives incremental-compilation for free via cell persistence.

### Unification work (architectural follow-ups)

1. **Topology handler → general strata list** (small): replace `register-topology-handler!` with `register-stratum-handler!` using a reserved topology request-cell-id. Remove the legacy `topology-handlers` box and special-cased BSP iteration. Functional equivalence; removes an inconsistency.

2. **Elaborator strata (S(-1), L1, L2) → BSP scheduler strata** — ✅ DONE (PPN 4C 2B, 2026-05-20): `run-retraction-stratum!` and `run-stratified-resolution!` retired; S(-1) lives as `process-retraction`, L2 as `process-resolution`, both registered via `register-stratum-handler!`. Single orchestration mechanism across solver and elaborator achieved.

3. **Stratum 3 (verification)** — referenced in `effect-executor.rkt` but not fully realized. Future Architecture AD continuation work.

## References

### Solver network (BSP scheduler strata)

(Coordinates re-verified 2026-06-10; they drift — re-grep before trusting.)

- `racket/prologos/propagator.rkt`:
  - `stratum-handlers` box (~line 3176)
  - `register-stratum-handler!` (~line 3193)
  - `topology-handlers` box + `register-topology-handler!` (legacy)
- `racket/prologos/relations.rkt`:
  - S1 NAF handler `process-naf-request` + `register-stratum-handler!` call (~line 246)

### Elaborator network (unified BSP stratum handlers since PPN 4C 2B, 2026-05-20)
- `racket/prologos/metavar-store.rkt`:
  - S(-1) Retraction: `process-retraction` (~line 1600), registered at ~line 1617 on `retraction-stratum-request-cell-id`; pure `record-assumption-retraction` writes requests to cell-13
  - L1 Readiness: `collect-ready-constraints-via-cells` (pure scan)
  - L2 Resolution: `process-resolution`, registered at ~line 1677 on `resolution-stratum-request-cell-id`
  - `run-retraction-stratum!` and `run-stratified-resolution!`: RETIRED (do not cite)
- `racket/prologos/effect-executor.rkt:53-54`: Stratum 3 (verification) — COMMENT-ONLY, not realized

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
