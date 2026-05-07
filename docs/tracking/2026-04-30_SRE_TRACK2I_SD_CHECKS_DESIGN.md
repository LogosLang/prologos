# SRE Track 2I: SD∨ / SD∧ Algebraic-Property Checks — Stage 3 Design (light)

**Date**: 2026-04-30
**Series**: [SRE (Structural Reasoning Engine)](2026-03-22_SRE_MASTER.md)
**Prerequisite**: [SRE Track 2G ✅](2026-03-30_SRE_TRACK2G_DESIGN.md) (Algebraic Domain Awareness — property inference, registry, implication rules)
**Source research**: [Lattice Variety and Canonical Form for SRE](../research/2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) §5.4 (the "smallest concrete near-term move" identification)
**Free-Lattices anchor**: Freese-Nation Theorem 1.21 (Jónsson-Kiefer 1962); see [companion ch01 §3](../learning/freelat-companion-ch01.html#s3)

**Stage 3 weight**: *light*. No formal P/R/M/S critique rounds (per user direction 2026-04-30: scope too small to warrant the full critique cycle; mini-design + mini-audit performed conversationally per phase, persisted into this doc as Stage 4 progresses). This doc is the persistence target for those mini-design/mini-audit outcomes.

**Acceptance file**: *deviation from the workflow.md "Acceptance file as Phase 0" rule*. Per user direction 2026-04-30: scope too small for an acceptance file. The track adds two test functions to `sre-core.rkt` and exercises them empirically; no user-facing language change, no `.prologos`-level behavior change, no risk of WS-mode regression. The existing `tests/test-sre-algebraic.rkt` test surface plus the new `tests/test-sre-sd-properties.rkt` (Phase T) cover regression. Justification recorded here per the workflow rule's spirit (track-level rationale rather than per-phase).

---

## Thesis

**Original (Phases 1-4)**: Add SD∨ and SD∧ as first-class algebraic-property checks in the SRE registry, parallel to the existing `commutative-join` / `associative-join` / `idempotent-join` / `distributive` machinery (`sre-core.rkt:262-322`). Implication rule `distributive ⇒ sd-vee ∧ sd-wedge` lets the two confirmed-Heyting domains inherit SD trivially; empirical sweep on the non-distributive-yet domains yields *information* — either confirms SD-but-not-distributive or surfaces counterexample triples.

**Extended (Phases 5-10, scope expansion 2026-04-30 post-Phase-4)**: Comprehensive empirical lattice-variety categorization across all SRE-registered domains, culminating in a presentation-quality research document suitable for sharing with Prof. J.B. Nation (Freese-Ježek-Nation 1995 *Free Lattices*). Adds the algebraic properties most relevant to both technical utility and theoretic value: pseudo-complement (Heyting →), Whitman's W (free-lattice membership), modularity, breadth bound (Jónsson-Kiefer-Nation 1962), with conditional follow-ons (Stone identity, sectional complement). Sweeps extended to session and form domains via per-domain generator extensions. The closing report is a Stage 0/1 research artifact cross-linked from PTF master.

This is the smallest concrete move toward variety identification per [LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md §5.4](../research/2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md). It does NOT commit to canonical-form ALGORITHMS in implementation (Whitman six-case dispatch, Reading-Speyer-Thomas, etc.), and NOT commit to UCS dispatch by variety. It establishes EMPIRICAL CHARACTERIZATION of where each domain sits — the data that any future variety-driven dispatch would be grounded in.

**Motivating context**: pseudo-complement and semi-complement checks arose from in-person conversation with Prof. Nation. The closing report is intended for the next meeting — a tangible, honest characterization of where Prologos's lattice structures live and what's open. Nation's *Free Lattices* monograph is the canonical reference; we cite Theorem 1.21 (his SD theorem with Jónsson-Kiefer 1962) and Theorem 1.17 (canonical form) directly. The extension respects his expertise: emphasis on what we can demonstrate, not pedagogy.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 1 | `test-sd-vee` + `test-sd-wedge` in sre-core.rkt; wire into inference + reporting; implication rules for distributive⇒SD | ✅ | `a35d5f65`. 99 LoC sre-core.rkt + 71 LoC test-sre-algebraic.rkt. 42 tests pass via targeted runner. VAG passed adversarially. |
| 2 | Programmatic sample generator from ctor-desc registry + sd-evidence struct + `/detailed` variants | ✅ | `f241e14e`. New file `sre-sample-generator.rkt` (~120 LoC) + sre-core.rkt enrichment (~80 LoC, sd-evidence struct + /detailed variants + backward-compat wrappers) + 11 new tests. 53 tests pass via targeted runner. VAG passed adversarially with two acknowledged Phase-3 gaps (sample-size verification, binder-ctor coverage). API note: `all-ctor-descs` takes `#:domain` keyword (not positional) — caught at compile time. |
| 2a | Principled-fix corrective: per-component-spec generation (Option C), drop `with-handlers`, include binder ctors with closed-body limitation | ✅ | `1c0c012e`. Generator refactored: per-component-spec atom pools, sentinel filter, binders included. **Bonus discovery**: Phase 2's `with-handlers` was masking malformed compounds (bot/top in component slots → reconstruct produces invalid `(expr-Pi mw type-top type-top)`-shape values that merge can't handle). Two-pool model (lattice elements vs structural components) surfaces and fixes it. 58 tests pass. VAG passed adversarially with the masked-issue surfacing as the Move B+ pattern's intended payoff. Codebase-wide audit of remaining 72 `with-handlers` instances filed as [issue #40](https://github.com/LogosLang/prologos/issues/40). |
| 3c | Per-relation `meet-registry` on sre-domain; retire `current-lattice-subtype-fn` callback; principled subtype-meet dispatch | ✅ | `d4e8c811`. User-flagged 2026-04-30 as principled cleanup. `meet-registry` field added to sre-domain; `type-meet-registry` registered in unify.rkt; `type-lattice-meet` refactored with `#:subtype-fn` keyword; callback retired; lint baseline updated; `type-pseudo-complement` updated to use explicit subtype-fn. **Bonus discovery**: Track 2G's "type lattice not distributive under equality merge" finding was an artifact of the always-installed callback mixing equality+subtype semantics. Post-3c with principled per-relation dispatch, equality lattice IS distributive (216/216 triples confirmed) — Track 2H (PPN 4C T-3 Commit B) had made it distributive via union-aware merge; the callback hid this. 4 stale test expectations updated in test-sre-algebraic.rkt + 4 cascading tests updated in test-sre-track2h.rkt + 5 new Phase-3c tests added. Sister callback `current-lattice-meta-solution-fn` deferred to PM Track 12 (cross-referenced in PM Master + DEFERRED.md). |
| 3 | Empirical sweep across all registered domains × relations; record findings | ✅ | Findings table populated in § Phase 3 Findings. Ground sublattice (depth-0, 6 atoms, 216 triples): both relations confirm distributive + SD. Wider sample (depth-1 with binders, 58 samples, 195112 triples): both refute distributive (Pi-typed witness), both confirm SD with asymmetric non-vacuity (3.5% vs 91.4%). Validates Track 2H's F7 scope conjecture. Discussion-phase considerations recorded; declaration updates deferred per locked scope. |
| 4 | Sweep semantic correction — per-relation join dispatch (Scaffolding-Hides-Truth corrective) | ✅ | _Commit pending_. 5 function signatures refactored (test-distributive, test-sd-{vee,wedge}/detailed + wrappers) to take explicit `join-fn`; ~25 callsites updated atomically across sre-core.rkt + sre-property-sweep.rkt + tests/test-sre-algebraic.rkt + tests/test-sre-sd-properties.rkt. Targeted suite GREEN (106 tests / 4.3s). Wider-sample sweep produced honest data: depth-0 ground sublattice both relations confirm distributive (matches Track 2H decl + Phase 3c hand-picked-6); depth-1 with binders BOTH refute distributive — empirical confirmation of Track 2H F7 scope conjecture. Both SD-vee + SD-wedge confirm on wider sample with asymmetric non-vacuity (3.5% vs 91.4%). |
| 5 | Pseudo-complement family checks | ✅ | _Sub-phased 5a (commit `b2751dd2`) + 5b (`2a8fc7ea`) + 5c (pending commit)._ 5a: rel + abs pseudo-complement, atomic rename `'has-pseudo-complement` → `'has-pseudo-complement-rel`, pc-rel-evidence struct, lattice-leq? helper. **Phase 5a positive finding**: type×equality reaches Heyting on ground sublattice (empirical pseudo-complement-rel confirms; combined with Phase 3c distributive → heyting via implication rule). 5b: relatively-complemented (Nation's primary terminology, O(N⁴)). 5c: Stone identity + stone-algebra implication rule. 14 new test-cases. Targeted suite GREEN: 122 tests / 4.3s. Q2 research found "semi-complement" not in Nation's lexicon → `test-relatively-complemented` is the canonical-term match. Adversarial VAG passed at close. |
| 6 | Free-lattice membership + modularity checks | ⬜ | `test-whitmans-condition` (W: 4-tuple O(N⁴) sweep; FL membership criterion; Nation's canonical-form territory) + `test-modular` (level between SD and distributive; clarifies binder-included posture) + `test-breadth-bound` (≤ k; Jónsson-Kiefer-Nation 1962 theorem; SD lattices have breadth ≤ 4 on finite sublattices) + `test-sectional-complement` (conditional, runs if modular confirms). |
| 7 | Generator extension: session domain | ⬜ | Audit `session-lattice.rkt` / `session-propagators.rkt` ctor-descs; design realistic session atom pool (close, send-T, recv-T, select, offer, mu, ...); extend `build-atoms-by-spec`. Splits original deferred Phase 3b into per-domain sub-phases. |
| 8 | Generator extension: form domain | ⬜ | Audit `form-cells.rkt` ctor-descs; design realistic form atom pool; extend `build-atoms-by-spec`. Form has nested-pipeline structure that may exhibit binder-like scope-sensitivity — possible 4th Scaffolding-Hides-Scope instance (mirror of Track 2H's form-cells.rkt:503 Heyting declaration). |
| 9 | Comprehensive sweep + findings synthesis | ⬜ | Run sweep across all `(domain, relation)` × all 7+ algebraic properties: distributive, sd-vee, sd-wedge, has-pseudo-complement, has-semi-complement, modular, breadth-bound, whitmans-condition (+ conditionals). Expanded findings table replaces/extends § Phase 3 Findings with the wider matrix. |
| 10 | Lattice Variety Report (presentation document) | ⬜ | Stage 0/1 research note `docs/research/YYYY-MM-DD_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md`. Comprehensive variety categorization per domain; cross-references to Freese-Ježek-Nation 1995, Whitman, Reading-Speyer-Thomas; worked examples + witnesses; open questions framed as conversation starters. Cross-linked from PTF master. Suitable for sharing with Prof. Nation. |
| T | Dedicated test phase: `test-sre-sd-properties.rkt` | ✅ | Realized early during Phase 3 (file created in commit `bd1179b1` to keep test-sre-algebraic.rkt fast under shared-fixture sweep). Phase 4 added 11 callsite updates + memq→check-not-false hygiene. Tests run in 0.28s at depth-0; cover sweep mechanism + ground-sublattice load-bearing assertions. Phases 5-9 will extend with new property-check tests as each lands. |
| Discussion (deprecated) | — | — | Discussion-phase scope folded into Phase 10's Lattice Variety Report. Findings + considerations from § Phase 3 Findings already captured + cross-linked. |

---

## Stage 2 Audit (folded in)

Currently-declared properties at the four SRE-domain registration sites (verified `git grep` 2026-04-30):

| Site | Domain × Relation | Declared properties | Variety placement (today) |
|---|---|---|---|
| [`unify.rkt:92`](../../racket/prologos/unify.rkt) | type × equality | comm-join, assoc-join, idem-join, has-meet | Bounded join-semilattice; *no distributivity declared* (Track 2G found refuted). Candidate for SD-but-not-distributive. |
| [`unify.rkt:96`](../../racket/prologos/unify.rkt) | type × subtype | comm-join, assoc-join, idem-join, has-meet, **distributive**, **has-pseudo-complement** | **Heyting** (Track 2H redesign). SD inherited via implication. |
| [`form-cells.rkt:503`](../../racket/prologos/form-cells.rkt) | form × equality | comm-join, assoc-join, idem-join, has-meet, **distributive**, **has-pseudo-complement**, has-complement *refuted* | **Heyting**, *not* Boolean. SD inherited. |
| [`form-cells.rkt:542`](../../racket/prologos/form-cells.rkt) | form × (no relation) | comm-join, assoc-join, idem-join | Semilattice; no meet declared. SD-untestable without meet. |
| [`session-propagators.rkt:277`](../../racket/prologos/session-propagators.rkt) | session × equality | comm-join, assoc-join, idem-join, has-meet | Bounded join-semilattice; *no distributivity declared*. Candidate. |

**Three domains where SD sweep is informative** (not derivable via implication): type×equality, session×equality, form×(unrelation).

**Two domains where SD is automatic** via the new implication rule: type×subtype, form×equality.

**One untestable**: form×(no-relation) — has no meet declared, so SD checks return `axiom-untested`.

**Existing infrastructure** (verified `sre-core.rkt:55,262-459`):
- `test-commutative-join`, `test-associative-join`, `test-idempotent-join`, `test-distributive` — exact pattern to mirror.
- `infer-domain-properties` (line 329) — extension point for new tests.
- `resolve-and-report-properties` (line 440) — extension point for new evidence reporting.
- `standard-implication-rules` (line 374) — extension point for `distributive ⇒ sd-vee` rule.
- `axiom-confirmed | axiom-refuted | axiom-untested` — return type to reuse.
- `property-value-join` (4-valued: ⊥, #t, #f, ⊤) — handles confirmed/refuted/contradicted/unknown reconciliation.

The existing test fixture `tests/test-sre-algebraic.rkt` (verified) is the parallel surface to extend.

---

## Phases

### Phase 1: Test functions + wiring

**Mini-design** (Stage 4 step 1 — populated as Phase 1 begins):
- *Design reference*: this doc § Stage 2 Audit; `sre-core.rkt:303-322` (template); `sre-core.rkt:329-358` (wiring); `sre-core.rkt:374-381` (implication rules).
- *Obligations carried*: research note §5.4 ("small, immediate, mirrors Track 2G").
- *Principles in play*: Cells over parameters (no — pure functions, sample-check style); Decomplection (yes — adding orthogonal property checks); Correct-by-Construction (no — empirical, not constructive).
- *Mantra check*: SD checks do not run on the propagator network; they are sample-check sweeps performed at SRE-domain registration time. **Off-network by design** — labeled as such, retired only if/when SD-property cells migrate to the network (a separate concern, parallel to how distributivity, idempotence, etc. are checked off-network today). Same pattern as existing Track 2G.
- *Drift risks*: (i) accidentally introducing on-network-style test loops where simple `for/fold` is correct; (ii) returning the wrong shape from the new test functions (must match `axiom-confirmed | axiom-refuted | axiom-untested`); (iii) the implication rule firing in the wrong direction (`distributive ⇒ SD` is forward; the inverse does not hold).

**Mini-audit** (will populate after touching `sre-core.rkt`).

**Concrete code shape** (template — exact form locks at implementation time):

```racket
;; SD∨: a ⊔ b = a ⊔ c ⇒ a ⊔ b = a ⊔ (b ⊓ c)
;; Requires meet-fn. axiom-untested if no meet available.
(define (test-sd-vee domain samples meet-fn)
  (if (not meet-fn)
      axiom-untested
      (let ([join ((sre-domain-merge-registry domain) 'equality)])
        (for/fold ([status (axiom-confirmed 0)])
                  ([a (in-list samples)] #:break (axiom-refuted? status))
          (for/fold ([st status])
                    ([b (in-list samples)] #:break (axiom-refuted? st))
            (for/fold ([st2 st])
                      ([c (in-list samples)] #:break (axiom-refuted? st2))
              (define ab (join a b))
              (define ac (join a c))
              (cond
                [(not (equal? ab ac))
                 ;; hypothesis fails — no obligation
                 (axiom-confirmed (+ (axiom-confirmed-count st2) 1))]
                [else
                 (define conclusion (join a (meet-fn b c)))
                 (if (equal? ab conclusion)
                     (axiom-confirmed (+ (axiom-confirmed-count st2) 1))
                     (axiom-refuted (list a b c)))])))))))

;; SD∧ dual
(define (test-sd-wedge domain samples meet-fn) ...)
```

Wire-up into `infer-domain-properties` and `resolve-and-report-properties` follows the exact pattern of `test-distributive` (lines 350-356, 446-454).

Implication rules (line 374):
```racket
(implication-rule 'distributive→sd-vee   '(distributive) 'sd-vee)
(implication-rule 'distributive→sd-wedge '(distributive) 'sd-wedge)
```

**Test coverage**: targeted unit tests in `tests/test-sre-algebraic.rkt` confirming:
- `test-sd-vee` returns `axiom-untested` when no meet-fn supplied.
- `test-sd-vee` returns `axiom-confirmed` on a known-distributive lattice (sanity check).
- `test-sd-vee` returns `axiom-refuted` with witness when given a known-non-SD lattice (constructed counterexample fixture).
- Implication `distributive ⇒ sd-vee` fires correctly via `derive-composite-properties`.

Estimated scope: ~80-100 LoC across `sre-core.rkt` + ~30 LoC of unit tests in `test-sre-algebraic.rkt`. ~30-45 min.

### Phase 2: Programmatic sample generator from ctor-desc registry

**Goal**: `generate-domain-samples : sre-domain × ... → (listof value)` walks the domain's ctor-desc registry to synthesize representative inhabitants. Plus enrich SD test return value to track vacuous-vs-non-vacuous triple counts for honest Phase 3 reporting.

**Mini-design + audit (locked 2026-04-30)**:

*Audit findings persisted from code-reading*:
- `ctor-desc` structure (`ctor-registry.rkt:85-96`): `tag`, `arity`, `recognizer-fn`, `extract-fn`, `reconstruct-fn`, `component-lattices`, `binder-depth`, `domain`, `component-variances`, `binder-open-fn`.
- Per-domain storage: `type-ctor-table`, `data-ctor-table`, `extra-domain-tables` (`ctor-registry.rkt:141-157`). Access via `(domain-table 'type)` / similar.
- Existing `type-samples` (test fixture, line 111): `(list type-bot type-top (expr-Int) (expr-Nat) (expr-String) (expr-Bool))` — 6 flat atoms only; no compound types.

*Decisions (per user direction, 2026-04-30 dialogue)*:

1. **Generator placement**: SEPARATE FILE `racket/prologos/sre-sample-generator.rkt`. Decomplection — sample generation is orthogonal to property checking; reusable for any future algebraic-property check.

2. **Vacuous-triple counting**: ENRICH SD test return value via parallel `/detailed` variants. Introduce `sd-evidence` struct (status, total-checked, hypothesis-fired, conclusion-held, witness). `test-sd-vee/detailed` and `test-sd-wedge/detailed` return `sd-evidence`; existing `test-sd-vee` and `test-sd-wedge` become thin wrappers preserving `axiom-confirmed | axiom-refuted | axiom-untested` shape (no breaking change to Phase 1 wiring or tests).

3. **Binder ctors** (`binder-depth > 0`): SKIP IN PHASE 2 with explicit comment in code. Limitation documented; if Phase 3 reveals gaps from missing function-type SD coverage, revisit. Per user direction.

*Honest implication of audit (flagged before implementation)*: `type × equality` uses agree-or-top merge; `a ⊔_eq b = a ⊔_eq c` rarely fires non-trivially regardless of sample diversity. SD on equality merge will likely report "confirmed mostly vacuously." This is real lattice structure, not a generator weakness — the vacuous-triple counter is what makes Phase 3's findings table informationally honest. The empirically interesting SD question is on `type × subtype` (where `Nat ⊔_sub Int = Int` is a non-trivial join), but that domain is already declared distributive (Heyting) — SD inherited via implication, not empirical sweep. Phase 3 reporting will need to mark the distinction.

*Generator algorithm*:
- Depth 0: bot, top (if `#:include-bot-top`), optional `#:base-values`, plus nullary ctor inhabitants reconstructed from `(ctor-desc-reconstruct-fn desc) '()`.
- Depth d > 0: for each non-binder ctor with arity > 0, take Cartesian product of `per-ctor-count` components from depth (d-1), reconstruct, validate via `lookup-domain-classification` (skip 'unclassified).
- Reconstruction failures caught via `with-handlers` + silent skip (defensive guard for naive component combinations; labeled scaffolding in code).
- Deduplication via `equal?` at each depth + final pass.

*Generator parameters*:
- `#:max-depth` (default 2)
- `#:per-ctor-count` (default 2 — Cartesian = 2^arity per ctor per depth)
- `#:include-bot-top` (default #t)
- `#:base-values` (optional pre-built atomic samples)

*Estimated sample-set size at defaults*: depth 0 ~6-10, depth 1 ~20, depth 2 ~30; total ~50 deduped. SD-check cost: O(50³) = 125k iterations per check per domain × ~1μs/iter = 125ms. Within budget for the diagnostic invocation pattern.

**Drift-risk mitigations (carried from §Drift risks)**:
- R2 (sample size): generator's parameter caps + Cartesian explicit; not auto-recursive.
- R4 (perf): O(|samples|³) bound visible from generator parameters; gated behind explicit `infer-domain-properties` call (no auto-runs).
- New for Phase 2: reconstruction failure tolerance — `with-handlers` defensive scaffolding labeled in code.

**Test coverage**: tests in `test-sre-algebraic.rkt` covering: generator returns non-empty for type domain; depth-0 includes bot/top + base atoms; depth > 0 produces compound values; all generated values pass classify; deduplication works. Plus tests for `sd-evidence` struct construction and `/detailed` variant return shape.

**Estimated scope**: generator ~100-150 LoC; sd-evidence + /detailed variants ~70-90 LoC; tests ~80-100 LoC. ~45-60 min.

### Phase 2a: Principled corrective — per-component-spec generation, drop `with-handlers`, include binders

**Origin**: User-flagged 2026-04-30 mid-Phase-3 dialogue. Phase 2's `try-reconstruct` `with-handlers` matched the codified red-flag pattern from PPN 4C S2.c-iii drift (`workflow.md:56`, `DEVELOPMENT_LESSONS.org §1102-1160`). Move B+ pattern is the precedent: separate corrective sub-phase that drops the defensive scaffolding and captures the principled benefit.

**Mini-design (locked 2026-04-30)**:

*Design references*:
- `.claude/rules/workflow.md:56` — VAG adversarial framing red-flag patterns (with-handlers / defensive guards)
- `DEVELOPMENT_LESSONS.org §1102-1160` — Move B+ corrective pattern (3 data points)
- `DEVELOPMENT_LESSONS.org §137-141` — "Prelude Errors Are Silently Swallowed" (older lesson on silent error masking)
- `ctor-registry.rkt:85-96` — `ctor-desc` struct with `component-lattices` field that drives Option C
- `ctor-registry.rkt:107-131` — `lattice-spec` struct + `'type` / `'session` / `'mult` sentinels

*Principles in play*: **Correct-by-Construction** (primary), **Decomplection** (per-ctor generation cleanly separated from cross-ctor combinatorics), **Data Orientation** (`component-lattices` IS the data driving generation; ignoring it was the original violation).

*Mantra check*: "structurally emergent" — components emerge from per-ctor lattice-specs, not from naive global pool. Phase 2's `with-handlers` violated emergence by Cartesian-producting blindly then catching failures. Option C aligns.

*Drift risks named*:
1. Scope creep into a generator rewrite that delays Phase 3 — *mitigation*: ~80-100 LoC delta; tests adjust to new shape.
2. `component-lattices` interpretation incomplete — concrete `lattice-spec` structs vs sentinel symbols — *mitigation*: handle both in `atoms-by-spec` lookup via `equal?`-keyed hash.
3. Validation for type-lattice components is not a single predicate — *mitigation*: per-component-spec POOL approach (draw from valid-by-construction pool; no validation predicate needed).
4. Cascading test changes — *mitigation*: my Phase 2 tests assert structural properties (count > 0, monotonicity, dedup), not exact counts. Should pass unchanged.
5. **Bonus risk from binder inclusion**: dependent function types (where codomain references bound parameter via `expr-bvar`) are NOT generated in 2a — closed-body Pi/Sigma/lam only. Documented in code; revisit if Phase 3 reveals gap.

*Mini-audit findings persisted*:

**A. With-handlers in my Phase 1+2 code** (verified `grep`):
- 1 instance in `sre-sample-generator.rkt:160` (`try-reconstruct`) — Phase 2a target.
- 0 elsewhere (sre-core.rkt SD additions, test-sre-algebraic.rkt SD tests have none).

**B. Consequence patterns from `try-reconstruct` returning `#f`**:
- `nullary-ctor-inhabitants`: `(if v (cons v acc) acc)` silent skip.
- `compound-ctor-inhabitants`: same pattern.
- Both go away once `with-handlers` is gone (reconstruction always succeeds → unconditional `cons`).

**C. Type-domain ctor-desc audit** (verified `ctor-registry.rkt:426-540`):
- All non-binder type ctors use uniform `(list type-lattice-spec ...)` for component-lattices: app, Eq, Vec, Fin, pair, PVec.
- Binder type ctors (Pi, Sigma, lam) add `mult-lattice-spec` to one slot: Pi `(mult type type)`, lam `(mult type type)`, Sigma `(type type)`.
- Generator needs two pools: `'type` (sentinel) and `mult-lattice-spec` (concrete struct).
- Mult pool: `'(mw m1 m0)` — three values, trivial.

**D. Reconstruct-fns blindly slot components without type-checking**:
- `(λ (cs) (expr-Pi (first cs) (second cs) (third cs)))` constructs the struct without validating component types.
- This means the original `with-handlers` was catching almost nothing for the type domain — defensive scaffolding for hypothetical concerns rather than observed failures.
- Even more shape-without-benefit than initially suspected.

**E. SRE-adjacent codebase-wide with-handlers audit** (deferred to GitHub issue):

| File | Line(s) | Pattern | Character | Disposition |
|---|---|---|---|---|
| `sre-sample-generator.rkt` | 160 | `try-reconstruct` silent skip | Strong red-flag | **Phase 2a target** |
| `form-cells.rkt` | 192, 306 | Process-form / pipeline silent skip | Ambiguous (parsing resilience or drift) | Defer to GitHub issue |
| `form-cells.rkt` | 234 | `tree-node-to-datum` returns `#f` on failure | Medium-effort signature refactor | Defer to GitHub issue |
| `session-propagators.rkt` | 487, 531 | `net-cell-read` fallback to sentinel | Cell-id contract analysis needed | Defer to GitHub issue |
| Codebase-wide (other 67) | various | Heterogeneous (I/O / feature-probe / fallback / drift) | Categorize per-instance | Defer to GitHub issue |

**Scope (locked)**:
1. Refactor `sre-sample-generator.rkt` per Option C (per-component-spec pools).
2. Drop `try-reconstruct` (the `with-handlers` and the `#f` fallback path).
3. Drop `(if v ...)` consequence patterns in both `*-ctor-inhabitants`.
4. Include binder ctors (remove `(zero? (ctor-desc-binder-depth desc))` filter).
5. Add `mult-pool` for binder ctors' mult slots.
6. Update doc comments to reflect new architecture.
7. Update tests if needed (mostly should pass unchanged given structural assertions).
8. After commit: draft + file ONE parent GitHub issue for codebase-wide with-handlers audit, with SRE-adjacent findings table preserved + Phase 2a commit referenced as principled-refactor precedent.

**NOT in scope (deferred to GitHub issue)**:
- form-cells.rkt error-model refactor (3 instances).
- session-propagators.rkt cell-read contract analysis (2 instances).
- Categorization + cleanup of remaining 67 codebase-wide instances.
- Dependent-type generation for binder ctors (with `expr-bvar` references).

**Estimated scope**: ~80-100 LoC delta on generator + ~20 LoC test additions for binder coverage. ~30-45 min implementation; ~15 min issue drafting.

### Phase 3: Empirical sweep + findings recording

**Goal**: Run the property sweep (including new SD checks) against every registered domain × relation pair using Phase 2a's generator + per-relation `meet-registry` lookup (Phase 3c). Capture findings as a committed test fixture and a markdown table in § Phase 3 Findings (populated when phase runs). **Do NOT update declared-properties at registration sites** — that's the Discussion phase per user direction.

**Mini-design (locked 2026-04-30, post-Phase-3c)**:

*Design references*:
- This doc § Stage 2 Audit + Phase 2a mini-design (sentinel filtering enabling honest reporting)
- Phase 3c bonus discovery (distributivity flip — equality lattice IS distributive on hand-picked-6 post-Phase-3c)
- Phase 1 surfacing #3 (vacuous-triple risk → /detailed enrichment)
- [PTF Lattice Hierarchy note](../research/2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md) (per-level capability catalog)

*Obligations carried*:
- Use `/detailed` variants for vacuous-vs-non-vacuous reporting (Phase 1+2 obligation)
- Use `sre-domain-meet` lookup for principled per-relation meet (Phase 3c enabling)
- Sweep type×equality AND type×subtype (both available via meet-registry post-Phase-3c)
- Distinguish "confirmed on full sample" / "confirmed on hand-picked-6 only" / "refuted with witness"
- Report hypothesis-fired/total-checked ratio per finding
- DO NOT update declared-properties at registration sites (Discussion phase)

*Scope (locked)*:
1. Add `run-sd-sweep` function (likely in `sre-sample-generator.rkt` — sample generation + diagnostic share concern). Walks (`'type`, `'equality`) and (`'type`, `'subtype`); uses `sre-domain-meet`; calls `/detailed` variants; produces structured `sd-finding` records.
2. Sweep with `realistic-type-atoms` base-values + max-depth 1-2 (Phase 2a generator's ctor coverage including non-dependent binders).
3. `format-sd-findings` produces markdown table for design doc § Phase 3 Findings.
4. Validate distributivity-confirmed status across wider sample. Findings table makes the sample-set explicit.
5. Capture counterexample triples (if any) as Phase T regression-test fixtures.
6. Document any Move B+ bonus findings prominently — Phase 2a + Phase 3c precedent says expect them. Per user direction (2026-04-30): if a bonus finding surfaces, dialogue first, decide together — NOT commit speculatively.
7. Phase 3 outputs → Discussion-phase inputs.

*NOT in scope (explicit hard boundary)*:
- Pseudo-complement empirical check → Phase 3.5 (own row in tracker)
- Bonus-finding atomic commits → discuss-when-found per user
- session × equality + form × equality sweeps → Phase 3b
- Registration declaration updates → Discussion phase

*Drift risks for Phase 3*:
1. Confusing finding-reporting with declaration-updating — explicit hard boundary.
2. Underclaiming or overclaiming the 6-atom-only result — findings table must name the sample set used.
3. Vacuous-triple ratios buried — must surface in the findings table per `/detailed` enrichment.
4. Move B+ pattern surfacing another bonus finding — discuss-when-found per user direction (NOT commit speculatively).
5. Performance: sweep on 50-70 samples is ~125k-340k iterations per check per relation. Acceptable for diagnostic; if it hits perf wall, sample-size cap is the dial.

**Test coverage**: regression test that the sweep produces the recorded findings (so future SRE changes that alter merge functions surface as test-fixture changes, not silent property drift). Snapshot the markdown output in a test fixture for diff-on-change.

**Estimated scope**: ~80-100 LoC for sweep + format functions, + the markdown findings table. ~30-45 min implementation + ~15 min findings analysis.

#### Decisions (mini-design + mini-audit dialogue 2026-04-30)

Mini-audit completed against actual code surfaces (`generate-domain-samples` at `sre-sample-generator.rkt:80`, `test-sd-vee/detailed` + `test-sd-wedge/detailed` at `sre-core.rkt:394,424`, `sd-evidence` struct at `sre-core.rkt:385`, `sre-domain-meet` at `sre-core.rkt:190`, `realistic-type-atoms` at `tests/test-sre-algebraic.rkt:469`). Three implementation-shape decisions resolved via dialogue:

**Q1 — File placement**: NEW file `racket/prologos/sre-property-sweep.rkt` (NOT colocated in `sre-sample-generator.rkt`). Decomplection rationale: generator IS input to sweep diagnostic, different concerns. Phase 3.5 (pseudo-complement sweep) and Phase 3b (session/form sweeps) will both consume the same sweep infrastructure — separate file gives them a natural home.

**Q2 — `realistic-type-atoms` location**: Sweep accepts atoms as a parameter; caller supplies per-domain. Sweep stays generic over `(domain, relations, atoms, depth-config)`. Phase 3b will want different atoms per domain. Avoids cross-cutting ownership of test-fixture constants.

**Q3 — Properties swept**: Run `{distributive, sd-vee, sd-wedge}` together per `(domain, relation)`, NOT just SD∨/SD∧. Rationale per [PTF Lattice Hierarchy note](../research/2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md) §5.1+§5.2: distributive is the most informative single result; if confirmed on wider sample, Heyting is the next question (Phase 3.5); if refuted with witness, SD becomes the load-bearing finding (Reading-Speyer-Thomas canonical form applies, DNF/Birkhoff don't). Showing all three reifies the implication chain `distributive ⇒ sd-vee ∧ sd-wedge`.

**`sd-finding` record shape** (locked):

```racket
(struct sd-finding
  (domain-name      ; symbol, e.g. 'type
   relation         ; symbol, e.g. 'equality | 'subtype
   property         ; symbol, 'sd-vee | 'sd-wedge | 'distributive
   sample-count     ; int — atoms count after generation
   evidence)        ; sd-evidence struct (for SD); axiom-* (for distributive)
  #:transparent)
```

**Markdown table columns**: Domain | Relation | Property | Samples | Status | Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness

**PTF Lattice Hierarchy connection — what the sweep results unlock**:

| If wider-sample sweep confirms... | Discussion-phase declaration unlocks (per PTF note §5.1+§5.2) |
|---|---|
| `type×equality` is distributive | DNF canonicalization; Birkhoff representation; clean Galois bridge composition with `type×subtype` (which is also declared distributive) — bridges between equality-context and subtype-context type cells compose cleanly without algebraic-level mismatches. UCS dispatch (§6.2) gets distributive-level routing for equality contexts. |
| `type×equality` is SD but not distributive (refuted with witness) | Reading-Speyer-Thomas canonical form applies; structural-unification MGU correctness assured; but DNF/Birkhoff/clean-bridge-composition foreclosed. Asymmetry with `type×subtype` becomes a tracked design concern. |
| `type×subtype` empirical results | Validates (or refutes) the Track 2H Heyting declaration on the wider sample space. |

**Two new drift risks** (added to design doc's existing 5):
6. Q3 scope creep — including `test-distributive` was an explicit dialogue decision, NOT a mid-flight expansion. Documented here so future-self doesn't read "scope creep" into the choice.
7. Q2 generic-vs-typed slippage — caller-supplied atoms keeps sweep generic; if a `default-atoms` parameter that hardcodes type atoms is later added, the decoupling is silently lost. Watch for this.

#### Phase 3 Findings (captured 2026-04-30, post-Phase-4 corrective)

**Sample parameters**: `realistic-type-atoms = (Int, Bool, Nat, String)`, `#:max-depth 1`, `#:per-ctor-count 2` → 58 samples after dedup (depth-0: 6 atoms = bot + top + 4 base; depth-1 adds compounds via `app, Eq, Vec, Fin, pair, PVec, Pi, Sigma, lam`). 195112 triples per check (58³). Generated via `racket sre-property-sweep.rkt` (`module+ main` invocation). Total runtime: 102s.

| Domain | Relation | Property | Samples | Status | Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness |
|---|---|---|---|---|---|---|---|---|---|
| type | equality | distributive | 58 | refuted | — | — | — | — | `(Pi(m1, Bool, Bool), Int, Pi(m1, Int, Bool))` |
| type | equality | sd-vee | 58 | confirmed | 195112 | 6814 | 6814 | 3.5% | — |
| type | equality | sd-wedge | 58 | confirmed | 195112 | 178382 | 178382 | 91.4% | — |
| type | subtype | distributive | 58 | refuted | — | — | — | — | `(Pi(m1, Bool, Bool), Int, Pi(m1, Int, Bool))` |
| type | subtype | sd-vee | 58 | confirmed | 195112 | 6786 | 6786 | 3.5% | — |
| type | subtype | sd-wedge | 58 | confirmed | 195112 | 178166 | 178166 | 91.3% | — |

**Ground-sublattice sweep** (depth-0, 6 atoms, 216 triples per check — captured in `test-sre-sd-properties.rkt` regression suite):

| Domain | Relation | Property | Status |
|---|---|---|---|
| type | equality | distributive | confirmed (216/216) |
| type | equality | sd-vee | confirmed |
| type | equality | sd-wedge | confirmed |
| type | subtype | distributive | confirmed (216/216) |
| type | subtype | sd-vee | confirmed |
| type | subtype | sd-wedge | confirmed |

**Interpretation** (per [PTF Lattice Hierarchy note §5.1+§5.2](../research/2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md)):

- The type lattice **is distributive on the ground sublattice** (atoms only — no binders, no metas) for both equality and subtype relations. This validates Phase 3c's hand-picked-6 finding (216/216 confirmed) and Track 2H's design-intent declaration. UCS dispatch could safely route ground-sublattice operations to distributive-level optimizations (DNF canonicalization, Birkhoff representation, Heyting pseudo-complement on subtype contexts).

- The type lattice **is SD but not distributive on the binder-included sublattice** for both relations. The witness shows distributivity fails when one operand is atomic and the others are Pi-typed — the function-type substructure is non-distributive. This empirically confirms Track 2H's F7 scope conjecture (design body line 107: *"distributivity is conjectured but not yet verified — substitution under binders does not obviously distribute over union-join"*).

- **SD-vee and SD-wedge both confirm on the wider sample**, with asymmetric non-vacuity: 3.5% vs 91.4%. The asymmetry is informative — the lattice's join is "spreadier" than its meet on these samples, so the SD-vee hypothesis (`a ⊔ b = a ⊔ c`) rarely fires non-trivially while the SD-wedge hypothesis (`a ⊓ b = a ⊓ c`) often does. SD-vee declared confirmed is informationally weak (mostly vacuous); SD-wedge confirmed is strong.

- **Track 2H's quantale framing intact**: the type lattice IS a quantale (tensor distributes over join). Quantale axioms are about the multiplicative tensor, not lattice meet/join distributivity. The lattice can be SD-not-distributive AND a quantale simultaneously — Phase 4 finding clarifies this distinction.

**Discussion-phase considerations** (out-of-band scope; informed by Phase 4 finding):

1. The registration at `unify.rkt:96` declares `'distributive prop-confirmed` unconditionally for type×subtype. This is over-broad relative to Track 2H's design body (which scoped to ground sublattice via F7). Discussion-phase decisions: amend declaration? extend property registry granularity to scope-aware?
2. Property registry has no scope granularity — booleans only ({prop-confirmed, prop-refuted, prop-unknown, prop-contradicted}) per (domain, relation). For UCS dispatch to use distributive optimizations on ground sublattice while falling back to SD on binder-typed values, scope-awareness is required.
3. Scope-awareness mechanisms ARE in scope for the in-flight PPN 4C work (sub-lattice bridges as Galois connections per Abstract Interpretation framing).
4. Sister research-note candidates (queued at PTF master): quantale distributivity laws, substructural-logic non-distributivity at function-type boundary, recovering distributivity for unsolved dependent types (frontier).

### Phase 4: Sweep Semantic Correction (Scaffolding-Hides-Truth corrective)

**Origin**: Phase 3 wider-sample sweep refuted distributivity for type×subtype with witness `(Int, Nat, type-top)`. Audit revealed the refutation was a sweep semantic bug — `test-distributive` and `test-sd-{vee,wedge}/detailed` in `sre-core.rkt` hardcode `((sre-domain-merge-registry domain) 'equality)` for the join, mixing meet-from-relation-R with join-from-relation-equality. Track 2H's distributivity claim was for `(meet-subtype, join-subtype)` (same lattice), not the mixed pair.

**Pattern**: 3rd Scaffolding-Hides-Truth data point (Phase 2a `with-handlers` masking malformed compounds; Phase 3c always-installed callback masking distributivity restoration; Phase 4 hardcoded `'equality` masking per-relation join dispatch). Crosses Watching-table promotion gate → graduate to `DEVELOPMENT_LESSONS.org` as separate commit at Phase 4 close.

**Audit findings persisted** (mini-audit completed 2026-04-30):

| Surface | Site | Current | Fix |
|---|---|---|---|
| `sre-core.rkt:330` | `test-distributive` | hardcodes `'equality` join | take `join-fn` parameter |
| `sre-core.rkt:394` | `test-sd-vee/detailed` | hardcodes `'equality` join | take `join-fn` parameter |
| `sre-core.rkt:424` | `test-sd-wedge/detailed` | hardcodes `'equality` join | take `join-fn` parameter |
| `sre-core.rkt:457,465` | `test-sd-vee`, `test-sd-wedge` wrappers | thin wrappers | take + thread `join-fn` |
| `sre-core.rkt:504,510,515` | `infer-domain-properties` callsites | pass meet-fn only | look up + pass join-fn from `merge-registry` per relation |
| `sre-core.rkt:621-623` | `resolve-and-report-properties` callsites | same | same |
| `sre-property-sweep.rkt:94,96,98` | `run-sd-sweep` calls | pass meet-fn only | look up + pass join-fn per relation (already has `rel` in scope) |
| `tests/test-sre-algebraic.rkt` | ~11 callsites (Phase 1+2 tests) | pass meet-fn only | add explicit join-fn (test fixtures use `type-lattice-merge`) |
| `tests/test-sre-track2h.rkt` | 0 callsites | — | — |

Total: ~25 callsite updates across 4 files.

**Decisions (mini-design + mini-audit dialogue 2026-04-30)**:

1. **Shape**: explicit `join-fn` parameter on all five property-test functions; no hidden lookup, no default. Mirrors Phase 3c's `meet-fn` pattern.

   ```racket
   (define (test-distributive domain samples meet-fn join-fn) ...)
   (define (test-sd-vee/detailed domain samples meet-fn join-fn) ...)
   (define (test-sd-wedge/detailed domain samples meet-fn join-fn) ...)
   (define (test-sd-vee domain samples meet-fn join-fn) ...)        ;; wrapper
   (define (test-sd-wedge domain samples meet-fn join-fn) ...)      ;; wrapper
   ```

2. **All callsites updated atomically in one commit** per pipeline.md co-migration discipline.

3. **Caller pattern**: derive both `meet-fn` and `join-fn` from the SAME relation:
   ```racket
   (define meet-fn (sre-domain-meet domain rel))
   (define join-fn ((sre-domain-merge-registry domain) rel))
   ```

4. **Re-run sweep at close**. Expected: all 6 findings confirmed. If type×subtype STILL refutes after the fix → halt, escalate, dialogue (genuine Track 2H declaration error vs. sweep semantic remaining).

5. **Pattern graduation** is a SEPARATE small commit after Phase 4 lands successfully. Codifies "Scaffolding-Hides-Truth" with 3 data points (Phase 2a, 3c, 4) into `DEVELOPMENT_LESSONS.org`.

**Principles in play**:
- **Correct-by-Construction** (primary): test functions operate on a `(meet, join)` pair from the same lattice; making both explicit removes the lattice-mixing failure mode
- **Decomplection**: separates "which lattice" decision (caller) from "test the property" mechanism (function)
- **First-Class by Default**: `join-fn` becomes a first-class argument, mirroring `meet-fn`

**Mantra check**: hardcoded `'equality` is the same shape as the retired callback — off-network state injection (a constant baked into the function instead of dispatched per-relation). Phase 4 retires it. Same Scaffolding-Hides-Truth template as Phase 2a + 3c.

**Drift risks**:
1. **Asymmetric callsite updates**: caller passes meet-fn from relation R₁ but join-fn from relation R₂ → mixes lattices again. Discipline: callers always derive both fns from the SAME relation.
2. **Missed callsite**: arity mismatch at runtime (Racket doesn't catch at compile). Mitigation: targeted test run catches all in-tree callers.
3. **Type×subtype STILL refutes after fix**: would mean Track 2H declaration is genuinely wrong. ESCALATE before commit.
4. **Test cascade bug**: 11 test callsites updating mechanically — risk of incorrect update. Mitigation: re-read each updated callsite manually.
5. **API surface change**: any consumer of `test-sd-*` outside Track 2I/2G needs update. Audit confirmed none exist outside the four files listed.

**Estimated scope**: ~30 LoC delta across sre-core.rkt + ~10 LoC across sre-property-sweep.rkt + ~15 LoC across test-sre-algebraic.rkt. ~30-45 min implementation + ~10 min sweep re-run + ~5 min validation.

### Phase 5: Pseudo-complement family checks

**Scope** (high-level; full mini-design + mini-audit when phase opens):

Add three property-check functions to `sre-core.rkt` paralleling Phase 1's SD additions:

- **`test-pseudo-complement`** (relative pseudo-complement; Heyting →): for each `(a, b)` pair in the sample set, the candidate is `a → b = ⋁{x : x ∧ a ≤ b}`. Verify the axiom: candidate `c` satisfies `c ∧ a ≤ b` AND for all `x` with `x ∧ a ≤ b`, `x ≤ c`. Sample-set-sensitive on infinite/non-bounded lattices; for ground sublattice with full sample, exhaustive.

- **`test-semi-complement`** (dual pseudo-complement; reading (a) of "semi-complement"): for each `(a, b)`, candidate is `⋀{x : x ∨ a ≥ b}`. The Galois adjoint of join. Cheap addition alongside pseudo-complement; useful for completeness even though our common usage is meet-side.

- **`test-stone-identity`** (conditional — runs only if pseudo-complement confirms): verifies `¬a ∨ ¬¬a = ⊤` for each atom `a`, where `¬a` is the pseudo-complement of `a` relative to ⊥. Characterizes Stone algebras (distributive pseudo-complemented + Stone identity) — connects to intermediate logics (Gödel-Dummett).

**Property registry additions**: `'has-pseudo-complement`, `'has-semi-complement`, `'stone-identity`.

**Implication rules** (extend `standard-implication-rules`):
- `distributive + has-pseudo-complement ⇒ heyting` (already exists)
- `heyting + has-complement ⇒ boolean` (already exists)
- `distributive + has-pseudo-complement + stone-identity ⇒ stone-algebra` (new)

**Calling discipline (per Phase 4 Scaffolding-Hides-Truth #3)**: takes explicit `meet-fn` AND `join-fn` parameters. Caller derives both from same relation via meet-registry + merge-registry.

**Estimated scope**: ~80-120 LoC across sre-core.rkt + ~50 LoC of tests. Sweep integration (~10 LoC in sre-property-sweep.rkt + per-domain cell additions).

#### Decisions (mini-design + mini-audit + adversarial pass 2026-04-30)

**Background research (Q2 — "semi-complement" semantics)**: WebSearch + mempalace survey + project-materials grep confirm that **"semi-complement" does not appear in Nation's canonical literature**. Nation's lexicon: "relatively complemented" (his primary terminology — partition lattice Eq X, Theorem 10.10 Dilworth 1950, Theorem 11.3 geometric lattices), "pseudo-complement" (standard meet-zero or relative form), "complemented" (Boolean sense). Most likely interpretation of the in-person conversation: phonetic carry-over from semi-distributivity discussion → user's "semi-complement" recollection corresponds to Nation's standard term **relatively complemented**. Mitigation: present BOTH (a) dual pseudo-complement AND (b) relative complementation in the report; let Nation clarify if either is wrong reading.

**Q1 — Pseudo-complement disambiguation**: option (b) chosen — disambiguate. Both forms have distinct utility; relative implies absolute in distributive lattices but not in non-distributive cases (independently testable). Rename `'has-pseudo-complement` → `'has-pseudo-complement-rel`; introduce `'has-pseudo-complement-abs` as separate property. Atomic rename + Track 2H declaration update + implication-rule update in same commit (Phase 4 co-migration discipline).

**Q3 — Stone identity gating**: only run when `'has-pseudo-complement-rel` confirms. Returns `axiom-untested` otherwise. Sensible.

**Q4 — Phase structure**: single phase covering all 4 checks (relative + absolute pseudo-complement + relatively-complemented + Stone identity) — same family of axiom checks; ~150-250 LoC total. Sub-phase fallback if implementation exceeds 1h conversational stretch: 5a (relative + absolute pseudo-complement; rename), 5b (relatively-complemented), 5c (Stone identity conditional).

**Updated Phase 5 family (post-adversarial pass)**:

| Function | Form | Detailed variant? | Registry symbol |
|---|---|---|---|
| `test-pseudo-complement-rel` | `(domain samples meet-fn join-fn) → axiom-*` | **YES** (`pc-rel-evidence` parallel to `sd-evidence` — non-vacuity informationally rich) | `'has-pseudo-complement-rel` (renamed from existing) |
| `test-pseudo-complement-abs` | `(domain samples meet-fn join-fn) → axiom-*` | No | `'has-pseudo-complement-abs` |
| `test-relatively-complemented` | `(domain samples meet-fn join-fn) → axiom-*` | No (interval-wise; non-vacuity less obviously informative) | `'relatively-complemented` |
| `test-stone-identity` | `(domain samples meet-fn join-fn) → axiom-*` (gated on `'has-pseudo-complement-rel` confirmed) | No (single per-atom check) | `'stone-identity` |

**Implication rules updated**:
- `distributive + has-pseudo-complement-rel ⇒ heyting` (renamed)
- `heyting + has-complement ⇒ boolean` (unchanged)
- `distributive + has-pseudo-complement-rel + stone-identity ⇒ stone-algebra` (new)

**Adversarial-pass surfaced refinements** (CRITIQUE_METHODOLOGY two-column applied across P/R/M/S):

1. **Property-registry rename atomic with Phase 5 commit**: `'has-pseudo-complement` → `'has-pseudo-complement-rel`. Updates: `unify.rkt:116` Track 2H declaration; `sre-core.rkt:552` heyting implication rule; any tests referencing the symbol. Atomic per Phase 4 co-migration discipline.

2. **`type-pseudo-complement` at `subtype-predicate.rkt:309` gets clarifying comment** distinguishing "context-relative absolute pseudo-complement" (this function) from the empirical relative-pseudo-complement check (Phase 5 NEW). No code change; documentation only.

3. **YAGNI on detailed variants**: emit `pc-rel-evidence` (parallel to `sd-evidence`) ONLY for pseudo-complement-rel (non-vacuity is informationally rich). Other 3 checks return simple `axiom-*` shape. Don't mass-produce.

**Honest scope-acknowledgments** (P-lens challenges that didn't change the design but warrant naming):

- *Property-registry granularity gap inherited*: 4-valued `{prop-confirmed, prop-refuted, prop-unknown, prop-contradicted}` cannot express scope qualifiers (Phase 4 finding "true on sub-A, false on sub-B"). Phase 5 doesn't fix; punts to Phase 9 / Discussion.
- *Property checks remain off-network*: existing Track 2G scaffolding lineage. Retirement direction = property-cells migration (sister track).
- *Phase 5 doesn't exploit the Hasse structure of the lattice being checked*: Phase 6's `test-breadth-bound` IS Hasse-structural; Phase 5's checks are sample-iteration. Honest gap; not new debt.

**SRE Lattice Lens applied** (mandatory per CRITIQUE_METHODOLOGY): Phase 5 doesn't introduce a new lattice; characterizes existing ones. The Lens applies to the **property-value lattice** (axiom-confirmed | axiom-refuted | axiom-untested + 4-valued contradiction). Q1-Q5 catalogued; Q3 (bridges as Galois pairs from samples + meet-fn + join-fn → axiom-evidence) and Q6 (Hasse trivial for property-value lattice; rich for lattice-being-checked but not exploited) named honestly.

**Drift risks (consolidated, 7 items)**:

1. **Asymmetric meet/join lookup** (Phase 4 risk #1, recurring): callers derive both fns from same relation
2. **Sample-set sensitivity for `test-pseudo-complement-rel`**: ground sublattice exhaustive (6 atoms); wider samples sensitive — flag in interpretation
3. **Stone identity ordering**: gated on `'has-pseudo-complement-rel` confirming
4. **API rename cascade**: `'has-pseudo-complement` → `'has-pseudo-complement-rel` touches 3-5 sites; atomic commit per pipeline.md co-migration
5. **Property-registry granularity gap inherited** (P-lens challenge): Phase 5 doesn't fix; punts to Phase 9 / Discussion
6. **YAGNI on detailed variants**: produce only where empirically interesting
7. **Phase size approaching 1h conversational stretch boundary**: split into 5a/5b/5c if implementation exceeds; fallback plan locked

### Phase 6: Free-lattice membership + modularity checks

**Scope** (high-level):

- **`test-modular`**: for each `(a, b, c)` triple, verify modular law `a ≤ c ⇒ a ∨ (b ∧ c) = (a ∨ b) ∧ c`. Hypothesis `a ≤ c` provides built-in non-vacuity gating. Modularity is the level between SD and distributive in the PTF hierarchy (§3.3) — clarifies whether binder-included sublattice is strictly SD or modular-but-not-distributive. With `modular-evidence` /detailed variant.

- **`test-whitmans-condition`** (Whitman's W; FL membership criterion): for each 4-tuple `(a, b, c, d)` in the sample, verify: if `a ∧ b ≤ c ∨ d`, then one of `a ≤ c ∨ d`, `b ≤ c ∨ d`, `a ∧ b ≤ c`, `a ∧ b ≤ d` holds. **O(N⁴) sweep**; at depth-0 (N=6), 1296 iterations — cheap. At depth-1 (N=58), 11.3M iterations — heavy but feasible (~minutes). Critical: if domain satisfies (W), free-lattice canonical form (Whitman six-case algorithm) applies — high theoretic + technical alignment with Nation's central work (Theorem 5.55 / 6.9, Nation 1982). With `whitman-evidence` /detailed variant.

- **`test-breadth-bound`** (Jónsson-Kiefer-Nation 1962): maximum antichain width `≤ k`. SD lattices have breadth ≤ 4 on finite sublattices (Theorem 1.21 corollary). Parameterized via `#:max-width` keyword (default 4). Search for any (k+1)-element antichain — if found, width > k → refuted. Cost: O(N^(k+1)). At k=4, N=6: 7776 iterations (cheap); N=58: 656M (heavy but feasible). **NEW (Q6 finding)**: this is the FIRST Hasse-structural property check — exploits adjacency (incomparability = no Hasse edge). Simple axiom-* shape (no /detailed; per-witness search).

- **`test-sectionally-complemented`** (Grätzer's *General Lattice Theory*): for every `b` and every `c ∈ [⊥, b]`, ∃ `d ∈ [⊥, b]` with `c ∧ d = ⊥` AND `c ∨ d = b`. **Distinct from Phase 5b's `test-relatively-complemented`** — sectional uses `⊥` as meet target (principal ideals only); relatively-complemented uses interval bottom `a` (all intervals). Forward implication: relatively-complemented ⇒ sectionally-complemented. Empirically separable: a lattice can be sectionally complemented but fail relative complementation. Simple axiom-* shape.

**Property registry additions**: `'modular`, `'whitmans-condition`, `'breadth-bound` (parameterized), `'sectionally-complemented`.

**Implication rules added** (extend `standard-implication-rules`):
- `distributive ⇒ modular` (forward; codifies SD ⊃ modular ⊃ distributive hierarchy)
- `relatively-complemented ⇒ sectionally-complemented` (forward; principal ideals are intervals)

Whitman's W and breadth-bound have no clean implication chains to other registry properties (free-lattice-relative).

**Estimated scope**: ~150-250 LoC across sre-core.rkt + ~60-80 LoC of tests. Whitman's W is the dominant cost (4-tuple sweep).

#### Decisions (mini-design + mini-audit + adversarial pass 2026-04-30)

**Q1 — Sectional vs relatively-complemented disambiguation**: NOT redundant under standard literature treatment (Grätzer's *General Lattice Theory*). Relatively-complemented (Phase 5b) is the STRONGER property (all intervals); sectionally-complemented is the WEAKER (principal ideals `[⊥, b]` only). Forward implication: rel-complemented ⇒ sect-complemented. Reverse does not hold. Add `test-sectionally-complemented` as DISTINCT Phase 6 check.

**Q2 — Breadth parameterization**: parameterize via `#:max-width` keyword, default 4 (Theorem 1.21 SD lattice bound). Future-proof for variety-specific bounds.

**Q3 — Sub-phase fallback**: ready if implementation exceeds 1h. Likely partition: 6a (modular) + 6b (Whitman's W) + 6c (breadth + sectional). Decision deferred to implementation flow per Phase 5 precedent.

**Q4 — Detailed evidence structs**: keep separate (`modular-evidence`, `whitman-evidence` parallel to `sd-evidence`, `pc-rel-evidence`). Per-property fields differ semantically. Decomplection over false generality.

**Mini-audit findings persisted**:
- sre-core.rkt at 1793 lines pre-Phase-6; Phase 6 adds ~200 LoC → ~2000 lines (approaching whale-file-splitting threshold per testing.md guidance, but within bounds)
- Implication-rules section at line 825; 5 rules currently (heyting, boolean, sd-vee, sd-wedge, stone-algebra)
- Inference pattern `props-0` through `props-9` (Phase 5c added); Phase 6 adds `props-10` through `props-13`
- 9 registry symbols currently active (10 with stone-algebra derived)

**Adversarial CRITIQUE pass surfaced refinements**:

1. **Q6 Hasse exploitation**: breadth-bound IS the FIRST Hasse-structural property check in Track 2I — exploits antichain enumeration via incomparability adjacency. Worth highlighting in dailies + Phase 10 report.

2. **Modular subsumes distributive**: type×equality on ground sublattice has distributive confirmed (Phase 3c) → modular SHOULD confirm via implication. Empirical sample-check is ALSO informative — non-vacuity ratio for modular's hypothesis (`a ≤ c`) likely differs from distributive's (always-fires).

3. **Phase 6 may surface ground-vs-binder distinction below distributive**: if type×equality binder-included sample is SD-not-distributive (Phase 4 finding), is it ALSO SD-not-modular, or modular-not-distributive? Empirically interesting refinement of the variety placement.

4. **File-size watch**: sre-core.rkt approaches 2000 lines after Phase 6. Sister concern (file split) noted; not Phase 6 scope.

**Honest scope-acknowledgments**:

- Property checks remain off-network (Track 2G scaffolding lineage; retirement = property-cells migration, sister track)
- Property registry granularity gap inherited (Phase 4 finding)
- Hasse-structural exploitation is partial — only breadth-bound; modular/Whitman's W don't exploit lattice topology

**Drift risks (consolidated, 7 items)**:

1. **Asymmetric meet/join lookup** (Phase 4 risk #1, recurring): callers derive both fns from same relation
2. **Whitman's W hypothesis non-vacuity**: `a ∧ b ≤ c ∨ d` may rarely fire on type lattice ground sublattice; /detailed surfaces honestly
3. **Breadth perf at wider sample**: O(N^(k+1)). Cap sample size if needed; default k=4
4. **Modular-distributive trivial-confirm**: when distributive confirms, modular auto-confirms; non-vacuity ratio distinguishes trivial vs genuine confirmation
5. **Phase 6 size approaching 1h boundary**: ~200-300 LoC; sub-phase 6a/6b/6c fallback ready
6. **/detailed proliferation**: only modular + Whitman's W warrant /detailed; breadth + sectional simple axiom-*
7. **File-size watch**: sre-core.rkt at ~2000 lines after Phase 6 — sister concern, not blocker

### Phase 7: Generator extension — session domain

**Scope** (high-level):

Extend `sre-sample-generator.rkt`'s `build-atoms-by-spec` to populate atom pools for the session domain. Audit ctor-descs in `session-lattice.rkt` / `session-propagators.rkt`; identify which slots take which lattice-specs; design realistic session atom pool: candidates `close`, `send-T` for atomic `T`, `recv-T`, `select` with branches, `offer`, recursive `mu`. Recursive types may need depth-bound special handling.

**Estimated scope**: ~30-60 LoC generator extension + ~20 LoC atom pool design + ~20 LoC tests.

### Phase 8: Generator extension — form domain

**Scope** (high-level):

Audit ctor-descs in `form-cells.rkt`; design realistic form atom pool. Form has nested-pipeline structure (forms-of-forms, polynomial-functor shape per Pocket Universe pattern) that may exhibit binder-like scope-sensitivity — sweep results may surface a 4th Scaffolding-Hides-Scope instance if `form-cells.rkt:503`'s Heyting declaration is over-broad relative to the design body's scope intent.

**Estimated scope**: ~30-60 LoC generator extension + ~20 LoC atom pool + ~20 LoC tests.

### Phase 9: Comprehensive sweep + findings synthesis

**Scope** (high-level):

Run `run-sd-sweep` (now extended to all 7+ properties via Phase 5+6 additions) across all SRE-registered `(domain, relation)` pairs:

- `type × equality`, `type × subtype` (already swept in Phase 3)
- `session × equality` (after Phase 7 generator extension)
- `form × equality` (after Phase 8)
- `mult × equality` (3-element lattice — exhaustive at depth-0)

Captures expanded findings into design doc § Phase 9 Findings (replacing § Phase 3 Findings as the comprehensive table). Per-property non-vacuity ratios surface evidence-strength asymmetries (Phase 4 finding for SD-vee 3.5% vs SD-wedge 91.4%).

Cross-references each finding to PTF Lattice Hierarchy note §5.1+§5.2 (which level unlocks which capability). Identifies any new Scaffolding-Hides-Scope instances surfaced by the wider sweep.

**Estimated scope**: ~30 LoC sweep harness updates + ~50 LoC findings synthesis (markdown table + interpretation).

### Phase 10: Lattice Variety Report (presentation document for Prof. Nation)

**Scope** (high-level):

New Stage 0/1 research note `docs/research/YYYY-MM-DD_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md`. Cross-linked from PTF master Research Documents table.

**Content shape**:

1. **Domain × variety placement table**: each Prologos lattice (type/session/form/mult × equality/subtype) placed in the hierarchy (free → SD → modular → distributive → Heyting → Boolean), with empirical evidence cited per cell.
2. **Per-domain narrative**: type lattice (with binder-boundary scope-sensitivity finding prominently); session lattice; form lattice; mult lattice. Honest about what's confirmed, what's refuted, what's inconclusive on current samples.
3. **Quantale framing**: explicit on type and session domains; clarifies orthogonality with lattice-distributivity (Track 2H quantale + SD-not-distributive at binder boundary).
4. **Connection to canonical-form theory**: which algorithms apply per variety (Whitman six-case for free; Reading-Speyer-Thomas for SD; DNF/Birkhoff for distributive; Heyting → for relative pseudo-complement). Cites Theorems 1.17 (canonical form), 1.21 (Jónsson-Kiefer-Nation).
5. **Worked examples + witnesses**: Pi-typed counterexample to distributivity; non-vacuity ratios; ground-vs-binder distinction; any session/form witnesses surfaced.
6. **Open research questions**: dependent-type-distributivity recovery (PTF research note C); substructural-logic non-distributivity (B); quantale distributivity laws (A) — framed as conversation starters with Nation.
7. **References**: Freese-Ježek-Nation 1995 explicitly + theorem citations + adjacent literature (Reading-Speyer-Thomas 2019; Adaricheva-Gorbunov-Tumanov 2003; Galatos-Jipsen-Kowalski-Ono).

**Tone**: report what we have, not pedagogy. Nation has full theoretic background; the value is empirical characterization of our system.

**Estimated scope**: ~500-1000 lines markdown.

### Phase T: Dedicated test file

**Goal**: `tests/test-sre-sd-properties.rkt` consolidating SD-specific tests:
- Constructed lattice fixtures known SD / non-SD (positive + negative golden tests).
- Per-domain confirmation tests (Heyting domains via implication, non-distributive empirically).
- Counterexample regression tests: if Phase 3 found a refuted SD on type-equality with witness `(a, b, c)`, the test asserts the witness still refutes — so any future merge-function change that "accidentally fixes" SD becomes a noticed test-failure rather than silent acceptance.

**Test coverage**: full coverage of the SD test path; no new behavior beyond what's tested elsewhere, so no exemption clause.

Estimated scope: ~150-250 LoC. ~30-45 min.

### Discussion (out-of-band)

After Phase 3 + T close, we sit with the empirical findings and discuss whether to:
- Update declared-properties at registration sites (declaring `sd-vee` / `sd-wedge` confirmed where applicable).
- Note any counterexample triples as design questions for future work.
- Decide whether the variety-identification track (Note A §8) is now ready to open or still gated on PPN 4.

This is explicit out-of-band scope — NOT a phase, NOT in the implementation tracker. Captured here so the discussion intent is recorded.

---

## Stage 0 Mantra Audit

> "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."

| Word | Audit | Resolution |
|---|---|---|
| All-at-once | SD checks iterate triples (a, b, c) — sequential `for/fold`. | Off-network by design. Same pattern as existing Track 2G distributivity check. **Labeled scaffolding** — would migrate to network-side property cells if/when the property registry itself migrates. Tracked in Track 2G's existing scaffolding lineage; not new debt. |
| All in parallel | Sequential triple sweep. | Same as above — off-network test infrastructure, parallelizable later if perf-material. Phase 3 may surface perf data. |
| Structurally emergent | Empirical sample-check, not lattice-derived. | This is the *point* of the check — empirical sample-checking is the methodology for un-declared algebraic properties. Constructive proofs would be a different and much larger track. |
| Information flow | Property values flow through declarations → inference → derivation → reporting. Off-network in the cell-id sense; on-data-flow in the inference-pipeline sense. | Existing Track 2G pattern. No deviation. |
| ON-NETWORK | Property checks themselves are off-network. | **Explicitly labeled scaffolding** with retirement direction (property cells migration), parallel to all existing Track 2G algebraic-property checks. No new architectural commitment. |

**Verdict**: this track does NOT advance on-network status of property checking. It extends an existing off-network mechanism that is already labeled as scaffolding. Retirement plan inherits from Track 2G's existing position. **No mantra-violation drift introduced.** Adversarial framing: *"could this be more on-network?"* — yes, by migrating the entire property-check infrastructure to propagator cells, which is a separate larger track. Not in scope here.

---

## P/R/M/S Light Pass

Per user direction (light Stage 3): no formal critique rounds. One-pass scan against each lens for sanity:

- **P (Principles)**: no new principle-level commitments. Mirrors Track 2G's existing principle stance (off-network sample-check with explicit labeling). ✓
- **R (Reality-Check)**: audit complete (§ Stage 2 Audit). Touches 1 file (`sre-core.rkt`) primarily, plus 4 registration sites (Phase 4 only — not in this track). 5 files at most across all phases. Scope realistic. ✓
- **M (Propagator-Mindspace)**: not propagator work. Off-network test infrastructure. Network Reality Check N/A. ✓ (no propagators to install; result is property-data, not cell-flow).
- **S (Structural — SRE / Hyperlattice / Module-theoretic / Variety+CanonicalForm)**: this IS S-lens work. The SD properties extend the Track 2G algebraic-property registry. Variety placement reasoning explicit in Stage 2 Audit. Hyperlattice optimality claim NOT advanced (no canonical-form algorithm in scope). Module-theoretic NOT advanced (no new bridges, no new ring action). Free-lattice / variety NOT advanced as a constructive matter — empirical only. ✓ (S-lens applied; advances are scoped and labeled).

---

## Drift risks (named upfront, per Stage 4 step 1)

1. **"We added the property but didn't actually use it"**: Phase 3 reports findings but does NOT update declared-properties at the registration sites. The use happens in the post-discussion pass. *Mitigation*: explicit "Discussion" entry in the progress tracker as out-of-band scope — names the gap, doesn't disguise it.
2. **"Sample set is too small to find counterexamples"**: Phase 2's generator must size sample sets such that 3-tuples cover the constructor space at depth ≥ 2. *Mitigation*: Phase 2 includes depth-bound + per-constructor representative coverage; not a single hand-picked list.
3. **"Heyting-via-implication confirms SD trivially, no empirical value"**: the *interesting* sweep is on non-distributive domains. *Mitigation*: Phase 3's findings table separates "via implication" from "via empirical sweep" so reviewer can see which are which.
4. **"Adding test-runtime to the SRE registration path"**: SD check is O(|samples|³). For 30 samples, 27k iterations per domain × relation. *Mitigation*: SD checks run in `infer-domain-properties` only when explicitly invoked; production code paths don't auto-run them. If perf-material later, gate behind a `--diagnostic` flag.
5. **"Stage 4 phase boundary discipline slipping into all-at-once"**: small track, easy to be tempted to do all phases in one stretch. *Mitigation*: per `workflow.md` "Conversational implementation cadence", check in with user between phases. Each phase produces a dialogue checkpoint.

---

## References

- Source research: [LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md §5.4](../research/2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md)
- Track 2G design (template): [SRE_TRACK2G_DESIGN.md](2026-03-30_SRE_TRACK2G_DESIGN.md), [PIR](2026-03-30_SRE_TRACK2G_PIR.md)
- Track 2H design (template): [SRE_TRACK2H_DESIGN.md](2026-04-02_SRE_TRACK2H_DESIGN.md), [PIR](2026-04-03_SRE_TRACK2H_PIR.md)
- Free Lattices Ch I (Theorem 1.21 Jónsson-Kiefer 1962): [companion](../learning/freelat-companion-ch01.html#s3)
- Reading-Speyer-Thomas 2019 (finite SD lattices canonical form) — for a future variety-identification track, NOT in scope here
- `.claude/rules/workflow.md` — phase completion 5-step, conversational cadence, dedicated test phase
- `.claude/rules/structural-thinking.md` — SRE Lattice Lens (S-lens application)
- `docs/tracking/principles/DESIGN_METHODOLOGY.org` § Stage 4 — implementation protocol followed for this track
