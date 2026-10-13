#lang racket/base

;;; test-tagged-cell-value.rkt — BSP-LE Track 2 Phase 4: bitmask-tagged cell value tests
;;;
;;; Tests: tagged-cell-value read/write/merge, make-tagged-merge,
;;; worldview cache cell in propagator core, net-cell-read/write
;;; integration with tagged-cell-values.

(require rackunit
         rackunit/text-ui
         rackcheck
         racket/list
         racket/set
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

    ;; ============================================================
    ;; PPN 4C Phase 3A.b (2026-05-22): Per-branch isolation substrate parity
    ;; ============================================================
    ;;
    ;; Per §9.3.4 Q3: substrate-level parity tests for the per-branch isolation
    ;; PROPERTY itself, independent of Phase 3A's fork-on-union mechanism. These
    ;; tests verify the load-bearing assumption Option E rests on: under
    ;; `promote-cell-to-tagged` + `wrap-with-worldview` writes, per-branch
    ;; tagged entries are correctly isolated by subset filtering on
    ;; tagged-cell-read.
    ;;
    ;; If these tests ever regress, the per-branch isolation guarantee for any
    ;; downstream consumer (PPN 4C Phase 3A.b fork-on-union, Phase 9b γ
    ;; hole-fill multi-candidate, PReduce e-class branching) breaks
    ;; structurally. Empirical tripwire for the substrate property.

    (test-case "per-branch isolation: writes under disjoint worldviews are isolated"
      (define net0 (make-prop-network))
      ;; Allocate a plain cell with hash-replace merge (analog of attribute-map)
      (define (replace-merge old new) new)
      (define-values (net1 cid) (net-new-cell net0 (hasheq 'pos 'base-value) replace-merge))
      ;; Promote to tagged-cell-value (mirrors Option E pattern)
      (define net2 (promote-cell-to-tagged net1 cid))
      ;; Write under wv=#b01 (branch 1's bitmask)
      (define net3
        (parameterize ([current-worldview-bitmask #b01])
          (net-cell-write net2 cid (hasheq 'pos 'branch-1-value))))
      ;; Write under wv=#b10 (branch 2's bitmask, disjoint)
      (define net4
        (parameterize ([current-worldview-bitmask #b10])
          (net-cell-write net3 cid (hasheq 'pos 'branch-2-value))))
      ;; Read under wv=#b01 → sees ONLY branch 1's entry
      (define v-branch1
        (parameterize ([current-worldview-bitmask #b01])
          (net-cell-read net4 cid)))
      (check-equal? (hash-ref v-branch1 'pos) 'branch-1-value
                    "Read under wv=#b01 sees branch-1's tagged entry only")
      ;; Read under wv=#b10 → sees ONLY branch 2's entry
      (define v-branch2
        (parameterize ([current-worldview-bitmask #b10])
          (net-cell-read net4 cid)))
      (check-equal? (hash-ref v-branch2 'pos) 'branch-2-value
                    "Read under wv=#b10 sees branch-2's tagged entry only")
      ;; Read under wv=#b00 (outer/no-speculation) → sees BASE only (not branch entries)
      (define v-outer
        (parameterize ([current-worldview-bitmask #b00])
          (net-cell-read net4 cid)))
      (check-equal? (hash-ref v-outer 'pos) 'base-value
                    "Read under wv=#b00 sees base only (per-branch entries hidden)"))

    (test-case "per-branch isolation: failed branch's write does NOT affect sibling branch's read"
      ;; THE 3A.b correctness property: in the originally-failing scenario,
      ;; one branch's contradiction must NOT be visible to the sibling branch.
      (define net0 (make-prop-network))
      (define (replace-merge old new) new)
      (define-values (net1 cid) (net-new-cell net0 (hasheq) replace-merge))
      (define net2 (promote-cell-to-tagged net1 cid))
      ;; Branch 2 writes "contradiction" sentinel under its wv
      (define net3
        (parameterize ([current-worldview-bitmask #b10])
          (net-cell-write net2 cid (hasheq 'pos 'CONTRADICTION))))
      ;; Branch 1 reads under wv=#b01 — should NOT see Branch 2's contradiction
      ;; (the precise bug Option E fixes: pre-promote, this read would see
      ;; CONTRADICTION in base; post-promote, branches are isolated)
      (define v-branch1
        (parameterize ([current-worldview-bitmask #b01])
          (net-cell-read net3 cid)))
      (check-false (equal? (hash-ref v-branch1 'pos #f) 'CONTRADICTION)
                   "Branch 1 (wv=#b01) does NOT see Branch 2's contradiction (wv=#b10)")
      ;; Branch 2 reads its own contradiction
      (define v-branch2
        (parameterize ([current-worldview-bitmask #b10])
          (net-cell-read net3 cid)))
      (check-equal? (hash-ref v-branch2 'pos) 'CONTRADICTION
                    "Branch 2 sees its own contradiction (wv=#b10)"))

    (test-case "per-branch isolation: promote-cell-to-tagged is idempotent"
      ;; The promote helper should be safely callable multiple times — once
      ;; tagged, subsequent calls are no-ops. Required for the fork-on-union
      ;; handler's "one promote per fork firing" pattern to be safe when
      ;; multiple forks fire across BSP rounds.
      (define net0 (make-prop-network))
      (define-values (net1 cid) (net-new-cell net0 'plain (lambda (a b) b)))
      (define net2 (promote-cell-to-tagged net1 cid))
      (define net3 (promote-cell-to-tagged net2 cid))  ;; second call
      ;; Read should give 'plain (the base, no entries written)
      (check-equal? (parameterize ([current-worldview-bitmask 0])
                      (net-cell-read net3 cid))
                    'plain
                    "Double-promote idempotent — base preserved"))
    ))

;; ============================================================
;; DEFERRED 148: entries are a SET — the join must be idempotent
;; ============================================================
;; The `entries` component is semantically a set of (bitmask . value) pairs
;; ordered by inclusion, join = union. `cons`/`append` is the sequence monoid:
;; associative but NOT idempotent, so a re-write of information already present
;; grew the list without bound (one duplicate per round on every long-lived
;; speculative cell) and — because the fire protocol diffs raw values with
;; `equal?` (propagator.rkt:2881, :2900) — re-scheduled every dependent on a
;; write that carried no new information. These tests pin the set semantics on
;; all three sites (tagged-cell-write, tagged-cell-merge, make-tagged-merge).

;; The OLD append-based union, kept here as the reference for the refinement
;; property: under the D.12 join-reader (domain-merge supplied) dedup must be
;; invisible — the deduped form reads identically for every worldview.
(define (ref-append-merge domain-merge)
  (lambda (old new)
    (tagged-cell-value
     (domain-merge (tagged-cell-value-base old) (tagged-cell-value-base new))
     (append (tagged-cell-value-entries new)
             (tagged-cell-value-entries old)))))

;; Small alphabets so the generators collide often: 3 worldview bits, 4 values.
(define gen:bm (gen:integer-in 1 7))
(define gen:val (gen:integer-in 0 3))
(define gen:entry (gen:let ([bm gen:bm] [v gen:val]) (cons bm v)))
(define gen:entries (gen:list gen:entry #:max-length 12))
(define gen:worldview (gen:integer-in 0 7))

;; Build a tcv the way production does: fold one-entry deltas through
;; make-tagged-merge (propagator.rkt:2018 shape).
(define (build-via-deltas tm entries)
  (for/fold ([acc (tagged-cell-value 0 '())]) ([e (in-list entries)])
    (tm acc (tagged-cell-value 0 (list e)))))

(define tagged-cell-dedup-tests
  (test-suite "DEFERRED 148: tagged-cell-value entries are a set"

    ;; --- pins: the three sites ---

    (test-case "tagged-cell-write: re-writing the same (bm . v) is a no-op"
      (define t1 (tagged-cell-write (tagged-cell-value 'base '()) #b01 'x))
      (define t2 (tagged-cell-write t1 #b01 'x))
      (check-equal? (length (tagged-cell-value-entries t2)) 1)
      (check-equal? t2 t1)
      ;; and the entries list is the SAME object (nothing was consed)
      (check-eq? (tagged-cell-value-entries t2) (tagged-cell-value-entries t1)))

    (test-case "tagged-cell-write: same bitmask, different value is a new entry"
      (define t1 (tagged-cell-write (tagged-cell-value 'base '()) #b01 'x))
      (define t2 (tagged-cell-write t1 #b01 'y))
      (check-equal? (length (tagged-cell-value-entries t2)) 2))

    (test-case "tagged-cell-merge: merging a value with itself leaves entries eq?"
      (define t (tagged-cell-value 'b (list (cons #b01 'x) (cons #b10 'y))))
      (define r (tagged-cell-merge t t))
      (check-eq? (tagged-cell-value-entries r) (tagged-cell-value-entries t)))

    (test-case "tagged-cell-merge: union keeps newer-first among genuinely new entries"
      (define old (tagged-cell-value 'b (list (cons #b01 'x))))
      (define new (tagged-cell-value 'b (list (cons #b10 'y) (cons #b01 'x) (cons #b11 'z))))
      (check-equal? (tagged-cell-value-entries (tagged-cell-merge old new))
                    (list (cons #b10 'y) (cons #b11 'z) (cons #b01 'x))))

    (test-case "make-tagged-merge: the production delta shape re-written 50× stays at 1 entry"
      (define tm (make-tagged-merge max))
      (define delta (tagged-cell-value 0 (list (cons #b101 42))))
      (define final (for/fold ([acc (tagged-cell-value 0 '())]) ([_ (in-range 50)])
                      (tm acc delta)))
      (check-equal? (tagged-cell-value-entries final) (list (cons #b101 42))))

    (test-case "make-tagged-merge: a no-information write returns a value equal? to old (scheduler diff sees no change)"
      (define tm (make-tagged-merge max))
      (define old (tagged-cell-value 7 (list (cons #b01 3) (cons #b10 5))))
      (define delta (tagged-cell-value 7 (list (cons #b10 5))))
      (define r (tm old delta))
      (check-equal? r old)
      (check-eq? (tagged-cell-value-entries r) (tagged-cell-value-entries old)))

    (test-case "compat reader (no domain-merge): a no-information re-write cannot change the read"
      ;; The compat path returns the OLDEST matching entry (tagged-cell-read
      ;; builds all-matching by cons, then takes car = last in list order).
      ;; Duplicates were prepended, so they never changed this read; the fix must
      ;; keep it that way while leaving the value itself unchanged.
      (define tm (make-tagged-merge (lambda (o n) n)))
      (define t0 (tm (tagged-cell-value 'b (list (cons #b001 'x)))
                     (tagged-cell-value 'b (list (cons #b011 'y)))))
      (check-equal? (tagged-cell-read t0 #b011) 'x)
      (define t1 (tm t0 (tagged-cell-value 'b (list (cons #b001 'x)))))
      (check-equal? (tagged-cell-read t1 #b011) 'x)
      (check-equal? t1 t0))

    ;; --- properties ---

    (test-case "property: tagged-cell-write is idempotent"
      (check-property
       (make-config #:tests 200)
       (property ([es gen:entries] [e gen:entry])
         (define t (for/fold ([acc (tagged-cell-value 0 '())]) ([x (in-list es)])
                     (tagged-cell-write acc (car x) (cdr x))))
         (define once (tagged-cell-write t (car e) (cdr e)))
         (define twice (tagged-cell-write once (car e) (cdr e)))
         (check-equal? twice once)
         (check-eq? (tagged-cell-value-entries twice) (tagged-cell-value-entries once)))))

    (test-case "property: make-tagged-merge is idempotent on entries (x ⊔ x = x)"
      (check-property
       (make-config #:tests 200)
       (property ([es gen:entries])
         (define tm (make-tagged-merge max))
         (define t (build-via-deltas tm es))
         (define r (tm t t))
         (check-equal? r t)
         (check-eq? (tagged-cell-value-entries r) (tagged-cell-value-entries t)))))

    (test-case "property: entries never contain duplicates after any write sequence"
      (check-property
       (make-config #:tests 200)
       (property ([es gen:entries])
         (define tm (make-tagged-merge max))
         (define entries (tagged-cell-value-entries (build-via-deltas tm es)))
         (check-equal? (length entries) (length (remove-duplicates entries)))
         ;; and the length is bounded by the alphabet of distinct pairs written
         (check-equal? (length entries) (length (remove-duplicates es))))))

    (test-case "property: merge is a set union (newer-first order aside)"
      (check-property
       (make-config #:tests 200)
       (property ([as gen:entries] [bs gen:entries])
         (define tm (make-tagged-merge max))
         (define a (build-via-deltas tm as))
         (define b (build-via-deltas tm bs))
         (define r (tagged-cell-value-entries (tm a b)))
         (check-equal? (length r) (length (remove-duplicates r)))
         (check-equal? (list->set r)
                       (set-union (list->set (tagged-cell-value-entries a))
                                  (list->set (tagged-cell-value-entries b)))))))

    (test-case "property: dedup is invisible to BOTH readers (refinement of the old append semantics)"
      (check-property
       (make-config #:tests 300)
       (property ([as gen:entries] [bs gen:entries] [w gen:worldview])
         (define tm (make-tagged-merge max))
         (define ref (ref-append-merge max))
         ;; a and b carry duplicates here on purpose (raw entry lists, not built
         ;; through the deduping path) — the readers must agree regardless.
         (define a (tagged-cell-value 0 as))
         (define b (tagged-cell-value 0 bs))
         ;; D.12 join-reader: order-insensitive by commutativity + idempotence of max
         (check-equal? (tagged-cell-read (tm a b) w max)
                       (tagged-cell-read (ref a b) w max))
         ;; compat reader (oldest match): the tail of the list is old's entries
         ;; in both forms, and new's matching entries survive the union exactly
         ;; when old has no match
         (check-equal? (tagged-cell-read (tm a b) w)
                       (tagged-cell-read (ref a b) w)))))
    ))

;; ============================================================
;; Run all tests
;; ============================================================

(run-tests tagged-cell-unit-tests)
(run-tests tagged-cell-network-tests)
(run-tests tagged-cell-dedup-tests)
