#lang racket/base
;;;
;;; bench-scheduler-accumulation.rkt
;;; PPN 4C Addendum Phase 4B — Probe 2 (Q-4B.2 / Q-4B.9): the "network soup"
;;; accumulation cost of run-to-quiescence on a PERSISTENT prop-network.
;;;
;;; THE GATE for the scheduler O(network-size) -> O(network-diff) optimization
;;; (§18.21.9 + §18.21.10). Re-run after any fire-and-collect-writes change:
;;; the per-command quiescence time should FLATTEN (O(N) -> O(changed)).
;;;
;;; Findings at HEAD e5ede4b2 (2026-06-03):
;;;   - per-command quiescence grows ~22x over 1000 cmds (O(N) per call)
;;;   - write-only (no quiescence) is FLAT -> cost is in run-to-quiescence, NOT cells
;;;   - worklist is O(1) (2 in / 0 out); add-propagator is flat
;;;   - GC = ~1% -> algorithmic, not GC
;;;   - ROOT CAUSE: fire-and-collect-writes (propagator.rkt:2869-2909) champ-folds
;;;     ALL cells for undeclared-writes + new-cells on every fire that changes the
;;;     cells CHAMP -> O(N log N)/fire. Fix = eq?-pruned CHAMP structural diff.
;;;
;;; USAGE: "/Applications/Racket v9.0/bin/racket" benchmarks/micro/bench-scheduler-accumulation.rkt
;;;

(require (only-in "../../propagator.rkt"
                  make-prop-network net-new-cell net-cell-read net-cell-write
                  net-add-fire-once-propagator net-remove-propagator-from-dependents
                  run-to-quiescence prop-network-worklist)
         racket/format)

(define (rep old new) new)

;; ---- Main accumulation measurement: N fire-once residuation propagators on a
;; ---- PERSISTENT network, per-command quiescence (commit a trigger + quiesce).
(define (bench-accum N self-clean?)
  (collect-garbage)(collect-garbage)
  (define mem0 (current-memory-use))
  (define net (make-prop-network 100000000))
  (define times (make-vector N 0.0))
  (for ([k (in-range N)])
    (define-values (n1 trig) (net-new-cell net #f rep))
    (define-values (n2 out)  (net-new-cell n1 #f rep))
    (define-values (n3 pid)
      (net-add-fire-once-propagator n2 (list trig) (list out)
        (lambda (nn)
          (define v (net-cell-read nn trig))
          (cond [(not v) nn]
                [self-clean? (net-remove-propagator-from-dependents (net-cell-write nn out v) pid trig)]
                [else (net-cell-write nn out v)]))))
    (define n4 (net-cell-write n3 trig k))
    (define t0 (current-inexact-milliseconds))
    (define n5 (run-to-quiescence n4))
    (define t1 (current-inexact-milliseconds))
    (vector-set! times k (- t1 t0))
    (set! net n5))
  (collect-garbage)
  (define mem1 (current-memory-use))
  (define (avg lo hi) (/ (for/sum ([k (in-range lo hi)]) (vector-ref times k)) (max 1 (- hi lo))))
  (printf "  accum N=~a self-clean=~a:  per-cmd quiescence first50=~a ms  last50=~a ms  ratio=~a   mem=~a B/cmd\n"
          N self-clean?
          (~r (avg 0 50) #:precision 4) (~r (avg (- N 50) N) #:precision 4)
          (~r (/ (max 0.0001 (avg (- N 50) N)) (max 0.0001 (avg 0 50))) #:precision 1)
          (quotient (- mem1 mem0) N)))

;; ---- Isolation: write-only (no propagators, no quiescence). Expect FLAT.
(define (bench-write-only N)
  (collect-garbage)
  (define net (make-prop-network 100000000))
  (define times (make-vector N 0.0))
  (for ([k (in-range N)])
    (define t0 (current-inexact-milliseconds))
    (define-values (n1 c) (net-new-cell net #f rep))
    (define n2 (net-cell-write n1 c k))
    (define t1 (current-inexact-milliseconds))
    (vector-set! times k (- t1 t0))
    (set! net n2))
  (define (avg lo hi) (/ (for/sum ([k (in-range lo hi)]) (vector-ref times k)) (max 1 (- hi lo))))
  (printf "  write-only N=~a (no props/quiescence):  first50=~a ms  last50=~a ms  ratio=~a  (FLAT = cost is the scheduler, not cells)\n"
          N (~r (avg 0 50) #:precision 4) (~r (avg (- N 50) N) #:precision 4)
          (~r (/ (max 0.0001 (avg (- N 50) N)) (max 0.0001 (avg 0 50))) #:precision 1)))

(printf "=== Probe 2: network-soup accumulation on a PERSISTENT mnr (the scheduler O(diff) gate) ===\n")
(bench-accum 1000 #f)
(bench-accum 1000 #t)
(bench-write-only 1000)
(printf "GATE: after the fire-and-collect-writes O(diff) fix, accum ratio should approach ~~1 (flat).\n")
