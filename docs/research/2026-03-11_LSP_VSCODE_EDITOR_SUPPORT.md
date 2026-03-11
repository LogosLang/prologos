# Stage 1 Research: LSP Server & VSCode Extension for Prologos

## Table of Contents

1. [Introduction](#1-introduction)
2. [Landscape Survey](#2-landscape-survey)
   - 2.1 [Calva (Clojure/ClojureScript for VSCode)](#21-calva)
   - 2.2 [Lean 4 (vscode-lean4)](#22-lean-4)
   - 2.3 [Idris 2 (idris2-lsp + idris-vscode)](#23-idris-2)
   - 2.4 [Agda (agda-mode-vscode)](#24-agda)
   - 2.5 [Racket (racket-langserver)](#25-racket)
   - 2.6 [rust-analyzer (Rust)](#26-rust-analyzer)
3. [Tree-sitter in VSCode: Current State](#3-tree-sitter-in-vscode)
4. [Infrastructure Audit: What Prologos Already Has](#4-infrastructure-audit)
   - 4.1 [Emacs Editor Packages](#41-emacs-editor-packages)
   - 4.2 [Tree-sitter Grammar](#42-tree-sitter-grammar)
   - 4.3 [Pipeline APIs](#43-pipeline-apis)
   - 4.4 [Error Infrastructure](#44-error-infrastructure)
   - 4.5 [Source Location Tracking](#45-source-location-tracking)
   - 4.6 [Module System & Namespace Resolution](#46-module-system)
   - 4.7 [Type Pretty-Printing](#47-type-pretty-printing)
5. [Architecture Design Space](#5-architecture-design-space)
   - 5.1 [The Two-Layer Model](#51-two-layer-model)
   - 5.2 [Racket-Native LSP Server](#52-racket-native-lsp)
   - 5.3 [REPL Backend (Calva-Style Interactive Evaluation)](#53-repl-backend)
   - 5.4 [VSCode Extension TypeScript Layer](#54-vscode-extension)
6. [Infrastructure Gap Analysis](#6-gap-analysis)
7. [Proposed Tier Architecture](#7-tier-architecture)
8. [Key Design Questions](#8-design-questions)
9. [Vocabulary](#9-vocabulary)
10. [Bibliography](#10-bibliography)

---

## 1. Introduction

Prologos is gaining initial external interest, making editor support beyond Emacs a
strategic priority. The goal of this research is to survey the landscape of language
server and editor extension architectures for dependently-typed, interactive, and
REPL-driven languages, audit what Prologos already has, and establish the conceptual
vocabulary and architectural options for building:

1. A **Racket-native LSP server** that wraps the existing type-checking, elaboration,
   and error reporting pipeline
2. A **VSCode extension** as the primary new-editor target, with a first-class
   interactive development experience (Calva/CIDER-style inline evaluation)
3. An architecture that **supplements** (not replaces) the existing Emacs editor support

The design targets are informed by the user's decisions:
- **Racket-native LSP** + **tree-sitter** for the two-layer architecture
- **VSCode as primary target**, Emacs LSP (via eglot) as secondary consumer
- **Interactive inline evaluation** as a key differentiator (not just static LSP)
- **Time to do it right** — full roadmap before implementation

---

## 2. Landscape Survey

### 2.1 Calva (Clojure/ClojureScript for VSCode)

**Repository**: [BetterThanTomorrow/calva](https://github.com/BetterThanTomorrow/calva)

Calva is the most directly relevant reference architecture because it provides the
exact experience model we want: a live REPL connection with inline evaluation results,
in a VSCode extension, for a Lisp-family language.

#### Architecture

Calva has a **dual-protocol architecture**:

1. **nREPL** — The primary protocol. Calva connects to a running Clojure/ClojureScript
   nREPL server (typically started by Leiningen, deps.edn, or shadow-cljs). nREPL
   provides:
   - Code evaluation with namespace context
   - Completion candidates
   - Documentation lookup
   - Macro expansion
   - Test running

2. **clojure-lsp** — A separate LSP server (written in Clojure/GraalVM native) provides
   static analysis features:
   - Go-to-definition
   - Find references
   - Rename refactoring
   - Code actions
   - Diagnostics from clj-kondo (static linter)

This separation is important: **nREPL handles runtime features** (evaluation, dynamic
state) while **clojure-lsp handles static features** (navigation, refactoring). They
run concurrently and complement each other.

#### Inline Evaluation

Calva's inline evaluation works by:
1. Identifying the form at cursor (using a structural parser — Calva has its own
   ClojureScript-based paredit/parser called `clojure-lexer`)
2. Sending the form to nREPL for evaluation in the file's namespace
3. Displaying the result as a **VSCode decoration** (ghost text after the evaluated form)
4. Results persist until the next edit or evaluation

The evaluation API is exposed programmatically: `calva.eval(code, options)` returns
a Promise resolving to a Result object with stdout/stderr capture.

#### Key Lesson for Prologos

The nREPL/LSP split maps to our architecture: the **Racket REPL backend** handles
evaluation (like nREPL), while the **Racket LSP server** handles static features
(like clojure-lsp). Both run in the same Racket process but serve different purposes.

#### Syntax Highlighting

Calva uses a **TextMate grammar** (JSON/PList format) for syntax highlighting, not
tree-sitter. This is pragmatic — VSCode's built-in highlighter uses TextMate grammars,
and Clojure's regular syntax (uniform S-expressions) doesn't need tree-sitter's power.

---

### 2.2 Lean 4 (vscode-lean4)

**Repository**: [leanprover/vscode-lean4](https://github.com/leanprover/vscode-lean4)

Lean 4 is the gold standard for dependently-typed language editor support. Its VSCode
extension is the primary development environment for most Lean users.

#### Architecture

Lean 4 uses a **pure LSP architecture** — the Lean server itself implements the
Language Server Protocol. The VSCode extension is a thin TypeScript client.

The extension has three packages (NPM workspaces):
1. **vscode-lean4** — The extension proper (TypeScript, activates on `.lean` files)
2. **lean4-infoview** — A React application for the interactive InfoView panel
3. **lean4-infoview-api** — API glue between the extension and InfoView

#### The InfoView

The InfoView is Lean 4's signature feature — a **React webapp** rendered in a VSCode
webview panel that displays:
- Goal state at cursor position (proof goals, expected types)
- Elaborated term information
- Error messages with rich formatting
- Interactive widgets (custom per-proof-state UI)

The InfoView communicates with the Lean server via **custom LSP notifications**. The
standard LSP protocol doesn't have a concept of "goal state at cursor," so Lean extends
LSP with custom methods:
- `$/lean/plainGoal` — Get goal state at position
- `$/lean/plainTermGoal` — Get term-level info
- Custom widget rendering protocol

The InfoView can be hosted in **any editor** capable of displaying a webpage and
forwarding LSP notifications — it's not VSCode-specific.

#### Key Lesson for Prologos

The InfoView pattern is directly applicable. Prologos could have an InfoView-like panel
that shows:
- **Inferred type** at cursor
- **Narrowing results** for logic expressions
- **Trait instances** in scope
- **Elaborated form** (desugared IR)

This goes beyond what standard LSP hover provides — it's a continuously-updated panel
that reacts to cursor movement.

#### Incremental Checking

Lean 4's server processes files **incrementally** using dependency tracking. When a file
changes, only the affected declarations are re-elaborated. This is essential for
responsiveness in large files.

---

### 2.3 Idris 2 (idris2-lsp + idris-vscode)

**Repository**: [idris-community/idris2-lsp](https://github.com/idris-community/idris2-lsp)

#### Architecture

idris2-lsp is written **in Idris 2 itself**, wrapping the compiler's API with LSP
JSON-RPC. The VSCode extension (`idris-vscode`) is a thin TypeScript client.

#### LSP Capabilities

Standard LSP features:
- Diagnostics, hover, completion, go-to-definition, document symbols

Custom features via **LSP code actions** (not custom protocol):
- **Case split** — Generate pattern match cases from a hole
- **Add clause** — Generate function clause from type signature
- **Proof search** — Attempt automatic proof
- **Make lemma** — Extract expression into a separate lemma
- **Make case** — Transform expression into case expression

These interactive features are exposed as standard LSP code actions, which is clever —
no custom protocol needed, any LSP-capable editor gets them for free.

#### Key Lesson for Prologos

Using **LSP code actions** for interactive features (rather than custom protocol) is the
most portable approach. Prologos could expose:
- "Infer type" as a code action
- "Expand narrowing" as a code action
- "Show trait instances" as a code action

---

### 2.4 Agda (agda-mode-vscode)

**Repository**: [banacorn/agda-mode-vscode](https://github.com/banacorn/agda-mode-vscode)

#### Architecture

Agda does **not use LSP**. The agda-mode-vscode extension communicates with the Agda
backend via a **custom protocol** (the same `agda --interaction` protocol used by
Emacs agda-mode). The extension:

1. Spawns an Agda process
2. Sends commands via stdin (Emacs-like S-expression protocol)
3. Parses responses
4. Renders goal information in a **webview panel** (similar to Lean's InfoView)

#### Interactive Features

- **Goal-based editing**: `?` holes become interactive goals with a panel showing the
  expected type and context
- **Refinement**: Fill a goal with a partial term, Agda checks and creates sub-goals
- **Case split**: Generate pattern match from a variable in scope
- **Auto**: Attempt automatic proof search

#### Key Lesson for Prologos

Agda's approach shows that a **custom protocol** can work well if the interactive
features are rich enough to justify it. However, the maintenance burden is significant —
Agda essentially implements an editor protocol twice (once for Emacs, once for VSCode).
Starting with LSP (like Idris 2) is more sustainable.

---

### 2.5 Racket (racket-langserver)

**Repository**: [jeapostrophe/racket-langserver](https://github.com/jeapostrophe/racket-langserver)

#### Architecture

racket-langserver is a Racket-native LSP server that wraps DrRacket's public APIs. It
provides:
- Hover info (type signatures + documentation links)
- Completion candidates
- Diagnostics
- Rename refactoring

Compatible with Racket 7.6–9.1. Used with VSCode via the Magic Racket extension.

#### Key Lesson for Prologos

Demonstrates that a **Racket-native LSP server** is viable and has precedent. Our
server would wrap `process-file`/`process-string` instead of DrRacket APIs, but the
JSON-RPC and TCP plumbing patterns are directly reusable. Racket's `json` library
and TCP server infrastructure are sufficient.

---

### 2.6 rust-analyzer (Rust)

**Repository**: [rust-lang/rust-analyzer](https://github.com/rust-lang/rust-analyzer)

#### Architecture

rust-analyzer demonstrates the **two-layer model** at scale:
- **tree-sitter-rust** (or rust-analyzer's own parser) handles syntax
- **rust-analyzer LSP server** handles semantics

Key architectural patterns:
- **Salsa incremental computation**: Only re-computes what changed. Functions are
  memoized; inputs are tracked; when an input changes, only dependent computations
  are invalidated.
- **Semantic tokens**: LSP `textDocument/semanticTokens` provides semantic highlighting
  that augments tree-sitter's syntactic highlighting. Variables get colored differently
  based on whether they're mutable, functions by whether they're unsafe, etc.
- **Inlay hints**: LSP `textDocument/inlayHint` shows inferred types as ghost text.

#### Key Lesson for Prologos

**Semantic tokens** and **inlay hints** are standard LSP capabilities that would be
very powerful for Prologos:
- Semantic tokens: color variables by multiplicity (linear vs. unrestricted), highlight
  logic variables differently, color trait-dispatched calls
- Inlay hints: show inferred types on untyped `defn` bindings, show resolved trait
  instances at call sites

---

## 3. Tree-sitter in VSCode: Current State

### 3.1 VSCode's Built-in Support

As of 2026, VSCode does **not** have native tree-sitter integration for syntax
highlighting. VSCode uses **TextMate grammars** (regex-based) for its built-in
highlighting engine. There have been ongoing proposals and POCs (PR #147648) for a
tree-sitter service, but it remains unofficial.

### 3.2 Integration Options

| Approach | How it works | Maturity |
|----------|-------------|----------|
| **TextMate grammar** | JSON/PList regex grammar in `package.json` contributes | Production, standard |
| **vscode-anycode** | Microsoft's tree-sitter extension; provides outline, symbols, highlights | Production, 350k+ installs |
| **@vscode/tree-sitter-wasm** | NPM package for loading .wasm grammars in extensions | Released (v0.3.0), used by anycode |
| **Custom WASM extension** | Bundle `tree-sitter-prologos.wasm` + use `web-tree-sitter` | Proven pattern |
| **Semantic tokens via LSP** | Server provides token classifications; VSCode renders | Standard LSP, production |

### 3.3 Recommended Path for Prologos

**Dual approach**:

1. **TextMate grammar for immediate highlighting** — Convert the tree-sitter
   `highlights.scm` patterns to TextMate regex rules. This gives instant, zero-dependency
   highlighting that works in all VSCode themes. The tree-sitter grammar has ~20
   highlighting rules that map cleanly to TextMate scopes.

2. **Tree-sitter WASM for structural features** — Compile `tree-sitter-prologos` to
   `.wasm`, bundle in the extension, use for:
   - Structural selection (select enclosing form, expand/contract selection)
   - Code folding (fold `defn`, `match`, `impl` blocks)
   - Document outline / breadcrumbs
   - Form identification for inline evaluation (identify the form at cursor)

3. **Semantic tokens via LSP for rich highlighting** — The LSP server provides
   semantic token data that augments TextMate highlighting:
   - Logic variables colored differently from regular variables
   - Linear vs. unrestricted bindings
   - Type constructors vs. data constructors
   - Trait-resolved vs. direct function calls

---

## 4. Infrastructure Audit: What Prologos Already Has

### 4.1 Emacs Editor Packages

Located in `editors/emacs/`. Seven packages, 149 ERT tests:

| Package | File | Purpose |
|---------|------|---------|
| **prologos-mode** | `prologos-mode.el` | Major mode: regex-based highlighting, keybindings |
| **prologos-ts-mode** | `prologos-ts-mode.el` | Tree-sitter major mode (Emacs 29+) |
| **prologos-font-lock** | `prologos-font-lock.el` | Shared font-lock keyword definitions |
| **prologos-indent** | `prologos-indent.el` | Indentation engine for WS-mode files |
| **prologos-repl** | `prologos-repl.el` | REPL integration (comint-based) |
| **prologos-surfer** | `prologos-surfer.el` | Structural navigation (paredit-style) |
| **prologos-surfer-navigation** | `prologos-surfer-navigation.el` | Extended navigation commands |

Tests: `prologos-mode-test.el`, `prologos-ts-mode-test.el`, `prologos-indent-test.el`,
`prologos-repl-test.el`, `prologos-surfer-test.el`.

**What transfers to VSCode**:
- Font-lock keyword lists → TextMate grammar scopes
- Indentation rules → LSP `textDocument/formatting` or tree-sitter-based indent
- REPL protocol → REPL backend protocol design
- Surfer structural commands → tree-sitter structural selection

**What doesn't transfer**:
- Emacs-specific comint integration
- Emacs-specific overlay rendering (for inline results)
- Emacs keybinding conventions

### 4.2 Tree-sitter Grammar

Located in `editors/tree-sitter-prologos/`.

**Files**:
- `grammar.js` — The tree-sitter grammar definition
- `src/parser.c` — Generated C parser
- `src/scanner.c` — Custom scanner (for WS-mode indentation sensitivity)
- `queries/highlights.scm` — Highlight queries (83 lines, ~20 rules)
- `libtree-sitter-prologos.dylib` — Compiled native library (macOS aarch64)
- `tree-sitter.json` — Configuration
- `test/corpus/` — 12 test corpus files

**Highlight categories covered**: keywords (grammar + identifier-matched), definition
names (defn, def, data, constructors, ns), built-in types (Pi, Sigma, Type, Nat, Bool,
etc.), built-in constants (zero, true, false, nil, cons, etc.), patterns, fn params,
operators, multiplicity annotations, literals (number, string, comment), identifiers.

**What's needed for VSCode**:
- Compile to `.wasm` (via `tree-sitter build --wasm`) for web-tree-sitter consumption
- Extend highlight queries for newer syntax (mixfix `.{}`, pipe `|>`, compose `>>`,
  quasiquote, transducers, traits/impl/bundle, session types)
- Add `folds.scm` and `indents.scm` query files

### 4.3 Pipeline APIs

The main entry points in the Racket pipeline:

| Function | File | Purpose |
|----------|------|---------|
| `process-file` | `driver.rkt` | Process a `.prologos` file (full pipeline: read → preparse → parse → elaborate → type-check → resolve traits → zonk) |
| `process-string` | `driver.rkt` | Process an S-expression string (skips reader) |
| `process-string-ws` | `driver.rkt` | Process a WS-mode string (includes reader) |

All three return a results list containing elaborated/reduced expressions and any
errors. The pipeline is single-shot (processes the entire input at once).

**For LSP, we need**:
- `process-file` for diagnostics-on-save (already exists)
- A way to query type information at a specific source position (does not exist)
- A way to evaluate a single form in an existing namespace context (partially exists
  via REPL)

### 4.4 Error Infrastructure

**Source**: `errors.rkt`, `typing-errors.rkt`, `lang-error.rkt`

Errors carry structured information:
- `srcloc` (file, line, col, span)
- Error category/code (E1001 type mismatch, E1002 unresolved meta, E1003 inference
  failure, etc.)
- Provenance chains (where the constraint originated)
- Expected vs. actual types
- Suggestions (for common mistakes)

**Mapping to LSP Diagnostics**: This maps cleanly to `textDocument/publishDiagnostics`:
- `srcloc` → `Range` (line/col to line/col+span)
- Error code → `DiagnosticCode`
- Error message → `message`
- Severity → Error for type errors, Warning for unused variables, etc.
- Related information → Provenance chain as `DiagnosticRelatedInformation`

**Gap**: Error srclocs reference the *surface* syntax positions. For WS-mode files
processed through the reader, line numbers should be correct since the reader tracks
positions. Need to verify this end-to-end.

### 4.5 Source Location Tracking

**Source**: `source-location.rkt`

```racket
(struct srcloc (file line col span) #:transparent)
```

Srclocs are attached to **surface syntax** nodes (`surf-*` forms in `surface-syntax.rkt`).
During elaboration, some srcloc information propagates to core AST nodes, but not
systematically. The `metavar-store.rkt` tracks source locations for metavariables
(important for "type at position" queries).

**Key gap**: There is no systematic `position → type` mapping produced during
elaboration. To support hover-type queries, we need either:

1. **Elaboration-time side table**: During elaboration, record `(srcloc → inferred-type)`
   entries in a hash table. This is the approach Lean 4 and rust-analyzer use.
2. **Post-hoc tree walk**: After elaboration, walk the core AST and collect type
   information. Lossy (not all positions retained) but simpler.

Option 1 is strongly recommended. The elaboration pass already has access to both the
surface form (with srcloc) and the inferred type — recording the mapping is cheap.

### 4.6 Module System & Namespace Resolution

**Sources**: `namespace.rkt`, `module-info.rkt`, `global-env.rkt`

The module system provides:
- `module-info` structs with exports (name → type), file paths, qualified names
- `current-module-registry` parameter: hash from module name to `module-info`
- Namespace resolution: `ns foo` triggers loading of the prelude + imports
- Import resolution: `:refer [x y]`, `:refer-all`, `:as alias` patterns

**Mapping to LSP features**:
- **Go-to-definition**: module-info has file paths; namespace resolution provides the
  binding → module mapping. Need to add source position to exports.
- **Completion**: module exports + prelude names + local bindings. Module-info already
  has export lists with types.
- **Signature help**: `spec` declarations provide function signatures. Need a lookup
  from function name → spec declaration.

### 4.7 Type Pretty-Printing

**Source**: `pretty-print.rkt` — exports `pp-expr`

The pretty-printer converts core AST types to readable strings. This is what would
appear in hover tooltips and InfoView panels. It already handles:
- Pi types with named/unnamed parameters
- Sigma types
- Multiplicity annotations
- Type applications
- Universe levels

**Gap**: The pretty-printer produces S-expression-style output. For WS-mode users,
we should have a WS-mode pretty-printer that shows types in the surface syntax style
(e.g., `<(x : Nat) -> Nat>` instead of `(Pi ((x :1 Nat)) Nat)`).

---

## 5. Architecture Design Space

### 5.1 The Two-Layer Model

Based on the landscape survey and user decisions, the architecture is:

```
┌─────────────────────────────────────────────────┐
│                  VSCode Extension                │
│                  (TypeScript)                    │
│                                                 │
│  ┌────────────┐  ┌────────────┐  ┌───────────┐ │
│  │  TextMate   │  │ Tree-sitter│  │  LSP      │ │
│  │  Grammar    │  │  .wasm     │  │  Client   │ │
│  │  (highlight)│  │  (struct)  │  │  (vscode- │ │
│  │             │  │            │  │  language- │ │
│  │             │  │            │  │  client)   │ │
│  └────────────┘  └────────────┘  └─────┬─────┘ │
│                                        │        │
│  ┌─────────────────────────────────────┼──────┐ │
│  │        Interactive Panel             │      │ │
│  │        (Webview, React)             │      │ │
│  │  - Type at cursor                   │      │ │
│  │  - Narrowing results               │      │ │
│  │  - Trait instances                  │      │ │
│  └─────────────────────────────────────┼──────┘ │
└────────────────────────────────────────┼────────┘
                     stdio / JSON-RPC    │
┌────────────────────────────────────────┼────────┐
│              Racket Process            │        │
│                                        │        │
│  ┌────────────────────┐  ┌────────────┼──────┐ │
│  │   LSP Server        │  │   REPL     │      │ │
│  │   (JSON-RPC)        │  │   Backend  │      │ │
│  │                     │  │            │      │ │
│  │ - diagnostics       │  │ - eval     │      │ │
│  │ - hover             │  │ - load-ns  │      │ │
│  │ - go-to-def         │  │ - inspect  │      │ │
│  │ - completion        │  │ - narrow   │      │ │
│  │ - semantic tokens   │  │ - solve    │      │ │
│  │ - inlay hints       │  │            │      │ │
│  └─────────┬──────────┘  └─────┬──────┘      │ │
│            │                    │              │ │
│  ┌─────────┴────────────────────┴──────────┐  │ │
│  │        Prologos Pipeline                 │  │ │
│  │  reader → preparse → parse → elaborate   │  │ │
│  │  → type-check → trait-resolve → zonk     │  │ │
│  │                                          │  │ │
│  │  process-file / process-string-ws        │  │ │
│  │  module-registry / global-env            │  │ │
│  └──────────────────────────────────────────┘  │ │
└────────────────────────────────────────────────┘
```

### 5.2 Racket-Native LSP Server

The LSP server runs as a Racket process communicating via **stdio** (standard for
LSP client-server communication). It implements the LSP protocol using JSON-RPC.

**Racket libraries needed**:
- `json` — JSON serialization/deserialization (built-in)
- TCP/stdio — Racket has built-in port I/O
- We write a thin JSON-RPC layer (or use an existing Racket JSON-RPC library)

**LSP capabilities to implement** (prioritized):

| Capability | LSP Method | Prologos Source | Priority |
|-----------|------------|-----------------|----------|
| Diagnostics | `textDocument/publishDiagnostics` | `process-file` errors | P0 |
| Hover | `textDocument/hover` | Position → type lookup (NEW) | P1 |
| Go-to-definition | `textDocument/definition` | module-info file paths | P1 |
| Completion | `textDocument/completion` | module exports + prelude + locals | P2 |
| Signature help | `textDocument/signatureHelp` | spec declarations | P2 |
| Document symbols | `textDocument/documentSymbol` | Top-level defs from parse | P2 |
| Semantic tokens | `textDocument/semanticTokens` | Elaboration metadata (NEW) | P3 |
| Inlay hints | `textDocument/inlayHint` | Inferred types on bindings (NEW) | P3 |
| Code actions | `textDocument/codeAction` | Interactive features | P4 |
| Formatting | `textDocument/formatting` | Formatter (NEW) | P5 |

### 5.3 REPL Backend (Calva-Style Interactive Evaluation)

The REPL backend is the component that enables inline evaluation. It maintains a
**persistent namespace context** (like Calva's nREPL session) and can evaluate forms
incrementally.

**Protocol options**:

1. **Integrated into LSP** — Custom LSP methods (like Lean's `$/lean/plainGoal`):
   - `$/prologos/eval` — Evaluate a form, return result
   - `$/prologos/loadFile` — Load a file into the REPL namespace
   - `$/prologos/narrowing` — Run narrowing query
   - `$/prologos/solve` — Run relational solve
   - `$/prologos/typeOf` — Get inferred type of expression
   - `$/prologos/instancesOf` — Query trait instances

2. **Separate protocol** — Like Calva's nREPL, a separate connection:
   - More flexibility, independent lifecycle
   - More complex to implement and manage

**Recommendation**: Option 1 (integrated into LSP). The Racket process already runs
for LSP — adding custom methods avoids a second process. Lean 4 validates this pattern.

**Implementation**: The existing REPL infrastructure (`repl.rkt`) already has:
- File processing with persistent global-env
- `process-file` that returns results
- Namespace-aware evaluation

We need to add:
- **Incremental namespace building**: Process individual top-level forms and accumulate
  into the global-env, rather than re-processing the entire file
- **Form identification**: Given a cursor position, identify the enclosing top-level
  form (tree-sitter handles this client-side)
- **Result formatting**: Format evaluation results for inline display

### 5.4 VSCode Extension TypeScript Layer

The VSCode extension (`vscode-prologos`) is a TypeScript package that:

1. **Activates** on `.prologos` files
2. **Starts** the Racket LSP server process
3. **Connects** via `vscode-languageclient` (the standard Node.js LSP client)
4. **Registers** commands for interactive features:
   - `prologos.evalForm` — Evaluate form at cursor
   - `prologos.evalTopLevel` — Evaluate top-level definition
   - `prologos.evalFile` — Load entire file
   - `prologos.showType` — Show type of expression at cursor
   - `prologos.narrow` — Run narrowing on expression
   - `prologos.clearInlineResults` — Clear inline decorations

5. **Renders** inline results as VSCode decorations (after-text decorations,
   like Calva does)

6. **Optionally** opens an InfoView panel (webview) for richer display

**Extension structure**:
```
vscode-prologos/
  package.json          -- Extension manifest (activationEvents, contributes)
  src/
    extension.ts        -- Main entry, activate/deactivate
    client.ts           -- LSP client setup, server lifecycle
    repl.ts             -- REPL interaction (eval, inline results)
    infoview/           -- React app for InfoView panel (later tier)
    decorations.ts      -- Inline result rendering
  syntaxes/
    prologos.tmLanguage.json  -- TextMate grammar
  tree-sitter/
    prologos.wasm       -- Compiled tree-sitter grammar
  language-configuration.json  -- Brackets, comments, auto-close
```

---

## 6. Infrastructure Gap Analysis

| Component | Have | Gap | Effort |
|-----------|------|-----|--------|
| **Tree-sitter grammar** | grammar.js, parser.c, highlights.scm, .dylib | Need .wasm build, extended queries (folds, indents), coverage for newer syntax | M |
| **TextMate grammar** | — | Need to create from scratch (or convert from tree-sitter highlights) | M |
| **LSP JSON-RPC** | — | Need Racket JSON-RPC implementation (stdio) | M |
| **Diagnostics pipeline** | process-file → errors with srclocs | Need error → LSP Diagnostic mapping | S |
| **Position → type map** | — | Need elaboration-time side table recording srcloc → type | L |
| **Module-info file paths** | module-info has module names | Need source file paths in module-info exports | M |
| **Spec → signature help** | spec declarations in parser | Need spec lookup by function name | S |
| **WS-mode pretty-printer** | pp-expr (sexp style) | Need WS-surface-style type display | M |
| **Incremental REPL** | repl.rkt (batch file processing) | Need per-form evaluation with persistent env | M |
| **Inline result formatting** | reduction produces values | Need compact result formatting for inline display | S |
| **VSCode extension scaffold** | — | TypeScript package with LSP client, commands, decorations | L |
| **Language configuration** | — | Brackets, comments, auto-close, word pattern | S |

**Legend**: S = Small (hours), M = Medium (1-2 days), L = Large (3+ days)

---

## 7. Proposed Tier Architecture

### Tier 1: Syntax & Static (no server)

**Goal**: A `.prologos` file opens in VSCode with correct highlighting, bracket
matching, code folding, and snippets. No server process needed.

**Components**:
- TextMate grammar (`prologos.tmLanguage.json`)
- Language configuration (brackets, comments, auto-close pairs)
- Snippets for common forms (`defn`, `spec`, `match`, `impl`, `ns`)
- Tree-sitter `.wasm` for structural selection and folding

**Effort**: ~3-5 days
**Dependencies**: None (can ship standalone)

---

### Tier 2: Diagnostics & Navigation (LSP, file-level)

**Goal**: Errors appear inline on save. Go-to-definition works. Signature help from
specs. Document outline shows top-level definitions.

**Components**:
- Racket LSP server skeleton (JSON-RPC over stdio)
- `textDocument/publishDiagnostics` from `process-file` errors
- `textDocument/definition` from module-info + namespace resolution
- `textDocument/signatureHelp` from spec declarations
- `textDocument/documentSymbol` from top-level form parsing

**Infrastructure needed**:
- JSON-RPC implementation in Racket
- Error → Diagnostic mapping
- Source file path tracking in module-info

**Effort**: ~1-2 weeks
**Dependencies**: Tier 1 (highlighting)

---

### Tier 3: Type Intelligence (LSP, expression-level)

**Goal**: Hover shows inferred types. Inlay hints show types on bindings. Semantic
tokens provide rich highlighting (logic vars, multiplicities, trait dispatch).

**Components**:
- `textDocument/hover` — Position → type lookup
- `textDocument/inlayHint` — Ghost text for inferred types
- `textDocument/semanticTokens` — Rich semantic highlighting
- `textDocument/completion` — Module exports + prelude + locals

**Infrastructure needed** (the big investment):
- **Elaboration-time side table**: `srcloc → inferred-type` mapping
- **WS-mode pretty-printer** for types
- **Semantic token classification** scheme for Prologos-specific concepts

**Effort**: ~2-3 weeks
**Dependencies**: Tier 2 (LSP server running)

---

### Tier 4: Interactive Evaluation (REPL backend, Calva-style)

**Goal**: Evaluate any form inline, see result next to the code. Build up namespace
interactively. Run narrowing/solve queries from the editor.

**Components**:
- Custom LSP methods for evaluation (`$/prologos/eval`, etc.)
- Per-form REPL evaluation with persistent namespace
- Inline result decorations (VSCode `DecorationRenderOptions`)
- REPL panel (terminal or webview)
- Keybindings: Ctrl+Enter (eval form), Shift+Enter (eval top-level), etc.

**Infrastructure needed**:
- Incremental namespace builder in Racket
- Form identification (tree-sitter client-side)
- Result formatting for inline display
- Decoration lifecycle management

**Effort**: ~2-3 weeks
**Dependencies**: Tier 3 (type infrastructure), tree-sitter .wasm (form identification)

---

### Tier 5: InfoView Panel (Lean-style, future)

**Goal**: A continuously-updated panel showing type context, narrowing state, goal
information, and interactive widgets.

**Components**:
- React webview app (like Lean's InfoView)
- Cursor-position-reactive updates
- Rich rendering (types, constraints, narrowing trees)
- Interactive narrowing exploration

**Effort**: ~3-4 weeks
**Dependencies**: Tier 4 (REPL backend)

---

## 8. Key Design Questions

### Q1: Diagnostics on save or on type?

**On save** is simpler (call `process-file` once when the file is saved) and sufficient
for Tier 2. **On type** requires debouncing and processing potentially-invalid partial
files. Start with on-save; add on-type in a later tier if responsiveness demands it.

### Q2: Single Racket process or pool?

A single Racket process is simplest. Racket's GC pauses could cause latency spikes,
but our files are small (not million-line codebases). If latency becomes an issue, a
two-process model (one for LSP, one for REPL eval) provides isolation. Start with one.

### Q3: How to identify forms for inline evaluation?

**Tree-sitter on the client side**. The VSCode extension uses the .wasm grammar to
parse the file locally, identifies the top-level form containing the cursor, and sends
it (as a string with position info) to the server for evaluation. This is how Calva
works — structural parsing happens client-side, evaluation happens server-side.

### Q4: How to handle the prelude for completion?

The prelude auto-imports ~200+ names. For completion, the LSP server should maintain a
cached list of prelude exports (with types) that is sent on initialization. Per-file
imports add to this list. The module registry already has this data.

### Q5: Should we use the existing Racket LSP libraries?

The existing `racket-langserver` uses DrRacket's APIs, not our pipeline. Starting from
scratch with a thin JSON-RPC layer gives us full control and avoids depending on
DrRacket internals that may not match our needs. The JSON-RPC protocol is simple enough
to implement directly (a few hundred lines of Racket).

### Q6: TextMate grammar: manual or generated?

**Manual** is recommended. The tree-sitter grammar has ~20 highlight categories that
map to ~40-50 TextMate regex rules. Prologos's WS-mode syntax has enough regularity
that regex-based highlighting works well. A generated approach (tree-sitter → TextMate)
is possible but the tools are immature and the output often needs manual tuning.

---

## 9. Vocabulary

| Term | Definition |
|------|-----------|
| **LSP** | Language Server Protocol — standardized JSON-RPC protocol between editors and language servers |
| **JSON-RPC** | JSON Remote Procedure Call — the wire protocol underlying LSP |
| **TextMate grammar** | Regex-based syntax grammar format used by VSCode, Sublime, Atom |
| **Semantic tokens** | LSP capability for server-provided syntax classification (augments TextMate) |
| **Inlay hints** | LSP capability for ghost text showing inferred information (types, parameter names) |
| **InfoView** | A side panel (webview) showing contextual information (types, goals, constraints) |
| **nREPL** | Network REPL protocol used by Clojure tooling; evaluates code in a running process |
| **web-tree-sitter** | WASM build of tree-sitter for use in web/Node.js environments |
| **Side table** | An auxiliary data structure built during compilation mapping positions to metadata |
| **Debounce** | Delay processing until input has settled (e.g., wait 300ms after last keystroke) |
| **Code action** | LSP feature for context-sensitive operations (refactoring, quick fixes) |

---

## 10. Bibliography

### Systems Surveyed

1. **Calva** — Clojure/ClojureScript VSCode extension. nREPL + clojure-lsp dual protocol.
   [calva.io](https://calva.io/), [GitHub](https://github.com/BetterThanTomorrow/calva)

2. **vscode-lean4** — Lean 4 VSCode extension. Pure LSP + custom methods + React InfoView.
   [GitHub](https://github.com/leanprover/vscode-lean4),
   [DeepWiki](https://deepwiki.com/leanprover/vscode-lean4/1-overview)

3. **idris2-lsp** — Idris 2 LSP server (written in Idris 2). Standard LSP + code actions for interactive features.
   [GitHub](https://github.com/idris-community/idris2-lsp)

4. **agda-mode-vscode** — Agda VSCode extension. Custom protocol (not LSP). Webview goals panel.
   [GitHub](https://github.com/banacorn/agda-mode-vscode)

5. **racket-langserver** — Racket LSP server wrapping DrRacket APIs. Precedent for Racket-native LSP.
   [Docs](https://docs.racket-lang.org/racket-langserver/index.html),
   [GitHub](https://github.com/jeapostrophe/racket-langserver)

6. **rust-analyzer** — Rust LSP server. Two-layer model (tree-sitter syntax + LSP semantics).
   Salsa incremental computation. Semantic tokens + inlay hints.
   [GitHub](https://github.com/rust-lang/rust-analyzer)

7. **ElixirLS** — Elixir LSP server. Uses Dialyzer for type inference. Standard LSP.
   [GitHub](https://github.com/elixir-lsp/elixir-ls)

### Specifications

8. **Language Server Protocol** — Microsoft. Standardized editor-server communication.
   [Specification](https://microsoft.github.io/language-server-protocol/),
   [GitHub](https://github.com/microsoft/language-server-protocol)

9. **vscode-languageserver-node** — NPM packages for LSP client/server in Node.js.
   [GitHub](https://github.com/microsoft/vscode-languageserver-node)

### Tree-sitter in VSCode

10. **vscode-anycode** — Microsoft's tree-sitter extension for VSCode.
    [Marketplace](https://marketplace.visualstudio.com/items?itemName=ms-vscode.anycode)

11. **@vscode/tree-sitter-wasm** — Pre-built tree-sitter WASM files.
    [GitHub](https://github.com/microsoft/vscode-tree-sitter-wasm),
    [NPM](https://www.npmjs.com/package/@vscode/tree-sitter-wasm)

12. **tree-sitter-vscode** — Community extension for tree-sitter in VSCode.
    [GitHub](https://github.com/AlecGhost/tree-sitter-vscode)

### Prior Prologos Research

13. **IMPLEMENTATION_EDITOR_SUPPORT_EMACS.md** — Research document covering the Emacs
    editor support implementation (7 packages, dual-mode architecture, REPL integration).
    `docs/research/IMPLEMENTATION_EDITOR_SUPPORT_EMACS.md`

14. **IMPLEMENTATION_EMACS_PROLOGOS_SURFER_AND_INTERACTIVE_DEVELOPMENT.md** — Research
    document covering structural editing and interactive development patterns.
    `docs/research/IMPLEMENTATION_EMACS_PROLOGOS_SURFER_AND_INTERACTIVE_DEVELOPMENT.md`
