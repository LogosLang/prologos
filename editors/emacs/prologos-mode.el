;;; prologos-mode.el --- Major mode for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: languages
;; URL: https://github.com/prologos-lang/prologos

;;; Commentary:

;; Major mode for editing Prologos source files (.prologos).
;; Prologos is a dependently-typed functional-logic language unifying
;; dependent types, session types, linear types (QTT), logic
;; programming, and propagators.
;;
;; Features:
;; - Syntax highlighting (5 levels via font-lock)
;; - Comment and string handling
;; - Bracket matching for (), [], <>, {} ([] used for grouping in WS mode)
;; - #lang detection for sexp vs. whitespace-significant mode
;; - Defun navigation (C-M-a / C-M-e)
;; - Imenu support for definitions
;; - Optional prettify-symbols (Pi -> Π, fn -> λ, etc.)

;;; Code:

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
;; Customization
;; ============================================================

(defgroup prologos nil
  "Major mode for Prologos."
  :prefix "prologos-"
  :group 'languages
  :link '(url-link "https://github.com/prologos-lang/prologos"))

;; ============================================================
;; Syntax table
;; ============================================================

(defvar prologos-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Comments: ; to end of line
    (modify-syntax-entry ?\; "<" table)
    (modify-syntax-entry ?\n ">" table)
    ;; Strings
    (modify-syntax-entry ?\" "\"" table)
    ;; Escape character in strings
    (modify-syntax-entry ?\\ "\\" table)
    ;; Brackets
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    ;; Angle brackets: punctuation by default.
    ;; syntax-propertize-function promotes matched <> to bracket syntax.
    ;; This avoids the > in -> being parsed as an unmatched close-bracket.
    (modify-syntax-entry ?\< "." table)
    (modify-syntax-entry ?\> "." table)
    ;; Symbol constituents
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?- "_" table)
    (modify-syntax-entry ?? "_" table)
    (modify-syntax-entry ?! "_" table)
    (modify-syntax-entry ?* "_" table)
    (modify-syntax-entry ?+ "_" table)
    (modify-syntax-entry ?/ "_" table)
    (modify-syntax-entry ?. "_" table)
    (modify-syntax-entry ?= "_" table)
    ;; Colon as punctuation (not symbol) — important for :0, :1, :w
    (modify-syntax-entry ?: "." table)
    table)
  "Syntax table for `prologos-mode'.")

;; ============================================================
;; Syntax propertize — angle bracket matching
;; ============================================================

;; The < and > characters serve dual roles:
;;   - Type annotation delimiters: <Nat>, <(-> A B)>
;;   - Part of the arrow operator: ->
;;
;; The syntax table sets them as punctuation. This function scans
;; for < that opens a type annotation (not preceded by -) and its
;; matching >, and gives them bracket syntax via text properties.

(defun prologos--syntax-propertize (start end)
  "Apply bracket syntax to angle brackets used as type annotations.
Scans region from START to END."
  (goto-char start)
  (while (re-search-forward "<" end t)
    ;; Only treat < as open-bracket if not preceded by - (i.e., not ->)
    (let ((pos (match-beginning 0)))
      (unless (and (> pos (point-min))
                   (eq (char-before pos) ?-))
        ;; Find the matching > by counting nesting
        (let ((depth 1)
              (limit end)
              (found nil))
          (save-excursion
            (while (and (> depth 0) (re-search-forward "[<>]" limit t))
              (let ((ch (char-before)))
                (cond
                 ((eq ch ?<)
                  ;; Only count as nesting if not part of ->
                  (unless (and (> (match-beginning 0) (point-min))
                               (eq (char-before (match-beginning 0)) ?-))
                    (setq depth (1+ depth))))
                 ((eq ch ?>)
                  ;; Only count as closing if not followed by something
                  ;; that makes it part of a symbol (future-proofing)
                  (setq depth (1- depth))
                  (when (= depth 0)
                    (setq found (match-beginning 0)))))))
            (when found
              ;; Mark the < as open-bracket
              (put-text-property pos (1+ pos)
                                 'syntax-table (string-to-syntax "(>"))
              ;; Mark the > as close-bracket
              (put-text-property found (1+ found)
                                 'syntax-table (string-to-syntax ")<")))))))))

;; ============================================================
;; #lang mode detection
;; ============================================================

(defvar-local prologos--ws-mode-p t
  "Non-nil when the current buffer uses significant-whitespace mode.
Prologos .prologos files always use WS mode.")

(defun prologos--detect-lang-mode ()
  "Set WS mode (the only supported mode for .prologos files)."
  (setq prologos--ws-mode-p t))

;; ============================================================
;; Defun navigation
;; ============================================================

(defun prologos-beginning-of-defun (&optional arg)
  "Move to the beginning of the ARGth preceding top-level definition."
  (interactive "p")
  (re-search-backward
   "^\\s-*[(\\[]\\(?:def\\(?:n\\|type\\|macro\\)?\\|data\\|spec\\|relation\\)\\s-"
   nil t (or arg 1)))

(defun prologos-end-of-defun (&optional arg)
  "Move to the end of the ARGth following top-level definition."
  (interactive "p")
  (prologos-beginning-of-defun (- (or arg 1)))
  (forward-sexp 1))

;; ============================================================
;; Imenu
;; ============================================================

(defvar prologos-imenu-generic-expression
  `(("Definitions" "^\\s-*[(\\[]def\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Functions"   "^\\s-*[(\\[]defn\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Specs"       "^\\s-*[(\\[]?spec\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Types"       "^\\s-*[(\\[]deftype\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Macros"      "^\\s-*[(\\[]defmacro\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Data"        "^\\s-*[(\\[]data\\s-+(?\\([A-Z][a-zA-Z0-9_]*\\)" 1))
  "Imenu generic expression for Prologos mode.")

;; ============================================================
;; Keymap
;; ============================================================

(defvar prologos-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-z") #'prologos-repl)
    (define-key map (kbd "C-x C-e") #'prologos-eval-last-sexp)
    (define-key map (kbd "C-c C-r") #'prologos-eval-region)
    (define-key map (kbd "C-c C-k") #'prologos-eval-buffer)
    (define-key map (kbd "C-c C-l") #'prologos-load-file)
    (define-key map (kbd "C-c C-d") #'prologos-eval-defun-at-point)
    map)
  "Keymap for `prologos-mode'.")

;; ============================================================
;; Mode definition
;; ============================================================

;;;###autoload
(define-derived-mode prologos-mode prog-mode "Prologos"
  "Major mode for editing Prologos source files."
  :group 'prologos
  :syntax-table prologos-mode-syntax-table

  ;; Font-lock
  (setq-local font-lock-defaults '(prologos-font-lock-keywords nil nil))

  ;; Syntax propertize — angle bracket matching
  (setq-local syntax-propertize-function #'prologos--syntax-propertize)

  ;; Indentation
  (setq-local indent-line-function #'prologos-indent-line)

  ;; Comments
  (setq-local comment-start ";; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip ";+\\s-*")

  ;; Navigation
  (setq-local beginning-of-defun-function #'prologos-beginning-of-defun)
  (setq-local end-of-defun-function #'prologos-end-of-defun)

  ;; Imenu
  (setq-local imenu-generic-expression prologos-imenu-generic-expression)

  ;; Detect #lang mode for WS vs. sexp behavior
  (prologos--detect-lang-mode)

  ;; Prettify symbols (opt-in)
  (when prologos-pretty-symbols
    (prologos--setup-prettify-symbols)))

;; ============================================================
;; Auto-mode-alist registration
;; ============================================================

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.prologos\\'" . prologos-mode))

(provide 'prologos-mode)

;;; prologos-mode.el ends here
