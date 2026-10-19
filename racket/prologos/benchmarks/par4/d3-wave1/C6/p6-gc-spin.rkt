#lang racket/base
;; C6 probe 6 — GC (stop-the-world) and spinning executors.
;; An allocator thread produces short-lived garbage (forcing minor GCs) while 3 other parallel
;; threads either do nothing, spin on a box (no allocation), or are parked on a semaphore.
;; Each spinner records the largest gap it observed between consecutive 4096-iteration
;; checkpoints: that is the pause the GC imposed on an executor that never allocates.
;; GC count and GC ms come from the 'GC log (counts are main evidence; ms secondary).
(require racket/fixnum)

(define (gc-receiver) (make-log-receiver (current-logger) 'debug 'GC))
(define (drain r)
  (let loop ([n 0] [maj 0] [ms 0.0] [cpuacc 0.0] [mx 0.0])
    (define v (sync/timeout 0 r))
    (if (not v) (list 'gcs n 'major maj 'gc-wall-ms (round ms) 'gc-process-cpu-ms (round cpuacc) 'max-gc-ms mx)
        (let ([d (vector-ref v 2)])
          (if (and (struct? d) (vector? (struct->vector d)) (> (vector-length (struct->vector d)) 10))
              (let* ([sv (struct->vector d)]
                     [mode (vector-ref sv 1)]
                     [wall (- (vector-ref sv 10) (vector-ref sv 9))]
                     [cpu (- (vector-ref sv 8) (vector-ref sv 7))])
                (loop (add1 n) (if (eq? mode 'major) (add1 maj) maj) (+ ms wall) (+ cpuacc cpu) (max mx wall)))
              (loop n maj ms cpuacc mx))))))

(define (churn n) ; ~n short-lived 10-element lists
  (let loop ([i 0] [acc 0])
    (if (fx= i n) acc
        (let ([l (for/list ([j (in-range 10)]) j)])
          (loop (fx+ i 1) (fxand (fx+ acc (car l)) 1023))))))

(define (run mode)
  (collect-garbage)
  (define r (gc-receiver))
  (define stop (box #f))
  (define parked (make-semaphore 0))
  (define gaps (make-vector 3 0.0))
  (define helpers
    (for/list ([k 3])
      (case mode
        [(none) #f]
        [(spin)
         (thread #:pool 'own
                 (lambda ()
                   (let loop ([i 0] [last (current-inexact-monotonic-milliseconds)] [mx 0.0])
                     (cond
                       [(unbox stop) (vector-set! gaps k mx)]
                       [(fx= 0 (fxand i 4095))
                        (let ([t (current-inexact-monotonic-milliseconds)])
                          (loop (fx+ i 1) t (max mx (- t last))))]
                       [else (loop (fx+ i 1) last mx)]))))]
        [(park) (thread #:pool 'own (lambda () (semaphore-wait parked)))])))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define a (thread #:pool 'own (lambda () (churn 3000000))))
  (thread-wait a)
  (define wall (- (current-inexact-monotonic-milliseconds) t0))
  (set-box! stop #t)
  (for ([k 3]) (semaphore-post parked))
  (for ([h helpers]) (when h (thread-wait h)))
  (list mode 'allocator-wall-ms (round wall) (drain r)
        'spinner-max-gap-ms (for/list ([g gaps]) (/ (round (* 1000 g)) 1000.0))))

(for ([rep 2])
  (for ([m '(none park spin)]) (printf "~s\n" (run m))))
