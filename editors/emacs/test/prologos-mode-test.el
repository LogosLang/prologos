;;; prologos-mode-test.el --- ERT tests for prologos-mode -*- lexical-binding: t; -*-

;;; Commentary:

;; Automated tests for Prologos major mode: mode activation, syntax
;; table, font-lock, #lang detection, defun navigation, and imenu.

;;; Code:

(require 'ert)
(require 'imenu)
(require 'prologos-mode)

;; ============================================================
;; Helpers
;; ============================================================

(defun prologos-test--with-buffer (content &optional mode-fn)
  "Create a temp buffer with CONTENT in prologos-mode, return the buffer.
If MODE-FN is given, call it instead of `prologos-mode'."
  (let ((buf (generate-new-buffer "*prologos-test*")))
    (with-current-buffer buf
      (insert content)
      (goto-char (point-min))
      (funcall (or mode-fn #'prologos-mode))
      (syntax-propertize (point-max))
      (font-lock-ensure))
    buf))

(defmacro prologos-test--in-buffer (content &rest body)
  "Execute BODY in a temp buffer with CONTENT in prologos-mode."
  (declare (indent 1))
  `(let ((buf (prologos-test--with-buffer ,content)))
     (unwind-protect
         (with-current-buffer buf ,@body)
       (kill-buffer buf))))

(defun prologos-test--face-at-first (text content)
  "Return the face at the first occurrence of TEXT in a buffer with CONTENT."
  (prologos-test--in-buffer content
    (goto-char (point-min))
    (search-forward text)
    (get-text-property (match-beginning 0) 'face)))

;; ============================================================
;; Test: Mode activation
;; ============================================================

(ert-deftest prologos-test/mode-activation ()
  "Opening a .prologos file should activate prologos-mode."
  (prologos-test--in-buffer "(def x <Nat> zero)"
    (should (eq major-mode 'prologos-mode))))

(ert-deftest prologos-test/mode-name ()
  "Mode name should be Prologos."
  (prologos-test--in-buffer ""
    (should (string= mode-name "Prologos"))))

;; ============================================================
;; Test: Syntax table — comments
;; ============================================================

(ert-deftest prologos-test/syntax-comment ()
  "Semicolon should start a comment."
  (prologos-test--in-buffer ";; this is a comment\n(def x <Nat> zero)"
    (goto-char (point-min))
    (should (nth 4 (syntax-ppss (+ (point-min) 5))))))

(ert-deftest prologos-test/syntax-not-comment ()
  "Code after a comment line should not be in a comment."
  (prologos-test--in-buffer ";; comment\n(def x <Nat> zero)"
    (goto-char (point-min))
    (forward-line 1)
    (should-not (nth 4 (syntax-ppss (point))))))

;; ============================================================
;; Test: Syntax table — strings
;; ============================================================

(ert-deftest prologos-test/syntax-string ()
  "Double-quoted strings should be recognized."
  (prologos-test--in-buffer "(def s \"hello world\")"
    (goto-char (point-min))
    (search-forward "\"hello")
    (should (nth 3 (syntax-ppss (point))))))

;; ============================================================
;; Test: Syntax table — brackets
;; ============================================================

(ert-deftest prologos-test/syntax-parens ()
  "Parentheses should be matched pairs."
  (prologos-test--in-buffer "(inc zero)"
    (goto-char (point-min))
    (should (= (save-excursion (forward-sexp 1) (point))
               (+ (point-min) 10)))))

(ert-deftest prologos-test/syntax-square-brackets ()
  "Square brackets should be matched pairs."
  (prologos-test--in-buffer "[x <Nat>]"
    (goto-char (point-min))
    (should (= (save-excursion (forward-sexp 1) (point))
               (+ (point-min) 9)))))

(ert-deftest prologos-test/syntax-curly-brackets ()
  "Curly brackets should be matched pairs."
  (prologos-test--in-buffer "{A B}"
    (goto-char (point-min))
    (should (= (save-excursion (forward-sexp 1) (point))
               (+ (point-min) 5)))))

(ert-deftest prologos-test/syntax-angle-brackets ()
  "Angle brackets should be matched pairs."
  (prologos-test--in-buffer "<Nat>"
    (goto-char (point-min))
    (should (= (save-excursion (forward-sexp 1) (point))
               (+ (point-min) 5)))))

(ert-deftest prologos-test/syntax-arrow-not-bracket ()
  "The > in -> should NOT be treated as a close bracket."
  (prologos-test--in-buffer "(-> Nat Bool)"
    (goto-char (point-min))
    ;; forward-sexp over the whole form should work without error
    (should (= (save-excursion (forward-sexp 1) (point))
               (+ (point-min) 13)))))

(ert-deftest prologos-test/syntax-angle-with-arrow ()
  "Angle brackets should work alongside -> in the same buffer."
  (prologos-test--in-buffer "(def f <(-> Nat Bool)> true)"
    (goto-char (point-min))
    ;; forward-sexp over the whole def form
    (should (= (save-excursion (forward-sexp 1) (point))
               (+ (point-min) 28)))))

;; ============================================================
;; Test: Font-lock — keywords
;; ============================================================

(ert-deftest prologos-test/font-lock-def ()
  "The `def' keyword should be highlighted."
  (let ((face (prologos-test--face-at-first "def" "(def x <Nat> zero)")))
    (should (eq face 'font-lock-keyword-face))))

(ert-deftest prologos-test/font-lock-defn ()
  "The `defn' keyword should be highlighted."
  (let ((face (prologos-test--face-at-first "defn" "(defn f [x <Nat>] <Nat> x)")))
    (should (eq face 'font-lock-keyword-face))))

(ert-deftest prologos-test/font-lock-fn ()
  "The `fn' keyword should be highlighted."
  (let ((face (prologos-test--face-at-first "fn" "(fn [x <Nat>] x)")))
    (should (eq face 'font-lock-keyword-face))))

(ert-deftest prologos-test/font-lock-match ()
  "The `match' keyword should be highlighted."
  (let ((face (prologos-test--face-at-first "match" "(match x (zero -> true))")))
    (should (eq face 'font-lock-keyword-face))))

(ert-deftest prologos-test/font-lock-ns ()
  "The `ns' keyword should be highlighted."
  (let ((face (prologos-test--face-at-first "ns" "(ns sample)")))
    (should (eq face 'font-lock-keyword-face))))

(ert-deftest prologos-test/font-lock-require ()
  "The `require' keyword should be highlighted."
  (let ((face (prologos-test--face-at-first "require" "(require [prologos.data.nat])")))
    (should (eq face 'font-lock-keyword-face))))

;; ============================================================
;; Test: Font-lock — commands
;; ============================================================

(ert-deftest prologos-test/font-lock-eval ()
  "The `eval' command should be highlighted as preprocessor."
  (let ((face (prologos-test--face-at-first "eval" "(eval (inc zero))")))
    (should (eq face 'font-lock-preprocessor-face))))

(ert-deftest prologos-test/font-lock-check ()
  "The `check' command should be highlighted as preprocessor."
  (let ((face (prologos-test--face-at-first "check" "(check (inc zero) <Nat>)")))
    (should (eq face 'font-lock-preprocessor-face))))

;; ============================================================
;; Test: Font-lock — type constructors
;; ============================================================

(ert-deftest prologos-test/font-lock-type-nat ()
  "The `Nat' type should be highlighted as type face."
  (let ((face (prologos-test--face-at-first "Nat" "(def x <Nat> zero)")))
    (should (eq face 'font-lock-type-face))))

(ert-deftest prologos-test/font-lock-type-bool ()
  "The `Bool' type should be highlighted as type face."
  (let ((face (prologos-test--face-at-first "Bool" "(def x <Bool> true)")))
    (should (eq face 'font-lock-type-face))))

(ert-deftest prologos-test/font-lock-type-type ()
  "The `Type' type should be highlighted as type face."
  (let ((face (prologos-test--face-at-first "Type" "(def x <(Type 0)> Nat)")))
    (should (eq face 'font-lock-type-face))))

(ert-deftest prologos-test/font-lock-type-vec ()
  "The `Vec' type should be highlighted as type face."
  (let ((face (prologos-test--face-at-first "Vec" "(Vec Nat 3)")))
    (should (eq face 'font-lock-type-face))))

;; ============================================================
;; Test: Font-lock — value constructors
;; ============================================================

(ert-deftest prologos-test/font-lock-zero ()
  "The `zero' constructor should be highlighted as constant."
  (let ((face (prologos-test--face-at-first "zero" "(eval zero)")))
    (should (eq face 'font-lock-constant-face))))

(ert-deftest prologos-test/font-lock-true ()
  "The `true' constructor should be highlighted as constant."
  (let ((face (prologos-test--face-at-first "true" "(eval true)")))
    (should (eq face 'font-lock-constant-face))))

(ert-deftest prologos-test/font-lock-inc ()
  "The `inc' constructor should be highlighted as constant."
  (let ((face (prologos-test--face-at-first "inc" "(inc zero)")))
    (should (eq face 'font-lock-constant-face))))

;; ============================================================
;; Test: Font-lock — eliminators
;; ============================================================

(ert-deftest prologos-test/font-lock-natrec ()
  "The `natrec' eliminator should be highlighted as builtin."
  (let ((face (prologos-test--face-at-first "natrec" "(natrec Nat zero f n)")))
    (should (eq face 'font-lock-builtin-face))))

(ert-deftest prologos-test/font-lock-boolrec ()
  "The `boolrec' eliminator should be highlighted as builtin."
  (let ((face (prologos-test--face-at-first "boolrec" "(boolrec Nat a b c)")))
    (should (eq face 'font-lock-builtin-face))))

;; ============================================================
;; Test: Font-lock — definition names
;; ============================================================

(ert-deftest prologos-test/font-lock-def-name ()
  "The name after `def' should be highlighted as function name."
  (prologos-test--in-buffer "(def my-value <Nat> zero)"
    (goto-char (point-min))
    (search-forward "my-value")
    (should (eq (get-text-property (match-beginning 0) 'face)
                'font-lock-function-name-face))))

(ert-deftest prologos-test/font-lock-defn-name ()
  "The name after `defn' should be highlighted as function name."
  (prologos-test--in-buffer "(defn double [x <Nat>] <Nat> x)"
    (goto-char (point-min))
    (search-forward "double")
    (should (eq (get-text-property (match-beginning 0) 'face)
                'font-lock-function-name-face))))

;; ============================================================
;; Test: Font-lock — data type names
;; ============================================================

(ert-deftest prologos-test/font-lock-data-name ()
  "The name after `data' should be highlighted as type face."
  (prologos-test--in-buffer "(data MyList (mynil) (mycons))"
    (goto-char (point-min))
    (search-forward "MyList")
    (should (eq (get-text-property (match-beginning 0) 'face)
                'font-lock-type-face))))

;; ============================================================
;; Test: Font-lock — Posit8 operations
;; ============================================================

(ert-deftest prologos-test/font-lock-posit8 ()
  "Posit8 operations should be highlighted as builtin."
  (let ((face (prologos-test--face-at-first "p8+" "(p8+ x y)")))
    (should (eq face 'font-lock-builtin-face))))

;; ============================================================
;; Test: #lang detection
;; ============================================================

(ert-deftest prologos-test/ws-mode-detection ()
  "#lang prologos should set ws-mode to t."
  (prologos-test--in-buffer "#lang prologos\n\ndef double\n  x <Nat>\n  <Nat>"
    (should (eq prologos--ws-mode-p t))))

(ert-deftest prologos-test/sexp-mode-detection ()
  "#lang prologos/sexp should still use WS mode (sexp not supported in editor)."
  (prologos-test--in-buffer "#lang prologos/sexp\n\n(def x <Nat> zero)"
    (should (eq prologos--ws-mode-p t))))

(ert-deftest prologos-test/no-lang-detection ()
  "No #lang directive should default to WS mode (t)."
  (prologos-test--in-buffer "(def x <Nat> zero)"
    (should (eq prologos--ws-mode-p t))))

(ert-deftest prologos-test/ns-detection ()
  "Files starting with `ns' should be WS mode (the common case)."
  (prologos-test--in-buffer "ns prologos.data.nat\n\nprovide add mult\n\ndefn add [x : Nat, y : Nat] : Nat\n  match y\n    | zero  -> x\n    | inc k -> inc (add x k)"
    (should (eq prologos--ws-mode-p t))))

;; ============================================================
;; Test: Defun navigation
;; ============================================================

(ert-deftest prologos-test/beginning-of-defun ()
  "beginning-of-defun should navigate to the start of a definition."
  (prologos-test--in-buffer "(def x <Nat> zero)\n\n(defn double [n <Nat>] <Nat>\n  (add n n))"
    (goto-char (point-max))
    (beginning-of-defun)
    (should (looking-at "(defn double"))))

(ert-deftest prologos-test/beginning-of-defun-skips-to-first ()
  "beginning-of-defun twice should navigate to the first definition."
  (prologos-test--in-buffer "(def x <Nat> zero)\n\n(defn double [n <Nat>] <Nat>\n  (add n n))"
    (goto-char (point-max))
    (beginning-of-defun)
    (beginning-of-defun)
    (should (looking-at "(def x"))))

;; ============================================================
;; Test: Imenu
;; ============================================================

(ert-deftest prologos-test/imenu-definitions ()
  "Imenu should find def definitions."
  (prologos-test--in-buffer "(def one (inc zero))\n(def two (inc one))"
    (let ((index (imenu--make-index-alist t)))
      (should (assoc "Definitions" index))
      (let ((defs (cdr (assoc "Definitions" index))))
        (should (>= (length defs) 2))))))

(ert-deftest prologos-test/imenu-functions ()
  "Imenu should find defn definitions."
  (prologos-test--in-buffer "(defn double [x <Nat>] <Nat> (add x x))\n(defn pred [n <Nat>] <Nat> n)"
    (let ((index (imenu--make-index-alist t)))
      (should (assoc "Functions" index))
      (let ((fns (cdr (assoc "Functions" index))))
        (should (>= (length fns) 2))))))

;; ============================================================
;; Test: Comment settings
;; ============================================================

(ert-deftest prologos-test/comment-start ()
  "comment-start should be ;; with a trailing space."
  (prologos-test--in-buffer ""
    (should (string= comment-start ";; "))))

(ert-deftest prologos-test/comment-end ()
  "comment-end should be empty."
  (prologos-test--in-buffer ""
    (should (string= comment-end ""))))

(provide 'prologos-mode-test)

;;; prologos-mode-test.el ends here
