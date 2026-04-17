#lang racket/base

;;;
;;; parity-test.rkt — BSP-LE Track 2B Phase 0a: Strategy Parity Baseline
;;;
;;; Runs each solver-exercising test file under both :depth-first and :atms
;;; strategies via current-solver-strategy-override. Reports pass/fail per
;;; file per strategy, and categorizes failures.
;;;
;;; Usage:
;;;   racket tools/parity-test.rkt           — run all solver test files
;;;   racket tools/parity-test.rkt FILE ...  — run specific files only
;;;

(require racket/system
         racket/string
         racket/port
         racket/path
         racket/file
         racket/format
         racket/list)

;; ============================================================
;; Test file list: files that exercise defr/solve
;; ============================================================

;; Core solver test files (Phase T-b: updated categorization)
;; Category 1: Full pipeline (defr + solve via run-prologos-string/process-file)
;; Category 2: Direct API (stratified-solve-goal, solve-goal, solve-goal-propagator)
;; Category 3: Infrastructure (WF engine, solver config — control group)
(define solver-test-files
  '(;; Category 1: Full pipeline
    "tests/test-relational-e2e.rkt"
    "tests/test-stratified-eval.rkt"
    "tests/test-bound-args-01.rkt"
    ;; Category 2: Direct API
    "tests/test-relations-runtime.rkt"
    "tests/test-propagator-solver.rkt"
    "tests/test-multiclause-debug.rkt"
    "tests/test-explain-provenance-01.rkt"
    "tests/test-search-heuristics-01.rkt"
    ;; Category 3: WF + infrastructure (control group — should be strategy-independent)
    "tests/test-wf-engine-01.rkt"
    "tests/test-wf-benchmark-01.rkt"
    "tests/test-wf-comparison-01.rkt"
    "tests/test-wf-errors-01.rkt"
    "tests/test-wf-literature-01.rkt"
    "tests/test-wf-tabling-01.rkt"
    "tests/test-solver-config.rkt"))

;; ============================================================
;; Runner
;; ============================================================

(define racket-path "/Applications/Racket v9.0/bin/racket")
(define base-dir "racket/prologos")

;; Run a test file with a given strategy override.
;; Returns (values exit-code stdout stderr)
(define (run-test-with-strategy file strategy)
  (define abs-test (path->string (simplify-path (build-path base-dir file))))
  (define abs-strat (path->string (simplify-path (build-path base-dir "stratified-eval.rkt"))))
  ;; Use -e to parameterize the override, then dynamic-require the test
  (define expr
    (format "(require \"~a\") (parameterize ([current-solver-strategy-override '~a]) (dynamic-require \"~a\" #f))"
            abs-strat strategy abs-test))
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define ok?
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr])
      (system* racket-path "-e" expr)))
  (values (if ok? 0 1)
          (get-output-string stdout)
          (get-output-string stderr)))

;; ============================================================
;; Main
;; ============================================================

(define (main)
  (define args (vector->list (current-command-line-arguments)))
  (define files
    (if (null? args)
        solver-test-files
        args))

  (printf "\n=== BSP-LE Track 2B Phase 0a: Strategy Parity Baseline ===\n\n")
  (printf "Running ~a test files under both :depth-first and :atms\n\n" (length files))

  (define results '()) ; list of (file dfs-ok? atms-ok? atms-stderr)

  (for ([file (in-list files)])
    (printf "~a ... " file)
    (flush-output)

    ;; DFS run (baseline — should always pass)
    (define-values (dfs-exit dfs-out dfs-err)
      (run-test-with-strategy file 'depth-first))
    (define dfs-ok? (zero? dfs-exit))

    ;; ATMS run (parity test)
    (define-values (atms-exit atms-out atms-err)
      (run-test-with-strategy file 'atms))
    (define atms-ok? (zero? atms-exit))

    (cond
      [(and dfs-ok? atms-ok?)
       (printf "BOTH PASS\n")]
      [(and dfs-ok? (not atms-ok?))
       (printf "ATMS FAIL\n")]
      [(and (not dfs-ok?) atms-ok?)
       (printf "DFS FAIL (unexpected)\n")]
      [else
       (printf "BOTH FAIL\n")])

    (set! results (cons (list file dfs-ok? atms-ok? atms-err) results)))

  ;; Summary
  (define results* (reverse results))
  (define total (length results*))
  (define both-pass (count (lambda (r) (and (second r) (third r))) results*))
  (define atms-fail (count (lambda (r) (and (second r) (not (third r)))) results*))
  (define dfs-fail (count (lambda (r) (and (not (second r)) (third r))) results*))
  (define both-fail (count (lambda (r) (and (not (second r)) (not (third r)))) results*))

  (printf "\n=== Summary ===\n")
  (printf "Total files:     ~a\n" total)
  (printf "Both pass:       ~a\n" both-pass)
  (printf "ATMS fail only:  ~a  ← parity gaps to investigate\n" atms-fail)
  (printf "DFS fail only:   ~a  ← unexpected\n" dfs-fail)
  (printf "Both fail:       ~a  ← pre-existing issues\n" both-fail)

  ;; Detail: ATMS failures
  (when (> atms-fail 0)
    (printf "\n=== ATMS Failures (Parity Gaps) ===\n\n")
    (for ([r (in-list results*)])
      (when (and (second r) (not (third r)))
        (define err (fourth r))
        (define snippet
          (let ([lines (string-split err "\n")])
            (string-join (take lines (min 10 (length lines))) "\n")))
        (printf "--- ~a ---\n~a\n\n" (first r) snippet))))

  ;; Write machine-readable results
  (define out-path "racket/prologos/data/benchmarks/parity-baseline.txt")
  (call-with-output-file out-path
    (lambda (out)
      (fprintf out "# BSP-LE Track 2B Phase 0a: Parity Baseline\n")
      (fprintf out "# file | dfs | atms\n")
      (for ([r (in-list results*)])
        (fprintf out "~a | ~a | ~a\n"
                 (first r)
                 (if (second r) "PASS" "FAIL")
                 (if (third r) "PASS" "FAIL"))))
    #:exists 'truncate)
  (printf "\nResults written to ~a\n" out-path))

(main)
