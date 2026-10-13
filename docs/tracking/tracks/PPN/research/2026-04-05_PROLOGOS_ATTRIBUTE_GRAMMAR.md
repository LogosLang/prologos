# The Prologos Attribute Grammar

**Date**: 2026-04-05
**Status**: Stage 1 — Formal attribute mapping
**Purpose**: Foundation for PPN Track 4B (elaboration as attribute evaluation on propagator network)
**Principle**: Engelfriet-Heyker equivalence: HR grammars = attribute grammars. Prolog DCGs = attribute grammars with difference-list threading.

---

## §1 What This Document Is

The imperative Prologos compiler computes information about each expression node: its type, the types of its sub-expressions, multiplicity usage, trait constraints, meta-variable solutions, and warnings. This information is scattered across 4 files (~8,000 lines): typing-core.rkt (infer/check), qtt.rkt (multiplicity), elaborator.rkt (surface→core + implicit args), and trait-resolution.rkt (constraint solving).

This document formalizes that information as an ATTRIBUTE GRAMMAR — a declarative specification of what attributes each node kind has, how inherited attributes flow downward, how synthesized attributes flow upward, and what constraints are generated between nodes.

The attribute grammar IS the specification for propagator-native elaboration. Each attribute rule becomes a propagator. The propagator network evaluates the grammar to fixpoint.

---

## §2 Attribute Kinds

Every AST node has attributes from five domains:

| Domain | Direction | Lattice | What It Represents |
|--------|-----------|---------|-------------------|
| **Type** | Synthesized (↑) + Inherited (↓, in check mode) | Type lattice (Track 2H): ⊥ → concrete → ⊤ | The type of this expression |
| **Context** | Inherited (↓) | Context lattice (Track 4A): binding stack | What's in scope at this node |
| **Multiplicity** | Synthesized (↑) | Mult semiring: (m0, m1, mw) with add + scale | How many times each variable is used |
| **Constraint** | Synthesized (↑, created at node) | Constraint lattice (Phase 6): pending → resolved → contradicted | Trait requirements, unification obligations |
| **Warning** | Synthesized (↑, accumulated) | Set lattice (monotone union) | Diagnostics: deprecation, coercion, capability |

Each domain has its own lattice. The REDUCED PRODUCT of all five domains is the full attribute space. Bridges between domains (type↔mult, type→constraint, constraint→type) create cross-domain propagation.

---

## §3 The Attribute Record

Each AST node position has an ATTRIBUTE RECORD — a structured value with one field per domain:

```
AttributeRecord = {
  type       : TypeLattice           ;; synthesized type (or inherited expected type)
  context    : ContextLattice        ;; inherited scope (binding stack)
  usage      : UsageVector           ;; synthesized multiplicity usage
  constraints: (Setof Constraint)    ;; synthesized constraints (traits, capabilities)
  warnings   : (Setof Warning)       ;; synthesized diagnostics
}
```

The type-map from Track 4A is the TYPE facet of this record. Track 4B extends it to the full record.

---

## §4 Node Attribute Rules

### §4.1 Variables

**Bound Variable (expr-bvar k)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `shift(k+1, 0, context.lookup-type(k))` |
| context | ↓ inherited | From enclosing scope |
| usage | ↑ synthesized | `single-usage(k, n)` — uses position k exactly once |
| constraints | — | None |
| warnings | — | None |

**Free Variable (expr-fvar name)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `global-env-lookup-type(name)` |
| context | ↓ inherited | From enclosing scope (not used for fvar) |
| usage | ↑ synthesized | `zero-usage(n)` — globals don't consume linear vars |
| constraints | — | None |
| warnings | ↑ synthesized | Deprecation warning if name is deprecated (spec, trait, or functor) |

### §4.2 Application

**Application (expr-app func arg)** — the CORE of bidirectional attribute flow.

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | If func.type = Pi(m, dom, cod): `subst(0, arg, cod)` |
| type (arg) | ↓ inherited (check) | `dom` from func's Pi type (bidirectional downward write) |
| context | ↓ inherited | Same context to both func and arg |
| usage | ↑ synthesized | `add-usage(func.usage, scale-usage(m, arg.usage))` where m = Pi mult |
| constraints | ↑ synthesized | Union of func.constraints and arg.constraints |
| warnings | ↑ synthesized | Union of func.warnings and arg.warnings |

**The bidirectional flow**: the app rule SYNTHESIZES the result type (upward) AND INHERITS the expected arg type from the function's domain (downward). The merge at the arg position IS unification.

**Union distribution**: when func.type is a union, the tensor distributes over components (Track 2H). Each applicable component produces a result type; the join collects them.

### §4.3 Lambda

**Lambda (expr-lam m dom body)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `Pi(m, dom, body.type)` |
| type (dom) | — | Must be a well-formed type: `dom.type = Type(l)` |
| context (body) | ↓ inherited | `context-extend(parent-ctx, dom, m)` — scope tensor |
| usage | ↑ synthesized | `scale-usage(m, body.usage)` with binder position dropped |
| constraints | ↑ synthesized | body.constraints |
| warnings | ↑ synthesized | body.warnings |

**Check mode (against Pi(m2, tdom, tcod))**:
- If dom is `expr-hole`: INHERIT tdom as the domain (key bidirectional case)
- Mult resolution: if m is mult-meta, solve to m2; if m2 is mult-meta, solve to m
- Domain unification: `unify(dom, tdom)` — merge at shared position

### §4.4 Pi Formation

**Pi (expr-Pi m dom cod)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `Type(lmax(dom.level, cod.level))` |
| context (cod) | ↓ inherited | `context-extend(parent-ctx, dom, m)` — binder scope |
| usage | ↑ synthesized | `add-usage(dom.usage, drop-binder(cod.usage))` |
| constraints | ↑ synthesized | Union of dom + cod constraints |

### §4.5 Sigma Formation

**Sigma (expr-Sigma fst-type snd-type)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `Type(lmax(fst.level, snd.level))` |
| context (snd) | ↓ inherited | `context-extend(parent-ctx, fst, mw)` |
| usage | ↑ synthesized | `add-usage(fst.usage, drop-binder(snd.usage))` |

### §4.6 Projections

**Fst (expr-fst e)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `fst-type` from `e.type = Sigma(fst-type, snd-type)` |
| usage | ↑ synthesized | e.usage |

**Snd (expr-snd e)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `subst(0, (expr-fst e), snd-type)` from `e.type = Sigma(fst, snd)` |
| usage | ↑ synthesized | e.usage |

### §4.7 Eliminators

**Nat Elimination (expr-natrec motive base step target)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `app(motive, target)` |
| type (base) | ↓ inherited (check) | `app(motive, zero)` |
| type (step) | ↓ inherited (check) | `Pi(mw, Nat, Pi(mw, app(motive, bvar(0)), app(motive, suc(bvar(1)))))` |
| type (target) | ↓ inherited (check) | `Nat` |
| usage | ↑ synthesized | `add-usage(target.usage, add-usage(base.usage, step.usage))` |

**Bool Elimination (expr-boolrec motive tc fc target)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `app(motive, target)` |
| type (tc) | ↓ inherited (check) | `app(motive, true)` |
| type (fc) | ↓ inherited (check) | `app(motive, false)` |
| type (target) | ↓ inherited (check) | `Bool` |
| usage | ↑ synthesized | Sum of all sub-usages |

### §4.8 Literals

**All literals** (expr-int, expr-nat-val, expr-true, expr-false, expr-string, etc.)

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | Constant: Int, Nat, Bool, String, etc. |
| usage | ↑ synthesized | `zero-usage(n)` — literals don't use variables |
| constraints | — | None |

### §4.9 Type Constructors

**All type constructors** (expr-Int, expr-Nat, expr-Bool, expr-String, etc.)

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `Type(lzero)` |
| usage | ↑ synthesized | `zero-usage(n)` |

**Universe (expr-Type l)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | `Type(lsuc(l))` |

### §4.10 Meta Variables

**Meta (expr-meta id cell-id)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | Cell read: if solved → solution type; if unsolved → ⊥ |
| type | ↓ inherited (from downward writes) | The merge at this position IS meta solving |
| usage | ↑ synthesized | `zero-usage(n)` (metas are type-level, not term-level) |

### §4.11 Specialized Operations

**Binary arithmetic (expr-int-add, expr-rat-mul, etc.)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | Constant: Int, Rat, Posit8, etc. (from SRE typing domain) |
| usage | ↑ synthesized | `add-usage(a.usage, b.usage)` |

**Generic arithmetic (expr-generic-add, etc.)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | DEPENDS ON trait resolution: `resolve(Add, arg.type) → arg.type` |
| usage | ↑ synthesized | `add-usage(a.usage, b.usage)` |
| constraints | ↑ synthesized | `{(Add, arg.type)}` — trait constraint |
| warnings | ↑ synthesized | Coercion warning if mixed-type |

**Map operations (expr-map-get, etc.)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↑ synthesized | Extract from collection type: `Map K V → V` |
| usage | ↑ synthesized | From operand usage |

### §4.12 Pattern Matching

**Reduce (expr-reduce scrutinee arms structural?)**

| Attribute | Direction | Rule |
|-----------|-----------|------|
| type | ↓ inherited (expected from check mode) | Expected result type (Church fold construction) |
| type (scrutinee) | — synthesized | Inferred from scrutinee |
| type (each arm body) | ↓ inherited (check) | Expected type under arm-extended context |
| context (each arm body) | ↓ inherited | Context extended with arm bindings |
| usage | ↑ synthesized | Join of all arm usages |

---

## §5 Elaboration-Specific Attributes

Elaboration (surface → core) adds attributes beyond typing:

### §5.1 Implicit Argument Insertion

When an application has fewer arguments than the function's Pi chain expects (implicit m0 parameters):

| Attribute | Node | Rule |
|-----------|------|------|
| implicit-metas | app | List of fresh metas created for implicit positions |
| constraint-start | app | Position index where trait constraints begin |
| type-var-metas | app | Metas for type-variable positions (before constraint-start) |
| trait-constraints | app | `(register-trait-constraint! meta-id (trait-constraint-info trait-name type-arg-metas))` per trait position |
| hasmethod-constraints | app | `(register-hasmethod-constraint! meta-id hm-info)` per method position |

### §5.2 Name Resolution

| Attribute | Node | Rule |
|-----------|------|------|
| qualified-name | fvar | `qualify-name(name, current-ns)` |
| de-bruijn-index | bvar | Computed from env depth at elaboration time |
| multi-defn-dispatch | app | Select arity-matching defn clause |

### §5.3 Capability Tracking

| Attribute | Node | Rule |
|-----------|------|------|
| capability-scope | inherited | `current-capability-scope` — list of available capabilities |
| capability-constraints | app | Created when domain is capability type not in scope |

---

## §6 Cross-Domain Bridges

Information flows BETWEEN attribute domains:

| Bridge | From → To | Mechanism | Existing? |
|--------|-----------|-----------|-----------|
| Type → Constraint | Function type reveals trait constraints | Implicit arg insertion detects trait domains | Elaborator (imperative) |
| Constraint → Type | Resolved trait fills dict-meta type | `solve-meta!(dict-id, dict-expr)` | Resolution loop |
| Type → Mult | Pi multiplicity extracted from type | `type->mult-alpha` bridge propagator | PM Track 8 ✅ |
| Mult → Type | (Future: reconstruct Pi with solved mult) | Not yet implemented | — |
| Type → Warning | Cross-family type detected → coercion warning | Imperative detection in elaborator | Needs migration |
| Constraint → Warning | Unresolved constraint → error message | `build-trait-error` | Resolution loop |

---

## §7 Stratification

Attributes evaluate at different strata of the BSP scheduler:

| Stratum | Attributes | Monotonicity | When |
|---------|-----------|--------------|------|
| **S0** | Type (infer), context, usage, literal types | Monotone (only gain info) | Main fixpoint |
| **S0** | Type (check) — bidirectional downward writes | Monotone (merge adds info) | Same pass as infer |
| **S0** | Constraint creation (trait, capability) | Monotone (constraints accumulate) | During type computation |
| **S1** | Trait resolution (readiness) | Fires when arg types are ground | After S0 quiescence |
| **S1** | HasMethod resolution | Fires when trait var + type args ground | After S0 quiescence |
| **S1** | Constraint retry (unification) | Fires when dependency metas solved | After S0 quiescence |
| **S2** | Meta defaulting (fan-in) | Non-monotone (writes arbitrary defaults) | After S0+S1 quiescence |
| **S2** | Multiplicity validation | Non-monotone (accept/reject) | After all types resolved |
| **S2** | Warning collection | Non-monotone (final report) | After all resolution |
| **S(-1)** | ATMS retraction | Non-monotone (remove failed branches) | On contradiction |

---

## §8 The Attribute Grammar → Propagator Mapping

Each attribute rule in §4 becomes a propagator:

| Grammar Concept | Propagator Concept |
|----------------|-------------------|
| Node with attributes | Position in the attribute PU with an attribute record |
| Inherited attribute | Downward cell write (check direction) |
| Synthesized attribute | Upward cell write (infer direction) |
| Attribute rule | Propagator fire function (reads inputs, writes outputs) |
| Grammar production | SRE typing domain entry |
| Attribute dependency | Propagator watching input positions |
| Cross-domain bridge | Bridge propagator connecting two attribute domains |
| Stratification | BSP strata (S0/S1/S2) |

The form cell's PU holds the ENTIRE attribute record for ALL nodes. A single quiescence computation evaluates ALL attributes simultaneously.

---

## §9 What This Enables (for Track 4B Design)

1. **The Attribute PU structure** — Track 4A's type-map becomes ONE FACET of the full attribute record. Adding constraint, usage, and warning facets extends the PU without changing the architecture.

2. **Propagator registration** — The SRE typing domain (§16) extends from type-only rules to full attribute rules. Each domain entry specifies inherited, synthesized, and constraint attributes.

3. **Stratification** — The BSP scheduler (S0/S1/S2) maps directly to the attribute evaluation order. S0 evaluates type + context + constraint creation. S1 resolves constraints. S2 defaults and validates.

4. **Self-hosting** — The attribute grammar IS the compiler specification. The propagator network IS the evaluation engine. The SRE domain IS the grammar data. A self-hosted compiler reads the grammar and builds the network.
