#lang racket/base

;;; test-solver-context.rkt — BSP-LE Track 2 Phase 5: architecture-validating tests
;;;
;;; Validates that information flows through the compound cell architecture:
;;;   compound decisions cell → projection propagator → worldview cache → net-cell-read
;;;
;;; These tests verify ARCHITECTURE (information flow paths), not just BEHAVIOR
;;; (correct answers). The behavioral parity tests are in the migrated test files
;;; (test-atms-types, test-elab-speculation, test-infra-cell-atms-01, test-capability-05b).

(require rackunit
         rackunit/text-ui
         "../atms.rkt"
         "../propagator.rkt"
         "../decision-cell.rkt")

;; ============================================================
;; 1. Compound Decisions Cell: merge-maintained bitmask
;; ============================================================

(define decisions-bitmask-tests
  (test-suite "Phase 5: compound decisions cell bitmask"

    (test-case "empty decisions-state has bitmask 0"
      (define ds (decisions-state-empty assumption-id-n))
      (check-equal? (decisions-state-bitmask ds) 0))

    (test-case "adding a committed component sets its bit"
      (define ds0 (decisions-state-empty assumption-id-n))
      (define aid (assumption-id 3))
      (define ds1 (decisions-state-add-component ds0 'g1
                    (decision-from-alternatives (list aid) (bit->mask 3) (list 3))))
      ;; decision-set with one alternative → decision-one → committed
      ;; Wait — decision-from-alternatives with 1 aid produces decision-one
      (check-true (decision-committed? (decisions-state-component-ref ds1 'g1)))
      ;; Bitmask should have bit 3 set
      (check-equal? (decisions-state-bitmask ds1) (arithmetic-shift 1 3)))

    (test-case "adding a multi-alternative component does NOT set bits (not committed)"
      (define ds0 (decisions-state-empty assumption-id-n))
      (define h1 (assumption-id 0))
      (define h2 (assumption-id 1))
      (define ds1 (decisions-state-add-component ds0 'g1
                    (decision-from-alternatives (list h1 h2) #b11 (list 0 1))))
      ;; Multi-alternative = decision-set, not committed
      (check-false (decision-committed? (decisions-state-component-ref ds1 'g1)))
      ;; Bitmask should be 0 (no committed assumptions)
      (check-equal? (decisions-state-bitmask ds1) 0))

    (test-case "narrowing to singleton sets the committed bit"
      (define ds0 (decisions-state-empty assumption-id-n))
      (define h1 (assumption-id 0))
      (define h2 (assumption-id 1))
      (define ds1 (decisions-state-add-component ds0 'g1
                    (decision-from-alternatives (list h1 h2) #b11 (list 0 1))))
      (check-equal? (decisions-state-bitmask ds1) 0)
      ;; Narrow: exclude h2 → only h1 remains → committed
      (define ds2 (decisions-state-narrow-component ds1 'g1 h2))
      (check-true (decision-committed? (decisions-state-component-ref ds2 'g1)))
      (check-equal? (decisions-state-bitmask ds2) (arithmetic-shift 1 0)))

    (test-case "retraction removes bit from bitmask"
      (define ds0 (decisions-state-empty assumption-id-n))
      (define h1 (assumption-id 0))
      ;; Add committed singleton
      (define ds1 (decisions-state-add-component ds0 h1
                    (decision-from-alternatives (list h1) (bit->mask 0) (list 0))))
      (check-equal? (decisions-state-bitmask ds1) #b1)
      ;; Narrow to exclude h1 → decision-top (empty)
      (define ds2 (decisions-state-narrow-component ds1 h1 h1))
      (check-equal? (decisions-state-bitmask ds2) 0))

    (test-case "merge recomputes bitmask from all components"
      (define ds-a (decisions-state-empty assumption-id-n))
      (define h1 (assumption-id 0))
      (define h2 (assumption-id 1))
      (define ds-a1 (decisions-state-add-component ds-a h1
                      (decision-from-alternatives (list h1) (bit->mask 0) (list 0))))
      (define ds-b (decisions-state-empty assumption-id-n))
      (define ds-b1 (decisions-state-add-component ds-b h2
                      (decision-from-alternatives (list h2) (bit->mask 1) (list 1))))
      ;; Merge: both committed → bitmask = bit0 | bit1
      (define merged (decisions-state-merge ds-a1 ds-b1))
      (check-equal? (decisions-state-bitmask merged) #b11))
    ))

;; ============================================================
;; 2. Worldview Projection: compound decisions → cache cell
;; ============================================================

(define projection-tests
  (test-suite "Phase 5: worldview projection propagator"

    (test-case "projection writes bitmask to worldview cache on quiescence"
      (define net0 (make-prop-network))
      ;; Create compound decisions cell
      (define-values (net1 dec-cid)
        (net-new-cell net0
                      (decisions-state-empty assumption-id-n)
                      decisions-state-merge))
      ;; Install projection
      (define-values (net2 _pid) (install-worldview-projection net1 dec-cid))
      ;; Write a committed component
      (define h (assumption-id 5))
      (define ds (decisions-state-add-component
                  (decisions-state-empty assumption-id-n) h
                  (decision-from-alternatives (list h) (bit->mask 5) (list 5))))
      (define net3 (net-cell-write net2 dec-cid ds))
      ;; Run to quiescence — projection fires
      (define net4 (run-to-quiescence net3))
      ;; Worldview cache cell should now have bit 5
      (check-equal? (net-cell-read-raw net4 worldview-cache-cell-id)
                    (arithmetic-shift 1 5)))

    (test-case "projection updates cache when component narrows"
      (define net0 (make-prop-network))
      (define-values (net1 dec-cid)
        (net-new-cell net0
                      (decisions-state-empty assumption-id-n)
                      decisions-state-merge))
      (define-values (net2 _pid) (install-worldview-projection net1 dec-cid))
      ;; Add two committed components
      (define h0 (assumption-id 0))
      (define h1 (assumption-id 1))
      (define ds0 (decisions-state-empty assumption-id-n))
      (define ds1 (decisions-state-add-component ds0 h0
                    (decision-from-alternatives (list h0) (bit->mask 0) (list 0))))
      (define ds2 (decisions-state-add-component ds1 h1
                    (decision-from-alternatives (list h1) (bit->mask 1) (list 1))))
      (define net3 (net-cell-write net2 dec-cid ds2))
      (define net4 (run-to-quiescence net3))
      (check-equal? (net-cell-read-raw net4 worldview-cache-cell-id) #b11)
      ;; Now narrow h1 away (retraction)
      (define ds3 (decisions-state-narrow-component ds2 h1 h1))
      (define net5 (net-cell-write net4 dec-cid ds3))
      (define net6 (run-to-quiescence net5))
      ;; Cache should now only have bit 0
      (check-equal? (net-cell-read-raw net6 worldview-cache-cell-id) #b01))
    ))

;; ============================================================
;; 3. End-to-end: solver-state → compound → projection → tagged-cell-value
;; ============================================================

(define end-to-end-tests
  (test-suite "Phase 5: end-to-end solver-state architecture"

    (test-case "make-solver-context allocates all cells + projection"
      (define net0 (make-prop-network))
      (define-values (net1 ctx) (make-solver-context net0))
      ;; All 5 cell-ids should be valid
      (check-true (cell-id? (solver-context-decisions-cid ctx)))
      (check-true (cell-id? (solver-context-commitments-cid ctx)))
      (check-true (cell-id? (solver-context-assumptions-cid ctx)))
      (check-true (cell-id? (solver-context-nogoods-cid ctx)))
      (check-true (cell-id? (solver-context-counter-cid ctx)))
      ;; Decisions cell should hold a decisions-state
      (define raw (net-cell-read-raw net1 (solver-context-decisions-cid ctx)))
      (check-true (decisions-state? raw)))

    (test-case "solver-assume creates decision component + updates worldview"
      (define ss0 (make-solver-state (make-prop-network)))
      (define-values (ss1 aid) (solver-state-assume ss0 'test-hyp 'datum))
      ;; Assumption created with sequential id
      (check-true (assumption-id? aid))
      ;; Compound decisions cell has a component for this assumption
      (define ds (net-cell-read-raw (solver-state-net ss1)
                                     (solver-context-decisions-cid (solver-state-ctx ss1))))
      (check-true (decisions-state? ds))
      (check-not-false (decisions-state-component-ref ds aid))
      ;; The component should be committed (trivial {h})
      (check-true (decision-committed? (decisions-state-component-ref ds aid)))
      ;; Run to quiescence to let projection fire
      (define net-q (run-to-quiescence (solver-state-net ss1)))
      ;; Worldview cache should have this assumption's bit
      (define wv (net-cell-read-raw net-q worldview-cache-cell-id))
      (check-equal? wv (arithmetic-shift 1 (assumption-id-n aid))))

    (test-case "solver-amb creates N components in compound decisions cell"
      (define ss0 (make-solver-state (make-prop-network)))
      (define-values (ss1 hyps) (solver-state-amb ss0 '(x y z)))
      (check-equal? (length hyps) 3)
      ;; Each hypothesis has a component
      (define ds (net-cell-read-raw (solver-state-net ss1)
                                     (solver-context-decisions-cid (solver-state-ctx ss1))))
      (for ([h (in-list hyps)])
        (check-not-false (decisions-state-component-ref ds h))))

    (test-case "solver-state-consistent? reads nogoods from cell"
      (define ss0 (make-solver-state (make-prop-network)))
      (define-values (ss1 h0) (solver-state-assume ss0 'h0 'a))
      (define-values (ss2 h1) (solver-state-assume ss1 'h1 'b))
      ;; No nogoods yet — consistent
      (check-true (solver-state-consistent? ss2 (hasheq h0 #t h1 #t)))
      ;; Add nogood
      (define ss3 (solver-state-add-nogood ss2 (hasheq h0 #t h1 #t)))
      ;; Now inconsistent
      (check-false (solver-state-consistent? ss3 (hasheq h0 #t h1 #t)))
      ;; But each alone is still consistent
      (check-true (solver-state-consistent? ss3 (hasheq h0 #t)))
      (check-true (solver-state-consistent? ss3 (hasheq h1 #t))))
    ))

;; ============================================================
;; 4. Compound Commitments Cell
;; ============================================================

(define commitments-tests
  (test-suite "Phase 5: compound commitments cell"

    (test-case "empty commitments state"
      (define cs (commitments-state-empty))
      (check-true (commitments-state? cs))
      (check-equal? (commitments-state-component-keys cs) '()))

    (test-case "add-nogood creates component with all-#f positions"
      (define cs0 (commitments-state-empty))
      (define cs1 (commitments-state-add-nogood cs0 'ng1 '(g1 g2 g3)))
      (define cv (commitments-state-component-ref cs1 'ng1))
      (check-not-false cv)
      (check-equal? (commitment-filled-count cv) 0)
      (check-false (commitment-contradicts? cv)))

    (test-case "write-position fills a commitment slot"
      (define cs0 (commitments-state-empty))
      (define h1 (assumption-id 1))
      (define cs1 (commitments-state-add-nogood cs0 'ng1 '(g1 g2)))
      (define cs2 (commitments-state-write-position cs1 'ng1 'g1 h1))
      (define cv (commitments-state-component-ref cs2 'ng1))
      (check-equal? (commitment-filled-count cv) 1)
      (check-false (commitment-contradicts? cv)))

    (test-case "all positions filled → contradiction"
      (define cs0 (commitments-state-empty))
      (define h1 (assumption-id 1))
      (define h2 (assumption-id 2))
      (define cs1 (commitments-state-add-nogood cs0 'ng1 '(g1 g2)))
      (define cs2 (commitments-state-write-position cs1 'ng1 'g1 h1))
      (define cs3 (commitments-state-write-position cs2 'ng1 'g2 h2))
      (define cv (commitments-state-component-ref cs3 'ng1))
      (check-true (commitment-contradicts? cv))
      (check-equal? (length (commitment-provenance cv)) 2))

    (test-case "multiple nogoods are isolated per-component"
      (define cs0 (commitments-state-empty))
      (define h1 (assumption-id 1))
      (define cs1 (commitments-state-add-nogood cs0 'ng1 '(g1 g2)))
      (define cs2 (commitments-state-add-nogood cs1 'ng2 '(g3 g4)))
      ;; Write to ng1 only
      (define cs3 (commitments-state-write-position cs2 'ng1 'g1 h1))
      ;; ng1 has 1 filled, ng2 still empty
      (check-equal? (commitment-filled-count (commitments-state-component-ref cs3 'ng1)) 1)
      (check-equal? (commitment-filled-count (commitments-state-component-ref cs3 'ng2)) 0))

    (test-case "merge unions components from both sides"
      (define cs-a (commitments-state-empty))
      (define cs-a1 (commitments-state-add-nogood cs-a 'ng1 '(g1 g2)))
      (define cs-b (commitments-state-empty))
      (define cs-b1 (commitments-state-add-nogood cs-b 'ng2 '(g3 g4)))
      (define merged (commitments-state-merge cs-a1 cs-b1))
      (check-not-false (commitments-state-component-ref merged 'ng1))
      (check-not-false (commitments-state-component-ref merged 'ng2)))
    ))

;; ============================================================
;; 5. Fire-once verification
;; ============================================================

(define fire-once-tests
  (test-suite "Phase 5: fire-once propagator pattern"

    (test-case "fire-once propagator fires once then is no-op"
      (define net0 (make-prop-network))
      (define-values (net1 src-cid) (net-new-cell net0 0 max))
      (define-values (net2 dst-cid) (net-new-cell net1 0 max))
      (define fire-count (box 0))
      (define-values (net3 _pid)
        (net-add-fire-once-propagator net2 (list src-cid) (list dst-cid)
          (lambda (n)
            (set-box! fire-count (add1 (unbox fire-count)))
            (net-cell-write n dst-cid (net-cell-read n src-cid)))))
      ;; First trigger
      (define net4 (net-cell-write net3 src-cid 42))
      (define net5 (run-to-quiescence net4))
      (check-equal? (net-cell-read net5 dst-cid) 42)
      (check-equal? (unbox fire-count) 1)
      ;; Second trigger — fire-once guard should prevent re-fire
      (define net6 (net-cell-write net5 src-cid 99))
      (define net7 (run-to-quiescence net6))
      ;; dst should still be 42 (fire-once didn't re-fire)
      ;; Actually, max merge: 99 > 42 at src, but fire-once doesn't re-fire
      ;; so dst stays at 42
      (check-equal? (net-cell-read net7 dst-cid) 42)
      ;; Fire count should still be 1
      ;; (the propagator IS scheduled but the flag-guard returns n immediately)
      (check-equal? (unbox fire-count) 1))
    ))


;; ============================================================
;; Run all tests
;; ============================================================

(run-tests decisions-bitmask-tests)
(run-tests projection-tests)
(run-tests end-to-end-tests)
(run-tests commitments-tests)
(run-tests fire-once-tests)
