#lang racket/base
;; C7 probe: is P0 §2.2's MODEL column "today's BSP, K=8" (1.76x on constraints-adversarial)
;; measurable today with the executors that already exist in propagator.rkt?
;; Legs (interleaved, same process, prelude preloaded untimed):
;;   seq   : default sequential-fire-all
;;   thr   : make-parallel-thread-fire-all  (OS threads #:pool 'own, created per round, inherit the
;;           round's parameterization; rounds < 8 fires stay sequential)
;; Reported per leg: sum of BSP fire-phase ms (current-bsp-round-stats), merge ms, rounds, fires,
;; wall of process-file, and whether the printed results equal the seq leg's.
(require racket/port racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define root "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define pre (string-append root "benchmarks/par4/preload-empty.prologos"))
(define target (string-append root "benchmarks/comparative/"
                              (or (getenv "C7_FILE") "constraints-adversarial.prologos")))
(define reps (string->number (or (getenv "C7_REPS") "4")))

(define (run-file f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-pnet-write-enabled? #f])
    (process-file f)))

(void (run-file pre))

(define (leg name exec)
  (define rounds (box '()))
  (collect-garbage 'major)
  (define t0 (current-inexact-monotonic-milliseconds))
  (define res
    (parameterize ([current-bsp-round-stats rounds]
                   [current-parallel-executor exec])
      (run-file target)))
  (define wall (- (current-inexact-monotonic-milliseconds) t0))
  (define rs (unbox rounds))
  (define fire (for/sum ([r rs]) (cadr r)))
  (define merge (for/sum ([r rs]) (caddr r)))
  (define wide (filter (λ (r) (>= (car r) 8)) rs))
  (define fire-wide (for/sum ([r wide]) (cadr r)))
  (values (list name (length rs) (apply + (map car rs)) (length wide) fire fire-wide merge wall)
          (format "~s" res)))

(define (real->decimal-string* x) (if (exact-integer? x) (number->string x) (number->string (/ (round (* 100 x)) 100.0))))
(define (string-join* xs) (apply string-append (add-between (map (λ (x) (format "~a" x)) xs) " ")))
(define-values (_w0 ref) (leg "warm" #f))   ; warm-up, untimed, reference result
(printf "file ~a reps ~a\n" target reps)
(printf "leg rounds fires wide-rounds(>=8) fire-ms fire-ms-in-wide merge-ms wall-ms same-result\n")
(for ([i reps])
  (for ([l (list (cons "seq" #f) (cons "thr" (make-parallel-thread-fire-all)))])
    (define-values (row out) (leg (car l) (cdr l)))
    (printf "~a ~a\n" (string-join* (map (λ (x) (if (real? x) (real->decimal-string* x) x)) row))
            (equal? out ref))))
