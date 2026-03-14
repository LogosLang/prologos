#lang racket/base

;;;
;;; Tests for WFLE Phase 2: Bilattice Module
;;; Verifies: lattice descriptors, bilattice variable construction,
;;;           three-valued reading, lower/upper writes, consistency
;;;           propagator, multi-var coexistence, scheduler convergence.
;;;

(require rackunit
         racket/list
         "../propagator.rkt"
         "../bilattice.rkt")

;; ========================================
;; 1. Lattice descriptors
;; ========================================

(test-case "bilattice/bool-lattice-structure"
  (check-equal? (lattice-desc-bot bool-lattice) #f)
  (check-equal? (lattice-desc-top bool-lattice) #t)
  ;; join = or
  (check-equal? ((lattice-desc-join bool-lattice) #f #f) #f)
  (check-equal? ((lattice-desc-join bool-lattice) #f #t) #t)
  (check-equal? ((lattice-desc-join bool-lattice) #t #f) #t)
  ;; meet = and
  (check-equal? ((lattice-desc-meet bool-lattice) #t #t) #t)
  (check-equal? ((lattice-desc-meet bool-lattice) #t #f) #f)
  ;; leq
  (check-true ((lattice-desc-leq bool-lattice) #f #t))
  (check-true ((lattice-desc-leq bool-lattice) #f #f))
  (check-true ((lattice-desc-leq bool-lattice) #t #t))
  (check-false ((lattice-desc-leq bool-lattice) #t #f)))

(test-case "bilattice/set-lattice-structure"
  (define lat (make-set-lattice '(a b c)))
  (check-equal? (lattice-desc-bot lat) '())
  (check-equal? (sort (lattice-desc-top lat) symbol<?) '(a b c))
  ;; join = union
  (check-equal? (sort ((lattice-desc-join lat) '(a) '(b)) symbol<?) '(a b))
  ;; meet = intersection
  (check-equal? ((lattice-desc-meet lat) '(a b) '(b c)) '(b))
  ;; leq = subset
  (check-true ((lattice-desc-leq lat) '(a) '(a b)))
  (check-false ((lattice-desc-leq lat) '(a b) '(a))))

;; ========================================
;; 2. Bilattice variable construction
;; ========================================

(test-case "bilattice/new-var-creates-two-cells"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  ;; Lower cell is ascending
  (check-equal? (net-cell-direction net1 (bilattice-var-lower-cid bvar)) 'ascending)
  ;; Upper cell is descending
  (check-equal? (net-cell-direction net1 (bilattice-var-upper-cid bvar)) 'descending))

(test-case "bilattice/fresh-bool-reads-unknown"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  ;; Fresh: lower=false, upper=true → unknown
  (check-equal? (bilattice-read-bool net1 bvar) 'unknown))

(test-case "bilattice/fresh-set-reads-approx"
  (define lat (make-set-lattice '(a b c)))
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net lat))
  ;; Fresh: lower=(), upper=(a b c) → approx
  (define result (bilattice-read net1 bvar))
  (check-equal? (car result) 'approx)
  (check-equal? (cadr result) '())
  (check-equal? (sort (caddr result) symbol<?) '(a b c)))

;; ========================================
;; 3. Lower/upper writes
;; ========================================

(test-case "bilattice/lower-write-raises-lower"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  (define net2 (bilattice-lower-write net1 bvar #t))
  ;; lower=true, upper=true → definitely true
  (check-equal? (bilattice-read-bool net2 bvar) 'true))

(test-case "bilattice/upper-write-lowers-upper"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  (define net2 (bilattice-upper-write net1 bvar #f))
  ;; lower=false, upper=false → definitely false
  (check-equal? (bilattice-read-bool net2 bvar) 'false))

(test-case "bilattice/lower-write-monotone"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  ;; Raise lower to true
  (define net2 (bilattice-lower-write net1 bvar #t))
  ;; Try to lower it back to false — join(true, false) = true, no change
  (define net3 (bilattice-lower-write net2 bvar #f))
  (check-equal? (net-cell-read net3 (bilattice-var-lower-cid bvar)) #t))

(test-case "bilattice/upper-write-monotone"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  ;; Lower upper to false
  (define net2 (bilattice-upper-write net1 bvar #f))
  ;; Try to raise it back to true — meet(false, true) = false, no change
  (define net3 (bilattice-upper-write net2 bvar #t))
  (check-equal? (net-cell-read net3 (bilattice-var-upper-cid bvar)) #f))

;; ========================================
;; 4. Three-valued reading (Boolean)
;; ========================================

(test-case "bilattice/read-true"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  (define net2 (bilattice-lower-write net1 bvar #t))
  ;; lower=true, upper=true → true
  (check-equal? (bilattice-read-bool net2 bvar) 'true)
  (check-equal? (bilattice-read net2 bvar) '(exact #t)))

(test-case "bilattice/read-false"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  (define net2 (bilattice-upper-write net1 bvar #f))
  ;; lower=false, upper=false → false
  (check-equal? (bilattice-read-bool net2 bvar) 'false)
  (check-equal? (bilattice-read net2 bvar) '(exact #f)))

(test-case "bilattice/read-unknown"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  ;; Fresh: lower=false, upper=true → unknown
  (check-equal? (bilattice-read-bool net1 bvar) 'unknown)
  (check-equal? (bilattice-read net1 bvar) '(approx #f #t)))

(test-case "bilattice/read-contradiction"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  ;; Force lower=true, upper=false → contradiction
  (define net2 (bilattice-lower-write net1 bvar #t))
  (define net3 (bilattice-upper-write net2 bvar #f))
  (check-equal? (bilattice-read-bool net3 bvar) 'contradiction)
  (check-equal? (bilattice-read net3 bvar) 'contradiction))

;; ========================================
;; 5. Consistency propagator
;; ========================================

(test-case "bilattice/consistency-noop-when-valid"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice #:consistency-check? #t))
  ;; Fresh var: lower=false <= upper=true — consistent
  (define net2 (run-to-quiescence net1))
  (check-false (net-contradiction? net2)))

(test-case "bilattice/consistency-flags-contradiction"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice #:consistency-check? #t))
  ;; Force lower > upper
  (define net2 (bilattice-lower-write net1 bvar #t))
  (define net3 (bilattice-upper-write net2 bvar #f))
  ;; Run propagators — consistency check should fire
  (define net4 (run-to-quiescence net3))
  (check-true (net-contradiction? net4)))

;; ========================================
;; 6. Multiple bilattice vars
;; ========================================

(test-case "bilattice/multiple-vars-coexist"
  (define net (make-prop-network))
  (define-values (net1 bv1) (bilattice-new-var net bool-lattice))
  (define-values (net2 bv2) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 bv3) (bilattice-new-var net2 bool-lattice))
  ;; Set different states
  (define net4 (bilattice-lower-write net3 bv1 #t))   ;; bv1 = true
  (define net5 (bilattice-upper-write net4 bv2 #f))   ;; bv2 = false
  ;; bv3 stays unknown
  (check-equal? (bilattice-read-bool net5 bv1) 'true)
  (check-equal? (bilattice-read-bool net5 bv2) 'false)
  (check-equal? (bilattice-read-bool net5 bv3) 'unknown))

(test-case "bilattice/propagator-between-vars"
  ;; bv1's truth implies bv2's truth
  ;; Propagator: when bv1's lower becomes true, set bv2's lower to true
  (define net (make-prop-network))
  (define-values (net1 bv1) (bilattice-new-var net bool-lattice))
  (define-values (net2 bv2) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 _pid)
    (net-add-propagator net2
      (list (bilattice-var-lower-cid bv1))
      (list (bilattice-var-lower-cid bv2))
      (lambda (n)
        (define lo1 (net-cell-read n (bilattice-var-lower-cid bv1)))
        (if lo1
            (net-cell-write n (bilattice-var-lower-cid bv2) #t)
            n))))
  ;; Set bv1 to true
  (define net4 (bilattice-lower-write net3 bv1 #t))
  (define net5 (run-to-quiescence net4))
  ;; bv2 should now be true
  (check-equal? (bilattice-read-bool net5 bv1) 'true)
  (check-equal? (bilattice-read-bool net5 bv2) 'true))

;; ========================================
;; 7. Integration with regular cells
;; ========================================

(test-case "bilattice/coexists-with-regular-cells"
  (define net (make-prop-network))
  ;; Regular ascending cell
  (define-values (net1 reg-id) (net-new-cell net 0 max))
  ;; Bilattice var
  (define-values (net2 bvar) (bilattice-new-var net1 bool-lattice))
  ;; Both work independently
  (define net3 (net-cell-write net2 reg-id 42))
  (define net4 (bilattice-lower-write net3 bvar #t))
  (check-equal? (net-cell-read net4 reg-id) 42)
  (check-equal? (bilattice-read-bool net4 bvar) 'true))

;; ========================================
;; 8. Scheduler convergence
;; ========================================

(test-case "bilattice/gauss-seidel-convergence"
  ;; Chain: bv1 true → bv2 true → bv3 true (propagators on lower cells)
  (define net (make-prop-network))
  (define-values (net1 bv1) (bilattice-new-var net bool-lattice))
  (define-values (net2 bv2) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 bv3) (bilattice-new-var net2 bool-lattice))
  ;; bv1 lower → bv2 lower
  (define-values (net4 _p1)
    (net-add-propagator net3
      (list (bilattice-var-lower-cid bv1))
      (list (bilattice-var-lower-cid bv2))
      (lambda (n)
        (if (net-cell-read n (bilattice-var-lower-cid bv1))
            (net-cell-write n (bilattice-var-lower-cid bv2) #t)
            n))))
  ;; bv2 lower → bv3 lower
  (define-values (net5 _p2)
    (net-add-propagator net4
      (list (bilattice-var-lower-cid bv2))
      (list (bilattice-var-lower-cid bv3))
      (lambda (n)
        (if (net-cell-read n (bilattice-var-lower-cid bv2))
            (net-cell-write n (bilattice-var-lower-cid bv3) #t)
            n))))
  ;; Trigger: set bv1 true
  (define net6 (bilattice-lower-write net5 bv1 #t))
  (define net7 (run-to-quiescence net6))
  (check-false (net-contradiction? net7))
  (check-equal? (bilattice-read-bool net7 bv1) 'true)
  (check-equal? (bilattice-read-bool net7 bv2) 'true)
  (check-equal? (bilattice-read-bool net7 bv3) 'true))

(test-case "bilattice/bsp-convergence"
  ;; Same chain but with BSP scheduler
  (define net (make-prop-network))
  (define-values (net1 bv1) (bilattice-new-var net bool-lattice))
  (define-values (net2 bv2) (bilattice-new-var net1 bool-lattice))
  ;; bv1 lower → bv2 lower
  (define-values (net3 _p1)
    (net-add-propagator net2
      (list (bilattice-var-lower-cid bv1))
      (list (bilattice-var-lower-cid bv2))
      (lambda (n)
        (if (net-cell-read n (bilattice-var-lower-cid bv1))
            (net-cell-write n (bilattice-var-lower-cid bv2) #t)
            n))))
  (define net4 (bilattice-lower-write net3 bv1 #t))
  (define net5 (run-to-quiescence-bsp net4))
  (check-false (net-contradiction? net5))
  (check-equal? (bilattice-read-bool net5 bv1) 'true)
  (check-equal? (bilattice-read-bool net5 bv2) 'true))
