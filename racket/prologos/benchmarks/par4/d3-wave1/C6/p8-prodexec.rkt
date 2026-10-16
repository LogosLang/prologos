#lang racket/base
;; C6 probe 8 — is production BSP already running fires on parallel threads?
;; driver.rkt:567 assigns (current-parallel-executor (make-parallel-thread-fire-all)).
;; This probe wraps whatever executor is installed, counts BSP rounds by width, estimates the
;; parallel threads created (propagator.rkt:3699-3722: chunk-size = max(1, n / processor-count)),
;; and sums the time spent inside the executor.  EXEC=par keeps the production executor;
;; EXEC=seq installs `sequential-fire-all` (the fallback at propagator.rkt:3404).
;; One .prologos file per process; the .pnet cache is read but never written.
(require racket/future racket/port
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define file (vector-ref (current-command-line-arguments) 0))
(define mode (or (getenv "EXEC") "par"))
(define orig (current-parallel-executor))
(printf "installed executor at load: ~a (procedure? ~a)\n" orig (procedure? orig))
(define ncores (processor-count))
(define calls 0) (define wide 0) (define fires 0) (define wide-fires 0) (define threads 0)
(define wide-ms 0.0) (define narrow-ms 0.0) (define wide-bytes 0) (define all-bytes 0) (define all-ms 0.0)
(define base (if (equal? mode "seq") sequential-fire-all orig))
(define (wrapped snap pids)
  (define n (length pids))
  (define b0 (current-memory-use 'cumulative))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define r (base snap pids))
  (define dt (- (current-inexact-monotonic-milliseconds) t0))
  (define db (- (current-memory-use 'cumulative) b0))
  (set! all-bytes (+ all-bytes db)) (set! all-ms (+ all-ms dt))
  (set! calls (add1 calls)) (set! fires (+ fires n))
  (cond [(>= n 8)
         (define cs (max 1 (quotient n ncores)))
         (set! wide (add1 wide)) (set! wide-fires (+ wide-fires n))
         (set! threads (+ threads (quotient (+ n cs -1) cs)))
         (set! wide-ms (+ wide-ms dt)) (set! wide-bytes (+ wide-bytes db))]
        [else (set! narrow-ms (+ narrow-ms dt))])
  r)
(current-parallel-executor wrapped)
(define t0 (current-inexact-monotonic-milliseconds))
(void (parameterize ([current-output-port (open-output-nowhere)]
                     [current-use-pnet-cache? #t]
                     [current-pnet-write-enabled? #f])
        (process-file file)))
(define wall (- (current-inexact-monotonic-milliseconds) t0))
(printf "mode ~a file ~a\n" mode file)
(printf "  BSP rounds through the executor: ~a (fires ~a); width>=8: ~a rounds, ~a fires, ~a parallel threads created (est.)\n"
        calls fires wide wide-fires threads)
(printf "  executor time: width>=8 ~a ms (~a us/fire), width<8 ~a ms; process-file wall ~a ms (incl. prelude load)\n"
        (round wide-ms) (if (zero? wide-fires) 'na (/ (round (* 10 (/ (* 1000 wide-ms) wide-fires))) 10.0))
        (round narrow-ms) (round wall))
(printf "  executor bytes: all rounds ~a KB (~a B/fire, ~a B/us); width>=8 ~a KB (~a B/fire)\n"
        (round (/ all-bytes 1000)) (round (/ all-bytes (max fires 1))) (round (/ all-bytes (max 1 (* 1000 all-ms))))
        (round (/ wide-bytes 1000)) (round (/ wide-bytes (max wide-fires 1))))
