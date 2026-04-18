# PPN Track 4C — Stage 2 Audit

**Date**: 2026-04-17
**Series**: PPN (Propagator-Parsing-Network) — Track 4C
**Prior art consumed**: [4C Design Note](../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md), [PPN Master §4](2026-03-26_PPN_MASTER.md), [Track 4 PIR](2026-04-04_PPN_TRACK4_PIR.md), [Track 4B PIR](2026-04-07_PPN_TRACK4B_PIR.md), [BSP-LE 2B PIR](2026-04-16_BSP_LE_TRACK2B_PIR.md), [Hypergraph Rewriting Research](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md), [Adhesive Categories Research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md), [Attribute Grammar Research](../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md), [Prologos Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md), [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md), [SEXP IR to Propagator Compiler](../research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md)
**Purpose**: Code-grounded audit preceding Stage 3 design.
**Status**: Draft — pre-D.1.

---

## §1 Thesis

**Bring elaboration completely on-network, designed with the mantra as north star and guided by the ten load-bearing design principles. NTT is guiderails and verification that we are doing this correctly.**

- **Mantra** ([`on-network.md`](../../.claude/rules/on-network.md)): "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK." Every propagator install, every cell allocation, every loop, every parameter, every return value is filtered against this.
- **Principles** ([`DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org)): ten load-bearing principles in two groups (how-we-build: propagator-first / data-orientation / correct-by-construction / first-class / decomplection; what-we-build-toward: completeness / composition / progressive disclosure / ergonomics / most-general-interface).
- **NTT** ([NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md)): guiderails. Every architectural piece must be expressible as `propagator` / `cell` / `interface` / `network` / `bridge` / `stratification` / `exchange`. Pieces that cannot be expressed are mantra violations with scaffolding labels.
- **Solver infrastructure as substrate**: BSP-LE Tracks 2+2B were built specifically so PPN 4 can use them for elaboration. Elaboration is solver-driven inference — the same architectural primitives that make logic programs fixpoint converge make type systems converge. This is the Prolog-in-Java-type-spec observation made first-class.

**Scope** (per user direction 2026-04-17):

- Everything not delivered in PPN 4A/4B is in scope.
- The 6 imperative bridges (4C Design Note) retire.
- Union types via ATMS (Phase 8 from 4B) delivered; BSP-LE 1.5 cell-based TMS pulled in as-needed.
- Elaborator strata (S(-1)/L1/L2) unified onto BSP scheduler via `register-stratum-handler!`.
- `:type` / `:term` facet split (Coq-style metavariable discipline, MLTT-grounded).
- Option A *and* Option C for freeze/zonk — Option C (cell-refs in expression representation) contributes DPO adhesive-rewriting infrastructure that SRE Track 6 builds on rather than re-invents.
- Making future language design easier — a `grammar` form (Track 7) built on 4C's output requires no new infrastructure, only surface elevation.

**Explicit non-goals**:

- Track 7 (user-surface `grammar` + `that`). 4C delivers the infrastructure; Track 7 is a later surface lift.
- PM Track 12 (module loading on network). Orthogonal.
- NTT design refinement (gated on PPN 4 completion — NTT design work resumes *after* 4C unblocks language design again).

---

## §2 Current 4B Infrastructure Map

### 2.1 The attribute-map and `that-read` / `that-write` API

- **Cell**: `current-attribute-map-cell-id` on the **persistent registry network** (not the per-command elab-network). [typing-propagators.rkt:74-75](../../racket/prologos/typing-propagators.rkt). One cell holds the entire attribute map for every AST position.
- **Structure**: nested hasheq `position → (hasheq facet → value)`. Component-indexed: compound component-paths `(cons cell-id (cons position facet))` identify a specific facet-at-position so propagators fire on targeted changes, not on every attribute-map write.
- **API**: `that-read attribute-map position facet` and `that-write net cell-id position facet value` — [typing-propagators.rkt:364, 372](../../racket/prologos/typing-propagators.rkt). These are the compiler-internal primitives; user-surface `that` is future (Track 7+).
- **Thin wrappers**: `type-map-read` / `type-map-write` over `that-read` / `that-write` for Track 4A compatibility — [line 387, 390].

### 2.2 The five facets today

| Facet | Lattice | SRE domain registered? | Declared where |
|---|---|---|---|
| `:type` | Track 2H quantale (union-join ⊕ + tensor ⊗) | ✅ `type-sre-domain` via [unify.rkt:109](../../racket/prologos/unify.rkt) | type-lattice.rkt |
| `:context` | Binding-stack extension; ⊥ = `#f` (distinguishable from empty) | ❌ not registered | typing-propagators.rkt |
| `:usage` | QTT multiplicity semiring (m0/m1/mw + add + scale) | ❌ not registered | qtt.rkt |
| `:constraints` | Heyting powerset (constraint-cell.rkt) | ❌ not registered as SRE domain | constraint-cell.rkt |
| `:warnings` | Monotone set union | ❌ not registered | warnings.rkt |

**Gap**: only 1 of 5 facet lattices is a registered SRE domain. Property inference runs only on `:type`. The Track 3 §12 lesson ("SRE domain registration caught the spec-cell top-absorption bug tests missed") implies this is under-verified territory.

### 2.3 Propagator inventory (typing-propagators.rkt)

- **Typing propagator fire functions**: 76 `register-typing-rule!` entries covering literals, Posit/Quire numerics, arithmetic, comparisons, map/set operations, generic arithmetic, ann/reduce/pair/tycon. [typing-propagators.rkt:95, 1024, 1081-1349].
- **Total `expr-*` struct count**: 326 in [syntax.rkt](../../racket/prologos/syntax.rkt). Not all need distinct typing rules (many dispatch through `:arrow` / `:builtin` groups), but the ratio 76/326 is a coverage signal — Bridge 3 ("~10% fallback to `infer/err`") is measured by processing volume, not by AST-kind coverage. The AST-kind coverage gap is much larger.
- **Cross-facet bridge propagators**: `:type → :constraints` (trait-constraint creation), meta-feedback propagators, coercion detection, structural-unification propagators. Not yet enumerated as explicit `bridge` declarations.

### 2.4 Stratification today — TWO orchestrators

This is a structural finding. The elaborator has two resolution orchestrators running parallel to the BSP scheduler:

**Orchestrator A** — imperative loop, [metavar-store.rkt:1863](../../racket/prologos/metavar-store.rkt) `run-stratified-resolution!`. Comment: *"Track 8 A5: Mostly dead code — superseded by run-stratified-resolution-pure"*. Still retained as test-path fallback.

**Orchestrator B** — pure variant, [metavar-store.rkt:1915](../../racket/prologos/metavar-store.rkt) `run-stratified-resolution-pure`. Current production path. Same structure:

1. **S(-1)**: `run-retraction-stratum!` — imperative, reads/writes box. Comment: *"TODO: purify retraction stratum in Phase 8"*. Clear scaffolding label.
2. **S0**: `(current-quiescence-scheduler) pnet` — calls BSP scheduler. This IS on the BSP scheduler.
3. **S1/L1**: `read-ready-queue-actions` — reads ready-queue cell populated by readiness propagators.
4. **S2**: `execute-resolution-actions!` — imperative action interpreter.

**BSP scheduler stratum handlers** in current use (5 total via `register-stratum-handler!`):

| Cell | Handler | Tier | Location |
|---|---|---|---|
| `decomp-request-cell` | SRE decomposition | topology | [sre-core.rkt:1229](../../racket/prologos/sre-core.rkt) |
| `elaborator-topology-cell-id` | Elaborator pair decomposition | topology | [elaborator-network.rkt:1058](../../racket/prologos/elaborator-network.rkt) — **already partial elaborator↔BSP integration** |
| `narrowing-topology-cell-id` | Narrowing decomposition | topology | [narrowing.rkt:79](../../racket/prologos/narrowing.rkt) |
| `constraint-propagators-cell-id` | Constraint topology | topology | propagator.rkt:2412 |
| `naf-pending-cell-id` | S1 NAF fork+BSP | value | [relations.rkt:245](../../racket/prologos/relations.rkt) |

**Observation**: `register-stratum-handler!` exists. It accepts `:tier 'topology | 'value`. The elaborator already uses it for topology. What's missing: the elaborator's S(-1)/L1/L2 strata are *not* registered as `:tier 'value` stratum handlers — they run via the sequential orchestrator (`run-stratified-resolution-pure`), which is parallel to (not integrated with) the BSP outer loop. This is the **elaborator-strata → BSP unification** target from PPN Master §4.6.

### 2.5 CHAMP meta-store as duplicate authority

[metavar-store.rkt:1730 `solve-meta-core!`](../../racket/prologos/metavar-store.rkt:1730) writes the meta solution to BOTH:
1. The CHAMP `meta-info-champ` (line 1769 `champ-insert`)
2. The elab-network propagator cell (line 1778+ `elab-cell-write`)

There are **79 `solve-meta!` call sites** across 18 files. The primary consumers reading the CHAMP downstream:
- [zonk.rkt (513 sites)](../../racket/prologos/zonk.rkt) — the entire zonking pipeline reads the CHAMP to substitute `expr-meta` nodes.
- [elaborator.rkt](../../racket/prologos/elaborator.rkt) — checkQ, multiplicity validation reads meta-info.
- [trait-resolution.rkt](../../racket/prologos/trait-resolution.rkt) — dict-meta resolution writes and reads.
- `freeze-top` / `zonk-top` — driver's post-typing pipeline.

The CHAMP is the authoritative store *by historical precedence*; the cell was added as the propagator-network mirror. Every `solve-meta!` call writes to both. This is **duplicate-store** in the BSP-LE 2B sense — two cells holding the same information, kept consistent by discipline, where the user-of-record (downstream zonk/trait) reads the CHAMP.

### 2.6 Warning parameter + cell (Bridge 6)

[warnings.rkt](../../racket/prologos/warnings.rkt) defines both:
- `current-coercion-warnings` Racket parameter (line 122) — mutated via `(current-coercion-warnings (cons w ...))`.
- `current-coercion-warnings-cell-id` propagator cell (line 62) — populated via `warnings-cell-write!`.

`emit-coercion-warning!` (line 129) writes to *both*. Reads from both paths exist downstream. Classic dual-store belt-and-suspenders pattern — the exact anti-pattern BSP-LE 2B codified as W1.

### 2.7 The `resolve-trait-constraints!` bridge

Single call site at [typing-propagators.rkt:1966](../../racket/prologos/typing-propagators.rkt) — called imperatively from `infer-on-network/err` after on-network typing, then feeds back. Bridges because parametric-impl pattern matching is not yet a propagator — it's an imperative function in [trait-resolution.rkt:318](../../racket/prologos/trait-resolution.rkt).

### 2.8 The `infer/err` fallback (Bridge 3)

49 `infer-on-network|infer/err` occurrences across the codebase. Fallback path triggers when:
- An AST kind has no `register-typing-rule!` entry (76/326 structs covered, many covered via family dispatch).
- An AST kind needs ATMS speculation (union types — Phase 8 territory).
- Type-arg metas can't resolve (the `:kind`/`:type` conflation — Bridge 5).

Exact coverage percentage by AST-kind (not by processing volume) is a Stage 3 measurement — the 4B PIR's "~90% on-network" figure is volume-based.

---

## §3 Mantra Audit: Named Violations in Current State

Per DESIGN_METHODOLOGY M1, applying the mantra *"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK"* to 4B's current state. Violations with file:line citations.

| # | Violation | Mantra word failed | Location | Resolution axis |
|---|---|---|---|---|
| V1 | `resolve-trait-constraints!` imperative call | *on-network* | [typing-propagators.rkt:1966](../../racket/prologos/typing-propagators.rkt) | Axis 1: parametric-resolution propagator |
| V2 | CHAMP duplicate store for meta solutions | *information flow* (double write; ambiguous authority) | [metavar-store.rkt:1769](../../racket/prologos/metavar-store.rkt), 79 `solve-meta!` sites | Axis 2: retire CHAMP authority; `:term` facet is authoritative |
| V3 | `infer/err` fallback for uncovered AST kinds | *structurally emergent* (imperative case dispatch) | [typing-errors.rkt](../../racket/prologos/typing-errors.rkt), 49 sites | Axis 3: aspect-coverage completion |
| V4 | `freeze`/`zonk` tree walk reading CHAMP | *information flow*, *on-network* | [zonk.rkt (513 sites)](../../racket/prologos/zonk.rkt), `freeze-top`/`zonk-top` | Axis 4: Option A (read attribute-map) + Option C (cell-refs / DPO rewriting) |
| V5 | `:kind` and `:type` conflated in one facet | *structurally emergent* (classical ⊥-not-distinguishable lattice error, Track 4B Bug #2 pattern) | typing-propagators.rkt Option C skip | Axis 5: `:type`/`:term` split, Coq-style |
| V6 | `current-coercion-warnings` parameter + cell dual store | *on-network* (belt-and-suspenders W1) | [warnings.rkt:122, 62, 129](../../racket/prologos/warnings.rkt) | Axis 6: retire parameter; driver reads `:warnings` facet |
| V7 | Elaborator `run-stratified-resolution-pure` parallel to BSP scheduler | *structurally emergent* (sequential orchestrator alongside reactive scheduler) | [metavar-store.rkt:1915](../../racket/prologos/metavar-store.rkt) | Axis 7: S(-1)/L1/L2 migrate to `register-stratum-handler!` |
| V8 | `:component-paths` discipline-maintained | *structurally emergent* (should be type-error-by-construction) | [propagator-design.md](../../.claude/rules/propagator-design.md) component-indexing rule | Axis 8: registration-time enforcement |
| V9 | 4 of 5 facet lattices unregistered as SRE domains | *structurally emergent* (property inference not verifying the lattices) | Only `type-sre-domain` registered; constraint/usage/warning/context unregistered | Axis 9: SRE domain registration per facet + property inference |

---

## §4 Scope Decomposition: Nine Axes

Reframing the 4C Design Note's "retire 6 bridges" into 9 axes ordered by structural dependency. Axes 1-6 correspond to the original 6 bridges (re-categorized by kind, not by name). Axes 7-9 are structural items beyond the original framing.

| Axis | Category | Current state | Post-4C state |
|---|---|---|---|
| **1** | Aspect completion: parametric trait resolution | Imperative fn called from typing propagator | Propagator on `:constraints` facet, S1 fiber, fires when type-arg facets ground |
| **2** | Duplicate-store retirement: meta solutions | Two stores (CHAMP + cell), CHAMP authoritative | One authority — `:term` facet on attribute-map — CHAMP retired |
| **3** | Aspect-coverage completion | 76 typing rules / ~326 AST kinds | All AST kinds have typing-propagator coverage or explicit SRE-derived rule |
| **4** | Expression representation: freeze/zonk | Tree walk reading CHAMP | Option A: read `:term` facet. Option C: cell-refs in expression; DPO rewriting primitive (contributes to SRE Track 6) |
| **5** | Facet split: `:kind`/`:type` → `:type`/`:term` | Conflated in `:type` → contradiction | Separate facets per Coq `concl`/`body` discipline. `:type` = classifier (what this position must have). `:term` = inhabitant (what solves it). |
| **6** | Warning authority: `:warnings` facet | Parameter + cell dual path | Driver reads `:warnings` facet exclusively; parameter retired |
| **7** | Orchestration unification: elaborator → BSP | `run-stratified-resolution-pure` sequential; BSP parallel | S(-1)/L1/L2 registered via `register-stratum-handler!` `:tier 'value`; single orchestration mechanism |
| **8** | `:component-paths` enforcement | Discipline-maintained rule | Registration-time check: propagator reading structural-lattice cell without `:component-paths` errors |
| **9** | Facet lattice verification | 1/5 facets SRE-registered | All facets (`:type`, `:term`, `:context`, `:usage`, `:constraints`, `:warnings`) SRE-registered with property-inference verified lattice laws |

### Interaction with Phase 8 (union types via ATMS)

Phase 8 from 4B was blocked on cell-based TMS (BSP-LE Track 1.5). Per user direction, union-type elaboration is in scope for 4C. This cross-cuts several axes:

- **Axis 5** (`:type`/`:term` split) enables meta positions to hold classifier information independent of solution — required for ATMS branching where each branch is a speculative `:term` at the same `:type`.
- **Axis 7** (BSP integration) provides the scheduler mechanism for union-type ATMS via `:fiber S0 :speculation :atms :branch-on [union-types]` (NTT pattern).
- **BSP-LE 1.5 (cell-based TMS)**: needs to be scoped — either inline with 4C as a prerequisite sub-track, or as an external dependency delivered before 4C's Phase 8. Decision belongs in Stage 3.

### Interaction with Option C (cell-refs / DPO)

Option C replaces `expr-meta` nodes in the expression tree with *cell references* that auto-resolve on read. Under this model:
- The expression tree IS a network of cell-refs; "zonking" is just `read`.
- The `:term` facet is accessed by dereferencing a cell-ref.
- DPO-style rewriting on expressions — substitution, β-reduction, η-expansion — becomes graph rewriting on the cell network.

This contributes adhesive-category-verified rewriting primitives that SRE Track 6 ([Adhesive Categories Research §6](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md)) formalizes for *all* structural transformations (parsing, elaboration, reduction). 4C builds the specific instance; SRE 6 generalizes the infrastructure. Pulling Option C into 4C prevents SRE 6 from re-inventing elaboration-specific DPO machinery.

---

## §5 Per-Axis Gap Analysis (Grep-Backed)

### Axis 1: Parametric trait-resolution propagator

- **Current**: `resolve-trait-constraints!` ([trait-resolution.rkt:318](../../racket/prologos/trait-resolution.rkt)), 1 bridge call site from typing-propagators.rkt.
- **Mechanism needed**: NTT `propagator` reading `:type` facet of type-arg positions + `:constraints` facet of constraint position, watching for ground-arg readiness, pattern-matching against parametric impl registry, writing narrowed constraint + sub-constraints.
- **SRE connection**: impl coherence = critical-pair analysis on impl patterns ([Adhesive §6](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) §6). Each parametric impl IS a DPO rule on type patterns; coherence means zero critical pairs.
- **Complexity estimate**: medium. Infrastructure exists (constraint-cell.rkt Heyting lattice, meta-feedback propagators). Main work is registering parametric impls as propagator fire functions with ground-readiness triggers.

### Axis 2: CHAMP retirement

- **Current**: CHAMP authoritative for meta solutions; cell mirrors. 79 `solve-meta!` writes to both. [zonk.rkt (513 reads)](../../racket/prologos/zonk.rkt) reads CHAMP for substitution.
- **Work**: migrate all CHAMP readers to read `:term` facet (post-Axis 5 split). `solve-meta!` becomes `that-write(pos, :term, solution)` at registration sites. Metadata fields of `meta-info` (ctx, constraints, source, kind-status) relocate to appropriate facets: `meta-info-ctx` → `:context` facet; `meta-info-constraints` → `:constraints` facet; `meta-info-type` → `:type` facet. `meta-info-source` is provenance metadata, not a lattice value — evaluate whether it remains a side structure or becomes a `:source` facet.
- **Risk**: 79 call sites + 513 zonk.rkt sites is significant surface area. Per-site audit mandatory.
- **Complexity estimate**: high. Mechanical but broad. Parity test skeleton per axis mandatory.

### Axis 3: Aspect-coverage completion

- **Current**: 76 `register-typing-rule!` entries. ~326 `expr-*` structs. Many covered via group dispatch (arrow-typed, builtin-typed), but uncovered AST kinds fall through to `infer/err` path.
- **Work**: enumerate uncovered AST kinds (grep `expr-*?` predicates not in `register-typing-rule!` arguments). For each: add typing-rule, write fire function, register.
- **Identified so far** (Track 4B PIR §7 / Phase 9 expansion): ann, tycon, reduce, pair, from-int/from-rat, generic-add/lt/negate — all *already added* in 4B Phase 9. Remaining gaps: ATMS-ops, narrowing expressions, auto-implicits, union-type-specific forms, session expressions not covered by typing-sessions.rkt.
- **Dependency**: some uncovered kinds (ATMS ops, union types) depend on Axis 5 (`:type`/`:term` split) and Phase 8.

### Axis 4: freeze/zonk on-network

- **Current**: [zonk.rkt (513 sites)](../../racket/prologos/zonk.rkt). `freeze-top` and `zonk-top` are the driver entry points. Tree-walk pattern: `walk(expr)` recursing on structure, substituting `expr-meta` → solution from CHAMP.
- **Option A path**: rewrite tree walk to read `:term` facet from attribute-map instead of CHAMP. Same walk structure, different data source. Low-risk if Axis 2 is complete. Keeps expression representation unchanged.
- **Option C path**: replace `expr-meta` nodes with cell-refs during elaboration. "Reading the expression" IS zonking (inherent dereferencing). No tree walk at driver time. Requires:
  - New expression representation (`expr-cell-ref` struct or reuse of existing `expr-meta` with cell-id field).
  - Pretty-printer + reducer + unifier + pattern-compiler updates for the new node kind (14-file pipeline exhaustiveness).
  - DPO rewriting primitives (substitution, β-reduction) expressed as graph rewrites on the cell network — contributes to SRE 6.
- **Recommendation**: Option A first (unblocks Axes 1-6 quickly), Option C as a follow-on phase within 4C that contributes SRE 6 infrastructure. Both in scope per user direction; Option A is the staging move.

### Axis 5: `:type` / `:term` facet split

- **Current**: the `:type` facet tries to carry both "this position's expected/classifying type" and "this position's solution." Track 4B Bug #3 documents the conflict: domain-kind `Type(0)` merges with solution `Nat` → `type-top`.
- **Design**: two facets, each with its own lattice:
  - `:type` : TypeFacet — the quantale element constraining the position. For regular term positions: the inferred/expected type. For type-variable meta positions: the universe-level classifier (e.g., `Type(0)`).
  - `:term` : TermFacet — the solution. For regular term positions: usually unknown (we care about the type, not the specific term). For meta positions: the inhabiting expression when solved.
  - Relationship: `:term` must inhabit `:type`. Merge invariant: if `:term` is known and `:type` is known, they must be consistent; contradiction = `:type = type-top`.
- **Bidirectional/residuation reading** (S3 flag from user, 2026-04-17): because the type lattice is a quantale (⊕ = union-join, ⊗ = tensor), it has left/right residuals. `check T e` = `T \ e`; `infer e` produces residual `? / e = T`. The `:type`/`:term` relationship IS residuation — the two facets are left/right residuals of each other. Design-phase consideration, not mandatory for first-pass implementation.
- **Naming precedent**: Coq's `evar_map` uses `concl` (the goal type) and `body` (the solution). Agda/Idris/Lean follow similar two-field separation. MLTT-native; not System-F-kinds.
- **Complexity estimate**: medium. New facet = new lattice registration (Axis 9) + facet-aware propagator updates + merge-bridge between `:type` and `:term` enforcing "term inhabits type." Once done, Option C unsolved-dict-fallback dissolves.

### Axis 6: Warning authority

- **Current**: `current-coercion-warnings` parameter (warnings.rkt:122) + `current-coercion-warnings-cell-id` cell (line 62). `emit-coercion-warning!` writes both (line 129). Driver reads from whichever path it finds.
- **Work**: retire parameter; driver reads `:warnings` facet. `emit-coercion-warning!` writes `that-write(pos, :warnings, ...)` or simply `net-cell-write` to warnings cell.
- **Complexity estimate**: low. Small blast radius. Listed here for completeness.

### Axis 7: Elaborator strata → BSP scheduler

- **Current**: [metavar-store.rkt:1915](../../racket/prologos/metavar-store.rkt) `run-stratified-resolution-pure` sequential loop: S(-1) retraction → S0 quiescence (BSP) → S1 readiness read → S2 action execution.
- **Already partial**: [elaborator-network.rkt:1058](../../racket/prologos/elaborator-network.rkt) uses `register-stratum-handler!` for topology decomposition. Mechanism is proven.
- **Work**:
  - `run-retraction-stratum!` (S(-1)) → register as `:tier 'value` handler on a retraction-request cell; handler reads retracted-assumption set, narrows scoped cells.
  - `collect-ready-constraints-via-cells` (L1) → already mostly propagator-driven (readiness propagators populate ready-queue cell). The remaining scan loop becomes an S1 stratum handler or dissolves entirely if readiness propagators' outputs directly drive S2.
  - `execute-resolution-actions!` (L2) → register as `:tier 'value` handler on ready-queue cell; handler processes actions, writes results back to facets.
  - The outer sequential loop (`let loop ([fuel ...])`) is replaced by BSP's outer loop iterating all stratum handlers.
- **Net effect**: `run-stratified-resolution-pure` retires in favor of BSP outer loop + registered handlers. Termination arguments (per [GÖDEL_COMPLETENESS.org](principles/GÖDEL_COMPLETENESS.org)) unchanged; orchestration mechanism unified.
- **Complexity estimate**: medium-high. Well-understood pattern (A1 addendum proved it for topology); adapting retraction + ready-queue processing to the handler shape is mechanical once the orchestration contract is spec'd.

### Axis 8: `:component-paths` registration-time enforcement

- **Current**: rule persisted in [propagator-design.md](../../.claude/rules/propagator-design.md) with NTT-refinement pointer for future type-error-by-construction.
- **Work (in-scope for 4C, not NTT)**: modify `net-add-propagator` (and `net-add-broadcast-propagator`) to check at registration time: if any `:reads` cell has `:lattice :structural`-equivalent shape (compound hasheq like attribute-map), `#:component-paths` is required. Omitted = registration error.
- **Complexity estimate**: low. Single function modification + a detection predicate. Catches any propagator we write during 4C implementation that forgets the declaration.

### Axis 9: Facet lattice SRE registration

- **Current**: only `type-sre-domain` registered ([unify.rkt:109](../../racket/prologos/unify.rkt)). Four facet lattices unregistered.
- **Work per facet**: extract lattice into SRE domain declaration. Run `property-inference` (Track 3 §12 mechanism). Any property failures = bug — fix the lattice definition. This is live diagnostic during implementation, per the user's Q2 observation.
- **Expected outcome**: likely finds at least one correctness bug in facet lattices (pattern across 2 prior PIRs: SRE 2G distributivity failure, Track 3 §12 spec-cell associativity failure). Budget for fixing as part of 4C.

---

## §6 Solver Infrastructure as Elaboration Substrate

BSP-LE Tracks 2+2B built solver infrastructure that elaboration reuses directly. The user's framing: *"our solver integrated into our language infrastructure."* This is not metaphor — it is a catalogue of concrete primitives.

| Solver primitive (BSP-LE origin) | Elaboration application |
|---|---|
| `register-stratum-handler!` (2B A1) | Axis 7: elaborator S(-1)/L1/L2 |
| Adaptive `:auto` dispatch (2B Phase 6) | Trait resolution dispatch — Tier 1 for solved metas, ATMS for union types, DFS for chains |
| Tier 1 direct fact return (2B Phase 5b) | Axis 1: when type args already ground at registration, skip BSP — direct impl return |
| Per-propagator worldview bitmask (2B R2) | Union-type ATMS branching per Phase 8 |
| S1 NAF handler as fork+BSP (2B Phase R4) | Model for Axis 5 ATMS: each union-component is a forked branch |
| Module Theory scope-sharing (2B R3) | Facet design: attribute-record is direct sum over facets via tagging (not bridges) |
| Parity regression test (2B T-c) | M3: `test-elaboration-parity.rkt` at design time |

**Key insight**: elaboration's "inference" problem IS a solver problem over a richer lattice. The Prolog-embedding-of-type-systems observation (Java type spec proved in Prolog) generalizes: **our type system is a constraint satisfaction problem in a quantale-structured domain**, and the BSP-LE solver solves exactly this shape of problem.

**Concrete implication for Phase 8** (union types via ATMS): each union component `A | B` creates a speculative branch. The ATMS manages consistency; branches retracting = union components eliminated by type-context. This IS what the BSP-LE 2B solver does for logic clauses; the only difference is the lattice on which merge occurs.

---

## §7 NTT Conformance Check

Can current 4B infrastructure be expressed in NTT syntax? Partial catalogue.

| 4B piece | NTT expression | Status |
|---|---|---|
| `attribute-map` cell | `interface AttributeNet :outputs [attr-map : Cell AttributeMap]` | ✅ expressible; AttributeMap is `:lattice :structural` |
| Typing propagator rules | `propagator rule-N :reads [Cell TypeFacet ...] :writes [Cell TypeFacet]` | ✅ expressible; `:component-paths` derivation missing (Axis 8 NTT gap, persisted) |
| Cross-facet `:type → :constraints` flow | `bridge TypeToConstraints :from TypeFacet :to ConstraintFacet :alpha ... :gamma ...` | ⚠️ conceptually expressible; no actual `bridge` declaration exists today |
| S0 / S1 / S2 stratification | `stratification ElabLoop :strata [S-neg1 S0 S1 S2] :fiber S0 ... :fiber S1 ... :barrier S2 -> S-neg1 :commit ...` | ⚠️ expressible; current implementation is sequential `run-stratified-resolution-pure`, not NTT-shaped |
| `resolve-trait-constraints!` | ✗ NOT expressible — imperative function | **Mantra violation V1** |
| `freeze-top` / `zonk-top` tree walk | ✗ NOT expressible — imperative tree walk | **Mantra violation V4** |
| CHAMP meta-store as authority | ✗ NOT expressible — non-propagator state | **Mantra violation V2** |
| `current-coercion-warnings` parameter | ✗ NOT expressible — Racket parameter is not a cell | **Mantra violation V6** |
| `:kind`/`:type` conflation | ✗ NOT expressible correctly — single facet cannot hold both without contradiction | **Mantra violation V5** |

**Post-4C expected NTT shape** (sketch, to be refined in Stage 3):

```
interface AttributeNet
  :inputs  [ast : Cell SurfaceAST]
  :outputs [attr-map : Cell AttributeMap]

data AttributeMap := position -> AttributeRecord
  :lattice :structural

data AttributeRecord := {:type TypeFacet, :term TermFacet,
                         :context ContextFacet, :usage UsageFacet,
                         :constraints ConstraintFacet, :warnings WarningFacet}
  :lattice :structural       ;; component-wise merge per facet

trait Lattice TypeFacet       { ... }  ;; Track 2H quantale
trait Lattice TermFacet       { ... }
trait Lattice ContextFacet    { ... }
trait Lattice UsageFacet      { ... }
trait Lattice ConstraintFacet { ... }
trait Lattice WarningFacet    { ... }

bridge TypeToConstraints :from TypeFacet :to ConstraintFacet
  :alpha infer-trait-obligations
  :gamma resolve-via-impls

bridge TermInhabitsType :from TermFacet :to TypeFacet
  :alpha term->classifier
  :gamma type->search-space      ;; used by proof search / hole fill

stratification ElabLoop
  :strata   [S-neg1 S0 S1 S2]
  :scheduler :bsp
  :fiber S0
    :networks [attribute-net]
    :bridges  [TypeToConstraints TermInhabitsType ContextToType UsageToType]
    :speculation :atms          ;; Phase 8: union types
    :branch-on  [union-types]
  :fiber S1
    :networks [trait-resolution-net parametric-narrowing-net]
  :barrier S2 -> S-neg1
    :commit default-and-validate-and-retract
  :fuel 100
  :where [WellFounded ElabLoop]
```

Every `propagator` declaration carries `:reads` / `:writes` / `:component-paths` (latter derived from lattice structure per Axis 8). Every cross-facet flow is a `bridge` (Galois connection). `stratification` makes orchestration declarative and verifiable.

---

## §8 Principles Alignment Check

Applying the ten load-bearing principles to 4C scope:

| Principle | 4C contribution | Risk / red-flag scrutiny |
|---|---|---|
| **Propagator-First** | Retires 6 bridges + orchestration unification. Everything on-network. | Axis 4 Option A "keeps tree walk, changes data source" — is this off-network? Answer: the walk is stateless and reads cells; acceptable under "everything that reads cells is on-network." |
| **Data Orientation** | Attribute-map IS data. `:warnings` facet IS data. Actions become declarative descriptors. | None. |
| **Correct-by-Construction** | Axis 8 enforcement + Axis 9 property inference = structural correctness, not discipline. | `:type`/`:term` merge invariant (term inhabits type) must be structural — not a runtime check. |
| **First-Class by Default** | Facets are first-class lattices (Axis 9). `that-read`/`that-write` are first-class (surface elevation deferred to Track 7). | None. |
| **Decomplection** | Separate facets for separate concerns. `:type` ≠ `:term` ≠ `:warnings`. Strata for separate timings. | None. |
| **Completeness** | All 9 axes must land. Any deferred piece is labeled scaffolding with retirement-track reference. | Option C deferral from initial proposal was wrong; corrected: Option C in-scope per user direction. |
| **Composition** | Solver infrastructure composes with elaboration via unified BSP scheduler. Axis 7. | Check: does Phase 8 (union ATMS) compose cleanly with S1 trait resolution? Cross-verify in Stage 3. |
| **Progressive Disclosure** | 4C is compiler-internal. User surface (Track 7 `grammar`) is later. | None at 4C level. |
| **Ergonomics** | Retiring bridges simplifies the add-new-AST-kind story: one `register-typing-rule!` + one `register-domain!`. | Keep registration API simple — don't let NTT-derivability land as user-facing verbosity. |
| **Most General Interface** | Facets extensible (with property-inference safety). New strata declarable (user-extensible per NTT). | Scope check: user-extensible facets/strata enter via Track 7 surface lift, not 4C. 4C provides infrastructure; exposure is a later surface track. |

**Red-flag audit** (red-flag phrases from [CLAUDE.md](../../CLAUDE.md)): the 4C Design Note uses "Option A (incremental)" and "Option B (structural)" framings. Under principles-first gate, "incremental/pragmatic" is scrutinized:

- Option A for freeze is in scope *as a staging move* that unblocks Axes 1-6, with Option C as a subsequent phase — **NOT as permanent architecture**. This is acceptable staging; the key is Option C is not deferred to a future track. Both land in 4C.
- No "belt-and-suspenders" paths: retirement of CHAMP (Axis 2) and warning parameter (Axis 6) are *deletions*, not "keep old path as safety."
- No "pragmatic" rationalizations: each axis has a named resolution, not a rationalized deferral.

---

## §9 Tradeoff Matrices for Open Design Decisions

### 9.1 Attribute-map hosting

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| Persistent registry network (current) | Survives across commands; CHAMP structural sharing; incremental re-elab foundations | Cross-command state; cleanup discipline needed | **Keep** (current). 4B Phase 0c already chose this. |
| Per-command ephemeral (Track 4 original) | Simple lifecycle | No cross-form attribute flow; re-allocation per command | Reject — already proved wrong in 4B Phase 6. |

### 9.2 `:term` facet introduction timing

| Option | Pros | Cons |
|---|---|---|
| Introduce `:term` first, then migrate CHAMP readers | Clean staging — new facet validated before CHAMP retirement | Temporary dual-path (but labeled scaffolding) |
| Retire CHAMP first, then add `:term` | One move; no dual-path | Risky — large surface area touched with uncertain destination |

**Recommendation**: introduce `:term` first, then migrate. Dual-path is labeled explicitly and retired in a bounded phase. No belt-and-suspenders — the CHAMP is retired, not kept as fallback.

### 9.3 Option A / Option C for freeze: single phase or sequential?

| Option | Pros | Cons |
|---|---|---|
| A then C in same track | Full on-network freeze, contributes SRE 6 infra | Large scope; risk of track-bloat |
| A only in 4C; C in follow-on track | Smaller 4C | User rejected — Option C is in scope |
| C only, skip A | Avoids dual path | Too risky; Option C touches expression representation (14-file pipeline) |

**Recommendation**: A as an early 4C phase (enables Axis 1-6 completion), C as a later 4C phase with explicit NTT-model for cell-ref expression representation. Per user direction, both in scope.

### 9.4 Elaborator-strata → BSP integration depth

| Option | Pros | Cons |
|---|---|---|
| Full migration — `run-stratified-resolution-pure` retired | Single orchestration mechanism; clean NTT shape | Large surface area; termination-argument refactor required |
| Partial — S(-1) and L1 migrate, S2 action interpreter remains | Smaller step | Incomplete unification; NTT model has gaps |

**Recommendation**: full migration. Per user direction: *"The whole reason we just did BSP-LE 2+2B is so that we could use it as elaboration infrastructure."* Partial migration defeats the reason 2+2B was done.

### 9.5 ATMS / cell-based TMS (BSP-LE 1.5) relationship to 4C

| Option | Pros | Cons |
|---|---|---|
| BSP-LE 1.5 as prerequisite — external dependency before 4C | Clean boundary; 4C doesn't scope TMS design | Sequences tracks; delays 4C start |
| BSP-LE 1.5 as 4C sub-track (inline) | 4C unblocked immediately; shared context | Larger 4C scope; requires cell-based TMS design within 4C |
| BSP-LE 1.5 skipped — Phase 8 uses existing ATMS | Fastest path | ATMS architecturally insufficient per 4B PIR §12 |

**Recommendation**: BSP-LE 1.5 as a 4C sub-track. Union types require cell-based TMS; the design is already scoped in [BSP-LE 1.5 Design Note](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) (if this doc exists — Stage 3 verifies). Keeps the logical boundary tight: 4C delivers elaboration on-network *including* the TMS substrate it needs.

---

## §10 Recommendations for Stage 3 Design

### 10.1 Methodology artifacts required (per [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org))

1. **Mantra Audit** (M1, Stage 0 gate): already drafted in §3 above. Formalize in design doc.
2. **NTT speculative model** (mandatory): Stage 3 design doc opens with NTT-model of post-4C state (§7 sketch formalized into full `network` / `stratification` / `bridge` / `propagator` declarations).
3. **Pre-0 benchmarks per semantic axis** (M2): enumerate semantic compositions per axis — not just performance. Examples:
   - Parametric resolution: `Seqable List`, `Foldable Tree`, `Num Posit32` across compound type args.
   - Union-type ATMS: `Int | String` narrowed by subsequent constraint.
   - Cross-family arithmetic: `Int + Posit32` coercion warning.
   - Cell-ref expression: `(λ x. x) Nat` β-reduces on cell network.
4. **Parity test skeleton** (M3): `test-elaboration-parity.rkt` at design time. One test per axis encoding a semantic divergence class. 9 tests minimum. Encoded as design artifact in Stage 3 doc.
5. **Principles-first design gate** per decision: every major design choice in Stage 3 annotated with principle served. Red-flag phrases scrutinized.
6. **Self-critique lenses P/R/M** (Stage 3 required): Principles Challenge + Reality Check + Propagator-Mindspace. All three mandatory.
7. **External critique** round.

### 10.2 Phasing proposal for Stage 3 to refine

Ordered by structural dependency:

- **Phase 0**: Acceptance file + Pre-0 benchmarks + parity skeleton.
- **Phase 1**: Axis 8 — `:component-paths` registration-time enforcement (foundation for all subsequent propagator work).
- **Phase 2**: Axis 9 — facet SRE registrations for `:context`, `:usage`, `:constraints`, `:warnings`. Property inference runs; fix any lattice bugs it finds.
- **Phase 3**: Axis 5 — `:type`/`:term` split. Introduce `:term` facet; facet-aware propagator updates.
- **Phase 4**: Axis 2 — CHAMP retirement. Migrate `solve-meta!` and all CHAMP readers to `:term` facet.
- **Phase 5**: Axis 6 — `:warnings` authority. Retire `current-coercion-warnings` parameter.
- **Phase 6**: Axis 3 — aspect-coverage completion. Register typing rules for all uncovered AST kinds.
- **Phase 7**: Axis 1 — parametric trait-resolution propagator.
- **Phase 8**: Axis 4 Option A — freeze/zonk reads `:term` facet.
- **Phase 9** (BSP-LE 1.5 sub-track): cell-based TMS, if scoped inline.
- **Phase 10**: Phase 8 (union types) — ATMS-branching elaboration using cell-based TMS + `:term` facet.
- **Phase 11**: Axis 7 — elaborator strata → BSP scheduler. Retire `run-stratified-resolution-pure`.
- **Phase 12**: Axis 4 Option C — cell-refs in expression representation; DPO rewriting primitives.
- **Phase T**: dedicated test file phase (`test-elaboration-parity.rkt` + sub-files per axis), per DESIGN_METHODOLOGY mandatory dedicated test phase.
- **Phase V**: acceptance file L3 + A/B benchmarks + capstone demo.

### 10.3 What Stage 3 must resolve

- Exact NTT-model of post-4C state (concrete, implementable).
- `:term` facet lattice design: what is bot? merge? top? Relationship to `:type` formalized.
- Cell-based TMS scope: prerequisite vs sub-track vs inline.
- Expression representation for Option C: new struct vs reuse `expr-meta` with cell-id field.
- Termination arguments per stratum for the unified BSP orchestration.
- Residuation framework feasibility for `:type`/`:term` (S3 design consideration — design-phase decision whether to formalize or leave implicit).

---

## §11 Open Questions + External Dependencies

### 11.1 Genuine decision points for the user (not project-answerable)

1. **BSP-LE 1.5 (cell-based TMS) scope**: inline 4C sub-track vs external prerequisite. Stage 3 recommendation in §9.5 is inline sub-track; confirm.
2. **Residuation formalization level**: design-phase discussion only, or formal design element with explicit `:type`/`:term` adjunction propagator? User's S3 note was "apply somewhere, consider on each design." Stage 3 proposes design-phase consideration with decision deferred to implementation; confirm.

### 11.2 External dependencies

| Dependency | Source | Impact |
|---|---|---|
| Cell-based TMS | BSP-LE Track 1.5 (design note or sub-track) | Required for Axis 5 Phase 8 (union types via ATMS) |
| SRE Track 6 relationship | SRE Master | 4C Option C contributes; SRE 6 generalizes. Ordering — 4C before SRE 6. |
| PM Track 12 (module loading on network) | PM Master | Orthogonal. Neither blocks. |
| Track 7 (user `grammar` + `that`) | PPN Master | Downstream from 4C. No prerequisite blocking 4C; 4C unblocks Track 7. |

### 11.3 Risks catalogued

- **Large surface area of CHAMP retirement**: 79 `solve-meta!` + 513 zonk-side reads. Mitigation: parity test skeleton at design time; per-site audit mandatory.
- **Option C touches 14-file pipeline**: new expression representation cascades through all AST-handling files. Mitigation: follow [`pipeline.md`](../../.claude/rules/pipeline.md) exhaustiveness checklist; treat as pipeline-wide change.
- **Union-type ATMS interaction with trait resolution**: untested composition. Mitigation: Pre-0 semantic-axis benchmark explicitly exercises `Seqable (List Int | Vector Int)` etc.
- **Facet property-inference finding lattice bugs**: budget for fixing found bugs (Track 3 §12 and SRE 2G set the precedent: each prior track found ~1 bug via property inference).

### 11.4 Cross-cutting lessons to apply

From PPN Master §4 (BSP-LE 2B cross-cutting lessons captured specifically for 4C):

- §4.1 Module Theory scope sharing dissolves bridges → Axis 5, Axis 6 apply this directly (tagged layers on shared carrier, not separate cells with bridge functions).
- §4.2 Per-registration evaluators → Axis 3 aspect-coverage completion IS this pattern at AST-kind granularity.
- §4.4 Per-variable split entries create dissolution cross-products → Axis 5 must pre-merge same-worldview writes before facet-splitting.
- §4.5 Parity regression gate → §10.1 M3 mandatory.
- §4.6 Elaborator strata → BSP unification → Axis 7.
- §4.7 Mantra at Stage 0 → §3 above.

---

## §12 Summary

4C's work is 9 axes organized to retire the 4B scaffolding and bring elaboration fully on-network under mantra discipline, NTT verification, and principles gates.

**The core move**: attribute-map + 6 verified facet lattices + unified BSP orchestration = a single propagator network computing elaboration as attribute-grammar fixpoint. Post-4C, every compiler step from parse to typed core AST is cells + propagators + strata — no imperative bridges, no duplicate stores, no sequential orchestrators alongside the BSP scheduler.

**Staging**: Axis 8 and 9 first (infrastructure); Axes 5, 2, 6 (facet work); Axis 3 (aspect completion); Axis 1 (parametric resolution); Axis 4A, BSP-LE 1.5, Phase 8 (union types); Axis 7 (orchestration unification); Axis 4C (cell-ref expression representation, SRE 6 contribution).

**Stage 3 opens with**: NTT speculative model of post-4C state, then prose design from that model, then P/R/M self-critique + external critique + iteration.
