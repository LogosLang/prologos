;;; check-corpus.el --- Measure tree-sitter grammar coverage over real code -*- lexical-binding: t; -*-

;;; Commentary:

;; Parses every `.prologos' file under the given directories with the
;; installed tree-sitter grammar and reports how much of it the grammar
;; actually understands.
;;
;; This exists because grammar quality is INVISIBLE without it.  A stale
;; grammar does not error: tree-sitter recovers, emits `ERROR' nodes, and
;; every consumer downstream (font-lock, folding, the surfer) silently
;; degrades.  Discovered 2026-08-14 with 2123 ERROR nodes across 73% of the
;; library -- five months after the grammar was last touched, and with no
;; symptom loud enough to have prompted a look.
;;
;; Usage:
;;   emacs -Q --batch -L ../../editors/emacs -l check-corpus.el -f prologos-ts-check-corpus [DIRS...]
;;
;; or via the wrapper:  ./check-corpus.sh [--max N] [DIRS...]
;;
;; Exit status is 1 when the error total exceeds `--max' (default: any error
;; at all fails), so this can gate a commit once the corpus is clean.

;;; Code:

(require 'treesit)
(require 'cl-lib)

(defvar prologos-ts-check--max nil
  "Maximum tolerated ERROR-node total; nil means zero.")

(defconst prologos-ts-check--default-dirs
  '("racket/prologos/lib" "racket/prologos/examples" "editors/emacs/test")
  "Corpus roots, relative to the repo root.")

(defvar prologos-ts-check--this-dir
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "Directory of this file, captured at LOAD time.
`load-file-name' is bound only while loading and is nil by the time the
entry point runs, so it has to be read here rather than there.")

(defun prologos-ts-check--repo-root ()
  "Repo root, derived from THIS FILE rather than from the cwd."
  (expand-file-name "../../" prologos-ts-check--this-dir))

(defun prologos-ts-check--scan-file (file)
  "Return (ERRORS MISSING LINES) for FILE.

The walk is ITERATIVE, with an explicit stack.  A recursive one blows
`max-lisp-eval-depth' on exactly the files this tool exists to find: bad
parses nest ERROR nodes hundreds deep, so the recursive version crashed
on the worst file in the corpus and reported nothing at all."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((errors 0) (missing 0))
      (if (not (treesit-language-available-p 'prologos))
          (list -1 -1 0)
        (treesit-parser-create 'prologos)
        (let ((stack (list (treesit-parser-root-node
                            (car (treesit-parser-list))))))
          (while stack
            (let ((node (pop stack)))
              (cond
               ((equal (treesit-node-type node) "ERROR") (cl-incf errors))
               ((treesit-node-check node 'missing) (cl-incf missing)))
              (dolist (c (treesit-node-children node)) (push c stack)))))
        (list errors missing (count-lines (point-min) (point-max)))))))

(defun prologos-ts-check-corpus ()
  "Scan the corpus and report grammar coverage.  Exit non-zero on failure."
  (let* ((args (cl-remove-if (lambda (a) (string-prefix-p "--" a))
                             command-line-args-left))
         (root (prologos-ts-check--repo-root))
         (dirs (or args
                   (mapcar (lambda (d) (expand-file-name d root))
                           prologos-ts-check--default-dirs)))
         (files (cl-loop for d in dirs
                         append (and (file-directory-p d)
                                     (directory-files-recursively d "\\.prologos\\'"))))
         ;; Emacs lock files (.#foo.prologos) are DANGLING SYMLINKS pointing at
         ;; "user@host.pid"; they match the glob and then fail to open.  Also
         ;; drop autosaves and anything unreadable, so an editor session open
         ;; on the corpus cannot break the measurement.
         (files (cl-remove-if-not
                 (lambda (f)
                   (let ((base (file-name-nondirectory f)))
                     (and (not (string-prefix-p ".#" base))
                          (not (string-prefix-p "#" base))
                          (file-regular-p f)
                          (file-readable-p f))))
                 files))
         (rows '()) (total 0) (total-missing 0) (clean 0) (lines 0))
    (unless (treesit-language-available-p 'prologos)
      (message "FATAL: tree-sitter grammar for prologos is not installed.")
      (message "       Run editors/tree-sitter-prologos/install.sh first.")
      (kill-emacs 2))
    (dolist (f files)
      (pcase-let ((`(,e ,m ,l) (prologos-ts-check--scan-file f)))
        (cl-incf total e) (cl-incf total-missing m) (cl-incf lines l)
        (if (and (zerop e) (zerop m)) (cl-incf clean)
          (push (list e m l (file-relative-name f root)) rows))))
    (setq rows (sort rows (lambda (a b) (> (car a) (car b)))))
    (message "")
    (message "  %-58s %7s %7s %7s" "FILE" "ERRORS" "MISSING" "LINES")
    (message "  %s" (make-string 82 ?-))
    (dolist (r (seq-take rows 25))
      (message "  %-58s %7d %7d %7d" (nth 3 r) (nth 0 r) (nth 1 r) (nth 2 r)))
    (when (> (length rows) 25)
      (message "  ... and %d more file(s) with errors" (- (length rows) 25)))
    (message "  %s" (make-string 82 ?-))
    (message "  files %d | clean %d (%.0f%%) | dirty %d | ERROR %d | MISSING %d | lines %d"
             (length files) clean
             (if (zerop (length files)) 0.0
               (* 100.0 (/ (float clean) (length files))))
             (length rows) total total-missing lines)
    (message "")
    (let ((budget (if prologos-ts-check--max
                      (string-to-number prologos-ts-check--max) 0)))
      (if (<= (+ total total-missing) budget)
          (progn (message "PASS (budget %d)" budget) (kill-emacs 0))
        (message "FAIL: %d error/missing node(s) exceeds budget %d"
                 (+ total total-missing) budget)
        (kill-emacs 1)))))

(provide 'check-corpus)

;;; check-corpus.el ends here
