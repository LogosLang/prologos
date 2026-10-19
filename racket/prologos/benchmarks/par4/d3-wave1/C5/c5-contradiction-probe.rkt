#lang racket/base
;; C5 (D.3 Theory) — WHICH contradiction a run reports is order-dependent even when every merge is a join.
;; Two cells c1, c2 (max merge, contradicts? when ≥ 10), two writers triggered by the same source in ONE round.
;; net-cell-write stores `[contradiction cid]` (propagator.rkt:2105 slow path, :1946 fast path): last writer wins.
;; Swapping the installation order swaps the round's merge order (bulk-merge-writes :2990) under BSP and the
;; firing order under the sequential drain. Existence of a contradiction is the same; its reported cell is not.
(require (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define (which bsp? order)
  (define n0 (make-prop-network 100000))
  (define-values (n1 s) (net-new-cell n0 0 (λ (a b) (max a b))))
  (define-values (n2 c1) (net-new-cell n1 0 (λ (a b) (max a b)) (λ (v) (>= v 10))))
  (define-values (n3 c2) (net-new-cell n2 0 (λ (a b) (max a b)) (λ (v) (>= v 10))))
  (define (w c) (λ (n) (if (zero? (net-cell-read n s)) n (net-cell-write n c 10))))
  (define installed
    (for/fold ([n n3]) ([c (in-list (if (eq? order 'c1-first) (list c1 c2) (list c2 c1)))])
      (let-values ([(n* _) (net-add-propagator n (list s) (list c) (w c))]) n*)))
  (define base (parameterize ([current-use-bsp-scheduler? bsp?]) (run-to-quiescence installed)))
  (define r (parameterize ([current-use-bsp-scheduler? bsp?]) (run-to-quiescence (net-cell-write base s 1))))
  (define k (prop-network-contradiction r))
  (cond [(equal? k c1) 'c1] [(equal? k c2) 'c2] [else k]))

(printf "== WHICH: reported contradiction cell by install order\n")
(for ([bsp? '(#t #f)])
  (printf "  ~a  c1-installed-first: ~a   c2-installed-first: ~a\n" (if bsp? "BSP" "SEQ")
          (which bsp? 'c1-first) (which bsp? 'c2-first)))
