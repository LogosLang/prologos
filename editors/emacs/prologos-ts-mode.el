;;; prologos-ts-mode.el --- Tree-sitter major mode for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors
;; Version: 0.1.0
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
;; - Tree-sitter based font-lock (4 levels: comment/string, keyword/definition,
;;   type/constant/number, operator/multiplicity)
;; - Imenu support for defn, def, data, and ns declarations
;; - Defun navigation (C-M-a / C-M-e) via treesit
;; - WS mode indentation (TAB cycling, reused from prologos-indent.el)
;; - Automatic fallback to prologos-mode when grammar unavailable

;;; Code:

(require 'treesit)
(require 'prologos-font-lock)
(require 'prologos-indent)

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

   ;; Level 2: keywords and definition names
   :language 'prologos
   :feature 'keyword
   '(["defn" "def" "data" "deftype" "match" "fn"
      "ns" "provide" "require" ":refer"] @font-lock-keyword-face)

   :language 'prologos
   :feature 'definition
   '((defn_form name: (identifier) @font-lock-function-name-face)
     (def_form name: (identifier) @font-lock-function-name-face)
     (data_form name: (identifier) @font-lock-type-face)
     (data_constructor name: (identifier) @font-lock-constant-face)
     (ns_declaration name: (qualified_name) @font-lock-constant-face))

   ;; Level 3: types, constructors, numbers
   :language 'prologos
   :feature 'type
   '((type_expr (identifier) @font-lock-type-face)
     (type_application (identifier) @font-lock-type-face)
     (arrow_type) @font-lock-type-face
     (paren_type) @font-lock-type-face
     (implicit_params (identifier) @font-lock-type-face))

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
                (keyword definition)
                (type number operator multiplicity)))

  ;; Indentation — WS mode: indentation IS the syntax, use TAB cycling
  ;; Tree-sitter indent rules don't make sense for WS-significant syntax
  (setq-local prologos--ws-mode-p t)
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
                ("Definition" "\\`def_form\\'" nil nil)
                ("Type" "\\`data_form\\'" nil nil)
                ("Namespace" "\\`ns_declaration\\'" nil nil)))

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
