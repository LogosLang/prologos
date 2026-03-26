# Kan Extensions, ATMS Search, and GFP Parsing — Conversational Research

**Date**: 2026-03-26
**Stage**: 0 (Conversational synthesis — insights from discussion)
**Series touches**: PRN, PPN, SRE, BSP-LE, OE, NTT

**Related documents**:
- [Lattice Foundations for PPN](2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — concrete lattice design
- [Hypergraph Rewriting + Propagator Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — foundational research
- [Tropical Optimization + Network Architecture](2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — cost-weighted rewriting
- [Categorical Foundations](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — Kan extensions, fibrations
- [FL-Narrowing Design](2026-03-07_FL_NARROWING_DESIGN.org) — definitional trees, needed narrowing
- [PRN Master](../tracking/2026-03-26_PRN_MASTER.md) — theory series tracking
- [PPN Master](../tracking/2026-03-26_PPN_MASTER.md) — parsing series tracking

---

## 1. NF-Narrowing and Right Kan — Structural Correspondence

### The mapping

| NTT concept (Right Kan S0↔S1) | NF-Narrowing implementation | Correspondence quality |
|-------------------------------|---------------------------|----------------------|
| S1 demands cell C from S0 | DT node says "narrow at position P" | STRUCTURAL — same intent |
| S0 computes only what S1 demands | Narrow `x` to each constructor (only at demanded position) | STRUCTURAL — targeted computation |
| Demand flows backward (S1→S0) | DT traversal determines what to narrow next | STRUCTURAL — backward flow |
| Residuation (S0 waits for information) | `(term-var? val)` → suspend narrowing | PARTIAL — same behavior, different mechanism |
| Demand as cell on demand lattice | Imperative decision in narrowing loop | GAP — demand is not a cell |
| Cross-domain demand composition | Demands are narrowing-local, not composable | GAP — biggest architectural miss |

### What formal Right Kan would give us

If demands were cells in a "demand lattice," and the DT installed demand
propagators (each DT node creates a demand cell), then:

1. **Residuation falls out of propagator semantics**: No special case for
   `term-var?`. An input cell at bot means the propagator doesn't fire.
   Residuation IS the normal propagator behavior.

2. **Cross-domain demand composition**: Type demands ("I need to know the
   type of `x`"), narrowing demands ("I need to know the constructor of
   `x`"), and session demands ("I need to know the protocol state") would
   interact on the same demand network. A type demand could trigger
   narrowing (if knowing the type requires knowing the constructor).

3. **Demand-driven evaluation is a single mechanism**: Currently we have
   separate "demand" concepts in: NF-Narrowing (DT-guided), type inference
   (bidirectional check mode), session verification (protocol-driven). With
   Right Kan as a first-class network operation, all three use the same
   demand propagation mechanism.

### Current vs ideal

The current implementation is ~70% of the formal Right Kan. The demand
INTENT is correct (narrow only what's needed). The implementation is
ad-hoc (imperative DT traversal, not demand cells). Formalizing would
gain: composability, cross-domain interaction, and elimination of special
cases. Cost: complexity of the demand lattice design.

**Recommendation**: When PPN Track 4 (elaboration as attribute evaluation)
is implemented, the demand lattice should be designed to unify: DT demands,
type-checking demands, and parse disambiguation demands. This is where
Right Kan formalization pays off — three demand sources on one network.

---

## 2. Left Kan, ATMS, and Search Space Optimization

### Left Kan vs ATMS — they're different operations

| Concept | Left Kan (speculative forwarding) | ATMS (speculative branching) |
|---------|----------------------------------|------------------------------|
| What it does | Forwards PARTIAL results from S0 to S1 before fixpoint | Creates PARALLEL WORLDS, each run to fixpoint |
| Information flow | Forward (S0→S1), prematurely | All directions, within each branch |
| Purpose | Approximation (early results, refined later) | Exploration (complete results, select consistent) |
| Monotonicity | Monotone (lower bounds only grow) | Monotone within branches, non-monotone between (retraction) |
| Cost model | Cheap (reuse partial work) | Expensive (N branches × full computation) |

### The 4-level optimization strategy

Left Kan and ATMS COMPOSE into a search strategy that's more efficient
than either alone:

1. **ATMS creates branches** (full exploration space): N branches for N
   possible parses/rewrites/inferences.

2. **Left Kan prunes obviously-wrong branches** (speculative forwarding):
   Forward PARTIAL type information from the elaborator into parse
   branches. If even the lower bound contradicts a branch, prune it
   WITHOUT running it to fixpoint. This is "speculative pruning."

3. **Right Kan focuses remaining computation** (demand-driven): Among
   surviving branches, only compute what's demanded. Don't elaborate
   parts of a parse that no downstream consumer needs.

4. **Tropical semiring selects among survivors** (cost-optimal): Among
   branches that survive pruning and produce complete results, select
   the cheapest. Cost = runtime perf, compile time, code size, etc.

**The composition**: Branch → Prune → Focus → Select.

Each level uses a different mechanism but they compose on the same
network:
- ATMS: assumption management (TMS cells, worldview filtering)
- Left Kan: forward approximation (lower-bound cells, threshold
  propagators)
- Right Kan: backward demand (demand cells, DT-guided computation)
- Tropical: cost accumulation (min-plus merge, Pareto extraction)

### Implications for PPN

Parse disambiguation currently uses heuristics. With the 4-level
strategy:
- Ambiguous parse → ATMS branches (one per parse alternative)
- Type elaboration forwards partial results → Left Kan prunes
  type-inconsistent parses
- Surviving parses elaborate only demanded portions → Right Kan
  focuses
- Cheapest surviving parse selected → tropical (if cost matters)

The parse result is not heuristic — it's a PROOF that the surviving
parse is the unique type-consistent, cost-optimal interpretation.

---

## 3. Coinductive / GFP Analysis for Parsing and Beyond

### The lfp/gfp duality

| | Least fixpoint (lfp) | Greatest fixpoint (gfp) |
|---|---------------------|------------------------|
| Starting point | Bot (nothing known) | Top (everything possible) |
| Direction | Accumulate upward | Eliminate downward |
| Question answered | "What CAN we derive?" | "What can we NOT rule out?" |
| Lattice | Standard ordering | DUAL ordering (reversed) |
| On the network | Cells start at bot, propagators add | Cells start at top, propagators remove |
| Monotonicity | Monotone in standard lattice | Monotone in dual lattice |

### GFP on propagator networks

GFP computation doesn't need new infrastructure. Use the DUAL LATTICE
(reverse the ordering): top becomes dual-bot, bot becomes dual-top.
Start cells at dual-bot (= original top). Propagate monotonically in
the dual. The fixpoint in the dual IS the gfp in the original.

The WF-LE bilattice already does this: knowledge ordering (lfp) and
truth ordering (gfp) on the same carrier. The "well-founded model"
combines both fixpoints.

### Applications of GFP to our architecture

#### 3.1 Grammar analysis (reachable nonterminals)

Given a grammar, compute the gfp of "reachable nonterminals." Start
with ALL nonterminals as reachable. Eliminate any that can't produce
terminal strings. The gfp is the set of reachable nonterminals.

On the network: each nonterminal has a cell in the "reachability"
lattice (`{reachable, unreachable}`, dual ordering). Start all at
`reachable`. Propagators eliminate: if all productions for nonterminal
N contain an unreachable nonterminal, N becomes unreachable.

#### 3.2 Foreign type inference (codata observations)

For foreign types where we observe the API but not the implementation:
gfp is the right approach. We CAN'T derive internal structure (no
constructors). We CAN observe operations (codata observations).

The gfp of "what types could this value have, given these observations?"
is the most permissive type consistent with observed behavior.

Example: `RacketPort` supports `read-byte → Option Byte` and
`port-open? → Bool`. The gfp: RacketPort is ANY type supporting these
observations. If we later observe `write-byte : Byte → IO ()`, the gfp
NARROWS (eliminates types that don't support write-byte).

This is coinductive type inference: define the type by what you CAN DO
with it, not by how you BUILD it. Dual to inductive typing (define by
constructors).

#### 3.3 Session protocol inference

When a session protocol isn't fully declared, gfp says: "what protocols
are consistent with the observed send/recv operations?" The most
permissive session type is the gfp.

This is valuable for gradual session typing: partially-annotated code
gets the most permissive session type that's consistent with the
annotations and the observed communication pattern.

#### 3.4 Error recovery as lfp/gfp gap

Given a parse error:
- **lfp** of "what DID match" = the partial parse (successful prefix)
- **gfp** of "what COULD match" = all rules applicable at the error point
- The GAP (gfp - lfp) = the set of possible repairs

The tropical semiring selects the cheapest repair from the gap.

This is more principled than heuristic error recovery: the repair set
is COMPUTED from the grammar structure, not hard-coded. And the cost
model makes the selection optimal.

#### 3.5 Grammar extension validation

When a user adds a grammar rule via PPN Track 7:
- Compute gfp of "parses for any string" with old grammar
- Compute gfp with new grammar (old + extension)
- If gfp GROWS (more parses possible), the extension introduces ambiguity
- If gfp stays the same, the extension is unambiguous

This is a STATIC check on grammar extensions — no test strings needed.
The gfp comparison IS the ambiguity analysis.

### The bilattice model for parsing

Combining lfp (derivation) and gfp (elimination) into a bilattice for
parsing:

- **Derivation ordering** (lfp): "what parse trees can be derived?"
  Accumulates derivations monotonically.
- **Elimination ordering** (gfp): "what parse trees can be ruled out?"
  Eliminates impossibilities monotonically (in dual).

The COMBINED fixpoint is the "well-founded parse" — derivations that
exist AND are not ruled out. This parallels WF-LE's well-founded
semantics exactly.

**This is a novel contribution.** No existing parsing framework uses a
bilattice combining derivation and elimination. It falls naturally from
our architecture because WF-LE already provides the bilattice fixpoint
machinery.

**Implication for PPN Track 0 (lattice design)**: The parse lattice
should be a BILATTICE, not a simple lattice. Two orderings: derivation
(what's parsed) and elimination (what's impossible). The reduced product
with the type lattice adds a third dimension (type consistency). The
ATMS manages branching across all three.

---

## 4. Cross-Network Information Sources for Parsing

Every lattice domain on the network is a potential disambiguation source.
The parser isn't a standalone phase — it participates in the full
network's fixpoint.

| Domain | What it tells the parser | Example |
|--------|------------------------|---------|
| Type lattice | Arity, argument types, return types | `f x y z` — type of `f` reveals arity |
| Session lattice | Expected communication actions | `send x` — protocol expects `Send Int` |
| QTT multiplicities | Usage constraints | Linear variable used twice → parse error |
| Effect lattice | Effect context constraints | IO operation in pure function → invalid form |
| Module exports | Available names | `use foo (bar)` — verify `bar` exists during parse |
| Trait constraints | Overloaded resolution | `[+ x y]` — resolve `+` based on `x`'s type |
| Narrowing lattice | Value constraints | Pattern match on `x` — narrowing knows possible constructors |
| Coercion lattice | Implicit conversions | `f(nat_val)` where `f : Int -> _` — coercion from Nat |

These sources flow BACKWARD (from downstream domains into the parser)
via Galois bridges. Each bridge α/γ pair mediates a specific cross-domain
information channel:

- `TypeToParse` bridge: type constraints disambiguate surface forms
- `SessionToParse` bridge: protocol state constrains valid operations
- `MultToParse` bridge: linearity constrains variable usage forms
- `EffectToParse` bridge: effect context constrains valid forms

Each bridge is a Galois connection — the backward flow (γ) is
well-defined and sound. The parser's disambiguation is not heuristic —
it's the γ-image of downstream constraints projected into the parse
domain.

---

## 5. NF-Narrowing as PRN Strategy Layer

### DTs are the universal rewrite strategy

Definitional trees provide OPTIMAL rule selection for inductively
sequential systems. The optimality result (Antoy 2005): needed narrowing
(guided by DTs) uses the MINIMUM number of narrowing steps to reach a
result. No other strategy uses fewer.

This optimality transfers to other rewriting domains IF the rules are
inductively sequential:

| Domain | Rules | Inductively sequential? | DT applicability |
|--------|-------|------------------------|-----------------|
| NF-Narrowing | Function clauses | YES (by construction — DTs are built from patterns) | OPTIMAL (proven) |
| Parsing (CFG) | Grammar productions | YES (each production matches a specific nonterminal at a specific position) | CONJECTURED optimal |
| SRE decomposition | Constructor descriptors | YES (each ctor matches a specific tag) | CONFIRMED (prop:ctor-desc-tag = 1-level DT) |
| β-reduction | Lambda applications | PARTIALLY (β-rule matches any application of any lambda — not constructor-specific) | DTs for specific function definitions, not general β |
| Optimization | Rewrite rules | DEPENDS on rule set | DTs when rules are pattern-based |

### The SRE's ctor-desc dispatch IS a 1-level DT

`prop:ctor-desc-tag` maps a value to its constructor descriptor. This
is a 1-level definitional tree: examine the root constructor, dispatch
to the corresponding rule.

Multi-level DTs would handle nested patterns — examining multiple
positions before selecting a rule. This is what NF-Narrowing does for
function definitions. PPN would need multi-level DTs for grammar rules
that match nested surface forms.

### Residuation = propagator waiting (exact correspondence)

When a DT demands information at position P, and the value at P is a
variable (not ground):
- NF-Narrowing: RESIDUATES — suspends until P is narrowed
- Propagator network: cell at P has value bot — propagator doesn't fire

These are the SAME behavior. Residuation IS the propagator waiting-for-
information pattern. This is not an analogy — it's an identity.

**Implication**: If parsing rules residuate (a grammar rule needs to see
a token that hasn't been lexed yet), the propagator network handles it
automatically. No special "residuation" mechanism needed for PPN — it's
the standard cell-at-bot behavior.

---

## 6. Open Questions from This Conversation

1. **Can the demand lattice unify DT demands, type-checking demands,
   and parse demands?** If so, Right Kan becomes a single mechanism
   serving all three. What is the carrier set? What is the ordering?

2. **Does needed-narrowing optimality transfer to CFG parsing?** The
   conjecture: DT-guided rule selection for CFGs is provably optimal
   (minimum production applications). The proof would require showing
   CFG productions are inductively sequential.

3. **Is the parse bilattice (derivation × elimination) useful in
   practice?** The theoretical structure is clean. Does it ACTUALLY help
   with error recovery or disambiguation, or is the standard lattice
   (derivation only + ATMS elimination) sufficient?

4. **How does Left Kan pruning interact with ATMS branch management?**
   If Left Kan prunes a branch, does the ATMS need to record a nogood?
   Or is the pruned branch simply never created?

5. **What is the categorical structure of the 4-level strategy
   (branch → prune → focus → select)?** Is it a chain of adjunctions?
   A composition of monads? Does the structure guarantee that the
   composition is well-defined (consistent, terminating)?

6. **Can tropical cost + Left Kan approximation give us "anytime"
   parsing?** Return the best parse found so far (cheapest surviving
   branch) at any time, refine as more branches are explored. This
   would give responsive IDE behavior — instant (approximate) results,
   progressively refined.
