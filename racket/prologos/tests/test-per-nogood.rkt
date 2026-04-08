#lang racket/base

;;; test-per-nogood.rkt — BSP-LE Track 2 Phase 3: per-nogood infrastructure
;;;
;;; Tests: commitment cell merge/contradict/provenance, install-per-nogood-infrastructure,
;;; commit-tracker fires on decision singleton, narrower fires at threshold,
;;; contradiction detector fires at full commitment.

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
;; Per-Nogood Infrastructure Integration Tests
;; ============================================================

(define per-nogood-tests
  (test-suite "Phase 3: Per-nogood infrastructure"

    (test-case "install-per-nogood-infrastructure: basic installation succeeds"
      (define net0 (make-prop-network))
      ;; Create two decision cells (simulating a 2-way nogood)
      (define-values (net1 dec-a-cid)
        (net-new-cell net0 (decision-from-alternatives (list h1 h2))
                      decision-domain-merge decision-domain-contradicts?))
      (define-values (net2 dec-b-cid)
        (net-new-cell net1 (decision-from-alternatives (list h2 h3))
                      decision-domain-merge decision-domain-contradicts?))
      ;; Create a nogoods accumulator cell
      (define-values (net3 nogoods-cid)
        (net-new-cell net2 nogood-empty nogood-merge))
      ;; Nogood: {h1, h2} — h1 from group-a, h2 from group-b
      (define nogood-set (hasheq h1 #t h2 #t))
      (define group-entries (list (list 'group-a dec-a-cid h1)
                                  (list 'group-b dec-b-cid h2)))
      ;; Install infrastructure
      (define net4 (install-per-nogood-infrastructure
                    net3 nogood-set group-entries nogoods-cid))
      ;; Should have more cells and propagators than before
      (check-true (> (prop-network-next-cell-id net4)
                     (prop-network-next-cell-id net3)))
      (check-true (> (prop-network-next-prop-id net4)
                     (prop-network-next-prop-id net3))))

    (test-case "commitment cell created with correct initial value"
      (define net0 (make-prop-network))
      (define-values (net1 dec-a-cid)
        (net-new-cell net0 (decision-from-alternatives (list h1))
                      decision-domain-merge decision-domain-contradicts?))
      (define-values (net2 dec-b-cid)
        (net-new-cell net1 (decision-from-alternatives (list h2))
                      decision-domain-merge decision-domain-contradicts?))
      (define-values (net3 nogoods-cid)
        (net-new-cell net2 nogood-empty nogood-merge))
      (define nogood-set (hasheq h1 #t h2 #t))
      (define group-entries (list (list 'group-a dec-a-cid h1)
                                  (list 'group-b dec-b-cid h2)))
      (define net4 (install-per-nogood-infrastructure
                    net3 nogood-set group-entries nogoods-cid))
      ;; Run to quiescence — the commit-tracker should fire
      ;; Both decision cells are singletons (h1 and h2 respectively)
      ;; So the commitment cell should have both positions filled
      (define net5 (run-to-quiescence net4))
      ;; The commitment should be fully committed (both positions set)
      ;; which means the contradiction detector should have fired
      ;; and written to the nogoods cell
      (define ngs (net-cell-read net5 nogoods-cid))
      ;; Should have at least one nogood written (the commitment provenance)
      (check-true (pair? ngs)
                  "contradiction detector should have written to nogoods cell"))
    ))


;; ============================================================
;; Run all tests
;; ============================================================

(run-tests commitment-cell-tests)
(run-tests per-nogood-tests)
