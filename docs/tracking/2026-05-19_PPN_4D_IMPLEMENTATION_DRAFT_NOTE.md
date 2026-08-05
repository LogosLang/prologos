# PPN 4D Implementation Draft Note — Findings Carried Forward from 1D/1E Exploration

**Date**: 2026-05-19
**Source**: PPN 4C Phase 9+ Addendum — Phases 1D and 1E exploration deferred to PPN 4D
**Status**: Implementation draft note (not a design doc) — captures audit findings, research, architectural exploration, diagnostic findings, and durable infrastructure from 1D/1E work as input to PPN 4D's eventual Stage 1-3 design cycle
**Authors**: 2026-05-17 through 2026-05-19 sessions (PPN 4C Phase 9+ Addendum)
**Linked from**: [PPN Master Track 4D row](2026-03-26_PPN_MASTER.md#track-4d-attribute-grammar-substrate-unification)

---

## §1 Purpose and scope

This note captures the architectural exploration, audit data, research findings, and diagnostic results from the PPN 4C Phase 9+ Addendum's attempted Phase 1D ("Meta-Solution Canonical Store Consolidation") and Phase 1E ("`that-*` Storage Unification") work. After several sessions of exploration, both phases were recognized as belonging to PPN 4D's substrate-unification charter rather than the Phase 9+ addendum's substrate+orchestration scope. They are deferred to PPN 4D with the findings below as inputs.

**This note does NOT prescribe a 4D design.** PPN 4D requires its own Stage 1 research synthesis, Stage 2 audit, and Stage 3 design iteration. This note saves 4D from re-doing the work already done — and surfaces a critical diagnostic constraint that 4D's storage unification will need to address.

---

## §2 Why 1D/1E were deferred (the process story)

### §2.1 What 1D/1E were trying to do

**Phase 1E (original §7.6.16)**: extend the `that-*` API to handle meta-positions consistently. `(that-read am meta-pos :type)` should return the meta's classifier; `(that-read am meta-pos :term)` should return its solution. The dispatch is at the API layer (`(expr-meta? pos)` predicate). The destination is the universe cell. Motivation: Track 7's user-`that x :type/:term V` syntax working uniformly for metas and non-metas. Originally scoped as surface-level routing — no new propagators, no new architecture.

**Phase 1D (added during exploration)**: address a "dual-store inconsistency" surfaced during 1E's Stage 2 audit. Two write paths produce "the meta is solved" state — trait-resolution writes attribute-map :term (typing-propagators.rkt:768); solve-meta! writes universe cell. The two stores can disagree for type-unification metas that are solved only via the imperative path. Originally proposed as Architecture A: a reverse-bridge propagator from universe cell to attribute-map :term INHABITANT layer, installed per type meta during install-typing-network.

### §2.2 What happened in implementation

1. **Stage 2 audit** (§3) captured comprehensive baselines and identified the dual-store
2. **Pre-Phase-1E cleanup** retired `with-handlers` in `resolve-worldview-bitmask` (Move B+ 2nd instance) — commit `1340aec8`; 3.3% suite improvement; INDEPENDENTLY VALUABLE (stands as Phase 1V incidental cleanup)
3. **1D.a BSP-firing spike** validated bridge fires at writing worldview; established NO-speculation-guard design pattern (§7.6.16.14)
4. **1D.a implementation attempt** broke `test-first-rest-01.rkt :: first-of-rest`: 12 metas in the composition `first [rest '[1 2 3]]` failed to resolve when the bridge propagator was installed per-meta
5. **Six diagnostic reductions** (§6.4) all failed identically: full design, no-op fire-fn, fire-once, no component-paths, no inputs, different input cell — every variant breaking resolution
6. **Topology-stratum hypothesis emerged** (user-articulated): install is a dynamic topology change; CALM doesn't guarantee convergence over changing topology; needs stratification (`register-topology-handler!` pattern). This hypothesis remains **untested** (see §6.6)
7. **Architecture re-evaluation** (Approaches A→E with adversarial principles framework) revealed deeper questions
8. **Scope re-grounding** (user-flagged): the dual-store is sources-of-truth fragmentation — exactly what PPN 4D's charter addresses. The piecemeal cut attempted in 1D/1E wants holistic treatment

### §2.3 Why this is the right scope for PPN 4D

The parent design doc + PPN Master row for 4D states:

> Collapse fragmented typing/elaboration/reduction subsystems into a unified attribute-grammar substrate; each typing rule as a declarative grammar production with attribute-equations compiled to propagator installations. **Motivated by PPN 4C Addendum T-3's three accidentally-load-bearing findings (the structural fingerprint of sources-of-truth fragmentation).**

The dual-store inconsistency IS sources-of-truth fragmentation. T-3 surfaced three accidentally-load-bearing patterns; the 1D/1E exploration surfaced a fourth potential one (install-breaks-resolution under specific patterns). PPN 4D's substrate unification naturally subsumes:
- Storage unification (one substrate; no dual-store)
- API routing (`that-*` against unified substrate, not multiple cells)
- The Realization B precedent from Coq/Agda/Idris/Lean
- Topology-stratum design (4D's grammar-rule compiler emits propagator installs — needs the right install mechanism)

### §2.4 Process lesson surfaced

**Audit findings flag debt, but don't auto-promote to precursor phases.** During the 1D/1E exploration, the Stage 2 audit surfaced a dual-store smell. The session interpreted this as "must fix before 1E" and promoted Phase 1D as precursor. But: the dual-store didn't gate 1E's actual charter (surface-level API routing), and the architectural concern wanted holistic treatment that 1D's local cut couldn't deliver. The "must fix before X" framing was scope drift.

**Discipline going forward**: audit findings are architectural INPUTS, not auto-promoted precursors. If a finding doesn't gate the current track's stated charter, capture it for an appropriate-scope track. Codification candidate for DEVELOPMENT_LESSONS.org alongside related scope-discipline lessons.

---

## §3 Stage 2 audit findings (durable; 4D inherits)

### §3.1 The `that-*` API surface

Defined in `typing-propagators.rkt:428-585`:
- `that-read` (arity 2 and 3) at line 466+
- `that-write` (arity 5) at line 527
- 5 storage facets: `:type`, `:context`, `:constraints`, `:usage`, `:warnings`
- `:term` is a magic keyword that routes to `:type` INHABITANT layer (per Phase 3c-ii)

~30 production call sites; all in arity-3 form.

### §3.2 Position is opaque `equal?`-comparable

Production uses **the AST expression itself as the position** (via match binding eq?-identity). No struct wrapper or protocol around position. For meta positions, position = `(expr-meta id #f)` under universe-active path (cell-id always #f post-S2.d).

### §3.3 Universe cells

Allocated lazily by `init-meta-universes!` (Option C-4 from S2.e-i). 4 cells:
- `current-type-meta-universe-cell-id`
- `current-mult-meta-universe-cell-id`
- `current-level-meta-universe-cell-id`
- `current-session-meta-universe-cell-id`

Plus 1 shared `current-worldview-hasse-registry-handle`.

`meta-domain-info` table at `metavar-store.rkt:2271-2283` (lean post-S2.e-iv-b — no more `'universe-active?` flag; all 4 domains active).

### §3.4 Dual-store inventory

| Meta class | Solution write path | Cell |
|---|---|---|
| Trait dict meta | `(that-write net tm-cid dict-meta-pos ':term dict-expr)` at typing-propagators.rkt:768 → magic-keyword routes to attribute-map :type INHABITANT | attribute-map |
| Type-unification meta | `solve-meta!` (~20 sites: unify, resolution, trait-resolution, qtt, sessions) | universe cell |

**Asymmetry**: for type-unification metas, attribute-map :term remains 'bot. `(that-read am type-meta-pos :term)` returns bot even when the meta IS solved. **Consumers** (`typing-propagators.rkt:766` and `:907`) reading attribute-map :term miss imperatively-solved metas.

### §3.5 Facet/domain naming gap

- 5 attribute-map facets: `:type`/`:context`/`:constraints`/`:usage`/`:warnings` + `:term` magic-keyword
- 4 universe domains: `type`/`mult`/`level`/`session`
- Only `:type ↔ 'type` overlaps; mult/level/session have NO attribute-map facets

### §3.6 Bench coverage

Pre-Phase-1E bench harness retired at 1C-iv-a (D.4-incompatible). NEW durable harness: `racket/prologos/benchmarks/micro/bench-attribute-record.rkt` (M+A+E+R+S tiers, ~700 lines). Inherits to 4D for ongoing A/B comparison.

**Baselines preserved**:
- `data/benchmarks/attribute-record-pre0-baseline-2026-05-17.txt` — pre-cleanup M+A+E+R+S baselines
- `data/benchmarks/attribute-record-post-cleanup-2026-05-18.txt` — post `with-handlers` retirement (commit `1340aec8`)

---

## §4 Research findings — Realization B is deliberate

### §4.1 Module Theory framing (per parent design §6.1)

> "There is one universe hierarchy; Nat, Type(0), Type(1), etc. are all terms at adjacent levels. 'Type' and 'term' are a **layer distinction, not a lattice distinction**. Attempting to separate them into two lattices in D.1 duplicates the carrier... The duplication is the scent."

> "User-visible surface is preserved: `that-read pos :type` reads CLASSIFIER-tagged entries; `that-read pos :term` reads INHABITANT-tagged entries. The tag distinction is implementation — :type and :term remain distinct surface names with distinct semantics."

### §4.2 Naming precedent (parent §6.1)

> "Coq's `evar_map` has `concl` (goal type) and `body` (optional solution) as separate fields — but Coq stores them in one meta-info record per meta, not two independent stores. Agda/Idris/Lean follow similar patterns. **Realization B matches how elaboration with metavariables is done in the reference systems, rendered in propagator-network terms**."

### §4.3 Provenance is first-class (parent §6.1.1)

Each tagged entry carries `(propagator-id, assumption-id, source-loc)` for first-class compiler + error features. Supports Track 7 + Phase 11b.

### §4.4 Qc resolution (user-confirmed)

Track 7 `that x :term V` is intended as **user-asserted-inhabitant**. User assertions are FIRST-CLASS WRITES to the same store as solver-derivation, with provenance distinguishing source. They:
- Participate in elaboration network like solver writes (provenance, contradiction-on-mismatch, worldview-aware)
- Converge on ONE canonical store via merge (Role B equality-enforce)
- Carry provenance distinguishing source (user assertion vs solver derivation)

**Implication for 4D**: substrate unification should preserve Realization B semantics AND support multi-writer provenance for the user-`that` use case.

---

## §5 Architectural exploration — Approaches A/B/C/D/E

### §5.1 Approach A (universe → attribute-map bridge)

- attribute-map :type CLASSIFIER × INHABITANT canonical (Realization B preserved)
- Universe cell stays as worldview-tagged projection (Phase 9 substrate role unchanged)
- Reverse-bridge propagator: watches universe cell at component-key=meta-id, writes attribute-map :type INHABITANT at meta-pos via `that-write :term`
- Co-installed at typing-propagators.rkt:1786 (between net-b and net-r)
- **FAILED EMPIRICALLY** — see §6

### §5.2 Approach B (universe cell canonical for metas)

- Universe cell value shape extends to `(hasheq meta-id → tagged-cell-value(classify-inhabit-value(CLASSIFIER, INHABITANT)))`
- attribute-map :type at meta-pos retired (universe cell takes over for metas)
- attribute-map :type at non-meta-pos unchanged
- `(that-read am pos :type/:term)` dispatches by `(expr-meta? pos)` (~1.6 ns predicate cost validated)
- Scope: ~1500-2200 LoC

### §5.3 Approach C (attribute-map with worldview-tagging)

- Attribute-map facets (or :type only) extended to support tagged-cell-value worldview-tagging natively
- Universe cells retired for metas
- Single store + worldview-tagging + Realization B + uniform across metas + non-metas
- Largest scope (~2000-3000+ LoC); touches worldview-tagging cascade across attribute-map facets

### §5.4 Approach D (write-through at solve-meta!) — REJECTED

Hook `solve-meta-core!` to ALSO write attribute-map :term. **Rejected on adversarial principles review**:
- Mantra-violating (sequential, imperative, not structurally emergent)
- Cell/Propagator/Scheduler Orthogonality-violating (coordination logic in imperative function, not propagator layer)
- Propagator-First-violating (sidestepping the network)
- Correct-by-Construction-violating (discipline-maintained invariant)
- Decomplecting-violating (solve-meta! gains a second responsibility)

### §5.5 Approach E (retire result-accumulator + read-site migration)

- Retire `make-meta-solution-output-fire-fn` (line 904) and its output cell + parameter
- Replace with end-of-infer `collect-solved-metas-from-universe-cell` helper
- Read-site migrations: trait dispatch (typing-propagators.rkt:766) + output bridge (typing-propagators.rkt:907) read universe cell directly
- (Optional) Write-side consolidation: app-fire-fn and trait-resolution write universe cell instead of attribute-map :term

**User flagged this as suspicious**: retires code we just wrote in Phase 3c-ii of the same track. Architectural whiplash signal. Approach E was a reaction to install-breaks-resolution rather than a principled architectural choice.

### §5.6 Architecture evaluation summary

| Approach | Adversarial principles | Implementation status |
|---|---|---|
| A | Sound IF install can be done without breaking resolution | Failed empirically; install mechanism untested via topology stratum |
| B | Sound; "splits meta vs non-meta architectures" tradeoff | Largest delta to current code; not attempted |
| C | Sound; biggest scope | Touches infrastructure beyond meta-store concern; not attempted |
| D | Fails P/M/S adversarial review | Rejected |
| E | Sound but architecturally suspicious (retires recent work) | Reactive; not principled |

**4D needs its own design cycle to choose among A/B/C** (or a yet-unidentified Approach F). The principled exploration captured here is input, not prescription.

---

## §6 Critical diagnostic finding — install-breaks-resolution

### §6.1 Symptom

Implementing Approach A — adding a reverse-bridge propagator per type meta during `install-typing-network`'s `(expr-meta id _)` case — broke `test-first-rest-01.rkt :: first-of-rest` (composition `first [rest '[1 2 3]]`). All 4 unresolved metas (`?meta3163 ?meta3164 ?meta3165 ?meta3169`) failed to get solved during run-to-quiescence. Simpler tests in the same file (e.g., `first '[1 2 3]`) passed.

### §6.2 Reductions tried (all failed identically)

| Variant | Result |
|---|---|
| Full bridge design (writes :term sol) | 1/15 fails |
| **No-op fire-fn** (`(lambda (net) net)`) | 1/15 fails |
| Fire-once + no-op | 1/15 fails |
| No component-paths declaration | 1/15 fails |
| **Empty inputs `'()`** | 1/15 fails |
| Different input cell (`tm-cid`) | **10/15 fails** (much worse) |
| Bridge AFTER residuation (worklist order) | 1/15 fails |
| TYPING-FUEL-LIMIT bumped 200→2000 | 1/15 fails |
| Install gated off (`if #f`) — baseline | **15/15 PASS** |

### §6.3 Hypotheses ruled out

| Hypothesis | Result |
|---|---|
| Topology-during-fire | **Ruled out** — `(current-bsp-fire-round?)` = #f at every install-typing-network call |
| Fuel exhaustion | **Ruled out** — FUEL=2000 still fails |
| Worklist order (LIFO interaction) | **Ruled out** — install before vs after residuation both fail |
| Component-paths interference | **Ruled out** — declared vs empty both fail |
| Input cell dependency | **Ruled out** — universe-cid OR `'()` both fail |
| Fire-fn side effects | **Ruled out** — pure no-op `(lambda (net) net)` still fails |

### §6.4 Hypotheses UNTESTED (carry forward to 4D)

**Topology stratification (user's primary hypothesis)**: install IS a dynamic topology change. CALM guarantees monotone fixpoint on FIXED topology; install (even pre-BSP) changes topology. The standard on-network pattern for dynamic topology is the topology stratum (`register-topology-handler!` / `register-stratum-handler!` patterns per PAR Track 1 + stratification.md). **This mechanism was not tested in the 1D/1E exploration.** The hypothesis remains open — defer-the-install-to-topology-stratum may resolve the symptom.

### §6.5 Why this matters for PPN 4D

If 4D's grammar-rule compiler emits propagator installations from declarative rules, each install is potentially the same pattern that broke here. 4D needs to either:
- **Diagnose the root cause** of install-breaks-resolution and fix it structurally
- **Adopt the topology-stratum pattern uniformly** for all rule-compiler installs (defer to between BSP rounds via topology request cell)
- **Choose a substrate architecture** (e.g., B or C) where per-meta observer installs aren't required

The diagnostic finding is a **latent constraint on future propagator additions** at install-typing-network's `(expr-meta id _)` case (and possibly other cases — only that case was tested). 4D should expand the diagnostic to cover the broader install surface.

---

## §7 Pre-cleanup commit preserved (Move B+ 2nd instance)

Commit `1340aec8`: retired `with-handlers` wrapper in `resolve-worldview-bitmask` (meta-universe.rkt:288 + propagator.rkt:3877). Both wrappers guarded a structurally-impossible failure (`worldview-cache-cell-id` is cell-id 1, always allocated by `make-prop-network`).

**Independently valuable** (Move B+ pattern, 2nd instance after S2.c-iii):
- Suite wall delta: **−3.8s (3.3%)** at 8224 tests / 110.9s baseline
- M5a `compound-cell-component-ref` solved: 207 → 78.5 ns (−62%)
- M7a `meta-solution` full dispatch: 328 → 173 ns (−47%)
- E2b wv=0 cache-fallback: 209 → 89.8 ns (−57%)
- E2 axis confirmed continuation-marker overhead empirically (127 ns differential)

**Stands as Phase 1V incidental cleanup** — not part of the deferred 1D/1E scope.

**Codification candidate (graduates from watching list)**: defensive `with-handlers` wrappers guarding structurally-impossible failures cost ~100-150 ns per call due to continuation-marker overhead. Retirement is structural per Move B+ pattern.

---

## §8 Durable infrastructure for 4D inheritance

### §8.1 Bench harness

`racket/prologos/benchmarks/micro/bench-attribute-record.rkt` (~700 lines):
- **M-tier (8 micros)**: that-* + compound-cell-component-* + meta-domain dispatch baselines
- **A-tier (5 micros)**: J-A vs J-C simulation + dispatch predicate + specialized-cell-cache LB + memory growth
- **E-tier (12 micros)**: read-state spread + speculation-active vs cache-fallback + cross-facet + arity-2 whole-record
- **R-tier**: realistic workload via process-file (67 commands; ~26% reduce_ms dominance)
- **S-tier**: 6 frozen-value semantic axes for parity baseline

Inherits to 4D for ongoing A/B comparison and Track 4D Phase F/G (`:whnf`, `:reduce`, `:surface` facets).

### §8.2 Baselines

- `data/benchmarks/attribute-record-pre0-baseline-2026-05-17.txt` — pre-cleanup M+A+E+R+S baselines
- `data/benchmarks/attribute-record-post-cleanup-2026-05-18.txt` — post `with-handlers` retirement A/B

### §8.3 Test cases (composition regressions)

`test-first-rest-01.rkt :: first-of-rest` is the canary for the install-breaks-resolution finding. Any architecture 4D adopts should pass this test.

---

## §9 Recommendations for PPN 4D design cycle

When 4D opens its Stage 1-3 cycle, this note's findings can short-circuit several activities:

### §9.1 Stage 1 research (extend, don't restart)

This note covers:
- Realization B architectural framing (Coq/Agda/Idris/Lean precedent)
- Multi-writer + provenance for user-`that` (Track 7)
- Architecture options A/B/C/D/E with principles evaluation
- The install-breaks-resolution diagnostic anomaly

4D Stage 1 may extend with attribute-grammar theory research (Knuth, Reps-Teitelbaum), declarative grammar rule semantics, and grammar-rule compiler design — areas NOT explored here.

### §9.2 Stage 2 audit (this note IS partially the Stage 2)

§3 of this note is much of what a 4D Stage 2 audit would produce for the meta-storage substrate. 4D Stage 2 should ADD:
- Full enumeration of typing rules currently in typing-core.rkt + typing-propagators.rkt (the rules to be lifted to declarative form)
- Sexp-infer retirement scope (typing-core.rkt:440+)
- Unification consolidation surface (PUnify ↔ attribute-equation dispatch)
- Zonking-as-readiness-stratum mapping

### §9.3 Stage 3 design (architectural questions to address)

1. **Substrate architecture choice**: A vs B vs C (vs yet-unidentified F)
2. **Install mechanism**: topology stratum vs other pattern that avoids install-breaks-resolution
3. **Realization B preservation**: how the unified substrate maintains CLASSIFIER × INHABITANT layer distinction
4. **Multi-writer provenance**: how user-`that`, network-propagator, solver writes are distinguished
5. **PM Track 12 coordination**: parameter retirements; module-loading on network
6. **Diagnostic gap closure**: root-cause the install-breaks-resolution anomaly

### §9.4 Independent diagnostic worth doing regardless

Even if 4D never revisits the 1D/1E framing, the install-breaks-resolution finding is a latent architectural constraint. Worth diagnosing in a dedicated session when not blocking active work:
- Expand reductions to non-expr-meta install cases (does ANY extra propagator install break, or only expr-meta?)
- Test topology-stratum deferred-install pattern empirically
- Trace the actual mechanism (PERF-COUNTERS during run-to-quiescence; per-fire instrumentation)

Add to DEFERRED.md as a tracked architectural debt item.

---

## §10 Cross-references

### Design docs
- [PPN 4C Phase 9+ Addendum D.3](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — §7.6.16 sections 1-14 are the canonical record of the 1D/1E exploration
- [PPN Master](2026-03-26_PPN_MASTER.md) — Track 4D row links here
- [PPN 4C Parent D.3](2026-04-17_PPN_TRACK4C_DESIGN.md) — Track 4D row + cross-track context
- [PPN 4D Vision Research](../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md)

### Principles
- [DESIGN_PRINCIPLES.org](principles/DESIGN_PRINCIPLES.org) — Realization B framing, Cell/Propagator/Scheduler Orthogonality
- [CRITIQUE_METHODOLOGY.org](principles/CRITIQUE_METHODOLOGY.org) — adversarial principles framework used in Approach E evaluation
- [stratification.md](../../.claude/rules/stratification.md) — topology stratum mechanism (untested hypothesis)

### Commits
- `1340aec8` — Pre-Phase-1E cleanup (Move B+ 2nd instance); INDEPENDENTLY VALUABLE; stands
- `a214cc7e` — 1D.a design finalized with spike findings (architecturally captured; implementation never landed)
- `9ebd6c3c` — Architecture A confirmation + audit-grounded sub-phase partition
- `b52721c5` — Phase 1D scope + Realization B research + Qc reframe
- `e0fe1aa0` — Pre-0 E+R+S-tier benches
- `88da1b8c` — Pre-0 A-tier benches
- `13d8f7d6` — Stage 2 audit + Pre-0 M-tier baseline

### Dailies
- `2026-05-17_dailies.md` — captures the full session arc including 1D/1E exploration, Approach D adversarial rejection, scope re-thinking, deferral decision

---

## §12 THE READER LAYER — a seed for 4D, added 2026-08-02 from the CIU T6 D4.P4c grounding audit

**Why this belongs here.** 4D's core proposition already names parsing —
*"Parsing, elaboration, typing, QTT, reduction, and zonking become COMPONENT
ATTRIBUTES of the same unified substrate"* — but **no phase in the A–G structure
covers the reader.** Phases A–G run from grammar-rule representation through
reduction-as-`:whnf`; the parse layer is assumed rather than scoped. This
section is the seed for that gap. It is findings, not a design.

### §12.1 The measured state — the parse layer has ZERO propagators

Measured at HEAD (`19ab78a9`) across all seven parse-layer files —
`parse-reader.rkt`, `parse-lattice.rkt`, `tree-parser.rkt`, `surface-rewrite.rkt`,
`form-cells.rkt`, `parser.rkt`, `macros.rkt`: **zero** installs of
`net-add-propagator` / `-fire-once` / `-broadcast` / `elab-add-propagator` /
`-cross-domain` / `register-stratum-handler`.

`parse-reader.rkt`'s complete network surface is **1 `make-prop-network`, 5
`net-new-cell`, 5 `net-cell-write`, 1 `net-cell-read`** — a **cell LEDGER**
written by a straight-line `net1→net6` sequence. `build-tree-from-domains` is
documented as "the fire function for the tree-builder propagator" and is then
**called directly**, never installed.

⚠ **PPN Master rows 1 and 3 were marked ✅ as propagator work.** Both have been
annotated (2026-08-02) rather than un-ticked: the cells, the switchover and the
tests are real; the ON-NETWORK claim is not. This is the project's own mandatory
Network Reality Check failing on a ✅ row, and it is worth reading as a lesson
about the check's placement rather than about those tracks.

### §12.2 The five cells, and the honest lattice picture

`parse-cells` = char · indent · token · bracket · tree.

- The **tree cell's** merge is a genuine join — set-union over derivation sets,
  monotone and idempotent (`parse-lattice.rkt`).
- The **four RRB cells' merge is NOT a lattice operation**: it is a size
  heuristic ("keep larger") with a constant-`#f` contradicts?. Any 4D design
  that leans on "the reader's cells are already lattices" must exclude these
  four, or fix them.

### §12.3 The population fact that reframes cell granularity

PPN Track 1 deferred per-node cells to **Track 8** with the argument *"One cell
is simpler and 300× fewer allocations than per-node cells."* That argument was
costed against **all nodes**. For an attribute that is *sparse*, the relevant N
is the attribute's own population, not the tree's.

Worked example (the CIU T6 `:` disposition attribute): mint sites are **tens**,
not thousands — an independent source-level cross-check found **86 across 163
tracked files, max 31 in any one file**; the audit's instrumented count was
267/max 58. Either way the population is ~0.3% of tokens. And where the
attribute's bottom element means "do nothing", **absence of an entry already IS
bottom**, so no storage is needed for the ~99.7% that never mint.

**Seed for 4D**: attribute-record granularity should be decided **per attribute
population**, not once for the whole tree. The Track 8 deferral answers a
different question than a sparse attribute asks.

### §12.4 There is no node identity, and one collision is by construction

Any per-node attribute keyed on identity must first MINT one:

- **`eq?` does not survive the pass** — syntax objects are rebuilt via
  `(datum->syntax #f kids* stx stx)` whenever anything below them changes.
- **srcloc `(pos,span)` is not unique** — collisions measured in 6/6 sampled
  files (e.g. `data/list.prologos`: 3033 nodes, 3003 distinct).
- **Worse, the collision is structural on exactly the interesting nodes**: a
  sentinel WRAPPER and its own PAYLOAD are minted with identical `(pos,span)`
  by construction. Sentinel-vs-payload is precisely what an attribute over
  wrapped nodes needs to tell apart.

### §12.5 "Per-node" is ambiguous by ~8× — and the tree cell is the wrong target

The binder post-pass operates on **syntax objects**, one level DOWNSTREAM of the
`parse-tree-node`s the tree cell holds, produced by tree→stx conversion. For one
file: **383 parse-tree-nodes vs 3,033 syntax nodes.** The tree cell's contents
are never consulted by the post-pass at all. A design aimed at the tree cell
addresses the wrong population.

### §12.6 The preferred realization already exists in NTT — do not reinvent it

`2026-03-22_NTT_SYNTAX_DESIGN.md` supplies both the storage and the precision
mechanism: an **`:embedded` Pocket-Universe cell** plus **`:diff`** so dependents
fire only for changed entries — *"~1.4 μs/cell × 4000 = 5.6 ms"* for individual
cells versus *"~0.01 ms"* embedded.

⚠ **And the obvious alternative is measured-bad at this scale**: a compound cell
with `:component-paths` goes **quadratic**, because once any dependent declares
component-paths, `net-cell-write` takes the slow path and `pu-value-diff`
rescans the whole merged hasheq on every component write. There is no in-tree
precedent for a compound cell with thousands of components — every production
use is per-domain meta universes at meta scale. This creates a real tension with
`propagator-design.md`'s MANDATORY `:component-paths` rule, which is the very
thing that triggers the quadratic here; no design doc in tree records it.

### §12.7 Three substrate blockers for any defaulting-on-absence stratum

An attribute whose bottom means "do nothing" needs a stratum to act on absence
after quiescence. Three blockers, all verified, none of which appears in
`stratification.md`:

1. **The BSP Tier-1 fast path runs NO strata**, and its eligibility guard reads
   ONLY `naf-pending-cell-id` despite a comment claiming it checks stratum
   requests. A qualifying network fires, clears the worklist and returns —
   `process-tier` is never reached. **It fails silently.** Generalizing that
   guard to consult every registered handler's request cell is a hard
   prerequisite.
2. **Stratum request cells must be pre-allocated by `make-prop-network`** —
   `register-stratum-handler!` errors at module load otherwise. All five parse
   cells are dynamically allocated via `net-new-cell` and would fail the guard.
3. **Stratum handlers are BSP-only.** The Gauss-Seidel path has no stratum
   processing, so a design whose *correctness* depends on a handler is
   scheduler-coupled — a layering violation by `propagator-design.md`'s own
   Cell/Propagator/Scheduler Orthogonality section.

Also load-bearing: **the request cell must hold the INVENTORY of undecided
nodes, not the grants.** `process-tier` SKIPS a handler whose request cell is
empty, so an accumulator holding grants makes the zero-grant case — the default
state — a silent no-op.

### §12.8 What is genuinely new here, stated narrowly

The mechanism (inherited attribute), the stratum shape (defaulting on absence
after quiescence), the cell-granularity question (→ Track 8), the realization
(→ NTT embedded PU + `:diff`), the ambiguity framing (→ **PPN Track 5**,
type-directed disambiguation: *the parser produces multiple parses; downstream
information constrains which survive; the ATMS retracts the rest*) and the
umbrella (→ **4D** itself) all pre-exist.

**Genuinely new: applying that stack to the READER/tree layer**, where zero
propagators exist today and where 4D's own prerequisites (4C complete + T-3 +
PM Track 12) are not met. This section exists so that when 4D opens, the reader
layer is a scoped phase rather than a rediscovery.

⚠ **Prior-art discipline note.** This section was written only after an audit
established the above; the same arc had already logged *"the third prior-art
miss of the D4.P4 arc"*, and a proposal to open a NEW track for this work would
have been the fourth. Search by CONCEPT before claiming novelty in this area —
it has four chartered homes.

---

## §11 Closing note

The 1D/1E exploration was technically extensive (Stage 2 audit + bench harness + research + spike + multiple architecture iterations + diagnostic reductions) but produced a clearer understanding than a finished implementation: this work belongs in PPN 4D's substrate-unification charter, not the Phase 9+ addendum's substrate+orchestration scope. The deferred sub-phases represent honest architectural humility — recognizing the wrong scope and capturing forward — rather than abandonment.

The Phase 9+ addendum resumes at Phase 2 (orchestration unification — registering S(-1)/L1/L2 as BSP stratum handlers).
