# PM Track 13 — Implementation Note (Stage 0)
# Stratum-Handler Mechanism + Scheduler State as On-Network Cells

**Date**: 2026-05-20
**Stage**: 0 — Pre-research SEED note. Concern captured during PPN 4C Addendum Phase 2A.b mini-design dialogue (2026-05-20).
**Status**: ⬜ Pending Stage 0/1 research conversation + Stage 2 audit + Stage 3 design cycle before implementation can begin.
**Originating dialogue**: [PPN 4C Addendum D.3 §8.7.b mini-design](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — Q1-Q4 + adversarial principles framework surfaced two levels of handler-as-scaffolding concern.

---

## §1 The concern (as articulated in dialogue)

User direction 2026-05-20 during 2A.b mini-design:

> *"I'm concerned about the handler approach, in general. I believe there are some design lessons that apply to red-flags to handlers/scaffolding hiding behavior. The side-effecting nature of them are a concern. I don't know if it's a silly idea or not — or whether it's a larger concern of its own phase — to think about a specialized cell, similar to our tropical quantale cell; that would be a scheduler registry cell that tracks stratum transitions/state? ... I'm starting to think of the propagator networks and scheduler more properly as compiler technology in their own right. So scheduler registries would fit into this conceptual framework."*

And the load-bearing operational principle that crystallized:

> *"Anything that is not 'on-network' is scaffolding."*

This is the mantra in its sharpest form. It is the operational definition of scaffolding: **off-network ≡ scaffolding**. Every off-network mechanism is by definition a candidate for retirement, with an explicit retirement plan attached.

## §2 The compiler-technology framing

Propagator networks + scheduler are not merely a runtime; they are **compiler technology in their own right**. The `.pnet` serialization (SH Series Track 1) demonstrates this: networks are first-class IR; the scheduler is the interpreter; specialized cell type framework (§4.6 from PPN 4C Tropical Quantale Addendum) is IR vocabulary.

Under this framing:
- **Cells = IR storage primitives** with declared semantics (`:tier` + `:storage` + `:fires-on` + `:on-write-check` etc.)
- **Propagators = IR computation primitives** with declared firing patterns
- **Scheduler = IR interpreter** that dispatches propagators against cells per their declarations
- **Scheduler state itself** (worklist, stratum-handler registry, fuel counter, worldview cache) = network-resident IR with its own specialized cell categories (per §10.3.A taxonomy: scheduler-state cells are a third category alongside propagator-state and topology-state)

The tropical-fuel cell is the first cleanly-realized scheduler-state cell. The stratum-handler registry (`stratum-handlers` box at propagator.rkt:2827) is the next natural candidate.

## §3 What's currently off-network (the scope this track addresses)

### §3.1 The stratum-handler registry (PRIMARY scope)

**Location**: [`propagator.rkt:2827`](../../racket/prologos/propagator.rkt) — `(define stratum-handlers (box '()))`

**Current shape**:
- Racket box of list-of-handler-entries
- Each entry: `(list request-cell-id handler-fn tier reset-value)`
- Populated imperatively at module-load time via `register-stratum-handler!` calls
- Read by BSP outer-loop's value/topology tier processing (line 3061)

**Affected handlers** (7+ registered as of 2A.a):
| Handler | Tier | Body shape | Source |
|---|---|---|---|
| `constraint-propagators-topology` handler | topology | Side-effects (cell allocations) | propagator.rkt:2849 |
| `elaborator-topology` handler | topology | Side-effects | (callback-style registration) |
| `narrowing-topology` handler | topology | Side-effects | (callback-style registration) |
| `sre-topology` handler | topology | Side-effects | (callback-style registration) |
| `process-naf-request` | value | Pure on prop-net (forks main-net + writes nogood) | relations.rkt:116 |
| classify-inhabit handler | value | Side-effects (residuation) | typing-propagators.rkt |
| `process-retraction` (PPN 4C 2A.a) | value | Pure on prop-net (scoped cells) | metavar-store.rkt |
| `process-resolution` (proposed 2A.b) | value | Side-effects (box-bridge to enet) | metavar-store.rkt |

### §3.2 Handler invocation mechanism (deeper scope)

The BSP outer-loop reads the registry box, then invokes handler functions imperatively. The handler is a Racket procedure invoked at quiescence boundaries.

Under the compiler-technology framing, this is two distinct concerns:
- (a) **Registry on-network**: replace box with specialized scheduler-state cell. Functional cell-write registers a handler; cell-read iterates handlers.
- (b) **Handler-as-data**: encode the handler's TRANSITION RELATION declaratively (cell + propagator structure that the scheduler interprets), not as an opaque Racket function. This is significantly deeper — moves toward "stratum transitions ARE network values."

(a) is a smaller refactor. (b) is foundational redesign.

### §3.3 Handler body side-effects (independent concern)

Many handler bodies touch off-network state (`current-prop-net-box`, `current-resolution-executor-pure`, `set-box!` on elab-net struct). This is a SEPARATE concern from the registry/mechanism concern. Body side-effects retire when their off-network dependencies retire — PPN 4C Parent Phase 4 (CHAMP→cell) + PM Track 12 (parameters→cells).

PM 13's scope is the REGISTRY + MECHANISM. Body side-effects ride retirements in PM 12 + Parent Phase 4.

## §4 Why this fits PM Track 13 (compiler-technology framing)

The Propagator Migration series moves "every piece of state that participates in compilation onto the propagator network." Tracks 1-12 have addressed:
- Constraint tracking, registries, ATMS, env, dep-edges (Tracks 1-5)
- Unification, reduction promoted to PReduce, module loading, params→cells (Tracks 8-12)

Scheduler state is the NEXT FRONTIER. Tropical-fuel cell (PPN 4C Phase 1) established the precedent for scheduler-state cells. PM 13 generalizes: ALL scheduler state on-network.

**Adjacent tracks** (sequencing dependencies):
- **PM Track 12** (parameters → cells for module loading) — provides the cell-space scope primitive PM 13 might need for the handler registry
- **PPN 4C Parent Phase 4** (CHAMP retirement) — independent; addresses handler BODY side-effects, not registry
- **SH Series Track 1** (`.pnet` network-as-value) — PM 13's specialized scheduler-state cells become part of `.pnet` IR vocabulary

## §5 Research questions (for Stage 0/1)

### §5.1 Core architectural questions

1. **Is the handler registry truly scheduler-state**, or is it topology-state? Stratum handlers describe BSP outer-loop iteration behavior. Migration: scheduler-state. But registering a handler ADDS computation to the network (analogous to adding a propagator). Topology framing might be more accurate.

2. **What's the right cell category for the registry?** Candidates from §10.3.A taxonomy:
   - scheduler-state (written by scheduler/configuration, read at iteration time)
   - topology-state (written by topology stratum, read at next BSP round)
   - propagator-state (written by propagators during fires) — probably wrong; registration isn't fire-driven

3. **Scope semantics**: should the registry be PER-NETWORK (each prop-net has its own handlers) or NETWORK-WIDE (one registry for all networks)?
   - Current: network-wide (one Racket box; all networks share)
   - Cell-based per-network: each network would need handler initialization
   - Cell-based network-wide: requires a "global" scope which conflicts with prop-net isolation
   - PM Track 12's submodule-scope primitive may provide the answer (handlers registered at module scope; networks inherit via scope chain)

4. **Handler representation**: keep as Racket function value in cell, OR represent declaratively (cell+propagator structure that encodes the transition)?
   - Option α: handler-as-procedure in cell (registry on-network; body still imperative) — small refactor
   - Option β: handler-as-data (transitions encoded as cell+propagator graphs the scheduler interprets) — foundational redesign; moves toward NTT vision
   - Option α is incremental; Option β is the deeper compiler-technology framing

5. **Interaction with `.pnet` serialization (SH Series Track 1)**: handlers in cells must serialize/deserialize across `.pnet` round-trip. Function values in cells = opaque (closures don't serialize); transition-data = serializable. Option β aligns with SH; Option α complicates.

### §5.2 Related architectural concerns

6. **Worklist as cell**: the BSP scheduler maintains a worklist (off-network, in `prop-net-warm` struct field). Is this also a scheduler-state cell migration target?

7. **Worldview-cache as cell**: ALREADY on-network (cell-id 1) via BSP-LE Track 2's worldview-cache-cell-id. Precedent for the pattern.

8. **Fuel-cost / fuel-budget as cells**: ALREADY on-network via Tropical Quantale Addendum Phase 1B. Specialized cell type framework prior art.

The pattern: scheduler-state migrates piecemeal. PM 13 adds the handler registry.

### §5.3 Cross-track research inputs

9. **PReduce Series Track 1** (e-class cell substrate) — declares cells with `:storage 'e-class`. Cross-track precedent for new specialized cell categories.

10. **NTT (Network Type Theory)** — types for cells + propagators + bridges + stratification. The `:fiber` annotation in NTT §7 expresses stratification declaratively. PM 13 may be the implementation target for NTT's stratification syntax.

11. **Categorical foundations** (per [`docs/research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md`](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md)) — Grothendieck fibrations over stratum posets formalize "scheduler invokes computation per stratum." PM 13's design should align with this framework.

## §6 Forward pointers (what PM 13 enables / consumes)

### §6.1 Downstream consumers

- **SH Series Track 1**: `.pnet` IR includes scheduler-state cells. PM 13's cell type for the handler registry becomes part of the serializable IR.
- **SH Series Track 4**: production LLVM substrate. Scheduler-state cells lower to LLVM as native data structures. Handlers as data (Option β) lower more cleanly than handlers as opaque procedures.
- **PReduce Series Tracks 1+5**: e-class extraction depends on cost-bounded scheduling. PM 13's scheduler-state cell pattern is precedent for PReduce's cost-extraction stratum.
- **PPN Track 4D** (Attribute Grammar Substrate Unification): handler-as-data framing aligns with declarative grammar rules. Possibly PM 13 + 4D converge.

### §6.2 Cross-cutting principle codifications

- **"Off-network ≡ scaffolding"** — operational definition; codification candidate for [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md) after PM 13 lands (operational principle has been observed across PPN 4C + PM 12 + PReduce; PM 13's research synthesis can codify it).
- **Specialized scheduler-state cell category** — third category in §10.3.A taxonomy alongside propagator-state and topology-state. PM 13 establishes when each is appropriate.

## §7 Status (2026-05-20)

- ⬜ Stage 0 — concern captured (this note)
- ⬜ Stage 1 — research conversation + literature review
- ⬜ Stage 2 — codebase audit (current `stratum-handlers` callers + handler shapes + scope analysis)
- ⬜ Stage 3 — design iteration
- ⬜ Stage 4 — implementation
- ⬜ Stage 5 — composition + PIR

**Gating signals to start Stage 1**:
- PPN 4C Addendum complete (so we have a clear picture of all handlers in production)
- PM Track 12 design at least Stage 2 (so we know scope-primitive semantics)
- SH Series Track 1 design active OR research-stage (so `.pnet` IR constraints inform cell representation)

**Anti-gating signals** (reasons to NOT pursue PM 13):
- If NTT design absorbs the stratification syntax problem, PM 13 may dissolve into NTT implementation
- If Parent Phase 4 + PM 12 already migrate ALL handler body concerns, the "handler-as-scaffolding" intuition may be met without registry migration (handlers become pure; registry box becomes a non-issue)

## §8 References

### §8.1 Originating dialogue
- [PPN 4C Addendum D.3 §8.7.b](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — 2A.b mini-design + Q1-Q4 (where this concern was surfaced)
- 2026-05-20 dailies entry: PM 13 capture conversation

### §8.2 Architectural precedents
- [DESIGN_PRINCIPLES.org § Cell / Propagator / Scheduler Orthogonality](principles/DESIGN_PRINCIPLES.org) — §10.3.A taxonomy (propagator-state / scheduler-state / topology-state cell categories)
- [DESIGN_PRINCIPLES.org § Specialized Cell Type Framework as Cross-Track Template](principles/DESIGN_PRINCIPLES.org) — §4.6 framework codified during PPN 4C Phase 1
- [PPN 4C Tropical Quantale Addendum D.4 §4.6](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — specialized cell type framework canonical source
- [PPN 4C Tropical Quantale Addendum PIR §1 Delivery 2](2026-05-17_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_PIR.md) — unforeseen cross-track template delivery

### §8.3 Affected sites (Stage 2 audit candidates)
- `propagator.rkt:2827` — `stratum-handlers` box (PRIMARY scope)
- `propagator.rkt:2829` — `register-stratum-handler!` (write API)
- `propagator.rkt:3061` — BSP outer-loop's reader site
- `propagator.rkt:2849` — constraint-propagators-topology handler registration
- `relations.rkt:246` — `process-naf-request` registration
- `metavar-store.rkt` post-2A.a — `process-retraction` registration
- `metavar-store.rkt` post-2A.b — `process-resolution` registration (if 2A.b lands first)
- `typing-propagators.rkt` — classify-inhabit handler registration
- `elab-network-types.rkt` or similar — 3 other topology handler registrations (audit needed)

### §8.4 Related research
- [Categorical Foundations of Typed Propagator Networks (2026-03-22)](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md)
- [Hypercube BSP-LE Design Addendum (2026-04-08)](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)
- [Self-Hosting Path + Bootstrap Stages (2026-04-30)](../research/2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md)
- [Propagator Network as Super-Optimizing Compiler (2026-04-30)](../research/2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md)

### §8.5 Cross-track relationships
- PM Track 12 — parameter→cell migration; provides scope primitive
- PPN 4C Parent Phase 4 — CHAMP retirement; addresses handler body side-effects
- SH Series Track 1 — `.pnet` IR; consumes PM 13's cell types
- NTT — stratification syntax; may absorb PM 13's design

---

**This is a Stage 0 SEED note. Do not implement without Stage 1/2/3 cycle.**

---

## §9 Cross-track input from PPN 4C Addendum Phase 4B.5 (2026-06-10)

4B.5's mechanism fork deferred the **on-network deferred-typing** design ("(iii)") with PM Track 13's mnr↔elab unification as one of its three prerequisites — the NET-1↔NET-2 crossing must dissolve (one network) or be bridged (NTT §17b) before a NET-2 typing propagator can `:reads` a NET-1 `def-entry` cell. **The full design capture lives in the PM Track 12B note §10** (`2026-06-06_PM_TRACK12B_FREE_ORDERING_ON_NETWORK.md`) — including the non-discard-reset facts PM 13 work must build against (the live discard is `reset-meta-store!` with 8 sites + a dual context gate; the dormant `reset-elab-network-command-state` template is broken at HEAD; stale-dependents/`next-prop-id` collision + pair-decomps-clearing + infra-cell-id churn hazards). When PM 13 opens, read 12B §10 alongside §3 of this note.

