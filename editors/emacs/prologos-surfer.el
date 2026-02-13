;;; prologos-surfer.el --- AST navigation and scope highlighting for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (prologos-mode "0.1.0"))
;; Keywords: languages, prologos, structural-editing
;; URL: https://github.com/prologos-lang/prologos

;;; Commentary:

;; prologos-surfer-mode is a minor mode providing AST-aware scope
;; visualization for Prologos code.  It layers on top of
;; `prologos-ts-mode' (tree-sitter) to highlight the current scope
;; with a depth-aware background tint, and shows the current position
;; in the AST on the mode line.
;;
;; Usage:
;;   (require 'prologos-surfer)
;;   (add-hook 'prologos-ts-mode-hook #'prologos-surfer-maybe-enable)
;;
;; Or toggle manually: M-x prologos-surfer-mode
;;
;; Sprint 1: scope detection, overlay, mode-line lighter.
;; Sprint 2: navigation commands (up/down/left/right), repeat-mode,
;;   optional hydra, select/expand/contract.

;;; Code:

(require 'treesit)
(require 'prologos-ts-mode)

;; ============================================================================
;; Customization
;; ============================================================================

(defgroup prologos-surfer nil
  "AST navigation and scope visualization for Prologos."
  :group 'prologos
  :prefix "prologos-surfer-")

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

(defcustom prologos-surfer-update-delay 0.05
  "Delay (in seconds) before updating the scope overlay after cursor movement."
  :type 'float
  :group 'prologos-surfer)

;; ============================================================================
;; Scope Node Types
;; ============================================================================

(defconst prologos-surfer--scope-node-types
  '("source_file"
    "defn_form"
    "def_form"
    "data_form"
    "deftype_form"
    "fn_expr"
    "match_expr"
    "match_arm"
    "block_body"
    "match_arm_body"
    "application"
    "grouped_expr")
  "Tree-sitter node types that represent structural scopes in Prologos.")

(defconst prologos-surfer--node-type-labels
  '(("source_file" . "file")
    ("defn_form" . "defn")
    ("def_form" . "def")
    ("data_form" . "data")
    ("deftype_form" . "deftype")
    ("fn_expr" . "fn")
    ("match_expr" . "match")
    ("match_arm" . "arm")
    ("block_body" . "body")
    ("match_arm_body" . "arm-body")
    ("application" . "app")
    ("grouped_expr" . "group"))
  "Short labels for scope node types, used in the mode-line lighter.")

;; ============================================================================
;; Buffer-local State
;; ============================================================================

(defvar-local prologos-surfer--current-scope nil
  "The tree-sitter node for the current scope (nil if none).")

(defun prologos-surfer-current-scope ()
  "Return the current scope node, or nil."
  prologos-surfer--current-scope)

(defvar-local prologos-surfer--scope-overlay nil
  "The primary overlay highlighting the current scope.")

(defvar-local prologos-surfer--update-timer nil
  "Timer for debounced scope updates.")

(defvar-local prologos-surfer--mode-line-lighter nil
  "Dynamic lighter string for the mode line.
Updated to show the current scope type (e.g., \" surfer:defn\").")

(defvar prologos-surfer--scope-faces nil
  "Cached alist of (DEPTH . FACE-NAME) for scope depth tinting.")

;; ============================================================================
;; Scope Detection
;; ============================================================================

(defun prologos-surfer--scope-node-p (node)
  "Return non-nil if NODE is a scope node."
  (member (treesit-node-type node) prologos-surfer--scope-node-types))

(defun prologos-surfer--find-scope ()
  "Return the innermost scope node enclosing point.
Walks up the tree from the current position until a scope node is found."
  (when (treesit-parser-list)
    (let ((node (treesit-node-at (point))))
      (while (and node (not (prologos-surfer--scope-node-p node)))
        (setq node (treesit-node-parent node)))
      node)))

(defun prologos-surfer--scope-depth (node)
  "Return the depth of NODE counting only scope-node ancestors.
Depth 0 means no scope-node ancestors (e.g., a top-level defn_form
whose only scope-node ancestor is source_file counts as depth 1)."
  (let ((depth 0)
        (parent (treesit-node-parent node)))
    (while parent
      (when (prologos-surfer--scope-node-p parent)
        (setq depth (1+ depth)))
      (setq parent (treesit-node-parent parent)))
    depth))

(defun prologos-surfer--scope-label (node)
  "Return a short label for NODE's type, or its raw type if no label defined."
  (or (cdr (assoc (treesit-node-type node) prologos-surfer--node-type-labels))
      (treesit-node-type node)))

(defun prologos-surfer--effective-end (node)
  "Return the effective end position of NODE, trimming trailing blank lines.
The tree-sitter external scanner extends node boundaries into trailing
whitespace and blank lines (due to INDENT/DEDENT token mechanics).
This function walks backward from the raw node end to find the end of
the last line with actual content, including its trailing newline."
  (let ((end (treesit-node-end node))
        (start (treesit-node-start node)))
    (save-excursion
      (goto-char end)
      (skip-chars-backward " \t\n\r" start)
      ;; Now at last non-whitespace char.  Include its trailing newline.
      (end-of-line)
      (min (1+ (point)) end))))

;; ============================================================================
;; Face Generation
;; ============================================================================

(defun prologos-surfer--get-scope-face (depth)
  "Return a face for highlighting a scope at given DEPTH.
Faces vary in color intensity by depth for better visual hierarchy.
Results are cached in `prologos-surfer--scope-faces'."
  (or (cdr (assoc depth prologos-surfer--scope-faces))
      (let* ((is-dark (eq (frame-parameter nil 'background-mode) 'dark))
             (intensity (/ (float (min depth 8)) 8.0))
             (bg-color
              (if is-dark
                  ;; Dark theme: blue tint deepening with depth
                  ;; From #1e1e2e (depth 0) to #1e1e4e (depth 8)
                  (format "#1e1e%02x" (round (+ 46 (* 32 intensity))))
                ;; Light theme: blue tint deepening with depth
                ;; From #f0f0ff (depth 0) to #d8d8ff (depth 8)
                (let ((channel (round (- 240 (* 24 intensity)))))
                  (format "#%02x%02xff" channel channel))))
             (face-name (intern (format "prologos-surfer-scope-depth-%d" depth))))
        (custom-declare-face face-name
                             `((t :background ,bg-color))
                             (format "Face for surfer scope at depth %d." depth))
        (push (cons depth face-name) prologos-surfer--scope-faces)
        face-name)))

;; ============================================================================
;; Overlay Management
;; ============================================================================

(defun prologos-surfer--update-overlay ()
  "Update the scope overlay to match the current scope.
Only redraws if the scope has actually changed."
  (when (and prologos-surfer-mode (buffer-live-p (current-buffer)))
    (let ((new-scope (prologos-surfer--find-scope)))
      (unless (and prologos-surfer--current-scope
                   new-scope
                   (eq (treesit-node-start prologos-surfer--current-scope)
                       (treesit-node-start new-scope))
                   (eq (treesit-node-end prologos-surfer--current-scope)
                       (treesit-node-end new-scope)))
        (setq prologos-surfer--current-scope new-scope)
        (prologos-surfer--redraw-overlay)
        ;; Update mode-line lighter
        (setq prologos-surfer--mode-line-lighter
              (if new-scope
                  (format " surfer:%s" (prologos-surfer--scope-label new-scope))
                " surfer"))
        (force-mode-line-update)))))

(defun prologos-surfer--redraw-overlay ()
  "Redraw the overlay for the current scope."
  ;; Remove old overlay
  (when prologos-surfer--scope-overlay
    (delete-overlay prologos-surfer--scope-overlay)
    (setq prologos-surfer--scope-overlay nil))
  ;; Create new overlay if scope exists and overlays are enabled
  (when (and prologos-surfer-enable-overlay
             prologos-surfer--current-scope)
    (let* ((start (treesit-node-start prologos-surfer--current-scope))
           (end (prologos-surfer--effective-end prologos-surfer--current-scope))
           (depth (prologos-surfer--scope-depth prologos-surfer--current-scope))
           (face (if prologos-surfer-depth-tinting
                     (prologos-surfer--get-scope-face depth)
                   'highlight)))
      (setq prologos-surfer--scope-overlay
            (make-overlay start end (current-buffer)))
      (overlay-put prologos-surfer--scope-overlay 'face face)
      (overlay-put prologos-surfer--scope-overlay
                   'priority prologos-surfer-overlay-priority)
      (overlay-put prologos-surfer--scope-overlay
                   'evaporate t)
      (overlay-put prologos-surfer--scope-overlay
                   'prologos-surfer t))))

(defun prologos-surfer--clear-overlay ()
  "Remove the scope overlay and reset state."
  (when prologos-surfer--scope-overlay
    (delete-overlay prologos-surfer--scope-overlay)
    (setq prologos-surfer--scope-overlay nil))
  (setq prologos-surfer--current-scope nil)
  (setq prologos-surfer--mode-line-lighter nil))

;; ============================================================================
;; Navigation Helper
;; ============================================================================

(defun prologos-surfer--navigate-to-scope (node)
  "Move point to NODE and update the overlay immediately.
Used by navigation commands for instant feedback (bypasses debounce)."
  (when node
    (goto-char (treesit-node-start node))
    (setq prologos-surfer--current-scope node)
    (prologos-surfer--redraw-overlay)
    (setq prologos-surfer--mode-line-lighter
          (format " surfer:%s" (prologos-surfer--scope-label node)))
    (force-mode-line-update)))

;; ============================================================================
;; Post-Command Hook (debounced)
;; ============================================================================

(defun prologos-surfer--post-command-hook ()
  "Schedule a debounced scope overlay update after each command."
  (when prologos-surfer--update-timer
    (cancel-timer prologos-surfer--update-timer))
  (setq prologos-surfer--update-timer
        (run-at-time prologos-surfer-update-delay nil
                     #'prologos-surfer--update-overlay)))

;; ============================================================================
;; Keymap
;; ============================================================================

(defvar prologos-surfer-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Toggle surfer mode
    (define-key map (kbd "C-c s s") #'prologos-surfer-mode)
    ;; Navigation (Sprint 2)
    (define-key map (kbd "C-c s u") #'prologos-surfer-up-scope)
    (define-key map (kbd "C-c s d") #'prologos-surfer-down-scope)
    (define-key map (kbd "C-c s l") #'prologos-surfer-prev-sibling)
    (define-key map (kbd "C-c s r") #'prologos-surfer-next-sibling)
    ;; Smart forward/backward (DFS pre-order traversal)
    (define-key map (kbd "C-c s f") #'prologos-surfer-forward)
    (define-key map (kbd "C-c s b") #'prologos-surfer-backward)
    ;; Selection (Sprint 2)
    (define-key map (kbd "C-c s e") #'prologos-surfer-expand-scope)
    (define-key map (kbd "C-c s c") #'prologos-surfer-contract-scope)
    (define-key map (kbd "C-c s v") #'prologos-surfer-select-scope)
    ;; Optional hydra entry (Sprint 2)
    (define-key map (kbd "C-c s h") #'prologos-surfer-hydra)
    map)
  "Keymap for `prologos-surfer-mode'.")

;; ============================================================================
;; Minor Mode Definition
;; ============================================================================

;;;###autoload
(define-minor-mode prologos-surfer-mode
  "Minor mode for AST-aware scope visualization in Prologos code.

When enabled, this mode:
- Highlights the current scope with a depth-aware background overlay.
- Shows the current scope type in the mode line (e.g., \" surfer:defn\").

Requires a tree-sitter parser for Prologos to be available.

\\{prologos-surfer-mode-map}"
  :init-value nil
  :lighter (:eval (or prologos-surfer--mode-line-lighter " surfer"))
  :keymap prologos-surfer-mode-map
  :group 'prologos-surfer
  (if prologos-surfer-mode
      ;; Enable
      (progn
        ;; Check tree-sitter availability
        (unless (treesit-parser-list)
          (if (treesit-language-available-p 'prologos)
              (treesit-parser-create 'prologos)
            (setq prologos-surfer-mode nil)
            (user-error "Tree-sitter parser for Prologos not available; surfer-mode disabled")))
        ;; Install hooks
        (add-hook 'post-command-hook #'prologos-surfer--post-command-hook nil t)
        ;; Initial overlay update
        (prologos-surfer--update-overlay))
    ;; Disable
    (remove-hook 'post-command-hook #'prologos-surfer--post-command-hook t)
    (prologos-surfer--clear-overlay)
    (when prologos-surfer--update-timer
      (cancel-timer prologos-surfer--update-timer)
      (setq prologos-surfer--update-timer nil))
    (force-mode-line-update)))

;; ============================================================================
;; Integration
;; ============================================================================

;;;###autoload
(defun prologos-surfer-maybe-enable ()
  "Enable `prologos-surfer-mode' if tree-sitter parser is available.
Intended for use in `prologos-ts-mode-hook'."
  (when (treesit-parser-list)
    (prologos-surfer-mode 1)))

(require 'prologos-surfer-navigation)

(provide 'prologos-surfer)

;;; prologos-surfer.el ends here
