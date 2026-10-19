#lang racket/base
;; W2-4: what do the two weakly-pinned queries of tests/test-propagator-solver.rkt:81-99 return today,
;; and what does DFS return? (The test accepts any of 3 values; only one is correct.)
(require (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/relations.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/solver.rkt"))
(define parent-rel
  (relation-info 'parent 2
    (list (variant-info (list (param-info 'x 'free) (param-info 'y 'free)) '()
                        (list (fact-row (list 'alice 'bob)) (fact-row (list 'bob 'carol)) (fact-row (list 'carol 'dave)))))
    #f #f))
(define store (relation-register (make-relation-store) parent-rel))
(define dfs (make-solver-config (hasheq 'strategy 'depth-first)))
(for ([q (list (list 'alice 'y) (list 'x 'carol))] [vars '((y) (x))])
  (printf "parent~a  ATMS(solve-goal-propagator): ~a   DFS(solve-goal): ~a\n" q
          (solve-goal-propagator default-solver-config store 'parent q vars)
          (solve-goal dfs store 'parent q vars)))
