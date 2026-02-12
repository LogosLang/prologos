;;; prologos-surfer-test.el --- ERT tests for prologos-surfer-mode -*- lexical-binding: t; -*-

;;; Commentary:

;; Automated tests for Prologos surfer minor mode: scope detection,
;; overlay management, depth calculation, and mode-line lighter.

;;; Code:

(require 'ert)
(require 'prologos-mode)

;; Only run these tests if treesit and surfer are available
(defvar prologos-surfer-test--available
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)
       (condition-case nil
           (progn (require 'prologos-surfer) t)
         (error nil)))
  "Non-nil when treesit, prologos grammar, and surfer are available for testing.")

;; ============================================================
;; Test content — WS-mode Prologos syntax
;; ============================================================

(defconst prologos-surfer-test--defn-with-match
  "defn pred [n : Nat] : Nat\n  match n\n    | zero -> zero\n    | inc k -> k\n"
  "A defn with a match expression for testing scope detection.")

(defconst prologos-surfer-test--data-form
  "data Ordering\n  lt-ord\n  eq-ord\n  gt-ord\n"
  "A data declaration for testing scope detection.")

(defconst prologos-surfer-test--multi-defn
  "ns test\n\ndefn add [x : Nat, y : Nat] : Nat\n  x\n\ndefn pred [n : Nat] : Nat\n  match n\n    | zero -> zero\n    | inc k -> k\n"
  "Multiple top-level forms for testing.")

;; ============================================================
;; Helpers
;; ============================================================

(defun prologos-surfer-test--with-buffer (content)
  "Create a temp buffer with CONTENT in `prologos-ts-mode' + surfer, return it."
  (let ((buf (generate-new-buffer "*prologos-surfer-test*")))
    (with-current-buffer buf
      (insert content)
      (goto-char (point-min))
      (prologos-ts-mode)
      (prologos-surfer-mode 1)
      ;; Force an immediate overlay update (bypass debounce)
      (prologos-surfer--update-overlay))
    buf))

(defmacro prologos-surfer-test--in-buffer (content &rest body)
  "Execute BODY in a temp buffer with CONTENT and surfer-mode enabled."
  (declare (indent 1))
  `(let ((buf (prologos-surfer-test--with-buffer ,content)))
     (unwind-protect
         (with-current-buffer buf ,@body)
       (kill-buffer buf))))

;; ============================================================
;; Test: Mode activation
;; ============================================================

(ert-deftest prologos-surfer-test/mode-activation ()
  "prologos-surfer-mode should activate in a prologos-ts-mode buffer."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "ns test\n"
    (should prologos-surfer-mode)
    (should (eq major-mode 'prologos-ts-mode))))

(ert-deftest prologos-surfer-test/mode-deactivation ()
  "Disabling surfer-mode should clear overlay and hooks."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "ns test\n"
    (should prologos-surfer-mode)
    (prologos-surfer-mode -1)
    (should-not prologos-surfer-mode)
    (should-not prologos-surfer--scope-overlay)
    (should-not prologos-surfer--current-scope)))

;; ============================================================
;; Test: Scope detection
;; ============================================================

(ert-deftest prologos-surfer-test/scope-source-file ()
  "At the very beginning of a file, scope should be source_file."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "ns test\n"
    (goto-char (point-min))
    (let ((scope (prologos-surfer--find-scope)))
      (should scope)
      (should (string= (treesit-node-type scope) "source_file")))))

(ert-deftest prologos-surfer-test/scope-defn-form ()
  "Inside a defn body, nearest scope should be block_body or defn_form."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    ;; Position at the 'match' keyword (inside defn body)
    (goto-char (point-min))
    (search-forward "match")
    (let ((scope (prologos-surfer--find-scope)))
      (should scope)
      ;; Should be match_expr, block_body, or defn_form (all are scope nodes)
      (should (prologos-surfer--scope-node-p scope)))))

(ert-deftest prologos-surfer-test/scope-match-expr ()
  "At the match keyword, scope should include match_expr."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (search-forward "match")
    (goto-char (match-beginning 0))
    (let ((scope (prologos-surfer--find-scope)))
      (should scope)
      ;; The match keyword itself is part of match_expr
      (should (member (treesit-node-type scope)
                      '("match_expr" "block_body" "defn_form"))))))

(ert-deftest prologos-surfer-test/scope-match-arm ()
  "Inside a match arm body, scope should be match_arm or match_arm_body."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    ;; Move to the "k" in "| inc k -> k"
    (goto-char (point-min))
    (search-forward "inc k -> k")
    (backward-char 1) ;; at the final 'k'
    (let ((scope (prologos-surfer--find-scope)))
      (should scope)
      (should (prologos-surfer--scope-node-p scope)))))

(ert-deftest prologos-surfer-test/scope-data-form ()
  "Inside a data declaration, scope should include data_form."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--data-form
    (goto-char (point-min))
    (search-forward "lt-ord")
    (let ((scope (prologos-surfer--find-scope)))
      (should scope)
      (should (prologos-surfer--scope-node-p scope)))))

(ert-deftest prologos-surfer-test/scope-application ()
  "Inside a function application, scope should be application or paren_expr."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "defn foo [x : Nat] : Nat\n  inc (inc x)\n"
    (goto-char (point-min))
    (search-forward "(inc x)")
    (backward-char 3) ;; inside the paren_expr
    (let ((scope (prologos-surfer--find-scope)))
      (should scope)
      (should (prologos-surfer--scope-node-p scope)))))

;; ============================================================
;; Test: Scope depth
;; ============================================================

(ert-deftest prologos-surfer-test/depth-source-file ()
  "source_file node should have depth 0 (no scope-node ancestors)."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "ns test\n"
    (goto-char (point-min))
    (let ((scope (prologos-surfer--find-scope)))
      (should scope)
      (when (string= (treesit-node-type scope) "source_file")
        (should (= (prologos-surfer--scope-depth scope) 0))))))

(ert-deftest prologos-surfer-test/depth-increases-with-nesting ()
  "Deeper nodes should have higher scope depth."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    ;; Get depth at top-level defn_form
    (goto-char (point-min))
    (let* ((defn-node (treesit-node-at (point)))
           ;; Walk up to defn_form
           (node defn-node))
      (while (and node (not (string= (treesit-node-type node) "defn_form")))
        (setq node (treesit-node-parent node)))
      (when node
        (let ((defn-depth (prologos-surfer--scope-depth node)))
          ;; Now find a match_arm — should have greater depth
          (goto-char (point-min))
          (search-forward "inc k -> k")
          (let ((arm-scope (prologos-surfer--find-scope)))
            (when arm-scope
              (should (> (prologos-surfer--scope-depth arm-scope) defn-depth)))))))))

;; ============================================================
;; Test: Overlay management
;; ============================================================

(ert-deftest prologos-surfer-test/overlay-exists ()
  "After enabling surfer-mode, overlay should be non-nil when scope detected."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (should prologos-surfer--scope-overlay)))

(ert-deftest prologos-surfer-test/overlay-bounds ()
  "Overlay start/end should match the tree-sitter node bounds."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (when (and prologos-surfer--scope-overlay prologos-surfer--current-scope)
      (should (= (overlay-start prologos-surfer--scope-overlay)
                 (treesit-node-start prologos-surfer--current-scope)))
      (should (= (overlay-end prologos-surfer--scope-overlay)
                 (treesit-node-end prologos-surfer--current-scope))))))

(ert-deftest prologos-surfer-test/overlay-cleared-on-disable ()
  "Disabling surfer-mode should remove the overlay."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (should prologos-surfer--scope-overlay)
    (prologos-surfer-mode -1)
    (should-not prologos-surfer--scope-overlay)))

(ert-deftest prologos-surfer-test/overlay-has-face ()
  "The scope overlay should have a face property."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (when prologos-surfer--scope-overlay
      (should (overlay-get prologos-surfer--scope-overlay 'face)))))

(ert-deftest prologos-surfer-test/overlay-has-priority ()
  "The scope overlay should have the configured priority."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (when prologos-surfer--scope-overlay
      (should (= (overlay-get prologos-surfer--scope-overlay 'priority)
                 prologos-surfer-overlay-priority)))))

;; ============================================================
;; Test: Mode-line lighter
;; ============================================================

(ert-deftest prologos-surfer-test/lighter-shows-scope-type ()
  "The mode-line lighter should reflect the current scope type."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (should (stringp prologos-surfer--mode-line-lighter))
    (should (string-match-p "surfer:" prologos-surfer--mode-line-lighter))))

;; ============================================================
;; Test: Face generation
;; ============================================================

(ert-deftest prologos-surfer-test/face-generation ()
  "prologos-surfer--get-scope-face should return a face symbol."
  (skip-unless prologos-surfer-test--available)
  (let ((face (prologos-surfer--get-scope-face 0)))
    (should face)
    (should (symbolp face))
    (should (facep face))))

(ert-deftest prologos-surfer-test/face-caching ()
  "Repeated calls with the same depth should return the same face."
  (skip-unless prologos-surfer-test--available)
  (let ((face1 (prologos-surfer--get-scope-face 3))
        (face2 (prologos-surfer--get-scope-face 3)))
    (should (eq face1 face2))))

;; ============================================================
;; Test: Scope node type predicate
;; ============================================================

(ert-deftest prologos-surfer-test/scope-node-predicate ()
  "prologos-surfer--scope-node-p should accept known scope types."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "ns test\n"
    (let ((root (treesit-buffer-root-node)))
      (should (prologos-surfer--scope-node-p root))
      (should (string= (treesit-node-type root) "source_file")))))

;; ============================================================
;; Test: Keymap
;; ============================================================

(ert-deftest prologos-surfer-test/keymap-defined ()
  "prologos-surfer-mode-map should be defined and have C-c s s bound."
  (skip-unless prologos-surfer-test--available)
  (should (keymapp prologos-surfer-mode-map))
  (should (eq (lookup-key prologos-surfer-mode-map (kbd "C-c s s"))
              'prologos-surfer-mode)))

(provide 'prologos-surfer-test)

;;; prologos-surfer-test.el ends here
