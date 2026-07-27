# Bring Numeric Typing On-Network — Future PPN Note

**Status**: Implementation note for a future **PPN** track (propagator-native typing). Home: PPN series (see `docs/tracking/MASTER_ROADMAP.org` § PPN). Spawned 2026-06-30 from the Numerics track Stage-3 D.2 (§15) adjudication.
**Owner principle (verbatim)**: *"Ultimately, anything that isn't fully on-network is scaffolding."*

## The scaffolding

The Numerics track (N5) realizes refinement typing **function-level**, not on-network — because the layer it lives in is *already* function-level: `numeric-join`, generic-arithmetic typing, and subsumption are plain imperative functions in `infer`/`check` (`typing-core.rkt:186, 789-833, 2419-2428`), with zero propagators. So refinement is carried as an **erased inference-time attribute** through those imperative rules. This is correct + consistent for v1, but it is **scaffolding**: the computation flows through return values, not cells + propagators.

The earlier "refinement as a sibling meta-domain bridged via a Galois propagator" design was *rejected* not because on-network is wrong, but because it would have put **only refinement** on-network while the numeric typing *around* it stayed imperative — an isolated island that buys nothing (the auxiliary `typing-propagators.rkt` network computes facets `infer` never reads back as the authoritative type). On-network refinement only pays off when the **whole numeric-typing layer** moves together.

## The retirement (the PPN work)

Bring numeric typing on-network **as a unit**:
- `numeric-join` (the base-type LUB) → a propagator/cell computation on the type lattice.
- the refinement transfer functions (`+`/`*`/`negate`/`abs`/`/` over the Sign domain) → propagators on the refinement attribute cell.
- subsumption (base-subtype ∧ refinement-⊑) → on-network, with the F2-isolation invariant (refined types never reach `subtype-lattice-merge`) preserved structurally rather than by the function-level decomposition.

At that point the refinement attribute becomes a genuine cell (the "sibling domain" idea returns, but now justified — the neighbors are on-network too), and the Numerics-track scaffolding retires. This is part of PPN's broader "elaboration fully on-network" thesis (PPN Track 4 / propagator-native typing); numeric typing + refinement is one well-scoped slice of it.

## References
- Numerics Stage-3 design [`2026-06-30_NUMERICS_TRACK_STAGE3_DESIGN.md`](2026-06-30_NUMERICS_TRACK_STAGE3_DESIGN.md) §15 (the function-level decision + this retirement pointer); §5 (the NTT model that becomes live when this lands).
- PPN series (MASTER_ROADMAP § PPN; PPN Track 4 = cell-references-in-expressions / propagator-native typing).
- `.claude/rules/on-network.md` (the mandate); `typing-propagators.rkt` (the existing auxiliary typing network).
