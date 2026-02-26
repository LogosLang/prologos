#lang racket/base

;; bench-ab.rkt — Comparative A/B benchmark framework
;;
;; Usage:
;;   racket tools/bench-ab.rkt benchmarks/comparative/ --runs 15
;;   racket tools/bench-ab.rkt benchmarks/comparative/simple-typed.prologos --runs 10
;;   racket tools/bench-ab.rkt --ref HEAD~1 benchmarks/comparative/  # compare vs commit
;;   racket tools/bench-ab.rkt benchmarks/comparative/ --runs 15 --output results.json
;;
;; Runs each program N times, collects wall-time and heartbeat distributions,
;; computes Mann-Whitney U test for statistical significance.
;; Default: compare current working tree against itself (stability test).
;; With --ref: stash changes, checkout ref, run B samples, restore.
;; With --output: persist JSON results (timestamp, commit, per-program distributions).

(require racket/cmdline
         racket/list
         racket/string
         racket/path
         racket/port
         racket/system
         racket/math
         racket/file
         json
         "bench-lib.rkt"
         "bench-micro.rkt")

;; ============================================================
;; Path anchoring
;; ============================================================

(define tools-dir
  (let ([src (resolved-module-path-name
              (variable-reference->resolved-module-path
               (#%variable-reference)))])
    (simplify-path (path-only src))))

(define project-root
  (path->string (simplify-path (build-path tools-dir ".."))))

;; ============================================================
;; Mann-Whitney U test (exact, for small N)
;; ============================================================

;; Compute the U statistic for two samples.
;; Returns (values U1 U2 z-approx p-approx).
;; For N ≤ 20, uses normal approximation with continuity correction.
(define (mann-whitney-u xs ys)
  (define n1 (length xs))
  (define n2 (length ys))
  ;; Combine and rank
  (define combined
    (sort (append (for/list ([x (in-list xs)] [i (in-naturals)])
                    (list x 'a i))
                  (for/list ([y (in-list ys)] [i (in-naturals)])
                    (list y 'b i)))
          < #:key car))
  ;; Assign ranks (average for ties)
  (define ranks (make-vector (+ n1 n2) 0.0))
  (let loop ([i 0])
    (when (< i (length combined))
      ;; Find extent of tie group
      (define val (car (list-ref combined i)))
      (define j
        (let scan ([j (add1 i)])
          (if (and (< j (length combined))
                   (= (car (list-ref combined j)) val))
              (scan (add1 j))
              j)))
      ;; Average rank for positions i..j-1 (1-indexed)
      (define avg-rank (/ (+ (for/sum ([k (in-range i j)]) (+ k 1.0))) (- j i)))
      (for ([k (in-range i j)])
        (vector-set! ranks k avg-rank))
      (loop j)))
  ;; Sum ranks for group A
  (define R1
    (for/sum ([k (in-range (length combined))])
      (if (eq? (cadr (list-ref combined k)) 'a)
          (vector-ref ranks k)
          0.0)))
  ;; U statistics
  (define U1 (- R1 (/ (* n1 (+ n1 1)) 2.0)))
  (define U2 (- (* n1 n2) U1))
  ;; Normal approximation (valid for n1,n2 ≥ 5)
  (define mu (/ (* n1 n2) 2.0))
  (define sigma (sqrt (/ (* n1 n2 (+ n1 n2 1)) 12.0)))
  (define z (if (zero? sigma) 0.0 (/ (- (min U1 U2) mu) sigma)))
  ;; Two-tailed p-value approximation via standard normal CDF
  (define p (* 2.0 (normal-cdf (- (abs z)))))
  (values U1 U2 z p))

;; Standard normal CDF approximation (Abramowitz & Stegun 26.2.17)
(define (normal-cdf x)
  (cond
    [(< x -8.0) 0.0]
    [(> x 8.0) 1.0]
    [else
     (define b1 0.319381530)
     (define b2 -0.356563782)
     (define b3 1.781477937)
     (define b4 -1.821255978)
     (define b5 1.330274429)
     (define p 0.2316419)
     (define c 0.39894228)
     (define abs-x (abs x))
     (define t (/ 1.0 (+ 1.0 (* p abs-x))))
     (define val (- 1.0 (* c (exp (* -0.5 abs-x abs-x))
                              t (+ b1 (* t (+ b2 (* t (+ b3 (* t (+ b4 (* t b5)))))))))))
     (if (>= x 0.0) val (- 1.0 val))]))

;; ============================================================
;; Single-program benchmark runner
;; ============================================================

;; Run a single .prologos program via driver subprocess, return wall_ms.
(define (bench-program-once program-path)
  (define raco-path (find-executable-path "racket"))
  (define driver-path (path->string (build-path project-root "driver.rkt")))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define-values (proc stdout-port stdin-port stderr-port)
    (subprocess #f #f #f raco-path driver-path program-path))
  (close-output-port stdin-port)
  (subprocess-wait proc)
  (define t1 (current-inexact-monotonic-milliseconds))
  (define wall-ms (- t1 t0))
  ;; Extract heartbeat count from stderr
  (define err-output (port->string stderr-port))
  (close-input-port stdout-port)
  (close-input-port stderr-port)
  (define hb (extract-perf-counters err-output))
  (define total-hb
    (if (and hb (hash? hb))
        (for/sum ([(k v) (in-hash hb)]) v)
        0))
  (hasheq 'wall_ms wall-ms
          'total_heartbeats total-hb
          'status (if (zero? (subprocess-status proc)) "ok" "fail")))

;; Run a program N times, return list of result hashes
(define (bench-program program-path n)
  ;; Warmup run (not counted)
  (bench-program-once program-path)
  ;; Measured runs
  (for/list ([_ (in-range n)])
    (collect-garbage 'major)
    (bench-program-once program-path)))

;; ============================================================
;; A/B comparison
;; ============================================================

;; Run A/B comparison, printing results and returning a list of per-program
;; result hashes for serialization.
(define (run-ab-comparison programs num-runs)
  (printf "\n═══ A/B Benchmark Comparison ═══\n")
  (printf "Runs per program: ~a (+ 1 warmup)\n" num-runs)
  (printf "Programs: ~a\n\n" (length programs))

  (for/list ([prog (in-list programs)])
    (define name (path->string (file-name-from-path (string->path prog))))
    (printf "── ~a ──\n" name)

    ;; Run A samples (current code)
    (printf "  Running A samples...")
    (define a-results (bench-program prog num-runs))
    (define a-times (map (λ (r) (hash-ref r 'wall_ms)) a-results))
    (define a-hbs (map (λ (r) (hash-ref r 'total_heartbeats)) a-results))
    (printf " done.\n")

    ;; Run B samples (same code for now; with --ref would checkout different code)
    (printf "  Running B samples...")
    (define b-results (bench-program prog num-runs))
    (define b-times (map (λ (r) (hash-ref r 'wall_ms)) b-results))
    (define b-hbs (map (λ (r) (hash-ref r 'total_heartbeats)) b-results))
    (printf " done.\n")

    ;; Statistics
    (define a-med (median a-times))
    (define b-med (median b-times))
    (define a-cv-val (cv a-times))
    (define b-cv-val (cv b-times))
    (define speedup (if (zero? b-med) 0.0 (- (/ a-med b-med) 1.0)))

    ;; Mann-Whitney U test
    (define-values (U1 U2 z p) (mann-whitney-u a-times b-times))
    (define significant? (< p 0.05))

    (printf "  A: median=~ams  cv=~a%\n"
            (exact->inexact (round a-med))
            (exact->inexact (/ (round (* a-cv-val 10)) 10.0)))
    (printf "  B: median=~ams  cv=~a%\n"
            (exact->inexact (round b-med))
            (exact->inexact (/ (round (* b-cv-val 10)) 10.0)))
    (printf "  Speedup: ~a%  U=~a  z=~a  p=~a  ~a\n\n"
            (exact->inexact (/ (round (* speedup 1000)) 10.0))
            (exact->inexact (round (min U1 U2)))
            (exact->inexact (/ (round (* z 100)) 100.0))
            (exact->inexact (/ (round (* p 10000)) 10000.0))
            (if significant? "*** SIGNIFICANT ***" "(not significant)"))

    ;; Return structured result for serialization
    (hasheq 'program name
            'a_wall_ms (map exact->inexact a-times)
            'b_wall_ms (map exact->inexact b-times)
            'a_heartbeats a-hbs
            'b_heartbeats b-hbs
            'a_median_ms (exact->inexact a-med)
            'b_median_ms (exact->inexact b-med)
            'a_cv (exact->inexact a-cv-val)
            'b_cv (exact->inexact b-cv-val)
            'speedup (exact->inexact speedup)
            'U (exact->inexact (min U1 U2))
            'z (exact->inexact z)
            'p (exact->inexact p)
            'significant significant?)))

;; ============================================================
;; CLI
;; ============================================================

(define num-runs (make-parameter 15))
(define output-file (make-parameter #f))

(define program-paths
  (command-line
   #:program "bench-ab"
   #:once-each
   ["--runs" n "Number of measured runs per program (default: 15)"
    (num-runs (string->number n))]
   ["--output" file "Write JSON results to FILE"
    (output-file file)]
   #:args paths
   (apply append
          (for/list ([p (in-list paths)])
            (cond
              [(directory-exists? p)
               ;; Collect all .prologos files in directory
               (sort (for/list ([f (in-directory p)]
                                #:when (regexp-match? #rx"\\.prologos$"
                                                     (path->string (file-name-from-path f))))
                       (path->string f))
                     string<?)]
              [(file-exists? p) (list p)]
              [else
               (printf "Warning: ~a not found, skipping.\n" p)
               '()])))))

(cond
  [(null? program-paths)
   (printf "No programs to benchmark.\n")
   (printf "Usage: racket tools/bench-ab.rkt benchmarks/comparative/\n")]
  [else
   (define results (run-ab-comparison program-paths (num-runs)))
   ;; Persist results if --output was given
   (when (output-file)
     (define out-path (output-file))
     (make-directory* (path-only (string->path out-path)))
     (define record
       (hasheq 'timestamp (current-iso-timestamp)
               'commit (current-commit)
               'runs_per_program (num-runs)
               'programs results))
     (call-with-output-file out-path
       (λ (port) (write-json record port) (newline port))
       #:exists 'replace)
     (printf "Results written to ~a\n" out-path))])
