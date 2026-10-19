#lang racket/base
;;; W2-8: is the PAR 2 demo network degenerate?  For each micro network: rounds, fires, productive fires
;;; (fires whose result carries a value write), and whether any cell's value changed from its initial value.
(require racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt") champ-fold)
         (file "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-8/w28-micro.rkt"))
(define (fr-writes r) (cond [(list? r) r] [else (define v (struct->vector r)) (if (eq? (vector-ref v 0) 'struct:fire-result) (vector-ref v 1) '())]))
(define (vals net) (champ-fold (prop-network-cells net) (lambda (k c acc) (cons (cons (cell-id-n k) (prop-cell-value c)) acc)) '()))
(for ([name '("grid12" "gc500" "wave1000" "grid12i" "gc500i" "grid20i")])
  (define-values (net _) (build-micro name))
  (define fires 0) (define prod 0) (define rounds 0) (define widths '())
  (define (exec snap pids)
    (define rs (sequential-fire-all snap pids))
    (set! rounds (add1 rounds)) (set! widths (cons (length pids) widths))
    (set! fires (+ fires (length rs))) (set! prod (+ prod (length (filter (λ (r) (pair? (fr-writes r))) rs))))
    rs)
  (define out (parameterize ([current-parallel-executor exec] [current-tree-reduce-threshold #f]) (run-to-quiescence net)))
  (define before (make-hash (vals net)))
  (define changed (for/sum ([p (vals out)]) (if (equal? (hash-ref before (car p) 'none) (cdr p)) 0 1)))
  (printf "~a: rounds ~a widths ~a fires ~a productive ~a cells-changed-by-S0 ~a contradiction ~a\n"
          name rounds (take (reverse widths) (min 6 (length widths))) fires prod changed (and (prop-network-contradiction out) #t)))
