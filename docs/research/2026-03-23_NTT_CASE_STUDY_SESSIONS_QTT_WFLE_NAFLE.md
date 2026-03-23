# NTT Deep Case Studies: Sessions, QTT, WF-LE, NAF-LE

**Stage**: 1 (Case Study)
**Date**: 2026-03-23
**Purpose**: Complete the NTT case study program. Four remaining systems
modeled in NTT syntax. Each reveals different NTT features and gaps.

---

## Part A: Session Types

### A.1 Lattice (Structural)

```prologos
data SessionExpr
  := sess-bot
   | sess-send [payload : TypeExpr] [cont : SessionExpr]
   | sess-recv [payload : TypeExpr] [cont : SessionExpr]
   | sess-dsend [payload : TypeExpr] [cont : SessionExpr]   ;; dependent
   | sess-drecv [payload : TypeExpr] [cont : SessionExpr]   ;; dependent
   | sess-async-send [payload : TypeExpr] [cont : SessionExpr]
   | sess-async-recv [payload : TypeExpr] [cont : SessionExpr]
   | sess-choice [branches : Map Symbol SessionExpr]
   | sess-offer [branches : Map Symbol SessionExpr]
   | sess-mu [body : SessionExpr]    ;; recursive session
   | sess-end
   | sess-top
  :lattice :structural
  :bot sess-bot
  :top sess-top
```

**Implementation status**: NETWORK-NATIVE.
- `session-lattice-merge` is the merge function (pure)
- Structural: `send+send` merges payloads + continuations recursively
- Polarity conflict (send vs recv) = `sess-top` (contradiction)
- `sess-meta` unsolved metas in CHAMP (same pattern as type metas)

**NTT observation**: SessionExpr is a structural lattice like TypeExpr
and TermValue — merge involves recursive decomposition of sub-fields.
`:lattice :structural` applies. The SRE handles decomposition of
`send/recv/choice/offer` into payload + continuation sub-cells.

### A.2 Duality as Involution

```prologos
;; Duality is a type-level involution: dual(dual(s)) = s
;; It swaps polarities: send ↔ recv, choice ↔ offer, end ↔ end

spec dual SessionExpr -> SessionExpr
  :where [Involution dual]    ;; dual ∘ dual = id

;; In the network: a duality propagator maintains the invariant
;; that two cells hold dual session types

propagator duality-check
  :reads  [client : Cell SessionExpr, server : Cell SessionExpr]
  :writes [client : Cell SessionExpr, server : Cell SessionExpr]
  ;; Bidirectional: when client refines, write dual to server and vice versa
```

**Implementation status**: NETWORK-NATIVE.
- `add-duality-prop` creates bidirectional duality propagators
- Two propagators per duality constraint (forward + backward)
- Fires on every change, maintaining dual invariant monotonically
- Contradiction when polarity mismatch detected

**NTT observation**: Duality is a **structural involution** on the
session lattice. The `:where [Involution dual]` captures the law
`dual(dual(s)) = s`. The NTT's `:where` mechanism handles this —
the compiler verifies the involution law.

The duality propagator is bidirectional — it reads AND writes both
cells. This is the `structural-unify` pattern applied to duality
instead of equality. The SRE could derive duality propagators from
the `dual` function definition, just as it derives unification
propagators from type constructors.

### A.3 Decomposition Propagators

```prologos
;; Each session operation decomposes one protocol step

propagator session-send-decompose
  :reads  [session : Cell SessionExpr]
  :writes [cont : Cell SessionExpr]
  ;; If session = send(A, S'): write S' to cont
  ;; If session = bot: residuate

propagator session-recv-decompose
  :reads  [session : Cell SessionExpr]
  :writes [cont : Cell SessionExpr]

propagator session-select
  :reads  [session : Cell SessionExpr]
  :writes [cont : Cell SessionExpr]
  ;; Read choice branches, extract label's branch

propagator session-offer-decompose
  :reads  [session : Cell SessionExpr]
  :writes [conts : Cell SessionExpr ...]  ;; one per branch
  ;; Fan-out: each branch gets its own continuation cell

propagator session-stop
  :reads  [session : Cell SessionExpr]
  :writes []  ;; asserts session = end; contradiction otherwise
```

**Implementation status**: ALL NETWORK-NATIVE.
- `add-send-prop`, `add-recv-prop`, `add-select-prop`, `add-offer-prop`,
  `add-stop-prop` in `session-propagators.rkt`
- Pure fire functions on the propagator network
- Return continuation cell IDs for further compilation

### A.4 Operation Tracing (Provenance)

```prologos
;; Each operation records a session-op for provenance
;; trace : Map CellId [List SessionOp]
;; Used for error derivation chains: "this cell contradicts because..."

;; NTT concept: this IS the traced monoidal structure.
;; The trace IS the morphism history in the traced monoidal category.
;; Each operation is a morphism; the trace is the composition.
```

**Implementation status**: IMPERATIVE (off-network).
- Trace is accumulated as a `hasheq` during compilation
- Post-quiescence, errors are built from the trace
- NOT on the propagator network — trace is metadata, not lattice state

**NTT gap**: Provenance tracing is not captured by the current NTT
syntax. The trace is the `:preserves [Trace]` structure we identified
on the TypeToSession bridge — but it applies to ALL session operations,
not just the bridge. A `TracedCell` concept would capture this:

```prologos
cell session-cell : TracedCell SessionExpr
  :trace [SessionOp ...]    ;; append-log of operations
```

The trace is itself a monotonic structure (append-only). Propagators
that write to a `TracedCell` automatically append to the trace.
Error reporting reads the trace for derivation chains.

### A.5 Bridge to Type Domain

```prologos
bridge SessionToType
  :from SessionExpr
  :to   TypeExpr
  :alpha send-type-alpha    ;; extract message type from send
  ;; One-way per operation (send extracts payload type)

bridge TypeToSession
  :from TypeExpr
  :to   SessionExpr
  :gamma type-to-session-gamma   ;; identity (prevents feedback loops)
```

**Implementation status**: NETWORK-NATIVE.
- `add-send-type-bridge`, `add-recv-type-bridge` use
  `net-add-cross-domain-propagator` with α/γ functions
- α extracts payload types; γ returns `sess-bot` (identity under merge)
- The γ being identity is a design choice to prevent feedback loops

**NTT observation**: The bridge is functionally one-way (α meaningful,
γ = identity). But structurally it's declared as bidirectional with a
trivial γ. Per our "one-way implicit from missing keyword" design, this
should be:

```prologos
bridge SendTypeExtract
  :from SessionExpr
  :to   TypeExpr
  :alpha send-type-alpha
  ;; No :gamma → one-way
```

### A.6 Network Compilation (Dynamic Topology)

```prologos
;; Like NF-Narrowing, the session network is dynamically constructed
;; by walking the process tree (proc-* AST).
;; Each process operation installs propagators.
;; proc-new installs duality constraint between client/server cells.

;; The process tree is the "definitional tree" for sessions —
;; it determines network topology.
```

**NTT observation**: Same dynamic topology pattern as NF-Narrowing.
The process tree determines which propagators are installed, similar
to how the DT determines narrowing propagators. Both are
"structural specifications" that the SRE should derive networks from.

### A.7 What the Case Study Reveals

- **Session types are the most complete network-native implementation.**
  Decomposition propagators, duality propagators, cross-domain bridges,
  and contradiction detection are all on-network.
- **Provenance tracing is the missing NTT concept.** The `TracedCell`
  idea emerges from sessions but applies broadly (any cell that needs
  explanation of how it reached its current value).
- **Duality as involution** validates `:where [Involution f]` on types.
  The SRE could derive duality propagators from the `dual` function
  definition — adding involution-based decomposition to the SRE's
  repertoire (alongside equality-based unification).
- **Dynamic topology again.** Process tree compilation, like DT walking,
  produces data-dependent network topology.

---

## Part B: QTT (Multiplicity Tracking)

### B.1 Lattice (Value + Quantale)

```prologos
type MultExpr := mult-bot | m0 | m1 | mw | mult-top

impl Lattice MultExpr
  join
    | mult-bot x -> x
    | x mult-bot -> x
    | x x        -> x
    | _ _        -> mult-top
  bot -> mult-bot

impl Quantale MultExpr
  tensor [a b] [mult-times a b]
  ;; m0·x = m0, m1·m1 = m1, m1·mw = mw, mw·mw = mw
```

**Implementation status**: FULLY NETWORK-NATIVE.
- `mult-lattice-merge` in `infra-cell.rkt` — 5-element flat lattice
- Pure function, no side effects
- Mult cells are propagator cells
- The simplest lattice in the system

### B.2 Bridge

```prologos
bridge TypeToMult
  :from TypeExpr
  :to   MultExpr
  :alpha type->mult-alpha     ;; extract multiplicity from Pi binder
  :gamma mult->type-gamma     ;; inject mult constraint back to type
  :preserves [Tensor]         ;; quantale morphism
```

**Implementation status**: NETWORK-NATIVE.
- Track 8 A3a: assumption-tagged mult CHAMP
- `current-structural-mult-bridge` callback installs cross-domain
  propagators in `decompose-pi`
- `:preserves [Tensor]` is validated: the bridge preserves
  `mult-times` structure across the domain crossing

### B.3 What the Case Study Reveals

- **QTT is the simplest system to model in NTT.** Flat value lattice,
  single bridge with quantale preservation, fully network-native.
- **The `:preserves [Tensor]` concept is grounded in reality.** QTT's
  multiplicity algebra IS a quantale; the bridge IS a quantale morphism.
- **Quantale structure matters.** Without `:preserves [Tensor]`, the
  bridge would lose the multiplication semantics during domain crossing.
  This validates the `:preserves` keyword as load-bearing, not decorative.

---

## Part C: WF-LE (Well-Founded Logic Engine)

### C.1 Lattice (Bilattice via `newtype`)

```prologos
type BilatticeValue := bl-bot | bl-true | bl-false | bl-unknown | bl-top

newtype Knowledge := Knowledge BilatticeValue
newtype Truth := Truth BilatticeValue

impl Lattice Knowledge
  join [Knowledge a] [Knowledge b] -> Knowledge [knowledge-join a b]
  bot -> Knowledge bl-bot

impl Lattice Truth
  join [Truth a] [Truth b] -> Truth [truth-join a b]
  bot -> Truth bl-bot
```

**Implementation status**: PARTIALLY NETWORK-NATIVE.
- `bilattice.rkt` provides the bilattice operations
- Lower cell (Knowledge ascending) and upper cell (Truth descending)
  per variable — two cells per logical atom
- The bilattice structure IS already two separate cells with different
  merge functions — the `newtype` wrapper makes this type-safe

**NTT observation**: The `newtype` approach maps directly to what the
implementation already does: two cells per atom, each with its own merge.
The NTT provides type safety that the implementation currently lacks
(Knowledge and Truth are both `BilatticeValue` at runtime, distinguished
only by which merge function is used).

### C.2 Stratification

```prologos
stratification WFSolver
  :fixpoint :approximation
  :bilattice Knowledge Truth
  :stable-operator wf-stable
  :fiber S0
    :networks [fact-net rule-net]
  ;; The AFT stable operator alternates between Knowledge and Truth
  ;; orderings to converge on the well-founded model
  :fuel 100
  :where [WellFounded WFSolver]
```

**Implementation status**: IMPLEMENTED but not fully on-network.
- The bilattice iteration (alternating fixpoint) is imperative
- Each iteration runs the network to quiescence (network-native)
- The alternation between knowledge and truth orderings is an
  outer imperative loop

**NTT observation**: The `:fixpoint :approximation` + `:bilattice`
keywords capture the AFT semantics declaratively. The alternating
fixpoint iteration is the `:stable-operator` — it reads the current
knowledge approximation, computes the truth approximation, and iterates.
This is inherently two-stratum (knowledge stratum + truth stratum),
which `:bilattice` makes explicit.

### C.3 Consistency Propagator

```prologos
propagator bilattice-consistency
  :reads  [lower : Cell Knowledge, upper : Cell Truth]
  :writes []  ;; contradiction if lower > upper
  ;; Enforces: knowledge-order(lower) ≤ truth-order(upper)
  ;; i.e., we can't know MORE than what's true
```

### C.4 What the Case Study Reveals

- **`newtype` resolves the bilattice gap cleanly.** Two orderings on
  one carrier = two wrapper types. Implementation already uses two cells;
  NTT adds type safety.
- **`:fixpoint :approximation` is load-bearing.** The AFT alternating
  fixpoint is fundamentally different from lfp/gfp — it needs both
  orderings declared and a stable operator that crosses between them.
- **The outer alternation loop is imperative.** The NTT captures the
  WHAT (bilattice, stable operator, approximation fixpoint) but not the
  HOW (the imperative loop that alternates). This is acceptable — the
  NTT is a specification language, not an implementation language.

---

## Part D: NAF-LE (Negation-as-Failure Logic Engine)

### D.1 Lattice (Value — Truth Values)

```prologos
;; Same as WF-LE's carrier, but simpler ordering (no bilattice)
type TruthValue := tv-bot | tv-true | tv-false | tv-top

impl Lattice TruthValue
  join
    | tv-bot x -> x
    | x tv-bot -> x
    | x x      -> x
    | _ _      -> tv-top    ;; true+false = contradiction
  bot -> tv-bot
```

### D.2 Stratification (Inductive)

```prologos
stratification NAFSolver
  :fixpoint :stratified
  :base S0
    :networks [fact-net rule-net]
  :recurse
    :trigger negation-as-failure
    :halts-when [fixpoint]
  :fuel 50
  :where [WellFounded NAFSolver]
```

### D.3 Non-Monotone Step

```prologos
;; NAF check: the stratum transition's non-monotone step
propagator naf-check
  :reads  [negated-goal : Cell TruthValue]
  :writes [result : Cell TruthValue]
  :non-monotone
  ;; If negated-goal = tv-bot after lfp: closed-world → result = tv-true
  ;; If negated-goal = tv-true: result = tv-false
```

**NTT observation**: The `:non-monotone` flag on the propagator is
correct. This propagator can ONLY fire at a stratum boundary (between
iterations of the inductive stratification). Within a stratum, all
propagators are monotone. The NTT enforces this: `:non-monotone`
requires assignment to a barrier stratum.

### D.4 What the Case Study Reveals

- **`:fixpoint :stratified` + `:recurse` maps directly to NAF-LE.**
  The inductive stratification syntax was designed for this case and
  it fits perfectly.
- **`:non-monotone` on propagators is validated.** NAF's non-monotone
  step (reading absence of information) is correctly captured as a
  propagator that can only fire at barrier transitions.
- **`:trigger negation-as-failure` needs formalization.** What exactly
  is the trigger condition? "A negated atom has no derivation after lfp"
  — this is a meta-condition on the fixpoint, not a cell value. The NTT
  may need to express trigger conditions more precisely.

---

## Cross-Study Synthesis

### NTT Syntax Validation Matrix

| NTT Feature | Type Checker | NF-Narrowing | Sessions | QTT | WF-LE | NAF-LE |
|-------------|-------------|-------------|----------|-----|-------|--------|
| Value lattice | MultExpr ✓ | — | — | MultExpr ✓ | TruthValue ✓ | TruthValue ✓ |
| Structural lattice | TypeExpr ✓ | TermValue ✓ | SessionExpr ✓ | — | — | — |
| `interface` | Implicit | Implicit | Implicit | Implicit | Implicit | Implicit |
| `network` | Static | Dynamic | Dynamic | Static | Static | Inductive |
| `bridge` | TypeToMult ✓ | Implicit | SendType ✓ | TypeToMult ✓ | — | — |
| `stratification` | 4-stratum ✓ | Embedded S0 | Embedded S0 | Embedded S0 | :approximation ✓ | :stratified ✓ |
| `exchange` | S0↔S1 ✓ | — | — | — | — | — |
| `:preserves` | [Tensor] ✓ | — | [Trace] ✓ | [Tensor] ✓ | — | — |
| `:non-monotone` | S(-1) ✓ | — | — | — | — | naf-check ✓ |
| `:fixpoint` | :lfp ✓ | :lfp ✓ | :lfp ✓ | :lfp ✓ | :approximation ✓ | :stratified ✓ |
| SRE applicable | HIGH | HIGHEST | HIGH | LOW | LOW | LOW |
| Imperative debt | HIGH | LOW | LOW | NONE | MEDIUM | LOW |

### Patterns Confirmed Across All Studies

1. **Structural lattices share the same SRE pattern**: TypeExpr, TermValue,
   SessionExpr all have merge-creates-propagators. SRE-derived merge handles
   all three uniformly.

2. **Dynamic topology is universal for structural systems**: Type Checker
   (PUnify), NF-Narrowing (DT walk), Sessions (process compilation) all
   produce data-dependent network topology. Static topology only applies
   to value-lattice systems (QTT, NAF-LE).

3. **Residuation is free everywhere**: Not just NF-Narrowing — session
   decomposition propagators also residuate on `sess-bot`. Any monotone
   propagator on a lattice with bot naturally residuates.

4. **`:preserves` is load-bearing**: QTT's Tensor and Sessions' Trace are
   real structural conditions that the bridge must maintain. Without them,
   the bridge loses algebraic information during domain crossing.

5. **The `interface` form is consistently needed but never used**: All six
   systems have implicit interfaces. Making them explicit would enable
   type checking of network composition (lattice compatibility, bridge
   soundness).

### New Gaps Discovered

| Gap | Source | Severity |
|-----|--------|----------|
| `TracedCell` for provenance | Sessions (A.4) | MEDIUM |
| Involution-based SRE (duality) | Sessions (A.2) | LOW |
| Trigger condition formalization | NAF-LE (D.4) | LOW |
| All `interface` forms are implicit | All systems | MEDIUM |

### Cumulative Gap Summary (All 6 Studies)

| Gap | Severity | Resolution Status |
|-----|----------|------------------|
| Structural merge creates propagators | HIGH | RESOLVED (§3.2 `:lattice :structural`) |
| Dynamic propagator installation | HIGH | RESOLVED (SRE handles it) |
| `expr-meta` / cell references as values | HIGH | OPEN (SRE endpoint: meta IS cell) |
| Dynamic network topology | MEDIUM | PARTIALLY RESOLVED (SRE from DT/proc/type) |
| Bilattice two orderings | MEDIUM | RESOLVED (`newtype` wrappers) |
| `TracedCell` for provenance | MEDIUM | OPEN (needs design) |
| Implicit `interface` everywhere | MEDIUM | OPEN (needs adoption) |
| Speculation dynamics | MEDIUM | OPEN (needs `speculation` form or integration) |
| Network lifetime (persistent/speculative) | LOW | RESOLVED (`:lifetime` on `network`) |
| Involution-based SRE decomposition | LOW | OPEN (extend SRE for duality) |
| NAF trigger condition formalization | LOW | OPEN |

---

## Source Documents

| Document | Relationship |
|----------|-------------|
| [Type Checker Case Study](2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) | Companion deep case study |
| [NF-Narrowing Case Study](2026-03-23_NTT_CASE_STUDY_NF_NARROWING.md) | Companion deep case study |
| [NTT Syntax Design](../tracking/2026-03-22_NTT_SYNTAX_DESIGN.md) | Syntax being validated |
| [Architecture Survey](2026-03-22_NTT_ARCHITECTURE_SURVEY.md) | Breadth-first survey |
| [SRE Research](2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | SRE scope expansion |
