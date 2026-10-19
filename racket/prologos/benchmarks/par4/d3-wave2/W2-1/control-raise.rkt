#lang racket/base
;; W2-1 control: does process-file raise on this file with the PRODUCTION executor and no observer?
(require racket/port
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-parallel-executor sequential-fire-all))
(define f (vector-ref (current-command-line-arguments) 0))
(define mode (vector-ref (current-command-line-arguments) 1))
(define r
  (with-handlers ([exn:fail? (λ (e) (list 'raised (exn-message e)))])
    (parameterize ([current-output-port (open-output-nowhere)]
                   [current-error-port (open-output-nowhere)]
                   [current-use-pnet-cache? #t] [current-pnet-write-enabled? #f]
                   [current-parallel-executor (if (equal? mode "seq") sequential-fire-all (current-parallel-executor))])
      (process-file f)
      'ok)))
(printf "~a ~a: ~s\n" mode f r)
