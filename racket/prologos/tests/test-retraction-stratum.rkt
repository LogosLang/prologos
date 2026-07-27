#lang racket/base

;;;
;;; test-retraction-stratum.rkt — Track 7 Phase 5 + PPN 4C 2A.a (2026-05-20)
;;;
;;; Validates:
;;; 1. tagged-entry infrastructure: wrap, unwrap, mixed tagged/untagged
;;; 2. retract-hasheq-entries: filter by assumption-id in hasheq cells
;;; 3. retract-hasheq-list-entries: filter list elements in wakeup cells
;;; 4. (NEW 2A.a) record-assumption-retraction: pure function writes to cell
;;; 5. (NEW 2A.a) process-retraction: BSP value-tier handler on scoped cells
;;; 6. (NEW 2A.a) Integration via run-to-quiescence: full cell-driven path
;;;
;;; Migrated from box-based API (record-assumption-retraction! +
;;; run-retraction-stratum!) to cell-based API (record-assumption-retraction
;;; pure function + process-retraction handler registered on cell-id 13) per
;;; PPN 4C 2A.a (D.3 §8.7.a). Box-based mechanism retires in 2B alongside
;;; run-stratified-resolution-pure.
;;;

(require rackunit
         racket/set
         "../infra-cell.rkt"
         "../elaborator-network.rkt"
         "../metavar-store.rkt"
         "../syntax.rkt"
         "../propagator.rkt"
         "../cell-ops.rkt"
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
;; 7. record-assumption-retraction — pure function API tests
;; (PPN 4C 2A.a, 2026-05-20: migrated from box-based bang API)
;; ========================================

(test-case "record-assumption-retraction: writes aid to retraction-stratum-request cell"
  (with-fresh-meta-env
    (define enet0 (unbox (current-prop-net-box)))
    (define enet1 (record-assumption-retraction enet0 'a1))
    (define pnet (elab-network-prop-net enet1))
    (check-equal? (net-cell-read pnet retraction-stratum-request-cell-id)
                  (seteq 'a1))))

(test-case "record-assumption-retraction: ignores #f assumption-id"
  (with-fresh-meta-env
    (define enet0 (unbox (current-prop-net-box)))
    (define enet1 (record-assumption-retraction enet0 #f))
    ;; #f passes through: returns enet unchanged
    (check-eq? enet0 enet1)
    ;; Cell still empty (initial set)
    (check-true (set-empty?
                  (net-cell-read (elab-network-prop-net enet1)
                                 retraction-stratum-request-cell-id)))))

(test-case "record-assumption-retraction: multiple writes accumulate via set-union merge"
  (with-fresh-meta-env
    (define enet0 (unbox (current-prop-net-box)))
    (define enet1 (record-assumption-retraction enet0 'a1))
    (define enet2 (record-assumption-retraction enet1 'a2))
    (define pnet (elab-network-prop-net enet2))
    (check-equal? (net-cell-read pnet retraction-stratum-request-cell-id)
                  (seteq 'a1 'a2))))

(test-case "record-assumption-retraction: idempotent for same aid (set semantics)"
  (with-fresh-meta-env
    (define enet0 (unbox (current-prop-net-box)))
    (define enet1 (record-assumption-retraction enet0 'a1))
    (define enet2 (record-assumption-retraction enet1 'a1))
    (define pnet (elab-network-prop-net enet2))
    (check-equal? (set-count (net-cell-read pnet retraction-stratum-request-cell-id)) 1)))

(test-case "scoped-cell-ids: returns 11 non-#f cell IDs after reset-meta-store!"
  (with-fresh-meta-env
    ;; reset-meta-store! creates all scoped cells
    (define ids (scoped-cell-ids))
    ;; 8 constraint + 3 wakeup = 11 scoped cells (warnings excluded)
    (check-equal? (length ids) 11)
    (check-false (memq #f ids))))

;; ========================================
;; 8. process-retraction handler — direct invocation tests
;; (PPN 4C 2A.a, 2026-05-20: NEW; pure on prop-net, only scoped cells)
;; ========================================

(test-case "process-retraction: empty set is no-op (pointer-equal return)"
  (with-fresh-meta-env
    (define pnet (elab-network-prop-net (unbox (current-prop-net-box))))
    (define pnet* (process-retraction pnet (set)))
    (check-eq? pnet pnet*)))

(test-case "process-retraction: retracts tagged entries from constraint cell"
  (with-fresh-meta-env
    (define net-box (current-prop-net-box))
    (define cstore-cid (current-constraint-cell-id))
    (define aid1 (gensym 'assumption))

    ;; Write tagged entries via elab-cell-write
    (define enet0 (unbox net-box))
    (define enet1
      (elab-cell-write enet0 cstore-cid
                       (hasheq 'c1 (tagged-entry 'constraint-1 aid1)
                               'c2 (tagged-entry 'constraint-2 #f))))
    (set-box! net-box enet1)

    ;; Apply process-retraction directly on prop-net
    (define pnet (elab-network-prop-net (unbox net-box)))
    (define pnet* (process-retraction pnet (seteq aid1)))

    ;; c1 retracted (aid1), c2 survives (#f = unconditional)
    (define result (net-cell-read pnet* cstore-cid))
    (check-equal? (hash-count result) 1)
    (check-false (hash-has-key? result 'c1))
    (check-true (hash-has-key? result 'c2))))

(test-case "process-retraction: retracts tagged entries from wakeup cell"
  (with-fresh-meta-env
    (define net-box (current-prop-net-box))
    (define wakeup-cid (current-wakeup-registry-cell-id))
    (define aid1 (gensym 'assumption))

    (define enet0 (unbox net-box))
    (define enet1
      (elab-cell-write enet0 wakeup-cid
                       (hasheq 'meta-A (list (tagged-entry 'cid-1 aid1)
                                             (tagged-entry 'cid-2 #f)))))
    (set-box! net-box enet1)

    (define pnet (elab-network-prop-net (unbox net-box)))
    (define pnet* (process-retraction pnet (seteq aid1)))

    (define result (net-cell-read pnet* wakeup-cid))
    (define entries (hash-ref result 'meta-A '()))
    (check-equal? (length entries) 1)
    (check-equal? (tagged-entry-value (car entries)) 'cid-2)))

(test-case "process-retraction: multi-assumption retraction"
  (with-fresh-meta-env
    (define net-box (current-prop-net-box))
    (define cstore-cid (current-constraint-cell-id))

    (define aid1 (gensym 'a))
    (define aid2 (gensym 'a))
    (define aid3 (gensym 'a))

    (define enet0 (unbox net-box))
    (define enet1
      (elab-cell-write enet0 cstore-cid
                       (hasheq 'c1 (tagged-entry 'v1 aid1)
                               'c2 (tagged-entry 'v2 aid2)
                               'c3 (tagged-entry 'v3 aid3))))
    (set-box! net-box enet1)

    (define pnet (elab-network-prop-net (unbox net-box)))
    (define pnet* (process-retraction pnet (seteq aid1 aid3)))

    (define result (net-cell-read pnet* cstore-cid))
    (check-equal? (hash-count result) 1)
    (check-true (hash-has-key? result 'c2))))

(test-case "process-retraction: untagged entries survive retraction"
  (with-fresh-meta-env
    (define net-box (current-prop-net-box))
    (define cstore-cid (current-constraint-cell-id))
    (define aid1 (gensym 'a))

    (define enet0 (unbox net-box))
    (define enet1
      (elab-cell-write enet0 cstore-cid
                       (hasheq 'c1 'raw-untagged-value
                               'c2 (tagged-entry 'v2 aid1))))
    (set-box! net-box enet1)

    (define pnet (elab-network-prop-net (unbox net-box)))
    (define pnet* (process-retraction pnet (seteq aid1)))

    (define result (net-cell-read pnet* cstore-cid))
    (check-equal? (hash-count result) 1)
    (check-equal? (hash-ref result 'c1) 'raw-untagged-value)))

;; ========================================
;; 9. Integration: record + run-to-quiescence triggers handler via BSP outer-loop
;; (PPN 4C 2A.a, 2026-05-20: full cell-driven path end-to-end)
;; ========================================

(test-case "integration: record + run-to-quiescence retracts scoped cells via handler"
  (with-fresh-meta-env
    (define net-box (current-prop-net-box))
    (define cstore-cid (current-constraint-cell-id))
    (define aid1 (gensym 'assumption))

    ;; Setup: write tagged entries
    (define enet0 (unbox net-box))
    (define enet1
      (elab-cell-write enet0 cstore-cid
                       (hasheq 'c1 (tagged-entry 'v1 aid1)
                               'c2 (tagged-entry 'v2 #f))))
    (set-box! net-box enet1)

    ;; Write aid to retraction cell via pure record-assumption-retraction
    (set-box! net-box (record-assumption-retraction (unbox net-box) aid1))

    ;; Run to quiescence: BSP outer-loop's value-tier processing invokes
    ;; process-retraction handler; it reads cell-13, retracts scoped cells,
    ;; auto-clears cell-13 to (set) via #:reset-value.
    (define pnet (elab-network-prop-net (unbox net-box)))
    (define pnet* (run-to-quiescence pnet))

    ;; Verify scoped cell cleaned via handler
    (define result (net-cell-read pnet* cstore-cid))
    (check-equal? (hash-count result) 1)
    (check-true (hash-has-key? result 'c2))

    ;; Verify retraction-stratum-request cell auto-cleared
    (check-true (set-empty?
                  (net-cell-read pnet* retraction-stratum-request-cell-id)))))

(test-case "integration: multi-aid retraction via cell accumulation"
  (with-fresh-meta-env
    (define net-box (current-prop-net-box))
    (define cstore-cid (current-constraint-cell-id))

    (define aid1 (gensym 'a))
    (define aid2 (gensym 'a))

    (define enet0 (unbox net-box))
    (define enet1
      (elab-cell-write enet0 cstore-cid
                       (hasheq 'c1 (tagged-entry 'v1 aid1)
                               'c2 (tagged-entry 'v2 aid2)
                               'c3 (tagged-entry 'v3 #f))))
    (set-box! net-box enet1)

    ;; Accumulate two retraction writes (set-union merge)
    (set-box! net-box (record-assumption-retraction (unbox net-box) aid1))
    (set-box! net-box (record-assumption-retraction (unbox net-box) aid2))

    ;; Quiescence triggers handler with combined set {aid1, aid2}
    (define pnet (elab-network-prop-net (unbox net-box)))
    (define pnet* (run-to-quiescence pnet))

    ;; Only c3 (unconditional) survives
    (define result (net-cell-read pnet* cstore-cid))
    (check-equal? (hash-count result) 1)
    (check-true (hash-has-key? result 'c3))))
