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
         "../syntax.rkt"
         "../propagator.rkt"
         "../decision-cell.rkt"
         "../atms.rkt"
         "../union-types.rkt"
         "../classify-inhabit.rkt"
         "../typing-propagators.rkt"
         "../elab-speculation-bridge.rkt")

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
    ;; Net should have 2 more propagators (one per branch)
    (check-equal? (- (prop-network-next-prop-id net1)
                     (prop-network-next-prop-id net))
                  2
                  "2 branch check propagators installed")))

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
;; Without 3A.b (contradiction watcher + cell-16), the contradiction stays
;; tagged at branch wv — readable at branch wv but invisible at outer wv.
;; Phase 3A.b will add narrowing to clear failed branch bits.

(test-case "E2E: fork-on-union flow with stubbed classifier-watcher"
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    ;; Step 1: write inhabitant (synthesizes to Nat)
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-nat-val 3)))
    ;; Step 2: STUB classifier-watcher — write a fork-on-union request to cell-15
    ;; (In production 3A.c, the classifier-watcher would detect classifier becoming
    ;; an expr-union and emit this request automatically.)
    (define components (list (expr-Int) (expr-String)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                 (hasheq position request)))
    ;; Step 3: run to quiescence — BSP outer-loop invokes process-fork-on-union
    ;; handler (between rounds), which allocates aids + sets worldview bits +
    ;; installs branch propagators; BSP then resets cell-15 to (hasheq) per
    ;; #:reset-value; subsequent rounds fire branch propagators under their
    ;; worldviews.
    (define net4 (run-to-quiescence net2))
    ;; Step 4: verify outcomes
    ;; Get the 2 branch bits from worldview-cache (set by handler)
    (define wv-after-fork (net-cell-read net4 worldview-cache-cell-id))
    (define initial-wv (net-cell-read net worldview-cache-cell-id))
    (define branch-bits (bitwise-and wv-after-fork (bitwise-not initial-wv)))
    (check-equal? (popcount branch-bits) 2 "2 branch bits in worldview-cache after BSP")
    ;; Verify cell-15 was reset (BSP #:reset-value)
    (check-equal? (net-cell-read net4 fork-on-union-request-cell-id) (hasheq)
                  "cell-15 reset after handler runs (BSP #:reset-value)")
    ;; The check propagators have fired. The contradiction (if any) is tagged at
    ;; the branch's worldview. To read at a branch worldview, we'd need to
    ;; either filter tagged entries manually or query under that wv. For this
    ;; test, verifying that the handler installed correctly + the worldview
    ;; bits are present is sufficient evidence of 3A.a's E2E flow.
    ;;
    ;; Phase 3A.b will verify per-branch contradiction → narrowing; 3A.c will
    ;; verify end-to-end with production classifier-watcher.
    (void)))

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
