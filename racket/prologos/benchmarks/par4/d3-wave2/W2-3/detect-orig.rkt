#lang racket/base
;; detect.rkt — PAR 4 P0-4: quiescence detection schemes (D.1 §5.4, A-6).
;;
;; K executors (persistent #:pool 'own threads, spin-parked between trials). Messages are
;; fixnums carried in per-(dst,src) SPSC rings (fxvector, release on publish / acquire on
;; read). A message with payload h>0 causes `fan` new messages with payload h-1, each to a
;; pseudo-random executor. Three ways to know S0 is DONE:
;;   ROUNDS  — BSP: each round every executor drains its inbox; a sense-reversing CAS
;;             barrier ends the round; stop when a round sent nothing (global flag).
;;   SCAN    — DIRECT: no rounds. Each executor keeps padded prod/cons counters; the
;;             detector (main thread) declares quiescence when Σprod = Σcons and every
;;             executor is idle, unchanged across two consecutive scans (Mattern).
;;   ATOMIC  — DIRECT: one shared outstanding-message counter (box-cas! +1 on send,
;;             -1 on consume); quiescent when it reads 0.
;; Workloads:  CHAIN  fan=1, depth D   (one message alive at a time: worst case for rounds)
;;             BURST  fan=F, depth d   (F^d messages: contention on the shared counter)
;; Free parameters printed in the header. Correctness: every scheme must consume exactly
;; the same number of messages (asserted).
(require racket/fixnum racket/unsafe/ops racket/future racket/list)

(define RING 4096)          ; slots per (dst,src) ring — sized so a burst never wraps
(define PAD 16)             ; fixnums per executor counter block (128 B → own cache lines)

(struct sys (K rings heads tails ctr bar sense running idle mode-box))
;; rings: vector K*K of fxvector RING  (index dst*K+src)
;; heads: fxvector K*K*PAD (consumer index, written by dst)   tails: same (producer, by src)
;; ctr:   fxvector K*PAD : slot0 prod, slot1 cons, slot2 idle(0/1), slot3 sent-this-round
(define (make-sys K)
  (sys K (for/vector ([i (* K K)]) (make-fxvector RING 0))
       (make-fxvector (* K K PAD) 0) (make-fxvector (* K K PAD) 0)
       (make-fxvector (* K PAD) 0) (box 0) (box 0) (box #t) (box 0) (box 'idle)))

(define (lane-ix s d src) (fx* (fx+ (fx* d (sys-K s)) src) PAD))
(define (send! s src dst payload)
  (define ix (lane-ix s dst src))
  (define t (fxvector-ref (sys-tails s) ix))
  (fxvector-set! (vector-ref (sys-rings s) (fx+ (fx* dst (sys-K s)) src)) (fxand t (fx- RING 1)) payload)
  (memory-order-release)
  (fxvector-set! (sys-tails s) ix (fx+ t 1)))
(define (cset! s i slot v) (fxvector-set! (sys-ctr s) (fx+ (fx* i PAD) slot) v))
(define (cref s i slot) (fxvector-ref (sys-ctr s) (fx+ (fx* i PAD) slot)))

;; drain executor i's inbox once; returns #messages consumed. `on-send` is called per send.
(define (drain! s i fan seed-box on-send)
  (define K (sys-K s))
  (let loop-src ([src 0] [n 0])
    (if (fx= src K) n
        (let* ([ix (lane-ix s i src)]
               [h (fxvector-ref (sys-heads s) ix)]
               [t (begin0 (fxvector-ref (sys-tails s) ix) (memory-order-acquire))])
          (let loop ([h h] [n n])
            (if (fx= h t)
                (begin (fxvector-set! (sys-heads s) ix h) (loop-src (fx+ src 1) n))
                (let ([p (fxvector-ref (vector-ref (sys-rings s) (fx+ (fx* i K) src)) (fxand h (fx- RING 1)))])
                  (when (fx> p 0)
                    (for ([j (in-range fan)])
                      (define sd (unbox seed-box))
                      (define sd* (fxand (fx+ (fx* (fxand sd #xFFFFF) 1103515245) 12345) #x3FFFFFFF))
                      (set-box! seed-box sd*)
                      (define dst (fxmodulo (fxrshift sd* 8) K))
                      (on-send i)
                      (send! s i dst (fx- p 1))))
                  (loop (fx+ h 1) (fx+ n 1)))))))))

;; ---------------------------------------------------------------------------- schemes ---
(define (barrier! s i)              ; sense-reversing counter barrier over K participants
  (define K (sys-K s))
  (define my-sense (not (unbox (sys-sense s))))
  ;; decide "last arriver" from the value OUR CAS installed — re-reading the counter lets
  ;; two threads both see K and double-flip the sense (deadlock; first version did this).
  (define mine (let retry () (define c (unbox (sys-bar s)))
                 (if (box-cas! (sys-bar s) c (add1 c)) (add1 c) (retry))))
  (if (= mine K)
      (begin (set-box! (sys-bar s) 0) (set-box! (sys-sense s) my-sense))
      (let spin () (unless (eq? (unbox (sys-sense s)) my-sense) (spin)))))

(define atomic-outstanding (box 0))
(define (atomic-add! d) (let retry () (define c (unbox atomic-outstanding))
                          (unless (box-cas! atomic-outstanding c (+ c d)) (retry))))

;; one trial: inject the root message at executor 0, run to detected quiescence.
;; returns (values consumed-total wall-ms rounds)
(define (trial s mode fan depth)
  (define K (sys-K s))
  ;; reset rings/counters
  (for ([i (* K K PAD)]) (fxvector-set! (sys-heads s) i 0) (fxvector-set! (sys-tails s) i 0))
  (for ([i (* K PAD)]) (fxvector-set! (sys-ctr s) i 0))
  (set-box! atomic-outstanding 0)
  (set-box! (sys-bar s) 0)
  (define done (box #f))
  (define rounds (box 0))
  (define consumed (make-fxvector (* K PAD) 0))
  (send! s 0 0 depth)
  (case mode [(atomic) (atomic-add! 1)] [else (cset! s 0 0 1)])   ; root counted as produced by 0
  (define t0 (current-inexact-monotonic-milliseconds))
  (define threads
    (for/list ([i K])
      (thread #:pool 'own
        (λ ()
          (define seed (box (+ 7 (* 7919 i))))
          (case mode
            [(rounds)
             (let loop ()
               (define n (drain! s i fan seed (λ (_) (cset! s i 3 (fx+ (cref s i 3) 1)))))
               (fxvector-set! consumed (* i PAD) (fx+ (fxvector-ref consumed (* i PAD)) n))
               (barrier! s i)                                   ; end of round r
               (when (= i 0)
                 (set-box! rounds (add1 (unbox rounds)))
                 (set-box! done (for/and ([j K]) (fx= (cref s j 3) 0))))
               (barrier! s i)                                   ; publish decision
               (define stop? (unbox done))
               (cset! s i 3 0)
               (barrier! s i)                                   ; counters reset before next round
               (unless stop? (loop)))]
            [(scan)
             (let loop ()
               (define n (drain! s i fan seed (λ (_) (cset! s i 0 (fx+ (cref s i 0) 1)))))
               (cond
                 [(fx> n 0)
                  (cset! s i 2 0)
                  (cset! s i 1 (fx+ (cref s i 1) n))
                  (memory-order-release)
                  (fxvector-set! consumed (* i PAD) (fx+ (fxvector-ref consumed (* i PAD)) n))
                  (loop)]
                 [else (cset! s i 2 1) (memory-order-release)
                       (unless (unbox done) (loop))]))]
            [(atomic)
             (let loop ()
               (define n (drain! s i fan seed (λ (_) (atomic-add! 1))))
               (when (fx> n 0)
                 (atomic-add! (- n))
                 (fxvector-set! consumed (* i PAD) (fx+ (fxvector-ref consumed (* i PAD)) n)))
               (unless (unbox done) (loop)))])))))
  ;; detectors for the DIRECT modes run on the main thread
  (case mode
    [(scan)
     (define (snap) (memory-order-acquire)
       (for/fold ([p 0] [c 0] [idle #t]) ([j K])
         (values (+ p (cref s j 0)) (+ c (cref s j 1)) (and idle (fx= (cref s j 2) 1)))))
     (let poll ()
       (define-values (p1 c1 i1) (snap))
       (define-values (p2 c2 i2) (snap))
       (if (and i1 i2 (= p1 c1) (= p1 p2) (= c1 c2)) (set-box! done #t) (poll)))]
    [(atomic)
     (let poll () (if (zero? (unbox atomic-outstanding)) (set-box! done #t) (poll)))]
    [else (void)])
  (for-each thread-wait threads)
  (define wall (- (current-inexact-monotonic-milliseconds) t0))
  (values (for/sum ([i K]) (fxvector-ref consumed (* i PAD))) wall (unbox rounds)))

(define (expected fan depth) (for/sum ([h (in-range (add1 depth))]) (expt fan h)))

(define (run K)
  (define s (make-sys K))
  (for ([w (list (list "CHAIN fan=1 depth=20000" 1 20000)
                 (list "BURST fan=4 depth=6"     4 6))])
    (define-values (name fan depth) (apply values w))
    (define exp (expected fan depth))
    (for ([mode '(rounds scan atomic)])
      (trial s mode fan (min depth 50))                          ; warm-up
      (define-values (n wall rounds)
        (for/fold ([bn 0] [bw +inf.0] [br 0]) ([rep 5])
          (define-values (n w r) (trial s mode fan depth))
          (unless (= n exp) (error 'detect "~a ~a K=~a consumed ~a expected ~a" name mode K n exp))
          (if (< w bw) (values n w r) (values bn bw br))))
      (printf "K=~a  ~a  ~a  msgs=~a  best-of-5 ~a ms  = ~a ns/msg~a\n"
              (~r2 K) name (pad mode) n (~r wall) (~r (/ (* 1e6 wall) n))
              (if (eq? mode 'rounds) (format "  rounds=~a (~a ns/round)" rounds (~r (/ (* 1e6 wall) (max 1 rounds)))) "")))))
(define (~r x) (/ (round (* 10 x)) 10.0))
(define (~r2 k) (if (< k 10) (format " ~a" k) (format "~a" k)))
(define (pad m) (let ([s (symbol->string m)]) (string-append s (make-string (- 7 (string-length s)) #\space))))

(printf "detect.rkt — quiescence detection. Free parameters: K executors (#:pool 'own threads);\n")
(printf "  CHAIN: fan=1, one message alive at a time (D hops); BURST: fan=4 depth=6 (5461 msgs, a 4^6 leaf wave).\n")
(printf "  processor-count=~a. Each row: best of 5 trials; consumed count asserted equal across schemes.\n" (processor-count))
(for ([K (let ([a (current-command-line-arguments)]) (if (zero? (vector-length a)) '(4 8 16) (map string->number (vector->list a))))])
  (run K))
