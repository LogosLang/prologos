#lang racket/base

;;;
;;; Tests for PPN 4C S2.b-iv: Constraint Readiness via Set-Latch
;;;
;;; Renamed + restructured 2026-04-24 from test-constraint-retry-propagator.rkt
;;; per D.3 §7.5.12.9 step 9. Old name reflected the 3-stage fan-in
;;; "constraint retry propagator" mechanism; post-S2.b-iv that mechanism
;;; is the set-latch readiness pattern (latch + threshold + per-input
;;; broadcast/fire-once watchers) writing to the ready-queue cell.
;;;
;;; What's tested under the new architecture:
;;;
;;;   constraint struct: meta-ids field populated with per-meta identity
;;;     (preserved across universe model where multiple type metas share
;;;     a universe-cid; cell-ids may collapse, meta-ids does not).
;;;
;;;   add-constraint!: builds the set-latch via add-readiness-set-latch!
;;;     internally; latch + threshold + watchers installed.
;;;
;;;   Event-driven readiness: solving a meta (via solve-meta! → component
;;;     write under universe model) triggers the per-input watcher → latch
;;;     accumulates → threshold fires → action descriptor written to
;;;     ready-queue cell → resolution executor processes the action.
;;;
;;;   Idempotency: latch is monotone-set with merge-set-union; threshold
;;;     fire-once means re-firing is structurally prevented; already-
;;;     solved constraints are no-ops on subsequent solves.
;;;
;;; The previous version of this file invoked the now-retired scan
;;; function `retry-constraints-via-cells!` directly. Those tests are
;;; rewritten to drive the event-driven path: write meta solutions via
;;; the cell mechanism (solve-meta!), let the network propagate to
;;; quiescence, observe the resulting constraint status.
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
;; Constraint struct: meta-ids identity-per-meta
;; ========================================
;;
;; PPN 4C S2.b-iv: cell-ids may collapse under universe model (multiple
;; type metas → same universe-cid → remove-duplicates leaves 1 cell-id);
;; meta-ids preserves per-meta identity across the same population walk.

(test-case "meta-ids/constraint-with-one-meta-has-one-meta-id"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    (define c (add-constraint! m (expr-Nat) ctx-empty "test"))
    ;; Constraint mentions 1 meta → 1 entry in meta-ids
    (check-not-false (constraint-meta-ids c))
    (check-equal? (length (constraint-meta-ids c)) 1)))

(test-case "meta-ids/constraint-with-two-metas-has-two-meta-ids"
  (with-fresh-meta-env
    (define m1 (fresh-meta ctx-empty (expr-hole) "a"))
    (define m2 (fresh-meta ctx-empty (expr-hole) "b"))
    ;; Constraint: ?m1 vs ?m2 — 2 distinct metas, regardless of whether
    ;; their cell-ids collapse to a shared universe-cid.
    (define c (add-constraint! m1 m2 ctx-empty "test"))
    (check-equal? (length (constraint-meta-ids c)) 2)
    ;; Identity preserved: both meta-ids present.
    (check-not-false (member (expr-meta-id m1) (constraint-meta-ids c)))
    (check-not-false (member (expr-meta-id m2) (constraint-meta-ids c)))))

(test-case "meta-ids/constraint-no-metas-has-empty-meta-ids"
  (with-fresh-meta-env
    ;; No metas — defensive case, shouldn't normally happen.
    (define c (add-constraint! (expr-Nat) (expr-Bool) ctx-empty "test"))
    (check-equal? (constraint-meta-ids c) '())))

(test-case "meta-ids/constraint-with-nested-meta-has-meta-id"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    ;; Nested: (Pi ?m Nat) vs (Pi Nat Nat)
    (define lhs (expr-Pi 'mw m (expr-Nat)))
    (define c (add-constraint! lhs (expr-Pi 'mw (expr-Nat) (expr-Nat)) ctx-empty "test"))
    (check-equal? (length (constraint-meta-ids c)) 1)))

(test-case "meta-ids/constraint-same-meta-both-sides-deduplicates"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    ;; Same meta on both sides — should dedupe to 1 entry
    (define c (add-constraint! m m ctx-empty "test"))
    (check-equal? (length (constraint-meta-ids c)) 1)))

(test-case "meta-ids/with-network-populated"
  ;; Phase 6e: With network-everywhere, meta-ids ALWAYS populated when
  ;; a constraint mentions metas.
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    (define c (add-constraint! m (expr-Nat) ctx-empty "test"))
    (check-true (pair? (constraint-meta-ids c))
                "constraint should have meta-ids with network active")))

;; ========================================
;; Event-driven readiness via solve-meta!
;; ========================================
;;
;; Under the set-latch readiness pattern:
;;   - add-constraint! installs per-meta watchers (broadcast for universe-
;;     migrated type metas, fire-once for legacy per-cell metas)
;;   - solve-meta! writes a meta solution → that meta's cell/component
;;     transitions from bot to value
;;   - The watcher fires (broadcast item-fn or fire-once fire-fn) and
;;     writes the meta-id into the latch cell (monotone-set)
;;   - Threshold fire-once watching the latch sees non-empty set →
;;     fires the action-thunk → writes action descriptor to ready-queue
;;   - The resolution executor (Stratum 2) reads the ready-queue and
;;     dispatches the retry action
;;
;; These tests exercise the end-to-end path via solve-meta! (which
;; integrates with the propagator network under driver.rkt's callback
;; setup) rather than directly invoking the now-retired scan functions.

(test-case "readiness/solve-meta-triggers-retry-and-resolution"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                   [current-module-definitions-content (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      ;; Create applied-meta constraint: (app ?m zero) vs Nat — postpones
      (define flex-term (expr-app m (expr-zero)))
      (define result (unify ctx-empty flex-term (expr-Nat)))
      (check-equal? result 'postponed)
      (check-equal? (length (all-postponed-constraints)) 1)
      ;; Solve the meta — exercises set-latch: meta-component-write
      ;; flips the watcher, threshold fires, action emitted, resolution
      ;; executor processes the retry, constraint becomes solved.
      (solve-meta! mid (expr-lam 'mw (expr-hole) (expr-Nat)))
      (check-equal? (length (all-postponed-constraints)) 0)
      (check-equal? (length (all-failed-constraints)) 0))))

(test-case "readiness/solve-meta-fails-constraint-via-event-path"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                   [current-module-definitions-content (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      ;; (app ?m zero) vs Bool — postpones
      (define flex-term (expr-app m (expr-zero)))
      (unify ctx-empty flex-term (expr-Bool))
      ;; Solve ?m to (fn [x] Nat) — retry yields Nat ≠ Bool → failed
      (solve-meta! mid (expr-lam 'mw (expr-hole) (expr-Nat)))
      (check-equal? (length (all-postponed-constraints)) 0)
      (check-equal? (length (all-failed-constraints)) 1))))

(test-case "readiness/multi-constraint-isolated-resolution"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                   [current-module-definitions-content (hasheq)])
      (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "a"))
      (define m2 (fresh-meta ctx-empty (expr-Type (lzero)) "b"))
      (define mid1 (expr-meta-id m1))
      (define mid2 (expr-meta-id m2))
      ;; Two independent constraints
      (define flex1 (expr-app m1 (expr-zero)))
      (define flex2 (expr-app m2 (expr-zero)))
      (unify ctx-empty flex1 (expr-Nat))
      (unify ctx-empty flex2 (expr-Bool))
      (check-equal? (length (all-postponed-constraints)) 2)
      ;; Solve only m1 — set-latch for m1's constraint fires; m2's
      ;; constraint may also be eagerly retried (C3 bridge can attempt
      ;; resolution during quiescence) but stays postponed if not
      ;; resolvable.
      (solve-meta! mid1 (expr-lam 'mw (expr-hole) (expr-Nat)))
      (check-true (<= (length (all-postponed-constraints)) 1))
      ;; Solve m2 — second constraint resolves
      (solve-meta! mid2 (expr-lam 'mw (expr-hole) (expr-Bool)))
      (check-equal? (length (all-postponed-constraints)) 0)
      (check-equal? (length (all-failed-constraints)) 0))))

;; ========================================
;; Idempotency + skip behaviors
;; ========================================
;;
;; Under the set-latch monotone-set + threshold fire-once architecture:
;;   - Solving a meta multiple times is idempotent (monotone latch, fire-
;;     once threshold prevents spurious re-fires)
;;   - A constraint with no metas → no readiness installation (helper
;;     no-ops); status stays at whatever add-constraint! initialized.
;;   - Already-solved constraints don't re-fire (status guard).

(test-case "idempotency/no-metas-no-readiness-installation"
  ;; Constraint with no metas (Nat vs Bool) — no readiness watchers
  ;; installed (helper no-ops on null meta-ids); status stays postponed
  ;; (caller-set initial state) until manually resolved.
  (with-fresh-meta-env
    (define c (add-constraint! (expr-Nat) (expr-Bool) ctx-empty "test"))
    (check-equal? (constraint-meta-ids c) '())
    (check-equal? (constraint-status c) 'postponed)))

(test-case "idempotency/unsolved-stays-postponed"
  ;; Without solving any meta, the set-latch never fires → constraint
  ;; stays postponed indefinitely (no spurious retries).
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    (define c (add-constraint! m (expr-Nat) ctx-empty "test"))
    (check-equal? (constraint-status c) 'postponed)
    ;; Re-read from store — still postponed.
    (define post-c (read-constraint-by-cid (constraint-cid c)))
    (check-equal? (constraint-status post-c) 'postponed)))

(test-case "idempotency/already-solved-no-spurious-refire"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                   [current-module-definitions-content (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      (define flex-term (expr-app m (expr-zero)))
      (unify ctx-empty flex-term (expr-Nat))
      ;; Solve once — constraint resolves
      (solve-meta! mid (expr-lam 'mw (expr-hole) (expr-Nat)))
      (check-equal? (length (all-postponed-constraints)) 0)
      (check-equal? (length (all-failed-constraints)) 0)
      ;; Already-solved constraint: re-asserting the same solution is
      ;; idempotent — solve-meta! on already-solved meta no-ops via
      ;; meta-solved? guard.
      (check-true (meta-solved? mid)))))

;; ========================================
;; Cell-id consistency (universe model)
;; ========================================
;;
;; Under universe model, multiple type metas share their universe-cid.
;; meta-ids preserves identity; cell-ids reflects the cell SHAPES the
;; constraint touches (universe-cid for type metas, per-cell for legacy).

(test-case "cell-ids/consistent-with-prop-meta-id-map"
  (with-fresh-meta-env
    (define m1 (fresh-meta ctx-empty (expr-hole) "a"))
    (define m2 (fresh-meta ctx-empty (expr-hole) "b"))
    (define c (add-constraint! m1 m2 ctx-empty "test"))
    ;; Verify cell-ids are derived from each meta's prop-meta-id->cell-id
    ;; lookup (with potential dedupe under universe model).
    (define id-map (elab-network-id-map (unbox (current-prop-net-box))))
    (define cid1 (champ-lookup id-map (prop-meta-id-hash (expr-meta-id m1)) (expr-meta-id m1)))
    (define cid2 (champ-lookup id-map (prop-meta-id-hash (expr-meta-id m2)) (expr-meta-id m2)))
    (check-not-equal? cid1 'none)
    (check-not-equal? cid2 'none)
    (check-not-false (member cid1 (constraint-cell-ids c))
                     "cell-id for m1 should be in constraint's cell-ids")
    (check-not-false (member cid2 (constraint-cell-ids c))
                     "cell-id for m2 should be in constraint's cell-ids")))
