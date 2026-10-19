#lang racket/base
;; C7 probe: does the S-6 fixture (tests/test-arena-parity.rkt:181) measure ASCENTS or FIRES?
;; D.2 §0 row 9 / P0 §5: "the S-6 row needs 1 ascent under BSP and up to 16 under the drain".
;; We count strict ascents of the join's output cell (merge calls whose result differs from the
;; old value) and fires of the join, under BSP and the sequential drain.
;;  A = the S-6 fixture as written (16 sources seeded after install, then run)
;;  B = sources produced by 16 upstream propagators triggered by one seed (arrivals interleave
;;      with the join's fires under the drain)
;;  B-rev = B with the upstream propagators installed in reverse order
(require racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define ascents (box 0))
(define join-fires (box 0))
(define (max-merge a b) (max a b))
(define (counting-max a b)
  (define r (max a b))
  (unless (equal? r a) (set-box! ascents (add1 (unbox ascents))))
  r)

(define (run-bsp net) (parameterize ([current-use-bsp-scheduler? #t]) (run-to-quiescence net)))
(define (run-seq net) (parameterize ([current-use-bsp-scheduler? #f]) (run-to-quiescence net)))

(define n 16)

(define (fixture-A)
  (define-values (net0 srcs)
    (for/fold ([net (make-prop-network)] [cs '()]) ([_ n])
      (define-values (nn c) (net-new-cell net 0 max-merge))
      (values nn (cons c cs))))
  (define srcv (reverse srcs))
  (define-values (net1 out) (net-new-cell net0 0 counting-max))
  (define-values (net2 _p)
    (net-add-propagator net1 srcv (list out)
                        (λ (net) (set-box! join-fires (add1 (unbox join-fires)))
                                 (net-cell-write net out (apply max (map (λ (c) (net-cell-read net c)) srcv))))))
  (define net3 (for/fold ([net net2]) ([c srcv] [i (in-naturals)]) (net-cell-write net c (add1 i))))
  (values net3 out))

(define (fixture-B reverse?)
  (define-values (net0 seed) (net-new-cell (make-prop-network) 0 max-merge))
  (define-values (net1 srcs)
    (for/fold ([net net0] [cs '()]) ([_ n])
      (define-values (nn c) (net-new-cell net 0 max-merge))
      (values nn (cons c cs))))
  (define srcv (reverse srcs))
  (define-values (net2 out) (net-new-cell net1 0 counting-max))
  (define order (if reverse? (reverse (range n)) (range n)))
  (define net3
    (for/fold ([net net2]) ([i order])
      (define c (list-ref srcv i))
      (define-values (nn _p)
        (net-add-propagator net (list seed) (list c)
                            (λ (net) (if (> (net-cell-read net seed) 0) (net-cell-write net c (add1 i)) net))))
      nn))
  (define-values (net4 _q)
    (net-add-propagator net3 srcv (list out)
                        (λ (net) (set-box! join-fires (add1 (unbox join-fires)))
                                 (net-cell-write net out (apply max (map (λ (c) (net-cell-read net c)) srcv))))))
  (values (net-cell-write net4 seed 1) out))

(define (measure label mk)
  (for ([sched (list (cons "BSP" run-bsp) (cons "seq-drain" run-seq))])
    (set-box! ascents 0) (set-box! join-fires 0)
    (define-values (net out) (mk))
    (set-box! ascents 0) (set-box! join-fires 0)   ; count only during the run
    (define res ((cdr sched) net))
    (printf "~a ~a: out=~a ascents-of-out=~a join-fires=~a fuel-used=~a\n"
            label (car sched) (net-cell-read res out) (unbox ascents) (unbox join-fires)
            (- 1000000 (net-fuel-remaining res)))))

(measure "A(S-6 as written)" fixture-A)
(measure "B(upstream producers)" (λ () (fixture-B #f)))
(measure "B-rev" (λ () (fixture-B #t)))
