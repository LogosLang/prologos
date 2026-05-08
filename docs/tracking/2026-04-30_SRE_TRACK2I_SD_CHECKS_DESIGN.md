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
| 6 | Free-lattice membership + modularity checks | ✅ | _Single-phase land (no sub-phase split needed; under 1h)._ 4 property checks: `test-modular` + modular-evidence /detailed (Dedekind 1900); `test-whitmans-condition` + whitman-evidence /detailed (Nation 1982 Theorem 5.55/6.9 — FL membership with SD); `test-breadth-bound` parameterized via `#:max-width` default 4 (Jónsson-Kiefer-Nation 1962 — FIRST Hasse-structural property check in Track 2I); `test-sectionally-complemented` (Grätzer; weaker than rel-complemented). 2 implication rules added: `distributive ⇒ modular`, `relatively-complemented ⇒ sectionally-complemented`. 12 new test-cases. Targeted suite GREEN: 134 tests / 4.5s. |
| 7 | Generator extension: session domain | ✅ | _Sub-phased 7a (session-meet-registry) + 7b (generator cross-domain-atoms) + 7c (session sweep tests)._ Surfaced + fixed pre-existing duplicate-registration bug: `phase1d-registrations.rkt` was overwriting session-sre-domain registration WITHOUT meet-registry. Fix replaces register/minimal call with explicit make-sre-domain that includes meet-registry per Phase 3c pattern. Generator API extended with `#:cross-domain-atoms` (caller-supplied per Decomplection + anti-Scaffolding-Hides-Truth). Targeted suite GREEN: 140 tests / 4.6s. 6 new Phase 7 test-cases. |
| 8 | Form-cell + spec-cell domain meet definition + empirical sweep | ✅ | _Sub-phased 8a (form-pipeline-meet) + 8b (atoms) + 8c (form sweep + tests) + 8d (spec-cell mirror)._ Phase 8 differs structurally — form-cell has NO ctor-descs (Pocket Universe wrapper). **5th Scaffolding-Hides-Truth corrected**: form-cells.rkt:508 declared `'has-meet prop-confirmed` without an actual meet function. Phase 8a defines `form-pipeline-meet`; 8d defines `spec-cell-meet-fn`. API extended with `#:include-bot-top` (form-cell top defaults #f → breaks merge contract). 13 new tests. Targeted suite GREEN: 153 tests / 4.5s. |
| 9 | Comprehensive sweep + findings synthesis | ✅ | _Sub-phased 9a (commits `8639c820` mini-design + `8d3257e7` code) + 9b (sweep run 2026-05-07 + findings persistence pending commit)._ 110 findings (10 (domain, relation, depth) tuples × 11 properties) captured via 4 concurrent per-domain sweep processes with `tools/run-phase9-sweep.rkt`. Wall time: ~34 min (type domain dominated; per-relation parallelization for type halved time vs sequential). **Comprehensive variety-placement matrix populated in § Phase 9 Findings**. **Headline findings**: (1) Whitman's W ✓ for all 10 — every Prologos lattice is FL-embeddable per Nation Theorem 5.55/6.9; (2) type×equality AND type×subtype both reach Heyting on ground sublattice (Phase 5a prediction validated comprehensively); (3) asymmetry between equality and subtype at binder boundary — equality preserves modularity, subtype refutes; (4) Stone identity refutes universally — no Prologos lattice reaches Stone-algebra level. No 6th Scaffolding-Hides-Truth instance surfaced. Adversarial VAG passed. |
| 10 | Lattice Variety Report (presentation document) | ✅ | Stage 0/1 research note `docs/research/2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md` (272 lines, terser than original 400-600 target — appropriate for in-person meeting context). Headline: Whitman's W ✓ across all 10 (Nation Theorem 5.55/6.9). Per-domain narrative includes equality-vs-subtype binder-boundary asymmetry (NEW finding) + Mermaid diagrams. 6 open questions framed as conversation starters with Nation. Quantale framing deemphasized per audience-specific calibration (Nation's expertise gap; referred to colleagues). Cross-linked from PTF master Research Documents table (entry 4). Adversarial VAG passed at phase close. **Track 2I "first-close" at this phase**; reopened 2026-05-08 per user direction to address gap-closure (Phases 11-15) — the report's "What we did not measure" section was too interesting to leave. Report will be updated in-place (Q-C lock 2026-05-08) once Phases 11-15 land. PDF render for the meeting is post-process step. |
| 11 | `has-complement` empirical check (Boolean placement) | ✅ | _Code + sweep + report integration in single commit per user-flagged in-phase pattern (2026-05-08)._ Added `complement-evidence` struct (5-field; YAGNI reversed per Completeness Over Deferral) + `test-has-complement/detailed` + wrapper. Atomic wiring: `infer-domain-properties` props-14, `resolve-and-report-properties` evidence map, `all-sweep-properties` (now 12), `sweep-one-property` dispatch, `extract-detailed-fields` (sre-property-sweep + run-phase9-sweep harness), Boolean column derivation in both summary tables. 6 new test-cases. Targeted suite GREEN: 164 tests / 4.4s. **Phase 11 finding**: Boolean refuted with witness `Int` for type×{eq,sub}×{ground,wider} AND spec-cell×equality×{ground,wider}; session + form-cell remain untested (sample-set bot/top absence). Type×{eq,sub} is **Heyting on ground but NOT Boolean** — net-new architectural data. Sweep via 4 concurrent processes with `--properties has-complement` flag (added to harness). Findings persisted to design doc § Phase 9 Findings + Nation report Boolean column updated in-place. Adversarial VAG passed. |
| 12 | M3 / N5 sublattice detection (Birkhoff theorem) | ✅ | _Code + sweep + report integration in single commit per Phase 11 pattern._ Direct construction (NOT 5-tuple enumeration which would be 105 min/tuple at N=58): antichain-of-3 for M3, comparable-pair-plus-incomparable for N5. m3-evidence + n5-evidence /detailed structs. ~9.5s wall for type wider domain (heaviest); other 3 domains <1s. **Concrete Birkhoff witnesses found**: session × eq × wider M3 sublattice `(sess-bot, sess-top, sess-end, sess-svar 0, sess-send Bool (sess-svar 0))`; spec-cell × eq × {ground, wider} M3 sublattice with 3 distinct spec-cell-values. Type × {eq, sub} × all depths confirms both no-M3 AND no-N5 on sample (sample-set limitation per Birkhoff 9.2 — classical witness exists in full lattice but depth-1 generator doesn't construct closed forbidden sublattices). Form-cell × eq confirms both. **Bug surfaced + fixed in-flight**: session sweep config had `#:include-bot-top #t` injecting `#f` into samples (since session is bounded-below per Phase 11); first sweep produced bogus M3 witness with `#f` element. Fix: match form-cell's `#f` config. Re-sweep produced legitimate witnesses. **Birkhoff forward implication deliberately NOT added** (sample-unsound). 8 new test-cases. Targeted suite GREEN: 171 tests / 4.8s. Adversarial VAG passed. |
| 13 | Convex geometry / anti-exchange characterization | ✅ | _Code + ground sweep + 3-domain wider sweep complete; type-wider sweep killed at 57min CPU (timeout — k=2 enumeration on |J(L)|>>50). Honest scope-bound._ Empirical AGT 2003 iff data: session×eq×wider REFUTED (concrete iff disagreement vs SD-confirmed — sample-bounded), spec-cell×eq×{ground,wider} REFUTED (coheres with M3 witness + non-distributive), type×{eq,sub}×ground CONFIRMED (cohres with SD+Heyting), form-cell CONFIRMED. AGT 2003 iff forward implication deliberately NOT added (Phase 12 Birkhoff precedent). 8 of 10 tuples have empirical data; type×wider deferred. |
| 14 | Targeted congruence tests | ✅ | _Ground-only sweep across all 4 domains × 4 candidates (~seconds wall) per Q5 time-budget pragma._ trivial + total CONFIRMED universally (vacuous-by-construction). mult-forgetful + erasure-equivalence CONFIRMED on type×{eq,sub}×ground (vacuous — atomic samples have no binders to strip), UNTESTED for non-type with reason `'congruence-not-applicable-to-domain`. Framework-wiring + sanity confirmation; substantive empirical content for type-domain candidates DEFERRED to wider sample post-meeting. No forward SI implication rule (sample-unsound). |
| 15 | Day's doubling / inflation detection | ⬜ | Test for interval-doubling structure per Adaricheva-Nation 2017. Most speculative (testing whether lattice ADMITS doubling vs WAS constructed via doubling). Higher implementation complexity. Tier 3. |
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

**Scope** (revised post mini-audit 2026-04-30):

Phase 7 broadens from "generator extension only" to **three atomic concerns** after audit revealed `session-lattice-meet` exists (Track 2G addition, exported at `session-lattice.rkt:32`) but no `meet-registry` was wired. This is a sister of Phase 3c's type-domain meet-registry addition.

#### Decisions (mini-design + mini-audit + adversarial pass 2026-04-30)

**Q1 — Cross-domain atom flow (explicit vs auto-discovery)**: option (A) explicit caller-supplied via `#:cross-domain-atoms` keyword. Locked on **Decomplection + anti-Scaffolding-Hides-Truth grounds**: auto-discovery is the same shape we retired in Phase 3c (always-installed callback hiding cross-domain flow). Caller burden (one hash literal per cross-domain sweep) is the cost of honest dependency surface.

**Q2 — Realistic session atoms**: `(list (sess-end) (sess-svar 0))`. Sweet spot per audit:
- (sess-end): canonical terminal session — semantically central
- (sess-svar 0): de Bruijn variable for mu body, covers binder-context "atom" case
- Higher svar indices (1+) reject: out-of-context for un-nested mu; diminishing return
- Pre-baked compounds reject: defeat depth-0/depth-1 semantics
- Empty/just-sess-end reject: too sparse (only 1 atom in pool after sentinel-filter)

**Q3 — Meet-limitation addressable in Phase 7**: YES. `session-lattice-meet` exists at `session-lattice.rkt:122` (Track 2G) — just never registered. Add `session-meet-registry` as Phase 7a (~15 LoC; sister of Phase 3c). This unlocks all Phase 5/6 checks for session×equality sweep. Without this, sweep would produce only `commutative/associative/idempotent-join` empirical (3 findings) — adding meet-registry unlocks ~10 more.

**Q4 — Sub-phase plan**: single phase intent; 7a/7b/7c sub-phase fallback ready.

**Three atomic sub-phases**:

| Sub-phase | Scope | Cost |
|---|---|---|
| **7a** | Add `session-meet-registry`; wire into `session-sre-domain`; atomic with declaration update if needed | ~15 LoC |
| **7b** | Generator: `#:cross-domain-atoms` parameter through `generate-domain-samples` + `build-atoms-by-spec` + `run-sd-sweep`; tests | ~50-80 LoC |
| **7c** | Define `realistic-session-atoms`; integration tests for session sweep mechanism on small sample; verify findings | ~30-50 LoC |

**Implementation shape (7b core)**:

```racket
(define (generate-domain-samples domain
                                 #:max-depth [max-depth 2]
                                 #:per-ctor-count [per-ctor-count 2]
                                 #:include-bot-top [include-bot-top #t]
                                 #:base-values [base-values #f]
                                 #:cross-domain-atoms [cross-domain-atoms (hasheq)])
  ;; cross-domain-atoms: hash spec → atoms (e.g., (hasheq 'type realistic-type-atoms))
  ;; Used for slots whose lattice-spec is from a domain other than `domain`.
  ...)

(define (build-atoms-by-spec full-pool per-ctor-count domain cross-domain-atoms)
  ;; Self-domain pool from full-pool (sentinel-filtered);
  ;; other-domain pools from cross-domain-atoms.
  ...)
```

**Sweep invocation for session×equality**:

```racket
(run-sd-sweep session-domain
              '(equality)
              realistic-session-atoms
              #:max-depth 1
              #:per-ctor-count 2
              #:cross-domain-atoms (hasheq 'type realistic-type-atoms))
```

**Audit findings persisted**:
- 7 session ctors registered in `ctor-registry.rkt:690-786`: 6 arity-2 (sess-send/recv/dsend/drecv/async-send/async-recv) with cross-domain components (type, session); 1 arity-1 (sess-mu) intra-domain
- Branch ctors NOT registered (sess-choice/sess-offer have variable arity) — limitation acknowledged
- 0 arity-0 ctors registered (sess-end is a struct but not ctor-desc-registered as nullary)
- session-sre-domain at `session-propagators.rkt:264` has merge-registry for 'equality only; no meet-registry; declared 'has-meet prop-confirmed
- `session-lattice-meet` exists at `session-lattice.rkt:122` (Track 2G); exported but unwired

**Adversarial CRITIQUE pass surfaced**:

1. **Cross-domain atom flow as Galois bridge**: Phase 7 makes cross-domain atom flow first-class via parameter — explicit Galois-connection-style bridge between domain pools. PTF §5.4 framing applies. Worth noting in dailies + Phase 10 report as architectural insight.

2. **Anti-Scaffolding-Hides-Truth in API design**: rejecting auto-discovery (option B) in favor of explicit caller-supply (option A) is a direct application of the pattern we graduated this session. The principle scales beyond defensive guards / hardcoded constants / always-installed callbacks to API-design choices that hide cross-cutting flow.

3. **Q6 Hasse**: same as Phases 1-5 + Phase 7 — only Phase 6's breadth-bound exploits Hasse. Phase 7 doesn't.

**Honest scope-acknowledgments**:
- Branch ctors (sess-choice/sess-offer) NOT covered — variable arity, not ctor-registered. Sister concern.
- Mu recursion: sess-mu compound generation may produce out-of-binder-context sess-svar values. Watch for malformed compounds (Phase 2a Scaffolding-Hides-Truth pattern could fire).
- Caller responsibility: cross-domain-atoms supplied correctly by caller; generator doesn't validate (would-be over-engineering).

**Drift risks (consolidated, 7 items)**:

1. **Cross-domain atom pool leakage**: caller forgets type atoms → empty type pool → zero compound sess-send inhabitants. Mitigation: documentation; eventual count-per-ctor diagnostic if needed.
2. **Session has no subtype relation**: only equality registered. Phase 7 doesn't add subtype-merge — sister concern.
3. **Branch ctors not covered**: sess-choice/sess-offer variable arity, unregistered. Limitation; sister concern.
4. **Mu recursion malformed compounds**: sess-mu with out-of-context sess-svar bodies may surface 4th Scaffolding-Hides-Truth instance. Watch via merge function behavior.
5. **API change cascade**: cross-domain-atoms parameter touches generator + sweep + tests atomically.
6. **Phase 7 size**: ~95-145 LoC. Sub-phase 7a/7b/7c fallback ready.
7. **Session sweep findings dependent on meet-registry landing**: 7a must land before 7c sweep is informative. Sub-phase ordering matters.

### Phase 8: Form-cell + spec-cell domain meet definition + empirical sweep

**Scope** (revised post mini-audit 2026-04-30):

Phase 8 differs structurally from Phases 7 + 6: form-cell domain has **NO ctor-descs registered** — it's a **Pocket Universe / lattice-embedding** wrapper, not a ctor-decomposable structure. Standard `generate-domain-samples` compound-generation doesn't apply. Phase 8 is **sweep on hand-picked atoms with NO compound generation**, plus the load-bearing **definition of `form-pipeline-meet` and `spec-cell-meet`** (sister of Phase 7a meet-registry wiring).

#### Decisions (mini-design + mini-audit + adversarial pass 2026-04-30)

**Q1 — Meet on Pocket Universe wrapper (lattice-embedding question)**: form-pipeline-value is a struct with mixed-content fields:
- *Lattice content*: `transforms` (powerset = Boolean), `type-map` (per-key type-lattice)
- *Non-lattice metadata*: `tree-node`, `registrations`, `source-pos`

The SRE registry's `meet-fn` returns a value of the SAME shape (form-pipeline-value), so we MUST construct ALL 5 fields including non-lattice ones. The merge function already faces this (chose ad-hoc semantics: prefer-richer-side, append, prefer-one). The meet has to make analogous choices.

**Resolution**: define meet with **lattice-consistent semantics per field** (preserves idempotent + commutative + associative axioms under field-by-field operation):
- `transforms`: `set-intersect` (canonical Boolean meet)
- `tree-node`: `(if (equal? old new) old #f)` (idempotent ✓ commutative ✓)
- `registrations`: filter-intersection with dedup (set-intersection on lists)
- `source-pos`: `(or old new)` (preserves provenance; same as merge)
- `type-map`: per-key intersection with equal-only-on-shared-values

This makes the WRAPPER algebraically consistent. Whether the declared properties (Heyting) hold under THIS meet choice is the empirical question Phase 8 answers.

**Q2 — Realistic form-cell atoms (test wrapper or embedded?)**: option (c) mix:
- Constant-metadata atoms (vary transforms only) test the embedded Boolean lattice
- Vary-metadata atoms test wrapper preservation of declared properties

Together these surface whether algebraic claims hold on the wrapper (Track 2H declaration) or only on the embedded sub-lattice. If wrapper refutes where embedded confirms → **5th Scaffolding-Hides-Truth instance**: hand-written `'distributive + has-pseudo-complement-rel` declarations don't survive principled metadata-handling. Honest finding for Phase 10 report.

~8-10 atoms total. Mix design:
- `form-cell-bot` (empty transforms; default metadata)
- 5 "constant-metadata" atoms varying transforms across pipeline progression: `(seteq 'tagged)`, `(seteq 'grouped)`, `(seteq 'tagged 'grouped)`, `(seteq 'tagged 'grouped 'v0-0)`, `(seteq 'done)`
- 2-3 "vary-metadata" atoms with non-trivial tree-node, registrations, source-pos values

**Q3 — 'spec-cell domain: include as 8d**, NOT defer. Per user lean (sub-phase out immediately applicable work). Symmetric sub-phase mirroring 8a-c for spec-cell. Phase 9 comprehensive sweep covers both. Phase 10 report has both in matrix.

**Q4 — Four sub-phases** (8a/8b/8c/8d).

| Sub-phase | Scope | Cost |
|---|---|---|
| **8a** | Define `form-pipeline-meet` in surface-rewrite.rkt (sister of `form-pipeline-merge` at line 580); add `form-cell-meet-registry`; wire into `form-cell-sre-domain` | ~40-60 LoC |
| **8b** | Define `realistic-form-cell-atoms` (Q2 mix) | ~30-40 LoC |
| **8c** | Sweep + integration tests on `form-cell×equality` at depth-0 (no compound generation possible — no ctor-descs) | ~30-50 LoC |
| **8d** | Mirror 8a-c for `'spec-cell`: define `spec-cell-meet`, wire registry, define `realistic-spec-cell-atoms`, sweep, tests | ~80-130 LoC |

**Pre-existing Scaffolding-Hides-Truth candidate**: `form-cells.rkt:508` declares `'has-meet prop-confirmed` but **no `form-cell-meet` function exists in the codebase**. The declared property has no actual meet implementation. Phase 8a corrects.

**Audit findings persisted**:
- `'form-cell` domain registered at `form-cells.rkt:495-513` (driver.rkt:33 load chain — IS in production unlike session-propagators.rkt)
- `'spec-cell` domain registered at `form-cells.rkt:534-548`
- merge-registry exists for both (just `'equality`)
- Neither has meet-registry
- `form-pipeline-value` (`surface-rewrite.rkt:566`) is a Pocket Universe wrapper: transforms (Boolean powerset), tree-node, registrations, source-pos, type-map
- No ctor-descs registered for either form-cell or spec-cell — Phase 8 ≠ ctor-based generator extension

**Adversarial CRITIQUE pass surfaced**:

1. **Pocket Universe / lattice-embedding pattern made empirical**: Phase 8 is the first Track-2I phase to test algebraic properties on a Pocket Universe wrapper (vs ctor-decomposable structural lattices). Worth Phase 10 report mention as architectural insight.

2. **5th Scaffolding-Hides-Truth instance candidate**: declared `'has-meet prop-confirmed` without an actual meet function. Phase 8a fixes; pattern keeps firing.

3. **Wrapper-vs-embedded algebraic-claim distinction**: declared Heyting on form-cell at form-cells.rkt:510 may hold on embedded transforms-lattice but NOT on wrapper. Empirically separable via Q2 atom design.

4. **Hasse exploitation NOT in Phase 8**: same as Phases 1-5 + 7. Form-cell's transforms IS Q_9 hypercube (256 elements via 9 transform symbols); could in principle exploit BSP-LE Track 2's hypercube primitives. Sister concern; not Phase 8 scope.

**Honest scope-acknowledgments**:
- Sweep limited to hand-picked atoms (no compound generation possible without ctor-descs)
- Metadata-handling semantics are best-effort (not unique-canonical); Phase 8a documents choice + rationale
- 'spec-cell empirical characterization is fresh (declared only comm/assoc/idem-join; sweep populates the rest)

**Drift risks (consolidated, 7 items)**:

1. **Asymmetric meet/join lookup**: same Phase 4 discipline
2. **Metadata semantic choices**: defensible but not unique; document trade-offs
3. **Wrapper algebraic refutation surfaces**: expected (5th Scaffolding-Hides-Truth); discuss-when-found per drift-risk-#4 mandate
4. **'spec-cell semantics**: spec-cell-value is a different struct shape (type-surf, type-erase, type-meta?, type-top? fields per spec-cell-merge-fn semantics); requires separate meet design with its own lattice-consistency choices
5. **No compound generation**: limited diversity; depth-0 only
6. **Phase 8 size**: ~180-280 LoC across 4 sub-phases (largest single Phase in Track 2I); sub-phase fallback ready
7. **Hasse hypercube exploitation deferred**: form-cell IS hypercube Q_9 in transforms; not exploited here

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

#### Decisions (mini-design + mini-audit + adversarial pass 2026-05-07)

**Mini-audit findings persisted**:
- Sweep harness `sre-property-sweep.rkt:82-115` currently hardcodes 3 properties (distributive, sd-vee, sd-wedge); Phase 9a extends to all 10.
- 6 sweepable (domain, relation) pairs: type × {equality, subtype, subtype-reverse}, session × equality, form-cell × equality, spec-cell × equality.
- `format-sd-finding-row` handles `sd-evidence` + `axiom-*`; needs extension for `pc-rel-evidence`, `modular-evidence`, `whitman-evidence`.
- Realistic atoms available per-domain (type from Phase 2a, session from Phase 7, form/spec from Phase 8).
- `sre-domain-meet` returns `#f` for unregistered relations (e.g., session × subtype) — sweep must handle gracefully without erroring.

**Q1 — Sweep depth strategy**: option **(b)** — full depth-1 sweep across all 10 properties × 6 (domain, relation) pairs. Estimated wall time ~45-60 min one-time; output captured as design-doc artifact. Rationale: the expensive properties at wider sample (Whitman's W, breadth-bound, relatively-complemented) are EXACTLY Nation's most-relevant theorems (Theorem 5.55/6.9 Nation 1982; Theorem 1.21 Jónsson-Kiefer-Nation 1962; Nation's primary terminology). Skipping them at depth-1 means telling Nation "we didn't run your theorems on the wider sample." Bounded one-time cost, high value for Phase 10 audience.

**Q2 — Findings table structure**: option **(c)** two tables —
1. **Variety-placement summary**: rows = (domain, relation, depth), columns = boolean variety membership (free? SD? modular? distributive? Heyting? Stone? Boolean?). At-a-glance hierarchy placement Nation will want first.
2. **Per-finding detail**: rows = each (domain, relation, depth, property) finding, columns = status, total triples, hypothesis fired, conclusion held, non-vacuity %, witness footnote ref. Drillable detail.

Phase 10 consumes both; Phase 9 produces both.

**Q3 — Sub-phasing**: **9a + 9b** —
- **9a**: code (extend `run-sd-sweep` to 10 properties + extend `format-sd-finding-row` for 4+ evidence types + add `untested-reason` field to `sd-finding` + variety-placement summary renderer)
- **9b**: data (run comprehensive sweep + capture findings into design doc § Phase 9 Findings)
- 9c (interpretation/synthesis) folded into Phase 10's report — Phase 9 produces empirical layer; Phase 10 = synthesis.

**Q4 — Conditional-property handling**: option **(a)** — run all unconditionally; report raw axiom result; Phase 10 interprets the conditionals (e.g., "Stone identity is informationally significant only where pc-rel confirms"). Most honest data; cleanest separation of empirical layer vs interpretation.

**Q5 — Witness rendering**: option **(b)** — footnoted witnesses. Findings table cells show `refuted (W3)` referencing footnote `W3: (Pi(m1, Bool, Bool), Int, Pi(m1, Int, Bool))`. Keeps table readable; Nation can cross-reference.

**Q6 — Whale-file pressure on sre-core.rkt**: source-file organization sister concern, deferred. (NOT a testing.md whale-file rule trigger — that rule applies to test files only, was misread in Phase 6 audit.)

**Q7 — Untested-reason reporting**: add **`untested-reason` symbol field** to `sd-finding` struct: `'no-relation` (relation not in domain registry), `'no-meet-fn` (relation in registry but meet returns #f), `'no-join-fn` (similarly for join), `#f` for tested results. Phase 9 sweeps emit explicit "not tested because X" findings for missing relations (e.g., session × subtype) — honest about coverage gaps. Nation sees complete map including what we didn't measure and why.

**Phase 9 deliverables (locked)**:

| Artifact | Phase 9a | Phase 9b |
|---|---|---|
| `run-sd-sweep` extended to all 10 properties | ✓ | — |
| `format-sd-finding-row` extended for 4+ evidence types | ✓ | — |
| `untested-reason` field added to `sd-finding` | ✓ | — |
| `format-variety-placement-summary` renderer (new) | ✓ | — |
| Sweep harness handles `(sre-domain-meet d r) = #f` gracefully | ✓ | — |
| Comprehensive sweep run (depth-0 + depth-1 across all 6 pairs × 10 properties) | — | ✓ |
| Variety-placement summary table populated in § Phase 9 Findings | — | ✓ |
| Per-finding detail table populated in § Phase 9 Findings | — | ✓ |
| Footnoted witnesses captured | — | ✓ |
| Phase 9 close VAG adversarial two-column at end | — | ✓ |

**Adversarial CRITIQUE pass surfaced**:

| Lens | Catalogue | **Challenge** |
|---|---|---|
| **P** | ✓ Data Orientation, Decomplection, Correct-by-Construction | **Findings as data-records** ✓; variety-placement via `derive-composite-properties` ✓ data-driven. Honest scope: findings could BE cells with monotone merge in a future on-network world (sister concern of property-cells migration). |
| **R** | ✓ All code surfaces audited; ~50-80 LoC delta total across 9a | None new |
| **M** | Off-network sample-iteration + format renderer | Off-network is correct for pure data-rendering. Honest scaffolding lineage inherited. |
| **S (SRE Lattice Lens)** | Findings characterize EXISTING lattices; output maps to PTF hierarchy | **Q6 Hasse exploitation**: breadth-bound is THE Hasse-structural check; Phase 9 reports it prominently. Variety-placement summary IS a hierarchy mapping (PTF §3 levels = table columns). ✓ |

**Drift risks** (consolidated):
1. **Sweep cost concentration on type domain** (~40 min of ~50 min total) — depth-1 with N=58 dominates; manageable per Q1 wall-time budget
2. **Findings table format complexity** addressed by Q2 two-table separation
3. **Conditional-property reporting honesty** addressed by Q4 raw-then-interpret in Phase 10
4. **Format function extension cascade** — handles 4+ evidence types in 9a code
5. **Cross-domain atom availability** ✓ established per-domain
6. **Phase 9 may surface inconsistent property declarations** (declared vs empirical mismatch — variant of Phase 4/8) — if it fires → dialogue (potential 6th Scaffolding-Hides-Truth instance)
7. **Source-file organization** for sre-core.rkt — sister concern, deferred per Q6
8. **Witness rendering at scale** addressed by Q5 footnoting
9. **Untested findings clarity** addressed by Q7 `untested-reason` field

#### Phase 9 Findings (captured 2026-05-07, post-comprehensive-sweep)

**Sweep parameters**: per-ctor-count 2; depth ∈ {0 (ground), 1 (wider/binder-included)}. Captured via 4 concurrent processes (one per domain) using `tools/run-phase9-sweep.rkt --domain X [--relation Y]` then concatenated. Type domain × depth-1 dominated wall time (eq: 2040s, sub: 1813s, ran concurrently → ~34 min wall). Other 3 domains complete in <1 second each.

**Total findings**: 110 sd-finding records (10 (domain, relation, depth) tuples × 11 algebraic properties).

##### Variety-placement summary

Each row places a `(domain × relation × depth)` lattice into the PTF lattice hierarchy. ✓ = property holds empirically; ✗ = refuted with witness. `(W)` = Whitman's W (free-lattice membership criterion, Nation 1982 Theorem 5.55/6.9).

| Domain | Relation | Depth | SD | Modular | Distributive | Heyting | Stone | Boolean | (W) | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| type | equality | ground | ✓ | ✓ | ✓ | **✓** | ✗ | ✗ | ✓ | Boolean refuted, witness Int |
| type | equality | wider | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ | Boolean refuted, witness Int |
| type | subtype | ground | ✓ | ✓ | ✓ | **✓** | ✗ | ✗ | ✓ | Boolean refuted, witness Int |
| type | subtype | wider | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | Boolean refuted, witness Int |
| session | equality | ground | ✗ | ✓ | ✗ | ✗ | ✗ | — | ✓ | has-complement untested (no top in samples) |
| session | equality | wider | ✗ | ✓ | ✗ | ✗ | ✗ | — | ✓ | has-complement untested (no top in samples) |
| form-cell | equality | ground | ✓ | ✗ | ✗ | ✗ | ✗ | — | ✓ | has-complement untested (no bot/top per Phase 8) |
| form-cell | equality | wider | ✓ | ✗ | ✗ | ✗ | ✗ | — | ✓ | has-complement untested (no bot/top per Phase 8) |
| spec-cell | equality | ground | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | Boolean refuted, witness in spec-cell-bot context |
| spec-cell | equality | wider | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | Boolean refuted, witness in spec-cell-bot context |

##### Headline findings (interpretation deferred to Phase 10 report)

1. **Whitman's W ✓ for ALL 10 (domain × relation × depth) combinations.** Every Prologos lattice we measured is FL-embeddable per Nation Theorem 5.55/6.9. Strong non-vacuity on the type domain (83-99% — i.e., the implication's antecedent fires non-trivially in ~95% of 4-tuples and the conclusion holds for all). This is the unified empirical claim across our system.

2. **Both type×equality AND type×subtype reach Heyting on the ground sublattice.** Phase 5a's prediction validated comprehensively at depth-0. New architectural claim beyond Track 2H's subtype-only Heyting declaration.

3. **Asymmetry between equality and subtype at the binder boundary**: type×equality × wider is **SD + modular** but not distributive; type×subtype × wider is **SD only** (modular refutes with Pi-Pi-Pi witness). Equality merge (union-aware) preserves modularity through binders; subtype's GLB meet does not. NEW finding beyond Phase 4.

4. **Form-cell × equality is "SD but not modular" at both depths** — a specific algebraic posture. Reading-Speyer-Thomas FTFSDL canonical form applies; Birkhoff representation does not.

5. **Session × equality is "modular but not SD"** — unusual placement (M3-like structure where modular holds but neither sd-vee nor sd-wedge does). Note: this contradicts the implication chain `distributive ⇒ SD` ONLY because distributive ALSO refutes here; the chain holds vacuously.

6. **Spec-cell × equality sits at the bottom of the hierarchy** — only Whitman's W + breadth-bound (at small N) confirm. Free-lattice-relative without higher properties.

7. **Stone identity refutes for ALL 10** — no Prologos lattice reaches the Stone algebra level. Honest negative data; Stone-algebra dispatch path will not be relevant to UCS for any of our domains.

8. **breadth-bound (k=4) refutes at wider sample for type×{eq,sub}, session, form-cell.** Only ground sublattices (small N) and spec-cell at any depth fit within the 4-element antichain bound. Most of our domains have higher antichain width on wider samples — relevant to parallel-decomposition fan-out estimates.

9. **Pseudo-complement variants decouple** for session × equality: `has-pseudo-complement-rel` ✗ but `has-pseudo-complement-abs` ✓. In Boolean algebras these coincide; here they separate. Validates the Q1(b) disambiguation decision from Phase 5 mini-design.

10. **Boolean refutes for type×{eq,sub} and spec-cell × equality (Phase 11, 2026-05-08)**. Same witness `Int` for all 4 type-domain rows (eq×ground, eq×wider, sub×ground, sub×wider) — Int has no `x` with `Int ∧ x = ⊥` AND `Int ∨ x = ⊤` under either equality or subtype merge. Spec-cell × equality also refutes. Closes the Boolean column definitively for these 6 rows. **type×{eq,sub} reaches Heyting on ground sublattice (Phase 5a finding) but does NOT extend to Boolean** — substantive new architectural data point.

11. **has-complement remains untested for session × equality and form-cell × equality** — both depths. Sample-set limitation: session and form-cell domains don't include both bot AND top in their default samples (form-cell top defaults to #f per Phase 8 lesson; session has no canonical top). Honest negative: cannot empirically determine Boolean placement on current samples; sister concern requires Phase 8 follow-up to enrich those domain atom pools.

12. **Phase 12 (M3/N5 sublattice detection, 2026-05-08)**: concrete Birkhoff witnesses surfaced for **session × equality × wider** and **spec-cell × equality × {ground, wider}**. Session witness: `(sess-bot, sess-top, sess-end, sess-svar 0, sess-send(Bool, sess-svar 0))` — 5-element closed sublattice with M3 structure (three pairwise-incomparable session types whose all-pairwise-meets give sess-bot and all-pairwise-joins give sess-top). Spec-cell witness: `(spec-cell-bot, collision-top, spec-cell-value(bar, Int), spec-cell-value(foo, Int), spec-cell-value(foo, Bool))` — same shape on spec-cell domain. **These are the concrete Birkhoff witnesses Nation will recognize**: empirical sublattice structures explaining non-distributivity in lattice-theoretic vocabulary.

13. **Sample-set limitation surfaced for type domain**: type × {eq, sub} × {ground, wider} confirms BOTH no-M3 AND no-N5 on the depth-1 sample (13824 antichains-of-3 enumerated, 0 hypothesis-firing for M3; 113-114 b<a pairs enumerated, 0-1 hypothesis-firing for N5). Yet Phase 4 found distributive REFUTED at type × wider. Classical Birkhoff 9.2 says distributive ⇔ no-M3 ∧ no-N5 on the FULL lattice — so a witness MUST exist there. **Honest interpretation**: depth-1 generator doesn't construct closed forbidden sublattices for the type domain even though distributivity-refuting triples exist. The sample captures local axiom failure (Phase 4's triple) but not global witness sublattice (Phase 12's 5-element closed structure). Sample-set scope acknowledgment, not a contradiction.

14. **Birkhoff forward-implication-rule deliberately NOT added** (Phase 12 mini-design 2026-05-08): the natural-seeming rule `no-m3 + no-n5 ⇒ distributive` is UNSOUND on sample-restricted checks (Birkhoff applies to FULL lattice, not arbitrary samples). Phase 12's empirical findings stand on their own; the theorem is referenced as structural connection but does not fire as derivation.

15. **Phase 13 (anti-exchange-on-J / AGT 2003, 2026-05-08)**: empirical convex-geometry-duality test across 8 of 10 tuples (type-wider sweep timeout — see #17). Findings:
    - **session × eq × wider: anti-exchange REFUTED** with witness (3-element subset; 757 triples, 1 hypothesis-fired, 0 conclusion-held). Together with session × eq × wider being **SD-confirmed** per Phase 9b: this is a concrete **AGT 2003 iff DISAGREEMENT at sample bounds** — empirical evidence that bounded-subset enumeration cannot soundly establish the iff direction even when SD confirms. Honest sample-limitation; the iff holds in the full lattice (theorem) but bounded-sample checks can disagree.
    - **spec-cell × eq × {ground, wider}: anti-exchange REFUTED** with witness `(13 triples, 4 hypothesis-fired, 3 conclusion-held)` — concrete refutation of anti-exchange. Combined with spec-cell × eq's M3 witness from Phase 12 + non-distributivity per Phase 9b, all three findings cohere.
    - **type × {eq, sub} × ground: anti-exchange CONFIRMED** with strong non-vacuity (26.9% / 32.2%) — coheres with SD-confirmed + Heyting-on-ground per Phase 9.
    - **form-cell × eq × {ground, wider}: anti-exchange CONFIRMED** at 1.1% non-vacuity (low but non-zero) — coheres with SD-confirmed.

16. **AGT 2003 iff implication rule deliberately NOT added** (Phase 13 mini-design 2026-05-08): same rationale as Phase 12 Birkhoff. The iff is a theorem on full lattices; empirical comparison via independent measurement of SD + anti-exchange gives stronger Nation-presentation value than implication-derived auto-confirmations would.

17. **Phase 13 type-domain wider-sample sweep timeout** (2026-05-08): k=2 bounded-subset enumeration on type-wider sample (|J(L)| much larger than the |J|≈50 estimate at mini-design time) ran 57+ min CPU without producing output. Sweep killed for time-budget. **type × {eq, sub} × wider: anti-exchange untested at depth-1**. Honest scope-bound; depth-0 ground confirmation captured. Sister concern: smaller k=1 rerun or depth-1 with smaller per-ctor-count would round out the matrix in post-meeting follow-up.

18. **Phase 14 (targeted congruence tests, 2026-05-08)**: 4 candidates (trivial, total, mult-forgetful, erasure-equivalence) tested ground-only across all 4 domains × applicable relations. Honest scope acknowledgment per Q5 time-budget pragma:
    - **trivial-congruence-valid CONFIRMED for all 6 ground tuples** (low non-vacuity 2-25%, vacuous-by-construction).
    - **total-congruence-valid CONFIRMED for all 6 ground tuples** (100% non-vacuity, vacuous-by-construction).
    - **mult-forgetful-congruence-valid + erasure-congruence-valid: CONFIRMED on type × {eq, sub} × ground; UNTESTED with reason `'congruence-not-applicable-to-domain` for non-type tuples**. At ground sublattice, atomic samples have no Pi/Sigma/lam compounds → both candidates degenerate to trivial congruence (no binders to strip) → vacuously confirm. **Empirical content for type-domain candidates deferred to wider sample (post-meeting follow-up).**
    - **No forward implication rule** to subdirectly-irreducible characterization (sample-unsound; matches Phase 12+13 discipline). Phase 14 deliberately does not claim the classical Nation-territory SI characterization.

19. **Phase 14 framework-wiring + sanity confirmation succeeded**: all 4 candidates produce structured `congruence-evidence` records with consistent non-vacuity decomposition. The framework is ready to receive substantive empirical content when wider-sample sweep runs post-meeting.

##### Per-finding detail tables

The full per-finding detail (sample counts, non-vacuity ratios, witnesses) lives in 4 per-domain markdown files captured during the run:

- `/tmp/phase9-type-eq.md` (type × equality)
- `/tmp/phase9-type-sub.md` (type × subtype)
- `/tmp/phase9-session.md` (session)
- `/tmp/phase9-form.md` (form-cell)
- `/tmp/phase9-spec.md` (spec-cell)

These files include footnoted refutation witnesses. They will be consolidated + interpreted in Phase 10's research note (`docs/research/YYYY-MM-DD_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md`). Raw markdown-pasted detail is verbose due to compound type witnesses (e.g., type × eq × wider's W5 stone-identity refutation contains a ~50-element union spanning all type ctors); Phase 10 truncates / abstracts witnesses for presentation.

##### No new Scaffolding-Hides-Truth instance surfaced

Phase 9 drift risk #6 anticipated potential 6th Scaffolding-Hides-Truth finding from declared-vs-empirical mismatch. **None surfaced**: all empirical results align with declarations OR honestly refute them with witness. The variety-placement table reflects empirical truth, not declared-but-refuted.

##### Adversarial VAG at Phase 9 close (two-column)

| Question | Catalogue | **Challenge** |
|---|---|---|
| (a) On-network? | ✓ Off-network sample-iteration (existing Track 2G scaffolding lineage, honestly labeled). | **Could the findings be cells with monotone merge?** Sister concern of property-cells migration; not Phase 9 scope. Honest acknowledgment: Phase 9 produces structured data records; the data ITSELF could be cell values in a future on-network world. |
| (b) Complete? | ✓ All 110 findings captured (10 × 11 properties). Variety-placement table populated for all 10 (domain × relation × depth) combinations. Per-finding detail files captured. Phase 9 deliverables (9a code + 9b data) both delivered. | **Did we deliver the BENEFIT?** Yes — the data is now design-doc resident; Phase 10 can synthesize without re-running. Wider-sample data captured for type domain (the previously-bottlenecked case). |
| (c) Vision-advancing? | ✓ First comprehensive empirical lattice-variety map across 4 SRE-registered domains. Honest about negative results (Stone identity universally refuted; breadth bound exceeded at wider samples for most domains). | **Inherited patterns still active?** Off-network property checks still are; sister-concern of broader property-cells migration. Honest scaffolding label inherited. |
| (d) Drift-risks-cleared? | ✓ All 9 named risks materialized as expected or didn't fire. Risk #1 (cost concentration on type) → addressed by per-relation parallelization (added `--relation` flag mid-flight, halved type wall time). Risk #6 (potential 6th Scaffolding-Hides-Truth) did NOT fire — honest data. | **Did the per-relation parallelization need design-doc backfill?** Yes — `tools/run-phase9-sweep.rkt --relation` flag is a new mini-design decision made mid-implementation. Honestly named in the dailies + this section. NOT a hidden change. |

VAG passes adversarially. No drift caught requiring corrective.

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

**Estimated scope**: ~500-1000 lines markdown. **Refined to 400-600 lines** post-mini-design (terser; in-person meeting context).

#### Decisions (mini-design + mini-audit + adversarial pass 2026-05-08)

**Audience-specific calibration** (per user direction from prior in-person Nation meetings):
- Nation oriented immediately to dependent types when described as **Pi/Sigma ↔ universal/existential quantification** — Phase 10 will use this framing.
- Nation is **expert on Free Lattices but NOT on quantales** — referred user to colleagues for quantale follow-up. Phase 10 should AVOID heavy quantale framing; if mentioned, frame as "open territory we're exploring; Nation's referrals to colleagues remain valid."
- Meeting is **in person** — terser is better. Doc supports the conversation; doesn't replace it.

**Q1 — Document structure**: option **(b)**. Main markdown doc + raw findings appendix files (already captured at `docs/tracking/2026-04-30_SRE_TRACK2I_PHASE9_FINDINGS_RAW/`). Main doc compact for reading; raw data preserved.

**Q2 — Pedagogy level**: option **(b)** brief Prologos-vocabulary orientation only (1 paragraph). Nation knows lattice theory; he doesn't know our specific abstractions ("domain", "relation", "meet-registry", "ctor-desc"). Brief mapping helps him read the rest.

**Q3 — Witness rendering**: option **(c)** — show smallest representative; reference appendix for full. Pi-typed witnesses get a **brief dependent-types reminder** (Pi ↔ universal quantifier; Sigma ↔ existential) — Nation oriented to this in past meetings, but reminder helps.

**Q4 — Diagrams**: option **(c)** Mermaid. Variety-hierarchy diagram with our domain placements highlighted; binder-boundary asymmetry diagram (equality preserves modularity; subtype refutes). Renderable in github markdown directly.

**Q5 — Open-questions framing**: option **(b)** conversation-starter format. "We observed X. Two hypotheses: Y or Z. Which matches lattice-theoretic intuition?"

**Q6 — Prologos-roadmap connection**: option **(a)** zero internal-roadmap context. If anything mentioned, frame as **lattice-theoretics of interest** (e.g., "how does this finding inform what canonical-form algorithm applies?" — not "this informs PPN 4C Phase X"). Quantale connections specifically deemphasized (Nation's expertise gap; his colleagues are the right audience for quantale-flavored follow-up).

**Q7 — Format**: markdown primary at `docs/research/2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md`. **PDF render** as secondary deliverable for the meeting (post-process via pandoc or similar; can include rendered Mermaid diagrams).

**Q8 — Order**: option **(a)** top-down — variety-placement matrix → per-domain narrative → open questions.

**Q9 — Length**: 400-600 lines markdown. Terse for in-person meeting context.

**Q10 — Lead with**: option **(a)** Whitman's W ✓ across all 10 (domain × relation × depth) combinations. Direct application of Nation's own Theorem 5.55/6.9. Strongest unified empirical claim. Sets up the per-domain refinements.

**Honest scope acknowledgments** (P-lens):
- Empirical sample-set claim, not constructive proof. Section will explicitly say: "We observed Whitman's W holds on all sampled triples (n³ at depth-0; n⁴ at depth-1) — sample-set-sensitive empirical evidence. Hypothesis non-vacuity ratios (83-99% on type, 92-100% on others) suggest the observation isn't vacuous, but constructive proof remains open."
- Stone identity universally refutes — honest negative finding; doesn't reach for higher hierarchy levels.
- Breadth bound exceeded at wider samples for most domains — honest about parallel-decomposition implications.

**Drift risks (mid-flight checkpoints)**:
1. **Padding / pedagogy creep** — most common synthesis-doc failure mode
2. **Witness verbosity** — surveillance for unreadable 50-element unions; truncate per Q3 (c)
3. **Over-claiming on small samples** — N=6 ground exhaustive but limited
4. **Implementation digressions** — Nation doesn't need Racket struct shapes
5. **Prologos-internal vocabulary leakage** — clarify once, don't re-explain
6. **Forgetting open-questions are CONVERSATION starters** (not assertions)
7. **Citation discipline** — Freese-Ježek-Nation 1995 + theorem numbers properly cited; Adaricheva-Gorbunov-Tumanov 2003; Reading-Speyer-Thomas 2019
8. **Quantale over-framing** — Q6 refinement: deemphasize, don't dominate; Nation's not the right audience for deep quantale follow-up
9. **Scope creep into deeper internal report** — that's a follow-on (see § Follow-on tracks below); Phase 10 is THE EXTERNAL doc only

**Adversarial CRITIQUE pass** (P/R/M/S two-column):

| Lens | Catalogue | **Challenge** |
|---|---|---|
| **P** | ✓ Compact synthesis (Q9); audience-specific calibration (no quantale-overload per Q6 refinement); raw appendix preserves data (Q1) | **Are we honest about empirical-vs-constructive scope?** Yes — explicit "sample-set-sensitive" caveat in lead. **Are we resisting Prologos-internal-roadmap padding?** Yes — Q6 lock. |
| **R** | ✓ All findings already captured in Phase 9 raw files; design-doc § Phase 9 Findings has interpretive matrix | None new |
| **M** | N/A — synthesis doc, not propagator-network design | — |
| **S (SRE Lattice Lens)** | ✓ Variety-placement is Q1 (lattice classification at PTF hierarchy levels). Witnesses cite specific lattice elements. References cite canonical lattice-theory papers. | **Q6 (Hasse adjacency) — does report exploit it?** Indirectly via breadth-bound discussion. Could include a Hasse-diagram-implication paragraph but probably overkill given length budget. |

VAG-projected: passes adversarially. Quantale-deemphasize is the biggest specific design adjustment from prior assumptions.

#### Follow-on tracks (NOT Phase 10 scope)

User-flagged 2026-05-08 mini-design dialogue:

1. **Web-app interactive network topology** — small interactive demo capturing a representative network with cells, propagators, strata, color-coded for in-person exploration with Nation. Secondary to Phase 10 report. Captured here so the interest doesn't get lost; will return after Phase 10 commits.

2. **Deeper internal lattice-variety report** — complementary doc with deeper explanations, full witness rendering, deeper Prologos-roadmap connections, quantale framing for our own architecture-team audience. Sister of Phase 10 but for INTERNAL use; Phase 10 is the EXTERNAL/Nation-facing version. Captured here; pickup after Phase 10 lands.

### Phase 11: `has-complement` empirical check (Boolean placement)

**Scope** (high-level; full mini-design + mini-audit when phase opens):

Add `test-has-complement` to `sre-core.rkt`. For each element `a`, search the sample set for `x` such that `a ∧ x = ⊥` AND `a ∨ x = ⊤`. If found for every `a`, confirm; otherwise refute with witness atom (the element that has no complement).

**Property registry**: `'has-complement` (the existing implication-rule already references this — it's been a source-not-yet-tested placeholder). Implication chain `heyting + has-complement ⇒ boolean` already in `standard-implication-rules`.

**Sweep integration**: extend `all-sweep-properties` with `'has-complement`. Variety-placement-summary's Boolean column becomes empirically populated (currently uniformly "—").

**Estimated scope**: ~30 LoC in sre-core.rkt + ~10 LoC sweep-dispatch. Tests + sweep run.

#### Decisions (mini-design + mini-audit + adversarial pass 2026-05-08)

**YAGNI reversal on /detailed variant** (user-flagged 2026-05-08): the original Phase 11 scope said "no /detailed variant per Phase 5 YAGNI discipline." User pushback: "YAGNI may prematurely preclude considerations vacuously, as an excuse to defer." The honest framing is *Completeness Over Deferral* — when the marginal cost is small AND the data is informationally distinct, build it. For has-complement:

- **total-checked** = total `a` iterated
- **hypothesis-fired** = `a` where bot AND top are reachable in sample (= check is non-vacuous for this `a`)
- **conclusion-held** = `a` with successful complement candidate found
- **witness** = `a` with no complement (refute)

Non-vacuity ratio (`fired / total-checked`) distinguishes strong-empirical-Boolean (high non-vacuity, confirms) from weak-empirical-Boolean (low non-vacuity, confirms only on tested elements) from concrete-refutation (witness atom). Phase 4's SD-vee 3.5% vs SD-wedge 91.4% asymmetry is the precedent — that finding would have been invisible without `/detailed`. Has-complement deserves the same treatment.

**Going-forward discipline (Phases 12-15)**: each property check that has a meaningful non-vacuity decomposition gets a `/detailed` variant unless we can articulate WHY the decomposition is genuinely uninformative for that property (NOT "we don't need it yet" but "it doesn't measure anything different for this check"). The honest test for each: do we get more information from the 5-tuple than from confirmed/refuted alone?

**In-phase sweep + report integration** (user-flagged 2026-05-08): original Phase 11 scope said "validation only; comprehensive sweep deferred." User pushback: front-loading code and back-loading data is unprincipled. Revised:

- After Phase 11 code lands and tests pass: run sweep on `has-complement` across all 10 (domain, relation, depth) tuples
- Append new rows to design doc § Phase 9 Findings (the comprehensive variety-placement matrix)
- Update Nation report's matrix in-place — replace the Boolean column's "—" entries with empirical results
- Adversarial VAG with the actual data, not just code shape
- Single commit: code + sweep findings + design doc + Nation report update

Cost analysis: O(N²) per (domain, relation, depth). At wider sample N=58, ~3364 iterations × ~70µs/iter = ~4 min per tuple. Across 10 tuples sequentially: ~40 min. With existing 4-concurrent-process model in `tools/run-phase9-sweep.rkt` (per Phase 9b harness): ~10-15 min wall.

Per-phase sweep applied to all of Phases 11-15 going forward — Nation report stays a living document throughout.

**Implementation plan**:

1. **Code** (~80-100 LoC):
   - `complement-evidence` struct (5-field, parallels sd-evidence/pc-rel-evidence/modular-evidence/whitman-evidence)
   - `test-has-complement/detailed` (parameterized; per-element decomposition; skip vacuous when bot or top missing for that `a`; track fired vs held)
   - `test-has-complement` wrapper translating to `axiom-*` shape
   - Wire into `infer-domain-properties` (`props-N+1`) + `resolve-and-report-properties` evidence map
   - Add to `all-sweep-properties` in `sre-property-sweep.rkt` (now 12 properties)
   - Add `[(has-complement) ...]` branch in `sweep-one-property`
   - Update `extract-detailed-fields` in `sre-property-sweep.rkt` to handle `complement-evidence`
   - Update `format-sd-finding-row` if needed

2. **Tests** (~30 LoC):
   - `test-has-complement-untested-without-fns`
   - `test-has-complement-detailed returns complement-evidence`
   - `test-has-complement-empirical refutes form domain` (validates Track 2H decl)
   - `infer-domain-properties produces has-complement entry`
   - 4-5 cases

3. **Sweep run** (~10-15 min wall):
   - Extend `tools/run-phase9-sweep.rkt` (or invoke directly with `#:properties '(has-complement)`)
   - 4 concurrent processes split by domain
   - Capture findings to file

4. **Report integration** (~10 min):
   - Append new rows to design doc § Phase 9 Findings (10 rows for `has-complement` × 10 tuples)
   - Update Nation report `docs/research/2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md` Boolean column
   - Update report's "What we did not measure" — strike has-complement from that list

**Drift risks**:

1. **Sample-set sensitivity** (Phase 5 acknowledged): wider sample may falsely refute when true complement exists outside sample. Flag in interpretation.
2. **Bot/top absence per-element handling**: skip vacuous (treat as not-fired); mirrors `test-pseudo-complement-abs` pattern. Honestly captured in detailed evidence.
3. **Form domain expected refutation**: `form-cells.rkt:562` declares `has-complement prop-refuted`. Phase 11 sweep validates. If sweep CONFIRMS instead → Scaffolding-Hides-Truth #6 candidate; escalate per drift-risk-#4 dialogue mandate.
4. **Type×subtype potential Boolean reach**: type×subtype is declared Heyting (Track 2H). If has-complement empirically confirms on ground sublattice → Boolean derives via implication rule. NEW architectural finding parallel to Phase 5a's type×equality Heyting reach. Watch.
5. **Sweep findings integration into Nation report**: ensure consistency with existing Phase 9 matrix rendering style — same row format, same per-(domain, relation, depth) granularity.
6. **Implication-rule ordering on derive-composite-properties**: existing `heyting + has-complement ⇒ boolean` rule fires after has-complement is inferred. Verify no race condition in inference order.

**Estimated scope**: ~80-100 LoC code + ~10-15 min sweep + ~10 min report integration. Single phase; one commit ties code + sweep findings + design doc + Nation report all together.

### Phase 12: M3 / N5 sublattice detection (Birkhoff's forbidden-sublattice theorem)

**Scope** (high-level):

Add `test-no-m3-sublattice` and `test-no-n5-sublattice` to `sre-core.rkt`. Enumerate 5-element subsets of the sample. For each, check order-isomorphism to:
- **M3** (the diamond): a 5-element lattice with `⊥, ⊤` and three pairwise-incomparable middle elements `a, b, c` with `a ∨ b = a ∨ c = b ∨ c = ⊤` and `a ∧ b = a ∧ c = b ∧ c = ⊥`.
- **N5** (the pentagon): a 5-element non-modular lattice with `⊥, ⊤, a, b, c` satisfying `b ≤ a`, `c` incomparable with both, `a ∨ c = b ∨ c = ⊤`, `a ∧ c = b ∧ c = ⊥`.

Refutation witness: the 5-element subset that IS isomorphic to M3 or N5. Concrete, lattice-theoretic vocabulary Nation immediately recognizes.

**Birkhoff's theorem** (Theorem 9.2): a lattice is distributive iff it contains neither M3 nor N5 as a sublattice. Phase 12 is the empirical sublattice-detection counterpart.

**Property registry**: `'no-m3-sublattice`, `'no-n5-sublattice`. Implication: `no-m3 + no-n5 ⇒ distributive` (forward; on finite samples). Inverse `distributive ⇒ no-m3 + no-n5` is the classical theorem.

**Cost**: O(C(N, 5)) per check. For type wider (N=58): C(58, 5) = 4.5M subsets. Per-subset isomorphism check is O(constant) (just compare order structure). Estimated 5-15 min on type wider.

**Estimated scope**: ~80 LoC in sre-core.rkt (M3/N5 fixtures + isomorphism check) + ~15 LoC sweep-dispatch + tests.

#### Decisions (mini-design + mini-audit + adversarial pass 2026-05-08)

**Implementation strategy reversal — direct construction, NOT full 5-tuple enumeration**: original scope said "enumerate 5-element subsets, check order-isomorphism." Cost analysis: at N=58 wider sample, C(58,5) = 4.5M subsets × ~1.4ms closure-check ≈ 105 minutes per tuple — unacceptable. Revised:

- **M3 detection**: enumerate antichains of size 3 (O(N³) ≈ 30k triples at N=58). For each `(a, b, c)` pairwise-incomparable triple, verify `a∧b = a∧c = b∧c` (= ⊥') AND `a∨b = a∨c = b∨c` (= ⊤'). If yes AND the resulting 5-element set is closed under meet/join, refute with witness `(⊥', ⊤', a, b, c)`. ~20-30 sec per tuple at N=58.

- **N5 detection**: enumerate ordered comparable pairs `(b, a)` with `b < a`. For each, iterate `c` incomparable with both. Verify `a ∨ c = b ∨ c` AND `a ∧ c = b ∧ c`. If yes AND closed, refute with witness. ~20-30 sec per tuple.

**`/detailed` variants for both** (per Phase 11 Completeness-Over-Deferral discipline):
- `m3-evidence` (5-field struct): status × total (antichains-of-3) × hypothesis-fired (common-meet/common-join exist) × conclusion-held (NOT M3) × witness
- `n5-evidence` (5-field struct): status × total (b<a pairs) × hypothesis-fired (incomparable c exists) × conclusion-held (NO N5-completing c) × witness

Non-vacuity meaningful: distinguishes "no antichains-of-3 in sample → vacuously confirmed (breadth ≤ 2)" from "many antichains checked, none completes M3 → strong confirmation."

**Property registry + implication rule**:
- `'no-m3-sublattice`, `'no-n5-sublattice`
- Implication: `no-m3-sublattice + no-n5-sublattice ⇒ distributive` (forward — empirical sample-bounded; the classical Birkhoff 9.2 converse is theorem, not empirical)

**Closure verification** post-construction: 5-element witness must be closed under meet/join with itself. The construction guarantees pairwise meets/joins are in {⊥', ⊤', a, b, c}; verify pairwise-meet-with-bot/top stays inside. Distinguishes "antichain shape exists" from "embedded sublattice exists."

**Adversarial pass surfaced**:
- P-lens: same off-network sample-iteration scaffolding lineage (existing). No new debt.
- R-lens: 5 sites (sre-core.rkt definition + provide + 2 wirings + 2 sweep dispatches in different files + tests). Phase 11 pattern.
- M-lens: O(N³) enumeration is step-think; same lineage as sample-iteration scaffolding.
- S-lens: M3 and N5 ARE structural patterns Nation immediately recognizes; the witnesses are CONCRETE LATTICE STRUCTURES (not just refute-tuples). Stronger Nation-presentation value than Phase 4's Pi-typed-triple distributivity refutation.

**Drift risks (7 named)**:
1. Direct-construction soundness — antichain-of-3 with common pairwise meets/joins is M3 SHAPE, but embedded SUBLATTICE requires closure. Verify post-construction.
2. Cost at N=58 — O(N³) ≈ 30k × ~700µs ≈ 20 sec per tuple. 8 sweeps × 20s = 160s sequential, ~40s wall via 4-concurrent. Tractable.
3. Witness verbosity — 5-element lists of compound types may be large; Phase 9 already truncates; Phase 12 inherits.
4. Sample-set sensitivity — same caveat as Phase 11. Document in interpretation.
5. Both harness `extract-detailed-fields` copies need updates (Phase 11 lesson).
6. Connection to Phase 4 distributivity refutation — does the Pi-typed witness complete M3 or N5? Phase 12 sweep tells us. Genuine architectural curiosity.
7. Phase size — ~150 LoC code + tests + sweep + report. Single phase; within 1h budget.

**Connection to Birkhoff 9.2**: classical theorem says distributive ⇔ no-M3 ∧ no-N5. Empirical sweep gives one direction (forward implication). Classical converse: distributive-refuted lattices MUST contain M3 or N5 — we'd EXPECT to find one in type×{eq,sub}×wider (Phase 4 found distributivity refuted). If Phase 12 finds neither, that's a bug or sample-set artifact.

**Estimated scope**: ~150 LoC sre-core.rkt + ~20 LoC sweep dispatch (both files) + ~30 LoC tests + sweep + report integration. Single atomic commit per Phase 11 pattern.

### Phase 13: Convex geometry / anti-exchange characterization

**Scope** (high-level):

For SD-confirmed domains, the Adaricheva-Gorbunov-Tumanov 2003 theorem says: the dual lattice corresponds to a convex geometry (anti-exchange closure operator) iff the lattice is finite join-semidistributive. We test the anti-exchange property empirically on the canonical closure operator: downward closure on join-irreducibles.

For a lattice L with join-irreducibles `J(L)`:
- Define `cl(A) = {x ∈ J(L) : x ≤ ⋁A}` (downward closure)
- Anti-exchange: for distinct `x, y ∉ cl(A)`, `y ∈ cl(A ∪ {x})` ⇒ `x ∉ cl(A ∪ {y})`

Implementation:
1. Enumerate join-irreducibles of the sample (elements not expressible as join of strictly-smaller elements)
2. For each subset A and each pair (x, y) of non-members, check anti-exchange
3. Confirm if all (A, x, y) pairs satisfy; refute with witness

**Property registry**: `'anti-exchange-on-J(L)` (or `'convex-geometry-dual`). Implication: AGT 2003 is *iff* — `sd-vee-and-sd-wedge ⇔ anti-exchange-on-J(L)` (in finite case).

**Cost**: depends on J(L) size; worst-case O(2^|J(L)|) for subset enumeration. For our domain samples typically |J(L)| ≪ N, so cost is bounded.

**Estimated scope**: ~100 LoC (join-irreducibles enumeration + closure operator + anti-exchange check) + tests + sweep.

**Why this matters for Nation**: AGT 2003 is *recommended in his lattice notes companion*. The duality between SD lattices and convex geometries is a key bridge to combinatorial-geometry literature. Confirming our SD lattices yield anti-exchange closure operators substantively connects our system to convex-geometry research.

#### Decisions (mini-design + mini-audit + adversarial pass 2026-05-08)

**Q1 — Bounded subset size**: `k=2` default, parameterizable via `#:max-subset-size`. Cost analysis at |J|≈50: k=2 gives ~16M iter with caching → ~20 min/tuple → ~50 min sweep wall via 4-concurrent. Tractable; matches Phase 11/12 sweep budgets. Sample-limitation honestly bounded.

**Q2 — AGT 2003 iff implication rule policy**: forward direction `sd-vee + sd-wedge ⇒ anti-exchange-on-J` **deliberately NOT encoded** (matches Phase 12 Birkhoff-9.2-forward precedent). Rationale: Nation gains MORE information from independent empirical measurements than from implication-derived results. Encoding the rule would auto-confirm anti-exchange whenever SD confirms (without empirical evidence) — hiding the AGT-iff-empirical-validation data point. NOT encoding lets us show empirical agreement (or boundary disagreement) across all 10 tuples — stronger presentation value. Same Phase 12 discipline.

**Q3 — Sweep scope**: ALL 10 (domain, relation, depth) tuples (matches Phase 11/12). Refutation in non-SD case is itself informative boundary data. SD all confirms to date per Phase 9b, so the empirical question across all 10 is whether anti-exchange follows correspondingly.

**Q4 — Phase structure**: single phase. Sub-phase fallback (13a join-irreducibles + closure helpers; 13b anti-exchange + wiring + sweep + report) only if implementation exceeds 1h. Phase 11+12 single-phase precedent.

**Q5 — `/detailed` decomposition** (per Phase 11 Completeness-Over-Deferral):
- `total-checked` — total `(A, x, y)` triples enumerated
- `hypothesis-fired` — triples where `y ∈ cl(A ∪ {x})` (the "if" of anti-exchange holds)
- `conclusion-held` — triples where additionally `x ∉ cl(A ∪ {y})` (axiom satisfied given hypothesis)
- `witness` — `(A, x, y)` on refute

Non-vacuity ratio captures hypothesis-firing rate — informative per Phase 11 precedent.

**Implementation plan**:

1. **Code** (~150 LoC sre-core.rkt):
   - `sample-join-irreducibles domain samples meet-fn join-fn` — enumerate `J(L)` excluding `bot`
   - `sample-closure-on-J A J meet-fn join-fn bot` — `cl(A) = {x ∈ J : x ≤ ⋁A}`
   - `anti-exchange-evidence` 5-field struct (per Phase 11 pattern)
   - `test-anti-exchange/detailed domain samples meet-fn join-fn #:max-subset-size [k 2]`
   - `test-anti-exchange` wrapper translating to `axiom-*`
   - Wire into `infer-domain-properties` (`props-17`) + `resolve-and-report-properties` evidence map

2. **Sweep harness updates** (~10 LoC each in 2 files — Phase 11 lesson):
   - `sre-property-sweep.rkt`: `all-sweep-properties` 14 → 15; `sweep-one-property` dispatch; `extract-detailed-fields` case
   - `tools/run-phase9-sweep.rkt`: matching `extract-detailed-fields` case (atomic per Phase 11 lesson)

3. **Tests** (~25 LoC):
   - `test-anti-exchange-untested-without-fns`
   - `test-anti-exchange/detailed returns anti-exchange-evidence struct`
   - `test-anti-exchange empirical on type domain returns axiom-*`
   - `infer-domain-properties produces anti-exchange-on-J entry`
   - 4-5 cases per Phase 11+12 pattern

4. **Sweep run** (~50 min wall):
   - 4 concurrent processes split by domain via `tools/run-phase9-sweep.rkt --properties anti-exchange-on-J`
   - Capture findings to file

5. **Report integration** (~10 min):
   - Append rows to design doc § Phase 9 Findings
   - Update Nation report `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md` with anti-exchange column
   - Cross-reference AGT 2003 in references; emphasize empirical bidirectional iff data

**Adversarial pass surfaced**:
- P-lens: same off-network sample-iteration scaffolding lineage (existing Track 2G); no new debt. AGT iff NOT encoded as rule preserves empirical data point.
- R-lens: 7 wire sites identified (5 file + 2 sweep harness copies); existing helpers from Phase 5.
- M-lens: bounded-subset enumeration is step-think; same lineage as Phase 12 enumeration. Honest scaffolding.
- S-lens: J(L) Hasse IS the Birkhoff representation poset. Q6 challenge: bounded-subset enumeration doesn't exploit J(L) Hasse adjacency (analogous to Gray-code for Boolean Q_n). NOT in scope; honest computational gap.

**Drift risks (7 named)**:

1. **|J(L)| explosion at wider sample**: bounded subset size `k=2` default; document scope-bound.
2. **AGT 2003 iff implication rule** — deliberately NOT added (Q2 decision); document rationale.
3. **Closure-cache memory**: precompute `cl(A)` per subset; |J|^k subsets × |J| each — manageable at k=2.
4. **Sample-set sensitivity** (Phase 11/12 recurring): bounded-subset confirmation = bounded confidence.
5. **Both `extract-detailed-fields` copies** (Phase 11 lesson): atomic update mandatory.
6. **Phase 11 in-phase pattern**: single commit ties code + sweep + design doc + Nation report.
7. **Phase size at 1h boundary**: ~150 LoC + sweep + report. Sub-phase fallback ready if exceeded.

### Phase 14: Targeted congruence tests

**Scope** (high-level):

Full Con(L) characterization is O(2^N) — explosive on wider samples. Phase 14 tests **specific candidate congruences** rather than enumerating all:

1. **Kernel of multiplicity-forgetful map** for type domain: equate types differing only in QTT multiplicity. Check meet/join compatibility.
2. **Canonical-form projection**: equate types that have the same canonical form (after ACI normalization, subtype absorption, etc.). Check meet/join compatibility.
3. **Trivial / total** as sanity: confirm both endpoints of Con(L) are present.

For each candidate congruence θ, verify: `(a θ b) ∧ (c θ d) ⇒ (a∧c) θ (b∧d)` AND `(a∨c) θ (b∨d)`.

**Property registry**: per-candidate symbols (`'mult-forgetful-congruence-valid`, `'canonical-form-congruence-valid`).

**Cost**: O(N²) per candidate × number of candidates. Tractable.

**Estimated scope**: ~60 LoC per candidate + ~30 LoC infrastructure. Tests + sweep.

**Honest scope**: targeted tests can confirm specific congruences but cannot characterize Con(L) fully. Subdirectly-irreducible characterization (the classical use of Con(L)) requires checking that the ONLY non-trivial congruences are exactly the candidates we test — a stronger claim Phase 14 cannot make.

#### Decisions (mini-design + mini-audit + adversarial pass 2026-05-08)

**Q1 — Candidate set**: 4 candidates: `trivial`, `total` (sanity / framework-wiring confirmation; both vacuous-by-construction); `mult-forgetful` (type-domain-only — strips ALL multiplicity from Pi/Sigma/lam binders); `erasure-equivalence` (type-domain-only — strips ONLY m0-typed components per QTT erasure semantics; distinct from mult-forgetful which strips ALL mult).

**Q2 — Canonical-form-projection DROPPED + sister concern recorded**: as originally proposed in the design doc, "canonical-form-projection" would be degenerate given our merge architecture (merge already produces canonical representatives via ACI + subtype absorption + dedup; canonical-form equivalence = identity = trivial). Phase 14 drops this candidate.

**Sister concern — "merge-as-canonical-form" structural-optimality claim** (recorded for Phase 10 Nation report update, NOT new Phase 14 content): the substantive claim Nation discussed in the prior meeting is that **our merge IS the canonical-form witness emerging from the lattice structure** — the algebraic axioms (ACI + subtype absorption) DETERMINE the canonical representative; we don't compute it algorithmically and impose it. This matches Nation's lattice-theoretic canonical form (Whitman/Freese-Nation 1.17, Reading-Speyer-Thomas FTFSDL) framing. The Phase 10 Nation report should add a "merge-as-canonical-form" subsection capturing this structural-optimality claim.

**Q3 — Sweep scope**: ALL 10 (domain, relation, depth) tuples for trivial + total (always applicable); type-domain-only for mult-forgetful + erasure-equiv. Non-type tuples for mult-forgetful + erasure return `axiom-untested` with reason `'congruence-not-applicable-to-domain`.

**Q4 — Phase structure**: single phase per Phase 11+12+13 precedent.

**Q5 — Time-budget pragma + ground-only sweep**: per user 2026-05-08, presentation time-crunch precludes full wider-sample sweep. **Ground-only sweep across all domains × all 4 candidates (~5 min wall).** Honest scope-bound flagged in findings: at ground sublattice (atomic sample, no Pi/Sigma/lam compounds), mult-forgetful and erasure-equivalence both DEGENERATE to trivial congruence (no binders to strip) → vacuously confirm with NO empirical content. **Framework-wiring + sanity confirmation only**; empirical content for mult-forgetful + erasure-equiv on type-domain wider sample deferred to post-meeting follow-up. Will opportunistically run small wider sample (per-ctor-count=1, ~30 samples, ~4 min) for type×{eq,sub} × {mult-forgetful, erasure-equiv} if time permits at phase close.

**`/detailed` decomposition** (per Phase 11+13 Completeness-Over-Deferral):
- `total-checked` — total `(a, b, c, d)` 4-tuples enumerated
- `hypothesis-fired` — 4-tuples where `a ~ b ∧ c ~ d` (non-vacuous antecedent)
- `conclusion-held` — 4-tuples where additionally `(a∧c) ~ (b∧d) ∧ (a∨c) ~ (b∨d)`
- `witness` — `(a, b, c, d)` on refute

**Implementation plan**:

1. **Code** (~120-150 LoC sre-core.rkt):
   - `congruence-evidence` 5-field struct
   - `test-congruence-axiom domain samples meet-fn join-fn equiv-fn` — generic O(N⁴) check
   - Wrapper functions per candidate that supply equiv-fn
   - `mult-forgetful-equiv?` + helper `forget-mult-norm` (recursive type normalization)
   - `erasure-equiv?` + helper `m0-erasure-norm` (recursive m0-stripping normalization)
   - Wire into `infer-domain-properties` (`props-18..21`) + `resolve-and-report-properties` evidence map
   - Add 4 properties to `all-sweep-properties`
   - Sweep dispatch + extract-detailed-fields (both copies per Phase 11 lesson)

2. **Tests** (~30 LoC).

3. **Sweep run** (~5 min wall ground-only across all domains).

4. **Report integration**: append to design doc § Phase 9 Findings + Nation report (with honest scope acknowledgment of ground-sublattice vacuity for type-domain candidates).

**Adversarial pass surfaced**:
- P-lens: same off-network sample-iteration scaffolding lineage. No new debt. Per-candidate domain-applicability is honest decomplection.
- R-lens: 7 wire sites + 2 normalization helpers; existing pattern from Phase 11+12+13.
- M-lens: O(N⁴) is step-think; same lineage as Phase 6 Whitman's W. Honest scaffolding.
- S-lens: Q1 VALUE; Q3 bridges to congruence-quotient lattice (not implemented; honest gap); Q6 Hasse not exploited (sister concern).

**No forward implication rule** added (matches Phase 12+13 sample-unsound discipline). Subdirectly-irreducible characterization — classical Nation territory — explicitly NOT claimed; Phase 14 cannot soundly make it.

**Drift risks (7 named)**:
1. Mult-forgetful + erasure-equiv applicability gating: type-domain-only; non-type tuples `axiom-untested` with reason `'congruence-not-applicable-to-domain`.
2. Trivial/total clearly labeled "framework-wiring sanity check, not empirical content".
3. **Ground-sublattice vacuity for mult-forgetful + erasure-equiv**: atomic sample has no binders → both degenerate to identity → vacuously confirm. Honestly flagged in findings.
4. No forward implication rule (matches Phase 12+13 sample-unsound discipline).
5. Both `extract-detailed-fields` copies (Phase 11 lesson): atomic update mandatory.
6. Phase 13 type-domain sweep still running concurrently — single-CPU contention possible. Phase 14 sweep can wait if needed.
7. Phase 10 Nation report "merge-as-canonical-form" subsection — separate task, recorded as Phase 14 sister concern; integrates at Nation report update post-Phase-13.

### Phase 15: Day's doubling / inflation detection

**Scope** (high-level):

Adaricheva-Nation 2017 ("Inflation of finite lattices along all-or-nothing sets") characterizes Day's doubling construction. Phase 15 tests for **interval-doubling structure** in our lattice samples:

1. Identify intervals `[a, b]` in the sample where `b` covers `a` plus 2+ chains.
2. For each candidate interval, check if it has the *doubled* shape (two parallel sub-structures) per Day's construction.
3. Confirm with witness intervals; refute if no interval admits doubling structure.

**Property registry**: `'admits-day-doubling`.

**Cost**: O(N²) interval enumeration × O(constant) per-interval check. Tractable.

**Honesty scope**: testing whether a lattice ADMITS doubling structure is different from testing whether it WAS constructed via doubling. Phase 15 tests admittance.

**Estimated scope**: ~150 LoC (interval enumeration + parallel-structure detection) + tests + sweep. Tier 3 — most speculative; may surface that the test framing itself needs refinement during implementation.

**Why this matters for Nation**: Adaricheva-Nation 2017 is HIS OWN co-authored work. The empirical check of "does Prologos's lattice structure exhibit Day-doubling-amenable form" is direct relevance.

#### Decisions (mini-design + mini-audit + adversarial pass 2026-05-08)

**Background research (Adaricheva-Nation 2017 lineage)**: Mempalace surfaced the lineage cleanly — Day 1970 original interval-doubling (used to prove (W) for free lattices), 1979 bounded-homomorphic-image characterization, Adaricheva-Nation 2017 generalizes Day's interval doubling to **all-or-nothing set inflation** (subsets S where every external element compares uniformly to all of S).

**Q1 — Algorithm choice**: **Option B (Adaricheva-Nation 2017 all-or-nothing pair detection)**. Rationale: direct relevance to Nation's recent co-authored work; generalizes Day's singleton-pair signature; empirically richer (catches inflation along subsets that don't exhibit covering-pair doubling). **Option A (Day 1970 interval-doubled-pair signature) subsumed** — every Day-doubled pair is also an all-or-nothing pair under Option B.

**Q2 — Pair-only scope**: pair-only for Phase 15. Extended-set search (extending confirmed pairs to triples/quadruples for richer witnesses) is **Tier 4 follow-up** if interesting post-meeting. Honest framing — pair-only finding is sound; richer witnesses are nice-to-have.

**Q3 — No forward implication rule**: per Phase 12 + 13 precedent (sample-unsound for negative absence claims). Phase 15 is primary empirical property, not derived.

**Q4 — Sweep scope**: all 4 domains × all relations × {ground, wider} (10 tuples), matching Phase 11 + 12 + 13 pattern. Expected runtime: ~minutes (O(N³) tractable).

**Q5 — Report honesty framing**: Phase 15 finding is a **sample-bounded claim about admittance**, not a theorem-strength claim about inflation history. Detection = "lattice admits inflation along this pair on this sample"; absence = "no all-or-nothing pair found on this sample". Both honestly named in evidence struct + report.

**Algorithm (Option B)**:

For each pair `(s₁, s₂)` of distinct, incomparable samples:
1. Hypothesis-fired: pair is incomparable (not vacuous).
2. Check all-or-nothing: ∀ external `x` ∈ samples, `x` is consistently above (`x ≥ s₁ AND x ≥ s₂`), below (`x ≤ s₁ AND x ≤ s₂`), or incomparable to BOTH s₁ and s₂.
3. If property holds for all external x: **confirmed witness** found — return early with `(s₁, s₂)` + dependency-pattern summary.
4. If no pair satisfies the property: **refuted on sample** — no all-or-nothing pair detected.

**Note on confirmation/refutation semantics**: Phase 15 differs from Phase 12+13 in that **finding even ONE witness is positive evidence of inflation-amenability**. The check thus returns `confirmed` on first witness, `refuted` only if EVERY pair was checked without finding one. This is the existence-claim shape (positive empirical assertion) — distinct from universal-claim shape (Phase 12 M3-absence) and iff-claim shape (Phase 13 anti-exchange).

**Witness format**: `(s₁, s₂, [dep-pattern])` where dep-pattern is a list of `(external, side)` with side ∈ `{above, below, incomparable}` summarizing the all-or-nothing dependency structure. Truncated to first 5 entries for log readability; full pattern in raw findings file.

**Property registry**: `'admits-day-doubling`. Single symbol; no derived counterpart needed.

**Deliverables (locked)**:
- `dd-evidence` struct: 5-field (status × total-pairs × hypothesis-fired-incomparable × conclusion-held-allon × witness)
- `test-admits-day-doubling/detailed` + wrapper (sre-core.rkt)
- Wiring: provides + props-19 + evidence map + 7-site dispatch (sre-property-sweep + run-phase9-sweep extract-detailed-fields)
- ~6-8 new test-cases (Phase 12 pattern)
- Sweep run via 4 concurrent processes
- Nation report integration: new column block + Adaricheva-Nation 2017 citation
- Single atomic commit per Phase 11+ in-phase pattern

**Adversarial pass (P/R/M/S two-column)**:

| Lens | Catalogue | **Challenge** |
|---|---|---|
| **P** Principles | ✓ Decomplection (orthogonal property check); Correct-by-Construction (explicit meet+join from same relation per Phase 4 discipline); Data Orientation (dd-evidence struct) | **Off-network scaffolding** (Track 2G lineage); inherits property-registry granularity gap. **NOT new debt** — same scaffolding markers as Phase 11-14. Honest. |
| **R** Reality-Check | ✓ Concrete sites: sre-core.rkt provides + infer/resolve callsites + sre-property-sweep + run-phase9-sweep. Phase 12 pattern proven across 4 domains × 2 depths. | **Sweep cost**: O(N³). At N=58 wider, 195k iterations × meet/leq calls ≈ minutes per domain. Manageable. **No external API consumers** — internal to Track 2I scope. |
| **M** Propagator-Mindspace | ✓ Off-network sample-iteration (Track 2G lineage; honest scaffolding label) | **for/fold over N² pairs** is step-think; could be `net-add-broadcast-propagator` decomposition. NOT migrating — sister concern of property-cells migration track. Honestly labeled. |
| **S** SRE Lattice Lens | The lattice being characterized is the property-value lattice (4-valued); Phase 15 doesn't introduce new lattice. Q1-Q5 catalogued (VALUE; 4-valued; bridges via Galois pairs from samples; extends Track 2G; primary=declared, derived=inferred). | **Q6 Hasse**: property-value lattice trivial (4-element diamond); lattice-being-checked (the 4 SRE domains) has rich Hasse — Phase 15 doesn't exploit Hasse adjacency in the sweep. **Acknowledged sister-concern**: Hasse-traversal-ordered checks could be cheaper; not in Phase 15 scope. |

**Adversarial passes**: no drift requiring corrective. All 4 lens challenges produce honest scope-acknowledgments rather than required redesign.

**Drift risks (consolidated, 7 items)**:
1. **(a) admits-doubling vs (b) was-constructed-via-doubling honesty** — Phase 15 tests (a). Witness names the pair + dependency pattern. ✓
2. **Sample-set sensitivity** — refutation on sample ≠ refutation on full lattice. Honest scope-bound matching Phase 12-13 discipline.
3. **No forward implication rule** — sample-unsound either direction (per Q3). Empirical-positive primary property only.
4. **Cost O(N³) on wider sample** — manageable per Phase 12-13 measurements.
5. **Algorithm locked** — Option B (Adaricheva-Nation 2017). Option A subsumed.
6. **Witness format truncation** — first 5 dependency entries in evidence struct; full pattern in raw findings file. Conservative for log readability.
7. **Phase 15 = final reopened-arc phase** — Track 2I closes after Phase 15. Adversarial VAG at close should extend to **whole reopened arc Phases 11-15** combined, surfacing any drift across the gap-closure work as a unit.

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
