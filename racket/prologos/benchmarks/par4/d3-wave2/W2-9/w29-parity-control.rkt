#lang racket/base
;; W2-9: does parity-adversarial raise under process-file with the PLAIN sequential executor (no census)?
(require racket/port racket/path
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt") process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt") current-parallel-executor sequential-fire-all))
(define f (vector-ref (current-command-line-arguments) 0))
(define which (vector-ref (current-command-line-arguments) 1))
(define r (with-handlers ([exn:fail? (λ (e) (format "RAISED: ~a" (car (regexp-split #rx"\n" (exn-message e)))))])
  (parameterize ([current-output-port (open-output-nowhere)] [current-use-pnet-cache? #t] [current-pnet-write-enabled? #f]
                 [current-parallel-executor (if (equal? which "seq") sequential-fire-all (current-parallel-executor))])
    (process-file f) "ok")))
(printf "~a executor=~a: ~a\n" (path->string (file-name-from-path f)) which r)
