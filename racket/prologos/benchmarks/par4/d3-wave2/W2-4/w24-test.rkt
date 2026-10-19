#lang racket/base
;; W2-4 Q1(c): does a test pin an answer that only the ATMS route gives?  Run ONE test file under a global
;; strategy override (STRAT=dfs | atms | auto) and print rackunit's pass/fail tally. A test that passes under
;; auto (the default) but fails under forced DFS depends on what the ATMS route returns.
(require rackunit/log racket/port
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/stratified-eval.rkt")
                  current-solver-strategy-override))
(define f (simplify-path (path->complete-path (vector-ref (current-command-line-arguments) 0))))
(define strat (or (getenv "STRAT") "auto"))
(define override (case strat [("dfs") 'depth-first] [("atms") 'atms] [else #f]))
(define sub `(submod (file ,(path->string f)) test))
(parameterize ([current-solver-strategy-override override])
  (with-handlers ([exn:fail? (lambda (e) (eprintf "W24-TEST-RAISE: ~a\n" (exn-message e)))])
    (if (module-declared? sub #t)
        (dynamic-require sub #f)
        (dynamic-require `(file ,(path->string f)) #f))))
(test-log #:display? #t #:exit? #f)
