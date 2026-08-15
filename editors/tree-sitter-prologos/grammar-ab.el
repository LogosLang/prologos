;;; grammar-ab.el --- per-file A/B of the grammar over the corpus -*- lexical-binding: t; -*-

;;; Commentary:

;; Measures ERROR and MISSING node counts for EVERY corpus file, and compares
;; two measurements file by file.
;;
;; WHY THIS EXISTS.  `.claude/rules/tree-sitter-grammar.md` requires that a
;; grammar change be A/B'd PER FILE and never by netted totals, because a real
;; fix can improve one file while error-RECOVERY CHURN degrades another that does
;; not contain the construct at all.  The rule existed; the instrument did not.
;; So the A/B kept being improvised, and on 2026-08-15 the improvisations
;; produced three wrong answers in one sitting — all the same mistake, PARSING A
;; GATE'S DISPLAY OUTPUT AS DATA:
;;
;;   1. `tail`'s exit code read as the gate's, reporting success on a failed run.
;;   2. `check-corpus.sh` REFUSED (exit 3, stale artifact, nothing measured) and
;;      the differ reported "25 files improved to zero".
;;   3. `check-corpus.sh`'s per-file table is TRUNCATED to the top 25.  Absence
;;      from it was scored as zero errors, manufacturing a phantom regression.
;;
;; And the table's columns were never verified: it prints 997 for a file whose
;; direct ERROR count is 129.  Numbers were being differenced whose meaning had
;; not been established.
;;
;; This tool therefore measures the tree DIRECTLY and owns its own output
;; format.  It never scrapes another tool's display.
;;
;; It is the grammar-layer sibling of `racket/prologos/tools/corpus-ab.rkt`,
;; which exists for the same reason one layer up — hand-rolled A/B harnesses
;; giving wrong answers.
;;
;; Usage (via grammar-ab.sh):
;;   ./grammar-ab.sh save     # measure now, store as the baseline
;;   ./grammar-ab.sh diff     # measure now, compare per file
;;
;; `diff' exits 1 if ANY file got worse, so it can gate a grammar change.

;;; Code:

(require 'treesit)
(require 'cl-lib)

(defvar prologos-ab--mode nil "Either \"save\" or \"diff\".")
(defvar prologos-ab--baseline nil "Path to the baseline TSV.")

(defconst prologos-ab--here
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "Directory of this file, captured at LOAD time.")

(defconst prologos-ab--dirs
  '("racket/prologos/lib"
    "racket/prologos/examples"
    "editors/emacs/test"
    "editors/tree-sitter-prologos/parity")
  "Corpus roots, relative to the repo root.")

(defun prologos-ab--root ()
  (expand-file-name "../../" prologos-ab--here))

(defun prologos-ab--files ()
  (let ((root (prologos-ab--root)))
    (cl-remove-if-not
     (lambda (f)
       (let ((b (file-name-nondirectory f)))
         ;; Emacs lock files are dangling symlinks that match the glob and then
         ;; fail to open — an editor session open on the corpus must not break
         ;; the measurement.
         (and (not (string-prefix-p ".#" b))
              (not (string-prefix-p "#" b))
              (file-regular-p f)
              (file-readable-p f))))
     (cl-loop for d in prologos-ab--dirs
              append (let ((p (expand-file-name d root)))
                       (and (file-directory-p p)
                            (directory-files-recursively p "\\.prologos\\'")))))))

(defun prologos-ab--scan (file)
  "Return (ERRORS . MISSING) for FILE.
The walk is ITERATIVE: a bad parse nests ERROR nodes hundreds deep, and a
recursive walk blows `max-lisp-eval-depth' on exactly the files this tool
exists to find."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((e 0) (m 0))
      (treesit-parser-create 'prologos)
      (let ((stack (list (treesit-parser-root-node (car (treesit-parser-list))))))
        (while stack
          (let ((n (pop stack)))
            (cond ((equal (treesit-node-type n) "ERROR") (cl-incf e))
                  ((treesit-node-check n 'missing) (cl-incf m)))
            (dolist (c (treesit-node-children n)) (push c stack)))))
      (cons e m))))

(defun prologos-ab--measure ()
  "Measure every corpus file.  Return an alist of (RELPATH . (ERRORS . MISSING))."
  (unless (treesit-language-available-p 'prologos)
    (message "FATAL: the prologos grammar is not installed.  Run ./install.sh.")
    (kill-emacs 2))
  (let* ((root (prologos-ab--root))
         (files (prologos-ab--files)))
    (when (null files)
      (message "FATAL: measured ZERO files.  Refusing to call that a result.")
      (kill-emacs 2))
    (cl-loop for f in (sort files #'string<)
             collect (cons (file-relative-name f root) (prologos-ab--scan f)))))

(defun prologos-ab--write (rows path)
  (with-temp-file path
    (insert "# grammar-ab baseline — relpath\tERROR\tMISSING\n")
    (dolist (r rows)
      (insert (format "%s\t%d\t%d\n" (car r) (cadr r) (cddr r))))))

(defun prologos-ab--read (path)
  (unless (file-readable-p path)
    (message "FATAL: no baseline at %s.  Run `./grammar-ab.sh save' first." path)
    (kill-emacs 2))
  (let (rows)
    (dolist (line (split-string
                   (with-temp-buffer (insert-file-contents path) (buffer-string))
                   "\n" t))
      (unless (string-prefix-p "#" line)
        (let ((f (split-string line "\t")))
          (push (cons (nth 0 f) (cons (string-to-number (nth 1 f))
                                      (string-to-number (nth 2 f))))
                rows))))
    (nreverse rows)))

(defun prologos-ab-run ()
  "Entry point."
  (let* ((rows (prologos-ab--measure))
         (te (cl-reduce #'+ rows :key (lambda (r) (cadr r)) :initial-value 0))
         (tm (cl-reduce #'+ rows :key (lambda (r) (cddr r)) :initial-value 0)))
    (cond
     ((string= prologos-ab--mode "save")
      (prologos-ab--write rows prologos-ab--baseline)
      (message "")
      (message "  baseline saved: %d files · ERROR %d · MISSING %d" (length rows) te tm)
      (message "  -> %s" prologos-ab--baseline)
      (message "")
      (kill-emacs 0))
     (t
      (let* ((base (prologos-ab--read prologos-ab--baseline))
             (be (cl-reduce #'+ base :key (lambda (r) (cadr r)) :initial-value 0))
             (bm (cl-reduce #'+ base :key (lambda (r) (cddr r)) :initial-value 0))
             (worse '()) (better '()) (gone '()) (new '()))
        (dolist (r rows)
          (let ((b (assoc (car r) base)))
            (cond
             ((null b) (push (car r) new))
             ((or (> (cadr r) (cadr b)) (> (cddr r) (cddr b)))
              (push (list (car r) (cdr b) (cdr r)) worse))
             ((or (< (cadr r) (cadr b)) (< (cddr r) (cddr b)))
              (push (list (car r) (cdr b) (cdr r)) better)))))
        (dolist (b base)
          (unless (assoc (car b) rows) (push (car b) gone)))
        (message "")
        (message "  TOTALS   ERROR %d -> %d      MISSING %d -> %d" be te bm tm)
        (when (> tm bm)
          (message "")
          (message "  ⚠ MISSING ROSE.  That is the STRONGER defect signal — a MISSING")
          (message "    node means a rule matched and then could not be satisfied,")
          (message "    i.e. a rule that is WRONG rather than absent.  Do not net it")
          (message "    off against an ERROR drop."))
        (message "")
        (dolist (w (sort worse (lambda (a b) (string< (car a) (car b)))))
          (message "  WORSE   %-52s E%d/M%d -> E%d/M%d"
                   (car w) (car (nth 1 w)) (cdr (nth 1 w))
                   (car (nth 2 w)) (cdr (nth 2 w))))
        (dolist (g (sort better (lambda (a b) (string< (car a) (car b)))))
          (message "  better  %-52s E%d/M%d -> E%d/M%d"
                   (car g) (car (nth 1 g)) (cdr (nth 1 g))
                   (car (nth 2 g)) (cdr (nth 2 g))))
        (dolist (f new)  (message "  NEW FILE %s (not in baseline)" f))
        (dolist (f gone) (message "  GONE     %s (in baseline, not measured)" f))
        (message "")
        (message "  %d file(s) better · %d WORSE · %d unchanged"
                 (length better) (length worse)
                 (- (length rows) (length better) (length worse)))
        (message "")
        (if worse
            (progn
              (message "FAIL — a grammar change that makes ANY file worse needs a reason.")
              (message "  Netted totals hide this: error-recovery churn can degrade a")
              (message "  file that does not contain the construct you changed.")
              (kill-emacs 1))
          (message "PASS — no file regressed.")
          (message "  (says nothing about whether the change is CORRECT, only that it")
          (message "   cost no file anything.)")
          (kill-emacs 0)))))))

(provide 'grammar-ab)

;;; grammar-ab.el ends here
