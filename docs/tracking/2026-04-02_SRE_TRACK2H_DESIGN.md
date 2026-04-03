# SRE Track 2H: Type Lattice Redesign — Stage 3 Design (D.5)

**Date**: 2026-04-02
**Series**: [SRE (Structural Reasoning Engine)](2026-03-22_SRE_MASTER.md)
**Prerequisites**: [SRE Track 2G ✅](2026-03-30_SRE_TRACK2G_DESIGN.md) (Algebraic Domain Awareness — property inference, meet, ring action), [SRE Track 2F 🔄](2026-03-28_SRE_TRACK2F_DESIGN.md) (Algebraic Foundation — variance table, merge registry)
**Audit**: [SRE Track 2H Stage 2 Audit](2026-04-02_SRE_TRACK2H_STAGE2_AUDIT.md)
**Principle**: Propagator Design Mindspace ([DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) § Propagator Design Mindspace)

**Research**:
- [Algebraic Embeddings on Lattices](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — §2.4 Heyting algebra for error reporting, §2.5 Residuated lattice for backward propagation
- [Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — endomorphism ring, variance as ring action
- [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — reduced product, chaotic iteration

**Cross-series consumers**:
- [PPN Track 4](2026-03-26_PPN_MASTER.md) — elaboration on network requires well-structured type lattice (PREREQUISITE)
- [SRE Track 3](2026-03-22_SRE_MASTER.md) — trait resolution strategy informed by Heyting properties
- BSP-LE — ATMS worldview management benefits from type lattice algebraic structure

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0 benchmarks + property checks | ✅ | 30 tests across 5 tiers. Design unchanged — data confirms all phases correctly scoped. See §Pre-0. |
| 1 | Extract union type helpers to standalone module | ✅ | `7a91db47`. union-types.rkt created. Duplicates removed from type-lattice.rkt + unify.rkt. |
| 2 | Subtype-aware join WITH absorption (atomic) | ✅ | `8bb7af3d`. subtype-lattice-merge redesigned. Bot/top handling fixes V1d. absorb-subtype-components (scaffolding). |
| 3 | Extend try-intersect-pure to all registered constructors | ✅ | `0ba64c3b`. Generic descriptor-driven meet. 9 constructors gained (2→11). Ring action per variance. |
| 4 | Tensor (⊗): core + distribute + SRE registration | ✅ | `0edee767`. type-tensor-core (bot-on-failure, F1) + type-tensor-distribute (scaffolding) in subtype-predicate.rkt. SRE registration in Phase 6. |
| 5 | Tensor-aware elaboration: infer for union-typed expr-app | ✅ | `493cfc68`. expr-app handles union function types via type-tensor-distribute. |
| 6 | Per-relation property declarations on sre-domain | ✅ | `bba6f7ab`. sre-domain +operations field (12th). declared-properties nested by relation. 13 sites migrated. |
| 7 | Validate algebraic properties: Heyting (ground sublattice) + quantale | ✅ | `5735b9e8`. V4 distributivity: 0/512 (was 412). Meet distributes over unions. Subtype callback. Sort key fix. |
| 8 | Pseudo-complement computation for error reporting | ✅ | `19e165e2`. SCAFFOLDING. type-pseudo-complement verified: ¬Int={Bool\|String}, ¬(Int\|String)={Bool}. |
| 9 | Verification + acceptance file + PIR | 🔄 | Suite 383/383 GREEN throughout. A/B data recorded. PIR in progress. |

---

## §1 Objectives

**End state**: The type lattice under the subtype ordering is a **quantale** — a Heyting algebra equipped with a tensor (function application) that distributes over the join. The join of incomparable types is a union type (`Int | String`), not type-top. The meet is a subtype-aware GLB using the ring action from Track 2G. The tensor applies Pi types to argument types, distributing over unions on both sides. Per-relation property declarations let the subtype ordering declare its full algebraic structure independently of the equality ordering. The elaborator handles union types in function application via the tensor's distributive law. Pseudo-complement error reporting is the first Heyting consumer.

**What is delivered**:
1. `union-types.rkt` — extracted union type helpers (eliminates duplication + drift risk)
2. Redesigned `subtype-lattice-merge` that produces union types for incomparable types
3. Subtype absorption in ACI union normalization (`Nat | Int → Int`)
4. Complete `try-intersect-pure` coverage via ctor-registry descriptors (not just Pi/Sigma)
5. `type-tensor` — reified function application as a lattice operation, distributing over unions
6. Tensor-aware elaboration: `infer`/`check` for `expr-app` handle union function types and union argument types via distribution
7. Per-relation property declaration infrastructure on `sre-domain`
8. Property inference validation: subtype ordering is Heyting AND quantale
9. Pseudo-complement computation: `pseudo-complement(A, B)` = largest X such that `X ⊓ A ≤ B`
10. Informative type error messages using pseudo-complement

**What this track is NOT**:
- It does NOT change the equality merge (`type-lattice-merge` remains flat — `Nat ⊔_eq String = ⊤` is correct for equality). Equality and subtype are different orderings on the same carrier. This is the L3 lesson from Track 2G.
- It does NOT put elaboration on-network as propagators — the tensor is a reified FUNCTION, not yet a propagator. PPN Track 4 makes it a propagator. Track 2H delivers the algebraic operation that Track 4 will wire into the network.
- It does NOT replace the imperative speculation for union checking (`with-speculative-rollback` at `typing-core.rkt:2424`). This is debt that PPN Track 4 retires via ATMS: union components become assumptions, elaboration proceeds under each in parallel, the ATMS manages consistency. Track 2H adds no new speculation paths — Phase 6 uses pure `type-tensor` (no rollback).
- It does NOT implement backward type propagation via residuation — deferred to the residuated lattice track (requires full bidirectional propagator infrastructure).
- It does NOT make `sre-domain` use keyword arguments — that debt (Track 2G L4) is out of scope here unless we touch the struct definition.

---

## §2 Mathematical Grounding

### The Two Orderings

The type carrier set admits two orderings:

1. **Equality ordering**: `a ≤_eq b` iff `a = b`. This is a discrete (flat) lattice. Join of distinct atoms is top. This is CORRECT — equality unification SHOULD produce a contradiction when `Nat ≠ String`. The equality merge is the unification merge.

2. **Subtype ordering**: `a ≤_sub b` iff `a <: b`. This is a partial order with chains (Nat <: Int <: Rat) and incomparable pairs (Int ≁ String). Currently, the join of incomparable types is type-top. The CORRECT join is the union type.

Track 2H redesigns the subtype ordering's lattice operations. The equality ordering is unchanged.

### Target: Heyting Algebra under Subtype Ordering

A **Heyting algebra** is a bounded lattice where for every pair (a, b), the pseudo-complement `a → b = max{x | x ∧ a ≤ b}` exists. Requirements:

1. **Distributive**: `a ⊓ (b ⊔ c) = (a ⊓ b) ⊔ (a ⊓ c)` where ⊔ is union-join, ⊓ is GLB-meet.
2. **Bounded**: type-bot (⊥) and type-top (⊤) exist. ✅ Already have these.
3. **Pseudo-complement exists**: For every a, b, the set `{x | x ⊓ a ≤ ⊥}` has a maximum.

Every finite distributive lattice is automatically Heyting (Birkhoff). Our type lattice is not finite (polymorphic types, dependent types), but for GROUND types (no metas, no binders) the working sublattice at any point in elaboration IS finite and distributive under union-join + GLB-meet.

### Worked Examples

**Join (union-join)**:
- `Int ⊔ String = Int | String` (incomparable → union)
- `Nat ⊔ Int = Int` (Nat <: Int → absorbed, subtype absorption)
- `(Int | String) ⊔ Nat = Int | String` (Nat <: Int → absorbed into Int component)
- `⊥ ⊔ A = A`, `A ⊔ ⊤ = ⊤`

**Meet (GLB-meet)**:
- `Int ⊓ Nat = Nat` (Nat <: Int → GLB is Nat)
- `Int ⊓ String = ⊥` (incomparable, no common subtype)
- `(Int | String) ⊓ Int = Int` (distribute: `(Int ⊓ Int) | (String ⊓ Int) = Int | ⊥ = Int`)
- `⊤ ⊓ A = A`, `⊥ ⊓ A = ⊥`

**Pseudo-complement**:
- `¬_Int(String) = max{X | X ⊓ String ≤ ⊥}` = everything NOT String = the complement of String in the working sublattice
- For ground type errors: `¬_context(conflicting_type)` gives the maximal type compatible with the context that excludes the conflicting type

**Distributivity verification** (the critical law):
- `Nat ⊓ (Int | String) = (Nat ⊓ Int) | (Nat ⊓ String) = Nat | ⊥ = Nat` ✅
- `(Int | Bool) ⊓ (Int | String) = Int | (Bool ⊓ String) = Int | ⊥ = Int` ✅ (by distributing both sides)

**Distributivity scope** (F7): The Heyting claim is validated for the **ground sublattice** (no metas, no binders). For dependent types with binder substitution (e.g., `meet(Pi(x:Nat, x), union(Pi(x:Nat, Nat), Pi(x:Int, Int)))`), distributivity is conjectured but not yet verified — substitution under binders does not obviously distribute over union-join. Phase 7 tests with binder types to validate or bound the claim.

### Equality Merge with Union Types (F9)

After Track 2H, union types exist as first-class type expressions. The equality merge (`type-lattice-merge`) is UNCHANGED — it remains flat. Worked examples:

- `(Int | String) ⊔_eq (Int | String) = Int | String` ✅ (equal? → identity)
- `(Int | String) ⊔_eq Int = type-top` ✅ (not equal — `try-unify-pure` fails, shapes differ)
- `(Int | String) ⊔_eq (String | Int) = Int | String` ✅ (canonical form → equal? succeeds)

This is correct: equality merge and subtype merge are DIFFERENT operations on DIFFERENT cells. A cell under equality merge that receives both `Int | String` and `Int` gets contradiction — because the values are not equal. A cell under subtype merge would give `Int | String` — because `Int <: Int | String`.

### Asymmetric Relationship Between Orderings (F12)

The equality ordering REFINES the subtype ordering: `a = b ⟹ a <: b`, but NOT the reverse. Information flows ONE WAY: equality resolution constrains subtype (if `a = b` is known, then `a <: b` is also known). But subtype resolution does NOT constrain equality (knowing `Nat <: Int` does not mean `Nat = Int`). Currently, equality and subtype use DIFFERENT cells — the equality merge cells are main elaboration type cells; subtype merge cells are short-lived SRE query cells. No bridge is needed today. PPN Track 4's design should address whether this asymmetric flow needs an explicit Galois bridge when both orderings coexist on the same network.

### Subtype Absorption

When building a union type, any component that is a subtype of another component is absorbed:
- `Nat | Int → Int` (Nat <: Int)
- `Nat | Rat → Rat` (Nat <: Rat by transitivity)
- `Posit8 | Posit32 | Posit64 → Posit64` (Posit8 <: Posit32 <: Posit64)
- `Int | String → Int | String` (incomparable, both retained)

Absorption is the canonical form computation WITHIN the join — like reducing fractions (M4). `Nat | Int` and `Int` denote the SAME lattice element (because `Nat <: Int` means `Nat ⊔ Int = Int`). No information is lost; both representations denote the same set of values. Monotonicity is preserved: `merge(Nat, Int) = Int ≥ Nat` in the subtype ordering.

This is ACI normalization PLUS subtype absorption, delivered as a single atomic operation (F11) — the merge function never produces non-canonical unions. The explicit `absorb-subtype-components` algorithm (flatten → pairwise filter) is **scaffolding** (F3): in the permanent network architecture, absorption is emergent from pairwise cell merges as writes arrive.

---

## §Pre-0: Benchmark Data and Findings

**Benchmark file**: `benchmarks/micro/bench-sre-track2h.rkt` (commit `a8023d58`)
**30 tests across 5 tiers**: M1-M8 micro, A1-A6 adversarial, E1-E4 E2E, V1-V6 algebraic, T1-T4 tensor.

### Performance Baselines

| Operation | Cost | Track 2H Implication |
|-----------|------|---------------------|
| `subtype-lattice-merge` incomparable (M2c) | 0.3μs | Currently returns type-top. After 2H: +0.2μs for union build + absorption |
| `subtype-lattice-merge` chain Nat→Int (M2b) | 0.1μs | Unchanged — subtype path already returns b |
| `build-union-type` 2-component (M5a) | 0.2μs | Cheap ACI normalization. No concern. |
| `build-union-type` 5-component (M5c) | 0.9μs | Linear growth. Acceptable. |
| `subtype?` flat positive (M4a) | 0.1μs | Per-pair cost in absorption. 10 components ≈ 9μs total |
| Absorption N^2: 10 components (A3b) | 16μs | Measured directly. Acceptable for typical 2-5 component unions |
| Absorption N^2: 20 components (A3c) | 72μs | Quadratic visible. Pathological but survivable. |
| `type-lattice-meet` incompatible (M3c) | 309μs | **whnf-dominated**. Structural operations are noise. |
| `type-lattice-meet` Pi ring action (M3d) | 609μs | Two whnf calls. Phase 4 extends to all constructors — same cost pattern. |
| `try-unify-pure` equal atoms (M7a) | 305μs | Also whnf-dominated. Baseline for equality merge. |
| Tensor simulation 3-union (A6a) | 223μs | subtype? + subst per component. Dominated by whnf in subtype?. |
| Hot-path 1000x incomparable (A5c) | 0.3ms | 1000 subtype-lattice-merge calls. After 2H: ~0.5ms (union build adds ~0.2μs each). |

**Key insight**: `whnf` (~300μs) dominates every structural lattice operation. Track 2H's additions (union construction 0.2μs, absorption 16μs for 10 components) are negligible. **No performance risk from the redesign.**

### E2E Baselines

| Program | Median | Description |
|---------|--------|-------------|
| E1 | 86.5ms | Numeric subtyping (simple Nat/Int) |
| E2 | 85.4ms | Mixed-type map (union values — existing consumer) |
| E3 | 98.8ms | Pattern matching with data constructors |
| E4 | 79.8ms | Subtype in arithmetic context |

These are dominated by prelude loading + elaboration. Track 2H lattice changes are invisible at E2E scale.

### Algebraic Findings

| Test | Failures | Analysis |
|------|----------|----------|
| V1a commutativity | 0/324 | ✅ subtype-lattice-merge is commutative |
| V1b associativity | 0/512 | ✅ associative |
| V1c idempotence | 0/18 | ✅ idempotent |
| V1d identity (bot) | **18/18** | **BUG**: `subtype-lattice-merge` missing bot handling. merge(bot, x) goes to subtype? path which returns #f, then → type-top. Phase 2 adds explicit bot/top cases. |
| V1e absorption (top) | 0/18 | ✅ top is absorbing |
| V2a meet commutativity | 0/324 | ✅ |
| V2b meet identity (top) | 0/18 | ✅ |
| V2c meet annihilator (bot) | 0/18 | ✅ |
| V3 distributivity (equality) | 336/512 | ✅ Expected — confirms Track 2G finding (flat lattice) |
| V4 distributivity (subtype) | 412/512 | Expected pre-2H — target 0 after Track 2H |
| V5 absorption law | **56/64** | Compound bug: meet(Nat,Int)=bot (uncovered by try-intersect-pure) + merge(Nat,bot)=top (missing bot handling). Fixed by Phases 2+4. |
| V6 subtype consistency | 0/3 | ✅ a<:b → join(a,b)=b holds |
| T1 right-distribution | 0/2 | ✅ (trivially — both sides → top currently) |
| T3 annihilation | 0/0 | ✅ bot is not Pi, tensor returns bot |
| T4 identity | 0/8 | ✅ id(a)=a holds for all base types |

**Total non-expected failures: 74** (V1d: 18 + V5: 56). Both are consequences of two known gaps: (1) missing bot handling in subtype-lattice-merge, (2) incomplete try-intersect-pure. Both are in Track 2H scope (Phases 2 and 4 respectively).

### Design Impact

### Post-Implementation A/B Comparison

| Metric | Pre-Track-2H | Post-Track-2H | Change |
|--------|-------------|---------------|--------|
| `subtype-lattice-merge` incomparable (M2c) | 0.3μs | 1.3μs | +1.0μs (builds union) |
| `build-union-type` 2-component (M5a) | 0.2μs | 0.2μs | unchanged |
| `type-lattice-meet` incompatible (M3c) | 309μs | 2.3μs | **-307μs** (whnf fast-path + subtype callback) |
| `subtype?` flat positive (M4a) | 0.1μs | 0.1μs | unchanged |
| Absorption 10 components (A3b) | 16μs | 15μs | unchanged |
| Hot-path 1000x incomparable (A5c) | 0.3ms | 1.3ms | +1.0ms (union construction) |
| E1 numeric (ms) | 86.5 | 83.3 | -3.2ms |
| E2 mixed-map (ms) | 85.4 | 81.2 | -4.2ms |
| E3 pattern (ms) | 98.8 | 96.6 | -2.2ms |
| E4 subtype (ms) | 79.8 | 78.7 | -1.1ms |
| V4 distributivity (subtype) | 412/512 fail | **0/512** | ✅ TARGET MET |
| V1d identity | 18/18 fail | **0/18** | ✅ FIXED |
| V5 absorption | 56/64 fail | **0/64** | ✅ FIXED |
| Suite wall time | 136.2s | 131.4s | **-3.5%** |

Subtype merge +1μs for incomparable (union construction vs returning sentinel) — expected, acceptable. Meet 130× faster from whnf fast-path. E2E improved across the board. All algebraic targets met.

### Design Impact (Pre-0)

**No design changes.** The data confirms:
1. All phases are correctly scoped — the two existing bugs (V1d, V5) are exactly what Phases 2 and 4 fix.
2. Performance overhead of union types is negligible (dominated by whnf at ~300μs per structural op).
3. Tensor axioms hold where testable; left-distribution (T2) deferred to post-implementation (requires union-of-Pi types).
4. The 412 V4 distributivity failures are the gap Track 2H closes — the target is 0 failures post-implementation.

---

## §3 Design

### §3.1 Phase 1: Extract union-types.rkt

**Problem**: `flatten-union`, `union-sort-key`, `dedup-union-components`, and `build-union-type` are duplicated between type-lattice.rkt and unify.rkt with active drift (unify.rkt has more sort key entries). type-lattice.rkt can't import unify.rkt (circular via metavar-store.rkt).

**Solution**: Extract pure union type helpers into `union-types.rkt`:
- `flatten-union : Expr → (Listof Expr)`
- `union-sort-key : Expr → String`
- `dedup-union-components : (Listof Expr) → (Listof Expr)`
- `build-union-type : (Listof Expr) → Expr`

Both type-lattice.rkt and unify.rkt import from union-types.rkt. The new module depends only on syntax.rkt (struct definitions). Delete the duplicate `*-pure` versions from type-lattice.rkt and the originals from unify.rkt.

**Principle served**: Decomplection (5). Separable concerns separated. One canonical union normalization.

### §3.2 Phase 2: Subtype-aware join WITH absorption (atomic, F11)

**Rationale for merging old Phases 2+3**: The subtype-lattice-merge must never produce non-canonical unions. Either it produces `type-top` (pre-Track-2H) or it produces absorbed unions (post-Track-2H). A non-absorbed union like `Nat | Int` violates the absorption law (`a ⊔ (a ⊓ b) = a`) — it is not a valid lattice element. The algebraic change is atomic: join + absorption together, or neither.

**Current** (`subtype-predicate.rkt:198`):
```racket
(define (subtype-lattice-merge a b)
  (cond
    [(equal? a b) a]
    [(subtype? a b) b]
    [(subtype? b a) a]
    [else type-top]))  ;; ← THIS becomes union type with absorption
```

**Redesigned**:
```racket
(define (subtype-lattice-merge a b)
  (cond
    [(type-bot? a) b]           ;; identity (fixes V1d)
    [(type-bot? b) a]
    [(type-top? a) type-top]    ;; absorbing
    [(type-top? b) type-top]
    [(equal? a b) a]            ;; idempotent
    [(subtype? a b) b]          ;; a ≤ b → join = b (absorption for comparable)
    [(subtype? b a) a]
    ;; Meta handling: keep concrete side. KNOWN UNSOUNDNESS (F2):
    ;; not monotone in the merge function itself — compensated by
    ;; solve-meta! + constraint-retry pipeline. Pre-existing pattern
    ;; inherited from type-lattice-merge. Retirement: PPN Track 4
    ;; ATMS-conditional cell values make this unnecessary.
    [(or (has-unsolved-meta? a) (has-unsolved-meta? b))
     (if (has-unsolved-meta? a) b a)]
    [else
     ;; Incomparable under subtyping → canonical union with absorption
     (build-union-type-with-absorption (list a b))]))
```

**`build-union-type-with-absorption`**: flatten + sort + dedup + absorb + fold. Absorption removes any component that is a subtype of another: `Nat | Int → Int`. The O(n^2) pairwise `subtype?` check in `absorb-subtype-components` is **scaffolding** (F3): in the permanent network architecture, absorption is emergent from pairwise cell merges as writes arrive. No list, no n^2 — the cell's merge function handles it pair-by-pair.

**Monotonicity argument**: `merge(a, b) ≥ a` and `merge(a, b) ≥ b` in the subtype ordering. `merge(Int, String) = Int | String`. Is `Int | String ≥ Int`? Yes — `Int <: Int | String`. `merge(Nat, Int) = Int`. Is `Int ≥ Nat`? Yes — `Nat <: Int`. Commutativity: canonical sort. Associativity: flatten + re-absorb. Idempotent: dedup.

**Where called**: Via merge-registry in type-sre-domain and type-sre-domain-for-subtype. Also from structural subtype checking.

### §3.3 Phase 3: Complete try-intersect-pure

**Current coverage**: Pi (with ring action), Sigma (both covariant). Everything else → `#f` → `type-bot`.

**Target**: All registered type-domain constructors with binder-depth 0.

**Approach**: Mirror the pattern from `try-unify-pure`'s else branch (type-lattice.rkt:367-377), which already uses generic descriptor-driven merge for join. Do the same for meet:

```racket
;; In try-intersect-pure, after Pi and Sigma cases:
[else
 (define desc-a (ctor-tag-for-value a))
 (cond
   [(and desc-a
         (eq? (ctor-desc-domain desc-a) 'type)
         (= (ctor-desc-binder-depth desc-a) 0)
         ((ctor-desc-recognizer-fn desc-a) b))
    ;; Same constructor, no binders — component-wise meet with ring action
    (generic-meet a b #:type-meet type-lattice-meet
                      #:type-join type-lattice-merge
                      #:domain 'type)]
   [else #f])]
```

Where `generic-meet` mirrors `generic-merge` but applies the ring action:
- Covariant (+): meet (monotone preserves)
- Contravariant (-): join (antitone flips)
- Invariant (=): equality (mismatch → #f)
- Phantom (ø): phantom (erased)

**Constructors gained**: app, Eq, Vec, Fin, pair, suc, PVec, Set, Map — 9 constructors, bringing total meet coverage from 2 to 11.

**Principle served**: Completeness (6). The meet was incomplete (only Pi/Sigma). Generic descriptor-driven meet makes it complete for all registered types.

### §3.4 Phase 4: Tensor (⊗) — type-level function application

**The operation**: The tensor takes a SINGLE function type and a SINGLE argument type and produces the result type. This is Pi elimination at the type level — the CORE lattice operation.

Distribution over unions is NOT part of the core tensor. In a propagator network, distribution is EMERGENT: multiple writes to the same output cell (one per union component) produce the union via the cell's merge function. The core tensor is what Track 4 wires as a propagator fire function. The imperative distribution wrapper is scaffolding for the pre-network elaborator.

**Core tensor** (`type-tensor-core`):
```racket
;; The core quantale tensor: single Pi × single arg → result
;; This is the operation Track 4 wires as a propagator.
;; Returns type-bot for inapplicable types (F1: NOT type-top).
;; In a propagator network, "can't apply" = propagator doesn't write
;; = output cell stays at bot (no information). type-top means
;; CONTRADICTION (two conflicting pieces of information), which is
;; semantically different from "no applicable function."
(define (type-tensor-core func-type arg-type)
  (cond
    [(type-bot? func-type) type-bot]  ;; no info → no output
    [(type-bot? arg-type) type-bot]
    [(type-top? func-type) type-top]  ;; genuine contradiction propagates
    [(type-top? arg-type) type-top]
    [(expr-Pi? func-type)
     (let ([domain (expr-Pi-domain func-type)]
           [codomain (expr-Pi-codomain func-type)])
       (cond
         [(subtype? arg-type domain) (subst 0 arg-type codomain)]
         [(try-unify-pure arg-type domain) (subst 0 arg-type codomain)]
         [else type-bot]))]           ;; inapplicable → no info (not contradiction)
    [else type-bot]))                 ;; non-Pi → no info
```

**Distribution wrapper** (`type-tensor-distribute` — scaffolding):
```racket
;; Scaffolding: imperative distribution for pre-network elaborator.
;; In Track 4's propagator network, this is unnecessary — the network
;; fires the tensor per component, the output cell's merge produces the union.
(define (type-tensor-distribute func-type arg-type)
  (cond
    [(and (expr-union? func-type) (expr-union? arg-type))
     (build-union-type-with-absorption
       (for*/list ([f (flatten-union func-type)]
                   [a (flatten-union arg-type)])
         (type-tensor-core f a)))]
    [(expr-union? func-type)
     (build-union-type-with-absorption
       (for/list ([f (flatten-union func-type)])
         (type-tensor-core f arg-type)))]
    [(expr-union? arg-type)
     (build-union-type-with-absorption
       (for/list ([a (flatten-union arg-type)])
         (type-tensor-core func-type a)))]
    [else (type-tensor-core func-type arg-type)]))
```

**Key algebraic properties** (of `type-tensor-core`):
1. **Annihilation**: `f ⊗ ⊥ = ⊥`, `⊥ ⊗ a = ⊥`
2. **Absorbing element**: `f ⊗ ⊤ = ⊤`
3. **Identity**: `(A → A) ⊗ A = A`
4. **Associativity**: `(A → B → C) ⊗ A ⊗ B = C`

Distribution (properties 5-6 below) is network-level, verified by writing multiple results to the same cell:
5. **Right-distributes over join**: `f ⊗ (a ⊕ b) = (f ⊗ a) ⊕ (f ⊗ b)` — emergent from cell merge
6. **Left-distributes over join**: `(f ⊕ g) ⊗ a = (f ⊗ a) ⊕ (g ⊗ a)` — emergent from cell merge

**Module location**: `subtype-predicate.rkt` (NOT type-lattice.rkt — D.3 finding R1). `type-tensor-core` requires `subtype?` (in subtype-predicate.rkt) and `try-unify-pure` (in type-lattice.rkt). subtype-predicate.rkt already imports type-lattice.rkt, so it can access both. No circular dependency.

**SRE registration**: Register the tensor as a discoverable operation on `sre-domain` via a new `operations` field. Track 4 looks up any domain's tensor generically: `(hash-ref (sre-domain-operations domain) 'tensor)`.

**Operations contract** (F8): Each operation entry is a hash with metadata:
```racket
(hasheq 'tensor (hasheq 'name 'tensor
                        'fn type-tensor-core
                        'arity 2
                        'properties '(distributes-over-join associative has-identity)))
```
The `properties` list declares which lattice laws the operation satisfies. Track 4 uses these to wire propagators correctly: a tensor that distributes over join can be decomposed into per-component firings; one that does not cannot. Extensible — future operations (residual, pseudo-complement) follow the same contract.

**Dependency**: Phases 2-3 (union-join + absorption) must be complete. `type-tensor-distribute` uses `build-union-type-with-absorption`.

**Principle served**: Propagator-First (1) — core tensor is the propagator fire function; distribution is network behavior. Completeness (6) — full quantale. Data Orientation (2) — tensor registered as discoverable data on domain, not standalone function.

### §3.5 Phase 5: Tensor-aware elaboration

**Current state** (`typing-core.rkt:548-555`):
```racket
;; General case: infer function type, check argument
[_
 (let ([t1 (whnf (infer ctx e1))])
   (match t1
     [(expr-Pi m a b)
      (if (check ctx e2 a)
          (subst 0 e2 b)
          (expr-error))]
     [_ (expr-error)]))]  ;; ← union types hit this branch
```

**Problem**: If `t1` is an `expr-union` of Pi types (e.g., from overloading or subtype merge), it falls to `[_ (expr-error)]`. The elaborator cannot handle union-typed functions or union-typed arguments.

**Redesigned**:
```racket
[_
 (let ([t1 (whnf (infer ctx e1))])
   (cond
     ;; Direct Pi: existing fast path
     [(expr-Pi? t1)
      (if (check ctx e2 (expr-Pi-domain t1))
          (subst 0 e2 (expr-Pi-codomain t1))
          (expr-error))]
     ;; Union type: distribute via tensor (scaffolding wrapper)
     ;; type-tensor-core returns bot for inapplicable (F1), so
     ;; type-tensor-distribute may return bot (all components inapplicable)
     ;; or top (genuine contradiction). Both → expr-error.
     [(expr-union? t1)
      (let ([result (type-tensor-distribute t1 (infer ctx e2))])
        (if (or (type-bot? result) (type-top? result))
            (expr-error)
            result))]
     [_ (expr-error)]))]
```

**Eliminator exposure** (D.3 finding P2): Union types from the redesigned `subtype-lattice-merge` do NOT flow into main elaboration cells — those cells use equality merge. The subtype merge is used by the SRE structural subtype checker which returns `#t`/`#f`. New union type exposure is limited to: (1) existing map value widening (handled), (2) existing user-written union annotations (handled by check path), (3) type-tensor results from this phase. Only #3 is new — and it's bounded by where `expr-app` inference results flow. Eliminators like `fst`/`natrec`/`boolrec` would see unions only if a tensor result is immediately projected. Monitor during implementation; handle if concrete cases arise.

**Check path for unions** (`typing-core.rkt:2424`): Currently `check(G, e, A | B)` uses `with-speculative-rollback` — `save-meta-state`/`restore-meta-state!` to try `e : A`, roll back on failure, try `e : B`. This is imperative speculation, not propagator-based. After Track 2H, more union types flow through, so this path fires more often. Track 2H does NOT modify or extend this speculation path — no new `with-speculative-rollback` calls. The permanent solution is ATMS-based: each union component becomes an assumption, elaboration proceeds under each assumption in parallel, the ATMS manages consistency and retracts contradictory branches. This is PPN Track 4 scope. The existing speculation is documented as debt to be retired.

**Scope boundary**: This phase wires `type-tensor` into the existing imperative elaborator as a PURE function call (no speculation, no rollback). It does NOT put the tensor on-network as a propagator — that's PPN Track 4. Track 2H makes the elaborator WORK with union types; Track 4 makes it work ON-NETWORK with ATMS-managed assumption branches replacing imperative speculation.

### §3.6 Phase 6: Per-relation property declarations

**Current state**: `sre-domain.declared-properties` is a single `(hasheq property-name → property-value)`. Properties apply to the domain's equality merge.

**Problem**: The subtype ordering has DIFFERENT algebraic properties than the equality ordering. We need per-relation declarations.

**Design**: Change `declared-properties` from a flat hash to a nested hash:

```racket
;; Current (Track 2G):
declared-properties : (hasheq property-name → property-value)

;; Redesigned (Track 2H):
declared-properties : (hasheq relation-name → (hasheq property-name → property-value))
```

Example for type domain:
```racket
(hasheq
  'equality (hasheq 'commutative-join prop-confirmed
                    'associative-join prop-confirmed
                    'idempotent-join  prop-confirmed
                    'has-meet         prop-confirmed)
  'subtype  (hasheq 'commutative-join prop-confirmed
                    'associative-join prop-confirmed
                    'idempotent-join  prop-confirmed
                    'has-meet         prop-confirmed
                    'distributive     prop-confirmed  ;; NEW — validated by inference
                    'has-pseudo-complement prop-confirmed
                    'heyting          prop-confirmed))
```

**API changes**:
- `sre-domain-has-property?` gains optional `#:relation` keyword (defaults to `'equality` for backward compat)
- `with-domain-property` and `select-by-property` gain `#:relation` keyword
- `infer-domain-properties` runs PER-RELATION (samples same domain, uses relation's merge)
- `resolve-and-report-properties` reports per-relation

**Migration**: All existing callers use the default (`'equality`) — zero breakage. New code specifies `#:relation 'subtype` when needed. **13 construction sites** need flat→nested hash migration (D.3 finding R2): 5 production (unify.rkt, subtype-predicate.rkt, session-propagators.rkt, form-cells.rkt ×2), 4 test files, 2 benchmarks, 2 in sre-core.rkt tests.

**Why domain×relation, not relation alone** (D.3 finding P4, Track 2G L3): The same relation (e.g., `sre-subtype`) is shared across domains — it's the same endomorphism struct for types and sessions. But the algebraic properties of subtype ordering DIFFER by domain: `type.subtype` may be Heyting while `session.subtype` is not. `sre-relation.properties` holds endomorphism-level properties (antitone, involutive). `sre-domain.declared-properties` indexed by relation holds lattice-structure properties (distributive, Heyting). This factoring ensures future domains reuse relation structs with independent property declarations.

**The `#:relation` keyword API is scaffolding** (F5): callers choose which ordering to query via control flow, not information flow. In a propagator network, properties are CELL VALUES — a property cell for (type, subtype, distributive) holds `prop-confirmed`. The query is a cell read, not a function call with a keyword. Track 2G's `property-cell-ids` field on `sre-domain` (currently `(hasheq)` — empty) is the permanent home. Populating it requires domain registration AFTER network creation — the lifecycle ordering issue from Track 2G PIR §9. This is Track 4 scope.

**Principle served**: Data Orientation (2). Properties are data indexed by (domain, relation) — not embedded in control flow. Decomplection (5) — relation-level properties (endomorphism kind) separated from domain×relation properties (lattice structure).

### §3.7 Phase 7: Algebraic validation — Heyting (ground sublattice) + quantale

Run property inference on the redesigned subtype-lattice-merge:
- **Ground type samples**: `(expr-Nat) (expr-Int) (expr-Rat) (expr-String) (expr-Bool) (expr-Unit) (expr-Char) (expr-Keyword)` — same base types used in Track 2G
- **Compound type samples**: `(expr-PVec (expr-Nat))`, `(expr-Pi 'mw (expr-Int) (expr-Bool))` — structural coverage for meet
- **Binder type samples** (F7): `(expr-Pi 'mw (expr-Nat) (expr-bvar 0))`, dependent Pi with binder — test distributivity for non-ground cases
- **Lattice tests**: commutativity, associativity, idempotence, distributivity (using meet = GLB)
- **Expected ground results**: ALL four confirmed under subtype ordering
- **Expected binder results**: distributivity may fail for dependent types — document as conjectured, scope Heyting claim to ground sublattice
- **Tensor tests**: associativity, identity, annihilation, distribution over join
- **Implication derivation**: distributive + has-pseudo-complement → Heyting = prop-confirmed (ground sublattice)

This is the "Pre-0 property check" lesson from Track 2G — validate mathematical properties DURING design, not after implementation.

### §3.8 Phase 8: Pseudo-complement error reporting

**Pseudo-complement**: `¬a = a → ⊥ = max{x | x ⊓ a ≤ ⊥}`

For ground types under the subtype ordering with union-join + GLB-meet:
- `¬Int` in context `{Int, String, Bool}` = `String | Bool` (everything incompatible with Int)
- `¬(Int | String)` in same context = `Bool`
- `¬⊤` = `⊥`, `¬⊥` = `⊤`

**Implementation**: The pseudo-complement is computable for GROUND types with a finite working set (the types currently in scope). For the general case (with metas, with polymorphism), the pseudo-complement may not be computable — fall back to the current error format.

```racket
(define (type-pseudo-complement type context-types)
  ;; context-types: list of types currently in the working set
  ;; Returns the union of all context types incompatible with `type`
  (define incompatible
    (filter (lambda (t) (eq? type-bot (type-lattice-meet t type)))
            context-types))
  (if (null? incompatible)
      type-top
      (build-union-type-with-absorption incompatible)))
```

**Consumer**: In `typing-errors.rkt` or at the error reporting site, when a type contradiction is found (cell reaches type-top), compute the pseudo-complement of the conflicting constraint against the other constraints. This produces:
- WHICH types conflict (the two constraints that produced top)
- WHAT alternatives remain (the pseudo-complement)
- WHY they conflict (the meet that produced ⊥)

**This is SCAFFOLDING** (D.3 M2, D.5 F6). The function-over-list approach requires collecting "context types" into a list — information that isn't aggregated on-network today. It filters via meet — recomputing relationships the network already established.

**Context source** (F6): Even as scaffolding, the pseudo-complement should derive its context from the network's existing cell state where possible, not from an ad-hoc list parameter. If the elaboration scope's cell registry provides the needed type cells (investigate during implementation), use it. This keeps identity structural (cell references) rather than positional (list membership). If the registry doesn't track per-expression type cells (likely — that's Track 4), the list parameter is acceptable scaffolding.

**Permanent solution**: ATMS-derived. When a cell reaches type-top, the ATMS nogood records the minimal assumption set that produced the contradiction. Retracting the conflicting assumption gives the maximal consistent subset — which IS the pseudo-complement, falling out of the dependency structure without list filtering. **Retire when**: PPN Track 4 delivers ATMS-managed type cells. At that point, contradiction → nogood → pseudo-complement is on-network.

**Why build the scaffolding**: It's the first CONSUMER of the Heyting structure. It validates that the pseudo-complement is computable and produces useful error information. The scaffolding proves the concept; the ATMS replaces the mechanism.

**Principle served**: Progressive Disclosure (8). Simple errors show simple messages. The pseudo-complement is available for advanced diagnostics without cluttering basic output.

---

## §4 NTT Model

The NTT (speculative syntax) model for key constructs:

```
-- Type lattice with first-class join/meet operations (F10)
lattice TypeLattice
  :carrier Type
  :bot     type-bot
  :top     type-top
  :join    union-join        -- FIRST-CLASS: the lattice's join operation
  :meet    glb-meet          -- FIRST-CLASS: the lattice's meet operation

  -- Equality relation (unchanged) — uses its own merge, not the lattice join
  relation equality
    :merge [a b -> (try-unify-pure a b) | type-top]
    :properties {commutative associative idempotent has-meet}

  -- Subtype relation (REDESIGNED) — uses the lattice's join/meet
  relation subtype
    :merge union-join        -- delegates to lattice join
    :meet  glb-meet          -- delegates to lattice meet
    :properties {commutative associative idempotent distributive
                 has-meet has-pseudo-complement heyting}
    :properties-scope ground-sublattice  -- F7: dependent types conjectured

-- Union join with subtype absorption
def union-join [a b : Type] -> Type
  := |> [a b]
        flatten-union
        sort-canonical
        dedup
        absorb-subtypes     -- NEW: remove components that are subtypes of others
        fold-right expr-union

-- Meet via ring action (generic, descriptor-driven)
def generic-meet [a b : Type] -> Type
  := match (ctor-tag a) (ctor-tag b)
     | same-tag -> component-wise with ring-action:
                    covariant    -> meet
                    contravariant -> join
                    invariant    -> equality-or-bot
                    phantom      -> erased
     | diff-tag -> type-bot

-- Tensor (⊗): function application as quantale multiplication
-- CORE: single Pi × single arg — the propagator fire function
-- Returns bot for inapplicable (F1: not top — absence ≠ contradiction)
def type-tensor-core [f : Type, a : Type] -> Type
  := match f a
     | (Pi dom cod) a  -> if a <: dom then cod[a] else bot  -- inapplicable = no info
     | top _           -> top   -- genuine contradiction propagates
     | _ top           -> top
     | bot _           -> bot   -- no info in → no info out
     | _ bot           -> bot
     | _               -> bot   -- non-Pi = no applicable function

-- SCAFFOLDING: imperative distribution for pre-network elaborator
-- In Track 4's network, distribution is emergent from multiple cell writes.
def type-tensor-distribute [f : Type, a : Type] -> Type
  := match f a
     | (union fs)   a         -> union-join (map [fi -> type-tensor-core fi a] fs)
     | f            (union as) -> union-join (map [ai -> type-tensor-core f ai] as)
     | f            a         -> type-tensor-core f a

-- Pseudo-complement (SCAFFOLDING — list filtering)
-- Permanent: ATMS nogood → retract conflicting assumption → pseudo-complement
def pseudo-complement [a : Type, ctx : (List Type)] -> Type
  := union-join (filter [t -> meet(t, a) = bot] ctx)
```

### NTT Correspondence Table

| NTT Construct | Racket Implementation | File |
|---------------|----------------------|------|
| `relation subtype :merge` | `subtype-lattice-merge` | subtype-predicate.rkt |
| `relation subtype :meet` | `type-lattice-meet` (extended) | type-lattice.rkt |
| `union-join` | `build-union-type-with-absorption` | union-types.rkt (NEW) |
| `flatten-union` | `flatten-union` | union-types.rkt (extracted) |
| `absorb-subtypes` | `absorb-subtype-components` | union-types.rkt (NEW) |
| `generic-meet` | `generic-meet` (NEW, mirrors generic-merge) | type-lattice.rkt |
| `type-tensor-core` | `type-tensor-core` (NEW — propagator fire fn) | subtype-predicate.rkt (R1: avoids circular dep) |
| `type-tensor-distribute` | `type-tensor-distribute` (NEW — scaffolding) | subtype-predicate.rkt |
| `infer expr-app union` | `expr-app` case calling `type-tensor-distribute` | typing-core.rkt |
| `pseudo-complement` | `type-pseudo-complement` (SCAFFOLDING — list filter) | typing-errors.rkt |
| `relation.properties` | `declared-properties` nested hash (13 migration sites) | sre-core.rkt |
| `has-property? :relation` | `sre-domain-has-property?` with #:relation | sre-core.rkt |
| `domain.operations` | `sre-domain-operations` hash (NEW field) | sre-core.rkt |

---

## §5 Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Union type proliferation (cells accumulate large union types) | Medium | Subtype absorption limits growth. Union types from subtype merge do NOT flow into main elab cells (P2 finding). Monitor during implementation. |
| Subtype absorption cost (O(n^2) per union build) | Low | Typical unions have 2-5 components. Absorption is canonical form computation WITHIN the join (M4), not a separate stratum. |
| Meta variables in unions (`?A | Int`) | Medium | Conservative: treat unsolved metas as in type-lattice-merge. Don't build unions containing metas. |
| Per-relation property change: 13 migration sites | Low | Default `#:relation 'equality` preserves all existing behavior. Migration is mechanical (R2). |
| Pseudo-complement computation on non-ground types | Medium | Fall back to standard error format. Scaffolding (M2) — ATMS replaces in Track 4. |
| `union-types.rkt` extraction breaks compilation order | Low | Module depends only on syntax.rkt. Add to dep-graph.rkt immediately. |
| `sre-domain` gains `operations` field (12th positional arg) | Medium | Same debt as Track 2G L4 (positional struct). All 13 construction sites need update. Consider keyword args if touching struct. |
| Tensor results reaching unexpected eliminators | Low | P2 finding: exposure limited to expr-app tensor results. Monitor; handle if concrete cases arise. |

---

## §6 Dependencies

**Depends on (all met)**:
- Track 2G ✅: property inference, declared-properties field, has-property? API, meet operations, ring action
- Track 2F 🔄: merge-registry, relation-level properties, variance table
- Track 1/1B ✅: subtype?, structural subtype check, subtype-lattice-merge
- ctor-registry ✅: generic-merge pattern, ctor-desc with component-variances

**Depended on by**:
- PPN Track 4: elaboration on network (BLOCKED on Track 2H — needs well-structured type lattice)
- SRE Track 3: trait resolution (benefits from Heyting properties, not blocked)

---

## §7 Test Strategy

**Phase 0**: Pre-0 benchmarks + property checks
- Benchmark `subtype-lattice-merge` on incomparable types (current: produces type-top, fast)
- Benchmark `build-union-type` ACI normalization (existing, measure baseline)
- Property check: manually verify distributivity on sample triples BEFORE implementation
- **Semiring validation**: verify tensor (function application) distributes over union-join on sample types — `f(A | B) = f(A) | f(B)` for concrete f, A, B. This validates the quantale structure that PPN Track 4 depends on (§10).

**Per-phase**: Targeted tests for each phase's deliverable. Shared fixture pattern for new test file.

**Phase 8**: Full suite GREEN + A/B benchmark comparing:
- Pre-Track-2H baseline (from timings.jsonl)
- Post-Track-2H performance
- Focus: any regression in subtype checking or union type paths

**Acceptance file**: `examples/2026-04-02-sre-track2h.prologos` exercising:
- Union type formation in type annotations
- Mixed-type maps (existing, regression check)
- Pattern matching on union types (existing, regression check)
- Subtype absorption visible in inferred types

---

## §8 WS Impact

Track 2H does NOT add or modify user-facing syntax. Union types (`<Int | String>`) already exist in the WS surface. The change is internal: the type lattice produces union types where it previously produced type-top. Users will see BETTER type inference (union types instead of errors for incomparable constraint merges) and BETTER error messages (pseudo-complement information).

No preparse changes. No reader changes. No parser changes.

---

## §D.3 Self-Critique Findings

Three lenses: Reality Check (R), Principles (P), Propagator Mindset (M).

| Finding | Lens | Impact | Resolution |
|---------|------|--------|------------|
| R1: `type-tensor` can't live in type-lattice.rkt (circular dep with subtype?) | R | **Blocker** — design specified wrong module | Moved to subtype-predicate.rkt (§3.4) |
| R2: 13 sre-domain construction sites, not 9 | R | Phase 6 underestimated migration | Sized explicitly in §3.6 |
| R3: Pre-0 numbers stale after whnf fast-path (300μs → 0.3μs) | R | Performance analysis too pessimistic | Noted — union cost even MORE negligible now |
| P1: Union normalization maintained by discipline, not structure | P | Risk of non-canonical expr-union | Monitor — smart constructor pattern if issues arise |
| P2: Union types from subtype merge don't reach main elab cells | P | Eliminator concern bounded | Documented in §3.5. Monitor during implementation. |
| P3: Tensor should be discoverable via SRE, not standalone | P | Track 4 can't generically look up tensor | `operations` hash on sre-domain (§3.4) |
| P4: Domain×relation IS the right property key | P | Confirms design's nested hash approach | Justified in §3.6 from Track 2G L3 |
| M2: Pseudo-complement is scaffolding (ATMS replaces) | M | Document scaffolding boundary | Explicit in §3.8 with retirement criterion |
| M3: Distribution is network behavior, not tensor behavior | M | **Design win** — split core from distribute | `type-tensor-core` (propagator fn) + `type-tensor-distribute` (scaffolding) |
| M4: Absorption is canonical form within join, not stratification | M | Confirms design — no separate cell needed | Documented in §2 and §3.2 |

## §D.5 External Critique Findings

Propagator information flow lens. 12 findings, responses inline.

| Finding | Issue | Resolution |
|---------|-------|------------|
| F1: Tensor top-on-failure conflates absence with contradiction | **Accept** | `type-tensor-core` returns `type-bot` for inapplicable (§3.4). In network: propagator doesn't write. |
| F2: Meta handling in subtype-lattice-merge breaks monotonicity | **Document** | Pre-existing pattern inherited from `type-lattice-merge`, compensated by solve-meta! + constraint-retry. Retirement: Track 4 ATMS-conditional values. Documented in §3.2. |
| F3: Absorption algorithm is scaffolding (not flagged as such) | **Accept** | `absorb-subtype-components` flagged as scaffolding in §2, §3.2. Network does pairwise merge. |
| F4: Core/scaffolding tensor split is right | Positive | No action. |
| F5: Property keyword API adds algorithmic dispatch | **Document** | Keyword API is scaffolding; property cells (Track 2G `property-cell-ids`) are permanent. Documented in §3.6. |
| F6: Pseudo-complement context from list, not cells | **Investigate** | Use cell registry if available; list parameter otherwise. Documented in §3.8. |
| F7: Distributivity claim needs scoping to ground types | **Accept** | Heyting scoped to ground sublattice. Phase 7 tests binder types. Documented in §2, §3.7. |
| F8: Operations hash needs a contract | **Accept** | Minimal contract: `(hasheq 'name sym 'fn proc 'arity nat 'properties list)`. Documented in §3.4. |
| F9: Equality merge + union types interaction | **Accept** | Worked examples added to §2. Cells never switch merge strategies. |
| F10: NTT model should declare join/meet as first-class | **Accept** | NTT lattice now declares `:join union-join :meet glb-meet`. Relations reference these. |
| F11: Phase ordering creates algebraic inconsistency window | **Compromise** | Phases 2+3 merged into atomic Phase 2 (§3.2). Phase 3 (meet) separate — incomplete meet doesn't break join laws. |
| F12: No explicit bridge between equality and subtype orderings | **Document for Track 4** | Asymmetric relationship documented in §2. Equality refines subtype, not reverse. Different cells today — no bridge needed. |

---

## §10 Semiring Structure: Scope Boundary and Forward Reference

### The Type Lattice as Quantale

The [Lattice Foundations research](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) §2.4 establishes that the type lattice is a **quantale** — a complete lattice that is simultaneously a semiring:

- **Addition (⊕)**: union-join — `Int ⊕ String = Int | String`. Track 2H delivers this.
- **Multiplication (⊗)**: function type application — `(A → B) ⊗ A = B`. This is PPN Track 4 scope.

The key semiring axiom is **distributivity of tensor over join**:

```
a ⊗ (b ⊕ c) = (a ⊗ b) ⊕ (a ⊗ c)
```

In type terms: applying a function to a union distributes across components:

```
(A → B) applied to (C | D) = ((A → B) applied to C) | ((A → B) applied to D)
```

This is the theoretical basis for "type inference as parsing" — elaboration IS parsing in the type-lattice semiring (§2.4: "The resulting 'parse' doesn't produce trees — it produces types"). When elaboration goes on-network (PPN Track 4), the tensor becomes a propagator: given cells for f's type and arg's type, write result's type. The propagator IS the tensor.

### What Track 2H delivers

Track 2H delivers BOTH halves of the quantale:
- **⊕ (union-join)**: Phases 2-3. Subtype-aware join producing union types with absorption. Absorption is canonical form computation within the join (M4), not a separate stratum.
- **⊗ (tensor)**: Phase 5. Split into `type-tensor-core` (the propagator fire function — single Pi × single arg) and `type-tensor-distribute` (scaffolding for imperative union distribution). Phase 6 wires `type-tensor-distribute` into the elaborator.

The core tensor is what Track 4 wires as a propagator. The distribution wrapper is scaffolding that the network subsumes — in Track 4, multiple writes to the output cell (one per union component) produce the union via the cell's merge function (M3). Distribution is EMERGENT network behavior, not explicit computation.

### What PPN Track 4 picks up

Track 4 takes the reified `type-tensor` and makes it a **propagator**: given cells for f's type and arg's type, a function-application propagator writes result's type. The propagator IS the tensor wired into the network.

Track 4's design should:
1. Wire `type-tensor` as a propagator fire function (cell reads → type-tensor → cell write)
2. Connect to the 6-domain reduced product architecture from the Lattice Foundations research
3. Design the parse-to-type and type-to-parse Galois bridges that make "type inference as parsing" concrete
4. The semiring axioms are already validated by Track 2H — Track 4 inherits them

---

## §11 Cross-References

- **Track 2G PIR §14** (L3): "Algebraic properties are per-ordering, not per-carrier." — This is the core motivation for per-relation property declarations.
- **Track 2G PIR §12**: "Pre-0 property check for algebraic tracks." — Phase 0 includes property checks.
- **Track 2G PIR §15**: "The RIGHT primary ordering is subtyping." — Track 2H implements this.
- **Algebraic Embeddings §2.4**: Heyting algebra → pseudo-complement error reporting.
- **Algebraic Embeddings §7.1**: "Is our type lattice a Heyting algebra?" — Track 2H answers this question.
- **SRE Master Track 2H row**: Scope description matches this design.
