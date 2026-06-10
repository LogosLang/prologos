# Polybox Notation Survey: Niu–Spivak Diagrams Applied to Prologos Patterns

**Date**: 2026-05-09
**Stage**: 0 (exploratory — notation survey; no design commitments; assessment-deferred)
**Series**: [PTF (Propagator Theory Foundations)](../tracking/2026-03-28_PTF_MASTER.md)
**Companion volume**: [Polynomial Functors Companion (Niu & Spivak, Cambridge UP 2025)](file:///sessions/festive-dazzling-euler/mnt/learning/poly-companion-toc.html) — see Chapter 3 §3.2 for the polybox notation's introduction; Chapter 6 §6.2 for stacked polyboxes; Chapter 8 §8.1.2–8.1.5 for cofree-comonoid polyboxes.

**Lateral context**:
- [Categorical Foundations of Typed Propagator Networks](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — the doc that established Poly as the categorical foundation
- [Tensor Propagator Research Program](2026-03-16_TENSOR_PROPAGATOR_RESEARCH_PROGRAM.md) — quantale structure on cells; LRP
- [Module Theory on Lattices](2026-03-28_MODULE_THEORY_LATTICES.md) — the algebraic backbone
- [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md) — current design checklist (the patterns this note diagrams)

---

## 0. Why this note exists

The Polynomial Functors companion volume (built 2026-05) made the Niu–Spivak **polybox notation** legible inside our project. Polyboxes are the book's primary visual device — a single rectangle whose top half names a polynomial's *positions* and whose bottom half names its *directions*, with arrows depicting the forward (on-positions) and backward (on-directions) components of a dependent lens.

The question this note opens: **is polybox notation worth adopting as a design / communication tool for Prologos propagator-network patterns?**

The note is Stage 0 — *survey*, not commitment. It applies polybox diagrams to four canonical patterns from [`propagator-design.md`](../../.claude/rules/propagator-design.md) (fire-once, broadcast, set-latch fan-in, component-paths) plus one cross-stratum interaction. The reader assesses fit after seeing the diagrams in context.

**What this note is NOT:**
- Not a design-language commitment. Whether to fold polyboxes into design docs, NTT syntax, or `propagator-design.md` is downstream.
- Not a tutorial on Niu–Spivak's notation. For that, see the [companion volume's Chapter 3 §3.2](file:///sessions/festive-dazzling-euler/mnt/learning/poly-companion-ch03.html) directly.
- Not a claim that polybox notation is the *right* visual language. Wire diagrams (Spivak's operad of wiring diagrams), string diagrams (for monoidal categories), hypergraph rewriting diagrams (PRN's hypergraph framing), Petri-net diagrams, and dataflow-network diagrams are all candidates. Polybox is *one* candidate, distinguished by the book's exposition just established.

**The assessment to defer**: after reading the rendered patterns below, does the polybox notation (a) clarify the architecture beyond the prose in `propagator-design.md`? (b) introduce ambiguity that prose doesn't? (c) feel like the right level of abstraction for Prologos design conversations? Decision is left to a follow-up note.

---

## 1. Polybox refresher (one paragraph + one diagram)

A polynomial $p = \sum_{i \in p(1)} y^{p[i]}$ has *positions* $i \in p(1)$ and *directions* $p[i]$ at each position. A dependent lens $f : p \to q$ has an on-positions function $f_1 : p(1) \to q(1)$ (forward) and an on-directions function $f^\sharp_i : q[f_1 i] \to p[i]$ (backward, at each position $i$). The polybox draws this as two side-by-side boxes — the left box for $p$, the right box for $q$ — with:

- **Forward arrow** (top): $i \mapsto f_1(i)$, drawn left-to-right (the position $i$ of $p$ maps to position $f_1(i)$ of $q$);
- **Backward arrow** (bottom): $q[f_1 i] \to p[i]$, drawn right-to-left at the chosen position (the direction $d \in q[f_1 i]$ at position $f_1(i)$ of $q$ pulls back to direction $f^\sharp_i(d) \in p[i]$ at position $i$ of $p$).

```
           f₁ (forward, on positions)
            ────────────────────────►
   ┌─────────────────┐    ┌─────────────────┐
   │       i         │    │     f₁(i)       │   ◄── positions (top half)
   ├─────────────────┤    ├─────────────────┤
   │   f^♯_i(d)      │ ◄──┤        d        │   ◄── directions (bottom half)
   │                 │    │                 │
   └─────────────────┘    └─────────────────┘
           p                       q
```

A "lens" in Prologos has the same structure: **forward on values** (the propagator reads cells, computes, writes to its outputs) and **backward on responses** (the propagator's dependent metadata — which reads it draws on for each write — flows backward from the writes to the reads). The on-directions function is `:component-paths` made operational.

For details and Prologos-relevant variations, see the [companion volume's Ch3](file:///sessions/festive-dazzling-euler/mnt/learning/poly-companion-ch03.html).

---

## 2. Five canonical patterns rendered as polyboxes

### 2.1 Pattern: Cell + reading propagator (fire-once)

The basic propagator: reads cell `c-in`, computes, writes to `c-out`. A fire-once propagator (per [§Fire-Once Propagators](../../.claude/rules/propagator-design.md)) produces output exactly once.

```
    ┌────────────────────┐         ┌────────────────────┐
    │   c-in : v ∈ V_in  │  ────► │  c-out : v' ∈ V_out │
    ├────────────────────┤  fire  ├────────────────────┤
    │   {read-action}    │ ◄────  │   {written-by-φ}   │
    └────────────────────┘         └────────────────────┘
            p_in                            p_out

Forward (on positions, fired once):
  v ↦ φ(v) = v'   where φ is the propagator's fire function

Backward (on directions):
  the {written-by-φ} entry in c-out's directions pulls back to
  the {read-action} entry in c-in's directions — i.e. c-out's
  "I was written by φ" depends on c-in's "I was read by φ".
```

**Prologos correspondence**: a fire-once propagator installed via `net-add-fire-once-propagator` IS exactly this two-polybox lens. The forward direction is the fire function's `(net-cell-read net c-in) → (net-cell-write net c-out)`. The backward direction is the dependency-graph edge `c-out's writer is φ → φ's reader is c-in` (which the BSP scheduler uses for change-propagation via `filter-dependents-by-paths`).

**Notation utility**: the polybox makes EXPLICIT the asymmetry between forward (value flow) and backward (dependency flow). In the codebase this is currently implicit in the `inputs:` / `outputs:` fields of the propagator struct. The polybox lifts this into a visual primitive.

---

### 2.2 Pattern: Broadcast propagator over N items

A broadcast propagator (per [§Broadcast Propagators](../../.claude/rules/propagator-design.md)) processes N independent items in ONE propagator fire with parallel-decomposition metadata. **"Broadcast is the polynomial functor made operational"** — `propagator-design.md` already names this.

```
                                   Σ_{k∈1..N} y^{B_k}
    ┌────────────────────┐                  =                ┌────────────────────┐
    │   c-shared : v     │   ──────────►                     │   c-out : f̄ : N → V'│
    │  shared-carrier    │   broadcast       (computed       │  result merged via │
    │   (compound cell)  │   item-fn k       per-item, then   │  result-merge-fn   │
    ├────────────────────┤   over N items    merged-in)      ├────────────────────┤
    │  K = {comp_1,...,  │   ◄──────────                     │  {merged-write}    │
    │     comp_N} =      │  :component-paths                  │                    │
    │   component-paths  │  (cons c-shared k) for k ∈ N      │                    │
    └────────────────────┘                                    └────────────────────┘
           p_shared                                                   p_out

Forward (on positions, broadcast in parallel):
  v ↦ (k=1, item-fn(1, v)) | (k=2, item-fn(2, v)) | ... | (k=N, item-fn(N, v))
  the merge of these via result-merge-fn produces c-out's new position

Backward (on directions):
  the merged-write entry pulls back to N component-paths edges into c-shared
  — the broadcast knows it depends on N specific components of c-shared.
```

**Prologos correspondence**: a broadcast propagator installed via `net-add-broadcast-propagator` with `:component-paths (list (cons c-shared comp_k) ...)`. The polybox renders the broadcast as a polynomial $\sum_{k \in N} y^{B_k}$ — N parallel "ways the input becomes output" — which is exactly Niu–Spivak's "polynomial-functor made operational" sense (one polynomial functor with N positions, each with the same direction-set, fired in parallel).

**Notation utility**: the polybox makes EXPLICIT that broadcast IS a single polynomial functor — the asymmetry between (a) N parallel-ready items and (b) ONE polynomial functor with N summands is visualised. The component-paths annotation lives on the backward arrow, where it structurally belongs.

---

### 2.3 Pattern: Set-latch fan-in readiness

The prime design pattern from [§Set-Latch for Fan-In Readiness](../../.claude/rules/propagator-design.md). N independent inputs feed a monotone-set latch cell; a threshold propagator fires when the latch's set meets a threshold.

This requires **three** polyboxes — a broadcast (for the universe sub-set), a set of fire-once propagators (for legacy per-cell sub-sets), and a threshold-firing propagator. The three boxes share a single latch.

```
   universe sub-set (broadcast, shared carrier):

     ┌────────────────────┐          Σ_{k∈input-ids} y^{readiness-test}
     │  c-univ : compound │       ─────────────────────────────────────►   ┌──────────────┐
     │  hasheq of inputs  │       broadcast item-fn k:                     │ c-latch :    │
     ├────────────────────┤       (ready k v) → (seteq k) | #f              │ monotone-set │
     │  cps:              │       result-merge: merge-set-union              ├──────────────┤
     │  (cons c-univ k)   │       ◄────────────                              │ {add-to-set} │
     │   k ∈ input-ids    │                                                  └──────────────┘
     └────────────────────┘                                                       p_latch
          p_univ

   legacy per-cell sub-set (N fire-once propagators):

     ┌────────────────────┐ fire-once: if ready(v_i) ┌──────────────┐
     │  c-input-i : v_i   │ ───────► (seteq i)       │ c-latch  ◄── same latch
     │  per-cell legacy   │                          │              │
     ├────────────────────┤                          ├──────────────┤
     │ ...                │ ◄────  {fire-once}        │ {add-to-set} │
     └────────────────────┘                          └──────────────┘

   threshold fire-once (on the latch's threshold):

     ┌──────────────┐                              ┌──────────────────────┐
     │ c-latch :    │ ──── threshold? ────►        │ c-action-output      │
     │  set         │ (e.g. set-count >= k)         │ (downstream effect)  │
     ├──────────────┤                              ├──────────────────────┤
     │ {threshold-  │ ◄── only fires when           │ {threshold-fired}    │
     │  consumes}   │     threshold met             │                      │
     └──────────────┘                              └──────────────────────┘
```

**Prologos correspondence**: the set-latch pattern exactly as documented in `propagator-design.md`. The three sub-diagrams compose: broadcast + fire-once feed the latch; the threshold fires when the latch's set reaches the threshold.

**Notation utility**: the polybox renders the **identity-preservation** property explicit — the latch's positions ARE the seteq of input identities, and the latch's directions are the "consume threshold" event. The threshold propagator's polybox shows that *the threshold sees only the set's current state, not the individual inputs' identities* (this is correct: threshold is identity-blind by construction). This is hard to see in the prose; the polybox makes it structural.

**Potential confusion**: the three sub-diagrams need to be drawn together to see the latch as the shared output. Three side-by-side polyboxes plus a shared cell is unusual notation. (Polyboxes are bilateral lenses, not three-way wiring. This is where the framework starts to strain.)

---

### 2.4 Pattern: Compound cell with component-keyed dispatch

A compound cell is a hasheq from component-keys to (possibly tagged-cell-value) entries. Propagators read/write specific components, and component-paths constrain which cell-changes trigger which propagator firings.

```
    ┌──────────────────────────────────┐
    │   c-compound : compound          │   positions = hasheq from K to V_k
    │   K = {k_1, k_2, ..., k_N}       │
    │   V_k = value-type at key k      │
    ├──────────────────────────────────┤
    │   directions:                    │   directions = per-component-path response
    │   {read-via-cp k}                │   (i.e. "I was accessed via component-path k")
    │    for k ∈ K                     │
    └──────────────────────────────────┘
            p_compound

Propagator φ that reads component k_3, writes c-out:
    ┌──────────────────────────────────┐ on-positions: extract v_{k_3} from hasheq
    │   c-compound : hasheq            │ ─────────────►          ┌─────────┐
    │   {k_1: v_1, ..., k_3: v_3, ...} │ then φ(v_{k_3})         │  c-out  │
    ├──────────────────────────────────┤ ◄──── {read-via-cp k_3} ├─────────┤
    │   {read-via-cp k_3}              │ on-directions:           │ {wrote}│
    │   (declared via :component-paths)│  scheduler dependency    └─────────┘
    └──────────────────────────────────┘
        p_compound                                                p_out
```

**Prologos correspondence**: this matches `(compound-cell-component-ref/pnet pnet c-compound k_3)` accessed in a fire function. The component-paths declaration `:component-paths (list (cons c-compound k_3))` is the backward direction; the scheduler's `filter-dependents-by-paths` checks this before re-firing.

**Notation utility**: the polybox makes EXPLICIT that a compound cell's directions are *component-keyed*, not value-typed. This is the structural fact that justifies `:component-paths` being a REQUIRED annotation (per [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md)). The polybox notation could ground the NTT-future intent of "the type checker derives :component-paths from :reads when the cell is :lattice :structural."

---

### 2.5 Pattern: Cross-stratum threshold-firing

A threshold-fire propagator on the S0 worldview-cache cell fires the S1 NAF stratum after S0 quiescence (per [§Stratification on the Propagator Base](../../.claude/rules/stratification.md)).

```
   S0 worldview cache cell:
     ┌────────────────────────┐
     │ c-worldview : bitmask  │   positions = worldview-bitmask after S0 quiescence
     │  (bitwise-OR of        │   directions = "S0 quiesced; ready for S1"
     │   committed decisions) │
     ├────────────────────────┤
     │ {S0-quiesced-marker}   │
     └────────────────────────┘
              p_S0_cache

   Threshold propagator (fire-once, threshold = S0 has-quiesced):
     ┌────────────────────────┐   threshold? : bitmask is stable
     │ c-worldview            │  ─────────────►       ┌───────────────────────┐
     │  bitmask               │                       │ c-S1-NAF-request-cell │
     ├────────────────────────┤                       ├───────────────────────┤
     │ {S0-quiesced-marker}   │ ◄── {S0-fired-cause-} │  {hash-union pending} │
     │                        │     {of-S1-fire}      │                       │
     └────────────────────────┘                       └───────────────────────┘
           p_S0_cache                                            p_S1_request

   S1 stratum handler runs (BSP outer loop iteration):
     ┌───────────────────────┐    process-naf-request : forks BSP, evaluates NAF goals
     │ c-S1-NAF-request-cell │  ─────────────►          ┌─────────────────────┐
     │  hasheq of pending    │                          │ c-decisions-state   │
     │  NAF requests         │                          │  (S0 decision cells │
     ├───────────────────────┤                          │   narrowed by NAF   │
     │ {S1-handler-          │ ◄── {S0-narrowed-by-     │   outcomes)         │
     │  consumed-pending}    │      S1-outcome}         ├─────────────────────┤
     └───────────────────────┘                          │ {decision-narrowed} │
        p_S1_request                                    └─────────────────────┘
                                                             p_S0_decisions
```

**Prologos correspondence**: the registered-stratum-handler pattern from `propagator.rkt:2441`. S0 quiesces → threshold-fire writes to the S1 request-accumulator cell → BSP outer loop invokes S1 handler → S1 handler updates decisions cells (which narrows S0 worldview).

**Notation utility**: the polybox renders **the composition direction** $\triangleleft$'s asymmetry EXPLICITLY. The arrow flow is:
- `c-S0` → `c-S1-request` (forward, "S0 finished, S1 may proceed")
- `c-S1-request` → `c-S0-decisions` (forward, "S1 NAF narrows S0 decisions")
- The asymmetry `S0 ⊳ S1 ⊳ S0` is the structural form of "stratum precedence."

This is the connection to ◁ the user asked about: $\triangleleft$'s asymmetry IS the stratum precedence; the polybox lens-chain renders this as forward-arrows that cannot be reversed without breaking the chain.

**Where polyboxes strain**: the cross-stratum interaction involves FORKING (S1 NAF forks BSP). A "fork" doesn't fit the lens framework directly — it's a more complex monoidal structure (a comultiplication ⊗ followed by parallel firing). The polybox notation is faithful for the linear arrow-chain but loses the fork's structural meaning.

---

## 3. Assessment criteria (the questions the user invited)

The user's question is whether polybox notation is "the correct fit to help us communicate or reason about our designs going forward."

The patterns above suggest the following potential utilities and limits:

### 3.1 Where polybox notation seems to help

1. **The lens asymmetry (forward on values, backward on directions) is structural** — and lives at the heart of `:component-paths` discipline. Polyboxes render this asymmetry explicitly, making the structural fact visual rather than buried in fire-function code.

2. **Broadcast IS a polynomial functor**, by `propagator-design.md`'s own framing. Polyboxes give us the visual primitive for this — N summands $\sum_k y^{B_k}$ as N parallel "broadcasts" — that matches the design intent.

3. **Component-paths are structurally directions**. Polyboxes make this explicit. The future NTT direction (`:component-paths` derivable by the type checker from `:lattice :structural`) gains a notation that grounds the type-checker-derived obligation.

4. **The forward / backward distinction matches Prologos's PRIMARY / DERIVED lattice distinction** (per [`.claude/rules/structural-thinking.md`](../../.claude/rules/structural-thinking.md) Q5). Primary lattices = forward direction (value flow); derived lattices = backward direction (dependency / projection). The polybox notation aligns with the SRE lattice lens's primary/derived classification.

5. **The asymmetry of $\triangleleft$ = stratum precedence**. The chained-polybox rendering of cross-stratum interactions makes the precedence visual.

### 3.2 Where polybox notation strains

1. **Three-way wiring (fan-in set-latch)** doesn't fit two-polybox lens notation cleanly. Three side-by-side polyboxes with a shared output cell is unusual. Wire diagrams (Spivak's operad) or hypergraph diagrams might be more natural for fan-in.

2. **Fork structures** (S1 NAF forks BSP; ATMS speculation forks worldview) require additional monoidal structure ($\otimes$ for parallel forks) that polyboxes don't natively render. A fork is two polyboxes drawn in parallel, but the "where they came from" arrow needs a comultiplication.

3. **Worldview-bitmask tagging** lives at the *direction-set* level (each direction can carry a bitmask). The polybox notation doesn't natively render bitmask-tagged directions; we'd need a sub-notation (e.g., colored arrows for different bitmasks).

4. **The lattice / quantale substrate** doesn't appear in the polybox. A polybox's positions are a *set*; for Prologos, positions are *lattice elements*. We'd need polyboxes-over-Lat (lattice-enriched polynomial functors) to render this correctly. This is a real but heavyweight gap.

5. **No native rendering of stratum dependency**. Stratum order is `S(-1) ⊳ S0 ⊳ S1 ⊳ S2`. Polyboxes render *one* level of asymmetry at a time. For multi-level stratification, we'd need a meta-diagrammatic layer.

### 3.3 Honest comparison with alternatives

| Notation | Forward strength | Backward strength | Lattice substrate | Fork support | Hypergraph rewriting | Use in Prologos today |
|---|---|---|---|---|---|---|
| Polybox (Niu–Spivak) | Strong | Strong | None natively | Weak | Weak | None |
| Wire diagrams (Spivak operad) | Strong | Implicit | None natively | Strong | Strong | None — referenced in research notes |
| String diagrams (monoidal cat) | Strong | Strong | Enriched possible | Strong | Strong | None |
| Hypergraph rewriting (DPO/SqPO) | Strong | Strong | None natively | Native | Native | `2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md` |
| Petri nets | Native | Native | Sometimes (token weights) | Native | Weak | None |
| Prose + tables (current) | Strong | Strong | Strong | Adequate | Adequate | Current default |

**Observation**: polyboxes are *one* good notation among several. They are NOT clearly better than wire diagrams or string diagrams for Prologos's needs. They are clearly better than prose-only for some patterns (the lens asymmetry, broadcast-as-polynomial-functor) but clearly worse for fan-in, forks, and lattice substrate.

---

## 4. Decision left for follow-up

This note ends without a commitment. The reader's questions to answer:

1. **Does the rendering of patterns above (2.1–2.5) clarify the architecture beyond what prose currently does?** Worth keeping for some patterns? Worth keeping for all?

2. **Is the lens-asymmetry (forward/backward) a primitive worth lifting into design conversations** — e.g., by amending `propagator-design.md`'s "Component Indexing" section to use polybox notation?

3. **Does the strain on fan-in and forks** (which Prologos uses heavily) outweigh the clarity on basic lenses?

4. **If polybox notation is adopted, in what register?** Options:
   - As design-doc-only illustration (low cost; high reuse if patterns recur)
   - As an NTT-syntax-level primitive (high cost; needs `:positions / :directions` declarations)
   - As a code-comment convention (medium cost; depends on consistency)
   - Not adopted; prose remains the default

5. **Is there a HYBRID** — polybox notation for the cell-and-lens layer; wire diagrams or hypergraphs for the network-topology layer; lattice-Hasse diagrams for the substrate layer? This is structurally what the project's existing framing suggests, but combining three notation systems in one design doc is itself a notation cost.

The honest framing: the companion volume's polybox rendering is *attractive* in the Niu–Spivak text, but the patterns above show it costs us coverage for the most operationally important Prologos patterns (fan-in, forks, stratum interactions). Prose + tables + ad-hoc ASCII may remain the highest-utility option, with polyboxes adopted SELECTIVELY for the basic-lens layer where they genuinely clarify.

---

## 5. Cross-references

- [Companion volume Chapter 3 §3.2](file:///sessions/festive-dazzling-euler/mnt/learning/poly-companion-ch03.html) — polybox notation introduction
- [Companion volume Chapter 6 §6.2](file:///sessions/festive-dazzling-euler/mnt/learning/poly-companion-ch06.html) — stacked polyboxes for composition product
- [Companion volume Chapter 8 §8.1.2–8.1.5](file:///sessions/festive-dazzling-euler/mnt/learning/poly-companion-ch08.html) — cofree-comonoid polyboxes
- [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md) — current design checklist (the patterns this note diagrams)
- [`.claude/rules/structural-thinking.md`](../../.claude/rules/structural-thinking.md) — SRE lattice lens (Q1–Q6); primary/derived distinction maps to forward/backward
- [Categorical Foundations of Typed Propagator Networks](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — Poly as foundation; section §2 surveys Operads/PROPs/Poly
- [Hypergraph Rewriting Propagator Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — alternative notation (hypergraphs)
- [Process Calculi Survey](2026-03-03_PROCESS_CALCULI_SURVEY.md) — wire-diagram-adjacent alternatives
