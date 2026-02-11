;;; prologos-ts-mode-test.el --- ERT tests for prologos-ts-mode -*- lexical-binding: t; -*-

;;; Commentary:

;; Automated tests for Prologos tree-sitter major mode: mode activation,
;; font-lock, imenu, defun navigation, and fallback to regex mode.

;;; Code:

(require 'ert)
(require 'imenu)
(require 'prologos-mode)

;; Only run these tests if treesit is available
(defvar prologos-ts-test--treesit-available
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)
       (condition-case nil
           (progn (require 'prologos-ts-mode) t)
         (error nil)))
  "Non-nil when treesit and prologos grammar are available for testing.")

;; ============================================================
;; Helpers
;; ============================================================

(defun prologos-ts-test--with-buffer (content)
  "Create a temp buffer with CONTENT in `prologos-ts-mode', return the buffer."
  (let ((buf (generate-new-buffer "*prologos-ts-test*")))
    (with-current-buffer buf
      (insert content)
      (goto-char (point-min))
      (prologos-ts-mode)
      (font-lock-ensure))
    buf))

(defmacro prologos-ts-test--in-buffer (content &rest body)
  "Execute BODY in a temp buffer with CONTENT in `prologos-ts-mode'."
  (declare (indent 1))
  `(let ((buf (prologos-ts-test--with-buffer ,content)))
     (unwind-protect
         (with-current-buffer buf ,@body)
       (kill-buffer buf))))

(defun prologos-ts-test--face-at-first (text content)
  "Return the face at the first occurrence of TEXT in a ts-mode buffer with CONTENT."
  (prologos-ts-test--in-buffer content
    (goto-char (point-min))
    (search-forward text)
    (get-text-property (match-beginning 0) 'face)))

;; ============================================================
;; Test: Mode activation
;; ============================================================

(ert-deftest prologos-ts-test/mode-activation ()
  "prologos-ts-mode should activate when treesit is available."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "ns test\n"
    (should (eq major-mode 'prologos-ts-mode))))

(ert-deftest prologos-ts-test/parser-created ()
  "A treesit parser should be created for prologos."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "ns test\n"
    (should (treesit-parser-list))
    (should (eq (treesit-parser-language (car (treesit-parser-list))) 'prologos))))

;; ============================================================
;; Test: Font-lock keywords
;; ============================================================

(ert-deftest prologos-ts-test/font-lock-defn-keyword ()
  "The `defn' keyword should get keyword face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               "defn"
               "defn pred [n : Nat] : Nat\n  zero\n")))
    (should (eq face 'font-lock-keyword-face))))

(ert-deftest prologos-ts-test/font-lock-data-keyword ()
  "The `data' keyword should get keyword face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               "data"
               "data Ordering\n  lt-ord\n")))
    (should (eq face 'font-lock-keyword-face))))

(ert-deftest prologos-ts-test/font-lock-match-keyword ()
  "The `match' keyword should get keyword face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               "match"
               "defn pred [n : Nat] : Nat\n  match n\n    | zero -> zero\n    | inc k -> k\n")))
    (should (eq face 'font-lock-keyword-face))))

(ert-deftest prologos-ts-test/font-lock-ns-keyword ()
  "The `ns' keyword should get keyword face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               "ns"
               "ns prologos.data.nat\n")))
    (should (eq face 'font-lock-keyword-face))))

(ert-deftest prologos-ts-test/font-lock-require-keyword ()
  "The `require' keyword should get keyword face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               "require"
               "require [prologos.core.eq-trait :refer [nat-eq]]\n")))
    (should (eq face 'font-lock-keyword-face))))

;; ============================================================
;; Test: Font-lock definition names
;; ============================================================

(ert-deftest prologos-ts-test/font-lock-defn-name ()
  "Function name after `defn' should get function-name face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               "pred"
               "defn pred [n : Nat] : Nat\n  zero\n")))
    (should (eq face 'font-lock-function-name-face))))

(ert-deftest prologos-ts-test/font-lock-data-type-name ()
  "Type name after `data' should get type face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               "Ordering"
               "data Ordering\n  lt-ord\n")))
    (should (eq face 'font-lock-type-face))))

(ert-deftest prologos-ts-test/font-lock-data-constructor ()
  "Data constructor names should get constant face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               "lt-ord"
               "data Ordering\n  lt-ord\n  eq-ord\n")))
    (should (eq face 'font-lock-constant-face))))

;; ============================================================
;; Test: Font-lock types
;; ============================================================

(ert-deftest prologos-ts-test/font-lock-type-annotation ()
  "Type identifiers in type position should get type face."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "defn pred [n : Nat] : Nat\n  zero\n"
    ;; Find "Nat" in the return type position (after last :)
    (goto-char (point-min))
    (search-forward "] : ")
    (let ((face (get-text-property (point) 'face)))
      (should (eq face 'font-lock-type-face)))))

;; ============================================================
;; Test: Font-lock multiplicity
;; ============================================================

(ert-deftest prologos-ts-test/font-lock-multiplicity ()
  "Multiplicity annotations should get multiplicity face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               ":0"
               "defn sym {A} [a :0 : A, b :0 : A] : A\n  a\n")))
    (should (eq face 'prologos-multiplicity-face))))

;; ============================================================
;; Test: Font-lock comments
;; ============================================================

(ert-deftest prologos-ts-test/font-lock-comment ()
  "Comments should get comment face."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((face (prologos-ts-test--face-at-first
               ";; test"
               ";; test comment\nns test\n")))
    (should (eq face 'font-lock-comment-face))))

;; ============================================================
;; Test: Imenu
;; ============================================================

(ert-deftest prologos-ts-test/imenu-finds-defn ()
  "Imenu should find defn_form entries."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "ns test\n\ndefn add [x : Nat, y : Nat] : Nat\n  zero\n\ndefn pred [n : Nat] : Nat\n  zero\n"
    (let ((items (treesit-simple-imenu)))
      (should items)
      (let ((fns (cdr (assoc "Function" items))))
        (should fns)
        (should (= (length fns) 2))
        (should (string= (car (nth 0 fns)) "add"))
        (should (string= (car (nth 1 fns)) "pred"))))))

(ert-deftest prologos-ts-test/imenu-finds-data ()
  "Imenu should find data_form entries."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "data Ordering\n  lt-ord\n  eq-ord\n"
    (let ((items (treesit-simple-imenu)))
      (should items)
      (let ((types (cdr (assoc "Type" items))))
        (should types)
        (should (= (length types) 1))
        (should (string= (car (car types)) "Ordering"))))))

(ert-deftest prologos-ts-test/imenu-finds-ns ()
  "Imenu should find ns_declaration entries."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "ns prologos.data.nat\n"
    (let ((items (treesit-simple-imenu)))
      (should items)
      (let ((nss (cdr (assoc "Namespace" items))))
        (should nss)
        (should (= (length nss) 1))))))

;; ============================================================
;; Test: Defun navigation
;; ============================================================

(ert-deftest prologos-ts-test/beginning-of-defun ()
  "beginning-of-defun should navigate to defn_form nodes."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "ns test\n\ndefn add [x : Nat] : Nat\n  zero\n\ndefn pred [n : Nat] : Nat\n  zero\n"
    (goto-char (point-max))
    (beginning-of-defun)
    (should (looking-at "defn pred"))))

(ert-deftest prologos-ts-test/beginning-of-defun-twice ()
  "beginning-of-defun called twice should navigate to previous defn."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "ns test\n\ndefn add [x : Nat] : Nat\n  zero\n\ndefn pred [n : Nat] : Nat\n  zero\n"
    (goto-char (point-max))
    (beginning-of-defun)
    (beginning-of-defun)
    (should (looking-at "defn add"))))

;; ============================================================
;; Test: Fallback
;; ============================================================

(ert-deftest prologos-ts-test/fallback-function ()
  "prologos-ts-mode-or-fallback should use ts-mode when grammar available."
  (skip-unless prologos-ts-test--treesit-available)
  (let ((buf (generate-new-buffer "*prologos-fallback-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert "ns test\n")
          (prologos-ts-mode-or-fallback)
          (should (eq major-mode 'prologos-ts-mode)))
      (kill-buffer buf))))

;; ============================================================
;; Test: WS mode indentation is set
;; ============================================================

(ert-deftest prologos-ts-test/ws-indent-function ()
  "prologos-ts-mode should use WS indent function."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "ns test\n"
    (should (eq indent-line-function #'prologos--ws-indent-line))))

(ert-deftest prologos-ts-test/ws-mode-flag ()
  "prologos-ts-mode should set prologos--ws-mode-p to t."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "ns test\n"
    (should prologos--ws-mode-p)))

;; ============================================================
;; Test: Comment settings
;; ============================================================

(ert-deftest prologos-ts-test/comment-settings ()
  "prologos-ts-mode should configure comment vars."
  (skip-unless prologos-ts-test--treesit-available)
  (prologos-ts-test--in-buffer "ns test\n"
    (should (string= comment-start ";; "))
    (should (string= comment-end ""))))

(provide 'prologos-ts-mode-test)

;;; prologos-ts-mode-test.el ends here
