#lang racket/base
;; W2-1 coverage check: on a file where the injected executor saw 0 fires, does S0 run at all?
;; Counts calls of the elaborator's quiescence scheduler (metavar-store.rkt:1766), the worklist length at entry,
;; whether the Tier-1 precondition (fire-once + empty inputs for every queued propagator, propagator.rkt:3412-3430)
;; held, and executor calls.  POWER: on constraints-adversarial the executor must see > 0 fires.
(require racket/port
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-parallel-executor sequential-fire-all prop-network-worklist prop-network-propagators
                  propagator-flags PROP-FIRE-ONCE PROP-EMPTY-INPUTS prop-id-hash)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt") champ-lookup)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/metavar-store.rkt")
                  current-quiescence-scheduler))
(define f (vector-ref (current-command-line-arguments) 0))
(define (run* g)
  (with-handlers ([exn:fail? (λ (e) (exn-message e))])
    (parameterize ([current-output-port (open-output-nowhere)] [current-error-port (open-output-nowhere)]
                   [current-use-pnet-cache? #t] [current-pnet-write-enabled? #f])
      (process-file g) 'ok)))
(run* "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/par4/preload-empty.prologos")
(define q-calls 0) (define q-nonempty 0) (define q-tier1 0) (define q-wl 0)
(define ex-calls 0) (define ex-fires 0)
(define orig (current-quiescence-scheduler))
(define (wrapped net)
  (set! q-calls (add1 q-calls))
  (define wl (prop-network-worklist net))
  (when (pair? wl)
    (set! q-nonempty (add1 q-nonempty)) (set! q-wl (+ q-wl (length wl)))
    (when (for/and ([pid wl])
            (define p (champ-lookup (prop-network-propagators net) (prop-id-hash pid) pid))
            (and (not (eq? p 'none))
                 (= (bitwise-and (propagator-flags p) (bitwise-ior PROP-FIRE-ONCE PROP-EMPTY-INPUTS))
                    (bitwise-ior PROP-FIRE-ONCE PROP-EMPTY-INPUTS))))
      (set! q-tier1 (add1 q-tier1))))
  (orig net))
(define (exec snap pids) (set! ex-calls (add1 ex-calls)) (set! ex-fires (+ ex-fires (length pids))) (sequential-fire-all snap pids))
(define r (parameterize ([current-quiescence-scheduler wrapped] [current-parallel-executor exec]) (run* f)))
(printf "~a: result ~a | quiescence calls ~a, with non-empty worklist ~a (queued ~a), of which Tier-1-shaped ~a | executor calls ~a fires ~a\n"
        (car (reverse (regexp-split #rx"/" f))) (if (string? r) "raised" r) q-calls q-nonempty q-wl q-tier1 ex-calls ex-fires)
