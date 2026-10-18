#lang racket/base
;; PSF-3: arena executors with the REAL tagged-cell-value lattice (decision-cell.rkt:397-500)
;; expressed flat: cell record = [base, n, dirty, (bm,v) x E]; base joins by fxmax (stand-in
;; domain merge), entries join by set-union (insert-if-absent). Read = entries whose bitmask is
;; a subset of the worldview, merged with base-fallback (tagged-cell-read semantics).
;; P logical partitions (fixed), K executors own P/K each; dirty lists bucketed by owner.
(require racket/future racket/fixnum racket/unsafe/ops
         (file "/Users/avanti/dev/projects/logos/prologos/racket/prologos/decision-cell.rkt"))

(define C 16384) (define E 12) (define S (+ 3 (* 2 E)))   ;; stride 15 words = 120 B/cell
(define P 16) (define R (quotient C P))                 ;; logical partitions, cells per partition
(define F 1024)                                         ;; fires per partition per round

(define (rnd s) (fxand (fx+ (fx* (fxand s #xFFFFFF) 1103515245) 12345) #x7FFFFFFF))

;; --- tagged ops on a flat arena -------------------------------------------------
(define (t-read arena i w)            ;; = tagged-cell-read with domain-merge fxmax
  (define o (fx* i S))
  (define n (unsafe-fxvector-ref arena (fx+ o 1)))
  (memory-order-acquire)
  (let loop ([e 0] [acc -1])
    (if (fx= e n)
        (if (fx= acc -1) (unsafe-fxvector-ref arena o) acc)
        (let ([bm (unsafe-fxvector-ref arena (fx+ o 3 (fx* 2 e)))])
          (if (fx= (fxand bm w) bm)
              (loop (fx+ e 1) (fxmax acc (unsafe-fxvector-ref arena (fx+ o 4 (fx* 2 e)))))
              (loop (fx+ e 1) acc))))))
(define overflow (box 0))
(define (t-insert-entry! arena o bm v)  ;; set-union insert; returns #t if record changed
  (define n (unsafe-fxvector-ref arena (fx+ o 1)))
  (let loop ([e 0])
    (cond
      [(fx= e n)
       (cond [(fx< n E) (unsafe-fxvector-set! arena (fx+ o 3 (fx* 2 n)) bm)
                        (unsafe-fxvector-set! arena (fx+ o 4 (fx* 2 n)) v)
                        (memory-order-release)
                        (unsafe-fxvector-set! arena (fx+ o 1) (fx+ n 1)) #t]
             [else (set-box! overflow (fx+ 1 (unbox overflow))) #f])]
      [(and (fx= bm (unsafe-fxvector-ref arena (fx+ o 3 (fx* 2 e))))
            (fx= v  (unsafe-fxvector-ref arena (fx+ o 4 (fx* 2 e))))) #f]
      [else (loop (fx+ e 1))])))
(define (t-write! arena i w v)         ;; = tagged-cell-write + merge, in place
  (define o (fx* i S))
  (if (fx= w 0)
      (let ([b (unsafe-fxvector-ref arena o)]) (and (fx> v b) (begin (unsafe-fxvector-set! arena o v) #t)))
      (t-insert-entry! arena o w v)))
(define (t-join! can delta i)          ;; canonical[i] := canonical[i] ⊔ delta[i]; clear delta[i]
  (define o (fx* i S))
  (define b (unsafe-fxvector-ref delta o))
  (when (fx> b (unsafe-fxvector-ref can o)) (unsafe-fxvector-set! can o b) (unsafe-fxvector-set! changed-flag 0 1))
  (define n (unsafe-fxvector-ref delta (fx+ o 1)))
  (for ([e n]) (when (t-insert-entry! can o (unsafe-fxvector-ref delta (fx+ o 3 (fx* 2 e)))
                                           (unsafe-fxvector-ref delta (fx+ o 4 (fx* 2 e))))
                 (unsafe-fxvector-set! changed-flag 0 1)))
  (unsafe-fxvector-set! delta o 0) (unsafe-fxvector-set! delta (fx+ o 1) 0) (unsafe-fxvector-set! delta (fx+ o 2) 0))

;; one fire for logical partition p, generation g, fire index f: read 2 cells under worldview w,
;; write their join (+1) to a cell in p's range under w. 90% of reads local.
(define (do-fire! can delta dirty-push! p g f)
  (define s1 (rnd (fx+ (fx* p 7919) (fx* g 104729) f)))
  (define s2 (rnd s1)) (define s3 (rnd s2))
  (define lo (fx* p R))
  (define w (if CONVERGE 0 (fxand (fxquotient s3 3) 7)))         ;; worldview: 3 assumption bits
  (define a (if (fx= 0 (fxand (fxquotient s1 5) 15)) (fxmodulo (fxquotient s1 11) C) (fx+ lo (fxmodulo s1 R))))
  (define b (if (fx= 0 (fxand s2 15)) (fxmodulo (fxquotient s2 7) C) (fx+ lo (fxmodulo (fxquotient s2 7) R))))
  (define c (if (fx= 0 (fxand s3 31)) (fxmodulo (fxquotient s3 13) C) (fx+ lo (fxmodulo (fxquotient s3 13) R))))
  (define work (let loop ([i 0] [acc s1]) (if (fx= i WORK) acc (loop (fx+ i 1) (fxand (fx+ (fx* acc 31) i) #xFFFFFF)))))
  (define v (fxmax (fxand work 0) (if CONVERGE (fxmax (t-read can b w) (t-read can c w)) (fxand (fx+ 1 (fxmax (t-read can b w) (t-read can c w))) #xFFFF))))
  (cond
    [(and DIRECT (fx= (fxquotient a R) p))   ;; owned by this executor's partition → write canonical directly
     (when (t-write! can a w v) (unsafe-fxvector-set! changed-flag 0 1))]
    [else
     (define o (fx* a S))
     (when (fx= 0 (unsafe-fxvector-ref delta (fx+ o 2))) (unsafe-fxvector-set! delta (fx+ o 2) 1) (dirty-push! a))
     (t-write! delta a w v)]))   ;; delta writes do not count as change; the join into canonical does
(define DIRECT (getenv "DIRECT"))
(define CONVERGE (getenv "CONVERGE"))
(define WORK (string->number (or (getenv "WORK") "0")))
(define changed-flag (make-fxvector 16 0))   ;; shared: any executor sets 1 when a write changed a record

(define (run K rounds0 #:verify-hash [vh #f])
  (define rounds rounds0)
  (define can (make-fxvector (* C S) 0))
  (when CONVERGE (for ([i C]) (unsafe-fxvector-set! can (fx* i S) (fxand (rnd (fx+ i 17)) #xFFFF))))
  (define deltas (for/vector ([k K]) (make-fxvector (* C S) 0)))
  ;; dirty buckets: bucket[j][k] = fxvector of cells executor j dirtied that executor k owns
  (define cap (* F (quotient P K) 2))
  (define buckets (for/vector ([j K]) (for/vector ([k K]) (make-fxvector cap 0))))
  (define counts  (for/vector ([j K]) (for/vector ([k K]) (make-fxvector 16 0))))  ;; padded
  (define (owner-of i) (fxquotient (fxquotient i R) (quotient P K)))
  (define gens (for/vector ([k K]) (make-fxvector 16 0)))
  (define dones (for/vector ([k K]) (make-fxvector 16 0)))
  (define etimes (for/vector ([k K]) (make-fxvector 16 0)))
  (define active (box #t))
  (define (fire-phase! k g)
    (define delta (vector-ref deltas k))
    (define my-buckets (vector-ref buckets k)) (define my-counts (vector-ref counts k))
    (define (dirty-push! i)
      (define o (owner-of i)) (define cnt (vector-ref my-counts o))
      (define n (unsafe-fxvector-ref cnt 0))
      (unsafe-fxvector-set! (vector-ref my-buckets o) n i) (unsafe-fxvector-set! cnt 0 (fx+ n 1)))
    (for* ([p (in-range (fx* k (quotient P K)) (fx* (fx+ k 1) (quotient P K)))] [f F])
      (do-fire! can delta dirty-push! p g f)))
  (define (join-phase! k)
    (for ([j K])
      (define bucket (vector-ref (vector-ref buckets j) k)) (define cnt (vector-ref (vector-ref counts j) k))
      (define delta (vector-ref deltas j))
      (for ([x (unsafe-fxvector-ref cnt 0)]) (t-join! can delta (unsafe-fxvector-ref bucket x)))
      (unsafe-fxvector-set! cnt 0 0)))
  (define threads
    (for/list ([k K])
      (thread #:pool 'own
        (lambda ()
          (define my-gen (vector-ref gens k)) (define my-done (vector-ref dones k))
          (let loop ([seen 0])
            (when (unbox active)
              (memory-order-acquire)
              (define g (unsafe-fxvector-ref my-gen 0))
              (cond [(fx> g seen)
                     (let ([t (current-inexact-monotonic-milliseconds)] [et (vector-ref etimes k)])
                       (if (fx= 0 (fxand g 1)) (fire-phase! k (fxquotient g 2)) (join-phase! k))
                       (let ([slot (fxand g 1)] [dt (inexact->exact (round (* 1000 (- (current-inexact-monotonic-milliseconds) t))))])
                         (unsafe-fxvector-set! et slot (fx+ dt (unsafe-fxvector-ref et slot)))))
                     (memory-order-release) (unsafe-fxvector-set! my-done 0 g) (loop g)]
                    [else (loop seen)])))))))
  (define (step! g)
    (memory-order-release)
    (for ([k K]) (unsafe-fxvector-set! (vector-ref gens k) 0 g))
    (for ([k K]) (define d (vector-ref dones k)) (let spin () (memory-order-acquire) (unless (fx= (unsafe-fxvector-ref d 0) g) (spin)))))
  (define result (box 0.0)) (define done (make-semaphore 0)) (define phase-info (box #f))
  (set-box! overflow 0)
  (thread #:pool 'own
    (lambda ()
      (step! 2) (step! 3)   ;; warm-up round (threads started, caches touched) — untimed
      (define b0 (current-memory-use 'cumulative))
      (define t0 (current-inexact-milliseconds))
      (define tf 0.0) (define tj 0.0)
      (define nrounds
        (let loop ([r 0])
          (cond
            [(if CONVERGE (>= r 10000) (>= r rounds)) r]
            [else
             (unsafe-fxvector-set! changed-flag 0 0)
             (define a (current-inexact-milliseconds)) (step! (+ 4 (* 2 r)))
             (define b (current-inexact-milliseconds)) (step! (+ 5 (* 2 r)))
             (set! tf (+ tf (- b a))) (set! tj (+ tj (- (current-inexact-milliseconds) b)))
             (memory-order-acquire)
             (if (and CONVERGE (fx= 0 (unsafe-fxvector-ref changed-flag 0))) (+ r 1) (loop (+ r 1)))])))
      (when CONVERGE (printf "   converged after ~a rounds\n" nrounds))
      (set! rounds nrounds)
      (set-box! result (- (current-inexact-milliseconds) t0))
      (set-box! phase-info (list (round (/ (* 1e3 tf) rounds)) (round (/ (* 1e3 tj) rounds))
                                 (round (/ (- (current-memory-use 'cumulative) b0) (* rounds P F)))))
      (semaphore-post done)))
  (semaphore-wait done) (set-box! active #f) (for-each thread-wait threads)
  (define ms (unbox result)) (define fires (* rounds P F))
  (when (> K 4)
    (printf "   per-executor avg us/round  fire: ~a\n                              join: ~a\n"
            (for/list ([k K]) (quotient (fxvector-ref (vector-ref etimes k) 0) (+ rounds 1)))
            (for/list ([k K]) (quotient (fxvector-ref (vector-ref etimes k) 1) (+ rounds 1)))))
  ;; canonical fixpoint hash: per cell base + SORTED entries (order-independent)
  (define h (for/fold ([h 0]) ([i C])
              (define o (fx* i S)) (define n (unsafe-fxvector-ref can (fx+ o 1)))
              (define es (sort (for/list ([e n]) (cons (unsafe-fxvector-ref can (fx+ o 3 (fx* 2 e))) (unsafe-fxvector-ref can (fx+ o 4 (fx* 2 e)))))
                               (lambda (x y) (or (< (car x) (car y)) (and (= (car x) (car y)) (< (cdr x) (cdr y)))))))
              (fxand (fx+ (fx* h 31) (equal-hash-code (cons (unsafe-fxvector-ref can o) es))) #xFFFFFFFF)))
  (printf "K=~a: ~a ns/fire  ~a us/round (fire ~a + join ~a)  ~a B/fire  ~a fires/ms  overflow=~a  hash=~a~a\n"
          K (/ (round (* 10 (/ (* 1e6 ms) fires))) 10.0) (round (/ (* 1e3 ms) rounds)) (car (unbox phase-info)) (cadr (unbox phase-info)) (caddr (unbox phase-info)) (round (/ fires ms))
          (unbox overflow) h (if vh (if (= vh h) "  ✓ same as K=1" "  ✗ DIFFERS") ""))
  h)

;; --- baseline: the same fire semantics on heap tagged-cell-value structs (functional) --------
(define (run-structs rounds)
  (define can (make-vector C 0))
  (define merge (make-tagged-merge fxmax))
  (define (rd i w) (let ([v (vector-ref can i)]) (if (tagged-cell-value? v) (let ([r (tagged-cell-read v w fxmax)]) (if (fixnum? r) r 0)) v)))
  (collect-garbage 'major)
  (define b0 (current-memory-use 'cumulative)) (define t0 (current-inexact-milliseconds))
  (for* ([r rounds] [p P] [f F])
    (define s1 (rnd (fx+ (fx* p 7919) (fx* r 104729) f))) (define s2 (rnd s1)) (define s3 (rnd s2))
    (define lo (fx* p R)) (define w (fxand (fxquotient s3 3) 7))
    (define a (if (fx= 0 (fxand (fxquotient s1 5) 15)) (fxmodulo (fxquotient s1 11) C) (fx+ lo (fxmodulo s1 R))))
    (define b (if (fx= 0 (fxand s2 15)) (fxmodulo (fxquotient s2 7) C) (fx+ lo (fxmodulo (fxquotient s2 7) R))))
    (define c (if (fx= 0 (fxand s3 31)) (fxmodulo (fxquotient s3 13) C) (fx+ lo (fxmodulo (fxquotient s3 13) R))))
    (define v (fxand (fx+ 1 (fxmax (rd b w) (rd c w))) #xFFFF))
    (define old (vector-ref can a))
    (define delta (if (fx= w 0) (tagged-cell-value v '()) (tagged-cell-value (if (tagged-cell-value? old) (tagged-cell-value-base old) old) (list (cons w v)))))
    (vector-set! can a (merge (if (tagged-cell-value? old) old (tagged-cell-value old '())) delta)))
  (define ms (- (current-inexact-milliseconds) t0)) (define bytes (- (current-memory-use 'cumulative) b0))
  (define fires (* rounds P F))
  (printf "heap tagged-cell-value structs, sequential, data-structure only (no network): ~a ns/fire, ~a B/fire\n"
          (/ (round (* 10 (/ (* 1e6 ms) fires))) 10.0) (round (/ bytes fires))))

(printf "procs=~a  C=~a E=~a P=~a F=~a  DIRECT=~a WORK=~a iters/fire\n" (processor-count) C E P F (and DIRECT #t) WORK)
(run-structs 10)
(define b0 (current-memory-use 'cumulative))
(define h1 (run 1 10))
(for ([k '(2 4 8 16)]) (run k 10 #:verify-hash h1))
(printf "heap allocated by ALL arena runs: ~a KB (~a B/fire)\n" (quotient (- (current-memory-use 'cumulative) b0) 1024)
        (round (/ (- (current-memory-use 'cumulative) b0) (* 5 11 P F))))
