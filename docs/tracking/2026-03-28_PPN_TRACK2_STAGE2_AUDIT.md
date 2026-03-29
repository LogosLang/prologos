# PPN Track 2: Surface Normalization — Stage 2 Audit

**Date**: 2026-03-28
**Target**: `macros.rkt` (9763 lines, 48 preparse/expand functions)
**Method**: Three parallel audits — rule catalog (A), imperative state (B), ordering/stratification (C)

---

## Executive Summary

macros.rkt is a **well-stratified 5-pass pipeline** operating on S-expression datums (Layer 1) and surf-* AST nodes (Layer 2). The pipeline is already structured as a forward DAG with no backward dependencies — a clean fit for propagator stratification.

### Key Numbers

| Metric | Count |
|--------|-------|
| Total lines | 9763 |
| Preparse/expand functions | 48 |
| Pure rewrite functions (zero side effects) | 18 |
| Registry-writing functions | 24 registries, dual-write pattern |
| Built-in expander registrations | 9 (let, do, if, cond, list-literal, lseq-literal, pipe, compose, mixfix) |
| WS-mode desugar functions | 5 (session, defproc, proc, strategy, + branches) |
| Layer 2 (post-parse) expand functions | 4 (expand-top-level, expand-expression, desugar-defn, expand-defn-multi) |
| Ordering constraints (essential) | 3 (Pass -1→0, Pass 0→1, subform rewrite order) |
| Ordering constraints (conventional) | 2 (Pass 1→2, within-Pass-2 order) |
| Fixed-point computations | 1 (preparse-expand-form, depth-100 guard) |

### Pipeline Architecture

```
Pass -1: ns/imports → load prelude (writes trait-registry)
Pass  0: data/trait/deftype/defmacro/bundle → pre-register (WRITES only, no READS)
Pass  1: spec/impl → pre-register (READS trait-registry, bundle-registry from Pass 0)
Pass  2: ALL forms → expand + emit (READS all registries, WRITES auto-exports)
Phase 5b: hoist generated defs before user defs (structural partition)
---
expand-top-level: Layer 2 post-parse desugaring (surf-* → surf-*)
```

### Stratification Classification

| Category | Functions | Propagator mapping |
|----------|-----------|-------------------|
| **MONOTONE (pure)** | 18 rewrites: expand-let, expand-do, expand-if, expand-cond, expand-list-literal, expand-lseq-literal, expand-pipe-block, expand-compose-sexp, rewrite-dot-access, rewrite-implicit-map, rewrite-infix-operators, desugar-session-ws, desugar-defproc-ws, desugar-proc-ws, desugar-strategy-ws, expand-quote, expand-quasiquote, expand-with-transient | → SRE rewrite rules (pattern→template) |
| **NON-MONOTONE (registry writes)** | process-data, process-trait, process-bundle, process-property, process-functor, process-deftype, process-defmacro, process-schema, process-selection | → Registry cell writes (stratum 0) |
| **NON-MONOTONE (registry reads)** | process-spec, process-impl, maybe-inject-spec, maybe-inject-where, extract-inline-constraints, expand-bundle-constraints | → Registry cell reads (stratum 1) |
| **FIXED-POINT** | preparse-expand-form (depth-100) | → Propagator cell convergence |
| **STRUCTURAL** | Phase 5b hoisting, expand-top-level pass-through | → Post-fixpoint structural partition |

### Critical Design Observations

1. **Dual-write pattern already exists**: Every `register-X!` writes to BOTH legacy parameter AND propagator cell (via `macros-cell-write!`). The cell infrastructure IS in place.

2. **24 cell-id parameters**: `init-macros-cells!` creates 24 cells in the persistent registry network. All registry reads go through `macros-cell-read-safe()` → cell-primary with parameter fallback.

3. **No backward information flow**: Pass N never reads what Pass N+1 writes. Strict forward DAG.

4. **Within Pass 0, no dependencies**: All forms can be processed in any order — they WRITE only.

5. **Spec/where injection is the key cross-pass dependency**: `maybe-inject-spec` reads `spec-store`, `maybe-inject-where` reads `trait-registry` and `bundle-registry`. Both populated in earlier passes.

6. **preparse-expand-form is already a fixpoint**: Recursive macro expansion with depth guard. This IS propagator convergence.

7. **Layer 2 operates on a different representation**: surf-* structs vs datums. Either needs two rewrite engines or a unified representation.

---

## Audit A: Complete Rule Catalog

*(Full catalog in agent output — 18 pure rewrites, 9 built-in expanders, 5 WS desugar functions, 6 spec/where injections, 4 Layer 2 expanders. See `/tmp/.../tasks/a135c25514e042ffc.output` for exhaustive details.)*

### Pure Rewrite Rules (Pattern → Template, zero side effects)

| Rule | Input | Output | Notes |
|------|-------|--------|-------|
| `expand-let` | `(let name := val body)` | `((fn [name] body) val)` | Multiple formats |
| `expand-do` | `(do binding... body)` | Nested `let` | |
| `expand-if` | `(if cond then else)` | `(boolrec motive then else cond)` | |
| `expand-cond` | `(cond \| g→e ...)` | Nested `if` | |
| `expand-list-literal` | `'[1 2 3]` | `(cons 1 (cons 2 (cons 3 nil)))` | |
| `expand-lseq-literal` | `~[1 2 3]` | `(lseq-cell 1 (thunk ...))` | |
| `expand-pipe-block` | `(\|> x f g)` | Fused pipeline (loop fusion) | Complex: classifies steps, builds fused reducers |
| `expand-compose-sexp` | `(>> f g h)` | `(fn [$>>0] (h (g (f $>>0))))` | |
| `expand-mixfix-form` | `($mixfix 1 < 2)` | `(< 1 2)` via Pratt parser | Reads user-operator registry (read-only) |
| `expand-quote` | `'datum` | Datum constructor chain | |
| `expand-quasiquote` | `` `datum `` | With unquote holes | |
| `rewrite-implicit-map` | Keyword-value tail | `$brace-params` sentinel | |
| `rewrite-dot-access` | `.field` sentinels | `(map-get ...)` calls | |
| `rewrite-infix-operators` | Infix `\|>` or `>>` | Prefix form | |
| `desugar-session-ws` | WS session body | Right-nested session | |
| `desugar-defproc-ws` | WS defproc body | Nested process body | |
| `desugar-proc-ws` | WS proc body | Nested process body | |
| `desugar-strategy-ws` | WS strategy props | Flattened keyword list | |

---

## Audit B: Imperative State

### 24 Registries (dual-write: parameter + cell)

| Registry | Written by | Read by | Pass written | Pass read |
|----------|-----------|---------|-------------|-----------|
| preparse-registry | process-defmacro, process-deftype | preparse-expand-form | 0 | 2 |
| spec-store | process-spec | maybe-inject-spec, maybe-inject-spec-def | 1 | 2 |
| ctor-registry | process-data | (implicit eval) | 0 | 2 |
| trait-registry | process-trait, prelude | extract-inline-constraints, maybe-inject-where | -1, 0 | 1, 2 |
| impl-registry | process-impl | (elaboration) | 1 | (post-preparse) |
| bundle-registry | process-bundle | expand-bundle-constraints | 0 | 1, 2 |
| schema-registry | register-schema! | lookup-schema (preparse-expand-form) | 0 | 2 |
| (+ 17 more) | ... | ... | 0 | 2 |

### Callback Parameters (3)
- `current-macros-prop-net-box` — box holding prop-network
- `current-macros-prop-cell-write` — injected cell-write function
- `current-macros-prop-cell-read` — injected cell-read function

### Mutable State (5 ad-hoc)
- `built-in-expander-table` — mutable hash (written at module load, never after)
- `generated-decl-names` — per-preparse-expand-all tracking hash
- `coercion-fn-cache` — memoization cache
- Various local mutable boxes (position counters, dedup sets)

---

## Audit C: Ordering + Stratification

### Essential Ordering Constraints

1. **Pass -1 → Pass 0**: Prelude traits must be registered before `process-spec` calls `extract-inline-constraints`
2. **Pass 0 → Pass 1**: `process-spec` reads trait-registry and bundle-registry populated in Pass 0
3. **Within subforms**: `rewrite-implicit-map` → `rewrite-dot-access` → `rewrite-infix-operators` (each reshapes form for the next)

### Conventional Ordering (not essential)

4. **Pass 1 → Pass 2**: Idempotent — Pass 2 re-processes spec/impl anyway
5. **Within Pass 2 source order**: Only matters for emitted defs (Phase 5b hoisting fixes generation order)

### CALM Analysis

- **Pass 0 forms are all CALM-safe**: they WRITE only, no READS. Can fire in any order within the pass (parallel-safe).
- **Pass 1 forms need stratification**: they READ from Pass 0 results. Must be in a later stratum.
- **Rewrite rules are all MONOTONE**: pure pattern→template, no state. Can fire in any order (parallel-safe).
- **preparse-expand-form is a FIXPOINT**: macro expansion converges to no-match (depth-bounded). This IS propagator quiescence.
- **The 5-pass structure IS the stratification**: Pass -1 = stratum -1, Pass 0 = stratum 0, Pass 1 = stratum 1, Pass 2 = value stratum.

---

## What This Means for Propagator Only Design

### Direct mappings

| Current | Propagator |
|---------|-----------|
| 18 pure rewrites | SRE rewrite rules (idempotent relation, Track 2D) |
| 24 registries | 24 registry cells (already exist!) |
| 5-pass pipeline | 4 strata (-1, 0, 1, value) |
| preparse-expand-form fixpoint | Propagator quiescence (convergence) |
| Phase 5b hoisting | Post-quiescence structural partition |
| Layer 2 expand-top-level | Separate stratum or same value stratum with priority |

### Key challenges

1. **Registration = side effect**: `process-data`, `process-trait` etc. don't just rewrite — they register metadata. In Propagator Only, these become "write to registry cell" propagators.

2. **Spec injection reads cross-pass**: `maybe-inject-spec` reads `spec-store` from Pass 1 to modify a form in Pass 2. In propagator terms: a propagator watches the spec-store cell and fires when spec is available.

3. **User-defined macros (defmacro) are dynamic**: The rewrite rule set changes during expansion — new macros registered in Pass 0 are available in Pass 2. In propagator terms: the rule registry is a cell; new rules are cell writes; expansion propagators re-fire when new rules appear.

4. **The form list is ordered**: Prologos files have source order that matters (forward references via Phase 5b hoisting). The propagator design needs to preserve this ordering.

5. **expand-pipe-block is complex**: Loop fusion analysis classifies steps, builds fused reducers inline. This is an optimization pass, not a simple rewrite. It may need its own stratum or a more expressive rule format.
