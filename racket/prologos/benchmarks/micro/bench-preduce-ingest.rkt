#lang racket/base
;; PReduce Track 2 — the ingestion overhead FLOOR (§5.8; ledger iter 23).
;; Measures whnf of int-fold exprs: native (gate OFF) vs e-graph (gate ON),
;; FRESH positions (every fold a new literal pair — worst case: full
;; intern+dispatch+union round-trip) vs MEMO HITS (same expr — best case:
;; hashcons lookup). The floor bounds what δ/β must save per position.
(require racket/set
         "../../reduction.rkt"
         "../../syntax.rkt"
         "../../eclass-graph.rkt"
         "../../rule-registry.rkt"
         "../../kernel-rules-seed.rkt"
         "../../propagator.rkt"
         (only-in "../../metavar-store.rkt" current-persistent-registry-net-box))

(define-syntax-rule (bench-ns label N-val body)
  (let* ([N N-val]
         [_ (for ([i (in-range (quotient N 10))]) body)]
         [t0 (current-inexact-monotonic-milliseconds)])
    (for ([i (in-range N)]) body)
    (let* ([t1 (current-inexact-monotonic-milliseconds)]
           [ns-per (/ (* (- t1 t0) 1e6) N)])
      (printf "~a: ~a ns/op  (~a ops)\n" label (real->decimal-string ns-per 0) N)
      ns-per)))

;; OFF baseline: the native fold arm
(define exprs (for/vector ([i (in-range 10000)])
                (expr-int-add (expr-int i) (expr-int 2))))
(define idx (box 0))
(define (next-expr!)
  (define i (unbox idx))
  (set-box! idx (modulo (add1 i) 10000))
  (vector-ref exprs i))

(printf "== native (gate OFF) ==\n")
(bench-ns "whnf int-fold, fresh exprs" 10000 (whnf (next-expr!)))
(define same-expr (expr-int-add (expr-int 7) (expr-int 35)))
(bench-ns "whnf int-fold, same expr" 10000 (whnf same-expr))

;; ON: plumb the e-graph
(define prn-box (box (make-prop-network)))
(parameterize ([current-rule-registry-cell-id #f]
               [current-eclass-hashcons-cell-id #f]
               [current-persistent-registry-net-box prn-box])
  (init-rule-registry-cell! prn-box)
  (set-box! prn-box (run-to-quiescence
                     (register-arithmetic-seed! (unbox prn-box)
                                                (current-rule-registry-cell-id))))
  (init-eclass-hashcons-cell! prn-box)
  (parameterize ([current-preduce-ingest? #t])
    (printf "== e-graph (gate ON) ==\n")
    (set-box! idx 0)
    (bench-ns "whnf int-fold, FRESH positions (intern+dispatch+union)" 2000
              (whnf (next-expr!)))
    (bench-ns "whnf int-fold, MEMO HIT (hashcons lookup)" 10000
              (whnf same-expr))))
