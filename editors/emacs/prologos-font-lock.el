;;; prologos-font-lock.el --- Font-lock support for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors

;;; Commentary:

;; Multi-level font-lock keywords, custom faces, and prettify-symbols
;; for the Prologos dependently-typed functional-logic language.

;;; Code:

;; ============================================================
;; Custom faces
;; ============================================================

(defgroup prologos-faces nil
  "Faces for Prologos mode."
  :group 'prologos
  :group 'faces)

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

;; ============================================================
;; Font-lock keyword levels
;; ============================================================

(defconst prologos-font-lock-keywords-1
  `(;; Top-level definition forms
    (,(regexp-opt '("def" "defn" "defmacro" "deftype" "data"
                    "ns" "require" "provide")
                  'symbols)
     . font-lock-keyword-face)
    ;; Top-level commands
    (,(regexp-opt '("check" "eval" "infer") 'symbols)
     . font-lock-preprocessor-face))
  "Level 1: keywords and commands.")

(defconst prologos-font-lock-keywords-2
  (append prologos-font-lock-keywords-1
   `(;; Expression forms
     (,(regexp-opt '("fn" "the" "the-fn" "let" "do" "if"
                     "match" "forall" "exists")
                   'symbols)
      . font-lock-keyword-face)
     ;; Type constructors
     (,(regexp-opt '("Pi" "Sigma" "Type" "Nat" "Bool" "Posit8"
                     "Vec" "Fin" "Eq" "Chan" "Session")
                   'symbols)
      . font-lock-type-face)))
  "Level 2: add expression forms and type constructors.")

(defconst prologos-font-lock-keywords-3
  (append prologos-font-lock-keywords-2
   `(;; Value constructors and constants
     (,(regexp-opt '("zero" "true" "false" "refl" "pair" "inc"
                     "vnil" "vcons" "fzero" "fsuc" "posit8"
                     "nothing" "just" "nil" "cons")
                   'symbols)
      . font-lock-constant-face)
     ;; Eliminators (internal, but may appear in prototype code)
     (,(regexp-opt '("natrec" "boolrec" "first" "second"
                     "vhead" "vtail" "vindex" "J")
                   'symbols)
      . font-lock-builtin-face)))
  "Level 3: add constructors and eliminators.")

(defconst prologos-font-lock-keywords-4
  (append prologos-font-lock-keywords-3
   `(;; Posit8 operations
     (,(regexp-opt '("p8+" "p8-" "p8*" "p8/" "p8-neg" "p8-abs"
                     "p8-sqrt" "p8-lt" "p8-le" "p8-from-nat"
                     "p8-if-nar")
                   'symbols)
      . font-lock-builtin-face)
     ;; Future: actor/session/logic keywords
     (,(regexp-opt '("relation" "clause" "query" "actor" "spawn"
                     "send" "recv" "chan" "propagator" "cell")
                   'symbols)
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
     ;; Definition name after def/defn/deftype/defmacro
     ("(def\\(?:n\\|type\\|macro\\)?\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)"
      (1 font-lock-function-name-face))
     ;; Data type name
     ("(data\\s-+(?\\([A-Z][a-zA-Z0-9_]*\\)"
      (1 font-lock-type-face))))
  "Level 5: add multiplicities, holes, definition names.")

;; Default: use the most complete level
(defconst prologos-font-lock-keywords prologos-font-lock-keywords-5
  "Default font-lock keywords for Prologos mode (all levels).")

;; ============================================================
;; Prettify symbols
;; ============================================================

(defcustom prologos-pretty-symbols nil
  "When non-nil, display Unicode symbols for Prologos operators.
For example, `Pi' displays as `Π', `fn' as `λ', `->` as `→'."
  :type 'boolean
  :group 'prologos)

(defun prologos--setup-prettify-symbols ()
  "Set up Unicode display for Prologos operators."
  (setq-local prettify-symbols-alist
              '(("Pi"     . ?Π)
                ("Sigma"  . ?Σ)
                ("fn"     . ?λ)
                ("->"     . ?→)
                (":w"     . ?ω)
                ("forall" . ?∀)
                ("exists" . ?∃)
                ("Nat"    . ?ℕ)
                ("Bool"   . ?𝔹)))
  (prettify-symbols-mode 1))

(provide 'prologos-font-lock)

;;; prologos-font-lock.el ends here
