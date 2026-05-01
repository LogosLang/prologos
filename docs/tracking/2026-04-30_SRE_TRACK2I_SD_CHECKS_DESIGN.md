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

Add SD∨ and SD∧ as first-class algebraic-property checks in the SRE registry, parallel to the existing `commutative-join` / `associative-join` / `idempotent-join` / `distributive` machinery (`sre-core.rkt:262-322`). Implication rule `distributive ⇒ sd-vee ∧ sd-wedge` lets the two confirmed-Heyting domains inherit SD trivially; empirical sweep on the three non-distributive-yet domains (type-equality, session-equality, secondary form registration) yields *information* — either confirms SD-but-not-distributive (a known-non-empty variety; canonical-form theory exists per Reading-Speyer-Thomas 2019) or surfaces counterexample triples we can act on.

This is the smallest concrete move toward variety identification per [LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md §5.4](../research/2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md). It does NOT commit to canonical-form algorithms, NOT commit to UCS dispatch by variety, and NOT commit to type-lattice variety identification at the broader level. It just adds the check.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 1 | `test-sd-vee` + `test-sd-wedge` in sre-core.rkt; wire into inference + reporting; implication rules for distributive⇒SD | ✅ | `a35d5f65`. 99 LoC sre-core.rkt + 71 LoC test-sre-algebraic.rkt. 42 tests pass via targeted runner. VAG passed adversarially. |
| 2 | Programmatic sample generator from ctor-desc registry + sd-evidence struct + `/detailed` variants | ✅ | `f241e14e`. New file `sre-sample-generator.rkt` (~120 LoC) + sre-core.rkt enrichment (~80 LoC, sd-evidence struct + /detailed variants + backward-compat wrappers) + 11 new tests. 53 tests pass via targeted runner. VAG passed adversarially with two acknowledged Phase-3 gaps (sample-size verification, binder-ctor coverage). API note: `all-ctor-descs` takes `#:domain` keyword (not positional) — caught at compile time. |
| 2a | Principled-fix corrective: per-component-spec generation (Option C), drop `with-handlers`, include binder ctors with closed-body limitation | ✅ | `1c0c012e`. Generator refactored: per-component-spec atom pools, sentinel filter, binders included. **Bonus discovery**: Phase 2's `with-handlers` was masking malformed compounds (bot/top in component slots → reconstruct produces invalid `(expr-Pi mw type-top type-top)`-shape values that merge can't handle). Two-pool model (lattice elements vs structural components) surfaces and fixes it. 58 tests pass. VAG passed adversarially with the masked-issue surfacing as the Move B+ pattern's intended payoff. Codebase-wide audit of remaining 72 `with-handlers` instances filed as [issue #40](https://github.com/LogosLang/prologos/issues/40). |
| 3c | Per-relation `meet-registry` on sre-domain; retire `current-lattice-subtype-fn` callback; principled subtype-meet dispatch | ✅ | (commit-hash-pending). User-flagged 2026-04-30 as principled cleanup. `meet-registry` field added to sre-domain; `type-meet-registry` registered in unify.rkt; `type-lattice-meet` refactored with `#:subtype-fn` keyword; callback retired; lint baseline updated; `type-pseudo-complement` updated to use explicit subtype-fn. **Bonus discovery**: Track 2G's "type lattice not distributive under equality merge" finding was an artifact of the always-installed callback mixing equality+subtype semantics. Post-3c with principled per-relation dispatch, equality lattice IS distributive (216/216 triples confirmed) — Track 2H (PPN 4C T-3 Commit B) had made it distributive via union-aware merge; the callback hid this. 4 stale test expectations updated in test-sre-algebraic.rkt + 4 cascading tests updated in test-sre-track2h.rkt + 5 new Phase-3c tests added. Sister callback `current-lattice-meta-solution-fn` deferred to PM Track 12 (cross-referenced in PM Master + DEFERRED.md). |
| 3 | Empirical sweep across all registered domains × relations; record findings | ⬜ | Findings reported, NOT used to update registration declarations (separate pass per user 2026-04-30). |
| T | Dedicated test phase: `test-sre-sd-properties.rkt` | ⬜ | Per workflow.md MANDATORY dedicated test phase. |
| Discussion | Review Phase 3 findings with user; decide on Phase 4 (declaration updates) | ⬜ | Out-of-band of the implementation phases per user direction. |

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

**Goal**: Run the property sweep (including new SD checks) against every registered domain × relation pair using Phase 2's generator. Capture findings as a committed test fixture and a section in this design doc (§ Phase 3 Findings, populated when phase runs). **Do NOT update declared-properties at registration sites** — that's a separate post-discussion pass per user direction.

**Mini-design + audit**: deferred to phase open.

**Output**: a markdown table in this doc, one row per domain × relation, columns for each algebraic property with confirmed/refuted/untested + counterexample triple if refuted.

**Test coverage**: regression test that the sweep produces the recorded findings (so future SRE changes that alter merge functions surface as test-fixture changes, not silent property drift).

Estimated scope: ~50-75 LoC + diagnostic output. ~30-45 min.

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
