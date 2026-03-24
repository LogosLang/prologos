# SRE Track 1: Relation-Parameterized Structural Decomposition — PIR

**Date**: 2026-03-23
**Track**: SRE Track 1
**Design Doc**: [SRE Track 1 Design](2026-03-23_SRE_TRACK1_RELATION_PARAMETERIZED_DECOMPOSITION_DESIGN.md)
**Series**: [SRE Master](2026-03-22_SRE_MASTER.md)
**Prior PIR**: [SRE Track 0 PIR](2026-03-22_SRE_TRACK0_PIR.md)

## §1. Stated Objectives

Extend the SRE from equality-only structural decomposition to handle three
relations: equality (symmetric merge), subtyping (directional check with
variance-driven decomposition), and duality (constructor pairing with
involution). Make subtyping and duality first-class for all types, including
user-defined types via polarity inference. Unify three separate mechanisms
(`unify` via SRE, `subtype?` as flat predicate, `dual` as recursive function)
into one relation-parameterized SRE.

## §2. What Was Delivered

**Files created**: 2
- `subtype-predicate.rkt`: Extracted flat subtype predicate + subtype-lattice-merge + SRE structural subtype check (query pattern)
- `tests/test-sre-duality.rkt`: 9 duality tests

**Files modified**: 6
- `sre-core.rkt`: +sre-relation struct, 5 built-in relations, subtype/duality propagators, duality decompose-dual-pair, variance-join/flip, ~200 lines added
- `ctor-registry.rkt`: +component-variances + binder-open-fn on ctor-desc, 12 type variance annotations, 5 session constructor registrations, session-lattice-spec sentinel
- `propagator.rkt`: decomp-key + decomp-key-hash accept optional relation name
- `unify.rkt`: type-sre-domain updated with top-value + subtype-merge
- `session-propagators.rkt`: duality propagator delegated to SRE
- `typing-core.rkt`: subtype? + type-key extracted to subtype-predicate.rkt

**Tests**: 31 new (22 subtype + 9 duality), 1 updated (reflexive subtype semantics), 1 updated (ctor-desc count 21→26). 7393 total tests pass.

**Commits**: 10 (Phase 1a/1b, Phase 2, Phase 2b, Phase 3, Phase 3 fix, Phase 4, Phase 4 fix, Phase 5, dailies×2)

## §3. What Went Well

1. **Design-to-implementation ratio**: 4 critique rounds (D.1→D.4) before coding. Zero architectural surprises during implementation. Each phase was straightforward because the design handled the hard questions upfront.

2. **Principles-First Design Gate caught a violation during implementation**: The user identified `flat-subtype?` as an off-network escape hatch (violating Propagator-First). This was caught DURING Phase 2, not in a post-hoc review. The gate works at all decision points, not just design-time.

3. **Second domain validation**: Session duality (Phase 5) was a drop-in replacement — all 21 session tests passed with zero changes. This validates that the SRE abstraction boundary (domain-parameterized, relation-parameterized) is correct.

4. **Completeness revision (D.2)**: The user caught 4 deferrals that were Completeness violations. User-defined structural subtyping, dependent session duality, transitivity, and cache correctness were all incorporated before coding. This prevented "we'll fix it later" debt.

## §4. What Went Wrong

1. **Type lattice merge ≠ subtype ordering**: The initial subtype propagator used `merge(a,b) = b` to check `a ≤ b`. But the type lattice is equality-ordered (flat: `merge(Nat, Int) = top`), not subtype-ordered. This caused ALL structural subtype tests to fail initially. Required discovering the fundamental insight: two lattice orderings on the same carrier need separate merge functions.

2. **Duality decomposition is asymmetric**: `sre-decompose-generic` assumes both sides have the same constructor tag. Duality has different tags (Send vs Recv). Required a dedicated `sre-duality-decompose-dual-pair` function. Not predicted by the design (which focused on sub-relation derivation, not decomposition mechanics).

3. **Don't pre-write dual values**: The skeleton approach (write `Recv(bot, bot)` to initialize the target cell) failed because `bot` is domain-specific — session-domain bot in a type-lattice position causes contradictions. The fix: don't pre-write, let sub-cell propagators + reconstructors build the correct value.

4. **Circular dependency**: `session-lattice.rkt` creates a transitive cycle through `type-lattice → reduction → ... → ctor-registry`. Required using a symbol sentinel (`'session`) instead of a concrete `lattice-spec` struct. Same pattern as `'type` for type-lattice.

5. **Reflexive subtype semantics change**: `subtype?` was previously strict (a <: b only if a ≠ b) because it was only called after equality failed. Adding the `equal?` fast path made it reflexive (standard preorder semantics). One existing test expected the old strict behavior. Small fix but a behavioral change.

## §5. Key Design Decisions

1. **Separate merge functions per relation** (not one lattice for everything). The type domain has equality-merge (flat) and subtype-merge (partially ordered). The relation selects which merge to use. This is the "correct lattice for the correct relation" principle.

2. **Derive duality sub-relations from component lattice types** (D.3). No `component-sub-relations` field on ctor-desc. `'type` sentinel = cross-domain → equality. `'session` sentinel = same-domain → duality. Keeps ctor-desc lean.

3. **Query pattern for subtype integration** (Phase 4). Mini-network per compound check. GC'd after use. Frequency counter for monitoring. Correct but may need persistent network if Track 2 makes checks frequent.

4. **top-value on sre-domain** (Phase 3). Relation violations (wrong dual pairing) can't always be signaled via lattice-merge (same-tag values merge cleanly). Explicit contradiction value needed.

5. **`subtype?` extraction to break circular dependency** (Phase 2b). Clean module boundary: `subtype-predicate.rkt` depends only on `syntax.rkt`, `macros.rkt`, `type-lattice.rkt`. Both `unify.rkt` and `typing-core.rkt` import without cycles.

## §6. Performance

- **Baseline**: 7358 tests, 236.7s (SRE Track 0 final)
- **Final**: 7392 tests (+34), 243.9s (+3.0%)
- **Expectation**: ≤ 245s (< 4% increase) ✅ MET (243.9s = 3.0%)
- **No structural subtype checks triggered in existing suite**: The existing test suite doesn't have compound subtype checks (PVec Nat <: PVec Int). The query pattern overhead is zero for the existing codebase.
- **Session duality overhead**: The SRE duality propagator replaces two simple `(dual v)` propagators with one structural propagator. For simple sessions (Send/Recv with no nesting), the overhead is minimal (one propagator instead of two, but with SRE dispatch overhead). For nested sessions, the SRE correctly decomposes structurally — the old approach applied `dual` recursively in one shot, the new approach decomposes into sub-cells and propagates. Performance should be equivalent for current test cases.

## §7. Architecture Assessment

**ctor-desc field count**: 10 (tag, arity, recognizer, extract, reconstruct, component-lattices, binder-depth, domain, component-variances, binder-open-fn). At the D.2 critique threshold. If Track 2 adds more, factor into core + capabilities.

**sre-domain field count**: 10 (name, lattice-merge, contradicts?, bot?, bot-value, meta-recognizer, meta-resolver, dual-pairs, top-value, subtype-merge). Also at 10. Both structs have grown through Track 0 and Track 1. Monitor.

**sre-core.rkt size**: ~550 lines (up from ~325 after Track 0). Still manageable. The duality propagator is the largest addition (~150 lines including helpers). If Track 2 adds more relation types, consider splitting relation-specific code into separate modules.

**NTT-Racket isomorphism**: CONFIRMED at Track 1 level. `#:relation` maps to NTT relation-parameterized structural decomposition. `subtype-merge` IS the NTT's subtype lattice. `dual-pairs` IS the NTT's `:dual-pairs`. Session constructors in ctor-registry ARE the NTT's structural lattice registration. The Racket implementation and the NTT syntax describe the same architecture.

## §8. What's Next

1. **SRE Track 2 (Elaborator-on-SRE)**: The big payoff. Each typing-core case becomes `structural-relate(type-cell, Form(sub-cells))`. Track 1 provides the relation infrastructure; Track 2 uses it to replace manual propagator wiring in the elaborator.

2. **Dependent session duality**: DSend/DRecv have binder-depth=1 but `binder-open-fn` is not yet implemented. The SRE correctly falls through to the caller for binder-depth>0. Implementing `sre-decompose-binder` would complete dependent duality and also enable Pi/Sigma binder decomposition on the SRE (currently handled by PUnify dispatch).

3. **Polarity inference integration**: The `variance-join`/`variance-flip` utilities exist but aren't wired into `data` elaboration yet. User-defined types currently get `#f` variance (no structural subtyping). Integration into the elaboration pipeline is Track 2 scope.

4. **Persistent subtype network**: If Track 2 makes subtype checks frequent, the query pattern (mini-network per check) may become a bottleneck. Monitor `current-subtype-check-count` and evaluate persistent network if compound checks > 1000 per suite.

## §9. Bugs Found and Fixed

1. **Type lattice merge ≠ subtype ordering** (Phase 2): `merge(Nat, Int) = top` in equality lattice. Required `subtype-lattice-merge` with proper subtype ordering.
2. **Circular dependency** (Phase 2b): `unify.rkt` → `typing-core.rkt` cycle. Resolved by extracting `subtype-predicate.rkt`.
3. **Duality pre-write creates cross-domain bot** (Phase 3): Skeleton `Recv(sess-bot, sess-bot)` puts session-domain bot in type-lattice position. Fix: don't pre-write, decompose directly.
4. **ctor-registry test count** (Phase 3): Expected 21 descs, actual 26 after session registration.
5. **Reflexive subtype semantics** (Phase 4): `subtype?(Int, Int)` now returns `#t`. Test updated.
6. **Binder-depth blocked Pi decomposition** (Phase 6): Pi has binder-depth=1, and `sre-maybe-decompose` fell through for binder-depth>0. For subtype/duality on ground types, binder opening is irrelevant — extract components directly. Caused 7 eliminator test failures (wrong codomain types passed subtype check because inner Pi decomposition was blocked). Fix: non-equality relations bypass binder-depth check (`dc796fb`).

## §10. Lessons Distilled

1. **"Correct lattice for the correct relation"** — two orderings on the same carrier need separate merge functions. The equality lattice is flat; the subtype lattice is partially ordered. The relation selects which merge to use. This is a specific instance of Decomplection: don't braid two orderings into one lattice.

2. **"Duality decomposition is fundamentally asymmetric"** — equality decomposition can share descriptors (both sides have the same tag). Duality requires per-side descriptors. This asymmetry wasn't predicted by the design (which focused on sub-relation derivation). Future relation types should examine decomposition mechanics, not just sub-cell semantics.

3. **"Don't pre-write partially-constructed values"** — skeletons with bot sub-components fail when components span domains. Let propagators build values from sub-cells. This is the Propagator-First principle applied to initialization: the network should construct values, not imperative pre-writes.

4. **"The Principles Gate works during implementation"** — the `flat-subtype?` violation was caught by the user asking "is this off-network?" during Phase 2, not in a post-hoc review. Scanning for principles violations at all decision points (design, implementation, review) catches issues before they compound.

5. **"Symbol sentinels for cross-module lattice identity"** — `'type` and `'session` sentinels avoid circular dependencies while providing domain identity for sub-relation derivation. Pattern: when a concrete import creates a cycle, use a sentinel symbol resolved at call time.

## §11. Key Files

| File | Role | Lines changed |
|------|------|---------------|
| `sre-core.rkt` | Relation structs, subtype/duality propagators | +200 |
| `ctor-registry.rkt` | Variance annotations, session constructors | +80 |
| `subtype-predicate.rkt` | Extracted predicate + subtype-merge + query pattern | +95 (new) |
| `session-propagators.rkt` | SRE duality delegation | +30, -24 |
| `propagator.rkt` | Relation-aware decomp key | +10 |
| `unify.rkt` | Domain spec updates | +5 |
| `typing-core.rkt` | subtype? extraction | -30 |
| `tests/test-sre-subtype.rkt` | 22 structural subtype tests | +170 (new) |
| `tests/test-sre-duality.rkt` | 9 duality tests | +130 (new) |
