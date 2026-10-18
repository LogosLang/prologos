#lang racket/base
;; detect-w23.rkt — W2-3 (PAR 4 D.3 wave 2): cost of the quiescence-detector repairs.
;; Copied from benchmarks/par4/detect.rkt (P0-4) — the ROUNDS / SCAN / ATOMIC modes and the CHAIN / BURST rows are
;; unchanged.  Added:
;;   * a DIRECT executor loop in D.2 §6.7's shape: at the top of each iteration drain every lane (a message with
;;     payload h>0 starts a LOCAL CASCADE of L local fires on the receiving executor), then pop ONE local item and
;;     fire it (WORK fixnum iterations); the cascade's last fire sends `fan` messages with payload h-1 to
;;     pseudo-random executors.  L = 0 reproduces detect.rkt's "send inside the drain".
;;   * the CASCADE row: fan=1, L=8 local fires per hop.
;;   * detection modes on that loop:
;;       d2        D.2 as written: cons published at drain, idle-epoch (sticky max-counter, never lowered in a trial).
;;                 UNSOUND (CL-3): the POWER ROW — premature declarations are counted, not asserted.
;;       flag      (a) D.1's reset flag: flag:=busy, RELEASE, cons+=n, RELEASE at drain; flag:=idle, RELEASE when idle.
;;       defer     (d) D.2's idle-epoch kept; cons published only when the cascade has drained (RELEASE, cons, RELEASE).
;;       seeds     (d') no indicator: the root is a counted message (as detect.rkt already does); cons published only
;;                 when the cascade has drained; detector = sum prod = sum cons over two identical scans.
;;       logseeds  (d') with lanes as logs + cursors (C4-8): prod and cons are DERIVED reads (sum of lane tails, sum of
;;                 published lane heads); no counter words at all.  Heads are published when the cascade has drained.
;;       seeds1    seeds with a ONE-PASS detector: read every cons, acquire, then every prod; declare iff equal (no
;;                 second scan: sound because sum cons <= sum prod at every instant when acks are deferred and sends
;;                 are counted before they are published — Mattern's four-counter argument with the waves merged).
;;       logseeds1 logseeds with the same one-pass detector (all published heads, acquire, all tails).
;;       act       (b) activity parity counter: +1 (store, RELEASE) at every idle<->busy transition; cons at drain.
;;       quiet     (c) quiet mark: on going idle store mark := cons+1 (RELEASE); idle iff mark = cons+1; cons at drain.
;;       credit    (e) credit recovery: a message carries credit 2^-k (k in the payload's high bits); an idle receiver
;;                 holds it, an active one returns it at once; a send halves the held credit; going idle returns it.
;;                 returned_i is an EXACT rational (Racket bignum arithmetic) in a padded vector; ONE scan: sum = 1.
;;   * a premature-declaration counter for every mode: local fires executed after `done` was set, and messages
;;     never consumed (consumed < expected).
;; Timing: modes are INTERLEAVED inside each repetition; best and median of REPS reported.
;; Free parameters (printed): K executors (#:pool 'own threads); CHAIN depth; BURST fan/depth; CASCADE depth and L;
;; WORK = fixnum loop iterations per local fire; REPS.
(require racket/fixnum racket/unsafe/ops racket/future racket/list)

(define RING 8192)          ; slots per (dst,src) ring — sized so no row ever wraps
(define PAD 16)             ; fixnums per executor counter block (128 B → own cache lines)
(define WLCAP 16384)        ; private worklist capacity

(define (env-num name default) (let ([v (getenv name)]) (if v (string->number v) default)))
(define WORK (env-num "WORK" 20))
(define WATCHDOG-MS (env-num "WATCHDOG_MS" 5000))
(define hung-box (box #f))
(define REPS (env-num "REPS" 7))
(define CASCADE-L (env-num "CASCADE_L" 8))
;; DRAIN=every (D.2 §6.7: drain all K lanes at the top of EVERY loop iteration) | idle (drain only when the local
;; worklist is empty — same protocol, fewer remote loads)
(define DRAIN-IDLE? (equal? (getenv "DRAIN") "idle"))

(struct sys (K rings heads tails ctr bar sense running idle mode-box))
;; ctr: fxvector K*PAD : slot0 prod, slot1 cons, slot2 idle/flag/idle-epoch, slot3 sent-this-round
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

(define (next-dst! seed-box K)
  (define sd (unbox seed-box))
  (define sd* (fxand (fx+ (fx* (fxand sd #xFFFFF) 1103515245) 12345) #x3FFFFFFF))
  (set-box! seed-box sd*)
  (fxmodulo (fxrshift sd* 8) K))

;; ---------------------------------------------------------------- P0's drain (ROUNDS / SCAN / ATOMIC) ---
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
                      (define dst (next-dst! seed-box K))
                      (on-send i)
                      (send! s i dst (fx- p 1))))
                  (loop (fx+ h 1) (fx+ n 1)))))))))

(define (barrier! s i)
  (define K (sys-K s))
  (define my-sense (not (unbox (sys-sense s))))
  (define mine (let retry () (define c (unbox (sys-bar s)))
                 (if (box-cas! (sys-bar s) c (add1 c)) (add1 c) (retry))))
  (if (= mine K)
      (begin (set-box! (sys-bar s) 0) (set-box! (sys-sense s) my-sense))
      (let spin () (unless (eq? (unbox (sys-sense s)) my-sense) (spin)))))

(define atomic-outstanding (box 0))
(define (atomic-add! d) (let retry () (define c (unbox atomic-outstanding))
                          (unless (box-cas! atomic-outstanding c (+ c d)) (retry))))

(define HBITS 16)
(define HMASK (fx- (fxlshift 1 HBITS) 1))
(define credit-ret (make-vector (* 64 PAD) 0))   ; returned_i, exact rationals, padded

(define (spin-work n) (let loop ([i 0] [a 0]) (if (fx= i n) a (loop (fx+ i 1) (fxxor a (fx* i 7))))))

;; ------------------------------------------------------------------------------- one trial, any mode ---
;; returns (values consumed wall-ms rounds late-fires)
(define (trial s mode fan depth L)
  (define K (sys-K s))
  (for ([i (* K K PAD)]) (fxvector-set! (sys-heads s) i 0) (fxvector-set! (sys-tails s) i 0))
  (for ([i (* K PAD)]) (fxvector-set! (sys-ctr s) i 0))
  (set-box! atomic-outstanding 0)
  (set-box! (sys-bar s) 0)
  (for ([i (* K PAD)]) (vector-set! credit-ret i 0))
  (define done (box #f))
  (define rounds (box 0))
  (define consumed (make-fxvector (* K PAD) 0))
  (define late (make-fxvector (* K PAD) 0))
  (send! s 0 0 depth)
  (case mode [(atomic) (atomic-add! 1)] [(logseeds logseeds1 credit) (void)] [else (cset! s 0 0 1)])   ; root counted as produced by 0
  ;; (credit: the root message carries credit 2^-0 = 1 in its payload's high bits, which are 0)
  (define t0 (current-inexact-monotonic-milliseconds))
  (set-box! hung-box #f)
  (define watchdog
    (thread (λ () (sleep (/ WATCHDOG-MS 1000.0))
                  (unless (unbox done) (set-box! hung-box #t) (set-box! done #t)))))
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
               (barrier! s i)
               (when (= i 0)
                 (set-box! rounds (add1 (unbox rounds)))
                 (set-box! done (for/and ([j K]) (fx= (cref s j 3) 0))))
               (barrier! s i)
               (define stop? (unbox done))
               (cset! s i 3 0)
               (barrier! s i)
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
               (unless (unbox done) (loop)))]
            [else (direct-executor s i mode fan L seed done consumed late)])))))
  ;; detectors run on the main thread
  (define (sum-ctr slot) (for/fold ([a 0]) ([j K]) (fx+ a (cref s j slot))))
  (case mode
    [(scan flag)
     (define (snap) (memory-order-acquire)
       (for/fold ([p 0] [c 0] [idle #t]) ([j K])
         (values (+ p (cref s j 0)) (+ c (cref s j 1)) (and idle (fx= (cref s j 2) 1)))))
     (let poll ()
       (define-values (p1 c1 i1) (snap))
       (define-values (p2 c2 i2) (snap))
       (if (and i1 i2 (= p1 c1) (= p1 p2) (= c1 c2)) (set-box! done #t) (poll)))]
    [(d2 defer)
     ;; idle-epoch: slot2 = 1 once the executor has gone idle in this trial (epoch e = 1)
     (define (snap) (memory-order-acquire)
       (for/fold ([p 0] [c 0] [idle #t]) ([j K])
         (values (+ p (cref s j 0)) (+ c (cref s j 1)) (and idle (fx= (cref s j 2) 1)))))
     (let poll ()
       (define-values (p1 c1 i1) (snap))
       (define-values (p2 c2 i2) (snap))
       (if (and i1 i2 (= p1 c1) (= p1 p2) (= c1 c2)) (set-box! done #t) (poll)))]
    [(act)
     (define (snap) (memory-order-acquire)
       (for/fold ([p 0] [c 0] [idle #t] [a 0]) ([j K])
         (define av (cref s j 2))
         (values (+ p (cref s j 0)) (+ c (cref s j 1)) (and idle (fx= 0 (fxand av 1))) (+ (* a 1000003) av))))
     (let poll ()
       (define-values (p1 c1 i1 a1) (snap))
       (define-values (p2 c2 i2 a2) (snap))
       (if (and i1 i2 (= p1 c1) (= p1 p2) (= c1 c2) (= a1 a2)) (set-box! done #t) (poll)))]
    [(quiet)
     (define (snap) (memory-order-acquire)
       (for/fold ([p 0] [c 0] [idle #t] [a 0]) ([j K])
         (define cj (cref s j 1)) (define qj (cref s j 2))
         (values (+ p (cref s j 0)) (+ c cj) (and idle (fx= qj (fx+ cj 1))) (+ (* a 1000003) qj))))
     (let poll ()
       (define-values (p1 c1 i1 a1) (snap))
       (define-values (p2 c2 i2 a2) (snap))
       (if (and i1 i2 (= p1 c1) (= p1 p2) (= c1 c2) (= a1 a2)) (set-box! done #t) (poll)))]
    [(credit)
     (let poll ()
       (memory-order-acquire)
       (if (= 1 (for/fold ([a 0]) ([j K]) (+ a (vector-ref credit-ret (* j PAD))))) (set-box! done #t) (poll)))]
    [(seeds)
     (define (snap) (memory-order-acquire)
       (for/fold ([p 0] [c 0]) ([j K]) (values (+ p (cref s j 0)) (+ c (cref s j 1)))))
     (let poll ()
       (define-values (p1 c1) (snap))
       (define-values (p2 c2) (snap))
       (if (and (= p1 c1) (= p1 p2) (= c1 c2)) (set-box! done #t) (poll)))]
    [(seeds1)
     (let poll ()
       (memory-order-acquire)
       (define c (for/fold ([a 0]) ([j K]) (fx+ a (cref s j 1))))
       (memory-order-acquire)
       (define p (for/fold ([a 0]) ([j K]) (fx+ a (cref s j 0))))
       (if (= p c) (set-box! done #t) (poll)))]
    [(logseeds1)
     (define KK (* K K))
     (let poll ()
       (memory-order-acquire)
       (define h (for/fold ([a 0]) ([x KK]) (fx+ a (fxvector-ref (sys-heads s) (fx* x PAD)))))
       (memory-order-acquire)
       (define t (for/fold ([a 0]) ([x KK]) (fx+ a (fxvector-ref (sys-tails s) (fx* x PAD)))))
       (if (= t h) (set-box! done #t) (poll)))]
    [(logseeds)
     ;; heads first, then tails (a published head never exceeds the tail it was read from)
     (define KK (* K K))
     (define (snap) (memory-order-acquire)
       (define h (for/fold ([a 0]) ([x KK]) (fx+ a (fxvector-ref (sys-heads s) (fx* x PAD)))))
       (memory-order-acquire)
       (define t (for/fold ([a 0]) ([x KK]) (fx+ a (fxvector-ref (sys-tails s) (fx* x PAD)))))
       (values t h))
     (let poll ()
       (define-values (p1 c1) (snap))
       (define-values (p2 c2) (snap))
       (if (and (= p1 c1) (= p1 p2) (= c1 c2)) (set-box! done #t) (poll)))]
    [(atomic)
     (let poll () (if (zero? (unbox atomic-outstanding)) (set-box! done #t) (poll)))]
    [else (void)])
  (for-each thread-wait threads)
  (kill-thread watchdog)
  (when (unbox hung-box)
    (eprintf "HUNG: mode ~a K=~a fan=~a depth=~a L=~a  prod=~a cons=~a heads=~a tails=~a\n" mode K fan depth L
             (for/list ([j K]) (cref s j 0)) (for/list ([j K]) (cref s j 1))
             (for/sum ([x (* K K)]) (fxvector-ref (sys-heads s) (fx* x PAD)))
             (for/sum ([x (* K K)]) (fxvector-ref (sys-tails s) (fx* x PAD)))))
  (define wall (- (current-inexact-monotonic-milliseconds) t0))
  (values (for/sum ([i K]) (fxvector-ref consumed (* i PAD))) wall (unbox rounds)
          (for/sum ([i K]) (fxvector-ref late (* i PAD)))))

;; ------------------------------------------------------------------ the DIRECT loop (D.2 §6.7 shape) ---
(define (direct-executor s i mode fan L seed done consumed late)
  (define K (sys-K s))
  (define wl-rem (make-fxvector WLCAP 0))       ; private worklist: (remaining local fires, payload h)
  (define wl-h (make-fxvector WLCAP 0))
  (define top 0)
  (define cursors (make-fxvector K 0))          ; private read cursors (logseeds publishes heads separately)
  (define unacked 0)
  (define sent (if (and (= i 0) (not (memq mode '(logseeds logseeds1)))) 1 0))   ; private copy of prod (the root counts for 0)
  (define cons 0)                               ; private copy of cons
  (define ind-busy? #t)                         ; flag mode: what slot2 currently says
  (define ie-set? #f)                           ; d2/defer: idle-epoch published
  (define act 0)                                ; act: even = idle (every executor starts idle; the root is a message)
  (define quiet 0)                              ; quiet: published mark (cons+1), 0 = never idle
  (define held-k -1)                            ; credit: exponent of the held credit 2^-k, -1 = none
  (define ret 0)                                ; credit: returned so far (exact)
  (define (return-credit! k)
    (set! ret (+ ret (expt 1/2 k)))
    (memory-order-release)                      ; this executor's S0 writes before its credit is returned
    (vector-set! credit-ret (* i PAD) ret))
  (define (count-send!)
    (unless (memq mode '(logseeds logseeds1))
      (set! sent (fx+ sent 1)) (cset! s i 0 sent)))
  (define (send-children! h)
    (when (fx> h 0)
      (for ([j (in-range fan)])
        (define dst (next-dst! seed K))
        (cond
          [(eq? mode 'credit)
           (set! held-k (fx+ held-k 1))          ; keep half, send half
           (send! s i dst (fxior (fxlshift held-k HBITS) (fx- h 1)))]
          [else
           (count-send!)                         ; prod store before the lane publish (send! releases)
           (send! s i dst (fx- h 1))]))))
  ;; drain every lane once; each message either sends at once (L = 0) or pushes a local cascade
  (define (drain-direct!)
    (let loop-src ([src 0] [n 0])
      (if (fx= src K) n
          (let* ([ix (lane-ix s i src)]
                 [h0 (fxvector-ref cursors src)]
                 [t (begin0 (fxvector-ref (sys-tails s) ix) (memory-order-acquire))])
            (let loop ([h h0] [n n])
              (if (fx= h t)
                  (begin (fxvector-set! cursors src h)
                         (unless (or (fx= h h0) (memq mode '(logseeds logseeds1))) (fxvector-set! (sys-heads s) ix h))
                         (loop-src (fx+ src 1) n))
                  (let* ([raw (fxvector-ref (vector-ref (sys-rings s) (fx+ (fx* i K) src)) (fxand h (fx- RING 1)))]
                         [p (fxand raw HMASK)])
                    (when (eq? mode 'credit)
                      (define k (fxrshift raw HBITS))
                      (if (fx= held-k -1) (set! held-k k) (return-credit! k)))
                    (if (fx= L 0)
                        (send-children! p)
                        (begin (fxvector-set! wl-rem top L) (fxvector-set! wl-h top p) (set! top (fx+ top 1))))
                    (loop (fx+ h 1) (fx+ n 1)))))))))
  (define (publish-heads!)
    (for ([src (in-range K)])
      (fxvector-set! (sys-heads s) (lane-ix s i src) (fxvector-ref cursors src))))
  (let loop ()
    (define n (if (and DRAIN-IDLE? (fx> top 0)) 0 (drain-direct!)))
    (when (fx> n 0)
      (fxvector-set! consumed (* i PAD) (fx+ (fxvector-ref consumed (* i PAD)) n))
      (case mode
        [(d2) (set! cons (fx+ cons n)) (cset! s i 1 cons) (memory-order-release)]
        [(flag) (when (not ind-busy?) (set! ind-busy? #t) (cset! s i 2 0) (memory-order-release))
                (set! cons (fx+ cons n)) (cset! s i 1 cons) (memory-order-release)]
        [(act) (when (fx= 0 (fxand act 1)) (set! act (fx+ act 1)) (cset! s i 2 act) (memory-order-release))
               (set! cons (fx+ cons n)) (cset! s i 1 cons) (memory-order-release)]
        [(quiet) (set! cons (fx+ cons n)) (cset! s i 1 cons) (memory-order-release)]
        [(credit) (void)]
        [else (set! unacked (fx+ unacked n))]))
    (cond
      [(fx> top 0)
       (set! top (fx- top 1))
       (define rem (fxvector-ref wl-rem top))
       (define h (fxvector-ref wl-h top))
       (spin-work WORK)
       (when (unbox done) (fxvector-set! late (* i PAD) (fx+ (fxvector-ref late (* i PAD)) 1)))
       (if (fx> rem 1)
           (begin (fxvector-set! wl-rem top (fx- rem 1)) (fxvector-set! wl-h top h) (set! top (fx+ top 1)))
           (send-children! h))
       (loop)]
      [(fx> n 0) (loop)]
      [else
       ;; idle: worklist and lanes empty
       (case mode
         [(d2) (unless ie-set? (set! ie-set? #t) (cset! s i 2 1) (memory-order-release))]
         [(flag) (when ind-busy? (set! ind-busy? #f) (cset! s i 2 1) (memory-order-release))]
         [(defer) (define pub? (fx> unacked 0))
                  (when pub?
                    (memory-order-release)                   ; the cascade's sends/writes before cons
                    (set! cons (fx+ cons unacked)) (set! unacked 0) (cset! s i 1 cons))
                  (unless ie-set? (set! ie-set? #t) (cset! s i 2 1) (memory-order-release))]
         [(act) (when (fx= 1 (fxand act 1)) (set! act (fx+ act 1)) (cset! s i 2 act) (memory-order-release))]
         [(quiet) (unless (fx= quiet (fx+ cons 1)) (set! quiet (fx+ cons 1)) (cset! s i 2 quiet) (memory-order-release))]
         [(credit) (unless (fx= held-k -1) (let ([k held-k]) (set! held-k -1) (return-credit! k)))]
         [(seeds seeds1) (when (fx> unacked 0)
                    (memory-order-release)
                    (set! cons (fx+ cons unacked)) (set! unacked 0) (cset! s i 1 cons))]
         [(logseeds logseeds1) (when (fx> unacked 0)
                       (memory-order-release)
                       (set! unacked 0) (publish-heads!))])
       (unless (unbox done) (loop))])))

(define (expected fan depth) (for/sum ([h (in-range (add1 depth))]) (expt fan h)))

;; the same work on ONE thread with a plain stack: no lanes, no counters, no detector (the floor)
(define (seq-trial fan depth L)
  (define stk-rem (make-fxvector (* 4 WLCAP) 0))
  (define stk-h (make-fxvector (* 4 WLCAP) 0))
  (define top 0)
  (define msgs 0)
  (define (push! r h) (fxvector-set! stk-rem top r) (fxvector-set! stk-h top h) (set! top (fx+ top 1)))
  (define (deliver! h) (set! msgs (fx+ msgs 1)) (if (fx= L 0) (children! h) (push! L h)))
  (define (children! h) (when (fx> h 0) (for ([j (in-range fan)]) (deliver! (fx- h 1)))))
  (define t0 (current-inexact-monotonic-milliseconds))
  (deliver! depth)
  (let loop ()
    (when (fx> top 0)
      (set! top (fx- top 1))
      (define rem (fxvector-ref stk-rem top)) (define h (fxvector-ref stk-h top))
      (spin-work WORK)
      (if (fx> rem 1) (push! (fx- rem 1) h) (children! h))
      (loop)))
  (values msgs (- (current-inexact-monotonic-milliseconds) t0)))
(define (~r x) (/ (round (* 10 x)) 10.0))
(define (median xs) (let ([v (sort xs <)]) (list-ref v (quotient (length v) 2))))

(define ALL-ROWS
  (list (list "CHAIN   fan=1 depth=20000 L=0" 1 20000 0 '(rounds scan atomic d2 flag act quiet defer seeds seeds1 logseeds logseeds1 credit))
        (list "BURST   fan=4 depth=6     L=0" 4 6 0 '(rounds scan atomic d2 flag act quiet defer seeds seeds1 logseeds logseeds1 credit))
        (list (format "CASCADE fan=1 depth=2000  L=~a" CASCADE-L) 1 2000 CASCADE-L '(d2 flag act quiet defer seeds seeds1 logseeds logseeds1 credit))
        (list (format "CASCADE2 fan=2 depth=9   L=~a" CASCADE-L) 2 9 CASCADE-L '(d2 flag act quiet defer seeds seeds1 logseeds logseeds1 credit))))
(define MODES-SEL (let ([m (getenv "MODES")]) (and m (map string->symbol (regexp-split #rx"," m)))))
(define ROWS0
  (let ([sel (getenv "ROWS")])
    (if sel
        (filter (λ (r) (for/or ([w (regexp-split #rx"," sel)]) (regexp-match? (regexp (string-append "^" w " ")) (car r)))) ALL-ROWS)
        ALL-ROWS)))
(define ROWS
  (for/list ([r ROWS0])
    (if MODES-SEL
        (list (list-ref r 0) (list-ref r 1) (list-ref r 2) (list-ref r 3) (filter (λ (m) (memq m MODES-SEL)) (list-ref r 4)))
        r)))

(define (run K)
  (define s (make-sys K))
  (for ([w ROWS])
    (define-values (name fan depth L modes) (apply values w))
    (define exp (expected fan depth))
    (for ([mode modes]) (trial s mode fan (min depth 50) L))            ; warm-up
    (define res (make-hasheq))                                         ; mode -> list of (wall consumed late)
    (define seqw '())
    (for ([rep REPS])
      (let-values ([(n w) (seq-trial fan depth L)])
        (unless (= n exp) (error 'seq "~a ~a" n exp))
        (set! seqw (cons w seqw)))
      (for ([mode modes])                                               ; modes interleaved within each rep
        (define-values (n w r lt) (trial s mode fan depth L))
        (hash-update! res mode (λ (l) (cons (list w n lt r) l)) '())))
    (printf "K=~a  ~a  ~a  msgs=~a  best ~a ms = ~a ns/msg   median ~a ns/msg   (one thread, no lanes, no detector)\n"
            K name (pad 'seq) exp (~r (apply min seqw)) (~r (/ (* 1e6 (apply min seqw)) exp)) (~r (/ (* 1e6 (median seqw)) exp)))
    (for ([mode modes])
      (define l (hash-ref res mode))
      (define walls (map car l))
      (define bad (for/sum ([x l]) (if (or (not (= (cadr x) exp)) (> (caddr x) 0)) 1 0)))
      (define lates (for/sum ([x l]) (caddr x)))
      (define lost (for/sum ([x l]) (- exp (cadr x))))
      (printf "K=~a  ~a  ~a  msgs=~a  best ~a ms = ~a ns/msg   median ~a ns/msg   premature-trials ~a/~a (late fires ~a, lost msgs ~a)~a\n"
              K name (pad mode) exp (~r (apply min walls)) (~r (/ (* 1e6 (apply min walls)) exp))
              (~r (/ (* 1e6 (median walls)) exp)) bad (length l) lates lost
              (if (eq? mode 'rounds) (format "  rounds=~a" (cadddr (car l))) "")))
    (flush-output)))
(define (pad m) (let ([s (symbol->string m)]) (string-append s (make-string (max 0 (- 8 (string-length s))) #\space))))

(printf "detect-w23.rkt — quiescence-detector repairs. K executors = #:pool 'own threads; detector = main thread.\n")
(printf "  CHAIN: one message alive (D hops). BURST: fan 4, depth 6 (5461 msgs). CASCADE: fan 1, each hop = L local fires.\n")
(printf "  WORK=~a fixnum iterations per local fire; REPS=~a (modes interleaved per rep); DRAIN=~a; processor-count=~a\n" WORK REPS (if DRAIN-IDLE? "idle" "every") (processor-count))
(for ([K (let ([a (current-command-line-arguments)]) (if (zero? (vector-length a)) '(2 4 8) (map string->number (vector->list a))))])
  (run K))
