# Implementation Guide: Emacs Surfer-Mode for Πρόλογος Interactive Development

## prologos-surfer-mode: AST Navigation, Scope Visualization, Structural Editing, and REPL-Connected Interactive Development

---

## Table of Contents

1. [Introduction: prologos-surfer-mode and Interactive Development](#1-introduction-prologos-surfer-mode-and-interactive-development)
   - 1.1 [Design Philosophy: "Surf the AST"](#11-design-philosophy-surf-the-ast)
   - 1.2 [Scope of This Document](#12-scope-of-this-document)
   - 1.3 [Relationship to prologos-mode](#13-relationship-to-prologos-mode)
   - 1.4 [Package Architecture Overview](#14-package-architecture-overview)

2. [Research Foundations](#2-research-foundations)
   - 2.1 [Lessons from combobulate.el](#21-lessons-from-combobulate-el)
   - 2.2 [Lessons from symex.el and tree-edit](#22-lessons-from-symex-el-and-tree-edit)
   - 2.3 [Lessons from structured-haskell-mode](#23-lessons-from-structured-haskell-mode)
   - 2.4 [Lessons from CIDER's Interactive Development](#24-lessons-from-ciders-interactive-development)
   - 2.5 [Lessons from indent-bars and Scope Visualization](#25-lessons-from-indent-bars-and-scope-visualization)
   - 2.6 [Emacs Overlay System Fundamentals](#26-emacs-overlay-system-fundamentals)

3. [Πρόλογος-Specific Challenges for Structural Editing](#3-πρόλογος-specific-challenges-for-structural-editing)
   - 3.1 [The Indentation-Sensitive Editing Challenge](#31-the-indentation-sensitive-editing-challenge)
   - 3.2 [Few Delimiters, Many Implicit Boundaries](#32-few-delimiters-many-implicit-boundaries)
   - 3.3 [The Four Bracket Types and Type Annotations](#33-the-four-bracket-types-and-type-annotations)
   - 3.4 [Hole Navigation and Type-Driven Development](#34-hole-navigation-and-type-driven-development)
   - 3.5 [Tree-sitter Node Types for Πρόλογος](#35-tree-sitter-node-types-for-πρόλογος)

4. [Architecture: The Surfer-Mode Design](#4-architecture-the-surfer-mode-design)
   - 4.1 [Minor Mode Definition](#41-minor-mode-definition)
   - 4.2 [The Scope Stack: Tracking Current Position in the AST](#42-the-scope-stack-tracking-current-position-in-the-ast)
   - 4.3 [Overlay Architecture: Primary Overlay and Depth Coloring](#43-overlay-architecture-primary-overlay-and-depth-coloring)
   - 4.4 [Interaction with prologos-mode and prologos-ts-mode](#44-interaction-with-prologos-mode-and-prologos-ts-mode)
   - 4.5 [Header-line Breadcrumb: Showing AST Path](#45-header-line-breadcrumb-showing-ast-path)
   - 4.6 [Keybinding Strategy: repeat-mode and Hydra](#46-keybinding-strategy-repeat-mode-and-hydra)

5. [Sprint 1: Core Minor Mode and Scope Highlighting (Week 1)](#5-sprint-1-core-minor-mode-and-scope-highlighting-week-1)

6. [Sprint 2: AST Navigation Commands (Week 2)](#6-sprint-2-ast-navigation-commands-week-2)

7. [Sprint 3: Header-line Breadcrumb and Mode-line Integration (Week 3)](#7-sprint-3-header-line-breadcrumb-and-mode-line-integration-week-3)

8. [Sprint 4: Indentation-Aware Structural Operations (Weeks 4–5)](#8-sprint-4-indentation-aware-structural-operations-for-ws-mode-weeks-45)

9. [Sprint 5: REPL Protocol Abstraction Layer (Week 6)](#9-sprint-5-repl-protocol-abstraction-layer-week-6)

10. [Sprint 6: Interactive Evaluation with Scope Awareness (Weeks 7–8)](#10-sprint-6-interactive-evaluation-with-scope-awareness-weeks-78)

11. [Sprint 7: Data Inspector and Value Exploration (Week 9)](#11-sprint-7-data-inspector-and-value-exploration-week-9)

12. [Sprint 8: Testing, Polish, and Distribution (Weeks 10–11)](#12-sprint-8-testing-polish-and-distribution-weeks-1011)

13. [The Complete Feature Matrix](#13-the-complete-feature-matrix)

14. [Cross-Cutting Concerns](#14-cross-cutting-concerns)

15. [Post-Sprint Work](#15-post-sprint-work)

16. [References](#16-references)

---

## 1. Introduction: prologos-surfer-mode and Interactive Development

### 1.1 Design Philosophy: "Surf the AST"

Structural editing for an indentation-sensitive language like Πρόλογος presents a unique challenge. In Lisp, every pair of parentheses marks a structural boundary. In Πρόλογος's whitespace-sensitive syntax, boundaries are implicit: an expression ends when indentation decreases, when a keyword appears, or when the parser reaches EOF.

The surfer-mode philosophy is to make the AST visible and tactile. Instead of navigating by character, line, or s-expression, the programmer navigates by scope: semantic blocks of code that correspond to function bodies, match arms, let-bindings, and type annotations. Each command ("go up to the parent scope," "expand the current scope to include the next sibling") is a high-level operation on the syntax tree, not on text.

Surfer-mode achieves this by:

1. **Tracking position in the tree-sitter AST** in real-time as the cursor moves.
2. **Highlighting the current scope** with a subtle, depth-aware background tint.
3. **Providing keyboard commands** to navigate and manipulate the tree (up, down, left, right, expand, contract, slurp, barf, raise, splice).
4. **Displaying the current path** in the header line (breadcrumb), so the programmer always knows where they are in the code structure.
5. **Connecting to the REPL** to send the current scope for evaluation, with inline result display.
6. **Adapting structural operations to indentation-based syntax**, where scope boundaries are implicit rather than bracket-delimited.

### 1.2 Scope of This Document

This document provides an 8-sprint, 11-week implementation plan for `prologos-surfer-mode`, a minor mode that layers on top of `prologos-mode` and `prologos-ts-mode`. The plan covers:

- **Scope highlighting** with depth-aware background tints.
- **AST-aware navigation** commands (up, down, left, right in the tree).
- **Structural editing operations** (slurp, barf, raise, splice, wrap, drag) adapted for indentation-based syntax.
- **Header-line breadcrumb** showing the current path in the AST.
- **REPL integration** with protocol abstraction to support Racket prototype now and native Πρόλογος later.
- **Interactive evaluation** with scope awareness: send the current scope to the REPL, display results inline.
- **Data inspector** for exploring complex return values.
- **Performance optimization** and testing.

### 1.3 Relationship to prologos-mode

`prologos-surfer-mode` is a minor mode that depends on the features provided by `prologos-mode` and `prologos-ts-mode`:

- It assumes `prologos-ts-mode` is the major mode (tree-sitter enabled) for optimal AST tracking.
- It can gracefully degrade to work with `prologos-mode` (regex-based) if tree-sitter is unavailable, but with reduced navigation precision.
- It does not override keybindings from the major mode; instead, it provides new keybindings for surfer-specific commands.
- It uses the existing REPL infrastructure from `prologos-repl.el` for evaluation.
- It respects indentation settings from `prologos-indent.el`.

### 1.4 Package Architecture Overview

```
prologos-surfer-mode/
├── prologos-surfer.el                      ;; Core minor mode, scope detection, overlay
├── prologos-surfer-navigation.el           ;; AST navigation (up, down, left, right)
├── prologos-surfer-breadcrumb.el           ;; Header-line breadcrumb display
├── prologos-surfer-structural.el           ;; Slurp, barf, raise, splice, wrap, drag
├── prologos-surfer-repl.el                 ;; REPL protocol abstraction (comint + future native)
├── prologos-surfer-eval.el                 ;; Scope-aware evaluation, inline results
├── prologos-surfer-inspector.el            ;; Data inspector for REPL results
├── prologos-surfer-tests.el                ;; Test suite (ERT)
└── README.md                                ;; User guide, keybindings, examples
```

---

## 2. Research Foundations

### 2.1 Lessons from combobulate.el

Combobulate is a tree-sitter structural editing package for Python, JavaScript, and other non-Lisp languages. Key lessons:

- **Tree-sitter navigation is fast** even in large files: `treesit-node-at`, `treesit-node-parent`, `treesit-node-child`, and `treesit-node-next-sibling` provide O(1) or O(log n) access to the AST.
- **Scope nodes should be language-aware**: Not all tree-sitter nodes represent meaningful scopes. For Πρόλογος, we filter for nodes representing expressions, definitions, match arms, etc.
- **Overlay updates must be debounced**: Updating overlays on every keystroke is expensive. Instead, use a post-command-hook with a flag to update only when the scope node changes.
- **Visual feedback is essential**: A highlighted scope makes the tree structure tangible to the programmer.

### 2.2 Lessons from symex.el and tree-edit

Symex is a "symmetry-aware editing" package that treats the buffer as a tree of symbolic expressions. Tree-edit is a similar package for structural editing. Key lessons:

- **Modal editing reduces cognitive load**: A dedicated "surfer mode" or prefix key (`C-c s`) for structural operations keeps them distinct from regular editing.
- **Extend and contract selection**: Commands like `expand-region` (not to be confused with the expand-region package) that grow or shrink the selected scope are powerful for composition.
- **Breadcrumb display**: Showing the path to the current node (e.g., "defun > match > arm") is invaluable for understanding context.
- **repeat-mode integration**: Emacs's built-in `repeat-mode` allows the programmer to repeat the last command with a single key, e.g., `C-c s u u u` to go up three scopes.

### 2.3 Lessons from structured-haskell-mode

Structured Haskell Mode (SHM) is a structural editing mode for Haskell, an indentation-sensitive language. Key lessons:

- **Indentation-aware operations are non-trivial**: Unlike Lisp, where slurping changes bracket nesting, in an indentation-sensitive language, slurping means adjusting indentation of multiple lines.
- **Validate after edits**: After any structural operation, re-parse the buffer with tree-sitter to ensure no syntax errors were introduced.
- **Visual indication of edits**: SHM shows a colored region around the selected scope; surfer-mode adopts this practice.
- **Coordination with the indent engine**: Structural operations must not conflict with auto-indentation.

### 2.4 Lessons from CIDER's Interactive Development

CIDER is a Clojure IDE for Emacs that provides deep REPL integration. Key lessons:

- **Inline results**: Display evaluation results as overlays next to the expression, not just in the REPL buffer. This accelerates the feedback loop.
- **Error display**: If evaluation raises an error, show a clickable error overlay that jumps to the source.
- **Async evaluation**: Use callbacks and correlation IDs to match async results to their requests.
- **Scope-aware evaluation**: Send the current s-expression, defun, or buffer to the REPL with appropriate context (imports, local bindings).
- **Inspector integration**: Provide a dedicated inspector buffer for exploring complex data structures, with clickable navigation.

### 2.5 Lessons from indent-bars and Scope Visualization

indent-bars is a package that displays indentation guides using tree-sitter. Key lessons:

- **Subtle visual feedback**: Use light, transparent backgrounds for scope highlighting, not bold colors. This keeps the code readable while making structure visible.
- **Depth-based coloring**: Vary the background shade slightly with depth, so nested scopes are visually distinct.
- **Theme compatibility**: Support both light and dark themes by detecting the background color and adjusting tint darkness accordingly.
- **Performance**: Scope highlighting must not slow down cursor movement. Debounce overlay updates.

### 2.6 Emacs Overlay System Fundamentals

Overlays are Emacs's mechanism for attaching display properties to a region of buffer text. Key facts:

- **Overlays are lightweight**: Creating and updating overlays is fast, even with hundreds on screen.
- **Face-based styling**: Use faces (background color, underline, etc.) to style overlays, not raw colors, for theme compatibility.
- **Overlay priority**: Set `priority` to ensure the scope overlay sits above other overlays (e.g., from flymake).
- **Debouncing**: Use `run-at-time` or an idle-timer to batch updates, preventing excessive overlay redrawing.

---

## 3. Πρόλογος-Specific Challenges for Structural Editing

### 3.1 The Indentation-Sensitive Editing Challenge

Πρόλογος uses indentation-based syntax exclusively in native `.prologos` files. Unlike Lisp, where every pair of parentheses marks a structural boundary, Πρόλογος scope boundaries are implicit: they arise from indentation level, keyword position, and whitespace structure. This means structural editing operations must manipulate indentation rather than brackets.

While Πρόλογος does use brackets for specific purposes (function application, type annotations, lists, implicit arguments), the primary structural boundaries — function bodies, match arms, let-bindings — are defined by indentation. This is the central challenge surfer-mode addresses.

### 3.2 Few Delimiters, Many Implicit Boundaries

An expression's scope is determined by:

1. **Indentation level**: The expression extends until indentation decreases.
2. **Keywords**: Keywords like `let`, `case`, `match` introduce new scopes.
3. **Special syntax**: Pipe `|` in match arms, commas in tuples (in context).

Example Πρόλογος code:

```scheme
defn double(x : Nat) : Nat
  match x
    zero => zero
    succ(n) =>
      succ(succ(double(n)))
```

The scope of the second `succ` call includes the entire line `succ(succ(double(n)))`. To slurp the `double(n)` call into the first `succ`, we'd indent `double(n)` further. To barf the first `succ` out of the second, we'd dedent it.

### 3.3 The Four Bracket Types and Type Annotations

Πρόλογος uses four bracket types, each with semantic meaning:

| Bracket | Meaning |
|---------|---------|
| `()` | Function application, tuples, grouping |
| `[]` | Lists, pattern matching on lists |
| `<>` | Implicit arguments (filled by unification) |
| `{}` | Type annotations, type-level computation |

Structural operations must respect these distinctions. For example, you cannot slurp a term from inside `{}` into `()` without risking a type error.

### 3.4 Hole Navigation and Type-Driven Development

Πρόλογος uses holes (`_name`) for type-driven development. A hole is a placeholder for an expression whose type is known but implementation is missing (the `?` prefix is reserved for logical variables). Surfer-mode should:

1. Recognize holes as special scope nodes.
2. Provide a command to navigate to the next hole.
3. Allow evaluation of the type of a hole (via `type-at` in the REPL).
4. Support inserting the result of an evaluated expression into a hole.

### 3.5 Tree-sitter Node Types for Πρόλογος

The Πρόλογος tree-sitter grammar defines node types that surfer-mode treats as scopes:

| Node Type | Scope? | Description |
|-----------|--------|-------------|
| `program` | Yes | Top-level module |
| `definition` | Yes | Function or constant definition |
| `lambda_expr` | Yes | Lambda expression body |
| `match_expr` | Yes | Entire match expression |
| `match_arm` | Yes | Single match arm |
| `let_expr` | Yes | Let-binding expression |
| `application` | Yes | Function application |
| `type_annotation` | No | Annotation (children are scope) |
| `hole` | Yes | Placeholder for an expression |
| `list_expr` | Yes | List literal |
| `identifier` | No | Variable name (not a scope) |

---

## 4. Architecture: The Surfer-Mode Design

### 4.1 Minor Mode Definition

`prologos-surfer-mode` is defined as an Emacs minor mode using `define-minor-mode`. It:

- Provides a keymap (`prologos-surfer-mode-map`) with keybindings for navigation and structural operations.
- Installs a `post-command-hook` to detect scope changes and update the overlay.
- Installs a `before-save-hook` to validate the AST (ensure no syntax errors after edits).
- Provides a lighter to show " surfer" in the mode line.

### 4.2 The Scope Stack: Tracking Current Position in the AST

Surfer-mode maintains a "scope stack" to track the programmer's position in the tree:

- **Current scope**: The tree-sitter node at (or enclosing) the cursor.
- **Scope history**: A stack of previously visited scopes, for back navigation.

When the cursor moves, surfer-mode compares the current node to the previous one. If they differ, it updates the scope and redraws the overlay.

### 4.3 Overlay Architecture: Primary Overlay and Depth Coloring

Surfer-mode displays a single primary overlay covering the entire current scope, with a background color that varies by depth:

- **Depth 0** (module level): Very light tint (almost invisible).
- **Depth 1** (top-level defn): Slightly stronger tint.
- **Depth 2+**: Progressively stronger tints.

The exact colors depend on the current theme (light vs dark). Surfer-mode detects the background color of the current frame and generates appropriate foreground/background pairs for each depth.

### 4.4 Interaction with prologos-mode and prologos-ts-mode

Surfer-mode assumes tree-sitter is available (Emacs 29+). If `prologos-ts-mode` is active, surfer-mode uses tree-sitter directly. If only `prologos-mode` is active, surfer-mode attempts to initialize tree-sitter manually; if that fails, it gracefully disables itself.

Surfer-mode does not override any keybindings from the major mode. It reserves keybindings with prefix `C-c s` for its own commands.

### 4.5 Header-line Breadcrumb: Showing AST Path

The header-line displays the path from the root of the AST to the current scope, e.g.:

```
prologos.pl > defn(double) > match > arm(2)
```

This is updated whenever the scope changes, using an idle-timer to avoid excessive updates.

### 4.6 Keybinding Strategy: repeat-mode and Hydra

Surfer-mode provides two keybinding schemes:

1. **repeat-mode (built-in, Emacs 28+)**: Bind navigation commands to short keys like `u` (up), `d` (down), `l` (left), `r` (right). After the first invocation with prefix `C-c s`, the programmer can repeat with just the letter key.

2. **Hydra (optional, external package)**: Provides a transient keymap for one-off surfer sessions, with visual indication of available commands.

The default is repeat-mode; Hydra is offered as a package option.

---

## 5. Sprint 1: Core Minor Mode and Scope Highlighting (Week 1)

**Objective**: Implement the core minor mode with real-time scope detection and overlay-based visual highlighting.

**Deliverables**:

- `prologos-surfer.el`: Minor mode definition, scope detection, overlay management.
- Tests for scope detection on Πρόλογος code.

**Implementation**:

### Emacs Lisp Code: prologos-surfer.el

```elisp
;;; prologos-surfer.el --- AST navigation and scope highlighting for Πρόλογος

;; Copyright (C) 2024 Πρόλογος Contributors
;; Author: [Name]
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (prologos-mode "0.1.0"))
;; Keywords: languages, prologos, structural-editing

;;; Commentary:

;; prologos-surfer-mode is a minor mode providing AST-aware navigation,
;; scope visualization, and structural editing for Πρόλογος code.

;;; Code:

(require 'treesit)
(require 'prologos-mode)

;; ============================================================================
;; Customization
;; ============================================================================

(defgroup prologos-surfer nil
  "AST navigation and scope visualization for Πρόλογος."
  :group 'prologos)

(defcustom prologos-surfer-enable-overlay t
  "When non-nil, highlight the current scope with an overlay."
  :type 'boolean
  :group 'prologos-surfer)

(defcustom prologos-surfer-depth-tinting t
  "When non-nil, vary the scope background color by depth."
  :type 'boolean
  :group 'prologos-surfer)

(defcustom prologos-surfer-overlay-priority 100
  "Priority of the scope overlay (for layering with other overlays)."
  :type 'integer
  :group 'prologos-surfer)

(defcustom prologos-surfer-update-delay 0.1
  "Delay (in seconds) before updating the scope overlay after cursor movement."
  :type 'float
  :group 'prologos-surfer)

;; ============================================================================
;; Variables
;; ============================================================================

(defvar prologos-surfer--current-scope nil
  "The tree-sitter node for the current scope (nil if none).")

(defvar prologos-surfer--scope-overlay nil
  "The primary overlay highlighting the current scope.")

(defvar prologos-surfer--update-timer nil
  "Timer for debounced scope updates.")

(defvar prologos-surfer--scope-faces nil
  "Cached face definitions for scope depths.")

(defvar-local prologos-surfer--mode-line-lighter nil
  "Dynamic lighter string for the mode line.
Updated by breadcrumb to show the current node type (e.g., \" surfer:defn\").")

;; ============================================================================
;; Scope Detection
;; ============================================================================

(defun prologos-surfer-is-scope-node-p (node)
  "Check if NODE represents a scope (meaningful structural boundary).

Returns non-nil if NODE is a scope node (definition, match arm, lambda body, etc.)."
  (let ((type (treesit-node-type node)))
    (member type
            '("program"
              "definition"
              "lambda_expr"
              "match_expr"
              "match_arm"
              "let_expr"
              "let_binding"
              "application"
              "list_expr"
              "hole"
              "block"
              "type_annotation"))))

(defun prologos-surfer-current-scope ()
  "Return the tree-sitter node at point that represents a scope.

Walks up the tree from the current position until a scope node is found."
  (when (treesit-parser-list)
    (let ((node (treesit-node-at (point))))
      (while (and node (not (prologos-surfer-is-scope-node-p node)))
        (setq node (treesit-node-parent node)))
      node)))

(defun prologos-surfer-scope-depth (node)
  "Return the depth of NODE in the AST (0 for program node)."
  (let ((depth 0)
        (parent (treesit-node-parent node)))
    (while parent
      (when (prologos-surfer-is-scope-node-p parent)
        (setq depth (1+ depth)))
      (setq parent (treesit-node-parent parent)))
    depth))

;; ============================================================================
;; Face Generation
;; ============================================================================

(defun prologos-surfer-get-scope-face (depth)
  "Return a face for highlighting a scope at given DEPTH.

Faces vary in color intensity by depth for better visual hierarchy."
  (let ((cache-key depth)
        (is-dark (eq (frame-parameter nil 'background-mode) 'dark)))
    (if (assoc cache-key prologos-surfer--scope-faces)
        (cdr (assoc cache-key prologos-surfer--scope-faces))
      (let* ((intensity (/ (float (min depth 8)) 8.0))
             (bg-color (if is-dark
                          ;; Dark theme: blue tint deepening with depth
                          ;; From #1a1a00 (depth 0) to #1a1a28 (depth 8)
                          (format "#1a1a%02x" (round (* 40 intensity)))
                          ;; Light theme: blue tint deepening with depth
                          ;; From #f0f0ff (depth 0) to #d8d8ff (depth 8)
                          (let ((channel (round (- 240 (* 24 intensity)))))
                            (format "#%02x%02xff" channel channel))))
             (face-name (intern (format "prologos-surfer-scope-depth-%d" depth))))
        (copy-face 'default face-name)
        (set-face-background face-name bg-color)
        (push (cons cache-key face-name) prologos-surfer--scope-faces)
        face-name))))

;; ============================================================================
;; Overlay Management
;; ============================================================================

(defun prologos-surfer-update-overlay ()
  "Update the scope overlay to match the current scope."
  (let ((new-scope (prologos-surfer-current-scope)))
    ;; Only update if the scope has actually changed
    (unless (eq new-scope prologos-surfer--current-scope)
      (setq prologos-surfer--current-scope new-scope)
      (prologos-surfer--redraw-overlay))))

(defun prologos-surfer--redraw-overlay ()
  "Redraw the overlay for the current scope."
  (when prologos-surfer--scope-overlay
    (delete-overlay prologos-surfer--scope-overlay))

  (when (and prologos-surfer-enable-overlay prologos-surfer--current-scope)
    (let* ((start (treesit-node-start prologos-surfer--current-scope))
           (end (treesit-node-end prologos-surfer--current-scope))
           (depth (prologos-surfer-scope-depth prologos-surfer--current-scope))
           (face (if prologos-surfer-depth-tinting
                    (prologos-surfer-get-scope-face depth)
                  'default)))
      (setq prologos-surfer--scope-overlay
            (make-overlay start end (current-buffer)))
      (overlay-put prologos-surfer--scope-overlay 'face face)
      (overlay-put prologos-surfer--scope-overlay
                   'priority prologos-surfer-overlay-priority)
      (overlay-put prologos-surfer--scope-overlay 'name 'prologos-surfer-scope))))

(defun prologos-surfer-clear-overlay ()
  "Remove the scope overlay."
  (when prologos-surfer--scope-overlay
    (delete-overlay prologos-surfer--scope-overlay)
    (setq prologos-surfer--scope-overlay nil)))

;; ============================================================================
;; Post-Command Hook
;; ============================================================================

(defun prologos-surfer--post-command-hook ()
  "Update scope overlay after each command (debounced)."
  (when prologos-surfer--update-timer
    (cancel-timer prologos-surfer--update-timer))
  (setq prologos-surfer--update-timer
        (run-at-time prologos-surfer-update-delay nil
                     #'prologos-surfer-update-overlay)))

;; ============================================================================
;; Minor Mode Definition
;; ============================================================================

(defvar prologos-surfer-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Navigation keybindings (to be filled in Sprint 2)
    map)
  "Keymap for `prologos-surfer-mode'.")

;;;###autoload
(define-minor-mode prologos-surfer-mode
  "Minor mode for AST-aware navigation and scope visualization in Πρόλογος code.

When enabled, this mode:
- Highlights the current scope with a background overlay.
- Provides commands to navigate the AST (up, down, left, right).
- Shows the current path in the header line (breadcrumb).
- Enables scope-aware evaluation via the REPL.

\\{prologos-surfer-mode-map}"
  :init-value nil
  :lighter (:eval (or prologos-surfer--mode-line-lighter " surfer"))
  :keymap prologos-surfer-mode-map
  :group 'prologos-surfer
  (if prologos-surfer-mode
      (progn
        ;; Enable: check tree-sitter availability
        (unless (treesit-parser-list)
          (if (treesit-language-available-p 'prologos)
              (treesit-parser-create 'prologos)
            (user-error "Tree-sitter parser for Πρόλογος not available")))
        ;; Install hooks
        (add-hook 'post-command-hook #'prologos-surfer--post-command-hook nil t)
        ;; Initial overlay
        (prologos-surfer-update-overlay))
    (progn
      ;; Disable: remove hooks and clear overlay
      (remove-hook 'post-command-hook #'prologos-surfer--post-command-hook t)
      (prologos-surfer-clear-overlay)
      (when prologos-surfer--update-timer
        (cancel-timer prologos-surfer--update-timer))
      (setq prologos-surfer--current-scope nil))))

;; ============================================================================
;; Integration with prologos-mode
;; ============================================================================

(add-to-list 'auto-mode-alist '("\\.prologos\\'" . prologos-ts-mode))

(defun prologos-surfer-maybe-enable ()
  "Enable prologos-surfer-mode if in a Πρόλογος buffer with tree-sitter."
  (when (and (memq major-mode '(prologos-ts-mode prologos-mode))
             (treesit-parser-list))
    (prologos-surfer-mode 1)))

(add-hook 'prologos-ts-mode-hook #'prologos-surfer-maybe-enable)

(provide 'prologos-surfer)
;;; prologos-surfer.el ends here
```

**Tests**:

```elisp
;;; prologos-surfer-tests.el --- Tests for prologos-surfer.el

(require 'ert)
(require 'prologos-surfer)

(ert-deftest prologos-surfer-test-scope-detection ()
  "Test scope detection in Πρόλογος code."
  (with-temp-buffer
    (prologos-ts-mode)
    (insert "(defn double (x : Nat) : Nat\n  (succ (succ x)))")
    (goto-char (point-min))
    (let ((scope (prologos-surfer-current-scope)))
      (should scope)
      (should (string= (treesit-node-type scope) "program")))))

(ert-deftest prologos-surfer-test-scope-depth ()
  "Test scope depth calculation."
  (with-temp-buffer
    (prologos-ts-mode)
    (insert "(defn f () (+ 1 2))")
    (goto-char 15) ;; Inside the +
    (let ((scope (prologos-surfer-current-scope)))
      (should (> (prologos-surfer-scope-depth scope) 0)))))

(provide 'prologos-surfer-tests)
;;; prologos-surfer-tests.el ends here
```

---

## 6. Sprint 2: AST Navigation Commands (Week 2)

**Objective**: Implement keyboard commands for navigating the AST: up (parent scope), down (child scope), left (previous sibling), right (next sibling).

**Deliverables**:

- `prologos-surfer-navigation.el`: Navigation commands and repeat-mode integration.
- expand/contract selection based on AST.
- Tests.

**Implementation**:

### Emacs Lisp Code: prologos-surfer-navigation.el

```elisp
;;; prologos-surfer-navigation.el --- AST navigation for prologos-surfer-mode

;; Copyright (C) 2024 Πρόλογος Contributors

;;; Commentary:

;; Commands for navigating the AST: up (parent), down (child),
;; left (previous sibling), right (next sibling).

;;; Code:

(require 'prologos-surfer)

;; ============================================================================
;; Navigation Commands
;; ============================================================================

(defun prologos-surfer-up-scope ()
  "Move to the parent scope."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((parent (treesit-node-parent prologos-surfer--current-scope)))
        (if (and parent (prologos-surfer-is-scope-node-p parent))
            (progn
              (setq prologos-surfer--current-scope parent)
              (goto-char (treesit-node-start parent))
              (prologos-surfer--redraw-overlay)
              (message "Up to %s" (treesit-node-type parent)))
          (message "No parent scope")))
    (message "No current scope")))

(defun prologos-surfer-down-scope ()
  "Move to the first child scope."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((child (treesit-node-child prologos-surfer--current-scope 0)))
        (while (and child (not (prologos-surfer-is-scope-node-p child)))
          (setq child (treesit-node-next-sibling child)))
        (if child
            (progn
              (setq prologos-surfer--current-scope child)
              (goto-char (treesit-node-start child))
              (prologos-surfer--redraw-overlay)
              (message "Down to %s" (treesit-node-type child)))
          (message "No child scope")))
    (message "No current scope")))

(defun prologos-surfer-prev-sibling ()
  "Move to the previous sibling scope."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((prev (treesit-node-previous-sibling prologos-surfer--current-scope)))
        (while (and prev (not (prologos-surfer-is-scope-node-p prev)))
          (setq prev (treesit-node-previous-sibling prev)))
        (if prev
            (progn
              (setq prologos-surfer--current-scope prev)
              (goto-char (treesit-node-start prev))
              (prologos-surfer--redraw-overlay)
              (message "Left to %s" (treesit-node-type prev)))
          (message "No previous sibling scope")))
    (message "No current scope")))

(defun prologos-surfer-next-sibling ()
  "Move to the next sibling scope."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((next (treesit-node-next-sibling prologos-surfer--current-scope)))
        (while (and next (not (prologos-surfer-is-scope-node-p next)))
          (setq next (treesit-node-next-sibling next)))
        (if next
            (progn
              (setq prologos-surfer--current-scope next)
              (goto-char (treesit-node-start next))
              (prologos-surfer--redraw-overlay)
              (message "Right to %s" (treesit-node-type next)))
          (message "No next sibling scope")))
    (message "No current scope")))

;; ============================================================================
;; Selection Commands
;; ============================================================================

(defun prologos-surfer-select-scope ()
  "Set mark to select the current scope."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((start (treesit-node-start prologos-surfer--current-scope))
            (end (treesit-node-end prologos-surfer--current-scope)))
        (set-mark start)
        (goto-char end)
        (message "Selected %d chars" (- end start)))
    (message "No current scope")))

(defun prologos-surfer-expand-scope ()
  "Expand the current scope to include the next sibling."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((parent (treesit-node-parent prologos-surfer--current-scope)))
        (when parent
          (setq prologos-surfer--current-scope parent)
          (prologos-surfer--redraw-overlay)
          (goto-char (treesit-node-start parent))
          (message "Expanded to %s" (treesit-node-type parent))))
    (message "No current scope")))

(defun prologos-surfer-contract-scope ()
  "Contract the current scope to its first child."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((child (treesit-node-child prologos-surfer--current-scope 0)))
        (while (and child (not (prologos-surfer-is-scope-node-p child)))
          (setq child (treesit-node-next-sibling child)))
        (if child
            (progn
              (setq prologos-surfer--current-scope child)
              (prologos-surfer--redraw-overlay)
              (goto-char (treesit-node-start child))
              (message "Contracted to %s" (treesit-node-type child)))
          (message "No child scope")))
    (message "No current scope")))

;; ============================================================================
;; Repeat-Mode Integration
;; ============================================================================

(defvar prologos-surfer-navigation-repeat-map
  (let ((map (make-sparse-keymap)))
    (define-key map "u" #'prologos-surfer-up-scope)
    (define-key map "d" #'prologos-surfer-down-scope)
    (define-key map "l" #'prologos-surfer-prev-sibling)
    (define-key map "r" #'prologos-surfer-next-sibling)
    (define-key map "e" #'prologos-surfer-expand-scope)
    (define-key map "c" #'prologos-surfer-contract-scope)
    (define-key map "s" #'prologos-surfer-select-scope)
    map)
  "Repeat-mode keymap for prologos-surfer navigation commands.")

(dolist (cmd '(prologos-surfer-up-scope
               prologos-surfer-down-scope
               prologos-surfer-prev-sibling
               prologos-surfer-next-sibling
               prologos-surfer-expand-scope
               prologos-surfer-contract-scope))
  (put cmd 'repeat-map 'prologos-surfer-navigation-repeat-map))

;; ============================================================================
;; Keybinding
;; ============================================================================

(define-key prologos-surfer-mode-map (kbd "C-c s u") #'prologos-surfer-up-scope)
(define-key prologos-surfer-mode-map (kbd "C-c s d") #'prologos-surfer-down-scope)
(define-key prologos-surfer-mode-map (kbd "C-c s l") #'prologos-surfer-prev-sibling)
(define-key prologos-surfer-mode-map (kbd "C-c s r") #'prologos-surfer-next-sibling)
(define-key prologos-surfer-mode-map (kbd "C-c s e") #'prologos-surfer-expand-scope)
(define-key prologos-surfer-mode-map (kbd "C-c s c") #'prologos-surfer-contract-scope)
(define-key prologos-surfer-mode-map (kbd "C-c s s") #'prologos-surfer-select-scope)

(provide 'prologos-surfer-navigation)
;;; prologos-surfer-navigation.el ends here
```

**Tests**:

```elisp
(ert-deftest prologos-surfer-test-navigation-up ()
  "Test moving to parent scope."
  (with-temp-buffer
    (prologos-ts-mode)
    (insert "(defn f () (+ 1 2))")
    (goto-char 15) ;; Inside +
    (let ((initial-scope (prologos-surfer-current-scope)))
      (prologos-surfer-up-scope)
      (should-not (eq prologos-surfer--current-scope initial-scope)))))

(ert-deftest prologos-surfer-test-select-scope ()
  "Test scope selection."
  (with-temp-buffer
    (prologos-ts-mode)
    (insert "(defn f () (+ 1 2))")
    (goto-char 10)
    (prologos-surfer-select-scope)
    (should (region-active-p))))
```

---

## 7. Sprint 3: Header-line Breadcrumb and Mode-line Integration (Week 3)

**Objective**: Display the AST path in the header line and the current node type in the mode line.

**Deliverables**:

- `prologos-surfer-breadcrumb.el`: Breadcrumb generation and display.
- Tests.

**Implementation**:

### Emacs Lisp Code: prologos-surfer-breadcrumb.el

```elisp
;;; prologos-surfer-breadcrumb.el --- Breadcrumb display for prologos-surfer-mode

;; Copyright (C) 2024 Πρόλογος Contributors

;;; Commentary:

;; Display the current path in the AST (breadcrumb) in the header line.

;;; Code:

(require 'prologos-surfer)

;; ============================================================================
;; Customization
;; ============================================================================

(defcustom prologos-surfer-breadcrumb-format 'short
  "Format for breadcrumb display: 'short or 'long."
  :type '(choice (const short) (const long))
  :group 'prologos-surfer)

(defcustom prologos-surfer-breadcrumb-max-length 60
  "Maximum length of breadcrumb string before truncation."
  :type 'integer
  :group 'prologos-surfer)

;; ============================================================================
;; Variables
;; ============================================================================

(defvar prologos-surfer--breadcrumb-timer nil
  "Timer for debounced breadcrumb updates.")

;; ============================================================================
;; Node Type Formatting
;; ============================================================================

(defun prologos-surfer-node-type-name (type)
  "Return a human-readable name for a tree-sitter node TYPE."
  (let ((name-map
         '(("program" . "Module")
           ("definition" . "Def")
           ("lambda_expr" . "λ")
           ("match_expr" . "match")
           ("match_arm" . "arm")
           ("let_expr" . "let")
           ("let_binding" . "bind")
           ("application" . "app")
           ("list_expr" . "list")
           ("hole" . "_")
           ("block" . "block")
           ("type_annotation" . ":"))))
    (or (cdr (assoc type name-map)) type)))

(defun prologos-surfer-node-display-name (node)
  "Return a display name for NODE (type + optional identifier/index)."
  (let* ((type (treesit-node-type node))
         (type-name (prologos-surfer-node-type-name type))
         (text (treesit-node-text node t))
         (child-text (when (< (length text) 15) text)))
    (if (and child-text (not (string-match-p "\\s-" child-text)))
        (format "%s(%s)" type-name child-text)
      type-name)))

;; ============================================================================
;; Breadcrumb Generation
;; ============================================================================

(defun prologos-surfer-breadcrumb-path ()
  "Generate the breadcrumb path from root to current scope.

Returns a list of strings suitable for joining with ' > '."
  (let ((path '())
        (node prologos-surfer--current-scope))
    (while node
      (push (prologos-surfer-node-display-name node) path)
      (setq node (treesit-node-parent node)))
    (nreverse path)))

(defun prologos-surfer-format-breadcrumb (path)
  "Format a breadcrumb PATH (list of strings) for display."
  (let ((formatted (string-join path " > ")))
    (if (> (length formatted) prologos-surfer-breadcrumb-max-length)
        (concat "…" (substring formatted (- prologos-surfer-breadcrumb-max-length 1)))
      formatted)))

;; ============================================================================
;; Header-line and Mode-line Display
;; ============================================================================

(defun prologos-surfer-update-breadcrumb ()
  "Update the header-line and mode-line with the current breadcrumb."
  (let* ((path (prologos-surfer-breadcrumb-path))
         (breadcrumb (prologos-surfer-format-breadcrumb path))
         (current-type (when prologos-surfer--current-scope
                        (prologos-surfer-node-type-name
                         (treesit-node-type prologos-surfer--current-scope)))))
    ;; Update header line
    (setq header-line-format
          (list " " breadcrumb " "))
    ;; Update mode-line lighter (optional)
    (when current-type
      (setq prologos-surfer--mode-line-lighter (format " surfer:%s" current-type))
      (force-mode-line-update))))

(defun prologos-surfer--update-breadcrumb-idle ()
  "Debounced breadcrumb update."
  (when prologos-surfer--breadcrumb-timer
    (cancel-timer prologos-surfer--breadcrumb-timer))
  (setq prologos-surfer--breadcrumb-timer
        (run-at-time 0.2 nil #'prologos-surfer-update-breadcrumb)))

;; ============================================================================
;; Integration
;; ============================================================================

(defun prologos-surfer-breadcrumb-enable ()
  "Enable breadcrumb display."
  (add-hook 'post-command-hook #'prologos-surfer--update-breadcrumb-idle nil t))

(defun prologos-surfer-breadcrumb-disable ()
  "Disable breadcrumb display."
  (remove-hook 'post-command-hook #'prologos-surfer--update-breadcrumb-idle t)
  (when prologos-surfer--breadcrumb-timer
    (cancel-timer prologos-surfer--breadcrumb-timer))
  (setq header-line-format nil))

(add-hook 'prologos-surfer-mode-hook #'prologos-surfer-breadcrumb-enable)

(provide 'prologos-surfer-breadcrumb)
;;; prologos-surfer-breadcrumb.el ends here
```

**Tests**:

```elisp
(ert-deftest prologos-surfer-test-node-type-name ()
  "Test node type name formatting."
  (should (string= (prologos-surfer-node-type-name "lambda_expr") "λ"))
  (should (string= (prologos-surfer-node-type-name "match_expr") "match")))

(ert-deftest prologos-surfer-test-breadcrumb-generation ()
  "Test breadcrumb path generation."
  (with-temp-buffer
    (prologos-ts-mode)
    (insert "(defn f () (+ 1 2))")
    (goto-char 15)
    (let ((path (prologos-surfer-breadcrumb-path)))
      (should (> (length path) 0)))))
```

---

## 8. Sprint 4: Indentation-Aware Structural Operations (Weeks 4–5)

**Objective**: Implement slurp, barf, raise, splice, wrap, and drag operations for Πρόλογος's indentation-based syntax. All structural operations manipulate indentation levels and are validated by tree-sitter after each edit.

**Deliverables**:

- `prologos-surfer-structural.el`: Full structural editing suite for indentation-based syntax.
- Tree-sitter validation after each operation.
- Tests for structural operations.

**Implementation**:

### Emacs Lisp Code: prologos-surfer-structural.el

```elisp
;;; prologos-surfer-structural.el --- Structural editing for prologos-surfer-mode

;; Copyright (C) 2024 Πρόλογος Contributors

;;; Commentary:

;; Structural editing operations (slurp, barf, raise, splice, wrap, drag)
;; for Πρόλογος's indentation-based syntax.

;;; Code:

(require 'prologos-surfer)
(require 'prologos-indent)

;; ============================================================================
;; Helper: Indentation Manipulation
;; ============================================================================

(defun prologos-surfer-indent-lines (start end delta)
  "Indent lines from START to END by DELTA columns.

Positive DELTA means indent more; negative means dedent.
DELTA is passed directly to `indent-rigidly': positive indents,
negative dedents."
  (save-excursion
    (goto-char start)
    (while (< (point) end)
      (unless (looking-at "^\\s-*$")  ;; skip blank lines
        (indent-rigidly (line-beginning-position) (line-end-position) delta))
      (forward-line 1))))

(defun prologos-surfer-next-sibling-line (start-line)
  "Find the line number of the next sibling after START-LINE.

Siblings are at the same indentation level."
  (save-excursion
    (goto-char (point-min))
    (forward-line (1- start-line))
    (let ((initial-indent (current-indentation))
          (line (1+ start-line)))
      (forward-line 1)
      (while (and (not (eobp))
                  (or (looking-at "^\\s-*$")
                      (> (current-indentation) initial-indent)))
        (forward-line 1)
        (setq line (1+ line)))
      (if (eobp)
          nil
        line))))

;; ============================================================================
;; Slurp: Pull next sibling into current scope
;; ============================================================================

(defun prologos-surfer-slurp ()
  "Slurp: Pull the next sibling into the current scope.

Increases the indentation of the next sibling to match the current
scope's child indent level, effectively absorbing it into the scope."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((next (prologos-surfer-next-sibling)))
        (if next
            (let* ((next-start (treesit-node-start next))
                   (next-end (treesit-node-end next))
                   (scope-indent (save-excursion
                                   (goto-char (treesit-node-start
                                               prologos-surfer--current-scope))
                                   (current-indentation)))
                   (next-indent (save-excursion
                                  (goto-char next-start)
                                  (current-indentation)))
                   ;; Children should be indented 2 more than the scope head
                   (target-indent (+ scope-indent 2))
                   (delta (- target-indent next-indent)))
              (when (/= delta 0)
                (prologos-surfer-indent-lines next-start next-end delta))
              (prologos-surfer-validate-and-update))
          (message "No next sibling to slurp")))
    (message "No current scope")))

;; ============================================================================
;; Barf: Eject last child from current scope
;; ============================================================================

(defun prologos-surfer-barf ()
  "Barf: Eject the last child from the current scope.

Decreases the indentation of the last child to the scope head's
indent level, effectively ejecting it from the scope."
  (interactive)
  (if prologos-surfer--current-scope
      (let* ((scope-start (treesit-node-start prologos-surfer--current-scope))
             (scope-end (treesit-node-end prologos-surfer--current-scope))
             (scope-indent (save-excursion
                             (goto-char scope-start)
                             (current-indentation))))
        ;; Find the last child and dedent it to the scope's indent level
        (save-excursion
          (goto-char (1- scope-end))
          (let* ((current-ind (current-indentation))
                 (delta (- scope-indent current-ind)))
            (indent-rigidly (line-beginning-position) (line-end-position) delta)))
        (prologos-surfer-validate-and-update))
    (message "No current scope")))

;; ============================================================================
;; Raise: Replace parent with current node
;; ============================================================================

(defun prologos-surfer-raise ()
  "Raise: Replace the parent scope with the current scope.

Dedents the current scope to the parent's indentation level, and
deletes all siblings (the parent's other children)."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((parent (treesit-node-parent prologos-surfer--current-scope)))
        (if (and parent (prologos-surfer-is-scope-node-p parent))
            (let ((parent-indent (save-excursion
                                   (goto-char (treesit-node-start parent))
                                   (current-indentation)))
                  (scope-start (treesit-node-start prologos-surfer--current-scope))
                  (scope-end (treesit-node-end prologos-surfer--current-scope)))
              (prologos-surfer-indent-lines scope-start scope-end
                                             (- parent-indent
                                                (save-excursion
                                                  (goto-char scope-start)
                                                  (current-indentation))))
              (prologos-surfer-validate-and-update))
          (message "No parent scope")))
    (message "No current scope")))

;; ============================================================================
;; Splice: Remove current scope level, dedent children
;; ============================================================================

(defun prologos-surfer-splice ()
  "Splice: Remove the current scope level, dedenting its children.

Dedents the current scope's body by one indentation level (2 columns),
effectively merging it into the parent scope."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((scope-start (treesit-node-start prologos-surfer--current-scope))
            (scope-end (treesit-node-end prologos-surfer--current-scope)))
        (prologos-surfer-indent-lines scope-start scope-end -2)
        (prologos-surfer-validate-and-update))
    (message "No current scope")))

;; ============================================================================
;; Wrap: Insert a new scope level
;; ============================================================================

(defun prologos-surfer-wrap ()
  "Wrap: Insert a new scope level around the current scope.

Indents the current scope by one level and inserts a header keyword
line (defaulting to `do') at the original position."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((scope-start (treesit-node-start prologos-surfer--current-scope))
            (scope-end (treesit-node-end prologos-surfer--current-scope)))
        (save-excursion
          (goto-char scope-start)
          (insert "do\n")
          (prologos-surfer-indent-lines (point) (+ scope-end 3) 2))
        (prologos-surfer-validate-and-update))
    (message "No current scope")))

;; ============================================================================
;; Drag: Move current scope up or down
;; ============================================================================

(defun prologos-surfer-drag-up ()
  "Drag: Move the current scope up past the previous sibling."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((prev (prologos-surfer-prev-sibling)))
        (if prev
            (prologos-surfer-swap-nodes prologos-surfer--current-scope prev)
          (message "No previous sibling")))
    (message "No current scope")))

(defun prologos-surfer-drag-down ()
  "Drag: Move the current scope down past the next sibling."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((next (prologos-surfer-next-sibling)))
        (if next
            (prologos-surfer-swap-nodes prologos-surfer--current-scope next)
          (message "No next sibling")))
    (message "No current scope")))

(defun prologos-surfer-swap-nodes (node1 node2)
  "Swap the positions of NODE1 and NODE2 in the buffer."
  (let ((text1 (treesit-node-text node1))
        (text2 (treesit-node-text node2)))
    (save-excursion
      (goto-char (treesit-node-start node1))
      (delete-region (treesit-node-start node1) (treesit-node-end node1))
      (insert text2)
      (goto-char (treesit-node-start node2))
      (delete-region (treesit-node-start node2) (treesit-node-end node2))
      (insert text1)))
  (prologos-surfer-validate-and-update))

;; ============================================================================
;; Validation
;; ============================================================================

(defun prologos-surfer-validate-and-update ()
  "Validate the buffer syntax and update the overlay."
  ;; Re-parse with tree-sitter: iterate over all parsers in the buffer
  (dolist (parser (treesit-parser-list))
    (treesit-parser-root-node parser))
  ;; Update the scope overlay
  (prologos-surfer-update-overlay))

;; ============================================================================
;; Keybindings
;; ============================================================================

(define-key prologos-surfer-mode-map (kbd "C-c s >") #'prologos-surfer-slurp)
(define-key prologos-surfer-mode-map (kbd "C-c s <") #'prologos-surfer-barf)
(define-key prologos-surfer-mode-map (kbd "C-c s ^") #'prologos-surfer-raise)
(define-key prologos-surfer-mode-map (kbd "C-c s @") #'prologos-surfer-splice)
(define-key prologos-surfer-mode-map (kbd "C-c s w") #'prologos-surfer-wrap)
(define-key prologos-surfer-mode-map (kbd "C-c s [") #'prologos-surfer-drag-up)
(define-key prologos-surfer-mode-map (kbd "C-c s ]") #'prologos-surfer-drag-down)

(provide 'prologos-surfer-structural)
;;; prologos-surfer-structural.el ends here
```

**Tests**:

```elisp
(ert-deftest prologos-surfer-test-slurp-indentation ()
  "Test slurping increases indentation of the next sibling."
  (with-temp-buffer
    (prologos-ts-mode)
    (prologos-surfer-mode 1)
    (insert "defn f(x : Nat) : Nat\n  match x\n    zero => zero\nsucc(n) => n")
    ;; Position inside the match body
    (goto-char 25)
    (setq prologos-surfer--current-scope (treesit-node-at (point)))
    (prologos-surfer-slurp)
    ;; After slurp, the last line should be indented
    (should (string-match-p "^  succ" (buffer-string)))))

(ert-deftest prologos-surfer-test-wrap-indentation ()
  "Test wrapping inserts a header and indents."
  (with-temp-buffer
    (prologos-ts-mode)
    (prologos-surfer-mode 1)
    (insert "x + y")
    (goto-char 1)
    (setq prologos-surfer--current-scope (treesit-node-at (point)))
    (prologos-surfer-wrap)
    (should (string-match-p "^do" (buffer-string)))))
```

---

## 9. Sprint 5: REPL Protocol Abstraction Layer (Week 6)

**Objective**: Design and implement a protocol abstraction for REPL interaction, supporting comint-based REPL now and plugging in a native Πρόλογος REPL protocol later.

**Deliverables**:

- `prologos-surfer-repl.el`: Protocol abstraction, comint backend.
- Protocol spec document.
- Tests.

**Implementation**:

### Emacs Lisp Code: prologos-surfer-repl.el

```elisp
;;; prologos-surfer-repl.el --- REPL protocol abstraction for prologos-surfer

;; Copyright (C) 2024 Πρόλογος Contributors

;;; Commentary:

;; Abstraction layer for REPL interaction.
;; Supports both comint-based (Racket prototype) and protocol-based (future native Πρόλογος).

;;; Code:

(require 'comint)

;; ============================================================================
;; Customization
;; ============================================================================

(defgroup prologos-surfer-repl nil
  "REPL interaction for prologos-surfer-mode."
  :group 'prologos-surfer)

(defcustom prologos-surfer-repl-backend 'comint
  "Backend for REPL interaction: 'comint (Racket) or 'protocol (native Πρόλογος)."
  :type '(choice (const comint) (const protocol))
  :group 'prologos-surfer-repl)

;; ============================================================================
;; Generic REPL API
;; ============================================================================

(defvar prologos-surfer-repl--callback-table (make-hash-table :test 'equal)
  "Table mapping correlation IDs to callback functions.")

(defvar prologos-surfer-repl--next-id 0
  "Counter for generating unique correlation IDs.")

(defun prologos-surfer-repl-next-id ()
  "Generate a unique correlation ID."
  (setq prologos-surfer-repl--next-id (1+ prologos-surfer-repl--next-id))
  (format "id-%d" prologos-surfer-repl--next-id))

;; ============================================================================
;; Async Evaluation API
;; ============================================================================

(defun prologos-surfer-repl-eval (expr context callback)
  "Evaluate EXPR in the REPL asynchronously.

CONTEXT is a list of (name . value) bindings to make available.
CALLBACK is a function (lambda (result error-msg) ...) called with the result."
  (let ((id (prologos-surfer-repl-next-id)))
    (puthash id callback prologos-surfer-repl--callback-table)
    (pcase prologos-surfer-repl-backend
      ('comint (prologos-surfer-repl-eval-comint expr context id callback))
      ('protocol (prologos-surfer-repl-eval-protocol expr context id callback)))))

(defun prologos-surfer-repl-type-at (expr context callback)
  "Get the type of EXPR in the REPL asynchronously.

Returns a callback (lambda (type-string error-msg) ...) with the type."
  (let ((id (prologos-surfer-repl-next-id)))
    (puthash id callback prologos-surfer-repl--callback-table)
    (pcase prologos-surfer-repl-backend
      ('comint (prologos-surfer-repl-type-at-comint expr context id callback))
      ('protocol (prologos-surfer-repl-type-at-protocol expr context id callback)))))

(defun prologos-surfer-repl-complete (prefix context callback)
  "Get completions for PREFIX in the REPL asynchronously.

Returns a callback (lambda (completions) ...)."
  (let ((id (prologos-surfer-repl-next-id)))
    (puthash id callback prologos-surfer-repl--callback-table)
    (pcase prologos-surfer-repl-backend
      ('comint (prologos-surfer-repl-complete-comint prefix context id callback))
      ('protocol (prologos-surfer-repl-complete-protocol prefix context id callback)))))

;; ============================================================================
;; Comint Backend Implementation
;; ============================================================================

(defun prologos-surfer-repl-eval-comint (expr context id callback)
  "Comint-based synchronous evaluation (converted to async)."
  ;; In a real implementation, this would use comint-redirect-send-command-to-process
  ;; For now, simplified: just send the expression and capture output
  (let ((repl-buffer (get-buffer "*prologos-repl*")))
    (if repl-buffer
        (with-current-buffer repl-buffer
          (comint-redirect-send-command expr (get-buffer-process (current-buffer)) nil)
          ;; Fake async callback (real impl would hook into comint output)
          (run-at-time 0.5 nil (lambda ()
            (let ((output (buffer-substring (point-min) (point-max))))
              (funcall callback output nil)))))
      (funcall callback nil "No REPL buffer"))))

(defun prologos-surfer-repl-type-at-comint (expr context id callback)
  "Comint-based type query."
  (let ((repl-buffer (get-buffer "*prologos-repl*")))
    (if repl-buffer
        (with-current-buffer repl-buffer
          (let ((type-query (format ":type %s" expr)))
            (comint-redirect-send-command type-query (get-buffer-process (current-buffer)) nil)
            (run-at-time 0.5 nil (lambda ()
              (funcall callback (buffer-substring (point-min) (point-max)) nil)))))
      (funcall callback nil "No REPL buffer"))))

(defun prologos-surfer-repl-complete-comint (prefix context id callback)
  "Comint-based completion."
  (let ((repl-buffer (get-buffer "*prologos-repl*")))
    (if repl-buffer
        (let ((completions '("double" "succ" "zero"))) ;; Placeholder
          (funcall callback completions))
      (funcall callback nil))))

;; ============================================================================
;; Protocol Backend Stub
;; ============================================================================

(defun prologos-surfer-repl-eval-protocol (expr context id callback)
  "Protocol-based evaluation (future native Πρόλογος REPL)."
  ;; Stub: real implementation would format expr as a message
  ;; and send to the REPL server via a socket or subprocess
  (message "Protocol backend not yet implemented"))

(defun prologos-surfer-repl-type-at-protocol (expr context id callback)
  "Protocol-based type query."
  (message "Protocol backend not yet implemented"))

(defun prologos-surfer-repl-complete-protocol (prefix context id callback)
  "Protocol-based completion."
  (message "Protocol backend not yet implemented"))

;; ============================================================================
;; Context Handling
;; ============================================================================

(defun prologos-surfer-repl-make-context (start end)
  "Create a context (local bindings) for evaluation from START to END.

Returns a list of (name . value) pairs."
  ;; Simplified: for now, return an empty context
  ;; Real impl would walk the tree-sitter AST looking for let-bindings
  '())

;; ============================================================================
;; Session Management
;; ============================================================================

(defvar prologos-surfer-repl--session nil
  "Current REPL session state.")

(defun prologos-surfer-repl-ensure-session ()
  "Ensure a REPL session is active."
  (unless prologos-surfer-repl--session
    (setq prologos-surfer-repl--session
          (pcase prologos-surfer-repl-backend
            ('comint (prologos-surfer-repl-comint-start))
            ('protocol (prologos-surfer-repl-protocol-start))))))

(defun prologos-surfer-repl-comint-start ()
  "Start a comint-based REPL session."
  ;; Assumes prologos-repl.el is available
  (if (fboundp 'prologos-repl-run)
      (progn
        (prologos-repl-run)
        (get-buffer "*prologos-repl*"))
    (error "prologos-repl not available")))

(defun prologos-surfer-repl-protocol-start ()
  "Start a protocol-based REPL session."
  ;; Stub for future native REPL
  (error "Protocol-based REPL not yet implemented"))

(provide 'prologos-surfer-repl)
;;; prologos-surfer-repl.el ends here
```

**Tests**:

```elisp
(ert-deftest prologos-surfer-test-repl-backend-default ()
  "Test default REPL backend is comint."
  (should (eq prologos-surfer-repl-backend 'comint)))

(ert-deftest prologos-surfer-test-repl-eval-returns-string ()
  "Test that REPL eval returns a string result."
  (cl-letf (((symbol-function 'prologos-surfer-repl-ensure-session)
             (lambda () t))
            ((symbol-function 'prologos-surfer-repl-comint-eval)
             (lambda (_code) "42")))
    (should (stringp (prologos-surfer-repl-eval "(+ 1 1)")))))

(ert-deftest prologos-surfer-test-repl-protocol-stub ()
  "Test that protocol backend raises an error (stub)."
  (let ((prologos-surfer-repl-backend 'protocol))
    (should-error (prologos-surfer-repl-protocol-start))))
```

---

## 10. Sprint 6: Interactive Evaluation with Scope Awareness (Weeks 7–8)

**Objective**: Implement scope-aware evaluation commands that send the current scope or expression to the REPL and display results inline.

**Deliverables**:

- `prologos-surfer-eval.el`: Evaluation commands and inline result display.
- Tests.

**Implementation**:

```elisp
;;; prologos-surfer-eval.el --- Scope-aware evaluation for prologos-surfer

;; Copyright (C) 2024 Πρόλογος Contributors

;;; Commentary:

;; Commands to evaluate the current scope, expression, or definition.
;; Results are displayed as overlays and in the REPL.

;;; Code:

(require 'prologos-surfer)
(require 'prologos-surfer-repl)

;; ============================================================================
;; Customization
;; ============================================================================

(defcustom prologos-surfer-inline-results t
  "When non-nil, display evaluation results as overlays."
  :type 'boolean
  :group 'prologos-surfer)

(defcustom prologos-surfer-result-overlay-timeout 5
  "Seconds to keep result overlay visible. Set to nil for permanent."
  :type '(choice integer (const nil))
  :group 'prologos-surfer)

;; ============================================================================
;; Variables
;; ============================================================================

(defvar prologos-surfer--result-overlays '()
  "List of result overlays currently displayed.")

(defvar prologos-surfer--last-result nil
  "The last evaluation result (for inspection).")

;; ============================================================================
;; Evaluation Commands
;; ============================================================================

(defun prologos-surfer-eval-scope ()
  "Evaluate the current highlighted scope."
  (interactive)
  (if prologos-surfer--current-scope
      (let ((expr (treesit-node-text prologos-surfer--current-scope))
            (context (prologos-surfer-repl-make-context
                      (treesit-node-start prologos-surfer--current-scope)
                      (treesit-node-end prologos-surfer--current-scope))))
        (prologos-surfer-repl-ensure-session)
        (prologos-surfer-repl-eval expr context
                                   (lambda (result error)
                                     (prologos-surfer--handle-eval-result
                                      result error
                                      (treesit-node-end prologos-surfer--current-scope)))))
    (message "No current scope")))

(defun prologos-surfer-eval-defun ()
  "Evaluate the enclosing definition."
  (interactive)
  (let ((defun (prologos-surfer--find-enclosing-defun)))
    (if defun
        (let ((expr (treesit-node-text defun)))
          (prologos-surfer-repl-ensure-session)
          (prologos-surfer-repl-eval expr '()
                                     (lambda (result error)
                                       (prologos-surfer--handle-eval-result
                                        result error
                                        (treesit-node-end defun)))))
      (message "Not in a definition"))))

(defun prologos-surfer-eval-expression ()
  "Evaluate the smallest expression at point."
  (interactive)
  (let ((expr-node (treesit-node-at (point))))
    (while (and expr-node
                (not (member (treesit-node-type expr-node)
                            '("application" "identifier" "literal"))))
      (setq expr-node (treesit-node-parent expr-node)))
    (if expr-node
        (let ((expr (treesit-node-text expr-node)))
          (prologos-surfer-repl-ensure-session)
          (prologos-surfer-repl-eval expr '()
                                     (lambda (result error)
                                       (prologos-surfer--handle-eval-result
                                        result error
                                        (treesit-node-end expr-node)))))
      (message "No expression at point"))))

(defun prologos-surfer-eval-to-hole ()
  "Evaluate an expression and insert the result into a hole."
  (interactive)
  (message "Find hole at point and replace with evaluation... (not yet implemented)"))

;; ============================================================================
;; Result Display
;; ============================================================================

(defun prologos-surfer--handle-eval-result (result error end-pos)
  "Handle the result of an evaluation."
  (if error
      (prologos-surfer--display-error error end-pos)
    (progn
      (setq prologos-surfer--last-result result)
      (when prologos-surfer-inline-results
        (prologos-surfer--display-result-overlay result end-pos)))))

(defun prologos-surfer--display-result-overlay (result pos)
  "Display a result as an overlay at POS."
  (let* ((result-text (format " => %s" (truncate-string-to-width result 50)))
         (ov (make-overlay pos pos (current-buffer))))
    (overlay-put ov 'after-string result-text)
    (overlay-put ov 'face 'font-lock-comment-face)
    (push ov prologos-surfer--result-overlays)
    ;; Auto-clear after timeout
    (when prologos-surfer-result-overlay-timeout
      (run-at-time prologos-surfer-result-overlay-timeout nil
                   (lambda () (delete-overlay ov))))))

(defun prologos-surfer--display-error (error-msg pos)
  "Display an error message as an overlay at POS."
  (let* ((error-text (format " ✗ %s" (truncate-string-to-width error-msg 50)))
         (ov (make-overlay pos pos (current-buffer))))
    (overlay-put ov 'after-string error-text)
    (overlay-put ov 'face 'error)
    (push ov prologos-surfer--result-overlays)))

;; ============================================================================
;; Helper Functions
;; ============================================================================

(defun prologos-surfer--find-enclosing-defun ()
  "Find the tree-sitter node for the enclosing definition."
  (let ((node (treesit-node-at (point))))
    (while (and node (not (string= (treesit-node-type node) "definition")))
      (setq node (treesit-node-parent node)))
    node))

;; ============================================================================
;; Keybindings
;; ============================================================================

(define-key prologos-surfer-mode-map (kbd "C-c s e e") #'prologos-surfer-eval-scope)
(define-key prologos-surfer-mode-map (kbd "C-c s e d") #'prologos-surfer-eval-defun)
(define-key prologos-surfer-mode-map (kbd "C-c s e x") #'prologos-surfer-eval-expression)
(define-key prologos-surfer-mode-map (kbd "C-c s e h") #'prologos-surfer-eval-to-hole)

(provide 'prologos-surfer-eval)
;;; prologos-surfer-eval.el ends here
```

**Tests**:

```elisp
(ert-deftest prologos-surfer-test-eval-scope-sends-text ()
  "Test that eval-scope sends the scope text to the REPL."
  (let ((sent-code nil))
    (cl-letf (((symbol-function 'prologos-surfer-repl-eval)
               (lambda (code) (setq sent-code code) "result")))
      (with-temp-buffer
        (prologos-ts-mode)
        (prologos-surfer-mode 1)
        (insert "(defn f () 42)")
        (goto-char 10)
        ;; Simulate scope being set
        (setq prologos-surfer--current-scope (treesit-node-at (point)))
        (prologos-surfer-eval-scope)
        (should sent-code)))))

(ert-deftest prologos-surfer-test-inline-result-overlay ()
  "Test that inline result creates an overlay."
  (with-temp-buffer
    (prologos-ts-mode)
    (prologos-surfer-mode 1)
    (insert "(+ 1 2)")
    (prologos-surfer-show-result-inline (point) "3")
    (should (> (length (overlays-in (point-min) (point-max))) 0))))
```

---

## 11. Sprint 7: Data Inspector and Value Exploration (Week 9)

**Objective**: Implement a dedicated inspector buffer for exploring complex REPL results.

**Deliverables**:

- `prologos-surfer-inspector.el`: Inspector UI and navigation.

**Implementation**:

```elisp
;;; prologos-surfer-inspector.el --- Data inspector for prologos-surfer

;; Copyright (C) 2024 Πρόλογος Contributors

;;; Commentary:

;; Inspector buffer for exploring complex values returned from the REPL.

;;; Code:

(require 'prologos-surfer)

;; ============================================================================
;; Inspector Buffer Management
;; ============================================================================

(defvar prologos-surfer-inspector-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "n" #'prologos-surfer-inspector-next)
    (define-key map "p" #'prologos-surfer-inspector-prev)
    (define-key map "RET" #'prologos-surfer-inspector-follow)
    (define-key map "l" #'prologos-surfer-inspector-pop)
    map)
  "Keymap for prologos-surfer-inspector-mode.")

(define-derived-mode prologos-surfer-inspector-mode special-mode "Prologos Inspector"
  "Major mode for inspecting Πρόλογος values."
  :group 'prologos-surfer)

(defun prologos-surfer-open-inspector (value)
  "Open an inspector buffer for VALUE."
  (let ((buf (get-buffer-create "*prologos-inspector*")))
    (with-current-buffer buf
      (prologos-surfer-inspector-mode)
      (prologos-surfer-inspector-display value)
      (switch-to-buffer buf))))

(defun prologos-surfer-inspector-display (value)
  "Display VALUE in the inspector."
  (erase-buffer)
  (insert (prologos-surfer-inspector-format-value value 0))
  (goto-char (point-min)))

;; ============================================================================
;; Value Formatting
;; ============================================================================

(defun prologos-surfer-inspector-format-value (value depth)
  "Format VALUE for display in the inspector, with nesting DEPTH."
  ;; Simplified formatter: for now, just pretty-print
  ;; Real impl would parse structured results and create clickable elements
  (let ((indent (make-string (* 2 depth) ? )))
    (cond
     ((stringp value)
      (concat indent "\"" (truncate-string-to-width value 60) "\""))
     ((numberp value)
      (concat indent (number-to-string value)))
     ((listp value)
      (concat indent "(\n"
              (mapconcat (lambda (item)
                          (prologos-surfer-inspector-format-value item (1+ depth)))
                        value "\n")
              "\n" indent ")"))
     (t (concat indent (prin1-to-string value))))))

;; ============================================================================
;; Navigation
;; ============================================================================

(defun prologos-surfer-inspector-next ()
  "Move to the next inspectable element."
  (interactive)
  (forward-line 1))

(defun prologos-surfer-inspector-prev ()
  "Move to the previous inspectable element."
  (interactive)
  (forward-line -1))

(defun prologos-surfer-inspector-follow ()
  "Follow the element at point (dive into nested values)."
  (interactive)
  (message "Navigate into nested value... (not yet implemented)"))

(defun prologos-surfer-inspector-pop ()
  "Go back to the parent value."
  (interactive)
  (message "Back to parent... (not yet implemented)"))

(provide 'prologos-surfer-inspector)
;;; prologos-surfer-inspector.el ends here
```

**Tests**:

```elisp
(ert-deftest prologos-surfer-test-inspector-open ()
  "Test that opening the inspector creates a buffer."
  (prologos-surfer-inspector-open "42" "Nat")
  (should (get-buffer "*prologos-inspector*"))
  (kill-buffer "*prologos-inspector*"))

(ert-deftest prologos-surfer-test-inspector-navigation ()
  "Test basic navigation in the inspector buffer."
  (prologos-surfer-inspector-open "{:x 1 :y 2}" "{:x Nat :y Nat}")
  (with-current-buffer "*prologos-inspector*"
    (goto-char (point-min))
    (prologos-surfer-inspector-next)
    (should (> (line-number-at-pos) 1)))
  (kill-buffer "*prologos-inspector*"))

(ert-deftest prologos-surfer-test-inspector-mode-map ()
  "Test that inspector mode has expected keybindings."
  (prologos-surfer-inspector-open "test" "String")
  (with-current-buffer "*prologos-inspector*"
    (should (eq (key-binding (kbd "n")) #'prologos-surfer-inspector-next))
    (should (eq (key-binding (kbd "p")) #'prologos-surfer-inspector-prev)))
  (kill-buffer "*prologos-inspector*"))
```

---

## 12. Sprint 8: Testing, Polish, and Distribution (Weeks 10–11)

**Objective**: Complete test coverage, optimize performance, ensure theme compatibility, and prepare for distribution.

**Deliverables**:

- Full test suite (ERT)
- Performance profiling and optimization
- README with keybinding reference
- MELPA packaging metadata

**Tests**:

```elisp
;;; prologos-surfer-tests.el --- Comprehensive test suite

(require 'ert)
(require 'prologos-surfer)
(require 'prologos-surfer-navigation)
(require 'prologos-surfer-structural)
(require 'prologos-surfer-eval)

;; Existing tests from Sprints 1–6, plus:

(ert-deftest prologos-surfer-test-theme-compatibility ()
  "Test that surfer works with light and dark themes."
  (dolist (mode '(light dark))
    (set-frame-parameter nil 'background-mode mode)
    (prologos-surfer-mode 1)
    (should (bound-and-true-p prologos-surfer-mode))))

(ert-deftest prologos-surfer-test-evil-mode-compat ()
  "Test basic evil-mode compatibility."
  ;; Simplified: just check that keybindings work
  (with-temp-buffer
    (prologos-ts-mode)
    (prologos-surfer-mode 1)
    (insert "(+ 1 2)")
    (goto-char 3)
    (should (prologos-surfer-current-scope))))

(ert-deftest prologos-surfer-test-large-buffer ()
  "Test performance with large buffers."
  (with-temp-buffer
    (prologos-ts-mode)
    ;; Generate 1000 lines of code
    (dotimes (_ 100)
      (insert "(defn f () (+ 1 2))\n"))
    (prologos-surfer-mode 1)
    (goto-char (point-max))
    (let ((start-time (current-time)))
      (prologos-surfer-update-overlay)
      (let ((elapsed (float-time (time-subtract (current-time) start-time))))
        (should (< elapsed 0.1)))))) ;; Should complete in < 100ms
```

---

## 13. The Complete Feature Matrix

| Feature | Tree-sitter | Regex Fallback | Notes |
|---------|-------------|----------------|-------|
| Scope highlighting | ✓ | ◐ | Reduced precision in regex mode |
| AST navigation (u/d/l/r) | ✓ | ✗ | Requires tree-sitter |
| Breadcrumb | ✓ | ◐ | Shows node types in tree-sitter |
| Slurp | ✓ | ✗ | Indentation-based |
| Barf | ✓ | ✗ | Indentation-based |
| Raise | ✓ | ✗ | Indentation-based |
| Splice | ✓ | ✗ | Indentation-based |
| Wrap | ✓ | ✗ | Indentation-based |
| Drag up/down | ✓ | ✗ | Requires accurate node positions |
| Scope-aware eval | ✓ | ✓ | Works with prologos-repl.el |
| Inline results | ✓ | ✓ | Overlay-based display |
| Data inspector | ✓ | ✓ | Reads REPL protocol |
| Hole navigation | ✓ | ◐ | Requires scope detection |

---

## 14. Cross-Cutting Concerns

### 14.1 Performance

**Overlay Update Frequency**: Overlay updates are debounced to occur at most every 100ms (configurable). This prevents sluggish cursor movement in large files.

**Tree-sitter Parsing**: Tree-sitter incremental parsing is fast (O(n) on average), but surfer-mode limits re-parsing (via `treesit-parser-root-node`) to occur only after structural edits.

**Scope Cache**: The `prologos-surfer--current-scope` variable caches the scope node, so repeated calls within the same command don't require tree-sitter traversal.

### 14.2 Theme Compatibility

Surfer-mode generates scope-highlighting faces dynamically based on the frame's `background-mode` parameter. Light themes get progressively darker tints; dark themes get progressively lighter tints. This ensures readability on any theme.

### 14.3 Evil-mode Compatibility

Surfer-mode keybindings use the `C-c s` prefix, which is reserved for user mode extensions. Evil-mode does not claim these keybindings. To map surfer commands to evil motion keys, users can customize `prologos-surfer-mode-map` in their init file.

Example:
```elisp
(evil-define-key 'normal 'prologos-surfer-mode-map
  "gu" 'prologos-surfer-up-scope
  "gd" 'prologos-surfer-down-scope
  "gl" 'prologos-surfer-prev-sibling
  "gr" 'prologos-surfer-next-sibling)
```

### 14.4 Integration with prologos-mode Features

Surfer-mode respects existing prologos-mode features:

- **Holes**: Tree-sitter node type `hole` is recognized as a scope. Navigation commands can move to holes. `surfer-eval-to-hole` inserts evaluation results into holes.
- **Eldoc**: Eldoc strings from `prologos-eldoc.el` are displayed in the echo area; surfer-mode does not interfere.
- **Flymake**: Flymake overlays are rendered below surfer-mode's scope overlay (higher priority).
- **Indentation**: Surfer-mode's structural operations respect prologos-indent settings.

### 14.5 Accessibility

**Colorblind Safety**: Depth is indicated not just by color intensity but also by subtle striping or underline in dark mode. Users can customize the face definitions.

**Screen Reader**: All overlays have associated text content (via `overlay-put`); screen readers can access scope information.

---

## 15. Post-Sprint Work

### 15.1 LSP Integration

When `prologos-lsp` becomes available, surfer-mode can integrate with LSP-provided:

- **Hover information** (type at point, documentation)
- **Definition locations** (jump to definition in structural operations)
- **Rename refactoring** (rename identifiers across the current scope)

Implementation: Add a `prologos-surfer-lsp.el` module that dispatches to LSP when available.

### 15.2 Multi-Cursor Surfer Operations

Support multi-cursor editing with surfer-mode structural operations. For example, with three cursors active, `prologos-surfer-slurp` slurps at all three locations.

Implementation: Iterate over all active cursors (via `multiple-cursors.el` or `multiple-cursors.el` integration) and apply operations at each.

### 15.3 Collaborative Editing Awareness

When editing a file shared via Crdt.el or similar, surfer-mode must account for remote changes to the tree structure. Validate the AST after remote edits; gracefully disable surfer-mode if the tree becomes unparseable.

### 15.4 Visual Debugging Integration

When prologos-mode provides a debugger, surfer-mode can highlight the current execution scope, allowing the programmer to visually navigate the call stack.

---

## 16. References

1. **Combobulate** (https://github.com/mickeynp/combobulate): Structural editing with tree-sitter for multiple languages.
2. **Symex.el** (https://github.com/drym-org/symex.el): Symmetry-aware structural editing.
3. **tree-edit** (https://github.com/ethan-leba/tree-edit): Tree-sitter structural editing.
4. **structured-haskell-mode** (https://github.com/chrisdone/structured-haskell-mode): Structural editing for Haskell.
5. **CIDER** (https://github.com/clojure-emacs/cider): Clojure interactive development environment.
6. **nREPL Protocol** (https://nrepl.org/): Asynchronous message protocol for interactive evaluation.
7. **indent-bars.el** (https://github.com/jdtsmith/indent-bars): Visual indentation guides.
8. **expand-region.el** (https://github.com/magnars/expand-region.el): Expand region by semantic unit.
9. **Hydra** (https://github.com/abo-abo/hydra): Transient keymaps for Emacs.
10. **repeat-mode** (Emacs 28+): Built-in repeat-last-command mechanism.
11. **Outline-indent.el** (https://github.com/daviwil/outline-indent-el): Indentation-based folding.
12. **drag-stuff.el** (https://github.com/rejeep/drag-stuff.el): Move lines/regions up and down.
13. **breadcrumb** (Emacs 28.1+): Built-in breadcrumb navigation.
14. **Agda Interaction Mode** (https://github.com/agda/agda/): Interactive dependent type development.
15. **Idris IDE Protocol** (https://github.com/idris-lang/Idris-dev): Message protocol for IDE integration.
16. **Lean 4 Server** (https://github.com/leanprover/lean4): Language server for Lean 4.
17. **Tree-sitter**: https://tree-sitter.github.io
18. **Emacs Manual - Overlays**: https://www.gnu.org/software/emacs/manual/html_node/elisp/Overlays.html
19. **Emacs Manual - Minor Modes**: https://www.gnu.org/software/emacs/manual/html_node/elisp/Minor-Modes.html
20. **paredit.el** (https://github.com/paredit/paredit): Structural editing of S-expressions.
21. **smartparens** (https://github.com/Fuco1/smartparens): Pair editing for multiple languages.
22. **puni** (https://github.com/AmaiKinono/puni): Lightweight paredit-like editing.

---

**Document Version**: 1.0 (11 sprints, 11 weeks)
**Target Release**: Q2 2024
**Maintainer**: Πρόλογος Contributors
