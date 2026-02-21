# Implementation Guide: Emacs Editor Support for Πρόλογος

## prologos-mode: Syntax Highlighting, Structural Editing, Tree-sitter, Code Navigation, and REPL Integration

---

## Table of Contents

1. [Introduction: Why Editor Support Matters Early](#1-introduction-why-editor-support-matters-early)
   - 1.1 [Design Philosophy](#11-design-philosophy)
   - 1.2 [Scope of This Document](#12-scope-of-this-document)
   - 1.3 [Package Architecture Overview](#13-package-architecture-overview)
2. [Research Foundations: Editor Support for Dependently-Typed S-expression Languages](#2-research-foundations-editor-support-for-dependently-typed-s-expression-languages)
   - 2.1 [Lessons from racket-mode, CIDER, and Geiser](#21-lessons-from-racket-mode-cider-and-geiser)
   - 2.2 [Lessons from idris-mode and agda-mode](#22-lessons-from-idris-mode-and-agda-mode)
   - 2.3 [Lessons from prolog-mode](#23-lessons-from-prolog-mode)
   - 2.4 [Tree-sitter: The Modern Foundation](#24-tree-sitter-the-modern-foundation)
   - 2.5 [Structural Editing: paredit, smartparens, and puni](#25-structural-editing-paredit-smartparens-and-puni)
3. [Audit: The Πρόλογος Syntax Landscape](#3-audit-the-πρόλογος-syntax-landscape)
   - 3.1 [Keyword and Special Form Catalogue](#31-keyword-and-special-form-catalogue)
   - 3.2 [Type Annotation Syntax](#32-type-annotation-syntax)
   - 3.3 [QTT Multiplicity Annotations](#33-qtt-multiplicity-annotations)
   - 3.4 [Pattern Matching Syntax](#34-pattern-matching-syntax)
   - 3.5 [Bracket Types and Delimiters](#35-bracket-types-and-delimiters)
   - 3.6 [Literals and Comments](#36-literals-and-comments)
   - 3.7 [Significant Whitespace Mode](#37-significant-whitespace-mode)
   - 3.8 [Module System](#38-module-system)
4. [Design: The Dual-Mode Architecture](#4-design-the-dual-mode-architecture)
   - 4.1 [prologos-mode (Regex-Based, Emacs 28+)](#41-prologos-mode-regex-based-emacs-28)
   - 4.2 [prologos-ts-mode (Tree-sitter, Emacs 29+)](#42-prologos-ts-mode-tree-sitter-emacs-29)
   - 4.3 [Shared Infrastructure](#43-shared-infrastructure)
   - 4.4 [File Extension and Auto-Mode Registration](#44-file-extension-and-auto-mode-registration)
5. [Sprint 1: Core Major Mode and Syntax Highlighting (Week 1)](#5-sprint-1-core-major-mode-and-syntax-highlighting-week-1)
6. [Sprint 2: Indentation Engine (Week 2)](#6-sprint-2-indentation-engine-week-2)
7. [Sprint 3: Structural Editing Integration (Week 3)](#7-sprint-3-structural-editing-integration-week-3)
8. [Sprint 4: Tree-sitter Grammar Development (Weeks 4–8)](#8-sprint-4-tree-sitter-grammar-development-weeks-48)
   - 8.1 [Sprint 4a: S-expression Grammar (Weeks 4–6)](#81-sprint-4a-objective-s-expression-grammar-weeks-46)
   - 8.5 [Sprint 4b: Significant Whitespace Mode (Weeks 7–8)](#85-sprint-4b-objective-significant-whitespace-mode-weeks-78)
9. [Sprint 5: prologos-ts-mode — Tree-sitter Emacs Integration (Week 9)](#9-sprint-5-prologos-ts-mode--tree-sitter-emacs-integration-week-9)
10. [Sprint 6: REPL Integration (Week 10)](#10-sprint-6-repl-integration-week-10)
11. [Sprint 7: Code Navigation — xref, imenu, which-function (Week 11)](#11-sprint-7-code-navigation--xref-imenu-which-function-week-11)
12. [Sprint 8: Inline Documentation and Completion (Week 12)](#12-sprint-8-inline-documentation-and-completion-week-12)
13. [Sprint 9: On-the-Fly Error Checking (Week 13)](#13-sprint-9-on-the-fly-error-checking-week-13)
14. [Sprint 10: Interactive Dependent Type Features (Week 14)](#14-sprint-10-interactive-dependent-type-features-week-14)
15. [Sprint 11: Testing, Polish, and Distribution (Weeks 15–16)](#15-sprint-11-testing-polish-and-distribution-weeks-1516)
16. [The Complete Feature Matrix](#16-the-complete-feature-matrix)
17. [Cross-Cutting Concerns](#17-cross-cutting-concerns)
18. [Post-Sprint Work: LSP Server and Multi-Editor Support](#18-post-sprint-work-lsp-server-and-multi-editor-support)
   - 18.2 [WS Mode Advanced Features](#182-ws-mode-advanced-features)
19. [References](#19-references)

---

## 1. Introduction: Why Editor Support Matters Early

### 1.1 Design Philosophy

Good editor support is not a luxury that can wait until the language is "finished." Every programmer who touches Πρόλογος — from the core team prototyping in Racket to eventual early adopters — will spend their entire working day inside an editor. The quality of that experience determines adoption velocity more than any type-theoretic innovation.

Emacs is the natural first editor target for Πρόλογος because of the language's homoiconic S-expression syntax, significant whitespace support, and the Lisp tradition of deep editor integration. The Emacs ecosystem already has mature infrastructure for exactly the features Πρόλογος needs: structural editing of S-expressions (paredit), REPL interaction (comint), and interactive type-driven development (inspired by agda-mode and idris-mode).

The guiding principle for `prologos-mode` is: **make the editor understand Πρόλογος deeply enough that the programmer never fights the tooling.** Parentheses balance themselves. Types appear at point. Definitions are one keystroke away. Errors show before the programmer saves. The Church encoding internals never leak into the editing experience.

### 1.2 Scope of This Document

This document provides a 16-week, 11-sprint implementation plan for a production-quality Emacs major mode for Πρόλογος. The mode works on files ending in `.prologos` and supports **both** the S-expression syntax (`#lang prologos/sexp`) and the significant-whitespace syntax (`#lang prologos`). The plan covers:

- **Syntax highlighting** with multi-level fontification for keywords, types, multiplicities, constructors, and holes.
- **Structural editing** via paredit/smartparens/puni integration, ensuring balanced parentheses and bracket-aware navigation across all four bracket types (`()`, `[]`, `<>`, `{}`).
- **Tree-sitter integration** with a custom grammar for accurate, incremental parsing and highlighting (Emacs 29+), with regex-based fallback for Emacs 28.
- **REPL integration** via comint-mode for interactive development.
- **Code navigation** via xref, imenu, and which-function-mode.
- **Inline documentation** via eldoc and completion-at-point.
- **On-the-fly error checking** via Flymake.
- **Interactive dependent type features** inspired by agda-mode: hole navigation, type-at-point, and case splitting.

### 1.3 Package Architecture Overview

```
prologos-mode/
├── prologos-mode.el              ;; Core major mode (regex-based)
├── prologos-font-lock.el         ;; Font-lock keyword definitions
├── prologos-indent.el            ;; Indentation engine
├── prologos-structural.el        ;; Structural editing integration
├── prologos-ts-mode.el           ;; Tree-sitter major mode (Emacs 29+)
├── prologos-repl.el              ;; REPL integration via comint
├── prologos-xref.el              ;; xref backend for go-to-definition
├── prologos-eldoc.el             ;; Inline documentation
├── prologos-completion.el        ;; Completion-at-point
├── prologos-flymake.el           ;; On-the-fly error checking
├── prologos-holes.el             ;; Interactive hole commands (type-driven dev)
├── tree-sitter-prologos/         ;; Tree-sitter grammar project
│   ├── grammar.js                ;; Grammar definition (sexp + WS modes)
│   ├── src/
│   │   └── scanner.c             ;; External scanner for INDENT/DEDENT tokens
│   ├── queries/
│   │   ├── highlights.scm        ;; Syntax highlighting queries
│   │   ├── indents.scm           ;; Indentation queries
│   │   └── locals.scm            ;; Scope/definition queries
│   ├── test/corpus/              ;; Grammar test cases (sexp + WS)
│   └── package.json
├── tests/
│   ├── prologos-font-lock-tests.el
│   ├── prologos-indent-tests.el
│   └── prologos-repl-tests.el
├── snippets/                     ;; Yasnippet templates
│   ├── prologos-mode/
│   │   ├── def
│   │   ├── defn
│   │   ├── fn
│   │   ├── match
│   │   ├── data
│   │   └── relation
├── README.md
└── Makefile
```

---

## 2. Research Foundations: Editor Support for Dependently-Typed S-expression Languages

### 2.1 Lessons from racket-mode, CIDER, and Geiser

Πρόλογος is an S-expression language, so existing Lisp editor support provides the blueprint. Three packages stand out for different reasons:

**racket-mode** (Greg Hendershott) is the closest analog because Πρόλογος is prototyped in Racket. It demonstrates how to handle `#lang` sublanguage detection, multi-level indentation for nested S-expressions, and REPL integration with `racket --repl` via comint-mode. Critically, racket-mode uses `define-derived-mode` inheriting from `prog-mode` rather than `lisp-mode` — this avoids inheriting Common Lisp assumptions (like `,` being a backquote operator) that would misfire for Πρόλογος.

**CIDER** (Clojure Interactive Development Environment that Rocks) demonstrates the gold standard for REPL-driven development in a Lisp. Its key innovations are: inline evaluation results displayed as overlays in the source buffer, a structured REPL protocol (nREPL) that separates evaluation from display, and deep integration with paredit/smartparens for structural editing. The nREPL protocol is overkill for the Πρόλογος prototype, but the inline overlay technique for displaying types at point is directly applicable.

**Geiser** (for Scheme/Guile) demonstrates comint-based REPL integration that is simpler than CIDER's nREPL but still provides send-expression, eval-region, and module-aware completion. This is the right weight class for the Πρόλογος prototype — a standard comint REPL with mode-aware keybindings.

### 2.2 Lessons from idris-mode and agda-mode

Πρόλογος has dependent types, which means the editor must support **interactive type-driven development** — a paradigm where the programmer leaves holes (`?name`) in their code and asks the compiler to fill them or display their expected types.

**agda-mode** (bundled with Agda) is the most mature implementation. Its key features:
- `C-c C-l` ("load"): Type-checks the entire file and highlights unsolved holes in yellow.
- `C-c C-,` ("goal type"): Shows the expected type and context of the hole at point.
- `C-c C-SPC` ("give"): Fills a hole with a term and verifies it type-checks.
- `C-c C-c` ("case split"): Generates pattern match arms from the type of a variable.
- `C-c C-r` ("refine"): Partially fills a hole based on available information.

agda-mode communicates with the Agda compiler via a custom protocol (not LSP). This deep integration is what makes Agda usable despite its fully dependent type system.

**idris-mode** follows a similar pattern but uses a socket-based protocol (the Idris IDE protocol) for communication with the compiler. It provides type-at-point, case splitting, proof search, and documentation lookup. Idris 2's protocol is documented and provides a useful reference for building interactive dependent-type features.

For Πρόλογος, the prototype plan implements a lighter-weight version: hole navigation (jump between `?` holes), type-at-point (query the Racket prototype for the type), and case split (generate match arms from a data type's constructors). These can be implemented against the existing Racket prototype's evaluation interface.

### 2.3 Lessons from prolog-mode

The built-in `prolog-mode` (or the more capable `ediprolog`) demonstrates syntax support for logic programming: clause definitions (`head :- body`), queries (`?- goal`), and operator highlighting. For Πρόλογος, the relevant lessons are:

- **Clause-level navigation**: Jump between clauses of the same relation (like `defn` forms).
- **Variable highlighting**: In Prolog, capitalized identifiers are logic variables. In Πρόλογος, the convention may differ, but the editor should distinguish logic variables from bound variables.
- **Query interaction**: Send a query to the REPL and display solutions. This is analogous to `eval-last-sexp` but for logic queries.

### 2.4 Tree-sitter: The Modern Foundation

Tree-sitter (Brunsfeld, 2018) provides incremental, error-recovering parsing that produces a concrete syntax tree. Emacs 29+ includes native tree-sitter support via `treesit.el`, making it the preferred foundation for syntax highlighting and code navigation.

For Πρόλογος, tree-sitter offers several advantages over regex-based font-lock:

**Accuracy.** Regex-based highlighting cannot distinguish `Nat` used as a type from `Nat` used as a constructor argument, because regex operates on text, not syntax. Tree-sitter parses the program into a syntax tree, so `(fn [x <Nat>] body)` correctly identifies `Nat` in type position and highlights it differently from `Nat` in expression position.

**Error recovery.** When the programmer is typing, the buffer frequently contains incomplete or syntactically invalid code. Regex-based highlighting fails catastrophically (mismatched brackets cause the entire buffer to re-fontify incorrectly). Tree-sitter's error recovery inserts synthetic nodes at error points, allowing the rest of the buffer to parse correctly.

**Incremental parsing.** Tree-sitter re-parses only the changed region on each keystroke (O(log n) typical complexity), making it suitable for large files. Regex-based font-lock may re-scan the entire buffer.

**Structural operations.** Tree-sitter nodes provide exact boundaries for S-expression operations: slurp, barf, raise, and splice can use the parse tree rather than heuristic sexp-scanning. This is particularly valuable for Πρόλογος's mixed bracket types.

The grammar development workflow is: write `grammar.js` (a JavaScript DSL for context-free grammars), compile to a C parser with `tree-sitter generate`, test with `tree-sitter parse`, and distribute the compiled grammar as a shared library. Queries for highlighting, indentation, and navigation are defined in `.scm` files using S-expression patterns.

### 2.5 Structural Editing: paredit, smartparens, and puni

S-expression languages benefit enormously from structural editing — operations that treat the code as a tree rather than a sequence of characters. Three packages provide this:

**paredit** (Taylor Campbell) is the original structural editing package for Emacs. It enforces balanced parentheses at all times, provides slurp/barf/splice/raise/wrap operations, and navigates by S-expression boundaries. paredit is strict — it prevents the programmer from creating unbalanced code, which can be frustrating during refactoring.

**smartparens** (Matúš Goljer) is the modern, language-agnostic alternative. It supports arbitrary pair types (not just parentheses), allows toggling between strict and permissive modes, and provides the same structural operations as paredit plus additional features like hybrid sexp-kill. smartparens is approximately 10,000 lines of code and supports every bracket type.

**puni** (Jin Fan) is the lightweight alternative (approximately 2,000 lines). It uses Emacs's built-in `forward-sexp` for all languages, making it simpler and more predictable. puni is the emerging choice for multi-language support with minimal configuration.

For Πρόλογος, the recommendation is to **support all three but recommend smartparens or puni** as the default. The mode provides a `defcustom` to select the structural editing engine, and enables it via the mode hook. The key requirement is that all four bracket types — `()`, `[]`, `<>`, `{}` — are treated as balanced pairs by the structural editing engine.

Special consideration: `<>` is used for type annotations (`<Nat>`, `<(-> A B)>`) and must be paired correctly. Standard paredit/smartparens do not pair `<>` by default; the Πρόλογος mode must configure this explicitly.

---

## 3. Audit: The Πρόλογος Syntax Landscape

### 3.1 Keyword and Special Form Catalogue

An exhaustive analysis of the Racket prototype's reader, parser, macro expander, and example files yields the following keyword categories:

**Definition forms** (top-level): `def`, `defn`, `defmacro`, `deftype`, `data`, `ns`, `require`, `provide`

**Expression forms**: `fn`, `the`, `the-fn`, `let`, `do`, `if`, `match`, `reduce`

**Type constructors**: `Pi`, `Sigma`, `->`, `Type`, `Nat`, `Bool`, `Posit8`, `Vec`, `Fin`, `Eq`

**Value constructors**: `zero`, `true`, `false`, `refl`, `pair`, `inc`, `vnil`, `vcons`, `fzero`, `fsuc`, `posit8`

**Eliminators** (internal, hidden after type inference): `natrec`, `boolrec`, `J`, `first`, `second`, `vhead`, `vtail`, `vindex`

**Posit8 operations**: `p8+`, `p8-`, `p8*`, `p8/`, `p8-neg`, `p8-abs`, `p8-sqrt`, `p8-lt`, `p8-le`, `p8-from-nat`, `p8-if-nar`

**Top-level commands**: `check`, `eval`, `infer`

**Future keywords** (from NOTES.org and other implementation guides): `relation`, `clause`, `query`, `actor`, `spawn`, `send`, `recv`, `chan`, `session`, `propagator`, `cell`, `forall`, `exists`

### 3.2 Type Annotation Syntax

Πρόλογος uses two annotation styles, both of which must be highlighted:

**Angle bracket style** (primary): `<Nat>`, `<(Type 0)>`, `<(-> A B)>`. The angle brackets delimit type annotations in parameter lists and definitions. The reader treats `<` and `>` as bracket delimiters, so `<Nat>` parses as a single annotated form.

**Colon style** (secondary): `(x : Nat)`, `def name : Type body`. The colon separates identifier from type. This style is used in some binder positions and is backwards-compatible with standard dependent type notation.

The editor should highlight the content inside `<...>` with a distinct face (e.g., `font-lock-type-face`) and recognize `:` in binder positions as a type annotation marker.

**Context sensitivity of `<>`.** In the current prototype, `<` and `>` are **always** treated as bracket delimiters by the reader (`reader.rkt` lines 318+). They are not used as comparison operators — Πρόλογος uses `p8-lt` and `p8-le` for posit comparison. This means the syntax table can unconditionally pair `<>` without context-dependent heuristics, simplifying both the structural editing integration and the tree-sitter grammar. If future syntax introduces `<` as a comparison operator, the grammar will need to be revised, but for the current prototype this is not a concern.

### 3.3 QTT Multiplicity Annotations

Multiplicities appear after `:` in binder positions: `:0` (erased), `:1` (linear), `:w` (unrestricted). These should be highlighted distinctly — they are API-level annotations that affect the semantics of the program. The recommended face is a custom `prologos-multiplicity-face` inheriting from `font-lock-preprocessor-face` with a visually distinct color.

**Concrete syntax in parameter lists:**

```
(fn [A :0 <(Type 0)>] (fn [x <A>] x))    ;; :0 = erased (type parameter)
(fn [handle :1 <FileHandle>] (close handle)) ;; :1 = linear (use exactly once)
(fn [x <Nat>] (+ x x))                    ;; no annotation = default ω (unrestricted)
(defn id [A :0 <(Type 0)>  x <A>] <A> x)  ;; :0 on type param, default on value
```

The multiplicity token always appears between the parameter name and the type annotation, inside square brackets. The tree-sitter grammar's `parameter` rule captures this as: `'[' identifier [multiplicity] [type_annotation] ']'`. The regex font-lock rule `("\\(:0\\|:1\\|:w\\)" . 'prologos-multiplicity-face)` handles highlighting in both regex and tree-sitter modes.

### 3.4 Pattern Matching Syntax

Pattern matching uses `match`/`reduce` with arm syntax:

```
(match scrutinee
  pattern₁ -> body₁
  pattern₂ -> body₂)
```

The `->` arrow separating pattern from body should be highlighted as an operator. Constructor names in patterns should receive `font-lock-constant-face`. The `|` pipe separator used in whitespace mode should be highlighted as punctuation.

### 3.5 Bracket Types and Delimiters

Πρόλογος uses four distinct bracket types:

| Bracket | Purpose | Example |
|---|---|---|
| `()` | Grouping, function application | `(inc zero)` |
| `[]` | Parameter lists | `[x <Nat>]` |
| `<>` | Type annotations | `<(-> Nat Nat)>` |
| `{}` | Implicit type parameters, EDN maps | `{A B}`, `{:key val}` |

All four must be registered in the syntax table for balanced-pair operations. The `<>` pair requires special handling because `<` and `>` also appear as comparison operators in future syntax — the reader currently resolves this by context, and the editor must do the same.

### 3.6 Literals and Comments

**Comments**: Line comments start with `;` and extend to end of line. No block comment syntax exists currently. The syntax table entry is `(modify-syntax-entry ?\; "<" table)` paired with `(modify-syntax-entry ?\n ">" table)`.

**Natural numbers**: Bare numerals `0`, `1`, `42` desugar to Church-encoded naturals. Highlight with `font-lock-constant-face`.

**Booleans**: `true`, `false` — highlight as constants.

**Posit8**: `(posit8 N)` where N is 0–255. The `posit8` keyword in constructor position should be highlighted.

**Strings**: Double-quoted with standard escape sequences (`\n`, `\t`, `\\`, `\"`). The syntax table marks `"` as a string delimiter.

### 3.7 Significant Whitespace Mode

Πρόλογος supports a whitespace-sensitive surface syntax (similar to TCL) where indentation creates implicit grouping. The `#lang prologos` directive activates this mode, while `#lang prologos/sexp` uses traditional S-expression syntax. **Both modes are first-class concerns of the Emacs editor support.** All `.prologos` files are handled by `prologos-mode`, which detects the `#lang` directive to determine the active syntax mode.

The WS mode rules from NOTES.org are:

- **New line, same level**: implicit list of arguments (siblings in the AST).
- **New line, deeper level**: implicit tree-depth of the AST (child nodes).
- **Same line with `()` groupings**: deeper tree-depth within a single line.

For the Emacs mode, WS mode has four implications:

1. **Indentation is semantically significant** — incorrect indentation changes the program's meaning. The indentation engine must distinguish between WS mode (where indentation is semantic and must not be auto-modified) and sexp mode (where indentation is cosmetic and can be freely adjusted). A buffer-local variable `prologos--ws-mode-p` tracks the active mode.

2. **The tree-sitter grammar must handle both modes.** An external scanner (`scanner.c`) tracks indentation levels and emits INDENT/DEDENT tokens for WS mode, similar to Python's tree-sitter grammar. The grammar detects the `#lang` directive in the first line and switches parsing rules accordingly.

3. **Structural editing differs between modes.** In sexp mode, all grouping is explicit via brackets. In WS mode, some grouping is implicit via indentation, so structural editing operations like slurp/barf must be indentation-aware in addition to bracket-aware.

4. **The `|` pipe separator** is used in WS mode for pattern match arms and should be highlighted as punctuation.

### 3.8 Module System

Modules use three directives: `(ns name)` for namespace declaration, `(require path)` for imports, and `(provide sym ...)` for exports. These should be highlighted as top-level keywords and used by imenu for module-level navigation.

---

## 4. Design: The Dual-Mode Architecture

### 4.1 prologos-mode (Regex-Based, Emacs 28+)

The base mode uses `define-derived-mode` inheriting from `prog-mode` (not `lisp-mode`, to avoid inheriting Common Lisp assumptions). It provides regex-based font-lock, custom indentation, and integrates with all shared infrastructure (REPL, xref, eldoc, completion).

```elisp
(define-derived-mode prologos-mode prog-mode "Πρόλογος"
  "Major mode for editing Πρόλογος source files."
  :group 'prologos
  :syntax-table prologos-mode-syntax-table
  ;; Font-lock
  (setq-local font-lock-defaults '(prologos-font-lock-keywords nil nil))
  ;; Indentation
  (setq-local indent-line-function #'prologos-indent-line)
  (setq-local lisp-indent-function #'prologos-lisp-indent-function)
  ;; Comments
  (setq-local comment-start ";; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip ";+\\s-*")
  ;; Navigation
  (setq-local beginning-of-defun-function #'prologos-beginning-of-defun)
  (setq-local end-of-defun-function #'prologos-end-of-defun)
  ;; Detect #lang mode for WS vs. sexp behavior
  (prologos--detect-lang-mode)
  ;; Shared infrastructure
  (prologos--setup-shared))
```

**Defun navigation functions** (used by `C-M-a` and `C-M-e`):

```elisp
(defun prologos-beginning-of-defun (&optional arg)
  "Move to the beginning of the ARGth preceding top-level definition."
  (interactive "p")
  (re-search-backward
   "^\\s-*(def\\(?:n\\|type\\|macro\\)?\\|data\\|relation\\)\\s-"
   nil t (or arg 1)))

(defun prologos-end-of-defun (&optional arg)
  "Move to the end of the ARGth following top-level definition."
  (interactive "p")
  (prologos-beginning-of-defun (- (or arg 1)))
  (forward-sexp 1))
```

### 4.2 prologos-ts-mode (Tree-sitter, Emacs 29+)

The tree-sitter mode provides accurate, incremental highlighting and navigation. It is preferred when the tree-sitter grammar is available.

```elisp
(define-derived-mode prologos-ts-mode prog-mode "Πρόλογος"
  "Tree-sitter based major mode for Πρόλογος."
  :group 'prologos
  :syntax-table prologos-mode-syntax-table
  (when (treesit-language-available-p 'prologos)
    (treesit-parser-create 'prologos)
    (setq-local treesit-font-lock-settings prologos-ts-font-lock-rules)
    (setq-local treesit-font-lock-feature-list
                '((comment string)
                  (keyword type builtin)
                  (constant function definition)
                  (multiplicity operator hole)))
    (setq-local treesit-simple-indent-rules prologos-ts-indent-rules)
    (setq-local treesit-simple-imenu-settings prologos-ts-imenu-settings)
    (treesit-major-mode-setup))
  ;; Detect #lang mode for WS vs. sexp behavior
  (prologos--detect-lang-mode)
  (prologos-ts--configure-for-lang-mode)
  (prologos--setup-shared))
```

### 4.3 Shared Infrastructure

Both modes share a common setup function that configures REPL integration, xref backend, eldoc, completion, Flymake, and structural editing:

```elisp
(defun prologos--setup-shared ()
  "Set up shared infrastructure for both prologos-mode and prologos-ts-mode."
  ;; xref
  (add-hook 'xref-backend-functions #'prologos-xref-backend nil t)
  ;; eldoc
  (add-hook 'eldoc-documentation-functions #'prologos-eldoc-function nil t)
  ;; completion
  (add-hook 'completion-at-point-functions #'prologos-completion-at-point nil t)
  ;; imenu (regex mode; ts-mode uses treesit-simple-imenu-settings)
  (unless (derived-mode-p 'prologos-ts-mode)
    (setq-local imenu-generic-expression prologos-imenu-generic-expression))
  ;; Flymake
  (when prologos-enable-flymake
    (add-hook 'flymake-diagnostic-functions #'prologos-flymake-checker nil t)
    (flymake-mode 1))
  ;; Structural editing
  (prologos--setup-structural-editing)
  ;; Pretty symbols
  (when prologos-pretty-symbols
    (prologos--setup-prettify-symbols)))
```

### 4.4 File Extension and Auto-Mode Registration

The canonical file extension is `.prologos`. Both sexp and WS mode files use this extension — the mode detects which syntax is active from the `#lang` directive on the first line of the file. A secondary `.pro` extension is supported for compatibility but `.prologos` is strongly recommended.

```elisp
;; Canonical extension: .prologos
(add-to-list 'auto-mode-alist '("\\.prologos\\'" . prologos-mode))
;; Secondary extension (compatibility)
(add-to-list 'auto-mode-alist '("\\.pro\\'" . prologos-mode))

;; Prefer tree-sitter mode when available
(when (and (fboundp 'treesit-language-available-p)
           (treesit-language-available-p 'prologos))
  (add-to-list 'major-mode-remap-alist '(prologos-mode . prologos-ts-mode)))
```

---

## 5. Sprint 1: Core Major Mode and Syntax Highlighting (Week 1)

### 5.1 Objective

Create the foundation: `prologos-mode.el` with `define-derived-mode`, syntax table, font-lock keywords, and auto-mode-alist registration. At the end of this sprint, opening a `.prologos` file shows properly highlighted code.

### 5.2 Deliverables

**`prologos-mode.el`**: Core mode definition with syntax table and keymap.

**Syntax table configuration:**

```elisp
(defvar prologos-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Comments: ; to end of line
    (modify-syntax-entry ?\; "<" table)
    (modify-syntax-entry ?\n ">" table)
    ;; Strings
    (modify-syntax-entry ?\" "\"" table)
    ;; Brackets
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    ;; Angle brackets (type annotations)
    (modify-syntax-entry ?\< "(>" table)
    (modify-syntax-entry ?\> ")<" table)
    ;; Symbol constituents
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?- "_" table)
    (modify-syntax-entry ?? "_" table)
    (modify-syntax-entry ?! "_" table)
    (modify-syntax-entry ?* "_" table)
    (modify-syntax-entry ?+ "_" table)
    (modify-syntax-entry ?/ "_" table)
    (modify-syntax-entry ?. "_" table)
    (modify-syntax-entry ?= "_" table)
    ;; Colon as punctuation (not symbol)
    (modify-syntax-entry ?: "." table)
    table)
  "Syntax table for `prologos-mode'.")
```

**`prologos-font-lock.el`**: Multi-level fontification with five levels of highlighting.

```elisp
(defconst prologos-font-lock-keywords-1
  `(;; Top-level definition forms
    (,(regexp-opt '("def" "defn" "defmacro" "deftype" "data"
                    "ns" "require" "provide") 'symbols)
     . font-lock-keyword-face)
    ;; Top-level commands
    (,(regexp-opt '("check" "eval" "infer") 'symbols)
     . font-lock-preprocessor-face))
  "Level 1: keywords and commands.")

(defconst prologos-font-lock-keywords-2
  (append prologos-font-lock-keywords-1
   `(;; Expression forms
     (,(regexp-opt '("fn" "the" "the-fn" "let" "do" "if"
                     "match" "reduce" "forall" "exists") 'symbols)
      . font-lock-keyword-face)
     ;; Type constructors
     (,(regexp-opt '("Pi" "Sigma" "Type" "Nat" "Bool" "Posit8"
                     "Vec" "Fin" "Eq" "Chan" "Session") 'symbols)
      . font-lock-type-face)))
  "Level 2: add expression forms and type constructors.")

(defconst prologos-font-lock-keywords-3
  (append prologos-font-lock-keywords-2
   `(;; Value constructors and constants
     (,(regexp-opt '("zero" "true" "false" "refl" "pair" "inc"
                     "vnil" "vcons" "fzero" "fsuc" "posit8"
                     "nothing" "just" "nil" "cons") 'symbols)
      . font-lock-constant-face)
     ;; Eliminators (internal, but may appear in prototype code)
     (,(regexp-opt '("natrec" "boolrec" "first" "second"
                     "vhead" "vtail" "vindex" "J") 'symbols)
      . font-lock-builtin-face)))
  "Level 3: add constructors and eliminators.")

(defconst prologos-font-lock-keywords-4
  (append prologos-font-lock-keywords-3
   `(;; Posit8 operations
     (,(regexp-opt '("p8+" "p8-" "p8*" "p8/" "p8-neg" "p8-abs"
                     "p8-sqrt" "p8-lt" "p8-le" "p8-from-nat"
                     "p8-if-nar") 'symbols)
      . font-lock-builtin-face)
     ;; Future: actor/session/logic keywords
     (,(regexp-opt '("relation" "clause" "query" "actor" "spawn"
                     "send" "recv" "chan" "propagator" "cell") 'symbols)
      . font-lock-keyword-face)
     ;; Arrow operator
     ("->" . font-lock-constant-face)))
  "Level 4: add Posit8 ops, future keywords, operators.")

(defconst prologos-font-lock-keywords-5
  (append prologos-font-lock-keywords-4
   `(;; QTT multiplicity annotations
     ("\\(:0\\|:1\\|:w\\)" . 'prologos-multiplicity-face)
     ;; Holes (metavariables)
     ("\\?[a-zA-Z_][a-zA-Z0-9_]*" . font-lock-warning-face)
     ;; Macro pattern variables
     ("\\$[a-zA-Z_][a-zA-Z0-9_]*" . font-lock-variable-name-face)
     ;; Definition name after def/defn
     ("(def\\(?:n\\|type\\|macro\\)?\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)"
      (1 font-lock-function-name-face))
     ;; data type name (handles both (data Name ...) and (data (Name A) ...))
     ("(data\\s-+\\(?\\([A-Z][a-zA-Z0-9_]*\\)"
      (1 font-lock-type-face))))
  "Level 5: add multiplicities, holes, definition names.")
```

**Custom faces:**

```elisp
(defface prologos-multiplicity-face
  '((t :inherit font-lock-preprocessor-face :weight bold))
  "Face for QTT multiplicity annotations (:0, :1, :w)."
  :group 'prologos-faces)

(defface prologos-hole-face
  '((t :inherit font-lock-warning-face :box t))
  "Face for unsolved holes (?name)."
  :group 'prologos-faces)

(defface prologos-type-annotation-face
  '((t :inherit font-lock-type-face :slant italic))
  "Face for type annotations in angle brackets."
  :group 'prologos-faces)
```

**Prettify symbols:**

```elisp
(defun prologos--setup-prettify-symbols ()
  "Set up Unicode display for Πρόλογος operators."
  (setq-local prettify-symbols-alist
              '(("Pi"    . ?Π)
                ("Sigma" . ?Σ)
                ("fn"    . ?λ)
                ("->"    . ?→)
                (":w"    . ?ω)
                ("forall" . ?∀)
                ("exists" . ?∃)
                ("Nat"   . ?ℕ)
                ("Bool"  . ?𝔹)))
  (prettify-symbols-mode 1))
```

### 5.3 Tests

- Open a `.prologos` file: mode activates, mode-line shows "Πρόλογος."
- Keywords (`def`, `fn`, `match`) highlighted in keyword face.
- Type constructors (`Nat`, `Bool`, `Vec`) highlighted in type face.
- Value constructors (`zero`, `true`, `vnil`) highlighted in constant face.
- Comments (`;`) dimmed correctly.
- Strings (`"hello"`) highlighted as strings.
- Brackets balanced: all four types `()`, `[]`, `<>`, `{}`.

---

## 6. Sprint 2: Indentation Engine (Week 2)

### 6.1 Objective

Implement Lisp-style indentation that understands Πρόλογος's specific forms — `def`/`defn` body indentation, `match` arm alignment, `let` binding alignment, and `fn` parameter alignment. The engine must also detect the `#lang` directive and adjust its behavior for WS mode, where indentation is semantically significant.

### 6.2 Deliverables

**`prologos-indent.el`**: Custom indentation engine.

**Indentation rules by form:**

| Form | Indentation Rule |
|---|---|
| `def` | Body indented 2 spaces from `def` |
| `defn` | Parameters aligned, body indented 2 |
| `fn` | Body indented 2 from `fn` |
| `let` | Bindings indented 4, body indented 2 |
| `do` | Bindings indented 2, each on own line |
| `if` | Condition, then, else each indented 2 |
| `match` | Each arm indented 2 from `match` |
| `Pi`/`Sigma` | Binder indented 4, body indented 2 |
| `data` | Constructors indented 2 from `data` |
| `relation` | Clauses indented 2 from `relation` |

**Custom indent function** (for sexp mode):

The `prologos-lisp-indent-function` dispatches indentation based on the `prologos-indent-function` property of the head symbol of each form. It accepts numeric values (number of special arguments before body indentation) and the symbol `defun` (body gets extra indent like Emacs Lisp `defun`).

```elisp
(defun prologos--sexp-indent-line ()
  "Indent current line using Lisp-style indentation for sexp mode."
  (lisp-indent-line))

(defun prologos-lisp-indent-function (indent-point state)
  "Calculate indentation for Πρόλογος forms in sexp mode.
Consults the `prologos-indent-function' property of the head symbol."
  (let ((normal-indent (current-column)))
    (goto-char (1+ (elt state 1)))
    (parse-partial-sexp (point) indent-point 0 t)
    (if (and (elt state 2)
             (not (looking-at "\\sw\\|\\s_")))
        ;; First element is not a symbol — align with first arg
        (progn
          (when (not (> (save-excursion (forward-line 1) (point))
                       (elt state 2)))
            (goto-char (elt state 2))
            (beginning-of-line)
            (parse-partial-sexp (point) (elt state 2) 0 t))
          (current-column))
      ;; First element is a symbol — check for prologos-indent-function property
      (let* ((function (buffer-substring (point)
                                         (progn (forward-sexp 1) (point))))
             (method (get (intern-soft function) 'prologos-indent-function)))
        (cond ((integerp method)
               (lisp-indent-specform method state indent-point normal-indent))
              ((eq method 'defun)
               (lisp-indent-defform state indent-point))
              (t (let ((function (buffer-substring (point)
                                                   (progn (goto-char (elt state 1))
                                                          (forward-sexp 1)
                                                          (point)))))
                   normal-indent)))))))
```

Implementation using `lisp-indent-function` properties:

```elisp
;; defun-style indentation (body gets extra indent)
(put 'def 'prologos-indent-function 'defun)
(put 'defn 'prologos-indent-function 'defun)
(put 'deftype 'prologos-indent-function 'defun)
(put 'defmacro 'prologos-indent-function 'defun)
(put 'data 'prologos-indent-function 'defun)
(put 'relation 'prologos-indent-function 'defun)

;; 1-arg special forms (first arg on same line, rest indented)
(put 'fn 'prologos-indent-function 1)
(put 'the 'prologos-indent-function 1)
(put 'match 'prologos-indent-function 1)
(put 'reduce 'prologos-indent-function 1)

;; 2-arg special forms
(put 'if 'prologos-indent-function 2)
(put 'let 'prologos-indent-function 1)
(put 'do 'prologos-indent-function 0)

;; Type forms
(put 'Pi 'prologos-indent-function 1)
(put 'Sigma 'prologos-indent-function 1)
(put 'forall 'prologos-indent-function 1)
(put 'exists 'prologos-indent-function 1)
```

**WS mode detection and semantic indentation:**

```elisp
(defvar-local prologos--ws-mode-p nil
  "Non-nil when the current buffer uses significant-whitespace mode.
Detected from the `#lang' directive on the first line.")

(defun prologos--detect-lang-mode ()
  "Detect whether this file uses sexp or whitespace mode.
Sets `prologos--ws-mode-p' based on the #lang directive."
  (save-excursion
    (goto-char (point-min))
    (setq prologos--ws-mode-p
          (and (looking-at "#lang\\s-+prologos\\s-*$")
               t))))

(defun prologos-indent-line ()
  "Indent current line as Πρόλογος code.
In WS mode, indentation is semantic — the engine warns if the user
requests re-indentation that would change program meaning.
In sexp mode, standard Lisp-style cosmetic indentation applies."
  (interactive)
  (if prologos--ws-mode-p
      (prologos--ws-indent-line)
    (prologos--sexp-indent-line)))

(defun prologos--ws-indent-line ()
  "Indent line in whitespace-significant mode.
Preserves existing indentation (which is semantic). Only indents
blank lines or new lines where the user is actively typing."
  (let ((current-indent (current-indentation)))
    (if (= (line-beginning-position) (line-end-position))
        ;; Blank line: indent to match previous non-blank line
        (indent-line-to (save-excursion
                          (forward-line -1)
                          (while (and (not (bobp))
                                      (looking-at "^\\s-*$"))
                            (forward-line -1))
                          (current-indentation)))
      ;; Non-blank line: preserve existing indentation (semantic!)
      (indent-line-to current-indent))))
```

### 6.3 Tests

Verify indentation for each form against expected output. For example:

```
;; Expected indentation:
(defn double [x <Nat>] <Nat>
  (match x
    zero    -> zero
    (inc n) -> (inc (inc (double n)))))

(let [x <Nat> (inc zero)
      y <Nat> (inc x)]
  (match y
    zero    -> x
    (inc n) -> n))
```

**WS mode indentation test:**

```
;; WS mode: indentation is preserved (semantic), not re-indented
#lang prologos

defn double
  x <Nat>
  <Nat>
  match x
    zero    -> zero
    inc n   -> inc (inc (double n))
```

In WS mode, pressing TAB on a non-blank line preserves the existing indentation. On a blank line, it matches the indentation of the previous non-blank line.

---

## 7. Sprint 3: Structural Editing Integration (Week 3)

### 7.1 Objective

Integrate structural editing so that parentheses always balance, and slurp/barf/splice/raise operations work correctly across all four bracket types.

### 7.2 Deliverables

**`prologos-structural.el`**: Configuration for smartparens, puni, or paredit.

**User-configurable engine selection:**

```elisp
(defcustom prologos-structural-editing 'smartparens
  "Structural editing engine. Choose smartparens (recommended), puni, or paredit."
  :type '(choice (const :tag "Smartparens (recommended)" smartparens)
                 (const :tag "Puni (lightweight)" puni)
                 (const :tag "Paredit (classic)" paredit)
                 (const :tag "None" nil))
  :group 'prologos)
```

**Smartparens configuration for Πρόλογος bracket types:**

```elisp
(defun prologos--setup-smartparens ()
  "Configure smartparens for Πρόλογος bracket types."
  (require 'smartparens)
  ;; Standard pairs already handled: (), [], {}
  ;; Add angle brackets for type annotations.
  ;; In Πρόλογος, <> are always type annotation delimiters (never comparison
  ;; operators — the language uses p8-lt/p8-le for comparisons), so they
  ;; can be unconditionally paired.
  (sp-local-pair 'prologos-mode "<" ">")
  ;; Strict mode: prevent unbalanced edits
  (smartparens-strict-mode 1)
  (smartparens-mode 1))
```

Because `<>` are always bracket delimiters in the current Πρόλογος syntax (the reader unconditionally treats them as matched pairs), no context-sensitive predicate is needed for auto-pairing. This is simpler and more reliable than heuristic-based pairing.

**Structural editing dispatcher** (called from `prologos--setup-shared`):

```elisp
(defun prologos--setup-structural-editing ()
  "Set up structural editing based on the user's `prologos-structural-editing' preference."
  (pcase prologos-structural-editing
    ('smartparens (prologos--setup-smartparens))
    ('puni       (require 'puni) (puni-mode 1))
    ('paredit    (require 'paredit) (enable-paredit-mode))
    ('nil        nil)))  ;; None selected
```

**Key bindings for structural operations:**

```elisp
(defvar prologos-structural-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-M-f") #'forward-sexp)
    (define-key map (kbd "C-M-b") #'backward-sexp)
    (define-key map (kbd "C-M-u") #'backward-up-list)
    (define-key map (kbd "C-M-d") #'down-list)
    (define-key map (kbd "C-M-n") #'forward-list)
    (define-key map (kbd "C-M-p") #'backward-list)
    map)
  "Keymap for structural navigation in Πρόλογος.")
```

### 7.3 Tests

- Type `(fn [x` then `<`: should auto-insert `>` and place cursor between.
- Slurp: with cursor in `(inc |) zero`, slurp pulls `zero` in → `(inc | zero)`.
- Barf: reverse of slurp.
- Raise: with cursor on `(inc zero)` inside `(double (inc zero))`, raise replaces parent → `(inc zero)`.
- Splice: unwraps surrounding brackets.
- Delete bracket: in strict mode, cannot delete single bracket.

---

## 8. Sprint 4: Tree-sitter Grammar Development (Weeks 4–8)

This sprint is the largest in the plan, split into two sub-sprints:

- **Sprint 4a (Weeks 4–6)**: S-expression mode grammar — the core tree-sitter grammar for `#lang prologos/sexp`.
- **Sprint 4b (Weeks 7–8)**: Significant whitespace mode — external scanner for INDENT/DEDENT tokens and grammar extensions for `#lang prologos`.

### 8.1 Sprint 4a Objective: S-expression Grammar (Weeks 4–6)

Write the core tree-sitter grammar for Πρόλογος S-expression syntax (`#lang prologos/sexp`). At the end of Sprint 4a, `tree-sitter parse file.prologos` produces a correct syntax tree for all test programs that use explicit S-expression syntax.

### 8.2 Sprint 4a Deliverables

**`tree-sitter-prologos/grammar.js`**: The core grammar definition (sexp mode).

```javascript
module.exports = grammar({
  name: 'prologos',

  extras: $ => [
    /\s+/,
    $.comment,
  ],

  rules: {
    source_file: $ => repeat($.top_level),

    top_level: $ => choice(
      $.definition,
      $.command,
      $.expression,
    ),

    // Top-level definitions
    definition: $ => choice(
      $.def_form,
      $.defn_form,
      $.deftype_form,
      $.defmacro_form,
      $.data_form,
      $.ns_form,
      $.require_form,
      $.provide_form,
    ),

    def_form: $ => seq('(', 'def',
      field('name', $.identifier),
      optional(field('type', $.type_annotation)),
      field('body', $.expression),
      ')'),

    defn_form: $ => seq('(', 'defn',
      field('name', $.identifier),
      repeat1(field('param', $.parameter)),
      optional(field('return_type', $.type_annotation)),
      field('body', $.expression),
      ')'),

    data_form: $ => seq('(', 'data',
      field('name', choice($.identifier, $.parameterized_type)),
      repeat(field('constructor', $.constructor_decl)),
      ')'),

    // Parameters
    parameter: $ => choice(
      seq('[', field('name', $.identifier),
       optional(field('mult', $.multiplicity)),
       optional(field('type', $.type_annotation)),
       ']'),
      $.identifier,
    ),

    multiplicity: $ => choice(':0', ':1', ':w'),

    type_annotation: $ => choice(
      seq('<', field('type', $.expression), '>'),
      seq(':', field('type', $.expression)),
    ),

    // Expressions
    expression: $ => choice(
      $.application,
      $.lambda,
      $.pi_type,
      $.sigma_type,
      $.match_expr,
      $.let_expr,
      $.if_expr,
      $.the_expr,
      $.list_form,
      $.identifier,
      $.number,
      $.string,
      $.boolean,
      $.hole,
    ),

    application: $ => seq('(',
      field('function', $.expression),
      repeat(field('argument', $.expression)),
      ')'),

    lambda: $ => seq('(', 'fn',
      repeat1(field('param', $.parameter)),
      field('body', $.expression),
      ')'),

    pi_type: $ => seq('(', choice('Pi', '->'),
      repeat1(field('param', choice($.parameter, $.expression))),
      field('codomain', $.expression),
      ')'),

    match_expr: $ => seq('(', choice('match', 'reduce'),
      field('scrutinee', $.expression),
      repeat1(field('arm', $.match_arm)),
      ')'),

    match_arm: $ => seq(
      field('pattern', $.pattern),
      '->',
      field('body', $.expression)),

    // Atoms
    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_!?*+\/.-]*/,
    number: $ => /[0-9]+/,
    string: $ => seq('"', repeat(choice(/[^"\\]/, /\\./)), '"'),
    boolean: $ => choice('true', 'false'),
    hole: $ => seq('?', $.identifier),
    comment: $ => seq(';', /.*/),
  }
});
```

**`tree-sitter-prologos/queries/highlights.scm`**: Highlighting queries.

```scheme
;; Keywords
["def" "defn" "deftype" "defmacro" "data" "ns" "require" "provide"] @keyword
["fn" "the" "the-fn" "let" "do" "if" "match" "reduce" "forall" "exists"] @keyword
["check" "eval" "infer"] @keyword.directive

;; Type constructors
["Pi" "Sigma" "Type" "Nat" "Bool" "Posit8" "Vec" "Fin" "Eq"] @type

;; Value constructors
["zero" "true" "false" "refl" "pair" "inc" "vnil" "vcons" "fzero" "fsuc" "posit8"] @constant

;; Eliminators
["natrec" "boolrec" "J" "first" "second" "vhead" "vtail" "vindex"] @function.builtin

;; Posit8 operations
["p8+" "p8-" "p8*" "p8/" "p8-neg" "p8-abs" "p8-sqrt" "p8-lt" "p8-le" "p8-from-nat" "p8-if-nar"] @function.builtin

;; Operators
"->" @operator

;; Definition names
(def_form name: (identifier) @function.definition)
(defn_form name: (identifier) @function.definition)
(data_form name: (identifier) @type.definition)
(deftype_form name: (identifier) @type.definition)
(defmacro_form name: (identifier) @function.macro)

;; QTT multiplicities
(multiplicity) @attribute

;; Holes
(hole) @warning

;; Comments
(comment) @comment

;; Strings
(string) @string

;; Numbers
(number) @number
```

**Test corpus** (`test/corpus/`): Test files covering all syntax constructs — definitions, functions, pattern matching, type annotations, multiplicities, data declarations, posit8 operations.

### 8.3 Sprint 4a Development Workflow

1. Install tree-sitter CLI: `npm install -g tree-sitter-cli`
2. Initialize grammar: `tree-sitter init-config` in `tree-sitter-prologos/`
3. Iterative development: edit `grammar.js` → `tree-sitter generate` → `tree-sitter parse test.prologos` → verify output
4. Write test cases in `test/corpus/` → `tree-sitter test`
5. Compile shared library: `tree-sitter build --wasm` (for browser) or system-specific build for Emacs

### 8.4 Sprint 4a Conflict Resolution

S-expression grammars have inherent ambiguities that tree-sitter resolves with precedence:
- `(f x y)` could be application or a grouping — resolved by treating `(...)` as application when the first element is an identifier.
- `<Nat>` could be comparison or type annotation — resolved by context (the grammar rules make `<>` valid only in annotation positions).
- `->` is both a keyword and an operator — resolved by treating it as a keyword in `Pi` forms and an operator in match arms.

### 8.5 Sprint 4b Objective: Significant Whitespace Mode (Weeks 7–8)

Extend the tree-sitter grammar to support the significant-whitespace syntax (`#lang prologos`). This requires an **external scanner** — a C function that the tree-sitter parser calls to produce synthetic INDENT and DEDENT tokens based on indentation changes. The reference implementation is Python's tree-sitter grammar (`tree-sitter-python/src/scanner.c`), which solves the same problem.

At the end of Sprint 4b, `tree-sitter parse file.prologos` produces correct syntax trees for **both** sexp and WS mode files, and the grammar auto-detects the active mode from the `#lang` directive.

### 8.6 Sprint 4b Deliverables

**`tree-sitter-prologos/src/scanner.c`**: External scanner for INDENT/DEDENT tokens.

The external scanner maintains a stack of indentation levels and emits tokens as follows:

```c
#include <tree_sitter/parser.h>
#include <string.h>
#include <stdlib.h>

enum TokenType {
  INDENT,
  DEDENT,
  NEWLINE,
  LANG_SEXP,
  LANG_WS,
};

typedef struct {
  int *indent_stack;
  int stack_size;
  int stack_capacity;
  bool ws_mode;
} Scanner;

// --- Lifecycle ---

void *tree_sitter_prologos_external_scanner_create(void) {
  Scanner *s = calloc(1, sizeof(Scanner));
  s->indent_stack = malloc(64 * sizeof(int));
  s->indent_stack[0] = 0;
  s->stack_size = 1;
  s->stack_capacity = 64;
  s->ws_mode = false;
  return s;
}

void tree_sitter_prologos_external_scanner_destroy(void *payload) {
  Scanner *s = payload;
  free(s->indent_stack);
  free(s);
}

// --- Serialization (for incremental re-parsing) ---

unsigned tree_sitter_prologos_external_scanner_serialize(
    void *payload, char *buffer) {
  Scanner *s = payload;
  unsigned offset = 0;
  buffer[offset++] = s->ws_mode ? 1 : 0;
  // Serialize indent stack (up to buffer limit)
  for (int i = 0; i < s->stack_size && offset < TREE_SITTER_SERIALIZATION_BUFFER_SIZE - 4; i++) {
    memcpy(buffer + offset, &s->indent_stack[i], sizeof(int));
    offset += sizeof(int);
  }
  return offset;
}

void tree_sitter_prologos_external_scanner_deserialize(
    void *payload, const char *buffer, unsigned length) {
  Scanner *s = payload;
  if (length == 0) {
    s->ws_mode = false;
    s->indent_stack[0] = 0;
    s->stack_size = 1;
    return;
  }
  unsigned offset = 0;
  s->ws_mode = buffer[offset++] != 0;
  s->stack_size = 0;
  while (offset + sizeof(int) <= length) {
    memcpy(&s->indent_stack[s->stack_size], buffer + offset, sizeof(int));
    s->stack_size++;
    offset += sizeof(int);
  }
}

// --- Scan logic ---
// The scanner detects #lang on the first line, then
// emits INDENT/DEDENT tokens at line boundaries when
// ws_mode is active. In sexp mode, no INDENT/DEDENT
// tokens are emitted and the grammar falls through to
// standard S-expression parsing.

bool tree_sitter_prologos_external_scanner_scan(
    void *payload, TSLexer *lexer, const bool *valid_symbols) {
  Scanner *s = payload;

  // ... (full implementation follows Python's scanner.c pattern)
  // Key logic:
  // 1. At start of file, detect #lang prologos vs #lang prologos/sexp
  // 2. At each newline in WS mode:
  //    a. Count leading whitespace on next line
  //    b. If indent > current level: emit INDENT, push to stack
  //    c. If indent < current level: emit DEDENT(s), pop from stack
  //    d. If indent == current level: emit NEWLINE
  // 3. At EOF: emit remaining DEDENTs to close all open levels

  return false; // placeholder — full implementation in code
}
```

**Grammar extensions for WS mode** (additions to `grammar.js`):

```javascript
module.exports = grammar({
  name: 'prologos',

  externals: $ => [
    $.indent,
    $.dedent,
    $.newline,
    $.lang_sexp,
    $.lang_ws,
  ],

  rules: {
    source_file: $ => seq(
      optional($.lang_directive),
      repeat($.top_level),
    ),

    // #lang detection
    lang_directive: $ => choice(
      seq('#lang', 'prologos', $.lang_ws),
      seq('#lang', 'prologos/sexp', $.lang_sexp),
    ),

    // WS mode: implicit grouping via indentation
    ws_block: $ => seq(
      $.indent,
      repeat1(choice($.ws_line, $.ws_block)),
      $.dedent,
    ),

    ws_line: $ => seq(
      repeat1($.expression),
      $.newline,
    ),

    // In WS mode, a top-level definition uses indentation
    // instead of parentheses:
    //
    //   defn double
    //     x <Nat>
    //     <Nat>
    //     match x
    //       zero    -> zero
    //       inc n   -> inc (inc (double n))
    //
    // The INDENT after "defn double" opens an implicit list,
    // and the DEDENT at the end closes it. Nested INDENTs
    // create nested implicit lists (deeper AST nodes).

    // ... (existing sexp rules remain unchanged)
  }
});
```

**`#lang` detection for dual-mode parsing.** The external scanner detects the `#lang` directive on the first line and sets its internal `ws_mode` flag. When `ws_mode` is false (sexp mode), the scanner never emits INDENT/DEDENT tokens, and the grammar falls through entirely to the S-expression rules from Sprint 4a. This means the sexp grammar works unchanged — WS mode is purely additive.

### 8.7 Sprint 4b Test Cases

The test corpus must include WS mode files alongside sexp mode files:

```
;; test/corpus/ws_mode_basic.txt
===
WS mode: simple function definition
===
#lang prologos

defn double
  x <Nat>
  <Nat>
  match x
    zero    -> zero
    inc n   -> inc (inc (double n))

---

(source_file
  (lang_directive)
  (definition
    (defn_form
      name: (identifier)
      (ws_block
        (ws_line (parameter (identifier) (type_annotation (identifier))))
        (ws_line (type_annotation (identifier)))
        (ws_line (match_expr
          scrutinee: (identifier)
          (ws_block
            (ws_line (match_arm pattern: (identifier) body: (identifier)))
            (ws_line (match_arm pattern: ...  body: ...)))))))))
```

```
;; test/corpus/ws_mode_data.txt
===
WS mode: algebraic data type
===
#lang prologos

data List A
  nil
  cons A (List A)

---

(source_file
  (lang_directive)
  (definition
    (data_form
      name: (parameterized_type (identifier) (identifier))
      (ws_block
        (ws_line (constructor_decl (identifier)))
        (ws_line (constructor_decl (identifier) (identifier) (application ...)))))))
```

### 8.8 Sprint 4b Risks and Mitigations

**Risk: External scanner complexity.** The external scanner is the most technically demanding component in the entire plan. Tree-sitter's incremental parsing requires the scanner to serialize and deserialize its state correctly, and bugs in the indent stack management cause cascading parse failures.

**Mitigation:** Start from Python's well-tested `scanner.c` and adapt it. Python has solved all the edge cases (mixed tabs/spaces, blank lines, continuation lines, EOF handling). Πρόλογος's WS mode is simpler than Python's because `()` grouping within lines is explicitly bracketed — only cross-line grouping uses indentation.

**Risk: Grammar conflicts between modes.** WS mode rules might create ambiguities with sexp mode rules.

**Mitigation:** The `#lang` detection sets `ws_mode` in the scanner before any content is parsed. In sexp mode, the scanner never emits INDENT/DEDENT, so WS-mode grammar rules never match. The two modes are effectively separate grammars sharing a common expression layer.

---

## 9. Sprint 5: prologos-ts-mode — Tree-sitter Emacs Integration (Week 9)

### 9.1 Objective

Create `prologos-ts-mode.el` that uses the tree-sitter grammar from Sprint 4 for accurate syntax highlighting, indentation, and navigation in Emacs 29+. The mode supports both sexp and WS mode files, detecting the `#lang` directive to configure mode-specific behavior (semantic vs. cosmetic indentation, INDENT/DEDENT-aware structural operations).

### 9.2 Deliverables

**`prologos-ts-mode.el`**: Tree-sitter-based major mode.

**Tree-sitter font-lock rules:**

```elisp
(defvar prologos-ts-font-lock-rules
  (treesit-font-lock-rules
   :language 'prologos
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'prologos
   :feature 'string
   '((string) @font-lock-string-face)

   :language 'prologos
   :feature 'keyword
   '(["def" "defn" "deftype" "defmacro" "data" "fn" "the"
      "let" "do" "if" "match" "reduce" "forall" "exists"
      "ns" "require" "provide" "check" "eval" "infer"]
     @font-lock-keyword-face)

   :language 'prologos
   :feature 'type
   '(["Pi" "Sigma" "Type" "Nat" "Bool" "Posit8" "Vec" "Fin" "Eq"]
     @font-lock-type-face)

   :language 'prologos
   :feature 'constant
   '(["zero" "true" "false" "refl" "pair" "inc" "vnil" "vcons"]
     @font-lock-constant-face
     (number) @font-lock-number-face)

   :language 'prologos
   :feature 'function
   '((def_form name: (identifier) @font-lock-function-name-face)
     (defn_form name: (identifier) @font-lock-function-name-face))

   :language 'prologos
   :feature 'definition
   '((data_form name: (identifier) @font-lock-type-face))

   :language 'prologos
   :feature 'multiplicity
   '((multiplicity) @prologos-multiplicity-face)

   :language 'prologos
   :feature 'hole
   '((hole) @prologos-hole-face))
  "Tree-sitter font-lock rules for Πρόλογος.")
```

**Tree-sitter indentation rules:**

```elisp
(defvar prologos-ts-indent-rules
  `((prologos
     ;; Top-level forms: no indentation
     ((node-is "source_file") column-0 0)
     ;; Body of definition forms: indent 2
     ((parent-is "def_form") parent-bol 2)
     ((parent-is "defn_form") parent-bol 2)
     ((parent-is "data_form") parent-bol 2)
     ;; Lambda body: indent 2
     ((parent-is "lambda") parent-bol 2)
     ;; Match arms: indent 2
     ((parent-is "match_expr") parent-bol 2)
     ;; Application arguments: align with first arg
     ((parent-is "application") first-sibling 0)
     ;; Default: indent 2 from parent
     (catch-all parent-bol 2)))
  "Tree-sitter indentation rules for Πρόλογος.")
```

**WS mode integration in prologos-ts-mode:**

In prologos-ts-mode, the `#lang` detection determines which indentation rules apply. When WS mode is active, tree-sitter indentation queries are configured to preserve semantic indentation rather than re-indenting:

```elisp
(defun prologos-ts--configure-for-lang-mode ()
  "Configure prologos-ts-mode based on detected #lang mode."
  (if prologos--ws-mode-p
      ;; WS mode: tree-sitter handles INDENT/DEDENT, indentation is semantic
      (progn
        (setq-local treesit-simple-indent-rules prologos-ts-ws-indent-rules)
        (setq-local indent-line-function #'prologos--ws-indent-line)
        (message "Πρόλογος: WS mode detected (#lang prologos)"))
    ;; Sexp mode: standard cosmetic indentation
    (setq-local treesit-simple-indent-rules prologos-ts-indent-rules)
    (message "Πρόλογος: sexp mode detected (#lang prologos/sexp)")))

(defvar prologos-ts-ws-indent-rules
  `((prologos
     ;; In WS mode, indentation is semantic — preserve it
     ((node-is "source_file") column-0 0)
     ;; ws_block children: maintain current indent
     ((parent-is "ws_block") parent-bol 2)
     ;; Everything else: maintain current indent
     (catch-all no-indent 0)))
  "Tree-sitter indentation rules for WS mode (semantic indentation).")
```

**Tree-sitter imenu settings:**

```elisp
(defvar prologos-ts-imenu-settings
  '(("Function" "\\`def_form\\'" nil nil)
    ("Function" "\\`defn_form\\'" nil nil)
    ("Type" "\\`data_form\\'" nil nil)
    ("Type" "\\`deftype_form\\'" nil nil)
    ("Macro" "\\`defmacro_form\\'" nil nil))
  "Tree-sitter imenu settings for Πρόλογος.")
```

---

## 10. Sprint 6: REPL Integration (Week 10)

### 10.1 Objective

Create comint-based REPL integration for interactive development. At the end of this sprint, the programmer can start a REPL, send expressions, and see results — all from within Emacs.

### 10.2 Deliverables

**`prologos-repl.el`**: REPL launcher and interaction functions.

**Core REPL commands:**

| Keybinding | Function | Description |
|---|---|---|
| `C-c C-z` | `prologos-repl` | Start or switch to REPL |
| `C-x C-e` | `prologos-eval-last-sexp` | Evaluate sexp before point |
| `C-c C-r` | `prologos-eval-region` | Evaluate selected region |
| `C-c C-k` | `prologos-eval-buffer` | Evaluate entire buffer |
| `C-c C-l` | `prologos-load-file` | Load current file into REPL |

**REPL process management:**

```elisp
(defcustom prologos-program "racket"
  "Path to the Πρόλογος interpreter.
For the prototype, this runs Racket with the Πρόλογος language module."
  :type 'string
  :group 'prologos)

(defcustom prologos-program-args '("-l" "prologos/repl")
  "Arguments passed to the Πρόλογος interpreter."
  :type '(repeat string)
  :group 'prologos)

(defun prologos-repl ()
  "Start or switch to the Πρόλογος REPL."
  (interactive)
  (let ((buffer (get-buffer "*Πρόλογος REPL*")))
    (if (and buffer (comint-check-proc buffer))
        (pop-to-buffer buffer)
      (let ((buf (apply #'make-comint-in-buffer
                        "prologos" nil prologos-program nil
                        prologos-program-args)))
        (with-current-buffer buf
          (prologos-repl-mode))
        (pop-to-buffer buf)))))
```

**REPL mode with completion:**

```elisp
(define-derived-mode prologos-repl-mode comint-mode "Πρόλογος REPL"
  "Major mode for the Πρόλογος REPL."
  :syntax-table prologos-mode-syntax-table
  (setq-local comint-prompt-regexp "^prologos> ")
  (setq-local comint-input-ignoredups t)
  (setq-local comint-input-ring-size 1000)
  (setq-local font-lock-defaults '(prologos-font-lock-keywords nil nil))
  (add-hook 'completion-at-point-functions
            #'prologos-completion-at-point nil t))
```

**Inline evaluation display** (inspired by CIDER):

```elisp
(defun prologos-eval-last-sexp ()
  "Evaluate the sexp before point and display result as overlay."
  (interactive)
  (let* ((end (point))
         (beg (save-excursion (backward-sexp) (point)))
         (sexp (buffer-substring-no-properties beg end)))
    (prologos--send-to-repl sexp
      (lambda (result)
        (prologos--display-inline-result result end)))))

(defun prologos--display-inline-result (result pos)
  "Display RESULT as an overlay at POS."
  (let ((ov (make-overlay pos pos)))
    (overlay-put ov 'after-string
                 (propertize (format " => %s" result)
                             'face 'font-lock-comment-face))
    (overlay-put ov 'prologos-result t)
    ;; Remove after next command
    (run-at-time 10 nil (lambda () (delete-overlay ov)))))
```

---

## 11. Sprint 7: Code Navigation — xref, imenu, which-function (Week 11)

### 11.1 Objective

Implement go-to-definition, find-references, and code outline navigation. At the end of this sprint, `M-.` jumps to a definition and `M-g i` shows a code outline.

### 11.2 Deliverables

**`prologos-xref.el`**: xref backend implementation.

The xref backend scans project files for definition forms and indexes them. For the prototype (single-file programs), this is a buffer-local scan. For multi-file projects, it scans all `.prologos` files in the project root.

```elisp
(defun prologos-xref-backend ()
  "Return the Πρόλογος xref backend."
  'prologos)

(cl-defmethod xref-backend-identifier-at-point ((_backend (eql prologos)))
  (thing-at-point 'symbol t))

(cl-defmethod xref-backend-definitions ((_backend (eql prologos)) identifier)
  (prologos--find-definitions identifier))

(cl-defmethod xref-backend-references ((_backend (eql prologos)) identifier)
  (prologos--find-references identifier))

(defun prologos--find-definitions (name)
  "Find definition of NAME across project files."
  (let ((results '())
        (pattern (format "(def\\(?:n\\|type\\|macro\\)?\\s-+%s\\b"
                        (regexp-quote name))))
    (dolist (file (prologos--project-files))
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (re-search-forward pattern nil t)
          (push (xref-make name
                  (xref-make-file-location file
                    (line-number-at-pos) 0))
                results))))
    (nreverse results)))
```

**imenu configuration** (for regex mode):

```elisp
(defvar prologos-imenu-generic-expression
  '(("Function" "^\\s-*(def\\(?:n\\)?\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Type" "^\\s-*(data\\s-+(\\([A-Za-z_][a-zA-Z0-9_]*\\)" 1)
    ("Type Alias" "^\\s-*(deftype\\s-+(\\([A-Za-z_][a-zA-Z0-9_]*\\)" 1)
    ("Macro" "^\\s-*(defmacro\\s-+(\\([A-Za-z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Namespace" "^\\s-*(ns\\s-+\\([a-zA-Z_][a-zA-Z0-9_./-]*\\)" 1))
  "Imenu entries for Πρόλογος mode.")
```

**which-function-mode**: Automatically works when imenu is configured — displays the current function name in the mode-line.

```elisp
(add-hook 'prologos-mode-hook #'which-function-mode)
```

---

## 12. Sprint 8: Inline Documentation and Completion (Week 12)

### 12.1 Objective

Display type signatures at point via eldoc, and provide completion for known identifiers and keywords.

### 12.2 Deliverables

**`prologos-eldoc.el`**: Inline documentation via eldoc.

The eldoc function displays the type signature of the identifier at point. For the prototype, this queries the REPL (using `(infer symbol)`) or uses a static database of built-in types.

```elisp
(defvar prologos--builtin-signatures
  '(("inc"     . "Nat → Nat")
    ("zero"    . "Nat")
    ("true"    . "Bool")
    ("false"   . "Bool")
    ("vnil"    . "∀A. Vec A 0")
    ("vcons"   . "∀A n. A → Vec A n → Vec A (n+1)")
    ("vhead"   . "∀A n. Vec A (n+1) → A")
    ("vtail"   . "∀A n. Vec A (n+1) → Vec A n")
    ("p8+"     . "Posit8 → Posit8 → Posit8")
    ("p8-"     . "Posit8 → Posit8 → Posit8")
    ("p8*"     . "Posit8 → Posit8 → Posit8")
    ("p8/"     . "Posit8 → Posit8 → Posit8")
    ("pair"    . "∀A B. A → B → Σ(A, B)")
    ("first"   . "∀A B. Σ(A, B) → A")
    ("second"  . "∀A B. Σ(A, B) → B")
    ("refl"    . "∀A (a : A). Eq A a a"))
  "Type signatures for built-in Πρόλογος identifiers.")

(defun prologos-eldoc-function (callback)
  "Provide type signature for symbol at point."
  (let* ((sym (thing-at-point 'symbol t))
         (sig (and sym (cdr (assoc sym prologos--builtin-signatures)))))
    (when sig
      (funcall callback
               (format "%s : %s" sym sig)
               :thing sym
               :face 'font-lock-function-name-face))))
```

**`prologos-completion.el`**: Completion at point.

```elisp
(defun prologos-completion-at-point ()
  "Completion-at-point function for Πρόλογος."
  (let ((bounds (bounds-of-thing-at-point 'symbol)))
    (when bounds
      (list (car bounds) (cdr bounds)
            (prologos--completion-candidates)
            :exclusive 'no
            :annotation-function #'prologos--completion-annotation
            :company-doc-buffer #'prologos--completion-doc))))

(defun prologos--completion-candidates ()
  "Return list of completion candidates."
  (append
   ;; Keywords
   '("def" "defn" "defmacro" "deftype" "data" "fn" "the"
     "let" "do" "if" "match" "reduce" "forall" "exists"
     "Pi" "Sigma" "Type" "Nat" "Bool" "Posit8" "Vec" "Fin" "Eq")
   ;; Constructors
   '("zero" "true" "false" "refl" "pair" "inc" "vnil" "vcons"
     "fzero" "fsuc" "posit8" "nothing" "just" "nil" "cons")
   ;; Buffer-local definitions
   (prologos--buffer-definitions)))

(defun prologos--buffer-definitions ()
  "Extract all definitions from current buffer."
  (let (defs)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              "(def\\(?:n\\|type\\|macro\\)?\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)"
              nil t)
        (push (match-string-no-properties 1) defs)))
    (nreverse defs)))
```

---

## 13. Sprint 9: On-the-Fly Error Checking (Week 13)

### 13.1 Objective

Display type errors and syntax errors as the programmer types, without requiring an explicit save-and-compile cycle.

### 13.2 Deliverables

**`prologos-flymake.el`**: Flymake backend for Πρόλογος.

The checker saves the buffer to a temporary file, runs the Πρόλογος type checker, and parses the error output into Flymake diagnostics.

```elisp
(defun prologos-flymake-checker (report-fn &rest _args)
  "Flymake checker for Πρόλογος."
  (let* ((source (current-buffer))
         (temp (make-temp-file "prologos" nil ".prologos")))
    (write-region (point-min) (point-max) temp nil 'silent)
    (let ((proc (make-process
                 :name "prologos-check"
                 :buffer (generate-new-buffer " *prologos-check*")
                 :command (list prologos-program
                               "-l" "prologos/check" temp)
                 :sentinel
                 (lambda (proc _event)
                   (when (eq (process-status proc) 'exit)
                     (let ((diags (prologos--parse-diagnostics
                                   (process-buffer proc) source)))
                       (funcall report-fn diags)
                       (kill-buffer (process-buffer proc))
                       (delete-file temp)))))))
      proc)))
```

**Error pattern parsing:**

The Πρόλογος compiler produces errors in a format inspired by Rust/Gleam (per NOTES.org). The parser extracts line number, column, severity, and message:

```elisp
(defun prologos--parse-diagnostics (output-buffer source-buffer)
  "Parse Πρόλογος compiler output into Flymake diagnostics."
  (let (diags)
    (with-current-buffer output-buffer
      (goto-char (point-min))
      (while (re-search-forward
              "^\\(?:error\\|warning\\)\\[E[0-9]+\\].*\n.*--> .*:\\([0-9]+\\):\\([0-9]+\\)"
              nil t)
        (let* ((line (string-to-number (match-string 1)))
               (col (string-to-number (match-string 2)))
               (severity (if (looking-back "error" (- (point) 20))
                            :error :warning))
               (msg (buffer-substring (line-beginning-position)
                                     (line-end-position))))
          (with-current-buffer source-buffer
            (save-excursion
              (goto-char (point-min))
              (forward-line (1- line))
              (forward-char (1- col))
              (push (flymake-make-diagnostic
                     source-buffer
                     (point) (min (1+ (point)) (line-end-position))
                     severity msg)
                    diags))))))
    (nreverse diags)))
```

---

## 14. Sprint 10: Interactive Dependent Type Features (Week 14)

### 14.1 Objective

Implement hole navigation, type-at-point, and case splitting — the core interactive features that make programming with dependent types practical.

### 14.2 Deliverables

**`prologos-holes.el`**: Interactive type-driven development commands.

**Hole navigation:**

```elisp
(defun prologos-next-hole ()
  "Jump to the next unsolved hole (?name) in the buffer."
  (interactive)
  (let ((pos (save-excursion
               (re-search-forward "\\?[a-zA-Z_][a-zA-Z0-9_]*" nil t))))
    (when pos
      (goto-char (match-beginning 0))
      (prologos--display-hole-info))))

(defun prologos-prev-hole ()
  "Jump to the previous unsolved hole."
  (interactive)
  (let ((pos (save-excursion
               (re-search-backward "\\?[a-zA-Z_][a-zA-Z0-9_]*" nil t))))
    (when pos
      (goto-char (match-beginning 0))
      (prologos--display-hole-info))))

;; Keybindings
(define-key prologos-mode-map (kbd "C-c C-f") #'prologos-next-hole)
(define-key prologos-mode-map (kbd "C-c C-b") #'prologos-prev-hole)
```

**Type at point:**

```elisp
(defun prologos-type-at-point ()
  "Display the type of the expression at point."
  (interactive)
  (let ((sexp (thing-at-point 'sexp t)))
    (when sexp
      (prologos--send-to-repl
       (format "(infer %s)" sexp)
       (lambda (result)
         (message "Type: %s" result))))))

(define-key prologos-mode-map (kbd "C-c C-t") #'prologos-type-at-point)
```

**Case split:**

```elisp
(defun prologos-case-split ()
  "Generate match arms for the type at point.
For a variable of type Nat, generates:
  (match var
    zero    -> ?body1
    (inc n) -> ?body2)"
  (interactive)
  (let* ((var (thing-at-point 'symbol t))
         (type (prologos--query-type var)))
    (when type
      (let ((arms (prologos--constructors-for-type type)))
        (delete-region (save-excursion (backward-sexp) (point)) (point))
        (insert (prologos--format-match var arms))))))
```

**Key bindings summary for dependent type interaction:**

| Keybinding | Function | Description |
|---|---|---|
| `C-c C-t` | `prologos-type-at-point` | Show type of expression |
| `C-c C-f` | `prologos-next-hole` | Jump to next hole |
| `C-c C-b` | `prologos-prev-hole` | Jump to previous hole |
| `C-c C-c` | `prologos-case-split` | Split variable into match arms |
| `C-c C-SPC` | `prologos-fill-hole` | Fill hole with inferred term |
| `C-c C-a` | `prologos-auto-fill` | Auto-fill hole by proof search |

---

## 15. Sprint 11: Testing, Polish, and Distribution (Weeks 15–16)

### 15.1 Objective

Write comprehensive tests, polish the user experience, create documentation, and prepare for MELPA distribution.

### 15.2 Deliverables

**ERT test suite:**

```elisp
(ert-deftest prologos-font-lock-keywords ()
  "Verify that def is highlighted as a keyword."
  (with-temp-buffer
    (prologos-mode)
    (insert "(def one <Nat> (inc zero))")
    (font-lock-ensure)
    (goto-char 2)
    (should (eq (get-text-property (point) 'face)
                'font-lock-keyword-face))))

(ert-deftest prologos-indent-defn ()
  "Verify defn body indentation."
  (with-temp-buffer
    (prologos-mode)
    (insert "(defn double [x <Nat>] <Nat>\n(match x\nzero -> zero\n(inc n) -> (inc (inc (double n)))))")
    (indent-region (point-min) (point-max))
    (goto-char (point-min))
    (forward-line 1)
    (should (= (current-indentation) 2))))

(ert-deftest prologos-bracket-balance ()
  "Verify all four bracket types are balanced."
  (with-temp-buffer
    (prologos-mode)
    (insert "(fn [x <Nat>] {y} x)")
    (goto-char (point-min))
    (should (= (scan-lists (point) 1 0) (point-max)))))
```

**Yasnippet templates** (Sprint 11 creates snippets for common forms):

```
# name: defn - function definition
# key: defn
# --
(defn ${1:name} [${2:x} <${3:Nat}>] <${4:Nat}>
  ${0:body})
```

```
# name: match - pattern match
# key: match
# --
(match ${1:scrutinee}
  ${2:pattern} -> ${3:body}
  ${0})
```

```
# name: data - algebraic data type
# key: data
# --
(data ${1:Name}
  ${2:constructor1}
  ${0:constructor2})
```

**Package header for MELPA:**

```elisp
;;; prologos-mode.el --- Major mode for the Πρόλογος language -*- lexical-binding: t; -*-

;; Author: Πρόλογος Team
;; Maintainer: Πρόλογος Team
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (smartparens "1.11.0"))
;; Homepage: https://github.com/prologos/prologos-mode
;; Keywords: languages lisp dependent-types
```

**README.md**: Installation instructions, feature overview, keybinding reference, configuration examples.

**Makefile** for testing:

```makefile
EMACS ?= emacs

test:
	$(EMACS) -Q --batch -l ert -l prologos-mode.el \
	  -l tests/prologos-font-lock-tests.el \
	  -l tests/prologos-indent-tests.el \
	  -f ert-run-tests-batch-and-exit

lint:
	$(EMACS) -Q --batch -l package-lint \
	  --eval "(package-lint-batch-and-exit)" prologos-mode.el
```

---

## 16. The Complete Feature Matrix

| Feature | Regex Mode (Emacs 28+) | Tree-sitter Mode (Emacs 29+) |
|---|---|---|
| Syntax highlighting | 5-level font-lock | Query-based, 8 features |
| Indentation | lisp-indent-function | treesit-simple-indent-rules |
| WS mode (whitespace) | `#lang` detect + semantic indent | External scanner + INDENT/DEDENT |
| Structural editing | smartparens/puni/paredit | smartparens + tree-sitter nodes |
| imenu navigation | Regex-based | treesit-simple-imenu-settings |
| xref go-to-definition | Regex scan | Tree-sitter node query |
| eldoc type display | Built-in DB + REPL query | Same |
| REPL integration | comint-mode | Same |
| Completion | CAPF (keywords + buffer defs) | Same + tree-sitter context |
| Flymake error checking | Process-based | Same |
| Hole navigation | Regex search | Tree-sitter node type |
| Type at point | REPL query | Same |
| Case split | Constructor DB | Tree-sitter aware |
| Pretty symbols | prettify-symbols-mode | Same |
| Bracket balancing | Syntax table (4 types) | Grammar-aware |

---

## 17. Cross-Cutting Concerns

### 17.1 Evil-Mode Compatibility

Many Emacs users use evil-mode (Vim emulation). The mode's keybindings should not conflict with evil's normal-state bindings. Use `C-c` prefix for mode-specific commands (safe in evil-mode) and provide an evil-leader integration option.

### 17.2 Significant Whitespace Mode Support

Both `#lang prologos/sexp` (explicit S-expressions) and `#lang prologos` (significant whitespace) are supported within the main sprint plan. The implementation touches multiple sprints:

- **Sprint 2 (Indentation)**: Detects the `#lang` directive and sets `prologos--ws-mode-p`. In WS mode, the indentation engine preserves semantic indentation rather than re-indenting cosmetically.
- **Sprint 4b (Tree-sitter Grammar)**: The external scanner (`scanner.c`) tracks indentation levels and emits INDENT/DEDENT tokens for WS mode. The grammar adds `ws_block` and `ws_line` rules for implicit grouping.
- **Sprint 5 (prologos-ts-mode)**: The Emacs integration configures different indentation and navigation behavior based on the detected `#lang` mode.

All `.prologos` files are handled by the same mode; the `#lang` directive on the first line determines whether sexp or WS parsing rules apply.

### 17.3 Performance Considerations

Font-lock performance is critical for large files. The regex-based mode uses `regexp-opt` with the `'symbols` flag (Emacs 24+) to prevent catastrophic backtracking. The tree-sitter mode inherently performs well due to incremental parsing. For the xref backend, file scanning should be cached and invalidated on file changes.

### 17.4 Multi-File Project Support

The xref backend and Flymake checker should support multi-file projects. Use `project.el` (Emacs 28+) to detect project roots via `.git` or a `prologos-project.edn` marker file.

```elisp
(defun prologos--project-root ()
  "Find the root of the current Πρόλογος project."
  (or (locate-dominating-file default-directory "prologos-project.edn")
      (locate-dominating-file default-directory ".git")
      default-directory))

(defun prologos--project-files ()
  "List all Πρόλογος source files in the project."
  (directory-files-recursively
   (prologos--project-root)
   "\\.prologos\\'" nil))
```

### 17.5 Integration with org-mode

For literate programming, register Πρόλογος as an org-babel language so code blocks can be evaluated:

```elisp
(defun org-babel-execute:prologos (body params)
  "Execute a Πρόλογος code block in org-mode."
  (prologos--eval-string body))

(add-to-list 'org-src-lang-modes '("prologos" . prologos))
```

### 17.6 Unicode and Display Considerations

Πρόλογος uses Unicode in its name (Πρόλογος) and operators (Π, Σ, →). The mode-line shows the Unicode name. The `prettify-symbols-mode` configuration translates ASCII to Unicode glyphs. Users can disable this via `(setq prologos-pretty-symbols nil)`.

---

## 18. Post-Sprint Work: LSP Server and Multi-Editor Support

### 18.1 Language Server Protocol

As Πρόλογος matures from prototype to production, an LSP server becomes the right architecture for editor support. LSP provides a single implementation shared across Emacs, VS Code, Vim/Neovim, and other editors.

The LSP server should expose:
- **textDocument/completion**: Context-aware completion.
- **textDocument/hover**: Type signatures and documentation.
- **textDocument/definition**: Go-to-definition.
- **textDocument/references**: Find all references.
- **textDocument/publishDiagnostics**: Error and warning diagnostics.
- **textDocument/formatting**: Auto-formatting.
- **textDocument/codeAction**: Case split, fill hole, refactor.

The Emacs mode integrates with the LSP server via `eglot` (built-in Emacs 29+):

```elisp
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(prologos-mode . ("prologos-lsp" "--stdio"))))
```

### 18.2 WS Mode Advanced Features

The Sprint 4b implementation covers the core WS mode grammar (INDENT/DEDENT tokenization, implicit grouping, `#lang` detection). Future extensions beyond the sprint plan include:

1. **Indentation-aware refactoring**: Commands that restructure WS-mode code while preserving semantic indentation — e.g., extracting a sub-expression into a named definition, or inlining a definition, with automatic indentation adjustment.
2. **Mixed-mode files**: Supporting files that embed sexp syntax within WS mode blocks (e.g., `()` grouping on a single line within an otherwise indentation-grouped file). The Sprint 4b grammar handles the basic case; advanced mixing may require additional grammar rules.
3. **Indentation diagnostics**: A Flymake extension that warns about inconsistent indentation (mixed tabs/spaces, unexpected indentation levels) in WS mode files.
4. **WS-to-sexp conversion**: An interactive command that converts a WS mode file to sexp mode (inserting explicit parentheses) or vice versa, useful for migration and debugging.

### 18.3 VS Code Extension

With tree-sitter and LSP, a VS Code extension requires minimal additional work:
- Tree-sitter grammar is shared (compiled to WASM for VS Code).
- LSP server is shared.
- TextMate grammar (`.tmLanguage.json`) provides fallback highlighting.
- VS Code-specific: extension manifest, launch configuration.

### 18.4 Neovim Support

Neovim natively supports tree-sitter and LSP. With the tree-sitter grammar and LSP server from this plan:
- Tree-sitter: Add to nvim-treesitter's parser list.
- LSP: Configure via nvim-lspconfig.
- Structural editing: conjure.nvim or custom Lua.

---

## 19. References

### Emacs Mode Development

Emacs Lisp Reference Manual. (2024). Major Modes. GNU Emacs 30.

Hendershott, G. (2024). racket-mode: Emacs Major Mode for Racket. github.com/greghendershott/racket-mode.

Zawinski, J. (1997). Font-Lock Mode. GNU Emacs 19.

### Structural Editing

Campbell, T. (2005). paredit.el: Minor Mode for Pseudo-Structural Editing. mumble.net/~campbell/emacs.

Goljer, M. (2023). smartparens: Dealing with Pairs in Emacs. github.com/Fuco1/smartparens.

Fan, J. (2024). puni: Parenthetical Universal Navigation and Interaction. github.com/AmaiKinono/puni.

### Tree-sitter

Brunsfeld, M. (2018). Tree-sitter: An Incremental Parsing System. tree-sitter.github.io.

Yuan, Y. (2023). Emacs 29 Tree-sitter Starter Guide. emacs-tree-sitter.github.io.

Hietala, J. (2024). Let's Create a Tree-sitter Grammar. jonashietala.se.

### Editor Support for Dependent Types

Norell, U. (2013). Interactive Programming with Dependent Types. agda.readthedocs.io. (agda-mode documentation)

Brady, E. (2021). Idris 2 IDE Protocol. idris2.readthedocs.io.

de Moura, L. & Ullrich, S. (2021). Lean 4 Language Server. github.com/leanprover/lean4.

### Language Server Protocol

Microsoft. (2024). Language Server Protocol Specification — 3.17. microsoft.github.io/language-server-protocol.

Tavaora, J. (2024). Eglot: The Emacs Client for LSP. joaotavora.github.io/eglot.

### REPL Integration

Batsov, B. (2024). CIDER: The Clojure Interactive Development Environment. docs.cider.mx.

Dominguez, J. (2024). Geiser: GNU Emacs and Scheme Talk to Each Other. nongnu.org/geiser.

Luís, S. (2024). SLY: Sylvester the Cat's Common Lisp IDE. github.com/joaotavora/sly.
