#lang racket/base

;;; test-decision-cell.rkt — BSP-LE Track 2 Phase 1: decision cell + parallel-map tests
;;;
;;; Tests: decision domain lattice, nogood lattice, assumptions accumulator,
;;; parallel-map propagator pattern, multi-write under BSP (3.1 gate).

(require rackunit
         rackunit/text-ui
         "../decision-cell.rkt"
         "../propagator.rkt"
         (only-in "../atms.rkt" assumption-id))

;; ============================================================
;; Helper: convenience assumption-id constructors
;; ============================================================
(define h1 (assumption-id 1))
(define h2 (assumption-id 2))
(define h3 (assumption-id 3))
(define h4 (assumption-id 4))
(define h5 (assumption-id 5))

;; ============================================================
;; Decision Domain Lattice Tests
;; ============================================================

(define decision-domain-tests
  (test-suite "BSP-LE Track 2 Phase 1: Decision domain lattice"

    (test-case "decision-from-alternatives: empty → top"
      (check-equal? (decision-from-alternatives '()) decision-top))

    (test-case "decision-from-alternatives: singleton → one"
      (define d (decision-from-alternatives (list h1)))
      (check-true (decision-one? d))
      (check-equal? (decision-one-assumption d) h1))

    (test-case "decision-from-alternatives: multiple → set"
      (define d (decision-from-alternatives (list h1 h2 h3)))
      (check-true (decision-set? d))
      (check-equal? (length (decision-alternatives d)) 3))

    (test-case "merge: bot ⊔ x = x"
      (define d (decision-from-alternatives (list h1 h2)))
      (check-equal? (decision-domain-merge decision-bot d) d)
      (check-equal? (decision-domain-merge d decision-bot) d))

    (test-case "merge: top ⊔ x = top"
      (define d (decision-from-alternatives (list h1 h2)))
      (check-equal? (decision-domain-merge decision-top d) decision-top)
      (check-equal? (decision-domain-merge d decision-top) decision-top))

    (test-case "merge: set ∩ set (narrowing)"
      (define d1 (decision-from-alternatives (list h1 h2 h3)))
      (define d2 (decision-from-alternatives (list h2 h3 h4)))
      (define merged (decision-domain-merge d1 d2))
      ;; Intersection: {h2, h3}
      (check-true (decision-set? merged))
      (check-equal? (length (decision-alternatives merged)) 2)
      (check-not-false (member h2 (decision-alternatives merged)))
      (check-not-false (member h3 (decision-alternatives merged))))

    (test-case "merge: set ∩ set → singleton"
      (define d1 (decision-from-alternatives (list h1 h2)))
      (define d2 (decision-from-alternatives (list h2 h3)))
      (define merged (decision-domain-merge d1 d2))
      ;; Intersection: {h2} → one
      (check-true (decision-one? merged))
      (check-equal? (decision-one-assumption merged) h2))

    (test-case "merge: set ∩ set → empty = top"
      (define d1 (decision-from-alternatives (list h1 h2)))
      (define d2 (decision-from-alternatives (list h3 h4)))
      (define merged (decision-domain-merge d1 d2))
      ;; Intersection: {} → top
      (check-equal? merged decision-top))

    (test-case "merge: one ⊔ one (same) = one"
      (define d (decision-from-alternatives (list h1)))
      (check-equal? (decision-domain-merge d d) d))

    (test-case "merge: one ⊔ one (different) = top"
      (define d1 (decision-from-alternatives (list h1)))
      (define d2 (decision-from-alternatives (list h2)))
      (check-equal? (decision-domain-merge d1 d2) decision-top))

    (test-case "merge: set ⊔ one (member) = one"
      (define s (decision-from-alternatives (list h1 h2 h3)))
      (define o (decision-from-alternatives (list h2)))
      (check-true (decision-one? (decision-domain-merge s o)))
      (check-equal? (decision-committed-assumption (decision-domain-merge s o)) h2))

    (test-case "merge: set ⊔ one (not member) = top"
      (define s (decision-from-alternatives (list h1 h2)))
      (define o (decision-from-alternatives (list h4)))
      (check-equal? (decision-domain-merge s o) decision-top))

    (test-case "narrow: remove from set"
      (define d (decision-from-alternatives (list h1 h2 h3)))
      (define narrowed (decision-domain-narrow d h2))
      (check-true (decision-set? narrowed))
      (check-equal? (length (decision-alternatives narrowed)) 2)
      (check-false (member h2 (decision-alternatives narrowed))))

    (test-case "narrow: remove → singleton"
      (define d (decision-from-alternatives (list h1 h2)))
      (define narrowed (decision-domain-narrow d h1))
      (check-true (decision-one? narrowed))
      (check-equal? (decision-one-assumption narrowed) h2))

    (test-case "narrow: remove last → top"
      (define d (decision-from-alternatives (list h1)))
      (define narrowed (decision-domain-narrow d h1))
      (check-equal? narrowed decision-top))

    (test-case "narrow: remove non-member = no-op"
      (define d (decision-from-alternatives (list h1 h2)))
      (define narrowed (decision-domain-narrow d h5))
      (check-true (decision-set? narrowed))
      (check-equal? (length (decision-alternatives narrowed)) 2))

    (test-case "contradicts?"
      (check-true (decision-domain-contradicts? decision-top))
      (check-false (decision-domain-contradicts? decision-bot))
      (check-false (decision-domain-contradicts? (decision-from-alternatives (list h1 h2)))))

    (test-case "committed?"
      (check-true (decision-committed? (decision-from-alternatives (list h1))))
      (check-false (decision-committed? (decision-from-alternatives (list h1 h2))))
      (check-false (decision-committed? decision-bot))
      (check-false (decision-committed? decision-top)))
    ))


;; ============================================================
;; Nogood Lattice Tests
;; ============================================================

(define nogood-tests
  (test-suite "BSP-LE Track 2 Phase 1: Nogood lattice"

    (test-case "nogood-empty"
      (check-equal? nogood-empty '()))

    (test-case "nogood-add"
      (define ng (hasheq h1 #t h2 #t))
      (define ngs (nogood-add nogood-empty ng))
      (check-equal? (length ngs) 1))

    (test-case "nogood-merge"
      (define ng1 (nogood-add nogood-empty (hasheq h1 #t h2 #t)))
      (define ng2 (nogood-add nogood-empty (hasheq h3 #t h4 #t)))
      (define merged (nogood-merge ng1 ng2))
      (check-equal? (length merged) 2))

    (test-case "nogood-member?: positive"
      (define ngs (nogood-add nogood-empty (hasheq h1 #t h2 #t)))
      ;; A worldview containing both h1 and h2 should match
      (define wv (hasheq h1 #t h2 #t h3 #t))
      (check-true (nogood-member? ngs wv)))

    (test-case "nogood-member?: negative"
      (define ngs (nogood-add nogood-empty (hasheq h1 #t h2 #t)))
      ;; A worldview with only h1 (not h2) should NOT match
      (define wv (hasheq h1 #t h3 #t))
      (check-false (nogood-member? ngs wv)))
    ))


;; ============================================================
;; Assumptions & Counter Tests
;; ============================================================

(define accumulator-tests
  (test-suite "BSP-LE Track 2 Phase 1: Accumulators"

    (test-case "assumptions-merge: empty + entry = entry"
      (define store (assumptions-add assumptions-empty h1 'assumption-data))
      (define merged (assumptions-merge assumptions-empty store))
      (check-true (hash-has-key? merged h1)))

    (test-case "assumptions-merge: union"
      (define s1 (assumptions-add assumptions-empty h1 'a1))
      (define s2 (assumptions-add assumptions-empty h2 'a2))
      (define merged (assumptions-merge s1 s2))
      (check-true (hash-has-key? merged h1))
      (check-true (hash-has-key? merged h2)))

    (test-case "counter-merge: max"
      (check-equal? (counter-merge 3 5) 5)
      (check-equal? (counter-merge 7 2) 7)
      (check-equal? (counter-merge 4 4) 4))
    ))


;; ============================================================
;; Parallel-Map Propagator Tests
;; ============================================================

(define parallel-map-tests
  (test-suite "BSP-LE Track 2 Phase 1: Parallel-map propagator"

    ;; 3.1 GATE: Verify multi-write to accumulator under BSP
    (test-case "parallel-map: 3 propagators write to shared accumulator (set-union)"
      ;; Create a network with an input cell and an accumulator cell
      (define net0 (make-prop-network))
      (define-values (net1 input-cid)
        (net-new-cell net0 'ready (lambda (a b) b)))
      ;; Accumulator cell: set-union merge (append, since we use lists)
      (define (set-union-merge old new)
        (cond
          [(null? old) new]
          [(null? new) old]
          [else (append old new)]))
      (define-values (net2 output-cid)
        (net-new-cell net1 '() set-union-merge))
      ;; Install 3 parallel-map propagators, each writing its item to the accumulator
      (define items '("alpha" "beta" "gamma"))
      (define (make-fire item)
        (lambda (net)
          (net-cell-write net output-cid (list item))))
      (define-values (net3 pids)
        (net-add-parallel-map-propagator net2 (list input-cid) output-cid
                                         items make-fire))
      ;; Run to quiescence — all 3 should fire
      (define net4 (run-to-quiescence net3))
      (define result (net-cell-read net4 output-cid))
      ;; All 3 items should be in the accumulator
      (check-equal? (length result) 3)
      (check-not-false (member "alpha" result))
      (check-not-false (member "beta" result))
      (check-not-false (member "gamma" result)))

    ;; Same test under BSP scheduler
    (test-case "parallel-map: 5 propagators under BSP (multi-write verification 3.1)"
      (define net0 (make-prop-network))
      (define-values (net1 input-cid)
        (net-new-cell net0 'ready (lambda (a b) b)))
      (define (set-union-merge old new)
        (cond
          [(null? old) new]
          [(null? new) old]
          [else (append old new)]))
      (define-values (net2 output-cid)
        (net-new-cell net1 '() set-union-merge))
      (define items '(1 2 3 4 5))
      (define (make-fire item)
        (lambda (net)
          (net-cell-write net output-cid (list item))))
      (define-values (net3 pids)
        (net-add-parallel-map-propagator net2 (list input-cid) output-cid
                                         items make-fire))
      ;; Run under BSP
      (define net4 (run-to-quiescence-bsp net3))
      (define result (net-cell-read net4 output-cid))
      ;; All 5 items should be accumulated
      (check-equal? (length result) 5)
      (for ([i (in-list items)])
        (check-not-false (member i result)
                    (format "item ~a missing from accumulator" i))))

    (test-case "parallel-map: 0 items = no propagators installed"
      (define net0 (make-prop-network))
      (define-values (net1 input-cid)
        (net-new-cell net0 'ready (lambda (a b) b)))
      (define-values (net2 output-cid)
        (net-new-cell net1 '() (lambda (a b) (append a b))))
      (define-values (net3 pids)
        (net-add-parallel-map-propagator net2 (list input-cid) output-cid
                                         '() (lambda (item) (lambda (net) net))))
      (check-equal? pids '())
      (define net4 (run-to-quiescence net3))
      (define result (net-cell-read net4 output-cid))
      (check-equal? result '()))

    (test-case "parallel-map: 10 propagators (polynomial functor scale test)"
      (define net0 (make-prop-network))
      (define-values (net1 input-cid)
        (net-new-cell net0 'ready (lambda (a b) b)))
      (define (set-union-merge old new)
        (cond
          [(null? old) new]
          [(null? new) old]
          [else (append old new)]))
      (define-values (net2 output-cid)
        (net-new-cell net1 '() set-union-merge))
      (define items (for/list ([i (in-range 10)]) (format "item-~a" i)))
      (define (make-fire item)
        (lambda (net)
          (net-cell-write net output-cid (list item))))
      (define-values (net3 pids)
        (net-add-parallel-map-propagator net2 (list input-cid) output-cid
                                         items make-fire))
      (check-equal? (length pids) 10)
      (define net4 (run-to-quiescence-bsp net3))
      (define result (net-cell-read net4 output-cid))
      (check-equal? (length result) 10))
    ))


;; ============================================================
;; Broadcast Propagator Tests (Phase 1Bii)
;; ============================================================

(define broadcast-tests
  (test-suite "BSP-LE Track 2 Phase 1B: Broadcast propagator"

    (test-case "broadcast: 3 items, one fire, one write"
      (define net0 (make-prop-network))
      (define-values (net1 input-cid)
        (net-new-cell net0 'ready (lambda (a b) b)))
      (define (set-union-merge old new)
        (cond [(null? old) new] [(null? new) old] [else (append old new)]))
      (define-values (net2 output-cid)
        (net-new-cell net1 '() set-union-merge))
      (define items '("alpha" "beta" "gamma"))
      (define (item-fn item _input-values) (list item))
      (define-values (net3 pid)
        (net-add-broadcast-propagator net2 (list input-cid) output-cid
                                      items item-fn append))
      ;; ONE propagator installed (not 3)
      (check-true (prop-id? pid))
      (define net4 (run-to-quiescence net3))
      (define result (net-cell-read net4 output-cid))
      (check-equal? (length result) 3)
      (check-not-false (member "alpha" result))
      (check-not-false (member "beta" result))
      (check-not-false (member "gamma" result)))

    (test-case "broadcast: 10 items under BSP"
      (define net0 (make-prop-network))
      (define-values (net1 input-cid)
        (net-new-cell net0 'ready (lambda (a b) b)))
      (define (set-union-merge old new)
        (cond [(null? old) new] [(null? new) old] [else (append old new)]))
      (define-values (net2 output-cid)
        (net-new-cell net1 '() set-union-merge))
      (define items (for/list ([i (in-range 10)]) i))
      (define (item-fn item _input-values) (list item))
      (define-values (net3 _pid)
        (net-add-broadcast-propagator net2 (list input-cid) output-cid
                                      items item-fn append))
      (define net4 (run-to-quiescence-bsp net3))
      (define result (net-cell-read net4 output-cid))
      (check-equal? (length result) 10)
      (for ([i (in-list items)])
        (check-not-false (member i result))))

    (test-case "broadcast: 0 items = no-op fire"
      (define net0 (make-prop-network))
      (define-values (net1 input-cid)
        (net-new-cell net0 'ready (lambda (a b) b)))
      (define-values (net2 output-cid)
        (net-new-cell net1 '() append))
      (define-values (net3 _pid)
        (net-add-broadcast-propagator net2 (list input-cid) output-cid
                                      '()
                                      (lambda (item vals) item)
                                      append))
      (define net4 (run-to-quiescence net3))
      (check-equal? (net-cell-read net4 output-cid) '()))

    (test-case "broadcast: item-fn can return #f to skip"
      (define net0 (make-prop-network))
      (define-values (net1 input-cid)
        (net-new-cell net0 'ready (lambda (a b) b)))
      (define (set-union-merge old new)
        (cond [(null? old) new] [(null? new) old] [else (append old new)]))
      (define-values (net2 output-cid)
        (net-new-cell net1 '() set-union-merge))
      ;; Items 1-5, but item-fn returns #f for even numbers
      (define items '(1 2 3 4 5))
      (define (item-fn item _input-values)
        (if (odd? item) (list item) #f))
      (define-values (net3 _pid)
        (net-add-broadcast-propagator net2 (list input-cid) output-cid
                                      items item-fn append))
      (define net4 (run-to-quiescence net3))
      (define result (net-cell-read net4 output-cid))
      ;; Only odd items: 1, 3, 5
      (check-equal? (length result) 3)
      (check-not-false (member 1 result))
      (check-not-false (member 3 result))
      (check-not-false (member 5 result)))

    (test-case "broadcast: profile struct is well-formed"
      ;; Verify broadcast-profile struct works correctly
      (define items '(a b c))
      (define my-item-fn (lambda (item vals) item))
      (define profile (broadcast-profile items my-item-fn append))
      (check-true (broadcast-profile? profile))
      (check-equal? (broadcast-profile-items profile) '(a b c))
      (check-equal? (broadcast-profile-item-fn profile) my-item-fn)
      (check-equal? (broadcast-profile-merge-fn profile) append))
    ))


;; ============================================================
;; Hasse Diagram / Bitmask Tests (D.7 touchup)
;; ============================================================

(define hasse-tests
  (test-suite "D.7: Hasse diagram bitmask operations"

    (test-case "aids->bitmask: computes OR of bit positions"
      (check-equal? (aids->bitmask '(0 2 4)) #b10101)
      (check-equal? (aids->bitmask '(1 3)) #b1010)
      (check-equal? (aids->bitmask '()) 0))

    (test-case "popcount: counts set bits"
      (check-equal? (popcount #b10101) 3)
      (check-equal? (popcount #b1111) 4)
      (check-equal? (popcount 0) 0)
      (check-equal? (popcount 255) 8))

    (test-case "hamming-distance: symmetric difference cardinality"
      (check-equal? (hamming-distance #b10101 #b01010) 5)
      (check-equal? (hamming-distance #b10101 #b10101) 0)
      (check-equal? (hamming-distance #b10101 #b10100) 1))

    (test-case "hasse-adjacent?: differ in exactly one bit"
      (check-true (hasse-adjacent? #b101 #b100))   ;; differ in bit 0
      (check-true (hasse-adjacent? #b101 #b111))   ;; differ in bit 1
      (check-false (hasse-adjacent? #b101 #b110))  ;; differ in bits 0+1
      (check-false (hasse-adjacent? #b101 #b101))) ;; same = not adjacent

    (test-case "subcube-member?: nogood containment"
      (check-true (subcube-member? #b111 #b101))   ;; 111 contains 101
      (check-false (subcube-member? #b110 #b101))  ;; 110 doesn't contain 101
      (check-true (subcube-member? #b1111 #b0101)) ;; 1111 contains 0101
      (check-true (subcube-member? #b101 #b101))   ;; exact match = contained
      (check-true (subcube-member? #b111 0)))      ;; everything contains empty

    (test-case "decision-set carries bitmask"
      (define d (decision-from-alternatives (list h1 h2 h3)
                                            #f
                                            (list 1 2 3)))
      (check-true (decision-set? d))
      (check-equal? (decision-set-bitmask d) #b1110))  ;; bits 1,2,3

    (test-case "merge preserves bitmask (AND)"
      (define d1 (decision-from-alternatives (list h1 h2 h3) #f '(1 2 3)))
      (define d2 (decision-from-alternatives (list h2 h3 h4) #f '(2 3 4)))
      (define merged (decision-domain-merge d1 d2))
      ;; Intersection: {h2, h3}, bitmask = bits 2,3 = #b1100
      (check-true (decision-set? merged))
      (check-equal? (decision-set-bitmask merged) (bitwise-and #b1110 #b11100)))

    (test-case "narrow with bit position updates bitmask"
      (define d (decision-from-alternatives (list h1 h2 h3) #f '(1 2 3)))
      ;; Narrow: remove h2 (bit position 2)
      (define narrowed (decision-domain-narrow d h2 2))
      (check-true (decision-set? narrowed))
      ;; Bitmask should have bit 2 cleared: #b1110 → #b1010
      (check-equal? (decision-set-bitmask narrowed) #b1010))

    (test-case "decision-bitmask for set"
      (define d (decision-from-alternatives (list h1 h2) #f '(1 2)))
      (check-equal? (decision-bitmask d) #b110))

    (test-case "decision-bitmask for bot/top"
      (check-equal? (decision-bitmask decision-bot) 0)
      (check-equal? (decision-bitmask decision-top) 0))
    ))


;; ============================================================
;; Run all tests
;; ============================================================

(run-tests decision-domain-tests)
(run-tests nogood-tests)
(run-tests accumulator-tests)
(run-tests parallel-map-tests)
(run-tests broadcast-tests)
(run-tests hasse-tests)
