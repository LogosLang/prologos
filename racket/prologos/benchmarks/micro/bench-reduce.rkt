#lang racket/base

;; bench-reduce.rkt — Micro-benchmarks for reduction (WHNF / NF)
;;
;; Stresses: Nat arithmetic, deep term reduction, beta-reduction chains.
;; Uses process-string to set up terms via the full pipeline, measuring
;; reduction cost through phase timing and heartbeat counters.

(require "../../tools/bench-micro.rkt"
         "../../syntax.rkt"
         "../../reduction.rkt"
         "../../global-env.rkt"
         "../../driver.rkt"
         "../../performance-counters.rkt"
         racket/port)

;; Helper: build Nat literal as AST (Church-style: S(S(S(...Z))))
(define (nat->ast n)
  (if (zero? n)
      (expr-zero)
      (expr-suc (nat->ast (sub1 n)))))

;; Helper: run process-string in a fresh env, capturing stderr
(define (bench-process-string str)
  (parameterize ([current-global-env (hasheq)])
    (with-output-to-string
      (λ ()
        (parameterize ([current-error-port (current-output-port)])
          (process-string str))))))

;; ============================================================
;; Benchmarks
;; ============================================================

;; 1. NF of small Nat — reduces S(S(S(Z))) to normal form
(define b-nf-small
  (let ([term (nat->ast 10)])
    (bench "reduce: nf Nat(10) x100"
      (parameterize ([current-global-env (hasheq)]
                     [current-reduction-fuel (box 100000)])
        (for ([_ (in-range 100)])
          (nf term))))))

;; 2. NF of medium Nat
(define b-nf-medium
  (let ([term (nat->ast 50)])
    (bench "reduce: nf Nat(50) x20"
      (parameterize ([current-global-env (hasheq)]
                     [current-reduction-fuel (box 100000)])
        (for ([_ (in-range 20)])
          (nf term))))))

;; 3. Beta-reduction chain: ((λx.x) ((λx.x) ((λx.x) ... Nat)))
(define (id-chain depth base)
  (if (zero? depth)
      base
      (expr-app (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                (id-chain (sub1 depth) base))))

(define b-beta-chain
  (let ([term (id-chain 100 (expr-Nat))])
    (bench "reduce: beta-chain (depth=100) x10"
      (parameterize ([current-global-env (hasheq)]
                     [current-reduction-fuel (box 100000)])
        (for ([_ (in-range 10)])
          (nf term))))))

;; 4. WHNF vs NF: WHNF should be faster (stops at head)
(define b-whnf-deep
  (let ([term (nat->ast 50)])
    (bench "reduce: whnf Nat(50) x500"
      (parameterize ([current-global-env (hasheq)]
                     [current-reduction-fuel (box 100000)])
        (for ([_ (in-range 500)])
          (whnf term))))))

;; 5. Full pipeline: Nat addition via eval
(define b-pipeline-add
  (bench "reduce: pipeline [add 3N 4N]"
    (bench-process-string "(eval [add 3N 4N])")))

;; ============================================================
;; Run all
;; ============================================================

(define all-results
  (list b-nf-small b-nf-medium b-beta-chain b-whnf-deep b-pipeline-add))

(print-bench-summary all-results)
