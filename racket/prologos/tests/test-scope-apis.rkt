#lang racket/base

;;;
;;; test-scope-apis.rkt — Phase 5 Day 12 (2026-05-02)
;;;
;;; Tests the Racket-side scope-cycle API
;;; (scope-enter / scope-run / scope-read / scope-exit) — the mirror of
;;; the kernel scope APIs from
;;; docs/tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md § 5.9.
;;;
;;; Day 12 GATE: NAF isolation gate — a divergent inner-goal scope
;;; returns 'fuel-exhausted while parent fuel stays intact except
;;; for the parent_fuel_charge debit.
;;;

(require rackunit
         "../propagator.rkt")

;; ========================================
;; 1. Basic scope cycle: enter → run → read → exit
;; ========================================

(test-case "scope-enter: charges parent_fuel_charge against parent"
  (define parent (make-prop-network 1000000))
  (define-values (scope parent*)
    (scope-enter parent #:parent-fuel-charge 10))
  ;; Parent debited 10
  (check-equal? (net-fuel-remaining parent*) (- 1000000 10))
  ;; Parent unchanged (immutable)
  (check-equal? (net-fuel-remaining parent) 1000000)
  ;; Scope is a fresh fork (full default fuel from fork-prop-network)
  (check-equal? (net-fuel-remaining scope) 1000000)
  (scope-exit scope))

(test-case "scope-enter: default parent_fuel_charge is 10"
  (define parent (make-prop-network 1000000))
  (define-values (scope parent*) (scope-enter parent))
  (check-equal? (net-fuel-remaining parent*) (- 1000000 (scope-parent-fuel-charge)))
  (scope-exit scope))

(test-case "scope-enter: parent_fuel_charge=0 leaves parent untouched"
  (define parent (make-prop-network 1000000))
  (define-values (scope parent*)
    (scope-enter parent #:parent-fuel-charge 0))
  (check-equal? (net-fuel-remaining parent*) 1000000)
  (scope-exit scope))

(test-case "scope-enter: parent fuel never goes below 0"
  ;; Parent has 5 fuel; charge 10 → clamps to 0, doesn't underflow.
  (define parent (make-prop-network 5))
  (define-values (scope parent*)
    (scope-enter parent #:parent-fuel-charge 10))
  (check-equal? (net-fuel-remaining parent*) 0)
  (scope-exit scope))

;; ========================================
;; 2. scope-run RunResult dispatch
;; ========================================

(test-case "scope-run: 'halt on quiescence (empty worklist)"
  (define parent (make-prop-network))
  (define-values (scope _p*) (scope-enter parent))
  (define-values (scope* result) (scope-run scope 1000))
  (check-eq? result 'halt)
  (scope-exit scope))

(test-case "scope-run: 'fuel-exhausted on divergence"
  ;; Build a network with a self-perpetuating worklist: two cells whose
  ;; fire-fns volley monotonically increasing writes back and forth.
  ;; Each fire produces a strictly greater value (max-merge), so the
  ;; cell changes and the dependents enqueue forever.
  (define parent (make-prop-network 1000000))
  (define-values (parent1 c1) (net-new-cell parent 0 max))
  (define-values (parent2 c2) (net-new-cell parent1 0 max))
  (define p1-fire
    (lambda (n) (net-cell-write n c2 (+ (net-cell-read n c1) 1))))
  (define p2-fire
    (lambda (n) (net-cell-write n c1 (+ (net-cell-read n c2) 1))))
  (define-values (parent3 _pid1)
    (net-add-propagator parent2 (list c1) (list c2) p1-fire))
  (define-values (parent4 _pid2)
    (net-add-propagator parent3 (list c2) (list c1) p2-fire))
  (define-values (scope _p*) (scope-enter parent4))
  ;; Seed INSIDE the scope (post-fork). fork-prop-network resets the
  ;; parent's worklist so the seed must happen on the scope itself.
  (define seeded (net-cell-write scope c1 1))
  ;; Run scope with small fuel — must exhaust before quiescence
  ;; (each fire consumes 1 fuel; 100 fuel → ~100 fires; volley diverges).
  (define-values (scope* result) (scope-run seeded 100))
  (check-eq? result 'fuel-exhausted)
  (scope-exit scope*))

;; ========================================
;; 3. scope-read after scope-run
;; ========================================

(test-case "scope-read: reads cell value from scope's HAMT"
  (define parent (make-prop-network))
  ;; LWW merge so we can write any value (incl. symbols).
  (define lww (lambda (_old new) new))
  (define-values (parent1 c1) (net-new-cell parent 'init lww))
  (define-values (scope _p*) (scope-enter parent1))
  (define scope-w (net-cell-write scope c1 42))
  (define-values (scope-r _result) (scope-run scope-w 1000))
  (check-equal? (scope-read scope-r c1) 42)
  ;; Parent's c1 is unaffected — scope writes were CoW-isolated.
  (check-equal? (net-cell-read parent1 c1) 'init)
  (scope-exit scope-r))

;; ========================================
;; 4. NAF ISOLATION GATE (Day 12 deliverable)
;; ========================================
;;
;; The canonical Day 12 acceptance gate: a scope holding a divergent
;; computation must return 'fuel-exhausted; parent's fuel must remain
;; intact EXCEPT for the parent_fuel_charge (10 by default).
;;
;; This is the kernel-equivalent of "an inner NAF goal that diverges
;; doesn't deplete the parent BSP's fuel budget" — the property that
;; makes per-PU isolation real.

(test-case "DAY 12 GATE: divergent inner scope leaves parent fuel intact"
  (define PARENT-FUEL 1000000)
  (define SCOPE-FUEL 100)
  (define parent (make-prop-network PARENT-FUEL))
  ;; Build a divergent network on the parent.
  (define-values (parent1 c1) (net-new-cell parent 0 max))
  (define-values (parent2 c2) (net-new-cell parent1 0 max))
  (define p1-fire
    (lambda (n)
      (define v (net-cell-read n c1))
      (net-cell-write n c2 (+ v 1))))
  (define p2-fire
    (lambda (n)
      (define v (net-cell-read n c2))
      (net-cell-write n c1 (+ v 1))))
  (define-values (parent3 _pid1)
    (net-add-propagator parent2 (list c1) (list c2) p1-fire))
  (define-values (parent4 _pid2)
    (net-add-propagator parent3 (list c2) (list c1) p2-fire))
  ;; DON'T seed the parent — we want to leave the parent's fuel
  ;; entirely intact. The scope inherits the topology via fork and
  ;; we seed inside the scope.
  (define-values (scope parent*) (scope-enter parent4))
  ;; Confirm parent's fuel only lost parent_fuel_charge.
  (check-equal? (net-fuel-remaining parent*)
                (- PARENT-FUEL (scope-parent-fuel-charge))
                "parent fuel debited only by parent_fuel_charge")
  ;; Seed divergence inside the scope.
  (define seeded (net-cell-write scope c1 1))
  (define-values (scope-after result) (scope-run seeded SCOPE-FUEL))
  ;; Inner goal diverged → fuel-exhausted (NOT halt, NOT trap).
  (check-eq? result 'fuel-exhausted
             "divergent inner-goal scope returns fuel-exhausted")
  ;; Scope ran out of fuel.
  (check-equal? (scope-fuel-remaining scope-after) 0)
  ;; Parent fuel UNTOUCHED by the divergent scope — only the
  ;; parent_fuel_charge applied at scope-enter.
  (check-equal? (net-fuel-remaining parent*)
                (- PARENT-FUEL (scope-parent-fuel-charge))
                "parent fuel intact except for parent_fuel_charge")
  (scope-exit scope-after))

(test-case "DAY 12 GATE: parent stays usable after divergent scope"
  ;; After a divergent scope exits, the parent must still be able to
  ;; run propagators normally (not contaminated by scope's worklist /
  ;; contradiction state).
  (define parent (make-prop-network 1000000))
  (define-values (parent1 c-p) (net-new-cell parent 0 max))
  (define-values (scope parent*) (scope-enter parent1))
  ;; Make scope diverge.
  (define-values (parent2 c-s) (net-new-cell scope 0 max))
  (define-values (parent3 c-s2) (net-new-cell parent2 0 max))
  (define-values (scope-with-prop _p)
    (net-add-propagator parent3
                        (list c-s) (list c-s2)
                        (lambda (n)
                          (net-cell-write n c-s2
                                          (+ (net-cell-read n c-s) 1)))))
  (define-values (scope-with-prop2 _p2)
    (net-add-propagator scope-with-prop
                        (list c-s2) (list c-s)
                        (lambda (n)
                          (net-cell-write n c-s
                                          (+ (net-cell-read n c-s2) 1)))))
  (define seeded (net-cell-write scope-with-prop2 c-s 1))
  (define-values (_scope-after result) (scope-run seeded 50))
  (check-eq? result 'fuel-exhausted)
  (scope-exit _scope-after)
  ;; Parent must still be runnable.
  (define parent-with-write (net-cell-write parent* c-p 99))
  (define parent-quiesced (run-to-quiescence parent-with-write))
  (check-equal? (net-cell-read parent-quiesced c-p) 99
                "parent network usable after divergent scope")
  (check-false (net-contradiction? parent-quiesced)
               "parent network not contaminated by scope's state"))

;; ========================================
;; 5. Nested scopes (LIFO discipline check)
;; ========================================

(test-case "nested scopes: each level has its own fuel budget"
  (define grandparent (make-prop-network 1000000))
  (define-values (parent _g*) (scope-enter grandparent))
  (define-values (child _p*) (scope-enter parent))
  ;; All three networks have independent fuel.
  (check-equal? (net-fuel-remaining grandparent) 1000000)
  (check-equal? (net-fuel-remaining parent) 1000000)  ;; fork resets fuel
  (check-equal? (net-fuel-remaining child) 1000000)
  (scope-exit child)
  (scope-exit parent))

;; ========================================
;; 6. Round-trip: scope writes don't leak to parent
;; ========================================

(test-case "scope writes are CoW-isolated from parent"
  (define parent (make-prop-network))
  (define lww (lambda (_old new) new))
  (define-values (parent1 c1) (net-new-cell parent 'parent-init lww))
  (define-values (scope _p*) (scope-enter parent1))
  ;; Write in scope.
  (define scope-w (net-cell-write scope c1 'scope-write))
  ;; Parent's c1 still 'parent-init.
  (check-equal? (net-cell-read parent1 c1) 'parent-init)
  ;; Scope's c1 is the merged value.
  (check-equal? (scope-read scope-w c1) 'scope-write)
  (scope-exit scope-w))
