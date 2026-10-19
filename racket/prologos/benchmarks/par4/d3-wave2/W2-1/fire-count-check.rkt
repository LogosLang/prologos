#lang racket/base
;; W2-1 side check: does the fire COUNT depend on the executor (production thread executor vs sequential) or on
;; preloading?  usage: racket fire-count-check.rkt FILE (prod|seq) (preload|nopreload) [reps]
(require racket/port
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-parallel-executor sequential-fire-all))
(define a (current-command-line-arguments))
(define f (vector-ref a 0)) (define mode (vector-ref a 1)) (define pre (vector-ref a 2))
(define reps (if (> (vector-length a) 3) (string->number (vector-ref a 3)) 3))
(define prod (current-parallel-executor))
(define (run* g)
  (with-handlers ([exn:fail? (λ (e) 'raised)])
    (parameterize ([current-output-port (open-output-nowhere)] [current-error-port (open-output-nowhere)]
                   [current-use-pnet-cache? #t] [current-pnet-write-enabled? #f])
      (process-file g) 'ok)))
(when (equal? pre "preload")
  (run* "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/par4/preload-empty.prologos"))
(define counts
  (for/list ([i reps])
    (define n 0) (define calls 0)
    (define base (if (equal? mode "prod") prod sequential-fire-all))
    (define (exec snap pids) (set! n (+ n (length pids))) (set! calls (add1 calls)) (base snap pids))
    (parameterize ([current-parallel-executor exec]) (run* f))
    (list n calls)))
(printf "~a ~a ~a: (fires rounds) per rep ~s\n" (car (reverse (regexp-split #rx"/" f))) mode pre counts)
