#lang racket/base

;; bench-unify.rkt — Micro-benchmarks for unification
;;
;; Stresses: structural decomposition, meta-solving, occurs check, deep terms.

(require "../../tools/bench-micro.rkt"
         "../../syntax.rkt"
         "../../unify.rkt"
         "../../metavar-store.rkt"
         "../../reduction.rkt"
         "../../performance-counters.rkt")

;; Helper: build a deeply nested Pi type: (Nat -> (Nat -> ... -> Nat))
(define (deep-pi depth)
  (if (zero? depth)
      (expr-Nat)
      (expr-Pi 'mw (expr-Nat) (deep-pi (sub1 depth)))))

;; Helper: build deeply nested application tree
(define (deep-app depth base)
  (if (zero? depth)
      base
      (expr-app (deep-app (sub1 depth) base) (expr-Nat))))

;; Fresh environment for each benchmark iteration
(define (with-fresh-stores thunk)
  (with-fresh-meta-env
    (parameterize ([current-reduction-fuel (box 10000)])
      (thunk))))

;; ============================================================
;; Benchmarks
;; ============================================================

;; 1. Identical types — should be fast (structural equality)
(define b-same-type
  (bench "unify: identical Nat"
    (with-fresh-stores
      (λ () (for ([_ (in-range 1000)])
              (unify '() (expr-Nat) (expr-Nat)))))))

;; 2. Identical deep Pi types
(define b-deep-pi
  (let ([ty (deep-pi 20)])
    (bench "unify: deep Pi (depth=20)"
      (with-fresh-stores
        (λ () (for ([_ (in-range 100)])
                (unify '() ty ty)))))))

;; 3. Meta-solving — unify ?m with Nat
(define b-meta-solve
  (bench "unify: meta-solve (?m = Nat) x500"
    (with-fresh-stores
      (λ ()
        (for ([_ (in-range 500)])
          (with-fresh-meta-env
            (define m (fresh-meta '() (expr-Type 0) 'bench))
            (unify '() m (expr-Nat))))))))

;; 4. Deep structural decomposition (Pi vs Pi)
(define b-decompose
  (let ([ty-a (deep-pi 15)]
        [ty-b (deep-pi 15)])
    (bench "unify: decompose Pi (depth=15) x200"
      (with-fresh-stores
        (λ () (for ([_ (in-range 200)])
                (unify '() ty-a ty-b)))))))

;; 5. Incompatible types — should fail fast
(define b-fail-fast
  (bench "unify: Nat vs Bool (fail) x200"
    (with-fresh-stores
      (λ () (for ([_ (in-range 200)])
              (unify '() (expr-Nat) (expr-Bool)))))))

;; ============================================================
;; Run all
;; ============================================================

(define all-results
  (list b-same-type b-deep-pi b-meta-solve b-decompose b-fail-fast))

(print-bench-summary all-results)
