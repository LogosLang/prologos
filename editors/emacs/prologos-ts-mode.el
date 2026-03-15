;;; prologos-ts-mode.el --- Tree-sitter major mode for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors
;; Version: 0.2.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages tree-sitter
;; URL: https://github.com/prologos-lang/prologos

;;; Commentary:

;; Tree-sitter based major mode for editing Prologos source files (.prologos).
;; Uses the tree-sitter grammar for accurate font-lock, navigation, and imenu.
;;
;; Requirements:
;; - Emacs 29.1+ with treesit support
;; - libtree-sitter-prologos.dylib installed in ~/.emacs.d/tree-sitter/
;;
;; Features:
;; - Tree-sitter based font-lock (4 levels)
;; - Imenu support for defn, def, data, and deftype declarations
;; - Defun navigation (C-M-a / C-M-e) via treesit
;; - #lang detection for WS vs sexp mode
;; - WS mode indentation (TAB cycling, reused from prologos-indent.el)
;; - Automatic fallback to prologos-mode when grammar unavailable

;;; Code:

(require 'treesit)
(require 'prologos-mode)
(require 'prologos-font-lock)
(require 'prologos-indent)

;; REPL integration (autoloaded — only loaded when first invoked)
(autoload 'prologos-repl "prologos-repl" "Start or switch to the Prologos REPL." t)
(autoload 'prologos-eval-last-sexp "prologos-repl" "Evaluate the sexp before point." t)
(autoload 'prologos-eval-region "prologos-repl" "Evaluate the region." t)
(autoload 'prologos-eval-buffer "prologos-repl" "Evaluate the entire buffer." t)
(autoload 'prologos-load-file "prologos-repl" "Load current file into REPL." t)
(autoload 'prologos-eval-defun-at-point "prologos-repl" "Evaluate defun at point." t)

;; ============================================================
;; Font-lock rules
;; ============================================================

(defconst prologos-ts-font-lock-rules
  (treesit-font-lock-rules
   ;; Level 1: comments and strings
   :language 'prologos
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'prologos
   :feature 'string
   '((string) @font-lock-string-face)

   ;; Level 2: keywords (grammar keywords + identifier-matched keywords)
   :language 'prologos
   :feature 'keyword
   '(["defn" "def" "data" "deftype" "match" "fn"
      "ns" "imports" "exports" "provide" "require" ":refer"] @font-lock-keyword-face)

   :language 'prologos
   :feature 'keyword
   :override t
   '(((identifier) @font-lock-keyword-face
      (:match "\\`\\(?:def\\|defn\\|data\\|deftype\\|match\\|fn\\|ns\\|provide\\|require\\|the\\|let\\|do\\|if\\|forall\\|exists\\|check\\|eval\\|infer\\|defmacro\\|spec\\|relation\\|clause\\|query\\|foreign\\|trait\\|impl\\|schema\\|defr\\|solver\\|solve-one\\|solve-with\\|explain\\|explain-with\\|rel\\)\\'"
              @font-lock-keyword-face)))
   ;; TODO: When the tree-sitter grammar adds `foreign` declarations,
   ;; add structural rules for :as aliases, racket language identifier,
   ;; and imported symbol names (currently only identifier-matched).

   ;; Level 2: function/definition names
   :language 'prologos
   :feature 'function
   '((defn_form name: (identifier) @font-lock-function-name-face)
     (def_form name: (identifier) @font-lock-function-name-face))

   :language 'prologos
   :feature 'definition
   '((data_form name: (identifier) @font-lock-type-face)
     (data_constructor name: (identifier) @font-lock-constant-face)
     (ns_declaration name: (qualified_name) @font-lock-constant-face))

   ;; Level 3: built-in type names (identifier-matched)
   :language 'prologos
   :feature 'type
   :override t
   '(((identifier) @font-lock-type-face
      (:match "\\`\\(?:Pi\\|Sigma\\|Type\\|Nat\\|Bool\\|Posit8\\|Vec\\|Fin\\|Eq\\|Chan\\|Session\\)\\'"
              @font-lock-type-face)))

   ;; Level 3: type expressions from grammar nodes
   :language 'prologos
   :feature 'type
   '((type_expr (identifier) @font-lock-type-face)
     (type_application (identifier) @font-lock-type-face)
     (implicit_params (identifier) @font-lock-type-face))

   ;; Level 3: built-in constants (identifier-matched)
   :language 'prologos
   :feature 'constant
   :override t
   '(((identifier) @font-lock-constant-face
      (:match "\\`\\(?:zero\\|true\\|false\\|refl\\|pair\\|inc\\|vnil\\|vcons\\|fzero\\|fsuc\\|nil\\|cons\\|nothing\\|just\\|posit8\\)\\'"
              @font-lock-constant-face)))

   :language 'prologos
   :feature 'number
   '((number) @font-lock-number-face)

   ;; Level 4: operators and multiplicity
   :language 'prologos
   :feature 'operator
   '(["->" "|"] @font-lock-operator-face)

   :language 'prologos
   :feature 'multiplicity
   '((multiplicity) @prologos-multiplicity-face))
  "Tree-sitter font-lock rules for Prologos.")

;; ============================================================
;; Defun name extraction
;; ============================================================

(defun prologos-ts--defun-name (node)
  "Return the name of the defun NODE for imenu and which-func."
  (treesit-node-text
   (treesit-node-child-by-field-name node "name")
   t))

;; ============================================================
;; Syntactic fontification fallback for tree-sitter
;; ============================================================
;;
;; The tree-sitter grammar doesn't handle all Prologos constructs
;; (e.g., `foreign' declarations).  Comments near ERROR nodes don't
;; get (comment) tree-sitter nodes, so they lose their face.
;;
;; This wrapper runs tree-sitter fontification first, then applies
;; Emacs's built-in syntactic fontification (using the syntax table)
;; as a safety net — any comment or string that tree-sitter missed
;; gets its face from the standard `syntax-ppss' based pass.

(defun prologos-ts--syntactic-fallback (beg end)
  "Apply comment/string faces via `syntax-ppss' in region BEG..END.
Only applies to positions where the `face' property is still nil,
so tree-sitter results are never overridden.

Handles three cases:
1. Point starts inside a comment or string (multi-line continuation).
2. Line begins with `;' — apply comment delimiter + comment faces.
3. Otherwise scan within the line for mid-line strings and comments
   that tree-sitter missed (e.g., on `foreign' declaration lines
   inside ERROR nodes)."
  (save-excursion
    (goto-char beg)
    (beginning-of-line)
    (while (< (point) end)
      (let* ((ppss (syntax-ppss (point)))
             (in-string (nth 3 ppss))
             (in-comment (nth 4 ppss))
             (start (point)))
        (cond
         (in-comment
          ;; Inside a comment — apply face to end of line
          (let ((comment-end (line-end-position)))
            (prologos-ts--apply-fallback-face
             start comment-end in-string in-comment)
            (goto-char (min (1+ comment-end) end))))
         (in-string
          ;; Inside a string — find its end via parse-partial-sexp
          (let ((string-end (save-excursion
                              (parse-partial-sexp (point) end nil nil ppss
                                                  'syntax-table)
                              (point))))
            (prologos-ts--apply-fallback-face
             start string-end in-string in-comment)
            (goto-char string-end)))
         (t
          ;; Not inside string or comment at start of line.
          ;; Check if line begins with comment delimiters.
          (if (looking-at "\\(;+\\)\\(.*\\)$")
              (let ((delim-end (match-end 1))
                    (line-end (match-end 0)))
                (prologos-ts--apply-fallback-face-range
                 start delim-end 'font-lock-comment-delimiter-face)
                (when (< delim-end line-end)
                  (prologos-ts--apply-fallback-face-range
                   delim-end line-end 'font-lock-comment-face))
                (goto-char (min (1+ line-end) end)))
            ;; Scan within the line for mid-line syntactic constructs.
            ;; This catches strings like "racket/base" and inline comments
            ;; on lines the tree-sitter grammar can't parse (ERROR nodes).
            (prologos-ts--scan-line-for-syntax end)
            (forward-line 1))))))))

(defun prologos-ts--scan-line-for-syntax (region-end)
  "Scan current line for mid-line strings and comments missed by tree-sitter.
Applies `font-lock-string-face' to string literals and
`font-lock-comment-face' to trailing comments.  Only touches
positions where `face' is still nil.  REGION-END bounds the scan."
  (let ((line-end (min (line-end-position) region-end))
        (pos (point)))
    (while (< pos line-end)
      (let ((ppss (syntax-ppss pos)))
        (cond
         ;; Entered a string
         ((nth 3 ppss)
          (let ((str-start (nth 8 ppss))  ; string/comment start position
                (str-end (save-excursion
                           (parse-partial-sexp pos line-end nil nil ppss
                                               'syntax-table)
                           (point))))
            ;; Apply string face (skip generic-string = racket blocks)
            (unless (eq (nth 3 ppss) t)
              (prologos-ts--apply-fallback-face-range pos str-end
                                                      'font-lock-string-face))
            (setq pos str-end)))
         ;; Entered a comment
         ((nth 4 ppss)
          (prologos-ts--apply-fallback-face-range pos line-end
                                                  'font-lock-comment-face)
          (setq pos line-end))
         ;; Normal code — advance to the next syntactically interesting char
         (t
          (let ((next (save-excursion
                        (parse-partial-sexp pos line-end nil nil ppss
                                            'syntax-table)
                        (point))))
            ;; If parse didn't advance (e.g., at line-end), force progress
            (setq pos (if (= next pos) line-end next)))))))))

(defun prologos-ts--apply-fallback-face (beg end in-string in-comment)
  "Apply syntactic face in BEG..END based on IN-STRING and IN-COMMENT.
Only applies where existing face is nil."
  (let ((face (cond
               (in-comment 'font-lock-comment-face)
               ((eq in-string t) nil)       ; generic-string (racket block)
               (in-string 'font-lock-string-face)
               (t nil))))
    (when face
      (prologos-ts--apply-fallback-face-range beg end face))))

(defun prologos-ts--apply-fallback-face-range (beg end face)
  "Apply FACE to positions in BEG..END where existing face is nil."
  (let ((pos beg))
    (while (< pos end)
      (let ((existing (get-text-property pos 'face))
            (next-change (or (next-single-property-change pos 'face nil end)
                             end)))
        (when (null existing)
          (put-text-property pos (min next-change end) 'face face))
        (setq pos next-change)))))

;; ============================================================
;; Native racket{...} block fontification for tree-sitter mode
;; ============================================================
;;
;; The tree-sitter grammar doesn't have a racket_escape node, so
;; racket{...} blocks parse as ERROR with their content treated as
;; regular Prologos nodes.  This pass finds racket blocks, applies
;; `prologos-racket-delimiter-face' to the delimiters, and delegates
;; to `prologos--fontify-racket-block-natively' (from prologos-font-lock.el)
;; for scheme-mode/racket-mode highlighting of the interior.

(defun prologos-ts--fontify-racket-blocks (beg end)
  "Find and natively fontify all racket{...} blocks in BEG..END.
Applies `prologos-racket-delimiter-face' to `racket{' and `}' delimiters,
and delegates interior fontification to scheme-mode/racket-mode."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "racket{" end t)
      (let ((kw-start (match-beginning 0))
            (brace-start (1- (point)))
            (content-start (point)))
        ;; Skip if inside a comment or string
        (unless (let ((ppss (save-excursion (syntax-ppss brace-start))))
                  (or (nth 3 ppss) (nth 4 ppss)))
          ;; Find matching } by brace counting
          (let ((depth 1)
                close)
            (save-excursion
              (goto-char content-start)
              (while (and (> depth 0) (re-search-forward "[{}]" end t))
                (cond
                 ((eq (char-before) ?\{) (setq depth (1+ depth)))
                 ((eq (char-before) ?\})
                  (setq depth (1- depth))
                  (when (= depth 0)
                    (setq close (1- (point))))))))
            (when close
              ;; Highlight delimiters
              (put-text-property kw-start (1+ brace-start)
                                 'face 'prologos-racket-delimiter-face)
              (put-text-property close (1+ close)
                                 'face 'prologos-racket-delimiter-face)
              ;; Natively fontify the interior content
              (when (< content-start close)
                (save-match-data
                  (prologos--fontify-racket-block-natively content-start close)))
              (goto-char (1+ close)))))))))

;; ============================================================
;; Keymap
;; ============================================================

(defvar prologos-ts-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-z") #'prologos-repl)
    (define-key map (kbd "C-x C-e") #'prologos-eval-last-sexp)
    (define-key map (kbd "C-c C-r") #'prologos-eval-region)
    (define-key map (kbd "C-c C-k") #'prologos-eval-buffer)
    (define-key map (kbd "C-c C-l") #'prologos-load-file)
    (define-key map (kbd "C-c C-d") #'prologos-eval-defun-at-point)
    map)
  "Keymap for `prologos-ts-mode'.")

;; ============================================================
;; Mode definition
;; ============================================================

;;;###autoload
(define-derived-mode prologos-ts-mode prog-mode "Prologos"
  "Tree-sitter based major mode for editing Prologos source files."
  :group 'prologos
  :syntax-table (if (boundp 'prologos-mode-syntax-table)
                    prologos-mode-syntax-table
                  (make-syntax-table))

  ;; Ensure tree-sitter parser is available
  (unless (treesit-ready-p 'prologos)
    (error "Tree-sitter grammar for `prologos' is not available"))

  (treesit-parser-create 'prologos)

  ;; Font-lock — tree-sitter rules
  (setq-local treesit-font-lock-settings prologos-ts-font-lock-rules)
  (setq-local treesit-font-lock-feature-list
              '((comment string)
                (keyword function definition)
                (type constant number multiplicity)
                (operator)))

  ;; Syntax propertize — angle brackets + racket{...} escape blocks
  (setq-local syntax-propertize-function #'prologos--syntax-propertize)
  (add-hook 'syntax-propertize-extend-region-functions
            #'prologos--extend-region-for-syntax nil t)

  ;; Extend jit-lock region across racket{...} blocks
  (add-hook 'jit-lock-after-change-extend-region-functions
            #'prologos--jit-lock-extend-region nil t)

  ;; WS mode — .prologos files always use whitespace-significant syntax
  (prologos--detect-lang-mode)

  ;; Indentation — WS mode: indentation IS the syntax, use TAB cycling
  (setq-local indent-line-function #'prologos--ws-indent-line)

  ;; Comments
  (setq-local comment-start ";; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip ";+\\s-*")

  ;; Navigation via treesit
  (setq-local treesit-defun-type-regexp
              (rx (or "defn_form" "def_form" "data_form" "deftype_form")))
  (setq-local treesit-defun-name-function #'prologos-ts--defun-name)

  ;; Imenu via treesit
  (setq-local treesit-simple-imenu-settings
              '(("Function" "\\`defn_form\\'" nil nil)
                ("Function" "\\`def_form\\'" nil nil)
                ("Type" "\\`data_form\\'" nil nil)
                ("Type" "\\`deftype_form\\'" nil nil)))

  ;; Activate tree-sitter features
  (treesit-major-mode-setup)

  ;; After treesit-major-mode-setup: install a wrapper around the
  ;; fontify-region function that runs three passes:
  ;; 1. Standard tree-sitter font-lock
  ;; 2. Syntactic fallback (comments/strings in ERROR regions)
  ;; 3. Native racket{...} block fontification (scheme-mode highlighting)
  (let ((original-fn font-lock-fontify-region-function))
    (setq-local font-lock-fontify-region-function
                (lambda (beg end &optional loudly)
                  ;; Pass 1: tree-sitter font-lock
                  (funcall original-fn beg end loudly)
                  ;; Pass 2: syntactic fallback for missed comments/strings
                  (prologos-ts--syntactic-fallback beg end)
                  ;; Pass 3: native racket{...} block highlighting
                  (when prologos-fontify-racket-blocks-natively
                    (prologos-ts--fontify-racket-blocks beg end))))))

;; ============================================================
;; Auto-mode fallback
;; ============================================================

;;;###autoload
(defun prologos-ts-mode-or-fallback ()
  "Use `prologos-ts-mode' if tree-sitter grammar available, else `prologos-mode'."
  (if (treesit-ready-p 'prologos t)
      (prologos-ts-mode)
    (prologos-mode)))

;; Override auto-mode-alist to use tree-sitter fallback dispatcher.
;; This takes precedence over prologos-mode.el's plain binding because
;; add-to-list pushes to the front of the alist.
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.prologos\\'" . prologos-ts-mode-or-fallback))

(provide 'prologos-ts-mode)

;;; prologos-ts-mode.el ends here



;;; TODO Sprint 3-7/8 of Implementation Prologos Surfer
