# UCS (Universal Constraint Solving) — Series Master Tracking

**Created**: 2026-03-28
**Status**: Research (Stage 0/1)
**Thesis**: Any domain with sufficient algebraic structure supports automatic constraint solving via propagators. A domain-polymorphic `#=` operator selects solving strategy based on the domain's algebraic class. The propagator network IS the universal constraint solver — each algebraic embedding brings its own solving toolkit.

**Origin**: Module Theory on Lattices + Algebraic Embeddings research + PTF Track 1 residuation finding + NF-Narrowing vision

---

## The Vision

The `#=` operator works across ANY domain lattice:
- **Types**: `#= (PVec ?A) (PVec Int)` → structural unification (SRE equality)
- **Sessions**: `#= S (dual T)` → duality constraint (SRE duality)
- **Arithmetic**: `#= (+ x 3) 7` → residuation: `x #= 4`
- **Sets**: `#= S (union A B)` → set constraint propagation
- **Resources**: `#= m (mult a b)` → quantale multiplication

The solving strategy is determined by the domain's algebraic class:
- **Boolean algebra** → SAT/CDCL (watched literals, conflict-driven learning)
- **Heyting algebra** → intuitionistic constraint solving (pseudo-complement = precise incompatibility)
- **Residuated lattice** → backward propagation (automatic residual computation)
- **Quantale** → resource-aware solving (multiplicative constraints)
- **Distributive lattice** → efficient join/meet propagation
- **Free algebra** → standard unification (Robinson/Martelli-Montanari)

The algebraic CSP dichotomy theorem (Bulatov-Zhuk) guarantees: constraint solving on a domain is either polynomial (if the domain has sufficient algebraic structure) or NP-hard (if it doesn't). Detecting which algebraic class a domain belongs to determines whether automatic solving is feasible.

---

## Progress Tracker

| Track | Description | Status | Notes |
|-------|------------|--------|-------|
| R0 | Research: Universal Constraint Solving Foundations | ⬜ | Bulatov-Zhuk, DPLL(T), lattice-based solving, residuated constraints |
| R1 | Research: NF-Narrowing as Residuation | ⬜ | PTF Track 1 confirmed first-order case. Extend to general case. |
| R2 | Research: `#=` Operator Design | ⬜ | Domain-polymorphic unification. Type-level dispatch via algebraic class. |
| 1 | `#=` Prototype — structural unification across domains | ⬜ | Depends on SRE Track 2F (algebraic foundation) + 2G (domain awareness) |
| 2 | Residuation Engine — automatic backward propagators | ⬜ | Depends on R1. For domains that are residuated: derive backward from forward. |
| 3 | CDCL Integration — SAT optimization for Boolean domains | ⬜ | Depends on BSP-LE (ATMS). For domains that are Boolean: watched literals, conflict learning. |
| 4 | Resource Constraints — quantale-based solving | ⬜ | For QTT multiplicities, session linearity, effect resource tracking. |

---

## Research Documents

| Document | Date | Scope |
|----------|------|-------|
| [Universal Constraint Solving](../research/2026-03-28_UNIVERSAL_CONSTRAINT_SOLVING.md) | 2026-03-28 | Bulatov-Zhuk, DPLL(T), residuated solving, algebraic CSP |
| [Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md) | 2026-03-28 | Endomorphism ring, Krull-Schmidt, residuation |
| [Algebraic Embeddings on Lattices](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) | 2026-03-28 | Heyting, Boolean, quantale, matroid, topology embeddings |

---

## Cross-Series Connections

| Series | Connection |
|--------|-----------|
| **SRE** | Track 2F (algebraic foundation) provides the kind registry. Track 2G (domain awareness) provides algebraic class declarations. UCS builds ON these. |
| **PTF** | Propagator kinds (Map, Reduce, Scatter) gain constraint-solving semantics. Reduce = meet constraint. Scatter = decomposition constraint. |
| **BSP-LE** | ATMS is Boolean algebra constraint management. UCS generalizes: ATMS is one algebraic class among many. CDCL optimization applies when domain is Boolean. |
| **PAR** | Constraint solving is monotone fixpoint computation. CALM guarantees parallel constraint propagation is correct. UCS inherits PAR's parallel infrastructure. |
| **PPN** | Parsing constraints (ambiguity, precedence) are lattice constraints. Parse disambiguation = constraint solving on token lattice. |
| **PRN** | Rewriting modulo constraints. E-graph saturation IS constraint solving on quotient lattice. |
| **CIU** | Collection trait dispatch IS constraint solving: narrow impl candidates by type information. |
| **NTT** | Syntax for declaring domain algebraic class: `:lattice :heyting`, `:lattice :residuated`, `:lattice :boolean`. |

---

## Open Questions

1. Is our type lattice Heyting? (Determines error reporting precision)
2. What is the minimal algebraic structure for automatic backward propagation? (Residuated? Weaker?)
3. Can we detect algebraic class automatically by testing properties? (Distributivity test, pseudo-complement existence)
4. How does `#=` interact with QTT multiplicities? (Resource-aware constraint solving)
5. What is the relationship between `#=` and the `solve` engine? (Are relational queries special cases of `#=`?)
6. Can the Bulatov-Zhuk dichotomy theorem guide our API design? (Warn/error when domain lacks tractable algebraic structure)
