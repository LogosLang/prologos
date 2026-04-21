# PPN Track 4C — Design (D.3)

**Date**: 2026-04-17 (original) / 2026-04-18 (D.3 version stamp)
**Series**: PPN (Propagator-Parsing-Network) — Track 4C
**Status**: **D.3 — external critique round closed** (2026-04-18). All 17 findings from [`2026-04-18_PPN_TRACK4C_EXTERNAL_CRITIQUE.md`](2026-04-18_PPN_TRACK4C_EXTERNAL_CRITIQUE.md) resolved: 6 deferred to phase-time mini-design with obligations captured in Progress Tracker rows, 2 deferred cross-series (PM), 1 rejected by design, 8 accepted as documentation refinements. D.2 self-critique closed 2026-04-18. Ready for Stage 4 implementation (Phase 0 proper).
**Version history**:
- D.1 (2026-04-17): initial draft. Full NTT model, 9 axes, 14-phase roadmap.
- D.2 (2026-04-17): `:type`/`:term` as tag-layers on shared TypeFacet carrier (Module Theory Realization B, not separate facets with bridge). Residuation internal to the quantale. γ hole-fill reframed in propagator-mindspace (no "walks"). General Residual Solver scoped to future BSP-LE Track 6. Q4 closed (cell `:lattice` annotation; SRE domain registration layered). Q6 closed (per-(meta, trait) propagators + module-theoretic decomposition + PUnify + Hasse-indexed registry + ATMS + set-latch fan-in). All six open questions from D.1 now closed.
- D.2 refinement (2026-04-17, SRE+PUnify lens pass): Hasse-registry extracted as a first-class primitive (new §6.12) — foundational infrastructure used by Phase 7 parametric resolution and Phase 9b γ hole-fill, consumed by future tracks. New Phase 2b (primitive) and Phase 9b (γ hole-fill) added to Progress Tracker — γ previously had no explicit phase. "Realization A → B collapse" named as cross-cutting pattern. PUnify named explicitly in §6.1/§6.4/§6.6/§6.10 (previously implicit). Stratification framed as module composition in §6.7/§6.11.1. Union ATMS branching framed as ⊕ ctor-desc decomposition in §6.10. SRE ctor-desc auto-derivation flagged as simplification opportunity in §6.4.
- D.2 refinement (2026-04-17, R1+P4 incorporation from [self-critique](2026-04-17_PPN_TRACK4C_SELF_CRITIQUE.md)): A8 enforcement restructured from cell-level `:lattice` annotation (D.2 original) to Tier 1/2/3 architecture with **merge-function inheritance** and **`#:domain` override**. Classification belongs to the lattice (Tier 1) via SRE domain registration, implemented by registered merge functions (Tier 2), inherited by cells (Tier 3). Cell-level `:lattice` language retired as conceptually wrong ("a cell is not a lattice"). Production migration scope clarified: **101 call sites / 37 merge functions** (not 666 — original figure included tests/benchmarks/cache), top 10 merge functions cover 70% of production calls. Override keyword `#:domain` takes a named registered domain; no anonymous classification tags.
- D.2 refinement (2026-04-17, S1 incorporation): TypeToWarnings bridge added to §4.3 (one-way α covering coercion + deprecation). Multi-source warning propagators (multiplicity, capability) documented in §4.4 as propagators (not bridges). Egress convention noted: driver reading `:warnings` is network output, not a bridge. ConstraintsToWarnings audit flagged for Phase 2.
- D.2 refinement (2026-04-17, M2+R4 incorporation — PUnify audit): audit of unify.rkt (1028 lines) confirms "PUnify IS the match operation" claims across 6 sections map directly to existing infrastructure (`sre-structural-classify`, `unify-union-components`, `type-tensor-core`, `subtype-lattice-merge`, `current-structural-meta-lookup`, flex-app machinery). **Variance support is already first-class via `'subtype` relation name** — no new PUnify work required. New §6.13 captures the audit; §6.1/§6.2/§6.4/§6.5/§6.6/§6.10/§6.12 cite specific existing mechanisms. Net-new PUnify work: ~150-200 lines of composition wiring across phases, no algorithm development.
- D.2 refinement (2026-04-18, M5 incorporation — residuation check timing): **lazy evaluation of cross-tag residuation check**, refined and verified correct. "Lazy" means skipped-when-unnecessary AND re-fired-on-narrowing, executed synchronously within the merge function (not deferred to a separate propagator). Trigger: cross-tag present AND (CLASSIFIER narrowed OR INHABITANT narrowed). Case 2 (narrowing re-check) is the subtle case naive lazy-cache-and-skip would miss. Option 4 (separate propagator for the check) dismissed — would create a timing window with unverified cross-tag state. Correctness compatible with BSP/CALM/ATMS. Verification plan: parity test cases (Phase 0) + property inference (Phase 2) + A/B micro-bench (Phase 3). Details in §6.2.
- D.2 refinement (2026-04-18, minors batch — M1/M3/M4/P3/R5): Language polish and clarifications. M1: "walks the Hasse diagram" → "dispatches through Hasse structural index" (§6.5, §6.12) — removes step-think wording. M3: `lookup` in Hasse-registry is a helper function invoked synchronously from consuming propagators' fire bodies, not a standalone propagator (§6.12). M4: "ATMS union branching IS ⊕ ctor-desc" framed as a conceptual lens, not an implementation change — Phase 10 uses existing `atms-amb` machinery (§6.10). P3: CHAMP retirement deletes the code path entirely; residual reads are compile errors, coupling A8 enforcement to A2 retirement (§6.3). R5: `current-meta-source-registry` Racket parameter explicitly declared as the side registry for meta source-loc metadata (§6.3).
- D.2 refinement (2026-04-18, O2 incorporation — comprehensive lens catalog): new §6.11.8 applies the SRE lens uniformly to all non-facet lattices in 4C (AttributeRecord, AttributeMap, impl coherence, inhabitant catalog, Hasse-registry ambient L, worldview Q_n, ready-queue, retraction request set, tagged-cell-value layers). Surfaces two structural insights: (a) impl coherence lattice (Phase 7) and inhabitant catalog (Phase 9b) are **structurally identical Hasse-registry instances** — both PUnify-with-`'subtype` over Hasse-indexed entries; §6.12 primitive abstracts the identity. (b) tagged-cell-value layer lattice is the **structural generalization** of Module Theory Realization B — every "shared-carrier + tags" situation in 4C is an instance (`:type`/`:term`, `:constraints` by trait, worldview by assumption, attribute-map by position). Pre-existing subsections (§6.11.2, §6.11.3, §6.11.4) cross-referenced; catalog provides the full lens applied to every lattice.
- D.2 refinement (2026-04-18, O3 incorporation — provenance as structural emergence): new §6.1.1 specifies the provenance infrastructure. Per [Module Theory §5-6](../research/2026-03-28_MODULE_THEORY_LATTICES.md) + [Hypergraph Rewriting §6.3](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md), provenance is structurally emergent from the propagator-firing dependency graph — not a new data structure. Three structural sources compose: ATMS assumption tagging, `:trace :structural` mode, source-location registry. **Error-reporting via backward residuation** on the Module-Theoretic chain structure — in 4C scope per user direction. Intended use case: first-class compiler and error features (not a debugging aid) — precise source-code mapping, human-readable messages with derivation context, machine-readable traces for IDE/LSP tooling. New **Phase 11b** (diagnostic infrastructure) added to Progress Tracker, consuming the provenance infrastructure built in Phases 3/4/9/11. `derivation-chain-for(position, tag)` helper API shape deferred to phase-time mini-design.
- D.2 self-critique round closed (2026-04-18): P1 resolved-by-design — Option A scaffold-period concern dissolves under phase sequencing (no alternative code path exists during Phases 9-11b; Phase 12 retires atomically). All P/R/M/SRE findings now resolved. D.2 ready for external critique. Full round summary in [`2026-04-17_PPN_TRACK4C_SELF_CRITIQUE.md`](2026-04-17_PPN_TRACK4C_SELF_CRITIQUE.md) §8.
- **D.3 (2026-04-18) — external critique round closed**: all 17 findings from [`2026-04-18_PPN_TRACK4C_EXTERNAL_CRITIQUE.md`](2026-04-18_PPN_TRACK4C_EXTERNAL_CRITIQUE.md) resolved. Notable outcomes absorbed into D.2 structure as in-place refinements: **R2** Phase 12 sub-split 12a/b/c/d + pipeline premise refined (post-Tracks-2/3/4A/4B, not 14-file cascade). **M2** tropical-lattice fuel cell adopted as lean — first practical tropical-lattice in Prologos production; template for upcoming PReduce. **M4** Phase 11b diagnostic as read-time derivation (option b); **trace monoidal category theory** (Joyal-Street-Verity 1996, Hasegawa 1997, Abramsky-Haghverdi-Scott 2002) raised as research input to the Phase 11b mini-design. **P3** Phase 6 structural-coverage lean over discipline coverage. **S2** §6.5.1 added (tag distributivity); **S3** §6.12.6 added (L_impl and L_inhabitant instantiations). **R1** §17 Reality-Check Artifacts appendix added (reproducible grep commands). Six findings (P3, P4, M1, M3, S1, C1, C2) deferred to phase-time mini-design with obligation lists in Progress Tracker rows. Parity skeleton [`test-elaboration-parity.rkt`](../../racket/prologos/tests/test-elaboration-parity.rkt) committed at D.3 per M3 methodology.
**Prior art**: [4C Audit](2026-04-17_PPN_TRACK4C_AUDIT.md), [4C Design Note](../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md), [PPN Master](2026-03-26_PPN_MASTER.md), [PPN 4 PIR](2026-04-04_PPN_TRACK4_PIR.md), [PPN 4B PIR](2026-04-07_PPN_TRACK4B_PIR.md), [BSP-LE 2B PIR](2026-04-16_BSP_LE_TRACK2B_PIR.md), [Cell-Based TMS Design Note](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md), [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md), [Hypergraph Rewriting Research](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md), [Adhesive Categories Research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md), [Attribute Grammars Research](../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md), [Prologos Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md), [Grammar Toplevel Form](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md), [SEXP IR to Propagator Compiler](../research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md).

---

## §1 Thesis

**Bring elaboration completely on-network.** Designed with the mantra as north star. Guided by the ten load-bearing design principles. NTT is guiderails and verification that we are doing this correctly.

- **Mantra** ([`on-network.md`](../../.claude/rules/on-network.md)): *"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."* Every propagator install, cell allocation, loop, parameter, return value is filtered against this.
- **Principles**: the ten load-bearing principles ([`DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org)). Infrastructure choices and design trade-offs will be annotated with principle served during the critique round; D.1 states them informally as rationale.
- **NTT**: *guiderails*. Every structural piece must be expressible in [NTT syntax](2026-03-22_NTT_SYNTAX_DESIGN.md). Pieces not expressible are mantra violations with scaffolding labels. The NTT model is the north-star shape; prose follows from it (§4 NTT model → §6 prose).
- **Solver infrastructure**: BSP-LE Tracks 2+2B built the orchestration, ATMS, stratification, and scope-sharing primitives specifically so PPN 4 can use them for elaboration. Elaboration IS constraint satisfaction over a quantale-structured domain — the same problem the solver solves, lifted by the richness of the lattice (types, terms, contexts, usage, constraints, warnings).

**Scope** (per user direction 2026-04-17):

- Everything not delivered in 4A/4B is in scope.
- The 6 imperative bridges retire.
- **Zonk retirement ENTIRELY** — `zonk-intermediate`, `zonk-final`, `zonk-level` (~1,300 lines in [zonk.rkt](../../racket/prologos/zonk.rkt)) deleted. This was the original PPN 4 Phase 4b target ([Track 4 Design §3.4b](2026-04-04_PPN_TRACK4_DESIGN.md)) unmet in 4B; owned by 4C Phase 12 via Option C (cell-refs replace `expr-meta`, reading the expression IS zonking).
- Union types via ATMS delivered (BSP-LE 1.5 cell-based TMS pulled in as 4C sub-track).
- Elaborator strata (S(-1)/L1/L2) unified onto BSP scheduler via `register-stratum-handler!`.
- `:type` / `:term` facet split (Coq-style metavariable discipline, MLTT-grounded).
- Option A AND Option C for freeze/zonk — Option A is a staging scaffold; Option C is the zonk-retirement phase. Option C contributes DPO-style rewriting primitives to SRE Track 6.
- **Hole-fill (γ residuation direction)** in scope via reuse of existing proof-search substrate (BSP + stratification + ATMS + worldview bitmask) as a dedicated propagator on the attribute-map. Does NOT depend on general residual solver (future BSP-LE track); uses substrate directly, matching how typing-propagators.rkt already consumes it.
- `:component-paths` enforcement at registration time (in 4C; NTT type-error formalization deferred to NTT work).
- **Parameter+cell dual-store sweep**: catalogue all Racket-parameter + propagator-cell dual stores in the codebase (like `current-coercion-warnings` + `...-cell-id`). Pre-0 finding: `that-read` is ~1400× faster than CHAMP reads, suggesting similar latent wins in other dual-store sites. Retire dual-stores uniformly — not just the 6 named bridges.
- **Hasse-registry primitive** (§6.12): extracted as first-class infrastructure. SRE-registered lattice + registration/structural-lookup interface. Used by Phase 7 (parametric impl registry) and Phase 9b (γ inhabitant catalog). Consumed by future tracks (general residual solver, PPN 5 disambiguation, FL-Narrowing refinement). User observation: *virtually every track will be designing for its own Hasse diagram.*
- **Tier 1/2/3 lattice architecture** for A8 enforcement (§6.8, refined from self-critique R1+P4): lattice types (Tier 1 via A9) — merge functions (Tier 2 `register-merge-fn!/lattice`) — cells (Tier 3 inherit). Cell-level `:lattice` retired as conceptually wrong; replaced by Tier 2 inheritance with `#:domain` override keyword. Aligns with NTT `impl Lattice L` syntax directly.

**Cross-cutting pattern — "Realization A → B collapse"**: several axes follow the same pattern of moving from Module Theory Realization A (separate cells with bridges) to Realization B (shared-carrier-with-tagging). Named here so the consistency is explicit across axes:
- A5 (`:type`/`:term`): two facets with `TermInhabitsType` bridge → tag-layers on shared TypeFacet carrier.
- A2 (CHAMP retirement): CHAMP as separate store → `:term` tag-layer on shared carrier.
- A6 (warnings): Racket-parameter + cell dual → single `:warnings` facet.
- A1 (constraints decomposition): flat `:constraints` set → trait-tagged layers on shared `:constraints` carrier.
- O1 sweep: every dual-store discovered in the codebase — same pattern applied uniformly.

**Out of scope**:

- Track 7 (user-surface `grammar` + `that`). 4C delivers the infrastructure; Track 7 is surface elevation.
- PM Track 12 (module loading on network). Orthogonal.
- NTT syntax design refinement (gated on PPN 4 completion).

---

## §2 Progress Tracker and Phased Roadmap

Each phase completes with the 5-step blocking checklist (tests, commit, tracker, dailies, proceed). Each phase ends with a dialogue checkpoint (Conversational Implementation Cadence). NTT-conformance check per phase alongside tests-green.

**Parity test obligations per phase**: see §9.1 "Per-phase parity-test enablement" — each phase that produces a divergence class is responsible for enabling and populating the corresponding tests in [`test-elaboration-parity.rkt`](../../racket/prologos/tests/test-elaboration-parity.rkt). Phase-completion step (a') = "parity tests for this phase enabled and passing."

### Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | Acceptance file + Pre-0 benchmarks + parity skeleton | ✅ | All three artifacts committed and verified clean (2026-04-19): [`examples/2026-04-17-ppn-track4c.prologos`](../../racket/prologos/examples/2026-04-17-ppn-track4c.prologos) broad pipeline exercise runs clean via `process-file`; [`bench-ppn-track4c.rkt`](../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) Pre-0 baseline complete ([`PRE0_REPORT`](2026-04-17_PPN_TRACK4C_PRE0_REPORT.md)); [`test-elaboration-parity.rkt`](../../racket/prologos/tests/test-elaboration-parity.rkt) skeleton committed with SKIP tags per §9.1. **Per-phase regression discipline**: run `process-file` on the acceptance file before AND after each phase; phase not DONE until 0 errors. |
| 1 | A8 `:component-paths` enforcement via Tier 2 merge-function inheritance (Phase 1 envelope — multiple sub-phases) | 🔄 | **Phase 1a ✅ (2026-04-19)** — [`tools/lint-cells.rkt`](../../racket/prologos/tools/lint-cells.rkt) created + baseline saved ([`tools/cell-lint-baseline.txt`](../../racket/prologos/tools/cell-lint-baseline.txt)); 101 production sites / 27 unique unregistered merge fns / 1 inline lambda / 6 ambiguous-name / 11 multi-line. **Phase 1b ✅ (2026-04-19)** — [`merge-fn-registry.rkt`](../../racket/prologos/merge-fn-registry.rkt) Tier 2 API: `register-merge-fn!/lattice` + `lookup-merge-fn-domain` per §6.8 option (a) (independent reverse-lookup registry, function-object `eq?` keying, idempotent-same-domain/error-different-domain collision semantics, scaffolding-labeled for PM Track 12). [`tests/test-merge-fn-registry.rkt`](../../racket/prologos/tests/test-merge-fn-registry.rkt) 8/8 GREEN. **Phase 1c ✅ (2026-04-19)** — `#:domain` keyword extended to `net-new-cell`, `net-new-cell-desc`, `net-new-cell-widen`; batch inherits automatically via `lookup-merge-fn-domain` on each spec's merge-fn. Storage: `cell-domains` CHAMP added to `prop-net-cold` (option (β) — parallel CHAMP, minimal blast radius — 1 struct definition + 1 positional constructor + 1 accessor; 15 `struct-copy prop-net-cold` sites unchanged via struct-copy field preservation). New `lookup-cell-domain` API for Phase 1f. [`tests/test-cell-domain-inheritance.rkt`](../../racket/prologos/tests/test-cell-domain-inheritance.rkt) 10/10 GREEN. Suite: 6017 tests GREEN, 110.6s (no regression). **Tier 1/2/3 architecture** (§6.8). Tier 1 = SRE-registered lattice type with classification (A9 covers the 6 facets). Tier 2 (NEW): `register-merge-fn!/lattice` registers a merge function `#:for-domain DomainName` — links Tier 2 implementation to Tier 1 type. Tier 3: `net-new-cell` inherits domain from merge function; `#:domain DomainName` keyword for explicit override (rare, must be registered). Audit scope: **~37 production merge functions** (not 666 cell sites). Top 10 cover 70% of production calls. `tools/lint-cells.rkt` baselines unregistered merge functions and `#:domain` overrides. Mini-design during Phase 1 for Tier 2 API shape. |
| **1.5** | **srcloc infrastructure** | ✅ (2026-04-19) | **Foundational srcloc infrastructure for compiler + tooling.** Design: hybrid (α)+(η) — `current-source-loc` parameter (read convenience) derived from on-network state. [`source-location.rkt`](../../racket/prologos/source-location.rkt) gains `current-source-loc` parameter. `propagator` struct gains `srcloc` field (on-network). `fire-propagator` wrapper parameterizes from propagator's srcloc field — fire functions stay stateless. [`surface-syntax.rkt`](../../racket/prologos/surface-syntax.rkt) gains `surf-node-srcloc` generic extractor (uses `struct->vector`; srcloc is always last field in `#:transparent` surf-* structs). `elaborate` wraps body with `parameterize` from surf-node srcloc. `driver.rkt::process-command` parameterizes from command surf-node srcloc. `net-add-propagator` + `-broadcast` + `-fire-once` gain `#:srcloc [srcloc #f]` kwarg. 6 scheduler fire-call sites replaced with `(fire-propagator prop net)` helper. Pipeline impact minimal (0 `struct-copy propagator` sites, 2 positional constructor updates). Forward-enables: Phase 2 `:warnings` correct-first-time registration, Phase 5 warnings authority (srcloc struct field + merge-set-union switch), Phase 11b diagnostic (M4), LSP tooling (PM Track 11), error recovery (PPN Track 6), type-directed disambiguation (PPN Track 5). [`tests/test-source-loc-infrastructure.rkt`](../../racket/prologos/tests/test-source-loc-infrastructure.rkt) 12/12 GREEN. Affected suite: 6379 tests GREEN, 111.2s (no regression). DEFERRED.md row added for `current-source-loc` parameter (PM Track 12 evaluates retention during scoping phase — parameter-shaped concept may remain). |
| 2 | A9 facet SRE domain registrations | ✅ (2026-04-19) | 4 facet domains registered: `:context`, `:usage`, `:constraints`, `:warnings`. `:term` deferred to Phase 3. Each facet = atomic Tier 1 + Tier 2 registration (Q7 resolved post-audit 2026-04-19 — Completeness). **Tests**: [`test-facet-sre-registration.rkt`](../../racket/prologos/tests/test-facet-sre-registration.rkt) 21/21 GREEN. **Suite**: 4945 affected-tests GREEN, 104.7s, no regression. **R5 contingency**: 1 real finding within K=2 — `:usage` idempotence refuted (accepted design — QTT semiring addition is a commutative MONOID, not join-semilattice). **D2 delta resolutions**: `:context` non-commutative accepted (quantale-like binding-stack semantics); `:usage` non-idempotent accepted (semiring monoid); `:warnings` comm+idem refuted → Phase 5 fixes via srcloc-in-value; `:constraints` + `:type` no delta. Bot-safe `context-facet-merge` wrapper added (Tier 2 registration needs total merge fn; raw `context-cell-merge` assumed bot-handling at facet-merge layer). **Per-facet merge functions** (audit 2026-04-19): `:context` → `context-cell-merge`, `:usage` → `add-usage`, `:constraints` → `constraint-merge`, `:warnings` → `warnings-facet-merge` (Phase 2 wraps raw `append` as named function). **D2 framework**: each facet ships aspirational / declared / inference / delta table as commit artifact (see §6.9.2). Property inference explicitly invoked (not auto-triggered). **Phase 1.5 unblocks** set-lattice ambition for `:warnings`, but Phase 2 registers current state (append + minimal properties + delta → Phase 5 fixes). **D1 resolution**: `:warnings` as set lattice with srcloc-in-value (target, Phase 5 completes); `:context` accepts non-commutative monoidal structure (binding-stack scope semantics, quantale-like). **R5 contingency**: K=2 bugs absorbed in Phase 2; K+1 opens Phase 2c repair. Predicted real bugs: 0 (both predicted refutations are accepted design or scoped to Phase 5). **S1 audit cleared**: no ConstraintsToWarnings bridge needed (no such flow in 4B). |
| 2b | Hasse-registry primitive | ✅ (2026-04-19) | Thin wrapper on existing infrastructure. [`hasse-registry.rkt`](../../racket/prologos/hasse-registry.rkt) (~240 lines). Cell uses `hasse-merge-hash-union` (equal?-based; positions are structured values — types, patterns, pairs — requiring equal? semantics not eq?). Handle struct carries cell-id + l-domain-name + position-fn + subsume-fn; consumer-provided subsume-fn (canonical impl uses PUnify+SRE; Q_n lattices override with bitmask per prior art). No materialized edges — Hasse order implicit in subsume-fn. Register = O(1) cell write; Lookup = O(N × subsume-cost) generic, O(1) bitmask for Q_n. SRE domain `'hasse-registry` registered (D2: comm + assoc + idem expected, no delta). Tier 2 linkage: `hasse-merge-hash-union` → `'hasse-registry`. [`tests/test-hasse-registry.rkt`](../../racket/prologos/tests/test-hasse-registry.rkt) 14/14 GREEN including bitmask-override test demonstrating Q_n pattern. Generalizes existing Hasse practice (tagged-cell-value across 10+ files; ATMS subcube bitmask from hypercube research). Foundational for Phase 7 (L_impl) + Phase 9b (L_inhabitant) + future tracks (PPN 5, FL-Narrowing, PM trait coherence, SRE Track 6, General Residual Solver). See §6.12. Handle struct = Racket-level scaffolding noted in DEFERRED.md (PM Track 12 evaluates). |
| 3 | A5 `:type` / `:term` facet split | 🔄 | See **§6.15** for full Phase 3 mini-design (2026-04-20). **S1 resolved**: reading (i) — TermFacet IS the SRE 2H quantale; `:type`/`:term` are role-tags over ONE carrier lattice with tag-dispatched merge. SRE lens Q1-Q6 answered in §6.15.1. **P4 resolved**: path (b) — cross-tag merge emits stratum request; merge stays pure `(v × v → v)`. Worldview-tagging of the request is a Phase 3+9 joint mini-design item tracked in §6.15.6. **Sub-phase partition**: 3a+3b atomic (facet infra + tag-dispatched merge), 3c migration of typing-propagators, 3d parity tests + lazy-vs-eager A/B bench, 3e Phase 1f classification to `'structural`, 3V Vision Alignment Gate. **PU audit**: Phase 3 is PU-aligned (attribute-map already compound; only VALUE SHAPE changes). Per-meta-cell consolidation deferred to Phase 4 mini-design. **Drift risks** at §6.15.8. **3a+3b ✅** (commit `98f503a2`): [`classify-inhabit.rkt`](../../racket/prologos/classify-inhabit.rkt) delivers tag-layer struct + pure accumulation merge + `'classify-inhabit` SRE domain (Tier 1 'structural + Tier 2 linkage). Classifier × classifier uses `type-lattice-merge`; inhabitant × inhabitant uses equal? (α-equiv proxy for 3a+3b MVP; 3c refines via ctor-desc). Cross-tag residuation check deferred to 3c as dedicated propagator per P4(b). 19/19 tests GREEN. **3c-i ✅** (commit `f21ed694`): reshape `:type` facet VALUE SHAPE to `classify-inhabit-value` + reader shim + `:term` magic keyword dispatch. Facet registration triple (merge/bot/bot?) updated atomically. Raw-value backward-compat at the boundary via Module-Theory embedding (base → classifier-only). New [`tests/test-facet-tag-dispatch.rkt`](../../racket/prologos/tests/test-facet-tag-dispatch.rkt) 20/20 GREEN. All 8 drift risks from 3c-i mini-design audit cleared. 7911 full-suite tests GREEN at 122.2s. **3c-ii ✅** (commit `08782d1a`): per-rule writer migration — 3 INHABITANT sites migrated to `:term` (trait-resolution dict-expr write, meta-feedback simple case, meta-feedback structural case) via new `term-map-read` / `term-map-write` helpers symmetric with `type-map-read` / `type-map-write`. Bridge migration surfaced by test-hasmethod-01 regression: `make-meta-solution-output-fire-fn` reads `:term` (not `:type`) — meta solutions live in INHABITANT. 7914 full-suite tests GREEN at 119.8s. **3c-iii ✅** (commit `2e768b0d`): cross-tag residuation propagator + stratum handler per Q2. cell-id 10 = classify-inhabit-request (pre-allocated in make-prop-network, next-cell-id 10→11). `type-of-expr` helper classifies literals + type-constructors. `make-classify-inhabit-residuation-fire-fn` threshold-fires; uses `subtype?` predicate (semantically correct for compatibility check; `subtype-lattice-merge` returns union for incomparable types not type-top). Contradiction write is the `'classify-inhabit-contradiction` sentinel; merge absorbs via existing path. Stratum handler registered; Phase 9 consumes request cell for ATMS-tagged fork-on-narrowing per §6.15.6 joint item. Install parallel to meta-solution-output at install-typing-network. New [`tests/test-residuation-propagator.rkt`](../../racket/prologos/tests/test-residuation-propagator.rkt) 15/15 GREEN including **Option C skip dissolution verification** (§6.15.9 #8): Type(0) classifier + Nat inhabitant resolves cleanly. test-propagator / test-observatory / test-trace-serialize updated for cell-id 10→11 cascade. 7929 full-suite tests GREEN at 126.3s. |
| 4 | A2 CHAMP retirement | ⬜ | Migrate `solve-meta!` writes; migrate all CHAMP readers; delete code path. **Mini-design decision (NEW 2026-04-20, Phase 3 mini-design surfaced)**: per-meta-cell authority vs compound meta-cell. Currently elaborator-network.rkt allocates N cells for N metas (`elab-fresh-type-cell`, etc.). PU pattern would suggest consolidation into ONE compound meta-cell with `hasheq meta-id → meta-value`, component-indexed by meta-id. Phase 4 is where this decision locks because CHAMP retirement forces meta-solution authority into cells. Options: (α) keep per-meta cells — status quo, simpler; (β) compound meta-cell — PU-aligned, better CHAMP structural sharing, component-paths by meta-id; (γ) hybrid — per-meta for cells that participate in many propagator reads, compound for rarer accesses. Decision at Phase 4 start informed by read-site audit + allocation profiling. Tag-layer scheme from Phase 3 works in all three options. |
| 5 | A6 Warnings authority | ⬜ | `:warnings` facet authoritative; parameter retired. **Scope (R4 external critique 2026-04-18)**: `current-coercion-warnings` parameter retirement = ~5 edit sites across 2 files ([`warnings.rkt`](../../racket/prologos/warnings.rkt) lines 62, 81-82, 105-106, 122, 131-133 + [`driver.rkt:467`](../../racket/prologos/driver.rkt) parameterize). Parallel retirement in scope: `current-deprecation-warnings` + `current-capability-warnings` (same dual-write pattern per [`warnings.rkt:158, 186, 207`](../../racket/prologos/warnings.rkt)). **Scope addition (2026-04-19)**: add srcloc field to warning structs (`coercion-warning`, `deprecation-warning`, `capability-warning`, `process-cap-warning`) + thread srcloc at emit sites (~10-12 callers, uses Phase 1.5 srcloc API) + update format functions to sort-by-srcloc + switch merge from `merge-list-append` to `merge-set-union` (already in lint baseline). Re-runs `:warnings` property inference — should confirm commutative + idempotent + associative now that position is in-value. Resolves Phase 2 `:warnings` D2 delta. |
| 6 | A3 Aspect-coverage completion | ⬜ | Audit uncovered AST kinds; register typing rules per kind. **Mini-design decision (P3 external critique 2026-04-18)**: coverage guarantee shape — (a) discipline coverage (exhaustive registration + `infer/err` fallback retained for safety) vs. (b) structural coverage (coverage cell with hash-union merge AST-kind → rule-id; network-build-time assertion iterates `syntax.rkt` `expr-*` predicates; `infer/err` deleted as a concept; missing coverage = contradiction at build time). **Lean: (b)** — Correct-by-Construction + Completeness + mantra discipline favor structural; keeping `infer/err` is belt-and-suspenders. Mechanism parallels Axis 8 registration-time enforcement (Phase 1). Mini-design deepens tradeoffs including implementation cost, timing of `infer/err` deletion, interaction with Phase 1's enforcement framework. **Mini-design consideration (C1 external critique 2026-04-18)**: Phase 6 → Phase 7 sequencing gate — if structural coverage (P3 lean (b)) is adopted, the gate is automatic: Phase 7 cannot start until the Phase 6 build-time assertion passes (no ⊥ entries in coverage cell for any `expr-*` kind reachable from Phase 7's acceptance tests). If P3 mini-design picks (a) discipline coverage instead, C1 needs its own explicit quiescence-gate treatment. C1 resolves as side-effect of P3's structural-coverage decision when (b) is chosen. |
| 7 | A1 Parametric trait-resolution — per-(meta, trait) propagators | ⬜ | `:constraints` facet tagged by trait (Module Theory Realization B). Per-(meta, trait) propagator on tagged layer. Hasse-indexed impl registry. PUnify for match (via SRE ctor-desc). ATMS branching on multi-candidate (via Phase 9 cell-based TMS). Set-latch fan-in for dict aggregation. Retires Bridge 1. **Mini-design decision (M1 external critique 2026-04-18)**: impl-registry write-path (module-load-time `impl X Y` registration) — cell-write on `impl-registry-cell` with hash-union merge, or imperative `register-impl!` labeled scaffolding owned by PM Track 12. Decision deferred to Phase 7 mini-design; must be consistent with Phase 9b's constructor-catalog write-path. |
| 8 | A4 Option A freeze | ⬜ | Tree walk reads `:term` facet; scaffold labeled for Option C retirement |
| 9 | BSP-LE 1.5 sub-track (cell-based TMS) | ⬜ | Phases A-D from design note. **Joint mini-design item from Phase 3 (NEW 2026-04-20, §6.15.6)**: P4(b)'s stratum-request mechanism (from Phase 3) carries worldview assumption-id as metadata. Phase 9 refines how the stratum handler binds worldview during request processing, how writes to destination cells get worldview-tagged, how S(-1) retraction narrows dependent writes. Pattern precedent: S1 NAF handler in relations.rkt. Phase 3 ships mechanism; Phase 9 adds worldview overlay. Hypercube / Hasse-diagram considerations (BSP-LE hypercube addendum: Q_n worldview lattice, Gray-code traversal, bitmask subcube pruning) revisit at Phase 9 mini-design. **Mini-design decision (C2 external critique 2026-04-18)**: relationship to existing ATMS infrastructure (`elab-speculation.rkt`, `save-meta-state`/`restore-meta-state!`, per-propagator worldview-bitmask, S1 NAF fork+BSP, discrimination). Choose between (1) substrate-only — Phase 9 delivers cell-based TMS; Phase 10 consumes; existing ATMS migration owned by a later named track labeled explicitly as scaffolding; (2) substrate + one representative migration as proof-of-concept; (3) wholesale replacement inside 4C via 9a/9b-new/9c split. Belt-and-suspenders steady state rejected by `workflow.md` — whatever shape chosen must avoid two TMS mechanisms as permanent state. Mini-design produces an R-lens inventory of existing ATMS-like call sites before picking shape. **Mini-design decision (M2 external critique 2026-04-18)**: ATMS fuel representation — (a) imperative decrementing counter (existing pattern) vs. (b) **tropical-lattice fuel cell** with min-merge; exhaustion hits tropical bottom → fires fuel-contradiction cell write, structurally indistinguishable from any other contradiction. **Lean: (b)** — on-network mandate + Completeness + composition with backward-residuation (M4). **Significance**: this is the *first practical implementation* of the tropical-lattice/quantale/semiring/cost-optimization structure in Prologos — the pattern has been theorized (Hyperlattice Conjecture, BSP-LE 2 research on tropical semirings, Module Theory §6 e-graphs as quotient modules) but not yet instantiated in production code. Phase 9 mini-design deepens tropical-fuel semantics; the pattern then becomes the template for upcoming PReduce (reductions on propagator networks with cost-optimization via tropical semiring). |
| 9b | γ hole-fill propagator (NEW in D.2) | ⬜ | Reactive propagator at two-threshold readiness (CLASSIFIER ground + INHABITANT bot). Consumes Phase 2b Hasse-registry for inhabitant catalog (type-env + constructor signatures). PUnify via ctor-desc for match. ATMS branching on multi-candidate via Phase 9 cell-based TMS. Set-latch fan-in for aggregation. Previously architecturally described in §6.2.1 but unphased; D.2 makes it explicit. **Mini-design decision (M1 external critique 2026-04-18)**: constructor-catalog write-path — must be consistent with Phase 7's impl-registry write-path decision (both are Hasse-registry instantiations). **Mini-design decision (M3 external critique 2026-04-18)**: γ re-firing on catalog growth — (a) γ fires once per hole at propagator-install time (risk: silent staleness when new constructors arrive), or (b) γ watches catalog cell via `#:component-paths` keyed on hole-type; catalog-growth events re-fire only γ propagators whose hole-type matches newly-arrived constructors. **Lean: (b)** via component-paths — Correct-by-Construction + Completeness + structurally-emergent-dataflow; component-paths guard minimizes spurious re-firing. M1 + M3 are catalog-write and catalog-read duals; mini-design resolves both together. |
| 10 | Phase 8 union types via ATMS | ⬜ | Fork-on-union, TMS-tagged branches, S(-1) retract |
| 11 | A7 Elaborator strata → BSP scheduler | ⬜ | S(-1)/S1/S2 as BSP handlers. **Orchestrator retirement (R3 external critique 2026-04-18)**: BOTH orchestrators retire in Phase 11 — `run-stratified-resolution!` ([metavar-store.rkt:1863](../../racket/prologos/metavar-store.rkt), already dead code per comment at line 1860, zero production callers confirmed by grep 2026-04-18) is deleted as hygienic prelude; `run-stratified-resolution-pure` ([metavar-store.rkt:1915](../../racket/prologos/metavar-store.rkt), production path called at [line 1699](../../racket/prologos/metavar-store.rkt)) is retired as main work. |
| 11b | Diagnostic infrastructure — residuation-backward error reporting (NEW in D.2) | ⬜ | First-class compiler + error features per user direction 2026-04-18. `derivation-chain-for(position, tag)` helper (API shape phase-time mini-design). Human-readable error messages with source-loc + propagator rationale; machine-readable structured traces for IDE/LSP. Backward residuation over the propagator-firing dependency graph (Module-Theory-principled, not ad-hoc tracker). See §6.1.1. **M4 external-critique lean (2026-04-18)**: read-time derivation (option b) — no error-propagator fires; `derivation-chain-for` is a read-time function over the dependency graph. **Research input**: trace monoidal category theory (Joyal-Street-Verity 1996; Hasegawa 1997; Abramsky-Haghverdi-Scott 2002) — network forms traced SMC, provenance IS trace morphism, backward residuation IS adjoint structure of trace. Consume before mini-design finalization. **Scope addition (2026-04-19) — Gap B from Phase 1.5 mini-audit**: `expr-*` core AST nodes currently carry NO srcloc field (~50 structs in syntax.rkt). Phase 11b's backward-residuation anchors need srcloc at post-elaboration nodes for precise source mapping. Decide at Phase 11b mini-design: (a) add srcloc field to all `expr-*` structs (pipeline.md cascade — 50 structs + struct-copy audit), or (b) side-channel mapping `(expr-node-identity → srcloc)` maintained during elaboration, or (c) Phase 1.5's propagator-struct srcloc proves sufficient via cell provenance tags without needing per-expr-node srcloc. Resolution informed by actual Phase 11b use cases. **Scope addition (2026-04-20) — identity-or-error upgrade from Phase 1e (Q4 resolution)**: Phase 1e replace-cell audit uses path (A) sentinel + `#:contradicts?` predicate for identity-or-error merges in the short term. Phase 11b upgrades identity-or-error sites to path (C) provenance-rich contradiction descriptors — returning a structured contradict-record carrying the conflicting values + their srclocs + producer propagator IDs. When `derivation-chain-for` fires on an identity-or-error contradiction, the chain starts with the two conflicting writes' provenance. Upgrade is non-breaking (the contradict-record's `contradicts?` predicate still returns true; the sentinel just carries more data). Captured here per Phase 1e Q4 resolution 2026-04-20. |
| 12a | A4 Option C — introduce `expr-cell-ref` struct + dereferencing primitive | ⬜ | No call-site changes yet. New struct in [`syntax.rkt`](../../racket/prologos/syntax.rkt); dereferencing API (cell-ops or similar). Post-R2 external-critique refinement 2026-04-18: pipeline is already collapsed by Tracks 2/3/4A/4B (tree-parser primary; 90% typing on-network); the original "14-file cascade" framing is stale. Phase 12 remains substantial (104 `expr-meta` occurrences across 19 files) but smaller than D.1 assumed. |
| 12b | A4 Option C — flip `expr-meta` construction to `expr-cell-ref` | ⬜ | Meta installation sites produce `expr-cell-ref`; readers go through the new dereferencing API. Residual `expr-meta` constructors deleted. |
| 12c | A4 Option C — delete `zonk.rkt` wholesale | ⬜ | `zonk-intermediate`/`zonk-final`/`zonk-level` deleted (~1,300 lines). Driver `freeze-top`/`zonk-top` plumbing retired. Reading the expression IS zonking via cell-ref dereferencing. |
| 12d | A4 Option C — acceptance + A/B + integration | ⬜ | L3 acceptance confirms cell-ref path clean; A/B bench shows E3 freeze cost → 0; no regressions. DPO primitives contributed to SRE 6. Meets original [Track 4 §3.4b](2026-04-04_PPN_TRACK4_DESIGN.md) expectation unmet in 4B. |
| 1d | Registration campaign (Phase 1 sub-phase) | ✅ | Register remaining ~22 unregistered merge functions + 1 inline lambda rewrite + triage 11 multi-line sites + lint-tool category refinement for parameterized-passthrough sites. **δ approach (D1 resolution 2026-04-19)**: `merge-hasheq-union` registered under `'monotone-registry` domain with honest D2 delta documenting non-commutative-by-mechanics / commutative-by-intent gap. **Decentralized (β)**: each merge fn registers where it lives (atms.rkt, session-runtime.rkt, relations.rkt, tabling.rkt, infra-cell.rkt, etc.). Ambiguous-name sites (6) left as-is per D3 resolution — runtime Tier 3 inheritance is correct; lint tool rename to "parameterized-passthrough" category. Lint baseline shrinks; goal: `--strict` green. **1d-A ✅** (commit `f9345fd6`) infra-cell generic merges; **1d-B ✅** (commit `6ce7a50d`) per-subsystem merges; **1d-C ✅** (commit `99d9acad`) inline lambda → `merge-list-append`; inline-lambda count 1 → 0. **1d-D ✅** (commit `bb6046b5`) 11 multi-line sites classified: 3 new registrations (`decisions-state-merge`, `commitments-state-merge`, `wf-all-mode-merge`) + `solver-term-merge` noted as internal-unexported follow-up + 6 parameterized-passthrough confirmed + atms.rkt:761 replace-lambda scoped to Phase 1e. **1d-E ✅** (commit `4c0a250e`) lint category rename `ambiguous-name → parameterized-passthrough` per D3. **1d-F ✅** (commit `7675517c`) lint helper detection for `register/minimal` shape (registered count 36 → 78 — 17 helper-registered fns now correctly tracked) + `answer-merge` replaced with `merge-list-append` (same pattern as 1d-C). **1d-close ✅** (this row) — baseline shrunk 27 → 6; `--strict` exits 0. Remaining baseline: `logic-var-merge` (1d-B follow-up), `merge-last-write-wins` (Phase 1e), `racket-merge` + `viability-merge` (fundamentally parameterized closures — further lint improvement or category extension possible), `table-answer-merge` + `table-registry-merge` (Phase 1e hoist). Phase 1d COMPLETE. |
| 1e | Correctness refactors (Phase 1 sub-phase, NEW 2026-04-19; sub-phases designed 2026-04-20) | ✅ | See **§6.14** for full design. Sub-phase execution: **1e-α ✅** (commit `876f3bf3`) η split of `merge-hasheq-union` → `merge-hasheq-identity` + `merge-hasheq-replace`; retire old name. Scope-reduced on per-site classification (test shared-fixture pattern revealed legitimate replace semantics; identity-candidate migration deferred to PM Track 12 for submodule-scope coordination). **1e-β-i ✅** (commit `4c5792a9`) meta-solve identity-or-error at [elaborator-network.rkt:966, 982](../../racket/prologos/elaborator-network.rkt) with new `'meta-solve` SRE domain + `merge-meta-solve-identity` + `'meta-solve-contradiction` sentinel. Production use; double-solve-with-inconsistency bug class now caught structurally. **1e-β-ii ✅** (commit `0b930d7e`) atms.rkt classification: hoisted `table-registry-merge` (registered under `'hasheq-replace`) + `table-answer-merge` (registered under new `'dedup-list-append`); new general `merge-list-dedup-append` in infra-cell.rkt; atms.rkt:761 documented as path-(3) tagged-scoped identity. **1e-β-iii-a ✅** (commit `4205b0ad`) [`clock.rkt`](../../racket/prologos/clock.rkt) E1 Lamport primitive built, tested (17/17), SRE-registered; `current-process-id` + `current-clock-cell-id` scaffolding parameters in DEFERRED.md. **1e-β-iii-b deferred to PM Track 12**: investigation revealed 5 consumer sites are snapshot-cells of Racket parameters; migration becomes load-bearing only after PM 12 retires the parameters (same architectural act as 1e-α's identity-candidate migration). See [PM series master § Track 12](../tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) for PM 12's 32 identity + 5 timestamp migration targets unified under submodule-scope. |
| 1f | Structural enforcement at `net-add-propagator` + hard-error flip | ✅ | **1f ✅** (commit `25b421fe`) sre-domain gets `#:classification` field ('structural | 'value | 'unclassified); sre-core.rkt's `lookup-domain-classification` exported; propagator.rkt adds `current-domain-classification-lookup` parameter + `enforce-component-paths!`; infra-cell-sre-registrations.rkt wires the callback. Hard-error fires on classified-structural cell read without `:component-paths`. Initial classifications: `'hasse-registry` structural; `'meta-solve`, `'timestamped-cell` value. All other existing domains remain `'unclassified` (progressive rollout). Dedicated test file `test-component-paths-enforcement.rkt` 10/10 GREEN. Full classification of remaining ~25 SRE domains is per-session progressive work. |
| 1V | Vision Alignment Gate for Phase 1 | ✅ | **1V ✅** (2026-04-20) all 4 VAG questions passed: (a) on-network — all registration infrastructure on-network; off-network scaffolding labeled in DEFERRED.md with PM Track 12 retirement plans. (b) complete — Tier 1/2/3 architecture delivered; 82 registered sites; 5 new SRE domains; hard-error enforcement live; 32 identity-migration + 5 timestamp-migration candidates captured for PM Track 12. (c) vision-advancing — discipline→structure transition for :component-paths rule complete. (d) drift-risks-cleared — all 8 named risks from Phase 1 mini-design audit cleared; scope-reductions (1e-α, 1e-β-iii-b) architecturally correct and captured for PM 12 coordination. **Phase 1 COMPLETE**. Aggregate: ~25 commits, 20+ new SRE domains, 5 new infra modules, lint baseline 27→4 (85% shrink), 6022 affected-tests GREEN, 124+ dedicated tests. Ready for Phase 3. |
| T | Dedicated test files | ⬜ | Enumerated (C4 external critique 2026-04-18): `test-elaboration-parity.rkt` (parity skeleton from §9 expanded per axis), `test-attribute-tag-layers.rkt` (A5 `:type`/`:term` Phase 3), `test-hasse-registry.rkt` (Phase 2b primitive + both instantiations), `test-parametric-resolution-propagator.rkt` (A1/Phase 7), `test-union-atms.rkt` (Phase 10 + cell-based TMS), `test-cell-ref-expressions.rkt` (Phase 12 Option C), `test-tropical-fuel.rkt` (M2 tropical-fuel cell, if adopted), `test-coverage-structural.rkt` (P3 structural coverage, if adopted), `test-warnings-retirement.rkt` (Phase 5 parameter retirement). |
| V | Acceptance + A/B benchmarks + capstone demo + PIR | ⬜ | L3 acceptance green; A/B shows no regression; PIR |

### Phase dependency graph

```
Phase 0 ✅
  ↓
Phase 1a ✅ → Phase 1b ✅ → Phase 1c ✅ (Tier 2 + Tier 3 infrastructure)
  ↓
Phase 1.5 ✅ (srcloc infrastructure) — prerequisite for Phase 2's `:warnings` correct-first-time registration; forward-enables Phase 5, Phase 11b, LSP, etc.
  ↓
Phase 2 ✅ (A9 facet registration) — property inference catches bugs early; D2 framework (aspirational/declared/inference/delta)
  ↓
Phase 2b ✅ (Hasse-registry primitive) — foundation for Phase 7 + Phase 9b
  ↓
Phase 1d → 1e → 1f → 1V (complete Phase 1)
  1d: registration campaign — register remaining ~22 merge fns as-they-are (δ approach per D1); honest D2 deltas per fn
  1e: correctness refactors — η split of merge-hasheq-union into identity + replace variants (23-site audit);
      replace-cell audit (merge-last-write-wins + merge-replace sites) with per-site refactor path:
      (1) timestamp-ordered lattice (principled commutative+assoc+idem upgrade),
      (2) identity-or-error cell (flat lattice with contradiction on conflict),
      (3) accept as non-lattice with explicit rationale.
      May surface timestamped-cell infrastructure need → mini-design at sub-phase.
  1f: structural enforcement at net-add-propagator + hard-error flip
  1V: Vision Alignment Gate for Phase 1
  ↓
Phase 3 (A5 :type/:term split)
  ↓
Phase 4 (A2 CHAMP retirement) — depends on :term facet
  ↓
Phase 5 (A6 warnings) — small independent piece
  ↓
Phase 6 (A3 aspect coverage) — independent; can parallel with 5
  ↓
Phase 7 (A1 parametric resolution) — uses Phase 2b Hasse-registry
  ↓
Phase 8 (A4 Option A freeze) — depends on CHAMP retirement
  ↓
Phase 9 (BSP-LE 1.5 TMS) — sub-track
  ↓
Phase 9b (γ hole-fill propagator) — uses Phase 2b + Phase 3 + Phase 4 + Phase 9
  ↓
Phase 10 (Phase 8 union types) — can parallel with 9b
  ↓
Phase 11 (A7 BSP orchestration) — can parallel with 10
  ↓
Phase 11b (diagnostic infrastructure) — sequenced AFTER Phase 11 (not parallel, not sub-phase). Dependency: diagnostic consumes unified BSP-stratum orchestration delivered by 11. Also consumes :trace + ATMS + source registry. Residuation-backward error reporting. (C3 external critique 2026-04-18: dependency-based sequencing; "b" naming retained.)
  ↓
Phase 12a → 12b → 12c → 12d (A4 Option C cell-refs; see §6.6) — sub-split per R2 external-critique refinement 2026-04-18: pipeline already collapsed by PPN 2/3/4A/4B, real scope is ~19 files / 104 `expr-meta` sites + `zonk.rkt` deletion, sub-split respects conversational cadence rule rather than a stale 14-file cascade
  ↓
Phase T (dedicated tests) — partly per-phase via parity skeleton, consolidated here
  ↓
Phase V (acceptance + A/B + demo + PIR)
```

---

## §3 Design Mantra Audit (Stage 0 gate — M1)

From audit §3. Each violation has a named resolution axis.

| # | Violation | Mantra word failed | Location | Axis |
|---|---|---|---|---|
| V1 | `resolve-trait-constraints!` imperative | *on-network* | [typing-propagators.rkt:1966](../../racket/prologos/typing-propagators.rkt) | A1 |
| V2 | CHAMP duplicate store for meta solutions | *information flow* | [metavar-store.rkt:1769](../../racket/prologos/metavar-store.rkt), 79 `solve-meta!` sites | A2 |
| V3 | `infer/err` fallback for uncovered AST kinds | *structurally emergent* | 49 sites | A3 |
| V4 | `freeze`/`zonk` tree walk reading CHAMP | *information flow*, *on-network* | [zonk.rkt (513 sites)](../../racket/prologos/zonk.rkt) | A4 |
| V5 | `:kind`/`:type` conflated in one facet | *structurally emergent* | Option C skip | A5 |
| V6 | `current-coercion-warnings` parameter + cell | *on-network* (belt-and-suspenders W1) | [warnings.rkt:122, 62, 129](../../racket/prologos/warnings.rkt) | A6 |
| V7 | `run-stratified-resolution-pure` parallel to BSP | *structurally emergent* | [metavar-store.rkt:1915](../../racket/prologos/metavar-store.rkt) | A7 |
| V8 | `:component-paths` discipline-maintained | *structurally emergent* | [propagator-design.md](../../.claude/rules/propagator-design.md) | A8 |
| V9 | 4/5 facet lattices unregistered as SRE domains | *structurally emergent* | Only `type-sre-domain` registered | A9 |

Each violation has a named axis in §4–§6; retirement is structural, not by discipline.

---

## §4 NTT Speculative Model — Post-4C State

The NTT model is the architectural north star. Prose follows from it.

### §4.1 Core facet lattices

```
;; :type — the classifier facet. Quantale from Track 2H.
;; Value lattice (pure join) but Quantale-rich (tensor for application).
trait Lattice TypeFacet
  :where [Monoid TypeFacet type-join type-bot]
         [Idempotent type-join]
         [Commutative type-join]
  spec type-join TypeFacet TypeFacet -> TypeFacet
  spec type-bot  -> TypeFacet

trait BoundedLattice TypeFacet
  :extends [Lattice TypeFacet]
  spec type-top -> TypeFacet

trait Quantale TypeFacet
  :extends [Lattice TypeFacet]
  spec type-tensor TypeFacet TypeFacet -> TypeFacet
  :where [Associative type-tensor]
         [Distributes type-tensor type-join]

impl Quantale TypeFacet
  ;; Implementation from type-lattice.rkt / unify.rkt
  join type-lattice-merge   ;; Track 2H union-join ⊕
  bot  type-bot
  top  type-top
  tensor type-tensor        ;; Track 2H function application ⊗

;; D.2 restructure: `:type` and `:term` are NOT separate facets/lattices.
;; They are tag-layers on the shared TypeFacet carrier (Module Theory
;; Realization B — direct sum via tagging on shared carrier; BSP-LE 2B
;; Resolution B pattern applied here). The MLTT foundation grounds this:
;; there is one universe hierarchy, and "type" and "term" are terms at
;; adjacent universe levels. The bitmask tag distinguishes:
;;
;;   tag CLASSIFIER : this layer is the classifying type of the position
;;   tag INHABITANT : this layer is the value inhabiting the classifier
;;
;; The merge function dispatches on tag:
;;   (CLASSIFIER × CLASSIFIER) → type-lattice-merge (unification)
;;   (INHABITANT × INHABITANT) → α-equivalence strict merge; top on mismatch
;;   (CLASSIFIER × INHABITANT) → residuation check: inhabitant ⊑ classifier
;;                                violation → contradiction → type-top
;;
;; Residuation laws are internal to the quantale and verified by SRE
;; property inference (§6.9).

;; `:preserves [Residual]` extends the quantale declaration with the
;; structural commitment that the carrier supports residuation
;; (both left \ and right /). This is a candidate NTT refinement
;; (§6.11 Observations).
impl Quantale TypeFacet
  ;; ... (previous declarations)
  :preserves [Residual]
  left-residual  type-left-residual   ;; A \ B — "what X satisfies X ⊗ A ⊑ B"
  right-residual type-right-residual  ;; B / A — "what X satisfies A ⊗ X ⊑ B"

;; :context — binding stack with distinguishable bot
;; (Track 4B fix: #f facet-bot distinct from valid empty context)
type ContextFacet := context-bot              ;; #f — no context yet
                   | context-val ContextList  ;; actual binding list (may be empty)

impl Lattice ContextFacet
  join
    | context-bot x                       -> x
    | x context-bot                       -> x
    | [context-val a] [context-val b]     -> if (context-equal? a b) [context-val a] context-top
    ...
  bot -> context-bot

;; :usage — QTT multiplicity semiring
;; Structural lattice — mult-vector is a map from De Bruijn index to MultExpr
data UsageFacet := usage-vector mult-map
  :lattice :structural     ;; per-key merge via Quantale MultExpr
  :bot (usage-vector {})

;; :constraints — Heyting powerset
;; (Reuses existing constraint-cell.rkt lattice)
type ConstraintFacet := constraint-bot | constraint-domain (Set Constraint) | constraint-top

impl Lattice ConstraintFacet
  join                                      ;; set intersection — narrowing
    | constraint-bot _                   -> constraint-bot   ;; bot is empty candidate set
    | _ constraint-bot                   -> constraint-bot
    | constraint-top _                   -> constraint-top
    ;; Existing constraint-cell merge function from constraint-cell.rkt
    ...

trait HeytingLattice ConstraintFacet
  :extends [BoundedLattice ConstraintFacet]
  spec implies ConstraintFacet ConstraintFacet -> ConstraintFacet

;; :warnings — monotone set union
type WarningFacet := warning-set (Set Warning)

impl Lattice WarningFacet
  join set-union
  bot  (warning-set (empty-set))
```

### §4.2 Attribute record as product lattice

Under D.2 restructure, the AttributeRecord is a product of **5 facets** (not 6):
`:classify-and-inhabit` replaces separate `:type` + `:term`. The tag scheme
within that facet preserves the user-visible `:type`/`:term` surface.

```
;; Product of 5 facet lattices per AST-node position
data AttributeRecord := record
  :fields   {:classify-and-inhabit TypeFacet,  ;; tagged: CLASSIFIER | INHABITANT
             :context ContextFacet, :usage UsageFacet,
             :constraints ConstraintFacet, :warnings WarningFacet}
  :lattice :structural     ;; component-wise per facet
  :bot     {:classify-and-inhabit (tagged-empty TypeFacet),
            :context context-bot, :usage (usage-vector {}),
            :constraints constraint-bot, :warnings (warning-set (empty-set))}
  :top     any-facet-at-top    ;; contradiction: if any facet hits top, record is top

;; Attribute map: position → AttributeRecord
;; Structural lattice with per-position, per-facet merge.
;; Compound component-paths allow targeted propagator firing.
data AttributeMap := map-pos-to-record (HashMap Position AttributeRecord)
  :lattice :structural
  :bot     (map-pos-to-record (empty-hash))
  ;; Merge: per-position component-wise per facet
```

### §4.3 Cross-facet bridges (Galois connections)

Under D.2, cross-facet bridges are Galois connections between distinct facets. The `TermInhabitsType` bridge from D.1 **dissolves** — it was a hint that `:type` and `:term` shared algebraic structure, and under Realization B that structure is the quantale residuation *internal to the shared carrier*, not a bridge between two lattices.

Remaining cross-facet bridges (each a verified Galois connection):

```
;; Type↔Constraints: when classifier is known, trait obligations can be generated
bridge TypeToConstraints
  :from TypeFacet  (CLASSIFIER layer)
  :to   ConstraintFacet
  :alpha infer-trait-obligations      ;; classifier → required constraints
  :gamma resolved-dict-to-type        ;; resolved dict → witness type

;; Context provides types for bvar lookups
bridge ContextToType
  :from ContextFacet
  :to   TypeFacet
  :alpha context-lookup-bvar          ;; ctx + index → type of binding
  :gamma type-to-context-demand       ;; expected type → implicit binder insertion demand

;; Usage reflects multiplicity; Pi mult extracted from type
bridge UsageToType
  :from UsageFacet
  :to   TypeFacet
  :alpha mult-to-pi-mult              ;; PM Track 8: usage → Pi multiplicity
  :gamma type-to-mult-demand          ;; (partial) Pi → expected mult

;; Coercion + deprecation warnings flow from TypeFacet's classifier/inhabitant
;; tag layers. One-way — warnings don't narrow type information.
;; Composed α covers both warning kinds; future refinement can split if needed.
bridge TypeToWarnings
  :from TypeFacet
  :to   WarningFacet
  :alpha detect-type-warnings
         ;; Covers: (a) cross-family coercion — type-tensor composition detects
         ;; mixed-family numeric ops (Int ⊗ Posit32) and emits a coercion warning;
         ;; (b) deprecated-spec access — TypeFacet entries carrying :deprecated
         ;; metadata (from resolved specs) emit a deprecation warning.
  ;; :gamma omitted — one-way. Warnings don't un-warn or narrow type info.
```

**Egress is not a bridge** (NTT convention per [§5 `interface`](2026-03-22_NTT_SYNTAX_DESIGN.md)): the driver reads `:warnings` via `(that-read attribute-map pos :warnings)`, formats as strings, outputs for display. That's network-output serialization, not a lattice-to-lattice morphism. No downstream bridge needed from WarningFacet to an external domain.

**Multi-source warning detectors are propagators, not bridges.** When a warning requires reading multiple facets (e.g., multiplicity violation needs both `:usage` and `:type`), the detector is a regular propagator — see §4.4.

### §4.4 Propagator declarations (examples; full list per AST kind)

Every propagator is typed, with `:reads` / `:writes` / `:component-paths` derived or declared. Propagators are pure `net → net` fire functions.

```
;; Example: λ-abstraction typing rule
propagator typing-lam
  :reads  [Cell AttributeMap
             :component-paths [(domain-pos :type)
                               (body-pos   :type)
                               (body-pos   :context)]]
  :writes [Cell AttributeMap
             :component-paths [(pos :type)
                               (pos :context)]]  ;; writes Pi type up; context down to body
  fire-lam    ;; :type = Pi(m, dom, body.type); body.context = extend(ctx, dom)

;; Example: application typing rule (bidirectional)
propagator typing-app
  :reads  [Cell AttributeMap
             :component-paths [(func-pos :type)
                               (arg-pos  :type)
                               (pos      :context)]]
  :writes [Cell AttributeMap
             :component-paths [(pos      :type)        ;; synthesize: subst(cod, arg)
                               (arg-pos  :type)]]      ;; check: write dom down
  fire-app    ;; bidirectional; merge at arg position IS unification

;; Example: parametric trait resolution (NEW in 4C — retires Bridge 1)
propagator parametric-trait-resolution
  :reads  [Cell AttributeMap
             :component-paths [(meta-pos :type)
                               (meta-pos :constraints)]]
  :writes [Cell AttributeMap
             :component-paths [(meta-pos :term)          ;; writes dict term on resolution
                               (meta-pos :constraints)]] ;; narrows candidate set
  fire-parametric-resolve
  ;; Fires on S1 fiber when type-args ground. Pattern-matches against parametric impl
  ;; registry (registered as data, not code). Writes narrowed constraint set or
  ;; solved dict term. Monotone: constraint set shrinks; dict term moves from bot.

;; Example: S2 meta-defaulting (non-monotone barrier stratum)
propagator meta-default
  :non-monotone    ;; S2; writes defaults if :term still bot post-quiescence
  :reads  [Cell AttributeMap
             :component-paths [(meta-pos :type)
                               (meta-pos :term)]]
  :writes [Cell AttributeMap
             :component-paths [(meta-pos :term)]]
  fire-meta-default    ;; writes default (lzero, mw, sess-end) if :term = term-bot

;; Multi-source warning detection — propagators, not bridges (§4.3).
;; Read multiple facets; write :warnings. Propagator formalism applies
;; (lattice-pair bridges don't fit multi-source).
propagator multiplicity-violation-detector
  :reads  [Cell AttributeMap
             :component-paths [(pos :usage), (pos :type)]]
  :writes [Cell AttributeMap
             :component-paths [(pos :warnings)]]
  fire-multiplicity-check   ;; QTT violation → warning (vs hard error via :type=top)

propagator capability-requirement-detector
  :reads  [Cell AttributeMap
             :component-paths [(pos :context), (pos :type)]]
  :writes [Cell AttributeMap
             :component-paths [(pos :warnings)]]
  fire-capability-check     ;; needed-capability-not-in-scope → warning
```

### §4.5 Stratification `ElabLoop`

```
stratification ElabLoop
  :strata   [S-neg1 S0 S1 S2]
  :scheduler :bsp
  :fixpoint  :stratified   ;; Iterated lfp across strata
  :fiber S-neg1
    :mode retraction
    :networks [retraction-net]
    ;; S(-1): reads retracted-assumption-set; narrows scoped cells.
    ;; Registered via register-stratum-handler! :tier 'value (A7).
  :fiber S0
    :mode monotone
    :networks [attribute-net]
    :bridges  [TypeToConstraints TermInhabitsType ContextToType UsageToType]
    :speculation :atms            ;; Phase 8: union types
    :branch-on  [union-types]
    :trace     :structural         ;; cascade default
  :fiber S1
    :mode monotone
    :networks [trait-resolution-net parametric-narrowing-net]
    ;; S1: readiness-triggered. Fires when type-args ground. Produces
    ;; dict terms + narrowed constraint sets. Registered via
    ;; register-stratum-handler! :tier 'value (A7).
  :barrier S2 -> S-neg1
    :mode commit
    :commit default-and-validate-and-retract
    ;; S2: meta-defaulting + usage validation + warning collection.
    ;; On contradiction: retract ATMS assumption → fibered back to S-neg1 via exchange.
  :fuel 100
  :where [WellFounded ElabLoop]

;; Exchange for union-type ATMS (Phase 8)
exchange S0 <-> S-neg1
  :kind :suspension-loop
  :left  fork-on-union       ;; S0: speculative branch per union component
  :right retract-contradicted  ;; S-neg1: retract branch on contradiction
```

### §4.6 NTT Observations (gaps found, impurities caught)

Per M1+NTT methodology, every NTT model ends with an Observations section.

1. **Everything on-network?** Yes, except one staging scaffold: Option A freeze tree walk (§6.6). Labeled as scaffold retired by Option C in a later phase of 4C itself. No other off-network state.

2. **Architectural impurities revealed by the NTT model?**
   - `TermInhabitsType` bridge surfaces the residuation structure (§4.3 + §6.2). This was implicit in Track 2H's quantale; making it a bridge forces naming. Also surfaces Residual as a `:preserves` keyword candidate — NTT refinement candidate (deferred to NTT design work).
   - Meta-default and usage-validator as `:non-monotone` propagators require barrier stratum assignment. This catches any attempt to run them on S0 or S1 at type-check time.
   - `parametric-trait-resolution` in S1 requires readiness-trigger. The NTT model makes this explicit; without it, mid-implementation I might have installed it on S0 and had it fire on bot inputs, producing thrashing.

3. **NTT syntax gaps?**
   - **A8 (`:component-paths` as derivable obligation)** — persisted in [`propagator-design.md`](../../.claude/rules/propagator-design.md). In this design, enforced at registration time; NTT-type-error formalization deferred.
   - **Residuation as `:preserves` keyword** — mentioned above. Deferred.
   - **`:fixpoint :stratified` semantics** — NTT defines `:stratified` as "iterated lfp across strata." 4C's ElabLoop is a concrete instance; semantics align.

4. **Components the NTT cannot express?**
   - None identified at D.1 level. P/R/M critique round may surface more.

---

## §5 Correspondence Table: NTT → Racket (post-4C)

| NTT construct | Racket implementation | File |
|---|---|---|
| `AttributeMap` cell | `current-attribute-map-cell-id` on persistent registry network | [typing-propagators.rkt:74-75](../../racket/prologos/typing-propagators.rkt) |
| `AttributeRecord` | Nested hasheq `position → facet → value` | typing-propagators.rkt |
| Facet `:type` | `that-read/write attribute-map pos :type` | typing-propagators.rkt:364, 372 |
| Facet `:term` (NEW) | `that-read/write attribute-map pos :term` | typing-propagators.rkt (new) |
| Facet `:context` | `that-read/write ... :context` | typing-propagators.rkt |
| Facet `:usage` | `that-read/write ... :usage` | typing-propagators.rkt |
| Facet `:constraints` | `that-read/write ... :constraints` | typing-propagators.rkt |
| Facet `:warnings` | `that-read/write ... :warnings` | typing-propagators.rkt |
| `TypeFacet` lattice | `type-lattice-merge` | type-lattice.rkt / unify.rkt |
| `TermFacet` lattice | new — see §6.1 | typing-propagators.rkt (new) |
| `ConstraintFacet` lattice | constraint-cell.rkt Heyting | constraint-cell.rkt |
| `WarningFacet` lattice | monotone set union | warnings.rkt |
| `bridge TypeToConstraints` | constraint-creation propagator + dict feedback | typing-propagators.rkt, trait-resolution.rkt |
| `bridge TermInhabitsType` | new merge-bridge; §6.2 | typing-propagators.rkt (new) |
| `propagator typing-*` | Fire functions registered via `register-typing-rule!` | typing-propagators.rkt |
| `propagator parametric-trait-resolution` | new S1 propagator; §6.5 | typing-propagators.rkt (new) |
| `stratification ElabLoop` | BSP scheduler + registered stratum handlers | propagator.rkt, typing-propagators.rkt (reorg) |
| Stratum handler S(-1) | `register-stratum-handler! :tier 'value retraction-request-cid` | metavar-store.rkt → propagator.rkt |
| Stratum handler S1 | `register-stratum-handler! :tier 'value ready-queue-cid` | metavar-store.rkt → propagator.rkt |
| Stratum handler S2 | `register-stratum-handler! :tier 'value s2-commit-cid` | metavar-store.rkt → propagator.rkt |
| Worldview cell (Phase 8) | new — cell-based TMS sub-track | propagator.rkt (refactor) |
| `exchange S0 <-> S-neg1` | ATMS fork-on-union + retraction | typing-propagators.rkt (new), metavar-store.rkt |

---

## §6 Architecture Details

### §6.1 `:type` / `:term` as tag-layers on the shared TypeFacet carrier (A5, Phase 3, D.2 restructure)

**Problem** (from 4B): conflating classifier and inhabitant in `:type` facet. A type-variable meta's classifier (`Type(0)`) and its solution (`Nat`) merge to `type-top` (contradiction), forcing Option C skip (D.1).

**D.1 fix** (superseded): two separate facets `TypeFacet` + `TermFacet` with a `TermInhabitsType` bridge.

**D.2 fix (Module Theory Realization B)**: one carrier, two tag-layers.

The MLTT foundation grounds this. There is one universe hierarchy; `Nat`, `Type(0)`, `Type(1)`, etc. are all terms at adjacent levels. "Type" and "term" are a *layer* distinction, not a *lattice* distinction. Attempting to separate them into two lattices in D.1 duplicates the carrier: both `TermFacet`'s `term-val Expr` and `TypeFacet`'s classifier-values hold `Expr`. The duplication is the scent.

Realization B: one facet `:classify-and-inhabit` on the shared TypeFacet carrier. Every entry carries a bitmask tag:

- **CLASSIFIER tag** — this layer holds the classifying type of the position (what it *must have*).
- **INHABITANT tag** — this layer holds the specific inhabitant (what *solves* this position).

Merge is tag-dispatched, composing existing unify.rkt relations (§6.13 PUnify audit):
- **CLASSIFIER × CLASSIFIER → `unify-core` with `'equality` relation** (dispatch through [type-merge-table](../../racket/prologos/unify.rkt) `'equality` → `type-lattice-merge`). Standard unification.
- **INHABITANT × INHABITANT → α-equivalence strict merge**; mismatch → type-top.
- **CLASSIFIER × INHABITANT → `unify-core` with `'subtype` relation**. The check `type-of(INHABITANT) ⊑ CLASSIFIER` dispatches through `type-merge-table` `'subtype` → [`subtype-lattice-merge`](../../racket/prologos/subtype-predicate.rkt). This IS the "PUnify with variance" — variance is already first-class via the relation name. PUnify success → compatible; failure → type-top (contradiction).

The residuation structure lives *inside* the quantale, not as a bridge. This is §6.2's subject.

**User-visible surface is preserved**: `that-read pos :type` reads the CLASSIFIER-tagged entries; `that-read pos :term` reads the INHABITANT-tagged entries. The tag distinction is implementation — `:type` and `:term` remain distinct surface names with distinct semantics. Error messages say "expected type T, got term e : Int" just as before; the tag-dispatched merge knows which side is which.

**Consequence**: Option C skip dissolves (as in D.1) but via a different mechanism. The APP downward write tags the arg-position entry as CLASSIFIER with value `dom`. The feedback from unification tags with CLASSIFIER (both merge cleanly via type-lattice-merge). If a meta is later solved to a specific term (e.g., `(expr-Nat)`), that entry is tagged INHABITANT — the cross-tag merge enforces `type-of(expr-Nat) ⊑ Type(0)` which holds (`Nat : Type(0)`). No contradiction.

**What changed vs D.1**: `:term` as its own lattice/facet is retired. `TermInhabitsType` bridge is retired (§4.3). SRE lens table (§6.11.1) updated accordingly (§6.11.1).

**Mitigations for the "cons" of Realization B** (addressing user's 1A concern):

1. **Surface clarity**: user-facing `:type`/`:term` names unchanged; tag distinction is internal. Type-error diagnostics can still say "expected T, got e : S" because the tag-dispatched merge knows which entry is which layer.
2. **Lattice-law verification**: SRE property inference on the tag-dispatched merge verifies commutativity (merge is tag-order-independent), associativity across tag combinations, idempotence per tag, and the residuation laws (`A ⊗ (A \ B) ⊑ B`, `(B / A) ⊗ A ⊑ B`, distribution). Track 3 §12 + SRE 2G precedent says inference catches bugs tests miss — actively invited here, not a risk.
3. **Provenance as first-class — structurally emergent** (O3 resolution 2026-04-18): each tagged entry's derivation chain (source-loc + producer propagator + ATMS assumption) is NOT a new data structure bolted onto entries. It's the propagator-firing dependency graph read as a derivation — structurally emergent from the network topology per [Module Theory §5-6](../research/2026-03-28_MODULE_THEORY_LATTICES.md) (propagator networks are quantale modules; derivation chains are ring-action sequences; backward residuation over chains produces error diagnostics principled, not ad-hoc) and [Hypergraph Rewriting §6.3](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) ("dependency graph IS a proof object — the network naturally maintains provenance; implementation exposes existing structure"). See §6.1.1 below for full specification.

#### §6.1.1 Provenance infrastructure (O3 resolution)

**Intended use case** (per user direction 2026-04-18): first-class compiler and error features, not a debugging aid. Specifically:
- Precise source-code mapping from error sites back to their structural origins.
- Human-readable error/warning messages with derivation context ("this type error arose because propagator X at source-loc L wrote type T, while propagator Y at source-loc L' wrote conflicting type T'").
- Machine-readable traces for IDE/LSP tooling (jump-to-definition, hover-inspect, error-origin navigation).
- Residuation-backward as the error-explanation mechanism (Module-Theory-principled).

**Structural sources** (three — all existing or near-existing infrastructure; no new data structures required):

1. **ATMS assumption tagging** (Phase 9 cell-based TMS via BSP-LE 1.5): each `tagged-cell-value` entry carries its `assumption-id`. For a `:type` CLASSIFIER-tagged entry written under branch `A`, the entry records `assumption-id = branch-A-aid`. Retraction at S(-1) narrows by assumption. Already the mechanism for worldview-managed speculation.
2. **Propagator-firing trace** via `:trace :structural` mode ([NTT Syntax §7.6](2026-03-22_NTT_SYNTAX_DESIGN.md)): each cell write records `(propagator-id, assumption-id)` pair. `:trace :structural` is the minimum mode for provenance; `:trace :full` adds values + timestamps for heavy debugging. Cascade-scoped via the stratification declaration — default `:structural` at ElabLoop level for 4C.
3. **Source-location registry** (Phase 4 R5): `current-meta-source-registry` holds `meta-id → source-info` for meta-creation sites. Non-meta positions carry source-loc inline through the elaboration pipeline (existing in 4B). Source-loc attachment is part of the AST itself.

**Error-reporting via backward residuation** (in 4C scope per user direction):

When `:type` merges to `type-top` (contradiction detected during cross-tag merge), the error-reporting mechanism residuates backward through the derivation chain:

1. Read the `:type` cell's tagged entries at the contradicting position.
2. For each conflicting tag entry, retrieve its `(propagator-id, assumption-id, source-loc)` via the three sources above.
3. Follow each contributing propagator's `:reads` cells to their derivation chain recursively — residuation over the Module-Theoretic chain structure.
4. Produce both human-readable message (with source-loc highlighting and propagator rationale) and machine-readable structured chain (for tooling).

No separate "error-tracker" mechanism. The error origin IS a residuation computation on the existing network. Module Theory principle: "backward chaining IS residuation" ([Module Theory §5](../research/2026-03-28_MODULE_THEORY_LATTICES.md) point 3).

**Helper API shape**: `derivation-chain-for(position, tag)` or similar — exposes the structural sources through a convenient interface. **Exact API deferred to phase-time mini-design** (per user direction O3.3) — signature considerations (lazy vs eager chain collection, human-readable vs machine-readable formats, LSP integration hooks) are better settled with implementation context than in D.2.

**Architectural shape — read-time derivation (M4 external-critique lean, 2026-04-18)**: the `derivation-chain-for` helper is a **read-time** function, not a propagator that fires on contradiction. Provenance is already present in the dependency graph (from sources 1-3 above); the explanation is a walk over that graph when a consumer queries it. No error-propagator installation. Rationale: (i) most contradictions during elaboration are *transient* (speculation branches that get retracted, ATMS assumption eliminations) — firing an error propagator on every transient contradiction generates noise requiring filtering; (ii) the proof-object IS the data per §3.10 closure — copying it into an error-output cell via a propagator is information movement without semantic gain; (iii) Data Orientation + Most General Interface favor a single read-time function over a propagator-plus-output-cell wiring that every consumer must subscribe to.

**Research input to the Phase 11b mini-design — trace monoidal categories**: the backward-residuation framing in point 3 above gains formal grounding through traced symmetric monoidal category theory. Propagator networks form a traced SMC: cells compose monoidally (tensor), propagators are morphisms, feedback through shared cells is the trace operator. Under this framing, provenance is the *trace morphism* of the contradiction path, and backward residuation is the adjoint structure of the trace. Classical references to consult before Phase 11b mini-design: Joyal-Street-Verity 1996 ("Traced Monoidal Categories") for the axiomatization (vanishing, yanking, superposing, naturality); Hasegawa 1997 ("Recursion from Cyclic Sharing") for the trace ↔ recursion/fixpoint correspondence in Cartesian-closed settings — directly relevant because propagator fixpoints *are* cyclic sharing; Abramsky-Haghverdi-Scott 2002 (Geometry of Interaction and linear combinatory algebras) for traces as information flow through cycles — provenance chains structurally. This is research *for* the Phase 11b mini-design, not prerequisite research blocking D.3 — we enter Phase 11b with the theoretical framing to guide the helper's algebra (how cycles compose, what the backward walk's invariants are, how chain composition works horizontally and vertically). **Phase 11b mini-design checkpoint**: consume this research before finalizing `derivation-chain-for` signatures.

**Diagnostic infrastructure as a dedicated phase**: see Progress Tracker Phase 11b (NEW).

**Naming precedent**: Coq's `evar_map` has `concl` (goal type) and `body` (optional solution) as separate fields — but Coq stores them in one meta-info record per meta, not two independent stores. Agda/Idris/Lean follow similar patterns. Realization B matches how elaboration with metavariables is done in the reference systems, rendered in propagator-network terms.

### §6.2 Residuation — internal to the TypeFacet quantale (A5, Phase 3, S3, D.2)

D.2 change: residuation is *internal* to the TypeFacet quantale (not a bridge between two facets). Bidirectional type-checking emerges from the quantale's own left/right residual operations applied at tag-dispatched merge.

The type lattice is a quantale ([Track 2H](2026-04-02_SRE_TRACK2H_DESIGN.md)): ⊕ = union-join, ⊗ = type-tensor (function application distributing over unions). Quantales have left/right residuals: `A \ B` (left) and `A / B` (right), satisfying `A ⊗ X ⊑ B ⟺ X ⊑ A \ B`.

Bidirectional type checking falls out of residuation:

- `check T e` = demand `e inhabits T`. Tag-dispatched merge of CLASSIFIER(T) × INHABITANT(e) computes the left residual `T \ type-of(e)` — if the result is bot, `e : T` holds; if top, contradiction.
- `infer e` = synthesize T from e. Tag-dispatched merge writes CLASSIFIER(type-of(e)) when INHABITANT(e) is known and no prior CLASSIFIER exists. Merge with any existing CLASSIFIER T' unifies (type-lattice-merge).

The "α" direction (check) is the merge itself. The "γ" direction (hole-fill) is a separate propagator that reads CLASSIFIER-tagged entries at positions where INHABITANT is bot, and produces candidate INHABITANT entries — see §6.6 and the audit in [§13 Q1](#13-open-questions).

**Structural basis for the tag-dispatched merge** (corner-case check for §13 Q1 sub-question):

```
merge(X-CLASSIFIER, Y-CLASSIFIER) = type-lattice-merge(X, Y)            ;; unification
merge(X-INHABITANT, Y-INHABITANT) = if α-equiv(X, Y) X else type-top    ;; strict equality up to α
merge(X-CLASSIFIER, Y-INHABITANT):
  ;; Cross-tag: the inhabitant Y must satisfy classifier X
  ;; Compute residual: does Y's classifier embed in X?
  let Y-classifier = type-of-expr(Y)
  let residual = type-left-residual(X, Y-classifier)  ;; X \ type-of(Y)
  if residual ⊑ type-bot  -> no constraint (Y is compatible); merge accepts both entries
  else if residual is type-top  -> contradiction; facet → type-top
  else  -> partial constraint recorded (narrowing case)
```

Property inference verifies at A9 facet registration (Phase 2):
- Commutativity of all three merge cases.
- Associativity across tag combinations (this is the non-trivial one; must check `merge(X-C, merge(Y-I, Z-C)) = merge(merge(X-C, Y-I), Z-C)`).
- Idempotence of the per-tag cases.
- Residuation distribution: `X \ (Y ⊓ Z) = (X \ Y) ⊓ (X \ Z)`.

Expected lattice-law corner cases (candidates property inference may flag):
- **Order-of-operations when multiple tag combinations cascade**: if INHABITANT is written before its corresponding CLASSIFIER, the residual computation must be deferred/retriggered when CLASSIFIER arrives. Solution: retrigger propagators watching the facet's cross-tag merge.
- **Residuation with type-top intermediates**: `X \ type-top` should be type-bot (trivially satisfied); `type-top \ X` should be type-top (nothing inhabits contradiction). Edge cases to explicitly verify.
- **Multi-layer nesting**: when the carrier is itself a compound type (e.g., `Pi`), residuation must descend structurally — SRE ctor-desc provides the decomposition; verify it composes with tag-dispatch at every level.

If any property fails, the fix is in the merge function — same iteration cycle as Track 3 §12's spec-cell associativity fix.

**Lazy evaluation of the cross-tag residuation check** (M5 resolution 2026-04-18):

"Lazy" here does not mean "deferred to a separate propagator" (see dismissed Option 4 below). It means the check is skipped when unnecessary and re-fired when required. The check executes *synchronously within the merge function call* — no timing window with unverified cross-tag state.

**Trigger condition**:

```
trigger-check?(current, result) =
  AND
    (has-classifier? result)
    (has-inhabitant? result)
    (OR
      (not (equal? (classifier-layer current) (classifier-layer result)))  ;; CLASSIFIER narrowed
      (not (equal? (inhabitant-layer current) (inhabitant-layer result)))) ;; INHABITANT narrowed
```

The check fires in these cases:
1. **New cross-tag**: CLASSIFIER written to a record that had INHABITANT (or vice versa).
2. **CLASSIFIER narrows**: the record had both tags; narrowing may invalidate previously-compatible INHABITANT. **Re-check required** — this is the subtle case naive "cache and skip" would miss.
3. **INHABITANT narrows**: rare, but re-verify.

The check is skipped when:
4. **Unchanged merge**: both tag layers unchanged (idempotent merge). No new information.
5. **Only one tag present**: no cross-tag situation.

**Correctness guarantees**:

- **BSP compatibility**: merge function fires synchronously at BSP round-merge boundary. `result` is returned already-verified (or replaced with `type-top` on failure). Downstream reads see post-check state; no timing window.
- **CALM monotonicity**: the check's outcome moves only one direction — toward "compatible" or "contradiction" (type-top). Never back from contradiction to compatible. CALM-safe.
- **ATMS compatibility**: under cell-based TMS (Phase 9), worldview-filtered reads mean cross-tag check fires per-branch. Branches don't cross-check each other (CLASSIFIER in branch A invisible to INHABITANT in branch B). S2 commit merge is where branches converge; that merge's check catches cross-branch inconsistency.
- **Property inference**: merge function passes commutativity/associativity/idempotence verification because the check is deterministic and argument-order-independent (subsumption direction is fixed: inhabitant inhabits classifier).

**Why not Option 4 (separate propagator for the check)**: a deferred propagator would create a timing window where cross-tag records exist un-verified. Other propagators reading `:type` in that window would see unchecked data. Adds per-position propagator count with no offsetting benefit. Dismissed.

**Verification plan** (implementation-time, not design-time):

Before Phase 3 commits to the lazy implementation:
1. **Parity test cases** covering all 5 conditions (new cross-tag, classifier narrows, inhabitant narrows, unchanged, single-tag). Scope: Phase 0 parity skeleton.
2. **Property inference run** on the lazy merge function (Phase 2, A9). Any failure is a bug to fix.
3. **A/B micro-benchmark** comparing lazy vs eager (always-check-on-cross-tag). If eager overhead is <5%, eager's simplicity may win; if ≥10%, lazy's trigger refinement is worth the additional logic. Decision locked at Phase 3 based on data.

#### §6.2.1 γ hole-fill propagator — reactive, not iterative (D.2 mantra reframe)

D.1 described γ as "walks type-env + ctor-desc catalogue." That's step-think: *walk*, *iterate*, *search* — all violations of "all-at-once, all in parallel, structurally emergent." D.2 reframes.

**Mantra-compliant γ design**:

The γ propagator is a reactive propagator on the attribute-map that fires when *two conditions* hold simultaneously — both of which are detected by cell readership, not by iteration:

1. A position's CLASSIFIER-tagged layer is ground (no unresolved metas within the type). This is detected by a *readiness threshold* on the CLASSIFIER entry — the same pattern Axis 1 parametric-trait-resolution uses (§6.5).
2. The same position's INHABITANT-tagged layer is still `bot` (no inhabitant known).

When both hold, the propagator fires — **once**, per position, at threshold. It does not walk.

**Pre-indexed inhabitant catalog**:

The fact pool (what could inhabit a given type) is implemented via the **Hasse-registry primitive (§6.12)** — same primitive as the parametric impl registry in §6.5. The catalog has two halves, both registered as `hasse-registry` instances with lattices keyed by classifying type:

- **Type-env index**: bindings in scope (from the `:context` facet) classified by their type. When a binding `x : T` enters scope, it's added to the index at classifier `T`. *This is a monotone cell write*, not a walk — the scope cell's merge function maintains the index.
- **Constructor signature index**: each data constructor's codomain type is registered at declaration time. `zero : Nat` indexes at `Nat`; `suc : Nat -> Nat` indexes at `Nat` with a pending sub-goal for its argument.

Lookup at propagator fire time is **Hasse-structured**, not iterative: the classifier `T` indexes directly into the Hasse graph; the adjacent nodes (most-specific-matching-subsumed by T) are the candidate inhabitants. O(log N) via Hasse height, not O(N) scan.

**Structural decomposition propagates via SRE ctor-desc**:

When the classifier is compound (e.g., `Pi(m, dom, cod)`), γ does not "walk into" the Pi type. Instead, SRE ctor-desc decomposition installs sub-propagators at the structural components:

- A λ-abstraction propagator fires when a `Pi(m, dom, cod)`-classifier cell becomes ground. It creates sub-cells for `dom` and `body`, classifies body with `cod`. The sub-cells are γ-propagator-watched independently. This is SRE's decomposition doing the structural work — all-at-once over sub-components, all in parallel.

**Multi-candidate case fires ATMS fork**:

When the Hasse index returns multiple candidates at the same specificity level, γ writes one candidate per branch via ATMS assumption-tagging (Phase 10 substrate: [cell-based TMS](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) + worldview bitmask). Branch contradiction retracts via S(-1). Single-candidate case writes INHABITANT directly.

**Network Reality Check** (Track 4 §9 methodology):
- `net-add-propagator` calls: 1 γ-propagator per position (fire-once at readiness); 1 SRE ctor-desc propagator per compound-classifier decomposition.
- `net-cell-write` calls: INHABITANT writes to attribute-map; ATMS tag writes on multi-candidate branches.
- Trace: CLASSIFIER cell read + INHABITANT cell read → propagator fires → Hasse-index lookup → INHABITANT write. Everything through cells.

No walks. No scan loops. No iteration. The "search" is the Hasse structural lookup, which is an index read — a cell operation, not a traversal.

**Symmetry with §6.5 parametric-trait-resolution**: γ hole-fill and parametric trait resolution are the *same* architectural pattern — PUnify-against-Hasse-indexed-catalog, differing only in the catalog content. §6.5's catalog is impl patterns; §6.2.1's catalog is inhabitant patterns (type-env bindings + constructor signatures). Both use ctor-desc decomposition, ATMS branching on ambiguity, and set-latch fan-in for downstream aggregation. This compositional unity is load-bearing — it means future tracks (SRE 6, PPN 5) inherit one pattern, not two. See §6.11.6 note on general residual solver unification.

### §6.3 CHAMP retirement (A2, Phase 4)

**Problem**: `meta-info` CHAMP is a duplicate store of the `:type` and `:term` facets, authoritative for downstream consumers.

**Fix**: migrate authority to attribute-map facets.

**Migration phases**:

1. **Introduction** (Phase 2): `:term` facet added. `solve-meta-core!` writes to BOTH CHAMP and attribute-map `:term` during migration window.
2. **Reader migration** (Phase 3): all CHAMP readers migrated to read `:term` facet. Grep-verified (79 `solve-meta!` sites, 513 zonk.rkt sites).
3. **CHAMP retirement** (Phase 3 close): **CHAMP code path + `meta-info` struct's lattice fields (ctx, type, status, solution, constraints) deleted entirely.** Any lingering reference becomes a compile error — hard-fails at build time, not a discipline-maintained contract. This couples A8 enforcement (Phase 1) to A2 retirement: post-retirement, no new code can inadvertently read the retired CHAMP.

**Meta source metadata (R5 resolution 2026-04-18)**: Pre-0 analysis (5 of 7 meta-info fields map to facets; `source` is the one lattice-irrelevant debug field — see [Pre-0 report](2026-04-17_PPN_TRACK4C_PRE0_REPORT.md) §2). Design commitment:

- **`current-meta-source-registry`** — a single Racket parameter holding a `hasheq` of `meta-id → source-info` (source-loc + creation context string). Pure debug metadata; not participating in lattice evaluation or network flow.
- Written once at meta creation (`fresh-meta`); read on-demand for diagnostic output. No propagator dependencies.
- Explicit choice NOT to make it a facet: source-loc doesn't have meaningful lattice structure, and facetizing it would force through property-inference verification for no algebraic gain. Side registry is the lightweight and principled choice.
- Test-harness awareness: the registry parameter must be added to `test-support.rkt` + `batch-worker.rkt` save/restore per [pipeline.md Two-Context Audit](../../.claude/rules/pipeline.md). Phase 4 migration scope includes this addition.

**No belt-and-suspenders**: the migration window Phase 2→3 is a labeled staging scaffold with explicit retirement in Phase 3 close. Not permanent. Post-Phase 3 close, any `meta-info-ref` call outside the side registry fails to compile.

### §6.4 Aspect-coverage completion (A3, Phase 6)

**Problem**: 76 `register-typing-rule!` entries vs ~326 `expr-*` structs. `infer/err` fallback catches the rest imperatively.

**Fix**: enumerate uncovered AST kinds, register one propagator per kind. Dispatch is structural (cell-ID → propagator), not imperative. **Matching/unification within typing rules IS PUnify** — app-typing's arg-domain unification invokes `unify-core` via [`sre-structural-classify`](../../racket/prologos/unify.rkt) (unify.rkt:127) which dispatches through ctor-desc decomposition. No hand-rolled pattern matcher needed; existing SRE ctor-desc infrastructure drives the unification. See §6.13 for the full PUnify mechanism audit.

**Methodology**:

1. Audit (Phase 5 pre-audit): grep all `expr-*?` predicates, cross-reference with `register-typing-rule!` entries. Produce a coverage gap list.
2. Enumerate gaps by category: ATMS ops, union-type forms, session expressions, narrowing expressions, auto-implicits, rare elaboration helpers.
3. Register one fire function per AST kind. Use SRE-derived decomposition where applicable (structural lattice rules handle N AST kinds via one decomposition template).
4. Verify: after registration, the `infer/err` fallback should be reachable only for genuinely unrepresentable cases (e.g., elaboration errors, not missing rules).

**Simplification opportunity — SRE ctor-desc auto-derivation**: many of the 76 existing `register-typing-rule!` entries follow the pattern "given constructor C with N fields typed T₁..Tₙ, result type is f(T₁..Tₙ) for some simple f." SRE ctor-desc ALREADY decomposes constructors structurally (`(struct expr-C ... #:property prop:ctor-desc-tag '(type . C))`). If the typing rule's result-type function is registered alongside the ctor-desc, the propagator can be auto-derived:

```
;; Today: separate ctor-desc + typing rule
(struct expr-Pi (mult domain codomain) #:transparent #:property prop:ctor-desc-tag '(type . Pi))
(register-typing-rule! expr-Pi? 2 (list expr-Pi-domain expr-Pi-codomain)
                       (lambda (dom cod) (expr-Type (lmax (type-of dom) (type-of cod))))
                       'Pi)

;; Possible consolidation:
(register-ctor-desc-with-typing!
  Pi
  :fields '(mult domain codomain)
  :result-type (lambda (_m dom cod) (expr-Type (lmax (type-of dom) (type-of cod)))))
```

Not all typing rules fit (some need bidirectional flow, constraint generation, etc.) — but the core/primitive-type ones largely do. A Phase 6 sub-design should assess how many of the 75 unregistered AST kinds fit the auto-derivation pattern. If high proportion, the simplification compresses Phase 6 significantly. Flagged here for Phase 6 decision.

### §6.5 Parametric trait-resolution propagator (A1, Phase 7) — **rebuilt for efficiency** (D.2)

**Problem**: `resolve-trait-constraints!` is an imperative function called from `infer-on-network/err`. Parametric impl pattern matching is not a propagator. Pre-0 finding E2 shows this path allocates **343 MB / 19× baseline** for a single `[head '[1N 2N 3N]]` call — ~325 MB/123 ms unique to the parametric path, driven by retry loops + candidate-list allocation + CHAMP updates + intermediate-type construction.

**Posture** (per user direction 2026-04-17): *rebuilt for efficiency*, not retrofit. Design for the efficient propagator architecture from the start rather than lifting the imperative algorithm into a propagator wrapper.

**Resolved architecture (D.2)**. Four mechanisms compose on-network, all-at-once, all-in-parallel:

1. **Module-theoretic decomposition of `:constraints` facet by trait tag** ([BSP-LE 2B Resolution B pattern](../../.claude/rules/structural-thinking.md) § Direct Sum Has Two Realizations). The `:constraints` facet at a meta is a direct sum over trait identifiers: `{Seqable, Num, Ord}` on meta A = three bitmask-tagged layers on the shared `:constraints` cell. Each trait is a module over the constraint base. Per-trait merges are algebraically independent — no cross-trait interference.

2. **Per-(meta, trait) propagator**, not per-meta and not per-individual-constraint. Each propagator watches exactly its own tag-layer on the meta's `:constraints` facet via targeted `:component-paths`. Independent firing, no internal iteration. When a meta has N traits, N propagators fire concurrently once the type grounds — true parallelism, not batched processing.

3. **Hasse-indexed impl registry** (§6.11.4) — **implemented via the Hasse-registry primitive (§6.12)**. Each parametric impl is registered once at declaration time, placed in a specificity Hasse diagram over impl patterns. At resolution time, lookup is structural index navigation (O(log N) via Hasse height), not scan. Coherence — no overlapping impls at same specificity — is critical-pair analysis on the impl-pattern DPO structure ([Adhesive §6](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md)); zero critical pairs verified at registration.

4. **PUnify for pattern matching**. "Does candidate impl pattern `P` match target type `T`?" is a **PUnify invocation** on the TypeFacet quantale — specifically `unify-core` ([unify.rkt:463](../../racket/prologos/unify.rkt)) with `'equality` relation for strict pattern match, dispatched through `sre-structural-classify` (unify.rkt:127) for ctor-desc decomposition. Not a hand-rolled pattern matcher. Impl-level type vars (e.g., `E` in `Seqable (List E)`) become fresh CLASSIFIER-tagged metas during the match attempt, resolved via `current-structural-meta-lookup`. PUnify's `decompose-meta-app` + `pattern-check` + `solve-flex-app` (unify.rkt:795-830) handle the flex-app case (Miller's pattern). On success, the substitution σ emerges as meta bindings on the shared carrier; the resolved dict term is constructed via structural cell reads. See §6.13 for the PUnify audit.

**Mechanism**:

```
propagator parametric-trait-resolution[trait]  ;; one per (meta, trait) pair
  :reads  [(meta-pos :type),
           (meta-pos :constraints) @ trait-tag-layer]
  :writes [(meta-pos :term),
           (meta-pos :constraints) @ trait-tag-layer]
  :component-paths [(meta-pos :type), (meta-pos :constraints trait-tag)]
  :fire-once-on-threshold (and ground? (trait-tag-layer-non-empty?))
  fire-parametric-resolve:
    ;; Hasse-index narrows to candidates at target's specificity (O(log N))
    (define candidates (hasse-lookup impl-registry trait type))
    ;; Each candidate is PUnify'd against the target; impl-level metas
    ;; are fresh CLASSIFIER-tagged entries on the shared carrier.
    ;; Multi-candidate at same specificity → ATMS branching (cell-based TMS):
    ;;   each branch runs PUnify under a tagged assumption;
    ;;   contradiction retracts the assumption (S(-1)), surviving branch commits.
    ;; PUnify success writes `impl-level-metas ↦ values` via cell merges.
    ;; Resolved dict = impl body under σ, constructed via structural cell reads.
    (punify-candidates-with-atms candidates type trait-tag-layer))
```

**Set-latch fan-in for dict aggregation** (prior art: Track 4 §3.4b meta-readiness bitmask pattern). When a meta has N traits, the N per-(meta, trait) propagators run concurrently. Each writes its resolved dict-fragment. A per-meta set-latch bitmask tracks completion: each trait-propagator flips its bit on success (monotone bitwise-OR). A single fan-in propagator watches the bitmask; when all bits are set, it fires once and assembles the full dict term for the meta into `:term`. No iteration; aggregation by structural composition of already-resolved components.

**End-to-end on-network trace**: meta's `:type` cell grounds → per-trait propagators fire concurrently → Hasse lookup + PUnify per candidate (with ATMS on ambiguity) → per-trait dict fragments written → bitmask set-latch bits flip → fan-in fires at completion → dict term aggregated into `:term`. Every step is cell reads and cell writes; no scan, no for-fold, no handler-with-iteration.

**Pre-0 expected improvement**: post-phase A/B measurement target is **~60-80% reduction** in E2 allocation (343 MB → ~70-140 MB), with similar wall-clock gains. The module-theoretic decomposition + Hasse-indexed registry + PUnify-via-ctor-desc combination plausibly exceeds this. Measured in V phase.

**SRE + Module Theory + Adhesive alignment**:
- Module Theory: `:constraints` = ⊕_trait TraitLattice (direct sum via tagging); zero-cost per-trait independence.
- SRE ctor-desc: drives PUnify's structural decomposition. No separate pattern-matching code.
- Adhesive DPO: impl coherence = zero critical pairs (verified at registration).
- Hasse diagram: specificity order captured structurally; "tiebreaker" becomes Hasse traversal, not algorithm.

#### §6.5.1 Tag distributivity across trait layers (S2 external critique 2026-04-18)

The carrier merge combines per-trait tagged layers via union. Distributivity across trait tags holds:

```
merge((T1:A) ∪ (T2:B), (T1:C)) = (T1: merge(A, C)) ∪ (T2: B)
```

Per-trait merge composes without cross-trait interference. The structural reason: [`DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org) § "No Trait Hierarchies — Bundles Only" makes per-trait sub-lattices *genuinely independent*. There is no trait that implies or requires another trait, so there are no cross-tag semantic dependencies that would break distributivity. Bundles are set-union syntactic sugar, not algebraic implications.

SRE lens answers:
- Q2 (Algebraic properties): per-trait sub-lattices are independent join-semilattices; the direct-sum via tagging inherits independence.
- Q3 (Bridges to other lattices): no cross-trait bridges exist; cross-trait interaction is *only* via carrier-cell union, not via Galois connections between trait sub-lattices.

Property inference verifies distributivity at A9 facet registration (Phase 2).

### §6.6 Option A and Option C for freeze/zonk (A4, Phase 8 + Phase 12a-d) — **zonk retirement entirely**

**Context — unmet PPN 4 expectation**: the original [Track 4 Design §3.4b "Phase 4b: Zonk Retirement"](2026-04-04_PPN_TRACK4_DESIGN.md) targeted elimination of all three zonk functions (`zonk-intermediate`, `zonk-final`, `zonk-level`, ~1,300 lines) with cell-refs replacing `expr-meta`. Phase 4b-i (readiness infrastructure) landed; Phase 4b-ii-b (zonk deletion) was blocked on the Track 4 Phase 2-3 redo and deferred. Track 4B PIR §12 reconfirmed this as still-deferred. **4C completes this.**

**Option A** (Phase 8): staging scaffold. `freeze`/`zonk` tree walk reads `:term` facet instead of CHAMP. Same walk structure; different data source. Low-risk, mechanical after A2 (CHAMP retirement).

*Scaffold label*: Option A keeps the tree walk. It is NOT the target; it exists only to unblock Axes 1–7 with minimal churn. Retired in Phase 12 (Option C).

**Option C** (Phase 12): **the zonk retirement phase.** Expression representation changes — `expr-meta id` becomes `expr-cell-ref cell-id`. Reading an `expr-cell-ref` auto-resolves via cell dereference to `:term` facet. *Reading the expression IS zonking.* No tree walk. `zonk.rkt` functions deleted.

**Pipeline impact — post-2/3/4A/4B state** (refined by R2 external-critique response 2026-04-18):

The "14-file pipeline" framing that appeared in earlier drafts and in [`.claude/rules/pipeline.md`](../../.claude/rules/pipeline.md) reflects a pre-PPN-series state. Track 2 deleted `reader.rkt`; Track 3 retired `parser.rkt` from WS dispatch; Track 4A/4B moved 90% of typing on-network via `typing-propagators.rkt`. Phase 12's actual surface:

- [`syntax.rkt`](../../racket/prologos/syntax.rkt) (1157 lines): new `expr-cell-ref` struct; `expr-meta` eventually deleted.
- [`surface-syntax.rkt`](../../racket/prologos/surface-syntax.rkt): no change (surface doesn't see cell-refs).
- [`tree-parser.rkt`](../../racket/prologos/tree-parser.rkt) (1856 lines, primary WS parser post-Track-2/3): no change (parses surface, not core).
- [`parser.rkt`](../../racket/prologos/parser.rkt) (6605 lines, now sexp-path + expression-parsing-via-datum only): produces `expr-meta` initially; elaborator converts to `expr-cell-ref` at meta installation.
- [`elaborator.rkt`](../../racket/prologos/elaborator.rkt) (4156 lines): meta installation produces `expr-cell-ref`. Residual imperative elaboration paths (shrinking).
- [`typing-core.rkt`](../../racket/prologos/typing-core.rkt) / [`typing-propagators.rkt`](../../racket/prologos/typing-propagators.rkt): propagators read `:type` facet via cell-ref; residual ~10% imperative infer/check.
- [`qtt.rkt`](../../racket/prologos/qtt.rkt): inferQ/checkQ handle cell-ref.
- [`reduction.rkt`](../../racket/prologos/reduction.rkt): β/δ/ι handle cell-ref (dereference before reducing).
- [`substitution.rkt`](../../racket/prologos/substitution.rkt): substitution follows cell-refs.
- [`zonk.rkt`](../../racket/prologos/zonk.rkt) (1372 lines): **DELETED wholesale** — reading a cell-ref IS zonking. `freeze-top`/`zonk-top` driver plumbing retired.
- [`pretty-print.rkt`](../../racket/prologos/pretty-print.rkt): dereferences cell-refs for display.
- Optional/peripheral: `unify.rkt`, `macros.rkt`, `foreign.rkt`.

Grep-backed scope: `expr-meta` has **104 occurrences across 19 files** (grep command: `rg -c "expr-meta" racket/prologos/*.rkt`). Many sites *simplify* because they used to walk through zonk; the deletion is dominant over the substitution.

**Phase 12 sub-split (post-R2 response 2026-04-18)**:

- **12a** — Add `expr-cell-ref` struct ([`syntax.rkt`](../../racket/prologos/syntax.rkt)) + dereferencing primitive. No call-site changes.
- **12b** — Flip all `expr-meta` construction sites to `expr-cell-ref`; readers go through the new dereferencing API. Residual `expr-meta` constructors deleted.
- **12c** — Delete [`zonk.rkt`](../../racket/prologos/zonk.rkt) wholesale (~1,300 lines) + driver `freeze-top`/`zonk-top` plumbing.
- **12d** — Acceptance (L3) + A/B bench (E3 freeze cost → 0) + integration confirmation.

Rationale: the split respects `workflow.md` "conversational implementation cadence" (max 1h autonomous stretch before checkpoint). 104 sites across 19 files is work-volume-dense, not pipeline-surface-wide.

**DPO contribution**: substitution, β-reduction, η-expansion become graph rewrites on the cell-ref network. The adhesive-category rewriting primitives ([Adhesive Research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md)) apply directly. These primitives are the infrastructure SRE Track 6 builds on — Option C in 4C means SRE 6 doesn't re-invent elaboration-specific DPO machinery.

**PUnify becomes universal for expressions**: under Option C, cell-ref dereferencing IS a one-step PUnify operation invoking `unify-core` with `'equality` relation on the resolved cell value; expression reduction IS graph rewriting via `sre-structural-classify` ctor-desc dispatch. "Reading the expression" IS PUnify with the current cell state. Zonking dissolves because reading already does the substitution structurally via the existing `current-structural-meta-lookup` mechanism. Every expression operation (type inference, reduction, pattern matching, display) becomes PUnify + ctor-desc on the cell-ref graph. Same machinery that handles types (§6.1, §6.2, §6.5) now handles expressions (§6.6) — unified computational substrate. See §6.13 for the PUnify audit confirming this reuse.

### §6.7 Elaborator strata → BSP scheduler unification (A7, Phase 11) — module composition

**Problem**: `run-stratified-resolution-pure` ([metavar-store.rkt:1915](../../racket/prologos/metavar-store.rkt)) is a sequential orchestrator parallel to the BSP scheduler. The BSP scheduler already has `register-stratum-handler!` ([propagator.rkt:2392](../../racket/prologos/propagator.rkt)) with `:tier 'topology | 'value` dispatch.

**Module-theoretic framing (§6.11.6)**: each stratum is a **module over the base propagator network**; `register-stratum-handler!` is module composition. A7 consolidates two orchestration mechanisms into one by realizing that BSP's solver strata (topology, S1 NAF) and the elaborator's strata (S(-1), L1, L2) are both modules over the same base network. The A1 addendum (BSP-LE 2B) established this pattern for the topology stratum; 4C extends it to the elaborator's strata.

**Fix**: register elaborator strata as BSP stratum handlers.

```
;; S(-1) retraction
(register-stratum-handler!
 retraction-request-cell-id
 (lambda (net req-set)
   (for/fold ([n net]) ([req (in-set req-set)])
     (narrow-scoped-cells-for-retracted-assumption n (retraction-request-aid req))))
 #:tier 'value
 #:reset-value (set))

;; S1/L1 readiness and S2/L2 actions
(register-stratum-handler!
 ready-queue-cell-id
 (lambda (net actions)
   (for/fold ([n actions-processed]) ([action actions])
     (execute-resolution-action n action)))
 #:tier 'value)
```

**Post-A7 state**: the BSP outer loop iterates all stratum handlers. `run-stratified-resolution-pure` retires. The `fuel` parameter becomes part of the BSP outer loop's termination discipline (matches the `stratification :fuel` NTT declaration).

**Readiness propagators already populate the ready-queue cell** — L1's `collect-ready-constraints-via-cells` scan dissolves (readiness is already cell-valued; the scan was a leftover pattern).

### §6.8 `:component-paths` registration-time enforcement (A8, Phase 1) — Tier 1/2/3 architecture

**Problem**: the rule "propagators reading compound cells MUST declare `:component-paths`" has been discipline-maintained ([propagator-design.md](../../.claude/rules/propagator-design.md)). Multiple design/implementation audits have repeatedly re-checked component-path coverage; things have slipped through. Correctness-by-construction required.

**Fix (D.2 refined after self-critique R1+P4, 2026-04-17)**: three-tier architecture. Classification belongs to the *lattice* (the algebraic type), not the cell (an instance). The declaration point sits at Tier 2 (merge function, which implements the lattice); cells inherit.

**Tier 1 — Lattice types as SRE domains (A9, already in scope)**:

The lattice is registered as an SRE domain with its classification (VALUE/STRUCTURAL) and algebraic properties (Heyting, quantale, residuated, etc.). See §6.9.

```racket
(register-domain! TypeFacetDomain
  #:lattice :structural
  #:properties '(Quantale Heyting-ground Residual)
  ...)
```

**Tier 2 — Merge functions linked to lattice types (NEW infrastructure)**:

Each merge function declares which domain (Tier 1 lattice type) it implements:

```racket
(register-merge-fn!/lattice hasheq-union
  #:for-domain 'StructuralHasheqDomain)

(register-merge-fn!/lattice type-lattice-merge
  #:for-domain 'TypeFacetDomain)
```

The registration links Tier 2 implementation to Tier 1 type. API shape is open for mini-design during Phase 1 (plausible alternatives: merge-fn struct with domain field; coupled to SRE domain registration with merge slot).

**Phase 1 mini-design decision** (captured 2026-04-19 from mini-audit):

SRE's `register-domain!` takes a `sre-domain` STRUCT (not keyword arguments) with a `merge-registry` field mapping `(relation-name → merge-fn)` — the FORWARD mapping. Phase 1 Tier 2 needs the REVERSE mapping: merge-fn → domain. Two realization paths:

- **Option (a) — Independent reverse-lookup registry**. New module-level `(make-hasheq)` keyed by merge-fn (object identity), valued by domain-name. `register-merge-fn!/lattice` writes to this new registry. Independent of SRE's `domain-registry`. **Blast radius**: Phase 1 only, no SRE modifications. **Cost**: one more registry for PM Track 12 to migrate (adds DEFERRED.md row — already captured).

- **Option (b) — Extend SRE domain semantics**. When `register-domain!` fires, iterate the domain's `merge-registry` values and register each merge function reverse into a cross-table (or compute reverse on demand). The SRE domain's `merge-registry` IS the authoritative mapping; reverse is derived. **Blast radius**: touches SRE domain registration semantics. **Cost**: couples Phase 1 to Tier 1 semantics bidirectionally.

**Lean: (a)**. Rationale: smaller blast radius, cleaner Phase 1 boundary; PM Track 12 eventually consolidates both registries anyway; (b)'s principled "single source of truth" benefit is deferred rather than lost.

**Consequence of (a)** — the `:for-domain` keyword in `register-merge-fn!/lattice` references a domain by NAME (symbol), not by struct. The reverse-lookup registry stores `merge-fn-identity → domain-name-symbol`. Lookup chains: `net-new-cell` receives `merge-fn` → reverse registry returns `domain-name` → SRE's `lookup-domain` returns `sre-domain` struct → classification field read.

**Tier 3 — Cells inherit from their merge function**:

```racket
;; Default: cell inherits merge function's registered domain
(net-new-cell net initial hasheq-union)
;; → cell's domain = 'StructuralHasheqDomain
;; → classification inferred = :structural

;; Override: explicit alternate registered domain
(net-new-cell net initial hasheq-union #:domain 'SimpleKeyValueDomain)
;; → cell's domain = 'SimpleKeyValueDomain (must be separately registered)
;; → classification follows from override domain's Tier 1 registration
```

**The `#:domain` keyword** takes a named registered domain. Overrides require the alternate domain to exist in Tier 1 — no anonymous classification tags. Forces exceptions to have a documented home. Pre-registered generic "Anonymous{Value,Structural}Domain" entries are NOT included in Phase 1 scope; added only if real need emerges.

**Why `#:domain` rather than `#:lattice`** (resolved in D.2 refinement 2026-04-17):

The cell is not a lattice — it's an *instance* of a lattice. "Annotate `:lattice` on the cell" conflates instance with type and reads like "is this cell a lattice?" which is incoherent. `#:domain` uses SRE vocabulary consistently: a cell belongs to a domain; the domain is a lattice type; classification is a property of the domain.

**Enforcement at `net-add-propagator`** (semantically unchanged from prior approach):

```
For each input cell:
  read cell's domain (inherited or #:domain-overridden)
  read domain's Tier 1 classification (:structural / :value)
  if classification = :structural AND :component-paths missing for this cell:
    error 'net-add-propagator
          "cells in structural domain ~a require :component-paths"
  if domain unregistered or :unclassified: warning (tracked baseline)
```

Type-check-like correctness at registration. Declaration point is the merge function (Tier 2); cells derive structurally.

**Migration under the Tier 2 approach** (R1 resolved):

Production scope measured (grep 2026-04-17):
- **101 production `net-new-cell` call sites** (D.2 original mentioned 666; that figure included tests, benchmarks, pnet cache).
- **37 distinct merge functions** in production.
- **Top 10 merge functions cover ~70% of production calls**.
- **1% inline lambdas** (1 of 101 production calls).

Phase 1 work (sub-phased; structure refined 2026-04-19):
1. **Phase 1a ✅**: `tools/lint-cells.rkt` + production baseline (101 sites, 27 unique unregistered at snapshot time).
2. **Phase 1b ✅**: Tier 2 API — `register-merge-fn!/lattice` (option (a) independent reverse-lookup registry per §6.8 below).
3. **Phase 1c ✅**: `#:domain` kwarg on `net-new-cell` + variants + Tier 3 inheritance + `lookup-cell-domain`.
4. **Phase 1.5 ✅** (inserted): srcloc infrastructure — prerequisite for Phase 2's `:warnings` correct-first-time registration.
5. **Phase 2 ✅** (pulled forward): 4 facet SRE domain registrations + atomic Tier 1+2 linkage per facet.
6. **Phase 2b ✅** (pulled forward): Hasse-registry primitive + its own SRE domain.
7. **Phase 1d ⬜** (NEXT — 2026-04-19): registration campaign for remaining ~22 merge functions + inline lambda rewrite + multi-line triage. **δ approach (D1 2026-04-19)** for `merge-hasheq-union`: register under `'monotone-registry` with honest D2 delta documenting mechanical vs intended semantics gap. **Ambiguous-name sites (D3 2026-04-19)**: leave as-is — runtime Tier 3 inheritance is correct; lint-tool rename "ambiguous" → "parameterized-passthrough" category.
8. **Phase 1e ⬜** (NEW 2026-04-19 — not deferred to DEFERRED.md per D2 resolution): correctness refactors. **η split**: `merge-hasheq-union` → `merge-hasheq-identity` + `merge-hasheq-replace`; audit 23 call sites per semantic intent. **Replace-cell audit**: each `merge-last-write-wins` + `merge-replace` call site classified per refactor path: (1) timestamp-ordered lattice for commutative+assoc+idem upgrade (may warrant timestamped-cell primitive); (2) identity-or-error flat lattice with contradiction on conflict; (3) accept as non-lattice with documented rationale. Audit → classify → refactor.
9. **Phase 1f ⬜**: hard-error flip at `net-add-propagator`. Gated by 1d+1e completion (lint baseline empty; all cells classified).
10. **Phase 1V ⬜**: Vision Alignment Gate for Phase 1 completion per Stage 4 step 5.

Compare to D.2 original: 666-site annotation → 37-function registration. Order-of-magnitude smaller and more principled.

**Secondary wins from Tier 2 audit**:
- Propagators reading compound cells without `:component-paths` — caught as bugs during migration.
- Merge functions used for different purposes across cells — forced to resolve (split into per-domain variants, or split domain definitions).
- Ad-hoc inline lambda merges — migration pressure to name and register.

**NTT alignment**: [NTT Syntax §3.1](2026-03-22_NTT_SYNTAX_DESIGN.md) already declares lattice types with `:lattice :structural`:

```prologos
type TypeExpr := ...
  :lattice :structural

trait Lattice {L : Type}
  spec join L L -> L

impl Lattice TypeExpr
  join type-lattice-merge  ;; ← this IS Tier 2 linking
  bot  type-bot
```

The Racket-level `register-merge-fn!/lattice` IS the Tier 2 declaration that `impl Lattice L` with `join fn` syntactically compiles to. When NTT design resumes, Racket migration is zero — the infrastructure IS the compile target of the NTT form.

### §6.9 Per-facet SRE domain registration (A9, Phase 2)

**Problem**: only `type-sre-domain` is registered ([unify.rkt:109](../../racket/prologos/unify.rkt)). Four facet lattices unverified.

**Fix**: register `context-sre-domain`, `usage-sre-domain`, `constraint-sre-domain`, `warning-sre-domain`. Each declares `bot`, `top`, `merge`, monotonicity, properties. Property inference runs **explicitly** (not auto-triggered by `register-domain!`). `:term` deferred to Phase 3.

**Expected outcome**: based on Track 3 §12 and SRE 2G precedent (each found ~1 lattice bug), property inference likely finds ≥1 facet-lattice bug. Under D2 framework (§6.9.2), refutation is DATA in the delta table, not a registration failure. Predicted delta count: 2 (`:context` non-commutative by design; `:warnings` resolves Phase 5); both are accepted design or scoped — 0 real bugs predicted, within K=2 R5 contingency.

**Phase 2 mini-audit findings (2026-04-19)**:

1. **Per-facet merge functions located**:
   | Facet | Merge function | Location | Bot value |
   |---|---|---|---|
   | `:type` | `type-lattice-merge` | [type-lattice.rkt](../../racket/prologos/type-lattice.rkt) (already registered as `type-sre-domain`) | `type-bot` |
   | `:context` | `context-cell-merge` | [typing-propagators.rkt](../../racket/prologos/typing-propagators.rkt) | `#f` (Track 4B bug #2 fix — distinguishable from empty-context) |
   | `:usage` | `add-usage` | [qtt.rkt](../../racket/prologos/qtt.rkt) — pointwise multiplicity addition | `'()` |
   | `:constraints` | `constraint-merge` | [constraint-cell.rkt](../../racket/prologos/constraint-cell.rkt) — Heyting powerset | `constraint-bot` |
   | `:warnings` | raw `append` (inside `facet-merge`) | [typing-propagators.rkt](../../racket/prologos/typing-propagators.rkt) | `'()` — Phase 2 wraps as named `warnings-facet-merge` |

2. **Registration pattern** — `make-sre-domain` keyword-arg API from `type-sre-domain` template:
   ```racket
   (make-sre-domain
     #:name 'context
     #:merge-registry <fn: relation-name → merge-fn>
     #:contradicts? <pred>
     #:bot? <pred>
     #:bot-value <value>
     #:top-value <value>)
   (register-domain! context-sre-domain)
   ```

   `merge-registry` is a FUNCTION (not hash) — takes relation-name (`'equality`, `'subtype`, etc.) and returns merge fn. Simple facets register only `'equality`.

3. **Property inference**: `sre-core.rkt` defines `test-commutative-join`, `test-associative-join`, `test-idempotent-join`, `test-distributive-join`. **Zero callers** in codebase today. `register-domain!` does NOT auto-trigger inference. Phase 2 must invoke explicitly, record results in D2 delta table.

4. **ConstraintsToWarnings bridge** — S1 audit item **cleared**: no soft-diagnostic flow from `:constraints` to `:warnings` exists today. No bridge needed.

5. **Registration location (β decentralized)** — each facet's `register-domain!` lives where its merge function lives. `:warnings` wrapper goes in warnings.rkt (cleanest home).

**Phase 2 Q7 resolution: immediate Tier 1 + Tier 2 linkage per facet** (decided post-audit):

Each facet registration is atomic — Tier 1 (SRE domain) + Tier 2 (`register-merge-fn!/lattice`) together. Rationale: Completeness — "the facet is registered" means fully, not half-way. Cell allocation via each facet's merge function immediately inherits the domain (Tier 3). Lint baseline shrinks by 4 after Phase 2; Phase 1d closes the remaining ~22 non-facet merge functions.

**Phase 2 Q8 resolution: refutation recorded as data** — property inference returns `axiom-confirmed` / `axiom-refuted` structs. Refutation does not fail registration; it populates the D2 delta table's "inference-result" row.

**Audit items checked**:

- **ConstraintsToWarnings potential bridge**: **cleared** — no such flow exists (grep 2026-04-19).
- **Other latent cross-facet flows**: no evidence in current 4B code; spot-check during inference runs.

#### §6.9.1 Phase 1.5 — srcloc infrastructure (NEW 2026-04-19)

**Context**: Phase 2's `:warnings` registration requires position-in-value for set-lattice semantics (D1 resolution). Current warning structs lack srcloc. Threading srcloc at emit sites requires either a `current-source-loc` mechanism or wide function-signature changes. The srcloc need also appears in Phase 11b diagnostic infrastructure (M4 external critique — backward residuation anchors), LSP tooling (PM Track 11), PPN Track 6 (error recovery), and PPN Track 5 (type-directed disambiguation). Rather than thread one-offs into Phase 2 and Phase 5, **Phase 1.5** builds unified srcloc infrastructure once, with a clean API that downstream consumers inherit.

**Scope IN (for Phase 1.5 proper)**:
- srcloc "current source location" mechanism design — Racket parameter, on-network cell, or `:context`-facet field (decision at Phase 1.5 mini-design audit)
- API surface for emit sites: `(current-source-loc)` or equivalent reader
- Threading discipline: set at top-level command processing + AST-walk propagation; invariant = "at any emit point, `(current-source-loc)` returns the srcloc of the AST node being processed"
- Tests verifying srcloc presence + accuracy across representative elaboration paths

**Scope OUT (deferred to consuming phases)**:
- Warning struct srcloc field additions (Phase 5 — uses Phase 1.5 API)
- Provenance chain assembly (Phase 11b)
- LSP protocol integration (PM Track 11)
- Per-binding context-scope srcloc (Phase 2, `:context` design choice)

**D1 resolution applied to `:warnings`** (per [structural-thinking.md](../../.claude/rules/structural-thinking.md) § "Direct Sum Has Two Realizations"): warnings become a set lattice with srcloc carried IN value, merged via `merge-set-union`. Quantales are not necessarily commutative, but the position-in-value pattern (precedent: PPN Track 1 source-line-keyed, Track 2B §12.6) makes `:warnings` commutative + idempotent by structure, preserving position via the srcloc field rather than list order.

#### §6.9.2 Per-facet projected shape (D2 framework, 2026-04-19)

**D2 framework** (user direction 2026-04-19): each facet registration ships with an **aspirational / declared / inference-result / delta** analysis table as a commit artifact. Aspirational = what we think SHOULD hold; declared = minimal conservative declaration (γ); inference result = empirical verification; delta = resolution (fix merge, accept + document, or defer to named phase).

| Facet | Aspirational | Declared initially | Expected inference | Expected delta |
|---|---|---|---|---|
| `:type` (re-verify) | commutative, associative, idempotent, Heyting under subtype | existing `type-sre-domain` declarations | confirm all | no delta (verify drift-free) |
| `:context` | associative; NON-commutative (binding order is scope order); idempotent under same-depth bindings | associativity only | confirm associativity; refute commutativity | **accept** non-commutativity — `:context` is a non-commutative monoidal structure (quantale-like, similar to sessions). Document as design. |
| `:usage` | commutative (max-join over multiplicities), associative, idempotent | all three | should confirm all | no delta expected |
| `:constraints` | commutative, associative, idempotent, Heyting powerset | all four | should confirm (existing infrastructure) | no delta expected |
| `:warnings` | commutative + idempotent (**with srcloc in-value per D1**); associative | all three (post-Phase-1.5 srcloc + Phase 5 struct update) | confirm all | **delta resolved Phase 5** — Phase 1.5 provides srcloc; Phase 5 adds struct field + switches merge to `merge-set-union` + re-runs inference |
| `:term` (Phase 3) | Phase-3 mini-design dependent (S1 finding) | TBD at Phase 3 | TBD | captured in Phase 3 D2 table |

**Phase 2 commit artifact** — each facet registration commit includes its own table (above format), plus:
- Inference-result line (what ran, what passed, what refuted)
- Delta resolution notes (for each refuted aspirational property, either fix or document)

**R5 contingency status** (per D2):
- "Bug found" = aspirational property refuted AND aspirational correct (fix required)
- "Conservative under-declaration" = inference confirms MORE than declared (positive — update declarations)
- Predicted bugs under current framing: **0-1** (within K=2 absorption). `:warnings` is scoped to Phase 5, not counted as Phase-2 bug. `:context` non-commutativity is accepted design, not a bug. If property inference surfaces something unexpected in `:type`/`:usage`/`:constraints`, that's the bug that fires contingency.

### §6.10 Union types via ATMS + cell-based TMS (Phases 9 + 10)

**BSP-LE 1.5 as 4C sub-track** (per audit §9.5 recommendation):

- **Phase A**: worldview-cell infrastructure. Create worldview cells alongside attribute-map cells. Propagators read worldview from cells.
- **Phase B**: `net-cell-write` / `net-cell-read` accept explicit worldview argument (backward-compatible with `current-speculation-stack` parameter).
- **Phase C**: migrate speculation users (elab-speculation-bridge, union type checking) to cell-based worldview.
- **Phase D**: `current-speculation-stack` parameter retired.

See [Cell-Based TMS Design Note](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) for the detailed migration path. Scope estimate: ~450 lines.

**Phase 8 (union types via ATMS)** builds on cell-based TMS. **Mechanistically, ATMS branching on a union type IS applying SRE ctor-desc to the ⊕ constructor**: a union type `A | B` is `A ⊕ B` in the TypeFacet quantale; ctor-desc of the ⊕ constructor yields two components; ATMS branching instantiates the structural decomposition into per-component branches. Each branch is ONE COMPONENT of the ⊕ structural decomposition, tagged with its own assumption. **PUnify within each branch** resolves sub-expressions against the component type.

```
;; When :type facet at position becomes union A | B:
;; This IS ctor-desc decomposition of the ⊕ constructor.
fork-on-union:
  ;; SRE ctor-desc for ⊕ (union-join) decomposes: components [A, B]
  ;; Each component gets its own assumption + tagged worldview
  aid-a := fresh-assumption
  aid-b := fresh-assumption
  branch-a := tag-worldview aid-a   ;; structural: component-1 of ⊕
  branch-b := tag-worldview aid-b   ;; structural: component-2 of ⊕
  ;; Both branches elaborate concurrently under their tagged worldview.
  ;; PUnify within each branch resolves sub-expressions against the component type.
  ;; Facet writes are TMS-tagged with the branch assumption.

;; On contradiction in branch-a (:type → type-top):
retract-contradicted:
  narrow :type facet by removing tagged entries for aid-a.
  emit narrowed :type = B.   ;; residual component after failed branch retracted

;; On both branches succeeding:
merge-viable-branches:
  compute S0 quiescence per branch.
  S2 barrier commits surviving branch(es) to base worldview.
```

**Connection to existing infrastructure**: BSP-LE Track 2B's per-propagator worldview bitmask + S1 NAF handler pattern (fork+BSP+nogood) IS this shape. ATMS assumption management is the BSP-LE ATMS solver; the only difference is the lattice on which merge occurs. The framing "ATMS union branching IS ctor-desc decomposition of ⊕" makes Phase 10 a natural extension of SRE ctor-desc dispatch — not a special case requiring new machinery.

**Framing note (M4 clarification 2026-04-18)**: "ATMS branching IS ⊕ ctor-desc decomposition" is a *conceptual lens* explaining why the ATMS mechanism applies cleanly to union types. The Phase 10 implementation uses the existing `atms-amb` / assumption-creation / worldview-forking machinery from BSP-LE 2+2B — not a new ctor-desc-driven mechanism. The lens justifies the principled connection without claiming an implementation change.

**PUnify within each branch**: per-branch elaboration invokes [`unify-union-components`](../../racket/prologos/unify.rkt) (unify.rkt:777) for compound-type unification under the branch's tagged worldview. Pre-existing: the function flattens/sorts/dedupes components and PUnifies pairwise. Reused as-is. See §6.13 for audit.

---

### §6.11 Design Lenses — Hyperlattice Conjecture / SRE / Hypercube Applied

Per user direction 2026-04-17: apply the SRE lens ([`structural-thinking.md`](../../.claude/rules/structural-thinking.md)) + Hypercube perspective ([BSP-LE Hypercube Addendum](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)) to strengthen the Hyperlattice Conjecture argument specifically within 4C.

The Conjecture ([DESIGN_PRINCIPLES.org](principles/DESIGN_PRINCIPLES.org) §Hyperlattice Conjecture) has two parts:
1. **Universal computational substrate** — every computable function is a fixpoint on lattices.
2. **Parallel optimality** — the Hasse diagram IS the optimal parallel decomposition.

#### §6.11.1 SRE lens: every facet is a lattice embedding

Per the SRE Lens's 6 questions (`structural-thinking.md`), each of the 6 facets receives an algebraic classification. This is **mandatory** per DESIGN_METHODOLOGY — the SRE lattice lens is required for all lattice design decisions, and property-inference verifies lattice laws.

| Facet | VALUE vs STRUCTURAL | Algebraic properties | Primary or Derived | Hasse diagram structure |
|---|---|---|---|---|
| `:classify-and-inhabit` (shared carrier for `:type` + `:term` surface names; see §6.1) | STRUCTURAL (quantale) | Join-semilattice, ⊗ tensor, ⊕ union-join, Heyting (ground sublattice), **left/right residuals** (`:preserves [Residual]`). Tag-dispatched merge for CLASSIFIER vs INHABITANT layers. | PRIMARY | Product of ctor-lattices; width = # type constructors; height = nesting depth. Residuation is internal — tag-cross merge IS quantale residual computation |
| `:context` | VALUE (list) | Chain lattice (extension only); monotone growth | DERIVED from enclosing scope | Linear chain; height = scope depth |
| `:usage` | STRUCTURAL (vector semiring) | Component-wise QTT semiring (m0, m1, mw + add + scale) | PRIMARY | Product of per-binding mult chains; width = # bindings |
| `:constraints` | STRUCTURAL (Heyting powerset) | Heyting lattice, distributive, set intersection narrowing | PRIMARY | Boolean lattice over candidate set; complement structure |
| `:warnings` | VALUE (monotone set union) | Free join-semilattice | DERIVED (receives from TypeToWarnings bridge + multi-source warning propagators) | Flat — union of independent warnings |

**D.2 consolidation**: 6 facets → 5 facets. `TermFacet` retires; `:type` and `:term` tag-layer on the shared TypeFacet carrier. `TermInhabitsType` bridge retires; replaced by internal quantale residuation (§6.2).

**D.2 refinement (S1)**: TypeToWarnings bridge added to §4.3 — coercion + deprecation warnings flow from TypeFacet (one-way). Multi-source warning detectors (multiplicity violation, capability requirement) remain as propagators, not bridges.

**Bridges between facets are Galois connections** (§4.3) — left adjoint preserves joins. This IS the Universal Substrate argument for 4C: *every facet is a lattice embedding; every cross-facet flow is a verified Galois connection; elaboration IS fixpoint on the product of embedded algebraic structures.*

#### §6.11.2 Hypercube perspective: parallel optimality of the AttributeRecord

The AttributeRecord is a **product** of 6 facet lattices. Its Hasse diagram is the product of per-facet Hasse diagrams. By the Conjecture's optimality claim, *the parallel decomposition of attribute computation IS this product structure*:

- **Per-facet propagators fire independently** — component-wise merge means `:type` and `:warnings` updates don't block each other. This is CALM-safe + structurally parallel by construction, not by discipline.
- **Cross-facet bridges (Galois connections) are the coordination points** — the Hasse diagram's edges between product components. Only bridges (not all propagators) coordinate.
- **Hasse diameter bounds BSP round count** — for an elaboration producing N facet writes with cross-facet dependency depth D, BSP reaches fixpoint in O(D) rounds (not O(N)). The Hasse diagram's vertical height bounds iteration count.

#### §6.11.3 Phase 10 (union types via ATMS) — hypercube structure explicit

The worldview space for N union branches IS Q_N (Boolean lattice = hypercube), per [Hypercube Addendum §1](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md). This STRUCTURAL IDENTITY — not metaphor — implies three optimizations to incorporate in Phase 10 design:

1. **Gray-code branch traversal** (Hypercube Addendum §2.1). When `atms-amb` creates M branches, explore them in Gray-code order (one-assumption-change between successors). CHAMP structural sharing reuses O(affected cells) per fork instead of O(all cells). Phase 10's fork strategy follows Gray-code.

2. **Subcube pruning for nogoods** (§2.2). When a contradiction in branch A produces a nogood `{h_A, h_B, h_C}`, the subcube of worldviews containing that assumption combination is STRUCTURALLY identifiable as a bitmask `(worldview & nogood-mask) == nogood-mask` — O(1). For worldviews up to 64 bits, a single 64-bit AND + compare. Phase 10's retraction uses bitmask subcube membership, not hash lookups.

3. **Hypercube all-reduce for S(-1) retraction barrier** (§2.3). When retraction affects multiple branches, use hypercube all-reduce (log₂(W) rounds of pairwise merge) instead of flat synchronization. Bounded for BSP-LE 1.5 sub-track's parallel execution paths.

#### §6.11.4 Phase 7 parametric-trait-resolution — Hasse-based index via §6.12 primitive

The parametric impl registry is an instance of the **Hasse-registry primitive (§6.12)**. Lattice = impl-pattern specificity order; entries = impl bodies; `position-fn` = impl's pattern type; `lookup-fn` does O(log N) structural navigation via PUnify on Hasse neighbors.

The SRE lens identifies this index as the *Hasse diagram of the impl coherence lattice* — where each impl is a node, and the partial order is *specificity* (`Eq Int` is more specific than `Eq A`). Matching at resolution time dispatches through the Hasse diagram's structural index from most-specific candidates:

- **O(log N) lookup** for N impls, via the Hasse height (not N scan).
- **Coherence = antichain** of maximal specific impls; zero critical pairs.
- **Specificity resolution** IS the Hasse order — most-specific match wins.

This is what the "rebuilt for efficiency" posture means concretely: the candidate-index IS the Hasse decomposition of the impl coherence lattice. The efficiency gain vs current E2 (343 MB) comes from the Hasse diagram's structural navigation, not an iterative algorithm. Post-§6.12 extraction: Phase 7's impl registry is ~30-50 lines (`position-fn` + post-lookup dict construction) built on the ~150-200-line primitive, rather than ~150 lines of ad-hoc Hasse implementation.

#### §6.11.5 Implications for 4C

Applying these lenses changes three concrete design elements:

1. **Every propagator declaration should name its lattice properties** (Value/Structural, Primary/Derived, algebraic properties). This makes the NTT conformance check (§15) richer than "is it expressible?" — it becomes "does the lattice classification match the SRE lens's structural analysis?"
2. **Hasse-diagram diameter bounds appear in termination arguments** (§8). The existing `:fuel 100` is a safety net; the Hasse bound is the structural argument. Strengthens Conjecture's optimality claim per stratum. **M2 external-critique lean (2026-04-18)**: fuel itself becomes a tropical-lattice cell (min-merge) rather than a decrementing counter — on-network resource tracking, not ambient state. First practical tropical-lattice implementation in Prologos; pattern template for upcoming PReduce. See Progress Tracker row 9 for Phase 9 mini-design obligation.
3. **Phase 10 design uses hypercube algorithms by construction** — not as an optimization pass. Gray-code, bitmask subcube, hypercube all-reduce are in the D.2 refinement.

#### §6.11.6 Stratification IS module composition over the base network

Applying the Module Theory lens to §6.7 (elaborator strata → BSP scheduler): each stratum is a module over the base propagator network; `register-stratum-handler!` is the composition operator. The full `stratification ElabLoop` declaration (§4.5) IS a composed module — S(-1)/S0/S1/S2 are independent modules composed by the BSP outer loop's orchestration.

This makes §6.7's "elaborator strata → BSP handlers" consolidation not just a mechanism unification but a module-theoretic realization: both BSP's solver strata (topology, S1 NAF) and elaborator's strata (S(-1), L1, L2) are modules over the same base. A1 addendum (BSP-LE 2B) established this for topology; 4C extends it to elaborator strata. Under the lens, the NTT `stratification` form IS module declaration + composition. Future NTT refinement: explicit module semantics for stratification.

#### §6.11.7 Note on the General Residual Solver (future BSP-LE scope)

During D.1 dialogue (2026-04-17), a cross-application pattern surfaced: PUnify, FL-Narrowing, BSP-LE, trait resolution, bidirectional type-checking, parse disambiguation, ATMS narrowing — **each is a residual computation on a quantale/lattice with a stratified + ATMS-tagged + CALM-compliant solver**. A general solver parameterized by `:lattice`, `:composition`, `:decomposition`, `:facts` would unify these as instances.

**Scoping**: the generalization is **out of 4C scope**. Audit of [BSP-LE 2/2B's search machinery](racket/prologos/relations.rkt) (2026-04-17) confirmed it is structurally a *relation-with-atoms solver*: `goal-desc` kinds, `clause-info`, `unify-terms`, discrimination are coupled to the relation model. Generalizing to arbitrary quantales requires lifting these primitives into a lattice-parameterized abstraction — a future **BSP-LE series track**, not 4C.

**What 4C DOES consume**: the *substrate* — BSP scheduler, `register-stratum-handler!`, worldview bitmask, ATMS assumption management, stratification. These are lattice-agnostic and already used by typing-propagators.rkt + elaborator-network.rkt. Hole-fill γ (Q1), parametric trait resolution (Axis 1), union-type ATMS (Phase 10) all use the substrate directly with specific propagators — not by invoking the BSP-LE relational solver.

**Forward reference**: the general residual solver track (when designed) consumes 4C's lattice specifications as example instances. PPN 5 (type-directed disambiguation), future FL-Narrowing refinements, and future PPN work that needs residual search inherit the general solver once it exists. Captured here so the insight isn't lost.

---

### §6.11.8 Full lattice catalog — lens applied comprehensively (O2 resolution)

O2 finding: §6.11.1 applies the SRE lens to the 5 facets, but other lattices in the design (AttributeRecord, AttributeMap, worldview, impl coherence, inhabitant catalog, Hasse-registry ambient L, tagged-cell-value layers, stratum-handler request cells) aren't uniformly characterized. Per CRITIQUE_METHODOLOGY §"SRE Lattice Lens (Mandatory for All Lattice Design Decisions)" — every lattice in a design needs the lens applied. This subsection closes that gap.

Deeper per-lattice treatments live in referenced subsections; this catalog is the consolidated lens reference.

#### Compound / aggregate lattices

**AttributeRecord** (§4.2, §6.11.2)

- **Classification**: STRUCTURAL — product of 5 facet lattices.
- **Algebra**: component-wise merge per facet; inherits properties from components (e.g., if one facet is Heyting, the product has component-wise Heyting).
- **Primary/Derived**: PRIMARY — central information store per AST position.
- **Hasse**: product Hasse of the 5 facet lattices. Vertical height = max component depth; width = sum of component widths.
- **Module Theory**: direct sum ⊕_{facet} FacetLattice. Component-wise independent merges. Facets are modules over AttributeRecord's base.
- **PUnify**: operates at the facet level (per-facet merge), not at the record level. The record aggregates facet-local PUnify results.
- **Hasse compute topology**: per-facet propagators fire independently on their component (§6.11.2). Cross-facet bridges coordinate at Galois-connection edges.

**AttributeMap** (§4.2)

- **Classification**: STRUCTURAL — hashmap of position → AttributeRecord.
- **Algebra**: per-position compound merge (each position's AttributeRecord merges component-wise).
- **Primary/Derived**: PRIMARY — global elaboration state on the persistent registry network.
- **Hasse**: two-level compound — outer per-position Hasse (position growth is monotone addition); inner per-facet Hasse (product structure).
- **Module Theory**: direct sum ⊕_{position} AttributeRecord(position). Each position is a module. Compound component-paths `(cons cell-id (cons position facet))` address the product structure for targeted propagator firing.
- **PUnify**: per-facet per-position.

#### Registry / catalog lattices

**Impl coherence lattice** (§6.11.4, Phase 7)

- **Classification**: STRUCTURAL — partial order over impl patterns by specificity.
- **Algebra**: poset at minimum; may be a lattice if meet/join (most-general-instance / most-specific-subsumer) are well-defined for arbitrary impl patterns.
- **Primary/Derived**: PRIMARY within trait-resolution mechanism.
- **Hasse**: specificity order — more-specific-below. Coherence = antichain at each level = zero critical pairs (verified at registration via Adhesive DPO analysis).
- **Module Theory**: entries at each Hasse node form an independent group; ⊕_{node} ImplSet(node) via Hasse-node tagging.
- **PUnify**: lookup IS `unify-core` with `'subtype` relation against Hasse-neighborhood impls (§6.13). Per-candidate PUnify via SRE ctor-desc decomposition.
- **Hasse compute topology**: O(log N) structural index lookup, not N-scan.

**Inhabitant catalog lattice** (§6.2.1, Phase 9b)

- **Classification**: STRUCTURAL — classifier-type order over inhabitant entries.
- **Algebra**: same subtype poset as TypeFacet's `'subtype` relation — reuses the existing quantale structure. Entries are (term, classifier-type) pairs indexed by classifier.
- **Primary/Derived**: PRIMARY for γ hole-fill; conceptually DERIVED from the TypeFacet quantale structure (inhabitant catalog uses TypeFacet's subtype lattice for its Hasse).
- **Hasse**: subtype order over classifying types. Navigation for candidate matching.
- **Module Theory**: entries (type-env bindings + registered constructor signatures) tagged by classifier. ⊕_{classifier} InhabitantSet(classifier).
- **PUnify**: lookup IS `unify-core` with `'subtype` relation via SRE ctor-desc (§6.13).

**Lens observation**: impl coherence and inhabitant catalog are STRUCTURALLY IDENTICAL Hasse-registry instances — both are PUnify-with-`'subtype` lookups on Hasse-indexed entries. The §6.12 primitive abstracts this identity; 4C builds ONE primitive + TWO parameterizations (impl-pattern Hasse vs classifier-type Hasse). Compositional win.

**Hasse-registry ambient lattice L** (§6.12, generic)

- **Classification**: depends on instance — typically STRUCTURAL for the use cases in 4C (impl patterns, classifier types).
- **Algebra**: partial order at minimum. May be a full lattice. Per-instance SRE domain registration declares properties.
- **Primary/Derived**: PRIMARY from the registry's perspective.
- **Hasse**: by construction, the lattice's Hasse IS the Hasse used for navigation. Compute topology: O(log N) via Hasse height.
- **Module Theory**: ⊕_{node} EntryGroup(node) — direct sum via Hasse-node tagging (Realization B).
- **PUnify**: registry lookup IS PUnify (typically with `'subtype` relation for subsumption-based matching).

#### Speculation lattice

**Worldview Q_n** (§6.10, Phase 9, BSP-LE 1.5)

- **Classification**: VALUE (bitmask) — but with rich hypercube adjacency structure per [BSP-LE Track 2 Hypercube Addendum](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md).
- **Algebra**: Boolean, complemented, distributive, Heyting, frame. Q_n for n assumptions.
- **Primary/Derived**: **DERIVED** from decision cells (per BSP-LE Track 2 D.1 self-critique finding — decision cells are primary, worldview is the union of committed assumption bits). The derivation is reflected in the A/B commitment flow: worldview = reduce(OR, committed-bits).
- **Hasse**: hypercube Q_n. Each worldview is a vertex; edges = Hamming distance 1 (one assumption differs). Adjacency structure enables Gray-code traversal, bitmask subcube membership (O(1) nogood containment), hypercube all-reduce (log₂ diameter).
- **Module Theory**: bitmask tag-layers on shared worldview cell. Each assumption is a tag-layer. ⊕_{assumption} AssumptionLayer.
- **PUnify**: not directly — worldview is atomic from PUnify's view. PUnify applies to cell values TAGGED BY worldview (per-branch PUnify in Phase 10).
- **Hasse-derived algorithms** (from hypercube addendum §2): Gray-code branch exploration maximizes CHAMP reuse; bitmask subcube check for nogood containment; hypercube all-reduce for S(-1) barrier synchronization when parallel.

#### BSP stratum handler request lattices

**Ready-queue actions** (§6.7, L1 readiness)

- **Classification**: VALUE — set of action descriptors (data orientation, not state).
- **Algebra**: monotone set union (free join-semilattice).
- **Primary/Derived**: PRIMARY for S1 action dispatch.
- **Hasse**: flat — actions accumulate without subsumption.
- **Module Theory**: N/A (atomic descriptors; flat monotone accumulation).
- **PUnify**: N/A at the lattice level; applies within action execution.

**Retraction request set** (§6.7, S(-1))

- **Classification**: VALUE — set of retracted assumption-ids.
- **Algebra**: monotone set union; consumed at barrier (S(-1) processes and clears).
- **Primary/Derived**: PRIMARY for S(-1) cleanup triggers.
- **Hasse**: flat set order.
- **Module Theory**: same algebraic structure as worldview (assumption-id set); used as barrier trigger rather than worldview state.
- **PUnify**: N/A.

#### Tag-layer lattice (the Module Theory Realization B carrier)

**Tagged-cell-value layers** (§6.1, §6.10 — pervasive in 4C)

- **Classification**: STRUCTURAL — tag → value hashmap as a carrier.
- **Algebra**: per-tag merge (tag-specific lattice); cross-tag trigger (e.g., CLASSIFIER × INHABITANT residuation in §6.2).
- **Primary/Derived**: PRIMARY — this IS the Module Theory Realization B mechanism. 4C's consolidation from "separate cells with bridges" to "shared carrier with tag-layers" applies throughout.
- **Hasse**: per-tag Hasse lifts to the compound; cross-tag merges may introduce additional structure (e.g., residuation check).
- **Module Theory**: THE direct-sum-via-tagging structure. Applied to: `:type`/`:term` (§6.1), `:constraints` by trait (§6.5), worldview by assumption (§6.10), attribute-map by position (§4.2).
- **PUnify**: per-layer PUnify operations; cross-layer triggers residuation or structural coherence checks.

**Key lens insight**: the tagged-cell-value layer lattice is the **structural generalization** of 4C's Module Theory Resolution B applications. Every "shared-carrier + tags" situation in 4C is an instance of this lattice, with domain-specific tag schemes and per-tag merge functions.

---

### §6.12 Hasse-registry primitive (Phase 2b, D.2) — foundational infrastructure

Two places in the 4C design consume the same structural pattern:

- §6.5 / §6.11.4: parametric impl registry — Hasse-ordered by specificity; lookup by target type.
- §6.2.1: γ hole-fill inhabitant catalog — Hasse-ordered by classifying type; lookup by expected type.

Rather than implement the pattern twice (with drift risk between the two), D.2 extracts it as a first-class primitive. User observation (2026-04-17): *"virtually every track will be designing for its own Hasse diagram, so having this generally available is a boon."* This section specifies the primitive.

#### §6.12.1 What the primitive IS

**Refined 2026-04-19** (Phase 2b design dialogue): the primitive is a thin, emergent wrapper over existing infrastructure. **SRE domains provide the Hasse structure via their `'subtype` relation; PUnify (via `unify-core`) provides the subsumption check via ctor-desc structural walk. The primitive does NOT reinvent "how to compare structured values" — it DELEGATES to SRE + PUnify.**

```
struct hasse-registry-handle
  :cell-id        CellId        ;; on-network registry cell (entries storage)
  :l-domain-name  Symbol        ;; SRE-registered lattice (provides :subtype)
  :position-fn    (Entry → L)   ;; entry → position in L
  :subsume-fn     (L × L → Bool) ;; default = PUnify + L's :subtype; override for specialized lattices
```

**Cell value**: `(hasheq position → list-of-entries-at-that-position)`. Module Theory Realization B: position-keyed tag-layers on shared carrier. Merge = `merge-hasheq-union` (existing in `infra-cell.rkt`).

**No materialized Hasse edges.** The Hasse ORDER is expressed implicitly by the L domain's `'subtype` relation; PUnify walks the structure via SRE ctor-desc at lookup time. This matches the prior art pattern across 10+ files (`tagged-cell-value`, ATMS bitmask subcube membership, `filter-dependents-by-paths`): **position-keyed cell value + filter-based read**.

**Operations**:

- `register!(entry)` — monotone. Compute position via `position-fn`; single cell write with `(hasheq position (list entry))`. `merge-hasheq-union` handles aggregation.
- `lookup(query)` — filter-based. Read cell; filter positions by `subsume?(pos, query)`; extract Hasse-minimal antichain (positions with no more-specific siblings). Return entries at antichain positions.

**SRE + PUnify integration (default subsume-fn)**:

```racket
;; Default subsumption = PUnify via L's 'subtype relation.
;; This IS the Hasse navigation — structural comparison through
;; SRE ctor-desc decomposition. The exact invocation pattern uses
;; unify-core with the relation parameter set via L's merge-registry
;; (verified at implementation time).
(define (make-default-subsume-fn l-domain-name)
  (lambda (pos query)
    (unify-ok? (unify-core '() pos query l-domain-name 'subtype))))
```

**Specialized lattice override**: specific lattices with exploitable structure (Q_n hypercube via bitmask; linear orders via interval trees) can provide their own `subsume-fn` — e.g., `(lambda (pos query) (= (bitwise-and pos query) query))` for Q_n. The generic primitive provides the structural foundation; specific consumers specialize.

**Correctness discipline**: `'hasse-registry` is itself registered as an SRE domain (Phase 2 pattern). Property inference verifies the entry-accumulation behavior: commutative + associative + idempotent over `merge-hasseq-union` (D2 no delta expected). The Hasse ORDER lives in L's domain (already SRE-registered with its own property inference).

**Complexity — honest framing** (refined 2026-04-19): the primitive is O(N × subsume-cost) for lookup where N = number of positions. For balanced lattices with sparse subsumption (typical), `|subsumers|` is small and practical cost is low. For specialized lattices:
- **Q_n hypercube** (Boolean lattice, worldview space): O(1) via bitmask subcube check (prior art — hypercube research 2026-04-08)
- **Linear orders / sparse posets**: consumers add interval-tree indexing or similar if A/B benchmarks justify
- **Arbitrary posets via PUnify**: O(N × ctor-desc-walk-cost) — this IS the Hasse navigation, just unindexed

**Prior art alignment**: the hypercube addendum's bitmask subcube check is the EXAMPLE of a specialized subsume-fn for Q_n. Hasse-registry generalizes this pattern: every SRE-registered lattice gets Hasse-structured lookup for free via PUnify; specific lattices with algebraic structure (Boolean, metric, etc.) can exploit it further via override.

**Lookup as helper function, not propagator** (M3 clarification 2026-04-18): `lookup` is invoked synchronously from within the fire functions of consuming propagators (Phase 7 parametric resolution, Phase 9b γ hole-fill). It is NOT a standalone propagator that fires independently. The consuming propagator's `:reads` includes the registry cell (which updates rarely — only on new entry registration); the propagator's fire body calls `lookup` as a library operation. This avoids unnecessary propagator proliferation (no per-query propagator) and keeps the lookup's timing deterministic (executes when the consumer fires). The registry cell's on-network status is preserved — the cell itself is stored in the propagator network and read via `net-cell-read`; only the lookup computation is a synchronous helper.

#### §6.12.2 SRE / Module Theory / PUnify composition

The primitive composes the three lenses natively — which is why it's small:

- **SRE**: the Hasse graph IS a structural lattice. Entries are nodes; transitive-reduction edges are the partial-order structure. Registration = cell write; lookup = structural read via SRE ctor-desc on the Hasse graph's decomposition.
- **Module Theory**: entries at each Hasse node form an independent group. The registry = ⊕_{node} EntryGroup(node) — direct sum with Hasse-node-tagged layers on the shared carrier (Realization B by construction). No bridges between nodes; merges are per-node structurally independent.
- **PUnify**: lookup IS structural subsumption checking — "does `position-fn(entry)` subsume `query`?" = PUnify with variance direction, specifically `unify-core` ([unify.rkt:463](../../racket/prologos/unify.rkt)) with `'subtype` relation (registered in `type-merge-table` at unify.rkt:70-73). Per-candidate PUnify via `sre-structural-classify` ctor-desc decomposition. The primitive implements lookup by invoking PUnify against the Hasse neighborhood of the query, returning all PUnify-successful entries.

The three lenses compose structurally. The primitive is ~150-200 lines Racket because each lens contributes existing machinery (SRE domain, tagged direct-sum merge, PUnify). See §6.13 for the audit confirming PUnify coverage.

#### §6.12.3 4C instances

**Instance 1 — parametric impl registry (Phase 7 / A1)**:
- Lattice `L` = impl-pattern lattice, ordered by specificity. Most-specific-bottom, least-specific-top.
- Entries = impl bodies (their types + dict constructors).
- `position-fn` = impl's pattern type (e.g., `Seqable (List E)` sits at the Hasse node corresponding to "Lists").
- `lookup(target-type)` = PUnify each Hasse-neighbor pattern against `target-type`; return successful matches. Coherence property (verified at impl registration): no two entries at the same Hasse node → zero critical pairs → unambiguous lookup.

**Instance 2 — γ hole-fill inhabitant catalog (Phase 9b)**:
- Lattice `L` = type lattice (classifier types), ordered by subtype.
- Entries = (term, classifier) pairs — from type-env bindings AND registered constructor signatures.
- `position-fn` = entry's classifying type.
- `lookup(expected-type)` = PUnify each Hasse-neighbor entry's classifier against `expected-type`; return candidates. Multi-candidate → ATMS branching (Phase 9 cell-based TMS); single-candidate → write `:term` directly.

Both instances are concise because the primitive does the structural work; each instance only specifies `position-fn` and the post-lookup action. Compare: without the primitive, each instance implements its own ~100-150 lines of Hasse construction + lookup. Net: the primitive pays for itself within 4C and leaves reusable infrastructure.

#### §6.12.4 Future consumers

- **General residual solver** (future BSP-LE Track 6, §6.11.7): lifts the BSP-LE low-level search to arbitrary lattices. The Hasse-registry primitive is the fact-indexing substrate it consumes.
- **PPN Track 5 (type-directed disambiguation)**: parse forest lattice Hasse-indexed; type context = query; lookup = type-compatible parses.
- **FL-Narrowing refinement**: rewrite-rule registry Hasse-indexed by LHS structure; target = query; lookup = applicable rules.
- **PM future work (module/trait registries)**: trait coherence checking IS Hasse registration + lookup.
- **SRE Track 6 (reduction on-network)**: rewrite rules Hasse-indexed.

User observation makes this sharper: *virtually every track needs a Hasse diagram over its domain's structure.* The primitive generalizes once; every subsequent track inherits.

#### §6.12.5 NTT connection

The `hasse-registry` primitive is an SRE-registered lattice with a registration/query interface. Under NTT syntax ([§3.1 NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md)), this is a `:lattice :structural` declaration with the Hasse structure as its `:lattice` property. When NTT design resumes, `hasse-registry` lifts to an NTT form — probably something like:

```
registry ParametricImpls
  :lattice ImplPatternLattice
  :position impl-pattern-type
```

4C-level implementation is Racket infrastructure; future NTT makes it declarative syntax. No migration cost — the primitive IS the declarative form; NTT just surfaces it.

#### §6.12.6 Concrete instantiations L_impl and L_inhabitant (S3 external critique 2026-04-18)

The primitive is parameterized by lattice L. 4C's two instantiations:

**`L_impl` (Phase 7 parametric trait resolution)** — **impl specificity lattice**.
- **Bot**: most-general parametric impl (e.g., `impl C A` quantifying universally over type variable A).
- **Top**: contradiction (incoherent impls — two impls at the same specificity claiming the same target pattern).
- **Meet**: shared common generalization of two impl patterns — the most-specific impl pattern that subsumes both.
- **Partial order**: `impl1 ≤ impl2` iff `impl1`'s pattern subsumes `impl2`'s (`impl1` is more general).
- **Position-fn** (for Hasse-registry API): the impl's type-pattern.
- **Lookup**: from target type T, traverse Hasse from most-specific candidates upward until a match is found via PUnify with `'subtype` relation.

**`L_inhabitant` (Phase 9b γ hole-fill inhabitant catalog)** — **constructor subsumption lattice**.
- **Bot**: no applicable constructors (the type has no inhabitants in the catalog).
- **Top**: contradiction (conflicting catalog entries).
- **Meet**: type-driven intersection — constructors whose signatures match both input type constraints.
- **Partial order**: `c1 ≤ c2` iff `c1`'s signature is a specialization of `c2`'s (more-specific constructor is below more-general).
- **Position-fn**: the constructor's classifying type.
- **Lookup**: from the hole's classifier (CLASSIFIER-tagged entry), Hasse-navigate to constructors matching the type; candidates returned as INHABITANT candidates for γ to propagate.

Both instantiations share the Hasse-registry API + structural-navigation mechanism. The compositional win: one ~150-200 line primitive supports both; each instantiation is ~30-50 lines (`position-fn` + post-lookup action).

### §6.13 PUnify infrastructure audit (from self-critique M2+R4)

Audit of [`unify.rkt`](../../racket/prologos/unify.rkt) (1028 lines) conducted 2026-04-17 to verify D.2's "PUnify IS the match operation" claims across §6.1, §6.2, §6.4, §6.5, §6.6, §6.10, §6.12. **Verdict: PUnify's reach already covers all D.2 claims via existing infrastructure.** Extension work is minimal composition wiring, not new algorithm development.

#### §6.13.1 Capability map — D.2 claims to existing unify.rkt infrastructure

| D.2 claim (where used) | Existing unify.rkt mechanism |
|---|---|
| **Structural unification via ctor-desc** (§6.4 aspect, §6.5 parametric, §6.6 Option C) | `sre-structural-classify` (line 127) — dispatches through `ctor-desc-tag` + `ctor-desc-extract-fn`. Same ctor-desc that decomposes SRE lattices decomposes expressions for unification. |
| **Union operand unification** (§6.10 ATMS per-branch, §6.1 CLASSIFIER ⊕) | `unify-union-components` (line 777). Flattens, sorts, dedupes, pairs components; PUnifies pairwise. Imported from `union-types.rkt` (SRE Track 2H Phase 1). |
| **Tensor operation** (§6.1 quantale, §6.4 app-type) | `type-tensor-core` registered in `type-sre-domain` (line 102-106) as binary operation with declared properties `(distributes-over-join associative has-identity)`. |
| **Subsumption / variance** (§6.2 CLASSIFIER × INHABITANT residuation, §6.2.1 γ hole-fill) | `subtype-lattice-merge` registered for `'subtype` and `'subtype-reverse` relations (line 72-73). **Variance is already first-class via the relation name** — `'equality` for strict unification, `'subtype` for variance. `subtype-predicate.rkt` is the supporting module. |
| **Meta handling** (§6.5 impl-level fresh metas, §6.2.1 γ candidates) | `expr-meta?` as meta-recognizer; `current-structural-meta-lookup` as meta-resolver (line 87-89). Cell-based resolution. |
| **Flex-app / Miller's pattern** (§6.5 parametric meta unification) | `decompose-meta-app`, `pattern-check`, `solve-flex-app` (lines 795-830). Applied metas handled structurally. |
| **Level unification** (§6.1 Type(n) levels) | `unify-level` (line 935). Separate unification domain. |
| **Multiplicity unification** (§6.4 Pi mults) | `unify-mult` (line 968). Separate unification domain. |

#### §6.13.2 The `type-sre-domain` declarative structure (already in place)

```racket
;; From unify.rkt:78-106 — already registered
(define type-sre-domain
  (make-sre-domain
    #:name 'type
    #:merge-registry type-merge-registry    ;; 'equality | 'subtype | 'subtype-reverse
    #:meta-recognizer expr-meta?
    #:meta-resolver ...                      ;; cell-based via current-structural-meta-lookup
    #:declared-properties                    ;; per-relation algebraic properties
      (hasheq 'equality  (hasheq ...)
              'subtype   (hasheq 'commutative-join prop-confirmed
                                 'associative-join prop-confirmed
                                 'idempotent-join  prop-confirmed
                                 'has-meet         prop-confirmed
                                 'distributive     prop-confirmed
                                 'has-pseudo-complement prop-confirmed))
    #:operations
      (hasheq 'tensor (hasheq 'fn type-tensor-core
                              'properties '(distributes-over-join associative has-identity)))))
```

This IS the Tier 1 lattice declaration we'd want for the A9 registration. More complete than D.2's original scoping assumed.

#### §6.13.3 What's actually new in 4C (vs existing infrastructure)

A short list:

1. **Tag-dispatched merge on shared TypeFacet carrier** (§6.1, D.2 restructure). The CLASSIFIER/INHABITANT tag distinction is a 4C addition. Merge dispatches on tag:
   - CLASSIFIER × CLASSIFIER → `unify-core` with `'equality` relation (exists)
   - INHABITANT × INHABITANT → α-equivalence merge (may need new case; trivial if not)
   - CLASSIFIER × INHABITANT → `unify-core` with `'subtype` relation (exists)

   **Composition work, ~50-100 lines.** No new algorithm. The merge function dispatches by tag; each tag-case calls existing unify-core with the appropriate relation.

2. **Explicit `:preserves [Residual]` declaration** (§6.1 NTT model). The quantale residual concept isn't named as a distinct operation in current `type-sre-domain`. But `subtype-lattice-merge` IS essentially a residual computation (narrowing toward consistent subtype). **Naming/documentation only**, not implementation. Add `:preserves [Residual]` to the domain declaration.

3. **Hasse-registry integration** (§6.12). Lookup invokes `unify-core` with `'subtype` relation. **New call site for existing API.** ~30-50 lines within the primitive.

4. **γ hole-fill per-candidate PUnify** (§6.2.1, Phase 9b). Invokes existing PUnify against inhabitant catalog entries. **New use of existing infrastructure.** ~30 lines in the γ propagator.

5. **Property inference for tag-dispatched merge laws** (Phase 2, A9). Runs on the new merge function to verify commutativity/associativity/idempotence. **Infrastructure exists** (Track 2G property inference); needs to run against the new composition.

#### §6.13.4 Net-new PUnify work total

~150-200 lines across phases, all composition wiring or naming refinement. **No new PUnify algorithm.** The claim "PUnify IS the match operation" was accurate for existing infrastructure; D.2's usage leverages capabilities already in unify.rkt.

#### §6.13.5 Implications

- **M2 + R4 closed.** PUnify reach audit confirms D.2 claims stand as-is.
- **Risk level low** for phases that claim PUnify use (§6.1, §6.4, §6.5, §6.6, §6.10, §6.12). No scope expansion needed.
- **Phase 3 (A5) scope**: the tag-dispatched merge implementation is ~50-100 lines of wiring; straightforward.
- **Phase 2 (A9) scope**: add `:preserves [Residual]` declaration and run property inference on the new merge — mechanical.
- **`'subtype` relation** is the key reusable mechanism: existing variance support via relation name means "PUnify with variance" needs no extension.

---

### §6.14 Phase 1e — Correctness Refactors (design 2026-04-20)

Phase 1e was un-folded from Phase 1d (D2 resolution 2026-04-19, no DEFERRED dodging) as a dedicated sub-phase for correctness refactors that surfaced during Phase 1d execution. This section captures the design decisions from the 2026-04-20 mini-design dialogue.

#### §6.14.1 Scope and sub-phase partition

Mini-audit (2026-04-20) surfaced three distinct concerns under the 1e umbrella. Each gets its own sub-phase for commit discipline:

- **1e-α**: η split of `merge-hasheq-union`. Retire the ambiguous single function; replace with two named variants distinguishing identity-or-error from explicit last-write-wins. Audit ~30 call sites; substitute per intent.
- **1e-β-i**: meta-solve identity-or-error fix. [elaborator-network.rkt:966, 982](../../racket/prologos/elaborator-network.rkt) currently use `merge-last-write-wins` at cells that should be identity-or-error (monotonic `'unsolved` → solution); current mechanics silently absorb bugs where a meta is solved twice with different values.
- **1e-β-ii**: per-site classification of remaining replace-cell sites (global-env × 3, namespace × 1, global-constraints × 1, atms.rkt:761 tagged-scope, atms.rkt table-* hoist + register).
- **1e-β-iii**: timestamped-cell primitive. Used by 1e-β-ii sites classified as "timestamp-ordered lattice" path.
- **1e-close**: baseline, `--strict` green, tracker ✅.

#### §6.14.2 1e-α — η split

Current state: `merge-hasheq-union` registered under `'monotone-registry` with D1-δ framing (non-commutative by mechanics; commutative by intent at most sites). ~30 production sites, audit (2026-04-20) classified:
- 24 module-load-time registries in [macros.rkt:579-631](../../racket/prologos/macros.rkt)
- 1 module registry at [namespace.rkt:753](../../racket/prologos/namespace.rkt)
- 7 per-elab meta stores in [metavar-store.rkt:2563-2592](../../racket/prologos/metavar-store.rkt)

**Split** (landed 2026-04-20, commit `876f3bf3`):
- `merge-hasheq-identity` — same-key collision: `(equal? old-v new-v)` → keep; else → `'hasheq-identity-contradiction` sentinel. Commutative + associative + idempotent by construction. Registered as `'hasheq-identity` domain with `#:contradicts?` recognizing the sentinel.
- `merge-hasheq-replace` — explicit last-write-wins (new wins on collision). Registered as `'hasheq-replace` domain with honest D2 delta (non-commutative; named so intent is explicit).

**Retired `merge-hasheq-union`** (no alias) — every call site chose explicitly during migration.

**Scope-reduction note (2026-04-20 execution)**: initial migration attempted to route most macros.rkt + namespace.rkt sites to `merge-hasheq-identity` per the "identity-or-error intent" classification. Surfaced 22 test failures — investigation revealed these are TEST-ISOLATION issues from the shared-fixture pattern: multiple tests legitimately write successive definitions to the same registry cell under a shared persistent network; new-wins is CORRECT behavior across test sequences, not a bug.

Final migration (preserves existing semantics; the η split itself is the main 1e-α win):
- 23 macros.rkt sites → `merge-hasheq-replace`
- 1 namespace.rkt site → `merge-hasheq-replace`
- 7 metavar-store.rkt sites → `merge-hasheq-replace`
- 1 test-readiness-propagator.rkt site → `merge-hasheq-identity`

**Per-site identity-vs-replace classification deferred** to PM Track 12 delivery. See [PM series master Track 12](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) — the submodule-scope primitive PM Track 12 introduces is the structural answer to "identity *within what scope*?" Today's flat shared-persistent network conflates module-load-time scope with session/test scope, so "identity-or-error" silently mis-fires under the shared-fixture test pattern. When PM Track 12 scopes registry cells per module-submodule:
- Prelude's definitions live in the prelude submodule's scope → identity-or-error correct
- Each test's definitions live in its own submodule's scope → no cross-test pollution
- Module reload = retract-and-reassert at submodule scope (S(-1) pattern extension)

The 32 migration-candidate sites (23 macros.rkt + 1 namespace.rkt + 7 metavar-store.rkt — all on `merge-hasheq-replace` today) are pre-identified in DEFERRED.md § "PM Track 12 design input from PPN 4C Phase 1e-α." Substitution to `merge-hasheq-identity` becomes mechanical once submodule scope lands.

**The submodule-as-sharing-primitive framing generalizes** beyond tests: LSP edits, REPL sessions, multi-module compilation all benefit from the same scope hierarchy. The SCOPE HIERARCHY is itself a lattice (submodules refine parents; scope lookup walks the lattice) — aligns with Hyperlattice Conjecture framing.

**Principle honored**: η split addresses the ambiguity of one overloaded name. `merge-hasheq-identity` is AVAILABLE as a named tool for future per-site refactoring. The decision to APPLY identity at each call site is a separate per-site classification, correctly not bundled with the ambiguity retirement.

#### §6.14.3 1e-β-i — meta-solve identity-or-error

Two sites at [elaborator-network.rkt:966, 982](../../racket/prologos/elaborator-network.rkt) allocate TMS cells with `'unsolved` initial and `merge-last-write-wins` merge. Semantically this should be identity-or-error:
- `'unsolved` → `value`: monotone solve (fine)
- `value1` → `value2` (same cell): if `value1 = value2` identity-safe; if different, **this is a double-solve-with-inconsistency bug**, currently absorbed silently.

**Refactor**: register `'meta-solve` domain with identity-or-error merge. Treat current code as potentially bug-hiding; any collision that surfaces post-refactor is a real finding to investigate.

#### §6.14.4 1e-β-ii — replace-cell per-site classification

Remaining sites classified per the three refactor paths from the un-fold resolution:

| Site | Classification | Path |
|---|---|---|
| [global-env.rkt:121, 354, 358](../../racket/prologos/global-env.rkt) | Shadowing semantics (later def wins) | **(1) timestamp-ordered** |
| [namespace.rkt:757](../../racket/prologos/namespace.rkt) | Scope-context change | **(1) timestamp-ordered** |
| [global-constraints.rkt:104](../../racket/prologos/global-constraints.rkt) | Narrow-var-constraints (pending site-read) | TBD at implementation (likely (1)) |
| [atms.rkt:761](../../racket/prologos/atms.rkt) | Tagged-scoped identity (within-branch same-value write) | **(3) accept + document as narrower-correct**; tagged-cell-value mechanism handles worldview distinction |
| [atms.rkt:496](../../racket/prologos/atms.rkt) `table-registry-merge` | Identity-or-error (same relation → same cell) | **(2) identity-or-error** via hoist + register under `'hasheq-identity` |
| [atms.rkt:611](../../racket/prologos/atms.rkt) `table-answer-merge` | Set-union with dedup | Not strictly replace — hoist + register under `'dedup-set` or reuse `merge-set-union`-equivalent; NOT timestamp-ordered |

4-5 timestamp-ordered consumers justify building the primitive per user direction 2026-04-20.

#### §6.14.5 1e-β-iii — timestamped-cell primitive (E1 Lamport, on-network)

**Design decision summary (user dialogue 2026-04-20)**:
- Reuse existing `counter-merge` / `'counter` domain (prior art at [decision-cell.rkt:612](../../racket/prologos/decision-cell.rkt), live at [atms.rkt:489](../../racket/prologos/atms.rkt) for assumption-id generation)
- **Dedicated clock cell** on main network (Option Y) — NOT shared with ATMS counter (separate lifecycles; clock must be available outside ATMS context)
- **E1 Lamport shape** — `(counter, pid)` pair timestamps, total order via lex compare. `current-process-id` parameter default 0 today. Future parallel workers parameterize per-worker without shape migration.

**Primitive components**:

```racket
;; clock.rkt (new module)
(define current-process-id (make-parameter 0))  ;; scaffolding; PM Track 12
(struct timestamp (counter pid) #:transparent)
(define (timestamp<? t1 t2)
  (or (< (timestamp-counter t1) (timestamp-counter t2))
      (and (= (timestamp-counter t1) (timestamp-counter t2))
           (< (timestamp-pid t1) (timestamp-pid t2)))))
(struct timestamped-value (ts payload) #:transparent)
(define (merge-by-timestamp-max old new) ...)  ;; newer wins; equal-ts equal-payload identity; equal-ts diff-payload contradiction
(define (net-new-timestamped-cell net clock-cid init-payload) ...)
(define (net-write-timestamped net clock-cid cid value) ...)
```

**SRE registration**:
- `'timestamped-cell` domain with `merge-by-timestamp-max`
- `#:contradicts?` recognizes `'timestamp-contradiction` sentinel (path A; Phase 11b upgrades to path C per §6.1.1 scope addition 2026-04-20)

**Concurrency discipline** (inherited from ATMS prior art at decision-cell.rkt:609-610):
> "Written ONLY at topology stratum (sequential) to prevent concurrent ID collision."

Timestamp writes happen at topology stratum OR in clearly-sequential elaboration context. Multi-propagator same-BSP-round writes to same timestamped cell would race on the counter; topology-stratum discipline makes this structurally impossible. Documented as a load-bearing invariant for timestamped-cell users.

**Rejected alternatives** (from design dialogue):
- **Option D (scalar timestamps)**: simplest today but forces every cell-shape migration when parallel workers arrive. ~10 LoC saved today; unbounded migration cost later.
- **Option E2 (Vector clocks)**: partial order with concurrent-write detection. Overkill — no use case for "incomparable timestamps" in single-BSP Prologos today. If distributed execution surfaces, E1 extends to E2 by replacing pid with pid-set.
- **Option X (reuse ATMS counter-cid)**: couples clock availability to ATMS context lifecycle; non-ATMS contexts need timestamps (e.g., global-env shadowing). Cleaner to keep independent.

**Execution split (2026-04-20)**: Phase 1e-β-iii partitioned into two commits for clean checkpointing.

- **1e-β-iii-a ✅** (commit `4205b0ad`): primitive built + tested + SRE-registered. `clock.rkt` with `timestamp` struct, `timestamp<?`/`timestamp=?` compares, `timestamped-value` struct, `merge-by-timestamp-max`, `fresh-timestamp`, `net-allocate-clock-cell`, `net-new-timestamped-cell`, `net-write-timestamped`, `net-read-timestamped`, `net-read-timestamped-payload`. `current-process-id` + `current-clock-cell-id` scaffolding parameters in DEFERRED.md. 17/17 tests GREEN.

- **1e-β-iii-b deferred to PM Track 12 coordination**: investigation revealed the 5 consumer sites (global-env.rkt × 3, namespace.rkt × 1, global-constraints.rkt × 1) are **snapshot-cells of Racket parameters** — dual-store pattern where the Racket parameter holds the LIVE state and the cell is initialized as a one-time snapshot at network-init time. Migrating the cells to timestamped-semantics today gives decorative wrapping; the timestamp becomes load-bearing only AFTER PM Track 12 retires the parameters and makes cells primary. Same architectural act that unlocks 1e-α's identity-or-error migration also unlocks 1e-β-iii's timestamp-ordering migration. See [PM series master § Track 12](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) "Additional design input from PPN 4C Phase 1e-β-iii (2026-04-20)" + DEFERRED.md § "PM Track 12 design input from PPN 4C Phase 1e-α" for the 5 pre-identified migration targets.

The primitive is scope-agnostic (consumers pass `clock-cid` as argument); whether PM 12 adopts a global clock or per-submodule clocks is a PM 12 design choice that clock.rkt already accommodates without redesign.

#### §6.14.6 Phase 11b upgrade path (Q4-C capture)

Per Q4 resolution 2026-04-20 and §6.1.1 addition: Phase 1e identity-or-error sites use path (A) sentinel + `#:contradicts?` in the short term. Phase 11b upgrades to path (C) provenance-rich contradiction descriptors (conflicting values + srclocs + producer propagator IDs). Non-breaking: contradict-record's `contradicts?` predicate still returns true; the sentinel just carries more data.

#### §6.14.7 Drift risks (VAG 5d checklist for Phase 1e)

Named 2026-04-20 from mini-design audit:

1. Classify-then-declare-done without refactoring — Phase 1e ships correctness fixes, not just classifications
2. Uniform timestamp-everywhere — path (1) isn't universally right; per-site classification preserved
3. Silent semantic change on η split — EXPECTED to surface real bugs; treat as findings
4. Timestamped-cell scope creep into Hasse-registry territory — timestamps are linear order, Hasse is partial order; keep distinct
5. `racket-merge` / `viability-merge` sneaking into 1e — fundamentally parameterized closures; OUT of 1e scope
6. atms.rkt:761 needs narrower-correct documentation, NOT rewrite to identity-or-error
7. Timestamp primitive over-engineering — E1 Lamport is justified by 3-5 consumers + future-proof shape; not building Vector clocks (E2) or wall-clock variants
8. current-process-id as permanent parameter — documented scaffolding with PM Track 12 retirement path

---

### §6.15 Phase 3 — `:type`/`:term` tag-layer split (design 2026-04-20)

Phase 3 delivers A5 (§6.1, §6.2): tag-layer dispatch on the shared TypeFacet carrier, replacing D.1's separate-facets-with-bridge approach. This subsection captures the 2026-04-20 mini-design dialogue resolutions (S1, P4) + sub-phase partition + PU audit + Phase 9 coherence note.

#### §6.15.1 S1 resolution — TermFacet IS the SRE 2H quantale (reading i)

Two readings under consideration:
- **(i)** TermFacet is the Track 2H quantale itself; `:type` and `:term` are role-tags over the ONE carrier lattice; residuation is the tag-cross-product operation on the one quantale.
- **(ii)** TermFacet is a distinct α-equivalence-respecting lattice bridged to TypeFacet via `type-of-expr`.

**Adopted: reading (i) with tag-dispatch nuance** (2026-04-20). Rationale:
- **MLTT foundation grounds this**: there's one universe hierarchy; "type" and "term" are layers at adjacent universe levels, not fundamentally different algebraic spaces
- **(ii) reduces to (i) with extra framing cost**: the "distinct lattice" framing in (ii) is really "distinct merge relation within the same carrier" — which (i) captures via tag-dispatch
- **SRE 2H quantale at play**: re-uses the full quantale machinery (⊕ union-join, ⊗ tensor, `'equality` and `'subtype` relations)

**Tag-dispatched merge** composes existing `unify.rkt` relations on the same carrier:

```
merge(X-CLASSIFIER, Y-CLASSIFIER) = unify-core X Y 'equality
  (standard unification on the quantale)

merge(X-INHABITANT, Y-INHABITANT) = α-equivalence strict merge
  (identity up to α; mismatch → carrier top)

merge(X-CLASSIFIER, Y-INHABITANT) = unify-core X (type-of-expr Y) 'subtype
  (residuation: does inhabitant inhabit classifier?)
```

SRE lens answers:
- **Q1 Classification**: STRUCTURAL (carrier holds tag-layered compound) + the per-tag merges operate on the underlying quantale
- **Q2 Algebraic properties**: Quantale (⊕ join, ⊗ tensor, left/right residuals). Per-tag merges inherit from the SRE 2H quantale; cross-tag merge is the residuation computation.
- **Q3 Bridges**: no new bridge. The `TermInhabitsType` bridge from D.1 is retired; residuation is internal to the quantale (subtype relation dispatched via tag).
- **Q4 Composition**: cross-facet bridges (TypeToConstraints, ContextToType, UsageToType, TypeToWarnings) operate on the CLASSIFIER layer; INHABITANT layer is mostly internal to elaboration.
- **Q5 Primary/Derived**: PRIMARY — this IS the classifying-and-inhabiting state.
- **Q6 Hasse diagram**: inherited from SRE 2H quantale's Hasse; tag-layer distinction adds a trivial factor-2 dimension (each position has 2 possible tag-populations).

#### §6.15.2 P4 resolution — merge emits stratum request (path b)

Two paths for cross-tag residuation check side effects:
- **(a)** merge may write to cells *other than* the one being merged (structurally enforced via Axis 8 widening)
- **(b)** merge emits a topology/stratum request processed between rounds

**Adopted: (b) stratum request + merge stays pure** (2026-04-20). Rationale:
- **Merge purity is load-bearing**: BSP scheduling, speculation-safety, worldview-filtered reads all assume merge is `(v × v → v)` pure
- **Correct-by-Construction**: pure merge's correctness argument is straightforward; (a) would require per-merge reentrancy reasoning
- **Pattern consistency**: S1 NAF handler (relations.rkt) and topology stratum (PAR Track 1) already use stratum-request pattern — matches established precedent
- **Latency acceptable**: one-BSP-round delay for cross-tag writes is bounded; not a hot-path concern

**Phase 3 + Phase 9 joint mini-design item (see §6.15.6)**: the stratum request carries the worldview assumption-id under which it was emitted. Processing under the right worldview is the Phase 9-era concern.

#### §6.15.3 Sub-phase partition

Adopted partition (2026-04-20 dialogue):

- **3a + 3b atomic** (facet infrastructure + tag-dispatched merge):
  - Register/extend the carrier domain with tag-layer awareness
  - Implement `merge-type-classify-inhabit` with tag-dispatch + invoke `unify-core` per case
  - Add cross-tag stratum-request helper (mechanism-only; worldview tagging refined at Phase 9 joint mini-design)
  - Register as SRE domain with full property declarations
- **3c** — Migration of typing-propagators.rkt:
  - Type-variable metas become CLASSIFIER-tagged entries (e.g., `?A : Type(0)` writes `(CLASSIFIER (expr-Type 0))` at meta's position)
  - Value-position metas become INHABITANT-tagged entries
  - `that-read pos :type` reads CLASSIFIER layer; `that-read pos :term` reads INHABITANT layer (user surface preserved)
- **3d** — Parity tests for `type-meta-split` divergence class per §9.1. Also: A/B bench for lazy-vs-eager residuation check (§6.2 verification plan). Decision-locks lazy vs eager per data.
- **3e** — Phase 1f enforcement: classify carrier domain as `'structural` (per §6.15.5 below). Any newly-uncovered `:component-paths` gaps treated as Phase 3 findings.
- **3V** — Vision Alignment Gate for Phase 3.

Rationale for atomic 3a+3b: the facet infrastructure and the tag-dispatched merge are too tightly coupled to ship separately. The merge function IS the facet's semantics.

#### §6.15.4 Property inference budget + R5 contingency

Property inference at 3b close runs on `merge-type-classify-inhabit`. Expected verifications:
- **Commutativity** per-tag-case (symmetric merges)
- **Associativity across tag combinations** — the NON-TRIVIAL one. Verify `merge(C, merge(I, C)) = merge(merge(C, I), C)` among all 9 tag triples.
- **Idempotence** per-tag
- **Residuation laws** (Track 2H quantale): `A ⊗ (A \ B) ⊑ B`; `(B / A) ⊗ A ⊑ B`; distribution over ⊓
- **Cross-tag transitivity**: residuation under cascading tag writes

Expected bugs: 0-1 (Track 3 §12 + SRE 2G precedent predicts ≥1 per lattice; tag-dispatch may be more or less robust). R5 contingency: K=2 absorbed; K+1 opens Phase 3c repair sub-phase.

Any delta between aspirational and inference-result is worth a design discussion — it may reveal the tag-dispatch needs refinement (not a bug to fix in isolation).

#### §6.15.5 Phase 1f enforcement timing

At Phase 3 start, the carrier domain stays `'unclassified` (no new enforcement firing). At **3e**, classify as `'structural` and observe any existing propagators that need `:component-paths`. Each gap is either:
- Missing declaration → add it (was a latent bug anyway; Phase 1f catches it)
- Genuinely whole-cell-reading propagator → that's rare for structural cells; if it exists, it's a design question (should this propagator be two propagators with different component-paths?)

This matches Phase 1f's progressive rollout pattern — classification reveals latent enforcement violations as real findings.

#### §6.15.6 Phase 9 coherence (joint mini-design item carried)

Per D.3 §6.2 analysis, Phase 3's tag-dispatched merge is **mostly orthogonal** to Phase 9's cell-based TMS. Two independent tag-dimensions on each cell entry:
- Worldview assumption-id (Phase 9 `tagged-cell-value`)
- CLASSIFIER/INHABITANT role (Phase 3 tag-dispatch)

Reads filter by worldview first; tag-dispatched merge fires on within-branch entries. Cross-branch contradictions detected only at S2 commit merge.

**ONE explicit joint design item**: P4(b)'s stratum request carries worldview assumption-id under which the emitting merge fired. The stratum handler processes under that worldview; writes to destination are worldview-tagged; S(-1) retraction narrows if the assumption is retracted.

Pattern precedent: S1 NAF handler in relations.rkt already has exactly this shape. Phase 9 mini-design (not Phase 3) formalizes: stratum-request struct includes assumption-id field; stratum handler binds worldview during request processing.

Phase 3 ships the MECHANISM of stratum-request emission without worldview-specificity (unified API); Phase 9 refines with worldview-tagging overlay. No redesign of Phase 3's interfaces expected.

**Hypercube / Hasse-diagram considerations** noted for Phase 9 mini-design: the worldview lattice IS Q_n hypercube per BSP-LE hypercube addendum; Phase 3's per-branch merge fires map onto hypercube vertices; Gray-code traversal + bitmask subcube pruning applicable. Out of scope for Phase 3 design.

#### §6.15.7 PU audit finding (cell-cost check 2026-04-20)

Phase 3 is PU-aligned: the attribute-map is already ONE compound cell with component-indexed access (position × facet). Phase 3 adds tag-layers to the `:type` facet's VALUE SHAPE, not new cells.

**Broader track-level question surfaced**: per-meta TMS cells (elaborator-network.rkt `elab-fresh-type-cell`, etc.) allocate N cells for N metas. Potential PU consolidation target: ONE compound meta-cell holding `hasheq meta-id → meta-value`, component-indexed by meta-id. This is NOT Phase 3 scope — it's a Phase 4 mini-design question (when CHAMP retirement forces the meta-cell authority decision).

Captured in Phase 4 Progress Tracker row (§2) as a mini-design item.

#### §6.15.8 Phase 3c sub-design (2026-04-20)

Dialogue refined Phase 3c's shape.

**Q1 migration strategy — (C) hybrid reshape with shim**: the existing `:type` facet's VALUE SHAPE changes from raw type-value → `classify-inhabit-value`. `(that-read ... :type)` transparently returns the CLASSIFIER layer (auto-unwrap); `(that-read ... :term)` returns the INHABITANT layer. `:term` is a MAGIC KEYWORD alias routed to the same facet's INHABITANT layer — 5 facets preserved per §4.2. Writers explicitly choose their tag via the surface keyword. Existing reader callers continue working unchanged.

**Q2 residuation check — PUnify + SRE + quantale MEET (lens-refined)**:

The cross-tag residuation check is a **quantale MEET operation** (greatest lower bound) on the Track 2H TypeFacet carrier. Under the quantale structure, MEET is derivable from ⊗ + ⊸ (residual). The check IS the quantale residual computation, grounded algebraically.

The propagator's fire function reduces to ~10-15 LoC via **PUnify reuse**:
- `unify-core classifier (type-of-expr inhabitant) 'subtype`
- `sre-structural-classify` → ctor-desc decomposition → structural walk (existing code)
- Three outcomes fall out of PUnify naturally:
  - Success no-narrowing → compatible (no-op)
  - Success with narrowing → the refined type IS the PUnify result; emit stratum request to narrow classifier layer (per P4(b))
  - Failure (contradiction) → write `'classify-inhabit-contradiction` sentinel to cell

Under **Module Theory**, the narrowing writes are NOT arbitrary cross-cell mutations — they're **module endomorphism** actions (quantale MEET result propagated to one side). The stratum request carries an algebraically-principled write.

**Q3 migration order — reader-first**: reshape `:type` facet's value to `classify-inhabit-value`; add shims; existing `(that-read ... :type)` continues returning the classifier layer (same value as before under CLASSIFIER-only init). Writer migration is per-rule; each writer explicitly picks CLASSIFIER or INHABITANT.

**Q4 `:term` is magic keyword** — attribute-map's dispatch recognizes `:term` and routes to INHABITANT layer of the `:type` facet. No new facet in the AttributeRecord struct; no schema migration.

**Q5 α-equivalence proxy**: ship 3c with `equal?` as α-equiv proxy. Refinement to ctor-desc-based α-walk deferred to follow-up — gain is **correctness-by-construction** (no false-positive contradictions on α-variants) not performance. Refine when property inference or real-world usage surfaces a false-positive. Same scope-reduction pattern as Phase 1e-α.

**Q6 sub-phase partition**:

- **3c-i** (~30-50 LoC): reshape `:type` facet value + reader-first shim. `:type` facet initializes with `(classify-inhabit-value 'bot 'bot)`. `(that-read ... :type)` returns classifier layer (auto-unwrap); `(that-read ... :term)` returns inhabitant. Writes via `(that-write ... :type val)` go to CLASSIFIER; `(that-write ... :term val)` go to INHABITANT. The dispatch lives in typing-propagators.rkt's that-read / that-write implementations.

- **3c-ii** (~50-100 LoC): migrate typing-propagators.rkt's writes to use the correct tag. Typing rules for literals/constants → INHABITANT. Type-variable meta classifier writes → CLASSIFIER. Per-rule changes; verify per-rule via tests.

- **3c-iii** (~30-50 LoC): cross-tag residuation propagator. Watches `:type` facet at each position with `#:component-paths`. Fires at threshold (both layers populated). Fire function invokes PUnify via unify-core with 'subtype; dispatches on outcome. On narrowing: emits stratum request carrying the narrowed classifier value. Stratum handler (also in typing-propagators.rkt or a dedicated file) processes the request between BSP rounds, writing the narrowed value back.

- **3c-iv (deferred)**: α-equivalence refinement via ctor-desc.

- **3c-close**: tests for each sub-phase + 3c tracker update.

**Estimated 3c total**: ~120-200 LoC across 3 commits + tests.

**Design payoff from the lens**: Q2's SRE+PUnify+Module-Theory framing reduced residuation propagator LoC from initial ~60-100 estimate to ~30-50, because:
- No new unification algorithm needed (reuses unify-core + 'subtype)
- No new ctor-desc logic needed (reuses SRE decomposition)
- The "narrowing write" is a clean module action (stratum-request carrier)

#### §6.15.9 Drift risks (VAG 5d checklist for Phase 3c)

Named 2026-04-20 from 3c sub-design:

1. **Value-shape cascade**: reshaping `:type` facet value breaks callers expecting raw type-value. Shim must cover ALL read paths. Mini-audit: grep `that-read ... :type` + `type-map-read` + direct attribute-map reads.
2. **Magic `:term` keyword** — dispatch must be explicit in read/write implementations; silent failure if keyword not recognized.
3. **Cross-tag propagator infinite loop**: residuation check propagator fires at threshold; its write (narrowing) could re-trigger threshold → loop. Prevention: write goes via stratum request NEXT round, not same round.
4. **Stratum handler semantics under speculation**: Phase 9 joint item. For 3c, stratum handler processes without worldview-awareness; Phase 9 refines.
5. **PUnify cost at cross-tag**: unify-core invocation at every propagator fire. Expected cost bounded by structural depth. Benchmark if pathological.
6. **α-equivalence false positive**: document as known limitation of `equal?` proxy; upgrade to ctor-desc when found.
7. **Migration-order test coverage**: each writer migration (3c-ii) should have tests confirming correct tag. Don't migrate blindly.
8. **Option C skip dissolution verification**: post-3c, the classifier/inhabitant tag distinction should make the Option C skip unreachable. Verify at 3c close.

#### §6.15.10 Drift risks (VAG 5d checklist for Phase 3 overall)

Named 2026-04-20 from mini-design audit:

1. **TermInhabitsType bridge artifacts linger** — grep + confirm no residual references to the D.1 bridge; 3a housekeeping
2. **Tag-dispatch complexity obscures algebraic clarity** — keep property inference live; treat any surprising result as a design question, not a bug-to-fix
3. **Merge-reentrancy sneaks via stratum-request implementation** — the stratum handler must itself be BSP-stratified (not fire within the same round)
4. **Premature Phase 9 coupling** — Phase 3's merge stays worldview-agnostic; stratum-request carries assumption-id as metadata, not as merge-function input
5. **`:component-paths` enforcement surfaces structural-read gaps at 3e** — treat as real findings; don't paper over
6. **Property inference divergence from aspirational** — discuss as design signal per the user's 2026-04-20 guidance
7. **A/B bench outcome forces rework** — lazy-vs-eager decision locked by data (threshold ≥10%); have both implementations ready for toggle

---

## §7 Termination Arguments

Per [GÖDEL_COMPLETENESS.org](principles/GÖDEL_COMPLETENESS.org) — each new/modified propagator and stratum needs a termination argument.

| Component | Guarantee level | Measure |
|---|---|---|
| S0 monotone propagators (typing rules, meta-feedback) | Level 1 (Tarski) | Finite AttributeRecord lattice, monotone joins |
| S1 parametric-trait-resolution | Level 1 (Tarski) | Constraint domain shrinks monotonically; bounded by impl registry size |
| S2 meta-default | Level 2 (well-founded) | Finite meta set; each default write is one-time (`:term` monotone) |
| S2 usage-validator | Level 1 (Tarski) | Finite position set; write-once warning emission |
| S(-1) retraction | Level 1 | Finite assumption set; narrowing only |
| ATMS branching (Phase 8) | Level 2 | Bounded by # union components; branches finite |
| ElabLoop outer (stratified) | Level 2 (iterated lfp) | Cross-stratum feedback decreases type depth (per 4B precedent) |
| Cell-based TMS | Level 1 | Worldview cell is finite-height (assumption set bounded) |

---

## §8 Principles Challenge (per decision)

Per [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) Stage 3 Lens P — each major decision annotated with principle served.

| Decision | Principle(s) served | Scrutiny |
|---|---|---|
| Attribute-map on persistent registry network | Propagator-First, First-Class | — |
| 6 facets (incl. new `:term`) | Decomplection, First-Class | Each facet separate lattice = separate concern |
| `:type` / `:term` split | Correct-by-Construction (Option C skip retires structurally), Completeness (MLTT-native) | None |
| `TermInhabitsType` bridge as merge invariant | Correct-by-Construction (invariant is structural) | D.2 may consider explicit α/γ propagators if hole-fill demands |
| CHAMP retirement | Decomplection (one store authority), Completeness | Migration window Phase 2→3 labeled staging scaffold, explicit retirement |
| Option A → Option C staging for freeze | Completeness (both in scope per user direction) | Option A labeled scaffold retired in Option C phase |
| Elaborator strata → BSP handlers | Decomplection (one orchestration mechanism), Composition | — |
| `:component-paths` registration-time check | Correct-by-Construction | NTT-type-error formalization deferred to NTT resume |
| Per-facet SRE domain registration | Correct-by-Construction (property inference catches bugs tests miss) | — |
| Cell-based TMS sub-track inline | Completeness (union types blocked otherwise), Composition | — |

**Red-flag scrutiny**: the phrases "temporary bridge", "belt-and-suspenders", "pragmatic", "keeping the old path as fallback" appear *only* in the retirement-plan sections of A2 (CHAMP migration window) and A4 (Option A staging). Both have explicit retirement phases. Neither is permanent architecture.

---

## §9 Parity Test Skeleton — `test-elaboration-parity.rkt` (M3)

At design time, encode divergence classes as regression tests. Pre-4C elaboration is baseline; post-4C elaboration must match for each class.

**Structure**:

```racket
(define-values (baseline-process post-4c-process)
  (setup-parity-harness))

(module+ test
  ;; Axis 1: parametric trait resolution
  (test-case "parametric Seqable List"
    (check-parity-equal? 'parametric-seqable-list
                         "[head '[1 2 3]]"
                         expected: '(Just 1)))

  (test-case "parametric Foldable Tree"
    (check-parity-equal? 'parametric-foldable-tree
                         "[foldr + 0 some-tree]"
                         expected: some-expected))

  ;; Axis 2: CHAMP retirement (meta solution authority)
  (test-case "zonk from attribute-map matches zonk from CHAMP"
    (check-parity-equal? 'meta-solution-zonk
                         "let x := ?? in x + 1"
                         expected-shape: '(expr-add ? 1)))

  ;; Axis 3: aspect coverage
  (test-case "session expression on-network typing"
    (check-parity-equal? 'session-typing
                         "proc p { !! Nat ; end }"
                         expected-type: '(Session ...)))

  ;; Axis 4: freeze/zonk
  ;; Option A test: freeze reads :term facet
  ;; Option C test: reading expression IS freeze — no tree walk

  ;; Axis 5: :type/:term split
  (test-case "type-meta ?A : Type(0), solution Nat"
    (check-parity-equal? 'type-meta-split
                         "[id 'nat 3N]"     ;; id : {A : Type 0} -> A -> A
                         expected: '3N))

  ;; Axis 6: warnings authority
  (test-case "coercion warning emitted via :warnings facet"
    (check-parity-equal? 'coercion-warning-facet
                         "[int+ 3 [p32->int 3.14p32]]"
                         expected-warnings: '(mixed-numeric ...)))

  ;; Axis 7: elaborator strata → BSP
  ;; (Orchestration parity; behavior should be identical)

  ;; Phase 8: union types via ATMS
  (test-case "union Int|String narrowed by constraint"
    (check-parity-equal? 'union-narrow-by-constraint
                         "[eq? x 0]"   ;; x : Int | String, Eq forces Int branch
                         expected-type: 'Int))

  ;; Option C
  (test-case "expression cell-ref deref = zonk result"
    (check-equal? (eval-expression cell-ref-expression)
                  (freeze-top original-expression)))
  )
```

**Per-axis test count**: 3-5 tests per axis × 9 axes = 27-45 tests. Encoded as regression harness at design time; expanded as phases land.

**Status**: minimal skeleton committed at D.3 (2026-04-18) as [`racket/prologos/tests/test-elaboration-parity.rkt`](../../racket/prologos/tests/test-elaboration-parity.rkt). All tests SKIP-tagged pending their axis's phase; harness `setup-parity-harness` and `check-parity-equal?` stubs raise until Phase 3 wires them.

### §9.1 Per-phase parity-test enablement (D.3 addendum)

Each phase is responsible for enabling and populating the parity tests for the axis it lands. The phase is not DONE until its parity tests pass on identical input through both paths.

| Phase | Axis | Parity tests to enable | Wire-up at this phase |
|---|---|---|---|
| 0 | — | (skeleton committed) | — |
| 1 (A8) | — | (infrastructure; no divergence class) | — |
| 2 (A9) | — | (property inference; no parity test per se — bugs found here are lattice-law violations, not path divergences) | — |
| 2b | — | (Hasse-registry primitive; no divergence class) | — |
| **3 (A5)** | **5** | `type-meta-split` + `:type`/`:term`-split variants (2-3 tests) | **Wires `setup-parity-harness` for the first time** — pre-4C path vs post-split path. Dual-path flag mechanism lands here. |
| **4 (A2)** | **2** | `meta-solution-zonk` + CHAMP-reader migration variants (3-5 tests) | CHAMP reader migration; extends harness to cover meta-solution authority paths. |
| **5 (A6)** | **6** | `coercion-warning-facet` + parallel retirements for deprecation/capability warnings | Warnings authority variants. |
| **6 (A3)** | **3** | `session-typing` + uncovered-AST-kind coverage variants | Per P3 lean: under structural coverage, parity tests verify no `infer/err` fallback is reachable post-phase. |
| **7 (A1)** | **1** | `parametric-seqable-list` + `parametric-foldable` + parametric impl variants | Per-(meta, trait) propagator output ≡ imperative `resolve-trait-constraints!` output. |
| **8 (A4 Opt A)** | **4** | `freeze-option-a` + `:term`-facet-read variants | Tree walk reading `:term` produces equivalent output to tree walk reading CHAMP. |
| **9** | — | (cell-based TMS substrate; Phase 10 consumes) | — |
| **9b** | γ | `gamma-hole-fill` + multi-candidate ATMS variants | Inhabitant synthesis produces expected single-candidate or ATMS-branched outputs. |
| **10** | union | `union-narrow-by-constraint` + ATMS narrow-and-retract variants | Union-type elaboration under ATMS equivalent to pre-ATMS speculation rollback. |
| **11 (A7)** | **7** | `orchestration-strata` + strata-equivalence variants | Behavior identical pre- and post-unification (ordering may differ but outputs match). |
| **11b** | — | `error-provenance-chain` + diagnostic-message variants | Error messages at contradiction equivalent under read-time derivation; tests verify `derivation-chain-for` output shape. |
| **12 (A4 Opt C)** | **4** | `cell-ref-option-c` + cell-ref-dereference variants | Reading expression IS zonking — output equivalent to pre-12 tree-walk zonk. 12d acceptance checks parity green. |
| **T** | — | **ALL parity tests enabled and green**; the parity file is the Phase T acceptance gate. | Final expansion + property regression; no SKIP markers remain. |
| **V** | — | Acceptance includes parity-suite GREEN as a capstone check. | — |

**Enablement discipline**: each phase's 5-step completion checklist ([`workflow.md`](../../.claude/rules/workflow.md) "Phase completion is a BLOCKING checklist") now includes "parity tests for this phase enabled and passing" as step (a'). Implementation phases that modify elaboration behavior but pass no parity test flag a divergence class we missed.

**Progress Tracker integration**: each phase's row should reference the parity-enablement obligation via "See §9.1" — added inline as part of D.3.

---

## §10 Pre-0 Benchmarks — Results and Implications

**Full report**: [`2026-04-17_PPN_TRACK4C_PRE0_REPORT.md`](2026-04-17_PPN_TRACK4C_PRE0_REPORT.md).
**Artifacts**: [`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt`](../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) (M/A/E/V tiers, wall-clock + memory per DESIGN_METHODOLOGY.org), [`racket/prologos/examples/2026-04-17-ppn-track4c-adversarial.prologos`](../../racket/prologos/examples/2026-04-17-ppn-track4c-adversarial.prologos).

### §10.1 Static analyses

- **A3 aspect-coverage gap**: 96 unique `expr-*` structs in syntax.rkt, 35 registered via `register-typing-rule!`, **75 unregistered (upper bound)**. Concrete actionable list produced in Phase 5 sub-audit.
- **Meta-info struct fields**: 7 total — `id`, `ctx`, `type`, `status`, `solution`, `constraints`, `source`. **5 map directly to facets**; `status` derives from `:term`; `source` is lattice-irrelevant debug metadata. *D.1 decision (answering §13 Q3): side registry for `source`; facets for the rest.*
- **A9 facet SRE domain registration**: 4 of 5 current facet lattices (`:context`, `:usage`, `:constraints`, `:warnings`) unregistered. `:type` alone runs through property inference. Phase 2 registers all 6 facets (incl. new `:term`); budget for ≥1 lattice bug found per Track 3 §12 + SRE 2G precedent.

### §10.2 Measured baselines

| Measurement | Value | Implication |
|---|---|---|
| **M1a `that-read :type`** | 27 ns/call | Post-A2 authoritative hot path |
| **M2c `meta-solution` CHAMP read** | 40 μs/call | ~**1400× slower** than `that-read` |
| **M2b `solve-meta!` (CHAMP + cell)** | 39 μs/call | Dual-store cost — halved post-A2 |
| **M3 `infer` core forms** | 382–606 μs/call | Per-call fallback cost; Axis 3 coverage attacks this |
| **A1b 20 metas solve** | 8.5 ms / 24 MB | Linear scaling ~1.3 MB/meta |
| **A2 10 speculation cycles** | 80 μs / 56 KB | Speculation is CHEAP — Phase 10 2^N bounded for N ≤ 10-15 |
| **E1 simple (floor)** | 55 ms / 18 MB | 4C target: measure delta above floor |
| **E2 parametric Seqable** | 178 ms / **343 MB** | **19× floor allocation** — Axis 1 rebuilt-for-efficiency target |
| **E3 polymorphic id** | 98 ms / 63 MB | Delta above floor: 43 ms / 45 MB — Axis 5 target |
| **E4 generic arithmetic** | 101 ms / 53 MB | Delta above floor: 46 ms / 35 MB |
| **Retention (all E cases)** | 20–25 KB | Allocation is GC-friendly garbage; no leaks |

### §10.3 Design refinements driven by Pre-0

1. **Parametric propagator posture**: *rebuilt for efficiency* (§6.5) — E2's 343 MB motivates pre-computed impl index (Hasse-based, §6.11.4) over imperative-retrofit.
2. **CHAMP retirement is a hot-path win, not a neutral migration** — 1400× `that-read` advantage makes A2 one of the highest-leverage axes, not just a cleanup.
3. **Parallel phasing of Option A freeze (Phase 8) and BSP-LE 1.5 TMS (Phase 9) is safe** — speculation is cheap enough that concurrent infrastructure churn doesn't thrash.
4. **ATMS fuel stance**: `:fuel 100` sufficient (§13 Q5 answered). Separate ATMS-fuel unneeded.
5. **Parameter+cell dual-store sweep** in §1 scope — informed by the 1400× finding: other dual-stores (beyond the 6 named bridges) likely hide similar latent wins.

### §10.4 Per-axis A/B targets (for V-phase validation)

| Axis | Pre-0 baseline | D.1 target after 4C lands |
|---|---|---|
| A1 (parametric) | E2 at 343 MB / 178 ms | ≤ 140 MB / ≤ 100 ms (≥ 60% reduction) |
| A2 (CHAMP retirement) | 40 μs CHAMP read / 513 sites | `that-read` replaces all; wall-clock improvement measurable in E3 |
| A5 (`:type`/`:term`) | E3 at 98 ms / 63 MB | ≤ 40 MB / ≤ 75 ms |
| A6 (warnings) | Parameter + cell dual | Single facet; E4 allocation ≤ 40 MB |
| Phase 10 (union types) | Not measurable (not supported) | E2E programs with union types succeed; speculation overhead tracked |
| Phase 12 (zonk retirement) | zonk.rkt 513 call sites | **0 zonk call sites**; ~1,300 lines deleted; E3 freeze cost → 0 |

V-phase (acceptance + A/B benchmarks) re-runs `bench-ppn-track4c.rkt` for post-4C comparison. Each axis target is reassessed against measured data; regressions investigated before PIR.

---

## §11 Acceptance File (Phase 0)

`examples/2026-04-17-ppn-track4c.prologos` — exercises all 9 axes at Level 3 via `process-file`. Progress per phase: uncomment sections as phases land.

Skeleton:

```
ns ppn-track4c

;; Axis 1: parametric trait resolution (Phase 7)
; [head '[1 2 3]]   ;; uses parametric Seqable List

;; Axis 3: aspect coverage (Phase 6)
; proc p { !! Nat ; end }

;; Axis 5: :type/:term split (Phase 3)
; [id 'nat 3N]      ;; id : {A : Type 0} -> A -> A

;; Axis 6: warnings authority (Phase 5)
; [int+ 3 [p32->int 3.14p32]]

;; Phase 8 union types (Phase 10)
; def x : <Int | String> := "hello"
; [eq? x "world"]   ;; narrows to String

;; Option C cell-refs (Phase 12)
; [compose inc dbl] 3N    ;; expression lives on cell-ref network
```

---

## §12 External Dependencies + Interactions

| Dependency | Interaction |
|---|---|
| BSP-LE Track 1.5 (cell-based TMS) | **Inline as 4C Phase 9**. ~450 lines. Unblocks Phase 10. |
| SRE Track 6 (DPO rewriting on-network) | 4C Phase 12 (Option C) contributes primitives. SRE 6 consumes, doesn't re-invent. |
| PM Track 12 (module loading on network) | Orthogonal. No blocking relationship. |
| Track 7 (user-level `grammar` + `that`) | Downstream from 4C. Requires no new 4C infrastructure. Surface lift only. |
| NTT design refinement | Gated on PPN 4 completion. Refinements from 4C (residuation `:preserves`, `:component-paths` derivation, `:fixpoint :stratified` semantics) flow back to NTT when that work resumes. |

---

## §13 Open Questions

Genuine design decision points to work through in dialogue. Phase 0 Pre-0 measurements have supplied data-driven answers for some; others remain for discussion. Critique rounds (P/R/M self + external) happen later, not here.

1. **Residuation formalization** — **RESOLVED by D.2 restructure + BSP-LE solver audit (2026-04-17)**:
   - **Check direction (α)** — tag-dispatched merge on the shared TypeFacet carrier (D.2 §6.1, §6.2). Residuation is internal to the quantale; CLASSIFIER × INHABITANT cross-tag merge IS the quantale residual computation.
   - **Hole-fill direction (γ)** — reactive propagator on the attribute-map (§6.2.1). Fires at two-threshold readiness (CLASSIFIER ground + INHABITANT bot). Hasse-indexed inhabitant catalog (type-env + constructor signatures). SRE ctor-desc decomposition handles compound-classifier structure. ATMS-branching on multi-candidate. Reuses BSP + stratification + ATMS + worldview substrate — **NO** general BSP-LE solver invocation.
   - **Why not general solver invocation**: audit showed BSP-LE's search machinery is structurally relation-with-atoms (goal-desc kinds, clause-info, unify-terms, discrimination). Generalization is future BSP-LE Track 6 ([BSP-LE Master](2026-03-21_BSP_LE_MASTER.md)), not 4C scope.
   - **Shared-carrier tag scheme** (D.2 §6.1): `:type` and `:term` as tag-layers, not separate facets. Residuation laws verified by SRE property inference (§6.9). Status: implementation-ready; lattice-law corner cases enumerated in §6.2 for verification at Phase 2.

   Q1 CLOSED. Sub-question remaining: property inference pass at Phase 2 (A9 facet SRE registration) may surface specific lattice-law corner cases to address; expected based on Track 3 §12 + SRE 2G precedent.

2. **Option A ↔ Option C staging granularity** — **LOOSENED by Pre-0**: speculation is cheap (~8 μs/cycle, §10.2) so Phase 8 (Option A freeze) and Phase 9 (BSP-LE 1.5 TMS) can be parallelized without thrashing. D.1 sequences them as a default; D.2 can relax to parallel if it buys a timing win.

3. **Meta metadata after CHAMP retirement** — **ANSWERED by Pre-0**: 5 of 7 `meta-info` fields map directly to facets; `source` alone is lattice-irrelevant debug metadata. **D.1 decision: side registry for `source`, facets for the rest**. Closed.

4. **Component-paths detection predicate** — **CLOSED (2026-04-17 dialogue, refined by self-critique R1+P4)**: Tier 1/2/3 architecture (§6.8). Classification belongs to the lattice type (Tier 1 SRE-domain), implemented by merge functions (Tier 2 `register-merge-fn!/lattice`), inherited by cells (Tier 3). `#:domain DomainName` keyword overrides default inheritance; takes a named registered domain. Cell-level `:lattice` language retired — cells are instances, not lattices. Production migration: **37 merge functions** (not 666 cells; original figure included tests/benchmarks). Authoritative, type-check-like, no shape-guessing. NTT-aligned — Tier 2 registration IS the compile target of NTT `impl Lattice L` with `join fn` syntax.

5. **Termination argument for ATMS branching (Phase 10)** — **ANSWERED by Pre-0**: speculation cost ~8 μs/cycle means `:fuel 100` bounds 2^N worst-case acceptably for N ≤ 10-15 unions. No separate ATMS-fuel needed. Hypercube Gray-code traversal (§6.11.3) further amortizes via CHAMP sharing. Closed.

6. **Parametric resolution decomposition granularity** — **CLOSED (2026-04-17 dialogue)**: originally posed as "handler vs propagator" — mis-framing. Single stratum handler is off-network (for/fold within handler body = step-think). Per-meta propagator has the same problem internally. Correct decomposition is **per-(meta, trait)**:
   - `:constraints` facet uses module-theoretic tagging by trait identifier (BSP-LE 2B Resolution B).
   - Per-(meta, trait) propagator, each with targeted `:component-paths` on its tag-layer.
   - Hasse-indexed impl registry (§6.11.4) for specificity-ordered lookup.
   - **PUnify** for the match operation itself — structural unification via SRE ctor-desc, with impl-level metas as fresh CLASSIFIER-tagged entries on the shared carrier.
   - ATMS branching on multi-candidate at same specificity (cell-based TMS, Phase 9).
   - Set-latch fan-in per meta for dict aggregation (prior art: Track 4 §3.4b meta-readiness bitmask).
   - Symmetric with §6.2.1 γ hole-fill — same PUnify-against-Hasse-indexed-catalog pattern, different catalog.

   See §6.5 for full mechanism. No scaling concern at any level: meta counts bounded per expression; traits-per-meta typically small; Hasse lookup O(log N); PUnify structural; ATMS handles ambiguity.

### Remaining for dialogue

All six open questions have been worked through. No open items remaining at D.2. Phase-level mini-design (per user direction O2, O4) handles implementation-specific refinements as they arise during Stage 4.

---

## §14 What's Next

1. **Phase 0: Pre-0 benchmark + adversarial testing** — ✅ done, results in [`2026-04-17_PPN_TRACK4C_PRE0_REPORT.md`](2026-04-17_PPN_TRACK4C_PRE0_REPORT.md).
2. **Discuss findings** — in progress. Data-driven answers feeding §13.
3. **Open-question dialogue** — work through §13 with Pre-0 findings + design reasoning.
4. **D.2 refinement** — incorporate dialogue outcomes + locked-in answers from §13.
5. **P/R/M self-critique** — after D.2 stabilizes.
6. **External critique** — after P/R/M.
7. **Acceptance file skeleton** — uncomment target expressions per phase.
8. **Parity test skeleton** — `test-elaboration-parity.rkt` committed.
9. Stage 4 Phase 0 begins only when the design converges (no open questions in §13 demanding redesign).

---

## §15 Observations (D.1 NTT model)

Final observations per M1+NTT methodology:

1. **Everything on-network** post-4C, with one staging scaffold (Option A freeze in Phase 8) retired by Option C (Phase 12).
2. **Architectural impurities caught by NTT modeling**: meta-default and usage-validator correctly marked `:non-monotone`, forcing their assignment to the S2 barrier stratum. Parametric-trait-resolution correctly located in S1 (readiness-triggered). S(-1) retraction correctly structured as `:tier 'value` handler (not `topology`).
3. **NTT syntax gaps surfaced**: `:preserves [Residual]` as quantale morphism extension; `:component-paths` as structural-lattice-derived obligation; `:fixpoint :stratified` semantics for iterated lfp. All persisted per audit §10.1 note; formalization deferred to NTT resume.
4. **No components inexpressible** in NTT at D.1. Full P/R/M critique round may find more.

---

## §17 Reality-Check Artifacts (R1 external critique 2026-04-18)

Reproducible grep commands behind each quantified scope claim in D.2. Phase 1's mini-audit ([DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) § Implementation Protocol) re-runs these; drift between the D.2 baseline and Phase 1's numbers signals either code churn since 2026-04-17 or an undercount in the original grep.

| Claim | Location in D.2 | Command (production-only unless noted) | Baseline count (2026-04-17) |
|---|---|---|---|
| `net-new-cell` production call sites | §6.8 / Phase 1 row | `rg -c "net-new-cell" racket/prologos/*.rkt \| grep -v "/tests/" \| grep -v "/benchmarks/"` | **101** |
| Unique merge functions | §6.8 / Phase 1 row | Phase 1 audit script ([`tools/lint-cells.rkt`](../../tools/lint-cells.rkt)) | **37** |
| Top-10 merge-function coverage | §6.8 | Derived from `tools/lint-cells.rkt` histogram output | **70%** |
| `solve-meta!` write sites | §6.3 / Phase 4 row | `rg -c "solve-meta\\!" racket/prologos/*.rkt` | **79** |
| `zonk.rkt` internal read sites | §6.6 / Phase 12 rows | `rg -c "zonk\|freeze" racket/prologos/zonk.rkt` | **513** |
| `infer/err` fallback sites | §6.4 / Phase 6 row | `rg -c "infer/err\|infer-on-network/err" racket/prologos/*.rkt` | **49** |
| Unregistered AST-kinds upper bound | §6.4 / Phase 6 row | `expr-*` definitions in `syntax.rkt` minus `register-typing-rule!` entries in `typing-propagators.rkt` | **75** |
| Phase 1a lint-cells baseline (2026-04-19 audit) | §6.8 / Phase 1a row | `racket racket/prologos/tools/lint-cells.rkt` | **101 production sites** (99 `net-new-cell` + 1 `-desc` + 1 `-widen` + 0 batch) / **27 unique named merge fns** (baselined in `tools/cell-lint-baseline.txt`) / **1 inline lambda** / **6 ambiguous-name sites** (`merge`, `merge-fn` — local bindings / parameters) / **11 multi-line sites** (initial value spans lines; manual review at Phase 1b) |
| `expr-meta` occurrences (Phase 12 scope) | §6.6 | `rg -c "expr-meta" racket/prologos/*.rkt` | **104 across 19 files** |
| `current-coercion-warnings` retirement scope | §6.5 / Phase 5 row | `rg -n "current-coercion-warnings" racket/prologos/*.rkt` | ~5 edit sites across 2 files |
| `run-stratified-resolution!` production callers | §6.7 / Phase 11 row | `rg -n "run-stratified-resolution\\!" racket/prologos/*.rkt \| grep -v ";"` | **0** (already dead code per metavar-store.rkt:1860 comment) |

**Usage**:
- Phase 1 implementation re-runs these; significant drift (>±20%) prompts a quick audit of what changed.
- Each claim in prose is traceable to one command; changing a claim should be matched by updating the relevant row.
- Commands are conservative (production-only greps) to match D.2's "rescope from 666 to 101" discipline (R1 finding).
