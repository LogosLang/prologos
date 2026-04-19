# PPN Track 4C — External Critique

**Date**: 2026-04-18
**Design under review**: [`2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) (D.2, self-critique round closed 2026-04-18, commit `a9027740`)
**Prior context**: [Self-Critique](2026-04-17_PPN_TRACK4C_SELF_CRITIQUE.md), [Audit](2026-04-17_PPN_TRACK4C_AUDIT.md), [Pre-0 Report](2026-04-17_PPN_TRACK4C_PRE0_REPORT.md), [D.2→External Handoff](handoffs/2026-04-18_PPN_4C_D2_EXTERNAL_CRITIQUE_HANDOFF.md)
**Methodology**: [`CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org) §4 (critic orientation) + §5 (grounded pushback)
**Purpose**: Independent critique of D.2. Findings drive D.3.
**Status**: Findings issued. Responses pending (dialogue).

---

## Orientation Applied

Per §4, this critique evaluates D.2 from a propagator-mindspace: information flow on cells to a fixpoint, not sequential algorithmic steps. Findings are tagged by lens — **P** (Principles Challenged), **R** (Reality-Check / Code Audit), **M** (Propagator-Mindspace), **S** (SRE Lattice Lens), **C** (Composition / Phase Ordering). Issues the self-critique round closed (per handoff §3) are NOT re-opened unless a genuinely new angle emerges — the three findings that touch closed ground are explicitly labeled.

Response format for each finding (§5):
- **Accept** (finding and proposed resolution both align)
- **Accept problem, reject solution** (real gap, wrong fix — name alternative)
- **Reject with justification** (premise false or principle violated — cite code/principle)
- **Defer with tracking** (valid, out of scope — DEFERRED.md reference)

Response slots are left empty under each finding for the dialogue.

---

## Findings

### P1 — "Validated but not deployed" risk around Option A / Option C phasing

The design places Option A (tree walk reading `:term` facet) at Phase 8 and Option C (cell-refs, zonk retirement) at Phase 12, with five intervening phases (9 cell-based TMS, 9b γ hole-fill, 10 union types, 11 elaborator strata→BSP, 11b diagnostic). During that span, `zonk.rkt`'s tree walk persists as a staging scaffold while the network substrate grows around it. [workflow.md](../../.claude/rules/workflow.md) flags "validated but not deployed" and "keeping the old path as fallback" as red-flag phrases demanding principle scrutiny; [DEVELOPMENT_LESSONS.org](principles/DEVELOPMENT_LESSONS.org) "Validated Is Not Deployed" codifies the rule.

D.2 labels Option A as "staging, not terminal architecture" (§6.6) — which is correct discipline — but does not bound the staging lifetime structurally. A five-phase window where both `:term`-reading tree walk AND the eventual cell-ref path will co-exist (briefly, at Phase 12 cutover) is the exact belt-and-suspenders shape the rule exists to prevent. The self-critique closed the "both in scope" question but did not address the staging duration risk.

**Proposed resolution**: either (a) commit to deleting `zonk.rkt` entirely at Phase 8, routing all readers to a single cell-reference API from the start (Phase 12 becomes an expression-representation change rather than a retirement); or (b) bound the staging window by requiring Phase 12 to land in the same working week as Phase 8, with a named integration test that fails if both code paths still execute on the same input.

**Response**: **Reject with justification** (2026-04-18). Phase 12 is sequenced to arrive soon enough after Phase 8 that the staging window does not accrete belt-and-suspenders risk. The intervening phases (9, 9b, 10, 11, 11b) are building the substrate that makes Phase 12 feasible; they are not optional detours. No action.

---

### P2 — Registration surface proliferation vs. Progressive Disclosure / Ergonomics

D.2 introduces (or extends) multiple registration APIs: `register-typing-rule!` (existing), `register-stratum-handler!` (existing), `register-merge-fn!/lattice` (new, §6.8), SRE domain registration via `register-domain!` (existing, extended to facets in Phase 2), `hasse-registry` primitive (new, §6.12 / Phase 2b), `register-constructor-for-hole-fill!` (implied by §6.2.1, new), and the Phase 1 registration-time `:component-paths` enforcement point.

Each is individually principled. Collectively, extension — adding a new AST kind with full 4C treatment — now requires four to six coordinated registrations. [DESIGN_PRINCIPLES.org](principles/DESIGN_PRINCIPLES.org) Ergonomics: "The hard thing we built by the principle of Completeness must be easy to reach for and use — or better, automatically subsumed into the infrastructure itself." Progressive Disclosure: "A user productive on day one... the full power reveals itself gradually."

The principles tension: Correct-by-Construction (each registration enforces one structural property) pulls toward more APIs; Ergonomics pulls toward one. D.2 does not address whether a unifying meta-registration — e.g., a single `declare-form` that derives typing-rule, SRE domain, component-paths, and (eventually) grammar-form entries from one source — is pursuable inside 4C or deferred to Track 7.

**Proposed resolution**: add a §6.14 "Registration API Surface" subsection that inventories the post-4C registration APIs, labels each with its structural obligation, and either (a) proposes a unifying `declare-form` macro as a Track 7 deliverable with 4C ensuring all registrations are derivable from one record, or (b) justifies the multi-API surface as irreducibly separate concerns.

**Response**: **Defer with tracking** (2026-04-18). The underlying concern is real — registries need to go on-network and a unified registration API would be valuable. But this is cross-series scope: on-network registries are PM series territory (PM Track 12 "module loading on network"), and the unified API is even broader. Not 4C scope; not even PPN series scope. A note is already believed to exist in PM series docs. 4C proceeds with the existing registration APIs; PM series carries the unification.

---

### P3 — "Walks" / step-think residue in Phase 6 (Aspect-coverage)

Per the handoff §4.2, "walks" step-think has twice slipped into the design and been caught. Phase 6 (A3, Aspect-coverage completion) reads in D.2 §6.6 and Audit §5.3 as "enumerate uncovered AST kinds, register typing-rule per kind." The *process of extension* is described in the plural-imperative ("enumerate... register... register... register"), which is fine as a work description — but the *mechanism of coverage* is not described as a lattice property. What happens when an uncovered AST kind appears at elaboration time? Today it falls through to `infer/err` (49 sites per Audit §2.8). Post-Phase-6, is coverage a structural property (registry exhaustiveness check at network-build time, missing coverage = contradiction cell write) or a discipline property (we think we covered everything; if not, fallback still catches it)?

If discipline: Phase 6 is scaffolding against human error, not correct-by-construction. If structural: the mechanism needs to be named — likely a `coverage-lattice` cell with a merge function that produces `type-top` (contradiction) when an AST kind has no registered propagator AND appears in an elaboration request.

**Proposed resolution**: make Phase 6 produce a *structural* coverage guarantee, not an *enumerated* one. Add a coverage cell (an instance of the aspect-coverage lattice) that propagators' registrations write to. A missing registration yields a contradiction when the AST kind appears, with a concrete error location for the uncovered kind. This eliminates `infer/err` as a concept rather than shrinking its footprint.

**Response**:


---

### P4 — Lazy residuation check: reentrant merge is a hidden ordering

Self-critique M5 (closed) specified the residuation check fires synchronously within the merge when `cross-tag-present AND (CLASSIFIER-narrowed OR INHABITANT-narrowed)`. The closure answered the "when does it fire" question. It did not address: **what if the synchronous check itself produces writes that would trigger another merge on the same cell?** Concretely: the check detects that a cross-tag is inhabited → narrows the classifier → writes → merge invoked → check fires again on the narrowed state.

Two concerns. First, reentrant merge execution violates the "merge is pure" contract if the recursion is not bounded structurally. Second, the ordering of the inner writes relative to the outer merge-round is an imposed ordering disguised as dataflow — exactly the step-think pattern [CRITIQUE_METHODOLOGY.org](principles/CRITIQUE_METHODOLOGY.org) M3 catches.

This is adjacent to closed ground (M5 closed "lazy vs eager") but is a new angle: the *mechanics* of synchronous execution inside merge, not the laziness decision. Worth reopening that narrow slice.

**Proposed resolution**: specify merge-reentrancy policy explicitly. Two viable positions: (a) check may write, but only to cells other than the one being merged — a structural constraint checkable by the registration-time enforcement (Axis 8); (b) check cannot write inside merge — it emits a topology request that the stratum handler processes between rounds. The second is more principled (merge stays pure); the first is cheaper. Pick one and state why.

**Response**:


---

### R1 — "101 call sites, 37 merge functions" figures need reproducible commands

D.2 §6.8 and Self-Critique R1 state the production-only scope as 101 `net-new-cell` sites using 37 merge functions. The reframe from 666 was accepted (Self-Critique §8 summary item 2). But the grep command that produced 101 / 37 is not cited in D.2 or in the self-critique. Per Reality-Check discipline ([CRITIQUE_METHODOLOGY.org](principles/CRITIQUE_METHODOLOGY.org) § R): "If a Stage 2 document says '~N sites' without grep evidence, it is incomplete."

Reproducibility matters because Phase 1 of implementation will re-run the audit ([Implementation Protocol step 1 in DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org)). A drift between the design's 101 and Phase 1's actual count signals either code churn since the D.2 audit or an undercount in the original grep.

**Proposed resolution**: append a "Reality-Check artifacts" appendix to D.2 listing the exact grep/rg commands, file inclusion patterns (production-only = which directories), and expected output counts for each quantified claim (101 sites, 37 merge functions, top-10 coverage 70%, 79 `solve-meta!`, 513 `zonk.rkt` reads, 49 `infer/err`, 75 unregistered AST-kinds).

**Response**:


---

### R2 — Phase 12 cost vs. pipeline-rules.md

`expr-meta` → `expr-cell-ref` is a new AST node. Per [`.claude/rules/pipeline.md`](../../.claude/rules/pipeline.md) "New AST Node" checklist, this touches 14 files: syntax, surface-syntax, parser, elaborator, typing-core, qtt, reduction, substitution, zonk, pretty-print, and possibly unify, macros, foreign. D.2 §6.6 describes Phase 12 at a high level ("reading the expression IS zonking") but does not itemize the 14-file cascade, and the Progress Tracker enumerates Phase 12 as a single checkbox.

If "Phase 12 touches expression representation" is compressed into one phase, the standard phase-boundary discipline ([workflow.md](../../.claude/rules/workflow.md) "Phase completion is a BLOCKING checklist") may not be respected — tests, tracker, dailies, vision-alignment gate — since the work's shape is pipeline-wide rather than phase-sized.

**Proposed resolution**: split Phase 12 into sub-phases along pipeline natural joints: 12a (syntax + parser + elaborator structurally introducing `expr-cell-ref`), 12b (typing-core + qtt + reduction + substitution semantics), 12c (zonk retirement + pretty-print + unify updates), 12d (integration + benchmarks + final acceptance). Each sub-phase completes the 5-step checklist independently.

**Response**: **Accept problem, refine premise, accept split** (2026-04-18). The finding's 14-file cascade premise is stale — Tracks 2 deleted `reader.rkt`, 3 retired `parser.rkt` from WS dispatch, 4A/4B moved typing 90% on-network via `typing-propagators.rkt`. Real Phase 12 surface is ~19 files / 104 `expr-meta` occurrences, dominated by `zonk.rkt` wholesale deletion (~1,300 lines) rather than an AST-node cascade.

The split is still warranted — not on pipeline-surface grounds but on `workflow.md` "conversational implementation cadence" grounds (work-volume dense). Adopted split:

- **12a** — Introduce `expr-cell-ref` struct + dereferencing primitive (no call-site changes).
- **12b** — Flip `expr-meta` construction to `expr-cell-ref`; readers dereference through the new API.
- **12c** — Delete `zonk.rkt` wholesale + driver `freeze-top`/`zonk-top` plumbing.
- **12d** — Acceptance (L3) + A/B bench + integration.

D.2 updated: Progress Tracker §2 rows, Phase dependency graph, and §6.6 pipeline-impact subsection all refined to the post-2/3/4A/4B state. `.claude/rules/pipeline.md`'s "14-file pipeline" framing is separately stale and should be updated in a follow-up (not 4C scope — PPN series housekeeping).

---

### R3 — Two elaborator orchestrators: is retirement inventory complete?

Audit §2.4 documents TWO elaborator orchestrators: `run-stratified-resolution!` ([metavar-store.rkt:1863](../../racket/prologos/metavar-store.rkt)), labeled "Mostly dead code — superseded by run-stratified-resolution-pure", AND `run-stratified-resolution-pure` ([metavar-store.rkt:1915](../../racket/prologos/metavar-store.rkt)), the production path. D.2 Phase 11 commits to retiring the latter. The former's status is ambiguous — labeled dead but retained as "test-path fallback."

Two concerns. (1) Post-Phase-11, is `run-stratified-resolution!` also deleted, or does it linger as the comment claims? Dead code that "can't be deleted yet" is a concrete instance of the belt-and-suspenders pattern. (2) Are there CALLERS of `run-stratified-resolution!` that would need migration? An audit grep for the symbol name would answer this.

**Proposed resolution**: Phase 11 plan must name BOTH orchestrators and commit to deleting BOTH. If any caller remains, name it in the phase plan. If the comment ("superseded by pure") is correct and there are no callers, delete at Phase 11 start as a hygienic prelude.

**Response**:


---

### R4 — Phase 5 (Warnings) scope is under-measured

Audit §2.6 cites [warnings.rkt:62, 122, 129](../../racket/prologos/warnings.rkt) as the dual-store anchor: parameter at line 122, cell at line 62, dual-write emit at line 129. Design Phase 5 (A6) retires the parameter. But the reader surface is unspecified — "downstream reads from both paths" (Audit §2.6) does not tell us how many, where, or what the risk profile is.

For a phase explicitly flagged low-risk ("Axis 6 — low" in Audit §5.6), the R-lens requires the actual numbers. Track 4 §3.4b is the cautionary example: zonk retirement was also "low-risk" until it wasn't.

**Proposed resolution**: add to D.2 §6.5 (or wherever Phase 5 is detailed) the grep-backed reader inventory: every `(current-coercion-warnings)` read, every `warnings-cell-read` or equivalent, and the specific call sites in `driver.rkt` and elsewhere.

**Response**:


---

### R5 — Phase 2 A9 "find ≥1 lattice bug" is a budget without a schedule

D.2 (per handoff §5.3) says Phase 2 expects "find ≥1 lattice bug (per Track 3 §12 + SRE 2G precedent)." Accepting this as a probabilistic expectation is fine for risk framing, but it does not translate into phase planning: if a bug is found, does Phase 2 fork a repair sub-phase? If three bugs are found, does the phase window extend? If zero bugs are found, is that a signal that property inference is too weak?

**Proposed resolution**: codify a "Phase 2 contingency": up to K lattice bugs are absorbed into Phase 2 with no replanning; K+1 or more opens a Phase 2b repair stratum. State K explicitly (suggest K=2 based on prior-track observation). Also: if zero bugs are found, mandate a property-coverage review — the precedent predicts at least one, so zero means either we got lucky or property inference isn't catching what it should.

**Response**:


---

### M1 — Phase 7 parametric resolution: impl REGISTRATION is off-network?

§6.5 + §6.12 put parametric trait resolution on-network via per-(meta, trait) propagators reading a Hasse-indexed impl registry. But when a module loads and registers a new `impl Foo List` via the user surface or a library prelude, is that registration a *cell write* to the Hasse registry, or an imperative `register-impl!` call?

If imperative: the *runtime* resolution is on-network, but the *structural growth* of the registry is off-network. The design's on-network claim is contingent on assuming the registry is a fixed set during elaboration — which is true per command but violates the mantra across module loads. Track 2B Phase R4 + PM Track 12 have already established that module-load-time infrastructure must go on-network for self-hosting.

**Proposed resolution**: D.2 should specify the impl-registration path as a cell write — likely `impl-registry-cell` with hash-union merge, component-indexed by trait name. The `impl X Y` surface form compiles to a registration write; the Hasse-registry propagator recomputes the Hasse-index on change. If registration-as-cell-write is out of scope for 4C (PM Track 12), label it explicitly as scaffolding to retire, not silently rely on "registration happens at module load."

**Response**: **Accept problem, defer decision to Phase 7 mini-design** (2026-04-18). The decision-point is real and the handoff's silence on it was a gap. But no earlier phase constrains the choice — Phase 2b (Hasse-registry primitive) is lattice-agnostic; Phases 1, 3, 4, 5, 6 do not touch impl-registry semantics. So the decision is a genuine Phase 7 mini-design concern rather than a D.2 obligation.

One adjacency captured: **Phase 9b** (γ hole-fill, constructor inhabitant catalog) faces the symmetric question. Both are Hasse-registry instantiations; their registration-write paths should be consistent. Phase 7's mini-design chooses; Phase 9b inherits.

D.2 updated: Phase 7 and Phase 9b Progress Tracker rows now name the registration-write-path as an explicit mini-design decision with cross-reference. Options at mini-design time will be (a) cell-write with hash-union merge, or (b) imperative `register-impl!`/`register-constructor!` labeled as scaffolding owned by PM Track 12 (mirrors the P2 resolution).

---

### M2 — Phase 10 ATMS fuel is an imperative counter

Self-Critique closed Q5 with "fuel 100 suffices." Closed. But the *mechanism* of fuel — is it a decrementing integer attached to the ATMS context? If so, fuel enforcement is a `(set! fuel (sub1 fuel))` pattern wearing a propagator mask. [on-network.md](../../.claude/rules/on-network.md) red-flag: "mutable state tracking progress." The fuel value itself should be a cell with a tropical-semiring merge (min), and fuel exhaustion should be a contradiction cell write, not a counter-reached-zero check.

This is adjacent to closed ground (fuel bound value = 100) but is a new angle: the fuel bound *representation*, not its numeric value. Worth addressing.

**Proposed resolution**: specify fuel as a tropical-lattice cell in D.2 §6.7 (Phase 10). The cell's value is "remaining fuel"; min-merge ensures any fork can only *decrease* fuel. Reaching 0 fires a fuel-exhausted contradiction, which is structurally indistinguishable from any other contradiction cell write. No imperative counter.

**Response**:


---

### M3 — Phase 9b γ hole-fill: what fires when the catalog grows?

D.2 §6.2.1 (per handoff) reframes γ as "reactive propagator with Hasse-indexed catalog" — good, the "walks" step-think was eliminated. New concern: the catalog can *grow* during a session (new constructors registered, new type families imported). When the catalog grows, do existing γ propagators re-fire for holes they previously "saw" as non-fillable? Per [on-network.md](../../.claude/rules/on-network.md) § Topology Requests, structural growth is a topology-stratum request.

If γ propagators don't re-fire on catalog growth, hole-fill is silently stale when new constructors arrive. If they DO re-fire, the re-firing trigger needs specification — is it a component-path watch on the catalog cell, or a topology request per hole, or a broadcast propagator keyed by hole position?

**Proposed resolution**: specify the re-firing trigger in §6.2.1. Recommendation: the γ propagator watches the catalog cell via `#:component-paths` (keyed on the hole's type), so a catalog write fires only γ propagators for holes whose types were newly matched.

**Response**:


---

### M4 — Phase 11b diagnostic: "backward residuation" needs to be a cell or a propagator

§3.10 (provenance as structural emergence) and Phase 11b (diagnostic infrastructure) commit to "error reporting via backward residuation on the Module-Theoretic chain." Per [MODULE_THEORY_LATTICES.md](../research/2026-03-28_MODULE_THEORY_LATTICES.md) §5, residuation is an algebraic operation — forward propagator f; backward residual f\\v. It is NOT automatically a propagator. The question: when a contradiction fires in a cell, does an error propagator fire to emit a message, or is the error message *data* derived from the cell's provenance metadata at read time?

If propagator: the error propagator's installation discipline (where, reads-what, writes-what) is unspecified in D.2. If data at read time: the read API for "explain this contradiction" needs a sketch.

**Proposed resolution**: pick the path. Recommendation: contradiction cells carry a provenance tag (ATMS assumption bits + `:trace` slice); a single `explain-contradiction(cell-id)` function reads the tag and walks the dependency graph backward to produce a human-readable chain. The walk IS structural navigation on the proof object — not a propagator. Phase 11b's NTT model should show the contradiction cell → `explain-contradiction` read path as an interface, not a `propagator`.

**Response**: **Accept problem, accept lean toward (b), deepen mini-design with research input** (2026-04-18). The shape question is real and D.2 §3.10 closure didn't resolve it. Accepted lean: **read-time derivation (option b)** — `derivation-chain-for(position, tag)` is a read-time function over the dependency graph; no error-propagator fires on contradiction. Rationale captured in §6.1.1 addendum: transient contradictions (speculation, ATMS retractions) would create propagator noise; proof-object IS the data per §3.10 closure; Data Orientation + Most General Interface favor one read-time function over propagator-plus-output-cell wiring.

**Research input to Phase 11b mini-design — trace monoidal categories** (user direction 2026-04-18). The backward-residuation framing has formal grounding through traced symmetric monoidal category theory: propagator networks form a traced SMC (cells tensor, propagators morphisms, cell feedback is trace); provenance IS the trace morphism of the contradiction path; backward residuation IS the adjoint structure of the trace. Classical references added to §6.1.1 and Progress Tracker row 11b: Joyal-Street-Verity 1996 (axiomatization); Hasegawa 1997 (trace ↔ recursion correspondence, directly relevant to cyclic-sharing propagator fixpoints); Abramsky-Haghverdi-Scott 2002 (Geometry of Interaction). Consume before Phase 11b mini-design finalization.

D.2 updated: §6.1.1 architectural-shape paragraph + research-input paragraph; Progress Tracker row 11b carries the lean + research pointer.

---

### S1 — TermFacet lattice: bot, join, top not specified

D.2 §6.1 restructures `:type`/`:term` as tag-layers on a shared TypeFacet carrier. The self-critique closed that framing choice. But the TermFacet *lattice itself* — what is bot, join, top — is underspecified in D.2's §6.1. TypeFacet is a Track 2H quantale (union-join ⊕ + tensor ⊗). Is TermFacet the same quantale? Or a different lattice?

If same: the carrier hosts one quantale with tag-layers distinguishing "classifier role" vs "inhabitant role" — merges compose cleanly. If different: we need a TermFacet algebraic structure definition, and the merge on the carrier cell needs to switch on tag to select the right operation. This is the SRE lens Q2 question (Algebraic properties) and Q3 (Bridges) that D.2 does not explicitly answer.

**Proposed resolution**: add a §6.1.2 "TermFacet Lattice Specification" stating bot (unsolved), join (most-specific-common-solution, i.e., structural unification meet), top (contradiction), AND the relationship to TypeFacet. Recommend: TermFacet IS the same quantale as TypeFacet, with tag-layer distinguishing roles — making the "`:type` and `:term` are residual partners" claim (§3.8) algebraically clean.

**Response**: **Accept problem, defer decision to Phase 3 mini-design** (2026-04-18). The ambiguity between reading (i) "one quantale, role-tagged entries — residual partners algebraically clean" and reading (ii) "distinct TermFacet lattice bridged via `type-of-expr`" is real; §6.2's merge spec as written leans (ii), §3.8's framing leans (i). Rather than pick in D.2 without implementation context, the choice belongs in Phase 3's mini-design alongside the facet-split work itself.

Mini-design obligations at Phase 3: (a) choose reading (i) or (ii) with rationale; (b) state TermFacet bot/join/top explicitly regardless of reading; (c) if (ii), name the `type-of-expr` bridge and its α-equivalence-respecting meet; (d) produce SRE lens Q2 (algebraic properties) + Q3 (bridges) answers for the chosen reading.

D.2 updated: Progress Tracker row 3 carries the S1 mini-design obligation list.

---

### S2 — `:constraints` by trait: tagged merge distributivity?

`:constraints` is decomposed by trait tag (Module Theory Realization B, per §6.5). Each trait's constraints form a sub-lattice. The carrier merge combines per-trait writes via tag-keyed union. SRE lens Q2: is the merge distributive across trait tags? I.e., does `merge((T1:A) ∪ (T2:B), (T1:C)) = (T1: merge(A, C)) ∪ (T2: B)`?

If yes (expected, since each tag is an independent sub-lattice): distributivity enables per-trait propagators to fire independently and compose safely. If no (e.g., if a constraint interacts across traits via `:includes` — though `DESIGN_PRINCIPLES.org` says trait hierarchies are forbidden): cross-trait semantics need spelling out.

**Proposed resolution**: add a §6.5.1 stating the distributivity property explicitly and citing the "No Trait Hierarchies" principle as the reason the per-trait sub-lattices are genuinely independent. This closes the SRE Q2 question structurally.

**Response**:


---

### S3 — Hasse-registry (§6.12): Hasse diagram of WHAT lattice?

§6.12 abstracts a "Hasse-registry primitive parameterized by lattice L" used by Phase 7 (impl registry) and Phase 9b (inhabitant catalog). SRE lens Q6 (Hasse diagram / compute topology) requires specifying the lattice. For the impl registry: is the lattice "impl specificity" (most-general impl ≤ most-specific), with meet = shared common generalization? For the inhabitant catalog: is the lattice "constructor subsumption" (parent constructor ≤ refined constructor)?

The two use cases likely have *different* lattices. "Parameterized by L" is the right abstraction — but D.2 should state, for each use case, what L *is*. Otherwise the primitive is a type variable in the design, not a commitment.

**Proposed resolution**: §6.12 gets a concrete-instantiation subsection showing L_impl (for Phase 7) and L_inhabitant (for Phase 9b) — with bot/meet/join spelled out for each. Phase 7 and Phase 9b then instantiate the primitive with their respective L.

**Response**:


---

### C1 — Phase 6 before Phase 7: coverage-first or resolution-first?

Phase 6 (aspect-coverage completion) is scheduled before Phase 7 (parametric trait resolution). But parametric resolution operates on AST kinds that include trait-bearing constructors (lists, maps, pairs, etc.). If Phase 6 is *fully complete* before Phase 7 starts, Phase 7 has a stable substrate. If Phase 6 is *partial* when Phase 7 starts (e.g., uncovered union-type-specific forms remain), Phase 7 must handle half-covered kinds.

D.2 Progress Tracker treats the phases as sequential but does not specify whether Phase 6 is a *quiescence point* (all covered before moving on) or a *rolling deliverable* (covered enough for Phase 7's needs).

**Proposed resolution**: state Phase 6 as a quiescence point — "Phase 7 does not start until coverage cell has no ⊥ entries for AST kinds reachable from the Phase 7 test set." Alternatively, if rolling: identify the coverage subset that Phase 7 actually depends on and require that subset at Phase 6's gate.

**Response**:


---

### C2 — Phase 9 (cell-based TMS) vs. existing ATMS: replace or augment?

D.2 Phase 9 delivers BSP-LE 1.5 cell-based TMS. The existing ATMS (used in worldview speculation, discrimination, S1 NAF) predates this. Does Phase 9 REPLACE the old ATMS infrastructure, or does the old ATMS remain for its existing use cases while the new cell-based TMS handles Phase 10 union types?

If replace: the existing ATMS tests and call sites need migration — an R-lens inventory is missing from D.2. If augment: two TMS mechanisms coexist, which is exactly the "dual paths" anti-pattern.

**Proposed resolution**: state the target explicitly. Recommendation: Phase 9 delivers the cell-based TMS as the *only* TMS substrate; existing ATMS call sites migrate in Phase 9. If migration is large enough to warrant its own sub-phase (say, >50 call sites), split into Phase 9a (build) + 9b (migrate) — renumbering the existing 9b γ hole-fill to 9c.

**Response**:


---

### C3 — Phase 11 and Phase 11b: same phase number, sequential or parallel?

Progress Tracker lists Phase 11 (elaborator strata→BSP) and Phase 11b (diagnostic infrastructure). Same numeric, different letters — in other tracks (e.g., Phase 6 / 6b in Track 4B) this notation has meant "sub-phases of one logical unit." Here, elaborator-strata→BSP (orchestration change) and diagnostic-infrastructure (error-reporting build-out) seem logically independent, not parent/child.

**Proposed resolution**: renumber. If they're parallel: Phase 11 (strata→BSP) and Phase 13 (diagnostic). If sequential: state which first and why. Rationale: phase numbering should reflect logical structure, not arrival order of the sub-designs.

**Response**:


---

### C4 — Dedicated test phase (Phase T) scope is under-specified

[`workflow.md`](../../.claude/rules/workflow.md) "Dedicated test phase is MANDATORY." D.2 includes Phase T. But Phase T's deliverable is "test files" without enumeration. Per the workflow rule, Phase T should name the test files and the coverage target for each. Missing specification risks Phase T becoming a catch-all residual phase rather than a structured deliverable.

**Proposed resolution**: Phase T gets a subsection listing the planned test files: `test-attribute-tag-layers.rkt`, `test-hasse-registry.rkt`, `test-parametric-resolution-propagator.rkt`, `test-union-atms.rkt`, `test-cell-ref-expressions.rkt`, `test-elaboration-parity.rkt` (already named in §9), etc., with per-file coverage goals tied to axes.

**Response**:


---

### Cross-cutting observation — External-critique angle that would NOT be accepted

One finding I considered and am NOT issuing, with justification: a domain expert in compiler engineering might suggest "replace the nested hasheq attribute-map with a hash-consed trie for O(1) shared-subtree identity." This would be [CRITIQUE_METHODOLOGY.org](principles/CRITIQUE_METHODOLOGY.org) § Anti-Patterns "Steering Toward Algorithms" — a data-structure optimization INSIDE the cell value, not a replacement for the propagator architecture. It could be a future micro-optimization but is not a design-level finding and would get an **accept-problem-reject-solution** response with "measure first, optimize later" as the counter. Noting here to show the lens was applied.

---

## Summary for Dialogue

**17 findings across lenses**: P (4), R (5), M (4), S (3), C (4), minus 1 cross-cutting non-finding.

**Highest-priority for dialogue** (largest design impact if accepted):
- **P1** (staging duration risk — Option A/C phasing)
- **R2** (Phase 12 split into 12a/b/c/d)
- **M1** (impl registration path — on-network or scaffolding?)
- **M4** (Phase 11b error-propagator vs. read-time)
- **S1** (TermFacet lattice specification)
- **C2** (Phase 9 replace-or-augment ATMS)

**Likely quick resolutions** (mostly documentation / explicit statement):
- R1 (grep commands appendix)
- R3 (name both orchestrators for retirement)
- R4 (warnings reader count)
- S2 (distributivity statement)
- S3 (L_impl / L_inhabitant instantiation)
- C3 (renumber 11b)
- C4 (enumerate Phase T files)

**May trigger principle-based pushback** (algorithmic framing creeping in):
- P2 (registration surface — may be irreducible)
- P3 (Phase 6 coverage — structural vs. enumerated)
- P4 (merge reentrancy — principled choice needed)
- M2 (fuel representation — the closed "100" was numeric, the representation is new)
- M3 (γ re-firing on catalog growth)

Responses and design updates feed D.3. Per [CRITIQUE_METHODOLOGY.org](principles/CRITIQUE_METHODOLOGY.org) §5.2, each response is one of: Accept / Accept problem, reject solution / Reject with justification / Defer with tracking.
