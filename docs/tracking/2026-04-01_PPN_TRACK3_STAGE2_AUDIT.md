# PPN Track 3: Parser as Propagators — Stage 2 Audit

**Date**: 2026-04-01
**Stage**: 2 (Grep-backed inventory)
**Target**: Replace `parser.rkt` with grammar-production-based parsing on the propagator network
**Related**: [PPN Master](2026-03-26_PPN_MASTER.md), [HR Research](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md), [Track 2B PIR](2026-03-30_PPN_TRACK2B_PIR.md), [SRE Track 2G Design](2026-03-30_SRE_TRACK2G_DESIGN.md)

---

## 1. What Are We Replacing?

### 1.1 parser.rkt

**Size**: 6,605 lines.
**Exports**: 8 symbols — `parse-datum`, `parse-string`, `parse-port`, `current-parsing-relational-goal?`, `narrow-var-symbol?`, `collect-narrow-vars`, `narrow-var-base-name`, `narrow-var-constraints`, `collect-narrow-vars+constraints`, `rewrite-constrained-vars`.
**Internal functions**: 73 `parse-*` functions.
**Requires**: `source-location.rkt`, `surface-syntax.rkt`, `errors.rkt`, `sexp-readtable.rkt`, `macros.rkt`, `global-env.rkt`.

**Core dispatch**: `parse-datum` (line 470) is the single entry point. Dispatches on datum type:
- Bare symbol → `parse-symbol` (43 type keywords + value keywords + pattern matching on string shape)
- Integer → `surf-int-lit`
- Fraction → `surf-rat-lit`
- Inexact → `surf-approx-literal`
- String → `surf-string`
- Char → `surf-char`
- List → `parse-list` (the main dispatch)

**parse-list dispatch**: ~236 unique keyword head symbols handled via nested `case`/`cond`. Categories:

| Category | Count | Examples |
|----------|-------|---------|
| Sentinel forms (`$`-prefixed) | ~12 | `$angle-type`, `$nat-literal`, `$approx-literal`, `$decimal-literal`, `$foreign-block`, `$brace-params`, `$solver-config`, `$set-literal`, `$vec-literal`, `$typed-hole` |
| Core language | ~25 | `fn`, `the`, `ann`, `lam`, `Pi`, `Sigma`, `match`, `let`, `if`, `when`, `do`, `cond`, `suc`, `pair`, `fst`, `snd`, `eq`, `J`, `boolrec`, `natrec` |
| Int/Rat/Posit builtins | ~35 | `int+`, `int-`, `int*`, `rat+`, `rat-`, etc. |
| Collections builtins | ~45 | `map-get`, `map-assoc`, `set-insert`, `pvec-nth`, etc. |
| Definition forms | ~8 | `def`, `defn`, `spec`, `data`, `trait`, `impl`, `deftype`, `subtype` |
| Relational/logic | ~15 | `defr`, `rel`, `solve`, `explain`, `solve-with`, `solve-one` |
| Session types | ~20 | `session`, `defproc`, `proc`, `dual`, `spawn`, `proc-send`, `proc-recv`, etc. |
| Propagator network ops | ~15 | `net-new`, `net-new-cell`, `net-cell-read`, `net-cell-write`, `net-add-prop`, `net-run` |
| ATMS/solver/table ops | ~20 | `atms-new`, `atms-assume`, `table-new`, `table-add`, `uf-*` |
| Meta/check/reduce | ~8 | `check`, `reduce`, `eval`, `infer`, `elaborate`, `trace` |
| Generic arithmetic | ~8 | `+`, `-`, `*`, `/`, `negate`, `abs`, `from-int`, `mod` |
| Module system | ~5 | `ns`, `require`, `provide`, `import` |
| Misc | ~20 | `defmacro`, `capability`, `bundle`, `foreign`, `selection`, etc. |

**Recursive structure**: `parse-datum` is called 512 times within parser.rkt itself — heavily recursive. Every compound form calls `parse-datum` on its sub-expressions.

**Key complexity centers** (most complex parse-* functions by line count):
1. `parse-list` (~2500 lines) — the main keyword dispatch
2. `parse-defn` / `parse-defn-multi` / `parse-defn-params-and-patterns` (~500 lines) — defn parsing is the most complex individual form
3. `parse-session-body` / `parse-proc-body` (~200 lines each) — session type forms
4. `parse-defr-body` (~150 lines) — relational definitions
5. `parse-check-cmd` (~150 lines) — check/reduce/trace commands

### 1.2 macros.rkt sexp expanders

**Total file size**: 9,763 lines (the largest file in the codebase).
**Expand functions**: 21 `expand-*` functions.

**Sexp-specific expanders (candidates for deletion once tree-parser covers all forms)**:

| Function | Lines | What it does |
|----------|-------|-------------|
| `expand-if` | ~20 | `(if c t f)` → `(boolrec (fn [_] T) t f c)` |
| `expand-cond` | ~40 | `(cond [c1 e1] [c2 e2] ...)` → nested if |
| `expand-let` | ~80 | `(let [x e] body)` → `((fn [x] body) e)` |
| `expand-let-bracket-bindings` | ~30 | Multi-binding let |
| `expand-let-inline-assign` | ~20 | Let with `:=` syntax |
| `expand-do` | ~40 | `(do e1 e2 ...)` → nested fn application |
| `expand-list-literal` | ~20 | `'[1 2 3]` → `(cons 1 (cons 2 (cons 3 nil)))` |
| `expand-lseq-literal` | ~20 | `'(1 2 3)` → lazy sequence |
| `expand-pipe-block` | ~30 | `(\|> x f g)` → `(g (f x))` — **ALREADY HANDLED by surface-rewrite.rkt** |
| `expand-compose-sexp` | ~20 | `(>> f g)` → `(fn [$c] (g (f $c)))` — **ALREADY HANDLED by surface-rewrite.rkt** |
| `expand-mixfix-form` | ~100 | `(.{a + b * c})` → precedence-resolved tree — **ALREADY HANDLED by surface-rewrite.rkt** |
| `expand-quote` | ~20 | Quote to literal list |
| `expand-quasiquote` | ~30 | Quasiquote |
| `expand-with-transient` | ~30 | Transient builder block |
| `expand-def-assign` | ~20 | `(def x := val)` desugaring |
| `expand-defn-multi` | ~30 | Multi-arity defn |

**NOT deletable (shared post-parse expanders)**:
- `expand-top-level` (~100 lines) — post-parse surface-level normalization (data/trait/impl registration). Called from elaborator.
- `expand-expression` (~80 lines) — post-parse expression normalization. Called from elaborator.
- `expand-bundle-constraints` / `expand-one-constraint` — constraint expansion

**Deletable estimate**: ~500-600 lines of sexp-specific expanders. 3 are already handled by surface-rewrite.rkt (pipe, compose, mixfix). The remaining ~12 become deletable once tree-parser handles their forms.

**`preparse-expand-all` call sites** (7 in driver.rkt, 6 in tests):
- `process-string-inner` (line 1431)
- `process-string-ws-inner` (line 1567)
- `process-file-inner` WS path (line 1624)
- `process-file-inner` sexp path (line 1632)
- `load-module` (line 1954)
- 6 test files use it directly

### 1.3 tree-parser.rkt (current coverage)

**Size**: 1,200 lines. 30 `parse-*-tree` functions.

**Fully implemented** (produce correct surf-* output):
- `parse-def-tree` — def with type annotations and `:=`
- `parse-defn-tree` — defn with multi-arity patterns, Pi chains
- `parse-spec-tree` — spec declarations
- `parse-eval-tree` — top-level eval
- `parse-fn-tree` — lambda expressions (typed/untyped, return types)
- `parse-when-tree` — when expressions
- `parse-if-tree` — if expressions
- `parse-expr-tree` — general expression parsing (application, type annotations)
- `parse-bracket-group-tree` — `[...]` groups
- `parse-angle-group-tree` — `<...>` type groups
- `parse-brace-group-tree` — `{...}` map/implicit groups
- `parse-paren-group-tree` — `(...)` keyword groups
- `parse-application-tree` — function application
- `parse-list-literal-tree` — list literals
- `parse-check-tree` — check commands
- `parse-infer-tree` — infer commands
- `parse-ns-tree` — namespace declarations
- `parse-imports-tree` — import declarations
- `parse-exports-tree` — provide/export declarations

**Error stubs** (return `parse-error-result`, fall back to preparse via merge):
- `parse-data-tree` — data type declarations
- `parse-trait-tree` — trait declarations
- `parse-impl-tree` — impl blocks
- `parse-quote-tree` — quoted expressions
- `parse-session-tree` — session type forms
- `parse-defproc-tree` — process definitions
- `parse-defr-tree` — relational definitions
- `parse-solver-tree` — solver configuration

**Coverage gap**: 8 form types are stubs. These are the more complex forms — data/trait/impl involve registration side effects during preparse, session/defproc/defr have complex sublanguages.

### 1.4 surface-rewrite.rkt

**Size**: 2,038 lines. Handles post-tree-parse rewriting.
**Already handles**: pipe (`|>`), compose (`>>`), mixfix (`.{...}`), tag refinement T(0), form grouping G(0).
**Relationship to Track 3**: surface-rewrite.rkt IS the Track 2B contribution that becomes the foundation for Track 3. Its rewrite rules are already grammar-production-like (pattern → output). Track 3 formalizes them as network propagators.

---

## 2. Call Sites and Data Flow

### 2.1 parse-datum call sites (external to parser.rkt)

| File | Line | Context |
|------|------|---------|
| `driver.rkt` | 1432 | `process-string-inner`: `(map parse-datum expanded-stxs)` |
| `driver.rkt` | 1568 | `process-string-ws-inner`: `(map parse-datum expanded-stxs)` (preparse path of merge) |
| `driver.rkt` | 1625 | `process-file-inner` WS: `(map parse-datum expanded-stxs)` (preparse path of merge) |
| `driver.rkt` | 1633 | `process-file-inner` sexp: `(map parse-datum expanded-stxs)` |
| `driver.rkt` | 1955 | `load-module`: `(map parse-datum expanded-stxs)` |
| `driver.rkt` | 2303 | `parse-type-annotation-string`: `(parse-datum type-sexp)` (one-off) |

**Pattern**: Always `(map parse-datum (preparse-expand-all stxs))`. The input is always a list of Racket syntax objects (from reader). The output is always a list of `surf-*` structs.

### 2.2 Merge infrastructure (Track 2B scaffolding)

`merge-preparse-and-tree-parser` (driver.rkt line 1481):
- **Input**: source string + list of preparse surfs
- **Mechanism**: Runs tree parser on source string. Builds `tree-by-line` hash (source line → tree parser surf). For each preparse surf, looks up by source line, calls `merge-form`.
- **`merge-form`** (line 1543): The per-form lattice join. Tree parser output wins for user forms; preparse wins for spec-annotated/generated forms. Error forms fall back to preparse.
- **Called from**: `process-string-ws-inner`, `process-file-inner` (WS path only)
- **NOT called from**: `load-module` (preparse-only for module loading)
- **NOT called from**: `process-string-inner` (sexp path, no merge)

### 2.3 Pipeline data flow

```
Source string
  → read-all-syntax-ws (parse-reader.rkt)      [tokenize + structure]
  → preparse-expand-all (macros.rkt)            [macro expand + registration side effects]
  → map parse-datum (parser.rkt)                [sexp → surf-*]
  → merge-preparse-and-tree-parser (driver.rkt) [merge with tree parser output]
  → process-command (driver.rkt)                [elaborate + type check each surf]
```

**Track 3 target**: Collapse the middle three steps. Grammar productions on the network replace `preparse-expand-all + parse-datum + merge`.

---

## 3. Registry and State Dependencies

### 3.1 parser.rkt reads NO registries

**Critical finding**: parser.rkt has only ONE parameter — `current-parsing-relational-goal?` (a boolean). It does not read:
- No operator table
- No precedence groups
- No data constructor registry
- No trait registry
- No impl registry
- No global environment

It imports `macros.rkt` for `known-type-name?` (a static function, not a parameter-based lookup) and `global-env.rkt` (but uses nothing from it — likely a transitive dependency).

**Implication for Track 3**: parser.rkt is a PURE FUNCTION of its input syntax. It has no external state dependencies. This makes the propagator migration straightforward — no need to thread registry cells through the parser. The only state dependency is `current-parsing-relational-goal?`, which controls whether bare applications become `surf-app` or `surf-goal-app`.

### 3.2 macros.rkt preparse-expand-all HAS registry side effects

**Critical distinction**: `preparse-expand-all` (macros.rkt) is where registration happens:
- `data` forms register constructors, accessors, type definitions
- `trait` forms register trait declarations
- `impl` forms register trait implementations
- `spec` forms pre-scan and inject type annotations
- `defmacro` forms register macro definitions
- `bundle` forms register bundle constraints
- `subtype` / `deftype` forms register type aliases and subtype relations

These registration side effects are what makes `preparse-expand-all` essential — and what makes it the HARDEST part to replace. Track 3 must either:
1. Move registration to tree-parser level (registration as grammar-production side effects)
2. Move registration to a separate pre-pass on the tree parser output
3. Move registration to the network (registration as cell writes)

Option 3 is the propagator-native path. Registration IS information flow.

### 3.3 `known-type-name?` dependency

parser.rkt calls `known-type-name?` from macros.rkt exactly once (line 585) — for nilable type sugar (`String?` → `<String | Nil>`). This is a static list of built-in type names, not a registry lookup. Easily extracted.

---

## 4. Surface Form Catalogue

**Total surf-* struct types**: 360 (in surface-syntax.rkt).

This is the complete set of grammar productions in the propagator architecture. Each `surf-*` struct IS a production output. The 73 `parse-*` functions in parser.rkt produce these 360 types.

**Production ratio**: 73 functions → 360 output types = ~5 output types per function on average. Some functions (like `parse-list`) handle dozens of output types; others are 1:1.

---

## 5. The Elaborator Boundary

### 5.1 Where does parsing end?

parser.rkt produces `surf-*` structs. These are consumed by:
- `expand-top-level` (macros.rkt) — further normalization for data/trait/impl/defn
- `expand-expression` (macros.rkt) — expression-level normalization
- `elaborate` (elaborator.rkt) — the main elaboration entry point

The boundary is CLEAN: parser.rkt → surf-* structs → elaborator. No mixing of parsing and elaboration within parser.rkt. Parser.rkt does not call any elaboration functions and does not create metas, constraints, or cells.

### 5.2 Error handling

parser.rkt produces `prologos-error` structs on parse failure (876 references to error handling in the file). Error propagation pattern:
- `parse-error` creates the error
- Recursive calls check `(prologos-error? result)` and propagate
- No recovery — first error terminates that subtree

**Error count in tree-parser.rkt**: Error stubs produce `parse-error-result` which the merge recognizes and falls back to preparse.

---

## 6. Performance Profile

### 6.1 Phase timing breakdown

**Representative .prologos file** (examples/2026-03-10-surface-ergonomics.prologos, 70 commands):

| Phase | Time (ms) | % of total |
|-------|-----------|------------|
| parse_ms | 0 | 0% |
| elaborate_ms | 146 | 9% |
| type_check_ms | 297 | 18% |
| qtt_ms | 154 | 9% |
| reduce_ms | 1,049 | **64%** |
| trait_resolve_ms | 0 | 0% |
| zonk_ms | 3 | <1% |
| **Total** | **1,649** | |

**Key finding**: **Parsing is 0ms.** It does not register in the phase timing. Reduction (64%) and type checking (18%) dominate.

### 6.2 Per-command verbose profile

70 commands in the acceptance file. Per-command wall time ranges 2ms–1,530ms. The expensive commands are the first ~7 (prelude-exercising eq-check calls with 164-194 reduce steps, 1,000-1,500ms each). Non-prelude commands average 50-200ms.

### 6.3 Micro benchmarks

| Benchmark | Time | Notes |
|-----------|------|-------|
| `process-string` x100 (no-prelude, 6 defs) | 103ms/call | parse_ms = 0 |
| `process-string` x10 (with prelude, 6 defs) | 488ms/call | Prelude loading dominates |

### 6.4 Performance implications for Track 3

**Parsing is NOT a performance bottleneck.** The sexp parse (`parse-datum`) is essentially instantaneous compared to elaboration/type-checking/reduction.

Track 3's value is NOT in making parsing faster. It's in:
1. **Architecture** — collapse the 14-file pipeline to registered productions
2. **Incrementality** — parse cells enable incremental re-parsing (Track 8/LSP)
3. **Extensibility** — grammar productions are the foundation for user-defined syntax (Track 7)
4. **Merge elimination** — shared cells replace the source-line-keyed merge scaffolding
5. **Preparse retirement** — moving registration to the network eliminates `preparse-expand-all`

---

## 7. Gap Analysis: Tree Parser Coverage

### 7.1 Implemented vs stub forms

| Form | tree-parser.rkt | parser.rkt | Status |
|------|----------------|------------|--------|
| def | Full | Full | Tree parser handles |
| defn | Full (multi-arity, Pi chains) | Full | Tree parser handles |
| spec | Full | Full | Tree parser handles |
| fn | Full (typed/untyped, return type) | Full | Tree parser handles |
| if/when | Full | Full | Tree parser handles |
| eval (top-level expr) | Full | Full | Tree parser handles |
| check/infer | Full | Full | Tree parser handles |
| ns/import/export | Full | Full | Tree parser handles |
| Application `[f x y]` | Full | Full | Tree parser handles |
| Angle types `<A -> B>` | Full | Full | Tree parser handles |
| Map/brace `{:k v}` | Full | Full | Tree parser handles |
| List literals `'[1 2 3]` | Full | Full | Tree parser handles |
| **data** | **ERROR STUB** | Full | **Gap** |
| **trait** | **ERROR STUB** | Full | **Gap** |
| **impl** | **ERROR STUB** | Full | **Gap** |
| **session** | **ERROR STUB** | Full (complex) | **Gap** |
| **defproc** | **ERROR STUB** | Full (complex) | **Gap** |
| **defr** | **ERROR STUB** | Full (complex) | **Gap** |
| **quote** | **ERROR STUB** | Full | **Gap** |
| **solver** | **ERROR STUB** | Full | **Gap** |

**8 error stubs**. The first 3 (data/trait/impl) are the most important — they involve registration side effects and are the most commonly used.

### 7.2 Builtin operations

parser.rkt handles ~115 builtin operation keywords (int+, map-get, set-insert, etc.) as direct `surf-*` struct construction. tree-parser.rkt handles these via `parse-expr-tree` → application parsing, which produces `surf-app` for function calls. The builtins handled by parser.rkt as special forms (with dedicated surf-* structs) vs. as application in tree-parser create a semantic gap.

**Implication**: In the propagator architecture, builtins can be registered as grammar productions that fire on specific function names, or they can remain as application + elaboration-time dispatch. The latter is simpler for Track 3.

---

## 8. Dependency Graph

```
parse-reader.rkt (tokenize, read)
    ↓
macros.rkt (preparse-expand-all: expand + register)
    ↓
parser.rkt (parse-datum: sexp → surf-*)
    ↓
driver.rkt (merge with tree-parser, then elaborate)
    ↑
tree-parser.rkt (parse-form-tree: tree → surf-*)
    ↑
surface-rewrite.rkt (pipe/compose/mixfix rewrite)
```

**parser.rkt requires from**: source-location, surface-syntax, errors, sexp-readtable, macros, global-env
**parser.rkt provides to**: driver.rkt (the ONLY external consumer via parse-datum)
**Coupling points**:
- parser.rkt → macros.rkt: `known-type-name?` (trivially extractable)
- parser.rkt → global-env.rkt: import but no usage (removable)
- driver.rkt → parser.rkt: `parse-datum` (7 call sites, all `(map parse-datum expanded-stxs)`)

---

## 9. Design Implications

### 9.1 Pure function characteristic

parser.rkt is a pure function with one boolean parameter. This is the BEST case for propagator migration — the function can be decomposed into grammar productions without untangling state dependencies. The state complexity is in `preparse-expand-all`, not in the parser itself.

### 9.2 Registration is the hard problem

The real challenge of Track 3 is not replacing parser.rkt — it's replacing `preparse-expand-all`. The registration side effects (data constructors, traits, impls, specs, macros) must move to the network. This is where SRE Track 2G's domain registry pattern applies: `register-domain!` IS the template for `register-data!`, `register-trait!`, etc. as cell writes.

### 9.3 Scale of the surface syntax

360 surf-* struct types is a large catalogue. Not all 360 need dedicated grammar productions — many are simple keyword→struct mappings that can be bulk-registered. The complexity centers are:
- **defn** (multi-arity, patterns, implicit binders, Pi chains) — ~500 lines of parsing
- **session/defproc** (complex sublanguage) — ~400 lines
- **defr** (relational sublanguage) — ~150 lines
- **data/trait/impl** (registration + parsing) — ~200 lines

Everything else is 5-20 lines of `case head → construct surf-*`.

### 9.4 Merge scaffolding is well-bounded

The Track 2B merge (driver.rkt) is 80 lines total: `merge-preparse-and-tree-parser` + `merge-form`. The scaffolding to replace is small. The `merge-form` function IS the lattice join that becomes the cell merge function.

### 9.5 Phasing suggestion

Based on this audit:
1. **Close tree-parser coverage gap** (8 stubs → full implementations: data, trait, impl, session, defproc, defr, quote, solver)
2. **Move registration to tree level** (data/trait/impl registration moves from preparse-expand-all to tree-parser or a dedicated post-tree-parse registration pass)
3. **Delete sexp expanders** (~500-600 lines in macros.rkt become unreachable)
4. **Formalize productions as propagators** (the grammar production architecture)
5. **Replace merge with shared cells** (merge-form becomes cell merge function)
6. **Retire parser.rkt** (6,605 lines)

Phases 1-3 are Track 2's "Phase 11" deferred work — prerequisite infrastructure.
Phases 4-6 are the core Track 3 propagator migration.

---

## 10. Quantitative Summary

| Metric | Value |
|--------|-------|
| parser.rkt lines | 6,605 |
| parser.rkt parse-* functions | 73 |
| parse-datum recursive calls (within parser.rkt) | 512 |
| Keyword head symbols dispatched | 236 |
| surf-* struct types (grammar outputs) | 360 |
| macros.rkt expand-* functions | 21 |
| macros.rkt total lines | 9,763 |
| Sexp expanders deletable | ~500-600 lines |
| tree-parser.rkt lines | 1,200 |
| tree-parser.rkt error stubs | 8 |
| surface-rewrite.rkt lines | 2,038 |
| Merge scaffolding lines | ~80 |
| External parse-datum call sites | 7 (all in driver.rkt) |
| Parameters read by parser.rkt | 1 (current-parsing-relational-goal?) |
| Registry/state reads by parser.rkt | 0 |
| Parse phase wall time (70-cmd file) | 0ms (unmeasurable) |
| Elaboration + type check wall time | 443ms (27% of total) |
| Reduction wall time | 1,049ms (64% of total) |
