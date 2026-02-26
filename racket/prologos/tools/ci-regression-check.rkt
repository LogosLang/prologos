#lang racket/base

;;;
;;; ci-regression-check.rkt — Benchmark regression detection for CI
;;;
;;; Runs the comparative benchmark suite, compares wall times against
;;; the stored baseline, and exits non-zero if any program regresses
;;; beyond the threshold (default: 15%).
;;;
;;; Usage:
;;;   racket tools/ci-regression-check.rkt [--threshold PCT]
;;;
;;; Phase 7d of the type inference refactoring.
;;;

(require racket/cmdline
         racket/path
         racket/port
         racket/string
         racket/list
         racket/format
         json)

;; ============================================================
;; Configuration
;; ============================================================

(define tools-dir
  (let ([src (syntax-source #'here)])
    (simplify-path (path-only src))))

(define project-root
  (path->string (simplify-path (build-path tools-dir ".."))))

(define benchmark-dir
  (path->string (build-path project-root "benchmarks" "comparative")))

(define baseline-file
  (path->string (build-path project-root "data" "benchmarks" "baseline-comparative-a.json")))

;; ============================================================
;; Benchmark runner (simple — runs each program N times via driver)
;; ============================================================

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
  (close-input-port stdout-port)
  (close-input-port stderr-port)
  wall-ms)

(define (bench-program program-path n)
  ;; Warmup run
  (bench-program-once program-path)
  ;; Measured runs
  (for/list ([_ (in-range n)])
    (collect-garbage 'major)
    (bench-program-once program-path)))

(define (median lst)
  (define sorted (sort lst <))
  (define len (length sorted))
  (if (odd? len)
      (list-ref sorted (quotient len 2))
      (/ (+ (list-ref sorted (- (quotient len 2) 1))
            (list-ref sorted (quotient len 2)))
         2.0)))

;; Format a number with 1 decimal place.
(define (format-pct n)
  (real->decimal-string (exact->inexact n) 1))

;; ============================================================
;; Main
;; ============================================================

(define regression-threshold (make-parameter 15.0))
(define num-runs (make-parameter 3))

(command-line
 #:program "ci-regression-check"
 #:once-each
 [("--threshold") pct "Regression threshold percentage (default: 15)"
  (regression-threshold (string->number pct))]
 [("--runs") n "Number of runs per program (default: 3)"
  (num-runs (string->number n))]
 #:args () (void))

;; 1. Load baseline
(unless (file-exists? baseline-file)
  (eprintf "ERROR: No baseline file found at ~a\n" baseline-file)
  (eprintf "Run: racket tools/bench-ab.rkt --runs 5 --output ~a benchmarks/comparative/\n"
           baseline-file)
  (exit 1))

(define baseline
  (call-with-input-file baseline-file
    (lambda (in) (read-json in))))

(define baseline-medians
  (for/hash ([prog (in-list (hash-ref baseline 'programs))])
    (values (hash-ref prog 'program)
            (hash-ref prog 'a_median_ms))))

;; 2. Discover benchmark programs
(define programs
  (sort
   (for/list ([f (in-list (directory-list benchmark-dir))]
              #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
     (path->string (build-path benchmark-dir f)))
   string<?))

(when (null? programs)
  (eprintf "ERROR: No .prologos files found in ~a\n" benchmark-dir)
  (exit 1))

;; 3. Run benchmarks
(printf "Regression check: ~a programs, ~a runs each (threshold: ~a%)\n\n"
        (length programs) (num-runs) (regression-threshold))

(define regressions '())

(for ([prog (in-list programs)])
  (define name (path->string (file-name-from-path prog)))
  (define times (bench-program prog (num-runs)))
  (define current-median (median times))
  (define baseline-median (hash-ref baseline-medians name #f))

  (cond
    [(not baseline-median)
     (printf "  ~a: ~ams (no baseline — skipped)\n" name (round current-median))]
    [else
     (define change-pct (* 100.0 (/ (- current-median baseline-median) baseline-median)))
     (define regressed? (> change-pct (regression-threshold)))
     (printf "  ~a: ~ams (baseline: ~ams, change: ~a~a%)~a\n"
             name
             (round current-median)
             (round baseline-median)
             (if (>= change-pct 0) "+" "")
             (format-pct change-pct)
             (if regressed? " ** REGRESSION **" ""))
     (when regressed?
       (set! regressions (cons (list name current-median baseline-median change-pct)
                               regressions)))]))

;; 4. Report
(newline)
(cond
  [(null? regressions)
   (printf "OK: No regressions detected (threshold: ~a%)\n" (regression-threshold))
   (exit 0)]
  [else
   (printf "REGRESSION DETECTED: ~a program(s) exceeded ~a% threshold:\n"
           (length regressions) (regression-threshold))
   (for ([r (in-list (reverse regressions))])
     (define-values (name current base pct) (apply values r))
     (printf "  ~a: ~ams → ~ams (+~a%)\n"
             name (round base) (round current) (format-pct pct)))
   (exit 1)])
