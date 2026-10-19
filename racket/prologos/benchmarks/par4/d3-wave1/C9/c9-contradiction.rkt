#lang racket/base
;; C9 (e): contradiction with work in flight (D.2 §6.7 "Contradiction: ⊤ in the contradiction cell;
;; executors see it at their next lane check and stop. Monotone." and S-7).
;; Two INDEPENDENT contradictions, on cells X and Y, reachable in the same S0 run. Which one does the
;; network report (prop-network-contradiction, the payload error messages are built from), and what
;; state do the other cells hold when the run stops? Also: the net-cell-write slow path REPLACES the
;; recorded cell id (propagator.rkt:2102-2105 `[contradiction cid]`) while the undeclared path keeps
;; the first (:3066 `(or ...)`): the payload is a last-writer-wins register, not a join.
(require racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define (run-bsp net) (parameterize ([current-use-bsp-scheduler? #t]) (run-to-quiescence net)))
(define (run-seq net) (parameterize ([current-use-bsp-scheduler? #f]) (run-to-quiescence net)))
(define (flat a b) (cond [(eq? a 'bot) b] [(eq? b 'bot) a] [(equal? a b) a] [else 'top]))
(define (mx a b) (max a b))
(define (top? v) (eq? v 'top))

(define (E sched order)
  (define-values (n0 s) (net-new-cell (make-prop-network 10000) 0 mx))
  (define-values (n1 X) (net-new-cell n0 'bot flat top?))
  (define-values (n2 Y) (net-new-cell n1 'bot flat top?))
  (define-values (n3 Z) (net-new-cell n2 0 mx))          ; unrelated progress cell, a chain
  (define-values (n4 Z2) (net-new-cell n3 0 mx))
  (define props
    (vector (list (list s) (list X) (λ (n) (if (> (net-cell-read n s) 0) (net-cell-write n X 'x1) n)))
            (list (list s) (list X) (λ (n) (if (> (net-cell-read n s) 0) (net-cell-write n X 'x2) n)))
            (list (list s) (list Y) (λ (n) (if (> (net-cell-read n s) 0) (net-cell-write n Y 'y1) n)))
            (list (list s) (list Y) (λ (n) (if (> (net-cell-read n s) 0) (net-cell-write n Y 'y2) n)))
            (list (list s) (list Z) (λ (n) (net-cell-write n Z (net-cell-read n s))))
            (list (list Z) (list Z2) (λ (n) (net-cell-write n Z2 (add1 (net-cell-read n Z)))))))
  (define n5 (for/fold ([n n4]) ([i order])
               (define p (vector-ref props i))
               (define-values (n* _p) (net-add-propagator n (car p) (cadr p) (caddr p))) n*))
  (define final ((if (eq? sched 'bsp) run-bsp run-seq) (net-cell-write n5 s 1)))
  (define c (prop-network-contradiction final))
  (list sched order 'reported (cond [(equal? c X) 'X] [(equal? c Y) 'Y] [else c])
        'X (net-cell-read final X) 'Y (net-cell-read final Y) 'Z2 (net-cell-read final Z2)))
(printf "== E: two independent contradictions in one S0 run — reported cell and held state, by schedule\n")
(for* ([sched '(bsp drain)] [o '((0 1 2 3 4 5) (2 3 0 1 4 5) (4 5 0 2 1 3) (5 4 3 2 1 0))])
  (printf "  ~a\n" (E sched o)))
