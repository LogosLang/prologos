#lang racket/base
;; C7 probe: does make-pool-executor (propagator.rkt:3899, retired by D.2 only in P6) fire every
;; propagator of a round?  pool-dispatch (:3819) dispatches only the first min(k, #thunks) chunks;
;; make-pool-executor builds ceil(n / max(1, n quotient k)) chunks.  Fixture: n independent propagators,
;; each copies a seed into its own output cell; count outputs that reached 1, under the sequential
;; executor and under a K=8 pool, for n in {8, 10, 16, 17, 23}.
(require (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define (max-merge a b) (max a b))
(define pool (make-worker-pool 8))
(define (fixture n)
  (define-values (net0 seed) (net-new-cell (make-prop-network) 0 max-merge))
  (define-values (net1 outs)
    (for/fold ([net net0] [os '()]) ([_ n])
      (define-values (nn c) (net-new-cell net 0 max-merge))
      (values nn (cons c os))))
  (define net2
    (for/fold ([net net1]) ([o outs])
      (define-values (nn _p) (net-add-propagator net (list seed) (list o)
                                                 (λ (net) (net-cell-write net o (net-cell-read net seed)))))
      nn))
  (values (net-cell-write net2 seed 1) outs))
(for ([n '(8 10 16 17 23)])
  (define (reached exec)
    (define-values (net outs) (fixture n))
    (define out (parameterize ([current-use-bsp-scheduler? #t] [current-parallel-executor exec])
                  (run-to-quiescence net)))
    (for/sum ([o outs]) (if (= 1 (net-cell-read out o)) 1 0)))
  (printf "n=~a  sequential: ~a/~a outputs reached   pool K=8: ~a/~a   thread-per-round: ~a/~a\n"
          n (reached #f) n (reached (make-pool-executor pool)) n (reached (make-parallel-thread-fire-all)) n))
