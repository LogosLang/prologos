;;; prologos-indent-test.el --- ERT tests for Prologos indentation -*- lexical-binding: t; -*-

;;; Commentary:

;; Automated tests for Prologos indentation engine.
;; Tests cover sexp-mode form-specific indentation and WS-mode
;; semantic indentation preservation.

;;; Code:

(require 'ert)
(require 'prologos-mode)

;; ============================================================
;; Helpers
;; ============================================================

(defun prologos-indent-test--strip-indent (s)
  "Remove all leading whitespace from each line of S."
  (mapconcat (lambda (line) (string-trim-left line))
             (split-string s "\n")
             "\n"))

(defun prologos-indent-test--indent-buffer ()
  "Indent every line in the current buffer using prologos-mode."
  (goto-char (point-min))
  (while (not (eobp))
    (prologos-indent-line)
    (forward-line 1)))

(defun prologos-indent-test--check (expected)
  "Check that indenting the stripped version of EXPECTED produces EXPECTED.
Creates a buffer, inserts the content with all leading whitespace removed,
activates prologos-mode, indents every line, and compares."
  (let ((buf (generate-new-buffer "*prologos-indent-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert (prologos-indent-test--strip-indent expected))
          (goto-char (point-min))
          (prologos-mode)
          (syntax-propertize (point-max))
          (prologos-indent-test--indent-buffer)
          (let ((result (buffer-string)))
            (should (string= result expected))))
      (kill-buffer buf))))

(defun prologos-indent-test--check-line (content line-num expected-col)
  "Check that line LINE-NUM in CONTENT gets indented to EXPECTED-COL.
LINE-NUM is 1-based."
  (let ((buf (generate-new-buffer "*prologos-indent-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert content)
          (goto-char (point-min))
          (prologos-mode)
          (syntax-propertize (point-max))
          (prologos-indent-test--indent-buffer)
          (goto-char (point-min))
          (forward-line (1- line-num))
          (should (= (current-indentation) expected-col)))
      (kill-buffer buf))))

;; ============================================================
;; Test: def indentation
;; ============================================================

(ert-deftest prologos-indent-test/def-body ()
  "Body of def should be indented 2 from opening paren."
  (prologos-indent-test--check
   "(def one\n  (inc zero))"))

(ert-deftest prologos-indent-test/def-single-line ()
  "Single-line def should stay on one line (no indent change)."
  (prologos-indent-test--check
   "(def x <Nat> zero)"))

;; ============================================================
;; Test: defn indentation
;; ============================================================

(ert-deftest prologos-indent-test/defn-body ()
  "Body of defn should be indented 2 from opening paren."
  (prologos-indent-test--check
   "(defn double [x <Nat>] <Nat>\n  (add x x))"))

(ert-deftest prologos-indent-test/defn-with-match ()
  "Match inside defn: match at 2, arms at 4."
  (prologos-indent-test--check-line
   "(defn pred [n <Nat>] <Nat>\n  (match n\n    zero -> zero\n    (inc k) -> k))"
   2 2)   ;; match line at column 2
  (prologos-indent-test--check-line
   "(defn pred [n <Nat>] <Nat>\n  (match n\n    zero -> zero\n    (inc k) -> k))"
   3 4)   ;; first arm at column 4
  (prologos-indent-test--check-line
   "(defn pred [n <Nat>] <Nat>\n  (match n\n    zero -> zero\n    (inc k) -> k))"
   4 4))  ;; second arm at column 4

;; ============================================================
;; Test: fn indentation
;; ============================================================

(ert-deftest prologos-indent-test/fn-body ()
  "Body of fn should be indented 2 from fn."
  (prologos-indent-test--check
   "(fn [x <Nat>]\n  (inc x))"))

;; ============================================================
;; Test: match indentation
;; ============================================================

(ert-deftest prologos-indent-test/match-arms ()
  "Match arms should be indented 2 from match."
  (prologos-indent-test--check
   "(match n\n  zero -> zero\n  (inc k) -> k)"))

;; ============================================================
;; Test: let indentation
;; ============================================================

(ert-deftest prologos-indent-test/let-body ()
  "Body of let should be indented 2 from let."
  (prologos-indent-test--check-line
   "(let [x <Nat> (inc zero)]\n  (add x x))"
   2 2))

;; ============================================================
;; Test: if indentation
;; ============================================================

(ert-deftest prologos-indent-test/if-branches ()
  "If: condition and then are special args, else indented 2."
  (prologos-indent-test--check-line
   "(if true\n    (inc zero)\n  zero)"
   2 4)   ;; then-branch at column 4 (aligned after condition)
  (prologos-indent-test--check-line
   "(if true\n    (inc zero)\n  zero)"
   3 2))  ;; else-branch at column 2

;; ============================================================
;; Test: data indentation
;; ============================================================

(ert-deftest prologos-indent-test/data-constructors ()
  "Data constructors should be indented 2 from data."
  (prologos-indent-test--check
   "(data (MyList A)\n  (mynil)\n  (mycons A (MyList A)))"))

;; ============================================================
;; Test: Pi/Sigma indentation
;; ============================================================

(ert-deftest prologos-indent-test/pi-body ()
  "Pi codomain should be indented 2 from Pi."
  (prologos-indent-test--check
   "(Pi [A <(Type 0)>]\n  (-> A A))"))

(ert-deftest prologos-indent-test/sigma-body ()
  "Sigma body should be indented 2 from Sigma."
  (prologos-indent-test--check
   "(Sigma [A <(Type 0)>]\n  A)"))

;; ============================================================
;; Test: do indentation
;; ============================================================

(ert-deftest prologos-indent-test/do-body ()
  "Do bindings and body indented 2."
  (prologos-indent-test--check-line
   "(do\n  [x <Nat> (inc zero)]\n  (add x x))"
   2 2)
  (prologos-indent-test--check-line
   "(do\n  [x <Nat> (inc zero)]\n  (add x x))"
   3 2))

;; ============================================================
;; Test: the indentation
;; ============================================================

(ert-deftest prologos-indent-test/the-body ()
  "The: type is first arg, body indented 2."
  (prologos-indent-test--check
   "(the Nat\n  (inc zero))"))

;; ============================================================
;; Test: nested forms
;; ============================================================

(ert-deftest prologos-indent-test/nested-defn-match ()
  "Full defn with nested match: proper cascading indentation."
  (prologos-indent-test--check-line
   "(defn double [x <Nat>] <Nat>\n  (match x\n    zero -> zero\n    (inc n) -> (inc (inc (double n)))))"
   1 0)   ;; defn at column 0
  (prologos-indent-test--check-line
   "(defn double [x <Nat>] <Nat>\n  (match x\n    zero -> zero\n    (inc n) -> (inc (inc (double n)))))"
   2 2)   ;; match at column 2
  (prologos-indent-test--check-line
   "(defn double [x <Nat>] <Nat>\n  (match x\n    zero -> zero\n    (inc n) -> (inc (inc (double n)))))"
   3 4)   ;; arm at column 4
  (prologos-indent-test--check-line
   "(defn double [x <Nat>] <Nat>\n  (match x\n    zero -> zero\n    (inc n) -> (inc (inc (double n)))))"
   4 4))  ;; arm at column 4

;; ============================================================
;; Test: reduce indentation (same as match)
;; ============================================================

(ert-deftest prologos-indent-test/reduce-arms ()
  "Reduce arms should be indented 2 from reduce (same as match)."
  (prologos-indent-test--check
   "(reduce n\n  zero -> zero\n  (inc k) -> k)"))

;; ============================================================
;; Test: WS mode — semantic indentation preservation
;; ============================================================

(ert-deftest prologos-indent-test/ws-mode-preserve ()
  "WS mode: non-blank lines preserve their existing indentation."
  (let ((buf (generate-new-buffer "*prologos-ws-indent-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert "#lang prologos\n\ndefn double\n  x <Nat>\n  <Nat>\n  match x\n    zero -> zero\n    inc n -> inc (inc (double n))")
          (goto-char (point-min))
          (prologos-mode)
          ;; Verify ws-mode detected
          (should (eq prologos--ws-mode-p t))
          ;; Indent each line — should preserve semantic indentation
          (prologos-indent-test--indent-buffer)
          ;; Check that lines retained their original indentation
          (goto-char (point-min))
          (forward-line 2) ;; "defn double"
          (should (= (current-indentation) 0))
          (forward-line 1) ;; "  x <Nat>"
          (should (= (current-indentation) 2))
          (forward-line 1) ;; "  <Nat>"
          (should (= (current-indentation) 2))
          (forward-line 1) ;; "  match x"
          (should (= (current-indentation) 2))
          (forward-line 1) ;; "    zero -> zero"
          (should (= (current-indentation) 4))
          (forward-line 1) ;; "    inc n -> ..."
          (should (= (current-indentation) 4)))
      (kill-buffer buf))))

(ert-deftest prologos-indent-test/ws-mode-blank-line ()
  "WS mode: blank lines indent to match previous non-blank line."
  (let ((buf (generate-new-buffer "*prologos-ws-blank-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert "#lang prologos\n\ndefn foo\n  body\n\n  more-body")
          (goto-char (point-min))
          (prologos-mode)
          (should (eq prologos--ws-mode-p t))
          ;; Go to the blank line (line 5)
          (goto-char (point-min))
          (forward-line 4)
          (should (= (line-beginning-position) (line-end-position))) ;; blank
          ;; Indent it
          (prologos-indent-line)
          ;; Should match previous non-blank line's indent (2)
          (should (= (current-indentation) 2)))
      (kill-buffer buf))))

;; ============================================================
;; Test: indent properties are set
;; ============================================================

(ert-deftest prologos-indent-test/properties-defun ()
  "Definition forms should have defun indent property."
  (should (eq (get 'def 'prologos-indent-function) 'defun))
  (should (eq (get 'defn 'prologos-indent-function) 'defun))
  (should (eq (get 'data 'prologos-indent-function) 'defun)))

(ert-deftest prologos-indent-test/properties-specform ()
  "Special forms should have numeric indent properties."
  (should (= (get 'fn 'prologos-indent-function) 1))
  (should (= (get 'match 'prologos-indent-function) 1))
  (should (= (get 'if 'prologos-indent-function) 2))
  (should (= (get 'let 'prologos-indent-function) 1))
  (should (= (get 'Pi 'prologos-indent-function) 1)))

(provide 'prologos-indent-test)

;;; prologos-indent-test.el ends here
