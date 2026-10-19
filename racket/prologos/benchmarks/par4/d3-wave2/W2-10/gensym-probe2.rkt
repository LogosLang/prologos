#lang racket/base
;; W2-10: final gensym counter after process-file, by leg (prod|seq) and observer (on|off). One file, one process.
(require racket/port
 (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
 (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define args (current-command-line-arguments))
(define f (vector-ref args 0))
(define leg (vector-ref args 1))
(define obs? (equal? (vector-ref args 2) "on"))
(define prod (current-parallel-executor))
(define rs (parameterize ([current-output-port (open-output-nowhere)] [current-error-port (open-output-nowhere)]
                          [current-parallel-executor (if (equal? leg "prod") prod sequential-fire-all)]
                          [current-bsp-observer (and obs? (λ (r) (void)))])
        (process-file f)))
(define names (for/list ([r rs] #:when (regexp-match? #rx"_g[0-9]" (format "~a" r)))
                (regexp-match* #rx"[a-z]+_g[0-9]+" (format "~a" r))))
(printf "~a obs=~a end=~a names=~a\n" leg obs? (gensym) names)
