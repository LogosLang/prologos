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
;;
;; Migrated 2026-04-25 from the pre-D.5b TMS API
;; (tms-write/tms-cell-value/tms-read/tms-commit, deleted in the refactor
;; to the tms-cell struct + atms-write-cell interface). Each "depth"
;; here is realized as an atms with N assumptions, a TMS cell whose
;; values list grows by depth, and the believed worldview switched to
;; the full N-assumption set so reads must scan to find a supported
;; value. tms-commit no longer has a direct analog (the post-refactor
;; commit story is implicit in worldview narrowing); the closest
;; behavioural analog (worldview switching cost) is benchmarked instead.

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
    (define-values (a* _aid) (atms-assume a (string->symbol (format "h~a" i)) i))
    a*))

;; Build a hasheq of N assumption-ids (used as sets)
(define (make-assumption-set n)
  (for/fold ([s (hasheq)])
            ([i (in-range n)])
    (hash-set s (assumption-id i) #t)))

;; Build an atms in which a TMS cell at `cell-key` holds `d` distinct
;; supported values, each justified by a deeper-nested support set.
;; The believed worldview is the union of all `d` assumptions, so
;; (atms-read-cell a cell-key) traverses the values list before finding
;; a supported value — the read cost grows with `d`.
;;
;; Mirrors the old `make-tms-at-depth` shape: depth = number of
;; speculation layers wrapping a single TMS cell.
(define (atms-at-depth d cell-key)
  (define a0 (make-atms-with-assumptions d))
  ;; Write d distinct values, each with progressively larger support.
  ;; Newest first in the values list, so the FIRST value has full support
  ;; (depth d) and is the one a read under the believed=all worldview
  ;; finds — the implementation walks the list head-first.
  (for/fold ([a a0])
            ([i (in-range d)])
    (define support
      (for/fold ([s (hasheq)])
                ([j (in-range (add1 i))])
        (hash-set s (assumption-id j) #t)))
    (atms-write-cell a cell-key (list 'val i) support)))

;; Stacks of assumption-ids at depths 1, 2, 5, 10 — used to build
;; support sets for write benchmarks.
(define (support-set-of-depth d)
  (for/fold ([s (hasheq)])
            ([i (in-range d)])
    (hash-set s (assumption-id i) #t)))

;; ============================================================
;; Benchmark 1: TMS read at varying depths
;; ============================================================
;;
;; Old `tms-read tcv stack`: cost was O(stack-depth) walk over a
;; per-cell stack of speculative bindings.
;;
;; New `atms-read-cell a key`: cost is O(values-length) walk until a
;; value's support is a subset of believed. We model "depth d" by an
;; atms whose target cell carries d supported values, with the believed
;; worldview = d-element assumption set, so the FIRST values-list entry
;; matches and the per-call cost is dominated by the hash-subset? check
;; over a d-element support set.

(define cell-key 'target)
(define atms-depth-1 (atms-at-depth 1 cell-key))
(define atms-depth-2 (atms-at-depth 2 cell-key))
(define atms-depth-5 (atms-at-depth 5 cell-key))
(define atms-depth-10 (atms-at-depth 10 cell-key))

(bench "atms-read-cell depth=1 x100000"
    (for ([_ (in-range 100000)])
    (atms-read-cell atms-depth-1 cell-key)))

(bench "atms-read-cell depth=5 x100000"
    (for ([_ (in-range 100000)])
    (atms-read-cell atms-depth-5 cell-key)))

(bench "atms-read-cell depth=10 x100000"
    (for ([_ (in-range 100000)])
    (atms-read-cell atms-depth-10 cell-key)))

;; ============================================================
;; Benchmark 2: TMS write at varying depths
;; ============================================================
;;
;; Old `tms-write tcv stack value`: cost was O(stack-depth) — pushing
;; a frame keyed on the depth-stack.
;;
;; New `atms-write-cell a key value support`: cost is O(1) to build the
;; supported-value + O(1) hash-set into atms-tms-cells. The "depth" is
;; encoded in the support set's size; constructing an N-element support
;; set is the dominant cost. We benchmark write of values whose support
;; set is depth N.

(define support-1 (support-set-of-depth 1))
(define support-5 (support-set-of-depth 5))
(define support-10 (support-set-of-depth 10))

(bench "atms-write-cell depth=1 x50000"
    (for ([_ (in-range 50000)])
    (atms-write-cell atms-depth-1 cell-key 'new support-1)))

(bench "atms-write-cell depth=5 x50000"
    (for ([_ (in-range 50000)])
    (atms-write-cell atms-depth-5 cell-key 'new support-5)))

(bench "atms-write-cell depth=10 x50000"
    (for ([_ (in-range 50000)])
    (atms-write-cell atms-depth-10 cell-key 'new support-10)))

;; ============================================================
;; Benchmark 3: Worldview switching
;; ============================================================
;;
;; Old `tms-commit tcv aid`: promoted a contingent value to permanent
;; — the operation no longer exists. The closest behavioural analog is
;; `atms-with-worldview`, which switches the believed set; subsequent
;; reads then re-resolve against the new worldview. We benchmark the
;; switch itself (cheap struct-copy) and also a switch + read cycle
;; (the more meaningful end-to-end shape).

(define narrow-worldview-1 (support-set-of-depth 1))
(define narrow-worldview-5 (support-set-of-depth 5))

(bench "atms-with-worldview narrow x100000"
    (for ([_ (in-range 100000)])
    (atms-with-worldview atms-depth-10 narrow-worldview-1)))

(bench "atms-with-worldview narrow + read x50000"
    (for ([_ (in-range 50000)])
    (atms-read-cell (atms-with-worldview atms-depth-10 narrow-worldview-5)
                    cell-key)))

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
