#lang racket/base

;;;
;;; test-propagator-bsp.rkt — Phase 2.5: BSP, Threshold, Parallel
;;;
;;; Tests for BSP (Jacobi) scheduler, threshold/barrier propagators,
;;; and parallel executor via Racket futures.
;;;

(require rackunit
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Test Merge Functions
;; ========================================

;; Flat lattice: 'bot → value → 'top
(define (flat-merge old new)
  (cond [(eq? old 'bot) new]
        [(eq? new 'bot) old]
        [(equal? old new) old]
        [else 'top]))

(define (flat-contradicts? v) (eq? v 'top))

;; Max merge (numeric cells)
(define (max-merge old new) (max old new))

;; Set merge (list-based)
(define (set-merge old new)
  (let loop ([items new] [result old])
    (cond
      [(null? items) result]
      [(member (car items) result) (loop (cdr items) result)]
      [else (loop (cdr items) (cons (car items) result))])))

;; ========================================
;; Helper fire-fns
;; ========================================

;; Copy propagator: reads src, writes to dst
(define (make-copy-fire-fn src dst)
  (lambda (net)
    (net-cell-write net dst (net-cell-read net src))))

;; Adder propagator: reads a+b, writes to c
(define (make-adder-fire-fn a b c)
  (lambda (net)
    (define va (net-cell-read net a))
    (define vb (net-cell-read net b))
    (net-cell-write net c (+ va vb))))

;; ========================================
;; 2.5a: BSP Core (10 tests)
;; ========================================

(test-case "bsp: simple chain A -> B converges"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 _p0) (net-add-propagator net2 (list ca) (list cb)
                              (make-copy-fire-fn ca cb)))
  (define net4 (run-to-quiescence-bsp (net-cell-write net3 ca 'hello)))
  (check-true (net-quiescent? net4))
  (check-equal? (net-cell-read net4 cb) 'hello))

(test-case "bsp: diamond A -> B, A -> C, B+C -> D converges"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 max-merge))
  (define-values (net4 cd) (net-new-cell net3 0 max-merge))
  ;; A -> B (copy), A -> C (copy), B+C -> D (adder)
  (define-values (net5 _p1) (net-add-propagator net4 (list ca) (list cb)
                              (make-copy-fire-fn ca cb)))
  (define-values (net6 _p2) (net-add-propagator net5 (list ca) (list cc)
                              (make-copy-fire-fn ca cc)))
  (define-values (net7 _p3) (net-add-propagator net6 (list cb cc) (list cd)
                              (make-adder-fire-fn cb cc cd)))
  (define result (run-to-quiescence-bsp (net-cell-write net7 ca 5)))
  (check-equal? (net-cell-read result cb) 5)
  (check-equal? (net-cell-read result cc) 5)
  (check-equal? (net-cell-read result cd) 10))

(test-case "bsp: fan-out one input two outputs"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cc) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 _p1) (net-add-propagator net3 (list ca) (list cb)
                              (make-copy-fire-fn ca cb)))
  (define-values (net5 _p2) (net-add-propagator net4 (list ca) (list cc)
                              (make-copy-fire-fn ca cc)))
  (define result (run-to-quiescence-bsp (net-cell-write net5 ca 42)))
  (check-equal? (net-cell-read result cb) 42)
  (check-equal? (net-cell-read result cc) 42))

(test-case "bsp: chain of 5 requires multiple rounds"
  (define net0 (make-prop-network))
  (define-values (net1 c0) (net-new-cell net0 0 max-merge))
  (define-values (net2 c1) (net-new-cell net1 0 max-merge))
  (define-values (net3 c2) (net-new-cell net2 0 max-merge))
  (define-values (net4 c3) (net-new-cell net3 0 max-merge))
  (define-values (net5 c4) (net-new-cell net4 0 max-merge))
  ;; c0 -> c1 -> c2 -> c3 -> c4
  (define-values (n1 _p1) (net-add-propagator net5 (list c0) (list c1)
                             (make-copy-fire-fn c0 c1)))
  (define-values (n2 _p2) (net-add-propagator n1 (list c1) (list c2)
                             (make-copy-fire-fn c1 c2)))
  (define-values (n3 _p3) (net-add-propagator n2 (list c2) (list c3)
                             (make-copy-fire-fn c2 c3)))
  (define-values (n4 _p4) (net-add-propagator n3 (list c3) (list c4)
                             (make-copy-fire-fn c3 c4)))
  (define result (run-to-quiescence-bsp (net-cell-write n4 c0 99)))
  (check-true (net-quiescent? result))
  (check-equal? (net-cell-read result c4) 99))

(test-case "bsp: fuel decreases by N per round"
  (define net0 (make-prop-network 100))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 max-merge))
  ;; 2 propagators: A->B and A->C (both fire in round 1)
  (define-values (net4 _p1) (net-add-propagator net3 (list ca) (list cb)
                              (make-copy-fire-fn ca cb)))
  (define-values (net5 _p2) (net-add-propagator net4 (list ca) (list cc)
                              (make-copy-fire-fn ca cc)))
  ;; Write to A → 2 propagators on worklist → round fires both → fuel -= 2
  (define net6 (net-cell-write net5 ca 10))
  (define result (run-to-quiescence-bsp net6))
  ;; Initial fuel was 100. We had 2 initial firings + 2 from the write = ~4 total
  ;; But dedup removes duplicates. The key check: fuel used > 0 and reasonable
  (check-true (< (net-fuel-remaining result) 100))
  (check-true (> (net-fuel-remaining result) 90)))

(test-case "bsp: worklist deduplication"
  (define net0 (make-prop-network 100))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 pid) (net-add-propagator net2 (list ca) (list cb)
                              (make-copy-fire-fn ca cb)))
  ;; Manually add pid to worklist twice
  (define net4 (struct-copy prop-network net3
                 [worklist (list pid pid pid)]))
  (define result (run-to-quiescence-bsp net4))
  ;; Dedup should reduce 3 → 1, so fuel cost is 1 for this round
  (check-true (net-quiescent? result))
  ;; Fuel: started at 100, one deduped round costs 1
  (check-equal? (net-fuel-remaining result) 99))

(test-case "bsp: contradiction halts"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge flat-contradicts?))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  ;; Write two different values → flat-top → contradiction
  (define net3 (net-cell-write (net-cell-write net2 ca 1) ca 2))
  (check-true (net-contradiction? net3))
  ;; BSP on contradicted net returns immediately
  (define result (run-to-quiescence-bsp net3))
  (check-true (net-contradiction? result)))

(test-case "bsp: already-contradicted returns immediately"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge flat-contradicts?))
  (define net2 (net-cell-write (net-cell-write net1 ca 1) ca 2))
  (check-true (net-contradiction? net2))
  (define result (run-to-quiescence-bsp net2))
  (check-eq? result net2))

(test-case "bsp: empty worklist returns immediately"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 42 max-merge))
  ;; No propagators, no worklist
  (check-true (net-quiescent? net1))
  (define result (run-to-quiescence-bsp net1))
  (check-eq? result net1))

(test-case "bsp: same fixpoint as gauss-seidel"
  ;; Build a moderate network: diamond + tail chain
  ;; A -> B, A -> C, B+C -> D, D -> E, E -> F
  (define net0 (make-prop-network))
  (define-values (n1 ca) (net-new-cell net0 0 max-merge))
  (define-values (n2 cb) (net-new-cell n1 0 max-merge))
  (define-values (n3 cc) (net-new-cell n2 0 max-merge))
  (define-values (n4 cd) (net-new-cell n3 0 max-merge))
  (define-values (n5 ce) (net-new-cell n4 0 max-merge))
  (define-values (n6 cf) (net-new-cell n5 0 max-merge))
  ;; Diamond
  (define-values (n7 _p1) (net-add-propagator n6 (list ca) (list cb)
                             (make-copy-fire-fn ca cb)))
  (define-values (n8 _p2) (net-add-propagator n7 (list ca) (list cc)
                             (make-copy-fire-fn ca cc)))
  (define-values (n9 _p3) (net-add-propagator n8 (list cb cc) (list cd)
                             (make-adder-fire-fn cb cc cd)))
  ;; Tail chain
  (define-values (n10 _p4) (net-add-propagator n9 (list cd) (list ce)
                              (make-copy-fire-fn cd ce)))
  (define-values (n11 _p5) (net-add-propagator n10 (list ce) (list cf)
                              (make-copy-fire-fn ce cf)))
  ;; Write to A
  (define base (net-cell-write n11 ca 7))
  ;; Run both schedulers
  (define gs-result (run-to-quiescence base))
  (define bsp-result (run-to-quiescence-bsp base))
  ;; Same fixpoint — all cells equal
  (for ([cid (list ca cb cc cd ce cf)])
    (check-equal? (net-cell-read bsp-result cid)
                  (net-cell-read gs-result cid)
                  (format "cell ~a mismatch" cid))))

;; ========================================
;; 2.5b: Threshold Propagators (5 tests)
;; ========================================

(test-case "threshold: fires when condition met"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  ;; Threshold: fire when ca >= 5, write 100 to cb
  (define-values (net3 _)
    (net-add-threshold net2 ca (lambda (v) (>= v 5))
                       '() (list cb)
                       (lambda (net) (net-cell-write net cb 100))))
  ;; Write 10 to ca (>= 5 → threshold met)
  (define result (run-to-quiescence-bsp (net-cell-write net3 ca 10)))
  (check-equal? (net-cell-read result cb) 100))

(test-case "threshold: does NOT fire below threshold"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  ;; Threshold: fire when ca >= 10
  (define-values (net3 _)
    (net-add-threshold net2 ca (lambda (v) (>= v 10))
                       '() (list cb)
                       (lambda (net) (net-cell-write net cb 100))))
  ;; Write 3 to ca (< 10 → threshold NOT met)
  (define result (run-to-quiescence-bsp (net-cell-write net3 ca 3)))
  (check-equal? (net-cell-read result cb) 0))  ;; unchanged from initial

(test-case "threshold: multi-round convergence with gating"
  ;; A -> B (copy), threshold on B >= 5 triggers C = 999
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 max-merge))
  ;; A -> B
  (define-values (net4 _p1) (net-add-propagator net3 (list ca) (list cb)
                               (make-copy-fire-fn ca cb)))
  ;; Threshold on B: fire when >= 5, write 999 to C
  (define-values (net5 _p2)
    (net-add-threshold net4 cb (lambda (v) (>= v 5))
                       '() (list cc)
                       (lambda (net) (net-cell-write net cc 999))))
  ;; Write 7 to A → propagates to B → threshold met → C = 999
  (define result (run-to-quiescence-bsp (net-cell-write net5 ca 7)))
  (check-equal? (net-cell-read result cb) 7)
  (check-equal? (net-cell-read result cc) 999))

(test-case "barrier: fires when ALL conditions met"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 max-merge))
  ;; Barrier: fire when ca >= 5 AND cb >= 3, write 1 to cc
  (define-values (net4 _)
    (net-add-barrier net3
                     (list (cons ca (lambda (v) (>= v 5)))
                           (cons cb (lambda (v) (>= v 3))))
                     '() (list cc)
                     (lambda (net) (net-cell-write net cc 1))))
  ;; Both conditions met
  (define net5 (net-cell-write (net-cell-write net4 ca 10) cb 5))
  (define result (run-to-quiescence-bsp net5))
  (check-equal? (net-cell-read result cc) 1))

(test-case "barrier: partial conditions block firing"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 max-merge))
  ;; Barrier: fire when ca >= 5 AND cb >= 10
  (define-values (net4 _)
    (net-add-barrier net3
                     (list (cons ca (lambda (v) (>= v 5)))
                           (cons cb (lambda (v) (>= v 10))))
                     '() (list cc)
                     (lambda (net) (net-cell-write net cc 1))))
  ;; Only ca meets condition (cb = 3 < 10)
  (define net5 (net-cell-write (net-cell-write net4 ca 10) cb 3))
  (define result (run-to-quiescence-bsp net5))
  (check-equal? (net-cell-read result cc) 0))  ;; unchanged

;; ========================================
;; 2.5c: Parallel Executor (3 tests)
;; ========================================

(test-case "parallel: same result as sequential for diamond"
  (define net0 (make-prop-network))
  (define-values (n1 ca) (net-new-cell net0 0 max-merge))
  (define-values (n2 cb) (net-new-cell n1 0 max-merge))
  (define-values (n3 cc) (net-new-cell n2 0 max-merge))
  (define-values (n4 cd) (net-new-cell n3 0 max-merge))
  (define-values (n5 _p1) (net-add-propagator n4 (list ca) (list cb)
                            (make-copy-fire-fn ca cb)))
  (define-values (n6 _p2) (net-add-propagator n5 (list ca) (list cc)
                            (make-copy-fire-fn ca cc)))
  (define-values (n7 _p3) (net-add-propagator n6 (list cb cc) (list cd)
                            (make-adder-fire-fn cb cc cd)))
  (define base (net-cell-write n7 ca 5))
  ;; Run with parallel executor (threshold=1 to force futures)
  (define par-result
    (run-to-quiescence-bsp base #:executor (make-parallel-fire-all 1)))
  (define seq-result (run-to-quiescence-bsp base))
  ;; Same fixpoint
  (for ([cid (list ca cb cc cd)])
    (check-equal? (net-cell-read par-result cid)
                  (net-cell-read seq-result cid))))

(test-case "parallel: correct below threshold (sequential fallback)"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 _p0) (net-add-propagator net2 (list ca) (list cb)
                              (make-copy-fire-fn ca cb)))
  ;; threshold=100 — only 1 propagator, will fall back to sequential
  (define result
    (run-to-quiescence-bsp (net-cell-write net3 ca 'world)
                           #:executor (make-parallel-fire-all 100)))
  (check-equal? (net-cell-read result cb) 'world))

(test-case "parallel: large fan-out (20 propagators) converges"
  (define net0 (make-prop-network))
  (define-values (net1 src) (net-new-cell net0 0 max-merge))
  ;; Create 20 output cells and 20 copy propagators
  (define-values (net-final outputs)
    (for/fold ([net net1] [outs '()])
              ([i (in-range 20)])
      (define-values (n cid) (net-new-cell net 0 max-merge))
      (define-values (n2 _pi) (net-add-propagator n (list src) (list cid)
                               (make-copy-fire-fn src cid)))
      (values n2 (cons cid outs))))
  ;; Write 42 to source, run parallel (threshold=1)
  (define result
    (run-to-quiescence-bsp (net-cell-write net-final src 42)
                           #:executor (make-parallel-fire-all 1)))
  ;; All 20 outputs should be 42
  (for ([cid (in-list outputs)])
    (check-equal? (net-cell-read result cid) 42)))
