#lang racket/base

;; bench-micro.rkt — Micro-benchmark harness with statistical analysis
;;
;; Provides a `bench` macro for precise function-level benchmarks:
;; warmup runs, multi-sample collection with GC between samples,
;; statistical analysis including CI, outlier detection, and stability gates.
;;
;; Used by benchmarks/micro/*.rkt files.

(require racket/list
         racket/math
         json)

(provide
 ;; Core benchmark macro + impl
 bench
 bench-impl

 ;; Result struct
 (struct-out bench-result)

 ;; Statistics (exported for use by bench-ab.rkt in Phase G)
 mean
 median
 stddev
 iqr
 cv
 confidence-interval-95
 detect-outliers
 validate-benchmark-stability

 ;; Output
 print-bench-result
 print-bench-summary
 bench-result->hasheq)

;; ============================================================
;; Statistics
;; ============================================================

(define (mean xs)
  (if (null? xs) 0.0
      (/ (apply + xs) (length xs))))

(define (median xs)
  (define sorted (sort xs <))
  (define n (length sorted))
  (cond
    [(zero? n) 0.0]
    [(odd? n) (list-ref sorted (quotient n 2))]
    [else
     (define mid (quotient n 2))
     (/ (+ (list-ref sorted (sub1 mid)) (list-ref sorted mid)) 2.0)]))

(define (stddev xs)
  (define n (length xs))
  (if (<= n 1) 0.0
      (let* ([m (mean xs)]
             [sq-diffs (map (λ (x) (expt (- x m) 2)) xs)])
        (sqrt (/ (apply + sq-diffs) (sub1 n))))))  ;; sample stddev (n-1)

;; Interquartile range
(define (iqr xs)
  (define sorted (sort xs <))
  (define n (length sorted))
  (if (< n 4) 0.0
      (let* ([q1-idx (quotient n 4)]
             [q3-idx (* 3 (quotient n 4))]
             [q1 (list-ref sorted q1-idx)]
             [q3 (list-ref sorted q3-idx)])
        (- q3 q1))))

;; Coefficient of variation (%)
(define (cv xs)
  (define m (mean xs))
  (if (zero? m) 0.0
      (* 100.0 (/ (stddev xs) (abs m)))))

;; ============================================================
;; T-distribution critical values for 95% CI (two-tailed, α=0.05)
;; df = n-1. Precomputed for common sample sizes.
;; ============================================================

(define t-critical-table
  (hasheq 1  12.706  2  4.303  3  3.182  4  2.776
          5  2.571   6  2.447  7  2.365  8  2.306
          9  2.262  10  2.228 11  2.201 12  2.179
         13  2.160  14  2.145 15  2.131 16  2.120
         17  2.110  18  2.101 19  2.093 20  2.086
         25  2.060  29  2.045 30  2.042 40  2.021
         50  2.009  60  2.000 80  1.990 100 1.984
         120 1.980 1000 1.962))

(define (t-critical df)
  (cond
    [(hash-ref t-critical-table df #f) => values]
    [else
     ;; Interpolate: find closest lower/upper keys
     (define keys (sort (hash-keys t-critical-table) <))
     (define lower (for/last ([k (in-list keys)] #:when (<= k df)) k))
     (define upper (for/first ([k (in-list keys)] #:when (>= k df)) k))
     (cond
       [(not lower) (hash-ref t-critical-table (car keys))]
       [(not upper) (hash-ref t-critical-table (last keys))]
       [(= lower upper) (hash-ref t-critical-table lower)]
       [else
        ;; Linear interpolation
        (define t-lo (hash-ref t-critical-table lower))
        (define t-hi (hash-ref t-critical-table upper))
        (+ t-lo (* (- t-hi t-lo) (/ (- df lower) (- upper lower))))])]))

;; Returns (cons lo hi) — 95% confidence interval for the mean
(define (confidence-interval-95 xs)
  (define n (length xs))
  (if (<= n 1) (cons 0.0 0.0)
      (let* ([m (mean xs)]
             [s (stddev xs)]
             [t (t-critical (sub1 n))]
             [margin (* t (/ s (sqrt n)))])
        (cons (- m margin) (+ m margin)))))

;; ============================================================
;; Outlier detection (Tukey fences)
;; ============================================================

;; Returns list of outlier values
(define (detect-outliers xs)
  (define sorted (sort xs <))
  (define n (length sorted))
  (if (< n 4) '()
      (let* ([q1 (list-ref sorted (quotient n 4))]
             [q3 (list-ref sorted (* 3 (quotient n 4)))]
             [iqr-val (- q3 q1)]
             [lo-fence (- q1 (* 1.5 iqr-val))]
             [hi-fence (+ q3 (* 1.5 iqr-val))])
        (filter (λ (x) (or (< x lo-fence) (> x hi-fence))) xs))))

;; ============================================================
;; Stability gate
;; ============================================================

;; Returns #t if CV is within acceptable range (default 10%)
(define (validate-benchmark-stability xs #:max-cv [max-cv 10.0])
  (<= (cv xs) max-cv))

;; ============================================================
;; Benchmark result
;; ============================================================

(struct bench-result (name samples stats) #:transparent)

(define (make-stats samples)
  (hasheq 'mean_ms     (exact->inexact (mean samples))
          'median_ms   (exact->inexact (median samples))
          'stddev_ms   (exact->inexact (stddev samples))
          'cv_pct      (exact->inexact (cv samples))
          'iqr_ms      (exact->inexact (iqr samples))
          'ci95_lo_ms  (exact->inexact (car (confidence-interval-95 samples)))
          'ci95_hi_ms  (exact->inexact (cdr (confidence-interval-95 samples)))
          'n           (length samples)
          'outliers    (length (detect-outliers samples))
          'stable      (validate-benchmark-stability samples)))

;; ============================================================
;; Core bench macro
;; ============================================================

;; (bench name #:warmup W #:samples N body ...)
;; Runs body W warmup times (discarded), then N sample times with GC between.
;; Returns a bench-result struct.
;; (bench name body ...) — run body with default 3 warmup, 15 samples.
;; For custom warmup/samples, call bench-impl directly:
;;   (bench-impl name warmup samples (λ () body ...))
(define-syntax-rule (bench name body ...)
  (bench-impl name 3 15 (λ () body ...)))

(define (bench-impl name warmup-count sample-count thunk)
  ;; Warmup
  (for ([_ (in-range warmup-count)])
    (thunk))
  ;; Collect samples
  (define samples
    (for/list ([_ (in-range sample-count)])
      (collect-garbage 'major)
      (define t0 (current-inexact-monotonic-milliseconds))
      (thunk)
      (- (current-inexact-monotonic-milliseconds) t0)))
  (bench-result name samples (make-stats samples)))

;; ============================================================
;; Output
;; ============================================================

(define (print-bench-result br)
  (define s (bench-result-stats br))
  (define stable? (hash-ref s 'stable))
  (printf "~a~a\n"
          (pad-str (bench-result-name br) 40)
          (if stable? "" " [UNSTABLE]"))
  (printf "  median ~ams  mean ~ams  stddev ~ams  CV ~a%  (n=~a, ~a outliers)\n"
          (fmt-ms (hash-ref s 'median_ms))
          (fmt-ms (hash-ref s 'mean_ms))
          (fmt-ms (hash-ref s 'stddev_ms))
          (real->decimal-string (hash-ref s 'cv_pct) 1)
          (hash-ref s 'n)
          (hash-ref s 'outliers))
  (printf "  95% CI [~a, ~a]ms\n"
          (fmt-ms (hash-ref s 'ci95_lo_ms))
          (fmt-ms (hash-ref s 'ci95_hi_ms))))

(define (print-bench-summary results)
  (printf "\n=== Micro-Benchmark Summary ===\n\n")
  (for ([br (in-list results)])
    (print-bench-result br)
    (newline))
  (define unstable (filter (λ (br) (not (hash-ref (bench-result-stats br) 'stable))) results))
  (when (not (null? unstable))
    (printf "WARNING: ~a benchmark(s) have CV > 10%:\n" (length unstable))
    (for ([br (in-list unstable)])
      (printf "  - ~a (CV=~a%)\n"
              (bench-result-name br)
              (real->decimal-string (hash-ref (bench-result-stats br) 'cv_pct) 1)))))

(define (bench-result->hasheq br)
  (hasheq 'name (bench-result-name br)
          'samples (bench-result-samples br)
          'stats (bench-result-stats br)))

;; ============================================================
;; Formatting helpers
;; ============================================================

(define (pad-str val min-width [align 'left] [pad-char #\space])
  (define s (format "~a" val))
  (define padding (max 0 (- min-width (string-length s))))
  (cond
    [(zero? padding) s]
    [(eq? align 'right) (string-append (make-string padding pad-char) s)]
    [else (string-append s (make-string padding pad-char))]))

(define (fmt-ms v)
  (real->decimal-string v 2))
