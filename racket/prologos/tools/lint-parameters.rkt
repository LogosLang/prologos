#lang racket/base

;;;
;;; lint-parameters.rkt — Classify `make-parameter` sites for test isolation
;;;
;;; Purpose: tactical near-term protection (BSP-LE 2B addendum A3-static-lint)
;;; against the longitudinal pattern 7 (two-context boundary bugs — 6+ PIRs).
;;; New `make-parameter` definitions have repeatedly been added to the codebase
;;; without updating test-support.rkt's parameterize blocks, causing silent
;;; test leakage across the shared-process batch worker.
;;;
;;; Architectural direction: PM Track 12 (Module Loading on Network) migrates
;;; state to cells, which isolates by construction. This lint is the safety
;;; net WHILE PM 12 is pending. Obsoletes itself when cells replace parameters.
;;;
;;; Classification:
;;;   - private        : make-parameter defined but NOT exported → cannot leak
;;;   - test-registered: exported AND referenced in test-support.rkt parameterize
;;;   - unclassified   : exported but NOT in test-support.rkt → potential leak
;;;
;;; Exit code: 0 always (warning-only; never blocks push). Run with --strict
;;; to exit non-zero when unclassified parameters are found (for manual audit).
;;;
;;; Usage:
;;;   racket tools/lint-parameters.rkt              # report + exit 0
;;;   racket tools/lint-parameters.rkt --strict     # report + exit 1 if unclassified
;;;   racket tools/lint-parameters.rkt --verbose    # also list private + test-registered
;;;

(require racket/cmdline
         racket/file
         racket/path
         racket/string
         racket/list)

;; ============================================================
;; Configuration
;; ============================================================

(define strict-mode? (make-parameter #f))
(define verbose-mode? (make-parameter #f))
(define save-baseline? (make-parameter #f))

;; Anchor from script's own location: tools/ → prologos/
(define this-file (path->string (simplify-path (syntax-source #'here))))
(define tools-dir (path-only this-file))
(define project-root (simplify-path (build-path tools-dir 'up)))

(define test-support-path
  (build-path project-root "tests" "test-support.rkt"))

;; Baseline: text file listing currently-accepted unclassified parameters
;; (one name per line). Tracked in git. New unclassified additions NOT in
;; this list are flagged. Shrinks over time as parameters migrate to cells
;; (PM Track 12) or get added to test-support.rkt parameterize blocks.
(define baseline-path
  (build-path tools-dir "parameter-lint-baseline.txt"))

(define (read-baseline)
  (cond
    [(file-exists? baseline-path)
     (define lines (string-split (file->string baseline-path) "\n"))
     (for/hash ([line (in-list lines)]
                #:when (and (not (string=? line ""))
                            (not (regexp-match? #px"^\\s*#" line))))  ;; skip comments
       (values (string-trim line) #t))]
    [else (hash)]))

(define (write-baseline unclassified)
  (define names (sort (map car unclassified) string<?))
  (with-output-to-file baseline-path #:exists 'replace
    (lambda ()
      (displayln "# parameter-lint-baseline.txt")
      (displayln "# Accepted unclassified parameters as of last baseline save.")
      (displayln "# New additions (unclassified AND not in this list) are flagged.")
      (displayln "# Shrinks over time as parameters migrate to cells (PM Track 12)")
      (displayln "# or are added to tests/test-support.rkt parameterize blocks.")
      (displayln "# Regenerate with: racket tools/lint-parameters.rkt --save-baseline")
      (displayln "")
      (for ([n (in-list names)]) (displayln n)))))

;; ============================================================
;; Source scanning
;; ============================================================

;; Scan a .rkt file for (define NAME (make-parameter ...)) sites.
;; Returns (listof (list name line-number)).
(define (find-parameter-defs file-path)
  (define content (file->string file-path))
  (define lines (string-split content "\n" #:trim? #f))
  (for/list ([line (in-list lines)]
             [line-num (in-naturals 1)]
             #:when (regexp-match?
                     #px"\\(define\\s+[a-zA-Z][a-zA-Z0-9!?*/<>+=:-]*\\s+\\(make-parameter"
                     line))
    (define match
      (regexp-match #px"\\(define\\s+([a-zA-Z][a-zA-Z0-9!?*/<>+=:-]*)\\s+\\(make-parameter"
                    line))
    (list (cadr match) line-num)))

;; Read file and return list of exported names from (provide ...) forms.
;; Simple heuristic: collect all identifier-shaped words inside provide blocks.
;; Handles multi-line provide, struct-out wrappers.
(define (find-exported-names file-path)
  (define content (file->string file-path))
  ;; Find all (provide ...) blocks — very loose match, scan for balanced parens
  (define names (make-hash))
  (let loop ([pos 0])
    (define idx (regexp-match-positions #px"\\(provide[\\s\\(]" content pos))
    (when idx
      (define start (cdar idx))  ;; position after "(provide "
      ;; Scan forward matching parens until we close the outer provide
      (define depth 1)
      (define word-start #f)
      (let inner ([i start])
        (cond
          [(>= i (string-length content)) (void)]
          [(zero? depth) (void)]
          [else
           (define ch (string-ref content i))
           (cond
             [(char=? ch #\()
              (set! depth (add1 depth))
              (when word-start
                (hash-set! names (substring content word-start i) #t)
                (set! word-start #f))
              (inner (add1 i))]
             [(char=? ch #\))
              (set! depth (sub1 depth))
              (when word-start
                (hash-set! names (substring content word-start i) #t)
                (set! word-start #f))
              (inner (add1 i))]
             [(or (char-whitespace? ch))
              (when word-start
                (hash-set! names (substring content word-start i) #t)
                (set! word-start #f))
              (inner (add1 i))]
             [else
              (when (not word-start) (set! word-start i))
              (inner (add1 i))])]))
      (loop (+ start 1))))
  (hash-keys names))

;; ============================================================
;; Test-support scanning
;; ============================================================

;; Extract parameter names that appear in parameterize blocks.
;; Simple heuristic: match `[current-X ...]` inside the file.
(define (read-test-registered-parameters)
  (define content (file->string test-support-path))
  (define matches (regexp-match* #px"\\[(current-[a-zA-Z0-9!?*/<>+=:-]*)\\s" content))
  ;; Strip the "[" prefix and trailing space
  (for/hash ([m (in-list matches)])
    (define name
      (car (regexp-match #px"current-[a-zA-Z0-9!?*/<>+=:-]*" m)))
    (values name #t)))

;; ============================================================
;; Main
;; ============================================================

(define (main)
  (command-line
   #:program "lint-parameters"
   #:once-each
   ["--strict" "Exit non-zero if NEW unclassified parameters are found (regressions)"
    (strict-mode? #t)]
   ["--verbose" "List private + test-registered parameters too"
    (verbose-mode? #t)]
   ["--save-baseline" "Regenerate the baseline file from current unclassified set"
    (save-baseline? #t)])

  (define registered-params (read-test-registered-parameters))
  (define baseline (read-baseline))

  ;; Collect all .rkt files under project-root (excluding tests/ and tools/)
  (define source-files
    (for/list ([f (in-directory project-root)]
               #:when (and (regexp-match? #rx"\\.rkt$" (path->string f))
                           (not (regexp-match? #rx"/tests/" (path->string f)))
                           (not (regexp-match? #rx"/tools/" (path->string f)))
                           (not (regexp-match? #rx"/compiled/" (path->string f)))
                           (not (regexp-match? #rx"/benchmarks/" (path->string f)))))
      f))

  (define private-count 0)
  (define test-registered-count 0)
  (define unclassified '())
  (define all-exported '())

  (for ([f (in-list source-files)])
    (define rel-path (path->string (find-relative-path project-root f)))
    (define defs (find-parameter-defs f))
    (when (pair? defs)
      (define exported (find-exported-names f))
      (define exported-set (for/hash ([n (in-list exported)]) (values n #t)))
      (for ([d (in-list defs)])
        (define name (car d))
        (define line (cadr d))
        (cond
          [(not (hash-ref exported-set name #f))
           (set! private-count (add1 private-count))]
          [(hash-ref registered-params name #f)
           (set! test-registered-count (add1 test-registered-count))
           (set! all-exported (cons (list name rel-path line 'test-registered) all-exported))]
          [else
           (set! unclassified (cons (list name rel-path line) unclassified))
           (set! all-exported (cons (list name rel-path line 'unclassified) all-exported))]))))

  (define unclassified-count (length unclassified))
  (define total (+ private-count test-registered-count unclassified-count))

  ;; Split unclassified by baseline membership
  (define new-unclassified
    (filter (lambda (e) (not (hash-ref baseline (car e) #f))) unclassified))
  (define baselined-count (- unclassified-count (length new-unclassified)))

  (cond
    [(save-baseline?)
     (write-baseline unclassified)
     (printf "Baseline saved: ~a unclassified parameters recorded.\n" unclassified-count)
     (printf "File: ~a\n" (path->string baseline-path))
     (exit 0)])

  ;; Report
  (printf "Parameter classification (~a total):\n" total)
  (printf "  private (not exported, cannot leak): ~a\n" private-count)
  (printf "  test-registered (in test-support.rkt parameterize): ~a\n" test-registered-count)
  (printf "  unclassified: ~a (baselined: ~a, NEW: ~a)\n"
          unclassified-count baselined-count (length new-unclassified))

  (when (verbose-mode?)
    (printf "\nExported parameters:\n")
    (for ([entry (in-list (sort all-exported string<? #:key (lambda (e) (symbol->string (string->symbol (car e))))))])
      (printf "  [~a] ~a (~a:~a)\n"
              (list-ref entry 3) (car entry) (cadr entry) (caddr entry))))

  (when (pair? new-unclassified)
    (printf "\n⚠ NEW unclassified parameters (not in baseline):\n")
    (for ([entry (in-list (sort new-unclassified string<? #:key car))])
      (printf "  ~a (~a:~a)\n" (car entry) (cadr entry) (caddr entry)))
    (printf "\nResolution options:\n")
    (printf "  1. Add to tests/test-support.rkt parameterize blocks (test-registered)\n")
    (printf "  2. Migrate to a cell (PM Track 12 agenda)\n")
    (printf "  3. Keep private (don't export) if module-local\n")
    (printf "  4. Update baseline: racket tools/lint-parameters.rkt --save-baseline\n"))

  (cond
    [(and (strict-mode?) (pair? new-unclassified))
     (exit 1)]
    [else
     (exit 0)]))

(main)
