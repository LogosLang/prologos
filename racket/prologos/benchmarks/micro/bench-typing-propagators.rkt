#lang racket/base

;; bench-typing-propagators.rkt — Micro-benchmarks for Track 4B typing propagators
;;
;; Stresses: attribute-map cell, propagator installation, quiescence,
;; P2 fire-once overhead, P3 cleanup, meta-feedback, constraint narrowing.
;;
;; Uses infer-on-network directly (bypasses elaboration) for precise measurement.

(require "../../tools/bench-micro.rkt"
         "../../propagator.rkt"
         "../../typing-propagators.rkt"
         "../../syntax.rkt"
         "../../prelude.rkt"
         "../../type-lattice.rkt"
         "../../global-env.rkt"
         "../../metavar-store.rkt"
         "../../driver.rkt"
         "../../champ.rkt"
         racket/port)

;; ============================================================
;; Helper: run infer-on-network on a raw prop-network
;; ============================================================

(define (bench-infer-raw expr)
  (parameterize ([current-attribute-map-cell-id #f])
    (define net (make-prop-network))
    (define ctx (context-cell-value '() 0))
    (define-values (_net* type _solutions)
      (infer-on-network net expr ctx))
    type))

;; Helper: run full pipeline (process-string) for end-to-end comparison
(define (bench-eval str)
  (with-output-to-string
    (λ ()
      (parameterize ([current-error-port (current-output-port)])
        (process-string str)))))

;; ============================================================
;; Benchmark 1: Simple literal (minimal propagator overhead)
;; ============================================================

(define b-literal
  (bench "infer-on-network: literal (expr-int 42)"
    (bench-infer-raw (expr-int 42))))

;; ============================================================
;; Benchmark 2: Application (Pi decomposition + bidirectional writes)
;; ============================================================

(define func-e (expr-fvar 'int+))
(define arg1 (expr-int 1))
(define arg2 (expr-int 2))
(define app1 (expr-app func-e arg1))
(define app2 (expr-app app1 arg2))

(define b-app
  (bench "infer-on-network: (int+ 1 2)"
    (bench-infer-raw app2)))

;; ============================================================
;; Benchmark 3: Lambda (context extension + Pi synthesis)
;; ============================================================

(define lam-e
  (expr-lam 'mw (expr-Int) (expr-bvar 0)))

(define b-lam
  (bench "infer-on-network: (fn [x:Int] x)"
    (bench-infer-raw lam-e)))

;; ============================================================
;; Benchmark 4: Nested lambda (context chain, multiple propagators)
;; ============================================================

(define nested-lam
  (expr-lam 'mw (expr-Int)
    (expr-lam 'mw (expr-Bool)
      (expr-bvar 1))))

(define b-nested-lam
  (bench "infer-on-network: nested lambda (fn [x:Int] (fn [y:Bool] x))"
    (bench-infer-raw nested-lam)))

;; ============================================================
;; Benchmark 5: Full pipeline — trait resolution end-to-end
;; ============================================================

(define b-trait
  (bench "process-string: [eq? 0N 0N] (trait resolution)"
    (bench-eval "ns bench :no-prelude\n(eval [eq? 0N 0N])")))

;; ============================================================
;; Benchmark 6: Adversarial — deeply nested applications
;; ============================================================

;; Build: (int+ (int+ (int+ (int+ 1 2) 3) 4) 5) — 4 levels
(define deep-app
  (let loop ([n 4] [acc (expr-int 1)])
    (if (= n 0) acc
        (loop (- n 1)
              (expr-app (expr-app (expr-fvar 'int+) acc)
                        (expr-int (+ n 1)))))))

(define b-deep-app
  (bench "infer-on-network: deeply nested int+ (4 levels)"
    (bench-infer-raw deep-app)))

;; ============================================================
;; Print results
;; ============================================================

;; ============================================================
;; Memory profiling: measure allocation per infer-on-network call
;; ============================================================

(define (measure-memory-per-call expr label n-calls)
  (collect-garbage)
  (collect-garbage)
  (collect-garbage)
  (define mem-before (current-memory-use))
  (for ([_ (in-range n-calls)])
    (parameterize ([current-attribute-map-cell-id #f])
      (define net (make-prop-network))
      (define ctx (context-cell-value '() 0))
      (infer-on-network net expr ctx)))
  (define mem-after (current-memory-use))
  (define per-call (exact->inexact (/ (- mem-after mem-before) n-calls)))
  (printf "  ~a\n    ~a calls: ~a bytes total, ~a bytes/call (~a KB/call)\n\n"
          label n-calls (- mem-after mem-before)
          (round per-call)
          (exact->inexact (/ (round per-call) 1024))))

(displayln "\n=== Memory Profiling (per infer-on-network call) ===\n")
(measure-memory-per-call (expr-int 42) "literal (expr-int 42)" 1000)
(measure-memory-per-call app2 "application (int+ 1 2)" 1000)
(measure-memory-per-call lam-e "lambda (fn [x:Int] x)" 1000)
(measure-memory-per-call nested-lam "nested lambda (fn [x:Int] (fn [y:Bool] x))" 500)
(measure-memory-per-call deep-app "deep int+ (4 levels)" 500)

;; ============================================================
;; Network size profiling: count cells + propagators after quiescence
;; ============================================================

(define (measure-network-size expr label)
  (parameterize ([current-attribute-map-cell-id #f])
    (define net (make-prop-network))
    (define ctx (context-cell-value '() 0))
    (define-values (net* _type _solutions)
      (infer-on-network net expr ctx))
    ;; Count cells and propagators in the returned network
    (define cell-count (prop-network-next-cell-id net*))
    (define prop-count
      (let ([props (prop-network-propagators net*)])
        (champ-fold props (lambda (_k _v acc) (add1 acc)) 0)))
    (printf "  ~a: ~a cells, ~a propagators\n"
            label cell-count prop-count)))

(displayln "\n=== Network Size (cells + propagators after quiescence) ===\n")
(measure-network-size (expr-int 42) "literal")
(measure-network-size app2 "int+ 1 2")
(measure-network-size lam-e "fn [x:Int] x")
(measure-network-size nested-lam "nested lambda")
(measure-network-size deep-app "deep int+ (4 levels)")

(displayln "\n=== Timing Micro-Benchmarks ===\n")
(for ([b (list b-literal b-app b-lam b-nested-lam b-deep-app)])
  (define s (bench-result-stats b))
  (printf "  ~a\n    median: ~a ms  mean: ~a ms  cv: ~a%  n: ~a\n\n"
          (bench-result-name b)
          (hash-ref s 'median_ms)
          (hash-ref s 'mean_ms)
          (hash-ref s 'cv_pct)
          (hash-ref s 'n)))
