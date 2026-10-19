#lang racket/base
;;; W2-2 timing harness (PAR 4 D.3 wave 2). Runs against the SCRATCH tree's build.
;;;   W22_EXEC_OFF / W22_KEYED_DIFF are read by the scratch driver/propagator at module load.
;;;   racket w22-time.rkt LEG REPS FILE...
;;; Per file: 1 untimed warm-up, then REPS timed process-file calls (major GC before each, not timed).
;;; Prints one line per file: W22T:{json}. Prelude preloaded in-process first (untimed), .pnet writes off.
;;; "command time" here = wall ms of process-file on the target after the preload (imports are already
;;; in the in-process module cache), which is process-command work plus the file's parse.
(require racket/list racket/port racket/string json
         (only-in (file "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2/tree/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in (file "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2/tree/racket/prologos/propagator.rkt")
                  current-bsp-round-stats current-parallel-executor))
(define args (current-command-line-arguments))
(define leg (vector-ref args 0))
(define reps (string->number (vector-ref args 1)))
(define files (for/list ([i (in-range 2 (vector-length args))]) (vector-ref args i)))
(define preload "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2/tree/racket/prologos/benchmarks/par4/preload-empty.prologos")
(define write-pnet? (equal? (getenv "W22_PNET_WRITE") "1"))
(define (run-file* f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)]
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? write-pnet?])
    (process-file f)))
(void (run-file* preload))
(define (r2 x) (/ (round (* 100 (exact->inexact x))) 100.0))
(define (fingerprint results)
  ;; order-sensitive digest of the printed results (gensym-free fields only would be nicer; this is a coarse check)
  (define s (format "~s" results))
  (list (length results) (equal-hash-code (regexp-replace* #px"[0-9]+" s "#"))))
(for ([f (in-list files)])
  (define fp0 (fingerprint (run-file* f)))                      ; warm-up (untimed)
  (define rows
    (for/list ([_ (in-range reps)])
      (define rounds (box '()))
      (collect-garbage) (collect-garbage)
      (define gc0 (current-gc-milliseconds)) (define cpu0 (current-process-milliseconds))
      (define t0 (current-inexact-monotonic-milliseconds))
      (define res (parameterize ([current-bsp-round-stats rounds]) (run-file* f)))
      (define t1 (current-inexact-monotonic-milliseconds))
      (define cpu (- (current-process-milliseconds) cpu0)) (define gc (- (current-gc-milliseconds) gc0))
      (define rs (unbox rounds))   ; each: (n fire-ms merge-ms writes deferred)
      (list (- t1 t0) cpu gc (for/sum ([r rs]) (cadr r)) (for/sum ([r rs]) (caddr r)) (length rs)
            (fingerprint res))))
  (printf "W22T:~a\n"
          (jsexpr->string
           (hasheq 'leg leg 'file (let-values ([(b n d) (split-path f)]) (path->string n))
                   'exec_off (and (getenv "W22_EXEC_OFF") #t) 'keyed (and (getenv "W22_KEYED_DIFF") #t)
                   'executor_installed (and (current-parallel-executor) #t)
                   'wall (map (λ (r) (r2 (list-ref r 0))) rows)
                   'cpu (map (λ (r) (list-ref r 1)) rows)
                   'gc (map (λ (r) (list-ref r 2)) rows)
                   'fire_ms (map (λ (r) (r2 (list-ref r 3))) rows)
                   'merge_ms (map (λ (r) (r2 (list-ref r 4))) rows)
                   'rounds (map (λ (r) (list-ref r 5)) rows)
                   'fp (cons fp0 (map (λ (r) (list-ref r 6)) rows)))))
  (flush-output))
