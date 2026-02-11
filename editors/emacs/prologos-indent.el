;;; prologos-indent.el --- Indentation engine for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors

;;; Commentary:

;; Custom indentation for Prologos source files.
;;
;; Sexp mode (#lang prologos/sexp): Lisp-style indentation using a
;; custom `lisp-indent-function' that dispatches on per-form indent
;; properties.  Reuses Emacs's `lisp-indent-specform' and
;; `lisp-indent-defform' for battle-tested indentation logic.
;;
;; WS mode (#lang prologos): Indentation is semantically significant.
;; The engine preserves existing indentation on non-blank lines and
;; matches the previous non-blank line's indentation on blank lines.

;;; Code:

;; Forward declaration — defined as buffer-local in prologos-mode.el
(defvar prologos--ws-mode-p)

;; ============================================================
;; Sexp mode: custom lisp-indent-function
;; ============================================================

(defun prologos-lisp-indent-function (indent-point state)
  "Calculate indentation for Prologos forms in sexp mode.
Consults the `prologos-indent-function' property of the head symbol.

INDENT-POINT is the position being indented.
STATE is the parse state from `parse-partial-sexp'."
  (let ((normal-indent (current-column)))
    (goto-char (1+ (elt state 1)))
    (parse-partial-sexp (point) indent-point 0 t)
    (if (and (elt state 2)
             (not (looking-at "\\sw\\|\\s_")))
        ;; First element is not a symbol — align with first arg
        (progn
          (when (not (> (save-excursion (forward-line 1) (point))
                       (elt state 2)))
            (goto-char (elt state 2))
            (beginning-of-line)
            (parse-partial-sexp (point) (elt state 2) 0 t))
          (current-column))
      ;; First element is a symbol — check for prologos-indent-function property
      (let* ((function (buffer-substring (point)
                                         (progn (forward-sexp 1) (point))))
             (method (get (intern-soft function) 'prologos-indent-function)))
        (cond ((integerp method)
               (lisp-indent-specform method state indent-point normal-indent))
              ((eq method 'defun)
               (lisp-indent-defform state indent-point))
              (t
               ;; Default: align with first argument
               (let ((function (buffer-substring (point)
                                                 (progn (goto-char (elt state 1))
                                                        (forward-sexp 1)
                                                        (point)))))
                 normal-indent)))))))

;; ============================================================
;; Indent properties for Prologos forms
;; ============================================================

;; defun-style indentation (body gets extra indent)
(put 'def      'prologos-indent-function 'defun)
(put 'defn     'prologos-indent-function 'defun)
(put 'deftype  'prologos-indent-function 'defun)
(put 'defmacro 'prologos-indent-function 'defun)
(put 'data     'prologos-indent-function 'defun)
(put 'relation 'prologos-indent-function 'defun)

;; 1-arg special forms (first arg on same line, rest indented)
(put 'fn      'prologos-indent-function 1)
(put 'the     'prologos-indent-function 1)
(put 'match   'prologos-indent-function 1)
(put 'reduce  'prologos-indent-function 1)

;; 2-arg special forms
(put 'if 'prologos-indent-function 2)

;; let/do
(put 'let 'prologos-indent-function 1)
(put 'do  'prologos-indent-function 0)

;; Type forms
(put 'Pi     'prologos-indent-function 1)
(put 'Sigma  'prologos-indent-function 1)
(put 'forall 'prologos-indent-function 1)
(put 'exists 'prologos-indent-function 1)

;; ============================================================
;; Sexp mode indent-line wrapper
;; ============================================================

(defun prologos--sexp-indent-line ()
  "Indent current line using Lisp-style indentation for sexp mode."
  (lisp-indent-line))

;; ============================================================
;; WS mode indent-line
;; ============================================================

(defun prologos--ws-indent-line ()
  "Indent line in whitespace-significant mode.
Preserves existing indentation (which is semantic).
Only indents blank lines to match previous non-blank line."
  (let ((current-indent (current-indentation)))
    (if (= (line-beginning-position) (line-end-position))
        ;; Blank line: indent to match previous non-blank line
        (indent-line-to (save-excursion
                          (forward-line -1)
                          (while (and (not (bobp))
                                      (looking-at "^\\s-*$"))
                            (forward-line -1))
                          (current-indentation)))
      ;; Non-blank line: preserve existing indentation (semantic!)
      (indent-line-to current-indent))))

;; ============================================================
;; Top-level dispatcher
;; ============================================================

(defun prologos-indent-line ()
  "Indent current line as Prologos code.
In WS mode, indentation is semantic and preserved.
In sexp mode, uses Lisp-style indentation with Prologos-specific rules."
  (interactive)
  (if prologos--ws-mode-p
      (prologos--ws-indent-line)
    (prologos--sexp-indent-line)))

(provide 'prologos-indent)

;;; prologos-indent.el ends here
