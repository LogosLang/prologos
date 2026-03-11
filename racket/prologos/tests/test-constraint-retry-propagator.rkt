#lang racket/base

;;;
;;; Tests for P1-E3a: Constraint-Retry Propagators (Shadow Path)
;;;
;;; Verifies that constraint retry works via propagator cell state:
;;; - cell-ids are populated on constraints when the propagator network is active
;;; - retry-constraints-via-cells! detects solved metas and retries constraints
;;; - Transitive propagation via the network triggers constraint retry
;;; - Shadow mode: both propagator and legacy paths produce consistent results
;;;

(require rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../metavar-store.rkt"
         "../unify.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../elaborator-network.rkt"
         "../champ.rkt"
         "../propagator.rkt"
         "../type-lattice.rkt")

;; ========================================
;; Helper: with-prop-meta-env
;;
;; Like with-fresh-meta-env but initializes the propagator network,
;; so cell-ids get populated on constraints.
;; ========================================

(define-syntax-rule (with-prop-meta-env body ...)
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-sess-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-constraint-cell-id #f]  ;; Phase 1a: isolate from other tests
                 [current-wakeup-registry (make-hasheq)]
                 [current-trait-constraint-map (make-hasheq)]
                 [current-trait-wakeup-map (make-hasheq)]
                 [current-prop-meta-info-box (box champ-empty)]
                 [current-prop-net-box (box (make-elaboration-network))]
                 [current-prop-id-map-box (box champ-empty)]
                 [current-level-meta-champ-box (box champ-empty)]
                 [current-mult-meta-champ-box (box champ-empty)]
                 [current-sess-meta-champ-box (box champ-empty)])
    body ...))

;; ========================================
;; Unit tests: cell-ids populated on constraints
;; ========================================

(test-case "cell-ids/constraint-with-one-meta-has-cell-id"
  (with-prop-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    (define c (add-constraint! m (expr-Nat) ctx-empty "test"))
    ;; Constraint mentions 1 meta → should have 1 cell-id
    (check-not-false (constraint-cell-ids c))
    (check-equal? (length (constraint-cell-ids c)) 1)))

(test-case "cell-ids/constraint-with-two-metas-has-two-cell-ids"
  (with-prop-meta-env
    (define m1 (fresh-meta ctx-empty (expr-hole) "a"))
    (define m2 (fresh-meta ctx-empty (expr-hole) "b"))
    ;; Constraint: ?m1 vs ?m2
    (define c (add-constraint! m1 m2 ctx-empty "test"))
    (check-equal? (length (constraint-cell-ids c)) 2)))

(test-case "cell-ids/constraint-no-metas-has-empty-cell-ids"
  (with-prop-meta-env
    ;; Constraint with no metas (shouldn't normally happen, but defensive)
    (define c (add-constraint! (expr-Nat) (expr-Bool) ctx-empty "test"))
    (check-equal? (constraint-cell-ids c) '())))

(test-case "cell-ids/constraint-with-nested-meta-has-cell-id"
  (with-prop-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    ;; Nested: (Pi ?m Nat) vs (Pi Nat Nat)
    (define lhs (expr-Pi 'mw m (expr-Nat)))
    (define c (add-constraint! lhs (expr-Pi 'mw (expr-Nat) (expr-Nat)) ctx-empty "test"))
    (check-equal? (length (constraint-cell-ids c)) 1)))

(test-case "cell-ids/constraint-same-meta-both-sides-deduplicates"
  (with-prop-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    ;; Same meta on both sides
    (define c (add-constraint! m m ctx-empty "test"))
    ;; Should be deduplicated to 1 cell-id
    (check-equal? (length (constraint-cell-ids c)) 1)))

(test-case "cell-ids/without-network-stays-empty"
  ;; When propagator network is NOT initialized, cell-ids stay empty
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    (define c (add-constraint! m (expr-Nat) ctx-empty "test"))
    (check-equal? (constraint-cell-ids c) '())))

;; ========================================
;; Unit tests: retry-constraints-via-cells!
;; ========================================

(test-case "via-cells/retries-when-meta-solved"
  (with-prop-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      ;; Create applied-meta constraint: (app ?m zero) vs Nat — will postpone
      (define flex-term (expr-app m (expr-zero)))
      (define result (unify ctx-empty flex-term (expr-Nat)))
      (check-equal? result 'postponed)
      (check-equal? (length (all-postponed-constraints)) 1)
      ;; Check the constraint has cell-ids from the propagator network
      (define c (car (current-constraint-store)))
      (check-true (> (length (constraint-cell-ids c)) 0)
                  "constraint should have cell-ids with network active")
      ;; Write solution to cell (simulate what solve-meta! does)
      (define cid (car (constraint-cell-ids c)))
      (define solution (expr-lam 'mw (expr-hole) (expr-Nat)))
      (set-box! (current-prop-net-box)
                (elab-cell-write (unbox (current-prop-net-box)) cid solution))
      ;; Now retry via cells — should find the cell is non-bot and retry
      (retry-constraints-via-cells!)
      ;; The constraint should now be solved (Nat = Nat)
      (check-equal? (constraint-status c) 'solved))))

(test-case "via-cells/skips-when-no-cells-solved"
  (with-prop-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    ;; Add a constraint — meta is unsolved, cell is still bot
    (define c (add-constraint! m (expr-Nat) ctx-empty "test"))
    (check-equal? (constraint-status c) 'postponed)
    ;; Retry via cells — no cell is non-bot, should skip
    (retry-constraints-via-cells!)
    (check-equal? (constraint-status c) 'postponed
                  "constraint should still be postponed")))

(test-case "via-cells/skips-already-solved-constraints"
  (with-prop-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      ;; Create and postpone
      (define flex-term (expr-app m (expr-zero)))
      (unify ctx-empty flex-term (expr-Nat))
      (define c (car (current-constraint-store)))
      ;; Manually mark as solved
      (set-constraint-status! c 'solved)
      ;; Write to cell
      (define cid (car (constraint-cell-ids c)))
      (set-box! (current-prop-net-box)
                (elab-cell-write (unbox (current-prop-net-box)) cid (expr-Nat)))
      ;; Retry should skip — constraint is already solved
      (retry-constraints-via-cells!)
      (check-equal? (constraint-status c) 'solved))))

(test-case "via-cells/skips-constraints-without-cell-ids"
  (with-prop-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    (define c (add-constraint! m (expr-Nat) ctx-empty "test"))
    ;; Clear cell-ids to simulate legacy constraint
    (set-constraint-cell-ids! c '())
    ;; Retry via cells should skip this constraint
    (retry-constraints-via-cells!)
    (check-equal? (constraint-status c) 'postponed)))

;; ========================================
;; Integration tests: solve-meta! triggers both paths
;; ========================================

(test-case "integration/solve-meta-retries-via-both-paths"
  (with-prop-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      ;; Create applied-meta constraint that will postpone
      (define flex-term (expr-app m (expr-zero)))
      (define result (unify ctx-empty flex-term (expr-Nat)))
      (check-equal? result 'postponed)
      (check-equal? (length (all-postponed-constraints)) 1)
      ;; Solve the meta — should trigger both legacy and cell-based retry
      (solve-meta! mid (expr-lam 'mw (expr-hole) (expr-Nat)))
      ;; Constraint should be solved regardless of which path resolved it
      (check-equal? (length (all-postponed-constraints)) 0)
      (check-equal? (length (all-failed-constraints)) 0))))

(test-case "integration/solve-meta-fails-constraint-via-both-paths"
  (with-prop-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      ;; (app ?m zero) vs Bool
      (define flex-term (expr-app m (expr-zero)))
      (define result (unify ctx-empty flex-term (expr-Bool)))
      (check-equal? result 'postponed)
      ;; Solve ?m to (fn [x] Nat) — retry yields Nat ≠ Bool → failed
      (solve-meta! mid (expr-lam 'mw (expr-hole) (expr-Nat)))
      (check-equal? (length (all-postponed-constraints)) 0)
      (check-equal? (length (all-failed-constraints)) 1))))

(test-case "integration/multiple-constraints-different-metas"
  (with-prop-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "a"))
      (define m2 (fresh-meta ctx-empty (expr-Type (lzero)) "b"))
      (define mid1 (expr-meta-id m1))
      (define mid2 (expr-meta-id m2))
      ;; Two constraints: (app ?m1 zero) vs Nat, (app ?m2 zero) vs Bool
      (define flex1 (expr-app m1 (expr-zero)))
      (define flex2 (expr-app m2 (expr-zero)))
      (unify ctx-empty flex1 (expr-Nat))
      (unify ctx-empty flex2 (expr-Bool))
      (check-equal? (length (all-postponed-constraints)) 2)
      ;; Solve only m1 — only its constraint should resolve
      (solve-meta! mid1 (expr-lam 'mw (expr-hole) (expr-Nat)))
      (check-equal? (length (all-postponed-constraints)) 1)
      ;; Solve m2 — second constraint resolves
      (solve-meta! mid2 (expr-lam 'mw (expr-hole) (expr-Bool)))
      (check-equal? (length (all-postponed-constraints)) 0)
      (check-equal? (length (all-failed-constraints)) 0))))

(test-case "integration/constraint-postponed-again-on-partial-solve"
  (with-prop-meta-env
    (parameterize ([current-global-env (hasheq)]
                   [current-retry-unify #f])  ;; disable retry to manually control
      (define m1 (fresh-meta ctx-empty (expr-hole) "a"))
      (define m2 (fresh-meta ctx-empty (expr-hole) "b"))
      ;; Constraint: ?m1 vs ?m2 — both unsolved
      (define c (add-constraint! m1 m2 ctx-empty "test"))
      (check-equal? (constraint-status c) 'postponed)
      (check-equal? (length (constraint-cell-ids c)) 2)
      ;; Both cells are bot → retry-via-cells should skip
      (retry-constraints-via-cells!)
      (check-equal? (constraint-status c) 'postponed))))

;; ========================================
;; Cell-id consistency tests
;; ========================================

(test-case "cell-ids/consistent-with-prop-meta-id-map"
  (with-prop-meta-env
    (define m1 (fresh-meta ctx-empty (expr-hole) "a"))
    (define m2 (fresh-meta ctx-empty (expr-hole) "b"))
    (define c (add-constraint! m1 m2 ctx-empty "test"))
    ;; Verify cell-ids match what the id-map has
    (define id-map (unbox (current-prop-id-map-box)))
    (define cid1 (champ-lookup id-map (prop-meta-id-hash (expr-meta-id m1)) (expr-meta-id m1)))
    (define cid2 (champ-lookup id-map (prop-meta-id-hash (expr-meta-id m2)) (expr-meta-id m2)))
    (check-not-equal? cid1 'none)
    (check-not-equal? cid2 'none)
    (check-not-false (member cid1 (constraint-cell-ids c))
                     "cell-id for m1 should be in constraint's cell-ids")
    (check-not-false (member cid2 (constraint-cell-ids c))
                     "cell-id for m2 should be in constraint's cell-ids")))

(test-case "cell-ids/cell-reads-reflect-meta-solutions"
  (with-prop-meta-env
    (parameterize ([current-global-env (hasheq)]
                   [current-retry-unify #f])  ;; manual control
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      (define c (add-constraint! m (expr-Nat) ctx-empty "test"))
      (check-equal? (length (constraint-cell-ids c)) 1)
      (define cid (car (constraint-cell-ids c)))
      ;; Cell should be bot initially
      (define enet (unbox (current-prop-net-box)))
      (check-true (type-bot? (elab-cell-read enet cid)))
      ;; Solve the meta
      (solve-meta! mid (expr-Nat))
      ;; Cell should now have the solution
      (define enet* (unbox (current-prop-net-box)))
      (check-false (type-bot? (elab-cell-read enet* cid))))))
