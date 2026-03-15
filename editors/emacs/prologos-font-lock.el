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
    (,(regexp-opt '("def" "defn" "defmacro" "deftype" "data" "spec"
                    "ns" "imports" "exports" "require" "provide" "foreign" "trait" "impl"
                    "schema" "defr" "solver")
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
                     "match" "forall" "exists"
                     "solve-one" "solve-with" "explain" "explain-with" "rel")
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
     ;; Module system keyword tokens
     (":as\\>" . font-lock-keyword-face)
     (":refer\\>" . font-lock-keyword-face)
     ;; Arrow operator
     ("->" . font-lock-constant-face)))
  "Level 4: add Posit8 ops, future keywords, module tokens, operators.")

(defconst prologos-font-lock-keywords-5
  (append prologos-font-lock-keywords-4
   `(;; QTT multiplicity annotations
     ("\\(:0\\|:1\\|:w\\)" . 'prologos-multiplicity-face)
     ;; Holes (metavariables)
     ("\\?[a-zA-Z_][a-zA-Z0-9_]*" . font-lock-warning-face)
     ;; Macro pattern variables
     ("\\$[a-zA-Z_][a-zA-Z0-9_]*" . font-lock-variable-name-face)
     ;; Definition name after def/defn/deftype/defmacro
     ;; Matches both sexp mode (paren-delimited) and WS mode (bare at BOL)
     ("\\(?:^\\|[(\\[]\\)def\\(?:n\\|type\\|macro\\)?\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)"
      (1 font-lock-function-name-face))
     ;; Spec name (sexp or WS mode)
     ("\\bspec\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)"
      (1 font-lock-function-name-face))
     ;; Relation name after defr (sexp or WS mode)
     ("\\bdefr\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)"
      (1 font-lock-function-name-face))
     ;; Schema name after schema (sexp or WS mode)
     ("\\bschema\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)"
      (1 font-lock-type-face))
     ;; Solver name after solver (sexp or WS mode)
     ("\\bsolver\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)"
      (1 font-lock-function-name-face))
     ;; Data type name (sexp or WS mode)
     ("\\(?:^\\|[(\\[]\\)data\\s-+(?\\([A-Z][a-zA-Z0-9_]*\\)"
      (1 font-lock-type-face))
     ;; Foreign language identifier: `racket' after `foreign'
     ("\\bforeign\\s-+\\(racket\\)" (1 font-lock-constant-face))
     ;; Alias name after :as (acts as a local definition)
     (":as\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*/-]*\\)"
      (1 font-lock-function-name-face))
     ;; Imported names inside :refer [...] — anchored matcher
     (":refer\\s-*\\["
      ("[a-zA-Z_][a-zA-Z0-9_!?*-]*"
       (save-excursion (search-forward "]" nil t) (point))
       nil
       (0 font-lock-variable-name-face)))
     ;; Native fontification for racket{...} blocks (must be last —
     ;; it stamps fontified/font-lock-fontified to prevent re-fontification)
     (prologos--fontify-racket-blocks)))
  "Level 5: add multiplicities, holes, definition names, foreign interop,
and native racket{...} block fontification.")

;; Default: use the most complete level
(defconst prologos-font-lock-keywords prologos-font-lock-keywords-5
  "Default font-lock keywords for Prologos mode (all levels).")

;; ============================================================
;; Native fontification for racket{...} escape blocks
;; ============================================================
;;
;; Uses the same temp-buffer technique as org-src-font-lock-fontify-block
;; and markdown-fontify-code-block-natively: extract block content into a
;; hidden buffer, activate scheme-mode (or racket-mode), run font-lock,
;; and copy the face properties back to the Prologos buffer.

(defcustom prologos-fontify-racket-blocks-natively t
  "When non-nil, fontify racket{...} blocks using scheme-mode font-lock.
If `racket-mode' is available it is preferred; otherwise `scheme-mode'
is used as the fallback."
  :type 'boolean
  :group 'prologos)

(defface prologos-racket-delimiter-face
  '((t :inherit font-lock-preprocessor-face))
  "Face for the `racket{' and `}' delimiters of escape blocks."
  :group 'prologos-faces)

(defun prologos--racket-lang-mode ()
  "Return the best available major mode for Racket code fontification."
  (cond
   ((fboundp 'racket-mode) 'racket-mode)
   (t 'scheme-mode)))

(defun prologos--fontify-racket-block-natively (content-start content-end)
  "Fontify the racket{...} block interior from CONTENT-START to CONTENT-END.
Uses scheme-mode or racket-mode font-lock in a temp buffer and copies
the resulting face properties back."
  (let ((lang-mode (prologos--racket-lang-mode)))
    (when (and lang-mode prologos-fontify-racket-blocks-natively)
      (let ((string (buffer-substring-no-properties content-start content-end))
            (modified (buffer-modified-p))
            (orig-buffer (current-buffer)))
        ;; Clear existing faces in the region
        (remove-text-properties content-start content-end '(face nil))
        ;; Fontify in a hidden temp buffer
        (with-current-buffer
            (get-buffer-create " *prologos-racket-fontification*")
          (let ((inhibit-modification-hooks t))
            (erase-buffer)
            (insert string " ")) ; trailing space ensures final property change
          (unless (eq major-mode lang-mode)
            (delay-mode-hooks (funcall lang-mode)))
          (font-lock-ensure)
          ;; Copy face properties back to the original buffer
          (let ((pos (point-min))
                next)
            (while (setq next (next-single-property-change pos 'face))
              (let ((val (get-text-property pos 'face)))
                (when val
                  (put-text-property
                   (+ content-start (1- pos))
                   (min (+ content-start (1- next)) content-end)
                   'face val orig-buffer)))
              (setq pos next))))
        ;; Stamp the region as fontified so jit-lock doesn't re-fontify
        (add-text-properties
         content-start content-end
         '(font-lock-fontified t fontified t font-lock-multiline t))
        (set-buffer-modified-p modified)))))

(defun prologos--fontify-racket-blocks (last)
  "Font-lock keyword function: fontify racket{...} blocks up to LAST.
Finds each racket{...} block, applies `prologos-racket-delimiter-face' to
the delimiters, and calls `prologos--fontify-racket-block-natively' on
the content interior.  Returns non-nil to continue searching."
  (let (found kw-start close-end)
    (while (and (not found) (re-search-forward "racket{" last t))
      (let ((this-kw-start (match-beginning 0))  ; start of `racket'
            (brace-start (1- (point)))            ; position of {
            (content-start (point)))              ; just after {
        ;; Skip if inside a comment or string
        (unless (let ((ppss (save-excursion (syntax-ppss brace-start))))
                  (or (nth 3 ppss) (nth 4 ppss)))
          ;; Find matching } by brace counting
          (let ((depth 1)
                close)
            (save-excursion
              (goto-char content-start)
              (while (and (> depth 0) (re-search-forward "[{}]" last t))
                (cond
                 ((eq (char-before) ?\{) (setq depth (1+ depth)))
                 ((eq (char-before) ?\})
                  (setq depth (1- depth))
                  (when (= depth 0)
                    (setq close (1- (point))))))))
            (when close
              ;; Highlight delimiters
              (put-text-property this-kw-start (1+ brace-start)
                                 'face 'prologos-racket-delimiter-face)
              (put-text-property close (1+ close)
                                 'face 'prologos-racket-delimiter-face)
              ;; Natively fontify the content (save-match-data because
              ;; the temp buffer operations corrupt match data)
              (when (< content-start close)
                (save-match-data
                  (prologos--fontify-racket-block-natively content-start close)))
              (setq kw-start this-kw-start
                    close-end (1+ close))
              (goto-char close-end)
              (setq found t))))))
    ;; Set match data so font-lock has valid data after we return
    (when found
      (set-match-data (list kw-start close-end)))
    found))

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
