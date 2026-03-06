# Relational Fact Design: Schema-Backed Facts

**Status**: Design Discussion (captured from mobile session)
**Date**: 2026-03-06
**Tracking**: `docs/tracking/2026-03-06_1400_RELATIONAL_FACT_DESIGN.md`
**Prior art**: `docs/tracking/2026-03-02_2200_SCHEMA_SELECTION_DESIGN.md` (schema + selection system)
**Context**: How to represent relational facts in Prologos, bridging the schema system with the logic engine

---

## 1. The Question

> We have PVec (RRB-tree backed) and Map (CHAMP-backed) as persistent data structures, plus the schema system for compile-time key-to-type mapping. How should relational facts be stored and queried?

The tension: Prolog-style positional facts (`parent alice bob`) are fast for unification but terrible for readability at scale. Keyed/named facts are ergonomic but traditionally slower.

## 2. Core Design Insight: Schema as Bridge

**Schemas establish a compile-time bijection between named keys and positional indices.** This means:

- **Storage**: Facts are flat vectors (fast positional unification, cache-friendly)
- **Surface syntax**: Keyed patterns (`{:dept "Engineering" :name name}`) for authoring and querying
- **Cost**: Zero runtime overhead — the key-to-index mapping is resolved at compile time

This is the same trick that database systems use: the schema defines column order, SQL uses column names, but the engine works with column indices.

### 2.1 The Desugaring

```prologos
;; User writes (keyed pattern):
(employees {:dept "Engineering" :name name})

;; Compiler sees (positional, after schema lookup):
(employees ?name "Engineering" ?_ ?_ ?_)
```

The schema for `employees` maps `:name -> 0, :dept -> 1, :salary -> 2, ...` so the compiler can rewrite keyed patterns into positional ones before the solver ever sees them.

## 3. Representation Options Considered

### 3.1 Flat Vector (Recommended)

```
fact = #(value0 value1 value2 ...)
```

- **Pro**: Cache-friendly, O(1) positional access, trivial unification
- **Pro**: Identical to how Datalog engines (Souffle, Flix) store tuples
- **Con**: Requires schema to be meaningful
- **Verdict**: Primary representation

### 3.2 CHAMP Map

```
fact = {champ :name "alice" :dept "eng" ...}
```

- **Pro**: Self-describing, no schema needed
- **Con**: O(log32 n) access per field during unification
- **Con**: Higher memory overhead per fact (hash + trie nodes)
- **Verdict**: Useful for schema-less exploratory mode, not primary

### 3.3 Hybrid (Schema + Map Fallback)

Schema-annotated relations use vectors; unannotated ones use maps. The solver dispatches based on whether the relation has a schema.

- **Verdict**: Good pragmatic choice for incremental adoption

## 4. Integration with Existing Systems

### 4.1 Schema System (from `SCHEMA_SELECTION_DESIGN.md`)

The schema system already provides:
- `(schema Employee :name String :dept String :salary Nat)` — declares shape
- Compile-time field-to-type mapping
- Dot-access syntax (`e.name`)

For relational facts, we extend this: `defr` (define relation) can reference a schema:

```prologos
(schema Employee :name String :dept String :salary Nat)

(defr employees : Employee
  {:name "Alice"   :dept "Engineering" :salary 130N}
  {:name "Bob"     :dept "Marketing"   :salary 95N}
  {:name "Carol"   :dept "Engineering" :salary 140N})
```

### 4.2 Query Patterns

```prologos
;; Keyed query — ergonomic
(query [name salary]
  (employees {:dept "Engineering" :name name :salary salary}))

;; Equivalent positional query — what the solver actually runs
(query [name salary]
  (employees name "Engineering" salary))
```

### 4.3 Type Safety

The schema gives us compile-time guarantees:
- All fact rows have the right number of fields
- Each field has the declared type
- Query patterns reference valid field names
- Typos in field names are caught at compile time (not silent failures)

## 5. Existing Implementation Inventory

### 5.1 Persistent Data Structures (already implemented)

| Structure | Backing | AST nodes | Surface syntax |
|-----------|---------|-----------|----------------|
| **PVec** | RRB-tree (`rrb.rkt`) | `expr-pvec-*` | `@[1N 2N 3N]` |
| **Map** | CHAMP (`champ.rkt`) | `expr-map-*`, `expr-champ` | `{:k v}` |
| **Set** | CHAMP w/ #t sentinel | `expr-set-*`, `expr-hset` | via stdlib |
| **Transient** | Mutable builders | `expr-tvec-*`, `expr-tmap-*` | `transient`/`persist` |

### 5.2 Schema (partially implemented)

- AST: `expr-schema`, `expr-schema-type`, `expr-defr` (in `syntax.rkt`)
- Dot-access: works via `expr-dot-project`
- Selection: designed but not yet implemented

### 5.3 Logic Engine

- Unification: `unify.rkt`
- Relations: `expr-defr` exists but needs schema integration
- Solver: reduction-based, pattern matching on AST nodes

## 6. Open Design Questions

### 6.1 Keyed Goal Pattern Desugaring

The `(employees {:dept "Engineering" :name name})` syntax needs:
- Schema lookup at elaboration time
- Rewriting keyed pattern to positional pattern
- Handling of omitted keys (wildcard `_` insertion)

**Question**: Does this happen in the parser, elaborator, or as a macro?
**Likely answer**: Elaborator, since it needs type/schema information.

### 6.2 Bulk Import Surface

For loading facts from external data:

```prologos
(defr employees : Employee
  :source "employees.csv"
  :format :csv
  :header true)
```

**Question**: How does the schema mediate column mapping? By name? By position?
**Likely answer**: By header name matching schema field names (with explicit `:columns` override).

### 6.3 Schema-less Facts with Retroactive Schema

Can you define facts first, then attach a schema later?

```prologos
;; REPL session
(defr points
  (point 1 2)
  (point 3 4))

;; Later...
(schema Point :x Nat :y Nat)
(annotate points : Point)  ;; retroactive
```

**Question**: Is this worth supporting, or should we require schema-first?
**Consideration**: Exploratory/REPL workflows benefit from schema-later. Production code should be schema-first.

### 6.4 Indexing Strategy

Prolog uses first-argument indexing. With keyed patterns, we could do:
- **Single-column index** (Prolog-style, on first field)
- **Multi-column index** (driven by query patterns — which fields are bound?)
- **Adaptive indexing** (build indices lazily based on query patterns seen)

**Question**: What's the right default?
**Likely answer**: First-argument indexing as default, with explicit `(:index [:dept :name])` annotations for multi-column.

### 6.5 The Hickey Separation (Schema vs Selection)

From the schema design doc: schemas define shape, selections define views. For relational facts:

```prologos
(selection EngineeringView :of Employee
  :name :salary)

(query [name salary]
  (employees (EngineeringView {:name name :salary salary})))
```

A selection on a schema-annotated relation is essentially a SQL projection.

**Question**: How deep does this go? Can selections drive query optimization (only fetch needed columns)?
**Consideration**: This connects to the "wide-row optimization" — for relations with many columns, selections tell the solver which columns matter.

## 7. Recommended Next Steps

1. **Finalize `defr` + schema integration** — wire up `expr-defr` to use `expr-schema` for type checking fact rows
2. **Implement keyed pattern desugaring** in the elaborator — `{:field val}` patterns in goal position rewrite to positional
3. **Add first-argument indexing** for schema-backed relations
4. **Design bulk import** surface syntax and implement CSV/JSON loaders
5. **Connect selections to relation queries** for projection optimization

---

*This document captures a design discussion from a mobile session on 2026-03-06. It serves as a reference for the relational fact representation design, bridging the existing schema system with the logic programming engine.*
