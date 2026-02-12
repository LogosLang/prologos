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

(defvar prologos-ts-font-lock-rules
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
      "ns" "provide" "require" ":refer"] @font-lock-keyword-face)

   :language 'prologos
   :feature 'keyword
   :override t
   '(((identifier) @font-lock-keyword-face
      (:match "\\`\\(?:the\\|let\\|do\\|if\\|reduce\\|forall\\|exists\\|check\\|eval\\|infer\\|defmacro\\|relation\\|clause\\|query\\)\\'"
              @font-lock-keyword-face)))

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

  ;; Font-lock
  (setq-local treesit-font-lock-settings prologos-ts-font-lock-rules)
  (setq-local treesit-font-lock-feature-list
              '((comment string)
                (keyword function definition)
                (type constant number multiplicity)
                (operator)))

  ;; Detect #lang mode — WS mode is default, sexp mode only for #lang prologos/sexp
  (prologos--detect-lang-mode)

  ;; Indentation — WS mode: indentation IS the syntax, use TAB cycling
  ;; Tree-sitter indent rules don't make sense for WS-significant syntax
  (setq-local indent-line-function
              (if prologos--ws-mode-p
                  #'prologos--ws-indent-line
                #'prologos--sexp-indent-line))

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
  (treesit-major-mode-setup))

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
