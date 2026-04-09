#lang racket/base

;;; test-branch-pu.rkt — BSP-LE Track 2 Phase 2: branch PU + assumption-tagged dependents
;;;
;;; Tests: make-branch-pu, assumption-tagged dependents with ON-NETWORK
;;; viability checking (decision cell read, no parameter), emergent dissolution.

(require rackunit
         rackunit/text-ui
         "../propagator.rkt"
         "../decision-cell.rkt"
         (only-in "../atms.rkt" assumption-id)
         (only-in "../performance-counters.rkt"
                  current-perf-counters perf-counters
                  perf-counters-inert-dependent-skips))

(define h1 (assumption-id 1))
(define h2 (assumption-id 2))
(define h3 (assumption-id 3))

;; ============================================================
;; Branch PU Tests
;; ============================================================

(define branch-pu-tests
  (test-suite "Phase 2: Branch PU lifecycle"

    (test-case "make-branch-pu: fork shares parent cells"
      (define net0 (make-prop-network))
      (define-values (net1 cid1)
        (net-new-cell net0 42 (lambda (a b) (max a b))))
      (define-values (branch-net aid) (make-branch-pu net1 h1))
      (check-equal? (net-cell-read branch-net cid1) 42)
      (check-equal? aid h1))

    (test-case "branch-local write invisible to parent"
      (define net0 (make-prop-network))
      (define-values (net1 cid1)
        (net-new-cell net0 10 (lambda (a b) (max a b))))
      (define-values (branch-net _aid) (make-branch-pu net1 h1))
      (define branch-net2 (net-cell-write branch-net cid1 50))
      (check-equal? (net-cell-read branch-net2 cid1) 50)
      (check-equal? (net-cell-read net1 cid1) 10))

    (test-case "branch creates local cells not visible on parent"
      (define net0 (make-prop-network))
      (define-values (branch-net _aid) (make-branch-pu net0 h1))
      (define-values (branch-net2 local-cid)
        (net-new-cell branch-net 'local-val (lambda (a b) b)))
      (check-equal? (net-cell-read branch-net2 local-cid) 'local-val)
      (check-exn exn:fail?
        (lambda () (net-cell-read net0 local-cid))))

    ;; Phase 6a: PU worldview isolation
    (test-case "branch with bit-position sets worldview cache"
      (define net0 (make-prop-network))
      ;; h1 = assumption-id 1, bit position = 1
      (define-values (branch-net _aid) (make-branch-pu net0 h1 1))
      ;; Fork's worldview cache should have bit 1 set
      (define wv (net-cell-read-raw branch-net worldview-cache-cell-id))
      (check-equal? wv (arithmetic-shift 1 1))
      ;; Parent's worldview cache should be unchanged (0)
      (check-equal? (net-cell-read-raw net0 worldview-cache-cell-id) 0))

    (test-case "branch worldview: tagged writes auto-tagged with branch bitmask"
      (define net0 (make-prop-network))
      ;; Create a tagged cell on the parent
      (define tcv (tagged-cell-value 'base '()))
      (define-values (net1 cid) (net-new-cell net0 tcv tagged-cell-merge))
      ;; Fork with bit position 2
      (define-values (branch-net _aid) (make-branch-pu net1 h3 2))
      ;; Write a value in the branch — should be auto-tagged with bit 2
      (define branch-net2 (net-cell-write branch-net cid 'branch-val))
      (define raw (net-cell-read-raw branch-net2 cid))
      (check-true (tagged-cell-value? raw))
      (check-true (pair? (tagged-cell-value-entries raw)))
      ;; Entry should have bitmask = (1 << 2) = 4
      (check-equal? (caar (tagged-cell-value-entries raw)) (arithmetic-shift 1 2)))
    ))

;; ============================================================
;; Assumption-Tagged Dependent Tests (ON-NETWORK viability)
;; ============================================================

(define assumption-tagged-tests
  (test-suite "Phase 2: Assumption-tagged dependents (on-network)"

    (test-case "tagged propagator fires when assumption is viable (in decision cell)"
      ;; Create decision cell with h1 viable
      (define net0 (make-prop-network))
      (define-values (net1 decision-cid)
        (net-new-cell net0 (decision-from-alternatives (list h1 h2))
                      decision-domain-merge decision-domain-contradicts?))
      (define-values (net2 in-cid) (net-new-cell net1 0 +))
      (define-values (net3 out-cid) (net-new-cell net2 0 +))
      ;; Install propagator tagged with h1, pointing to decision-cid
      (define-values (net4 _pid)
        (net-add-propagator net3 (list in-cid) (list out-cid)
          (lambda (net) (net-cell-write net out-cid (+ 1 (net-cell-read net in-cid))))
          #:assumption h1
          #:decision-cell decision-cid))
      ;; h1 is viable (in decision cell domain) → propagator fires
      (define net5 (run-to-quiescence net4))
      (check-equal? (net-cell-read net5 out-cid) 1))

    (test-case "tagged propagator skipped when assumption eliminated from decision cell"
      ;; Create decision cell, then narrow to eliminate h1
      (define net0 (make-prop-network))
      (define-values (net1 decision-cid)
        (net-new-cell net0 (decision-from-alternatives (list h1 h2))
                      decision-domain-merge decision-domain-contradicts?))
      (define-values (net2 in-cid) (net-new-cell net1 0 +))
      (define-values (net3 out-cid) (net-new-cell net2 0 +))
      ;; Install propagator tagged with h1
      (define-values (net4 _pid)
        (net-add-propagator net3 (list in-cid) (list out-cid)
          (lambda (net) (net-cell-write net out-cid 999))
          #:assumption h1
          #:decision-cell decision-cid))
      ;; Run to quiescence — h1 is still viable, fires once (writes 999)
      (define net5 (run-to-quiescence net4))
      (check-equal? (net-cell-read net5 out-cid) 999)
      ;; Now narrow the decision cell to ELIMINATE h1
      (define net6 (net-cell-write net5 decision-cid
                                   (decision-from-alternatives (list h2))))
      ;; Write to in-cid to trigger dependent re-evaluation
      (define net7 (net-cell-write net6 in-cid 42))
      ;; Run to quiescence — h1 is no longer viable, propagator should NOT re-fire
      (define net8 (run-to-quiescence net7))
      ;; out-cid should still be 999 (from first fire), not updated
      ;; (The + merge means it would have been 999+999=1998 if it re-fired)
      (check-equal? (net-cell-read net8 out-cid) 999))

    (test-case "inert dependent counter increments on skip"
      (define net0 (make-prop-network))
      (define-values (net1 decision-cid)
        (net-new-cell net0 (decision-from-alternatives (list h1 h2))
                      decision-domain-merge decision-domain-contradicts?))
      (define-values (net2 in-cid) (net-new-cell net1 0 +))
      (define-values (net3 out-cid) (net-new-cell net2 0 +))
      ;; Install tagged propagator
      (define-values (net4 _pid)
        (net-add-propagator net3 (list in-cid) (list out-cid)
          (lambda (net) net)
          #:assumption h1
          #:decision-cell decision-cid))
      ;; Run initial quiescence
      (define net5 (run-to-quiescence net4))
      ;; Narrow decision to eliminate h1
      (define net6 (net-cell-write net5 decision-cid
                                   (decision-from-alternatives (list h2))))
      ;; Enable perf counters
      (define pc (perf-counters 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0))
      ;; Write to in-cid with perf counters active
      (define net7
        (parameterize ([current-perf-counters pc])
          (net-cell-write net6 in-cid 42)))
      ;; The inert-dependent counter should have incremented
      (check-true (> (perf-counters-inert-dependent-skips pc) 0)
                  "inert dependent skip counter should be > 0"))

    (test-case "untagged propagator fires normally alongside inert tagged"
      (define net0 (make-prop-network))
      (define-values (net1 decision-cid)
        (net-new-cell net0 (decision-from-alternatives (list h1 h2))
                      decision-domain-merge decision-domain-contradicts?))
      (define-values (net2 in-cid) (net-new-cell net1 0 +))
      (define-values (net3 out-cid) (net-new-cell net2 0 +))
      ;; Install UNTAGGED propagator (always active)
      (define-values (net4 _pid1)
        (net-add-propagator net3 (list in-cid) (list out-cid)
          (lambda (net)
            (net-cell-write net out-cid (+ 10 (net-cell-read net in-cid))))))
      ;; Install TAGGED propagator (active only when h2 viable)
      (define-values (net5 _pid2)
        (net-add-propagator net4 (list in-cid) (list out-cid)
          (lambda (net)
            (net-cell-write net out-cid (+ 100 (net-cell-read net in-cid))))
          #:assumption h2
          #:decision-cell decision-cid))
      ;; Run to quiescence — both fire (h2 is viable)
      (define net6 (run-to-quiescence net5))
      ;; Now eliminate h2
      (define net7 (net-cell-write net6 decision-cid
                                   (decision-from-alternatives (list h1))))
      ;; Write to in-cid
      (define net8 (net-cell-write net7 in-cid 5))
      (define net9 (run-to-quiescence net8))
      ;; Untagged should have fired (contributes +10+5=15 via +)
      ;; Tagged should NOT have re-fired (h2 eliminated)
      (check-true (> (net-cell-read net9 out-cid) 0)
                  "untagged propagator should have produced output"))
    ))


;; ============================================================
;; Run all tests
;; ============================================================

(run-tests branch-pu-tests)
(run-tests assumption-tagged-tests)
