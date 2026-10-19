#lang racket/base
;; C6 probe 7 — allocation from several parallel threads (K <= 4), same total work at every K.
;; Rows: fixnum compute (no allocation); short-lived cons churn; persistent CHAMP insert into a
;; 256-key map (path copy, the production write shape; results die young).  Per row: wall
;; (secondary), GCs and GC wall from the 'GC log, bytes allocated.  TRIP=<MB> raises
;; Chez collect-trip-bytes to test whether GC frequency, rather than the allocation-area
;; refill mutex (Chez c/alloc.c S_get_more_room_help), is what stops scaling.
(require racket/fixnum ffi/unsafe/vm
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt"))

(define trip (let ([t (getenv "TRIP")]) (and t (string->number t))))
(when trip (vm-eval `(collect-trip-bytes ,(* trip 1024 1024))))
(printf "collect-trip-bytes = ~a\n" (vm-eval '(collect-trip-bytes)))

(define (gc-receiver) (make-log-receiver (current-logger) 'debug 'GC))
(define (drain r)
  (let loop ([n 0] [ms 0.0])
    (define v (sync/timeout 0 r))
    (if (not v) (values n ms)
        (let ([d (vector-ref v 2)])
          (if (and (struct? d) (> (vector-length (struct->vector d)) 10))
              (let ([sv (struct->vector d)]) (loop (add1 n) (+ ms (- (vector-ref sv 10) (vector-ref sv 9)))))
              (loop n ms))))))

(define m256 (for/fold ([m champ-empty]) ([i 256]) (champ-insert m (equal-hash-code i) i i)))
(define (work kind n)
  (case kind
    [(compute) (let loop ([i 0] [a 0]) (if (fx= i n) a (loop (fx+ i 1) (fxand (fx+ (fx* a 3) i) #xFFFFF))))]
    [(cons) (let loop ([i 0] [a 0]) (if (fx= i n) a
                                         (let ([l (list i i i i i i i i)]) (loop (fx+ i 1) (fxand (fx+ a (car l)) 1023)))))]
    [(champ) (let loop ([i 0] [a 0]) (if (fx= i n) a
                                          (let* ([k (fxand i 255)]
                                                 [m (champ-insert m256 (equal-hash-code k) k i)])
                                            (loop (fx+ i 1) (fxand (fx+ a (champ-size m)) 1023)))))]))
(define total (hash 'compute 400000000 'cons 40000000 'champ 3000000))

(define (run kind k)
  (collect-garbage)
  (define r (gc-receiver))
  (define n (quotient (hash-ref total kind) k))
  (define b0 (current-memory-use 'cumulative))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define ths (for/list ([i k]) (thread #:pool 'own (lambda () (work kind n)))))
  (for-each thread-wait ths)
  (define wall (- (current-inexact-monotonic-milliseconds) t0))
  (define bytes (- (current-memory-use 'cumulative) b0))
  (define-values (gcs gcms) (drain r))
  (list kind 'K k 'wall-ms (round wall) 'MB (round (/ bytes 1e6)) 'gcs gcs 'gc-wall-ms (round gcms)
        'gc-share (if (> wall 0) (/ (round (* 100 (/ gcms wall))) 100.0) 0)))

(for ([kind '(compute cons champ)])
  (define base #f)
  (for ([k '(1 2 4)])
    (define row (run kind k))
    (define w (list-ref row 4))
    (unless base (set! base w))
    (printf "~s speedup ~a\n" row (/ (round (* 100 (/ base (max w 1)))) 100.0))))
