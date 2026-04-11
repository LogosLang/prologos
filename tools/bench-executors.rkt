#lang racket/base

;; bench-executors.rkt — BSP-LE Track 2B Phase 0c: A/B Executor Comparison
;;
;; Compares three BSP executor configurations on benchmark programs:
;;   1. Sequential (current default — sequential-fire-all)
;;   2. Futures (make-parallel-fire-all, threshold=4)
;;   3. Threads (make-parallel-thread-fire-all, per-core partitioning)
;;
;; Each benchmark runs N times under each executor. Reports median,
;; mean, CV, and pairwise Mann-Whitney U significance tests.
;;
;; Usage:
;;   racket tools/bench-executors.rkt                    — all benchmarks, 10 runs
;;   racket tools/bench-executors.rkt --runs 15          — 15 runs for more precision
;;   racket tools/bench-executors.rkt FILE.prologos      — single file

(require racket/list
         racket/string
         racket/format
         racket/math
         racket/path
         racket/port
         racket/file)

;; Import the actual infrastructure
(require (prefix-in p: "../racket/prologos/propagator.rkt")
         "../racket/prologos/driver.rkt"
         "../racket/prologos/stratified-eval.rkt"
         "../racket/prologos/namespace.rkt"
         "../racket/prologos/global-env.rkt"
         "../racket/prologos/metavar-store.rkt"
         "../racket/prologos/relations.rkt"
         "../racket/prologos/trait-resolution.rkt"
         "../racket/prologos/parse-reader.rkt"
         "../racket/prologos/macros.rkt"
         "../racket/prologos/errors.rkt")

;; ============================================================
;; Benchmark programs
;; ============================================================

(define default-benchmarks
  '("racket/prologos/benchmarks/comparative/simple-typed.prologos"
    "racket/prologos/benchmarks/comparative/nat-arithmetic.prologos"
    "racket/prologos/benchmarks/comparative/higher-order.prologos"
    "racket/prologos/benchmarks/comparative/solve-adversarial.prologos"
    "racket/prologos/benchmarks/comparative/atms-adversarial.prologos"
    "racket/prologos/benchmarks/comparative/parity-adversarial.prologos"
    "racket/prologos/benchmarks/comparative/constraints-adversarial.prologos"))

;; ============================================================
;; Executor configurations
;; ============================================================

(define executors
  (list
   (list "sequential" #f)
   (list "futures"    (p:make-parallel-fire-all))
   (list "threads"    (p:make-parallel-thread-fire-all))))

;; ============================================================
;; Runner
;; ============================================================

(define lib-dir
  (path->string (simplify-path (build-path "racket" "prologos" "lib"))))

(define (run-benchmark-once file-path executor-val)
  (collect-garbage 'major)
  (define start (current-inexact-monotonic-milliseconds))
  (parameterize ([p:current-parallel-executor executor-val]
                 [p:current-use-bsp-scheduler? #t]
                 [current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-relation-store (make-relation-store)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)]
                 [current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (install-module-loader!)
    (with-handlers ([exn:fail? (lambda (e) (void))])
      (process-file file-path)))
  (define end (current-inexact-monotonic-milliseconds))
  (- end start))

(define (run-benchmark file-path executor-name executor-val n-runs)
  ;; 1 warmup
  (run-benchmark-once file-path executor-val)
  ;; N measured runs
  (for/list ([i (in-range n-runs)])
    (run-benchmark-once file-path executor-val)))

;; ============================================================
;; Statistics
;; ============================================================

(define (median xs)
  (define sorted (sort xs <))
  (define n (length sorted))
  (if (odd? n)
      (list-ref sorted (quotient n 2))
      (/ (+ (list-ref sorted (sub1 (quotient n 2)))
            (list-ref sorted (quotient n 2)))
         2.0)))

(define (mean xs)
  (/ (apply + xs) (length xs)))

(define (stddev xs)
  (define m (mean xs))
  (define n (length xs))
  (sqrt (/ (apply + (map (lambda (x) (expt (- x m) 2)) xs))
           (max 1 (sub1 n)))))

(define (cv-pct xs)
  (* 100.0 (/ (stddev xs) (max 0.001 (mean xs)))))

;; Mann-Whitney U test (simplified)
(define (mann-whitney-u xs ys)
  (define all (append (map (lambda (x) (cons x 'a)) xs)
                      (map (lambda (y) (cons y 'b)) ys)))
  (define sorted (sort all < #:key car))
  ;; Assign ranks (no tie handling for simplicity)
  (define ranks
    (for/list ([item (in-list sorted)]
               [rank (in-naturals 1)])
      (cons (cdr item) rank)))
  (define r-a (apply + (map cdr (filter (lambda (r) (eq? (car r) 'a)) ranks))))
  (define n1 (length xs))
  (define n2 (length ys))
  (define u1 (- r-a (/ (* n1 (+ n1 1)) 2)))
  (define u2 (- (* n1 n2) u1))
  (define u (min u1 u2))
  (define mu (/ (* n1 n2) 2.0))
  (define sigma (sqrt (/ (* n1 n2 (+ n1 n2 1)) 12.0)))
  (define z (/ (- u mu) (max 0.001 sigma)))
  ;; Approximate p-value (two-tailed normal)
  (define p (* 2.0 (- 1.0 (normal-cdf (abs z)))))
  (values u z p))

(define (normal-cdf z)
  ;; Abramowitz & Stegun approximation
  (define b0 0.2316419)
  (define b1 0.319381530)
  (define b2 -0.356563782)
  (define b3 1.781477937)
  (define b4 -1.821255978)
  (define b5 1.330274429)
  (define az (abs z))
  (define t (/ 1.0 (+ 1.0 (* b0 az))))
  (define pdf (/ (exp (* -0.5 az az)) (sqrt (* 2.0 pi))))
  (define cdf (- 1.0 (* pdf (+ (* b1 t) (* b2 t t) (* b3 t t t)
                                (* b4 t t t t) (* b5 t t t t t)))))
  (if (>= z 0) cdf (- 1.0 cdf)))

;; ============================================================
;; Main
;; ============================================================

(define (main)
  (define args (vector->list (current-command-line-arguments)))

  ;; Parse --runs flag
  (define n-runs
    (let ([idx (index-of args "--runs")])
      (if (and idx (< (add1 idx) (length args)))
          (string->number (list-ref args (add1 idx)))
          10)))

  ;; Filter out flags to get file list
  (define files
    (let ([non-flags (filter (lambda (a) (not (string-prefix? a "--"))) args)])
      ;; Also remove the value after --runs
      (let ([idx (index-of args "--runs")])
        (define skip-val (if idx (list-ref args (add1 idx)) #f))
        (filter (lambda (a) (and (not (string-prefix? a "--"))
                                 (not (equal? a skip-val))))
                args))))

  (define benchmarks
    (if (null? files) default-benchmarks files))

  (printf "\n=== BSP-LE Track 2B Phase 0c: Executor Comparison ===\n")
  (printf "Runs per config: ~a | Executors: sequential, futures, threads\n\n" n-runs)

  (define all-results '())

  (for ([file (in-list benchmarks)])
    (define name (path->string (file-name-from-path file)))
    (printf "~a:\n" name)

    (define exec-results
      (for/list ([exec-pair (in-list executors)])
        (define exec-name (first exec-pair))
        (define exec-val (second exec-pair))
        (printf "  ~a ... " exec-name)
        (flush-output)
        (define times (run-benchmark file exec-name exec-val n-runs))
        (define med (median times))
        (define cv (cv-pct times))
        (printf "median=~ams CV=~a%~a\n"
                (~r med #:precision '(= 1))
                (~r cv #:precision '(= 1))
                (if (> cv 10.0) " ⚠️" ""))
        (list exec-name times med cv)))

    ;; Pairwise comparison: seq vs futures, seq vs threads
    (define seq-times (second (first exec-results)))
    (define fut-times (second (second exec-results)))
    (define thr-times (second (third exec-results)))

    (define-values (u-sf z-sf p-sf) (mann-whitney-u seq-times fut-times))
    (define-values (u-st z-st p-st) (mann-whitney-u seq-times thr-times))

    (define seq-med (third (first exec-results)))
    (define fut-med (third (second exec-results)))
    (define thr-med (third (third exec-results)))

    (printf "  seq→fut: ~a% (p=~a~a) | seq→thr: ~a% (p=~a~a)\n\n"
            (~r (* 100 (- (/ fut-med seq-med) 1.0)) #:precision '(= 1))
            (~r p-sf #:precision '(= 3))
            (if (< p-sf 0.05) " ***" "")
            (~r (* 100 (- (/ thr-med seq-med) 1.0)) #:precision '(= 1))
            (~r p-st #:precision '(= 3))
            (if (< p-st 0.05) " ***" ""))

    (set! all-results
          (cons (list name exec-results
                      (list p-sf p-st)
                      (list (/ fut-med seq-med) (/ thr-med seq-med)))
                all-results)))

  ;; Summary table
  (printf "\n=== Summary ===\n\n")
  (printf "| Program | Seq (ms) | Fut (ms) | Thr (ms) | Fut vs Seq | Thr vs Seq |\n")
  (printf "|---|---|---|---|---|---|\n")
  (for ([r (in-list (reverse all-results))])
    (define name (first r))
    (define execs (second r))
    (define ratios (fourth r))
    (printf "| ~a | ~a | ~a | ~a | ~a% | ~a% |\n"
            name
            (~r (third (first execs)) #:precision '(= 1))
            (~r (third (second execs)) #:precision '(= 1))
            (~r (third (third execs)) #:precision '(= 1))
            (~r (* 100 (- (first ratios) 1.0)) #:precision '(= 1))
            (~r (* 100 (- (second ratios) 1.0)) #:precision '(= 1)))))

(main)
