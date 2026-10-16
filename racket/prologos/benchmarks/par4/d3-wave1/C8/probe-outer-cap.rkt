#lang racket/base
;; C8 probe: BC-3 routes every producer/consumer/table creation through a topology request applied at the
;; topology stratum (G-1). How many successive topology-discovery levels does today's stratum loop allow?
;; propagator.rkt:3619-3634 errors when outer-round > 20. D.2 §8 keeps "strata outer loop | unchanged".
;; Construction: a chain of depth N. Level d: a propagator (input: seed cell) fires in S0 and writes one
;; callback-topology-request into cell 6 (constraint-propagators-topology-cell-id, the built-in topology
;; handler, propagator.rkt:3373). The handler (topology tier, outside S0) runs the callback, which installs the
;; level-(d+1) propagator. So each level = one S0 quiescence + one topology application = one outer iteration,
;; the shape of SLG subgoal discovery when each new call variant needs a new table/producer.
(require racket/set
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define (run-chain N)
  (define net0 (make-prop-network))
  (define-values (net1 seed) (net-new-cell net0 0 (lambda (a b) (max a b))))
  (define-values (net2 depth-cell) (net-new-cell net1 0 (lambda (a b) (max a b))))
  (define (make-level d)
    ;; fire fn for level d: record depth d; if d < N, request installation of level d+1
    (lambda (net)
      (define n1 (net-cell-write net depth-cell d))
      (if (< d N)
          (net-cell-write n1 constraint-propagators-topology-cell-id
                          (set (callback-topology-request
                                (lambda (n) (let-values ([(n* pid) (net-add-propagator n (list seed) (list depth-cell constraint-propagators-topology-cell-id)
                                                                (make-level (add1 d)))]) n*))
                                (cons 'c8-level (cons (cell-id (+ 1000 d)) (cell-id (+ 2000 d)))))))
          n1)))
  (define-values (net3 pid0) (net-add-propagator net2 (list seed) (list depth-cell constraint-propagators-topology-cell-id) (make-level 1)))
  (define net4 (net-cell-write net3 seed 1))
  (with-handlers ([exn:fail? (lambda (e) (format "ERROR: ~a" (exn-message e)))])
    (define out (run-to-quiescence-bsp net4))
    (format "ok: depth reached ~a, contradiction ~a" (net-cell-read out depth-cell) (prop-network-contradiction out))))

(for ([N (in-list '(5 15 20 21 22 23 24 25 40))])
  (printf "N=~a  ~a\n" N (run-chain N)))
