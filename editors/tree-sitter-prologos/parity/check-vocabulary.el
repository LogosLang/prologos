;;; check-vocabulary.el --- EHP capture-vocabulary completeness gate -*- lexical-binding: t; -*-

;;; Commentary:

;; Asserts the D2 contract (ruled 2026-08-14, option E) in BOTH directions:
;;
;;   →  every capture `highlights.scm' emits is in queries/captures.md,
;;      and resolves in every consumer's mapping
;;   ←  every mapping entry is emitted, OR is a proper dotted-prefix ancestor
;;      of something emitted (the ROOTS POLICY)
;;
;; The reverse direction is the one that was never tested and where the mess
;; actually was: nine speculative entries had accumulated in the VS Code map
;; since its first commit, five of them contradicted by rulings taken later.
;; Forward-only completeness would have reported all of that as healthy.
;;
;; The roots policy is enforced rather than described because a root and a
;; speculative leaf look identical in a diff. `constant' is a root of
;; `constant.builtin' and is kept; `function.call' was a leaf whose root already
;; produced an identical token, and was removed.
;;
;; No new dependency: Emacs is already required by check-corpus.sh and
;; check-parity.sh. The VS Code map is read out of the TypeScript source, since
;; importing it would need a build step.
;;
;; Usage:  ./check-vocabulary.sh

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defvar prologos-vocab--dir
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "Directory of this file, captured at LOAD time.")

(defun prologos-vocab--path (rel)
  (expand-file-name rel prologos-vocab--dir))

(defun prologos-vocab--slurp (path)
  (unless (file-readable-p path) (error "cannot read %s" path))
  (with-temp-buffer (insert-file-contents path) (buffer-string)))

(defun prologos-vocab--emitted ()
  "Captures `highlights.scm' actually emits."
  (let ((s (prologos-vocab--slurp (prologos-vocab--path "../queries/highlights.scm")))
        (out '()) (i 0))
    (while (string-match "@\\([a-zA-Z][a-zA-Z0-9._]*\\)" s i)
      (push (match-string 1 s) out)
      (setq i (match-end 0)))
    (delete-dups (nreverse out))))

(defun prologos-vocab--vocabulary ()
  "Capture names documented in captures.md, from the `| `name` |' table."
  (let ((s (prologos-vocab--slurp (prologos-vocab--path "../queries/captures.md")))
        (out '()) (i 0))
    (while (string-match "^| `\\([a-zA-Z][a-zA-Z0-9._]*\\)` |" s i)
      (push (match-string 1 s) out)
      (setq i (match-end 0)))
    (nreverse out)))

(defun prologos-vocab--emacs-map ()
  "Capture names mapped by prologos-ts-mode."
  (require 'prologos-ts-mode)
  (mapcar #'car (symbol-value 'prologos-ts--capture-faces)))

(defun prologos-vocab--vscode-map ()
  "Capture names mapped by src/semanticTokens.ts, read from source."
  (let* ((s (prologos-vocab--slurp
             (prologos-vocab--path "../../vscode-prologos/src/semanticTokens.ts")))
         (beg (or (string-match "const CAPTURE_MAP" s)
                  (error "CAPTURE_MAP not found in semanticTokens.ts")))
         (end (or (string-match "^\\]);" s beg)
                  (error "CAPTURE_MAP has no terminator")))
         (blk (substring s beg end))
         (out '()) (i 0))
    (while (string-match "^[ \t]*\\['\\([^']+\\)'" blk i)
      (push (match-string 1 blk) out)
      (setq i (match-end 0)))
    (nreverse out)))

(defun prologos-vocab--known-gaps ()
  "Alist of (CONSUMER . CAPTURE) deliberate exceptions."
  (let ((p (prologos-vocab--path "known-gaps.tsv")))
    (if (not (file-readable-p p)) '()
      (cl-loop for line in (split-string (prologos-vocab--slurp p) "\n" t)
               unless (or (string-prefix-p "#" line) (string-blank-p line))
               collect (let ((f (split-string line "\t")))
                         (cons (nth 0 f) (nth 1 f)))))))

(defun prologos-vocab--resolves-p (map name)
  "Non-nil if NAME resolves in MAP under the dotted-prefix fallback."
  (let ((parts (split-string name "\\.")))
    (cl-loop while parts
             thereis (member (string-join parts ".") map)
             do (setq parts (butlast parts)))))

(defun prologos-vocab--root-of-emitted-p (emitted name)
  "Non-nil if NAME is a PROPER dotted-prefix ancestor of something emitted."
  (cl-some (lambda (e) (and (not (string= e name))
                            (string-prefix-p (concat name ".") e)))
           emitted))

(defun prologos-vocab-check ()
  "Run the contract.  Exit non-zero on any violation."
  (let* ((emitted (prologos-vocab--emitted))
         (vocab   (prologos-vocab--vocabulary))
         (maps    (list (cons "emacs"  (prologos-vocab--emacs-map))
                        (cons "vscode" (prologos-vocab--vscode-map))))
         (gaps    (prologos-vocab--known-gaps))
         (fails   '()))

    ;; Vacuity guards.  Each of these parsers could silently return nil and
    ;; make every assertion below trivially true.
    (dolist (probe (list (cons "emitted" emitted) (cons "vocabulary" vocab)))
      (when (null (cdr probe))
        (error "parsed ZERO %s entries — the checker is broken, not the data"
               (car probe))))
    (dolist (m maps)
      (when (null (cdr m))
        (error "parsed ZERO entries from the %s mapping" (car m))))

    (message "  emitted by highlights.scm : %d" (length emitted))
    (message "  documented in captures.md : %d" (length vocab))
    (dolist (m maps) (message "  mapped by %-16s: %d" (car m) (length (cdr m))))
    (message "")

    ;; --- STRICT VOCABULARY: documented == emitted, exactly ---
    (dolist (c (cl-set-difference emitted vocab :test #'string=))
      (push (format "emitted but NOT documented in captures.md: @%s" c) fails))
    (dolist (c (cl-set-difference vocab emitted :test #'string=))
      (push (format "documented but never emitted (vocabulary is STRICT): %s" c) fails))

    ;; --- DIRECTION 1: every emitted capture resolves in every mapping ---
    (dolist (m maps)
      (dolist (c emitted)
        (unless (or (prologos-vocab--resolves-p (cdr m) c)
                    (member (cons (car m) c) gaps))
          (push (format "%s does not map @%s (and it is not a known gap)"
                        (car m) c)
                fails))))

    ;; --- DIRECTION 2 + ROOTS POLICY ---
    (dolist (m maps)
      (dolist (e (cdr m))
        (unless (or (member e emitted)
                    (prologos-vocab--root-of-emitted-p emitted e))
          (push (format "%s maps '%s', which is neither emitted nor a root of anything emitted"
                        (car m) e)
                fails))))

    (dolist (g gaps)
      (message "  known gap: %s does not map @%s" (car g) (cdr g)))
    (when gaps (message ""))

    (if fails
        ;; Count BEFORE reversing: `nreverse' is destructive, so `fails' would
        ;; afterwards point at the last cons and report 1 no matter how many
        ;; violations there were.  Caught by a power check that printed two
        ;; FAIL lines above "1 violation(s)".
        (let ((n (length fails)))
          (dolist (f (nreverse fails)) (message "FAIL: %s" f))
          (message "\n%d violation(s)" n)
          (kill-emacs 1))
      (message "PASS — vocabulary is strict, both directions hold, roots policy respected")
      (kill-emacs 0))))

(provide 'check-vocabulary)

;;; check-vocabulary.el ends here
