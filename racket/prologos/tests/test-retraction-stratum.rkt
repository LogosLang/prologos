#lang racket/base

;;;
;;; test-retraction-stratum.rkt — Track 7 Phase 5: S(-1) retraction + tagged entry tests
;;;
;;; Validates:
;;; 1. tagged-entry infrastructure: wrap, unwrap, mixed tagged/untagged
;;; 2. retract-hasheq-entries: filter by assumption-id in hasheq cells
;;; 3. retract-hasheq-list-entries: filter list elements in wakeup cells
;;; 4. run-retraction-stratum!: depth-0 fast path, assumption tracking
;;; 5. record-assumption-retraction!: set accumulation + clearing
;;; Post-fix: run-retraction-stratum! now uses net-cell-replace (bypass merge)
;;; to write cleaned values. Previously used elab-cell-write (merge-based)
;;; which unioned cleaned values with old, restoring retracted entries.
;;; Bug discovered by these tests; fix: net-cell-replace in propagator.rkt.
;;;

(require rackunit
         racket/set
         "../infra-cell.rkt"
         "../elaborator-network.rkt"
         "../metavar-store.rkt"
         "../syntax.rkt"
         "../propagator.rkt"
         "../driver.rkt")

;; ========================================
;; 1. tagged-entry struct basics
;; ========================================

(test-case "tagged-entry: construction and access"
  (define te (tagged-entry 'value-A 'assumption-1))
  (check-true (tagged-entry? te))
  (check-equal? (tagged-entry-value te) 'value-A)
  (check-equal? (tagged-entry-assumption-id te) 'assumption-1))

(test-case "tagged-entry: #f assumption-id (depth-0, unconditional)"
  (define te (tagged-entry 'value-B #f))
  (check-equal? (tagged-entry-assumption-id te) #f))

;; ========================================
;; 2. unwrap-tagged-hasheq
;; ========================================

(test-case "unwrap-tagged-hasheq: empty hasheq"
  (check-equal? (unwrap-tagged-hasheq (hasheq)) (hasheq)))

(test-case "unwrap-tagged-hasheq: infra-bot"
  (check-equal? (unwrap-tagged-hasheq 'infra-bot) 'infra-bot))

(test-case "unwrap-tagged-hasheq: all tagged entries"
  (define h (hasheq 'k1 (tagged-entry 'v1 'a1) 'k2 (tagged-entry 'v2 'a2)))
  (define result (unwrap-tagged-hasheq h))
  (check-equal? (hash-ref result 'k1) 'v1)
  (check-equal? (hash-ref result 'k2) 'v2))

(test-case "unwrap-tagged-hasheq: mixed tagged and untagged"
  (define h (hasheq 'k1 (tagged-entry 'v1 'a1) 'k2 'raw-value))
  (define result (unwrap-tagged-hasheq h))
  (check-equal? (hash-ref result 'k1) 'v1)
  (check-equal? (hash-ref result 'k2) 'raw-value))

(test-case "unwrap-tagged-hasheq: #f assumption-id entries"
  (define h (hasheq 'k1 (tagged-entry 'v1 #f)))
  (define result (unwrap-tagged-hasheq h))
  (check-equal? (hash-ref result 'k1) 'v1))

;; ========================================
;; 3. unwrap-tagged-list
;; ========================================

(test-case "unwrap-tagged-list: empty"
  (check-equal? (unwrap-tagged-list '()) '()))

(test-case "unwrap-tagged-list: infra-bot"
  (check-equal? (unwrap-tagged-list 'infra-bot) 'infra-bot))

(test-case "unwrap-tagged-list: all tagged"
  (define lst (list (tagged-entry 'a 'x1) (tagged-entry 'b 'x2)))
  (check-equal? (unwrap-tagged-list lst) '(a b)))

(test-case "unwrap-tagged-list: mixed tagged/untagged"
  (define lst (list (tagged-entry 'a 'x1) 'raw-b))
  (check-equal? (unwrap-tagged-list lst) '(a raw-b)))

;; ========================================
;; 4. unwrap-tagged-hasheq-list (wakeup cells)
;; ========================================

(test-case "unwrap-tagged-hasheq-list: empty"
  (check-equal? (unwrap-tagged-hasheq-list (hasheq)) (hasheq)))

(test-case "unwrap-tagged-hasheq-list: infra-bot"
  (check-equal? (unwrap-tagged-hasheq-list 'infra-bot) 'infra-bot))

(test-case "unwrap-tagged-hasheq-list: nested tagged lists"
  (define h (hasheq 'k1 (list (tagged-entry 'c1 'a1) (tagged-entry 'c2 'a2))))
  (define result (unwrap-tagged-hasheq-list h))
  (check-equal? (hash-ref result 'k1) '(c1 c2)))

;; ========================================
;; 5. retract-hasheq-entries (constraint/status cells)
;; ========================================

(test-case "retract-hasheq-entries: empty hash"
  (check-equal? (retract-hasheq-entries (hasheq) (seteq 'a1)) (hasheq)))

(test-case "retract-hasheq-entries: non-hash input"
  (check-equal? (retract-hasheq-entries 'infra-bot (seteq 'a1)) 'infra-bot))

(test-case "retract-hasheq-entries: retract matching assumption"
  (define h (hasheq 'c1 (tagged-entry 'val-1 'a1)
                    'c2 (tagged-entry 'val-2 'a2)))
  (define result (retract-hasheq-entries h (seteq 'a1)))
  ;; c1 retracted, c2 survives
  (check-false (hash-has-key? result 'c1))
  (check-true (hash-has-key? result 'c2))
  (check-equal? (tagged-entry-value (hash-ref result 'c2)) 'val-2))

(test-case "retract-hasheq-entries: retract multiple assumptions"
  (define h (hasheq 'c1 (tagged-entry 'v1 'a1)
                    'c2 (tagged-entry 'v2 'a2)
                    'c3 (tagged-entry 'v3 'a3)))
  (define result (retract-hasheq-entries h (seteq 'a1 'a3)))
  (check-equal? (hash-count result) 1)
  (check-true (hash-has-key? result 'c2)))

(test-case "retract-hasheq-entries: #f assumption-id survives retraction"
  (define h (hasheq 'c1 (tagged-entry 'v1 #f)
                    'c2 (tagged-entry 'v2 'a1)))
  (define result (retract-hasheq-entries h (seteq 'a1)))
  ;; c1 (#f = unconditional) survives, c2 retracted
  (check-equal? (hash-count result) 1)
  (check-true (hash-has-key? result 'c1)))

(test-case "retract-hasheq-entries: untagged entries survive retraction"
  (define h (hasheq 'c1 'raw-value 'c2 (tagged-entry 'v2 'a1)))
  (define result (retract-hasheq-entries h (seteq 'a1)))
  (check-equal? (hash-count result) 1)
  (check-equal? (hash-ref result 'c1) 'raw-value))

(test-case "retract-hasheq-entries: no matching assumptions — no change"
  (define h (hasheq 'c1 (tagged-entry 'v1 'a1)))
  (define result (retract-hasheq-entries h (seteq 'a99)))
  (check-equal? (hash-count result) 1))

(test-case "retract-hasheq-entries: retract all entries"
  (define h (hasheq 'c1 (tagged-entry 'v1 'a1)
                    'c2 (tagged-entry 'v2 'a1)))
  (define result (retract-hasheq-entries h (seteq 'a1)))
  (check-equal? (hash-count result) 0))

;; ========================================
;; 6. retract-hasheq-list-entries (wakeup cells)
;; ========================================

(test-case "retract-hasheq-list-entries: empty hash"
  (check-equal? (retract-hasheq-list-entries (hasheq) (seteq 'a1)) (hasheq)))

(test-case "retract-hasheq-list-entries: non-hash input"
  (check-equal? (retract-hasheq-list-entries 'infra-bot (seteq 'a1)) 'infra-bot))

(test-case "retract-hasheq-list-entries: retract tagged list elements"
  (define h (hasheq 'meta1 (list (tagged-entry 'wk1 'a1)
                                 (tagged-entry 'wk2 'a2)
                                 (tagged-entry 'wk3 'a1))))
  (define result (retract-hasheq-list-entries h (seteq 'a1)))
  ;; wk1, wk3 retracted (assumption a1); wk2 survives
  (define remaining (hash-ref result 'meta1))
  (check-equal? (length remaining) 1)
  (check-equal? (tagged-entry-value (car remaining)) 'wk2))

(test-case "retract-hasheq-list-entries: entire key removed when all entries retracted"
  (define h (hasheq 'meta1 (list (tagged-entry 'wk1 'a1)
                                 (tagged-entry 'wk2 'a1))))
  (define result (retract-hasheq-list-entries h (seteq 'a1)))
  ;; Key removed entirely (not left as empty list)
  (check-false (hash-has-key? result 'meta1)))

(test-case "retract-hasheq-list-entries: #f assumption-id survives"
  (define h (hasheq 'meta1 (list (tagged-entry 'wk1 #f)
                                 (tagged-entry 'wk2 'a1))))
  (define result (retract-hasheq-list-entries h (seteq 'a1)))
  (check-equal? (length (hash-ref result 'meta1)) 1)
  (check-equal? (tagged-entry-value (car (hash-ref result 'meta1))) 'wk1))

(test-case "retract-hasheq-list-entries: multiple keys, selective retraction"
  (define h (hasheq 'meta1 (list (tagged-entry 'w1 'a1))
                    'meta2 (list (tagged-entry 'w2 'a2))
                    'meta3 (list (tagged-entry 'w3 'a1) (tagged-entry 'w4 'a2))))
  (define result (retract-hasheq-list-entries h (seteq 'a1)))
  ;; meta1 removed (all entries retracted), meta2 untouched, meta3 keeps w4
  (check-false (hash-has-key? result 'meta1))
  (check-equal? (length (hash-ref result 'meta2)) 1)
  (check-equal? (length (hash-ref result 'meta3)) 1)
  (check-equal? (tagged-entry-value (car (hash-ref result 'meta3))) 'w4))

;; ========================================
;; 7. run-retraction-stratum! — depth-0 fast path + tracking
;; ========================================

(test-case "run-retraction-stratum!: depth-0 fast path (no retracted assumptions)"
  (with-fresh-meta-env
    ;; Initialize retraction tracking with empty set
    (parameterize ([current-retracted-assumptions (box (seteq))])
      ;; Should be a no-op — no assumptions retracted
      (run-retraction-stratum!)
      ;; Verify scoped cells are untouched
      (check-not-false (current-constraint-cell-id)))))

(test-case "run-retraction-stratum!: #f retracted-assumptions box (no tracking)"
  (with-fresh-meta-env
    ;; current-retracted-assumptions defaults to #f in with-fresh-meta-env
    ;; run-retraction-stratum! should be a no-op (not crash)
    (run-retraction-stratum!)))

(test-case "record-assumption-retraction!: accumulates in set"
  (define retracted-box (box (seteq)))
  (parameterize ([current-retracted-assumptions retracted-box])
    (record-assumption-retraction! 'a1)
    (record-assumption-retraction! 'a2)
    (check-equal? (set-count (unbox retracted-box)) 2)
    (check-true (set-member? (unbox retracted-box) 'a1))
    (check-true (set-member? (unbox retracted-box) 'a2))))

(test-case "record-assumption-retraction!: ignores #f assumption-id"
  (define retracted-box (box (seteq)))
  (parameterize ([current-retracted-assumptions retracted-box])
    (record-assumption-retraction! #f)
    (check-true (set-empty? (unbox retracted-box)))))

(test-case "record-assumption-retraction!: no-op when box is #f"
  ;; Should not crash when retraction tracking is disabled
  (parameterize ([current-retracted-assumptions #f])
    (record-assumption-retraction! 'a1)))

(test-case "run-retraction-stratum!: clears retracted set after processing"
  (with-fresh-meta-env
    (define retracted-box (box (seteq)))
    (parameterize ([current-retracted-assumptions retracted-box])
      (record-assumption-retraction! 'a1)
      (run-retraction-stratum!)
      ;; Retracted set should be cleared
      (check-true (set-empty? (unbox retracted-box))))))

(test-case "scoped-cell-ids: returns 11 non-#f cell IDs after reset-meta-store!"
  (with-fresh-meta-env
    ;; reset-meta-store! creates all scoped cells
    (define ids (scoped-cell-ids))
    ;; 8 constraint + 3 wakeup = 11 scoped cells (warnings excluded)
    (check-equal? (length ids) 11)
    (check-false (memq #f ids))))

;; ========================================
;; 8. S(-1) retraction integration (post-fix: uses net-cell-replace)
;; ========================================

(test-case "run-retraction-stratum!: retracts tagged entries from constraint cell"
  (with-fresh-meta-env
    (parameterize ([current-retracted-assumptions (box (seteq))])
      (define net-box (current-prop-net-box))
      (define write-fn (current-prop-cell-write))
      (define read-fn (current-prop-cell-read))
      (define cstore-cid (current-constraint-cell-id))

      ;; Write entries with different assumptions
      (define aid1 (gensym 'assumption))
      (define enet0 (unbox net-box))
      (define enet1
        (write-fn enet0 cstore-cid
                  (hasheq 'c1 (tagged-entry 'constraint-1 aid1)
                          'c2 (tagged-entry 'constraint-2 #f))))
      (set-box! net-box enet1)

      ;; Record retraction and run S(-1)
      (record-assumption-retraction! aid1)
      (run-retraction-stratum!)

      ;; c1 retracted (aid1), c2 survives (#f = unconditional)
      (define result (read-fn (unbox net-box) cstore-cid))
      (check-equal? (hash-count result) 1)
      (check-false (hash-has-key? result 'c1))
      (check-true (hash-has-key? result 'c2)))))

(test-case "run-retraction-stratum!: retracts tagged entries from wakeup cell"
  (with-fresh-meta-env
    (parameterize ([current-retracted-assumptions (box (seteq))])
      (define net-box (current-prop-net-box))
      (define write-fn (current-prop-cell-write))
      (define read-fn (current-prop-cell-read))
      (define wakeup-cid (current-wakeup-registry-cell-id))

      ;; Write wakeup entries (hasheq-list: meta-id → (listof tagged-entry))
      (define aid1 (gensym 'assumption))
      (define enet0 (unbox net-box))
      (define enet1
        (write-fn enet0 wakeup-cid
                  (hasheq 'meta-A (list (tagged-entry 'cid-1 aid1)
                                        (tagged-entry 'cid-2 #f)))))
      (set-box! net-box enet1)

      ;; Record retraction
      (record-assumption-retraction! aid1)
      (run-retraction-stratum!)

      ;; cid-1 retracted, cid-2 survives
      (define result (read-fn (unbox net-box) wakeup-cid))
      (define entries (hash-ref result 'meta-A '()))
      (check-equal? (length entries) 1)
      (check-equal? (tagged-entry-value (car entries)) 'cid-2))))

(test-case "run-retraction-stratum!: multi-assumption retraction"
  (with-fresh-meta-env
    (parameterize ([current-retracted-assumptions (box (seteq))])
      (define net-box (current-prop-net-box))
      (define write-fn (current-prop-cell-write))
      (define read-fn (current-prop-cell-read))
      (define cstore-cid (current-constraint-cell-id))

      (define aid1 (gensym 'a))
      (define aid2 (gensym 'a))
      (define aid3 (gensym 'a))

      (define enet0 (unbox net-box))
      (define enet1
        (write-fn enet0 cstore-cid
                  (hasheq 'c1 (tagged-entry 'v1 aid1)
                          'c2 (tagged-entry 'v2 aid2)
                          'c3 (tagged-entry 'v3 aid3))))
      (set-box! net-box enet1)

      ;; Retract aid1 and aid3
      (record-assumption-retraction! aid1)
      (record-assumption-retraction! aid3)
      (run-retraction-stratum!)

      ;; Only c2 survives
      (define result (read-fn (unbox net-box) cstore-cid))
      (check-equal? (hash-count result) 1)
      (check-true (hash-has-key? result 'c2)))))

(test-case "run-retraction-stratum!: successive retractions are independent"
  (with-fresh-meta-env
    (parameterize ([current-retracted-assumptions (box (seteq))])
      (define net-box (current-prop-net-box))
      (define write-fn (current-prop-cell-write))
      (define read-fn (current-prop-cell-read))
      (define cstore-cid (current-constraint-cell-id))

      (define aid1 (gensym 'a))
      (define aid2 (gensym 'a))

      ;; First round: write c1 (aid1) and c2 (aid2)
      (set-box! net-box
        (write-fn (unbox net-box) cstore-cid
                  (hasheq 'c1 (tagged-entry 'v1 aid1)
                          'c2 (tagged-entry 'v2 aid2))))

      ;; First retraction: retract aid1
      (record-assumption-retraction! aid1)
      (run-retraction-stratum!)
      (check-equal? (hash-count (read-fn (unbox net-box) cstore-cid)) 1)

      ;; Second round: add c3 (aid2)
      (set-box! net-box
        (write-fn (unbox net-box) cstore-cid
                  (hasheq 'c3 (tagged-entry 'v3 aid2))))
      (check-equal? (hash-count (read-fn (unbox net-box) cstore-cid)) 2)

      ;; Second retraction: retract aid2
      (record-assumption-retraction! aid2)
      (run-retraction-stratum!)
      (check-equal? (hash-count (read-fn (unbox net-box) cstore-cid)) 0))))
