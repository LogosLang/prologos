#lang racket/base
;; W2-4 Q2 power rows: can fires on the PRODUCTION thread executor (make-parallel-thread-fire-all, #:pool 'own)
;; race on (a) a shared box read-modify-written through current-prop-net-box, as resolution.rkt:373-386's retry
;; bridge does, and (b) a perf counter incremented with perf-inc-reduce! (a non-atomic struct-field RMW)?
;; Network: one seed cell, W propagators reading it, each writing its own output cell; every fire does
;; ITER box RMWs and ITER perf increments. Expected totals: W*ITER for both. Sequential executor = control.
(require racket/future
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/performance-counters.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/metavar-store.rkt")
                  current-prop-net-box))
(define W (string->number (or (getenv "W") "16")))
(define ITER (string->number (or (getenv "ITER") "20000")))
(define (build)
  (define net0 (make-prop-network))
  (define-values (net1 seed) (net-new-cell net0 0 max))
  (for/fold ([n net1]) ([i (in-range W)])
    (define-values (n2 out) (net-new-cell n 0 max))
    (define-values (n3 _p)
      (net-add-propagator n2 (list seed) (list out)
        (lambda (net)
          (define nb (current-prop-net-box))
          (for ([k (in-range ITER)])
            (define v (unbox nb))           ; read ...
            (set-box! nb (add1 v))          ; ... modify-write (the retry bridge's unbox / set-box! shape)
            (perf-inc-reduce!))
          (net-cell-write net out (add1 (net-cell-read net seed))))))
    n3))
(define (run label exec)
  (define nb (box 0))
  (define pc (perf-counters 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0))
  (define net2 (build))   ; every propagator is on the worklist at install => one round of width W
  (parameterize ([current-prop-net-box nb] [current-perf-counters pc] [current-parallel-executor exec])
    (run-to-quiescence net2))
  (printf "~a: W=~a ITER=~a expected ~a | box total ~a (lost ~a) | perf reduce-steps ~a (lost ~a)\n"
          label W ITER (* W ITER) (unbox nb) (- (* W ITER) (unbox nb))
          (perf-counters-reduce-steps pc) (- (* W ITER) (perf-counters-reduce-steps pc))))
(printf "processor-count ~a\n" (processor-count))
(for ([i 3]) (run "production thread executor" (make-parallel-thread-fire-all)))
(run "sequential-fire-all (control)" sequential-fire-all)
