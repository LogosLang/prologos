#lang racket/base
;;; W2-2 single-instrument split (adapted from d3-wave1/C10/split-probe.rkt) against the SCRATCH build.
;;; Raw sampler stacks of the MAIN thread, 1 ms. Meaningful only with W22_EXEC_OFF=1 (with the thread
;;; executor on, wide-round fires run on other threads and the main-thread sampler does not see them).
;;;   racket w22-split.rkt FILE.prologos REPS
(require racket/list racket/port json profile/sampler
         (only-in (file "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2/tree/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in (file "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2/tree/racket/prologos/propagator.rkt")
                  current-parallel-executor))
(define args (current-command-line-arguments))
(define file (vector-ref args 0))
(define reps (string->number (vector-ref args 1)))
(define preload "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2/tree/racket/prologos/benchmarks/par4/preload-empty.prologos")
(define (run-file* f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)]
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? #f])
    (process-file f)))
(void (run-file* preload))
(void (run-file* file))                       ; warm-up
(define th (current-thread))
(define sampler (create-sampler th 0.001))
(define t0 (current-inexact-monotonic-milliseconds))
(for ([_ (in-range reps)]) (run-file* file))
(define wall (- (current-inexact-monotonic-milliseconds) t0))
(sampler 'stop)
(define snaps (cdr (sampler 'get-snapshots)))
(define (names s) (for/list ([fr (in-list (cddr s))]) (and (pair? fr) (car fr))))
(define counts (make-hash))
(define (inc! k) (hash-set! counts k (add1 (hash-ref counts k 0))))
(define (diff? ns) (or (memq 'pu-value-diff ns) (memq 'w22-keyed-diff ns)))
(for ([s (in-list snaps)])
  (define ns (names s))
  (inc! 'all)
  (when (memq 'process-command ns) (inc! 'process-command))
  (when (memq 'process-file ns) (inc! 'process-file))
  (when (memq 'run-to-quiescence-bsp ns) (inc! 'bsp))
  (when (diff? ns) (inc! 'diff-all))
  (when (memq 'attribute-map-merge-fn ns) (inc! 'merge-all))
  (cond
    [(memq 'bulk-merge-writes ns)
     (inc! 'bulk)
     (cond [(diff? ns) (inc! 'bulk/diff)]
           [(memq 'attribute-map-merge-fn ns) (inc! 'bulk/merge)]
           [else (inc! 'bulk/other)])]
    [(memq 'fire-and-collect-writes ns)
     (inc! 'fcw)
     ;; callee of fire-and-collect-writes (the frame just inside it) and innermost frame
     (let* ([rev (let loop ([l ns] [prev #f]) (cond [(null? l) prev] [(eq? (car l) 'fire-and-collect-writes) prev] [else (loop (cdr l) (car l))]))])
       (inc! (string->symbol (format "fcw-callee:~a" rev)))
       ;; innermost named frame, and whether the sample sits under a write (net-cell-write) or champ diff
       (inc! (string->symbol (format "fcw-inner:~a" (for/first ([n (in-list ns)] #:when n) n))))
       (inc! (cond [(memq 'champ-node-diff ns) 'fcw-class:champ-diff]
                   [(or (memq 'net-cell-write/slow-path ns) (memq 'net-cell-write ns)) 'fcw-class:under-write]
                   [(eq? (for/first ([n (in-list ns)] #:when n) n) 'fire-and-collect-writes) 'fcw-class:fcw-self]
                   [(memq 'net-cell-read-raw ns) 'fcw-class:read-raw]
                   [else 'fcw-class:other])))
     (cond [(memq 'fire-propagator ns)
            (inc! 'fcw/body)
            (cond [(diff? ns) (inc! 'fcw/body/diff)]
                  [(memq 'attribute-map-merge-fn ns) (inc! 'fcw/body/merge)]
                  [else (inc! 'fcw/body/other)])]
           [(memq 'champ-diff ns) (inc! 'fcw/ceremony/champ-diff)]
           [else (inc! 'fcw/ceremony/other)])]
    [(memq 'run-to-quiescence-bsp ns) (inc! 'bsp/other)]
    [(memq 'process-command ns)
     (inc! 'outside)
     (cond [(diff? ns) (inc! 'outside/diff)]
           [(memq 'attribute-map-merge-fn ns) (inc! 'outside/merge)]
           [else (inc! 'outside/other)])]
    [else (inc! 'not-in-command)]))
(printf "W22SPLIT:~a\n"
        (jsexpr->string
         (for/fold ([h (hasheq 'file (let-values ([(b n d) (split-path file)]) (path->string n))
                               'reps reps 'wall_ms_per_rep (/ (round (* 100 (/ wall reps))) 100.0)
                               'exec_off (and (getenv "W22_EXEC_OFF") #t) 'keyed (and (getenv "W22_KEYED_DIFF") #t)
                               'delta_writes (and (getenv "W22_DELTA_WRITES") #t)
                               'executor_installed (and (current-parallel-executor) #t))])
                   ([(k v) counts])
           (hash-set h k v))))
