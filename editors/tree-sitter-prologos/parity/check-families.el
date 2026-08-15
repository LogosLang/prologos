;;; check-families.el --- do both consumers give a capture the same ROLE? -*- lexical-binding: t; -*-

;;; Commentary:

;; `check-parity.sh' proves both consumers see the same CAPTURES.  It never asks
;; what those captures RESOLVE TO, so one capture could be a constant in Emacs
;; and a string in VS Code with every gate green.  That is not hypothetical: it
;; is how a stale build shipped keyword literals with string chrome on
;; 2026-08-15, and no gate could see it.
;;
;; This gate asks the missing question: for each capture BOTH consumers map,
;; does it land in the same semantic FAMILY?
;;
;; ⚠ It does not compare colours, and it must not.  Colour is per-editor and
;; per-theme, which `captures.md' states on purpose.  A family is the ROLE — "a
;; constant", "a type" — and role is meaning, which the same file says IS
;; shared.  See families.tsv.
;;
;; Blind to: whether either mapping is RIGHT (that is check-tokens.mjs and human
;; judgement), whether a capture is mapped at all (check-vocabulary.sh), and what
;; any theme actually paints.
;;
;; Usage: ./check-families.sh

;;; Code:

(require 'prologos-ts-mode)
(require 'cl-lib)
(require 'subr-x)

(defconst prologos-fam--here
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "Directory of this file, captured at LOAD time.")

(defun prologos-fam--path (rel)
  (expand-file-name rel prologos-fam--here))

(defun prologos-fam--slurp (p)
  (with-temp-buffer (insert-file-contents p) (buffer-string)))

;; ------------------------------------------------------------------
;; The family table
;; ------------------------------------------------------------------

(defun prologos-fam--families ()
  "Return (FAMILY EMACS-FACES VSCODE-PREFIXES) rows from families.tsv."
  (cl-loop for line in (split-string (prologos-fam--slurp
                                      (prologos-fam--path "families.tsv")) "\n" t)
           unless (or (string-prefix-p "#" line) (string-blank-p line))
           collect (let ((f (split-string line "\t" nil)))
                     (list (string-trim (nth 0 f))
                           (split-string (or (nth 1 f) "") " " t)
                           (split-string (or (nth 2 f) "") " " t)))))

(defun prologos-fam--face-family (face rows)
  "Family of FACE, following its `:inherit' chain.  nil when unknown."
  (let ((name (if face (symbol-name face) "nil"))
        (seen '()) hit)
    (while (and name (not hit) (not (member name seen)))
      (push name seen)
      (setq hit (cl-loop for r in rows
                         when (member name (nth 1 r)) return (nth 0 r)))
      (unless hit
        ;; Follow :inherit so a project face lands where its parent does.
        (let* ((sym (intern-soft name))
               (parent (and sym (facep sym)
                            (face-attribute sym :inherit nil nil))))
          (setq name (cond ((and parent (symbolp parent) (not (eq parent 'unspecified)))
                            (symbol-name parent))
                           ((consp parent) (symbol-name (car parent)))
                           (t nil))))))
    hit))

(defun prologos-fam--scope-family (scope rows)
  "Family of TextMate SCOPE by LONGEST matching prefix.  nil when unknown."
  (let ((best nil) (best-len -1))
    (dolist (r rows)
      (dolist (pfx (nth 2 r))
        (when (and (or (string= scope pfx) (string-prefix-p (concat pfx ".") scope))
                   (> (length pfx) best-len))
          (setq best (nth 0 r) best-len (length pfx)))))
    best))

;; ------------------------------------------------------------------
;; The two mappings
;; ------------------------------------------------------------------

(defun prologos-fam--emacs-map ()
  "Alist of (CAPTURE . FACE) from the live Emacs mapping."
  (symbol-value 'prologos-ts--capture-faces))

(defun prologos-fam--vscode-map ()
  "Alist of (CAPTURE . SCOPE), resolved through semanticTokenScopes."
  (let* ((ts (prologos-fam--slurp
              (prologos-fam--path "../../vscode-prologos/src/semanticTokens.ts")))
         (beg (or (string-match "const CAPTURE_MAP" ts)
                  (error "CAPTURE_MAP not found")))
         (end (or (string-match "export const LEGEND" ts beg)
                  (error "CAPTURE_MAP has no terminator")))
         (body (substring ts beg end))
         (pkg (prologos-fam--slurp
               (prologos-fam--path "../../vscode-prologos/package.json")))
         (scopes (let-alist (json-parse-string pkg :object-type 'alist)
                   (alist-get 'scopes
                              (aref (alist-get 'semanticTokenScopes .contributes) 0))))
         (out '()))
    ;; LINE-ORIENTED on purpose.  One multi-line regex over the whole body
    ;; backtracks catastrophically — it hung the gate on first run.  Each entry
    ;; occupies one line in the source, so a per-line match is both faster and
    ;; far easier to reason about.
    (dolist (line (split-string body "\n" t))
      (when (string-match
             "\\['\\([^']+\\)',[ \t]*\\['\\([^']+\\)',[ \t]*\\[\\([^]]*\\)\\]\\]\\]"
             line)
        (let* ((cap (match-string 1 line))
               (tok (match-string 2 line))
               (mods (match-string 3 line))
               (mod (and (string-match "'\\([^']+\\)'" mods)
                         (match-string 1 mods)))
               (key (if mod (concat tok "." mod) tok))
               (sc (or (alist-get (intern key) scopes)
                       (alist-get (intern tok) scopes))))
          ;; scopes values are vectors of strings; take the first.
          (push (cons cap (cond ((vectorp sc) (aref sc 0))
                                ((stringp sc) sc)
                                (t nil)))
                out))))
    (nreverse out)))

(defun prologos-fam--divergences ()
  "Deliberate `family' rows from known-gaps.tsv: alist of (CAPTURE . WHY)."
  (let ((p (prologos-fam--path "known-gaps.tsv")))
    (if (not (file-readable-p p)) '()
      (cl-loop for line in (split-string (prologos-fam--slurp p) "\n" t)
               unless (or (string-prefix-p "#" line) (string-blank-p line))
               when (string= (car (split-string line "\t")) "family")
               collect (let ((f (split-string line "\t")))
                         (cons (nth 1 f) (nth 2 f)))))))

;; ------------------------------------------------------------------
;; The gate
;; ------------------------------------------------------------------

(defun prologos-fam-check ()
  "Compare the two consumers' families capture by capture."
  (let* ((rows (prologos-fam--families))
         (em (prologos-fam--emacs-map))
         (vs (prologos-fam--vscode-map))
         (div (prologos-fam--divergences))
         (bad 0) (allowed 0) (checked 0) (unknown 0))
    (message "")
    (message "  %-24s %-16s %-16s %s" "CAPTURE" "EMACS" "VS CODE" "")
    (message "  %s" (make-string 74 ?-))
    (dolist (pair (sort (copy-sequence em)
                        (lambda (a b) (string< (car a) (car b)))))
      (let* ((cap (car pair))
             (face (cdr pair))
             (scope (alist-get cap vs nil nil #'string=)))
        ;; Only captures BOTH consumers map are this gate's business.
        (when scope
          (cl-incf checked)
          (let ((ef (prologos-fam--face-family face rows))
                (vf (prologos-fam--scope-family scope rows))
                (why (alist-get cap div nil nil #'string=)))
            (cond
             ((or (null ef) (null vf))
              (cl-incf unknown)
              (message "  %-24s %-16s %-16s  ?? UNCLASSIFIED"
                       cap (or ef (format "%s" face)) (or vf scope)))
             ((string= ef vf)
              (message "  %-24s %-16s %-16s  ok" cap ef vf))
             (why
              (cl-incf allowed)
              (message "  %-24s %-16s %-16s  ~ recorded divergence" cap ef vf))
             (t
              (cl-incf bad)
              (message "  %-24s %-16s %-16s  ** DIVERGES **" cap ef vf)))))))
    (message "  %s" (make-string 74 ?-))
    (message "  %d capture(s) mapped by both · %d diverge · %d recorded · %d unclassified"
             checked bad allowed unknown)
    (message "")
    (if (and (zerop bad) (zerop unknown))
        (progn
          (message "PASS — both consumers give every shared capture the same ROLE.")
          (message "  (says nothing about colour, nor about whether either mapping is right)")
          (kill-emacs 0))
      (when (> unknown 0)
        (message "  UNCLASSIFIED means families.tsv has no row covering that face or")
        (message "  scope.  Add one, or the gate is not actually checking it."))
      (when (> bad 0)
        (message "  A DIVERGENCE means the two consumers disagree about what the thing")
        (message "  IS.  Fix a mapping, or record it in known-gaps.tsv with consumer")
        (message "  `family' and a reason."))
      (kill-emacs 1))))

(provide 'check-families)

;;; check-families.el ends here
