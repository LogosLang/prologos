#lang racket/base
;; C7 probe 2: recompute P0 §2.2/§10.2's per-file models (H-S = remove BSP merge phase; K=8 = fire time
;; divided by min(width, 8) + merge + L) from round stats of the FIRST run after preload (what P0's
;; single-run `stats` used) and of WARM runs, in one process, plus measured legs with the executors that
;; exist today (thread-per-round; persistent pool K=8). Counts (rounds, fires) are the sanity check.
(require racket/port racket/list racket/string
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define root "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define pre (string-append root "benchmarks/par4/preload-empty.prologos"))
(define fname (or (getenv "C7_FILE") "constraints-adversarial.prologos"))
(define target (string-append root "benchmarks/comparative/" fname))
(define reps (string->number (or (getenv "C7_REPS") "3")))
(define (r2 x) (/ (round (* 100 x)) 100.0))

(define (run-file f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)]
                 [current-pnet-write-enabled? #f])
    (process-file f)))
(void (run-file pre))

(define (leg name exec)
  (define rounds (box '()))
  (collect-garbage 'major)
  (define g0 (current-gc-milliseconds))
  (define t0 (current-inexact-monotonic-milliseconds))
  (parameterize ([current-bsp-round-stats rounds]
                 [current-parallel-executor exec])
    (void (run-file target)))
  (define wall (- (current-inexact-monotonic-milliseconds) t0))
  (define gc (- (current-gc-milliseconds) g0))
  (define rs (unbox rounds))
  (define fire (for/sum ([r rs]) (cadr r)))
  (define merge (for/sum ([r rs]) (caddr r)))
  (define fire-wide (for/sum ([r rs] #:when (>= (car r) 8)) (cadr r)))
  (define (s0-par K [L 0.001]) (for/sum ([r rs]) (+ (/ (cadr r) (min (max 1 (car r)) K)) (caddr r) L)))
  (define work (- wall gc))
  (define hs (/ work (- work merge)))
  (define k8 (/ work (+ (- work fire merge) (- (s0-par 8) merge))))   ; H-S + K=8: merge removed, fire / min(n,8)
  (define bspk8 (/ work (+ (- work fire merge) (s0-par 8))))          ; today's BSP K=8 model
  (printf "~a rounds=~a fires=~a fire=~a (in width>=8: ~a) merge=~a work(wall-gc)=~a gc=~a | MODEL H-S=~a BSP-K8=~a H-S+K8=~a\n"
          name (length rs) (apply + (map car rs)) (r2 fire) (r2 fire-wide) (r2 merge) (r2 work) gc
          (r2 hs) (r2 bspk8) (r2 k8)))

(printf "file ~a\n" fname)
(leg "first-run(seq)" #f)
(define pool (make-worker-pool 8))
(for ([i reps])
  (leg "warm seq " #f)
  (leg "warm thr-per-round" (make-parallel-thread-fire-all))
  (leg "warm pool-K8" (make-pool-executor pool)))
