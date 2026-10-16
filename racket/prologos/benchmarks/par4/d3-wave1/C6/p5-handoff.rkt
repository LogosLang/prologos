#lang racket/base
;; C6 probe 5 — park/unpark and spin costs between two `#:pool 'own` threads, plus the
;; single-thread cost of the fences and of box-cas!, and box-cas! spurious failures (aarch64
;; LL/SC).  Wall-clock rows are secondary evidence (machine shared; load printed by the runner).
(require racket/fixnum racket/future racket/unsafe/ops)

(define R 20000)   ; round trips per handoff row
(define (now) (current-inexact-monotonic-milliseconds))

(define (pingpong-sema)
  (define s1 (make-semaphore 0)) (define s2 (make-semaphore 0))
  (define b (thread #:pool 'own (lambda () (for ([i R]) (semaphore-wait s1) (semaphore-post s2)))))
  (define a (thread #:pool 'own
                    (lambda () (for ([i R]) (semaphore-post s1) (semaphore-wait s2)))))
  (define t0 (now)) (thread-wait a) (thread-wait b)
  (/ (* 1e6 (- (now) t0)) (* 2 R)))

(define (pingpong-fsema)
  (define s1 (make-fsemaphore 0)) (define s2 (make-fsemaphore 0))
  (define b (thread #:pool 'own (lambda () (for ([i R]) (fsemaphore-wait s1) (fsemaphore-post s2)))))
  (define a (thread #:pool 'own
                    (lambda () (for ([i R]) (fsemaphore-post s1) (fsemaphore-wait s2)))))
  (define t0 (now)) (thread-wait a) (thread-wait b)
  (/ (* 1e6 (- (now) t0)) (* 2 R)))

(define (pingpong-spin)
  (define x (box 0)) (define pad (make-vector 32 0)) (define y (box 0))
  (define RR (* 10 R))
  (define b (thread #:pool 'own
                    (lambda ()
                      (let loop ([i 1])
                        (when (fx<= i RR)
                          (let wait () (unless (fx= (unbox x) i) (wait)))
                          (memory-order-acquire)
                          (memory-order-release)
                          (set-box! y i)
                          (loop (fx+ i 1)))))))
  (define a (thread #:pool 'own
                    (lambda ()
                      (let loop ([i 1])
                        (when (fx<= i RR)
                          (memory-order-release)
                          (set-box! x i)
                          (let wait () (unless (fx= (unbox y) i) (wait)))
                          (memory-order-acquire)
                          (loop (fx+ i 1)))))))
  (define t0 (now)) (thread-wait a) (thread-wait b)
  (/ (* 1e6 (- (now) t0)) (* 2 RR)))

(define M 20000000)
(define (single label f)
  (define t0 (now))
  (define r (f))
  (printf "  ~a: ~a ns/op ~a\n" label (/ (* 1e6 (- (now) t0)) M) r))
(define bx (box 0))
(printf "one-way hop, two parallel threads (ns):\n")
(for ([rep 2])
  (printf "  semaphore ~a | fsemaphore ~a | box spin + fences ~a\n"
          (pingpong-sema) (pingpong-fsema) (pingpong-spin)))
(printf "single-thread costs, M=~a:\n" M)
(single "set-box! fixnum (plain)" (lambda () (for ([i (in-range M)]) (set-box! bx i)) ""))
(single "memory-order-release + set-box! fixnum" (lambda () (for ([i (in-range M)]) (memory-order-release) (set-box! bx i)) ""))
(single "unbox + memory-order-acquire" (lambda () (for/fold ([a 0]) ([i (in-range M)]) (define v (unbox bx)) (memory-order-acquire) (fxand (fx+ a v) 1023))))
(single "box-cas! fixnum (uncontended), spurious-failure count"
        (lambda ()
          (set-box! bx 0)
          (let loop ([i 0] [fails 0])
            (if (fx= i M) (list 'spurious-failures fails)
                (let ([c (unbox bx)])
                  (if (box-cas! bx c (fx+ c 1)) (loop (fx+ i 1) fails) (loop (fx+ i 1) (fx+ fails 1))))))))
