#lang racket/base

;;; test-tagged-cell-value.rkt — BSP-LE Track 2 Phase 4: bitmask-tagged cell value tests
;;;
;;; Tests: tagged-cell-value read/write/merge, make-tagged-merge,
;;; worldview cache cell in propagator core, net-cell-read/write
;;; integration with tagged-cell-values.

(require rackunit
         rackunit/text-ui
         "../decision-cell.rkt"
         "../propagator.rkt")

;; ============================================================
;; Unit Tests: tagged-cell-value operations (decision-cell.rkt)
;; ============================================================

(define tagged-cell-unit-tests
  (test-suite "Phase 4: tagged-cell-value unit operations"

    ;; --- Struct basics ---

    (test-case "tagged-cell-value: construct and access"
      (define tcv (tagged-cell-value 42 '()))
      (check-true (tagged-cell-value? tcv))
      (check-equal? (tagged-cell-value-base tcv) 42)
      (check-equal? (tagged-cell-value-entries tcv) '()))

    (test-case "tagged-cell-value: base with entries"
      (define tcv (tagged-cell-value 'bot (list (cons #b01 'left) (cons #b10 'right))))
      (check-equal? (tagged-cell-value-base tcv) 'bot)
      (check-equal? (length (tagged-cell-value-entries tcv)) 2))

    ;; --- tagged-cell-read ---

    (test-case "tagged-cell-read: plain value pass-through"
      (check-equal? (tagged-cell-read 42 #b11) 42)
      (check-equal? (tagged-cell-read 'hello 0) 'hello))

    (test-case "tagged-cell-read: zero worldview returns base (Tier 1 fast path)"
      (define tcv (tagged-cell-value 'base (list (cons #b01 'left))))
      (check-equal? (tagged-cell-read tcv 0) 'base))

    (test-case "tagged-cell-read: empty entries returns base"
      (define tcv (tagged-cell-value 'base '()))
      (check-equal? (tagged-cell-read tcv #b11) 'base))

    (test-case "tagged-cell-read: single matching entry"
      (define tcv (tagged-cell-value 'base (list (cons #b01 'left))))
      ;; Worldview #b01 includes bit 0 → entry #b01 is subset → matches
      (check-equal? (tagged-cell-read tcv #b01) 'left))

    (test-case "tagged-cell-read: entry not subset of worldview"
      (define tcv (tagged-cell-value 'base (list (cons #b10 'right))))
      ;; Worldview #b01 does NOT include bit 1 → entry #b10 is NOT subset → base
      (check-equal? (tagged-cell-read tcv #b01) 'base))

    (test-case "tagged-cell-read: most-specific match wins (higher popcount)"
      ;; Entry #b01 (popcount 1) vs entry #b11 (popcount 2, more specific)
      (define tcv (tagged-cell-value 'base (list (cons #b01 'shallow)
                                                  (cons #b11 'deep))))
      ;; Worldview #b11 includes both entries, but #b11 is more specific
      (check-equal? (tagged-cell-read tcv #b11) 'deep))

    (test-case "tagged-cell-read: partial worldview selects matching subset"
      ;; Entries for two different branches
      (define tcv (tagged-cell-value 'base (list (cons #b01 'left)
                                                  (cons #b10 'right))))
      ;; Worldview #b01 → only left matches
      (check-equal? (tagged-cell-read tcv #b01) 'left)
      ;; Worldview #b10 → only right matches
      (check-equal? (tagged-cell-read tcv #b10) 'right)
      ;; Worldview #b11 → both match, both popcount=1, last scanned wins (impl detail)
      ;; but at same popcount it's a tie — we just check one of them is returned
      (define result (tagged-cell-read tcv #b11))
      (check-not-false (or (eq? result 'left) (eq? result 'right))))

    (test-case "tagged-cell-read: nested speculation (3 bits)"
      ;; Simulate: outer=bit0, inner=bit0+bit1, innermost=bit0+bit1+bit2
      (define tcv (tagged-cell-value 'base
                    (list (cons #b001 'outer)
                          (cons #b011 'inner)
                          (cons #b111 'innermost))))
      ;; Full worldview sees innermost (most specific)
      (check-equal? (tagged-cell-read tcv #b111) 'innermost)
      ;; Partial worldview #b011 sees inner
      (check-equal? (tagged-cell-read tcv #b011) 'inner)
      ;; Minimal worldview #b001 sees outer
      (check-equal? (tagged-cell-read tcv #b001) 'outer)
      ;; Disjoint worldview #b100 sees nothing → base
      (check-equal? (tagged-cell-read tcv #b100) 'base))

    ;; --- tagged-cell-write ---

    (test-case "tagged-cell-write: plain value, zero worldview = plain pass-through"
      (check-equal? (tagged-cell-write 'old 0 'new) 'new))

    (test-case "tagged-cell-write: plain value, non-zero worldview = wrap"
      (define result (tagged-cell-write 'old #b01 'speculative))
      (check-true (tagged-cell-value? result))
      (check-equal? (tagged-cell-value-base result) 'old)
      (check-equal? (length (tagged-cell-value-entries result)) 1)
      (check-equal? (car (tagged-cell-value-entries result)) (cons #b01 'speculative)))

    (test-case "tagged-cell-write: tagged value, zero worldview = update base"
      (define tcv (tagged-cell-value 'old-base (list (cons #b01 'entry))))
      (define result (tagged-cell-write tcv 0 'new-base))
      (check-equal? (tagged-cell-value-base result) 'new-base)
      ;; Entries preserved
      (check-equal? (length (tagged-cell-value-entries result)) 1))

    (test-case "tagged-cell-write: tagged value, non-zero worldview = append entry"
      (define tcv (tagged-cell-value 'base (list (cons #b01 'first))))
      (define result (tagged-cell-write tcv #b10 'second))
      (check-equal? (tagged-cell-value-base result) 'base)
      (check-equal? (length (tagged-cell-value-entries result)) 2)
      ;; New entry prepended (cons)
      (check-equal? (car (tagged-cell-value-entries result)) (cons #b10 'second)))

    (test-case "tagged-cell-write: monotone accumulation"
      (define tcv0 (tagged-cell-value 'base '()))
      (define tcv1 (tagged-cell-write tcv0 #b01 'a))
      (define tcv2 (tagged-cell-write tcv1 #b10 'b))
      (define tcv3 (tagged-cell-write tcv2 #b11 'c))
      (check-equal? (length (tagged-cell-value-entries tcv3)) 3))

    ;; --- tagged-cell-merge ---

    (test-case "tagged-cell-merge: both tagged = union entries"
      (define a (tagged-cell-value 'base-a (list (cons #b01 'a1))))
      (define b (tagged-cell-value 'base-b (list (cons #b10 'b1))))
      (define result (tagged-cell-merge a b))
      (check-true (tagged-cell-value? result))
      (check-equal? (tagged-cell-value-base result) 'base-b)  ;; newer base wins
      (check-equal? (length (tagged-cell-value-entries result)) 2))

    (test-case "tagged-cell-merge: tagged + plain = base update"
      (define tcv (tagged-cell-value 'old (list (cons #b01 'entry))))
      (define result (tagged-cell-merge tcv 'new-plain))
      (check-true (tagged-cell-value? result))
      (check-equal? (tagged-cell-value-base result) 'new-plain)
      (check-equal? (length (tagged-cell-value-entries result)) 1))

    (test-case "tagged-cell-merge: plain + tagged = tagged wins"
      (define tcv (tagged-cell-value 'base (list (cons #b01 'entry))))
      (define result (tagged-cell-merge 'plain tcv))
      (check-true (tagged-cell-value? result))
      (check-equal? (tagged-cell-value-base result) 'base))

    (test-case "tagged-cell-merge: both plain = new wins"
      (check-equal? (tagged-cell-merge 'old 'new) 'new))

    ;; --- make-tagged-merge ---

    (test-case "make-tagged-merge: domain merge on bases"
      (define tm (make-tagged-merge max))
      (define a (tagged-cell-value 3 (list (cons #b01 10))))
      (define b (tagged-cell-value 7 (list (cons #b10 20))))
      (define result (tm a b))
      (check-true (tagged-cell-value? result))
      (check-equal? (tagged-cell-value-base result) 7)  ;; max(3, 7)
      (check-equal? (length (tagged-cell-value-entries result)) 2))

    (test-case "make-tagged-merge: infra-bot handling"
      (define tm (make-tagged-merge max))
      (define tcv (tagged-cell-value 5 '()))
      (check-equal? (tm 'infra-bot tcv) tcv)
      (check-equal? (tm tcv 'infra-bot) tcv))

    (test-case "make-tagged-merge: tagged + plain"
      (define tm (make-tagged-merge max))
      (define tcv (tagged-cell-value 3 (list (cons #b01 10))))
      (define result (tm tcv 7))
      (check-true (tagged-cell-value? result))
      (check-equal? (tagged-cell-value-base result) 7)  ;; max(3, 7)
      (check-equal? (length (tagged-cell-value-entries result)) 1))

    (test-case "make-tagged-merge: plain + tagged"
      (define tm (make-tagged-merge max))
      (define tcv (tagged-cell-value 7 (list (cons #b10 20))))
      (define result (tm 3 tcv))
      (check-true (tagged-cell-value? result))
      (check-equal? (tagged-cell-value-base result) 7)  ;; max(3, 7)
      (check-equal? (length (tagged-cell-value-entries result)) 1))

    (test-case "make-tagged-merge: both plain delegates to domain-merge"
      (define tm (make-tagged-merge max))
      (check-equal? (tm 3 7) 7)
      (check-equal? (tm 10 2) 10))
    ))

;; ============================================================
;; Integration Tests: tagged-cell-value in propagator network
;; ============================================================

(define tagged-cell-network-tests
  (test-suite "Phase 4: tagged-cell-value in propagator network"

    ;; --- Worldview cache cell ---

    (test-case "worldview cache cell: pre-allocated at cell-id 1"
      (define net (make-prop-network))
      ;; Cell-id 1 exists and holds 0 (no speculation)
      (define raw (net-cell-read-raw net worldview-cache-cell-id))
      (check-equal? raw 0))

    (test-case "worldview cache cell: replacement merge (D.10)"
      (define net0 (make-prop-network))
      ;; Write bit 0
      (define net1 (net-cell-write net0 worldview-cache-cell-id #b01))
      (check-equal? (net-cell-read-raw net1 worldview-cache-cell-id) #b01)
      ;; Write #b10 — replacement merge, NOT bitwise-ior
      (define net2 (net-cell-write net1 worldview-cache-cell-id #b10))
      (check-equal? (net-cell-read-raw net2 worldview-cache-cell-id) #b10))

    (test-case "worldview cache cell: replacement handles retraction"
      (define net0 (make-prop-network))
      (define net1 (net-cell-write net0 worldview-cache-cell-id #b111))
      ;; Writing a subset REPLACES — bits CAN decrease (retraction)
      (define net2 (net-cell-write net1 worldview-cache-cell-id #b001))
      (check-equal? (net-cell-read-raw net2 worldview-cache-cell-id) #b001))

    (test-case "worldview cache cell: no-change write is no-op"
      (define net0 (make-prop-network))
      (define net1 (net-cell-write net0 worldview-cache-cell-id #b101))
      ;; Same value → merge returns eq? old → no cell change
      (define net2 (net-cell-write net1 worldview-cache-cell-id #b101))
      ;; Should be eq? (same network object — no change detected)
      (check-eq? net1 net2))

    ;; --- net-cell-read with tagged-cell-value ---

    (test-case "net-cell-read: tagged-cell-value, worldview 0 → base"
      (define net0 (make-prop-network))
      ;; Create a cell initialized with a tagged-cell-value
      (define tcv (tagged-cell-value 'base (list (cons #b01 'speculative))))
      (define-values (net1 cid) (net-new-cell net0 tcv tagged-cell-merge))
      ;; Worldview cache is 0 → read returns base
      (check-equal? (net-cell-read net1 cid) 'base))

    (test-case "net-cell-read: tagged-cell-value, worldview matches entry"
      (define net0 (make-prop-network))
      (define tcv (tagged-cell-value 'base (list (cons #b01 'left))))
      (define-values (net1 cid) (net-new-cell net0 tcv tagged-cell-merge))
      ;; Write bit 0 to worldview cache
      (define net2 (net-cell-write net1 worldview-cache-cell-id #b01))
      ;; Now read should return 'left (entry #b01 ⊆ worldview #b01)
      (check-equal? (net-cell-read net2 cid) 'left))

    (test-case "net-cell-read: tagged-cell-value, worldview doesn't match → base"
      (define net0 (make-prop-network))
      (define tcv (tagged-cell-value 'base (list (cons #b10 'right))))
      (define-values (net1 cid) (net-new-cell net0 tcv tagged-cell-merge))
      ;; Write bit 0 (not bit 1) to worldview cache
      (define net2 (net-cell-write net1 worldview-cache-cell-id #b01))
      ;; Entry #b10 is NOT subset of worldview #b01 → returns base
      (check-equal? (net-cell-read net2 cid) 'base))

    ;; --- net-cell-write with tagged-cell-value ---

    (test-case "net-cell-write: auto-tags when cell is tagged and worldview non-zero"
      (define net0 (make-prop-network))
      ;; Create tagged cell
      (define tcv (tagged-cell-value 'base '()))
      (define-values (net1 cid) (net-new-cell net0 tcv tagged-cell-merge))
      ;; Set worldview to #b01
      (define net2 (net-cell-write net1 worldview-cache-cell-id #b01))
      ;; Write a plain value — should be auto-tagged with worldview bitmask
      (define net3 (net-cell-write net2 cid 'speculative))
      ;; Raw read reveals the tagged-cell-value with entry
      (define raw (net-cell-read-raw net3 cid))
      (check-true (tagged-cell-value? raw))
      (check-equal? (length (tagged-cell-value-entries raw)) 1)
      (check-equal? (car (tagged-cell-value-entries raw)) (cons #b01 'speculative))
      ;; Filtered read under worldview #b01 sees the speculative value
      (check-equal? (net-cell-read net3 cid) 'speculative))

    (test-case "net-cell-write: no tag when worldview is 0"
      (define net0 (make-prop-network))
      (define tcv (tagged-cell-value 'base '()))
      (define-values (net1 cid) (net-new-cell net0 tcv tagged-cell-merge))
      ;; Worldview is 0 (default). Write a plain value.
      (define net2 (net-cell-write net1 cid 'unconditional))
      ;; Should update the base, not add an entry
      (define raw (net-cell-read-raw net2 cid))
      (check-true (tagged-cell-value? raw))
      (check-equal? (tagged-cell-value-base raw) 'unconditional)
      (check-equal? (tagged-cell-value-entries raw) '()))

    ;; --- Branch isolation: two branches write, reads are worldview-dependent ---

    (test-case "branch isolation: left/right writes visible only under their worldview"
      (define net0 (make-prop-network))
      (define tcv (tagged-cell-value 'base '()))
      (define-values (net1 cid) (net-new-cell net0 tcv tagged-cell-merge))

      ;; Simulate left branch write (bit 0)
      (define net-wv-left (net-cell-write net1 worldview-cache-cell-id #b01))
      (define net-left (net-cell-write net-wv-left cid 'left-val))

      ;; Simulate right branch write (bit 1) — start from net-left but change worldview
      ;; Reset worldview first by starting fresh from net1 to avoid left bit
      ;; (In real ATMS, branches are on separate PU forks. Here we simulate manually.)
      (define net-wv-right (net-cell-write net1 worldview-cache-cell-id #b10))
      (define net-right (net-cell-write net-wv-right cid 'right-val))

      ;; Read raw from left branch network
      (define raw-left (net-cell-read-raw net-left cid))
      (check-equal? (length (tagged-cell-value-entries raw-left)) 1)
      ;; Filtered read sees left-val
      (check-equal? (net-cell-read net-left cid) 'left-val)

      ;; Read raw from right branch network
      (define raw-right (net-cell-read-raw net-right cid))
      (check-equal? (length (tagged-cell-value-entries raw-right)) 1)
      ;; Filtered read sees right-val
      (check-equal? (net-cell-read net-right cid) 'right-val))

    ;; --- Propagator firing with tagged cell ---

    (test-case "propagator reads tagged cell under worldview"
      (define net0 (make-prop-network))
      ;; Source cell: tagged, with one speculative entry
      (define src-tcv (tagged-cell-value 'src-base (list (cons #b01 'src-spec))))
      (define-values (net1 src-cid) (net-new-cell net0 src-tcv tagged-cell-merge))
      ;; Destination cell: plain
      (define-values (net2 dst-cid) (net-new-cell net1 'dst-init (lambda (a b) b)))
      ;; Propagator: copy source to destination
      (define (copy-fn net)
        (define v (net-cell-read net src-cid))
        (net-cell-write net dst-cid v))
      (define-values (net3 _pid) (net-add-propagator net2 (list src-cid) (list dst-cid) copy-fn))
      ;; Set worldview to #b01 so propagator sees 'src-spec
      (define net4 (net-cell-write net3 worldview-cache-cell-id #b01))
      ;; Run to quiescence — propagator fires, reads 'src-spec, writes to dst
      (define net5 (run-to-quiescence net4))
      (check-equal? (net-cell-read net5 dst-cid) 'src-spec))

    (test-case "propagator reads tagged cell base when worldview 0"
      (define net0 (make-prop-network))
      (define src-tcv (tagged-cell-value 'src-base (list (cons #b01 'src-spec))))
      (define-values (net1 src-cid) (net-new-cell net0 src-tcv tagged-cell-merge))
      (define-values (net2 dst-cid) (net-new-cell net1 'dst-init (lambda (a b) b)))
      (define (copy-fn net)
        (define v (net-cell-read net src-cid))
        (net-cell-write net dst-cid v))
      (define-values (net3 _pid) (net-add-propagator net2 (list src-cid) (list dst-cid) copy-fn))
      ;; Worldview stays at 0 — propagator reads base
      (define net4 (run-to-quiescence net3))
      (check-equal? (net-cell-read net4 dst-cid) 'src-base))
    ))

;; ============================================================
;; Run all tests
;; ============================================================

(run-tests tagged-cell-unit-tests)
(run-tests tagged-cell-network-tests)
