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
Creates a buffer in sexp mode, inserts the content with all leading
whitespace removed, activates prologos-mode, indents every line, and compares."
  (let ((buf (generate-new-buffer "*prologos-indent-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert (prologos-indent-test--strip-indent expected))
          (goto-char (point-min))
          (prologos-mode)
          ;; Force sexp mode for sexp indentation tests
          (setq prologos--ws-mode-p nil)
          (syntax-propertize (point-max))
          (prologos-indent-test--indent-buffer)
          (let ((result (buffer-string)))
            (should (string= result expected))))
      (kill-buffer buf))))

(defun prologos-indent-test--check-line (content line-num expected-col)
  "Check that line LINE-NUM in CONTENT gets indented to EXPECTED-COL.
LINE-NUM is 1-based.  Uses sexp mode for indentation."
  (let ((buf (generate-new-buffer "*prologos-indent-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert content)
          (goto-char (point-min))
          (prologos-mode)
          ;; Force sexp mode for sexp indentation tests
          (setq prologos--ws-mode-p nil)
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
;; Test: WS mode TAB cycling
;; ============================================================

(ert-deftest prologos-indent-test/ws-mode-indent-levels ()
  "WS mode: calculate-indent-levels returns correct candidates."
  (let ((buf (generate-new-buffer "*prologos-ws-levels-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert "#lang prologos\n\ndefn double\n  match n\n    zero -> zero")
          (goto-char (point-min))
          (prologos-mode)
          (should (eq prologos--ws-mode-p t))
          ;; Go to "    zero -> zero" (line 5, indent 4)
          ;; Previous non-blank is "  match n" (indent 2)
          (goto-char (point-min))
          (forward-line 4)
          (let ((levels (prologos--ws-calculate-indent-levels)))
            ;; prev=2, so candidates: 0, max(0,2-2)=0, 2, 2+2=4
            ;; dedup+sort: (0 2 4)
            (should (equal levels '(0 2 4)))))
      (kill-buffer buf))))

(ert-deftest prologos-indent-test/ws-mode-indent-levels-top ()
  "WS mode: indent levels at top-level (prev=0) should be (0 2)."
  (let ((buf (generate-new-buffer "*prologos-ws-levels-top-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert "#lang prologos\n\ndefn double\n  match n")
          (goto-char (point-min))
          (prologos-mode)
          ;; Go to "  match n" (line 4), prev is "defn double" (indent 0)
          (goto-char (point-min))
          (forward-line 3)
          (let ((levels (prologos--ws-calculate-indent-levels)))
            ;; prev=0, candidates: 0, max(0,0-2)=0, 0, 0+2=2
            ;; dedup+sort: (0 2)
            (should (equal levels '(0 2)))))
      (kill-buffer buf))))

(ert-deftest prologos-indent-test/ws-mode-cycle-indent ()
  "WS mode: cycle-indent returns next lower level, wrapping at min."
  ;; levels = (0 2 4)
  (should (= (prologos--ws-cycle-indent '(0 2 4) 4) 2))
  (should (= (prologos--ws-cycle-indent '(0 2 4) 2) 0))
  ;; At minimum (0), wrap to max (4)
  (should (= (prologos--ws-cycle-indent '(0 2 4) 0) 4))
  ;; Current indent not in levels (e.g. 3) — picks next lower (2)
  (should (= (prologos--ws-cycle-indent '(0 2 4) 3) 2))
  ;; levels = (0 2), cycle from 2 to 0 to 2
  (should (= (prologos--ws-cycle-indent '(0 2) 2) 0))
  (should (= (prologos--ws-cycle-indent '(0 2) 0) 2)))

(ert-deftest prologos-indent-test/ws-mode-tab-cycling ()
  "WS mode: repeated TAB cycles indentation on non-blank lines."
  (let ((buf (generate-new-buffer "*prologos-ws-tab-cycle-test*")))
    (unwind-protect
        (with-current-buffer buf
          ;; Line at col 4, prev non-blank at col 2 → levels (0 2 4)
          (insert "#lang prologos\n\ndefn foo\n  match n\n    | zero -> zero")
          (goto-char (point-min))
          (prologos-mode)
          (should (eq prologos--ws-mode-p t))
          ;; Go to last line (col 4)
          (goto-char (point-min))
          (forward-line 4)
          (should (= (current-indentation) 4))
          ;; First TAB (not cycling): should preserve indentation
          (let ((this-command 'indent-for-tab-command)
                (last-command 'self-insert-command))
            (prologos-indent-line)
            (should (= (current-indentation) 4)))
          ;; Second TAB (cycling): 4 → 2
          (let ((this-command 'indent-for-tab-command)
                (last-command 'indent-for-tab-command))
            (prologos-indent-line)
            (should (= (current-indentation) 2)))
          ;; Third TAB: 2 → 0
          (let ((this-command 'indent-for-tab-command)
                (last-command 'indent-for-tab-command))
            (prologos-indent-line)
            (should (= (current-indentation) 0)))
          ;; Fourth TAB: 0 → 4 (wrap to max)
          (let ((this-command 'indent-for-tab-command)
                (last-command 'indent-for-tab-command))
            (prologos-indent-line)
            (should (= (current-indentation) 4))))
      (kill-buffer buf))))

(ert-deftest prologos-indent-test/ws-mode-ns-tab-cycling ()
  "WS mode: TAB cycling works in files starting with `ns' (no #lang)."
  (let ((buf (generate-new-buffer "*prologos-ws-ns-cycle-test*")))
    (unwind-protect
        (with-current-buffer buf
          ;; Real-world content: no #lang, starts with ns
          (insert "ns prologos.data.nat\n\ndefn add [x : Nat, y : Nat] : Nat\n  match y\n    | zero  -> x\n    | inc k -> inc (add x k)")
          (goto-char (point-min))
          (prologos-mode)
          ;; Must detect WS mode from ns-prefixed file
          (should (eq prologos--ws-mode-p t))
          ;; Go to "    | zero  -> x" (line 5, col 4)
          (goto-char (point-min))
          (forward-line 4)
          (should (= (current-indentation) 4))
          ;; First TAB: preserve
          (let ((this-command 'indent-for-tab-command)
                (last-command 'self-insert-command))
            (prologos-indent-line)
            (should (= (current-indentation) 4)))
          ;; Second TAB: 4 → 2
          (let ((this-command 'indent-for-tab-command)
                (last-command 'indent-for-tab-command))
            (prologos-indent-line)
            (should (= (current-indentation) 2)))
          ;; Third TAB: 2 → 0
          (let ((this-command 'indent-for-tab-command)
                (last-command 'indent-for-tab-command))
            (prologos-indent-line)
            (should (= (current-indentation) 0)))
          ;; Fourth TAB: 0 → 4 (wrap)
          (let ((this-command 'indent-for-tab-command)
                (last-command 'indent-for-tab-command))
            (prologos-indent-line)
            (should (= (current-indentation) 4))))
      (kill-buffer buf))))

;; ============================================================
;; Test: indent properties are set
;; ============================================================

(ert-deftest prologos-indent-test/properties-defun ()
  "Definition forms should have defun indent property."
  (should (eq (get 'def 'lisp-indent-function) 'defun))
  (should (eq (get 'defn 'lisp-indent-function) 'defun))
  (should (eq (get 'data 'lisp-indent-function) 'defun)))

(ert-deftest prologos-indent-test/properties-specform ()
  "Special forms should have numeric indent properties."
  (should (= (get 'fn 'lisp-indent-function) 1))
  (should (= (get 'match 'lisp-indent-function) 1))
  (should (= (get 'if 'lisp-indent-function) 2))
  (should (= (get 'let 'lisp-indent-function) 1))
  (should (= (get 'Pi 'lisp-indent-function) 1)))

(provide 'prologos-indent-test)

;;; prologos-indent-test.el ends here
