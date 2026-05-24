#lang racket/base

;;;
;;; tests/test-union-types-atms.rkt — PPN 4C Phase 3A union types via ATMS
;;;
;;; Per addendum design §9.3 + §9.3.1 + §9.3.2 + §9.3.3 (Phase 3A.a body).
;;; Tests the fork-on-union stratum-handler architecture per Realization B
;;; (in-place worldview tagging on shared carrier; NOT fork-and-rejoin).
;;;
;;; Phase 3A.a delivers:
;;;   - make-branch-check-fire-fn factory (per-branch propagator wrapped at
;;;     branch worldview; reads INHABITANT; checks subtype against branch
;;;     component; writes contradiction under branch wv if incompatible)
;;;   - process-fork-on-union handler (consumes cell-15 requests; allocates
;;;     N aids; initializes worldview-cache branch bits; installs N branch
;;;     check propagators)
;;;
;;; Test strategy (per §9.3.3.4):
;;;   - Unit: direct invocation of process-fork-on-union with synthetic
;;;     pending-hash (no classifier-watcher needed — 3A.c delivers that)
;;;   - Unit: make-branch-check-fire-fn under branch worldview (subtype
;;;     pass + non-subtype contradiction write)
;;;   - E2E: stub classifier-watcher writes synthetic request to cell-15;
;;;     run BSP rounds; verify branch propagators install + fire correctly
;;;
;;; Phase 3A.b will add the contradiction watcher + cell-16 narrowing.
;;; Tests here verify 3A.a in isolation; full union-check end-to-end at 3A.c.
;;;

(require rackunit
         racket/set
         racket/list
         racket/string                       ;; PPN 4C Phase 3C.b.5.c — string-contains?
         "../syntax.rkt"
         "../propagator.rkt"
         "../decision-cell.rkt"
         "../atms.rkt"
         "../union-types.rkt"
         "../classify-inhabit.rkt"
         "../typing-propagators.rkt"
         "../elab-speculation-bridge.rkt"
         ;; PPN 4C Phase 3C.b.4 (2026-05-23): derivation-chain struct
         ;; accessors for threshold-fire-fn unit tests (T-C.b.4-*).
         "../error-explanation.rkt")

;; Local bot value (matches the local classify-inhabit-bot-value in
;; typing-propagators.rkt:349 — not exported).
(define test-classify-inhabit-bot (classify-inhabit-value 'bot 'bot))

;; ========================================
;; Fixture: synthetic elab-network + attribute-map cell + position
;; ========================================
;;
;; Phase 3A.a tests operate at the prop-network level (no full elaborator
;; needed). Each test allocates a fresh prop-network + attribute-map cell;
;; writes a synthetic classify-inhabit-value at a position; invokes
;; process-fork-on-union directly (unit) or via cell-15 write (E2E).

;; Create a fresh prop-network + attribute-map cell + position.
;; Returns: (values net tm-cid position).
(define (make-test-fixture)
  (define net (make-prop-network))
  ;; Allocate an attribute-map cell for typing (similar to the production
  ;; pattern at init-attribute-map-cell!). Use hash-replace merge since
  ;; the attribute-map's full facet-merge isn't load-bearing for these tests.
  (define (attr-map-merge old new)
    (cond
      [(not (hash? old)) new]
      [(not (hash? new)) old]
      [else
       (for/fold ([acc old]) ([(k v) (in-hash new)])
         (hash-set acc k v))]))
  (define-values (net1 tm-cid) (net-new-cell net (hasheq) attr-map-merge))
  ;; Use a symbol as the synthetic position (production uses AST nodes).
  (values net1 tm-cid 'test-position))

;; Write a classify-inhabit-value at the given position's :type facet.
(define (write-classify-inhabit net tm-cid position classifier inhabitant)
  (define cinhab-val (classify-inhabit-value classifier inhabitant))
  (net-cell-write net tm-cid (hasheq position (hasheq ':type cinhab-val))))

;; ========================================
;; Unit: make-branch-check-fire-fn — subtype-pass case
;; ========================================

(test-case "make-branch-check-fire-fn: inhabitant inhabits component → no contradiction"
  ;; Component = Int; inhabitant = (expr-nat-val 3) (synthesizes to Nat <: Int)
  (define-values (net tm-cid position) (make-test-fixture))
  ;; Write a synthetic inhabitant — the value's expression form
  (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-nat-val 3)))
  ;; Build branch check fire-fn for component = expr-Int
  (define fire-fn (make-branch-check-fire-fn tm-cid position (expr-Int)))
  ;; Invoke directly (no wrap-with-worldview for unit test)
  (define net2 (fire-fn net1))
  ;; Read back: no contradiction written (cell value unchanged at :type for this position)
  (define tm-val (net-cell-read net2 tm-cid))
  (define record (hash-ref tm-val position (hasheq)))
  (define cinhab-val (hash-ref record ':type test-classify-inhabit-bot))
  ;; Should NOT be contradiction (inhabitant Nat <: Int is compatible)
  (check-false (classify-inhabit-contradiction? cinhab-val)
               "Inhabitant Nat is subtype of Int → no contradiction"))

;; ========================================
;; Unit: make-branch-check-fire-fn — non-subtype case writes contradiction
;; ========================================

(test-case "make-branch-check-fire-fn: inhabitant does NOT inhabit component → contradiction"
  ;; Component = String; inhabitant = (expr-nat-val 3) (Nat, not <: String)
  (define-values (net tm-cid position) (make-test-fixture))
  (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-nat-val 3)))
  ;; Build branch check fire-fn for component = expr-String
  (define fire-fn (make-branch-check-fire-fn tm-cid position (expr-String)))
  ;; Invoke directly
  (define net2 (fire-fn net1))
  ;; Read back: contradiction written
  (define tm-val (net-cell-read net2 tm-cid))
  (define record (hash-ref tm-val position (hasheq)))
  (define cinhab-val (hash-ref record ':type test-classify-inhabit-bot))
  ;; SHOULD be contradiction (Nat not subtype of String)
  (check-true (classify-inhabit-contradiction? cinhab-val)
              "Inhabitant Nat is NOT subtype of String → contradiction sentinel written"))

;; ========================================
;; Unit: make-branch-check-fire-fn — defers when inhabitant not populated
;; ========================================

(test-case "make-branch-check-fire-fn: defers when inhabitant is 'bot"
  (define-values (net tm-cid position) (make-test-fixture))
  ;; Write only classifier; inhabitant stays 'bot
  (define net1 (write-classify-inhabit net tm-cid position (expr-Int) 'bot))
  (define fire-fn (make-branch-check-fire-fn tm-cid position (expr-String)))
  (define net2 (fire-fn net1))
  (define tm-val (net-cell-read net2 tm-cid))
  (define record (hash-ref tm-val position (hasheq)))
  (define cinhab-val (hash-ref record ':type test-classify-inhabit-bot))
  ;; Defer — should not write contradiction (inhabitant not yet populated)
  (check-false (classify-inhabit-contradiction? cinhab-val)
               "Inhabitant bot → defer; no contradiction"))

;; ========================================
;; Unit: process-fork-on-union — empty pending-hash is no-op
;; ========================================

(test-case "process-fork-on-union: empty pending-hash returns net unchanged"
  (define-values (net tm-cid position) (make-test-fixture))
  (define net-before-wv (net-cell-read net worldview-cache-cell-id))
  (define net1 (process-fork-on-union net (hasheq)))
  (check-equal? (net-cell-read net1 worldview-cache-cell-id) net-before-wv
                "Empty pending → worldview-cache unchanged"))

;; ========================================
;; Unit: process-fork-on-union — allocates N aids + sets worldview bits
;; ========================================

(test-case "process-fork-on-union: allocates N aids + sets N branch bits"
  (define-values (net tm-cid position) (make-test-fixture))
  ;; Set up current-command-atms (per-command ATMS box; production-allocated
  ;; via driver.rkt:464; for tests we initialize manually).
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    ;; Synthetic request: 2 components (Int + String)
    (define components (list (expr-Int) (expr-String)))
    (define request-info
      (hasheq 'components components
              'tm-cid tm-cid))
    (define pending-hash (hasheq position request-info))
    (define wv-before (net-cell-read net worldview-cache-cell-id))
    (define net1 (process-fork-on-union net pending-hash))
    (define wv-after (net-cell-read net1 worldview-cache-cell-id))
    ;; Worldview-cache should have 2 bits set that weren't before
    (define added-bits (bitwise-and wv-after (bitwise-not wv-before)))
    (check-equal? (popcount added-bits) 2
                  "2 branch bits set in worldview-cache after fork-on-union")
    ;; Net should have 5 more propagators (N=2: per branch, 1 check + 1 watcher;
    ;; plus 1 PER-FORK threshold-fire propagator for chain emission).
    ;; PPN 4C Phase 3A.b (2026-05-22): updated from 2 → 4 to account for the
    ;; N fire-once contradiction watchers installed alongside the N branch
    ;; check propagators (Option E per §9.3.4 — N check + N watcher pattern).
    ;; PPN 4C Phase 3C.b.4 (2026-05-23): updated from 4 → 5 to account for the
    ;; per-fork threshold-fire propagator (step 4.5) — closes over (position,
    ;; branch-aid-set, request-info); reads cell-18; fires when all branches
    ;; contradict; writes derivation-chain to cell-19. Per addendum §9.5.3.3
    ;; refined option (d) set-latch + threshold canonical pattern.
    (check-equal? (- (prop-network-next-prop-id net1)
                     (prop-network-next-prop-id net))
                  5
                  "5 propagators installed (2 branch checks + 2 contradiction watchers + 1 threshold)")))

;; ========================================
;; Unit: process-fork-on-union — defensive on malformed request
;; ========================================

(test-case "process-fork-on-union: missing 'components → defensive no-op for that entry"
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define malformed-request (hasheq 'tm-cid tm-cid))  ;; missing 'components
    (define pending-hash (hasheq position malformed-request))
    (define wv-before (net-cell-read net worldview-cache-cell-id))
    (define net1 (process-fork-on-union net pending-hash))
    ;; Defensive: no change
    (check-equal? (net-cell-read net1 worldview-cache-cell-id) wv-before
                  "Malformed request (no 'components) → no worldview change")))

;; ========================================
;; E2E: classifier-watcher stub → process-fork-on-union → branch propagator fires
;; ========================================
;;
;; Simulates the full Phase 3A flow without 3A.c's classifier-watcher install:
;;   1. Write inhabitant (Nat value 3) to position
;;   2. STUB classifier-watcher: write fork-on-union request to cell-15
;;   3. Run process-fork-on-union (handler simulation) — allocates aids,
;;      sets worldview bits, installs 2 branch propagators
;;   4. Run BSP rounds — branch propagators fire under their worldviews
;;   5. Verify: branch for compatible component (Int) does NOT write
;;      contradiction; branch for incompatible component (String) DOES write
;;      contradiction tagged at its worldview
;;
;; PPN 4C Phase 3A.b (2026-05-22) UPDATE: contradiction watcher + cell-16 + handler
;; now landed. Branch narrowing fires post-fork-on-union: failed branches' bits
;; clear; successful branches' bits remain. Test expectations updated to reflect
;; the post-3A.b end-to-end semantics. (The dedicated "Int succeeds, String fails"
;; E2E test in the 3A.b section below verifies the full happy + sad path
;; separately and is the more detailed semantic check; this 3A.a E2E test now
;; verifies the integration flow + cell-15 reset + watcher install completeness.)

(test-case "E2E: fork-on-union flow with stubbed classifier-watcher (post-3A.b semantics)"
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    ;; Step 1: write inhabitant (synthesizes to Nat — subtype of Int, NOT String)
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-nat-val 3)))
    ;; Step 2: STUB classifier-watcher — write a fork-on-union request to cell-15
    ;; (In production 3A.c, the classifier-watcher would detect classifier becoming
    ;; an expr-union and emit this request automatically.)
    (define components (list (expr-Int) (expr-String)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                 (hasheq position request)))
    ;; Step 3: run to quiescence — BSP outer-loop invokes process-fork-on-union
    ;; handler (between rounds): allocates aids → sets worldview bits → promotes
    ;; attribute-map carrier (3A.b Option E) → installs N branch propagators +
    ;; N contradiction watchers; subsequent rounds fire propagators; failed
    ;; branches' watchers write to cell-16; process-fork-contradiction narrows.
    (define net4 (run-to-quiescence net2))
    ;; Step 4: verify outcomes (post-3A.b)
    (define wv-after-fork (net-cell-read net4 worldview-cache-cell-id))
    (define initial-wv (net-cell-read net worldview-cache-cell-id))
    (define branch-bits (bitwise-and wv-after-fork (bitwise-not initial-wv)))
    ;; Post-3A.b: String branch contradicts (Nat NOT <: String) → handler narrows
    ;; String's bit. Int branch succeeds (Nat <: Int) → Int's bit remains.
    ;; Expected: exactly 1 branch bit remaining (Int).
    (check-equal? (popcount branch-bits) 1
                  "post-3A.b: 1 branch bit remains (Int retained; String narrowed by handler)")
    ;; Verify cell-15 was reset (BSP #:reset-value)
    (check-equal? (net-cell-read net4 fork-on-union-request-cell-id) (hasheq)
                  "cell-15 reset after handler runs (BSP #:reset-value)")
    ;; cell-16 also reset (handler consumed aid-set; #:reset-value cleared)
    (check-equal? (net-cell-read net4 fork-contradiction-request-cell-id) (seteq)
                  "cell-16 reset after handler runs")))

;; ========================================
;; E2E: stratum tier — verify process-fork-on-union runs successfully
;;       (validates D-3A.a-stratum-tier risk)
;; ========================================

(test-case "stratum tier verification: handler installs propagators without error"
  ;; D-3A.a-stratum-tier risk: handler installs propagators (topology change).
  ;; If #:tier 'value blocks topology, this test would error. Currently
  ;; registered at #:tier 'value (3A.0 registration). This test verifies that
  ;; direct invocation succeeds. (BSP-time invocation is verified by E2E test
  ;; above through run-to-quiescence.)
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define request (hasheq 'components (list (expr-Int)) 'tm-cid tm-cid))
    (define pending-hash (hasheq position request))
    ;; Should not error
    (check-not-exn (lambda () (process-fork-on-union net pending-hash))
                   "process-fork-on-union runs without topology guard violation")))

;; ============================================================
;; PPN 4C Phase 3A.b — contradiction watcher + handler tests
;; ============================================================

;; ========================================
;; Unit: make-branch-contradiction-watcher-fire-fn — emits aid on contradiction
;; ========================================

;; PPN 4C Phase 3C.b.2 (2026-05-23): watcher fan-out — writes to BOTH cell-16
;; (existing transient narrowing handler input) AND cell-18 (NEW persistent
;; latch for per-fork threshold-fire-once propagator at 3C.b.4). Test verifies
;; BOTH writes land with correct shapes (cell-16: (seteq aid); cell-18:
;; (hasheq position (seteq aid))). Per addendum §9.5.3.3 refined option (d).
(test-case "make-branch-contradiction-watcher-fire-fn: fan-out to cell-16 + cell-18 when contradiction sentinel present"
  (define-values (net tm-cid position) (make-test-fixture))
  ;; Write contradiction sentinel at position's :type
  (define net1 (net-cell-write net tm-cid
                               (hasheq position (hasheq ':type 'classify-inhabit-contradiction))))
  ;; Build watcher for synthetic aid (use bare aid struct; bit-pos = 0 for this test)
  (define test-aid (assumption-id 0))
  (define watcher-fn (make-branch-contradiction-watcher-fire-fn tm-cid position test-aid))
  ;; Invoke directly
  (define net2 (watcher-fn net1))
  ;; cell-16 should contain (seteq test-aid) — existing 3A.b behavior unchanged
  (define cell-16-val (net-cell-read net2 fork-contradiction-request-cell-id))
  (check-true (set? cell-16-val) "cell-16 holds a set")
  (check-equal? (set-count cell-16-val) 1 "1 aid in cell-16 set")
  (check-true (set-member? cell-16-val test-aid) "test-aid is in cell-16 set")
  ;; cell-18 should contain (hasheq position (seteq test-aid)) — NEW 3C.b.2 fan-out
  (define cell-18-val (net-cell-read net2 contradicted-branch-aids-cell-id))
  (check-true (hash? cell-18-val) "cell-18 holds a hash")
  (check-equal? (hash-count cell-18-val) 1 "1 position entry in cell-18 hash")
  (define cell-18-aids (hash-ref cell-18-val position (seteq)))
  (check-true (set? cell-18-aids) "cell-18's per-position entry is a set")
  (check-equal? (set-count cell-18-aids) 1 "1 aid in cell-18's per-position set")
  (check-true (set-member? cell-18-aids test-aid) "test-aid is in cell-18's per-position set"))

;; ========================================
;; Unit: make-branch-contradiction-watcher-fire-fn — no emit when no contradiction
;; ========================================

(test-case "make-branch-contradiction-watcher-fire-fn: NO emit (cell-16 + cell-18) when no contradiction"
  (define-values (net tm-cid position) (make-test-fixture))
  ;; Write a normal (non-contradiction) classify-inhabit-value
  (define net1 (write-classify-inhabit net tm-cid position (expr-Int) (expr-nat-val 3)))
  (define test-aid (assumption-id 0))
  (define watcher-fn (make-branch-contradiction-watcher-fire-fn tm-cid position test-aid))
  (define net2 (watcher-fn net1))
  ;; BOTH cells should remain empty (no fan-out at all when non-contradiction)
  (define cell-16-val (net-cell-read net2 fork-contradiction-request-cell-id))
  (check-equal? cell-16-val (seteq)
                "cell-16 remains empty seteq when no contradiction sentinel")
  ;; PPN 4C Phase 3C.b.2: cell-18 also untouched when no contradiction
  (define cell-18-val (net-cell-read net2 contradicted-branch-aids-cell-id))
  (check-equal? cell-18-val (hasheq)
                "cell-18 remains empty hasheq when no contradiction sentinel"))

;; ========================================
;; PPN 4C Phase 3C.b.2 (2026-05-23): cell-18 set-union per-position
;; ========================================
;; Multiple aids contradicting at the SAME position accumulate via set-union
;; in cell-18's per-position aid-set entry. Verifies hash-union-with-set-union
;; merge semantic (contradicted-branch-aids-merge).

(test-case "make-branch-contradiction-watcher-fire-fn: cell-18 set-union per-position across multiple aids"
  (define-values (net tm-cid position) (make-test-fixture))
  ;; Write contradiction sentinel at the position
  (define net1 (net-cell-write net tm-cid
                               (hasheq position (hasheq ':type 'classify-inhabit-contradiction))))
  ;; Two distinct aids contradict at the same position (simulating 2 branches)
  (define aid-0 (assumption-id 0))
  (define aid-1 (assumption-id 1))
  ;; Fire watcher for aid-0
  (define watcher-0 (make-branch-contradiction-watcher-fire-fn tm-cid position aid-0))
  (define net2 (watcher-0 net1))
  ;; Fire watcher for aid-1 (same position, different aid — simulating second branch)
  (define watcher-1 (make-branch-contradiction-watcher-fire-fn tm-cid position aid-1))
  (define net3 (watcher-1 net2))
  ;; cell-18: 1 position entry; set-union accumulated to (seteq aid-0 aid-1)
  (define cell-18-val (net-cell-read net3 contradicted-branch-aids-cell-id))
  (check-equal? (hash-count cell-18-val) 1 "still 1 position entry (same position)")
  (define cell-18-aids (hash-ref cell-18-val position (seteq)))
  (check-equal? (set-count cell-18-aids) 2 "2 aids in cell-18's per-position set (set-union)")
  (check-true (set-member? cell-18-aids aid-0) "aid-0 in set")
  (check-true (set-member? cell-18-aids aid-1) "aid-1 in set")
  ;; cell-16: also accumulated (set-union); both aids present
  (define cell-16-val (net-cell-read net3 fork-contradiction-request-cell-id))
  (check-equal? (set-count cell-16-val) 2 "2 aids in cell-16 (set-union semantic)")
  (check-true (set-member? cell-16-val aid-0) "aid-0 in cell-16")
  (check-true (set-member? cell-16-val aid-1) "aid-1 in cell-16"))

;; ========================================
;; PPN 4C Phase 3C.b.2 (2026-05-23): cell-18 hash-union across positions
;; ========================================
;; Aids contradicting at DIFFERENT positions accumulate as distinct hash
;; entries in cell-18. Verifies the hash-union (not per-position-merge)
;; portion of contradicted-branch-aids-merge.

(test-case "make-branch-contradiction-watcher-fire-fn: cell-18 hash-union across distinct positions"
  ;; Two distinct synthetic positions (use different symbols)
  (define net0 (make-prop-network))
  (define (attr-map-merge old new)
    (cond
      [(not (hash? old)) new]
      [(not (hash? new)) old]
      [else (for/fold ([acc old]) ([(k v) (in-hash new)]) (hash-set acc k v))]))
  (define-values (net1 tm-cid) (net-new-cell net0 (hasheq) attr-map-merge))
  (define pos-a 'position-a)
  (define pos-b 'position-b)
  ;; Write contradiction sentinel at BOTH positions
  (define net2 (net-cell-write net1 tm-cid
                               (hasheq pos-a (hasheq ':type 'classify-inhabit-contradiction)
                                       pos-b (hasheq ':type 'classify-inhabit-contradiction))))
  ;; Distinct aid per position (simulating 2 separate forks)
  (define aid-a (assumption-id 0))
  (define aid-b (assumption-id 1))
  ;; Fire watcher for (pos-a, aid-a)
  (define watcher-a (make-branch-contradiction-watcher-fire-fn tm-cid pos-a aid-a))
  (define net3 (watcher-a net2))
  ;; Fire watcher for (pos-b, aid-b)
  (define watcher-b (make-branch-contradiction-watcher-fire-fn tm-cid pos-b aid-b))
  (define net4 (watcher-b net3))
  ;; cell-18: 2 distinct position entries; each with its own aid-set
  (define cell-18-val (net-cell-read net4 contradicted-branch-aids-cell-id))
  (check-equal? (hash-count cell-18-val) 2 "2 position entries in cell-18 (hash-union across positions)")
  (define pos-a-aids (hash-ref cell-18-val pos-a (seteq)))
  (define pos-b-aids (hash-ref cell-18-val pos-b (seteq)))
  (check-equal? (set-count pos-a-aids) 1 "pos-a has 1 aid")
  (check-equal? (set-count pos-b-aids) 1 "pos-b has 1 aid")
  (check-true (set-member? pos-a-aids aid-a) "aid-a tagged at pos-a")
  (check-true (set-member? pos-b-aids aid-b) "aid-b tagged at pos-b"))

;; ========================================
;; Unit: process-fork-contradiction — narrows worldview-cache atomically
;; ========================================

(test-case "process-fork-contradiction: narrows worldview-cache by bitwise-AND-with-NOT-mask"
  (define-values (net tm-cid _position) (make-test-fixture))
  ;; Seed worldview-cache with bits 1, 2, 4 (3 branch bits set)
  (define net1 (net-cell-write net worldview-cache-cell-id #b00000111))
  ;; Aid-set: aids for bit positions 0 and 2 (clear those bits)
  (define aid-0 (assumption-id 0))
  (define aid-2 (assumption-id 2))
  (define aid-set (seteq aid-0 aid-2))
  (define net2 (process-fork-contradiction net1 aid-set))
  (define wv-after (net-cell-read net2 worldview-cache-cell-id))
  ;; Expected: original 0b111 = 7; clear bits 0 and 2 → 0b010 = 2
  (check-equal? wv-after #b00000010
                "worldview-cache narrowed: 0b111 & ~0b101 = 0b010"))

;; ========================================
;; Unit: process-fork-contradiction — empty aid-set is no-op
;; ========================================

(test-case "process-fork-contradiction: empty aid-set returns net unchanged"
  (define-values (net tm-cid _position) (make-test-fixture))
  (define net1 (net-cell-write net worldview-cache-cell-id #b00000111))
  (define net2 (process-fork-contradiction net1 (seteq)))
  (check-equal? (net-cell-read net2 worldview-cache-cell-id) #b00000111
                "Empty aid-set → worldview-cache unchanged"))

;; ========================================
;; Unit: process-fork-contradiction — non-set input is defensive no-op
;; ========================================

(test-case "process-fork-contradiction: non-set input is defensive no-op"
  (define-values (net tm-cid _position) (make-test-fixture))
  (define net1 (net-cell-write net worldview-cache-cell-id #b00000111))
  (define net2 (process-fork-contradiction net1 'malformed))
  (check-equal? (net-cell-read net2 worldview-cache-cell-id) #b00000111
                "Non-set input → defensive no-op preserves worldview"))

;; ============================================================
;; PPN 4C Phase 3C.b.4 (2026-05-23): per-fork threshold-fire propagator
;; ============================================================
;; The threshold fire-fn (make-fork-chain-threshold-fire-fn) reads cell-18;
;; checks (subset? branch-aid-set position-aids); if held, calls wrapper +
;; writes cell-19 (chain storage). Defensive idempotence guard via cell-19
;; emit-once check (hash-has-key?).

;; ========================================
;; Unit: make-fork-chain-threshold-fire-fn — subset met → writes cell-19
;; ========================================

(test-case "make-fork-chain-threshold-fire-fn: subset met → chain written to cell-19"
  ;; Setup synthetic prop-network with a tm-cell that has tagged-cell-value
  ;; entries marking aid-0 + aid-1 as having contradicted (bit 0 + bit 1 set
  ;; in tm-cell's tagged-cell-value entries — so decode-aids-from-cell-value
  ;; in 3C.a primitive returns those aids during the wrapper's walk).
  (define net0 (make-prop-network))
  (define (tagged-aware-merge old new)
    (cond [(eq? old 'bot) new]
          [(tagged-cell-value? new) new]
          [else new]))
  (define-values (net1 cell-input) (net-new-cell net0 'bot tagged-aware-merge))
  (define-values (net2 tm-cell) (net-new-cell net1 'bot tagged-aware-merge))
  ;; Add a writer propagator (so static-reverse-walk finds at least 1 step)
  (define-values (net3 _writer-pid)
    (net-add-propagator net2 (list cell-input) (list tm-cell) (lambda (n) n)))
  ;; Write tagged-cell-value at tm-cell with bits 0+1 set (aid-0 + aid-1)
  (define net4 (net-cell-write net3 tm-cell
                               (tagged-cell-value 'base (list (cons #b011 'val)))))
  ;; Manually populate cell-18 with (hasheq position (seteq aid-0 aid-1)) —
  ;; simulating both branch contradiction watchers having fired.
  (define test-position 'test-pos)
  (define aid-0 (assumption-id 0))
  (define aid-1 (assumption-id 1))
  (define net5 (net-cell-write net4 contradicted-branch-aids-cell-id
                                (hasheq test-position (seteq aid-0 aid-1))))
  ;; Set up current-command-atms for assumption-name enrichment
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define atms-box (current-command-atms))
    (define-values (atms-1 _aid-a)
      (solver-state-assume (unbox atms-box) 'h0 "branch-0-at-pos"))
    (define-values (atms-2 _aid-b)
      (solver-state-assume atms-1 'h1 "branch-1-at-pos"))
    (set-box! atms-box atms-2)
    ;; Build threshold fire-fn for branch-aid-set = {aid-0, aid-1}
    (define branch-aid-set (seteq aid-0 aid-1))
    (define request-info (hasheq 'tm-cid tm-cell))
    (define threshold-fn
      (make-fork-chain-threshold-fire-fn test-position branch-aid-set request-info))
    ;; Invoke threshold body
    (define net6 (threshold-fn net5))
    ;; Verify cell-19 has chain entry for test-position
    (define cell-19-val (net-cell-read net6 union-derivation-chains-cell-id))
    (check-true (hash? cell-19-val) "cell-19 is a hash")
    (check-true (hash-has-key? cell-19-val test-position)
                "cell-19 has entry for test-position after threshold fires")
    (define chain (hash-ref cell-19-val test-position #f))
    (check-true (derivation-chain? chain)
                "cell-19's per-position entry is a derivation-chain struct")
    (define steps (derivation-chain-steps chain))
    (check-true (>= (length steps) 1)
                "chain has at least 1 step (writer propagator)")))

;; ========================================
;; Unit: make-fork-chain-threshold-fire-fn — subset NOT met → no-op
;; ========================================

(test-case "make-fork-chain-threshold-fire-fn: subset NOT met → cell-19 unchanged"
  ;; Setup: cell-18 has aid-0 ONLY; branch-aid-set requires aid-0 + aid-1.
  (define net0 (make-prop-network))
  (define test-position 'test-pos)
  (define aid-0 (assumption-id 0))
  (define aid-1 (assumption-id 1))
  ;; Only aid-0 has contradicted (partial)
  (define net1 (net-cell-write net0 contradicted-branch-aids-cell-id
                                (hasheq test-position (seteq aid-0))))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define branch-aid-set (seteq aid-0 aid-1))
    (define request-info (hasheq 'tm-cid 'dummy))  ;; tm-cid not consulted in this path
    (define threshold-fn
      (make-fork-chain-threshold-fire-fn test-position branch-aid-set request-info))
    (define net2 (threshold-fn net1))
    ;; cell-19 should remain empty (threshold not met)
    (define cell-19-val (net-cell-read net2 union-derivation-chains-cell-id))
    (check-equal? cell-19-val (hasheq)
                  "cell-19 remains empty hasheq when subset NOT met (partial contradiction)")))

;; ========================================
;; Unit: make-fork-chain-threshold-fire-fn — idempotence guard (already emitted)
;; ========================================

(test-case "make-fork-chain-threshold-fire-fn: defensive idempotence guard (already-emitted position)"
  ;; Setup: cell-18 has full subset; cell-19 already has entry for position.
  ;; Threshold should NOT overwrite (defensive guard).
  (define net0 (make-prop-network))
  (define test-position 'test-pos)
  (define aid-0 (assumption-id 0))
  (define net1 (net-cell-write net0 contradicted-branch-aids-cell-id
                                (hasheq test-position (seteq aid-0))))
  ;; Pre-populate cell-19 with a marker chain for test-position (simulating
  ;; previous emission for this position)
  (define marker-chain (derivation-chain '()))  ;; empty marker chain
  (define net2 (net-cell-write net1 union-derivation-chains-cell-id
                                (hasheq test-position marker-chain)))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define branch-aid-set (seteq aid-0))
    (define request-info (hasheq 'tm-cid 'dummy))
    (define threshold-fn
      (make-fork-chain-threshold-fire-fn test-position branch-aid-set request-info))
    (define net3 (threshold-fn net2))
    ;; cell-19's entry for test-position should STILL be the marker (unchanged)
    (define cell-19-val (net-cell-read net3 union-derivation-chains-cell-id))
    (check-equal? (hash-ref cell-19-val test-position #f) marker-chain
                  "cell-19 entry unchanged when position already emitted (idempotence guard)")))

;; ========================================
;; E2E: Int branch succeeds, String branch fails → only 1 bit remains
;; ========================================
;;
;; THE originally-failing scenario from the prior session's halted 3A.b
;; implementation (checkpoint at commit 18645783). Under Option E (lazy
;; `promote-cell-to-tagged` on attribute-map at fork-on-union entry), per-branch
;; isolation works correctly:
;;
;;   - Inhabitant: (expr-nat-val 3) — synthesizes to Nat
;;   - Components: Int (subtype-pass: Nat <: Int) + String (subtype-fail)
;;   - Expected outcome: Int branch's bit remains in worldview-cache;
;;     String branch's bit cleared by process-fork-contradiction handler.
;;
;; If Option E is missing (attribute-map not promoted): String's contradiction
;; sentinel merges into base attribute-map; both Int and String watchers see
;; it; BOTH bits cleared → 0 added bits (the bug). With Option E: tagged
;; entries at branch worldviews provide structural isolation; only String's
;; watcher detects contradiction → only String's bit cleared → 1 added bit.

(test-case "E2E: Int branch succeeds + String branch fails → 1 bit remaining in worldview"
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    ;; Step 1: write inhabitant (synthesizes to Nat — subtype of Int, NOT subtype of String)
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-nat-val 3)))
    ;; Step 2: STUB classifier-watcher writes fork-on-union request
    (define components (list (expr-Int) (expr-String)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                 (hasheq position request)))
    ;; Step 3: run to quiescence — handler allocates aids + promotes carrier +
    ;; installs branch propagators + installs contradiction watchers; BSP fires
    ;; everything in subsequent rounds; process-fork-contradiction narrows
    ;; worldview-cache between rounds.
    (define net3 (run-to-quiescence net2))
    ;; Step 4: verify outcome
    (define initial-wv (net-cell-read net worldview-cache-cell-id))
    (define final-wv (net-cell-read net3 worldview-cache-cell-id))
    (define added-bits (bitwise-and final-wv (bitwise-not initial-wv)))
    ;; EXPECTED: exactly 1 added bit (Int's branch survives; String's narrowed).
    ;; THE original failure: 0 added bits (both narrowed because attribute-map
    ;; wasn't tagged-cell-value-aware → contradiction collapsed across branches).
    (check-equal? (popcount added-bits) 1
                  "Option E: exactly 1 branch bit remains (Int succeeds; String contradicted+narrowed)")
    ;; cell-15 reset
    (check-equal? (net-cell-read net3 fork-on-union-request-cell-id) (hasheq)
                  "cell-15 reset after handler runs")
    ;; cell-16 reset (handler consumed aid-set + #:reset-value cleared)
    (check-equal? (net-cell-read net3 fork-contradiction-request-cell-id) (seteq)
                  "cell-16 reset after handler runs")))

;; ========================================
;; E2E: BOTH branches fail → all branch bits cleared
;; ========================================
;;
;; Verifies all-branch-contradict path (which Phase 3C will hook for error
;; explanation). Under Option E, when ALL branches contradict, ALL branch
;; bits clear from worldview-cache via process-fork-contradiction.

(test-case "E2E: both branches fail → all branch bits cleared (3C all-contradict signal)"
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    ;; Inhabitant: bool value (expr-true; type-of-expr returns expr-Bool — NOT subtype of Int OR String)
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-true)))
    (define components (list (expr-Int) (expr-String)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                 (hasheq position request)))
    (define net3 (run-to-quiescence net2))
    (define initial-wv (net-cell-read net worldview-cache-cell-id))
    (define final-wv (net-cell-read net3 worldview-cache-cell-id))
    (define added-bits (bitwise-and final-wv (bitwise-not initial-wv)))
    (check-equal? (popcount added-bits) 0
                  "Both branches fail → 0 added bits remain (all-contradict signal for 3C)")))

;; ========================================
;; E2E: both branches succeed → both bits remain (non-committing semantics)
;; ========================================
;;
;; Verifies OQ1 non-committing inhabitation semantics (per §9.3.1.3): when
;; multiple branches succeed, BOTH stay viable in worldview-cache. Narrowing
;; happens downstream via constraint propagation, not via check-time commit.

(test-case "E2E: both branches succeed → both bits remain (non-committing inhabitation)"
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    ;; Inhabitant: Nat value — subtype of Int AND of Nat (both branches compatible)
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-nat-val 5)))
    (define components (list (expr-Int) (expr-Nat)))  ;; Nat <: Int AND Nat <: Nat
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                 (hasheq position request)))
    (define net3 (run-to-quiescence net2))
    (define initial-wv (net-cell-read net worldview-cache-cell-id))
    (define final-wv (net-cell-read net3 worldview-cache-cell-id))
    (define added-bits (bitwise-and final-wv (bitwise-not initial-wv)))
    (check-equal? (popcount added-bits) 2
                  "Both branches succeed → 2 branch bits remain (non-committing per OQ1)")))

;; ========================================
;; Phase 3C.b — union-all-contradict-chain axes (PPN 4C 3C.b.5.c, 2026-05-23)
;; ========================================
;;
;; Per addendum §9.5.3.9 Q-C.b.5.2 revised lean (b) — PIVOT post-empirical
;; falsification: 4 structural axes verify the Propagator-First Diagnostics
;; mechanism (3C.b.2 watcher fan-out → cell-18 latch → 3C.b.4 threshold →
;; 3C.b.3 wrapper → cell-19 chain) end-to-end through the synthetic E2E
;; dispatch pattern.
;;
;; PIVOT RATIONALE (per §9.5.3.9.4 D-3C.b.5-6 + 3C.b.5.c-bugfix arc):
;;
;; Q-C.b.5.2 originally locked lean (a) — axes in test-elaboration-parity.rkt
;; via run-ns-with-net + sexp annotated `def : T := value` syntax. Empirical
;; probe at 3C.b.5.c initial attempt revealed that sexp annotated unions go
;; through the SEXP `check/err` path (typing-errors.rkt:64), NOT Phase 3A's
;; on-network mechanism. Phase 3A is VALIDATED via synthetic-network tests
;; but NOT DEPLOYED for user-facing sexp annotated unions until 3C.c bridges.
;;
;; Pivoted to lean (b) — synthetic E2E in test-union-types-atms.rkt using the
;; existing E2E pattern (lines 585-662): make-test-fixture + current-command-
;; atms parameterize + write-classify-inhabit + direct cell-15 write + run-
;; to-quiescence + cell-19 read. This exercises the FULL on-network dispatch
;; chain post-make-prop-network + handler-installation.
;;
;; The pivot ALSO surfaced a critical 3C.b.2 bugfix (committed separately at
;; bc47e0d6): the watcher fan-out's cell-18 write was hitting the undeclared-
;; writes bypass-merge path because cell-18 wasn't in the watcher's outputs
;; list — silent last-write-wins. Pre-bugfix, these 4 axes would have failed
;; (cell-18 only had ONE branch's aid). Post-bugfix, cell-18 correctly
;; accumulates all branch aids via the merge function.
;;
;; DISCRIMINATING POWER per Q-C.b.5.5:
;;   /int-bool-both-fail        → catches dispatch-chain wiring regressions
;;                                (handler install + watcher fan-out + threshold
;;                                install + wrapper invocation + assumption-
;;                                name decoding) — positive baseline
;;   /nat-string-both-fail      → discriminates against accidentally hardcoded
;;                                type dependencies (different component types)
;;   /int-string-int-succeeds   → catches spurious threshold fires (subset
;;                                check broken — over-fires when ANY branch
;;                                contradicts instead of ALL) — NEGATIVE
;;   /nat-int-both-succeed      → catches spurious fires when NO branches
;;                                contradict (defensive guard incorrectly
;;                                applied) — NEGATIVE
;;
;; SCOPE NOTE: T-C.b.4 unit tests above test the threshold fire-fn in
;; isolation (manually-populated cell-18). These E2E axes test the
;; COMPOSITION: watcher fan-out + cell-18 accumulation + threshold +
;; wrapper + cell-19. Distinct regression coverage:
;;   T-C.b.4 catches threshold-body bugs (subset check, guards)
;;   These 4 axes catch dispatch-chain wiring bugs (the 3C.b.5.c bugfix
;;   class — undeclared writes bypassing merge would be caught here)
;;
;; ASSUMPTION-NAME assertion per D-3C.b.5-4 mitigation: `string-contains?
;; name "branch"` substring match insulates against 3C.b.3 name-format
;; evolution (Phase 3A's `(format "branch-~a-at-~v" i position)` shape at
;; typing-propagators.rkt:1142-1144).

(test-case "union-all-contradict-chain/int-bool-both-fail: cell-19 populated"
  ;; Components Int + Bool; inhabitant expr-string ("hello") — fails BOTH
  ;; branches (string is neither Int subtype nor Bool subtype).
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-string "hello")))
    (define components (list (expr-Int) (expr-Bool)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                 (hasheq position request)))
    (define net3 (run-to-quiescence net2))
    (define cell-19-val (net-cell-read net3 union-derivation-chains-cell-id))
    (check-true (hash? cell-19-val) "cell-19 value is a hasheq")
    (check-true (hash-has-key? cell-19-val position)
                "cell-19 has chain entry for the union position")
    (define chain (hash-ref cell-19-val position #f))
    (check-true (derivation-chain? chain)
                "cell-19 entry is a derivation-chain struct (3C.a foundation)")
    (define steps (derivation-chain-steps chain))
    (check-true (>= (length steps) 1)
                "chain has ≥1 step (≥1 propagator writer in dep graph)")
    ;; D-3C.b.5-4: substring match insulates against name-format evolution
    (define names-flat
      (apply append (map derivation-step-assumption-names steps)))
    (check-true (ormap (lambda (n) (and (string? n) (string-contains? n "branch")))
                       names-flat)
                "some step's assumption-names references a 'branch' label (per 3C.b.3 enrichment)")))

(test-case "union-all-contradict-chain/nat-string-both-fail: cell-19 populated (component variety)"
  ;; Components Nat + String; inhabitant expr-true (Bool) — fails BOTH
  ;; branches (Bool is neither Nat nor String).
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-true)))
    (define components (list (expr-Nat) (expr-String)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                 (hasheq position request)))
    (define net3 (run-to-quiescence net2))
    (define cell-19-val (net-cell-read net3 union-derivation-chains-cell-id))
    (check-true (hash-has-key? cell-19-val position)
                "cell-19 has chain entry for Nat|String all-fail position")
    (define chain (hash-ref cell-19-val position #f))
    (check-true (derivation-chain? chain)
                "cell-19 entry is a derivation-chain struct")
    (check-true (>= (length (derivation-chain-steps chain)) 1)
                "chain has ≥1 step")))

(test-case "union-all-contradict-chain/int-string-int-succeeds: cell-19 empty (partial success)"
  ;; Components Int + String; inhabitant expr-nat-val 42 — Int succeeds
  ;; (Nat <: Int), String fails. NEGATIVE AXIS — subset predicate never holds.
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-nat-val 42)))
    (define components (list (expr-Int) (expr-String)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                 (hasheq position request)))
    (define net3 (run-to-quiescence net2))
    (define cell-19-val (net-cell-read net3 union-derivation-chains-cell-id))
    (check-false (hash-has-key? cell-19-val position)
                 "cell-19 has NO chain entry — Int succeeded, partial success, no all-contradict")))

(test-case "union-all-contradict-chain/nat-int-both-succeed: cell-19 empty (full success)"
  ;; Components Nat + Int; inhabitant expr-nat-val 0 — both branches succeed
  ;; (Nat <: Nat trivially; Nat <: Int via SRE Track 2H subtype lattice).
  ;; NEGATIVE AXIS — complement of "E2E: both branches succeed" test above.
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-nat-val 0)))
    (define components (list (expr-Nat) (expr-Int)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                 (hasheq position request)))
    (define net3 (run-to-quiescence net2))
    (define cell-19-val (net-cell-read net3 union-derivation-chains-cell-id))
    (check-false (hash-has-key? cell-19-val position)
                 "cell-19 has NO chain entry — both branches succeeded, no all-contradict")))
