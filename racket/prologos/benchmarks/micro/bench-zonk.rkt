#lang racket/base

;; bench-zonk.rkt — Micro-benchmarks for zonking (meta-substitution)
;;
;; Stresses: shallow terms, deep nesting, many metas, solved vs unsolved.

(require "../../tools/bench-micro.rkt"
         "../../syntax.rkt"
         "../../zonk.rkt"
         "../../metavar-store.rkt"
         "../../reduction.rkt"
         "../../performance-counters.rkt")

;; Helper: create a fresh meta store with N solved metas
;; Returns (values meta-exprs term-with-metas)
(define (setup-solved-metas n)
  (define store (make-hasheq))
  (parameterize ([current-meta-store store])
    (define metas
      (for/list ([i (in-range n)])
        (define m (fresh-meta '() (expr-Type 0) 'bench))
        ;; Solve each meta to (expr-Nat)
        (solve-meta! (expr-meta-id m) (expr-Nat))
        m))
    (values store metas)))

;; Helper: build a term with N metas nested in Pi types
;; Pi(?m0, Pi(?m1, ... Pi(?mN, Nat)))
(define (nested-pi-metas metas)
  (if (null? metas)
      (expr-Nat)
      (expr-Pi 'mw (car metas) (nested-pi-metas (cdr metas)))))

;; Helper: build a flat application chain with metas
;; (app (app ... (app base ?m0) ?m1) ... ?mN)
(define (app-chain-metas base metas)
  (for/fold ([acc base]) ([m (in-list metas)])
    (expr-app acc m)))

;; ============================================================
;; Benchmarks
;; ============================================================

;; 1. Zonk atom (no metas) — baseline
(define b-zonk-atom
  (bench "zonk: atom (Nat) x5000"
    (with-fresh-meta-env
      (parameterize ([current-reduction-fuel (box 10000)])
        (for ([_ (in-range 5000)])
          (zonk (expr-Nat)))))))

;; 2. Zonk shallow: single solved meta
(define b-zonk-shallow
  (bench "zonk: single solved meta x2000"
    (let-values ([(store metas) (setup-solved-metas 1)])
      (define term (car metas))
      (parameterize ([current-meta-store store]
                     [current-reduction-fuel (box 10000)])
        (for ([_ (in-range 2000)])
          (zonk term))))))

;; 3. Zonk deep: 20 solved metas nested in Pi
(define b-zonk-deep
  (bench "zonk: 20 metas in nested Pi x500"
    (let-values ([(store metas) (setup-solved-metas 20)])
      (define term (nested-pi-metas metas))
      (parameterize ([current-meta-store store]
                     [current-reduction-fuel (box 10000)])
        (for ([_ (in-range 500)])
          (zonk term))))))

;; 4. Zonk wide: 50 metas in flat app chain
(define b-zonk-wide
  (bench "zonk: 50 metas in app chain x200"
    (let-values ([(store metas) (setup-solved-metas 50)])
      (define term (app-chain-metas (expr-Nat) metas))
      (parameterize ([current-meta-store store]
                     [current-reduction-fuel (box 10000)])
        (for ([_ (in-range 200)])
          (zonk term))))))

;; 5. Zonk many: 100 solved metas in Pi chain
(define b-zonk-many
  (bench "zonk: 100 metas in Pi chain x100"
    (let-values ([(store metas) (setup-solved-metas 100)])
      (define term (nested-pi-metas metas))
      (parameterize ([current-meta-store store]
                     [current-reduction-fuel (box 100000)])
        (for ([_ (in-range 100)])
          (zonk term))))))

;; ============================================================
;; Run all
;; ============================================================

(define all-results
  (list b-zonk-atom b-zonk-shallow b-zonk-deep b-zonk-wide b-zonk-many))

(print-bench-summary all-results)
