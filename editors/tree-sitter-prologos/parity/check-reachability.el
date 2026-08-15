;;; check-reachability.el --- does every capture actually FIRE? -*- lexical-binding: t; -*-

;;; Commentary:

;; The third gate, added 2026-08-14 after the P2 census found `(comment)
;; @comment' almost never producing a node -- ~1% of the library's comment lines
;; -- while every existing check stayed green.
;;
;; The two we already had ask the wrong question for this defect:
;;
;;   check-vocabulary  — is the capture WRITTEN in the query, documented, mapped?
;;   check-parity      — do both consumers AGREE about what the query captures?
;;
;; Neither asks whether the grammar ever produces a node for it.  A rule can be
;; present, documented, mapped by every consumer, agreed upon by both — and
;; unreachable.  `@comment' was exactly that: correct rule, `extras' declared,
;; and the external scanner consuming comment lines before the parser could
;; tokenize them.  Both editors covered for it privately (Emacs via its syntax
;; table, VS Code via TextMate), so comparing the editors to each other could
;; never have revealed it.
;;
;; Two populations, deliberately reported apart:
;;
;;   CORPUS  — real code.  What our users' files actually exercise.
;;   FIXTURE — parity/fixture.prologos, written to exercise every capture.
;;
;; A capture that fires in NEITHER is a defect and fails the gate.  A capture
;; that fires only in the FIXTURE is merely a construct real code does not use
;; yet — reported, not failed.  Folding the fixture into the corpus would mask
;; the first case, which is the case that matters.
;;
;; ⚠ Runs the query through `prologos-ts-translate-query-predicates', like every
;; other consumer path.  Skipping it would evaluate `#match?' in the wrong
;; dialect and report `type.builtin' (and only it) as unreachable — a false
;; positive that looks exactly like a real finding.
;;
;; ⚠⚠ KNOW WHAT THIS GATE CANNOT SEE.  "Fires somewhere" is a FLOOR, not a
;; health check.  `@comment' passes it with 1455 hits corpus-wide while covering
;; ~1% of the comment lines in the library — the rule fires, just almost never.
;; A capture that is 99% broken reads here as healthy.  Where an independent
;; expected count exists, measure COVERAGE instead; `--coverage' does that for
;; comments, which is the one case where a cheap ground truth (`;'-lines) exists.

;;; Code:

(require 'treesit)
(require 'cl-lib)
(require 'prologos-ts-mode)

(defvar prologos-reach--dir
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "Directory of this file, captured at LOAD time.")

(defconst prologos-reach--corpus-dirs
  '("racket/prologos/lib" "racket/prologos/examples" "editors/emacs/test")
  "Corpus roots, relative to the repo root.  Deliberately EXCLUDES parity/.")

(defun prologos-reach--root ()
  (expand-file-name "../../../" prologos-reach--dir))

(defun prologos-reach--query ()
  (prologos-ts-translate-query-predicates
   (with-temp-buffer
     (insert-file-contents (expand-file-name "../queries/highlights.scm"
                                             prologos-reach--dir))
     (buffer-string))))

(defun prologos-reach--tally (files query table)
  "Add capture counts for FILES into TABLE."
  (dolist (f files)
    (ignore-errors
      (with-temp-buffer
        (insert-file-contents f)
        (treesit-parser-create 'prologos)
        (dolist (pair (treesit-query-capture (treesit-buffer-root-node) query))
          (let ((c (symbol-name (car pair))))
            (puthash c (1+ (gethash c table 0)) table)))))))

(defun prologos-reach--corpus-files ()
  (cl-loop for d in prologos-reach--corpus-dirs
           append (let ((dir (expand-file-name d (prologos-reach--root))))
                    (and (file-directory-p dir)
                         (cl-remove-if-not
                          (lambda (f)
                            (let ((b (file-name-nondirectory f)))
                              (and (not (string-prefix-p ".#" b))
                                   (file-regular-p f) (file-readable-p f))))
                          (directory-files-recursively dir "\\.prologos\\'"))))))

(defun prologos-reach-check ()
  "Report per-capture reachability.  Exit non-zero if any capture never fires."
  (unless (treesit-language-available-p 'prologos)
    (message "FATAL: grammar not installed — run ../install.sh") (kill-emacs 2))
  (let* ((query   (prologos-reach--query))
         (corpus  (prologos-reach--corpus-files))
         (fixture (list (expand-file-name "fixture.prologos" prologos-reach--dir)))
         (ct (make-hash-table :test 'equal))
         (ft (make-hash-table :test 'equal))
         (declared '()))
    ;; Captures the query DECLARES, from its text.
    (let ((s (with-temp-buffer
               (insert-file-contents
                (expand-file-name "../queries/highlights.scm" prologos-reach--dir))
               (buffer-string)))
          (i 0))
      (while (string-match "@\\([a-zA-Z][a-zA-Z0-9._]*\\)" s i)
        (cl-pushnew (match-string 1 s) declared :test #'string=)
        (setq i (match-end 0))))
    (setq declared (sort declared #'string<))
    (when (null declared) (error "parsed ZERO captures from highlights.scm"))
    (when (null corpus)   (error "found ZERO corpus files"))

    (prologos-reach--tally corpus  query ct)
    (prologos-reach--tally fixture query ft)

    (message "  corpus files: %d   captures declared: %d\n" (length corpus) (length declared))
    (message "  %-24s %10s %10s" "capture" "CORPUS" "FIXTURE")
    (message "  %s" (make-string 48 ?-))
    (let ((dead '()) (fixture-only '()))
      (dolist (c declared)
        (let ((cn (gethash c ct 0)) (fn (gethash c ft 0)))
          (message "  %-24s %10d %10d%s" c cn fn
                   (cond ((and (zerop cn) (zerop fn)) "   <-- NEVER FIRES")
                         ((zerop cn)                  "   <-- fixture only")
                         (t "")))
          (cond ((and (zerop cn) (zerop fn)) (push c dead))
                ((zerop cn) (push c fixture-only)))))
      (message "")
      (when fixture-only
        (message "  note: %d capture(s) fire only in the fixture — real code does not"
                 (length fixture-only))
        (message "        use those constructs yet.  Informational, not a failure.\n"))
      (if dead
          (let ((n (length dead)))
            (dolist (c (nreverse dead))
              (message "FAIL: @%s is DECLARED, documented and mapped — and never fires" c))
            (message "\n%d unreachable capture(s)" n)
            (kill-emacs 1))
        (message "PASS — every declared capture fires somewhere")
        (kill-emacs 0)))))


(defun prologos-reach-coverage ()
  "Report COMMENT coverage per corpus area: captures vs `;'-lines.

Separate from `prologos-reach-check' because it asks a different and stricter
question.  Reachability asks whether a capture EVER fires; coverage asks what
fraction of the occurrences it should match it actually does.  `@comment'
passes the first and fails the second, which is precisely the defect the P2
census found — and the reason \"fires somewhere\" is not a health check."
  (unless (treesit-language-available-p 'prologos)
    (message "FATAL: grammar not installed") (kill-emacs 2))
  (let ((root (prologos-reach--root)) (tc 0) (tl 0))
    (message "  %-26s %6s %8s %10s" "area" "caps" "; lines" "coverage")
    (message "  %s" (make-string 54 ?-))
    (dolist (spec '(("lib (real WS Prologos)" "racket/prologos/lib/prologos")
                    ("examples"               "racket/prologos/examples")
                    ("editors/emacs/test"     "editors/emacs/test")))
      (let ((files (ignore-errors
                     (directory-files-recursively
                      (expand-file-name (nth 1 spec) root) "\\.prologos\\'")))
            (c 0) (l 0))
        (dolist (f files)
          (ignore-errors
            (with-temp-buffer
              (insert-file-contents f)
              (treesit-parser-create 'prologos)
              (setq c (+ c (length (treesit-query-capture
                                    (treesit-buffer-root-node) "(comment) @comment"))))
              (goto-char (point-min))
              (while (re-search-forward "^[ \t]*;" nil t) (setq l (1+ l))))))
        (setq tc (+ tc c) tl (+ tl l))
        (message "  %-26s %6d %8d %9.0f%%" (nth 0 spec) c l
                 (if (> l 0) (* 100.0 (/ (float c) l)) 0.0))))
    (message "  %s" (make-string 54 ?-))
    (message "  %-26s %6d %8d %9.0f%%" "TOTAL" tc tl
             (if (> tl 0) (* 100.0 (/ (float tc) tl)) 0.0))
    (message "\n  Target is ~100%%. The gap is scanner.c consuming comment-only")
    (message "  lines while computing indentation (~:399), before the parser can")
    (message "  tokenize the `extras' comment the grammar declares.")))

(provide 'check-reachability)

;;; check-reachability.el ends here
