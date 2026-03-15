;;; prologos-indent.el --- Indentation engine for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors

;;; Commentary:

;; Custom indentation for Prologos source files.
;;
;; Sexp mode (#lang prologos/sexp): Lisp-style indentation using the
;; standard `lisp-indent-function' symbol property on each form.
;; Emacs's built-in `calculate-lisp-indent' reads these properties
;; and dispatches to `lisp-indent-specform'/`lisp-indent-defform'.
;;
;; WS mode (#lang prologos): Indentation is semantically significant.
;; The engine preserves existing indentation on non-blank lines and
;; matches the previous non-blank line's indentation on blank lines.

;;; Code:

;; Forward declaration — defined as buffer-local in prologos-mode.el
(defvar prologos--ws-mode-p)

;; ============================================================
;; Customization
;; ============================================================

(defcustom prologos-indent-offset 2
  "Number of spaces for each indentation level in Prologos."
  :type 'integer
  :group 'prologos)

(defcustom prologos-indent-trigger-commands
  '(indent-for-tab-command)
  "Commands that trigger indent cycling in WS mode.
When one of these commands is repeated (TAB TAB TAB...),
WS mode cycles through plausible indentation levels."
  :type '(repeat symbol)
  :group 'prologos)

;; ============================================================
;; Indent properties for Prologos forms
;;
;; Uses the standard 'lisp-indent-function symbol property so that
;; Emacs's built-in calculate-lisp-indent dispatches correctly.
;; This is the same mechanism used by racket-mode and clojure-mode.
;; ============================================================

;; defun-style indentation (body gets extra indent)
(put 'def      'lisp-indent-function 'defun)
(put 'defn     'lisp-indent-function 'defun)
(put 'deftype  'lisp-indent-function 'defun)
(put 'defmacro 'lisp-indent-function 'defun)
(put 'data     'lisp-indent-function 'defun)
(put 'relation 'lisp-indent-function 'defun)
(put 'defr     'lisp-indent-function 'defun)
(put 'schema   'lisp-indent-function 'defun)
(put 'solver   'lisp-indent-function 'defun)

;; 1-arg special forms (first arg on same line, rest indented)
(put 'fn      'lisp-indent-function 1)
(put 'solve-with   'lisp-indent-function 1)
(put 'explain-with 'lisp-indent-function 1)
(put 'the     'lisp-indent-function 1)
(put 'match   'lisp-indent-function 1)

;; 2-arg special forms
(put 'if 'lisp-indent-function 2)

;; let/do
(put 'let 'lisp-indent-function 1)
(put 'do  'lisp-indent-function 0)

;; Type forms
(put 'Pi     'lisp-indent-function 1)
(put 'Sigma  'lisp-indent-function 1)
(put 'forall 'lisp-indent-function 1)
(put 'exists 'lisp-indent-function 1)

;; ============================================================
;; Sexp mode indent-line wrapper
;; ============================================================

(defun prologos--sexp-indent-line ()
  "Indent current line using Lisp-style indentation for sexp mode."
  (lisp-indent-line))

;; ============================================================
;; WS mode — TAB-cycling indentation
;;
;; Follows the Python-mode pattern: first TAB indents to the
;; suggested level; repeated TABs cycle through plausible
;; indent levels (decreasing, then wrap back to maximum).
;; ============================================================

(defun prologos--ws-prev-nonblank-indent ()
  "Return indentation of the previous non-blank line, or 0."
  (save-excursion
    (forward-line -1)
    (while (and (not (bobp))
                (looking-at "^\\s-*$"))
      (forward-line -1))
    (if (looking-at "^\\s-*$")
        0
      (current-indentation))))

(defun prologos--ws-calculate-indent-levels ()
  "Return a sorted list of plausible indent levels for current line.
Based on the previous non-blank line's indentation, offers:
  - 0 (top-level)
  - prev-indent - offset (dedent)
  - prev-indent (same level)
  - prev-indent + offset (indent deeper)"
  (let* ((prev-indent (prologos--ws-prev-nonblank-indent))
         (offset prologos-indent-offset)
         (candidates (list 0
                           (max 0 (- prev-indent offset))
                           prev-indent
                           (+ prev-indent offset))))
    (delete-dups (sort candidates #'<))))

(defun prologos--ws-cycle-indent (levels current-indent)
  "Return the next lower indent level from LEVELS, cycling at minimum.
LEVELS is a sorted ascending list of indent columns.
CURRENT-INDENT is the current indentation.
Returns the largest level that is strictly less than CURRENT-INDENT,
or wraps to the maximum level if already at or below the minimum."
  (let* ((rev-levels (reverse levels))
         (default (car rev-levels)))  ;; max level
    (catch 'found
      (dolist (level rev-levels)
        (when (< level current-indent)
          (throw 'found level)))
      default)))

(defun prologos--ws-indent-line ()
  "Indent line in whitespace-significant mode with TAB cycling.
Blank lines: indent to match previous non-blank line.
Non-blank lines, first TAB: preserve existing indentation.
Non-blank lines, repeated TABs: cycle through plausible indent levels."
  (if (= (line-beginning-position) (line-end-position))
      ;; Blank line: indent to match previous non-blank line
      (let ((target (prologos--ws-prev-nonblank-indent)))
        (indent-line-to target)
        (when (< (current-column) target)
          (move-to-column target)))
    ;; Non-blank line: cycle on repeated TAB
    (let* ((cycling-p (and (memq this-command prologos-indent-trigger-commands)
                           (eq last-command this-command)))
           (levels (prologos--ws-calculate-indent-levels))
           (target (if cycling-p
                       (prologos--ws-cycle-indent levels (current-indentation))
                     ;; First TAB: preserve existing indentation
                     (current-indentation))))
      (indent-line-to target)
      (when (< (current-column) target)
        (move-to-column target)))))

;; ============================================================
;; Top-level dispatcher
;; ============================================================

(defun prologos-indent-line ()
  "Indent current line as Prologos code.
In WS mode, TAB cycles through plausible indentation levels.
In sexp mode, uses Lisp-style indentation with Prologos-specific rules."
  (interactive)
  (if prologos--ws-mode-p
      (prologos--ws-indent-line)
    (prologos--sexp-indent-line)))

(provide 'prologos-indent)

;;; prologos-indent.el ends here
