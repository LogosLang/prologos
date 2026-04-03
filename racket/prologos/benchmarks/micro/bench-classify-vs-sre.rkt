#lang racket/base

;; ========================================================================
;; SRE Track 2 Pre-0: Micro-Benchmark
;; ========================================================================
;;
;; Compares classify-whnf-problem dispatch vs SRE ctor-desc lookup
;; for the same expression pairs.
;;
;; Questions this answers:
;; 1. Is SRE lookup faster or slower than hardcoded match*?
;; 2. Which expression types are hottest?
;; 3. Does ctor-tag-for-value's linear scan dominate?

(require "../../syntax.rkt"
         "../../ctor-registry.rkt"
         "../../sre-core.rkt"
         "../../type-lattice.rkt"
         "../../unify.rkt")

;; ========================================
;; Test expressions (representative of real usage)
;; ========================================

(define pi-expr-a (expr-Pi 'mw expr-Int (expr-Pi 'mw expr-Int expr-Bool)))
(define pi-expr-b (expr-Pi 'mw expr-Nat (expr-Pi 'mw expr-Nat expr-Bool)))

(define app-expr-a (expr-app (expr-fvar 'f) expr-Int))
(define app-expr-b (expr-app (expr-fvar 'f) expr-Nat))

(define sigma-expr-a (expr-Sigma expr-Int expr-Bool))
(define sigma-expr-b (expr-Sigma expr-Nat expr-Bool))

(define eq-expr-a (expr-Eq expr-Int (expr-int 1) (expr-int 2)))
(define eq-expr-b (expr-Eq expr-Int (expr-int 3) (expr-int 4)))

(define pair-expr-a (expr-pair (expr-int 1) (expr-true)))
(define pair-expr-b (expr-pair (expr-int 2) (expr-false)))

(define vec-expr-a (expr-Vec expr-Int (expr-nat-val 3)))
(define vec-expr-b (expr-Vec expr-Nat (expr-nat-val 5)))

(define suc-expr-a (expr-suc (expr-suc expr-zero)))
(define suc-expr-b (expr-suc (expr-suc (expr-suc expr-zero))))

;; Atoms (no structure — classifier returns 'conv)
(define atom-a expr-Int)
(define atom-b expr-Nat)

;; Deeply nested (adversarial)
(define (make-deep-pi depth)
  (if (= depth 0) expr-Int
      (expr-Pi 'mw expr-Int (make-deep-pi (- depth 1)))))

(define deep-pi-5a (make-deep-pi 5))
(define deep-pi-5b (make-deep-pi 5))
(define deep-pi-10a (make-deep-pi 10))
(define deep-pi-10b (make-deep-pi 10))

;; ========================================
;; Benchmark: classify-whnf-problem (current)
;; ========================================

(define (bench-classify label a b n)
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range n)])
    (classify-whnf-problem a b))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us n) 1000))
  (printf "  classify ~a: ~a calls, ~a ns/call\n" label n (exact->inexact (round per-call-ns))))

;; ========================================
;; Benchmark: SRE ctor-tag-for-value lookup
;; ========================================

(define (bench-sre-tag label expr n)
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range n)])
    (ctor-tag-for-value expr))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us n) 1000))
  (printf "  sre-tag ~a: ~a calls, ~a ns/call\n" label n (exact->inexact (round per-call-ns))))

;; Benchmark: SRE full sre-constructor-tag (domain check)
(define type-domain-for-bench
  (make-sre-domain
    #:name 'type
    #:merge-registry type-lattice-merge
    #:contradicts? type-top?
    #:bot? type-bot?
    #:bot-value type-bot
    #:top-value type-top
    #:meta-recognizer expr-meta?))

(define (bench-sre-full-tag label expr n)
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range n)])
    (sre-constructor-tag type-domain-for-bench expr))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us n) 1000))
  (printf "  sre-constructor-tag ~a: ~a calls, ~a ns/call\n" label n (exact->inexact (round per-call-ns))))

;; Benchmark: Direct struct predicate (the baseline)
(define (bench-struct-pred label pred expr n)
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range n)])
    (pred expr))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us n) 1000))
  (printf "  struct-pred ~a: ~a calls, ~a ns/call\n" label n (exact->inexact (round per-call-ns))))

;; ========================================
;; Run benchmarks
;; ========================================

(define N 100000)

(printf "\n=== SRE Track 2 Pre-0: Classify vs SRE Dispatch ===\n\n")

(printf "--- Classify dispatch (current match*) ---\n")
(bench-classify "Pi-vs-Pi" pi-expr-a pi-expr-b N)
(bench-classify "app-vs-app" app-expr-a app-expr-b N)
(bench-classify "Sigma-vs-Sigma" sigma-expr-a sigma-expr-b N)
(bench-classify "Eq-vs-Eq" eq-expr-a eq-expr-b N)
(bench-classify "pair-vs-pair" pair-expr-a pair-expr-b N)
(bench-classify "Vec-vs-Vec" vec-expr-a vec-expr-b N)
(bench-classify "suc-vs-suc" suc-expr-a suc-expr-b N)
(bench-classify "atom-vs-atom" atom-a atom-b N)

(printf "\n--- SRE ctor-tag-for-value (linear scan) ---\n")
(bench-sre-tag "Pi" pi-expr-a N)
(bench-sre-tag "app" app-expr-a N)
(bench-sre-tag "Sigma" sigma-expr-a N)
(bench-sre-tag "Eq" eq-expr-a N)
(bench-sre-tag "pair" pair-expr-a N)
(bench-sre-tag "Vec" vec-expr-a N)
(bench-sre-tag "suc" suc-expr-a N)
(bench-sre-tag "atom(Int)" atom-a N)

(printf "\n--- SRE sre-constructor-tag (domain + linear scan) ---\n")
(bench-sre-full-tag "Pi" pi-expr-a N)
(bench-sre-full-tag "app" app-expr-a N)
(bench-sre-full-tag "Sigma" sigma-expr-a N)
(bench-sre-full-tag "Eq" eq-expr-a N)
(bench-sre-full-tag "pair" pair-expr-a N)
(bench-sre-full-tag "Vec" vec-expr-a N)
(bench-sre-full-tag "suc" suc-expr-a N)
(bench-sre-full-tag "atom(Int)" atom-a N)

(printf "\n--- Direct struct predicate (baseline) ---\n")
(bench-struct-pred "expr-Pi?" expr-Pi? pi-expr-a N)
(bench-struct-pred "expr-app?" expr-app? app-expr-a N)
(bench-struct-pred "expr-Sigma?" expr-Sigma? sigma-expr-a N)
(bench-struct-pred "expr-Eq?" expr-Eq? eq-expr-a N)
(bench-struct-pred "expr-pair?" expr-pair? pair-expr-a N)
(bench-struct-pred "expr-Vec?" expr-Vec? vec-expr-a N)
(bench-struct-pred "expr-suc?" expr-suc? suc-expr-a N)

(printf "\n--- Adversarial: deeply nested ---\n")
(bench-classify "deep-Pi-5" deep-pi-5a deep-pi-5b N)
(bench-classify "deep-Pi-10" deep-pi-10a deep-pi-10b N)
(bench-sre-full-tag "deep-Pi-5" deep-pi-5a N)
(bench-sre-full-tag "deep-Pi-10" deep-pi-10a N)

(printf "\n=== Done ===\n")
