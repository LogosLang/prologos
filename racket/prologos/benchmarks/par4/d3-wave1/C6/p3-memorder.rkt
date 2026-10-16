#lang racket/base
;; C6 probe 3 — memory ordering across two `#:pool 'own` threads on aarch64 (Apple Silicon).
;; Writer and reader are both parallel threads; main only waits.  Counts of violations are
;; the evidence; a variant that SHOULD be able to fail (plain MP on fixnums) is the power row.
(require racket/fixnum racket/unsafe/ops
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt"))

(define (pad) (make-vector 32 0))   ; keep hot boxes on separate cache lines

;; --- V1/V2: message passing on two fixnum boxes.  writer: x:=i ; y:=i.  reader: ry:=y ; rx:=x.
;; Under sequential consistency rx >= ry always.
(define (mp fenced? N)
  (define x (box 0)) (define _p1 (pad)) (define y (box 0)) (define _p2 (pad))
  (define stop (box #f)) (define viol (box 0)) (define reads (box 0))
  (define rd (thread #:pool 'own
                     (lambda ()
                       (let loop ([v 0] [r 0])
                         (if (unbox stop) (begin (set-box! viol v) (set-box! reads r))
                             (let* ([ry (unbox y)]
                                    [_ (when fenced? (memory-order-acquire))]
                                    [rx (unbox x)])
                               (loop (if (fx< rx ry) (fx+ v 1) v) (fx+ r 1))))))))
  (define wr (thread #:pool 'own
                     (lambda ()
                       (let loop ([i 1])
                         (when (fx<= i N)
                           (set-box! x i)
                           (when fenced? (memory-order-release))
                           (set-box! y i)
                           (loop (fx+ i 1))))
                       (set-box! stop #t))))
  (thread-wait wr) (thread-wait rd)
  (list 'violations (unbox viol) 'reader-iterations (unbox reads)))

;; --- V3/V4: SPSC lane append.  writer: slot[i] := (cons i i) ; count := i+1 (a fixnum).
;; reader: c := count ; e := slot[c-1] ; violation if e is still the initial #f.
(define (lane fenced? N)
  (define slots (make-vector N #f)) (define _p (pad))
  (define count (box 0)) (define _p2 (pad))
  (define stop (box #f)) (define viol (box 0)) (define reads (box 0))
  (define rd (thread #:pool 'own
                     (lambda ()
                       (let loop ([v 0] [r 0])
                         (if (unbox stop) (begin (set-box! viol v) (set-box! reads r))
                             (let ([c (unbox count)])
                               (when fenced? (memory-order-acquire))
                               (if (fx= c 0) (loop v r)
                                   (let ([e (vector-ref slots (fx- c 1))])
                                     (loop (if e v (fx+ v 1)) (fx+ r 1))))))))))
  (define wr (thread #:pool 'own
                     (lambda ()
                       (let loop ([i 0])
                         (when (fx< i N)
                           (vector-set! slots i (cons i i))
                           (when fenced? (memory-order-release))
                           (set-box! count (fx+ i 1))
                           (loop (fx+ i 1))))
                       (set-box! stop #t))))
  (thread-wait wr) (thread-wait rd)
  (list 'violations (unbox viol) 'reader-checks (unbox reads)))

;; --- V5: persistent CHAMP root published by a plain set-box! of a pointer (no explicit fences).
;; reader checks that keys i, i/2 and 0 of the version it sees are present with the right value.
(define (champ-pub N)
  (define pub (box (cons -1 champ-empty))) (define _p (pad))
  (define stop (box #f)) (define viol (box 0)) (define reads (box 0))
  (define (h k) (equal-hash-code k))
  (define rd (thread #:pool 'own
                     (lambda ()
                       (let loop ([v 0] [r 0])
                         (if (unbox stop) (begin (set-box! viol v) (set-box! reads r))
                             (let* ([p (unbox pub)] [i (car p)] [root (cdr p)])
                               (if (fx< i 0) (loop v r)
                                   (let ([ok (and (eqv? (champ-lookup root (h i) i) i)
                                                  (eqv? (champ-lookup root (h (quotient i 2)) (quotient i 2)) (quotient i 2))
                                                  (eqv? (champ-lookup root (h 0) 0) 0))])
                                     (loop (if ok v (fx+ v 1)) (fx+ r 1))))))))))
  (define wr (thread #:pool 'own
                     (lambda ()
                       (let loop ([i 0] [root champ-empty])
                         (when (fx< i N)
                           (define root* (champ-insert root (h i) i i))
                           (set-box! pub (cons i root*))
                           (loop (fx+ i 1) root*)))
                       (set-box! stop #t))))
  (thread-wait wr) (thread-wait rd)
  (list 'violations (unbox viol) 'reader-checks (unbox reads)))

(printf "aarch64 memory-order probe; each row: writer N ops, reader spins concurrently\n")
(for ([rep 2])
  (printf "V1 MP fixnums, plain        N=20M: ~a\n" (mp #f 20000000))
  (printf "V2 MP fixnums, rel/acq      N=20M: ~a\n" (mp #t 20000000))
  (printf "V3 lane append, plain count N=4M:  ~a\n" (lane #f 4000000))
  (printf "V4 lane append, rel/acq     N=4M:  ~a\n" (lane #t 4000000)))
(printf "V5 CHAMP root publish, plain set-box! N=300k: ~a\n" (champ-pub 300000))
