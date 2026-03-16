#lang racket/base

;;;
;;; test-module-network-01.rkt — Track 5 Phase 1 unit tests
;;;
;;; Tests:
;;;   1. Module lifecycle lattice (merge-mod-status)
;;;   2. module-network-ref struct and operations
;;;   3. Shadow-cell cross-network prototype
;;;

(require rackunit
         "../propagator.rkt"
         "../infra-cell.rkt"
         "../namespace.rkt")

;; ========================================
;; 1. Module Lifecycle Lattice
;; ========================================

(test-case "merge-mod-status: bot + loading = loading"
  (check-equal? (merge-mod-status 'infra-bot mod-loading) mod-loading))

(test-case "merge-mod-status: bot + loaded = loaded"
  (check-equal? (merge-mod-status 'infra-bot mod-loaded) mod-loaded))

(test-case "merge-mod-status: bot + stale = stale"
  (check-equal? (merge-mod-status 'infra-bot mod-stale) mod-stale))

(test-case "merge-mod-status: loading + loaded = loaded"
  (check-equal? (merge-mod-status mod-loading mod-loaded) mod-loaded))

(test-case "merge-mod-status: loaded + loading = loaded (monotone)"
  (check-equal? (merge-mod-status mod-loaded mod-loading) mod-loaded))

(test-case "merge-mod-status: loaded + stale = stale"
  (check-equal? (merge-mod-status mod-loaded mod-stale) mod-stale))

(test-case "merge-mod-status: stale + loaded = stale (stale dominates)"
  (check-equal? (merge-mod-status mod-stale mod-loaded) mod-stale))

(test-case "merge-mod-status: stale + stale = stale"
  (check-equal? (merge-mod-status mod-stale mod-stale) mod-stale))

(test-case "merge-mod-status: loading + loading = loading"
  (check-equal? (merge-mod-status mod-loading mod-loading) mod-loading))

;; ========================================
;; 2. Module Network Ref — CRUD Operations
;; ========================================

(test-case "make-module-network: creates with mod-loading status"
  (define mnr (make-module-network))
  (check-equal? (module-network-status mnr) mod-loading)
  (check-equal? (module-network-ref-cell-id-map mnr) (hasheq))
  (check-equal? (module-network-ref-dep-edges mnr) (hasheq))
  (check-false  (module-network-ref-snapshot-hash mnr)))

(test-case "module-network-add-definition: adds a cell, lookup works"
  (define mnr0 (make-module-network))
  (define-values (mnr1 cid) (module-network-add-definition mnr0 'foo (cons 'Int 42)))
  (check-not-false cid)
  (define result (module-network-lookup mnr1 'foo))
  (check-equal? result (cons 'Int 42)))

(test-case "module-network-lookup: returns #f for missing name"
  (define mnr (make-module-network))
  (check-false (module-network-lookup mnr 'nonexistent)))

(test-case "module-network-write: updates existing cell"
  (define mnr0 (make-module-network))
  (define-values (mnr1 _cid) (module-network-add-definition mnr0 'bar (cons 'Int 1)))
  (define mnr2 (module-network-write mnr1 'bar (cons 'Int 99)))
  (check-equal? (module-network-lookup mnr2 'bar) (cons 'Int 99)))

(test-case "module-network-set-status: loading → loaded"
  (define mnr0 (make-module-network))
  (check-equal? (module-network-status mnr0) mod-loading)
  (define mnr1 (module-network-set-status mnr0 mod-loaded))
  (check-equal? (module-network-status mnr1) mod-loaded))

(test-case "module-network-set-status: loaded → stale (monotone)"
  (define mnr0 (make-module-network))
  (define mnr1 (module-network-set-status mnr0 mod-loaded))
  (define mnr2 (module-network-set-status mnr1 mod-stale))
  (check-equal? (module-network-status mnr2) mod-stale))

(test-case "module-network-set-status: stale + loaded stays stale (monotone merge)"
  (define mnr0 (make-module-network))
  (define mnr1 (module-network-set-status mnr0 mod-stale))
  (define mnr2 (module-network-set-status mnr1 mod-loaded))
  (check-equal? (module-network-status mnr2) mod-stale))

(test-case "module-network-materialize: returns all definitions"
  (define mnr0 (make-module-network))
  (define-values (mnr1 _c1) (module-network-add-definition mnr0 'foo (cons 'Int 1)))
  (define-values (mnr2 _c2) (module-network-add-definition mnr1 'bar (cons 'String "hi")))
  (define-values (mnr3 _c3) (module-network-add-definition mnr2 'baz (cons 'Bool #t)))
  (define snap (module-network-materialize mnr3))
  (check-equal? (hash-count snap) 3)
  (check-equal? (hash-ref snap 'foo) (cons 'Int 1))
  (check-equal? (hash-ref snap 'bar) (cons 'String "hi"))
  (check-equal? (hash-ref snap 'baz) (cons 'Bool #t)))

(test-case "module-network: multiple definitions with overwrites"
  (define mnr0 (make-module-network))
  (define-values (mnr1 _c1) (module-network-add-definition mnr0 'x (cons 'Int 10)))
  (define-values (mnr2 _c2) (module-network-add-definition mnr1 'y (cons 'Int 20)))
  ;; Overwrite x
  (define mnr3 (module-network-write mnr2 'x (cons 'Int 100)))
  (check-equal? (module-network-lookup mnr3 'x) (cons 'Int 100))
  (check-equal? (module-network-lookup mnr3 'y) (cons 'Int 20)))

;; ========================================
;; 3. Shadow-Cell Cross-Network Prototype
;; ========================================
;;
;; Validates the core architectural pattern for Track 5:
;; Two independent prop-networks (simulating two modules).
;; A shadow cell in network B is initialized from a cell in network A.
;; Propagation within B works from the shadow cell.
;; "Reload" of A is simulated by writing to B's shadow cell.

(test-case "shadow-cell: cross-network read via shadow initialization"
  ;; Network A: module "bar" with a definition cell
  (define net-a0 (make-prop-network))
  (define-values (net-a1 bar-cell) (net-new-cell net-a0 (cons 'Int 42) merge-replace))

  ;; Network B: file "foo" creates a shadow cell initialized from A's value
  (define bar-value (net-cell-read net-a1 bar-cell))
  (define net-b0 (make-prop-network))
  (define-values (net-b1 shadow-cell) (net-new-cell net-b0 bar-value merge-replace))

  ;; Verify: shadow cell in B has bar's value
  (check-equal? (net-cell-read net-b1 shadow-cell) (cons 'Int 42)))

(test-case "shadow-cell: propagation within B from shadow cell"
  ;; Network A: module "bar"
  (define net-a0 (make-prop-network))
  (define-values (net-a1 bar-cell) (net-new-cell net-a0 (cons 'Int 42) merge-replace))

  ;; Network B: shadow cell + downstream cell + propagator
  (define net-b0 (make-prop-network))
  (define bar-val (net-cell-read net-a1 bar-cell))
  (define-values (net-b1 shadow) (net-new-cell net-b0 bar-val merge-replace))
  (define-values (net-b2 result) (net-new-cell net-b1 'infra-bot merge-replace))

  ;; Propagator: when shadow changes, write its cdr (the value part) to result
  ;; fire-fn contract: (prop-network → prop-network)
  (define (extract-value-prop net)
    (define shadow-val (net-cell-read net shadow))
    (if (and shadow-val (pair? shadow-val))
        (net-cell-write net result (cdr shadow-val))
        net))

  (define-values (net-b3 _pid)
    (net-add-propagator net-b2 (list shadow) (list result) extract-value-prop))
  (define net-b4 (run-to-quiescence net-b3))

  ;; Result cell should have the extracted value
  (check-equal? (net-cell-read net-b4 result) 42))

(test-case "shadow-cell: simulated reload updates propagation"
  ;; Network A: module "bar" — initial value
  (define net-a0 (make-prop-network))
  (define-values (net-a1 bar-cell) (net-new-cell net-a0 (cons 'Int 42) merge-replace))

  ;; Network B: shadow + downstream
  (define net-b0 (make-prop-network))
  (define bar-val (net-cell-read net-a1 bar-cell))
  (define-values (net-b1 shadow) (net-new-cell net-b0 bar-val merge-replace))
  (define-values (net-b2 result) (net-new-cell net-b1 'infra-bot merge-replace))

  (define (extract-value-prop net)
    (define shadow-val (net-cell-read net shadow))
    (if (and shadow-val (pair? shadow-val))
        (net-cell-write net result (cdr shadow-val))
        net))

  (define-values (net-b3 _pid)
    (net-add-propagator net-b2 (list shadow) (list result) extract-value-prop))
  (define net-b4 (run-to-quiescence net-b3))
  (check-equal? (net-cell-read net-b4 result) 42)

  ;; Simulate "bar reloads": A gets new value, we update B's shadow
  (define net-a2 (net-cell-write net-a1 bar-cell (cons 'Int 99)))
  (define new-bar-val (net-cell-read net-a2 bar-cell))

  ;; Write new value to B's shadow cell, re-propagate
  (define net-b5 (net-cell-write net-b4 shadow new-bar-val))
  (define net-b6 (run-to-quiescence net-b5))

  ;; Result should reflect the new value
  (check-equal? (net-cell-read net-b6 result) 99))

(test-case "shadow-cell: multiple shadows from different modules"
  ;; Module A: definition x = 10
  (define net-a0 (make-prop-network))
  (define-values (net-a1 x-cell) (net-new-cell net-a0 (cons 'Int 10) merge-replace))

  ;; Module C: definition y = 20
  (define net-c0 (make-prop-network))
  (define-values (net-c1 y-cell) (net-new-cell net-c0 (cons 'Int 20) merge-replace))

  ;; File B: shadows both, combines them
  (define net-b0 (make-prop-network))
  (define-values (net-b1 shadow-x) (net-new-cell net-b0 (net-cell-read net-a1 x-cell) merge-replace))
  (define-values (net-b2 shadow-y) (net-new-cell net-b1 (net-cell-read net-c1 y-cell) merge-replace))
  (define-values (net-b3 sum-cell) (net-new-cell net-b2 'infra-bot merge-replace))

  ;; Propagator: sum = x + y (extract cdr from both shadows)
  (define (sum-prop net)
    (define xv (net-cell-read net shadow-x))
    (define yv (net-cell-read net shadow-y))
    (if (and xv (pair? xv) yv (pair? yv))
        (net-cell-write net sum-cell (+ (cdr xv) (cdr yv)))
        net))

  (define-values (net-b4 _pid)
    (net-add-propagator net-b3 (list shadow-x shadow-y) (list sum-cell) sum-prop))
  (define net-b5 (run-to-quiescence net-b4))

  (check-equal? (net-cell-read net-b5 sum-cell) 30))

(test-case "module-network-ref: full lifecycle (create, populate, finalize)"
  ;; Simulate loading a module: create network, add defs, mark loaded
  (define mnr0 (make-module-network))
  (check-equal? (module-network-status mnr0) mod-loading)

  ;; Add definitions
  (define-values (mnr1 _c1) (module-network-add-definition mnr0 'add (cons 'fn 'add-impl)))
  (define-values (mnr2 _c2) (module-network-add-definition mnr1 'zero (cons 'Nat 'zero-val)))
  (define-values (mnr3 _c3) (module-network-add-definition mnr2 'suc (cons 'fn 'suc-impl)))

  ;; Mark loaded
  (define mnr4 (module-network-set-status mnr3 mod-loaded))
  (check-equal? (module-network-status mnr4) mod-loaded)

  ;; All definitions accessible
  (check-equal? (module-network-lookup mnr4 'add) (cons 'fn 'add-impl))
  (check-equal? (module-network-lookup mnr4 'zero) (cons 'Nat 'zero-val))
  (check-equal? (module-network-lookup mnr4 'suc) (cons 'fn 'suc-impl))

  ;; Materialize matches
  (define snap (module-network-materialize mnr4))
  (check-equal? (hash-count snap) 3))
