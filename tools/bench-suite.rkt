#lang racket/base

;; bench-suite.rkt — Comprehensive benchmark sweep across multiple
;; algorithms, sizes, and program forms (unrolled vs iterative).
;;
;; Compared to pnet-bench.rkt (which times one program at a time), this
;; harness:
;;   1. Generates source files at multiple N for each algorithm
;;   2. Runs both UNROLLED (gen-fib.rkt) and ITERATIVE (gen-iter.rkt)
;;      forms where applicable — fib supports both, sum/factorial
;;      iterative-only.
;;   3. Times Racket reduction + native run + parses kernel JSON stats
;;   4. Prints a markdown table for easy reading + sharing
;;
;; Usage:
;;   racket tools/bench-suite.rkt
;;     default: fib unrolled+iterative at N=10,20,40,60,80,92;
;;              sum+factorial iterative at N=10,20,40,60,80,92.
;;
;;   racket tools/bench-suite.rkt --runs 3
;;     average over 3 runs per measurement.
;;
;;   racket tools/bench-suite.rkt --quick
;;     small-N only (10, 20) for fast smoke check.

(require racket/cmdline
         racket/system
         racket/port
         racket/list
         racket/runtime-path
         racket/file
         racket/format
         racket/string)

(define-runtime-path here ".")

(define runs (make-parameter 1))
(define quick? (make-parameter #f))

(command-line
 #:program "bench-suite"
 #:once-each
 [("--runs") n "Number of runs to average per measurement (default 1)"
  (runs (string->number n))]
 [("--quick") "Small-N sweep only (smoke test)" (quick? #t)])

;; ============================================================
;; Configuration
;; ============================================================

(define n-values
  (if (quick?)
      '(10 20)
      '(10 20 40 60 80 92)))

;; (algorithm form-symbol) where form-symbol ∈ '(unrolled iterative).
;; fib supports both unrolled (gen-fib.rkt) and iterative (gen-iter.rkt
;; in 3 encodings: fib = 3-scalar, pair-fib = pair-state, helpered-fib
;; = inlined helper). sum / factorial only iterative.
(define configs
  '((fib          unrolled)
    (fib          iterative)
    (pair-fib     iterative)
    (helpered-fib iterative)
    (sum          iterative)
    (factorial    iterative)
    (sumsq        iterative)
    (dual-acc     iterative)
    (pell         iterative)
    (pow2         iterative)))

;; ============================================================
;; Helpers
;; ============================================================

(define gen-fib-script  (build-path here "gen-fib.rkt"))
(define gen-iter-script (build-path here "gen-iter.rkt"))
(define pnet-compile-script (build-path here "pnet-compile.rkt"))
(define driver-path
  (build-path here ".." "racket" "prologos" "driver.rkt"))

(define (open-output-nowhere) (open-output-string))

(define (write-source-file algorithm form n out-path)
  (define-values (script args)
    (case form
      [(unrolled)
       (unless (eq? algorithm 'fib)
         (error 'bench-suite "unrolled form only available for fib (got ~a)" algorithm))
       (values gen-fib-script (list (number->string n)))]
      [(iterative)
       (values gen-iter-script
               (list "--algorithm" (symbol->string algorithm)
                     "--n" (number->string n)))]))
  (define racket-exe (find-executable-path "racket"))
  (define out-port (open-output-file out-path #:exists 'truncate))
  (parameterize ([current-output-port out-port]
                 [current-error-port (open-output-nowhere)])
    (apply system* racket-exe script args))
  (close-output-port out-port))

(define (time-racket-reduce src-path)
  ;; Run process-file as a subprocess (so each measurement is isolated
  ;; from the bench harness's shared module cache).
  (define racket-exe (find-executable-path "racket"))
  (define t0 (current-inexact-milliseconds))
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (system* racket-exe "-e"
             (format "(dynamic-require '(file ~v) #f) ((dynamic-require '(file ~v) 'process-file) ~v)"
                     (path->string driver-path)
                     (path->string driver-path)
                     src-path)))
  (- (current-inexact-milliseconds) t0))

(define (compile-with-stats src-path out-bin)
  (define racket-exe (find-executable-path "racket"))
  (define old-stats (getenv "PROLOGOS_STATS"))
  (putenv "PROLOGOS_STATS" "1")
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (system* racket-exe pnet-compile-script "--no-run"
             "-o" out-bin src-path))
  (putenv "PROLOGOS_STATS" (or old-stats "")))

(struct run-result (wall-ms stderr) #:transparent)

(define (time-native-run out-bin)
  (define abs-path (path->complete-path out-bin))
  (define stderr-bytes (open-output-bytes))
  (define t0 (current-inexact-milliseconds))
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port stderr-bytes])
    (system*/exit-code abs-path))
  (run-result (- (current-inexact-milliseconds) t0)
              (bytes->string/utf-8 (get-output-bytes stderr-bytes))))

(define (parse-stat key stderr)
  (define rx (regexp (format "\"~a\":([0-9]+)" (regexp-quote key))))
  (define m (regexp-match rx stderr))
  (and m (string->number (cadr m))))

;; ============================================================
;; Per-config measurement
;; ============================================================

(struct config-result
  (algorithm form n
   reduce-ms-avg native-run-ms-avg
   scheduler-ns rounds fires cells props max-worklist
   committed dropped)
  #:transparent)

(define (avg xs) (if (null? xs) 0 (/ (apply + xs) (length xs))))

(define (measure-config algorithm form n)
  (define src-path (make-temporary-file
                    (format "bench-~a-~a-~a-~~a.prologos" algorithm form n)))
  (write-source-file algorithm form n src-path)

  (define out-bin (make-temporary-file
                   (format "bench-~a-~a-~a-bin-~~a" algorithm form n)))
  (compile-with-stats src-path out-bin)

  (define reduce-ms-list
    (for/list ([_ (in-range (runs))])
      (time-racket-reduce src-path)))

  (define native-results
    (for/list ([_ (in-range (runs))])
      (time-native-run out-bin)))

  ;; Structural stats (rounds, fires, cells, props) are deterministic
  ;; across runs — pull from any of them. Scheduler ns IS noisy across
  ;; runs (clock_gettime jitter, OS scheduling), so average those.
  (define stderrs (map run-result-stderr native-results))
  (define ns-list
    (filter values (map (lambda (s) (parse-stat "run_ns" s)) stderrs)))
  (define ns-avg
    (if (null? ns-list) #f (/ (apply + ns-list) (length ns-list))))

  (define result
    (config-result
     algorithm form n
     (avg reduce-ms-list)
     (avg (map run-result-wall-ms native-results))
     ns-avg
     (parse-stat "rounds"        (last stderrs))
     (parse-stat "fires"         (last stderrs))
     (parse-stat "cells"         (last stderrs))
     (parse-stat "props"         (last stderrs))
     (parse-stat "max_worklist"  (last stderrs))
     (parse-stat "committed"     (last stderrs))
     (parse-stat "dropped"       (last stderrs))))

  (delete-file src-path)
  (delete-file out-bin)
  result)

;; ============================================================
;; Driver + table emission
;; ============================================================

(define (run-one algorithm form n)
  (printf "  ~a/~a N=~a... " algorithm form n)
  (flush-output)
  (define t0 (current-inexact-milliseconds))
  (define r (measure-config algorithm form n))
  (printf "(~ams elapsed)~n" (round (- (current-inexact-milliseconds) t0)))
  r)

(printf "Bench suite: ~a configs × ~a sizes × ~a runs~n"
        (length configs) (length n-values) (runs))
(printf "Sizes: ~a~n~n" n-values)

(define all-results
  (for*/list ([config (in-list configs)]
              [n (in-list n-values)])
    (define algorithm (car config))
    (define form (cadr config))
    (run-one algorithm form n)))

(define (or-? v) (or v "?"))
(define (round-ms x) (round x))
(define (μs ns) (if ns (real->decimal-string (/ ns 1000.0) 1) "?"))
(define (fmt-ns ns)
  (cond [(not ns) "?"]
        [(integer? ns) (number->string ns)]
        [else (number->string (inexact->exact (round ns)))]))
(define (fmt-ratio reduce-ms sched-ns)
  (cond [(and sched-ns (> sched-ns 0))
         (define x (/ (* reduce-ms 1000000) sched-ns))
         (cond [(>= x 1000) (format "~a,~ax"
                                    (quotient (inexact->exact (round x)) 1000)
                                    (~a (modulo (inexact->exact (round x)) 1000)
                                        #:min-width 3 #:pad-string "0" #:align 'right))]
               [else (format "~ax" (inexact->exact (round x)))])]
        [else "?"]))
(define (fmt-fire-ns total-ns fires)
  (cond [(and total-ns fires (> fires 0))
         (real->decimal-string (/ total-ns fires) 1)]
        [else "?"]))

;; ============================================================
;; Table 1: WALL-TIME COMPARISON — the headline view.
;; ============================================================

(printf "~n## Wall-time comparison: Racket interpreter vs native scheduler~n~n")
(printf "Each row: same Prologos source, two evaluation paths.~n")
(printf "  - Racket reduce ms: process-file (parser+elaborator+typecheck+reducer) in a~n")
(printf "    fresh subprocess per run. Includes ~~600ms of fixed startup overhead.~n")
(printf "  - Native scheduler μs: just the BSP propagator scheduler (run_to_quiescence).~n")
(printf "    Excludes binary startup. Apples-to-apples for the reduction work itself.~n")
(printf "  - ns/fire: scheduler ns ÷ propagator fires; the per-fire throughput.~n~n")
(printf "| algorithm | form | N | Racket ms | Native μs | Speedup | ns/fire | Rounds | Fires |~n")
(printf "|---|---|---|---|---|---|---|---|---|~n")
(for ([r (in-list all-results)])
  (define reduce-ms (config-result-reduce-ms-avg r))
  (define sched-ns  (config-result-scheduler-ns r))
  (define fires     (config-result-fires r))
  (printf "| ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a |~n"
          (config-result-algorithm r)
          (config-result-form r)
          (config-result-n r)
          (round-ms reduce-ms)
          (μs sched-ns)
          (fmt-ratio reduce-ms sched-ns)
          (fmt-fire-ns sched-ns fires)
          (or-? (config-result-rounds r))
          (or-? fires)))

;; ============================================================
;; Table 2: structural metrics — independent of timing noise.
;; ============================================================

(printf "~n## Structural metrics (deterministic across runs)~n~n")
(printf "| algorithm | form | N | Cells | Props | Rounds | Fires | Committed/Dropped writes |~n")
(printf "|---|---|---|---|---|---|---|---|~n")
(for ([r (in-list all-results)])
  (printf "| ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a/~a |~n"
          (config-result-algorithm r)
          (config-result-form r)
          (config-result-n r)
          (or-? (config-result-cells r))
          (or-? (config-result-props r))
          (or-? (config-result-rounds r))
          (or-? (config-result-fires r))
          (or-? (config-result-committed r))
          (or-? (config-result-dropped r))))

;; ============================================================
;; Table 3: unrolled vs iterative side-by-side for fib.
;; ============================================================

(printf "~n## Unrolled vs iterative form (fib only)~n~n")
(printf "Demonstrates the cell-budget tradeoff: unrolled scales with N,~n")
(printf "iterative is constant. Per-N scheduler ns figures show that for~n")
(printf "small N unrolled is faster (fewer rounds), but iterative wins at large~n")
(printf "N because of fewer total fires (BSP fan-in stale-fire pattern in unrolled).~n~n")
(printf "| N | u-cells | u-rounds | u-fires | u-ns | u-ms | i-cells | i-rounds | i-fires | i-ns | i-ms |~n")
(printf "|---|---|---|---|---|---|---|---|---|---|---|~n")
(for ([n (in-list n-values)])
  (define u (findf (lambda (r) (and (eq? (config-result-algorithm r) 'fib)
                                    (eq? (config-result-form r) 'unrolled)
                                    (= (config-result-n r) n)))
                   all-results))
  (define i (findf (lambda (r) (and (eq? (config-result-algorithm r) 'fib)
                                    (eq? (config-result-form r) 'iterative)
                                    (= (config-result-n r) n)))
                   all-results))
  (when (and u i)
    (printf "| ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a |~n"
            n
            (or-? (config-result-cells u))
            (or-? (config-result-rounds u))
            (or-? (config-result-fires u))
            (fmt-ns (config-result-scheduler-ns u))
            (round-ms (config-result-reduce-ms-avg u))
            (or-? (config-result-cells i))
            (or-? (config-result-rounds i))
            (or-? (config-result-fires i))
            (fmt-ns (config-result-scheduler-ns i))
            (round-ms (config-result-reduce-ms-avg i)))))

;; ============================================================
;; Table 4: per-N wall time for all iterative algorithms.
;; ============================================================

(printf "~n## Per-N wall time across iterative algorithms (Racket reduce ms)~n~n")
(printf "Shows how Racket reduce time scales per algorithm.~n~n")
(define iter-algs (remove-duplicates
                   (for/list ([r (in-list all-results)]
                              #:when (eq? (config-result-form r) 'iterative))
                     (config-result-algorithm r))))
(printf "| algorithm | ~a |~n" (string-join (map (lambda (n) (format "N=~a" n)) n-values) " | "))
(printf "|---~a|~n" (string-join (build-list (length n-values) (lambda (_) "|---")) ""))
(for ([alg (in-list iter-algs)])
  (define cells (for/list ([n (in-list n-values)])
                  (define r (findf (lambda (rr) (and (eq? (config-result-algorithm rr) alg)
                                                     (eq? (config-result-form rr) 'iterative)
                                                     (= (config-result-n rr) n)))
                                   all-results))
                  (if r (round-ms (config-result-reduce-ms-avg r)) "?")))
  (printf "| ~a | ~a |~n" alg (string-join (map (lambda (c) (format "~a" c)) cells) " | ")))

(printf "~n## Per-N scheduler μs across iterative algorithms~n~n")
(printf "| algorithm | ~a |~n" (string-join (map (lambda (n) (format "N=~a" n)) n-values) " | "))
(printf "|---~a|~n" (string-join (build-list (length n-values) (lambda (_) "|---")) ""))
(for ([alg (in-list iter-algs)])
  (define cells (for/list ([n (in-list n-values)])
                  (define r (findf (lambda (rr) (and (eq? (config-result-algorithm rr) alg)
                                                     (eq? (config-result-form rr) 'iterative)
                                                     (= (config-result-n rr) n)))
                                   all-results))
                  (if r (μs (config-result-scheduler-ns r)) "?")))
  (printf "| ~a | ~a |~n" alg (string-join cells " | ")))
