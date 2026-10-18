#lang racket/base
;; W2-10: is the gensym counter already run-dependent before process-file runs?
(require racket/port
 (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt"))
(define f (vector-ref (current-command-line-arguments) 0))
(define before (gensym))
(void (parameterize ([current-output-port (open-output-nowhere)] [current-error-port (open-output-nowhere)])
        (process-file f)))
(printf "before ~a after ~a\n" before (gensym))
