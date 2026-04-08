#lang racket/base

;; bench-bsp-le-track2.rkt — Pre-0 micro-benchmarks for BSP-LE Track 2
;;
;; Measures the building blocks of propagator-native search BEFORE
;; implementation begins. These are BASELINE measurements of the
;; infrastructure Track 2 will build on:
;;
;;   1. TMS read/write at varying speculation depths (current parameter-based)
;;   2. ATMS operations: assume, amb, nogood, consistency check
;;   3. Cell operations under speculation (current infrastructure)
;;   4. Set operations on assumption-id sets (worldview lattice primitives)
;;   5. Prop-network creation + cell allocation (PU creation cost model)
;;
;; These inform the design: if TMS depth-10 reads are 100× depth-1,
;; the PU-per-branch architecture must minimize depth. If set-intersection
;; is cheap, the filtered nogood watcher is viable. Etc.
;;
;; Run: racket benchmarks/micro/bench-bsp-le-track2.rkt

(require "../../tools/bench-micro.rkt"
         "../../propagator.rkt"
         "../../atms.rkt"
         "../../champ.rkt"
         racket/set)

;; ============================================================
;; Helpers
;; ============================================================

;; Build an ATMS with N assumptions
(define (make-atms-with-assumptions n)
  (for/fold ([a (atms-empty)])
            ([i (in-range n)])
    (define-values (a* _aid) (atms-assume a (format "h~a" i) i))
    a*))

;; Build a hasheq of N assumption-ids (used as sets)
(define (make-assumption-set n)
  (for/fold ([s (hasheq)])
            ([i (in-range n)])
    (hash-set s (assumption-id i) #t)))

;; Build a TMS cell value at depth d
(define (make-tms-at-depth d base-val)
  (define stack (for/list ([i (in-range d)]) (assumption-id i)))
  (tms-write (tms-cell-value base-val (hasheq)) stack 'branch-value))

;; ============================================================
;; Benchmark 1: TMS read at varying depths
;; ============================================================

(define tms-depth-1 (make-tms-at-depth 1 'base))
(define tms-depth-2 (make-tms-at-depth 2 'base))
(define tms-depth-5 (make-tms-at-depth 5 'base))
(define tms-depth-10 (make-tms-at-depth 10 'base))

(define stack-1 (list (assumption-id 0)))
(define stack-2 (for/list ([i 2]) (assumption-id i)))
(define stack-5 (for/list ([i 5]) (assumption-id i)))
(define stack-10 (for/list ([i 10]) (assumption-id i)))

(bench "tms-read depth=1 x100000"
    (for ([_ (in-range 100000)])
    (tms-read tms-depth-1 stack-1)))

(bench "tms-read depth=5 x100000"
    (for ([_ (in-range 100000)])
    (tms-read tms-depth-5 stack-5)))

(bench "tms-read depth=10 x100000"
    (for ([_ (in-range 100000)])
    (tms-read tms-depth-10 stack-10)))

;; ============================================================
;; Benchmark 2: TMS write at varying depths
;; ============================================================

(bench "tms-write depth=1 x50000"
    (for ([_ (in-range 50000)])
    (tms-write (tms-cell-value 'base (hasheq)) stack-1 'val)))

(bench "tms-write depth=5 x50000"
    (for ([_ (in-range 50000)])
    (tms-write (tms-cell-value 'base (hasheq)) stack-5 'val)))

(bench "tms-write depth=10 x50000"
    (for ([_ (in-range 50000)])
    (tms-write (tms-cell-value 'base (hasheq)) stack-10 'val)))

;; ============================================================
;; Benchmark 3: TMS commit
;; ============================================================

(bench "tms-commit leaf x100000"
    (for ([_ (in-range 100000)])
    (tms-commit tms-depth-1 (assumption-id 0))))

(bench "tms-commit nested x50000"
    (for ([_ (in-range 50000)])
    (tms-commit tms-depth-5 (assumption-id 0))))

;; ============================================================
;; Benchmark 4: ATMS operations
;; ============================================================

(define atms-10 (make-atms-with-assumptions 10))

(bench "atms-assume x10000"
    (for ([_ (in-range 10000)])
    (atms-assume (atms-empty) "h" 42)))

(bench "atms-amb (3 alternatives) x5000"
    (for ([_ (in-range 5000)])
    (atms-amb (atms-empty) '(a b c))))

(bench "atms-amb (10 alternatives) x2000"
    (for ([_ (in-range 2000)])
    (atms-amb (atms-empty) '(a b c d e f g h i j))))

(bench "atms-consistent? (10 assumptions, 5 nogoods) x50000"
    (let* ([a0 (make-atms-with-assumptions 10)]
         ;; Add 5 nogoods (pairs of assumptions)
         [a1 (atms-add-nogood a0 (hasheq (assumption-id 0) #t (assumption-id 1) #t))]
         [a2 (atms-add-nogood a1 (hasheq (assumption-id 2) #t (assumption-id 3) #t))]
         [a3 (atms-add-nogood a2 (hasheq (assumption-id 4) #t (assumption-id 5) #t))]
         [a4 (atms-add-nogood a3 (hasheq (assumption-id 6) #t (assumption-id 7) #t))]
         [a5 (atms-add-nogood a4 (hasheq (assumption-id 8) #t (assumption-id 9) #t))]
         [test-set (hasheq (assumption-id 0) #t (assumption-id 2) #t (assumption-id 4) #t)])
    (for ([_ (in-range 50000)])
      (atms-consistent? a5 test-set))))

;; ============================================================
;; Benchmark 5: Set operations (worldview lattice primitives)
;; ============================================================

(define set-10 (make-assumption-set 10))
(define set-5a (make-assumption-set 5))
(define set-5b (for/fold ([s (hasheq)]) ([i (in-range 5 10)])
                 (hash-set s (assumption-id i) #t)))
(define nogood-2 (hasheq (assumption-id 3) #t (assumption-id 7) #t))

(bench "set-union (10 + 5 elements) x100000"
    (for ([_ (in-range 100000)])
    (for/fold ([s set-10]) ([(k v) (in-hash set-5a)])
      (hash-set s k v))))

(bench "set-intersection check (10 ∩ 2-element nogood) x200000"
    (for ([_ (in-range 200000)])
    (for/or ([(k _v) (in-hash nogood-2)])
      (hash-has-key? set-10 k))))

(bench "subset? check (2 ⊆ 10) x200000"
    (for ([_ (in-range 200000)])
    (for/and ([(k _v) (in-hash nogood-2)])
      (hash-has-key? set-10 k))))

;; ============================================================
;; Benchmark 6: Prop-network creation + cell allocation
;; ============================================================

(bench "make-prop-network x10000"
    (for ([_ (in-range 10000)])
    (make-prop-network)))

(bench "net-new-cell x5000 (on fresh network)"
    (for ([_ (in-range 5000)])
    (define net (make-prop-network))
    (net-new-cell net 'bot (lambda (a b) b))))

(bench "net-new-cell x100 chained (growing network)"
    (for ([_ (in-range 100)])
    (for/fold ([net (make-prop-network)])
              ([i (in-range 100)])
      (define-values (net2 _cid) (net-new-cell net 'bot (lambda (a b) b)))
      net2)))

;; Network with 100 cells: how expensive is cell-write?
(define net-100
  (for/fold ([net (make-prop-network)])
            ([i (in-range 100)])
    (define-values (net2 _cid) (net-new-cell net 'bot (lambda (a b) b)))
    net2))

(bench "net-cell-write on 100-cell network x10000"
    (for ([_ (in-range 10000)])
    (net-cell-write net-100 (cell-id 50) 'new-val)))

;; ============================================================
;; Benchmark 7: Propagator installation cost
;; ============================================================

(bench "net-add-propagator x2000 (on fresh network with 2 cells)"
    (for ([_ (in-range 2000)])
    (define net0 (make-prop-network))
    (define-values (net1 cid1) (net-new-cell net0 'bot (lambda (a b) b)))
    (define-values (net2 cid2) (net-new-cell net1 'bot (lambda (a b) b)))
    (define-values (net3 _pid) (net-add-propagator net2 (list cid1) (list cid2)
                                  (lambda (net) net)))
    net3))

;; ============================================================
;; Benchmark 8: run-to-quiescence overhead
;; ============================================================

;; Empty network (no propagators): pure scheduler overhead
(bench "run-to-quiescence empty network x10000"
    (for ([_ (in-range 10000)])
    (run-to-quiescence (make-prop-network))))

;; Network with 1 propagator + 2 cells
(define (make-simple-propagator-net)
  (define net0 (make-prop-network))
  (define-values (net1 in-cid) (net-new-cell net0 0 +))
  (define-values (net2 out-cid) (net-new-cell net1 0 +))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list in-cid) (list out-cid)
      (lambda (net)
        (define v (net-cell-read net in-cid))
        (net-cell-write net out-cid (+ v 1)))))
  (net-cell-write net3 in-cid 42))

(bench "run-to-quiescence 1 propagator x5000"
    (for ([_ (in-range 5000)])
    (run-to-quiescence (make-simple-propagator-net))))
