#lang racket/base
;;; C10 probe: where does pu-value-diff's time sit — inside fires (the diff whose dependents result the
;;; BSP protocol DISCARDS with the snapshot's worklist, and which DIRECT keeps), inside bulk-merge-writes
;;; (the re-diff DIRECT removes), or outside the BSP loop? Raw sampler stacks, 1 ms, one file per process.
;;;   racket split-probe.rkt FILE.prologos REPS
(require racket/list racket/port json profile/sampler
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?))
(define args (current-command-line-arguments))
(define file (vector-ref args 0))
(define reps (string->number (vector-ref args 1)))
(define preload "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/par4/preload-empty.prologos")
(define (run-file* f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)]
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? #f])
    (process-file f)))
(run-file* preload)
(define th (current-thread))
(define sampler (create-sampler th 0.001))
(for ([_ (in-range reps)]) (run-file* file))
(sampler 'stop)
(define snaps (cdr (sampler (quote get-snapshots))))   ; (cons total-time samples), as profile/analyzer reads it
;; each snapshot: (list* thread-id timestamp stack) ; stack: list of (name . srcloc), innermost first
(define (names s) (for/list ([fr (in-list (cddr s))]) (and (pair? fr) (car fr))))
(define counts (make-hash))
(define (inc! k) (hash-set! counts k (add1 (hash-ref counts k 0))))
(for ([s (in-list snaps)])
  (define ns (names s))
  (inc! 'all)
  (when (memq 'process-command ns) (inc! 'process-command))
  (when (memq 'run-to-quiescence-bsp ns) (inc! 'bsp))
  (when (memq 'fire-and-collect-writes ns) (inc! 'fire-and-collect-writes))
  (when (memq 'bulk-merge-writes ns) (inc! 'bulk-merge-writes))
  (when (memq 'pu-value-diff ns)
    (inc! 'pu-value-diff)
    (cond [(memq 'bulk-merge-writes ns) (inc! 'pu/bulk)]
          [(memq 'fire-and-collect-writes ns) (inc! 'pu/in-fire)]
          [(memq 'run-to-quiescence-bsp ns) (inc! 'pu/bsp-other)]
          [else (inc! 'pu/outside-bsp)]))
  (when (memq 'filter-dependents-by-paths ns)
    (inc! 'filter-deps)
    (cond [(memq 'bulk-merge-writes ns) (inc! 'filter-deps/bulk)]
          [(memq 'fire-and-collect-writes ns) (inc! 'filter-deps/in-fire)]
          [else (inc! 'filter-deps/other)]))
  (when (memq 'net-cell-write/slow-path ns) (inc! 'slow-path))
  (when (memq 'attribute-map-merge-fn ns)
    (inc! 'merge)
    (cond [(memq 'bulk-merge-writes ns) (inc! 'merge/bulk)]
          [(memq 'fire-and-collect-writes ns) (inc! 'merge/in-fire)]
          [else (inc! 'merge/other)])))
(printf "C10SPLIT:~a\n" (jsexpr->string (for/hasheq ([(k v) counts]) (values k v))))
