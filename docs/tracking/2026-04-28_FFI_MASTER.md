# FFI (Foreign Function Interface) — Series Master Tracking

**Created**: 2026-04-28
**Status**: Active
**Thesis**: Prologos as a **polyglot hub**. The FFI surface is where languages, runtimes, and substrates meet — Racket today, more languages and platforms over time. Each addition must integrate cleanly with the propagator network's information-flow discipline rather than bolting on parallel off-network bridges. When pragmatic scaffolding is necessary (e.g., procedure-shaped foreign callbacks while the on-network alternative matures), it is named as scaffolding with an explicit retirement direction tracked here.

**Origin**: surfaced 2026-04-28 from PR #33 (Posit/List marshaling) + PR #35 (lambda passing) + the EigenTrust-on-propagators effort whose blockers map directly to FFI gaps.

## Source documents

- [FFI Lambda Passing Design](2026-04-28_FFI_LAMBDA_PASSING.md) — Track 2 design doc; mantra alignment + SRE lattice lens + edge cases
- [EigenTrust-on-Propagators Pitfalls](2026-04-28_ETPROP_PITFALLS.md) — names the four "what must stay in Racket" responsibilities; PR #35 downgraded items 1-2 from required to preferred
- `racket/prologos/foreign.rkt` — current FFI implementation
- Tracking issue [#37](https://github.com/LogosLang/prologos/issues/37) — retirement of Track 2's off-network scaffolding via propagator-native callbacks

## Cross-series connections

- **PM (Propagator Migration)** — the cell-migration discipline applies to FFI: parameters become cells, off-network bridges are scaffolding marked for retirement
- **PPN (Propagator-native typing)** — the elaboration-on-network direction informs how foreign-typed values participate in the propagator network
- **OE (Optimization Enrichment)** — cost-aware FFI: tropical-quantale fuel applies to foreign call cost as much as native reduction
- **PRN (Propagator-Rewriting-Network)** — foreign calls as edges in the rewriting hypergraph; hyperlattice rewriting unifies native and foreign computation

## The polyglot hub vision

Prologos's intended position: a hub language whose lattice + propagator + dependent-type substrate provides a shared semantic foundation under multiple language frontends and execution backends. The FFI is the operational surface of this vision. Each foreign language Prologos integrates with should:

1. **Marshal values** through structurally-principled lattice-aware bridges (not ad-hoc per-type glue)
2. **Express functions** as cell handles, not procedure boundaries (long-term; procedure-shaped scaffolding accepted near-term)
3. **Track effects** through capability-typed surfaces consistent with Prologos's session-types direction
4. **Compose** with the propagator network's worldview, retraction, and stratification semantics

Track Series tracks progress toward this vision.

---

## Progress Tracker

| Track | Description | Status | Design / PR | PIR | Notes |
|-------|-------------|--------|-------------|-----|-------|
| 0 | Foundation marshaling: Nat / Int / Bool / Unit / Char / String / Rat / Path / Keyword / Passthrough / Opaque | ✅ | (pre-existing) | — | Atomic-type bridges; no compound types |
| 1 | Extended marshaling: Posit8/16/32/64 + List | ✅ | [PR #33](https://github.com/LogosLang/prologos/pull/33) (`9ef34206`) | — | NaR rejection; per-width dispatch; recursive List with namespace-qualified cons/nil; 49 unit + 14 integration tests |
| 2 | FFI lambda passing (Prologos function → Racket procedure) | 🔄 | [PR #35](https://github.com/LogosLang/prologos/pull/35) + [Design](2026-04-28_FFI_LAMBDA_PASSING.md) | — | **Off-network scaffolding by design** — labeled with explicit retirement direction. One-way only (reverse direction explicitly errors). Driving `nf` reduction from Racket procedure body. Awaiting kumavis lift-from-draft. |
| 3 | Retire Track 2 scaffolding via propagator-native callbacks (cell subscription) | ⬜ | — | — | Tracked as [#37](https://github.com/LogosLang/prologos/issues/37). Replaces procedure-shape boundary with cell-shape. Several open design questions (cell identity, multi-arg dispatch, synchronization, worldview, retraction). Gates on propagator-native infrastructure maturity. |

## Future tracks (placeholders, scope TBD)

These are forward-looking slots for FFI work that hasn't been scheduled but fits the polyglot-hub vision. Tracks get promoted to numbered/scheduled when they have a design phase started.

- **Reverse-direction lambda passing** (Racket procedure → Prologos lambda). Currently errors with a clear message in PR #35. Requires fabricating `expr-foreign-fn` at marshal time; crosses type-checked surface; needs deliberate design.
- **Compound type marshaling**: PVec, Map, Set, Sigma, custom user-defined data types. Track 1 covered List as the first compound; the SRE structural-decomposition machinery may compose with this naturally (form registry as the bridge between IR shape and FFI shape).
- **Effect-typed FFI**: capability-typed foreign declarations consistent with Prologos's session-types direction. Foreign procedures advertised with explicit capability requirements; calls type-check against caller's capability set.
- **Additional language backends**: JavaScript, Python, Wasm, native C ABI. Each requires its own marshaling layer but should reuse the FFI surface architecture.
- **Module system polyglot**: importing identifiers, types, and value-level definitions from non-Racket sources via the existing `ns` / `use` / `require` mechanism.
- **Cost-aware FFI**: tropical-quantale fuel for foreign call cost (cross-references OE).

---

## Design discipline

All FFI tracks adhere to the standard project methodology:

- **Mantra alignment** at design time per `.claude/rules/on-network.md` — challenge each scaffolding decision against the mantra; name retirement direction
- **Pipeline checklists** for new AST nodes, parameters, struct fields per `.claude/rules/pipeline.md`
- **Adversarial framing** in critique rounds per `.claude/rules/workflow.md` — explicit two-column catalogue-vs-challenge
- **Acceptance file Phase 0** per `principles/ACCEPTANCE_FILE_METHODOLOGY.org` — Level 3 (process-file) validation required before track close

## Key invariants (cross-track)

- **Marshaling is one-way unless type-checked typed-foreign-fn machinery exists** — e.g., PR #35's reverse direction explicitly errors rather than silently fabricating values
- **Off-network scaffolding gets named, scoped, retired** — every off-network FFI bridge has an issue tracking the on-network successor (Track 3 / #37 is the canonical example)
- **No belt-and-suspenders** — when a propagator-native path matures for a given FFI feature, the off-network bridge retires, not coexists. Per `.claude/rules/workflow.md`.
- **Foreign types map onto the lattice infrastructure** — bridges to non-Racket runtimes should produce values that participate in Prologos's lattice merges, not opaque blobs that bypass them. Cross-references SRE's structural decomposition discipline.

## Related documents

- `principles/EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org` — effect typing direction relevant to FFI
- `principles/PROTOCOLS_AS_TYPES.org` — capabilities and session types
- `principles/LANGUAGE_VISION.org` — broader vision the polyglot hub is part of
