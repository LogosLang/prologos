;;; prologos-surfer-navigation.el --- AST navigation for prologos-surfer -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors

;;; Commentary:

;; Navigation commands for prologos-surfer-mode: up (parent), down (child),
;; left (previous sibling), right (next sibling), select, expand, contract.
;; Includes repeat-mode integration (Emacs 28+) and optional hydra support.

;;; Code:

(require 'treesit)

;; Forward declarations from prologos-surfer.el (avoids circular require)
(defvar prologos-surfer-mode)
(defvar prologos-surfer--current-scope)
(defvar prologos-surfer--scope-node-types)
(declare-function prologos-surfer--scope-node-p "prologos-surfer")
(declare-function prologos-surfer--find-scope "prologos-surfer")
(declare-function prologos-surfer--navigate-to-scope "prologos-surfer")
(declare-function prologos-surfer--effective-end "prologos-surfer")

;; ============================================================================
;; Customization
;; ============================================================================

(defcustom prologos-surfer-use-hydra nil
  "When non-nil, provide a hydra-based transient menu via \\`C-c s h'.
Requires the `hydra' package to be installed separately.
The default keybinding scheme uses Emacs 28+ repeat-mode."
  :type 'boolean
  :group 'prologos-surfer)

;; ============================================================================
;; Internal Navigation Helpers
;; ============================================================================

(defun prologos-surfer--find-parent-scope (node)
  "Return the nearest scope-node ancestor of NODE, or nil.
Walks up through non-scope wrapper nodes (e.g., top_level, expression)."
  (let ((parent (treesit-node-parent node)))
    (while (and parent (not (prologos-surfer--scope-node-p parent)))
      (setq parent (treesit-node-parent parent)))
    parent))

(defun prologos-surfer--first-scope-descendant (node)
  "Return the first scope-node child or descendant of NODE, or nil.
Searches named children in document order.  Handles wrapper nodes
like `top_level' and `expression' that sit between parent scope
and child scope nodes."
  (let ((count (treesit-node-child-count node t))
        (i 0)
        result)
    ;; First pass: check direct named children
    (while (and (< i count) (not result))
      (let ((child (treesit-node-child node i t)))
        (when (prologos-surfer--scope-node-p child)
          (setq result child)))
      (setq i (1+ i)))
    ;; Second pass: recurse into non-scope children
    (unless result
      (setq i 0)
      (while (and (< i count) (not result))
        (let ((child (treesit-node-child node i t)))
          (unless (prologos-surfer--scope-node-p child)
            (setq result (prologos-surfer--first-scope-descendant child))))
        (setq i (1+ i))))
    result))

(defun prologos-surfer--sibling-scope (node direction)
  "Find the next or previous sibling scope node of NODE.
DIRECTION is `next' or `prev'.  Walks up through non-scope wrapper
nodes (e.g., top_level) but stops at scope-node parent boundaries."
  (let ((current node)
        result)
    (while (and current (not result))
      (let ((sib (if (eq direction 'next)
                     (treesit-node-next-sibling current t)
                   (treesit-node-prev-sibling current t))))
        ;; Walk through siblings in the given direction
        (while (and sib (not result))
          (if (prologos-surfer--scope-node-p sib)
              (setq result sib)
            ;; Check if sibling contains a scope-node descendant
            (let ((desc (prologos-surfer--first-scope-descendant sib)))
              (if desc
                  (setq result desc)
                ;; No scope descendant; try next sibling
                (setq sib (if (eq direction 'next)
                              (treesit-node-next-sibling sib t)
                            (treesit-node-prev-sibling sib t)))))))
        ;; No sibling found at this level
        (unless result
          (let ((parent (treesit-node-parent current)))
            ;; Only walk up through non-scope wrapper nodes
            ;; Stop if parent is a scope node (stay within scope boundary)
            (if (or (null parent) (prologos-surfer--scope-node-p parent))
                (setq current nil)  ; stop — exhausted siblings at this scope level
              (setq current parent))))))  ; go up through wrapper
    result))

(defun prologos-surfer--last-scope-descendant (node)
  "Return the last (deepest, rightmost) scope-node descendant of NODE, or nil.
Searches named children in reverse document order, recursing into the last
scope child found.  Handles wrapper nodes like `top_level' and `expression'
that sit between parent scope and child scope nodes."
  (let ((count (treesit-node-child-count node t))
        (i (1- (treesit-node-child-count node t)))
        result)
    ;; First pass: find last direct scope child (reverse order)
    (while (and (>= i 0) (not result))
      (let ((child (treesit-node-child node i t)))
        (when (prologos-surfer--scope-node-p child)
          (setq result child)))
      (setq i (1- i)))
    ;; Second pass: recurse into non-scope children in reverse
    (unless result
      (setq i (1- count))
      (while (and (>= i 0) (not result))
        (let ((child (treesit-node-child node i t)))
          (unless (prologos-surfer--scope-node-p child)
            (setq result (prologos-surfer--last-scope-descendant child))))
        (setq i (1- i))))
    ;; Recurse deeper: find the deepest last descendant of the found scope child
    (when result
      (or (prologos-surfer--last-scope-descendant result) result))))

;; ============================================================================
;; Navigation Commands
;; ============================================================================

(defun prologos-surfer-up-scope ()
  "Move point to the parent scope node.
Walks up through non-scope wrapper nodes until a scope node is found."
  (interactive)
  (when prologos-surfer-mode
    (let* ((current (or prologos-surfer--current-scope
                        (prologos-surfer--find-scope)))
           (parent (and current (prologos-surfer--find-parent-scope current))))
      (if parent
          (progn
            (prologos-surfer--navigate-to-scope parent)
            (message "Up to %s" (treesit-node-type parent)))
        (message "Already at top scope")))))

(defun prologos-surfer-down-scope ()
  "Move point to the first child scope node.
Searches through wrapper nodes to find the nearest scope descendant."
  (interactive)
  (when prologos-surfer-mode
    (let* ((current (or prologos-surfer--current-scope
                        (prologos-surfer--find-scope)))
           (child (and current (prologos-surfer--first-scope-descendant current))))
      (if child
          (progn
            (prologos-surfer--navigate-to-scope child)
            (message "Down to %s" (treesit-node-type child)))
        (message "No child scope")))))

(defun prologos-surfer-next-sibling ()
  "Move point to the next sibling scope node.
Navigates through wrapper nodes like `top_level' between definitions."
  (interactive)
  (when prologos-surfer-mode
    (let* ((current (or prologos-surfer--current-scope
                        (prologos-surfer--find-scope)))
           (next (and current (prologos-surfer--sibling-scope current 'next))))
      (if next
          (progn
            (prologos-surfer--navigate-to-scope next)
            (message "Right to %s" (treesit-node-type next)))
        (message "No next sibling scope")))))

(defun prologos-surfer-prev-sibling ()
  "Move point to the previous sibling scope node.
Navigates through wrapper nodes like `top_level' between definitions."
  (interactive)
  (when prologos-surfer-mode
    (let* ((current (or prologos-surfer--current-scope
                        (prologos-surfer--find-scope)))
           (prev (and current (prologos-surfer--sibling-scope current 'prev))))
      (if prev
          (progn
            (prologos-surfer--navigate-to-scope prev)
            (message "Left to %s" (treesit-node-type prev)))
        (message "No previous sibling scope")))))

;; ============================================================================
;; Smart Forward/Backward (DFS pre-order traversal)
;; ============================================================================

(defun prologos-surfer-forward ()
  "Move to the next scope node in depth-first pre-order.
Tries: (1) descend into first child scope, (2) advance to next sibling
scope, (3) walk up ancestors trying next sibling at each level.
This provides a linear forward walk through all scope nodes in document
order, similar to `paredit-forward-sexp' but for AST scope nodes."
  (interactive)
  (when prologos-surfer-mode
    (let* ((current (or prologos-surfer--current-scope
                        (prologos-surfer--find-scope)))
           target)
      (when current
        ;; Step 1: try descending into first child scope
        (setq target (prologos-surfer--first-scope-descendant current))
        ;; Step 2: try next sibling scope
        (unless target
          (setq target (prologos-surfer--sibling-scope current 'next)))
        ;; Step 3: walk up ancestors, trying next sibling at each level
        (unless target
          (let ((ancestor (prologos-surfer--find-parent-scope current)))
            (while (and ancestor (not target))
              (if (string= (treesit-node-type ancestor) "source_file")
                  (setq ancestor nil)  ;; stop at top
                (setq target (prologos-surfer--sibling-scope ancestor 'next))
                (unless target
                  (setq ancestor (prologos-surfer--find-parent-scope ancestor)))))))
        (if target
            (progn
              (prologos-surfer--navigate-to-scope target)
              (message "Forward to %s" (treesit-node-type target)))
          (message "No more scopes forward"))))))

(defun prologos-surfer-backward ()
  "Move to the previous scope node in depth-first pre-order.
Tries: (1) go to previous sibling scope's deepest last descendant,
\(2) go to parent scope.
This provides a linear backward walk through all scope nodes in reverse
document order, similar to `paredit-backward-sexp' but for AST scope nodes."
  (interactive)
  (when prologos-surfer-mode
    (let* ((current (or prologos-surfer--current-scope
                        (prologos-surfer--find-scope)))
           target)
      (when current
        ;; Step 1: try previous sibling, navigate to its deepest last descendant
        (let ((prev (prologos-surfer--sibling-scope current 'prev)))
          (when prev
            (setq target (or (prologos-surfer--last-scope-descendant prev) prev))))
        ;; Step 2: go to parent scope
        (unless target
          (let ((parent (prologos-surfer--find-parent-scope current)))
            (when parent
              (setq target parent))))
        (if target
            (progn
              (prologos-surfer--navigate-to-scope target)
              (message "Backward to %s" (treesit-node-type target)))
          (message "No more scopes backward"))))))

;; ============================================================================
;; Selection Commands
;; ============================================================================

(defun prologos-surfer-select-scope ()
  "Mark the region of the current scope node.
Sets point at the start and mark at the end of the scope."
  (interactive)
  (when prologos-surfer-mode
    (let ((current (or prologos-surfer--current-scope
                       (prologos-surfer--find-scope))))
      (if current
          (progn
            (let ((eff-end (prologos-surfer--effective-end current)))
              (goto-char (treesit-node-start current))
              (push-mark eff-end t t)
              (message "Selected %s (%d chars)"
                       (treesit-node-type current)
                       (- eff-end (treesit-node-start current)))))
        (message "No current scope")))))

(defun prologos-surfer-expand-scope ()
  "Expand the scope to the parent scope node and mark the region.
Similar to `expand-region' but using AST scope nodes."
  (interactive)
  (when prologos-surfer-mode
    (let* ((current (or prologos-surfer--current-scope
                        (prologos-surfer--find-scope)))
           (parent (and current (prologos-surfer--find-parent-scope current))))
      (if parent
          (progn
            (prologos-surfer--navigate-to-scope parent)
            (push-mark (prologos-surfer--effective-end parent) t t)
            (message "Expanded to %s" (treesit-node-type parent)))
        (message "Already at top scope")))))

(defun prologos-surfer-contract-scope ()
  "Contract the scope to the first child scope node and mark the region.
Inverse of `prologos-surfer-expand-scope'."
  (interactive)
  (when prologos-surfer-mode
    (let* ((current (or prologos-surfer--current-scope
                        (prologos-surfer--find-scope)))
           (child (and current (prologos-surfer--first-scope-descendant current))))
      (if child
          (progn
            (prologos-surfer--navigate-to-scope child)
            (push-mark (treesit-node-end child) t t)
            (message "Contracted to %s" (treesit-node-type child)))
        (message "No child scope to contract into")))))

;; ============================================================================
;; Repeat-Mode Integration (Emacs 28+)
;; ============================================================================

(defvar prologos-surfer-navigation-repeat-map
  (let ((map (make-sparse-keymap)))
    (define-key map "u" #'prologos-surfer-up-scope)
    (define-key map "d" #'prologos-surfer-down-scope)
    (define-key map "l" #'prologos-surfer-prev-sibling)
    (define-key map "r" #'prologos-surfer-next-sibling)
    (define-key map "e" #'prologos-surfer-expand-scope)
    (define-key map "c" #'prologos-surfer-contract-scope)
    (define-key map "v" #'prologos-surfer-select-scope)
    (define-key map "f" #'prologos-surfer-forward)
    (define-key map "b" #'prologos-surfer-backward)
    map)
  "Repeat map for surfer navigation commands.
After pressing \\`C-c s f', press \\`f' again to keep going forward, etc.")

(dolist (cmd '(prologos-surfer-up-scope
               prologos-surfer-down-scope
               prologos-surfer-prev-sibling
               prologos-surfer-next-sibling
               prologos-surfer-expand-scope
               prologos-surfer-contract-scope
               prologos-surfer-select-scope
               prologos-surfer-forward
               prologos-surfer-backward))
  (put cmd 'repeat-map 'prologos-surfer-navigation-repeat-map))

;; ============================================================================
;; Optional Hydra Integration
;; ============================================================================

(defvar prologos-surfer--hydra-defined nil
  "Non-nil if the surfer hydra has been defined.")

(defun prologos-surfer--maybe-define-hydra ()
  "Define the surfer hydra if `hydra' is available."
  (when (and (not prologos-surfer--hydra-defined)
             (require 'hydra nil t))
    (eval
     '(defhydra prologos-surfer-hydra (:color pink :hint nil)
        "
 Surfer Navigation
 _u_: up scope    _d_: down scope   _v_: select
 _l_: prev sibling  _r_: next sibling
 _f_: forward     _b_: backward
 _e_: expand      _c_: contract     _q_: quit
"
        ("k" prologos-surfer-up-scope)
        ("j" prologos-surfer-down-scope)
        ("h" prologos-surfer-prev-sibling)
        ("l" prologos-surfer-next-sibling)
        ("f" prologos-surfer-forward)
        ("b" prologos-surfer-backward)
        ("e" prologos-surfer-expand-scope)
        ("c" prologos-surfer-contract-scope)
        ("v" prologos-surfer-select-scope)
        ("q" nil :exit t)))
    (setq prologos-surfer--hydra-defined t)))

(defun prologos-surfer-hydra ()
  "Enter the surfer navigation hydra.
Requires the `hydra' package to be installed."
  (interactive)
  (prologos-surfer--maybe-define-hydra)
  (if prologos-surfer--hydra-defined
      (prologos-surfer-hydra/body)
    (message "Hydra package not available; install `hydra' or use repeat-mode")))

(provide 'prologos-surfer-navigation)

;;; prologos-surfer-navigation.el ends here
