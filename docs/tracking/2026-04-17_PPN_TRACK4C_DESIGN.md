# PPN Track 4C — Design (D.1)

**Date**: 2026-04-17
**Series**: PPN (Propagator-Parsing-Network) — Track 4C
**Status**: D.1 — first draft; ready for P/R/M self-critique round, then external critique.
**Version history**: D.1 (this document).
**Prior art**: [4C Audit](2026-04-17_PPN_TRACK4C_AUDIT.md) (commit `881d2282`), [4C Design Note](../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md), [PPN Master](2026-03-26_PPN_MASTER.md), [PPN 4 PIR](2026-04-04_PPN_TRACK4_PIR.md), [PPN 4B PIR](2026-04-07_PPN_TRACK4B_PIR.md), [BSP-LE 2B PIR](2026-04-16_BSP_LE_TRACK2B_PIR.md), [Cell-Based TMS Design Note](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md), [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md), [Hypergraph Rewriting Research](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md), [Adhesive Categories Research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md), [Attribute Grammars Research](../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md), [Prologos Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md), [Grammar Toplevel Form](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md), [SEXP IR to Propagator Compiler](../research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md).

---

## §1 Thesis

**Bring elaboration completely on-network.** Designed with the mantra as north star. Guided by the ten load-bearing design principles. NTT is guiderails and verification that we are doing this correctly.

- **Mantra** ([`on-network.md`](../../.claude/rules/on-network.md)): *"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."* Every propagator install, cell allocation, loop, parameter, return value is filtered against this.
- **Principles**: the ten load-bearing principles ([`DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org)). Infrastructure choices and design trade-offs are annotated with which principle they serve (§7).
- **NTT**: *guiderails*. Every structural piece must be expressible in [NTT syntax](2026-03-22_NTT_SYNTAX_DESIGN.md). Pieces not expressible are mantra violations with scaffolding labels. The NTT model is the north-star shape; prose follows from it (§3 NTT model → §5 prose).
- **Solver infrastructure**: BSP-LE Tracks 2+2B built the orchestration, ATMS, stratification, and scope-sharing primitives specifically so PPN 4 can use them for elaboration. Elaboration IS constraint satisfaction over a quantale-structured domain — the same problem the solver solves, lifted by the richness of the lattice (types, terms, contexts, usage, constraints, warnings).

**Scope** (per user direction 2026-04-17):

- Everything not delivered in 4A/4B is in scope.
- The 6 imperative bridges retire.
- Union types via ATMS delivered (BSP-LE 1.5 cell-based TMS pulled in as 4C sub-track).
- Elaborator strata (S(-1)/L1/L2) unified onto BSP scheduler via `register-stratum-handler!`.
- `:type` / `:term` facet split (Coq-style metavariable discipline, MLTT-grounded).
- Option A and Option C for freeze/zonk — Option C contributes DPO-style rewriting primitives to SRE Track 6.
- `:component-paths` enforcement at registration time (in 4C; NTT type-error formalization deferred to NTT work).

**Out of scope**:

- Track 7 (user-surface `grammar` + `that`). 4C delivers the infrastructure; Track 7 is surface elevation.
- PM Track 12 (module loading on network). Orthogonal.
- NTT syntax design refinement (gated on PPN 4 completion).

---

## §2 Design Mantra Audit (Stage 0 gate — M1)

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

Each violation has a named axis in §3-§5; retirement is structural, not by discipline.

---

## §3 NTT Speculative Model — Post-4C State

The NTT model is the architectural north star. Prose follows from it.

### §3.1 Core facet lattices

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

;; :term — the inhabitant facet. Coq-style body. NEW in 4C.
type TermFacet := term-bot                 ;; unknown solution
                | term-val Expr            ;; specific inhabiting term
                | term-top                 ;; contradictory — multiple inconsistent values merged

impl Lattice TermFacet
  join
    | term-bot x                    -> x
    | x term-bot                    -> x
    | [term-val a] [term-val b]     -> if (expr-equal? a b) [term-val a] term-top
    | _ _                            -> term-top
  bot -> term-bot

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

### §3.2 Attribute record as product lattice

```
;; Product of 6 facet lattices per AST-node position
data AttributeRecord := record
  :fields   {:type TypeFacet, :term TermFacet, :context ContextFacet,
             :usage UsageFacet, :constraints ConstraintFacet, :warnings WarningFacet}
  :lattice :structural     ;; component-wise per facet
  :bot     {:type type-bot, :term term-bot, :context context-bot,
            :usage (usage-vector {}), :constraints constraint-bot,
            :warnings (warning-set (empty-set))}
  :top     any-facet-at-top    ;; contradiction: if any facet hits top, record is top

;; Attribute map: position → AttributeRecord
;; Structural lattice with per-position, per-facet merge.
;; Compound component-paths allow targeted propagator firing.
data AttributeMap := map-pos-to-record (HashMap Position AttributeRecord)
  :lattice :structural
  :bot     (map-pos-to-record (empty-hash))
  ;; Merge: per-position component-wise per facet
```

### §3.3 Cross-facet bridges (Galois connections)

Each cross-facet information flow is a verified `bridge` — not an imperative function.

```
;; Type↔Constraints: when :type is known, trait obligations can be generated
bridge TypeToConstraints
  :from TypeFacet
  :to   ConstraintFacet
  :alpha infer-trait-obligations      ;; type → required constraints
  :gamma resolved-dict-to-type        ;; resolved dict → witness type

;; Term inhabits Type: when :term known, check it inhabits :type
;; Residuation reading: :type = T, :term = e ⇒ constraint: e : T (i.e., T \ e in quantale)
bridge TermInhabitsType
  :from TermFacet
  :to   TypeFacet
  :alpha term-classifier              ;; term → its classifying type
  :gamma type-inhabitant-search       ;; type → search space for inhabitants
  :preserves [Residual]               ;; Quantale residuation; formalizes bidirectional typing

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

### §3.4 Propagator declarations (examples; full list per AST kind)

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

### §3.5 Stratification `ElabLoop`

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

### §3.6 NTT Observations (gaps found, impurities caught)

Per M1+NTT methodology, every NTT model ends with an Observations section.

1. **Everything on-network?** Yes, except one staging scaffold: Option A freeze tree walk (§5.6). Labeled as scaffold retired by Option C in a later phase of 4C itself. No other off-network state.

2. **Architectural impurities revealed by the NTT model?**
   - `TermInhabitsType` bridge surfaces the residuation structure (§3.3 + §5.2). This was implicit in Track 2H's quantale; making it a bridge forces naming. Also surfaces Residual as a `:preserves` keyword candidate — NTT refinement candidate (deferred to NTT design work).
   - Meta-default and usage-validator as `:non-monotone` propagators require barrier stratum assignment. This catches any attempt to run them on S0 or S1 at type-check time.
   - `parametric-trait-resolution` in S1 requires readiness-trigger. The NTT model makes this explicit; without it, mid-implementation I might have installed it on S0 and had it fire on bot inputs, producing thrashing.

3. **NTT syntax gaps?**
   - **A8 (`:component-paths` as derivable obligation)** — persisted in [`propagator-design.md`](../../.claude/rules/propagator-design.md). In this design, enforced at registration time; NTT-type-error formalization deferred.
   - **Residuation as `:preserves` keyword** — mentioned above. Deferred.
   - **`:fixpoint :stratified` semantics** — NTT defines `:stratified` as "iterated lfp across strata." 4C's ElabLoop is a concrete instance; semantics align.

4. **Components the NTT cannot express?**
   - None identified at D.1 level. P/R/M critique round may surface more.

---

## §4 Correspondence Table: NTT → Racket (post-4C)

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
| `TermFacet` lattice | new — see §5.1 | typing-propagators.rkt (new) |
| `ConstraintFacet` lattice | constraint-cell.rkt Heyting | constraint-cell.rkt |
| `WarningFacet` lattice | monotone set union | warnings.rkt |
| `bridge TypeToConstraints` | constraint-creation propagator + dict feedback | typing-propagators.rkt, trait-resolution.rkt |
| `bridge TermInhabitsType` | new merge-bridge; §5.2 | typing-propagators.rkt (new) |
| `propagator typing-*` | Fire functions registered via `register-typing-rule!` | typing-propagators.rkt |
| `propagator parametric-trait-resolution` | new S1 propagator; §5.5 | typing-propagators.rkt (new) |
| `stratification ElabLoop` | BSP scheduler + registered stratum handlers | propagator.rkt, typing-propagators.rkt (reorg) |
| Stratum handler S(-1) | `register-stratum-handler! :tier 'value retraction-request-cid` | metavar-store.rkt → propagator.rkt |
| Stratum handler S1 | `register-stratum-handler! :tier 'value ready-queue-cid` | metavar-store.rkt → propagator.rkt |
| Stratum handler S2 | `register-stratum-handler! :tier 'value s2-commit-cid` | metavar-store.rkt → propagator.rkt |
| Worldview cell (Phase 8) | new — cell-based TMS sub-track | propagator.rkt (refactor) |
| `exchange S0 <-> S-neg1` | ATMS fork-on-union + retraction | typing-propagators.rkt (new), metavar-store.rkt |

---

## §5 Architecture Details

### §5.1 The `:type` / `:term` facet split (A5)

**Problem**: Track 4B conflates classifier and solution in `:type`. A type-variable meta's *classifier* (`Type(0)`) and its *solution* (`Nat`) merge to `type-top` (contradiction), forcing Option C (skip downward write for meta positions) — architectural impurity.

**Fix**: two facets.

- `:type` carries the classifier — the type this position *must have*. Always meaningful:
  - For a term-level expression `e : T`, `:type` holds `T`.
  - For a type-variable meta `?A : Type(0)`, `:type` holds `Type(0)`.
  - For a value meta `?e : Nat`, `:type` holds `Nat`.
- `:term` carries the solution — the specific inhabitant when known. Often unknown for term-level expressions (we care about the type, not the specific value). Load-bearing for metas:
  - A type-variable meta `?A` solved to `Nat` has `:term = term-val (expr-Nat)`.
  - A value meta `?e` solved to `(expr-add 1 2)` has `:term = term-val (expr-add 1 2)`.

**Invariant** (enforced by `TermInhabitsType` bridge, §5.2): if `:term = term-val e` is known and `:type = T` is known, then `type-of(e) ⊑ T` in the type lattice. Violation = `:type` facet merges to `type-top`.

**Consequence**: Option C skip retires. The downward write on APP goes to `:type` of the arg position (classifier — "this arg position must have type `dom`"). Feedback from unification writes to `:type` as well (also classifier — "arg's actual type is `T`"). Merge computes the unifier. If the arg position is a meta, its `:term` facet remains `term-bot` until structurally resolved. No conflict; no skip.

**Naming precedent**: Coq's `evar_map` fields `concl` (goal type) and `body` (optional solution). Agda/Idris/Lean follow similar two-field separation. MLTT-native (not System-F-kinds).

### §5.2 The `TermInhabitsType` bridge — residuation (A5, S3)

The type lattice is a quantale ([Track 2H](2026-04-02_SRE_TRACK2H_DESIGN.md)): ⊕ = union-join, ⊗ = type-tensor (function application distributing over unions). Quantales have left/right residuals: `A \ B` (left) and `A / B` (right), satisfying `A ⊗ X ⊑ B ⟺ X ⊑ A \ B`.

Bidirectional type checking is residuation:

- `check T e` = demand `e ⊑ T` in the term-inhabits-type relation. Computation: the residual `T \ (type-of e)` — "what must e's structure satisfy."
- `infer e` = synthesize `T = type-of(e)`. Computation: `(type-of e) / ?` where `?` is the position-context demand.

**The bridge** (D.1 implementation — residuation as declarative structure, not explicit computation):

```
bridge TermInhabitsType
  :from TermFacet
  :to   TypeFacet
  :alpha (lambda (term-val)
           (if (eq? term-val term-bot)
               type-bot
               (type-of-expr term-val)))  ;; compute classifier of given term
  :gamma (lambda (type-val)
           ;; Given expected type, the search space for inhabitants.
           ;; Used by hole-fill / proof search. D.1 stub: identity.
           type-val)
  :preserves [Residual]
```

At facet merge: when `:term` is updated to `term-val e` and `:type` is already `T`, the merge invariant checks `(type-of-expr e) ⊑ T`. If violated, `:type` merges to `type-top` (contradiction). This IS the bridge firing as a propagator — no separate imperative check.

**Design decision D.1**: implement the bridge as a declarative `merge-invariant` function attached to the AttributeRecord lattice. Don't separate α/γ as explicit propagators at D.1 — the invariant is computed at merge time. If residuation needs explicit propagators (e.g., for hole-fill search), scope as D.2 refinement.

### §5.3 CHAMP retirement (A2)

**Problem**: `meta-info` CHAMP is a duplicate store of the `:type` and `:term` facets, authoritative for downstream consumers.

**Fix**: migrate authority to attribute-map facets.

**Migration phases**:

1. **Introduction** (Phase 2): `:term` facet added. `solve-meta-core!` writes to BOTH CHAMP and attribute-map `:term` during migration window.
2. **Reader migration** (Phase 3): all CHAMP readers migrated to read `:term` facet. Grep-verified (79 `solve-meta!` sites, 513 zonk.rkt sites).
3. **CHAMP retirement** (Phase 3 close): CHAMP code path deleted. `meta-info` struct retained only for non-lattice metadata (origin, source-loc, kind metadata) — move to a separate `:meta-metadata` facet or a side registry.

**No belt-and-suspenders**: the migration window Phase 2→3 is a labeled staging scaffold with explicit retirement in Phase 3 close. Not permanent.

### §5.4 Aspect-coverage completion (A3)

**Problem**: 76 `register-typing-rule!` entries vs ~326 `expr-*` structs. `infer/err` fallback catches the rest imperatively.

**Fix**: enumerate uncovered AST kinds, register one propagator per kind. Dispatch is structural (cell-ID → propagator), not imperative.

**Methodology**:

1. Audit (Phase 5 pre-audit): grep all `expr-*?` predicates, cross-reference with `register-typing-rule!` entries. Produce a coverage gap list.
2. Enumerate gaps by category: ATMS ops, union-type forms, session expressions, narrowing expressions, auto-implicits, rare elaboration helpers.
3. Register one fire function per AST kind. Use SRE-derived decomposition where applicable (structural lattice rules handle N AST kinds via one decomposition template).
4. Verify: after registration, the `infer/err` fallback should be reachable only for genuinely unrepresentable cases (e.g., elaboration errors, not missing rules).

### §5.5 Parametric trait-resolution propagator (A1)

**Problem**: `resolve-trait-constraints!` is an imperative function called from `infer-on-network/err`. Parametric impl pattern matching is not a propagator.

**Fix**: register `parametric-trait-resolution` as an S1 propagator. It reads `:type` facet of type-arg positions + `:constraints` facet of constraint position; writes narrowed constraint set or resolved dict term to `:term`.

**Mechanism**:

```
propagator parametric-trait-resolution
  :reads  [(meta-pos :type), (meta-pos :constraints)]
  :writes [(meta-pos :term), (meta-pos :constraints)]
  fire-parametric-resolve:
    (when (and (constraint-domain-has-parametric? constraints)
               (type-args-ground? type))
      (define matches (match-parametric-impls constraints type))
      (cond
        [(empty? matches) (that-write pos :constraints constraint-top)]  ;; failure
        [(singleton? matches)
         (that-write pos :term (dict-for-impl (first matches)))
         (that-write pos :constraints (narrow-to (first matches)))]
        [else
         (that-write pos :constraints (narrow-to-subset matches))]))  ;; ambiguous — S2 handles
```

**SRE connection**: impl coherence = critical-pair analysis on impl patterns ([Adhesive §6](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md)). Each parametric impl IS a DPO rule. Coherence = zero critical pairs at registration time.

### §5.6 Option A and Option C for freeze/zonk (A4)

**Option A** (Phase 7): `freeze`/`zonk` tree walk reads `:term` facet instead of CHAMP. Same walk structure. Low-risk. After A2 (CHAMP retirement), `:term` is authoritative; A4-A is mechanical.

*Staging scaffold label*: Option A tree walk is off-network (stateless, reads cells). Retirement in Option C.

**Option C** (Phase 11): expression representation changes. `expr-meta id` becomes `expr-cell-ref cell-id`. Reading an `expr-cell-ref` auto-resolves via cell dereference to `:term` facet.

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

### §5.7 Elaborator strata → BSP scheduler unification (A7)

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

### §5.8 `:component-paths` registration-time enforcement (A8)

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

### §5.9 Per-facet SRE domain registration (A9)

**Problem**: only `type-sre-domain` is registered ([unify.rkt:109](../../racket/prologos/unify.rkt)). Four facet lattices unverified.

**Fix**: register `context-sre-domain`, `usage-sre-domain`, `constraint-sre-domain`, `warning-sre-domain`, `term-sre-domain`. Each declares `bot`, `top`, `merge`, monotonicity, properties. Property inference runs.

**Expected outcome**: based on Track 3 §12 and SRE 2G precedent (each found ~1 lattice bug), property inference likely finds ≥1 facet-lattice bug. Budget for fixes.

### §5.10 Union types via ATMS + cell-based TMS (Phase 8)

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

## §6 Termination Arguments

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

## §7 Principles Challenge (per decision)

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

## §8 P/R/M Self-Critique

Lens outputs at D.1. Full P/R/M cycle happens with the critique round producing D.2.

### §8.1 Lens P — Principles challenged

- **Completeness**: are all 9 axes concretely scoped? Yes — each has a phase and test plan. Union types + cell-based TMS inline. Option C in 4C.
- **Correct-by-Construction**: is `TermInhabitsType` invariant structural or discipline? **Answer: structural**. Invariant is computed at attribute-record merge time, not in separate call sites. Violation = `:type → type-top` automatically.
- **First-Class by Default**: is `:term` facet first-class? Yes — it's a reified facet in the attribute record, declarable by SRE domain, subject to property inference, accessible via `that-read/write`.
- **Propagator-First**: is Option A freeze on-network? Strictly: it's a tree walk reading cells. It's the last off-network state; retired in Option C.
- **Data Orientation**: are actions descriptors? L1/L2 actions are data in the ready-queue cell. S1/S2 handlers process them. Matches Data Orientation pattern from DESIGN_PRINCIPLES.org.

### §8.2 Lens R — Reality check (file:line verification)

Counts from audit §2-§5 were grep-backed. Reconfirmed in D.1:

- `resolve-trait-constraints!`: 1 bridge site at [typing-propagators.rkt:1966](../../racket/prologos/typing-propagators.rkt). ✓
- `solve-meta!`: 79 sites across 18 files. ✓
- Zonk: 513 `zonk.rkt` sites. ✓
- `register-stratum-handler!`: 5 registrations incl. [elaborator-network.rkt:1058](../../racket/prologos/elaborator-network.rkt). ✓
- `register-typing-rule!`: 76 entries. ✓
- `register-domain!`: 4 registrations. Four facets unregistered. ✓
- `run-stratified-resolution!` / `run-stratified-resolution-pure`: [metavar-store.rkt:1863, 1915](../../racket/prologos/metavar-store.rkt). ✓
- `current-coercion-warnings` + `current-coercion-warnings-cell-id`: both in [warnings.rkt:122, 62](../../racket/prologos/warnings.rkt). ✓

**Gap**: aspect-coverage precise count (A3 Phase 5 pre-audit) not yet done. D.2 pre-audit produces the concrete list.

### §8.3 Lens M — Propagator mindspace

- **Network Reality Check per new component**:
  - `parametric-trait-resolution` propagator: `net-add-propagator` — yes. `net-cell-write` to `:term`/`:constraints` — yes. Trace: `:type` + `:constraints` input → fire → `:term` + narrowed `:constraints` output via cell write. ✓
  - `meta-default` propagator: `net-add-propagator` — yes. Writes `:term`. ✓
  - S(-1) / S1 / S2 stratum handlers: `register-stratum-handler!` registrations. Handler reads request cell, writes facet cells. ✓
  - `TermInhabitsType` bridge: merge invariant at attribute-record lattice. Structural. ✓
  - ATMS fork-on-union: worldview cell read + per-branch propagator spawn. Cell-based TMS required. ✓
- **Red flags scan**: `for/fold`, `let loop`, scan-and-dispatch, imperative queues — present only in S1/S2 handler internals processing discrete action sets, and in the ElabLoop outer fuel loop (which BSP already implements). No new `for/fold` over independent items that should be broadcasts.

---

## §9 Phased Roadmap

### Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | Acceptance file + Pre-0 benchmarks + parity skeleton | ⬜ | `examples/2026-04-17-ppn-track4c.prologos`, Pre-0 bench file, `test-elaboration-parity.rkt` skeleton |
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
| 12 | A4 Option C cell-ref expression representation | ⬜ | Replace `expr-meta` with `expr-cell-ref`; 14-file pipeline update; DPO primitives to SRE 6 |
| T | Dedicated test files | ⬜ | `test-elaboration-parity.rkt` expanded; per-axis test files |
| V | Acceptance + A/B benchmarks + capstone demo + PIR | ⬜ | L3 acceptance green; A/B shows no regression; PIR |

### Per-phase summary

Each phase completes with the 5-step blocking checklist (tests, commit, tracker, dailies, proceed). Each phase ends with a dialogue checkpoint (Conversational Implementation Cadence). NTT-conformance check per phase alongside tests-green.

**Phase dependencies**:

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

## §10 Parity Test Skeleton — `test-elaboration-parity.rkt` (M3)

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

## §11 Pre-0 Benchmarks per Semantic Axis (M2)

Semantic compositions, not just performance. For each axis, adversarial examples exercise the composition *before* implementation. The data reshapes D.2 design.

### Axis 1 (parametric resolution) semantic axes

- Parametric impl with compound type args: `Seqable (List Int)`, `Foldable (Tree Nat)`.
- Parametric impl with polymorphic type args: `Seqable (f A)` for higher-kinded.
- Multiple parametric candidates: `Num Int` and `Num Rat` — specificity resolution.

### Axis 3 (aspect coverage) semantic axes

- Session expressions: `proc p { !! Nat ; ?? Bool ; end }`.
- ATMS-ops in current 4B fallback: `union branches with narrowing`.
- Narrowing expressions: `[add ?a 3 = 5]`.

### Axis 5 (`:type`/`:term`) semantic axes

- Type-variable meta with concrete solution: `[id 'nat 3N]`.
- Value-meta with polymorphic type: `?e : Nat -> Nat`.
- Nested metas: `?e1 = app ?e2 ?e3`.

### Phase 8 (union types) semantic axes

- `Int | String` narrowed by `Eq` constraint → `Int`.
- `List Int | Vector Int` intersected with `Indexed` → both viable.
- Contradictory union: `Int | Bool` with `Num` → `Int` branch survives.
- Deep union in compound types: `List (Int | String)`.

### Performance axes (concurrent)

- Per-facet access cost: `that-read/write` hot-path measurement.
- Attribute-map cell allocation: compound component-paths overhead.
- BSP outer loop with elaborator handlers: stratum iteration cost vs sequential `run-stratified-resolution-pure`.

---

## §12 Acceptance File (Phase 0)

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

## §13 External Dependencies + Interactions

| Dependency | Interaction |
|---|---|
| BSP-LE Track 1.5 (cell-based TMS) | **Inline as 4C Phase 9**. ~450 lines. Unblocks Phase 10. |
| SRE Track 6 (DPO rewriting on-network) | 4C Phase 12 (Option C) contributes primitives. SRE 6 consumes, doesn't re-invent. |
| PM Track 12 (module loading on network) | Orthogonal. No blocking relationship. |
| Track 7 (user-level `grammar` + `that`) | Downstream from 4C. Requires no new 4C infrastructure. Surface lift only. |
| NTT design refinement | Gated on PPN 4 completion. Refinements from 4C (residuation `:preserves`, `:component-paths` derivation, `:fixpoint :stratified` semantics) flow back to NTT when that work resumes. |

---

## §14 Open Questions for External Critique

These are genuine decision points for the critique round. The P/R/M self-critique does not resolve them; external eyes needed.

1. **Residuation formalization**: is `TermInhabitsType` as merge invariant (D.1) sufficient, or should `:alpha` / `:gamma` be explicit propagators in D.2? The latter enables hole-fill / proof search via `:gamma` but doubles the propagator count for this bridge. Lean D.1: invariant at merge time; D.2 question: when is proof search triggered?

2. **Option A ↔ Option C staging granularity**: is Phase 8 (Option A freeze) in parallel with Phase 9 (BSP-LE 1.5 TMS)? Or sequential to reduce concurrent infrastructure churn? D.1 sequences them; parallel possibly risks test parity — critique welcome.

3. **Meta metadata (source-loc, kind hint) after CHAMP retirement**: proposal is side registry or `:meta-metadata` facet. Side registry is simpler but re-introduces off-network state. Facet is on-network but increases facet count. Which?

4. **Component-paths detection predicate**: `structural-lattice?` predicate checks cell value shape. False-positive risk: `hasheq`-valued cells that are NOT structural lattices (e.g., simple map cells). Proposal: explicit `:lattice :structural` annotation on cell registration. Requires new registration API.

5. **Termination argument for ATMS branching (Phase 10)**: worst-case branch count = 2^N for N unions. Does `:fuel 100` bound this acceptably, or do we need a separate ATMS-fuel?

6. **Elaborator stratum handler vs propagator**: S1 parametric-trait-resolution — is it a single stratum handler (iterate over all ready constraints) or multiple per-constraint propagators (fire when individual constraints become ready)? D.1 leans propagator-per-constraint for composability; critique: does this scale with large impl registries?

---

## §15 What's Next

1. **P/R/M critique round** → D.2 (refinements from Lens P/R/M outputs).
2. **External critique** (10-point structure, adversarial) → D.3.
3. **Propagator-Mindspace challenge** (Lens M at Stage 3 rigor) → D.4 if needed.
4. **Pre-0 benchmark setup** — actual bench runs feed D.4 or D.5.
5. **Acceptance file skeleton** — uncomment target expressions per phase.
6. **Parity test skeleton** — `test-elaboration-parity.rkt` committed.
7. Stage 4 Phase 0 begins only when the design converges (no open questions in §14 demanding redesign).

---

## §16 Observations (D.1 NTT model)

Final observations per M1+NTT methodology:

1. **Everything on-network** post-4C, with one staging scaffold (Option A freeze in Phase 8) retired by Option C (Phase 12).
2. **Architectural impurities caught by NTT modeling**: meta-default and usage-validator correctly marked `:non-monotone`, forcing their assignment to the S2 barrier stratum. Parametric-trait-resolution correctly located in S1 (readiness-triggered). S(-1) retraction correctly structured as `:tier 'value` handler (not `topology`).
3. **NTT syntax gaps surfaced**: `:preserves [Residual]` as quantale morphism extension; `:component-paths` as structural-lattice-derived obligation; `:fixpoint :stratified` semantics for iterated lfp. All persisted per audit §10.1 note; formalization deferred to NTT resume.
4. **No components inexpressible** in NTT at D.1. Full P/R/M critique round may find more.
