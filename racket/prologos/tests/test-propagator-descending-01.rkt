#lang racket/base

;;;
;;; Tests for WFLE Phase 1: Descending Cells in Propagator Network
;;; Verifies: net-new-cell-desc, net-cell-direction, meet semantics,
;;;           mixed ascending/descending coexistence, scheduler convergence.
;;;

(require rackunit
         racket/list
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Lattice helpers
;; ========================================

;; Boolean lattice: false < true
;; join = or, meet = and
(define (bool-join a b) (or a b))
(define (bool-meet a b) (and a b))

;; Max merge (ascending numeric)
(define (max-merge old new) (max old new))

;; Min merge (descending numeric) — meet in the numeric lattice [0, +inf]
(define (min-merge old new) (min old new))

;; Set lattice: join = union, meet = intersection
(define (set-join a b) (remove-duplicates (append a b)))
(define (set-intersect a b) (filter (lambda (x) (member x b)) a))

;; ========================================
;; 1. Cell creation basics
;; ========================================

(test-case "desc/creates-cell-with-top-value"
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell-desc net #t bool-meet))
  (check-equal? (net-cell-read net1 cid) #t))

(test-case "desc/read-returns-top-for-fresh"
  ;; Numeric lattice: top = +inf.0
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell-desc net +inf.0 min-merge))
  (check-equal? (net-cell-read net1 cid) +inf.0))

;; ========================================
;; 2. Direction queries
;; ========================================

(test-case "desc/direction-returns-descending"
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell-desc net #t bool-meet))
  (check-equal? (net-cell-direction net1 cid) 'descending))

(test-case "desc/direction-returns-ascending-for-regular"
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell net 0 max-merge))
  (check-equal? (net-cell-direction net1 cid) 'ascending))

;; ========================================
;; 3. Meet semantics via net-cell-write
;; ========================================

(test-case "desc/write-narrows-descending-cell"
  ;; Numeric descending cell: top = 100, meet = min
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell-desc net 100 min-merge))
  ;; Write 50 — should narrow from 100 to 50
  (define net2 (net-cell-write net1 cid 50))
  (check-equal? (net-cell-read net2 cid) 50))

(test-case "desc/write-noop-when-meet-equals-old"
  ;; Write 200 to a cell at 100 with min-merge — min(100, 200) = 100, no change
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell-desc net 100 min-merge))
  (define net2 (net-cell-write net1 cid 200))
  ;; Should be the same network object (no change)
  (check-eq? net1 net2))

(test-case "desc/contradiction-at-bot"
  ;; Descending bool cell: top = #t, contradicts at #f (bot)
  (define net (make-prop-network))
  (define-values (net1 cid)
    (net-new-cell-desc net #t bool-meet (lambda (v) (not v))))
  ;; Write #f — meet(#t, #f) = #f, which is bot → contradiction
  (define net2 (net-cell-write net1 cid #f))
  (check-true (net-contradiction? net2)))

;; ========================================
;; 4. Mixed ascending + descending coexistence
;; ========================================

(test-case "desc/ascending-still-works-in-mixed-network"
  (define net (make-prop-network))
  ;; Create an ascending cell
  (define-values (net1 asc-id) (net-new-cell net 0 max-merge))
  ;; Create a descending cell
  (define-values (net2 desc-id) (net-new-cell-desc net1 100 min-merge))
  ;; Write to ascending — should still join (max)
  (define net3 (net-cell-write net2 asc-id 42))
  (check-equal? (net-cell-read net3 asc-id) 42)
  ;; Descending cell unchanged
  (check-equal? (net-cell-read net3 desc-id) 100))

(test-case "desc/mixed-cells-coexist"
  (define net (make-prop-network))
  (define-values (net1 a1) (net-new-cell net 0 max-merge))
  (define-values (net2 d1) (net-new-cell-desc net1 100 min-merge))
  (define-values (net3 a2) (net-new-cell net2 0 max-merge))
  (define-values (net4 d2) (net-new-cell-desc net3 +inf.0 min-merge))
  ;; Verify directions
  (check-equal? (net-cell-direction net4 a1) 'ascending)
  (check-equal? (net-cell-direction net4 d1) 'descending)
  (check-equal? (net-cell-direction net4 a2) 'ascending)
  (check-equal? (net-cell-direction net4 d2) 'descending)
  ;; Verify values
  (check-equal? (net-cell-read net4 a1) 0)
  (check-equal? (net-cell-read net4 d1) 100)
  (check-equal? (net-cell-read net4 a2) 0)
  (check-equal? (net-cell-read net4 d2) +inf.0))

;; ========================================
;; 5. Propagators with mixed direction cells
;; ========================================

(test-case "desc/propagator-ascending-to-descending"
  ;; Ascending cell writes to descending cell via propagator
  ;; Scenario: asc cell accumulates max, propagator caps desc cell
  (define net (make-prop-network))
  (define-values (net1 asc-id) (net-new-cell net 0 max-merge))
  (define-values (net2 desc-id) (net-new-cell-desc net1 100 min-merge))
  ;; Propagator: when asc changes, write (100 - asc) to desc
  (define-values (net3 _pid)
    (net-add-propagator net2
      (list asc-id) (list desc-id)
      (lambda (n)
        (define v (net-cell-read n asc-id))
        (net-cell-write n desc-id (- 100 v)))))
  ;; Write 30 to ascending → propagator fires → desc gets min(100, 70) = 70
  (define net4 (net-cell-write net3 asc-id 30))
  (define net5 (run-to-quiescence net4))
  (check-equal? (net-cell-read net5 asc-id) 30)
  (check-equal? (net-cell-read net5 desc-id) 70))

(test-case "desc/propagator-descending-to-ascending"
  ;; Descending cell writes to ascending cell via propagator
  (define net (make-prop-network))
  (define-values (net1 desc-id) (net-new-cell-desc net 100 min-merge))
  (define-values (net2 asc-id) (net-new-cell net1 0 max-merge))
  ;; Propagator: when desc changes, write desc/2 to asc
  (define-values (net3 _pid)
    (net-add-propagator net2
      (list desc-id) (list asc-id)
      (lambda (n)
        (define v (net-cell-read n desc-id))
        (net-cell-write n asc-id (quotient v 2)))))
  ;; Write 60 to desc → meet(100,60)=60 → propagator fires → asc gets max(0,30)=30
  (define net4 (net-cell-write net3 desc-id 60))
  (define net5 (run-to-quiescence net4))
  (check-equal? (net-cell-read net5 desc-id) 60)
  (check-equal? (net-cell-read net5 asc-id) 30))

;; ========================================
;; 6. Scheduler convergence
;; ========================================

(test-case "desc/gauss-seidel-mixed-convergence"
  ;; Two-cell system: asc starts at 0, desc starts at 10
  ;; Propagator A→D: write asc+1 to desc (narrowing via min)
  ;; Propagator D→A: write desc-1 to asc (accumulating via max)
  ;; Should converge: asc=5, desc=5 (or close, depending on firing order)
  (define net (make-prop-network))
  (define-values (net1 asc-id) (net-new-cell net 0 max-merge))
  (define-values (net2 desc-id) (net-new-cell-desc net1 10 min-merge))
  (define-values (net3 p1)
    (net-add-propagator net2
      (list asc-id) (list desc-id)
      (lambda (n)
        (define v (net-cell-read n asc-id))
        (net-cell-write n desc-id (+ v 1)))))
  (define-values (net4 p2)
    (net-add-propagator net3
      (list desc-id) (list asc-id)
      (lambda (n)
        (define v (net-cell-read n desc-id))
        (net-cell-write n asc-id (- v 1)))))
  (define net5 (run-to-quiescence net4))
  (check-false (net-contradiction? net5))
  ;; Both should converge to a fixpoint where asc+1 >= desc and desc-1 <= asc
  ;; i.e., asc+1 >= desc >= asc+1 → desc = asc+1
  ;; and desc-1 <= asc, so asc >= desc-1 = asc → holds.
  ;; Firing order (LIFO worklist): p2 fires first (added last)
  ;; p2: desc=10 → writes 9 to asc → max(0,9)=9. asc changed, p1 enqueued.
  ;; p1: asc=9 → writes 10 to desc → min(10,10)=10. No change.
  ;; Quiescent: asc=9, desc=10
  (check-equal? (net-cell-read net5 asc-id) 9)
  (check-equal? (net-cell-read net5 desc-id) 10))

(test-case "desc/bsp-mixed-convergence"
  ;; Same setup as Gauss-Seidel, but using BSP scheduler
  (define net (make-prop-network))
  (define-values (net1 asc-id) (net-new-cell net 0 max-merge))
  (define-values (net2 desc-id) (net-new-cell-desc net1 10 min-merge))
  (define-values (net3 p1)
    (net-add-propagator net2
      (list asc-id) (list desc-id)
      (lambda (n)
        (define v (net-cell-read n asc-id))
        (net-cell-write n desc-id (+ v 1)))))
  (define-values (net4 p2)
    (net-add-propagator net3
      (list desc-id) (list asc-id)
      (lambda (n)
        (define v (net-cell-read n desc-id))
        (net-cell-write n asc-id (- v 1)))))
  (define net5 (run-to-quiescence-bsp net4))
  (check-false (net-contradiction? net5))
  ;; BSP may converge to different fixpoint due to parallel firing,
  ;; but must still reach quiescence without contradiction
  (define asc-val (net-cell-read net5 asc-id))
  (define desc-val (net-cell-read net5 desc-id))
  ;; Fixpoint invariant: asc+1 meets desc, desc-1 joins asc
  ;; So desc <= asc+1 and asc >= desc-1
  (check-true (<= desc-val (+ asc-val 1)))
  (check-true (>= asc-val (- desc-val 1))))

;; ========================================
;; 7. Coexistence with widening cells
;; ========================================

(test-case "desc/widening-cell-coexists"
  (define net (make-prop-network))
  ;; Create a widening cell (ascending with widening)
  (define-values (net1 wid-id)
    (net-new-cell-widen net 0 max-merge
                        (lambda (old new) (if (> new 100) +inf.0 new))
                        (lambda (old new) new)))
  ;; Create a descending cell
  (define-values (net2 desc-id) (net-new-cell-desc net1 100 min-merge))
  ;; Both exist, directions correct
  (check-equal? (net-cell-direction net2 wid-id) 'ascending)
  (check-equal? (net-cell-direction net2 desc-id) 'descending)
  ;; Operations on each don't interfere
  (define net3 (net-cell-write net2 wid-id 50))
  (define net4 (net-cell-write net3 desc-id 30))
  (check-equal? (net-cell-read net4 wid-id) 50)
  (check-equal? (net-cell-read net4 desc-id) 30))

;; ========================================
;; 8. Non-Boolean lattice: set-intersection
;; ========================================

(test-case "desc/set-intersection-lattice"
  ;; Descending cell over set lattice: top = universe, meet = intersection
  (define universe '(a b c d e))
  (define net (make-prop-network))
  (define-values (net1 cid)
    (net-new-cell-desc net universe set-intersect))
  (check-equal? (sort (net-cell-read net1 cid) symbol<?) '(a b c d e))
  ;; Write {a b c} — meet({a b c d e}, {a b c}) = {a b c}
  (define net2 (net-cell-write net1 cid '(a b c)))
  (check-equal? (sort (net-cell-read net2 cid) symbol<?) '(a b c))
  ;; Write {b c d} — meet({a b c}, {b c d}) = {b c}
  (define net3 (net-cell-write net2 cid '(b c d)))
  (check-equal? (sort (net-cell-read net3 cid) symbol<?) '(b c))
  ;; Write {a b c d e} — meet({b c}, {a b c d e}) = {b c} — no change
  (define net4 (net-cell-write net3 cid '(a b c d e)))
  (check-eq? net3 net4))
