#lang racket/base
;; W2-10 predictability probe (adapted from d3-wave1/C2/probe-executor-ab.rkt): run-to-run DISPERSION of
;; whole-file elaboration time, production thread executor (today's K>1-ish path) vs sequential,
;; interleaved in one process. Reports min / median / p90 / max / CV per leg, and the S0 fire-phase share.
;; usage: racket variance.rkt FILE.prologos REPS
(require racket/port racket/list racket/math
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define args (current-command-line-arguments))
(define file (vector-ref args 0))
(define reps (string->number (vector-ref args 1)))
(define prod-exec (current-parallel-executor))
(define (run! exec)
  (define rounds (box '()))
  (collect-garbage) (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (parameterize ([current-parallel-executor exec]
                 [current-bsp-round-stats rounds]
                 [current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (process-file file))
  (define t1 (current-inexact-monotonic-milliseconds))
  (list (- t1 t0) (for/sum ([r (unbox rounds)] #:when (>= (car r) 8)) (cadr r))))
(void (run! prod-exec)) (void (run! sequential-fire-all)) ; warm
(define res (for*/list ([i reps] [which '(prod seq)])
              (cons which (run! (if (eq? which 'prod) prod-exec sequential-fire-all)))))
(define (stats xs)
  (define s (sort xs <)) (define n (length s))
  (define mean (/ (apply + s) n))
  (define sd (sqrt (/ (for/sum ([x s]) (sqr (- x mean))) (max 1 (- n 1)))))
  (list (first s) (list-ref s (quotient n 2)) (list-ref s (min (- n 1) (exact-floor (* 0.9 n)))) (last s)
        (/ (round (* 1000 (/ sd mean))) 1000.0)))
(for ([which '(prod seq)])
  (define rs (map cdr (filter (λ (r) (eq? (car r) which)) res)))
  (define w (stats (map car rs)))
  (define f (stats (map cadr rs)))
  (printf "~a: wall-ms min ~a med ~a p90 ~a max ~a CV ~a | wide-round fire-ms min ~a med ~a max ~a CV ~a\n"
          which (exact-round (list-ref w 0)) (exact-round (list-ref w 1)) (exact-round (list-ref w 2))
          (exact-round (list-ref w 3)) (list-ref w 4)
          (/ (round (* 10 (list-ref f 0))) 10.0) (/ (round (* 10 (list-ref f 1))) 10.0)
          (/ (round (* 10 (list-ref f 3))) 10.0) (list-ref f 4)))
(printf "raw: ~s\n" (for/list ([r res]) (list (car r) (exact-round (cadr r)) (/ (round (* 10 (caddr r))) 10.0))))
