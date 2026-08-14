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
    (let ((errors 0) (missing 0) (bytes 0) (worst 0))
      (if (not (treesit-language-available-p 'prologos))
          (list -1 -1 0 0 0 0)
        (treesit-parser-create 'prologos)
        (let ((stack (list (treesit-parser-root-node
                            (car (treesit-parser-list))))))
          (while stack
            (let ((node (pop stack)))
              (cond
               ((equal (treesit-node-type node) "ERROR")
                (cl-incf errors)
                ;; Count the SPAN, and do not descend: nested ERRORs are
                ;; inside this one and their bytes are already counted.
                (let ((span (- (treesit-node-end node)
                               (treesit-node-start node))))
                  (cl-incf bytes span)
                  (setq worst (max worst span))))
               (t
                (when (treesit-node-check node 'missing) (cl-incf missing))
                (dolist (c (treesit-node-children node)) (push c stack)))))))
        (list errors missing (count-lines (point-min) (point-max)) bytes
              worst (buffer-size))))))

(defun buffer-size-of-corpus (files)
  "Total byte size of FILES, for the unparsed-percentage denominator."
  (let ((n 0))
    (dolist (f files n)
      (cl-incf n (or (file-attribute-size (file-attributes f)) 0)))))

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
         (rows '()) (total 0) (total-missing 0) (clean 0) (lines 0) (total-bytes 0)
         (swallowed 0) (worst-frac 0.0))
    (unless (treesit-language-available-p 'prologos)
      (message "FATAL: tree-sitter grammar for prologos is not installed.")
      (message "       Run editors/tree-sitter-prologos/install.sh first.")
      (kill-emacs 2))
    (dolist (f files)
      (pcase-let ((`(,e ,m ,l ,b ,w ,sz) (prologos-ts-check--scan-file f)))
        (cl-incf total e) (cl-incf total-missing m) (cl-incf lines l)
        (cl-incf total-bytes b)
        (let ((frac (if (zerop sz) 0.0 (/ (float w) sz))))
          ;; A "swallow": ONE error node covering a fifth of the file.  That is
          ;; the failure that makes an editor unusable — font-lock and
          ;; navigation lose the whole region, not just the bad form.
          (when (>= frac 0.20) (cl-incf swallowed))
          (setq worst-frac (max worst-frac frac))
          (if (and (zerop e) (zerop m)) (cl-incf clean)
            (push (list e m l (file-relative-name f root) b w frac) rows)))))
    (setq rows (sort rows (lambda (a b) (> (nth 6 a) (nth 6 b)))))
    (message "")
    (message "  %-46s %8s %7s %9s %7s" "FILE" "WORST-B" "WORST%" "ERR-BYTE" "ERRORS")
    (message "  %s" (make-string 82 ?-))
    (dolist (r (seq-take rows 25))
      (message "  %-46s %8d %6.0f%% %9d %7d" (nth 3 r) (nth 5 r) (* 100.0 (nth 6 r)) (nth 4 r) (nth 0 r)))
    (when (> (length rows) 25)
      (message "  ... and %d more file(s) with errors" (- (length rows) 25)))
    (message "  %s" (make-string 82 ?-))
    (message "  files %d | clean %d (%.0f%%) | dirty %d | ERROR %d | MISSING %d | lines %d"
             (length files) clean
             (if (zerop (length files)) 0.0
               (* 100.0 (/ (float clean) (length files))))
             (length rows) total total-missing lines)
    ;; THE headline metric.  ERROR COUNT IS MISLEADING: a grammar fix that lets
    ;; a construct parse further replaces one swallowing mega-ERROR with several
    ;; precise small ones, so the count RISES while coverage improves.  Bytes
    ;; inside ERROR spans measure how much text the grammar fails to understand,
    ;; which is the thing we actually care about.  (Learned 2026-08-14: the
    ;; multi-clause defn fix moved count 8336 -> 8456 while being an improvement.)
    (message "  LOCALITY: %d file(s) SWALLOWED (one error >=20%% of the file); worst single error covers %.0f%% of its file"
             swallowed (* 100.0 worst-frac))
    (message "  ERROR-BYTES %d of %d (%.1f%% of the corpus unparsed)"
             total-bytes (buffer-size-of-corpus files)
             (if (zerop (buffer-size-of-corpus files)) 0.0
               (* 100.0 (/ (float total-bytes) (buffer-size-of-corpus files)))))
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
