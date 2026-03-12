# Stage 2→4: VSCode Extension — Research, Design & Implementation

**Companion to**: [Stage 1 Research](./2026-03-11_LSP_VSCODE_EDITOR_SUPPORT.md)
**Date**: 2026-03-11
**Stage**: 2–4 of 5 (per [DESIGN_METHODOLOGY.org](../tracking/principles/DESIGN_METHODOLOGY.org))
**Implementation started**: 2026-03-11

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Progress Tracker](#2-progress-tracker)
3. [Architecture Decision: Reference Model](#3-architecture-decision)
4. [Tier Dependency Graph](#4-tier-dependency-graph)
5. [Tier 1: Syntax & Static](#5-tier-1-syntax--static)
6. [Tier 2: Diagnostics & Navigation](#6-tier-2-diagnostics--navigation)
7. [Tier 3: Type Intelligence](#7-tier-3-type-intelligence)
8. [Tier 4: Interactive Evaluation](#8-tier-4-interactive-evaluation)
9. [Tier 5: InfoView Panel](#9-tier-5-infoview-panel)
10. [Infrastructure Investments (Cross-Tier)](#10-infrastructure-investments)
11. [Tradeoff Matrices](#11-tradeoff-matrices)
12. [Principle Alignment Check](#12-principle-alignment-check)
13. [Open Design Questions with Recommendations](#13-open-design-questions)
14. [Effort Summary & Sequencing](#14-effort-summary)
15. [Risk Register](#15-risk-register)

---

## 1. Executive Summary

This document refines the Stage 1 landscape survey into a concrete, phased implementation
roadmap for VSCode editor support. It identifies the infrastructure gaps in the Prologos
codebase, estimates effort at the file level, resolves key design questions with
recommendations, and sequences work into five tiers with explicit dependencies.

**Key decisions refined here:**
- Two-layer architecture: tree-sitter (syntax) + Racket-native LSP (semantics)
- Single Racket process serving both LSP and REPL evaluation
- Custom LSP methods (`$/prologos/*`) for interactive features (eval, narrowing)
- TextMate grammar for immediate highlighting; tree-sitter WASM for structural features
- **Propagator-first infrastructure**: all LSP state (type index, definition registry,
  diagnostics, module exports, completion cache) built on propagator cells — not mutable
  hash tables. Correct-by-construction: derived state is always consistent because the
  network topology enforces it. Incremental re-elaboration falls out of the architecture
  rather than requiring hand-written invalidation code.

**Total estimated effort**: ~8–12 weeks of focused implementation across all five tiers.
Tier 1 (syntax-only, no server) can ship independently within ~1 week. Tier 2 (diagnostics
+ navigation) adds ~2 weeks. Combined Tiers 1+2 provide a usable development experience.

---

## 2. Progress Tracker

### Design Phases

| # | Phase | ⏳ | Notes |
|---|-------|---|-------|
| D1 | Stage 1: Landscape survey | ✅ | `2026-03-11_LSP_VSCODE_EDITOR_SUPPORT.md` |
| D2 | Stage 2: Research refinement & gap analysis | ✅ | This document (original) |
| D3 | Stage 3: Design iteration | ✅ | Propagator-first decision, §9-10 tradeoff matrices |
| D4 | Stage 4: Implementation | 🔄 | Started 2026-03-11 |

### Tier 1: Syntax & Static (No Server)

| # | Sub-phase | ⏳ | Notes |
|---|-----------|---|-------|
| 1.0 | Extension scaffold (`package.json`, `tsconfig`, `extension.ts`) | ✅ | `ca4d756` — manifest, TS config, minimal activation |
| 1.1 | Tree-sitter grammar refresh | ✅ | `3b52243` + `899b226` — ~25 new forms, parser generated, 3/5 stdlib files parse 100% |
| 1.2 | TextMate grammar (`prologos.tmLanguage.json`) | ✅ | `ca4d756` — 15 scope categories, all current keywords/types/operators |
| 1.3 | Language configuration + snippets | ✅ | `ca4d756` — brackets, comments, indentation, folding, 16 snippets |
| 1.4 | Tree-sitter WASM build + query files | ✅ | `899b226` — parser generated, queries in place. WASM for VSCode deferred to Tier 4 (tree-sitter WASM needed for form identification). |
| 1.5 | Integration test + verification | ⬜ | Needs manual VSCode testing (`code --extensionDevelopmentPath=.`) |

### Tier 2: Diagnostics & Navigation (LSP Server)

| # | Sub-phase | ⏳ | Notes |
|---|-----------|---|-------|
| 2.0 | JSON-RPC layer (`lsp/json-rpc.rkt`) | ✅ | `c2787b2` — read/write with Content-Length, #px regex |
| 2.1 | LSP server main loop (`lsp/server.rkt`) | ✅ | `c2787b2` — lifecycle + didOpen/didChange/didSave/didClose + documentSymbol |
| 2.2 | Diagnostic publisher (`lsp/diagnostics.rkt`) | ✅ | `c2787b2` — error→diagnostic, E1001-E3001, srcloc→range |
| 2.3 | Definition location infrastructure | ✅ | `d1eab47` — current-definition-locations param, module-info 8th field, 3 success paths in process-def |
| 2.4 | Go-to-definition provider | ✅ | `d1eab47` — word-at-position + location lookup with FQN and regex fallbacks |
| 2.5 | Document symbol provider | ✅ | `c2787b2` — regex-based outline in server.rkt |
| 2.6 | Signature help provider | ✅ | `d1eab47` — bracket-based fn detection + param names from defn registry |
| 2.7 | TypeScript LSP client (`src/client.ts`) | ✅ | `c2787b2` — auto-detect Racket, configurable paths |
| 2.8 | Integration test + verification | ⬜ | Lifecycle verified; on-save diagnostics need VSCode test |

### Tier 3: Type Intelligence

| # | Sub-phase | ⏳ | Notes |
|---|-----------|---|-------|
| 3.0 | Elaboration side table (`lsp/type-index.rkt`) | ⬜ | ~30-50 instrumentation points |
| 3.1 | WS-mode pretty-printer (`pp-expr-ws`) | ⬜ | ~200-300 lines |
| 3.2 | Hover provider (`lsp/hover.rkt`) | ⬜ | |
| 3.3 | Completion provider (`lsp/completion.rkt`) | ⬜ | 5 completion sources |
| 3.4 | Semantic token provider (`lsp/semantic-tokens.rkt`) | ⬜ | 12 token types, 6 modifiers |
| 3.5 | Inlay hint provider (`lsp/inlay-hints.rkt`) | ⬜ | |
| 3.6 | Integration test + verification | ⬜ | All §6.8 verification checklist items |

### Tier 4: Interactive Evaluation

| # | Sub-phase | ⏳ | Notes |
|---|-----------|---|-------|
| 4.0 | REPL backend (`lsp/repl.rkt`) | ⬜ | |
| 4.1 | Custom LSP methods (`$/prologos/*`) | ⬜ | eval, loadFile, narrowing, typeOf, elaborated |
| 4.2 | Form identification (`src/forms.ts`) | ⬜ | Tree-sitter WASM cursor navigation |
| 4.3 | Inline decorations (`src/decorations.ts`) | ⬜ | |
| 4.4 | REPL commands + keybindings | ⬜ | |
| 4.5 | Integration test + verification | ⬜ | |

### Tier 5: InfoView Panel

| # | Sub-phase | ⏳ | Notes |
|---|-----------|---|-------|
| 5.0 | React webview skeleton | ⬜ | |
| 5.1 | Goal/context display | ⬜ | |
| 5.2 | Narrowing result display | ⬜ | |
| 5.3 | Interactive type exploration | ⬜ | |
| 5.4 | Integration test + verification | ⬜ | |

### Legend

| Symbol | Meaning |
|--------|---------|
| ⬜ | Not started |
| 🔄 | In progress |
| ✅ | Complete |
| ⏸️ | Paused/blocked |
| 🚫 | Deferred |

---

## 3. Architecture Decision: Reference Model

### Selected Architecture

Based on the Stage 1 survey of Lean 4, Calva, Idris 2, Agda, rust-analyzer, and
racket-langserver, we adopt a **Lean 4–influenced, Calva-inspired** architecture:

```
┌──────────────────────────────────────────────────────────────┐
│                    VSCode Extension (TypeScript)             │
│                                                              │
│  ┌──────────────┐ ┌──────────────┐ ┌───────────────────────┐ │
│  │ TextMate     │ │ Tree-sitter  │ │ LSP Client            │ │
│  │ Grammar      │ │ WASM         │ │ (vscode-languageclient│ │
│  │ (.tmLanguage)│ │ (structural) │ │  + custom methods)    │ │
│  └──────────────┘ └──────────────┘ └───────────┬───────────┘ │
│                                                │             │
│  ┌────────────────────────┐  ┌─────────────────┼──────────┐  │
│  │ Inline Result          │  │ InfoView Panel  │          │  │
│  │ Decorations            │  │ (React Webview) │          │  │
│  │ (VSCode DecorationAPI) │  │ (Tier 5)        │          │  │
│  └────────────────────────┘  └─────────────────┼──────────┘  │
└────────────────────────────────────────────────┼─────────────┘
                              stdio / JSON-RPC   │
┌────────────────────────────────────────────────┼─────────────┐
│                 Racket Process (single)        │             │
│                                                │             │
│  ┌───────────────────────┐  ┌──────────────────┴───────────┐ │
│  │ LSP Server            │  │ REPL Backend                 │ │
│  │ (lsp-server.rkt)      │  │ (lsp-repl.rkt)               │ │
│  │                       │  │                              │ │
│  │ Standard methods:     │  │ Custom methods:              │ │
│  │ · publishDiagnostics  │  │ · $/prologos/eval            │ │
│  │ · hover               │  │ · $/prologos/loadFile        │ │
│  │ · definition          │  │ · $/prologos/narrowing       │ │
│  │ · completion          │  │ · $/prologos/typeOf          │ │
│  │ · signatureHelp       │  │ · $/prologos/elaborated      │ │
│  │ · semanticTokens      │  │                              │ │
│  │ · inlayHint           │  │                              │ │
│  │ · documentSymbol      │  │                              │ │
│  │ · codeAction          │  │                              │ │
│  └──────────┬────────────┘  └──────────────┬───────────────┘ │
│             │                              │                 │
│  ┌──────────┴──────────────────────────────┴───────────────┐ │
│  │              Prologos Pipeline                          │ │
│  │                                                         │ │
│  │  reader → preparse → parse → elaborate → type-check     │ │
│  │  → trait-resolve → zonk → reduce                        │ │
│  │                                                         │ │
│  │  ┌────────────────────────────────────────────────────┐ │ │
│  │  │         Propagator Network (LSP State)             │ │ │
│  │  │                                                    │ │ │
│  │  │  Type Index Cells  ←──── Metavariable Cells        │ │ │
│  │  │       ↓                        ↑                   │ │ │
│  │  │  Diagnostic Cells  ←── Elaboration Results         │ │ │
│  │  │       ↓                        ↑                   │ │ │
│  │  │  Completion Cells  ←── Module Export Cells         │ │ │
│  │  │       ↓                        ↑                   │ │ │
│  │  │  Definition Loc Cells ←─ REPL Session Cells        │ │ │
│  │  └────────────────────────────────────────────────────┘ │ │
│  │                                                         │ │
│  │  process-file / process-string-ws / process-command     │ │
│  │  module-registry / global-env / ns-context              │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Why This Model

| Decision | Rationale | Reference System |
|----------|-----------|------------------|
| Single Racket process | Avoids IPC complexity; Racket is fast enough for single-file projects | Idris 2 (single process) |
| LSP over stdio | Standard, universal editor support; no TCP port management | All surveyed systems |
| Custom methods on same connection | Avoid second protocol/connection (Calva's nREPL adds complexity) | Lean 4 (`$/lean/*`) |
| TextMate + tree-sitter WASM | TextMate for instant highlighting; tree-sitter for structural ops | Calva (TextMate) + rust-analyzer (two-layer) |
| React webview for InfoView | Portable, rich rendering, Lean 4 validates the pattern | Lean 4 (lean4-infoview) |
| Standard code actions for DT features | Portable across editors without custom protocol | Idris 2 |

### What We Explicitly Reject

| Rejected Approach | Reason |
|-------------------|--------|
| Custom protocol (like Agda IOTCM) | Maintenance burden of dual-editor protocol; Agda is the cautionary tale |
| Separate nREPL-like process | Adds connection management complexity; Lean 4 proves integrated works |
| DrRacket API wrapping | Our pipeline is independent of DrRacket; wrapping adds indirection |
| On-type diagnostics (initially) | `process-file` is whole-file; partial-file processing is a major investment |

---

## 4. Tier Dependency Graph

```
Tier 1: Syntax & Static
  │  (no server, pure client-side)
  │
  ▼
Tier 2: Diagnostics & Navigation ◄── [Infra: JSON-RPC layer, error mapping]
  │  (LSP server, file-level)
  │
  ▼
Tier 3: Type Intelligence ◄─────── [Infra: Elaboration side table, WS pretty-printer]
  │  (LSP server, expression-level)
  │
  ├──────────────────────┐
  ▼                      ▼
Tier 4: Interactive    Tier 5: InfoView Panel
  Eval                   (can start after Tier 3)
  (REPL backend)         (React webview)
```

**Critical path**: Tier 1 → Tier 2 → Tier 3 → Tier 4/5

**Parallelizable**: Tier 1 can be built entirely independently. The infrastructure
investments (§9) can start during Tier 1 implementation. Tiers 4 and 5 are independent
of each other once Tier 3 is complete.

---

## 5. Tier 1: Syntax & Static

**Goal**: `.prologos` files open in VSCode with correct syntax highlighting, bracket
matching, comment toggling, code folding, and snippets. No server process required.

### 4.1 Components

| Component | File(s) to Create | Effort |
|-----------|-------------------|--------|
| **TextMate grammar** | `syntaxes/prologos.tmLanguage.json` | 2–3 days |
| **Language configuration** | `language-configuration.json` | 2–4 hours |
| **Snippets** | `snippets/prologos.json` | 2–4 hours |
| **Extension manifest** | `package.json` | 4–8 hours |
| **Extension entry point** | `src/extension.ts` (minimal) | 2–4 hours |
| **Tree-sitter WASM build** | `tree-sitter/prologos.wasm` | 4–8 hours |
| **Tree-sitter queries** | `queries/folds.scm`, `queries/indents.scm` | 4–8 hours |

**Total**: ~4–6 days

### 4.2 TextMate Grammar Design

The TextMate grammar translates our tree-sitter `highlights.scm` (83 lines, ~20 rules)
into regex patterns. Key scope mappings:

| Tree-sitter Capture | TextMate Scope | Examples |
|---------------------|----------------|----------|
| `@keyword` | `keyword.control.prologos` | `defn`, `def`, `data`, `match`, `fn`, `ns`, `let`, `if` |
| `@function` | `entity.name.function.prologos` | Names in `defn`, `def` forms |
| `@type.definition` | `entity.name.type.prologos` | Names in `data` forms |
| `@type.builtin` | `support.type.prologos` | `Pi`, `Sigma`, `Type`, `Nat`, `Bool` |
| `@constructor` | `entity.name.tag.prologos` | Constructor names in `data`, patterns |
| `@constant.builtin` | `constant.language.prologos` | `zero`, `true`, `false`, `nil`, `refl` |
| `@variable.parameter` | `variable.parameter.prologos` | fn params |
| `@operator` | `keyword.operator.prologos` | `->`, `\|`, `\|>`, `>>` |
| `@attribute` | `storage.modifier.prologos` | Multiplicity annotations (`:0`, `:1`, `:w`) |
| `@number` | `constant.numeric.prologos` | `3N`, `42`, `3.14` |
| `@string` | `string.quoted.double.prologos` | `"hello"` |
| `@comment` | `comment.line.semicolon.prologos` | `; ...` and `;;; ...` |
| `@namespace` | `entity.name.namespace.prologos` | Qualified names in `ns` |
| `@variable` | `variable.other.prologos` | Fallback identifier |

**WS-mode challenges for TextMate**: Indentation-sensitivity is hard for regex-based
grammars. TextMate patterns match single lines — they can't track indentation state.
Strategy: highlight individual tokens correctly (keywords, literals, types) without
trying to track block structure. Tree-sitter WASM handles structural understanding.

### 4.3 Language Configuration

```json
{
  "comments": { "lineComment": ";" },
  "brackets": [["[", "]"], ["(", ")"], ["{", "}"], ["<", ">"]],
  "autoClosingPairs": [
    { "open": "[", "close": "]" },
    { "open": "(", "close": ")" },
    { "open": "{", "close": "}" },
    { "open": "<", "close": ">" },
    { "open": "\"", "close": "\"" }
  ],
  "surroundingPairs": [
    ["[", "]"], ["(", ")"], ["{", "}"], ["<", ">"], ["\"", "\""]
  ],
  "indentationRules": {
    "increaseIndentPattern": "^\\s*(defn|def|data|match|fn|impl|trait|if|let|do|ns)\\b",
    "decreaseIndentPattern": "^\\s*\\)"
  },
  "wordPattern": "[a-zA-Z_][a-zA-Z0-9_?!-]*"
}
```

### 4.4 Snippets

| Prefix | Expands To | Description |
|--------|-----------|-------------|
| `defn` | `defn ${1:name} [${2:args}]\n  ${0:body}` | Function definition |
| `spec` | `spec ${1:name} ${0:Type}` | Type specification |
| `specdefn` | `spec ${1:name} ${2:Type}\ndefn ${1:name} [${3:args}]\n  ${0:body}` | Spec + defn |
| `data` | `data ${1:Name} : ${2:Type} where\n  \| ${0:Constructor}` | Data type |
| `match` | `(match ${1:expr}\n  [${2:pattern} ${0:body}])` | Pattern match |
| `fn` | `(fn [${1:args}] ${0:body})` | Anonymous function |
| `ns` | `ns ${0:name}` | Namespace declaration |
| `impl` | `impl ${1:Trait} ${2:Type}\n  ${0:methods}` | Trait implementation |
| `let` | `(let ${1:name} := ${2:expr}\n  ${0:body})` | Let binding |
| `if` | `(if ${1:cond}\n  ${2:then}\n  ${0:else})` | Conditional |

### 4.5 Tree-sitter WASM Compilation

```bash
# From editors/tree-sitter-prologos/
tree-sitter build --wasm
# Produces tree-sitter-prologos.wasm

# Or via Emscripten directly:
npx tree-sitter build-wasm .
```

**Needed query files** (currently only `highlights.scm` exists):

**`folds.scm`** — Code folding regions:
```scheme
(defn_form) @fold
(def_form) @fold
(data_form) @fold
(match_expr) @fold
(fn_expr) @fold
(impl_form) @fold
(trait_form) @fold
(ns_declaration) @fold
```

**`indents.scm`** — Indentation hints:
```scheme
(defn_form) @indent
(match_expr) @indent
(fn_expr) @indent
(match_clause) @indent
```

### 4.6 Extension Manifest Structure

```
editors/vscode-prologos/
├── package.json                    # Extension manifest
├── tsconfig.json                   # TypeScript config
├── webpack.config.js               # Bundle config
├── src/
│   └── extension.ts                # Activation, command registration
├── syntaxes/
│   └── prologos.tmLanguage.json    # TextMate grammar
├── snippets/
│   └── prologos.json               # Code snippets
├── tree-sitter/
│   └── prologos.wasm               # Compiled tree-sitter grammar
├── queries/
│   ├── highlights.scm              # (copy from tree-sitter-prologos)
│   ├── folds.scm
│   └── indents.scm
└── language-configuration.json     # Brackets, comments, word pattern
```

### 4.7 Verification

- [ ] `.prologos` file opens with correct highlighting for all token types
- [ ] Bracket matching works for `[]`, `()`, `{}`, `<>`
- [ ] Comment toggling (Cmd+/) inserts `;`
- [ ] Code folding works on `defn`, `data`, `match`, `fn` blocks
- [ ] Snippets expand correctly
- [ ] Tree-sitter structural selection (expand/contract) works

---

## 6. Tier 2: Diagnostics & Navigation

**Goal**: Type errors appear inline on save. Go-to-definition works across files.
Document outline shows top-level definitions. Signature help from `spec` declarations.

### 5.1 Components

| Component | File(s) | Effort |
|-----------|---------|--------|
| **JSON-RPC layer** (Racket) | `racket/prologos/lsp/json-rpc.rkt` | 2–3 days |
| **LSP server main loop** | `racket/prologos/lsp/server.rkt` | 2–3 days |
| **Diagnostic publisher** | `racket/prologos/lsp/diagnostics.rkt` | 1 day |
| **Document symbol provider** | `racket/prologos/lsp/symbols.rkt` | 1 day |
| **Go-to-definition provider** | `racket/prologos/lsp/definition.rkt` | 1–2 days |
| **Signature help provider** | `racket/prologos/lsp/signature.rkt` | 1 day |
| **LSP client setup** (TS) | `src/client.ts` | 1 day |
| **Definition location registry** | Modify `namespace.rkt`, `global-env.rkt` | 1 day |

**Total**: ~10–14 days

### 5.2 JSON-RPC Layer

The LSP protocol uses JSON-RPC 2.0 over stdio with Content-Length headers. We need:

```racket
;; lsp/json-rpc.rkt — ~150-200 lines

;; Read a JSON-RPC message from stdin
;; Parses "Content-Length: N\r\n\r\n" header, reads N bytes, parses JSON
(define (read-message port) ...)

;; Write a JSON-RPC response to stdout
;; Formats as "Content-Length: N\r\n\r\n{json}"
(define (write-message port msg) ...)

;; Dispatch incoming messages to handlers
(define (dispatch-message msg handlers) ...)
```

**Dependencies**: Racket's built-in `json` library (`racket/json` or `json` package).
No external libraries needed.

### 5.3 LSP Server Main Loop

```racket
;; lsp/server.rkt — ~400-500 lines

;; Server state is the propagator network (see §9.0-9.1)
;; Each document gets a sub-network of cells; the server holds the root network.
(struct lsp-state
  (initialized?         ; boolean — has client sent Initialize?
   network              ; propagator network (all LSP cells)
   module-registry      ; shared module registry (prelude pre-cached)
   ) #:mutable)

;; Per-document cells are created in the network when a document is opened.
;; Source cell (content), parse cells, elaboration cells, diagnostic cells,
;; type index cells, def location cells — all wired into the network.

;; Main loop: thin event pump feeding the propagator network
(define (run-lsp-server)
  (define state (make-initial-state))
  ;; Pre-cache prelude modules at startup
  (preload-prelude! state)
  (let loop ()
    (define msg (read-message (current-input-port)))
    (define response (handle-message state msg))
    (when response
      (write-message (current-output-port) response))
    ;; Flush any changed diagnostic cells as publishDiagnostics
    (publish-changed-diagnostics! (lsp-state-network state))
    (loop)))
```

### 5.4 Diagnostic Publisher

Maps `prologos-error` structs to LSP `Diagnostic` objects:

```racket
;; lsp/diagnostics.rkt

;; Convert prologos-error → LSP Diagnostic JSON
(define (error->diagnostic err)
  (define loc (prologos-error-srcloc err))
  (hasheq
   'range (srcloc->range loc)
   'severity 1  ; DiagnosticSeverity.Error
   'source "prologos"
   'message (prologos-error-message err)
   'code (error->code err)  ; E1001, E1002, etc.
   'relatedInformation (error->related-info err)))

;; Convert srcloc → LSP Range
;; LSP uses 0-based lines, 0-based characters
(define (srcloc->range loc)
  (if (or (not loc) (equal? loc srcloc-unknown))
      (hasheq 'start (hasheq 'line 0 'character 0)
              'end   (hasheq 'line 0 'character 0))
      (hasheq 'start (hasheq 'line (sub1 (srcloc-line loc))
                              'character (srcloc-col loc))
              'end   (hasheq 'line (sub1 (srcloc-line loc))
                              'character (+ (srcloc-col loc)
                                            (srcloc-span loc))))))
```

**Error code mapping**:

| Prologos Error Type | LSP Code | Severity |
|---------------------|----------|----------|
| `type-mismatch-error` | `E1001` | Error |
| `unbound-variable-error` | `E1002` | Error |
| `multiplicity-error` | `E1003` | Error |
| `inference-failed-error` | `E1004` | Error |
| `cannot-infer-param-error` | `E1005` | Error |
| `conflicting-constraints-error` | `E1006` | Error |
| `no-instance-error` | `E1007` | Error |
| `parse-error` | `E2001` | Error |
| `arity-error` | `E2002` | Error |
| `session-error` | `E3001` | Error |
| Coercion warning | `W1001` | Warning |
| Deprecation warning | `W1002` | Warning |

**Diagnostic trigger**: `textDocument/didSave` notification. On save, re-run
`process-file` on the document content and publish diagnostics.

### 5.5 Go-to-Definition

**Current state**: `module-info` has `env-snapshot` (name → type+value) and `file-path`,
but NOT the source position of each definition within the file.

**Gap to fill** (Infrastructure Investment §9.2): Add a `definition-locations` field to
`module-info` mapping `fqn-symbol → srcloc`. Populated during `process-command` for `def`
and `defn` forms.

**Implementation**:
1. When `process-command` encounters a `surf-def`, record `(name → (srcloc of the def form))` in a per-file definition location table
2. Store this table in `module-info` when the module is registered
3. On `textDocument/definition` request, resolve the name via `ns-context`, look up the FQN in the module registry, return the file path + position

**Files modified**:
- `namespace.rkt`: Add `definition-locations` field to `module-info` struct (~10 lines)
- `driver.rkt`: Record definition locations during `process-def` (~15 lines)
- `global-env.rkt`: Add `current-definition-locations` parameter (~10 lines)

### 5.6 Document Symbols

Parse the file's surface AST to extract top-level symbols:

| Surface Form | Symbol Kind | Name Source |
|-------------|-------------|-------------|
| `surf-def` (with type) | `Function` | `surf-def-name` |
| `surf-def` (no type, data) | `Class` | `surf-def-name` |
| `surf-def-group` | `Function` | group name |
| `data` constructor | `Constructor` | constructor name |
| `ns` | `Namespace` | namespace name |
| `spec` | `Interface` | spec name |

### 5.7 Signature Help

When the cursor is inside a function application `[f ...]`, look up `f`'s `spec`
declaration (if any) and display the parameter names and types.

**Current state**: `spec` declarations are stored as type annotations in the global-env.
The `current-defn-param-names` parameter maps function names to their user-facing parameter
names. Together, these provide what we need.

**Implementation**: On `textDocument/signatureHelp`, find the enclosing application form,
resolve the function name, look up its type in the global-env, and format using `pp-expr`.

### 5.8 TypeScript Client Setup

```typescript
// src/client.ts — ~100 lines
import { LanguageClient, LanguageClientOptions, ServerOptions }
  from 'vscode-languageclient/node';

export function createClient(context: vscode.ExtensionContext): LanguageClient {
  const serverOptions: ServerOptions = {
    command: '/Applications/Racket v9.0/bin/racket',
    args: [getLspServerPath()],
    options: { env: { ...process.env } }
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'prologos' }],
    synchronize: {
      fileEvents: vscode.workspace.createFileSystemWatcher('**/*.prologos')
    }
  };

  return new LanguageClient('prologos', 'Prologos', serverOptions, clientOptions);
}
```

### 5.9 Verification

- [ ] Type errors appear inline on save (red squiggly, hover shows message)
- [ ] Error codes (E1001, etc.) appear in diagnostics
- [ ] Go-to-definition on an imported name jumps to the definition file
- [ ] Go-to-definition on a local name jumps to the `def`/`defn` form
- [ ] Document outline shows all top-level `defn`, `def`, `data`, `spec` forms
- [ ] Signature help triggers on `[function-name ` and shows parameter types
- [ ] Diagnostics clear when errors are fixed and file is re-saved

---

## 7. Tier 3: Type Intelligence

**Goal**: Hover shows inferred types. Inlay hints display types on untyped bindings.
Semantic tokens provide rich highlighting (logic vars, multiplicities, traits).
Completion offers module exports and prelude names with type signatures.

### 6.1 Components

| Component | File(s) | Effort |
|-----------|---------|--------|
| **Elaboration side table** | Modify `elaborator.rkt`, new `lsp/type-index.rkt` | 3–5 days |
| **WS-mode pretty-printer** | New `ws-pretty-print.rkt` or extend `pretty-print.rkt` | 2–3 days |
| **Hover provider** | `lsp/hover.rkt` | 1 day |
| **Completion provider** | `lsp/completion.rkt` | 2–3 days |
| **Semantic token provider** | `lsp/semantic-tokens.rkt` | 2–3 days |
| **Inlay hint provider** | `lsp/inlay-hints.rkt` | 1–2 days |

**Total**: ~12–18 days

### 6.2 Elaboration Side Table (Key Infrastructure)

This is the largest single infrastructure investment. During elaboration, we build a
mapping from source positions to type information.

**Design**:

The type index is a propagator-backed structure (see §9.1–9.2). Each source position
with type information gets a propagator cell containing a `type-index-entry`:

```racket
;; lsp/lsp-cells.rkt

(struct type-index-entry
  (srcloc           ; source location of the expression
   type             ; inferred type (core expr) — may contain metas initially
   names            ; name stack at this point (for pp-expr)
   kind             ; 'variable | 'application | 'binding | 'type-annotation | 'pattern
   name             ; symbol or #f — the name if this is a named binding
   ) #:transparent)
```

**Why propagator cells here**: Type entries often contain unsolved metavariables at
creation time. When a meta is solved later (trait resolution, unification), the type
index cell automatically reflects the solution via the existing meta → dependent
propagation path. No explicit "zonk the index" pass needed. This is correct by
construction — the cell's value is always consistent with the current meta solutions.

**Recording entries during elaboration**:

```racket
;; Called from elaborator.rkt at each instrumentation point
(define (record-type-at-position! srcloc type names kind [name #f])
  (when (current-lsp-network)
    (define cell (get-or-create-type-index-cell!
                   (current-lsp-network) srcloc))
    (cell-add-content! cell (type-index-entry srcloc type names kind name))))
```

**Instrumentation points in `elaborator.rkt`** (3924 lines):

The elaborator's `elaborate` function dispatches on surface AST type. We instrument
each case to record the inferred type:

| Surface Form | What to Record | Location in elaborator.rkt |
|-------------|----------------|---------------------------|
| `surf-var` | Variable's type from context/global-env | `elaborate` → `surf-var?` case |
| `surf-app` | Result type of application | `elaborate` → `surf-app?` case |
| `surf-ann` | The annotated type | `elaborate` → `surf-ann?` case |
| `surf-lambda` | Each parameter's inferred type | `elaborate` → `surf-lambda?` case |
| `surf-def` | Defined name's type | `process-def` in driver.rkt |
| `surf-match` | Scrutinee type, branch types | `elaborate` → `surf-match?` case |

**Estimated changes**: ~30-50 `record-type-at-position!` calls inserted across
`elaborator.rkt` and `driver.rkt`. Each call is 1–3 lines. The elaborator already has
access to both the surface form (with srcloc) and the inferred type.

**Performance impact**: Cell content additions are O(1). For a typical file with ~100
expressions, this adds ~100 cell writes — negligible. The propagation overhead (meta
solutions updating type index cells) is proportional to the number of affected cells,
which is small in practice.

### 6.3 WS-Mode Pretty-Printer

The current `pp-expr` (1474 lines) produces S-expression output:
```
(Pi ((x :1 Nat)) Nat)
```

For VSCode hover, we want WS-mode surface syntax:
```
<(x : Nat) -> Nat>
```

**Approach**: Add a `pp-expr-ws` function (or a mode flag to `pp-expr`) that uses
WS-mode conventions:

| Core Form | Current (sexp) | Target (WS) |
|-----------|---------------|-------------|
| `expr-pi` (named) | `(Pi ((x :1 Nat)) Bool)` | `<(x : Nat) -> Bool>` |
| `expr-pi` (unnamed) | `(Pi ((_ :1 Nat)) Bool)` | `Nat -> Bool` |
| `expr-sigma` | `(Sigma ((x :1 Nat)) (Vec x))` | `<(x : Nat) * Vec x>` |
| `expr-app` | `(Vec Nat 3)` | `[Vec Nat 3N]` |
| `expr-lam` | `(lambda ((x :1)) x)` | `(fn [x] x)` |
| Multiplicity | `:0`, `:1`, `:w` | `:0`, `:1`, `:w` (same) |
| Universe | `(Type lzero)` | `Type` |

**File**: Extend `pretty-print.rkt` with `pp-expr-ws` (~200–300 lines, reusing most
of `pp-expr`'s pattern matching).

### 6.4 Hover Provider

```racket
;; On textDocument/hover:
;; 1. Find the document state for the URI
;; 2. Look up the type index at the requested position
;; 3. Format the type using pp-expr-ws
;; 4. Return Markdown-formatted hover content

(define (handle-hover state params)
  (define uri (hash-ref (hash-ref params 'textDocument) 'uri))
  (define pos (hash-ref params 'position))
  (define line (add1 (hash-ref pos 'line)))  ; LSP is 0-based, we're 1-based
  (define col (hash-ref pos 'character))
  (define doc (hash-ref (lsp-state-documents state) uri #f))
  (define entry (and doc (lookup-type-at-position
                           (document-state-type-index doc) line col)))
  (and entry
       (hasheq 'contents
               (hasheq 'kind "markdown"
                       'value (format "```prologos\n~a : ~a\n```"
                                      (or (type-index-entry-name entry) "_")
                                      (pp-expr-ws (type-index-entry-type entry)
                                                  (type-index-entry-names entry)))))))
```

### 6.5 Completion Provider

**Completion sources** (in priority order):
1. **Local bindings** — Variables in scope at cursor position
2. **File-level definitions** — `def`/`defn` from current file
3. **Imported names** — From `ns` imports (`:refer` names)
4. **Prelude names** — Auto-imported prelude (~200+ names)
5. **Module-qualified names** — After typing `module::` prefix

Each completion item includes:
- `label` — The name
- `detail` — The type signature (from global-env)
- `kind` — Function, Variable, Class, etc.
- `documentation` — The `spec` declaration if available

**Implementation**: On `textDocument/completion`, gather names from the document's
`global-env` and `ns-context`, format types, return as `CompletionItem[]`.

### 6.6 Semantic Tokens

**Token types** (Prologos-specific classification):

| Token Type ID | Name | Applies To |
|---------------|------|-----------|
| 0 | `namespace` | Module names in `ns`, `require` |
| 1 | `type` | Type names (from elaboration) |
| 2 | `class` | Trait names |
| 3 | `function` | Function names in definitions and applications |
| 4 | `variable` | Regular variables |
| 5 | `parameter` | Function parameters |
| 6 | `property` | Record/struct field accessors |
| 7 | `enumMember` | Data constructors |
| 8 | `keyword` | Language keywords |
| 9 | `number` | Numeric literals |
| 10 | `string` | String literals |
| 11 | `comment` | Comments |

**Token modifiers** (Prologos-specific):

| Modifier Bit | Name | Meaning |
|--------------|------|---------|
| 0 | `declaration` | Definition site |
| 1 | `definition` | Definition (defn/def) |
| 2 | `readonly` | Erased (`:0` multiplicity) |
| 3 | `static` | Unrestricted (`:w` multiplicity) |
| 4 | `deprecated` | Deprecated name |
| 5 | `modification` | Logic variable (`?x`) |

The `modification` bit for logic variables provides distinct coloring for `?x`, `?y`
in narrowing queries — visually distinguishing them from regular variables.

### 6.7 Inlay Hints

Display inferred types on bindings that lack explicit type annotations:

```prologos
defn add [x y]        -- inlay: ": Nat -> Nat -> Nat" after "add"
  [Nat::add x y]

def result := [add 3N 4N]  -- inlay: ": Nat" after "result"
```

**Implementation**: After elaboration, walk the type index entries with `kind = 'binding`
and emit inlay hints for each untyped binding.

### 6.8 Verification

- [ ] Hover on a variable shows its inferred type in WS-mode syntax
- [ ] Hover on a function application shows the result type
- [ ] Hover on a `defn` name shows its full type signature
- [ ] Inlay hints appear on untyped `def` and `defn` bindings
- [ ] Completion offers prelude names with type signatures
- [ ] Completion offers imported module names
- [ ] Semantic tokens color logic variables differently from regular variables
- [ ] Semantic tokens distinguish type names from function names

---

## 8. Tier 4: Interactive Evaluation

**Goal**: Evaluate any form inline (Calva/CIDER-style), see results next to code.
Run narrowing queries from the editor. Persistent namespace context across evaluations.

### 7.1 Components

| Component | File(s) | Effort |
|-----------|---------|--------|
| **REPL backend** (Racket) | `lsp/repl.rkt` | 3–4 days |
| **Custom LSP methods** | Extend `lsp/server.rkt` | 2–3 days |
| **Form identification** (TS) | `src/forms.ts` (tree-sitter) | 2–3 days |
| **Inline decorations** (TS) | `src/decorations.ts` | 2–3 days |
| **REPL commands** (TS) | `src/repl.ts` | 1–2 days |
| **Status bar integration** (TS) | `src/statusbar.ts` | 0.5 days |

**Total**: ~12–16 days

### 7.2 REPL Backend

The REPL backend maintains a persistent evaluation context per workspace, backed by
a REPL session cell in the propagator network (see §9.1):

```racket
;; lsp/repl.rkt

;; The REPL session is a propagator cell whose content is the accumulated
;; global-env. Definitions only grow (monotonic), so this is a natural
;; lattice: ⊥ → {name₁ → type₁} → {name₁ → type₁, name₂ → type₂} → ...
;;
;; New definitions from eval propagate into type index cells and completion
;; cells automatically via the network — no explicit cache invalidation.

;; Evaluate a single form in the session context
(define (repl-eval network uri code)
  (define session-cell (get-repl-session-cell network uri))
  (parameterize ([current-global-env (cell-content session-cell)]
                 [current-ns-context (cell-content (get-ns-context-cell network uri))]
                 [current-module-registry (lsp-network-module-registry network)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-lsp-network network])  ;; enables type index recording
    (define results (process-string-ws code))
    ;; Update session cell — propagates to completion/type index cells
    (cell-add-content! session-cell (current-global-env))
    results))

;; Load a file into the session (like CIDER's load-file)
(define (repl-load-file network uri path)
  (define session-cell (get-repl-session-cell network uri))
  (parameterize ([current-global-env (cell-content session-cell)]
                 [current-ns-context (cell-content (get-ns-context-cell network uri))]
                 [current-module-registry (lsp-network-module-registry network)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-lsp-network network])
    (define results (process-file path))
    (cell-add-content! session-cell (current-global-env))
    results))
```

### 7.3 Custom LSP Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `$/prologos/eval` | `{code: string, uri: string, position: Position}` | `{result: string, type: string, error?: string}` | Evaluate a form |
| `$/prologos/loadFile` | `{uri: string}` | `{results: Result[], errors: Diagnostic[]}` | Load file into REPL |
| `$/prologos/narrowing` | `{expr: string, uri: string}` | `{solutions: Solution[]}` | Run narrowing query |
| `$/prologos/typeOf` | `{expr: string, uri: string}` | `{type: string}` | Infer type of expression |
| `$/prologos/elaborated` | `{expr: string, uri: string}` | `{sexp: string}` | Show elaborated IR |
| `$/prologos/resetSession` | `{uri: string}` | `{}` | Reset REPL session |

### 7.4 Form Identification (Client-Side)

The VSCode extension uses tree-sitter WASM to identify forms at the cursor:

```typescript
// src/forms.ts
import Parser from 'web-tree-sitter';

export function getTopLevelFormAtCursor(
  tree: Parser.Tree,
  position: vscode.Position
): { text: string; range: vscode.Range } | null {
  // Walk tree to find the top-level form (child of root) containing position
  const root = tree.rootNode;
  for (const child of root.children) {
    if (child.startPosition.row <= position.line &&
        child.endPosition.row >= position.line) {
      return {
        text: child.text,
        range: new vscode.Range(
          child.startPosition.row, child.startPosition.column,
          child.endPosition.row, child.endPosition.column
        )
      };
    }
  }
  return null;
}

export function getInnermostFormAtCursor(
  tree: Parser.Tree,
  position: vscode.Position
): { text: string; range: vscode.Range } | null {
  // Walk tree to find the smallest form containing cursor
  // Used for "evaluate expression at cursor"
  ...
}
```

### 7.5 Inline Decorations

```typescript
// src/decorations.ts
const resultDecorationType = vscode.window.createTextEditorDecorationType({
  after: {
    margin: '0 0 0 1em',
    color: new vscode.ThemeColor('editorCodeLens.foreground'),
    fontStyle: 'italic'
  }
});

export function showInlineResult(
  editor: vscode.TextEditor,
  range: vscode.Range,
  result: string,
  type: string
) {
  const decoration: vscode.DecorationOptions = {
    range: new vscode.Range(range.end.line, range.end.character,
                            range.end.line, range.end.character),
    renderOptions: {
      after: {
        contentText: `=> ${result} : ${type}`,
      }
    }
  };
  editor.setDecorations(resultDecorationType, [decoration]);
}
```

### 7.6 Commands and Keybindings

| Command | Keybinding | Description |
|---------|-----------|-------------|
| `prologos.evalTopLevel` | `Ctrl+Enter` | Evaluate top-level form at cursor |
| `prologos.evalExpression` | `Ctrl+Shift+Enter` | Evaluate innermost expression |
| `prologos.evalFile` | `Ctrl+Alt+Enter` | Load entire file into REPL |
| `prologos.clearResults` | `Ctrl+Shift+Backspace` | Clear all inline results |
| `prologos.typeOf` | `Ctrl+T` | Show type of expression |
| `prologos.showElaborated` | `Ctrl+Shift+E` | Show elaborated form |
| `prologos.narrow` | `Ctrl+Shift+N` | Run narrowing query |
| `prologos.resetSession` | `Ctrl+Alt+R` | Reset REPL session |

### 7.7 Session Lifecycle

1. **First eval**: Creates a REPL session, loads the file's `ns` declaration + prelude
2. **Subsequent evals**: Use the existing session's accumulated `global-env`
3. **File save**: Re-runs diagnostics (Tier 2) but does NOT reset the session
4. **Manual reset**: `prologos.resetSession` starts fresh
5. **File switch**: Each file has its own session, keyed by `ns` declaration

### 7.8 Verification

- [ ] `Ctrl+Enter` evaluates the top-level form and shows result inline
- [ ] Results persist until cleared or until the form is modified
- [ ] Evaluating a `defn` adds it to the session; subsequent evals can call it
- [ ] `ns` declaration loads the prelude; imported names are available
- [ ] Narrowing query shows solutions inline (e.g., `=> {?x: 2N, ?y: 3N}`)
- [ ] Error results show inline with red coloring
- [ ] Status bar shows REPL connection state

---

## 9. Tier 5: InfoView Panel

**Goal**: A continuously-updated panel (like Lean 4's InfoView) showing type context,
narrowing state, goal information, and interactive widgets.

### 8.1 Components

| Component | File(s) | Effort |
|-----------|---------|--------|
| **InfoView React app** | `src/infoview/` (React + TypeScript) | 5–7 days |
| **Cursor tracking** (TS) | `src/infoview/cursor.ts` | 1–2 days |
| **Type context display** | `src/infoview/TypeContext.tsx` | 2–3 days |
| **Narrowing explorer** | `src/infoview/NarrowingView.tsx` | 2–3 days |
| **Webview provider** (TS) | `src/infoview/provider.ts` | 1–2 days |
| **Server-side context query** | `lsp/context.rkt` | 2–3 days |
| **Custom notifications** | Extend `lsp/server.rkt` | 1 day |

**Total**: ~15–22 days

### 8.2 InfoView Panels

| Panel Section | Content | Update Trigger |
|---------------|---------|----------------|
| **Type at Cursor** | Inferred type of the expression under the cursor | Cursor movement |
| **Local Context** | All bindings in scope with their types | Cursor movement |
| **Trait Instances** | Available trait instances for the types in scope | Cursor movement |
| **Narrowing Results** | Solutions from the most recent narrowing query | After eval |
| **Elaborated Form** | The desugared core AST for the current form | Cursor movement |
| **Reduction Steps** | Step-by-step reduction of the evaluated form | After eval |

### 8.3 Communication Protocol

```
Extension ──── postMessage() ────► InfoView (React)
         ◄─── postMessage() ────
         │
         ├─── LSP request ──────► Racket Server
         ◄─── LSP response ─────
```

Custom notifications for cursor-reactive updates:
- `$/prologos/cursorContext` — Send current position, receive type context
- `$/prologos/goalState` — If inside a `?`-hole, show expected type

### 8.4 Verification

- [ ] InfoView panel opens alongside the editor
- [ ] Moving the cursor updates the type display in real time
- [ ] Local context shows all bindings in scope with correct types
- [ ] Narrowing results appear in the panel after a narrowing query
- [ ] Elaborated form shows the desugared IR

---

## 10. Infrastructure Investments (Cross-Tier)

These are foundational changes to the Prologos codebase that support multiple tiers.
They follow the **Propagator-First Infrastructure** principle (see `DESIGN_PRINCIPLES.org`):
all LSP state is built on propagator cells, not mutable hash tables. This is a
**correct-by-construction** approach — derived state is always consistent because the
network topology enforces it, eliminating the need for hand-written invalidation code.

### 9.0 Design Philosophy: Why Propagator-First

The naïve approach to LSP infrastructure is mutable hash tables with manual invalidation:
build a type index as a `(make-hash)`, insert entries during elaboration, zonk all entries
when metas are solved, rebuild when the file changes, diff the old diagnostics against the
new ones, etc. Each cross-cutting concern requires explicit plumbing.

The propagator-first approach replaces mutable stores with propagator cells connected by
dependency edges. The infrastructure becomes a reactive network:

```
Content Change ──► Parse Cells ──► Elaboration Cells ──► Type Index Cells
                                          │                     │
                                          ▼                     ▼
                                   Meta Cells ──────────► Diagnostic Cells
                                          │                     │
                                          ▼                     ▼
                                   Module Export Cells ──► Completion Cells
                                          │
                                          ▼
                                   Def Location Cells
```

**Key properties:**
- **Incremental**: Changing one form re-elaborates only that cell; downstream cells
  (diagnostics, types, completions) update automatically via propagation
- **Consistent**: No "stale cache" bugs — cells always reflect their inputs
- **Composable**: Adding a new LSP feature (e.g., inlay hints) means adding cells that
  read from existing cells — no modification of existing infrastructure
- **Non-monotonic via ATMS**: File edits that remove definitions are handled by retracting
  ATMS assumptions, which causes dependent cells to fall back — the pocket-universe
  pattern already validated in the constraint propagation system

**Relationship to existing infrastructure**: The Prologos codebase already has
battle-tested propagator cells (`propagator.rkt`), lattice traits, ATMS (`atms.rkt`),
and metavariable cells that propagate solutions through the type checker. The LSP
network is a new application of the same abstractions, not a new framework.

### 9.1 LSP Propagator Network

**Supports**: All tiers (foundational)

This is the core infrastructure: a propagator network that represents the entire LSP
server state as a reactive graph of cells.

**Cell taxonomy:**

| Cell Type | Content | Lattice | Inputs |
|-----------|---------|---------|--------|
| **Source cell** | Document text (per URI) | String (replace) | `textDocument/didChange` |
| **Parse cell** | Surface AST (`surf-*` forms) | List of forms | Source cell |
| **Elaboration cell** | Per-form: core AST + type + errors | `⊥ → (ast, type, errors)` | Parse cell, meta cells |
| **Meta cell** | Metavariable solution | `unsolved → solved(expr)` | Elaboration cells, trait resolution |
| **Type index cell** | Per-position: `srcloc → type` | `⊥ → type-index-entry` | Elaboration cells, meta cells |
| **Diagnostic cell** | Per-form: error list | `[] → [diag ...]` | Elaboration cells |
| **Def location cell** | Per-name: definition srcloc | `⊥ → srcloc` | Elaboration cells |
| **Module export cell** | Per-module: export list + types | `⊥ → module-info` | Module loading |
| **Completion cell** | Per-namespace: available names | Set of completion items | Module export cells, def location cells |
| **REPL session cell** | Accumulated global-env | Monotonic map growth | Eval results |

**ATMS integration**: Each elaboration cell is backed by an ATMS assumption corresponding
to the top-level form it represents. When a form changes:
1. Retract the old assumption (pocket-universe pattern)
2. Create a new assumption for the re-elaborated form
3. Dependent cells (type index, diagnostics) automatically update via the ATMS

**Files created**:
| File | Est. Lines | Purpose |
|------|-----------|---------|
| `lsp/lsp-network.rkt` | ~300 | LSP propagator network topology, cell creation, wiring |
| `lsp/lsp-cells.rkt` | ~200 | Cell types, lattice definitions, merge functions |

**Files modified**:
| File | Lines | Change |
|------|-------|--------|
| `elaborator.rkt` | 3924 | ~50 `record-type-at-position!` calls that write to type index cells |
| `driver.rkt` | 1968 | Initialize network per document; connect to process-command pipeline |

**Effort**: 4–6 days

### 9.2 Type Index (Propagator-Backed)

**Supports**: Tier 3 (hover), Tier 3 (inlay hints), Tier 5 (InfoView)

The type index is a collection of propagator cells, one per source position that has
type information. Each cell's content is a `type-index-entry`:

```racket
(struct type-index-entry
  (srcloc           ; source location
   type             ; inferred type (core expr) — may contain metas initially
   names            ; name stack for pp-expr
   kind             ; 'variable | 'application | 'binding | 'pattern
   name             ; symbol or #f
   ) #:transparent)
```

**Why propagator cells, not a hash table**: Type index entries often contain unsolved
metavariables at creation time. When the meta is later solved (e.g., during trait
resolution), the type index entry needs to reflect the solution. With propagator cells:
the meta cell's solution propagates into the type index cell automatically via the
existing meta → dependent propagation path. With a hash table: you'd need an explicit
"zonk the entire index" pass after trait resolution, and again after each meta solution.

**Instrumentation points in `elaborator.rkt`**: Same as the original design (§6.2) —
~50 calls inserted at `surf-var`, `surf-app`, `surf-ann`, `surf-lambda`, `surf-def`,
`surf-match` cases. The difference is that each call writes to a propagator cell rather
than a mutable hash entry.

**Query interface**: `lookup-type-at-position` reads cells and returns the innermost
entry containing the queried position. Reading a cell is O(1).

**Effort**: Included in §9.1 (part of the network)

### 9.3 Definition Location Registry (Propagator-Backed)

**Supports**: Tier 2 (go-to-definition), Tier 3 (completion with location)

Each definition gets a propagator cell mapping `name → srcloc`. When a module is loaded,
its definition location cells are populated. When a file is re-elaborated, only the
changed definitions' cells update.

**Files modified**:
| File | Lines | Change |
|------|-------|--------|
| `namespace.rkt` | 652 | Add `definition-locations` to `module-info` (cell-backed) |
| `global-env.rkt` | 81 | Add `current-definition-locations` parameter |
| `driver.rkt` | 1968 | Record def locations during `process-def`/`process-def-group` |

**Effort**: 1–2 days

### 9.4 Diagnostic Cells (Propagator-Backed)

**Supports**: Tier 2 (publishDiagnostics)

Each top-level form has a diagnostic cell. The cell's content is the list of
`prologos-error` values produced by elaborating/type-checking that form.

**Key benefit**: When re-elaborating a single form, only that form's diagnostic cell
changes. The LSP diagnostic publisher watches all diagnostic cells and sends
`publishDiagnostics` only for URIs whose diagnostic cells have changed. This is the
natural path from on-save to on-type diagnostics — the network topology handles the
incrementality, not explicit diffing.

**Effort**: Included in §9.1 (part of the network)

### 9.5 WS-Mode Pretty-Printer

**Supports**: Tier 3 (hover display), Tier 4 (inline results), Tier 5 (InfoView)

**Files modified**:
| File | Lines | Change |
|------|-------|--------|
| `pretty-print.rkt` | 1474 | Add `pp-expr-ws` function (~300 lines) |

**Effort**: 2–3 days

### 9.6 JSON-RPC Layer

**Supports**: Tier 2+

**Files created**:
| File | Est. Lines | Purpose |
|------|-----------|---------|
| `lsp/json-rpc.rkt` | ~200 | JSON-RPC 2.0 message parsing, serialization, dispatch |

**Effort**: 2–3 days

### 9.7 LSP Server Skeleton

**Supports**: Tier 2+

The server main loop becomes a thin event pump feeding the propagator network. Incoming
LSP messages (didOpen, didChange, didSave) update source cells. Outgoing LSP responses
(hover, completion, diagnostics) read from output cells. The network does the work.

```racket
;; Simplified server loop — the network is the engine
(define (run-lsp-server network)
  (let loop ()
    (define msg (read-message (current-input-port)))
    (cond
      [(did-change? msg)
       ;; Feed source cell → network propagates to all dependent cells
       (update-source-cell! network (msg-uri msg) (msg-content msg))]
      [(hover-request? msg)
       ;; Read from type index cells — always current
       (write-response (read-type-at-position network (msg-uri msg) (msg-position msg)))]
      [(completion-request? msg)
       ;; Read from completion cells — always current
       (write-response (read-completions network (msg-uri msg) (msg-position msg)))]
      ...)
    ;; Flush any changed diagnostic cells as publishDiagnostics
    (publish-changed-diagnostics! network)
    (loop)))
```

**Files created**:
| File | Est. Lines | Purpose |
|------|-----------|---------|
| `lsp/server.rkt` | ~500 | Main loop, event pump, response dispatch |
| `lsp/protocol.rkt` | ~200 | LSP protocol constants, message builders |

**Effort**: 2–3 days

### 9.8 Reduction Cache Cells (Deferred — Requires Benchmarking)

**Supports**: Tier 2 (incremental re-elaboration), Tier 3 (type-correct hover after edits)

**Status**: Deferred from Propagator-First Migration Phase 3e. Captured here as an
LSP-specific infrastructure investment because **batch mode does not need this** — in
batch compilation, reduction caches (`current-whnf-cache`, `current-nf-cache`,
`current-nat-value-cache`) are populated during a single run and discarded afterward.
There is no invalidation problem because there is no incremental re-use.

The question of "which cached reductions depend on definition X?" only arises when a
user edits definition X in their editor and the LSP needs to selectively re-elaborate
dependents without rebuilding everything from scratch. Without cache invalidation, the
LSP must either (a) clear all reduction caches on any edit (correct but potentially
slow) or (b) risk stale cached reductions feeding incorrect type-checking results
(fast but unsound).

**Design question — two approaches:**

| Approach | Description | Pros | Cons |
|----------|-------------|------|------|
| **Fine-grained** | Per-reduction-entry cells with dependency tracking. Each `whnf` call records which definitions it unfolded; changing a definition invalidates only the entries that used it. | Precise invalidation, minimal re-work | High overhead per reduction call. Reduction is the hottest code path (~millions of calls per file). Even a single `hash-set` per call could measurably regress batch performance. |
| **Coarse-grained** | Bulk invalidation of all caches when any definition in the dependency set (Phase 3b) changes. | Near-zero batch overhead (no per-call tracking). Simple implementation. | Over-invalidates — changing `foo` clears caches for `bar` even if `bar` never reduced through `foo`. Acceptable if re-reduction is fast relative to re-elaboration. |

**Recommendation**: Start with coarse-grained. The dependency graph from Phase 3b
already tells us which definitions depend on the edited definition. When re-elaborating
those dependents, simply start with empty reduction caches. This gives correct
incremental behavior with zero batch-mode overhead. Fine-grained tracking is a
potential optimization if profiling shows re-reduction dominates LSP response latency.

**Batch-mode safety gate**: Any implementation MUST be gated behind a
`current-track-reduction-deps?` parameter (default `#f`). Batch compilation never
sets this parameter, so the reduction hot path sees zero additional overhead — not
even a parameter check in the inner loop. The LSP server sets it to `#t` only when
fine-grained tracking is active.

**Benchmarking requirements** (before implementing fine-grained approach):

1. **Baseline**: Measure batch-mode wall time with `--all` tests. Current: ~190s.
2. **Per-call overhead**: Instrument `whnf` with a no-op `hash-set` on every call.
   Measure delta. If >5% regression, fine-grained is ruled out without optimization.
3. **Cache hit rate**: Measure whnf/nf cache hit rates during typical elaboration.
   If hit rates are low (<30%), caches provide little value and coarse invalidation
   is free.
4. **Re-reduction cost**: Measure time spent in reduction during elaboration of a
   single definition. If <10ms, coarse invalidation is negligible even for
   large files.
5. **Regression gate**: No approach ships unless full test suite stays within 5%
   of baseline wall time.

**Dependencies**: Phase 3a (per-definition cells), Phase 3b (dependency recording)

**Effort**: 2–4 days (coarse-grained); 5–8 days (fine-grained with benchmarking)

---

## 11. Tradeoff Matrices

### 10.1 Diagnostics: On Save vs. On Type

| Criterion | On Save | On Type |
|-----------|---------|---------|
| **Implementation complexity** | Low — single `process-file` call | High — debouncing, partial-file handling, error recovery |
| **User experience** | Good — errors appear after explicit action | Better — errors appear as you type |
| **Correctness** | Always correct (complete file) | May show spurious errors on incomplete edits |
| **Performance** | No wasted work | Repeated processing on every keystroke (debounced) |
| **Infrastructure needed** | `process-file` (exists) | Partial-file processing, error recovery (NEW) |

**Recommendation**: **On Save initially, with on-type as a natural evolution**. The
propagator-first architecture (§9.0) significantly reduces the incremental cost of
on-type diagnostics: diagnostic cells per form already support incremental updates,
so the path from on-save to on-type is adding debounced content-change events and
per-form re-elaboration — not a full rewrite. The remaining cost is error recovery
(the current pipeline aborts on the first error in a form), which is orthogonal to
the propagator design but still needed for a good on-type experience.

### 10.2 State Management: Mutable Hash Tables vs. Propagator Network

| Criterion | Mutable Hash Tables | Propagator Network |
|-----------|--------------------|--------------------|
| **Initial implementation** | Simpler (~20 lines per store) | More structure (~80-100 lines per cell type) |
| **Incremental updates** | Manual invalidation + rebuild | Automatic via dependency propagation |
| **Meta solution propagation** | Explicit "zonk the index" pass | Automatic — metas propagate to dependents |
| **Cross-feature consistency** | Manual plumbing between stores | Structural — network topology enforces it |
| **Path to on-type diagnostics** | Requires rewrite of state management | Natural evolution — add debounced source cell updates |
| **Composability** | Each new feature adds invalidation code | Each new feature adds cells that read existing cells |
| **Correctness guarantee** | By discipline (test that invalidation is complete) | By construction (network is always consistent) |
| **Existing infrastructure** | None needed | Propagator cells, lattice traits, ATMS already exist |

**Decision**: **Propagator network**. The upfront cost is modestly higher, but correctness
is structural rather than maintained by discipline. Every subsequent tier benefits from
the network without adding invalidation complexity. This follows the Correct by
Construction principle (`DESIGN_PRINCIPLES.org`): the architecture makes the wrong thing
hard to express, rather than relying on vigilance to avoid it.

### 10.3 Process Model: Single vs. Dual

| Criterion | Single Process | Dual Process |
|-----------|---------------|--------------|
| **Simplicity** | One process, shared state | Two processes, IPC needed |
| **Latency isolation** | Long eval blocks LSP responses | LSP stays responsive during eval |
| **Memory** | One module registry, one prelude load | Duplicated state or shared-memory IPC |
| **Implementation** | Standard | Needs inter-process coordination |
| **Failure isolation** | Crash kills both | One can restart independently |

**Recommendation**: **Single process for initial implementation**. Prologos files are
small (< 1000 lines); `process-file` completes in < 1s typically. If latency becomes an
issue (e.g., for very large files or long-running narrowing queries), split the eval
backend into a second process. The architecture (custom LSP methods) makes this split
straightforward later — just route `$/prologos/*` methods to the second process.

### 10.3 Highlighting: TextMate vs. Semantic Tokens vs. Both

| Criterion | TextMate Only | Semantic Tokens Only | Both |
|-----------|--------------|---------------------|------|
| **No-server experience** | Full highlighting | No highlighting without server | Full highlighting + enrichment |
| **Correctness** | Regex-based (approximate) | Elaboration-based (exact) | Best of both |
| **Implementation** | Grammar file only | Server-side token provider | Both needed |
| **Startup time** | Instant | Delayed until server initializes | Instant base + delayed enrichment |

**Recommendation**: **Both**. TextMate for instant baseline highlighting (Tier 1).
Semantic tokens for elaboration-aware enrichment (Tier 3). This is the rust-analyzer
pattern and provides the best user experience — files highlight immediately, then get
richer coloring once the server initializes.

### 10.4 Interactive Features: Code Actions vs. Custom Methods

| Criterion | LSP Code Actions | Custom `$/prologos/*` Methods |
|-----------|-----------------|-------------------------------|
| **Editor portability** | Works in any LSP-capable editor | Only works with custom client code |
| **Feature richness** | Limited to action/edit model | Arbitrary request/response |
| **Discoverability** | Appears in lightbulb menu | Requires custom keybindings |
| **Streaming results** | No (single response) | Yes (via notifications) |

**Recommendation**: **Hybrid**. Use **code actions** for features that fit the
action/edit model (type annotations, case split, import suggestions). Use **custom
methods** for features that need richer interaction (eval, narrowing, InfoView data).
This maximizes portability while enabling the interactive experience.

---

## 12. Principle Alignment Check

Per DESIGN_METHODOLOGY.org §Stage 2, each recommendation must align with core principles.

### Homoiconicity

✅ **Aligned**. The `$/prologos/elaborated` method exposes the desugared IR, reinforcing
code-as-data. The InfoView panel can show both WS-mode and sexp representations.

### Progressive Disclosure

✅ **Aligned**. Tier architecture is inherently progressive:
- Tier 1: Just highlighting (no complexity)
- Tier 2: Errors and navigation (standard IDE features)
- Tier 3: Types on hover (deeper when you want it)
- Tier 4: Interactive eval (power user)
- Tier 5: Full InfoView (expert)

### Decomplection

✅ **Aligned**. The two-layer architecture (tree-sitter for syntax, LSP for semantics)
decouples concerns. TextMate grammar works without a server. Semantic tokens augment
rather than replace TextMate. The REPL backend is integrated but uses separate methods
from the static LSP features.

### Composability

✅ **Aligned**. Each tier builds on but doesn't modify the previous tier. The LSP server
composes with `process-file` rather than replacing it. Custom methods extend LSP rather
than forking the protocol.

### Most Generalizable Interface

✅ **Aligned**. Standard LSP for the 80%. Custom methods only where standard LSP can't
express the interaction (eval, narrowing). Code actions for features that fit the
standard model. Any LSP-capable editor gets Tiers 1–3 for free.

### Correct by Construction

✅ **Aligned**. The propagator-first infrastructure design (§9.0) makes incremental
consistency a structural property of the network topology. Type index cells are always
consistent with metavariable solutions because the propagation path enforces it —
no explicit "zonk the index" pass that could be forgotten or called at the wrong time.
Diagnostic cells are always consistent with elaboration results because the dependency
edges enforce it — no "rebuild diagnostics" step that could be skipped. The architecture
makes the wrong thing (stale state) hard to express, rather than relying on discipline
to avoid it.

### Propagator-First Infrastructure

✅ **Aligned**. All five infrastructure subsystems (type index, definition registry,
diagnostics, module exports, completion cache) are propagator-backed. They compose into
a single reactive network where information flows bidirectionally. Adding a new LSP
feature means adding new cells that read from existing cells — no modification of
existing infrastructure, no new invalidation code. The synergy of composing propagator
networks exceeds the sum of their parts.

---

## 13. Open Design Questions with Recommendations

### Q1: Where should the LSP server code live?

**Options**:
- (A) `racket/prologos/lsp/` — alongside the pipeline
- (B) `editors/vscode-prologos/server/` — alongside the VSCode extension
- (C) Separate top-level `lsp-server/` directory

**Recommendation**: **(A) `racket/prologos/lsp/`**. The LSP server is Racket code that
imports the pipeline (`driver.rkt`, `errors.rkt`, etc.). It belongs with the pipeline.
The VSCode extension (TypeScript) lives in `editors/vscode-prologos/`. Clean separation:
Racket code in `racket/`, TypeScript code in `editors/`.

### Q2: How to handle the Racket path dependency?

The LSP server needs to run as `racket lsp/server.rkt`. The Racket binary is at
`/Applications/Racket v9.0/bin/racket` — not on standard PATH.

**Recommendation**: Extension setting `prologos.racketPath` with auto-detection:
1. Check `prologos.racketPath` setting
2. Check `PATH` for `racket`
3. Check common install locations (`/Applications/Racket*/bin/racket`, `~/.racket/bin/racket`)
4. Prompt user if not found

### Q3: How to handle prelude loading latency?

Loading the prelude takes ~2-3 seconds on first load. This blocks the first
`textDocument/publishDiagnostics`.

**Recommendation**: **Eager preload on server startup**. When the LSP server starts,
immediately load the prelude into a cached module registry before waiting for the first
`textDocument/didOpen`. The `prelude-module-registry` pattern from `test-support.rkt`
already demonstrates this — use the same approach. Report prelude loading progress via
`$/progress` notifications.

### Q4: Should we support multi-root workspaces?

**Recommendation**: **No, not initially**. Single-root workspace support covers
the typical use case. Multi-root adds complexity (multiple module registries, path
resolution ambiguity). Defer until there's user demand.

### Q5: File encoding assumptions?

**Recommendation**: **UTF-8 only**. Prologos source files are UTF-8. The LSP protocol
transmits content as UTF-16 offsets (per spec), so the server needs UTF-8 ↔ UTF-16
offset conversion. Racket's string handling is Unicode-aware; the conversion is
straightforward.

### Q6: How to handle `process-file` output noise?

`process-file` currently prints phase timing, provenance reports, and memory reports
to stdout. This would corrupt the JSON-RPC stream.

**Recommendation**: **Suppress all side-effect output in LSP mode**. Add a
`current-lsp-mode` parameter (default `#f`). When `#t`, suppress all
`print-phase-report!`, `print-provenance-report!`, `print-memory-report!`, and
redirect any `printf`/`displayln` to stderr. The JSON-RPC layer owns stdout exclusively.

**Files modified**: `driver.rkt` (~10 lines, guard print calls with `(when (not (current-lsp-mode)) ...)`).

### Q7: Tree-sitter grammar coverage gaps?

The current grammar (`grammar.js`, 363 lines) covers the core syntax but may be missing
newer additions. Known gaps from the Stage 1 audit:

| Syntax | Status in grammar.js | Needed For |
|--------|---------------------|-----------|
| Mixfix `.{}` | Unknown — needs check | Narrowing queries |
| Pipe `\|>` | Unknown | Pipeline expressions |
| Compose `>>` | Unknown | Composition chains |
| Quasiquote `` ` `` | Unknown | Homoiconicity features |
| Transducers (`-xf`) | N/A (naming convention) | — |
| `trait`/`impl`/`bundle` | Check coverage | Trait definitions |
| Session types | Unknown | Session type syntax |
| `foreign` | Unknown | FFI declarations |

**Recommendation**: Audit `grammar.js` against the formal grammar
(`docs/spec/grammar.ebnf`) before Tier 1 implementation. File any missing rules as
tasks for the Tier 1 phase.

### Q8: Extension distribution?

**Options**:
- (A) VSCode Marketplace (public)
- (B) `.vsix` file (manual install)
- (C) Both

**Recommendation**: **(B) `.vsix` initially**, **(C) later**. The language isn't public
yet. Distribute via GitHub releases as a `.vsix`. Publish to Marketplace when the
language is ready for wider adoption.

---

## 14. Effort Summary & Sequencing

### Per-Tier Effort

| Tier | Description | Effort | Cumulative |
|------|-------------|--------|-----------|
| **Infra** | JSON-RPC, side table, def locations, WS pp | ~2 weeks | 2 weeks |
| **1** | Syntax & Static (TextMate, snippets, WASM) | ~1 week | 3 weeks |
| **2** | Diagnostics & Navigation (LSP server) | ~2 weeks | 5 weeks |
| **3** | Type Intelligence (hover, completion, semantic) | ~2.5 weeks | 7.5 weeks |
| **4** | Interactive Evaluation (REPL, inline results) | ~2 weeks | 9.5 weeks |
| **5** | InfoView Panel (React webview) | ~2.5 weeks | 12 weeks |

### Recommended Execution Sequence

```
Week 1-2:   Infrastructure (JSON-RPC layer, definition location registry)
            + Tier 1 (TextMate grammar, language config, snippets, WASM build)
            → Ship Tier 1 as standalone .vsix

Week 3-4:   Tier 2 (LSP server skeleton, diagnostics, go-to-def, doc symbols)
            + Infrastructure (elaboration side table — start)
            → Ship Tiers 1+2 as usable dev experience

Week 5-7:   Tier 3 (elaboration side table — complete, hover, completion,
            semantic tokens, inlay hints, WS pretty-printer)
            → Ship Tiers 1-3

Week 8-9:   Tier 4 (REPL backend, custom methods, inline decorations,
            form identification)
            → Ship Tiers 1-4 (Calva-comparable experience)

Week 10-12: Tier 5 (InfoView React app, cursor tracking, narrowing explorer)
            → Ship complete extension
```

### Files Created (New)

| Path | Purpose | Tier |
|------|---------|------|
| `editors/vscode-prologos/package.json` | Extension manifest | 1 |
| `editors/vscode-prologos/src/extension.ts` | Entry point | 1 |
| `editors/vscode-prologos/syntaxes/prologos.tmLanguage.json` | TextMate grammar | 1 |
| `editors/vscode-prologos/snippets/prologos.json` | Snippets | 1 |
| `editors/vscode-prologos/language-configuration.json` | Brackets, comments | 1 |
| `editors/vscode-prologos/tree-sitter/prologos.wasm` | WASM grammar | 1 |
| `editors/vscode-prologos/queries/folds.scm` | Folding queries | 1 |
| `editors/vscode-prologos/queries/indents.scm` | Indent queries | 1 |
| `racket/prologos/lsp/json-rpc.rkt` | JSON-RPC layer | 2 |
| `racket/prologos/lsp/server.rkt` | LSP server main (event pump) | 2 |
| `racket/prologos/lsp/protocol.rkt` | LSP constants | 2 |
| `racket/prologos/lsp/lsp-network.rkt` | Propagator network topology | Infra |
| `racket/prologos/lsp/lsp-cells.rkt` | Cell types, lattices, merge fns | Infra |
| `racket/prologos/lsp/diagnostics.rkt` | Error → Diagnostic | 2 |
| `racket/prologos/lsp/symbols.rkt` | Document symbols | 2 |
| `racket/prologos/lsp/definition.rkt` | Go-to-definition | 2 |
| `racket/prologos/lsp/signature.rkt` | Signature help | 2 |
| `editors/vscode-prologos/src/client.ts` | LSP client | 2 |
| (type index is part of `lsp-network.rkt` / `lsp-cells.rkt`) | — | Infra |
| `racket/prologos/lsp/hover.rkt` | Hover provider | 3 |
| `racket/prologos/lsp/completion.rkt` | Completion | 3 |
| `racket/prologos/lsp/semantic-tokens.rkt` | Semantic tokens | 3 |
| `racket/prologos/lsp/inlay-hints.rkt` | Inlay hints | 3 |
| `racket/prologos/lsp/repl.rkt` | REPL backend | 4 |
| `editors/vscode-prologos/src/forms.ts` | Form identification | 4 |
| `editors/vscode-prologos/src/decorations.ts` | Inline results | 4 |
| `editors/vscode-prologos/src/repl.ts` | REPL commands | 4 |
| `editors/vscode-prologos/src/statusbar.ts` | Status bar | 4 |
| `editors/vscode-prologos/src/infoview/` | React InfoView app | 5 |

### Files Modified (Existing)

| Path | Change | Tier |
|------|--------|------|
| `racket/prologos/namespace.rkt` | Add `definition-locations` to `module-info` | Infra |
| `racket/prologos/global-env.rkt` | Add `current-definition-locations` parameter | Infra |
| `racket/prologos/driver.rkt` | Record def locations; suppress output in LSP mode; init type index | Infra, 2, 3 |
| `racket/prologos/elaborator.rkt` | ~50 `record-type-at-position!` instrumentation calls | 3 |
| `racket/prologos/pretty-print.rkt` | Add `pp-expr-ws` function (~300 lines) | 3 |
| `editors/tree-sitter-prologos/grammar.js` | Audit and extend for missing syntax | 1 |
| `editors/tree-sitter-prologos/queries/highlights.scm` | Extend for newer syntax | 1 |

---

## 15. Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| **Racket process startup latency** | First diagnostics delayed ~3s (prelude load) | High | Eager preload on server startup; `$/progress` notification |
| **srcloc accuracy in WS mode** | Hover/diagnostic positions off by a line | Medium | End-to-end test with `.prologos` files; verify reader → parser → elaborator srcloc chain |
| **TextMate regex limitations** | Some syntax unhighlightable (nested forms) | Medium | Accept imperfect TextMate; semantic tokens (Tier 3) fix it |
| **Tree-sitter grammar gaps** | WASM build fails or misparses newer syntax | Medium | Grammar audit against `grammar.ebnf` before Tier 1 |
| **`process-file` stdout noise** | JSON-RPC stream corrupted by debug prints | High | `current-lsp-mode` parameter to suppress all non-JSON output |
| **Single-process GC pauses** | LSP becomes unresponsive during long eval | Low (small files) | Monitor; split to dual-process if needed |
| **UTF-16 offset conversion** | Position mismatch between LSP and Racket | Medium | Careful conversion layer; test with non-ASCII identifiers |
| **Elaboration side table completeness** | Some positions missing type info | Medium | Incremental instrumentation; accept gaps initially |
| **Extension size** (WASM + React) | Large `.vsix` download | Low | Tree-sitter WASM is ~200KB; React InfoView can be lazy-loaded |
| **Racket version dependency** | Users on different Racket versions | Low | Document minimum version (9.0); test on 8.x |

---

## Appendix A: LSP Capability Negotiation

The server should advertise these capabilities in the `Initialize` response:

```json
{
  "capabilities": {
    "textDocumentSync": {
      "openClose": true,
      "change": 1,
      "save": { "includeText": true }
    },
    "hoverProvider": true,
    "completionProvider": {
      "triggerCharacters": [":", "[", "."],
      "resolveProvider": true
    },
    "signatureHelpProvider": {
      "triggerCharacters": ["[", " "]
    },
    "definitionProvider": true,
    "documentSymbolProvider": true,
    "semanticTokensProvider": {
      "legend": {
        "tokenTypes": ["namespace", "type", "class", "function", "variable",
                       "parameter", "property", "enumMember", "keyword",
                       "number", "string", "comment"],
        "tokenModifiers": ["declaration", "definition", "readonly", "static",
                           "deprecated", "modification"]
      },
      "full": true
    },
    "inlayHintProvider": true,
    "codeActionProvider": true
  }
}
```

## Appendix B: File Size Reference (Current Codebase)

For infrastructure investment sizing:

| File | Lines | Relevance |
|------|-------|-----------|
| `driver.rkt` | 1968 | Pipeline orchestration — main integration point |
| `elaborator.rkt` | 3924 | Type index instrumentation target |
| `pretty-print.rkt` | 1474 | WS pretty-printer addition |
| `typing-core.rkt` | 2777 | Type checking kernel (read-only for LSP) |
| `metavar-store.rkt` | 1125 | Meta-level type info source |
| `namespace.rkt` | 652 | Module system — definition locations |
| `errors.rkt` | 315 | Error types — diagnostic mapping |
| `typing-errors.rkt` | 276 | Error wrappers — diagnostic formatting |
| `global-env.rkt` | 81 | Global definitions — hover/completion source |
| `source-location.rkt` | 27 | Source positions — LSP range conversion |
