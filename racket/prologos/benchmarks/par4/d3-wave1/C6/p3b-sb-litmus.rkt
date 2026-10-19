#lang racket/base
;; C6 probe 3b — store-buffering (SB / Dekker) litmus between two `#:pool 'own` threads.
;; This is the ordering that D.2 §6.7's late-write check needs: an executor publishes a write,
;; then reads boundary-epoch; the detector publishes boundary-epoch, then reads the executors'
;; state.  A: x := i ; [fence] ; rA := y      B: y := i ; [fence] ; rB := x
;; Under sequential consistency at least one of rA, rB equals i.  Violation: both < i.
;; The two threads run in lockstep (spin barrier on per-thread done counters).
(require racket/fixnum)
(define N 1000000)
(define (pad) (make-vector 32 0))

(define (sb fence ptr?)
  (define x (box 0)) (define _1 (pad)) (define y (box 0)) (define _2 (pad))
  (define da (box 0)) (define _3 (pad)) (define db (box 0)) (define _4 (pad))
  (define ra (make-fxvector (add1 N) 0)) (define rb (make-fxvector (add1 N) 0))
  (define (val i) (if ptr? (cons i i) i))
  (define (num v) (if (pair? v) (car v) v))
  (define (fence!) (case fence [(release) (memory-order-release)] [(acquire) (memory-order-acquire)] [else (void)]))
  (define a (thread #:pool 'own
                    (lambda ()
                      (let loop ([i 1])
                        (when (fx<= i N)
                          (let wait () (unless (fx>= (unbox db) (fx- i 1)) (wait)))
                          (set-box! x (val i)) (fence!)
                          (fxvector-set! ra i (num (unbox y)))
                          (set-box! da i)
                          (loop (fx+ i 1)))))))
  (define b (thread #:pool 'own
                    (lambda ()
                      (let loop ([i 1])
                        (when (fx<= i N)
                          (let wait () (unless (fx>= (unbox da) (fx- i 1)) (wait)))
                          (set-box! y (val i)) (fence!)
                          (fxvector-set! rb i (num (unbox x)))
                          (set-box! db i)
                          (loop (fx+ i 1)))))))
  (thread-wait a) (thread-wait b)
  (for/sum ([i (in-range 1 (add1 N))])
    (if (and (fx< (fxvector-ref ra i) i) (fx< (fxvector-ref rb i) i)) 1 0)))

(printf "SB litmus, N=~a lockstep iterations; count of iterations where neither thread saw the other's write\n" N)
(for ([rep 2])
  (printf "  fixnum stores, no fence:                    ~a\n" (sb 'none #f))
  (printf "  pointer stores (auto dmb ishst), no fence:  ~a\n" (sb 'none #t))
  (printf "  fixnum, memory-order-acquire between:       ~a\n" (sb 'acquire #f))
  (printf "  fixnum, memory-order-release between:       ~a\n" (sb 'release #f))
  (printf "  pointer, memory-order-acquire between:      ~a\n" (sb 'acquire #t))
  (printf "  pointer, memory-order-release between:      ~a\n" (sb 'release #t)))
