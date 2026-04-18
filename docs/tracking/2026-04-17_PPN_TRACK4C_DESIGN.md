# PPN Track 4C — Design (D.1)

**Date**: 2026-04-17
**Series**: PPN (Propagator-Parsing-Network) — Track 4C
**Status**: D.2 — refined from D.1 via Pre-0 findings + Hyperlattice/SRE/Hypercube lens application + Module Theory Realization B restructure for `:type`/`:term`.
**Version history**:
- D.1 (2026-04-17): initial draft. Full NTT model, 9 axes, 14-phase roadmap.
- D.2 (2026-04-17): `:type`/`:term` as tag-layers on shared TypeFacet carrier (Module Theory Realization B, not separate facets with bridge). Residuation internal to the quantale. γ hole-fill reframed in propagator-mindspace (no "walks"). General Residual Solver scoped to future BSP-LE Track 6.
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

**Out of scope**:

- Track 7 (user-surface `grammar` + `that`). 4C delivers the infrastructure; Track 7 is surface elevation.
- PM Track 12 (module loading on network). Orthogonal.
- NTT syntax design refinement (gated on PPN 4 completion).

---

## §2 Progress Tracker and Phased Roadmap

Each phase completes with the 5-step blocking checklist (tests, commit, tracker, dailies, proceed). Each phase ends with a dialogue checkpoint (Conversational Implementation Cadence). NTT-conformance check per phase alongside tests-green.

### Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | Acceptance file + Pre-0 benchmarks + parity skeleton | 🔄 | `examples/2026-04-17-ppn-track4c.prologos`, Pre-0 bench file, `test-elaboration-parity.rkt` skeleton |
| 1 | A8 `:component-paths` registration-time enforcement | ⬜ | `net-add-propagator` modified; detection predicate |
| 2 | A9 facet SRE domain registrations | ⬜ | `context`, `usage`, `constraint`, `warning`, `term` domains; property inference |
| 3 | A5 `:type` / `:term` facet split | ⬜ | `:term` facet added; `TermInhabitsType` bridge invariant; Option C skip retires |
| 4 | A2 CHAMP retirement | ⬜ | Migrate `solve-meta!` writes; migrate all CHAMP readers; delete code path |
| 5 | A6 Warnings authority | ⬜ | `:warnings` facet authoritative; parameter retired |
| 6 | A3 Aspect-coverage completion | ⬜ | Audit uncovered AST kinds; register typing rules per kind |
| 7 | A1 Parametric trait-resolution propagator | ⬜ | New S1 propagator; retires Bridge 1 |
| 8 | A4 Option A freeze | ⬜ | Tree walk reads `:term` facet; scaffold labeled for Option C retirement |
| 9 | BSP-LE 1.5 sub-track (cell-based TMS) | ⬜ | Phases A-D from design note |
| 10 | Phase 8 union types via ATMS | ⬜ | Fork-on-union, TMS-tagged branches, S(-1) retract |
| 11 | A7 Elaborator strata → BSP scheduler | ⬜ | S(-1)/S1/S2 as BSP handlers; `run-stratified-resolution-pure` retires |
| 12 | A4 Option C — **zonk retirement entirely** via cell-refs | ⬜ | Replace `expr-meta` with `expr-cell-ref`. Reading expression IS zonking. `zonk-intermediate`/`zonk-final`/`zonk-level` deleted (~1,300 lines). 14-file pipeline update. DPO primitives contributed to SRE 6. Meets original [Track 4 §3.4b](2026-04-04_PPN_TRACK4_DESIGN.md) expectation unmet in 4B. |
| T | Dedicated test files | ⬜ | `test-elaboration-parity.rkt` expanded; per-axis test files |
| V | Acceptance + A/B benchmarks + capstone demo + PIR | ⬜ | L3 acceptance green; A/B shows no regression; PIR |

### Phase dependency graph

```
Phase 0
  ↓
Phase 1 (A8 enforcement) — foundation for all subsequent propagators
  ↓
Phase 2 (A9 facet registration) — property inference catches bugs early
  ↓
Phase 3 (A5 :type/:term split)
  ↓
Phase 4 (A2 CHAMP retirement) — depends on :term facet
  ↓
Phase 5 (A6 warnings) — small independent piece
  ↓
Phase 6 (A3 aspect coverage) — independent; can parallel with 5
  ↓
Phase 7 (A1 parametric resolution)
  ↓
Phase 8 (A4 Option A freeze) — depends on CHAMP retirement
  ↓
Phase 9 (BSP-LE 1.5 TMS) — sub-track
  ↓
Phase 10 (Phase 8 union types)
  ↓
Phase 11 (A7 BSP orchestration) — can parallel with 10
  ↓
Phase 12 (A4 Option C cell-refs) — largest single phase; 14-file pipeline
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
```

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

### §6.1 `:type` / `:term` as tag-layers on the shared TypeFacet carrier (A5, D.2 restructure)

**Problem** (from 4B): conflating classifier and inhabitant in `:type` facet. A type-variable meta's classifier (`Type(0)`) and its solution (`Nat`) merge to `type-top` (contradiction), forcing Option C skip (D.1).

**D.1 fix** (superseded): two separate facets `TypeFacet` + `TermFacet` with a `TermInhabitsType` bridge.

**D.2 fix (Module Theory Realization B)**: one carrier, two tag-layers.

The MLTT foundation grounds this. There is one universe hierarchy; `Nat`, `Type(0)`, `Type(1)`, etc. are all terms at adjacent levels. "Type" and "term" are a *layer* distinction, not a *lattice* distinction. Attempting to separate them into two lattices in D.1 duplicates the carrier: both `TermFacet`'s `term-val Expr` and `TypeFacet`'s classifier-values hold `Expr`. The duplication is the scent.

Realization B: one facet `:classify-and-inhabit` on the shared TypeFacet carrier. Every entry carries a bitmask tag:

- **CLASSIFIER tag** — this layer holds the classifying type of the position (what it *must have*).
- **INHABITANT tag** — this layer holds the specific inhabitant (what *solves* this position).

Merge is tag-dispatched:
- CLASSIFIER × CLASSIFIER → type-lattice-merge (unification of classifiers).
- INHABITANT × INHABITANT → α-equivalence strict merge; mismatch → type-top.
- CLASSIFIER × INHABITANT → **quantale residuation check**: does the inhabitant inhabit the classifier? Enforced via left residual `type-of(INHABITANT) ⊑ CLASSIFIER`. Violation → type-top (contradiction).

The residuation structure lives *inside* the quantale, not as a bridge. This is §6.2's subject.

**User-visible surface is preserved**: `that-read pos :type` reads the CLASSIFIER-tagged entries; `that-read pos :term` reads the INHABITANT-tagged entries. The tag distinction is implementation — `:type` and `:term` remain distinct surface names with distinct semantics. Error messages say "expected type T, got term e : Int" just as before; the tag-dispatched merge knows which side is which.

**Consequence**: Option C skip dissolves (as in D.1) but via a different mechanism. The APP downward write tags the arg-position entry as CLASSIFIER with value `dom`. The feedback from unification tags with CLASSIFIER (both merge cleanly via type-lattice-merge). If a meta is later solved to a specific term (e.g., `(expr-Nat)`), that entry is tagged INHABITANT — the cross-tag merge enforces `type-of(expr-Nat) ⊑ Type(0)` which holds (`Nat : Type(0)`). No contradiction.

**What changed vs D.1**: `:term` as its own lattice/facet is retired. `TermInhabitsType` bridge is retired (§4.3). SRE lens table (§6.11.1) updated accordingly (§6.11.1).

**Mitigations for the "cons" of Realization B** (addressing user's 1A concern):

1. **Surface clarity**: user-facing `:type`/`:term` names unchanged; tag distinction is internal. Type-error diagnostics can still say "expected T, got e : S" because the tag-dispatched merge knows which entry is which layer.
2. **Lattice-law verification**: SRE property inference on the tag-dispatched merge verifies commutativity (merge is tag-order-independent), associativity across tag combinations, idempotence per tag, and the residuation laws (`A ⊗ (A \ B) ⊑ B`, `(B / A) ⊗ A ⊑ B`, distribution). Track 3 §12 + SRE 2G precedent says inference catches bugs tests miss — actively invited here, not a risk.
3. **Provenance as first-class**: each tagged entry carries its derivation chain (source-loc + producer propagator + ATMS assumption). Error messages walk the chain. Richer provenance because the lattice-structured carrier IS a derivation DAG by construction.

**Naming precedent**: Coq's `evar_map` has `concl` (goal type) and `body` (optional solution) as separate fields — but Coq stores them in one meta-info record per meta, not two independent stores. Agda/Idris/Lean follow similar patterns. Realization B matches how elaboration with metavariables is done in the reference systems, rendered in propagator-network terms.

### §6.2 Residuation — internal to the TypeFacet quantale (A5, S3, D.2)

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

#### §6.2.1 γ hole-fill propagator — reactive, not iterative (D.2 mantra reframe)

D.1 described γ as "walks type-env + ctor-desc catalogue." That's step-think: *walk*, *iterate*, *search* — all violations of "all-at-once, all in parallel, structurally emergent." D.2 reframes.

**Mantra-compliant γ design**:

The γ propagator is a reactive propagator on the attribute-map that fires when *two conditions* hold simultaneously — both of which are detected by cell readership, not by iteration:

1. A position's CLASSIFIER-tagged layer is ground (no unresolved metas within the type). This is detected by a *readiness threshold* on the CLASSIFIER entry — the same pattern Axis 1 parametric-trait-resolution uses (§6.5).
2. The same position's INHABITANT-tagged layer is still `bot` (no inhabitant known).

When both hold, the propagator fires — **once**, per position, at threshold. It does not walk.

**Pre-indexed inhabitant catalog**:

The fact pool (what could inhabit a given type) is a **pre-indexed Hasse structure** registered at declaration time — exactly parallel to the parametric impl registry in §6.11.4 and §6.5. The catalog has two halves, both registered as SRE domains with Hasse indices keyed by classifying type:

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

### §6.3 CHAMP retirement (A2)

**Problem**: `meta-info` CHAMP is a duplicate store of the `:type` and `:term` facets, authoritative for downstream consumers.

**Fix**: migrate authority to attribute-map facets.

**Migration phases**:

1. **Introduction** (Phase 2): `:term` facet added. `solve-meta-core!` writes to BOTH CHAMP and attribute-map `:term` during migration window.
2. **Reader migration** (Phase 3): all CHAMP readers migrated to read `:term` facet. Grep-verified (79 `solve-meta!` sites, 513 zonk.rkt sites).
3. **CHAMP retirement** (Phase 3 close): CHAMP code path deleted. `meta-info` struct retained only for non-lattice metadata (origin, source-loc, kind metadata) — move to a separate `:meta-metadata` facet or a side registry.

**No belt-and-suspenders**: the migration window Phase 2→3 is a labeled staging scaffold with explicit retirement in Phase 3 close. Not permanent.

### §6.4 Aspect-coverage completion (A3)

**Problem**: 76 `register-typing-rule!` entries vs ~326 `expr-*` structs. `infer/err` fallback catches the rest imperatively.

**Fix**: enumerate uncovered AST kinds, register one propagator per kind. Dispatch is structural (cell-ID → propagator), not imperative.

**Methodology**:

1. Audit (Phase 5 pre-audit): grep all `expr-*?` predicates, cross-reference with `register-typing-rule!` entries. Produce a coverage gap list.
2. Enumerate gaps by category: ATMS ops, union-type forms, session expressions, narrowing expressions, auto-implicits, rare elaboration helpers.
3. Register one fire function per AST kind. Use SRE-derived decomposition where applicable (structural lattice rules handle N AST kinds via one decomposition template).
4. Verify: after registration, the `infer/err` fallback should be reachable only for genuinely unrepresentable cases (e.g., elaboration errors, not missing rules).

### §6.5 Parametric trait-resolution propagator (A1) — **rebuilt for efficiency**

**Problem**: `resolve-trait-constraints!` is an imperative function called from `infer-on-network/err`. Parametric impl pattern matching is not a propagator. Pre-0 finding E2 shows this path allocates **343 MB / 19× baseline** for a single `[head '[1N 2N 3N]]` call — ~325 MB/123 ms unique to the parametric path, driven by retry loops + candidate-list allocation + CHAMP updates + intermediate-type construction.

**Posture** (per user direction 2026-04-17): *rebuilt for efficiency*, not retrofit. Design for the efficient propagator architecture from the start rather than lifting the imperative algorithm into a propagator wrapper.

**Fix**: register `parametric-trait-resolution` as an S1 propagator. Key efficiency choices:

1. **Pre-compute candidate sets at impl registration time** — not at resolution time. When a parametric impl is registered, compute its type-arg pattern and index it. At resolution time, the propagator matches against a pre-indexed structure rather than iterating over all impls.
2. **Monotone narrowing** — the `:constraints` facet shrinks monotonically as type-args become ground. No retry loops; the propagator fires at readiness thresholds.
3. **No intermediate type allocation** — match against pre-indexed patterns; emit the winning dict term directly. Structural sharing (SRE + Module Theory lens, §6.11) allows candidate patterns to share type subterms rather than copying them.
4. **Fire-once at ground-readiness** — `:component-paths` targets type-arg ground thresholds. Zero re-firing on partial input.

**Mechanism**:

```
propagator parametric-trait-resolution
  :reads  [(meta-pos :type), (meta-pos :constraints)]
  :writes [(meta-pos :term), (meta-pos :constraints)]
  :fire-once-on-threshold (and ground? (non-empty? :constraints))
  fire-parametric-resolve:
    ;; Pre-indexed at registration: parametric-impl-index ↦ pattern trie
    (define matches (index-lookup parametric-impl-index type))  ;; O(log N) via trie
    (cond
      [(empty? matches) (that-write pos :constraints constraint-top)]       ;; failure
      [(singleton? matches)
       (that-write pos :term      (dict-for-impl (first matches)))          ;; resolved
       (that-write pos :constraints (narrow-to (first matches)))]
      [else
       (that-write pos :constraints (narrow-to-subset matches))])            ;; ambiguous — S2
```

**Pre-0 expected improvement**: post-phase A/B measurement target is **~60-80% reduction** in E2 allocation (343 MB → ~70-140 MB), with similar wall-clock gains. The target is set conservatively; the pre-indexing + fire-once combination plausibly achieves more. Measured in V phase.

**SRE connection**: impl coherence = critical-pair analysis on impl patterns ([Adhesive §6](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md)). Each parametric impl IS a DPO rule. Coherence = zero critical pairs at registration time. The pre-computed pattern index IS the critical-pair-free decomposition of the registry — indexing STRUCTURE (not ALGORITHM).

### §6.6 Option A and Option C for freeze/zonk (A4) — **zonk retirement entirely**

**Context — unmet PPN 4 expectation**: the original [Track 4 Design §3.4b "Phase 4b: Zonk Retirement"](2026-04-04_PPN_TRACK4_DESIGN.md) targeted elimination of all three zonk functions (`zonk-intermediate`, `zonk-final`, `zonk-level`, ~1,300 lines) with cell-refs replacing `expr-meta`. Phase 4b-i (readiness infrastructure) landed; Phase 4b-ii-b (zonk deletion) was blocked on the Track 4 Phase 2-3 redo and deferred. Track 4B PIR §12 reconfirmed this as still-deferred. **4C completes this.**

**Option A** (Phase 8): staging scaffold. `freeze`/`zonk` tree walk reads `:term` facet instead of CHAMP. Same walk structure; different data source. Low-risk, mechanical after A2 (CHAMP retirement).

*Scaffold label*: Option A keeps the tree walk. It is NOT the target; it exists only to unblock Axes 1–7 with minimal churn. Retired in Phase 12 (Option C).

**Option C** (Phase 12): **the zonk retirement phase.** Expression representation changes — `expr-meta id` becomes `expr-cell-ref cell-id`. Reading an `expr-cell-ref` auto-resolves via cell dereference to `:term` facet. *Reading the expression IS zonking.* No tree walk. `zonk.rkt` functions deleted.

**14-file pipeline impact**:

- [`syntax.rkt`](../../racket/prologos/syntax.rkt): new `expr-cell-ref` struct.
- [`surface-syntax.rkt`](../../racket/prologos/surface-syntax.rkt): no change (surface doesn't see cell-refs).
- [`parser.rkt`](../../racket/prologos/parser.rkt): produces `expr-meta` initially; the elaborator converts to `expr-cell-ref` at meta installation.
- [`elaborator.rkt`](../../racket/prologos/elaborator.rkt): meta installation produces `expr-cell-ref`.
- [`typing-core.rkt`](../../racket/prologos/typing-core.rkt) / [`typing-propagators.rkt`](../../racket/prologos/typing-propagators.rkt): propagators read `:type` facet via cell-ref.
- [`qtt.rkt`](../../racket/prologos/qtt.rkt): inferQ/checkQ handle cell-ref.
- [`reduction.rkt`](../../racket/prologos/reduction.rkt): β/δ/ι handle cell-ref (dereference before reducing).
- [`substitution.rkt`](../../racket/prologos/substitution.rkt): substitution follows cell-refs.
- [`zonk.rkt`](../../racket/prologos/zonk.rkt): **most zonk call sites dissolve** — reading a cell-ref IS zonking. `freeze-top` becomes trivial.
- [`pretty-print.rkt`](../../racket/prologos/pretty-print.rkt): dereferences cell-refs for display.
- Optional: `unify.rkt`, `macros.rkt`, `foreign.rkt`.

**DPO contribution**: substitution, β-reduction, η-expansion become graph rewrites on the cell-ref network. The adhesive-category rewriting primitives ([Adhesive Research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md)) apply directly. These primitives are the infrastructure SRE Track 6 builds on — Option C in 4C means SRE 6 doesn't re-invent elaboration-specific DPO machinery.

### §6.7 Elaborator strata → BSP scheduler unification (A7)

**Problem**: `run-stratified-resolution-pure` ([metavar-store.rkt:1915](../../racket/prologos/metavar-store.rkt)) is a sequential orchestrator parallel to the BSP scheduler. The BSP scheduler already has `register-stratum-handler!` ([propagator.rkt:2392](../../racket/prologos/propagator.rkt)) with `:tier 'topology | 'value` dispatch.

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

### §6.8 `:component-paths` registration-time enforcement (A8)

**Problem**: the rule ("propagators reading compound cells MUST declare `:component-paths`") is discipline-maintained, per [propagator-design.md](../../.claude/rules/propagator-design.md). In-session it's easy to forget on newly-written propagators.

**Fix**: modify `net-add-propagator` (and `net-add-broadcast-propagator`) to check at registration time:

```racket
(define (net-add-propagator net inputs outputs fire-fn
                            #:component-paths [paths '()]
                            . opts)
  ;; A8 enforcement: any input cell whose value is structural MUST have
  ;; a :component-paths entry covering it.
  (for ([cell-id (in-list inputs)])
    (define cell-val (net-cell-read net cell-id))
    (when (and (structural-lattice? cell-val)
               (not (any-path-covers? paths cell-id)))
      (error 'net-add-propagator
             "structural cell ~a reads require :component-paths (see propagator-design.md)"
             cell-id)))
  ...)
```

*Detection predicate*: `structural-lattice?` recognizes compound cell values (hasheq, RRB, decisions-state, scope-cell). Attribute-map cells match by construction.

*NTT refinement*: §7 of [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) will eventually make this a type error via `:lattice :structural` on cells. 4C's registration-time check is the bridge until NTT design resumes.

### §6.9 Per-facet SRE domain registration (A9)

**Problem**: only `type-sre-domain` is registered ([unify.rkt:109](../../racket/prologos/unify.rkt)). Four facet lattices unverified.

**Fix**: register `context-sre-domain`, `usage-sre-domain`, `constraint-sre-domain`, `warning-sre-domain`, `term-sre-domain`. Each declares `bot`, `top`, `merge`, monotonicity, properties. Property inference runs.

**Expected outcome**: based on Track 3 §12 and SRE 2G precedent (each found ~1 lattice bug), property inference likely finds ≥1 facet-lattice bug. Budget for fixes.

### §6.10 Union types via ATMS + cell-based TMS (Phase 8)

**BSP-LE 1.5 as 4C sub-track** (per audit §9.5 recommendation):

- **Phase A**: worldview-cell infrastructure. Create worldview cells alongside attribute-map cells. Propagators read worldview from cells.
- **Phase B**: `net-cell-write` / `net-cell-read` accept explicit worldview argument (backward-compatible with `current-speculation-stack` parameter).
- **Phase C**: migrate speculation users (elab-speculation-bridge, union type checking) to cell-based worldview.
- **Phase D**: `current-speculation-stack` parameter retired.

See [Cell-Based TMS Design Note](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) for the detailed migration path. Scope estimate: ~450 lines.

**Phase 8 (union types via ATMS)** builds on cell-based TMS:

```
;; When :type facet at position becomes union A | B:
fork-on-union:
  aid-a := fresh-assumption
  aid-b := fresh-assumption
  branch-a := tag-worldview aid-a
  branch-b := tag-worldview aid-b
  ;; Both branches elaborate concurrently under their tagged worldview.
  ;; Facet writes are TMS-tagged with the branch assumption.

;; On contradiction in branch-a (:type → type-top):
retract-contradicted:
  narrow :type facet by removing tagged entries for aid-a.
  emit narrowed :type = B.

;; On both branches succeeding:
merge-viable-branches:
  compute S0 quiescence per branch.
  S2 barrier commits surviving branch(es) to base worldview.
```

**Connection to existing infrastructure**: BSP-LE Track 2B's per-propagator worldview bitmask + S1 NAF handler pattern (fork+BSP+nogood) IS this shape. ATMS assumption management is the BSP-LE ATMS solver; the only difference is the lattice on which merge occurs.

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
| `:warnings` | VALUE (monotone set union) | Free join-semilattice | DERIVED (side output) | Flat — union of independent warnings |

**D.2 consolidation**: 6 facets → 5 facets. `TermFacet` retires; `:type` and `:term` tag-layer on the shared TypeFacet carrier. `TermInhabitsType` bridge retires; replaced by internal quantale residuation (§6.2).

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

#### §6.11.4 Phase 7 parametric-trait-resolution — Hasse-based index

The parametric impl registry (§6.5 "rebuilt for efficiency") indexes impls by type-arg pattern. The SRE lens identifies this index as the *Hasse diagram of the impl coherence lattice* — where each impl is a node, and the partial order is *specificity* (`Eq Int` is more specific than `Eq A`). Matching at resolution time walks the Hasse diagram from most-specific candidates downward:

- **O(log N) lookup** for N impls, via the Hasse height (not N scan).
- **Coherence = antichain** of maximal specific impls; zero critical pairs.
- **Specificity resolution** IS the Hasse order — most-specific match wins.

This is what the "rebuilt for efficiency" posture means concretely: the candidate-index IS the Hasse decomposition of the impl coherence lattice. The efficiency gain vs current E2 (343 MB) comes from walking the Hasse structure, not the algorithm.

#### §6.11.5 Implications for 4C

Applying these lenses changes three concrete design elements:

1. **Every propagator declaration should name its lattice properties** (Value/Structural, Primary/Derived, algebraic properties). This makes the NTT conformance check (§15) richer than "is it expressible?" — it becomes "does the lattice classification match the SRE lens's structural analysis?"
2. **Hasse-diagram diameter bounds appear in termination arguments** (§8). The existing `:fuel 100` is a safety net; the Hasse bound is the structural argument. Strengthens Conjecture's optimality claim per stratum.
3. **Phase 10 design uses hypercube algorithms by construction** — not as an optimization pass. Gray-code, bitmask subcube, hypercube all-reduce are in the D.2 refinement.

#### §6.11.6 Note on the General Residual Solver (future BSP-LE scope)

During D.1 dialogue (2026-04-17), a cross-application pattern surfaced: PUnify, FL-Narrowing, BSP-LE, trait resolution, bidirectional type-checking, parse disambiguation, ATMS narrowing — **each is a residual computation on a quantale/lattice with a stratified + ATMS-tagged + CALM-compliant solver**. A general solver parameterized by `:lattice`, `:composition`, `:decomposition`, `:facts` would unify these as instances.

**Scoping**: the generalization is **out of 4C scope**. Audit of [BSP-LE 2/2B's search machinery](racket/prologos/relations.rkt) (2026-04-17) confirmed it is structurally a *relation-with-atoms solver*: `goal-desc` kinds, `clause-info`, `unify-terms`, discrimination are coupled to the relation model. Generalizing to arbitrary quantales requires lifting these primitives into a lattice-parameterized abstraction — a future **BSP-LE series track**, not 4C.

**What 4C DOES consume**: the *substrate* — BSP scheduler, `register-stratum-handler!`, worldview bitmask, ATMS assumption management, stratification. These are lattice-agnostic and already used by typing-propagators.rkt + elaborator-network.rkt. Hole-fill γ (Q1), parametric trait resolution (Axis 1), union-type ATMS (Phase 10) all use the substrate directly with specific propagators — not by invoking the BSP-LE relational solver.

**Forward reference**: the general residual solver track (when designed) consumes 4C's lattice specifications as example instances. PPN 5 (type-directed disambiguation), future FL-Narrowing refinements, and future PPN work that needs residual search inherit the general solver once it exists. Captured here so the insight isn't lost.

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

4. **Component-paths detection predicate** — OPEN: `structural-lattice?` predicate checks cell value shape. False-positive risk: `hasheq`-valued cells that are NOT structural lattices (e.g., simple map cells). Proposal: explicit `:lattice :structural` annotation on cell registration. Requires new registration API. Dialogue needed.

5. **Termination argument for ATMS branching (Phase 10)** — **ANSWERED by Pre-0**: speculation cost ~8 μs/cycle means `:fuel 100` bounds 2^N worst-case acceptably for N ≤ 10-15 unions. No separate ATMS-fuel needed. Hypercube Gray-code traversal (§6.11.3) further amortizes via CHAMP sharing. Closed.

6. **Elaborator stratum handler vs propagator** — OPEN: S1 parametric-trait-resolution — single stratum handler (iterate over all ready constraints) or multiple per-constraint propagators (fire when individual constraints become ready)? D.1 leans per-constraint + rebuilt-for-efficiency indexing (§6.5), motivated by E2's 343 MB observation. Open: does this scale for very large impl registries? Depends on index structure — Hasse index (§6.11.4) should scale log N. Dialogue + phase-level measurement.

### Remaining for dialogue

Q1 (residuation), Q4 (component-paths detection), Q6 (handler vs per-constraint — scaling). These are genuine design choices Pre-0 doesn't resolve directly; discussed in D.2 iteration or phase-level mini-design as appropriate (per user direction on O2, O4: delegate specifics to per-phase mini-design).

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
