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
  "Overlay start/end should match the trimmed node bounds (effective-end)."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (when (and prologos-surfer--scope-overlay prologos-surfer--current-scope)
      (should (= (overlay-start prologos-surfer--scope-overlay)
                 (treesit-node-start prologos-surfer--current-scope)))
      (should (= (overlay-end prologos-surfer--scope-overlay)
                 (prologos-surfer--effective-end prologos-surfer--current-scope))))))

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

;; ============================================================
;; Sprint 2: Navigation Tests
;; ============================================================

(defun prologos-surfer-test--navigate-up-to (target-type)
  "Navigate up-scope until reaching TARGET-TYPE or source_file.
Returns non-nil if TARGET-TYPE was reached."
  (let ((safety 0))
    (while (and prologos-surfer--current-scope
                (not (member (treesit-node-type prologos-surfer--current-scope)
                             (if (listp target-type) target-type
                               (list target-type "source_file"))))
                (< safety 15))
      (prologos-surfer-up-scope)
      (setq safety (1+ safety))))
  (and prologos-surfer--current-scope
       (if (listp target-type)
           (member (treesit-node-type prologos-surfer--current-scope) target-type)
         (string= (treesit-node-type prologos-surfer--current-scope) target-type))))

;; --- Public API ---

(ert-deftest prologos-surfer-test/current-scope-accessor ()
  "prologos-surfer-current-scope should return the current scope node."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (should (prologos-surfer-current-scope))
    (should (eq (prologos-surfer-current-scope) prologos-surfer--current-scope))))

(ert-deftest prologos-surfer-test/navigate-to-scope-instant ()
  "prologos-surfer--navigate-to-scope should update scope and overlay immediately."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (let ((root (treesit-buffer-root-node)))
      (prologos-surfer--navigate-to-scope root)
      (should (eq prologos-surfer--current-scope root))
      (should (= (point) (treesit-node-start root)))
      (should prologos-surfer--scope-overlay)
      (should (= (overlay-start prologos-surfer--scope-overlay)
                 (treesit-node-start root))))))

;; --- up-scope ---

(ert-deftest prologos-surfer-test/up-scope-from-match-arm ()
  "up-scope from a match arm should move to an ancestor scope."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (search-forward "inc k -> k")
    (backward-char 1)
    (prologos-surfer--update-overlay)
    (let ((arm-start (treesit-node-start prologos-surfer--current-scope)))
      (prologos-surfer-up-scope)
      (should prologos-surfer--current-scope)
      (should (< (treesit-node-start prologos-surfer--current-scope) arm-start)))))

(ert-deftest prologos-surfer-test/up-scope-to-defn ()
  "up-scope repeatedly should eventually reach defn_form."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (search-forward "inc k -> k")
    (backward-char 1)
    (prologos-surfer--update-overlay)
    ;; Navigate up repeatedly until we reach defn_form or source_file
    (prologos-surfer-test--navigate-up-to '("defn_form" "source_file"))
    (should prologos-surfer--current-scope)
    (should (member (treesit-node-type prologos-surfer--current-scope)
                    '("defn_form" "source_file")))))

(ert-deftest prologos-surfer-test/up-scope-at-top ()
  "up-scope at source_file should show message and stay put."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "ns test\n"
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (should (string= (treesit-node-type prologos-surfer--current-scope) "source_file"))
    (let ((pos (point)))
      (prologos-surfer-up-scope)
      ;; Should remain at source_file (no parent scope)
      (should (string= (treesit-node-type prologos-surfer--current-scope) "source_file")))))

;; --- down-scope ---

(ert-deftest prologos-surfer-test/down-scope-from-source-file ()
  "down-scope from source_file should reach a definition form."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    ;; Walk to source_file first
    (prologos-surfer-test--navigate-up-to '("source_file"))
    (should (string= (treesit-node-type prologos-surfer--current-scope) "source_file"))
    (prologos-surfer-down-scope)
    (should prologos-surfer--current-scope)
    ;; Should have descended into a scope node (defn_form, through top_level wrapper)
    (should (prologos-surfer--scope-node-p prologos-surfer--current-scope))
    (should-not (string= (treesit-node-type prologos-surfer--current-scope) "source_file"))))

(ert-deftest prologos-surfer-test/down-scope-from-defn ()
  "down-scope from defn_form should reach block_body or match_expr."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (search-forward "match")
    (prologos-surfer--update-overlay)
    ;; Navigate up to defn_form
    (prologos-surfer-test--navigate-up-to "defn_form")
    (when (and prologos-surfer--current-scope
               (string= (treesit-node-type prologos-surfer--current-scope) "defn_form"))
      (prologos-surfer-down-scope)
      (should prologos-surfer--current-scope)
      (should (member (treesit-node-type prologos-surfer--current-scope)
                      '("block_body" "match_expr" "match_arm" "application"))))))

(ert-deftest prologos-surfer-test/down-scope-no-children ()
  "down-scope with no child scope should stay put."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "defn x : Nat\n  zero\n"
    (goto-char (point-min))
    (search-forward "zero")
    (prologos-surfer--update-overlay)
    ;; Try going down — should reach a leaf where further down is impossible
    (let ((safety 0))
      (while (< safety 10)
        (let ((prev-start (treesit-node-start prologos-surfer--current-scope))
              (prev-end (treesit-node-end prologos-surfer--current-scope)))
          (prologos-surfer-down-scope)
          (if (and (= (treesit-node-start prologos-surfer--current-scope) prev-start)
                   (= (treesit-node-end prologos-surfer--current-scope) prev-end))
              (setq safety 10)  ; scope didn't change — we're at a leaf
            (setq safety (1+ safety))))))
    (should prologos-surfer--current-scope)))

;; --- next-sibling ---

(ert-deftest prologos-surfer-test/next-sibling-defn-forms ()
  "next-sibling should navigate between top-level defn_forms."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    ;; Navigate to the first defn_form (add)
    (goto-char (point-min))
    (search-forward "defn add")
    (prologos-surfer--update-overlay)
    ;; Walk up to defn_form
    (prologos-surfer-test--navigate-up-to "defn_form")
    (should (string= (treesit-node-type prologos-surfer--current-scope) "defn_form"))
    (let ((first-start (treesit-node-start prologos-surfer--current-scope)))
      ;; Navigate to next sibling
      (prologos-surfer-next-sibling)
      (should prologos-surfer--current-scope)
      (should (> (treesit-node-start prologos-surfer--current-scope) first-start))
      ;; Should also be a defn_form
      (should (string= (treesit-node-type prologos-surfer--current-scope) "defn_form")))))

(ert-deftest prologos-surfer-test/next-sibling-match-arms ()
  "next-sibling should navigate between match arms."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    ;; Position at first arm "| zero -> zero"
    (goto-char (point-min))
    (search-forward "zero -> zero")
    (prologos-surfer--update-overlay)
    ;; Walk up to match_arm
    (prologos-surfer-test--navigate-up-to "match_arm")
    (should (and prologos-surfer--current-scope
                 (string= (treesit-node-type prologos-surfer--current-scope) "match_arm")))
    (let ((first-arm-start (treesit-node-start prologos-surfer--current-scope)))
      (prologos-surfer-next-sibling)
      (should prologos-surfer--current-scope)
      (should (> (treesit-node-start prologos-surfer--current-scope) first-arm-start))
      (should (string= (treesit-node-type prologos-surfer--current-scope) "match_arm")))))

(ert-deftest prologos-surfer-test/next-sibling-at-last ()
  "next-sibling at the last sibling should show message and stay put."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    ;; Navigate to last defn_form (pred)
    (goto-char (point-min))
    (search-forward "defn pred")
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    (let ((last-start (treesit-node-start prologos-surfer--current-scope)))
      (prologos-surfer-next-sibling)
      ;; Should still be at the same scope (no next sibling)
      (should (= (treesit-node-start prologos-surfer--current-scope) last-start)))))

(ert-deftest prologos-surfer-test/next-sibling-point-moves ()
  "next-sibling should move point to the start of the sibling scope."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    (goto-char (point-min))
    (search-forward "defn add")
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    (prologos-surfer-next-sibling)
    (when prologos-surfer--current-scope
      (should (= (point) (treesit-node-start prologos-surfer--current-scope))))))

;; --- prev-sibling ---

(ert-deftest prologos-surfer-test/prev-sibling-defn-forms ()
  "prev-sibling should navigate backward between defn_forms."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    ;; Navigate to the second defn_form (pred)
    (goto-char (point-min))
    (search-forward "defn pred")
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    (let ((second-start (treesit-node-start prologos-surfer--current-scope)))
      (prologos-surfer-prev-sibling)
      (should prologos-surfer--current-scope)
      (should (< (treesit-node-start prologos-surfer--current-scope) second-start))
      (should (string= (treesit-node-type prologos-surfer--current-scope) "defn_form")))))

(ert-deftest prologos-surfer-test/prev-sibling-match-arms ()
  "prev-sibling should navigate backward between match arms."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    ;; Position inside second arm "| inc k -> k"
    (goto-char (point-min))
    (search-forward "| inc")
    (backward-char 2)  ;; point inside "inc" text, within the match_arm
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "match_arm")
    (should (and prologos-surfer--current-scope
                 (string= (treesit-node-type prologos-surfer--current-scope) "match_arm")))
    (let ((second-arm-start (treesit-node-start prologos-surfer--current-scope)))
      (prologos-surfer-prev-sibling)
      (should prologos-surfer--current-scope)
      (should (< (treesit-node-start prologos-surfer--current-scope) second-arm-start))
      (should (string= (treesit-node-type prologos-surfer--current-scope) "match_arm")))))

(ert-deftest prologos-surfer-test/prev-sibling-at-first ()
  "prev-sibling at the first sibling should stay put."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    ;; Navigate to first defn_form (add)
    (goto-char (point-min))
    (search-forward "defn add")
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    (let ((first-start (treesit-node-start prologos-surfer--current-scope)))
      (prologos-surfer-prev-sibling)
      ;; Should still be at the same scope (no prev sibling)
      (should (= (treesit-node-start prologos-surfer--current-scope) first-start)))))

;; --- select-scope ---

(ert-deftest prologos-surfer-test/select-scope-region-active ()
  "select-scope should set mark at the scope end."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (prologos-surfer-select-scope)
    ;; Mark should be set (push-mark was called)
    (should (mark t))
    ;; Point should be at scope start
    (should (= (point) (treesit-node-start prologos-surfer--current-scope)))))

(ert-deftest prologos-surfer-test/select-scope-region-bounds ()
  "select-scope region should match the scope node bounds."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (let ((scope prologos-surfer--current-scope))
      (prologos-surfer-select-scope)
      (when scope
        (should (= (point) (treesit-node-start scope)))
        (should (= (mark) (treesit-node-end scope)))))))

;; --- expand-scope ---

(ert-deftest prologos-surfer-test/expand-scope ()
  "expand-scope should move to parent scope."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (search-forward "inc k -> k")
    (backward-char 1)
    (prologos-surfer--update-overlay)
    (let ((inner-start (treesit-node-start prologos-surfer--current-scope)))
      (prologos-surfer-expand-scope)
      (should prologos-surfer--current-scope)
      (should (< (treesit-node-start prologos-surfer--current-scope) inner-start)))))

(ert-deftest prologos-surfer-test/expand-scope-at-top ()
  "expand-scope at source_file should stay put."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "ns test\n"
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (should (string= (treesit-node-type prologos-surfer--current-scope) "source_file"))
    (prologos-surfer-expand-scope)
    (should (string= (treesit-node-type prologos-surfer--current-scope) "source_file"))))

;; --- contract-scope ---

(ert-deftest prologos-surfer-test/contract-scope ()
  "contract-scope should move to first child scope."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    ;; Walk to source_file
    (prologos-surfer-test--navigate-up-to '("source_file"))
    (should (string= (treesit-node-type prologos-surfer--current-scope) "source_file"))
    (prologos-surfer-contract-scope)
    (should prologos-surfer--current-scope)
    (should-not (string= (treesit-node-type prologos-surfer--current-scope) "source_file"))))

(ert-deftest prologos-surfer-test/contract-scope-no-children ()
  "contract-scope at a leaf scope should stay put."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "defn x : Nat\n  zero\n"
    (goto-char (point-min))
    (search-forward "zero")
    (prologos-surfer--update-overlay)
    ;; Descend as far as possible
    (let ((safety 0))
      (while (< safety 10)
        (let ((prev-start (treesit-node-start prologos-surfer--current-scope))
              (prev-end (treesit-node-end prologos-surfer--current-scope)))
          (prologos-surfer-down-scope)
          (if (and (= (treesit-node-start prologos-surfer--current-scope) prev-start)
                   (= (treesit-node-end prologos-surfer--current-scope) prev-end))
              (setq safety 10)
            (setq safety (1+ safety))))))
    ;; Now at a leaf — contract should stay put
    (let ((leaf-start (treesit-node-start prologos-surfer--current-scope))
          (leaf-end (treesit-node-end prologos-surfer--current-scope)))
      (prologos-surfer-contract-scope)
      (should (= (treesit-node-start prologos-surfer--current-scope) leaf-start))
      (should (= (treesit-node-end prologos-surfer--current-scope) leaf-end)))))

;; --- Keybindings ---

(ert-deftest prologos-surfer-test/keybinding-up ()
  "C-c s u should be bound to prologos-surfer-up-scope."
  (skip-unless prologos-surfer-test--available)
  (should (eq (lookup-key prologos-surfer-mode-map (kbd "C-c s u"))
              'prologos-surfer-up-scope)))

(ert-deftest prologos-surfer-test/keybinding-select ()
  "C-c s v should be bound to prologos-surfer-select-scope."
  (skip-unless prologos-surfer-test--available)
  (should (eq (lookup-key prologos-surfer-mode-map (kbd "C-c s v"))
              'prologos-surfer-select-scope)))

(ert-deftest prologos-surfer-test/keybinding-hydra ()
  "C-c s h should be bound to prologos-surfer-hydra."
  (skip-unless prologos-surfer-test--available)
  (should (eq (lookup-key prologos-surfer-mode-map (kbd "C-c s h"))
              'prologos-surfer-hydra)))

;; --- Repeat-mode ---

(ert-deftest prologos-surfer-test/repeat-map-exists ()
  "prologos-surfer-navigation-repeat-map should be a keymap."
  (skip-unless prologos-surfer-test--available)
  (should (keymapp prologos-surfer-navigation-repeat-map)))

(ert-deftest prologos-surfer-test/repeat-map-property ()
  "Navigation commands should have the repeat-map property set."
  (skip-unless prologos-surfer-test--available)
  (should (eq (get 'prologos-surfer-up-scope 'repeat-map)
              'prologos-surfer-navigation-repeat-map))
  (should (eq (get 'prologos-surfer-down-scope 'repeat-map)
              'prologos-surfer-navigation-repeat-map))
  (should (eq (get 'prologos-surfer-next-sibling 'repeat-map)
              'prologos-surfer-navigation-repeat-map)))

;; --- Hydra ---

(ert-deftest prologos-surfer-test/hydra-defcustom-exists ()
  "prologos-surfer-use-hydra defcustom should exist."
  (skip-unless prologos-surfer-test--available)
  (should (boundp 'prologos-surfer-use-hydra)))

(ert-deftest prologos-surfer-test/hydra-command-defined ()
  "prologos-surfer-hydra command should be defined."
  (skip-unless prologos-surfer-test--available)
  (should (fboundp 'prologos-surfer-hydra)))

;; --- Forward ---

(ert-deftest prologos-surfer-test/forward-down-into-child ()
  "forward from source_file should descend into the first defn_form."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "source_file")
    (should (string= (treesit-node-type prologos-surfer--current-scope) "source_file"))
    (prologos-surfer-forward)
    (should prologos-surfer--current-scope)
    (should (string= (treesit-node-type prologos-surfer--current-scope) "defn_form"))))

(ert-deftest prologos-surfer-test/forward-next-sibling ()
  "forward from a leaf match_arm_body should advance to next match_arm."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    ;; Navigate to first match_arm_body (inside "| zero -> zero")
    (goto-char (point-min))
    (search-forward "| zero")
    (backward-char 2)
    (prologos-surfer--update-overlay)
    ;; Walk down to the deepest scope in the first arm
    (let ((safety 0))
      (while (< safety 10)
        (let ((prev-start (treesit-node-start prologos-surfer--current-scope)))
          (prologos-surfer-down-scope)
          (if (= (treesit-node-start prologos-surfer--current-scope) prev-start)
              (setq safety 10)
            (setq safety (1+ safety))))))
    ;; Now at a leaf scope — forward should advance to the next match_arm
    (let ((pos-before (point)))
      (prologos-surfer-forward)
      (should (> (point) pos-before)))))

(ert-deftest prologos-surfer-test/forward-up-then-next ()
  "forward from inside defn_form(add) should cross to defn_form(pred)."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    ;; Navigate to inside defn add
    (goto-char (point-min))
    (search-forward "defn add")
    (backward-char 3)
    (prologos-surfer--update-overlay)
    ;; Forward repeatedly until we leave defn add or hit the next defn
    ;; Get position of defn pred
    (let ((pred-pos (save-excursion (goto-char (point-min)) (search-forward "defn pred") (match-beginning 0)))
          (safety 0))
      (while (and (< (point) pred-pos) (< safety 30))
        (prologos-surfer-forward)
        (setq safety (1+ safety)))
      ;; Should have arrived at defn_form(pred) or past it
      (should (>= (point) pred-pos))
      (should (string= (treesit-node-type prologos-surfer--current-scope) "defn_form")))))

(ert-deftest prologos-surfer-test/forward-at-end ()
  "forward at last scope in file should show message."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer "defn x : Nat\n  zero\n"
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    ;; Forward repeatedly to the end
    (let ((safety 0)
          (prev-pos -1))
      (while (and (not (= (point) prev-pos)) (< safety 30))
        (setq prev-pos (point))
        (prologos-surfer-forward)
        (setq safety (1+ safety)))
      ;; At the end, point should not have moved
      (should (= (point) prev-pos)))))

(ert-deftest prologos-surfer-test/forward-point-moves-forward ()
  "forward should always move point forward in the buffer."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    ;; Forward 5 times — point should always increase (or stay at end)
    (let ((prev-pos (point))
          (moved-count 0))
      (dotimes (_ 5)
        (prologos-surfer-forward)
        (when (> (point) prev-pos)
          (setq moved-count (1+ moved-count)))
        (should (>= (point) prev-pos))
        (setq prev-pos (point)))
      ;; At least some moves should have moved forward
      (should (> moved-count 0)))))

(ert-deftest prologos-surfer-test/forward-full-traversal ()
  "Repeated forward from source_file should visit multiple distinct scope nodes."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "source_file")
    ;; Collect all scope types visited by forward
    (let ((visited (list (treesit-node-type prologos-surfer--current-scope)))
          (safety 0))
      (while (< safety 30)
        (let ((prev-type (treesit-node-type prologos-surfer--current-scope))
              (prev-start (treesit-node-start prologos-surfer--current-scope))
              (prev-end (treesit-node-end prologos-surfer--current-scope)))
          (prologos-surfer-forward)
          (if (and (string= (treesit-node-type prologos-surfer--current-scope) prev-type)
                   (= (treesit-node-start prologos-surfer--current-scope) prev-start)
                   (= (treesit-node-end prologos-surfer--current-scope) prev-end))
              (setq safety 30)  ;; same node — stop
            (push (treesit-node-type prologos-surfer--current-scope) visited)
            (setq safety (1+ safety)))))
      ;; Should visit several distinct scope node types
      (setq visited (nreverse visited))
      (should (> (length visited) 3))  ;; at least source_file, defn_form, block_body, match_expr
      ;; First should be source_file, second defn_form
      (should (string= (car visited) "source_file"))
      (should (string= (cadr visited) "defn_form")))))

;; --- Backward ---

(ert-deftest prologos-surfer-test/backward-to-parent ()
  "backward from a first child (no prev sibling) should go to parent."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    ;; Navigate to first match_arm
    (goto-char (point-min))
    (search-forward "| zero")
    (backward-char 2)
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "match_arm")
    (should (string= (treesit-node-type prologos-surfer--current-scope) "match_arm"))
    ;; Backward should go to parent match_expr
    (prologos-surfer-backward)
    (should prologos-surfer--current-scope)
    (should (string= (treesit-node-type prologos-surfer--current-scope) "match_expr"))))

(ert-deftest prologos-surfer-test/backward-to-prev-sibling-deepest ()
  "backward should go to prev sibling's deepest last descendant."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    ;; Navigate to defn pred (second defn)
    (goto-char (point-min))
    (search-forward "defn pred")
    (backward-char 4)
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    ;; Verify we are at the second defn_form
    (let ((defn-start (treesit-node-start prologos-surfer--current-scope)))
      (should (> defn-start (point-min)))
      ;; Backward should go deep into defn add, not to defn add itself
      (prologos-surfer-backward)
      (should prologos-surfer--current-scope)
      ;; The target should be inside defn add (deeper than defn_form level)
      (should (< (point) defn-start)))))

(ert-deftest prologos-surfer-test/backward-at-start ()
  "backward at source_file should show message and stay."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    (goto-char (point-min))
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "source_file")
    (should (string= (treesit-node-type prologos-surfer--current-scope) "source_file"))
    (let ((pos-before (point)))
      (prologos-surfer-backward)
      ;; Should not have moved (source_file has no parent)
      (should (= (point) pos-before)))))

(ert-deftest prologos-surfer-test/backward-point-moves-backward ()
  "backward should move point backward (or stay) in the buffer."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--defn-with-match
    ;; Start at the end of the buffer and navigate to some deep scope
    (goto-char (point-max))
    (search-backward "k")
    (prologos-surfer--update-overlay)
    ;; Backward 5 times — point should always decrease (or stay)
    (let ((prev-pos (point))
          (moved-count 0))
      (dotimes (_ 5)
        (prologos-surfer-backward)
        (when (< (point) prev-pos)
          (setq moved-count (1+ moved-count)))
        (should (<= (point) prev-pos))
        (setq prev-pos (point)))
      ;; At least some moves should have gone backward
      (should (> moved-count 0)))))

(ert-deftest prologos-surfer-test/backward-from-second-defn ()
  "backward from defn_form(pred) should go deep into defn_form(add)."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    ;; Navigate to defn pred
    (goto-char (point-min))
    (search-forward "defn pred")
    (backward-char 4)
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    (let ((pred-start (treesit-node-start prologos-surfer--current-scope)))
      (prologos-surfer-backward)
      ;; Should be inside defn add's subtree, not at defn_form(add) itself
      ;; (because backward goes to prev sibling's *last* descendant)
      (should (< (point) pred-start))
      (should prologos-surfer--current-scope)
      ;; Should NOT be at defn_form level — should be deeper
      (should-not (string= (treesit-node-type prologos-surfer--current-scope) "defn_form")))))

;; --- Forward/Backward keybindings and repeat-map ---

(ert-deftest prologos-surfer-test/keybinding-forward ()
  "C-c s f should be bound to prologos-surfer-forward."
  (skip-unless prologos-surfer-test--available)
  (should (eq (lookup-key prologos-surfer-mode-map (kbd "C-c s f"))
              'prologos-surfer-forward)))

(ert-deftest prologos-surfer-test/keybinding-backward ()
  "C-c s b should be bound to prologos-surfer-backward."
  (skip-unless prologos-surfer-test--available)
  (should (eq (lookup-key prologos-surfer-mode-map (kbd "C-c s b"))
              'prologos-surfer-backward)))

(ert-deftest prologos-surfer-test/repeat-map-forward-backward ()
  "forward and backward should have the repeat-map property set."
  (skip-unless prologos-surfer-test--available)
  (should (eq (get 'prologos-surfer-forward 'repeat-map)
              'prologos-surfer-navigation-repeat-map))
  (should (eq (get 'prologos-surfer-backward 'repeat-map)
              'prologos-surfer-navigation-repeat-map)))

;; ============================================================
;; Boundary Trimming (--effective-end) Tests
;; ============================================================

(ert-deftest prologos-surfer-test/effective-end-defn-form ()
  "effective-end of defn_form(add) should stop at end of body, not extend into blank line."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    (goto-char (point-min))
    (search-forward "defn add")
    (backward-char 3)
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    (should prologos-surfer--current-scope)
    (should (string= (treesit-node-type prologos-surfer--current-scope) "defn_form"))
    (let* ((eff-end (prologos-surfer--effective-end prologos-surfer--current-scope))
           (raw-end (treesit-node-end prologos-surfer--current-scope))
           (node-start (treesit-node-start prologos-surfer--current-scope)))
      ;; effective-end should be strictly less than raw end (trailing blank trimmed)
      (should (< eff-end raw-end))
      ;; The text from start to eff-end should contain "x" (body) but
      ;; NOT contain "defn pred" (the next definition)
      (let ((selected (buffer-substring-no-properties node-start eff-end)))
        (should (string-match-p "defn add" selected))
        (should (string-match-p "x" selected))
        (should-not (string-match-p "defn pred" selected))))))

(ert-deftest prologos-surfer-test/effective-end-match-arm ()
  "effective-end of first match_arm should stop at end of arm, not extend into next arm indent."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    (goto-char (point-min))
    (search-forward "| zero")
    (backward-char 2)
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "match_arm")
    (should prologos-surfer--current-scope)
    (should (string= (treesit-node-type prologos-surfer--current-scope) "match_arm"))
    (let* ((eff-end (prologos-surfer--effective-end prologos-surfer--current-scope))
           (raw-end (treesit-node-end prologos-surfer--current-scope)))
      ;; effective-end should be <= raw end
      (should (<= eff-end raw-end))
      ;; The text from start to effective-end should contain "zero" but NOT "inc"
      (let ((selected (buffer-substring-no-properties
                       (treesit-node-start prologos-surfer--current-scope)
                       eff-end)))
        (should (string-match-p "zero" selected))
        (should-not (string-match-p "inc" selected))))))

(ert-deftest prologos-surfer-test/overlay-uses-trimmed-end ()
  "Overlay end position should equal effective-end, not raw treesit-node-end."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    (goto-char (point-min))
    (search-forward "defn add")
    (backward-char 3)
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    (should prologos-surfer--current-scope)
    ;; Force overlay redraw
    (prologos-surfer--redraw-overlay)
    (should prologos-surfer--scope-overlay)
    (let ((ov-end (overlay-end prologos-surfer--scope-overlay))
          (eff-end (prologos-surfer--effective-end prologos-surfer--current-scope))
          (raw-end (treesit-node-end prologos-surfer--current-scope)))
      ;; Overlay end should match effective-end
      (should (= ov-end eff-end))
      ;; And effective-end should be <= raw end
      (should (<= eff-end raw-end)))))

(ert-deftest prologos-surfer-test/select-scope-trimmed-region ()
  "After select-scope, mark should be at effective-end, not raw node-end."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    (goto-char (point-min))
    (search-forward "defn pred")
    (backward-char 4)
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    (should prologos-surfer--current-scope)
    (should (string= (treesit-node-type prologos-surfer--current-scope) "defn_form"))
    (prologos-surfer-select-scope)
    ;; mark should be at effective-end
    (let ((expected-end (prologos-surfer--effective-end prologos-surfer--current-scope)))
      (should (= (mark) expected-end))
      ;; point should be at node start
      (should (= (point) (treesit-node-start prologos-surfer--current-scope))))))

(ert-deftest prologos-surfer-test/select-scope-copy-paste-clean ()
  "kill-ring-save + yank after select-scope should produce text without trailing blank lines."
  (skip-unless prologos-surfer-test--available)
  (prologos-surfer-test--in-buffer prologos-surfer-test--multi-defn
    (goto-char (point-min))
    (search-forward "defn add")
    (backward-char 3)
    (prologos-surfer--update-overlay)
    (prologos-surfer-test--navigate-up-to "defn_form")
    (should prologos-surfer--current-scope)
    ;; Select and copy
    (prologos-surfer-select-scope)
    (kill-ring-save (point) (mark))
    ;; Yank into a clean buffer and verify no trailing blank lines
    (let ((paste-buf (generate-new-buffer "*paste-test*")))
      (unwind-protect
          (with-current-buffer paste-buf
            (yank)
            (let ((text (buffer-string)))
              ;; Should contain the defn
              (should (string-match-p "defn add" text))
              ;; Should NOT have trailing blank lines
              (should-not (string-match-p "\n\n\\'" text))
              ;; Should NOT contain the next defn or comments from after
              (should-not (string-match-p "defn pred" text))))
        (kill-buffer paste-buf)))))

(provide 'prologos-surfer-test)

;;; prologos-surfer-test.el ends here
