#lang racket/base

;;; test-per-nogood.rkt — BSP-LE Track 2 Phase 3: commitment cell
;;;
;;; Tests: commitment cell merge/contradict/provenance lattice semantics.
;;;
;;; A1 (BSP-LE 2B addendum, 2026-04-16): the `install-per-nogood-infrastructure`
;;; integration tests were removed along with the dead code they exercised. The
;;; function + its `nogood-install-request` topology handler had zero producers
;;; across the codebase (designed in Phase 3 but the wiring was superseded by
;;; direct `nogood-add` writes from ATMS S1 handlers). Commitment cell lattice
;;; tests remain — the commitment cell itself is live code.

(require rackunit
         rackunit/text-ui
         "../decision-cell.rkt"
         "../propagator.rkt"
         (only-in "../atms.rkt" assumption-id))

(define h1 (assumption-id 1))
(define h2 (assumption-id 2))
(define h3 (assumption-id 3))

;; ============================================================
;; Commitment Cell Unit Tests
;; ============================================================

(define commitment-cell-tests
  (test-suite "Phase 3: Commitment cell lattice"

    (test-case "commitment-initial: all positions #f"
      (define cv (commitment-initial '(a b)))
      (check-equal? (hash-ref cv 'a) #f)
      (check-equal? (hash-ref cv 'b) #f))

    (test-case "commitment-merge: OR per position"
      (define old (hasheq 'a #f 'b #f))
      (define new (hasheq 'a h1 'b #f))
      (define merged (commitment-merge old new))
      (check-equal? (hash-ref merged 'a) h1)
      (check-equal? (hash-ref merged 'b) #f))

    (test-case "commitment-merge: once set stays set"
      (define old (hasheq 'a h1 'b #f))
      (define new (hasheq 'a #f 'b h2))
      (define merged (commitment-merge old new))
      (check-equal? (hash-ref merged 'a) h1)
      (check-equal? (hash-ref merged 'b) h2))

    (test-case "commitment-contradicts?: all non-#f"
      (check-true (commitment-contradicts? (hasheq 'a h1 'b h2)))
      (check-false (commitment-contradicts? (hasheq 'a h1 'b #f)))
      (check-false (commitment-contradicts? (hasheq 'a #f 'b #f))))

    (test-case "commitment-filled-count"
      (check-equal? (commitment-filled-count (hasheq 'a h1 'b #f)) 1)
      (check-equal? (commitment-filled-count (hasheq 'a h1 'b h2)) 2)
      (check-equal? (commitment-filled-count (hasheq 'a #f 'b #f)) 0))

    (test-case "commitment-provenance"
      (define prov (commitment-provenance (hasheq 'a h1 'b h2)))
      (check-equal? (length prov) 2)
      (check-not-false (member h1 prov))
      (check-not-false (member h2 prov)))

    (test-case "commitment-remaining-group"
      (check-equal? (commitment-remaining-group (hasheq 'a h1 'b #f)) 'b)
      (check-equal? (commitment-remaining-group (hasheq 'a #f 'b h2)) 'a)
      (check-false (commitment-remaining-group (hasheq 'a h1 'b h2))))
    ))


;; ============================================================
;; Run all tests
;; ============================================================

(run-tests commitment-cell-tests)
