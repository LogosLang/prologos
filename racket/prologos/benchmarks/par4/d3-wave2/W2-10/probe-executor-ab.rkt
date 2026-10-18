#lang racket/base
;; C2 probe: A/B of the production BSP executor (driver.rkt:567 make-parallel-thread-fire-all)
;; vs sequential-fire-all, on ONE corpus file, interleaved, S0 round stats only.
;; usage: racket probe-executor-ab.rkt FILE.prologos REPS
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
  (define rs (unbox rounds))
  ;; each entry: (n fire-ms merge-ms writes deferred)
  (define wide (filter (lambda (r) (>= (car r) 8)) rs))
  (list (- t1 t0)
        (for/sum ([r rs]) (cadr r)) (for/sum ([r rs]) (caddr r))
        (length rs) (length wide) (for/sum ([r wide]) (cadr r))))
(void (run! prod-exec)) ; warm
(define res (for*/list ([i reps] [which '(prod seq)])
              (cons which (run! (if (eq? which 'prod) prod-exec #f)))))
(define (med xs) (let ([s (sort xs <)]) (list-ref s (quotient (length s) 2))))
(for ([which '(prod seq)])
  (define rs (map cdr (filter (lambda (r) (eq? (car r) which)) res)))
  (printf "~a: wall-ms med ~a | S0 fire-ms med ~a | merge-ms med ~a | rounds ~a | rounds>=8 ~a | fire-ms in rounds>=8 med ~a\n"
          which (exact-round (med (map car rs)))
          (/ (exact-round (* 100 (med (map cadr rs)))) 100.0)
          (/ (exact-round (* 100 (med (map caddr rs)))) 100.0)
          (list-ref (car rs) 3) (list-ref (car rs) 4)
          (/ (exact-round (* 100 (med (map (lambda (r) (list-ref r 5)) rs)))) 100.0)))
(printf "raw: ~s\n" (for/list ([r res]) (list (car r) (exact-round (cadr r)) (/ (exact-round (* 100 (caddr r))) 100.0))))
