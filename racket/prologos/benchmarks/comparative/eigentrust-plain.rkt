#lang racket/base

;;; eigentrust-plain.rkt — plain Racket EigenTrust implementation.
;;;
;;; No propagator network. Just iterates the off-network step kernel
;;; K times in a tail loop with parameter-passing. The point is to
;;; isolate "propagator infrastructure overhead" from "the algorithm
;;; in plain Racket" — both versions call the SAME `eigentrust-step`
;;; / `eigentrust-step-fl` kernel; only the orchestration differs.
;;;
;;; Compared against `eigentrust-propagators.rkt` (rat-coarse) and
;;; `eigentrust-propagators-float.rkt` (float), this gives:
;;;
;;;   propagator overhead = (propagator time) − (plain time)
;;;
;;; for the same workload.

(require "eigentrust-propagators.rkt"
         "eigentrust-propagators-float.rkt"
         racket/flonum)

(provide
 run-eigentrust-plain
 run-eigentrust-plain-fl)

;; ============================================================
;; Plain rational implementation
;; ============================================================

;; t_K = step^K(p), starting from t_0 = p.
;; Same convention as the propagator version (see semantic note in
;; eigentrust-propagators.rkt): k = max-iter + 1 to match the Prologos
;; surface `eigentrust m p α 0/1 max-iter` semantics.
(define (run-eigentrust-plain m p alpha k)
  (unless (col-stochastic? m)
    (error 'run-eigentrust-plain "M must be column-stochastic"))
  (let loop ([t p] [remaining k])
    (cond
      [(zero? remaining) t]
      [else (loop (eigentrust-step m p alpha t) (sub1 remaining))])))

;; ============================================================
;; Plain float implementation
;; ============================================================

(define (run-eigentrust-plain-fl m p alpha k)
  (unless (col-stochastic-fl? m)
    (error 'run-eigentrust-plain-fl "M must be column-stochastic"))
  (let loop ([t p] [remaining k])
    (cond
      [(zero? remaining) t]
      [else (loop (eigentrust-step-fl m p alpha t) (sub1 remaining))])))


;; ============================================================
;; Smoke
;; ============================================================

(module+ main
  (define rat-result (run-eigentrust-plain m-ring-4 p-seed-0 3/10 4))
  (printf "plain rat ring-4 / α=3/10 / k=4:~n  ~s~n" rat-result)
  (unless (equal? rat-result (vector 5401/10000 21/100 147/1000 1029/10000))
    (error 'main "rat result mismatch"))
  (printf "  matches Prologos surface + propagator versions ✓~n~n")

  (define fl-result (run-eigentrust-plain-fl m-ring-4-fl p-seed-0-fl 0.3 4))
  (printf "plain float ring-4 / α=0.3 / k=4:~n  ~s~n" fl-result)
  ;; Expected ~ #fl(0.5401 0.21 0.147 0.1029); float round-off makes
  ;; this approximate.
  (define ok?
    (for/and ([i (in-range 4)])
      (define expected (vector-ref (vector 0.5401 0.21 0.147 0.1029) i))
      (< (abs (- (flvector-ref fl-result i) expected)) 1e-9)))
  (unless ok? (error 'main "float result mismatch"))
  (printf "  matches rational version within 1e-9 ✓~n"))
