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
    ;; Curly braces: punctuation by default.
    ;; syntax-propertize-function promotes racket{...} braces to
    ;; generic-string syntax.  Keeping them as punctuation avoids
    ;; jit-lock seeing unmatched brackets before propertize runs.
    (modify-syntax-entry ?\{ "." table)
    (modify-syntax-entry ?\} "." table)
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
;; Syntax propertize — angle bracket matching & racket{...}
;; ============================================================

;; The < and > characters serve dual roles:
;;   - Type annotation delimiters: <Nat>, <(-> A B)>
;;   - Part of the arrow operator: ->
;;
;; The syntax table sets them as punctuation. This function scans
;; for < that opens a type annotation (not preceded by -) and its
;; matching >, and gives them bracket syntax via text properties.
;;
;; It also marks the content inside racket{...} escape blocks as
;; generic-string (syntax class |) so that Racket code with quotes
;; or angle brackets doesn't interfere with Prologos fontification.

(defun prologos--syntax-propertize (start end)
  "Apply syntax properties for Prologos in region START..END.
1. Mark angle brackets used as type annotations with bracket syntax.
2. Mark racket{...} escape block interiors as generic-string so
   embedded Racket code (containing quotes, brackets, etc.) does
   not corrupt Prologos fontification.
Skips constructs inside comments or strings."
  (goto-char start)
  ;; Pass 1: racket{...} escape blocks — mark content as generic-string.
  ;; We search for `racket{' and mark everything between { and matching }
  ;; so Emacs treats the block contents as an opaque string.
  (while (re-search-forward "racket{" end t)
    (let ((brace-start (1- (point))))  ; position of {
      (unless (let ((ppss (save-excursion (syntax-ppss brace-start))))
                (or (nth 3 ppss) (nth 4 ppss)))
        ;; Find matching } by counting brace nesting
        (let ((depth 1)
              (found nil))
          (while (and (> depth 0) (re-search-forward "[{}]" end t))
            (let ((ch (char-before)))
              (cond
               ((eq ch ?\{) (setq depth (1+ depth)))
               ((eq ch ?\})
                (setq depth (1- depth))
                (when (= depth 0)
                  (setq found (1- (point))))))))
          (when found
            ;; Mark { as generic-string opener (syntax class |)
            (put-text-property brace-start (1+ brace-start)
                               'syntax-table (string-to-syntax "|"))
            ;; Mark } as generic-string closer
            (put-text-property found (1+ found)
                               'syntax-table (string-to-syntax "|"))
            ;; Mark the block for multiline handling so jit-lock
            ;; re-propertizes the entire block when any part changes
            (put-text-property brace-start (1+ found)
                               'syntax-multiline t)
            (put-text-property brace-start (1+ found)
                               'font-lock-multiline t))))))
  ;; Pass 2: angle bracket type annotations
  (goto-char start)
  (while (re-search-forward "<" end t)
    (let ((pos (match-beginning 0)))
      ;; Skip angle brackets inside comments, strings, or generic-strings
      (unless (let ((ppss (save-excursion (syntax-ppss pos))))
                (or (nth 3 ppss) (nth 4 ppss)))
        ;; Only treat < as open-bracket if not preceded by - (i.e., not ->)
        (unless (and (> pos (point-min))
                     (eq (char-before pos) ?-))
          ;; Find the matching > by counting nesting
          (let ((depth 1)
                (limit end)
                (found nil))
            (save-excursion
              (while (and (> depth 0) (re-search-forward "[<>]" limit t))
                (let* ((mpos (match-beginning 0))
                       (ch (char-before))
                       (inner-ppss (save-excursion (syntax-ppss mpos))))
                  ;; Skip brackets inside comments, strings, or generic-strings
                  (unless (or (nth 3 inner-ppss) (nth 4 inner-ppss))
                    (cond
                     ((eq ch ?<)
                      ;; Only count as nesting if not part of ->
                      (unless (and (> mpos (point-min))
                                   (eq (char-before mpos) ?-))
                        (setq depth (1+ depth))))
                     ((eq ch ?>)
                      ;; Only count as closing
                      (setq depth (1- depth))
                      (when (= depth 0)
                        (setq found mpos))))))))
            (when found
              ;; Mark the < as open-bracket
              (put-text-property pos (1+ pos)
                                 'syntax-table (string-to-syntax "(>"))
              ;; Mark the > as close-bracket
              (put-text-property found (1+ found)
                                 'syntax-table (string-to-syntax ")<")))))))))

(defun prologos--extend-region-for-syntax (start end)
  "Extend the syntax-propertize region to include full racket{...} blocks.
Called with START and END; returns (NEW-START . NEW-END) or nil.
When jit-lock starts fontifying in the middle of a multi-line racket{...}
block, this ensures the region is extended back to the opening `racket{'
so syntax properties are applied correctly."
  (let ((new-start start)
        (new-end end))
    ;; If START is inside a racket{...} block, search backward for `racket{'
    (save-excursion
      (goto-char start)
      (when (re-search-backward "racket{" nil t)
        (let ((brace-pos (1- (match-end 0))) ; position of {
              (depth 1)
              (close nil))
          ;; Find the matching } from after the {
          (save-excursion
            (goto-char (1+ brace-pos))
            (while (and (> depth 0) (re-search-forward "[{}]" nil t))
              (cond
               ((eq (char-before) ?\{) (setq depth (1+ depth)))
               ((eq (char-before) ?\})
                (setq depth (1- depth))
                (when (= depth 0)
                  (setq close (point)))))))
          ;; If START falls inside this block, extend back
          (when (and close (> close start) (<= brace-pos start))
            (setq new-start (match-beginning 0))
            (when (> close new-end)
              (setq new-end close))))))
    ;; Return cons if changed, nil otherwise
    (if (or (/= new-start start) (/= new-end end))
        (cons new-start new-end)
      nil)))

(defun prologos--syntactic-face-function (state)
  "Return the face for a syntactic construct described by STATE.
Returns nil for generic-string contexts (racket{...} blocks) so that
the keyword-level native fontifier handles them.  For regular strings
and comments, returns the standard faces."
  (cond
   ((nth 4 state) font-lock-comment-face)          ; in a comment
   ((eq (nth 3 state) t) nil)                       ; generic-string (racket block)
   ((nth 3 state) font-lock-string-face)            ; in a regular string
   (t nil)))

;; Forward-declare jit-lock variables for the byte-compiler
(defvar jit-lock-start)
(defvar jit-lock-end)

(defun prologos--jit-lock-extend-region (_start _end _old-len)
  "Extend jit-lock region to fully include any racket{...} block.
Added to `jit-lock-after-change-extend-region-functions'.
Mutates `jit-lock-start' and `jit-lock-end' as side effects."
  (let ((res (prologos--extend-region-for-syntax jit-lock-start jit-lock-end)))
    (when res
      (setq jit-lock-start (min jit-lock-start (car res))
            jit-lock-end   (max jit-lock-end   (cdr res))))))

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
   "^\\s-*[(\\[]?\\(?:def\\(?:n\\|type\\|macro\\)?\\|data\\|spec\\|relation\\|foreign\\)\\s-"
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
  `(("Definitions" "^\\s-*[(\\[]?def\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Functions"   "^\\s-*[(\\[]?defn\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Specs"       "^\\s-*[(\\[]?spec\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Types"       "^\\s-*[(\\[]?deftype\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Macros"      "^\\s-*[(\\[]?defmacro\\s-+\\([a-zA-Z_][a-zA-Z0-9_!?*-]*\\)" 1)
    ("Data"        "^\\s-*[(\\[]?data\\s-+(?\\([A-Z][a-zA-Z0-9_]*\\)" 1))
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

  ;; Font-lock (enable multiline support for racket{...} blocks)
  (setq-local font-lock-defaults
              '(prologos-font-lock-keywords nil nil nil nil
                (font-lock-multiline . t)
                (font-lock-syntactic-face-function
                 . prologos--syntactic-face-function)))

  ;; Syntax propertize — angle brackets + racket{...} escape blocks
  (setq-local syntax-propertize-function #'prologos--syntax-propertize)
  (add-hook 'syntax-propertize-extend-region-functions
            #'prologos--extend-region-for-syntax nil t)

  ;; Extend jit-lock region across racket{...} blocks
  (add-hook 'jit-lock-after-change-extend-region-functions
            #'prologos--jit-lock-extend-region nil t)

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
