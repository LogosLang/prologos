#lang racket/base

;;;
;;; lint-memo-hash.rkt — equal-based hashes near memo/cache context
;;;
;;; Purpose: static guard for pipeline.md § "New Memo / Cache Keyed on an
;;; AST Node". Racket's equal-hash-code is DEPTH-BOUNDED (~17 levels), so
;;; an equal-based (make-hash) memo keyed on expr trees collapses deep-
;;; term families into a handful of buckets and degenerates into O(N³)
;;; linear scans running full structural equal? — the memo costs vastly
;;; more than the work it saves (GitHub #58: 647,773x vs hasheq at N=512,
;;; hidden behind a green suite and a misleading counter). eq? keying is
;;; SOUND for expr memos (no expr struct is #:mutable), so `make-hasheq`
;;; is the default answer.
;;;
;;; Detection: line-scan (comments intentionally count — "memoization"
;;; usually lives in a comment) for make-hash / make-weak-hash sites
;;; whose surrounding +-4-line window mentions memo/cache/seen. Each finding is keyed by file + nearest enclosing
;;; define name (line numbers drift). Baselined findings should each have
;;; been audited: fine when keys are NOT expr trees (symbols, strings,
;;; small fixed-shape keys); a real hazard when they are.
;;;
;;; Usage:
;;;   racket tools/lint-memo-hash.rkt              # report, exit 0
;;;   racket tools/lint-memo-hash.rkt --strict     # exit 1 on NEW findings
;;;   racket tools/lint-memo-hash.rkt --save-baseline
;;;   racket tools/lint-memo-hash.rkt FILE.rkt ... # scan specific files
;;;

(require racket/cmdline
         racket/file
         racket/list
         racket/path
         racket/string)

(define strict-mode? (make-parameter #f))
(define save-baseline? (make-parameter #f))

(define this-file (path->string (simplify-path (syntax-source #'here))))
(define tools-dir (path-only this-file))
(define project-root (simplify-path (build-path tools-dir 'up)))
(define baseline-path (build-path tools-dir "memo-hash-baseline.txt"))

;; `$` alternative: `(make-hash` with its argument on the NEXT line ends the
;; line right after "hash" — without it that layout evades the scan entirely.
(define hash-site-rx #px"\\(make-(weak-)?hash([\\s)]|$)")
(define context-rx #px"(?i:memo|cache|seen)")
;; ±4 lines: a typical comment block + blank line + define spans 3-4 lines;
;; ±2 missed that shape. Measured tree-wide cost of 2→4: exactly one extra
;; finding, already covered by an existing baseline key.
(define context-window 4)
(define define-name-rx #px"\\(define(?:-values)?\\s+\\(?\\s*([a-zA-Z][a-zA-Z0-9!?*/<>+=:._-]*)")

;; ============================================================
;; Scan
;; ============================================================

;; Returns (listof (list rel-path line-num define-name line-text)).
(define (scan-file path)
  (define rel (path->string (find-relative-path project-root (simplify-path path))))
  (define lines (string-split (file->string path) "\n" #:trim? #f))
  (define vec (list->vector lines))
  (define n (vector-length vec))
  ;; nearest preceding define name for stable keying
  (define (enclosing-define i)
    (let loop ([j i])
      (cond
        [(< j 0) "top-level"]
        [(regexp-match define-name-rx (vector-ref vec j)) => cadr]
        [else (loop (sub1 j))])))
  (for/list ([line (in-list lines)]
             [i (in-naturals)]
             #:when (regexp-match? hash-site-rx line)
             #:when (for/or ([j (in-range (max 0 (- i context-window))
                                          (min n (+ i context-window 1)))])
                      (regexp-match? context-rx (vector-ref vec j))))
    (list rel (add1 i) (enclosing-define i) (string-trim line))))

;; ============================================================
;; Baseline
;; ============================================================

(define (finding-key f)
  (format "~a::~a" (car f) (caddr f)))

(define (read-baseline)
  (cond
    [(file-exists? baseline-path)
     (for/hash ([line (in-list (string-split (file->string baseline-path) "\n"))]
                #:when (and (not (string=? (string-trim line) ""))
                            (not (regexp-match? #px"^\\s*#" line))))
       (values (string-trim line) #t))]
    [else (hash)]))

(define (write-baseline findings)
  (define keys (sort (remove-duplicates (map finding-key findings)) string<?))
  (with-output-to-file baseline-path #:exists 'replace
    (lambda ()
      (displayln "# memo-hash-baseline.txt")
      (displayln "# Accepted equal-based-hash-near-memo findings as of last baseline save")
      (displayln "# (key: file::enclosing-define). Each entry should have been audited:")
      (displayln "# fine when keys are not expr trees; an O(N^3) hazard when they are")
      (displayln "# (pipeline.md § New Memo / Cache Keyed on an AST Node; GitHub #58).")
      (displayln "# Regenerate with: racket tools/lint-memo-hash.rkt --save-baseline")
      (displayln "")
      (for ([k (in-list keys)]) (displayln k)))))

;; ============================================================
;; Main
;; ============================================================

(define (production-files)
  (for/list ([f (in-directory project-root)]
             #:when (and (regexp-match? #rx"\\.rkt$" (path->string f))
                         (not (regexp-match? #rx"/(tests|tools|benchmarks|compiled|examples)/"
                                             (path->string f)))))
    f))

(define (main)
  (define explicit-files
    (command-line
     #:program "lint-memo-hash"
     #:once-each
     ["--strict" "Exit non-zero if NEW findings appear (not in baseline)"
      (strict-mode? #t)]
     ["--save-baseline" "Regenerate the baseline from current findings"
      (save-baseline? #t)]
     #:args files
     files))

  (define targets
    (if (pair? explicit-files)
        (map (lambda (f) (simplify-path (path->complete-path f))) explicit-files)
        (production-files)))

  (define findings (append-map scan-file targets))
  (define baseline (read-baseline))

  (when (save-baseline?)
    (write-baseline findings)
    (printf "Baseline saved: ~a findings recorded.\n"
            (length (remove-duplicates (map finding-key findings))))
    (exit 0))

  (define new-findings
    (filter (lambda (f) (not (hash-ref baseline (finding-key f) #f))) findings))

  (printf "memo-hash check (~a files): ~a findings (baselined: ~a, NEW: ~a)\n"
          (length targets) (length findings)
          (- (length findings) (length new-findings)) (length new-findings))

  (when (pair? new-findings)
    (printf "\n⚠ NEW equal-based hashes near memo/cache context:\n")
    (for ([f (in-list (sort new-findings string<? #:key finding-key))])
      (printf "  ~a:~a (in ~a): ~a\n" (car f) (cadr f) (caddr f) (cadddr f)))
    (printf "\nIf the keys are expr trees, use make-hasheq: equal-hash-code is depth-\n")
    (printf "bounded, so an equal-based memo on deep terms degenerates to O(N^3) —\n")
    (printf "and eq? keying is sound (no expr struct is #:mutable). If the keys are\n")
    (printf "not expr trees, audit and baseline the site.\n")
    (printf "See .claude/rules/pipeline.md § New Memo / Cache Keyed on an AST Node.\n"))

  (if (and (strict-mode?) (pair? new-findings))
      (exit 1)
      (exit 0)))

(main)
